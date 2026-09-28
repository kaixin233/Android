import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:provider/provider.dart';

import '../data/textbooks.dart';
import '../models/question.dart';
import '../models/history_item.dart';
import '../models/knowledge_point.dart';
import '../providers/app_provider.dart';
import '../services/question_loader.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../services/ai_question_service.dart';
import '../services/knowledge_service.dart';
import '../services/annotation_store.dart';
import '../utils/ai_assistant_launcher.dart';
import '../utils/knowledge_playback_mixin.dart';
import '../widgets/ask_ai_selection_area.dart';
import '../widgets/annotated_text.dart';
import 'ai_generate_page.dart';
import 'practice_page.dart';

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
    with SingleTickerProviderStateMixin,
        KnowledgePlaybackMixin<SubsectionDetailPage> {
  bool _isLoading = true;
  List<String> _questionKnowledgePoints = [];
  int _questionCount = 0;
  bool _isSubsectionLevel = false;
  List<KnowledgeSection> _knowledgeSections = [];
  late TabController _tabController;
  // 知识点练习状态：key = 知识点名称, value = 统计数据
  Map<String, KnowledgePointStats> _kpStats = {};

  // 考点阅读进度（滚动位置）记忆
  final ScrollController _knowledgeScrollController = ScrollController();
  Timer? _readingOffsetTimer;
  bool _readingOffsetRestored = false;
  String get _readingKey =>
      '${widget.subject.name}|${widget.chapterNumber}|${widget.subsection.number}';

  // 「从当前位置朗读」与「跟随朗读」：用于定位当前小节/段落
  final GlobalKey _knowledgeListKey = GlobalKey();
  final List<GlobalKey> _sectionKeys = [];

  /// 用于从 AppBar 打开目录抽屉
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  List<KnowledgeSection> get playbackSections => _knowledgeSections;

  /// 目录高亮用：当前所处小节号
  String? get _tocCurrentSubsection => widget.subsection.number;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    // 预热 TTS 引擎，避免首次点击朗读时出现明显延迟
    initKnowledgePlayback();
    // 确保用户批注已从本地加载到内存
    AnnotationStore.ensureLoaded();
    // 监听滚动以记录考点阅读进度
    _knowledgeScrollController.addListener(_onKnowledgeScroll);
    // 记录"上次阅读"，用于教材页"继续阅读"
    StorageService.saveLastRead(
      widget.subject.name,
      widget.chapterNumber,
      widget.subsection.number,
      widget.subsection.title,
    );
  }

  @override
  void dispose() {
    disposeKnowledgePlayback();
    // 保存最后的阅读位置
    _readingOffsetTimer?.cancel();
    if (_knowledgeScrollController.hasClients) {
      StorageService.saveReadingOffset(
          _readingKey, _knowledgeScrollController.offset);
    }
    _knowledgeScrollController.removeListener(_onKnowledgeScroll);
    _knowledgeScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// 滚动时（防抖 500ms）记录阅读位置；同时标记"用户手动滚动"时间
  void _onKnowledgeScroll() {
    if (_knowledgeScrollController.hasClients &&
        _knowledgeScrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      _lastUserScrollAt = DateTime.now();
    }
    _readingOffsetTimer?.cancel();
    _readingOffsetTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || !_knowledgeScrollController.hasClients) return;
      StorageService.saveReadingOffset(
          _readingKey, _knowledgeScrollController.offset);
    });
  }

  /// 恢复上次阅读的滚动位置
  Future<void> _restoreReadingOffset() async {
    if (_readingOffsetRestored) return;
    _readingOffsetRestored = true;
    final offset = await StorageService.loadReadingOffset(_readingKey);
    if (offset == null || offset <= 0) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_knowledgeScrollController.hasClients) return;
      final max = _knowledgeScrollController.position.maxScrollExtent;
      _knowledgeScrollController.jumpTo(offset.clamp(0.0, max));
    });
  }

  GlobalKey _sectionKey(int index) {
    while (_sectionKeys.length <= index) {
      _sectionKeys.add(GlobalKey());
    }
    return _sectionKeys[index];
  }

  /// 滚动到指定小节（目录导航与跟随朗读共用）
  void _scrollToSection(int index, {double alignment = 0.02}) {
    if (index < 0 || index >= _sectionKeys.length) return;
    final ctx = _sectionKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: alignment,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  /// 仅在内容明显离开视口时才滚动，避免朗读时"跳来跳去"
  void _ensureVisibleIfNeeded(BuildContext ctx) {
    final box = ctx.findRenderObject();
    final listBox = _knowledgeListKey.currentContext?.findRenderObject();
    if (box is! RenderBox || listBox is! RenderBox) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final vTop = listBox.localToGlobal(Offset.zero).dy;
    final vBottom = vTop + listBox.size.height;
    const margin = 28.0;
    if (top >= vTop + margin && bottom <= vBottom - margin) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  /// 朗读位置变化 → 让"当前所读内容"保持可见（仅在离开视口时滚动）
  @override
  void onPlaybackPositionChanged() {
    if (!isActiveKnowledge) return;
    // 跟随滚动：用户刚刚手动滚动过则不要"跟随"，避免把视图拉回旧位置
    if (_userScrollingRecently) return;
    final key = _paragraphKeys[_pKey(playingSectionIndex, playingParagraphIndex)];
    final ctx = key?.currentContext;
    if (ctx != null) {
      _ensureVisibleIfNeeded(ctx);
      return;
    }
    _scrollToSection(playingSectionIndex, alignment: 0.08);
  }

  /// 段落 GlobalKey 的键 = 小节下标 * 步长 + 段落下标
  static const int _paragraphKeyStride = 100000;
  final Map<int, GlobalKey> _paragraphKeys = {};

  int _pKey(int sectionIndex, int paragraphIndex) =>
      sectionIndex * _paragraphKeyStride + paragraphIndex;

  GlobalKey _paragraphKey(int sectionIndex, int paragraphIndex) =>
      _paragraphKeys.putIfAbsent(
          _pKey(sectionIndex, paragraphIndex), () => GlobalKey());

  /// 滚动到指定小节内的段落（目录跳转用）
  void _jumpToParagraph(int sectionIndex, int paragraphIndex) {
    if (paragraphIndex < 0) {
      _scrollToSection(sectionIndex, alignment: 0.05);
      return;
    }
    final ctx =
        _paragraphKeys[_pKey(sectionIndex, paragraphIndex)]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.06,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      return;
    }
    _scrollToSection(sectionIndex, alignment: 0.05);
  }

  /// 构建"当前内容细目"：小节 → 子标题(####) → 要点(**粗体**)，覆盖到每个点
  Map<String, List<_TocNode>> _buildDeepToc() {
    final map = <String, List<_TocNode>>{};
    for (var si = 0; si < playbackSections.length; si++) {
      final sec = playbackSections[si];
      final nodes = <_TocNode>[];
      for (var pi = 0; pi < sec.paragraphs.length; pi++) {
        final p = sec.paragraphs[pi];
        if (p.isSubheading) {
          nodes.add(_TocNode(
            title: p.text,
            sectionIndex: si,
            paragraphIndex: pi,
            level: 3,
          ));
        } else if (p.isBold) {
          final node = _TocNode(
            title: p.text,
            sectionIndex: si,
            paragraphIndex: pi,
            level: 4,
          );
          if (nodes.isNotEmpty && nodes.last.level == 3) {
            nodes.last.children.add(node);
          } else {
            nodes.add(node);
          }
        }
      }
      map[sec.number] = nodes;
    }
    return map;
  }

  bool _drawerSwipeArmed = false;

  /// 包裹页面主体，实现"**向右滑动打开目录**"。
  ///
  /// 关键：**不限制起手位置**（此前限制在左侧 25%，用户在屏幕中部右滑无效）；
  /// 只要向右水平拖动即打开。页面内的横向滚动已关闭，故不会误触。
  Widget _wrapDrawerSwipe(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _drawerSwipeArmed = true,
      onHorizontalDragUpdate: (d) {
        if (_drawerSwipeArmed && d.delta.dx > 0) {
          _drawerSwipeArmed = false;
          _scaffoldKey.currentState?.openDrawer();
        }
      },
      onHorizontalDragEnd: (_) => _drawerSwipeArmed = false,
      onHorizontalDragCancel: () => _drawerSwipeArmed = false,
      child: child,
    );
  }

  // ===== 朗读起点：从当前可见位置 =====

  bool _pickStartMode = false;
  DateTime? _lastUserScrollAt;

  /// 用户是否**正在或刚刚**手动滚动过。
  ///
  /// 用 [ScrollPosition.userScrollDirection] 区分"手指拖动"与"程序跟随滚动"，
  /// 避免把用户滚到的新位置又拉回正在朗读的旧位置。
  bool get _userScrollingRecently {
    if (_knowledgeScrollController.hasClients &&
        _knowledgeScrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      return true;
    }
    return _lastUserScrollAt != null &&
        DateTime.now().difference(_lastUserScrollAt!) <
            const Duration(milliseconds: 2000);
  }

  /// 从指定小节/段落开始连续朗读
  Future<void> _playFromPosition(int section, int paragraph) async {
    if (playbackSections.isEmpty) return;
    final s = section.clamp(0, playbackSections.length - 1);
    // 先停止（含在途的旧朗读与延迟回调），再起播，确保不会"接着读旧内容"
    await stopKnowledgePlayback();
    if (!mounted) return;
    setKnowledgeAnchor(s);
    await reader.startFrom(s, startParagraph: paragraph);
    if (!mounted) return;
    final title = playbackSections[s].title;
    final label = paragraph >= 0 ? '第 ${paragraph + 1} 段' : '开头';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('从「$title」$label 开始朗读'),
      ),
    );
  }

  /// 全量考点目录抽屉（科目 → 章 → 节）；支持从屏幕左侧向右滑动打开
  Widget _buildTocDrawer() {
    final book = Textbooks.all.firstWhere(
      (b) => b.subject == widget.subject,
      orElse: () => Textbooks.all.first,
    );
    return _KnowledgeTocDrawer(
      book: book,
      color: Color(widget.bookColor),
      currentChapter: widget.chapterNumber,
      currentSubsection: _tocCurrentSubsection,
      onPick: _openFromToc,
      onJump: _jumpToParagraph,
      deepBySubsection: _buildDeepToc(),
      onPlayAll: playAllFromStart,
      playingSectionNumber: playingSectionNumber,
      pickStartMode: _pickStartMode,
      onTogglePickStart: () {
        Navigator.of(context).pop();
        setState(() => _pickStartMode = !_pickStartMode);
      },
    );
  }

  /// 目录导航跳转：[subsectionNumber] 为 null 表示进入该章总览
  void _openFromToc(String chapterNumber, String? subsectionNumber) {
    final book = Textbooks.all.firstWhere(
      (b) => b.subject == widget.subject,
      orElse: () => Textbooks.all.first,
    );
    final chapter = book.chapters.firstWhere(
      (c) => c.number == chapterNumber,
      orElse: () => book.chapters.first,
    );
    if (subsectionNumber == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChapterKnowledgePage(
            subject: book.subject,
            chapterNumber: chapterNumber,
            chapterTitle: chapter.title,
            bookColor: widget.bookColor,
            bookTitle: widget.bookTitle,
          ),
        ),
      );
      return;
    }
    final subs = chapter.subsections;
    final target = subs.firstWhere(
      (s) => s.number == subsectionNumber,
      orElse: () => subs.isEmpty
          ? TextbookChapter(number: subsectionNumber, title: '', page: 0)
          : subs.first,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SubsectionDetailPage(
          subsection: target,
          chapterNumber: chapterNumber,
          subject: book.subject,
          bookColor: widget.bookColor,
          bookTitle: widget.bookTitle,
        ),
      ),
    );
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
      // 通知朗读控制器考点数据已就绪
      syncPlaybackSections();
      // 载入完成后恢复上次的阅读位置
      await _restoreReadingOffset();
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
      key: _scaffoldKey,
      drawer: _buildTocDrawer(),
      appBar: AppBar(
        title: Text('${widget.subsection.number} ${widget.subsection.title}'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: '目录导航（也可从左侧向右滑动打开）',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'AI 出题（本节）',
            onPressed: _openAiGenerate,
          ),
        ],
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
      body: _wrapDrawerSwipe(
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                // 关闭横向滑动：避免抢占"从左向右滑动打开目录"的手势
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildKnowledgeTab(theme, color),
                  _buildPracticeTab(theme, color),
                ],
              ),
      ),
    );
  }

  /// 打开 AI 出题（带当前小节上下文，生成题目自动归入本节）
  void _openAiGenerate() {
    final ctx = AiQuestionContext(
      subject: widget.subject,
      chapterNumber: widget.chapterNumber,
      subsection: widget.subsection.number,
      sectionTitle: widget.subsection.title,
      knowledgeContext: _knowledgeSections.isEmpty
          ? null
          : _knowledgeSections.map((s) => s.toPlainText()).join('\n').trim(),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiGeneratePage(predefinedContext: ctx)),
    );
  }

  /// 考点知识 Tab - 展示从HTML解析的考点内容
  Widget _buildKnowledgeTab(ThemeData theme, Color color) {
    if (_knowledgeSections.isEmpty) {
      return _buildEmptyState('暂无考点知识内容', icon: Icons.menu_book_outlined);
    }

    return Stack(
      children: [
        // 一次性构建全部小节：使目录跳转与"跟随朗读"能精确定位目标
        ListView(
          key: _knowledgeListKey,
          controller: _knowledgeScrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            for (var index = 0;
                index < _knowledgeSections.length;
                index++)
              KeyedSubtree(
                key: _sectionKey(index),
                child: _KnowledgeSectionCard(
                  section: _knowledgeSections[index],
                  color: color,
                  subject: widget.subject,
                  chapterNumber: widget.chapterNumber,
                  isPlaying: isPlayingKnowledge && playingSectionIndex == index,
                  isSectionActive:
                      isActiveKnowledge && playingSectionIndex == index,
                  paragraphKeyOf: (pi) => _paragraphKey(index, pi),
                  highlightParagraphIndex:
                      isActiveKnowledge && playingSectionIndex == index
                          ? playingParagraphIndex
                          : -1,
                  highlightStart: highlightStart,
                  highlightEnd: highlightEnd,
                  showPlayButton: _pickStartMode,
                  onPlayFromParagraph: (pi) => _playFromPosition(index, pi),
                  playingParagraphIndex:
                      isActiveKnowledge && playingSectionIndex == index
                          ? playingParagraphIndex
                          : -1,
                  onPlayTap: () => playSection(index),
                  onPlayFromHere: () => playFromSection(index),
                  onAskAi: (text) => _askAiAboutSection(
                      _knowledgeSections[index],
                      selectedText: text),
                  onAskAiWhole: () =>
                      _askAiAboutSection(_knowledgeSections[index]),
                  onAnnotate: (text) =>
                      _annotateSection(_knowledgeSections[index], text),
                  onAnnotationsChanged: () => setState(() {}),
                ),
              ),
          ],
        ),
        // 右下角悬浮：从当前位置朗读 + 播放全部（紧凑，不占整行）
        Positioned(
          right: 16,
          bottom: 16,
          child: buildKnowledgePlaybackBar(theme, color),
        ),
      ],
    );
  }

  /// 以考点小节为上下文向 AI 提问（[selectedText] 为用户选中的片段）
  void _askAiAboutSection(KnowledgeSection section, {String? selectedText}) {
    AiAssistantLauncher.showForKnowledgeSection(
      context,
      subject: widget.subject,
      chapterNumber: widget.chapterNumber,
      section: section,
      selectedText: selectedText,
    );
  }

  /// 为选中文本添加/编辑用户批注。term 为用户选中的短语（整节级批注）。
  Future<void> _annotateSection(KnowledgeSection section, String term) async {
    final result = await AnnotatedText.showNoteDialog(context, term, '');
    if (result == null || result.note.isEmpty) return;
    await AnnotationStore.upsert(UserAnnotation(
      subject: widget.subject.name,
      chapterNumber: widget.chapterNumber,
      sectionNumber: section.number,
      paragraphIndex: -1,
      term: term,
      note: result.note,
      scope: result.scope,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (mounted) setState(() {});
  }
  Widget _buildPracticeTab(ThemeData theme, Color color) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 小节信息卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
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
                  const Icon(Icons.bookmark_rounded, color: Colors.white, size: 28),
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
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
        color: isDark ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: status == _KPStatus.unpracticed ? 0.15 : 0.3),
        ),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 1))],
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
                  color: color.withValues(alpha: 0.1),
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
                            color: statusColor.withValues(alpha: 0.12),
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
                  color: color.withValues(alpha: 0.1),
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
    required this.subject,
    required this.chapterNumber,
    this.isPlaying = false,
    this.isSectionActive = false,
    this.paragraphKeyOf,
    this.highlightParagraphIndex = -1,
    this.highlightStart = 0,
    this.highlightEnd = 0,
    this.showPlayButton = false,
    this.onPlayFromParagraph,
    this.playingParagraphIndex = -1,
    this.onPlayTap,
    this.onPlayFromHere,
    this.onAskAi,
    this.onAskAiWhole,
    this.onAnnotate,
    this.onAnnotationsChanged,
  });

  final KnowledgeSection section;
  final Color color;
  final QuestionSubject subject;
  final String chapterNumber;
  final bool isPlaying;

  /// 本节是否为"当前朗读小节"（含暂停态，用于保持高亮）
  final bool isSectionActive;

  /// 正在朗读的段落下标（-1 表示无）：该段加淡色底 + 句内**逐字高亮**
  final int highlightParagraphIndex;

  /// 段落内字符高亮区间（左闭右开），由页面按朗读进度推进
  final int highlightStart;
  final int highlightEnd;

  /// 为每个段落提供 GlobalKey（段落级"从当前位置朗读"与目录跳转定位用）
  final GlobalKey? Function(int paragraphIndex)? paragraphKeyOf;

  /// 是否在每个段落前显示"从这里朗读"入口（"选择起始段"模式）
  final bool showPlayButton;

  /// 点击"从这里朗读"回调（参数为段落下标）
  final ValueChanged<int>? onPlayFromParagraph;

  /// 当前正在朗读的段落下标（-1 表示无），用于高亮"当前所读内容"
  final int playingParagraphIndex;

  final VoidCallback? onPlayTap;

  /// 点击"从本节开始播放"回调（从指定位置连续播放到末尾）
  final VoidCallback? onPlayFromHere;

  /// 选中部分段落后点击"问 AI"的回调，参数为选中文本
  final ValueChanged<String>? onAskAi;

  /// 以整个小节内容为上下文向 AI 提问的回调
  final VoidCallback? onAskAiWhole;

  /// 选中部分段落后点击"加注释"的回调，参数为选中文本
  final ValueChanged<String>? onAnnotate;

  /// 用户批注增删后回调（用于刷新卡片高亮）
  final VoidCallback? onAnnotationsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSectionActive ? color : color.withValues(alpha: 0.15),
          width: isSectionActive ? 2 : 1,
        ),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小节标题
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: isPlaying ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
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
                // AI 提问按钮（以整节内容为上下文）
                if (onAskAiWhole != null) ...[
                  GestureDetector(
                    onTap: onAskAiWhole,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // 播放按钮
                if (onPlayTap != null)
                  GestureDetector(
                    onTap: onPlayTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isPlaying ? color : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : (isSectionActive
                                ? Icons.play_arrow_rounded
                                : Icons.volume_up_rounded),
                        color: isPlaying || isSectionActive ? Colors.white : color,
                        size: 20,
                      ),
                    ),
                  ),
                // 从本节开始连续播放（指定位置开始播放）
                if (onPlayFromHere != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Tooltip(
                      message: '从本节开始连续播放',
                      child: GestureDetector(
                        onTap: onPlayFromHere,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.playlist_play_rounded,
                              color: color, size: 20),
                        ),
                      ),
                    ),
                  ),
                // 书签按钮
                if (onAnnotate != null)
                  GestureDetector(
                    onTap: () => _toggleBookmark(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.bookmark_outline_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 段落内容（支持选中文本后"问 AI" / "加注释"）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: AskAiSelectionArea(
              onAskAi: onAskAi ?? (_) {},
              extraActions: onAnnotate == null
                  ? const []
                  : [SelectionAction(label: '加注释', onSelected: onAnnotate!)],
              child: _buildParagraphs(context, theme, isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// 点击配图查看大图（可双指缩放/拖动）。
  void _showImageZoom(BuildContext context, String imagePath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('查看大图'),
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.asset(
                'assets/knowledge/$imagePath',
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 切换当前小节的阅读书签。
  Future<void> _toggleBookmark(BuildContext context) async {
    final id = '${subject.name}_$chapterNumber}_${section.number}';
    final bookmarked = await StorageService.toggleBookmark({
      'id': id,
      'subject': subject.name,
      'chapterNumber': chapterNumber,
      'sectionNumber': section.number,
      'title': section.title,
      'savedAt': DateTime.now().toIso8601String(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(bookmarked ? '已加入书签' : '已移除书签')),
      );
    }
  }

  /// 段落基础文字样式（按标题/子标题/加粗区分）
  /// 行内逐字高亮：把 [text] 中第 [highlightStart, highlightEnd) 个字符加底色。
  ///
  /// 只改背景色，**不改变字体度量与换行**，因此不会像"拆句成行"那样挤压页面。
  Widget _inlineHighlighted(
    String text,
    int paragraphIndex,
    TextStyle style,
    bool isDark,
  ) {
    if (paragraphIndex != highlightParagraphIndex ||
        highlightEnd <= highlightStart ||
        text.isEmpty) {
      return Text(text, style: style);
    }
    final s = highlightStart.clamp(0, text.length);
    final e = highlightEnd.clamp(0, text.length);
    if (s >= e) return Text(text, style: style);
    final hl = style.copyWith(
      backgroundColor: isDark
          ? const Color(0xFF2E7D6B).withValues(alpha: 0.75)
          : const Color(0xFFB2F5E4),
    );
    return Text.rich(
      TextSpan(children: [
        if (s > 0) TextSpan(text: text.substring(0, s), style: style),
        TextSpan(text: text.substring(s, e), style: hl),
        if (e < text.length) TextSpan(text: text.substring(e), style: style),
      ]),
    );
  }

  Widget _buildParagraphs(BuildContext context, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(section.paragraphs.length, (i) {
        final p = section.paragraphs[i];
        Widget widget = _buildOneParagraph(context, theme, isDark, i, p);
        // "选择起始段"模式：每段给出"从这里朗读"入口（比自动定位更精确、可控）
        if (showPlayButton && p.imagePath == null) {
          widget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => onPlayFromParagraph?.call(i),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill_rounded,
                          size: 15, color: color),
                      const SizedBox(width: 4),
                      Text('从这里朗读',
                          style: TextStyle(fontSize: 11, color: color)),
                    ],
                  ),
                ),
              ),
              widget,
            ],
          );
        }
        // 挂载段落 GlobalKey：供"从当前位置朗读"做段落级定位与目录跳转
        final key = paragraphKeyOf?.call(i);
        return key == null ? widget : KeyedSubtree(key: key, child: widget);
      }),
    );
  }

  /// 渲染单个段落
  Widget _buildOneParagraph(BuildContext context, ThemeData theme, bool isDark,
      int i, KnowledgeParagraph p) {
        // 图片段落
        if (p.imagePath != null) {
          final imagePath = p.imagePath!;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: () => _showImageZoom(context, imagePath),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/knowledge/$imagePath',
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
                                '图片缺失：$imagePath',
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
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.zoom_in_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
          );
        }
        final isActive = i == highlightParagraphIndex;
        Widget body;
        if (p.isHeading) {
          body = Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: _inlineHighlighted(
              p.text,
              i,
              TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.blue.shade200 : color,
              ),
              isDark,
            ),
          );
        } else if (p.isSubheading) {
          body = Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: _inlineHighlighted(
              p.text,
              i,
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? Colors.teal.shade200 : color.withValues(alpha: 0.8),
              ),
              isDark,
            ),
          );
        } else if (p.isBold) {
          body = Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: _inlineHighlighted(
              p.text,
              i,
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? Colors.orange.shade200 : Colors.red.shade700,
              ),
              isDark,
            ),
          );
        } else {
          body = Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: AnnotatedText(
              paragraph: p,
              subject: subject,
              chapterNumber: chapterNumber,
              section: section,
              userAnnotations: AnnotationStore.annotationsForSection(
                subject.name,
                chapterNumber,
                section.number,
              ),
              color: color,
              // 行内逐字高亮：只加背景色，不改变字体度量与换行
              highlightStart: isActive ? highlightStart : null,
              highlightEnd: isActive ? highlightEnd : null,
              onAskAi: onAskAi == null
                  ? null
                  : (text) => onAskAi!(text),
              onAnnotationsChanged: onAnnotationsChanged,
            ),
          );
        }

        // 正在朗读的段落：加淡色底帮助定位（仅背景，不改变尺寸与换行）
        if (!isActive) return body;
        return Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.10 : 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: body,
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

class _ChapterKnowledgePageState extends State<ChapterKnowledgePage>
    with KnowledgePlaybackMixin<ChapterKnowledgePage> {
  /// 以考点小节为上下文向 AI 提问（[selectedText] 为用户选中的片段）
  void _askAiAboutSection(KnowledgeSection section, {String? selectedText}) {
    AiAssistantLauncher.showForKnowledgeSection(
      context,
      subject: widget.subject,
      chapterNumber: widget.chapterNumber,
      section: section,
      selectedText: selectedText,
    );
  }

  /// 为选中文本添加/编辑用户批注。term 为用户选中的短语（整节级批注）。
  Future<void> _annotateSection(KnowledgeSection section, String term) async {
    final result = await AnnotatedText.showNoteDialog(context, term, '');
    if (result == null || result.note.isEmpty) return;
    await AnnotationStore.upsert(UserAnnotation(
      subject: widget.subject.name,
      chapterNumber: widget.chapterNumber,
      sectionNumber: section.number,
      paragraphIndex: -1,
      term: term,
      note: result.note,
      scope: result.scope,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (mounted) setState(() {});
  }

  bool _isLoading = true;
  List<KnowledgeSection> _sections = [];

  // 考点阅读进度（滚动位置）记忆
  final ScrollController _knowledgeScrollController = ScrollController();
  Timer? _readingOffsetTimer;
  bool _readingOffsetRestored = false;
  String get _readingKey =>
      '${widget.subject.name}|${widget.chapterNumber}|__chapter__';

  // 「从当前位置朗读」与「跟随朗读」：用于定位当前小节/段落
  final GlobalKey _knowledgeListKey = GlobalKey();
  final List<GlobalKey> _sectionKeys = [];

  /// 用于从 AppBar 打开目录抽屉
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  List<KnowledgeSection> get playbackSections => _sections;

  /// 目录高亮用：本章总览（无具体小节）
  String? get _tocCurrentSubsection => null;

  @override
  void initState() {
    super.initState();
    _loadData();
    // 预热 TTS 引擎，避免首次点击朗读时出现明显延迟
    initKnowledgePlayback();
    // 确保用户批注已从本地加载到内存
    AnnotationStore.ensureLoaded();
    // 监听滚动以记录考点阅读进度
    _knowledgeScrollController.addListener(_onKnowledgeScroll);
    // 记录"上次阅读"（章节级），用于教材页"继续阅读"
    StorageService.saveLastRead(
      widget.subject.name,
      widget.chapterNumber,
      '',
      '第${widget.chapterNumber}章 考点知识',
    );
  }

  @override
  void dispose() {
    disposeKnowledgePlayback();
    _readingOffsetTimer?.cancel();
    if (_knowledgeScrollController.hasClients) {
      StorageService.saveReadingOffset(
          _readingKey, _knowledgeScrollController.offset);
    }
    _knowledgeScrollController.removeListener(_onKnowledgeScroll);
    _knowledgeScrollController.dispose();
    super.dispose();
  }

  void _onKnowledgeScroll() {
    _readingOffsetTimer?.cancel();
    _readingOffsetTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || !_knowledgeScrollController.hasClients) return;
      StorageService.saveReadingOffset(
          _readingKey, _knowledgeScrollController.offset);
    });
  }

  Future<void> _restoreReadingOffset() async {
    if (_readingOffsetRestored) return;
    _readingOffsetRestored = true;
    final offset = await StorageService.loadReadingOffset(_readingKey);
    if (offset == null || offset <= 0) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_knowledgeScrollController.hasClients) return;
      final max = _knowledgeScrollController.position.maxScrollExtent;
      _knowledgeScrollController.jumpTo(offset.clamp(0.0, max));
    });
  }

  GlobalKey _sectionKey(int index) {
    while (_sectionKeys.length <= index) {
      _sectionKeys.add(GlobalKey());
    }
    return _sectionKeys[index];
  }

  /// 滚动到指定小节（目录导航与跟随朗读共用）
  void _scrollToSection(int index, {double alignment = 0.02}) {
    if (index < 0 || index >= _sectionKeys.length) return;
    final ctx = _sectionKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: alignment,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  /// 仅在内容明显离开视口时才滚动，避免朗读时"跳来跳去"
  void _ensureVisibleIfNeeded(BuildContext ctx) {
    final box = ctx.findRenderObject();
    final listBox = _knowledgeListKey.currentContext?.findRenderObject();
    if (box is! RenderBox || listBox is! RenderBox) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final vTop = listBox.localToGlobal(Offset.zero).dy;
    final vBottom = vTop + listBox.size.height;
    const margin = 28.0;
    if (top >= vTop + margin && bottom <= vBottom - margin) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.35,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  /// 朗读位置变化 → 让"当前所读内容"保持可见（仅在离开视口时滚动）
  @override
  void onPlaybackPositionChanged() {
    if (!isActiveKnowledge) return;
    // 跟随滚动：用户刚刚手动滚动过则不要"跟随"，避免把视图拉回旧位置
    if (_userScrollingRecently) return;
    final key = _paragraphKeys[_pKey(playingSectionIndex, playingParagraphIndex)];
    final ctx = key?.currentContext;
    if (ctx != null) {
      _ensureVisibleIfNeeded(ctx);
      return;
    }
    _scrollToSection(playingSectionIndex, alignment: 0.08);
  }

  /// 段落 GlobalKey 的键 = 小节下标 * 步长 + 段落下标
  static const int _paragraphKeyStride = 100000;
  final Map<int, GlobalKey> _paragraphKeys = {};

  int _pKey(int sectionIndex, int paragraphIndex) =>
      sectionIndex * _paragraphKeyStride + paragraphIndex;

  GlobalKey _paragraphKey(int sectionIndex, int paragraphIndex) =>
      _paragraphKeys.putIfAbsent(
          _pKey(sectionIndex, paragraphIndex), () => GlobalKey());

  /// 滚动到指定小节内的段落（目录跳转用）
  void _jumpToParagraph(int sectionIndex, int paragraphIndex) {
    if (paragraphIndex < 0) {
      _scrollToSection(sectionIndex, alignment: 0.05);
      return;
    }
    final ctx =
        _paragraphKeys[_pKey(sectionIndex, paragraphIndex)]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.06,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      return;
    }
    _scrollToSection(sectionIndex, alignment: 0.05);
  }

  /// 构建"当前内容细目"：小节 → 子标题(####) → 要点(**粗体**)，覆盖到每个点
  Map<String, List<_TocNode>> _buildDeepToc() {
    final map = <String, List<_TocNode>>{};
    for (var si = 0; si < playbackSections.length; si++) {
      final sec = playbackSections[si];
      final nodes = <_TocNode>[];
      for (var pi = 0; pi < sec.paragraphs.length; pi++) {
        final p = sec.paragraphs[pi];
        if (p.isSubheading) {
          nodes.add(_TocNode(
            title: p.text,
            sectionIndex: si,
            paragraphIndex: pi,
            level: 3,
          ));
        } else if (p.isBold) {
          final node = _TocNode(
            title: p.text,
            sectionIndex: si,
            paragraphIndex: pi,
            level: 4,
          );
          if (nodes.isNotEmpty && nodes.last.level == 3) {
            nodes.last.children.add(node);
          } else {
            nodes.add(node);
          }
        }
      }
      map[sec.number] = nodes;
    }
    return map;
  }

  bool _drawerSwipeArmed = false;

  /// 包裹页面主体，实现"**向右滑动打开目录**"。
  ///
  /// 关键：**不限制起手位置**（此前限制在左侧 25%，用户在屏幕中部右滑无效）；
  /// 只要向右水平拖动即打开。页面内的横向滚动已关闭，故不会误触。
  Widget _wrapDrawerSwipe(Widget child) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _drawerSwipeArmed = true,
      onHorizontalDragUpdate: (d) {
        if (_drawerSwipeArmed && d.delta.dx > 0) {
          _drawerSwipeArmed = false;
          _scaffoldKey.currentState?.openDrawer();
        }
      },
      onHorizontalDragEnd: (_) => _drawerSwipeArmed = false,
      onHorizontalDragCancel: () => _drawerSwipeArmed = false,
      child: child,
    );
  }

  // ===== 朗读起点：从当前可见位置 =====

  bool _pickStartMode = false;
  DateTime? _lastUserScrollAt;

  /// 用户是否**正在或刚刚**手动滚动过。
  ///
  /// 用 [ScrollPosition.userScrollDirection] 区分"手指拖动"与"程序跟随滚动"，
  /// 避免把用户滚到的新位置又拉回正在朗读的旧位置。
  bool get _userScrollingRecently {
    if (_knowledgeScrollController.hasClients &&
        _knowledgeScrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      return true;
    }
    return _lastUserScrollAt != null &&
        DateTime.now().difference(_lastUserScrollAt!) <
            const Duration(milliseconds: 2000);
  }

  /// 从指定小节/段落开始连续朗读
  Future<void> _playFromPosition(int section, int paragraph) async {
    if (playbackSections.isEmpty) return;
    final s = section.clamp(0, playbackSections.length - 1);
    // 先停止（含在途的旧朗读与延迟回调），再起播，确保不会"接着读旧内容"
    await stopKnowledgePlayback();
    if (!mounted) return;
    setKnowledgeAnchor(s);
    await reader.startFrom(s, startParagraph: paragraph);
    if (!mounted) return;
    final title = playbackSections[s].title;
    final label = paragraph >= 0 ? '第 ${paragraph + 1} 段' : '开头';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('从「$title」$label 开始朗读'),
      ),
    );
  }

  /// 全量考点目录抽屉（科目 → 章 → 节）；支持从屏幕左侧向右滑动打开
  Widget _buildTocDrawer() {
    final book = Textbooks.all.firstWhere(
      (b) => b.subject == widget.subject,
      orElse: () => Textbooks.all.first,
    );
    return _KnowledgeTocDrawer(
      book: book,
      color: Color(widget.bookColor),
      currentChapter: widget.chapterNumber,
      currentSubsection: _tocCurrentSubsection,
      onPick: _openFromToc,
      onJump: _jumpToParagraph,
      deepBySubsection: _buildDeepToc(),
      onPlayAll: playAllFromStart,
      playingSectionNumber: playingSectionNumber,
      pickStartMode: _pickStartMode,
      onTogglePickStart: () {
        Navigator.of(context).pop();
        setState(() => _pickStartMode = !_pickStartMode);
      },
    );
  }

  /// 目录导航跳转：[subsectionNumber] 为 null 表示进入该章总览
  void _openFromToc(String chapterNumber, String? subsectionNumber) {
    final book = Textbooks.all.firstWhere(
      (b) => b.subject == widget.subject,
      orElse: () => Textbooks.all.first,
    );
    final chapter = book.chapters.firstWhere(
      (c) => c.number == chapterNumber,
      orElse: () => book.chapters.first,
    );
    if (subsectionNumber == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChapterKnowledgePage(
            subject: book.subject,
            chapterNumber: chapterNumber,
            chapterTitle: chapter.title,
            bookColor: widget.bookColor,
            bookTitle: widget.bookTitle,
          ),
        ),
      );
      return;
    }
    final subs = chapter.subsections;
    final target = subs.firstWhere(
      (s) => s.number == subsectionNumber,
      orElse: () => subs.isEmpty
          ? TextbookChapter(number: subsectionNumber, title: '', page: 0)
          : subs.first,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SubsectionDetailPage(
          subsection: target,
          chapterNumber: chapterNumber,
          subject: book.subject,
          bookColor: widget.bookColor,
          bookTitle: widget.bookTitle,
        ),
      ),
    );
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
        // 通知朗读控制器考点数据已就绪
        syncPlaybackSections();
        await _restoreReadingOffset();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(widget.bookColor);

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildTocDrawer(),
      appBar: AppBar(
        title: Text('第${widget.chapterNumber}章 考点知识'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: '目录导航（也可从左侧向右滑动打开）',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'AI 出题（本章）',
            onPressed: _openAiGenerate,
          ),
        ],
      ),
      body: _wrapDrawerSwipe(
        _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? _buildEmptyState()
              : Stack(
                  children: [
                    // 一次性构建全部小节：使目录跳转与"跟随朗读"能精确定位目标
                    ListView(
                      key: _knowledgeListKey,
                      controller: _knowledgeScrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: [
                        for (var index = 0; index < _sections.length; index++)
                          KeyedSubtree(
                            key: _sectionKey(index),
                            child: _KnowledgeSectionCard(
                              section: _sections[index],
                              color: color,
                              subject: widget.subject,
                              chapterNumber: widget.chapterNumber,
                              isPlaying: isPlayingKnowledge &&
                                  playingSectionIndex == index,
                              isSectionActive: isActiveKnowledge &&
                                  playingSectionIndex == index,
                              paragraphKeyOf: (pi) => _paragraphKey(index, pi),
                              highlightParagraphIndex: isActiveKnowledge &&
                                      playingSectionIndex == index
                                  ? playingParagraphIndex
                                  : -1,
                              highlightStart: highlightStart,
                              highlightEnd: highlightEnd,
                              showPlayButton: _pickStartMode,
                              onPlayFromParagraph: (pi) =>
                                  _playFromPosition(index, pi),
                              playingParagraphIndex: isActiveKnowledge &&
                                      playingSectionIndex == index
                                  ? playingParagraphIndex
                                  : -1,
                              onPlayTap: () => playSection(index),
                              onPlayFromHere: () => playFromSection(index),
                              onAskAi: (text) => _askAiAboutSection(
                                  _sections[index],
                                  selectedText: text),
                              onAskAiWhole: () =>
                                  _askAiAboutSection(_sections[index]),
                              onAnnotate: (text) =>
                                  _annotateSection(_sections[index], text),
                              onAnnotationsChanged: () => setState(() {}),
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: buildKnowledgePlaybackBar(theme, color),
                    ),
                  ],
                ),
      ),
    );
  }
  /// 打开 AI 出题（带本章上下文）
  void _openAiGenerate() {
    final ctx = AiQuestionContext(
      subject: widget.subject,
      chapterNumber: widget.chapterNumber,
      sectionTitle: '第${widget.chapterNumber}章',
      knowledgeContext: _sections.isEmpty
          ? null
          : _sections.map((s) => s.toPlainText()).join('\n').trim(),
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiGeneratePage(predefinedContext: ctx)),
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
  final Map<String, bool> _completedChapters = {};
  final Map<String, int> _chapterQuestionCounts = {};
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
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
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
        side: BorderSide(color: color.withValues(alpha: enabled ? 0.3 : 0.1)),
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
                  color: color.withValues(alpha: enabled ? 0.15 : 0.05),
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
                        color: color.withValues(alpha: 0.1),
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
                      icon: Icon(Icons.menu_book_rounded, color: color.withValues(alpha: 0.7)),
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
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
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
                          color: color.withValues(alpha: 0.4),
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
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
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

/// 目录节点（覆盖到最细层级：#### 子标题 与 **加粗要点**）
class _TocNode {
  _TocNode({
    required this.title,
    required this.sectionIndex,
    required this.paragraphIndex,
    required this.level,
  });

  final String title;
  final int sectionIndex;
  final int paragraphIndex;

  /// 3 = 子标题（#### X.Y.Z）；4 = 要点（**1. xxx**）
  final int level;
  final List<_TocNode> children = [];
}

/// 全量考点目录抽屉：按「科目 → 章 → 节 → 子标题 → 要点」四级展示。
///
/// 设计目标：
/// - **层级清晰**：四级用不同缩进、不同标记（章号方块 / 节号 / 子标题点 / 要点小点）
///   并配左侧引导线，一眼看出从属关系；
/// - **当前位置可见**：当前章用主色左强调条 + 淡底，当前小节加粗着色并带喇叭标记，
///   正在朗读的小节同步标记；打开抽屉时**自动滚动定位到当前项**；
/// - 由 `Scaffold.drawer` 承载，**从屏幕左侧向右滑动或点 AppBar 图标**均可打开。
class _KnowledgeTocDrawer extends StatefulWidget {
  const _KnowledgeTocDrawer({
    required this.book,
    required this.color,
    required this.currentChapter,
    required this.currentSubsection,
    required this.onPick,
    required this.onJump,
    required this.deepBySubsection,
    required this.onPlayAll,
    required this.pickStartMode,
    required this.onTogglePickStart,
    this.playingSectionNumber,
  });

  final Textbook book;
  final Color color;

  /// 当前所在章号（打开此页面的章）
  final String currentChapter;

  /// 当前所在小节号（null 表示"本章总览"）
  final String? currentSubsection;

  final void Function(String chapterNumber, String? subsectionNumber) onPick;

  /// 跳转到当前已加载内容的指定小节/段落
  final void Function(int sectionIndex, int paragraphIndex) onJump;

  /// 小节号 → 该小节的细目（子标题/要点），仅当前已加载的内容有值
  final Map<String, List<_TocNode>> deepBySubsection;

  /// 从头播放全部考点
  final VoidCallback onPlayAll;

  /// 正在朗读的小节号（用于标记"正在朗读"）
  final String? playingSectionNumber;

  /// 是否处于"选择起始段"模式
  final bool pickStartMode;
  final VoidCallback onTogglePickStart;

  @override
  State<_KnowledgeTocDrawer> createState() => _KnowledgeTocDrawerState();
}

class _KnowledgeTocDrawerState extends State<_KnowledgeTocDrawer> {
  final ScrollController _scroll = ScrollController();

  /// 当前小节的定位 Key（打开时自动滚动到它）
  final GlobalKey _currentSubKey = GlobalKey();
  final GlobalKey _currentChKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    final ctx = _currentSubKey.currentContext ?? _currentChKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.18,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, widget.color),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                children: [
                  for (final ch in widget.book.chapters)
                    _buildChapter(context, theme, ch),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 头部：标题 + 当前位置 + 朗读入口 =====
  Widget _buildHeader(ThemeData theme, Color color) {
    final chTitle = _chapterTitle(widget.currentChapter);
    final ss = widget.currentSubsection;
    final ssTitle = ss == null ? null : _subsectionTitle(ss);
    final playing = widget.playingSectionNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: color.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.book.subject.label} · 考点目录',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Text(
                '${widget.book.chapters.length} 章',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 当前位置
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.my_location_rounded, size: 13, color: color),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '当前位置：第${widget.currentChapter}章 ${chTitle ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        ss == null ? '本章考点总览' : '$ss ${ssTitle ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (playing != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.volume_up_rounded,
                                size: 11, color: Colors.orange),
                            const SizedBox(width: 3),
                            Text(
                              '正在朗读 $playing',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onPlayAll();
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  label: const Text('从头播放', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onTogglePickStart,
                  icon: Icon(
                    widget.pickStartMode
                        ? Icons.check_circle_rounded
                        : Icons.touch_app_rounded,
                    size: 17,
                  ),
                  label: Text(
                    widget.pickStartMode ? '选择起始段（已开启）' : '选择起始段',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.pickStartMode ? Colors.teal : color,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          if (widget.pickStartMode) ...[
            const SizedBox(height: 6),
            Text(
              '已开启：关闭抽屉后，正文每段上方会出现「从这里朗读」',
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  String? _chapterTitle(String number) {
    for (final c in widget.book.chapters) {
      if (c.number == number) return c.title;
    }
    return null;
  }

  String? _subsectionTitle(String number) {
    for (final c in widget.book.chapters) {
      for (final s in c.subsections) {
        if (s.number == number) return s.title;
      }
    }
    return null;
  }

  // ===== 第 1 级：章 =====
  Widget _buildChapter(
      BuildContext context, ThemeData theme, TextbookChapter ch) {
    final isCur = ch.number == widget.currentChapter;
    final isPlaying = widget.playingSectionNumber != null &&
        widget.playingSectionNumber!.split('.').first == ch.number;

    return Container(
      key: isCur ? _currentChKey : null,
      decoration: BoxDecoration(
        color: isCur ? widget.color.withValues(alpha: 0.07) : null,
        border: Border(
          left: BorderSide(
            color: isCur ? widget.color : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      child: Theme(
        // 去掉 ExpansionTile 默认分隔线，避免与层级引导线打架
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('toc_ch_${ch.number}'),
          initiallyExpanded: isCur,
          tilePadding: const EdgeInsets.only(left: 10, right: 10),
          childrenPadding: EdgeInsets.zero,
          leading: _levelBadge(ch.number, filled: isCur, size: 26),
          title: Text(
            ch.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.25,
              fontWeight: isCur ? FontWeight.bold : FontWeight.w600,
              color: isCur ? widget.color : null,
            ),
          ),
          subtitle: Text(
            '${ch.subsections.length} 节',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
          trailing: isPlaying
              ? const Icon(Icons.volume_up_rounded,
                  size: 16, color: Colors.orange)
              : null,
          children: [
            _buildChapterOverview(context, ch, isCur),
            for (final ss in ch.subsections)
              _buildSubsection(context, theme, ss),
          ],
        ),
      ),
    );
  }

  /// 本章考点总览（第 2 级的一个特殊项）
  Widget _buildChapterOverview(
      BuildContext context, TextbookChapter ch, bool isCurCh) {
    final isCur = isCurCh && widget.currentSubsection == null;
    return _levelRow(
      indent: 14,
      leading: Icon(Icons.dashboard_outlined,
          size: 15, color: isCur ? widget.color : Colors.grey.shade500),
      title: '本章考点总览',
      subtitle: '(${ch.number}.x)',
      emphasized: isCur,
      onTap: () {
        Navigator.of(context).pop();
        widget.onPick(ch.number, null);
      },
    );
  }

  // ===== 第 2 级：节 =====
  Widget _buildSubsection(
      BuildContext context, ThemeData theme, TextbookChapter ss) {
    final color = widget.color;
    final isCur = ss.number == widget.currentSubsection;
    final isPlaying = ss.number == widget.playingSectionNumber;
    final deep = widget.deepBySubsection[ss.number] ?? const <_TocNode>[];

    if (deep.isEmpty) {
      return _levelRow(
        key: isCur ? _currentSubKey : null,
        indent: 14,
        leading: _levelBadge(ss.number, filled: isCur, size: 0),
        title: '${ss.number} ${ss.title}',
        emphasized: isCur,
        playing: isPlaying,
        onTap: () {
          Navigator.of(context).pop();
          widget.onPick(ss.number.split('.').first, ss.number);
        },
      );
    }

    return Container(
      key: isCur ? _currentSubKey : null,
      margin: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: color.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isCur,
          tilePadding: const EdgeInsets.only(left: 6, right: 10),
          childrenPadding: const EdgeInsets.only(bottom: 4),
          title: Text(
            '${ss.number} ${ss.title}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.25,
              fontWeight: isCur ? FontWeight.bold : FontWeight.w500,
              color: isCur ? color : null,
            ),
          ),
          subtitle: Text(
            '${deep.length} 个细目',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          trailing: isPlaying
              ? const Icon(Icons.volume_up_rounded,
                  size: 16, color: Colors.orange)
              : null,
          children: [
            for (final n in deep) ..._buildDeepNodes(context, n),
          ],
        ),
      ),
    );
  }

  // ===== 第 3/4 级：子标题（####）与要点（**粗体**） =====
  List<Widget> _buildDeepNodes(BuildContext context, _TocNode n) {
    final color = widget.color;
    final isSub = n.level == 3;
    final rows = <Widget>[
      _levelRow(
        indent: isSub ? 16.0 : 30.0,
        leading: isSub
            ? Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
        title: n.title,
        textStyle: TextStyle(
          fontSize: isSub ? 12 : 11.5,
          fontWeight: isSub ? FontWeight.w600 : FontWeight.normal,
          color: isSub ? null : Colors.grey.shade700,
        ),
        onTap: () {
          Navigator.of(context).pop();
          widget.onJump(n.sectionIndex, n.paragraphIndex);
        },
      ),
    ];
    for (final child in n.children) {
      rows.addAll(_buildDeepNodes(context, child));
    }
    return rows;
  }

  // ===== 通用行（带层级缩进与当前项强调） =====
  Widget _levelRow({
    required double indent,
    required Widget leading,
    required String title,
    required VoidCallback onTap,
    Key? key,
    String? subtitle,
    bool emphasized = false,
    bool playing = false,
    TextStyle? textStyle,
  }) {
    final color = widget.color;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.only(left: indent + 6, right: 10, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: emphasized ? color.withValues(alpha: 0.10) : null,
          border: Border(
            left: BorderSide(
              color: emphasized ? color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 14, child: Center(child: leading)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    (textStyle ?? const TextStyle(fontSize: 12.5, height: 1.25))
                        .copyWith(
                  color: emphasized ? color : textStyle?.color,
                  fontWeight: emphasized
                      ? FontWeight.bold
                      : (textStyle?.fontWeight ?? FontWeight.w500),
                ),
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ),
            if (playing)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.volume_up_rounded,
                    size: 15, color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }

  /// 层级标记：章号（方块）/ 节号（浅色小字，size 传 0）
  Widget _levelBadge(String number,
      {required bool filled, required double size}) {
    final color = widget.color;
    if (size > 0) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          number,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: filled ? Colors.white : color,
          ),
        ),
      );
    }
    return Text(
      number,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color.withValues(alpha: 0.85),
      ),
    );
  }
}
