/// 单题作答结果
///
/// 引入 [partial] 以支持多选题"少选有分"：所选选项均正确但漏选部分正确答案时，
/// 既不是"全对"也不是"回答错误"，而是部分正确（有分）。
enum AnswerOutcome {
  /// 完全正确
  correct,

  /// 部分正确（多选题少选，有分）
  partial,

  /// 错误（含错选/多选/未作答）
  wrong,
}

extension AnswerOutcomeX on AnswerOutcome {
  String get name {
    switch (this) {
      case AnswerOutcome.correct:
        return 'correct';
      case AnswerOutcome.partial:
        return 'partial';
      case AnswerOutcome.wrong:
        return 'wrong';
    }
  }

  /// 是否计入"答对"（部分正确有分，视为答对，不计入错题）
  bool get countsAsCorrect => this != AnswerOutcome.wrong;

  bool get isFullCorrect => this == AnswerOutcome.correct;
  bool get isWrong => this == AnswerOutcome.wrong;

  String get label {
    switch (this) {
      case AnswerOutcome.correct:
        return '回答正确';
      case AnswerOutcome.partial:
        return '少选（部分正确，有分）';
      case AnswerOutcome.wrong:
        return '回答错误';
    }
  }

  static AnswerOutcome fromName(String name) {
    switch (name) {
      case 'correct':
        return AnswerOutcome.correct;
      case 'partial':
        return AnswerOutcome.partial;
      default:
        return AnswerOutcome.wrong;
    }
  }
}
