import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/textbooks.dart';
import '../models/question.dart';
import '../models/history_item.dart';
import '../models/knowledge_point.dart';
import '../providers/app_provider.dart';
import '../services/question_loader.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../services/knowledge_service.dart';
import '../services/tts_service.dart';
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
  // 知识点练习状态：key = 知识点名称, value = 统计数据
  Map<String, KnowledgePointStats> _kpStats = {};
  // TTS 播放状态
  bool _isPlayingKnowledge = false;
  int _playingSectionIndex = -1; // -1 = 未播放

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    // 预热 TTS 引擎，避免首次点击朗读时出现明显延迟
    TtsService.initialize();
  }

  @override
  void dispose() {
    if (_isPlayingKnowledge) {
      TtsService.stop();
    }
    _tabController.dispose();
    super.dispose();
  }

  // ========== TTS 语音播报 ==========

  /// 播放指定小节的考点内容
  Future<void> _playSection(int index) async {
    if (index < 0 || index >= _knowledgeSections.length) return;

    // 如果当前正在播放同一个小节，则停止
    if (_playingSectionIndex == index && _isPlayingKnowledge) {
      await _stopKnowledgePlayback();
      return;
    }

    // 停止之前的播放
    if (_isPlayingKnowledge) {
      _isPlayingKnowledge = false;
      await TtsService.stop();
    }

    if (!mounted) return;
    // 应用用户保存的语音参数（TTS 初始化由 speak() 内部处理，含重试逻辑）
    try {
      final app = context.read<AppProvider>();
      await TtsService.applySpeechParams(
        rate: app.ttsSpeechRate,
        pitch: app.ttsPitch,
        volume: app.ttsVolume,
      );
    } catch (e) {
      debugPrint('读取/应用语音参数失败，使用默认值: $e');
    }

    if (!mounted) return;

    if (!await _ensureTtsReady()) return;

    setState(() {
      _isPlayingKnowledge = true;
      _playingSectionIndex = index;
    });

    final raw = _knowledgeSections[index].toSpeechText();
    final chunks = _cleanAndChunk(raw);
    var overallSuccess = true;

    for (var i = 0; i < chunks.length; i++) {
      if (!_isPlayingKnowledge || !mounted) {
        overallSuccess = false;
        break;
      }

      final chunk = chunks[i];
      final success = await TtsService.speak(chunk, waitForCompletion: true);
      if (!success) {
        overallSuccess = false;
        break;
      }
      // 小段间短暂停顿，避免句子连读
      await Future.delayed(const Duration(milliseconds: 180));
    }

    if (mounted) {
      setState(() {
        _isPlayingKnowledge = false;
        _playingSectionIndex = -1;
      });
    }

    if (!overallSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音播报失败，请重试')),
      );
    }
  }

  /// 防止重复调用 _playAllKnowledge
  bool _isStartingPlayback = false;

  /// 顺序播放所有考点内容
  Future<void> _playAllKnowledge() async {
    // 防止重复点击
    if (_isStartingPlayback) return;
    _isStartingPlayback = true;

    try {
      if (_knowledgeSections.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无考点内容可播放')),
          );
        }
        return;
      }

      // 如果正在播放，则停止
      if (_isPlayingKnowledge) {
        await _stopKnowledgePlayback();
        return;
      }

      // 应用用户保存的语音参数（TTS 初始化由 speak() 内部处理，含重试逻辑）
      try {
        final app = context.read<AppProvider>();
        await TtsService.applySpeechParams(
          rate: app.ttsSpeechRate,
          pitch: app.ttsPitch,
          volume: app.ttsVolume,
        );
      } catch (e) {
        debugPrint('读取/应用语音参数失败，使用默认值: $e');
      }

      if (!mounted) return;

      setState(() {
        _isPlayingKnowledge = true;
        _playingSectionIndex = 0;
      });

      if (!await _ensureTtsReady()) {
        if (mounted) {
          setState(() {
            _isPlayingKnowledge = false;
            _playingSectionIndex = -1;
          });
        }
        return;
      }

      for (var i = 0; i < _knowledgeSections.length; i++) {
        if (!_isPlayingKnowledge || !mounted) break;

        setState(() {
          _playingSectionIndex = i;
        });

        final raw = _knowledgeSections[i].toSpeechText();
        final chunks = _cleanAndChunk(raw);
        var ok = true;
        for (var c = 0; c < chunks.length; c++) {
          if (!_isPlayingKnowledge || !mounted) {
            ok = false;
            break;
          }
          final success = await TtsService.speak(chunks[c], waitForCompletion: true);
          if (!success) {
            ok = false;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 160));
        }
        if (!ok || !_isPlayingKnowledge || !mounted) break;
      }

      if (mounted) {
        setState(() {
          _isPlayingKnowledge = false;
          _playingSectionIndex = -1;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('_playAllKnowledge 异常: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isPlayingKnowledge = false;
          _playingSectionIndex = -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放启动失败: $e')),
        );
      }
    } finally {
      _isStartingPlayback = false;
    }
  }


  /// 停止播放
  Future<void> _stopKnowledgePlayback() async {
    _isPlayingKnowledge = false;
    await TtsService.stop();
    if (mounted) {
      setState(() {
        _isPlayingKnowledge = false;
        _playingSectionIndex = -1;
      });
    }
  }

  Future<bool> _ensureTtsReady() async {
    final ready = await TtsService.initialize();
    if (!ready && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音引擎初始化失败，请检查 TTS 设置')),
      );
    }
    return ready;
  }

  /// 将原始文本/HTML清洗为纯文本，并按语音友好的句子或长度分块返回
  List<String> _cleanAndChunk(String raw) {
    // 移除常见 HTML 标签与实体（简单处理，复杂 HTML 可用后端预处理）
    var s = raw.replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ');
    s = s.replaceAll('&nbsp;', ' ');
    s = s.replaceAll('&lt;', '<');
    s = s.replaceAll('&gt;', '>');
    s = s.replaceAll('&amp;', '&');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (s.isEmpty) return [];

    // 先按中文句号、问号、感叹号或英文标点拆分为句子
    final sentenceSep = RegExp(r'(?<=[。！？!?;；.])\s*');
    final parts = s.split(sentenceSep).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // 合并句子以控制每块长度（目标 160-260 字符）
    const int target = 220;
    final List<String> chunks = [];
    var buffer = StringBuffer();

    for (var p in parts) {
      if (buffer.isEmpty) {
        buffer.write(p);
      } else if ((buffer.length + p.length) <= target) {
        buffer.write(' ');
        buffer.write(p);
      } else {
        chunks.add(buffer.toString());
        buffer = StringBuffer(p);
      }
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());

    // 如果没有切出句子（比如整段无标点），再按长度切分
    if (chunks.isEmpty) {
      for (var i = 0; i < s.length; i += target) {
        chunks.add(s.substring(i, (i + target).clamp(0, s.length)));
      }
    }

    return chunks;
  }

  Future<void> _loadData() async {
    // 并行加载题目数据、考点知识和知识点统计
    final results = await Future.wait([
      _loadQuestions(),
      _loadKnowledge(),
      _loadKnowledgeStats(),
    ]);

    final questionData = results[0] as _QuestionData;
    final knowledgeSections = results[1] as List<KnowledgeSection>;
    final kpStats = results[2] as Map<String, KnowledgePointStats>;

    if (mounted) {
      setState(() {
        _questionKnowledgePoints = questionData.knowledgePoints;
        _questionCount = questionData.questionCount;
        _isSubsectionLevel = questionData.isSubsectionLevel;
        _knowledgeSections = knowledgeSections;
        _kpStats = kpStats;
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

  Future<Map<String, KnowledgePointStats>> _loadKnowledgeStats() async {
    try {
      final stats = await StorageService.loadKnowledgeStats();
      return {for (final s in stats) s.point.id: s};
    } catch (_) {
      return {};
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

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: _knowledgeSections.length,
          itemBuilder: (context, index) {
            final section = _knowledgeSections[index];
            final isThisPlaying = _isPlayingKnowledge && _playingSectionIndex == index;
            return _KnowledgeSectionCard(
              section: section,
              color: color,
              isPlaying: isThisPlaying,
              onPlayTap: () => _playSection(index),
            );
          },
        ),
        // 底部播放控制栏
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _buildPlaybackBar(theme, color),
        ),
      ],
    );
  }

  /// 底部播放控制栏
  Widget _buildPlaybackBar(ThemeData theme, Color color) {
    final isDark = theme.brightness == Brightness.dark;
    final playingLabel = _playingSectionIndex >= 0 && _playingSectionIndex < _knowledgeSections.length
        ? _knowledgeSections[_playingSectionIndex].title
        : '考点知识';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // 播放/停止按钮
          GestureDetector(
            onTap: _playAllKnowledge,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isPlayingKnowledge ? Colors.red : color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPlayingKnowledge ? Icons.stop_rounded : Icons.playlist_play_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 播放状态文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isPlayingKnowledge ? '正在播放' : '点击播放全部',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (_isPlayingKnowledge)
                  Text(
                    playingLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // 停止按钮（仅播放时显示）
          if (_isPlayingKnowledge)
            GestureDetector(
              onTap: _stopKnowledgePlayback,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
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
            final stats = _kpStats[point];
            return _buildKnowledgePointCard(index, point, stats, color);
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

  /// 构建知识点卡片，展示练习状态标识
  Widget _buildKnowledgePointCard(
    int index,
    String point,
    KnowledgePointStats? stats,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 判断练习状态
    _KPStatus status;
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (stats == null || stats.practiceCount == 0) {
      status = _KPStatus.unpracticed;
      statusText = '未练习';
      statusColor = Colors.grey;
      statusIcon = Icons.radio_button_unchecked_rounded;
    } else if (stats.point.masteryLevel >= 0.8) {
      status = _KPStatus.mastered;
      statusText = '已掌握';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else if (stats.point.totalQuestions > 0 &&
        stats.point.accuracy < 0.6) {
      status = _KPStatus.needsReview;
      statusText = '需巩固';
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      status = _KPStatus.practiced;
      statusText = '已练习';
      statusColor = Colors.blue;
      statusIcon = Icons.play_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withOpacity(status == _KPStatus.unpracticed ? 0.15 : 0.3),
        ),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _startKnowledgePointPractice(point),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // 序号
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 知识点名称和统计
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 统计信息行
                    Row(
                      children: [
                        // 状态徽章
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 12, color: statusColor),
                              const SizedBox(width: 3),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 练习次数和正确率
                        if (stats != null && stats.practiceCount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '练习${stats.practiceCount}次',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '正确率${(stats.point.accuracy * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: stats.point.accuracy >= 0.6
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (stats.wrongCount > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '错${stats.wrongCount}题',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 练习按钮
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: color,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 从练习页面返回后刷新知识点统计
  Future<void> _refreshKnowledgeStats() async {
    final kpStats = await _loadKnowledgeStats();
    if (mounted) {
      setState(() {
        _kpStats = kpStats;
      });
    }
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
    ).then((_) => _refreshKnowledgeStats());
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
    ).then((_) => _refreshKnowledgeStats());
  }
}

/// 知识点练习状态
enum _KPStatus { unpracticed, practiced, needsReview, mastered }

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
  const _KnowledgeSectionCard({
    required this.section,
    required this.color,
    this.isPlaying = false,
    this.onPlayTap,
  });

  final KnowledgeSection section;
  final Color color;
  final bool isPlaying;
  final VoidCallback? onPlayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying ? color : color.withOpacity(0.15),
          width: isPlaying ? 2 : 1,
        ),
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
              color: isPlaying ? color.withOpacity(0.15) : color.withOpacity(0.08),
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
                // 播放按钮
                if (onPlayTap != null)
                  GestureDetector(
                    onTap: onPlayTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isPlaying ? color : color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                        color: isPlaying ? Colors.white : color,
                        size: 20,
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
        // 图片段落
        if (p.imagePath != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/knowledge/${p.imagePath}',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.broken_image_outlined,
                          color: isDark ? Colors.white54 : Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '图片缺失：${p.imagePath}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
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
  // TTS 播放状态
  bool _isPlayingKnowledge = false;
  int _playingSectionIndex = -1;
  int _currentChunkIndex = 0;
  int _currentChunkCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    // 预热 TTS 引擎，避免首次点击朗读时出现明显延迟
    TtsService.initialize();
  }

  @override
  void dispose() {
    if (_isPlayingKnowledge) {
      TtsService.stop();
    }
    super.dispose();
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

  // ========== TTS 语音播报 ==========

  Future<void> _playSection(int index) async {
    if (index < 0 || index >= _sections.length) return;

    if (_playingSectionIndex == index && _isPlayingKnowledge) {
      await _stopKnowledgePlayback();
      return;
    }

    if (_isPlayingKnowledge) {
      _isPlayingKnowledge = false;
      await TtsService.stop();
    }

    if (!mounted) return;

    try {
      final app = context.read<AppProvider>();
      await TtsService.applySpeechParams(
        rate: app.ttsSpeechRate,
        pitch: app.ttsPitch,
        volume: app.ttsVolume,
      );
    } catch (e) {
      debugPrint('读取/应用语音参数失败，使用默认值: $e');
    }

    if (!mounted) return;

    if (!await _ensureTtsReady()) return;

    final raw = _sections[index].toSpeechText();
    final chunks = _cleanAndChunk(raw);

    setState(() {
      _isPlayingKnowledge = true;
      _playingSectionIndex = index;
      _currentChunkCount = chunks.length;
      _currentChunkIndex = 0;
    });

    var overallSuccess = true;

    for (var i = 0; i < chunks.length; i++) {
      if (!_isPlayingKnowledge || !mounted) {
        overallSuccess = false;
        break;
      }
      if (mounted) {
        setState(() {
          _currentChunkIndex = i;
        });
      }
      final success = await TtsService.speak(chunks[i], waitForCompletion: true);
      if (!success) {
        overallSuccess = false;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 180));
    }

    if (mounted) {
      setState(() {
        _isPlayingKnowledge = false;
        _playingSectionIndex = -1;
        _currentChunkIndex = 0;
        _currentChunkCount = 0;
      });
    }

    if (!overallSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音播报失败，请重试')),
      );
    }
  }

  /// 防止重复调用 _playAllKnowledge
  bool _isStartingPlayback = false;

  Future<void> _playAllKnowledge() async {
    if (_isStartingPlayback) return;
    _isStartingPlayback = true;

    try {
      if (_sections.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无考点内容可播放')),
          );
        }
        return;
      }

      if (_isPlayingKnowledge) {
        await _stopKnowledgePlayback();
        return;
      }

      try {
        final app = context.read<AppProvider>();
        await TtsService.applySpeechParams(
          rate: app.ttsSpeechRate,
          pitch: app.ttsPitch,
          volume: app.ttsVolume,
        );
      } catch (e) {
        debugPrint('读取/应用语音参数失败，使用默认值: $e');
      }

      if (!mounted) return;

      if (!await _ensureTtsReady()) {
        if (mounted) {
          setState(() {
            _isPlayingKnowledge = false;
            _playingSectionIndex = -1;
          });
        }
        return;
      }

      setState(() {
        _isPlayingKnowledge = true;
        _playingSectionIndex = 0;
      });

      for (var i = 0; i < _sections.length; i++) {
        if (!_isPlayingKnowledge || !mounted) break;

        final raw = _sections[i].toSpeechText();
        final chunks = _cleanAndChunk(raw);

        setState(() {
          _playingSectionIndex = i;
          _currentChunkCount = chunks.length;
          _currentChunkIndex = 0;
        });

        var ok = true;
        for (var j = 0; j < chunks.length; j++) {
          if (!_isPlayingKnowledge || !mounted) {
            ok = false;
            break;
          }
          if (mounted) {
            setState(() {
              _currentChunkIndex = j;
            });
          }
          final success = await TtsService.speak(chunks[j], waitForCompletion: true);
          if (!success) {
            ok = false;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 160));
        }
        if (!ok || !_isPlayingKnowledge || !mounted) break;
      }
    } catch (e, stackTrace) {
      debugPrint('_playAllKnowledge 异常: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放启动失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlayingKnowledge = false;
          _playingSectionIndex = -1;
        });
      }
      _isStartingPlayback = false;
    }
  }

  void _playNextInSequence(int index) {
    // 已弃用：使用 waitForCompletion 的顺序播放逻辑替代此递归实现。
    if (mounted) {
      setState(() {
        _isPlayingKnowledge = false;
        _playingSectionIndex = -1;
      });
    }
  }

  Future<void> _stopKnowledgePlayback() async {
    _isPlayingKnowledge = false;
    await TtsService.stop();
    if (mounted) {
      setState(() {
        _isPlayingKnowledge = false;
        _playingSectionIndex = -1;
        _currentChunkIndex = 0;
        _currentChunkCount = 0;
      });
    }
  }

  Future<bool> _ensureTtsReady() async {
    final ready = await TtsService.initialize();
    if (!ready && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音引擎初始化失败，请检查 TTS 设置')),
      );
    }
    return ready;
  }

  List<String> _cleanAndChunk(String raw) {
    var text = raw.replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) return [];

    final sentenceSep = RegExp(r'(?<=[。！？!?;；.])\s*');
    final parts = text
        .split(sentenceSep)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    const int targetLength = 220;
    final chunks = <String>[];
    var buffer = StringBuffer();

    for (final part in parts) {
      if (buffer.isEmpty) {
        buffer.write(part);
      } else if ((buffer.length + part.length) <= targetLength) {
        buffer.write(' ');
        buffer.write(part);
      } else {
        chunks.add(buffer.toString());
        buffer = StringBuffer(part);
      }
    }
    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    if (chunks.isEmpty) {
      for (var i = 0; i < text.length; i += targetLength) {
        chunks.add(text.substring(i, (i + targetLength).clamp(0, text.length)));
      }
    }

    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              : Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _sections.length,
                      itemBuilder: (context, index) {
                        final isThisPlaying =
                            _isPlayingKnowledge && _playingSectionIndex == index;
                        return _KnowledgeSectionCard(
                          section: _sections[index],
                          color: color,
                          isPlaying: isThisPlaying,
                          onPlayTap: () => _playSection(index),
                        );
                      },
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: _buildPlaybackBar(theme, color),
                    ),
                  ],
                ),
    );
  }

  /// 底部播放控制栏
  Widget _buildPlaybackBar(ThemeData theme, Color color) {
    final isDark = theme.brightness == Brightness.dark;
    final playingLabel = _playingSectionIndex >= 0 && _playingSectionIndex < _sections.length
        ? _sections[_playingSectionIndex].title
        : '考点知识';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _playAllKnowledge,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isPlayingKnowledge ? Colors.red : color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPlayingKnowledge ? Icons.stop_rounded : Icons.playlist_play_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isPlayingKnowledge ? '正在播放' : '点击播放全部',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (_isPlayingKnowledge)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playingLabel,
                          style: TextStyle(fontSize: 12, color: color),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (_currentChunkCount > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '第 ${_playingSectionIndex + 1} / ${_sections.length} 节 · 当前段 ${_currentChunkIndex + 1} / $_currentChunkCount',
                                style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _currentChunkCount > 0
                                      ? (_currentChunkIndex + 1) / _currentChunkCount
                                      : 0,
                                  minHeight: 6,
                                  backgroundColor: color.withOpacity(0.14),
                                  valueColor: AlwaysStoppedAnimation<Color>(color),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_isPlayingKnowledge)
            GestureDetector(
              onTap: _stopKnowledgePlayback,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                ),
              ),
            ),
        ],
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