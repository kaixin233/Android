import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/knowledge_service.dart';
import '../widgets/ai_assistant_sheet.dart';

/// AI 学习助手统一入口
///
/// 集中管理各类学习内容（考点知识 / 练习题目）的：
/// - 提问上下文组装规则
/// - 持久化条目 ID 规则（`know:科目:章:小节`、`q:题目uniqueKey`）
/// 避免各页面各自拼装导致的规则漂移。
class AiAssistantLauncher {
  AiAssistantLauncher._();

  /// 以考点知识小节为上下文打开 AI 助手
  ///
  /// [selectedText] 为用户在卡片中选中的片段；为空则以整节内容为上下文。
  static void showForKnowledgeSection(
    BuildContext context, {
    required QuestionSubject subject,
    required String chapterNumber,
    required KnowledgeSection section,
    String? selectedText,
  }) {
    final wholeText = section.toPlainText();
    final hasSelection = selectedText != null && selectedText.isNotEmpty;
    AiAssistantSheet.show(
      context,
      itemId: 'know:${subject.name}:$chapterNumber:${section.number}',
      itemType: 'knowledge',
      itemTitle: section.title,
      contextText: hasSelection
          ? '【选中片段】\n$selectedText\n\n【所属小节「${section.title}」完整内容】\n$wholeText'
          : wholeText,
    );
  }

  /// 以练习题目为上下文打开 AI 助手
  ///
  /// [submitted] 表示当前是否已提交答案：已提交时上下文携带正确答案与解析；
  /// 未提交时提示 AI 以启发式讲解为主，不直接给出答案。
  /// [selectedText] 为用户在题干/解析中选中的片段。
  static void showForQuestion(
    BuildContext context, {
    required Question question,
    required bool submitted,
    String? selectedText,
  }) {
    final whole = buildQuestionContext(question, submitted: submitted);
    final hasSelection = selectedText != null && selectedText.isNotEmpty;
    final title = question.prompt.length > 30
        ? '${question.prompt.substring(0, 30)}…'
        : question.prompt;
    AiAssistantSheet.show(
      context,
      itemId: 'q:${question.uniqueKey}',
      itemType: 'question',
      itemTitle: title,
      contextText: hasSelection
          ? '【选中片段】\n$selectedText\n\n【完整题目】\n$whole'
          : whole,
    );
  }

  /// 组装题目上下文文本（题干 + 选项 + 提交后的答案与解析）
  static String buildQuestionContext(
    Question question, {
    required bool submitted,
  }) {
    final buffer = StringBuffer()
      ..writeln('【题型】${question.type.label}')
      ..writeln('【题目】${question.prompt}');
    if (question.options.isNotEmpty) {
      for (var i = 0; i < question.options.length; i++) {
        buffer
            .writeln('${String.fromCharCode(65 + i)}. ${question.options[i]}');
      }
    }
    if (submitted) {
      buffer.writeln('【正确答案】${correctAnswerTextOf(question)}');
      if (question.explanation.isNotEmpty) {
        buffer.writeln('【解析】${question.explanation}');
      }
    } else {
      buffer.writeln('（学员尚未作答，请勿直接给出答案，以启发式讲解为主）');
    }
    return buffer.toString();
  }

  /// 各题型的正确答案文本
  static String correctAnswerTextOf(Question question) {
    switch (question.type) {
      case QuestionType.singleChoice:
        if (question.answerIndex != null &&
            question.answerIndex! < question.options.length) {
          return question.options[question.answerIndex!];
        }
        return '未知';
      case QuestionType.multipleChoice:
        return question.answerIndices
            .where((i) => i < question.options.length)
            .map((i) => question.options[i])
            .join('、');
      case QuestionType.trueFalse:
        return question.isCorrect == true ? '正确' : '错误';
      case QuestionType.fillBlank:
        return question.acceptableAnswers.join(' / ');
    }
  }
}
