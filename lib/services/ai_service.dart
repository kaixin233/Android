import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
/// 主链路：[WebChatBridge] 驱动的 App 内常驻网页端会话（免费、无需 Token、天然绕过
/// PoW 与风控），由 AI 助手界面直接调用。
///
/// 备用链路：配置了官方 API Key 时，退回 api.deepseek.com（OpenAI 兼容，按 token 计费），
/// 见 [chatOfficial]。
///
/// 说明：旧版「纯客户端直连网页端后端」的 `_chatDirect` / `_chatViaProxy` 因缺少 PoW
/// 求解与会话 Cookie，必然被官网拦截，已移除；凡需稳定链路请走官方 API Key 或网页端登录。
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
  /// 注：方案 B 主链路已不再依赖手抄 Token（由常驻 WebView 会话驱动），
  /// 此处仅保留存取以备兼容与高级用途。
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

  /// 是否至少配置了官方 API Key（网页端主链路由 App 内登录会话提供）
  static Future<bool> hasAnyProvider() async => await hasApiKey();

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
    if (await hasApiKey()) return '官方 API';
    return '网页端（App 内登录）';
  }

  // ========== API 调用 ==========

  /// 仅走官方 API（按 token 计费），供需要稳定链路的场景调用。
  /// 抛出 [AiApiException] 时可直接向用户展示其 message。
  static Future<String> chatOfficial(List<AiChatMessage> messages) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      throw AiApiException('尚未配置官方 API Key。网页端问答请直接在 App 内登录后提问；'
          '如需官方 API 通道，请到「AI 助手设置」填写 Key。');
    }
    return _chatOfficial(messages, apiKey);
  }

  /// 测试当前生效的提供方是否可用（最小开销请求）
  static Future<void> testConnection() async {
    await chatOfficial(const [
      AiChatMessage(role: 'user', content: '你好，请只回复"连接成功"'),
    ]);
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
    } on AiApiException {
      rethrow;
    } catch (e) {
      throw AiApiException('调用官方 API 失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  // ========== 工具方法 ==========

  static String _friendlyErrorForStatus(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'Token / API Key 无效或已过期，请重新填写';
      case 402:
        return 'DeepSeek 账户余额不足，请前往 platform.deepseek.com 充值';
      case 403:
        return '请求被拒绝（可能是权限或风控拦截），请检查 API Key';
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
