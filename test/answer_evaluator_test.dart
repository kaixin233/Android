import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/models/answer_outcome.dart';
import 'package:android_app/models/history_item.dart';
import 'package:android_app/models/practice_progress.dart';
import 'package:android_app/models/question.dart';
import 'package:android_app/services/answer_evaluator.dart';

Question single({
  required String prompt,
  List<String> options = const ['A', 'B', 'C', 'D'],
  int answerIndex = 0,
}) =>
    Question(
      title: prompt,
      prompt: prompt,
      type: QuestionType.singleChoice,
      options: options,
      answerIndex: answerIndex,
    );

Question multi({
  required String prompt,
  List<String> options = const ['A', 'B', 'C', 'D'],
  required List<int> answerIndices,
}) =>
    Question(
      title: prompt,
      prompt: prompt,
      type: QuestionType.multipleChoice,
      options: options,
      answerIndices: answerIndices,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnswerEvaluator.isNegativePrompt（否定题识别）', () {
    test('识别"错误的是/不正确的是/不属于/不包括"', () {
      expect(AnswerEvaluator.isNegativePrompt('关于法的效力层级，下列表述错误的是（）。'), isTrue);
      expect(AnswerEvaluator.isNegativePrompt('关于知识产权的说法，不正确的是（）。'), isTrue);
      expect(AnswerEvaluator.isNegativePrompt('下列不属于担保物权的是（）。'), isTrue);
      expect(AnswerEvaluator.isNegativePrompt('国有建设用地使用者依法对土地享有的权利不包括（）。'),
          isTrue);
    });

    test('不误判场景描述类否定词', () {
      // "不能确定如何适用时" 是正向题
      expect(
          AnswerEvaluator.isNegativePrompt('部门规章与地方性法规对同一事项的规定不一致，不能确定如何适用时，（）。'),
          isFalse);
      expect(
          AnswerEvaluator.isNegativePrompt(
              '某施工现场安全设施不符合国家规定，造成施工单位2名工人死亡。关于犯罪主体及其罪名的说法，正确的是（）。'),
          isFalse);
      expect(
          AnswerEvaluator.isNegativePrompt(
              '混凝土预制构件出厂时的混凝土强度不宜低于设计混凝土强度等级值的（）。'),
          isFalse);
    });

    test('尾部模式：不是/不应/无需 + 的是', () {
      expect(AnswerEvaluator.isNegativePrompt('下列管辖不是《民事诉讼法》规定的民事案件管辖的是（）。'),
          isTrue);
      expect(AnswerEvaluator.isNegativePrompt('下列不应视为投标人相互串通投标的情形的是（）'), isTrue);
      expect(AnswerEvaluator.isNegativePrompt('根据《仲裁法》，仲裁员具有下列情形，无需回避的是（）。'),
          isTrue);
      // 场景描述（含逗号）不应误判
      expect(AnswerEvaluator.isNegativePrompt('但项目部不是法人，根本原因是（）。'), isFalse);
    });
  });

  group('AnswerEvaluator.evaluate（多选题少选=部分正确）', () {
    final q = multi(prompt: '下列关于法律法规的说法，错误的有（）。',
        answerIndices: [2, 3]);

    test('全对', () {
      expect(AnswerEvaluator.evaluate(question: q, selectedIndices: {2, 3}),
          AnswerOutcome.correct);
    });

    test('少选（所选均正确但漏选）→ partial，不再判为错误', () {
      expect(AnswerEvaluator.evaluate(question: q, selectedIndices: {2}),
          AnswerOutcome.partial);
      expect(AnswerEvaluator.evaluate(question: q, selectedIndices: {3}),
          AnswerOutcome.partial);
      // partial 视为"有分"，不计入错题
      expect(AnswerOutcome.partial.countsAsCorrect, isTrue);
      expect(AnswerOutcome.partial.isWrong, isFalse);
    });

    test('错选/多选 → wrong', () {
      expect(AnswerEvaluator.evaluate(question: q, selectedIndices: {2, 3, 0}),
          AnswerOutcome.wrong);
      expect(AnswerEvaluator.evaluate(question: q, selectedIndices: {0}),
          AnswerOutcome.wrong);
    });

    test('未作答 → wrong', () {
      expect(AnswerEvaluator.evaluate(question: q, selectedIndices: const {}),
          AnswerOutcome.wrong);
    });

    test('单选题：对/错', () {
      final s = single(prompt: '应该（）。', answerIndex: 1);
      expect(AnswerEvaluator.evaluate(question: s, selectedIndex: 1),
          AnswerOutcome.correct);
      expect(AnswerEvaluator.evaluate(question: s, selectedIndex: 0),
          AnswerOutcome.wrong);
    });

    test('判断题与填空题', () {
      final t = Question(
          title: 't', prompt: 't', type: QuestionType.trueFalse, isCorrect: true);
      expect(AnswerEvaluator.evaluate(question: t, selectedBool: true),
          AnswerOutcome.correct);
      expect(AnswerEvaluator.evaluate(question: t, selectedBool: false),
          AnswerOutcome.wrong);

      final f = Question(
        title: 'f',
        prompt: 'f',
        type: QuestionType.fillBlank,
        acceptableAnswers: const ['施工组织设计'],
      );
      expect(
          AnswerEvaluator.evaluate(question: f, fillBlankText: '施工组织设计'),
          AnswerOutcome.correct);
      expect(AnswerEvaluator.evaluate(question: f, fillBlankText: '随便'),
          AnswerOutcome.wrong);
      expect(AnswerEvaluator.evaluate(question: f, fillBlankText: '  '),
          AnswerOutcome.wrong);
    });
  });

  group('答案提示语（否定题不提"正确答案"）', () {
    test('否定题 → "本题要求选出错误项，应选："', () {
      expect(AnswerEvaluator.answerLeadIn(negative: true), '本题要求选出错误项，应选：');
    });
    test('普通题 → "正确答案是："', () {
      expect(AnswerEvaluator.answerLeadIn(negative: false), '正确答案是：');
    });
    test('结果文案', () {
      expect(AnswerEvaluator.outcomeLabel(AnswerOutcome.correct), '回答正确');
      expect(AnswerEvaluator.outcomeLabel(AnswerOutcome.partial), contains('少选'));
      expect(AnswerEvaluator.outcomeLabel(AnswerOutcome.wrong), '回答错误');
    });
  });

  group('PracticeProgress 序列化', () {
    test('json 往返保持字段', () {
      final p = PracticeProgress(
        title: '法规 练习',
        modeName: 'practice',
        subjectName: 'law',
        chapterNumber: '1',
        subsection: '1.1',
        questionKeys: const ['k1', 'k2', 'k3'],
        answers: {
          'k1': const SavedAnswer(
              outcome: AnswerOutcome.correct, selectedIndex: 1),
          'k2': const SavedAnswer(
              outcome: AnswerOutcome.partial, selectedIndices: [2]),
        },
        currentIndex: 2,
        correctCount: 2,
        savedAt: DateTime(2026, 9, 27, 8, 0),
      );
      final back = PracticeProgress.fromJson(p.toJson());
      expect(back.title, '法规 练习');
      expect(back.mode, PracticeMode.practice);
      expect(back.subjectName, 'law');
      expect(back.questionKeys, ['k1', 'k2', 'k3']);
      expect(back.answeredCount, 2);
      expect(back.total, 3);
      expect(back.isFinished, isFalse);
      expect(back.progressText, '2/3');
      expect(back.answers['k1']!.outcome, AnswerOutcome.correct);
      expect(back.answers['k2']!.outcome, AnswerOutcome.partial);
      expect(back.answers['k2']!.selectedIndices, [2]);
      expect(back.currentIndex, 2);
      expect(back.correctCount, 2);
    });

    test('全部作答后 isFinished 为 true', () {
      final p = PracticeProgress(
        title: 't',
        modeName: 'practice',
        questionKeys: const ['k1'],
        answers: {'k1': const SavedAnswer(outcome: AnswerOutcome.wrong)},
        currentIndex: 0,
        correctCount: 0,
        savedAt: DateTime(2026, 1, 1),
      );
      expect(p.isFinished, isTrue);
    });
  });
}
