import 'package:flutter/material.dart';

import '../services/knowledge_reader.dart';
import '../services/knowledge_service.dart';

/// 段落文本中第 [index] 句的**字符起点**（-1 表示越界）。
///
/// `splitSentences` 会 trim 每句，因此用 `indexOf` 从上一句末尾往后找，
/// 保证与朗读端使用的是同一份切分，逐字高亮的偏移不会错位。
int sentenceStartOffset(String paragraphText, List<String> sentences, int index) {
  if (index < 0 || index >= sentences.length) return -1;
  var off = 0;
  for (var i = 0; i < sentences.length; i++) {
    final idx = paragraphText.indexOf(sentences[i], off);
    final s = idx >= 0 ? idx : off;
    if (i == index) return s;
    off = s + sentences[i].length;
  }
  return -1;
}

/// 考点知识朗读能力（控制器驱动，见 [KnowledgeReaderController]）
///
/// 页面只需：
/// ```dart
/// class _S extends State<W> with KnowledgePlaybackMixin<W> {
///   @override
///   List<KnowledgeSection> get playbackSections => _sections; // 数据到达后
///   @override
///   void onPlaybackPositionChanged() { /* 可选：让当前朗读内容保持可见 */ }
/// }
/// ```
/// 数据加载完成后调用 [syncPlaybackSections] 通知控制器。
mixin KnowledgePlaybackMixin<T extends StatefulWidget> on State<T> {
  late final KnowledgeReaderController reader = KnowledgeReaderController();

  /// 当前可朗读的小节列表
  List<KnowledgeSection> get playbackSections;

  /// 播放/暂停/停止导致位置变化时回调（页面据此做"跟随滚动"）
  void onPlaybackPositionChanged() {}

  /// 预热并订阅控制器
  void initKnowledgePlayback() {
    reader.addListener(_onReaderChanged);
    _syncSections();
  }

  /// 数据变化后同步小节列表（页面在 setState 后调用）
  void syncPlaybackSections() => _syncSections();

  void _syncSections() {
    reader.loadSections(playbackSections);
  }

  void _onReaderChanged() {
    if (!mounted) return;
    // 先同步高亮区间（供本次 setState 使用），再交回页面做跟随滚动
    _syncHighlight();
    onPlaybackPositionChanged();
    setState(() {});
  }

  void disposeKnowledgePlayback() {
    reader.removeListener(_onReaderChanged);
    reader.dispose();
  }

  // ===== 逐字高亮（真实语音进度优先，估算兜底）=====
  //
  // 高亮区间 = 当前所读句子在段落中的起始下标 + 控制器给出的**句内已读字符数**。
  // 因为朗读单元与渲染端共用 `splitSentences`，两边切分完全一致，映射不会错位。
  int _hlParagraph = -1;
  int _hlSentenceStart = -1;
  String? _hlKey;

  /// 当前高亮所属的段落下标（-1 表示不高亮）
  int get highlightParagraphIndex => _hlParagraph;

  /// 高亮区间起点（段落内字符下标）
  int get highlightStart => _hlParagraph < 0 ? 0 : _hlSentenceStart;

  /// 高亮区间终点（段落内字符下标，不含）
  int get highlightEnd =>
      _hlParagraph < 0 ? 0 : _hlSentenceStart + reader.unitCharEnd;

  /// 本句高亮是否来自引擎真实进度（false 表示按语速估算）
  bool get highlightIsLive => reader.hasLiveProgress;

  void _clearHighlight() {
    _hlKey = null;
    _hlParagraph = -1;
    _hlSentenceStart = -1;
  }

  void _syncHighlight() {
    final si = playingSectionIndex;
    final pi = playingParagraphIndex;
    if (si < 0 || pi < 0 || si >= playbackSections.length) {
      _clearHighlight();
      return;
    }
    final p = playbackSections[si].paragraphs[pi];
    final sents = splitSentences(p.text);
    final n = reader.currentSentenceIndexInParagraph;
    if (n < 0 || n >= sents.length) {
      _clearHighlight();
      return;
    }
    final key = '$si:$pi:$n';
    if (_hlKey == key) return; // 同一句：区间由控制器进度驱动，无需重算

    final start = sentenceStartOffset(p.text, sents, n);
    if (start < 0) {
      _clearHighlight();
      return;
    }
    _hlKey = key;
    _hlParagraph = pi;
    _hlSentenceStart = start;
  }

  // ===== 状态透传 =====
  bool get isPlayingKnowledge => reader.isPlaying;
  bool get isPausedKnowledge => reader.isPaused;
  bool get isActiveKnowledge => reader.isActive;
  int get playingSectionIndex => reader.isActive ? reader.currentSectionIndex : -1;
  int get playingParagraphIndex => reader.currentParagraphIndex;
  String? get currentSentence => reader.currentSentence;

  /// 正在朗读的小节号（如 "1.1.1"），空闲为 null。用于目录/卡片标记"正在朗读"。
  String? get playingSectionNumber {
    final i = playingSectionIndex;
    if (i < 0 || i >= playbackSections.length) return null;
    return playbackSections[i].number;
  }

  // ===== 控制 =====
  /// 朗读指定小节（仅本节）；再次点击同一小节则暂停/继续
  Future<void> playSection(int index) =>
      reader.startFrom(index, untilSection: index + 1);

  /// 从指定小节开始连续朗读到末尾
  Future<void> playFromSection(int index) => reader.startFrom(index);

  /// 播放/暂停切换：播放中 → 暂停；暂停中 → 继续；空闲 → 从上次位置起播。
  ///
  /// 说明：不再提供"自动从当前可见位置开始"的入口——该入口依赖版面几何推算、
  /// 体验不稳，已由**「选择起始段」**（点段落上的"从这里朗读"）取代，精确且可控。
  Future<void> toggleKnowledgePlayPause() async {
    if (reader.isPlaying) {
      await reader.pause();
    } else if (reader.isPaused) {
      await reader.resume();
    } else {
      await reader.startFrom(reader.currentSectionIndex);
    }
  }

  /// 从头播放全部考点
  Future<void> playAllFromStart() {
    reader.setAnchorSection(0);
    return reader.startFrom(0);
  }

  Future<void> stopKnowledgePlayback() => reader.stop();

  /// 记录当前可见位置（供"从当前位置朗读"）
  void setKnowledgeAnchor(int sectionIndex) =>
      reader.setAnchorSection(sectionIndex);

  // ===== 控制栏 UI =====
  /// 紧凑播放控制条：播放/暂停、进度、停止。
  Widget buildKnowledgePlaybackBar(ThemeData theme, Color color) {
    final isDark = theme.brightness == Brightness.dark;
    final active = reader.isActive;
    final secIdx = reader.currentSectionIndex;
    final title = (secIdx >= 0 && secIdx < playbackSections.length)
        ? playbackSections[secIdx].title
        : '考点知识';
    final unitCount = reader.currentSectionUnitCount;
    final unitNo = unitCount == 0 ? 0 : reader.currentUnitInSection + 1;

    return Material(
      color: isDark ? theme.colorScheme.surface : Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 从头播放全部 / 暂停 / 继续
            _circleButton(
              icon: reader.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              bg: reader.isPlaying ? Colors.orange : color,
              onTap: () {
                if (reader.isPlaying) {
                  reader.pause();
                } else if (reader.isPaused) {
                  reader.resume();
                } else {
                  playAllFromStart();
                }
              },
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 168),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active
                        ? (reader.isPaused ? '已暂停 · $title' : '正在朗读 · $title')
                        : '从头播放全部考点',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (active && unitCount > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '第 ${secIdx + 1}/${playbackSections.length} 节 · 第 $unitNo/$unitCount 句',
                          style: TextStyle(
                            fontSize: 11,
                            color: color.withValues(alpha: 0.85),
                          ),
                        ),
                        // 高亮同步状态：真实语音进度 / 按语速估算
                        if (reader.unitCharEnd > 0) ...[
                          const SizedBox(width: 6),
                          Icon(
                            reader.hasLiveProgress
                                ? Icons.graphic_eq_rounded
                                : Icons.timelapse_rounded,
                            size: 11,
                            color: color.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 150,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: reader.progress,
                          minHeight: 4,
                          backgroundColor: color.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (active) ...[
              const SizedBox(width: 8),
              _circleButton(
                icon: Icons.stop_rounded,
                bg: Colors.grey.shade400,
                onTap: stopKnowledgePlayback,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
