import '../models/answer_outcome.dart';
import '../models/question.dart';

/// 作答判定与"否定题"识别。
///
/// 两类问题在此统一处理：
/// 1. **否定题**（"下列表述错误的是/不属于/不包括…"）：题库无对应字段，通过题干识别。
///    识别后，播报与展示不再说"正确答案是 X"，而改为"本题要求选出错误项，应选：X"，
///    避免把选项内容本身就是"错误说法"的正确选项说成"正确答案"。
/// 2. **多选题少选**：所选选项均正确但漏选 → [AnswerOutcome.partial]（有分），
///    不再判为"回答错误"。
class AnswerEvaluator {
  AnswerEvaluator._();

  /// 高置信度"选错项"指示语（题干中出现即视为否定题）
  static const List<String> _negativePhrases = <String>[
    '错误的是',
    '错误的',
    '不正确的是',
    '不正确',
    '不属于',
    '不包括',
  ];

  /// 尾部指示模式：否定词 + 若干非标点字符 + "的是/的有/选项"。
  ///
  /// 用逗号等标点截断，避免把"…不是法人，根本原因是（）"这类场景描述误判；
  /// 也刻意不收录"不能/不宜/不符合"等常见于正向题的否定词。
  static final RegExp _negativeTail = RegExp(
    r'(不是|不应|无需|无须|不对)[^，。！？；、\n]{0,20}(的是|的有|选项)',
  );

  /// 是否为"要求选出错误项/不属于项"的否定题。
  static bool isNegativeQuestion(Question question) =>
      isNegativePrompt(question.prompt);

  static bool isNegativePrompt(String prompt) {
    final p = prompt.replaceAll(RegExp(r'\s+'), '');
    if (p.isEmpty) return false;
    for (final phrase in _negativePhrases) {
      if (p.contains(phrase)) return true;
    }
    return _negativeTail.hasMatch(p);
  }

  /// 判定作答结果。
  ///
  /// 多选题规则：所选全部正确且完整 → [AnswerOutcome.correct]；
  /// 所选均正确但漏选 → [AnswerOutcome.partial]；含错误选项或未选 → [AnswerOutcome.wrong]。
  static AnswerOutcome evaluate({
    required Question question,
    int? selectedIndex,
    Set<int> selectedIndices = const <int>{},
    bool? selectedBool,
    String fillBlankText = '',
  }) {
    switch (question.type) {
      case QuestionType.singleChoice:
        return selectedIndex == question.answerIndex
            ? AnswerOutcome.correct
            : AnswerOutcome.wrong;

      case QuestionType.multipleChoice:
        final correct = question.answerIndices.toSet();
        if (selectedIndices.isEmpty) return AnswerOutcome.wrong;
        // 错选/多选：只要出现非正确项即不得分
        if (selectedIndices.any((i) => !correct.contains(i))) {
          return AnswerOutcome.wrong;
        }
        if (selectedIndices.length == correct.length) {
          return AnswerOutcome.correct;
        }
        // 所选全部正确但漏选 → 部分得分
        return AnswerOutcome.partial;

      case QuestionType.trueFalse:
        return selectedBool == question.isCorrect
            ? AnswerOutcome.correct
            : AnswerOutcome.wrong;

      case QuestionType.fillBlank:
        final input = fillBlankText.trim();
        if (input.isEmpty) return AnswerOutcome.wrong;
        final normalizedInput = _normalize(input);
        final ok = question.acceptableAnswers
            .any((answer) => normalizedInput == _normalize(answer));
        return ok ? AnswerOutcome.correct : AnswerOutcome.wrong;
    }
  }

  static String _normalize(String answer) =>
      answer.toLowerCase().replaceAll(RegExp(r'[\s\p{Punct}]'), '');

  /// "应选答案"提示语。
  ///
  /// 否定题用"本题要求选出错误项，应选："，避免"正确答案是：「某个错误说法」"的歧义。
  static String answerLeadIn({required bool negative}) =>
      negative ? '本题要求选出错误项，应选：' : '正确答案是：';

  /// 结果标题（UI 与播报共用）。
  static String outcomeLabel(AnswerOutcome outcome) {
    switch (outcome) {
      case AnswerOutcome.correct:
        return '回答正确';
      case AnswerOutcome.partial:
        return '少选（部分正确，有分）';
      case AnswerOutcome.wrong:
        return '回答错误';
    }
  }
}
