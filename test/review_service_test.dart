import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/models/review_item.dart';
import 'package:android_app/services/review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewService.nextReviewTime（艾宾浩斯间隔）', () {
    final base = DateTime(2026, 1, 1, 8);

    test('各阶段对应 1/2/4/7/15/30 天', () {
      expect(ReviewService.intervals, [1, 2, 4, 7, 15, 30]);
      expect(ReviewService.nextReviewTime(0, base),
          base.add(const Duration(days: 1)));
      expect(ReviewService.nextReviewTime(1, base),
          base.add(const Duration(days: 2)));
      expect(ReviewService.nextReviewTime(2, base),
          base.add(const Duration(days: 4)));
      expect(ReviewService.nextReviewTime(5, base),
          base.add(const Duration(days: 30)));
    });

    test('阶段越界被钳制到有效范围', () {
      expect(ReviewService.nextReviewTime(99, base),
          base.add(const Duration(days: 30)));
      expect(ReviewService.nextReviewTime(-3, base),
          base.add(const Duration(days: 1)));
    });
  });

  group('ReviewService.advanceStage（阶段推进）', () {
    test('答对推进，答错回到第一阶段', () {
      expect(ReviewService.advanceStage(0, isCorrect: true), 1);
      expect(ReviewService.advanceStage(2, isCorrect: true), 3);
      expect(ReviewService.advanceStage(2, isCorrect: false), 0);
      expect(ReviewService.advanceStage(0, isCorrect: false), 0);
    });

    test('到达最大阶段后不再前进', () {
      expect(ReviewService.advanceStage(5, isCorrect: true), 5);
    });
  });

  group('ReviewService.dueItems / summarize', () {
    final now = DateTime(2026, 6, 1, 12);

    ReviewItem mk(String k, DateTime next) => ReviewItem(
          questionKey: k,
          firstLearnedAt: now.subtract(const Duration(days: 1)),
          nextReviewAt: next,
        );

    test('dueItems 仅取已到期，并按到期时间升序', () {
      final items = {
        'a': mk('a', now.subtract(const Duration(days: 1))),
        'b': mk('b', now.add(const Duration(days: 2))),
        'c': mk('c', now.subtract(const Duration(days: 3))),
      };
      final due = ReviewService.dueItems(items, now: now)
          .map((e) => e.questionKey)
          .toList();
      expect(due, ['c', 'a']);
    });

    test('summarize 统计 到期/3天内/7天内/总数', () {
      final items = {
        'a': mk('a', now.subtract(const Duration(days: 1))),
        'b': mk('b', now.add(const Duration(days: 2))),
        'c': mk('c', now.add(const Duration(days: 6))),
        'd': mk('d', now.add(const Duration(days: 40))),
      };
      final s = ReviewService.summarize(items, now: now);
      expect(s.total, 4);
      expect(s.due, 1);
      expect(s.within3Days, 1);
      expect(s.within7Days, 1);
    });

    test('无到期题目时 hasDue 为 false', () {
      final items = {'a': mk('a', now.add(const Duration(days: 5)))};
      expect(ReviewService.summarize(items, now: now).hasDue, isFalse);
    });
  });

  group('ReviewItem 序列化 / isDue', () {
    test('json 往返保持字段', () {
      final it = ReviewItem(
        questionKey: 'law|x',
        firstLearnedAt: DateTime(2026, 1, 1),
        nextReviewAt: DateTime(2026, 1, 2),
        stage: 2,
        reviewCount: 3,
        wrongCount: 1,
        lastReviewedAt: DateTime(2026, 1, 1, 10),
      );
      final back = ReviewItem.fromJson(it.toJson());
      expect(back.questionKey, 'law|x');
      expect(back.stage, 2);
      expect(back.reviewCount, 3);
      expect(back.wrongCount, 1);
      expect(back.nextReviewAt, DateTime(2026, 1, 2));
      expect(back.lastReviewedAt, DateTime(2026, 1, 1, 10));
    });

    test('isDue 判定', () {
      final now = DateTime(2026, 6, 1, 12);
      final due = ReviewItem(
        questionKey: 'k',
        firstLearnedAt: now,
        nextReviewAt: now.subtract(const Duration(minutes: 1)),
      );
      final notDue = ReviewItem(
        questionKey: 'k2',
        firstLearnedAt: now,
        nextReviewAt: now.add(const Duration(days: 1)),
      );
      expect(due.isDue(now), isTrue);
      expect(notDue.isDue(now), isFalse);
    });
  });
}
