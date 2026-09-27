import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/models/question_stat.dart';

void main() {
  test('累计作答次数与正确率', () {
    var s = const QuestionStat()
        .record(correct: true)
        .record(correct: false, wrongOptions: [1])
        .record(correct: true);
    expect(s.attempts, 3);
    expect(s.correctCount, 2);
    expect(s.accuracy, closeTo(2 / 3, 1e-9));
    expect(s.neverCorrect, isFalse);
  });

  test('错选分布与"最易错选"', () {
    var s = const QuestionStat()
        .record(correct: false, wrongOptions: [1])
        .record(correct: false, wrongOptions: [1])
        .record(correct: false, wrongOptions: [3]);
    expect(s.wrongCountOf(1), 2);
    expect(s.wrongCountOf(3), 1);
    expect(s.wrongCountOf(0), 0);
    expect(s.mostWrongOption, 1);
    expect(s.mostWrongCount, 2);
  });

  test('答对时不记录错选', () {
    final s = const QuestionStat().record(correct: true, wrongOptions: [2]);
    expect(s.wrongOptionCounts, isEmpty);
    expect(s.mostWrongOption, isNull);
  });

  test('从未答对标记（用于提醒）', () {
    final s = const QuestionStat()
        .record(correct: false, wrongOptions: [0])
        .record(correct: false, wrongOptions: [2]);
    expect(s.neverCorrect, isTrue);
    expect(s.accuracy, 0);
  });

  test('JSON 往返保持字段', () {
    final s = const QuestionStat()
        .record(correct: true)
        .record(correct: false, wrongOptions: [3]);
    final back = QuestionStat.fromJson(s.toJson());
    expect(back.attempts, s.attempts);
    expect(back.correctCount, s.correctCount);
    expect(back.wrongCountOf(3), 1);
    expect(back.mostWrongOption, 3);
  });

  test('空统计的安全默认值', () {
    const s = QuestionStat();
    expect(s.attempts, 0);
    expect(s.accuracy, 0);
    expect(s.mostWrongOption, isNull);
    expect(s.neverCorrect, isFalse);
  });
}
