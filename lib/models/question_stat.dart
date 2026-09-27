/// 单题作答统计（用于展示"做过多少次 / 正确率 / 往期最易错选"）
class QuestionStat {
  const QuestionStat({
    this.attempts = 0,
    this.correctCount = 0,
    this.wrongOptionCounts = const {},
    this.lastAnsweredAt,
  });

  /// 累计作答次数
  final int attempts;

  /// 答对次数（少选按"有分"计入，与答题判定口径一致）
  final int correctCount;

  /// 错选统计：选项下标 → 被错选次数
  final Map<int, int> wrongOptionCounts;

  final DateTime? lastAnsweredAt;

  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;

  /// 是否为"从不未答对"（用于"老是错"的提示）
  bool get neverCorrect => attempts > 0 && correctCount == 0;

  /// 最容易被错选的选项下标（无则 null）
  int? get mostWrongOption {
    if (wrongOptionCounts.isEmpty) return null;
    var bestIdx = -1;
    var bestCount = -1;
    wrongOptionCounts.forEach((idx, count) {
      if (count > bestCount) {
        bestCount = count;
        bestIdx = idx;
      }
    });
    return bestIdx < 0 ? null : bestIdx;
  }

  int get mostWrongCount =>
      mostWrongOption == null ? 0 : (wrongOptionCounts[mostWrongOption!] ?? 0);

  /// 某选项被错选的次数
  int wrongCountOf(int optionIndex) => wrongOptionCounts[optionIndex] ?? 0;

  QuestionStat record({required bool correct, List<int> wrongOptions = const []}) {
    final next = Map<int, int>.from(wrongOptionCounts);
    if (!correct) {
      for (final o in wrongOptions) {
        next[o] = (next[o] ?? 0) + 1;
      }
    }
    return QuestionStat(
      attempts: attempts + 1,
      correctCount: correctCount + (correct ? 1 : 0),
      wrongOptionCounts: next,
      lastAnsweredAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'a': attempts,
        'c': correctCount,
        'w': wrongOptionCounts.map((k, v) => MapEntry(k.toString(), v)),
        't': lastAnsweredAt?.millisecondsSinceEpoch,
      };

  factory QuestionStat.fromJson(Map<String, dynamic> json) {
    final rawWrong = json['w'] as Map<String, dynamic>? ?? const {};
    return QuestionStat(
      attempts: (json['a'] as num?)?.toInt() ?? 0,
      correctCount: (json['c'] as num?)?.toInt() ?? 0,
      wrongOptionCounts: rawWrong.map(
        (k, v) => MapEntry(int.tryParse(k) ?? -1, (v as num).toInt()),
      )..remove(-1),
      lastAnsweredAt: (json['t'] as num?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((json['t'] as num).toInt()),
    );
  }
}
