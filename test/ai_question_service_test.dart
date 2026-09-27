import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/models/question.dart';
import 'package:android_app/services/ai_question_service.dart';

AiQuestionContext _ctx() => const AiQuestionContext(
      subject: QuestionSubject.law,
      topic: '物权制度',
      chapterNumber: '1',
      subsection: '1.2',
      sectionTitle: '建设工程物权制度',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiQuestionService.parseGenerated', () {
    test('解析标准 JSON（单选/多选/判断）', () {
      const raw = '''
{"questions":[
 {"type":"singleChoice","prompt":"题干一","options":["A","B","C","D"],"answerIndex":2,
  "explanation":"解析一","knowledgePoints":["担保物权"]},
 {"type":"multipleChoice","prompt":"题干二","options":["A","B","C","D"],
  "answerIndices":[1,3],"explanation":"解析二","knowledgePoints":["用益物权"]},
 {"type":"trueFalse","prompt":"题干三","isCorrect":false,"explanation":"解析三",
  "knowledgePoints":["物权"]}
]}''';
      final list = AiQuestionService.parseGenerated(
        raw,
        context: _ctx(),
        types: {
          QuestionType.singleChoice,
          QuestionType.multipleChoice,
          QuestionType.trueFalse,
        },
      );
      expect(list.length, 3);

      expect(list[0].type, QuestionType.singleChoice);
      expect(list[0].answerIndex, 2);
      expect(list[0].knowledgePoints, ['担保物权']);
      // 自动带入章节/小节上下文
      expect(list[0].chapter, '1');
      expect(list[0].subsection, '1.2');
      expect(list[0].subject, QuestionSubject.law);

      expect(list[1].type, QuestionType.multipleChoice);
      expect(list[1].answerIndices, [1, 3]);

      expect(list[2].type, QuestionType.trueFalse);
      expect(list[2].isCorrect, isFalse);
    });

    test('容忍 Markdown 代码块与前后多余文字', () {
      const raw = '''
好的，以下是题目：
```json
{"questions":[{"type":"singleChoice","prompt":"P","options":["a","b"],
"answerIndex":1,"explanation":"E","knowledgePoints":[]}]}
```
希望有帮助！''';
      final list = AiQuestionService.parseGenerated(
        raw,
        context: _ctx(),
        types: {QuestionType.singleChoice},
      );
      expect(list.length, 1);
      expect(list.first.prompt, 'P');
      expect(list.first.answerIndex, 1);
    });

    test('丢弃非法题目（缺选项/答案越界/题干为空）', () {
      const raw = '''
{"questions":[
 {"type":"singleChoice","prompt":"","options":["A","B"],"answerIndex":0},
 {"type":"singleChoice","prompt":"只有一项","options":["A"],"answerIndex":0},
 {"type":"singleChoice","prompt":"越界","options":["A","B"],"answerIndex":5},
 {"type":"singleChoice","prompt":"正常","options":["A","B"],"answerIndex":1,"explanation":"e"}
]}''';
      final list = AiQuestionService.parseGenerated(
        raw,
        context: _ctx(),
        types: {QuestionType.singleChoice},
      );
      expect(list.length, 1);
      expect(list.first.prompt, '正常');
    });

    test('多选题答案少于 2 个视为非法', () {
      const raw = '''
{"questions":[{"type":"multipleChoice","prompt":"P","options":["A","B","C"],
"answerIndices":[1]}]}''';
      final list = AiQuestionService.parseGenerated(
        raw,
        context: _ctx(),
        types: {QuestionType.multipleChoice},
      );
      expect(list, isEmpty);
    });

    test('返回题型不在请求集合时按请求题型降级', () {
      const raw = '''
{"questions":[{"type":"multipleChoice","prompt":"P","options":["A","B"],
"answerIndex":0,"explanation":"e"}]}''';
      final list = AiQuestionService.parseGenerated(
        raw,
        context: _ctx(),
        types: {QuestionType.singleChoice},
      );
      expect(list.length, 1);
      expect(list.first.type, QuestionType.singleChoice);
    });

    test('无 JSON 时返回空列表', () {
      expect(
        AiQuestionService.parseGenerated('抱歉，我无法完成。',
            context: _ctx(), types: {QuestionType.singleChoice}),
        isEmpty,
      );
    });

    test('判断题字符串答案兼容', () {
      const raw = '''
{"questions":[{"type":"trueFalse","prompt":"P","isCorrect":"正确","explanation":"e"}]}''';
      final list = AiQuestionService.parseGenerated(
        raw,
        context: _ctx(),
        types: {QuestionType.trueFalse},
      );
      expect(list.single.isCorrect, isTrue);
    });
  });

  group('AiQuestionContext.displayName', () {
    test('拼接科目/章节/主题', () {
      expect(_ctx().displayName, contains('法规'));
      expect(_ctx().displayName, contains('第1章'));
      expect(_ctx().displayName, contains('物权制度'));
    });
  });
}
