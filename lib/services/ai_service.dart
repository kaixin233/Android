import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// AI 接口调用异常，[message] 为可直接展示给用户的友好文案
class AiApiException implements Exception {
  AiApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 对话消息（OpenAI 兼容格式）
class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  final String role; // system / user / assistant
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// DeepSeek AI 服务
///
/// 主链路：DeepSeek 网页端接口（chat.deepseek.com）。
///   凭登录后的 `userToken`（浏览器 localStorage 值）直接调用网页端后端，
///   无需跳转网页、免费使用。支持两种模式：
///     - 直连：POST /api/v0/chat_session/create 建会话 →
///             POST /api/v0/chat/completion（SSE 流式）发消息。
///     - 反代：填写自托管的 OpenAI 兼容反代地址（如 deepseek-free-api），
///             由其代为求解 PoW / 绕过风控，App 走标准 OpenAI 格式。
/// 备用链路：配置了官方 API Key 时，退回 api.deepseek.com（OpenAI 兼容，按 token 计费）。
///
/// 说明：网页端接口为非官方接口，字段可能随官网改版变化；且存在 PoW 算力验证
/// 与 Cloudflare 风控，纯客户端直连偶发被拦，此时建议配置反代地址。
class AiService {
  AiService._();

  static const String _apiKeyPrefsKey = 'deepseekApiKey';
  static const String _modelPrefsKey = 'deepseekModel';
  static const String _webTokenPrefsKey = 'deepseekWebToken';
  static const String _proxyUrlPrefsKey = 'deepseekProxyUrl';

  static const String defaultModel = 'deepseek-chat';
  static const List<String> availableModels = <String>[
    'deepseek-chat',
    'deepseek-reasoner',
  ];

  /// 官方 API（备用链路）
  static const String _officialEndpoint =
      'https://api.deepseek.com/chat/completions';

  /// 网页端接口（主链路，直连模式）
  static const String _webBaseUrl = 'https://chat.deepseek.com';
  static const String _webSessionEndpoint = '$_webBaseUrl/api/v0/chat_session/create';
  static const String _webChatEndpoint = '$_webBaseUrl/api/v0/chat/completion';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ========== 配置管理 ==========

  static Future<String> getApiKey() async {
    final prefs = await _instance;
    return prefs.getString(_apiKeyPrefsKey)?.trim() ?? '';
  }

  static Future<bool> hasApiKey() async => (await getApiKey()).isNotEmpty;

  static Future<void> saveApiKey(String key) async {
    final prefs = await _instance;
    await prefs.setString(_apiKeyPrefsKey, key.trim());
  }

  static Future<void> clearApiKey() async {
    final prefs = await _instance;
    await prefs.remove(_apiKeyPrefsKey);
  }

  /// 网页端登录 Token（chat.deepseek.com 的 userToken，存于 localStorage）
  static Future<String> getWebToken() async {
    final prefs = await _instance;
    return prefs.getString(_webTokenPrefsKey)?.trim() ?? '';
  }

  static Future<bool> hasWebToken() async => (await getWebToken()).isNotEmpty;

  static Future<void> saveWebToken(String token) async {
    final prefs = await _instance;
    await prefs.setString(_webTokenPrefsKey, token.trim());
  }

  static Future<void> clearWebToken() async {
    final prefs = await _instance;
    await prefs.remove(_webTokenPrefsKey);
  }

  /// 可选的反代地址（OpenAI 兼容，用于绕过 PoW / 风控）
  static Future<String> getProxyUrl() async {
    final prefs = await _instance;
    return prefs.getString(_proxyUrlPrefsKey)?.trim() ?? '';
  }

  static Future<void> saveProxyUrl(String url) async {
    final prefs = await _instance;
    await prefs.setString(_proxyUrlPrefsKey, url.trim());
  }

  /// 是否至少配置了网页端 Token 或官方 API Key
  static Future<bool> hasAnyProvider() async =>
      (await hasWebToken()) || (await hasApiKey());

  static Future<String> getModel() async {
    final prefs = await _instance;
    final model = prefs.getString(_modelPrefsKey);
    return availableModels.contains(model) ? model! : defaultModel;
  }

  static Future<void> saveModel(String model) async {
    final prefs = await _instance;
    await prefs.setString(_modelPrefsKey, model);
  }

  /// 当前生效的提供方描述（用于 UI 展示）
  static Future<String> activeProviderLabel() async {
    if (await hasWebToken()) {
      final proxy = await getProxyUrl();
      return proxy.isEmpty ? '网页端直连' : '网页端反代';
    }
    if (await hasApiKey()) return '官方 API';
    return '未配置';
  }

  // ========== API 调用 ==========

  /// 发起多轮对话请求，返回 AI 回答文本。
  ///
  /// [messages] 需包含 system 提示词与按时间顺序的 user/assistant 消息。
  /// 优先级：网页端 Token（直连 / 反代）> 官方 API Key。
  /// 抛出 [AiApiException] 时可直接向用户展示其 message。
  static Future<String> chat(List<AiChatMessage> messages) async {
    final token = await getWebToken();
    if (token.isNotEmpty) {
      return _chatViaWeb(messages, token);
    }
    final apiKey = await getApiKey();
    if (apiKey.isNotEmpty) {
      return _chatOfficial(messages, apiKey);
    }
    throw AiApiException('尚未配置 DeepSeek 网页端 Token 或 API Key，请到「AI 助手设置」中填写');
  }

  /// 仅走官方 API（忽略网页端 Token），供需要稳定链路的场景调用。
  static Future<String> chatOfficial(List<AiChatMessage> messages) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      throw AiApiException('尚未配置官方 API Key');
    }
    return _chatOfficial(messages, apiKey);
  }

  /// 测试当前生效的提供方是否可用（最小开销请求）
  static Future<void> testConnection() async {
    await chat(const [
      AiChatMessage(role: 'user', content: '你好，请只回复"连接成功"'),
    ]);
  }

  // ---------- 网页端链路 ----------

  static Future<String> _chatViaWeb(List<AiChatMessage> messages, String token) async {
    final proxy = await getProxyUrl();
    if (proxy.isNotEmpty) {
      return _chatViaProxy(messages, token, proxy);
    }
    return _chatDirect(messages, token);
  }

  /// 直连 chat.deepseek.com 后端（需 userToken）
  static Future<String> _chatDirect(List<AiChatMessage> messages, String token) async {
    final model = await getModel();
    final isReasoner = model == 'deepseek-reasoner';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      // 1) 创建会话
      final sessionId = await _createWebSession(client, token);

      // 2) 发送消息（网页端使用单一 prompt，需要把多轮上下文拼进 prompt）
      final prompt = _flattenToPrompt(messages);
      final request = await client.postUrl(Uri.parse(_webChatEndpoint));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
        ..set('Accept', 'text/event-stream')
        ..set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(<String, dynamic>{
        'chat_session_id': sessionId,
        'parent_message_id': _uuid(),
        'prompt': prompt,
        'ref_file_ids': <String>[],
        'search_enabled': false,
        'thinking_enabled': isReasoner,
        'model_class': isReasoner ? 'deepseek_reasoner' : 'deepseek_chat',
      }));

      final response =
          await request.close().timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final answer = await _readSse(response);
        if (answer.isEmpty) throw AiApiException('AI 返回内容为空，请重试');
        return answer;
      }
      throw AiApiException(
        _friendlyErrorForStatus(response.statusCode,
            await response.transform(utf8.decoder).join()),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw AiApiException('请求超时，请检查网络后重试');
    } on SocketException {
      throw AiApiException('网络连接失败，请检查网络后重试');
    } on HandshakeException {
      throw AiApiException('网络安全校验失败，请检查系统时间或网络后重试');
    } on AiApiException {
      rethrow;
    } catch (e) {
      throw AiApiException('调用网页端失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _createWebSession(HttpClient client, String token) async {
    try {
      final request = await client.postUrl(Uri.parse(_webSessionEndpoint));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
        ..set('User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(<String, dynamic>{
        'chat_session_id': _uuid(),
      }));

      final response =
          await request.close().timeout(const Duration(seconds: 30));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw AiApiException(
          _friendlyErrorForStatus(response.statusCode, body),
          statusCode: response.statusCode,
        );
      }
      try {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final id = decoded['data']?['biz_data']?['id'] ??
            decoded['data']?['id'] ??
            decoded['id'];
        if (id is String && id.isNotEmpty) return id;
      } catch (_) {
        // 解析失败时交给下方统一报错
      }
      throw AiApiException('无法解析网页端会话，请确认 Token 是否有效');
    } on AiApiException {
      rethrow;
    } catch (e) {
      throw AiApiException('创建网页端会话失败：$e');
    }
  }

  /// 走自托管的 OpenAI 兼容反代（标准 messages 数组，支持原生多轮上下文）
  static Future<String> _chatViaProxy(
      List<AiChatMessage> messages, String token, String proxy) async {
    final model = await getModel();
    final proxyModel = model == 'deepseek-reasoner' ? 'deepseek-r1' : 'deepseek';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final base = proxy.endsWith('/') ? proxy.substring(0, proxy.length - 1) : proxy;
      final request = await client.postUrl(Uri.parse('$base/v1/chat/completions'));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
        ..set('Accept', 'text/event-stream')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(jsonEncode(<String, dynamic>{
        'model': proxyModel,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': 0.3,
        'max_tokens': 2048,
        'stream': true,
      }));

      final response =
          await request.close().timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        final answer = await _readSse(response);
        if (answer.isEmpty) throw AiApiException('AI 返回内容为空，请重试');
        return answer;
      }
      throw AiApiException(
        _friendlyErrorForStatus(response.statusCode,
            await response.transform(utf8.decoder).join()),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw AiApiException('请求超时，请检查网络后重试');
    } on SocketException {
      throw AiApiException('网络连接失败，请检查网络后重试');
    } on HandshakeException {
      throw AiApiException('网络安全校验失败，请检查系统时间或网络后重试');
    } on AiApiException {
      rethrow;
    } catch (e) {
      throw AiApiException('调用反代失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  // ---------- 官方 API 链路（备用） ----------

  static Future<String> _chatOfficial(
      List<AiChatMessage> messages, String apiKey) async {
    final model = await getModel();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(Uri.parse(_officialEndpoint));
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.write(jsonEncode({
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': 0.3,
        'max_tokens': 2048,
        'stream': false,
      }));

      final response =
          await request.close().timeout(const Duration(seconds: 90));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) {
          throw AiApiException('AI 返回内容为空，请重试');
        }
        final content = (choices.first as Map<String, dynamic>)['message']
            ?['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          throw AiApiException('AI 返回内容为空，请重试');
        }
        return content.trim();
      }

      throw AiApiException(
        _friendlyErrorForStatus(response.statusCode, body),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw AiApiException('请求超时，请检查网络后重试');
    } on SocketException {
      throw AiApiException('网络连接失败，请检查网络后重试');
    } on HandshakeException {
      throw AiApiException('网络安全校验失败，请检查系统时间或网络后重试');
    } on FormatException {
      throw AiApiException('AI 返回数据格式异常，请重试');
    } finally {
      client.close(force: true);
    }
  }

  // ========== 工具方法 ==========

  /// 把 OpenAI 格式的多轮消息压平成网页端所需的单一 prompt 文本
  static String _flattenToPrompt(List<AiChatMessage> messages) {
    final buffer = StringBuffer();
    String? system;
    final turns = <Map<String, String>>[];

    for (final m in messages) {
      if (m.role == 'system') {
        system = m.content;
      } else if (m.role == 'user') {
        turns.add(<String, String>{'role': 'user', 'content': m.content});
      } else if (m.role == 'assistant') {
        if (turns.isNotEmpty && !turns.last.containsKey('answer')) {
          turns.last['answer'] = m.content;
        } else {
          turns.add(<String, String>{'role': 'assistant', 'content': m.content});
        }
      }
    }

    if (system != null && system.isNotEmpty) {
      buffer.writeln(system);
      buffer.writeln();
    }
    for (final t in turns) {
      buffer.writeln('用户：${t['content']}');
      final answer = t['answer'];
      if (answer != null && answer.isNotEmpty) {
        buffer.writeln('助手：$answer');
      }
    }
    return buffer.toString().trim();
  }

  /// 读取 OpenAI 兼容的 SSE 流，拼接 delta.content 返回完整文本
  static Future<String> _readSse(HttpClientResponse response) async {
    final buffer = StringBuffer();
    String? pending;
    await for (final chunk in response.transform(utf8.decoder)) {
      final text = pending == null ? chunk : pending + chunk;
      final lines = text.split('\n');
      pending = lines.isNotEmpty ? lines.removeLast() : null;
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || !line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') continue;
        try {
          final decoded = jsonDecode(data) as Map<String, dynamic>;
          final choices = decoded['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;
          final delta =
              (choices.first as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) buffer.write(content);
        } catch (_) {
          // 忽略畸形行
        }
      }
    }
    if (pending != null) {
      final line = pending.trim();
      if (line.startsWith('data:')) {
        final data = line.substring(5).trim();
        if (data.isNotEmpty && data != '[DONE]') {
          try {
            final decoded = jsonDecode(data) as Map<String, dynamic>;
            final choices = decoded['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = (choices.first as Map<String, dynamic>)['delta']
                  as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) buffer.write(content);
            }
          } catch (_) {}
        }
      }
    }
    return buffer.toString().trim();
  }

  /// 生成 UUID v4（用于网页端 session / message id）
  static String _uuid() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex[0]}${hex[1]}${hex[2]}${hex[3]}-'
        '${hex[4]}${hex[5]}-'
        '${hex[6]}${hex[7]}-'
        '${hex[8]}${hex[9]}-'
        '${hex[10]}${hex[11]}${hex[12]}${hex[13]}${hex[14]}${hex[15]}';
  }

  static String _friendlyErrorForStatus(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'Token / API Key 无效或已过期，请重新填写';
      case 402:
        return 'DeepSeek 账户余额不足，请前往 platform.deepseek.com 充值';
      case 403:
        return '请求被拒绝（可能是网页端 PoW 验证或风控拦截）。'
            '建议：在「AI 助手设置」中填写自托管的反代地址后重试';
      case 429:
        return '请求过于频繁，请稍后再试';
      case 500:
      case 502:
      case 503:
        return 'DeepSeek 服务暂时不可用，请稍后重试';
      default:
        String detail = '';
        try {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          detail = (decoded['error'] as Map<String, dynamic>?)?['message']
                  as String? ??
              '';
        } catch (_) {}
        return '请求失败（HTTP $statusCode）${detail.isNotEmpty ? '：$detail' : ''}';
    }
  }
}
