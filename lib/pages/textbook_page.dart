import 'package:flutter/material.dart';

import '../data/textbooks.dart';
import '../models/question.dart';
import '../models/history_item.dart';
import '../services/question_loader.dart';
import '../services/storage_service.dart';
import 'practice_page.dart';

/// 大纲与考点页面 - 显示教材章节大纲和题库分类
class TextbookPage extends StatefulWidget {
  const TextbookPage({super.key});

  @override
  State<TextbookPage> createState() => _TextbookPageState();
}

class _TextbookPageState extends State<TextbookPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('大纲与考点'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '二级建造师考试大纲',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '按章节大纲浏览考点，学练结合高效备考',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...Textbooks.all.map((book) => _TextbookCard(book: book)),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('学习建议', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip('按章节大纲逐章练习，系统掌握各知识点'),
                  _buildTip('先做章节练习巩固基础，再挑战模拟测试'),
                  _buildTip('错题反复练习，直至完全掌握'),
                  _buildTip('考前冲刺阶段，使用考试模式模拟实战'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _TextbookCard extends StatelessWidget {
  const _TextbookCard({required this.book});

  final Textbook book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(book.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TextbookDetailPage(book: book)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 72,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    book.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.description,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${book.chapters.length}章 · ${book.questionBankCategories.length}个练习分类',
                          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 大纲详情页面 - 显示章节大纲和题库分类
class TextbookDetailPage extends StatefulWidget {
  const TextbookDetailPage({super.key, required this.book});

  final Textbook book;

  @override
  State<TextbookDetailPage> createState() => _TextbookDetailPageState();
}

class _TextbookDetailPageState extends State<TextbookDetailPage> {
  List<bool> _expandedChapters = [];
  Map<String, bool> _completedChapters = {};
  Map<String, int> _chapterQuestionCounts = {};

  @override
  void initState() {
    super.initState();
    _expandedChapters = List.filled(widget.book.chapters.length, false);
    _loadData();
  }

  Future<void> _loadData() async {
    // 加载章节完成状态
    for (final chapter in widget.book.chapters) {
      final completed = await StorageService.isChapterCompleted(widget.book.subject, chapter.number);
      if (mounted) {
        setState(() {
          _completedChapters[chapter.number] = completed;
        });
      }
    }
    // 加载题目数量
    try {
      final index = await QuestionLoader.loadSubjectIndex(widget.book.subject.name);
      if (mounted) {
        setState(() {
          for (final entry in index.entries) {
            _chapterQuestionCounts[entry.key] = entry.value.count;
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(widget.book.color);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.book.icon,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.book.description,
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip('${widget.book.chapters.length} 章', Icons.list_alt_rounded),
                    const SizedBox(width: 8),
                    _buildStatChip('${widget.book.questionBankCategories.length} 个练习', Icons.quiz_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('📖 章节大纲', color),
          const SizedBox(height: 12),
          ...widget.book.chapters.asMap().entries.map((entry) {
            final index = entry.key;
            final chapter = entry.value;
            return _ChapterExpansionTile(
              chapter: chapter,
              color: color,
              isExpanded: _expandedChapters[index],
              onTap: () {
                setState(() {
                  _expandedChapters[index] = !_expandedChapters[index];
                });
              },
              onPracticeTap: () => _startChapterPractice(chapter.number),
              isCompleted: _completedChapters[chapter.number] ?? false,
              questionCount: _chapterQuestionCounts[chapter.number],
            );
          }),
          if (widget.book.chapters.isEmpty)
            _buildEmptyState('暂无大纲信息'),
          const SizedBox(height: 24),
          _buildSectionHeader('📝 题库练习', color),
          const SizedBox(height: 12),
          ...widget.book.questionBankCategories.map((category) => _QuestionBankCard(
                category: category,
                color: color,
                questionCount: category.chapterNumber != null
                    ? _chapterQuestionCounts[category.chapterNumber]
                    : null,
                onTap: () => _handleQuestionBankTap(category),
              )),
          if (widget.book.questionBankCategories.isEmpty)
            _buildEmptyState('暂无题库分类'),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  void _startChapterPractice(String chapterNumber) {
    final config = PracticeConfig(
      subject: widget.book.subject,
      chapterNumber: chapterNumber,
      mode: PracticeMode.practice,
      shuffleQuestions: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: config,
          onCompleted: (result) async {
            await StorageService.addHistory(result);
            await StorageService.markChapterCompleted(widget.book.subject, chapterNumber);
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  void _handleQuestionBankTap(QuestionBankCategory category) {
    final subject = widget.book.subject;
    PracticeConfig config;

    if (category.chapterNumber != null) {
      config = PracticeConfig(
        subject: subject,
        chapterNumber: category.chapterNumber,
        mode: PracticeMode.practice,
        shuffleQuestions: false,
      );
    } else if (category.id.contains('mock')) {
      config = PracticeConfig(
        subject: subject,
        mode: PracticeMode.exam,
        shuffleQuestions: true,
        shuffleOptions: true,
        questionLimit: 20,
        timeLimitSeconds: 30 * 60,
      );
    } else if (category.id.contains('final')) {
      config = PracticeConfig(
        subject: subject,
        mode: PracticeMode.practice,
        shuffleQuestions: true,
        questionLimit: 30,
      );
    } else {
      config = PracticeConfig(subject: subject);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: config,
          onCompleted: (result) async {
            await StorageService.addHistory(result);
            if (category.chapterNumber != null) {
              await StorageService.markChapterCompleted(subject, category.chapterNumber!);
            }
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }
}

class _ChapterExpansionTile extends StatelessWidget {
  const _ChapterExpansionTile({
    required this.chapter,
    required this.color,
    required this.isExpanded,
    required this.onTap,
    required this.onPracticeTap,
    required this.isCompleted,
    this.questionCount,
  });

  final TextbookChapter chapter;
  final Color color;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onPracticeTap;
  final bool isCompleted;
  final int? questionCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 12),
                  if (isCompleted)
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                  if (!isCompleted)
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(
                    '第${chapter.number}章',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      chapter.title,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  if (questionCount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$questionCount题',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onPracticeTap,
                    icon: Icon(Icons.play_circle_rounded, color: color),
                    tooltip: '开始练习',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && chapter.subsections.isNotEmpty)
            const Divider(height: 0),
          if (isExpanded && chapter.subsections.isNotEmpty)
            Column(
              children: chapter.subsections.map((subsection) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        subsection.number,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          subsection.title,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _QuestionBankCard extends StatelessWidget {
  const _QuestionBankCard({
    required this.category,
    required this.color,
    required this.onTap,
    this.questionCount,
  });

  final QuestionBankCategory category;
  final Color color;
  final VoidCallback onTap;
  final int? questionCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    category.icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      if (category.description.isNotEmpty)
                        Text(
                          category.description,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                if (questionCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$questionCount题',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}