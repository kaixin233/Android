import 'package:flutter/material.dart';

import '../services/knowledge_reader.dart';
import '../services/knowledge_service.dart';

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
    setState(() {});
    onPlaybackPositionChanged();
  }

  void disposeKnowledgePlayback() {
    reader.removeListener(_onReaderChanged);
    reader.dispose();
  }

  // ===== 状态透传 =====
  bool get isPlayingKnowledge => reader.isPlaying;
  bool get isPausedKnowledge => reader.isPaused;
  bool get isActiveKnowledge => reader.isActive;
  int get playingSectionIndex => reader.isActive ? reader.currentSectionIndex : -1;
  int get playingParagraphIndex => reader.currentParagraphIndex;
  String? get currentSentence => reader.currentSentence;

  // ===== 控制 =====
  /// 朗读指定小节（仅本节）；再次点击同一小节则暂停/继续
  Future<void> playSection(int index) =>
      reader.startFrom(index, untilSection: index + 1);

  /// 从指定小节开始连续朗读到末尾
  Future<void> playFromSection(int index) => reader.startFrom(index);

  /// 播放起始小节：由页面按"当前可见位置"提供（"从当前位置朗读"）
  int get playbackStartSectionIndex => 0;

  /// 播放起始段落（-1 表示从小节开头）。
  /// 页面按视口顶部所在段落提供，实现**段落级**的"从当前位置朗读"。
  int get playbackStartParagraphIndex => -1;

  /// 由页面提供的"**从当前可见位置重新开始朗读**"动作（先彻底停止在途朗读再起播）。
  ///
  /// 与 [toggleKnowledgePlayPause] 的区别：后者在播放中只是"暂停"，而本动作无论
  /// 当前状态如何都会**跳到当前可见位置重新朗读**——这才是用户期待的语义。
  Future<void> Function()? get playFromCurrentPositionHandler => null;

  /// 播放/暂停切换：
  /// - 播放中 → 暂停；
  /// - 暂停中且位置未变 → 继续；位置已变 → 从新位置重新开始；
  /// - 空闲 → 从当前可见位置开始朗读。
  Future<void> toggleKnowledgePlayPause() async {
    if (reader.isPlaying) {
      await reader.pause();
      return;
    }
    final start = playbackStartSectionIndex;
    final para = playbackStartParagraphIndex;
    if (reader.isPaused) {
      if (reader.isSameRange(start, null, para)) {
        await reader.resume();
        return;
      }
      await reader.stop();
    }
    reader.setAnchorSection(start);
    await reader.startFrom(start, startParagraph: para);
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
            // 播放（空闲时从"当前可见位置"开始）/ 暂停 / 继续
            _circleButton(
              icon: reader.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              bg: reader.isPlaying ? Colors.orange : color,
              onTap: () {
                if (reader.isPlaying) {
                  reader.pause();
                  return;
                }
                if (reader.isPaused) {
                  // 暂停中：若用户已滚动到别处，则从新位置重开；否则继续
                  if (reader.isSameRange(playbackStartSectionIndex, null,
                      playbackStartParagraphIndex)) {
                    reader.resume();
                  } else {
                    final h = playFromCurrentPositionHandler;
                    if (h != null) {
                      h();
                    } else {
                      toggleKnowledgePlayPause();
                    }
                  }
                  return;
                }
                final h = playFromCurrentPositionHandler;
                if (h != null) {
                  h();
                } else {
                  toggleKnowledgePlayPause();
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
                        : '从当前位置播放',
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
                    Text(
                      '第 ${secIdx + 1}/${playbackSections.length} 节 · 第 $unitNo/$unitCount 句',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.85),
                      ),
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
