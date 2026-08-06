import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/services/knowledge_service.dart';
import 'package:android_app/models/question.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('三个科目均能解析出考点小节', () async {
    for (final s in QuestionSubject.values) {
      final all = await KnowledgeService.getSections(s);
      expect(all, isNotEmpty, reason: '${s.name} 不应为空');
    }
  });

  test('管理科目 第1章 应匹配到小节', () async {
    final sections = await KnowledgeService.getSectionsBySubsection(
      subject: QuestionSubject.management,
      chapterNumber: '1',
    );
    expect(sections, isNotEmpty);
  });

  test('管理科目 小节 1.1 精确匹配', () async {
    final sections = await KnowledgeService.getSectionsBySubsection(
      subject: QuestionSubject.management,
      chapterNumber: '1',
      subsectionNumber: '1.1',
    );
    expect(sections, isNotEmpty);
  });

  test('市政科目 第18章 应匹配到小节', () async {
    final sections = await KnowledgeService.getSectionsBySubsection(
      subject: QuestionSubject.practice,
      chapterNumber: '18',
    );
    expect(sections, isNotEmpty);
  });
}
