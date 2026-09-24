import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/services/knowledge_service.dart';

void main() {
  group('splitSentences（逐句朗读切分）', () {
    test('按句末标点拆分并保留标点', () {
      expect(splitSentences('第一句。第二句！第三句？'),
          ['第一句。', '第二句！', '第三句？']);
    });

    test('无句末标点时整段返回', () {
      expect(splitSentences('没有标点的一段文字'), ['没有标点的一段文字']);
    });

    test('空白文本返回空列表', () {
      expect(splitSentences('   '), isEmpty);
    });

    test('支持英文叹号/问号与省略号句末', () {
      expect(splitSentences('Hello. World! 还有…完'),
          ['Hello. World!', '还有…', '完']);
    });

    test('不按半角句点拆分（避免拆开 1.5 米、题号 10.1 等）', () {
      expect(splitSentences('第1.5条规定'), ['第1.5条规定']);
      expect(splitSentences('10.1 施工管理'), ['10.1 施工管理']);
    });
  });

  group('KnowledgeSection.speechUnits（朗读单元 + 段落下标）', () {
    const section = KnowledgeSection(
      number: '1.1',
      title: '标题',
      paragraphs: [
        KnowledgeParagraph(text: '第一段。第二句。'),
        KnowledgeParagraph(text: '', imagePath: 'images/a.jpg'),
        KnowledgeParagraph(text: '第二段内容'),
      ],
    );

    test('标题 + 非空非图片段落按句拆分，下标对应原段落', () {
      final units = section.speechUnits();
      expect(units.length, 4); // 标题1 + 第一段2句 + 第二段1句
      expect(units[0].paragraphIndex, -1); // 标题不参与正文高亮
      expect(units[0].text, '标题');
      expect(units[1].paragraphIndex, 0);
      expect(units[1].text, '第一段。');
      expect(units[2].paragraphIndex, 0);
      expect(units[2].text, '第二句。');
      expect(units[3].paragraphIndex, 2); // 跳过图片段落
      expect(units[3].text, '第二段内容');
    });

    test('空标题/全图片段落时仍可用', () {
      const empty = KnowledgeSection(
        number: '1.2',
        title: '',
        paragraphs: [
          KnowledgeParagraph(text: '', imagePath: 'images/b.jpg'),
        ],
      );
      expect(empty.speechUnits(), isEmpty);
    });
  });
}
