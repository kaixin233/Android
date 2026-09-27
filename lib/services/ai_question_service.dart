import 'dart:convert';

import '../models/question.dart';
import 'ai_service.dart';
import 'web_chat_bridge.dart';

/// AI 出题上下文：约束生成题目的科目/章节/考点归属
class AiQuestionContext {
  const AiQuestionContext({
    required this.subject,
    this.topic = '',
    this.chapterNumber,
    this.subsection,
    this.sectionTitle,
    this.knowledgeContext,
  });

  final QuestionSubject subject;

  /// 用户输入的主题（可为空，为空时用考点上下文）
  final String topic;

  final String? chapterNumber;
  final String? subsection;
  final String? sectionTitle;

  /// 关联考点正文（来自电子教材），用于提升命中率
  final String? knowledgeContext;

  String get displayName {
    final parts = <String>[subject.label];
    if (chapterNumber != null && chapterNumber!.isNotEmpty) {
      parts.add('第$chapterNumber章');
    }
    if (subsection != null && subsection!.isNotEmpty) {
      parts.add('第$subsection节');
    }
    if (topic.trim().isNotEmpty) parts.add(topic.trim());
    return parts.join(' · ');
  }
}

/// AI 出题服务：基于 DeepSeek（网页端常驻会话 / 官方 API Key）生成题目，
/// 解析为 [Question] 后可由题库导入，并自动归入指定章节/小节。
class AiQuestionService {
  AiQuestionService._();

  static const String _systemPrompt = '''你是二级建造师执业资格考试的资深命题专家，熟悉考试大纲与命题规律。

命题要求：
1. 严格贴合给定考点，符合考试大纲范围，不编造超纲内容；
2. 单选题 4 个选项，干扰项要有迷惑性但不能有歧义；多选题 4~5 个选项，正确答案 2~4 个；
3. 判断题仅输出"正确"或"错误"作为答案；
4. 每题必须给出简明解析，并标注 1~3 个考点关键词；
5. 只输出 JSON，不得输出任何解释性文字或 Markdown 代码块标记。

JSON 结构（严格遵循）：
{"questions":[
  {"type":"singleChoice","prompt":"题干","options":["A选项","B选项","C选项","D选项"],
   "answerIndex":0,"explanation":"解析","knowledgePoints":["考点1","考点2"]},
  {"type":"multipleChoice","prompt":"题干","options":["A","B","C","D"],
   "answerIndices":[0,2],"explanation":"解析","knowledgePoints":["考点"]},
  {"type":"trueFalse","prompt":"判断下列说法的正误：...","isCorrect":true,
   "explanation":"解析","knowledgePoints":["考点"]}
]}''';

  /// 生成题目。
  ///
  /// [count] 建议 1~10；[types] 为允许的题型集合。
  /// [onProgress] 在网页端流式通道下实时回显。
  static Future<List<Question>> generate({
    required AiQuestionContext context,
    required Set<QuestionType> types,
    int count = 5,
    void Function(String partial)? onProgress,
  }) async {
    final typeText = types.map((t) => t.label).join('、');
    final lines = <String>[
      '请命制 $count 道题目。',
      '科目：${context.subject.label}（${context.subject.description}）',
      '题型：仅限 $typeText',
    ];
    if (context.chapterNumber != null && context.chapterNumber!.isNotEmpty) {
      lines.add('所属章节：第${context.chapterNumber}章');
    }
    if (context.sectionTitle != null && context.sectionTitle!.isNotEmpty) {
      lines.add('所属小节：${context.sectionTitle}');
    }
    if (context.topic.trim().isNotEmpty) {
      lines.add('命题主题/范围：${context.topic.trim()}');
    }
    if (context.knowledgeContext != null &&
        context.knowledgeContext!.trim().isNotEmpty) {
      final kc = context.knowledgeContext!.trim();
      lines.add('参考考点内容（务必围绕其命题）：\n'
          '${kc.length > 2500 ? kc.substring(0, 2500) : kc}');
    }

    final userPrompt = lines.join('\n');

    String raw;
    if (await WebChatBridge.instance.checkLogin()) {
      raw = await WebChatBridge.instance
          .sendPrompt('$_systemPrompt\n\n$userPrompt', onProgress: onProgress);
    } else if (await AiService.hasApiKey()) {
      raw = await AiService.chatOfficial([
        AiChatMessage(role: 'system', content: _systemPrompt),
        AiChatMessage(role: 'user', content: userPrompt),
      ]);
    } else {
      throw AiApiException('未检测到 DeepSeek 网页端登录或官方 API Key。'
          '请先在「AI 助手设置」中登录网页端，或填写官方 API Key 后再使用 AI 出题。');
    }

    return parseGenerated(
      raw,
      context: context,
      types: types,
    );
  }

  /// 解析 AI 返回的 JSON 为题目列表（纯函数，便于单测）。
  ///
  /// 容忍 Markdown 代码块包裹、前后多余文字；丢弃字段缺失/不合法的题目。
  static List<Question> parseGenerated(
    String raw, {
    required AiQuestionContext context,
    required Set<QuestionType> types,
  }) {
    final map = _extractFirstJsonObject(raw);
    if (map == null) return const [];
    final list = map['questions'];
    if (list is! List) return const [];

    final out = <Question>[];
    var seq = 0;
    for (final item in list) {
      if (item is! Map) continue;
      final q = _buildQuestion(
        Map<String, dynamic>.from(item),
        context: context,
        types: types,
        seq: seq,
      );
      if (q != null) {
        out.add(q);
        seq++;
      }
    }
    return out;
  }

  /// 从可能包含多余文本/代码块的输出中提取首个完整 JSON 对象。
  static Map<String, dynamic>? _extractFirstJsonObject(String raw) {
    var text = raw.trim();
    // 去掉 ```json ... ``` 包裹
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final m = fence.firstMatch(text);
    if (m != null) text = m.group(1)!.trim();

    final start = text.indexOf('{');
    if (start < 0) return null;
    // 花括号配平扫描，截取首个完整对象（忽略字符串内的括号）
    var depth = 0;
    var inStr = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (inStr) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inStr = false;
        }
        continue;
      }
      if (c == '"') {
        inStr = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) {
          final candidate = text.substring(start, i + 1);
          try {
            final decoded = jsonDecode(candidate);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {
            return null;
          }
        }
      }
    }
    return null;
  }

  static Question? _buildQuestion(
    Map<String, dynamic> item, {
    required AiQuestionContext context,
    required Set<QuestionType> types,
    required int seq,
  }) {
    final prompt = (item['prompt'] as String?)?.trim() ?? '';
    if (prompt.isEmpty) return null;

    var type = QuestionTypeExtension.fromName(item['type'] as String? ?? '');
    if (!types.contains(type)) {
      // AI 返回了未请求的题型：按请求题型集合中的第一个降级处理
      type = types.isEmpty ? QuestionType.singleChoice : types.first;
    }

    final explanation = (item['explanation'] as String?)?.trim() ?? '';
    final kps = (item['knowledgePoints'] as List<dynamic>?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final id = 'ai_${DateTime.now().millisecondsSinceEpoch}_$seq';

    if (type == QuestionType.trueFalse) {
      final v = item['isCorrect'];
      bool? isCorrect;
      if (v is bool) {
        isCorrect = v;
      } else if (v is String) {
        isCorrect = v.contains('正确') || v.toLowerCase() == 'true';
      }
      if (isCorrect == null) return null;
      return Question(
        id: id,
        title: prompt,
        prompt: prompt,
        type: QuestionType.trueFalse,
        subject: context.subject,
        difficulty: QuestionDifficulty.medium,
        isCorrect: isCorrect,
        explanation: explanation,
        chapter: context.chapterNumber,
        subsection: context.subsection,
        knowledgePoints: kps,
      );
    }

    final options =
        (item['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            const <String>[];
    if (options.length < 2) return null;

    if (type == QuestionType.multipleChoice) {
      final idx = (item['answerIndices'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .where((i) => i >= 0 && i < options.length)
              .toSet()
              .toList() ??
          const <int>[];
      if (idx.length < 2) return null;
      idx.sort();
      return Question(
        id: id,
        title: prompt,
        prompt: prompt,
        type: QuestionType.multipleChoice,
        subject: context.subject,
        difficulty: QuestionDifficulty.medium,
        options: options,
        answerIndices: idx,
        explanation: explanation,
        chapter: context.chapterNumber,
        subsection: context.subsection,
        knowledgePoints: kps,
      );
    }

    final ai = item['answerIndex'];
    if (ai is! num) return null;
    final answerIndex = ai.toInt();
    if (answerIndex < 0 || answerIndex >= options.length) return null;
    return Question(
      id: id,
      title: prompt,
      prompt: prompt,
      type: QuestionType.singleChoice,
      subject: context.subject,
      difficulty: QuestionDifficulty.medium,
      options: options,
      answerIndex: answerIndex,
      explanation: explanation,
      chapter: context.chapterNumber,
      subsection: context.subsection,
      knowledgePoints: kps,
    );
  }
}
