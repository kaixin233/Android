import 'package:flutter/services.dart';

import '../models/question.dart';

/// 考点知识点段落
class KnowledgeParagraph {
  final String text;
  final bool isHeading;
  final bool isSubheading;
  final bool isBold;

  /// 本地图片资源路径（相对于 assets/knowledge/，例如 "images/xxx.jpg"）。
  /// 仅当该段落是一张图片时非空；图片段落的 [text] 为空，不参与语音播报。
  final String? imagePath;

  const KnowledgeParagraph({
    required this.text,
    this.isHeading = false,
    this.isSubheading = false,
    this.isBold = false,
    this.imagePath,
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

  /// 将考点内容转换为适合语音播报的纯文本
  String toSpeechText() {
    final buffer = StringBuffer();
    buffer.write(title);
    buffer.write('。');
    for (final p in paragraphs) {
      // 图片段落无文本，跳过
      if (p.imagePath != null) continue;
      if (p.text.trim().isEmpty) continue;
      buffer.write(p.text);
      // 段落之间加句号停顿
      if (!RegExp(r'[。.！!？?]$').hasMatch(p.text)) {
        buffer.write('。');
      }
    }
    return buffer.toString();
  }

  /// 小节纯文本（跳过图片与空段落，按行拼接），用作 AI 提问上下文
  String toPlainText() {
    return paragraphs
        .where((p) => p.imagePath == null)
        .map((p) => p.text)
        .where((t) => t.trim().isNotEmpty)
        .join('\n');
  }
}

/// 考点知识服务 - 从 Markdown 文件中解析章节考点内容
///
/// Markdown 文件结构（由 二级建造师题库/*.html 转换并整理得到）：
///   # 科目名称
///   ## 目录
///   - 第1章 ...          （目录列表，解析时跳过）
///   ## 第X章 标题
///   ### X.X 小节标题
///   #### X.X.X 子标题
///   **1. 加粗要点**
///   正文段落...
///   ![图注](images/xxx.jpg)
///   *图注说明*
class KnowledgeService {
  KnowledgeService._();

  static final Map<String, List<KnowledgeSection>> _cache = {};
  static final Map<String, String> _rawMdCache = {};

  /// 获取指定科目的所有章节考点
  static Future<List<KnowledgeSection>> getSections(QuestionSubject subject) async {
    if (_cache.containsKey(subject.name)) return _cache[subject.name]!;

    final md = await _loadMarkdown(subject);
    final sections = _parseMarkdown(md);
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
      // 精确匹配小节号（如 "10.1"）
      return all.where((s) => s.number == subsectionNumber).toList();
    }

    // 匹配整章：小节号以 chapterNumber + "." 开头
    return all
        .where((s) => s.number.startsWith('$chapterNumber.'))
        .toList();
  }

  /// 加载 Markdown 文件
  static Future<String> _loadMarkdown(QuestionSubject subject) async {
    if (_rawMdCache.containsKey(subject.name)) {
      return _rawMdCache[subject.name]!;
    }
    final md = await rootBundle.loadString('assets/knowledge/${subject.name}.md');
    _rawMdCache[subject.name] = md;
    return md;
  }

  /// 解析 Markdown，提取所有小节（### 标题）
  static List<KnowledgeSection> _parseMarkdown(String md) {
    final sections = <KnowledgeSection>[];
    KnowledgeSection? current;
    var inToc = false;

    final imgRegex = RegExp(r'^\!\[(.*?)\]\(([^)]*)\)');

    for (final raw in md.split('\n')) {
      final trimmed = raw.trim();

      // 章节标题（## 第X章）与目录标题（## 目录）：标记为结构，不生成段落
      if (trimmed.startsWith('## ')) {
        if (trimmed == '## 目录') {
          inToc = true;
        } else {
          inToc = false;
        }
        continue;
      }

      // 顶层科目标题（# 科目名称）
      if (trimmed.startsWith('# ')) continue;

      // 小节标题（### X.X 小节标题）：新起一个 KnowledgeSection
      if (trimmed.startsWith('### ')) {
        inToc = false;
        final titleText = trimmed.substring(4).trim();
        final numberMatch = RegExp(r'^([\d.]+)').firstMatch(titleText);
        final number = numberMatch?.group(1) ?? '';
        current = KnowledgeSection(
          number: number,
          title: titleText,
          paragraphs: <KnowledgeParagraph>[],
        );
        sections.add(current);
        continue;
      }

      // 目录列表项跳过
      if (inToc) continue;
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('- ')) continue;
      if (current == null) continue;

      // 图片
      final imgMatch = imgRegex.firstMatch(trimmed);
      if (imgMatch != null) {
        final path = imgMatch.group(2)!.trim();
        current.paragraphs.add(KnowledgeParagraph(
          text: '',
          imagePath: path,
        ));
        continue;
      }

      // 子标题（#### X.X.X）
      if (trimmed.startsWith('#### ')) {
        current.paragraphs.add(KnowledgeParagraph(
          text: trimmed.substring(5).trim(),
          isSubheading: true,
        ));
        continue;
      }

      // 加粗要点（整行 **...**）
      if (trimmed.length >= 4 &&
          trimmed.startsWith('**') &&
          trimmed.endsWith('**')) {
        current.paragraphs.add(KnowledgeParagraph(
          text: trimmed.substring(2, trimmed.length - 2).trim(),
          isBold: true,
        ));
        continue;
      }

      // 斜体图注（整行 *...*，非加粗）
      if (trimmed.length >= 2 &&
          trimmed.startsWith('*') &&
          trimmed.endsWith('*') &&
          !trimmed.startsWith('**')) {
        current.paragraphs.add(KnowledgeParagraph(
          text: trimmed.substring(1, trimmed.length - 1).trim(),
        ));
        continue;
      }

      // 普通段落
      current.paragraphs.add(KnowledgeParagraph(text: trimmed));
    }

    return sections;
  }

  /// 清除缓存
  static void clearCache() {
    _cache.clear();
    _rawMdCache.clear();
  }
}
