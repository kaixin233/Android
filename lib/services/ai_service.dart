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
/// 主链路：DeepSeek 官方 API（OpenAI 兼容，https://api.deepseek.com）。
/// 降级链路：未配置 API Key 时，由 UI 层打开 App 内置的 DeepSeek 网页端
///（见 pages/deepseek_web_page.dart），用户登录后粘贴已复制的提问内容。
class AiService {
  AiService._();

  static const String _apiKeyPrefsKey = 'deepseekApiKey';
  static const String _modelPrefsKey = 'deepseekModel';

  static const String defaultModel = 'deepseek-chat';
  static const List<String> availableModels = <String>[
    'deepseek-chat',
    'deepseek-reasoner',
  ];

  static const String _endpoint = 'https://api.deepseek.com/chat/completions';

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

  static Future<String> getModel() async {
    final prefs = await _instance;
    final model = prefs.getString(_modelPrefsKey);
    return availableModels.contains(model) ? model! : defaultModel;
  }

  static Future<void> saveModel(String model) async {
    final prefs = await _instance;
    await prefs.setString(_modelPrefsKey, model);
  }

  // ========== API 调用 ==========

  /// 发起多轮对话请求，返回 AI 回答文本。
  ///
  /// [messages] 需包含 system 提示词与按时间顺序的 user/assistant 消息。
  /// 抛出 [AiApiException] 时可直接向用户展示其 message。
  static Future<String> chat(List<AiChatMessage> messages) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      throw AiApiException('尚未配置 DeepSeek API Key');
    }
    final model = await getModel();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(Uri.parse(_endpoint));
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

  /// 测试 API Key 是否可用（最小开销请求）
  static Future<void> testConnection() async {
    await chat(const [
      AiChatMessage(role: 'user', content: '你好，请回复"连接成功"'),
    ]);
  }

  static String _friendlyErrorForStatus(int statusCode, String body) {
    switch (statusCode) {
      case 401:
        return 'API Key 无效或已过期，请重新填写';
      case 402:
        return 'DeepSeek 账户余额不足，请前往 platform.deepseek.com 充值';
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
