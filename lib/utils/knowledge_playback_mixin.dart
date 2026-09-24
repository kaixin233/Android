import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/knowledge_service.dart';
import '../services/tts_service.dart';

/// 考点知识 TTS 连续播放能力（逐句朗读 + 当前句高亮）
///
/// 为展示 [KnowledgeSection] 列表的页面提供统一的播放/停止/进度跟踪逻辑
/// 与底部播放控制栏 UI。播放按"句子"为单位推进，并对外暴露当前正在朗读的
/// 段落下标与句子文本，便于页面在正文中高亮"当前所读内容"。
///
/// 使用方式：
/// ```dart
/// class _MyPageState extends State<MyPage> with KnowledgePlaybackMixin {
///   @override
///   List<KnowledgeSection> get playbackSections => _sections;
///
///   @override
///   void onPlaybackPositionChanged() {
///     // 可选：滚动到当前朗读的段落
///   }
/// }
/// ```
mixin KnowledgePlaybackMixin<T extends StatefulWidget> on State<T> {
  bool _isPlayingKnowledge = false;
  int _playingSectionIndex = -1; // -1 = 未播放
  int _playingParagraphIndex = -1; // 当前段落下标（-1 = 标题/未播放）
  String? _currentSentence; // 当前正在朗读的句子
  int _currentUnitIndex = 0;
  int _currentUnitCount = 0;

  /// 防止重复调用 [playAllKnowledge]
  bool _isStartingPlayback = false;

  /// 当前可播放的考点小节列表，由使用方提供
  List<KnowledgeSection> get playbackSections;

  /// 是否正在播放（含暂停前的播放中状态）
  bool get isPlayingKnowledge => _isPlayingKnowledge;

  /// 正在播放的小节下标，-1 表示未播放
  int get playingSectionIndex => _playingSectionIndex;

  /// 正在播放的小节内段落下标；-1 表示未播放或正在读标题
  int get playingParagraphIndex => _playingParagraphIndex;

  /// 当前正在朗读的句子文本（用于在正文中高亮）
  String? get currentSentence => _currentSentence;

  /// 当前句序号（从 1 开始）与总句数
  int get currentUnitIndex => _currentUnitIndex;
  int get currentUnitCount => _currentUnitCount;

  /// 播放位置（小节/句子）变化时回调，页面可据此自动滚动。默认空实现。
  void onPlaybackPositionChanged() {}

  /// 预热 TTS 引擎，避免首次点击朗读时出现明显延迟
  void initKnowledgePlayback() {
    TtsService.initialize();
  }

  /// 页面销毁时停止播放，在 dispose 中调用
  void disposeKnowledgePlayback() {
    if (_isPlayingKnowledge) {
      TtsService.stop();
    }
  }

  /// 播放指定小节；若正在播放该小节则停止
  Future<void> playSection(int index) async {
    if (index < 0 || index >= playbackSections.length) return;

    // 如果当前正在播放同一个小节，则停止
    if (_playingSectionIndex == index && _isPlayingKnowledge) {
      await stopKnowledgePlayback();
      return;
    }

    // 停止之前的播放
    if (_isPlayingKnowledge) {
      _isPlayingKnowledge = false;
      await TtsService.stop();
    }

    if (!mounted) return;
    await _applySpeechParams();

    if (!mounted) return;
    if (!await _ensureTtsReady()) return;

    final units = playbackSections[index].speechUnits();
    if (units.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该小节暂无可朗读内容')),
        );
      }
      return;
    }

    setState(() {
      _isPlayingKnowledge = true;
      _playingSectionIndex = index;
      _currentUnitCount = units.length;
      _currentUnitIndex = 0;
      _playingParagraphIndex = units.first.paragraphIndex;
      _currentSentence = units.first.text;
    });
    onPlaybackPositionChanged();

    final ok = await _speakUnits(units, index);

    _resetPlaybackState();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音播报失败，请重试')),
      );
    }
  }

  /// 从第一个小节开始连续播放全部；播放中再次调用则停止。
  Future<void> playAllKnowledge() async {
    if (_isPlayingKnowledge) {
      await stopKnowledgePlayback();
      return;
    }
    await playFromSection(0);
  }

  /// 从指定小节开始，连续播放到末尾（用于"从指定位置开始播放"）。
  Future<void> playFromSection(int startIndex) async {
    if (startIndex < 0 || startIndex >= playbackSections.length) return;
    if (_isPlayingKnowledge) {
      await TtsService.stop();
      _resetPlaybackState();
    }
    await _playRange(startIndex);
  }

  /// 从上一小节开始播放（当前在第一小节或未播放时从头开始）。
  Future<void> playPreviousSection() async {
    final idx = _playingSectionIndex > 0 ? _playingSectionIndex - 1 : 0;
    await playFromSection(idx);
  }

  /// 从下一小节开始播放。
  Future<void> playNextSection() async {
    final idx = _playingSectionIndex >= 0 ? _playingSectionIndex + 1 : 0;
    if (idx >= playbackSections.length) return;
    await playFromSection(idx);
  }

  /// 从 [startIndex] 起连续播放到末尾的内部实现。
  Future<void> _playRange(int startIndex) async {
    // 防止重复触发
    if (_isStartingPlayback) return;
    _isStartingPlayback = true;

    try {
      if (playbackSections.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('暂无考点内容可播放')),
          );
        }
        return;
      }

      await _applySpeechParams();
      if (!mounted) return;

      if (!await _ensureTtsReady()) {
        _resetPlaybackState();
        return;
      }

      setState(() {
        _isPlayingKnowledge = true;
        _playingSectionIndex = startIndex;
      });

      for (var i = startIndex; i < playbackSections.length; i++) {
        if (!_isPlayingKnowledge || !mounted) break;
        final units = playbackSections[i].speechUnits();
        if (units.isEmpty) continue;
        final ok = await _speakUnits(units, i);
        if (!ok || !_isPlayingKnowledge || !mounted) break;
      }
    } catch (e, stackTrace) {
      debugPrint('连续播放异常: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放启动失败: $e')),
        );
      }
    } finally {
      _resetPlaybackState();
      _isStartingPlayback = false;
    }
  }

  /// 逐句朗读一组单元；返回整体是否成功。
  Future<bool> _speakUnits(
      List<KnowledgeSpeechUnit> units, int sectionIndex) async {
    for (var i = 0; i < units.length; i++) {
      if (!_isPlayingKnowledge || !mounted) return false;
      if (_playingSectionIndex != sectionIndex) return false;
      if (mounted) {
        setState(() {
          _currentUnitIndex = i;
          _playingParagraphIndex = units[i].paragraphIndex;
          _currentSentence = units[i].text;
        });
        onPlaybackPositionChanged();
      }
      final success =
          await TtsService.speak(units[i].text, waitForCompletion: true);
      if (!success) return false;
      // 句间短暂停顿，避免句子连读
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return true;
  }

  /// 停止播放
  Future<void> stopKnowledgePlayback() async {
    _isPlayingKnowledge = false;
    await TtsService.stop();
    _resetPlaybackState();
  }

  void _resetPlaybackState() {
    if (mounted) {
      setState(() {
        _isPlayingKnowledge = false;
        _playingSectionIndex = -1;
        _playingParagraphIndex = -1;
        _currentSentence = null;
        _currentUnitIndex = 0;
        _currentUnitCount = 0;
      });
      onPlaybackPositionChanged();
    }
  }

  /// 应用用户保存的语音参数（TTS 初始化由 speak() 内部处理，含重试逻辑）
  Future<void> _applySpeechParams() async {
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
  }

  Future<bool> _ensureTtsReady() async {
    // initialize() 现已内置重试+超时，单次调用通常足以让冷启动的引擎就绪；
    // 这里再给一次机会，并加总超时防止 UI 长时间卡住。
    for (var attempt = 0; attempt < 2; attempt++) {
      final ready = await TtsService.initialize().timeout(
        const Duration(seconds: 25),
        onTimeout: () => false,
      );
      if (ready) return true;
      if (!mounted) return false;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音引擎初始化失败，请检查 TTS 设置')),
      );
    }
    return false;
  }

  /// 底部播放控制栏
  ///
  /// [showChunkProgress] 为 true 时在播放中显示"第 x/y 节 · 当前句 m/n"
  /// 与分段进度条。
  Widget buildKnowledgePlaybackBar(
    ThemeData theme,
    Color color, {
    bool showChunkProgress = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final playingLabel =
        _playingSectionIndex >= 0 && _playingSectionIndex < playbackSections.length
            ? playbackSections[_playingSectionIndex].title
            : '考点知识';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // 播放/停止按钮
          GestureDetector(
            onTap: playAllKnowledge,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isPlayingKnowledge ? Colors.red : color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPlayingKnowledge
                    ? Icons.stop_rounded
                    : Icons.playlist_play_rounded,
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
                  _isPlayingKnowledge ? '正在朗读' : '点击播放全部',
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
                        if (showChunkProgress && _currentUnitCount > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '第 ${_playingSectionIndex + 1} / ${playbackSections.length} 节 · '
                            '当前句 ${_currentUnitIndex + 1} / $_currentUnitCount',
                            style: TextStyle(
                              fontSize: 11,
                              color: color.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (_currentUnitIndex + 1) /
                                  _currentUnitCount,
                              minHeight: 6,
                              backgroundColor: color.withValues(alpha: 0.14),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // 播放中：上一节 / 下一节 / 停止（支持"从指定位置开始播放"）
          if (_isPlayingKnowledge) ...[
            GestureDetector(
              onTap: playPreviousSection,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.skip_previous_rounded, color: color, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: playNextSection,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.skip_next_rounded, color: color, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: stopKnowledgePlayback,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
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
        ],
      ),
    );
  }
}
