import '../models/review_item.dart';
import 'storage_service.dart';

/// 艾宾浩斯遗忘曲线复习服务
///
/// 负责：把「做过的题」纳入间隔重复计划、计算到期队列、推进/重置阶段。
/// 纯调度逻辑（[nextReviewTime] / [advanceStage] / [dueItems]）为静态纯函数，
/// 便于单元测试；持久化交由 [StorageService]。
class ReviewService {
  ReviewService._();

  /// 复习间隔（天），与 [ReviewItem.intervals] 一致。
  static const List<int> intervals = ReviewItem.intervals;

  /// 计算 [stage] 阶段对应的下次复习时间（从 [from] 起算）。
  static DateTime nextReviewTime(int stage, DateTime from) {
    final idx = stage.clamp(0, intervals.length - 1);
    return from.add(Duration(days: intervals[idx]));
  }

  /// 根据答题结果计算新阶段：
  /// 答对 → 阶段 +1（间隔变长）；答错 → 回到 0（次日重来）。
  static int advanceStage(int currentStage, {required bool isCorrect}) {
    if (!isCorrect) return 0;
    return (currentStage + 1).clamp(0, intervals.length - 1);
  }

  /// 记录一次答题结果并更新复习计划，返回更新后的条目。
  ///
  /// 首次出现的题（无论对错）都从阶段 0 开始，安排到 1 天后复习；
  /// 已存在的题按 [advanceStage] 推进。答错同时累加 [ReviewItem.wrongCount]。
  static Future<ReviewItem> recordAnswer(
    String questionKey, {
    required bool isCorrect,
    DateTime? now,
  }) async {
    final t = now ?? DateTime.now();
    final items = await StorageService.loadReviewItems();
    final existing = items[questionKey];

    final ReviewItem item;
    if (existing == null) {
      item = ReviewItem(
        questionKey: questionKey,
        firstLearnedAt: t,
        nextReviewAt: nextReviewTime(0, t),
        stage: 0,
        reviewCount: 0,
        wrongCount: isCorrect ? 0 : 1,
      );
    } else {
      final newStage = advanceStage(existing.stage, isCorrect: isCorrect);
      item = ReviewItem(
        questionKey: questionKey,
        firstLearnedAt: existing.firstLearnedAt,
        nextReviewAt: nextReviewTime(newStage, t),
        stage: newStage,
        reviewCount: existing.reviewCount + 1,
        wrongCount: existing.wrongCount + (isCorrect ? 0 : 1),
        lastReviewedAt: t,
      );
    }

    items[questionKey] = item;
    await StorageService.saveReviewItems(items);
    return item;
  }

  /// 取出所有已到期的条目，按到期时间升序（越早到期越靠前）。
  static List<ReviewItem> dueItems(
    Map<String, ReviewItem> items, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final list = items.values.where((e) => e.isDue(t)).toList()
      ..sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
    return list;
  }

  /// 统计概览（用于首页/复习页展示）。
  static ReviewStats summarize(
    Map<String, ReviewItem> items, {
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    var due = 0;
    var dueToday = 0;
    var within3Days = 0;
    var within7Days = 0;
    for (final e in items.values) {
      final d = e.daysUntilDue(t);
      if (d <= 0) {
        due++;
        // 到期时间与"现在"同一天视为今天到期
        if (e.nextReviewAt.difference(t).inHours < 24 &&
            e.nextReviewAt.year == t.year &&
            e.nextReviewAt.month == t.month &&
            e.nextReviewAt.day == t.day) {
          dueToday++;
        }
      } else if (d <= 3) {
        within3Days++;
      } else if (d <= 7) {
        within7Days++;
      }
    }
    return ReviewStats(
      total: items.length,
      due: due,
      dueToday: dueToday,
      within3Days: within3Days,
      within7Days: within7Days,
    );
  }
}

/// 复习概览统计
class ReviewStats {
  const ReviewStats({
    required this.total,
    required this.due,
    required this.dueToday,
    required this.within3Days,
    required this.within7Days,
  });

  /// 纳入复习计划的题目总数
  final int total;

  /// 已到期（含逾期）的题目数
  final int due;

  /// 今天到期的题目数
  final int dueToday;

  /// 未来 3 天内到期
  final int within3Days;

  /// 未来 7 天内到期
  final int within7Days;

  bool get hasDue => due > 0;
}
