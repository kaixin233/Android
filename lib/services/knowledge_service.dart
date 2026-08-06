import '../models/question.dart';

/// 考点知识点段落
class KnowledgeParagraph {
  final String text;
  final bool isHeading;
  final bool isSubheading;
  final bool isBold;

  const KnowledgeParagraph({
    required this.text,
    this.isHeading = false,
    this.isSubheading = false,
    this.isBold = false,
  });
}

/// 章节考点知识
class KnowledgeSection {
  final String number;
  final String title;
  final List<KnowledgeParagraph> paragraphs;

  const KnowledgeSection({
    required this.number,
    required this.title,
    required this.paragraphs,
  });
}

/// 考点知识服务。
/// 旧版 HTML 数据已移除，后续将改为从更适合播报的文本格式加载。
class KnowledgeService {
  KnowledgeService._();

  static final Map<String, List<KnowledgeSection>> _cache = {};

  /// 获取指定科目的所有章节考点
  static Future<List<KnowledgeSection>> getSections(QuestionSubject subject) async {
    if (_cache.containsKey(subject.name)) return _cache[subject.name]!;

    final sections = <KnowledgeSection>[];
    _cache[subject.name] = sections;
    return sections;
  }

  /// 获取指定科目指定小节的考点内容
  static Future<List<KnowledgeSection>> getSectionsBySubsection({
    required QuestionSubject subject,
    required String chapterNumber,
    String? subsectionNumber,
  }) async {
    final all = await getSections(subject);

    if (subsectionNumber != null) {
      return all.where((s) => s.number == subsectionNumber).toList();
    }

    return all.where((s) => s.number.startsWith('$chapterNumber.')).toList();
  }
}
