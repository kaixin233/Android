import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/knowledge_service.dart';
import '../services/tts_service.dart';

/// 考点知识 TTS 连续播放能力
///
/// 为展示 [KnowledgeSection] 列表的页面提供统一的播放/停止/进度跟踪逻辑
/// 与底部播放控制栏 UI，避免各页面重复维护同一份 TTS 代码。
///
/// 使用方式：
/// ```dart
/// class _MyPageState extends State<MyPage> with KnowledgePlaybackMixin {
///   @override
///   List<KnowledgeSection> get playbackSections => _sections;
///
///   @override
///   void initState() {
///     super.initState();
///     initKnowledgePlayback(); // 预热 TTS 引擎
///   }
///
///   @override
///   void dispose() {
///     disposeKnowledgePlayback();
///     super.dispose();
///   }
/// }
/// ```
mixin KnowledgePlaybackMixin<T extends StatefulWidget> on State<T> {
  bool _isPlayingKnowledge = false;
  int _playingSectionIndex = -1; // -1 = 未播放
  int _currentChunkIndex = 0;
  int _currentChunkCount = 0;

  /// 防止重复调用 [playAllKnowledge]
  bool _isStartingPlayback = false;

  /// 当前可播放的考点小节列表，由使用方提供
  List<KnowledgeSection> get playbackSections;

  /// 是否正在播放（含暂停前的播放中状态）
  bool get isPlayingKnowledge => _isPlayingKnowledge;

  /// 正在播放的小节下标，-1 表示未播放
  int get playingSectionIndex => _playingSectionIndex;

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

    final chunks = TtsService.cleanAndChunk(
        playbackSections[index].toSpeechText());

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
        setState(() => _currentChunkIndex = i);
      }
      final success = await TtsService.speak(chunks[i], waitForCompletion: true);
      if (!success) {
        overallSuccess = false;
        break;
      }
      // 小段间短暂停顿，避免句子连读
      await Future.delayed(const Duration(milliseconds: 180));
    }

    _resetPlaybackState();

    if (!overallSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音播报失败，请重试')),
      );
    }
  }

  /// 顺序播放全部考点内容；播放中再次调用则停止
  Future<void> playAllKnowledge() async {
    // 防止重复点击
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

      // 如果正在播放，则停止
      if (_isPlayingKnowledge) {
        await stopKnowledgePlayback();
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
        _playingSectionIndex = 0;
      });

      for (var i = 0; i < playbackSections.length; i++) {
        if (!_isPlayingKnowledge || !mounted) break;

        final chunks = TtsService.cleanAndChunk(
            playbackSections[i].toSpeechText());

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
            setState(() => _currentChunkIndex = j);
          }
          final success =
              await TtsService.speak(chunks[j], waitForCompletion: true);
          if (!success) {
            ok = false;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 160));
        }
        if (!ok || !_isPlayingKnowledge || !mounted) break;
      }
    } catch (e, stackTrace) {
      debugPrint('playAllKnowledge 异常: $e');
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
        _currentChunkIndex = 0;
        _currentChunkCount = 0;
      });
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
  /// [showChunkProgress] 为 true 时在播放中显示"第 x/y 节 · 当前段 m/n"
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
                        if (showChunkProgress && _currentChunkCount > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '第 ${_playingSectionIndex + 1} / ${playbackSections.length} 节 · '
                            '当前段 ${_currentChunkIndex + 1} / $_currentChunkCount',
                            style: TextStyle(
                              fontSize: 11,
                              color: color.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (_currentChunkIndex + 1) /
                                  _currentChunkCount,
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
          // 停止按钮（仅播放时显示）
          if (_isPlayingKnowledge)
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
      ),
    );
  }
}
