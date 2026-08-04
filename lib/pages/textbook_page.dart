import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/textbooks.dart';
import '../models/question.dart';
import '../models/history_item.dart';
import '../providers/app_provider.dart';
import '../services/question_loader.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../services/knowledge_service.dart';
import 'practice_page.dart';

/// 大纲与考点页面 - 显示教材章节大纲和题库分类
class TextbookPage extends StatefulWidget {
  const TextbookPage({super.key});

  @override
  State<TextbookPage> createState() => _TextbookPageState();
}

class _TextbookPageState extends State<TextbookPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('大纲与考点'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              decoration: InputDecoration(
                hintText: '搜索章节、小节或考点...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总体学习进度概览
          _buildOverallProgress(theme, app),
          const SizedBox(height: 16),
          ...Textbooks.all.map((book) => _TextbookCard(book: book, searchQuery: _searchQuery)),
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

  /// 总体学习进度概览卡片
  Widget _buildOverallProgress(ThemeData theme, AppProvider app) {
    final totalChapters = Textbooks.all.fold(0, (sum, book) => sum + book.chapters.length);
    final completed = app.completedChapters;
    final progress = totalChapters == 0 ? 0.0 : (completed / totalChapters).clamp(0.0, 1.0);
    final wrongCount = app.wrongQuestions.length;
    final favCount = app.favorites.length;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 16),
          // 进度条
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completed/$totalChapters 章',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 快捷统计
          Row(
            children: [
              _buildQuickStat('错题', wrongCount, Icons.error_outline_rounded),
              const SizedBox(width: 12),
              _buildQuickStat('收藏', favCount, Icons.star_outline_rounded),
              const SizedBox(width: 12),
              _buildQuickStat('题目', app.totalQuestions, Icons.quiz_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
          ],
        ),
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
  const _TextbookCard({required this.book, this.searchQuery = ''});

  final Textbook book;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(book.color);
    final app = context.watch<AppProvider>();

    // 该科目的题目数
    final subjectQuestions = app.subjectStats[book.subject] ?? 0;
    // 该科目的错题数
    final subjectWrong = app.wrongQuestions
        .where((key) => key.startsWith(book.subject.name))
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TextbookDetailPage(book: book, searchQuery: searchQuery)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildTag('${book.chapters.length}章', color),
                              _buildTag('$subjectQuestions题', color),
                              if (subjectWrong > 0)
                                _buildTag('$subjectWrong错题', Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 小节详情页面 - 双Tab展示考点知识和章节练习
class SubsectionDetailPage extends StatefulWidget {
  const SubsectionDetailPage({
    super.key,
    required this.subsection,
    required this.chapterNumber,
    required this.subject,
    required this.bookColor,
    required this.bookTitle,
  });

  final TextbookChapter subsection;
  final String chapterNumber;
  final QuestionSubject subject;
  final int bookColor;
  final String bookTitle;

  @override
  State<SubsectionDetailPage> createState() => _SubsectionDetailPageState();
}

class _SubsectionDetailPageState extends State<SubsectionDetailPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<String> _questionKnowledgePoints = [];
  int _questionCount = 0;
  bool _isSubsectionLevel = false;
  List<KnowledgeSection> _knowledgeSections = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // 并行加载题目数据和考点知识
    final results = await Future.wait([
      _loadQuestions(),
      _loadKnowledge(),
    ]);

    final questionData = results[0] as _QuestionData;
    final knowledgeSections = results[1] as List<KnowledgeSection>;

    if (mounted) {
      setState(() {
        _questionKnowledgePoints = questionData.knowledgePoints;
        _questionCount = questionData.questionCount;
        _isSubsectionLevel = questionData.isSubsectionLevel;
        _knowledgeSections = knowledgeSections;
        _isLoading = false;
      });
    }
  }

  Future<_QuestionData> _loadQuestions() async {
    var questions = await QuestionService.filter(
      subject: widget.subject,
      chapterNumber: widget.chapterNumber,
      subsection: widget.subsection.number,
    );

    bool subsectionLevel = false;
    if (questions.isEmpty) {
      questions = await QuestionService.filter(
        subject: widget.subject,
        chapterNumber: widget.chapterNumber,
      );
    } else {
      subsectionLevel = true;
    }

    final points = <String>{};
    for (final q in questions) {
      points.addAll(q.knowledgePoints);
    }

    return _QuestionData(
      knowledgePoints: points.toList()..sort(),
      questionCount: questions.length,
      isSubsectionLevel: subsectionLevel,
    );
  }

  Future<List<KnowledgeSection>> _loadKnowledge() async {
    try {
      // 先尝试精确匹配小节号
      var sections = await KnowledgeService.getSectionsBySubsection(
        subject: widget.subject,
        chapterNumber: widget.chapterNumber,
        subsectionNumber: widget.subsection.number,
      );
      // 如果精确匹配无结果，回退到整章
      if (sections.isEmpty) {
        sections = await KnowledgeService.getSectionsBySubsection(
          subject: widget.subject,
          chapterNumber: widget.chapterNumber,
        );
      }
      return sections;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(widget.bookColor);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subsection.number} ${widget.subsection.title}'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: '考点知识'),
            Tab(icon: Icon(Icons.quiz_rounded, size: 18), text: '章节练习'),
          ],
          labelColor: color,
          indicatorColor: color,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildKnowledgeTab(theme, color),
                _buildPracticeTab(theme, color),
              ],
            ),
    );
  }

  /// 考点知识 Tab - 展示从HTML解析的考点内容
  Widget _buildKnowledgeTab(ThemeData theme, Color color) {
    if (_knowledgeSections.isEmpty) {
      return _buildEmptyState('暂无考点知识内容', icon: Icons.menu_book_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _knowledgeSections.length,
      itemBuilder: (context, index) {
        final section = _knowledgeSections[index];
        return _KnowledgeSectionCard(section: section, color: color);
      },
    );
  }

  /// 章节练习 Tab - 展示题目相关考点和练习入口
  Widget _buildPracticeTab(ThemeData theme, Color color) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 小节信息卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
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
                  Icon(Icons.bookmark_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.subsection.number} ${widget.subsection.title}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.bookTitle} · 第${widget.chapterNumber}章',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip('$_questionCount 题', Icons.quiz_rounded),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    '${_questionKnowledgePoints.length} 个考点',
                    Icons.lightbulb_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip('P${widget.subsection.page}', Icons.menu_book_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 题目考点列表
        if (_questionKnowledgePoints.isNotEmpty) ...[
          _buildSectionHeader('题目考点', color),
          const SizedBox(height: 12),
          ..._questionKnowledgePoints.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () => _startKnowledgePointPractice(point),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(point, style: const TextStyle(fontSize: 15)),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: color.withOpacity(0.4),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],

        // 练习入口
        if (!_isSubsectionLevel && _questionCount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '题目数据暂未细分到此小节，以下练习包含整章题目',
                    style: TextStyle(color: Colors.orange[700], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (_questionCount > 0)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _startPractice,
              icon: const Icon(Icons.play_circle_rounded),
              label: const Text('开始练习', style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
        else
          _buildEmptyState('暂无题目', icon: Icons.quiz_outlined),
      ],
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

  Widget _buildStatChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
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

  Widget _buildEmptyState(String text, {IconData icon = Icons.inbox_rounded}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(text, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _startPractice() {
    final config = PracticeConfig(
      subject: widget.subject,
      chapterNumber: widget.chapterNumber,
      subsection: _isSubsectionLevel ? widget.subsection.number : null,
      mode: PracticeMode.practice,
      shuffleQuestions: false,
    );

    final provider = context.read<AppProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: config,
          onCompleted: (result) async {
            await provider.addHistory(result);
            await StorageService.markChapterCompleted(widget.subject, widget.chapterNumber);
          },
        ),
      ),
    );
  }

  void _startKnowledgePointPractice(String knowledgePoint) {
    final config = PracticeConfig(
      subject: widget.subject,
      chapterNumber: widget.chapterNumber,
      keyword: knowledgePoint,
      mode: PracticeMode.practice,
      shuffleQuestions: false,
    );

    final provider = context.read<AppProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: config,
          onCompleted: (result) async {
            await provider.addHistory(result);
            await StorageService.markChapterCompleted(widget.subject, widget.chapterNumber);
          },
        ),
      ),
    );
  }
}

/// 题目数据封装
class _QuestionData {
  final List<String> knowledgePoints;
  final int questionCount;
  final bool isSubsectionLevel;

  const _QuestionData({
    required this.knowledgePoints,
    required this.questionCount,
    required this.isSubsectionLevel,
  });
}

/// 考点知识段落渲染组件
class _KnowledgeSectionCard extends StatelessWidget {
  const _KnowledgeSectionCard({required this.section, required this.color});

  final KnowledgeSection section;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小节标题
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.book_rounded, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 段落内容
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: _buildParagraphs(theme, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraphs(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: section.paragraphs.map((p) {
        if (p.isHeading) {
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              p.text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.blue.shade200 : color,
              ),
            ),
          );
        }
        if (p.isSubheading) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              p.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.teal.shade200 : color.withOpacity(0.8),
              ),
            ),
          );
        }
        if (p.isBold) {
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Text(
              p.text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.orange.shade200 : Colors.red.shade700,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Text(
            p.text,
            style: TextStyle(
              fontSize: 14,
              height: 1.7,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 章节考点知识页面 - 展示整章所有小节的考点内容
class ChapterKnowledgePage extends StatefulWidget {
  const ChapterKnowledgePage({
    super.key,
    required this.subject,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.bookColor,
    required this.bookTitle,
  });

  final QuestionSubject subject;
  final String chapterNumber;
  final String chapterTitle;
  final int bookColor;
  final String bookTitle;

  @override
  State<ChapterKnowledgePage> createState() => _ChapterKnowledgePageState();
}

class _ChapterKnowledgePageState extends State<ChapterKnowledgePage> {
  bool _isLoading = true;
  List<KnowledgeSection> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final sections = await KnowledgeService.getSectionsBySubsection(
        subject: widget.subject,
        chapterNumber: widget.chapterNumber,
      );
      if (mounted) {
        setState(() {
          _sections = sections;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.bookColor);

    return Scaffold(
      appBar: AppBar(
        title: Text('第${widget.chapterNumber}章 考点知识'),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sections.length,
                  itemBuilder: (context, index) =>
                      _KnowledgeSectionCard(section: _sections[index], color: color),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('暂无考点知识内容', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

/// 大纲详情页面 - 显示章节大纲和题库分类
class TextbookDetailPage extends StatefulWidget {
  const TextbookDetailPage({super.key, required this.book, this.searchQuery = ''});

  final Textbook book;
  final String searchQuery;

  @override
  State<TextbookDetailPage> createState() => _TextbookDetailPageState();
}

class _TextbookDetailPageState extends State<TextbookDetailPage> {
  List<bool> _expandedChapters = [];
  Map<String, bool> _completedChapters = {};
  Map<String, int> _chapterQuestionCounts = {};
  String _searchQuery = '';
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _expandedChapters = List.filled(widget.book.chapters.length, false);
    _searchQuery = widget.searchQuery;
    _searchController = TextEditingController(text: _searchQuery);
    // 如果有搜索词，自动展开所有章节
    if (_searchQuery.isNotEmpty) {
      _expandedChapters = List.filled(widget.book.chapters.length, true);
    }
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final app = context.watch<AppProvider>();

    // 过滤章节（搜索功能）
    final filteredChapters = widget.book.chapters.where((chapter) {
      if (_searchQuery.isEmpty) return true;
      // 匹配章节标题
      if (chapter.title.contains(_searchQuery) ||
          chapter.number.contains(_searchQuery)) {
        return true;
      }
      // 匹配小节标题
      for (final sub in chapter.subsections) {
        if (sub.title.contains(_searchQuery) ||
            sub.number.contains(_searchQuery)) {
          return true;
        }
      }
      return false;
    }).toList();

    // 该科目错题数
    final subjectWrongCount = app.wrongQuestions
        .where((key) => key.startsWith(widget.book.subject.name))
        .length;
    // 该科目收藏数
    final subjectFavCount = app.favorites
        .where((key) => key.startsWith(widget.book.subject.name))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() {
                _searchQuery = value.trim();
                // 搜索时自动展开所有章节
                if (_searchQuery.isNotEmpty) {
                  _expandedChapters = List.filled(widget.book.chapters.length, true);
                }
              }),
              decoration: InputDecoration(
                hintText: '搜索章节或小节...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _expandedChapters = List.filled(widget.book.chapters.length, false);
                          });
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 教材信息卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withOpacity(0.7),
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
          const SizedBox(height: 12),
          // 快捷入口：错题重做、收藏练习
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  '错题重做',
                  '$subjectWrongCount 题',
                  Icons.error_outline_rounded,
                  Colors.red,
                  () => _startWrongQuestionPractice(),
                  subjectWrongCount > 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionCard(
                  '收藏练习',
                  '$subjectFavCount 题',
                  Icons.star_rounded,
                  Colors.amber,
                  () => _startFavoritePractice(),
                  subjectFavCount > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('📖 章节大纲', color),
          const SizedBox(height: 12),
          if (_searchQuery.isNotEmpty && filteredChapters.isEmpty)
            _buildEmptyState('未找到匹配「$_searchQuery」的章节')
          else
            ...filteredChapters.asMap().entries.map((entry) {
              // 获取在原始列表中的索引
              final originalIndex = widget.book.chapters.indexOf(entry.value);
              final chapter = entry.value;
              return _ChapterExpansionTile(
                chapter: chapter,
                color: color,
                isExpanded: _expandedChapters[originalIndex],
                onTap: () {
                  setState(() {
                    _expandedChapters[originalIndex] = !_expandedChapters[originalIndex];
                  });
                },
                onPracticeTap: () => _startChapterPractice(chapter.number),
                onKnowledgeTap: () => _openChapterKnowledge(chapter),
                onSubsectionTap: (subsection) => _openSubsection(subsection, chapter.number),
                isCompleted: _completedChapters[chapter.number] ?? false,
                questionCount: _chapterQuestionCounts[chapter.number],
                searchQuery: _searchQuery,
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
        color: Colors.white.withOpacity(0.2),
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

  void _openSubsection(TextbookChapter subsection, String chapterNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubsectionDetailPage(
          subsection: subsection,
          chapterNumber: chapterNumber,
          subject: widget.book.subject,
          bookColor: widget.book.color,
          bookTitle: widget.book.title,
        ),
      ),
    );
  }

  void _openChapterKnowledge(TextbookChapter chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterKnowledgePage(
          subject: widget.book.subject,
          chapterNumber: chapter.number,
          chapterTitle: chapter.title,
          bookColor: widget.book.color,
          bookTitle: widget.book.title,
        ),
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

    final provider = context.read<AppProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: config,
          onCompleted: (result) async {
            await provider.addHistory(result);
            await StorageService.markChapterCompleted(widget.book.subject, chapterNumber);
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

    final provider = context.read<AppProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: config,
          onCompleted: (result) async {
            await provider.addHistory(result);
            if (category.chapterNumber != null) {
              await StorageService.markChapterCompleted(subject, category.chapterNumber!);
            }
          },
        ),
      ),
    );
  }
  void _startWrongQuestionPractice() {
    final config = PracticeConfig(
      subject: widget.book.subject,
      mode: PracticeMode.wrong,
      shuffleQuestions: false,
    );

    final provider = context.read<AppProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: config,
          onCompleted: (result) async {
            await provider.addHistory(result);
          },
        ),
      ),
    );
  }

  void _startFavoritePractice() {
    final config = PracticeConfig(
      subject: widget.book.subject,
      onlyFavorites: true,
      mode: PracticeMode.practice,
      shuffleQuestions: false,
    );

    final provider = context.read<AppProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: config,
          onCompleted: (result) async {
            await provider.addHistory(result);
          },
        ),
      ),
    );
  }

  /// 快捷操作卡片（错题重做、收藏练习）
  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
    bool enabled,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(enabled ? 0.3 : 0.1)),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(enabled ? 0.15 : 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: enabled ? color : Colors.grey, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: enabled
                            ? (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? color : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    required this.onSubsectionTap,
    required this.isCompleted,
    this.questionCount,
    this.searchQuery = '',
    this.onKnowledgeTap,
  });

  final TextbookChapter chapter;
  final Color color;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onPracticeTap;
  final void Function(TextbookChapter subsection) onSubsectionTap;
  final bool isCompleted;
  final int? questionCount;
  final String searchQuery;
  final VoidCallback? onKnowledgeTap;

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
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$questionCount题',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (onKnowledgeTap != null)
                    IconButton(
                      onPressed: onKnowledgeTap,
                      icon: Icon(Icons.menu_book_rounded, color: color.withOpacity(0.7)),
                      tooltip: '查看考点',
                      visualDensity: VisualDensity.compact,
                    ),
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
                return InkWell(
                  onTap: () => onSubsectionTap(subsection),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                    child: Row(
                      children: [
                        Text(
                          subsection.number,
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            subsection.title,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: color.withOpacity(0.4),
                        ),
                      ],
                    ),
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
          side: BorderSide(color: color.withOpacity(0.2)),
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
                    color: color.withOpacity(0.1),
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
                      color: color.withOpacity(0.1),
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