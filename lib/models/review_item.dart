/// 艾宾浩斯遗忘曲线复习条目
///
/// 针对每道"做过的题"（含错题）维护一个间隔重复计划：按 [intervals] 天
/// 安排下一次复习时间。答对则推进到下一阶段（间隔变长，符合遗忘曲线），
/// 答错则回到第一阶段（次日重来），从而实现"在即将遗忘时复习"的效果。
class ReviewItem {
  ReviewItem({
    required this.questionKey,
    required this.firstLearnedAt,
    required this.nextReviewAt,
    this.stage = 0,
    this.reviewCount = 0,
    this.wrongCount = 0,
    this.lastReviewedAt,
  });

  /// 题目唯一键（对应 [Question.uniqueKey]）
  final String questionKey;

  /// 首次学习（答过）的时间
  final DateTime firstLearnedAt;

  /// 下次应复习的时间
  DateTime nextReviewAt;

  /// 当前阶段（0-based，对应 [intervals] 下标，越大间隔越长）
  int stage;

  /// 累计复习次数
  int reviewCount;

  /// 累计答错次数
  int wrongCount;

  /// 上次复习时间
  DateTime? lastReviewedAt;

  /// 艾宾浩斯复习间隔（天）：1、2、4、7、15、30
  static const List<int> intervals = <int>[1, 2, 4, 7, 15, 30];

  /// 该条目是否已到期需要复习
  bool isDue([DateTime? now]) => !nextReviewAt.isAfter(now ?? DateTime.now());

  /// 距离到期的天数（负数表示已逾期）。用于 UI 展示"逾期 N 天 / N 天后"。
  int daysUntilDue([DateTime? now]) {
    final t = now ?? DateTime.now();
    return nextReviewAt.difference(t).inDays;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'questionKey': questionKey,
      'firstLearnedAt': firstLearnedAt.toIso8601String(),
      'nextReviewAt': nextReviewAt.toIso8601String(),
      'stage': stage,
      'reviewCount': reviewCount,
      'wrongCount': wrongCount,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    };
  }

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ReviewItem(
      questionKey: json['questionKey'] as String? ?? '',
      firstLearnedAt: _parseDate(json['firstLearnedAt'], now),
      nextReviewAt: _parseDate(json['nextReviewAt'], now),
      stage: (json['stage'] as num?)?.toInt() ?? 0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 0,
      lastReviewedAt: json['lastReviewedAt'] == null
          ? null
          : _parseDate(json['lastReviewedAt'], now),
    );
  }

  static DateTime _parseDate(Object? value, DateTime fallback) {
    if (value is String) {
      return DateTime.tryParse(value) ?? fallback;
    }
    return fallback;
  }
}
