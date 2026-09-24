import '../services/ai_service.dart';
import '../services/web_chat_bridge.dart';

/// AI 考点记忆口诀生成
///
/// 复用应用内已有的 AI 学习助手通道（DeepSeek 网页端常驻会话 / 官方 API Key），
/// 为单题生成朗朗上口、易于记忆的考点口诀。选择通道的逻辑与 [AiAssistantSheet]
/// 一致：优先网页端已登录会话（免费、无需 Token），其次官方 API Key。
class AiMnemonicService {
  AiMnemonicService._();

  /// 系统设定：限定输出为简洁、押韵、易记的口诀。
  static const String _systemPrompt = '''你是二级建造师执业资格考试的资深辅导讲师，擅长把枯燥的考点编成朗朗上口、易于记忆的口诀。

要求：
1. 围绕"题目 + 解析 + 考点"提炼 1~3 句记忆口诀，押韵或有节奏感为佳；
2. 口诀后可附一句极简要点说明（为什么这么记），用"要点："开头；
3. 只输出口诀内容本身，不要输出"好的""以下是"等客套话，不要使用 Markdown 标题；
4. 语言简洁，控制在 80 字以内。''';

  /// 为给定考点上下文生成记忆口诀。
  ///
  /// [knowledgeContext] 形如：题干、选项、正确答案、解析、关联考点。
  /// [onProgress] 网页端流式通道下用于实时回显（官方 API 不触发）。
  /// 返回口诀文本；无任何可用通道时抛 [AiApiException]。
  static Future<String> generateMnemonic({
    required String knowledgeContext,
    void Function(String partial)? onProgress,
  }) async {
    final userPrompt = '请为以下考点生成记忆口诀：\n\n$knowledgeContext';
    if (await WebChatBridge.instance.checkLogin()) {
      final combined = '$_systemPrompt\n\n$userPrompt';
      return WebChatBridge.instance.sendPrompt(combined, onProgress: onProgress);
    }
    if (await AiService.hasApiKey()) {
      return AiService.chatOfficial([
        AiChatMessage(role: 'system', content: _systemPrompt),
        AiChatMessage(role: 'user', content: userPrompt),
      ]);
    }
    throw AiApiException('未检测到 DeepSeek 网页端登录或官方 API Key。'
        '请先在「AI 助手设置」中登录网页端，或填写官方 API Key 后再使用记忆口诀功能。');
  }
}
