import 'package:flutter/services.dart';

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

  /// 将考点内容转换为适合语音播报的纯文本
  String toSpeechText() {
    final buffer = StringBuffer();
    buffer.write(title);
    buffer.write('。');
    for (final p in paragraphs) {
      if (p.text.trim().isEmpty) continue;
      buffer.write(p.text);
      // 段落之间加句号停顿
      if (!p.text.endsWith(RegExp(r'[。.！!？?]'))) {
        buffer.write('。');
      }
    }
    return buffer.toString();
  }
}

/// 考点知识服务 - 从 HTML 文件中解析章节考点内容
///
/// HTML 文件结构：
/// <div class="chapter">
///   <div class="chapter-title">第X章 标题</div>
///   <div class="section">
///     <div class="section-title">X.X 小节标题</div>
///     <div class="section-content">...HTML内容...</div>
///   </div>
/// </div>
class KnowledgeService {
  KnowledgeService._();

  static final Map<String, List<KnowledgeSection>> _cache = {};
  static final Map<String, String> _rawHtmlCache = {};

  /// 获取指定科目的所有章节考点
  static Future<List<KnowledgeSection>> getSections(QuestionSubject subject) async {
    if (_cache.containsKey(subject.name)) return _cache[subject.name]!;

    final html = await _loadHtml(subject);
    final sections = _parseHtml(html);
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

  /// 加载 HTML 文件
  static Future<String> _loadHtml(QuestionSubject subject) async {
    if (_rawHtmlCache.containsKey(subject.name)) {
      return _rawHtmlCache[subject.name]!;
    }
    final html = await rootBundle.loadString('assets/knowledge/${subject.name}.html');
    _rawHtmlCache[subject.name] = html;
    return html;
  }

  /// 解析 HTML，提取所有 section
  static List<KnowledgeSection> _parseHtml(String html) {
    final sections = <KnowledgeSection>[];

    // 匹配 <div class="section">...</div> 块
    // section-title 和 section-content 在同一个 section div 内
    final sectionRegex = RegExp(
      r'<div class="section-title[^"]*">([^<]+)</div>\s*<div class="section-content">(.*?)</div>\s*(?=<div class="section|</div>\s*</div>\s*<div class="chapter|</div>\s*$)',
      dotAll: true,
    );

    for (final match in sectionRegex.allMatches(html)) {
      final titleText = match.group(1)!.trim();
      final contentHtml = match.group(2)!;

      // 从标题中提取小节号（如 "10.1 建设工程争议和解、调解制度" → "10.1"）
      final numberMatch = RegExp(r'^([\d.]+)').firstMatch(titleText);
      final number = numberMatch?.group(1) ?? '';

      final paragraphs = _parseContent(contentHtml);
      sections.add(KnowledgeSection(
        number: number,
        title: titleText,
        paragraphs: paragraphs,
      ));
    }

    return sections;
  }

  /// 将 section-content 的 HTML 转换为段落列表
  static List<KnowledgeParagraph> _parseContent(String html) {
    // 清理 HTML entities
    var content = html
        .replaceAll('&emsp;', '    ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"');

    final paragraphs = <KnowledgeParagraph>[];

    // 按 <h2>, <h4>, <p>, <br/> 分段
    // 先将 <h2> 和 <h4> 标记为特殊段落
    final blockRegex = RegExp(
      r'<h2[^>]*>(.*?)</h2>|<h4[^>]*>(.*?)</h4>|<p[^>]*>(.*?)</p>|<li[^>]*>(.*?)</li>',
      dotAll: true,
    );

    // 先提取块级元素
    int lastEnd = 0;
    final blocks = <Map<String, dynamic>>[];

    for (final match in blockRegex.allMatches(content)) {
      // 捕获块之前的文本
      if (match.start > lastEnd) {
        final between = content.substring(lastEnd, match.start);
        final cleaned = _stripTags(between).trim();
        if (cleaned.isNotEmpty) {
          blocks.add({'text': cleaned, 'type': 'normal'});
        }
      }

      if (match.group(1) != null) {
        blocks.add({'text': _stripTags(match.group(1)!).trim(), 'type': 'h2'});
      } else if (match.group(2) != null) {
        blocks.add({'text': _stripTags(match.group(2)!).trim(), 'type': 'h4'});
      } else if (match.group(3) != null) {
        final text = _stripTags(match.group(3)!).trim();
        if (text.isNotEmpty) {
          // 检查是否包含 <strong> 标签
          final hasStrong = match.group(3)!.contains('<strong>');
          blocks.add({'text': text, 'type': hasStrong ? 'bold' : 'normal'});
        }
      } else if (match.group(4) != null) {
        final text = _stripTags(match.group(4)!).trim();
        if (text.isNotEmpty) {
          blocks.add({'text': '• $text', 'type': 'normal'});
        }
      }

      lastEnd = match.end;
    }

    // 捕获最后的文本
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd);
      final cleaned = _stripTags(remaining).trim();
      if (cleaned.isNotEmpty) {
        blocks.add({'text': cleaned, 'type': 'normal'});
      }
    }

    // 如果没有提取到任何块，尝试直接清理
    if (blocks.isEmpty) {
      final cleaned = _stripTags(content).trim();
      if (cleaned.isNotEmpty) {
        // 按 <br/> 分割后的换行分割
        for (final line in cleaned.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            paragraphs.add(KnowledgeParagraph(text: trimmed));
          }
        }
      }
      return paragraphs;
    }

    // 转换块为段落
    for (final block in blocks) {
      final text = block['text'] as String;
      final type = block['type'] as String;

      // 处理块内的换行（来自 <br/>）
      for (final line in text.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        switch (type) {
          case 'h2':
            paragraphs.add(KnowledgeParagraph(
              text: trimmed,
              isHeading: true,
            ));
            break;
          case 'h4':
            paragraphs.add(KnowledgeParagraph(
              text: trimmed,
              isSubheading: true,
            ));
            break;
          case 'bold':
            paragraphs.add(KnowledgeParagraph(
              text: trimmed,
              isBold: true,
            ));
            break;
          default:
            paragraphs.add(KnowledgeParagraph(text: trimmed));
        }
      }
    }

    return paragraphs;
  }

  /// 移除 HTML 标签，保留文本内容
  static String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</p>'), '\n')
        .replaceAll(RegExp(r'</li>'), '\n')
        .replaceAll(RegExp(r'</tr>'), '\n')
        .replaceAll(RegExp(r'</td>'), '\t')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// 清除缓存
  static void clearCache() {
    _cache.clear();
    _rawHtmlCache.clear();
  }
}
