import 'package:flutter/foundation.dart';

import 'knowledge_service.dart';
import 'tts_service.dart';

/// 朗读状态
enum ReaderState { idle, playing, paused }

/// 队列项：一个句子 + 它所属的小节下标
class _QueueEntry {
  final int sectionIndex;
  final KnowledgeSpeechUnit unit;
  const _QueueEntry(this.sectionIndex, this.unit);
}

/// 考点知识朗读控制器（与 UI 解耦，可单测）
///
/// 采用"**单循环 + 游标**"模型，替代此前嵌套异步调用的实现，从而获得可靠且
/// 可预测的播放/暂停/续读/停止行为：
/// - `startFrom` 构建 [startSection, untilSection) 的句子队列并启动循环；
/// - `pause` 停止引擎但**保留游标**，`resume` 从当前句继续；
/// - `stop` 清空队列回到 idle；
/// - 每次启动使用自增 token，旧的异步回调会被安全丢弃，避免"上一个循环继续跑"。
///
/// 通过构造参数注入 [speak]/[stopSpeaker]，使核心调度逻辑可在无 Flutter/TTS 环境
/// 下单测（默认使用 [TtsService]）。
class KnowledgeReaderController extends ChangeNotifier {
  KnowledgeReaderController({
    Future<bool> Function(String text, {bool waitForCompletion})? speak,
    Future<void> Function()? stopSpeaker,
  })  : _speak = speak ??
            ((text, {waitForCompletion = false}) =>
                TtsService.speak(text, waitForCompletion: waitForCompletion)),
        _stopSpeaker = stopSpeaker ?? TtsService.stop;

  final Future<bool> Function(String text, {bool waitForCompletion}) _speak;
  final Future<void> Function() _stopSpeaker;

  List<KnowledgeSection> _sections = const [];
  List<_QueueEntry> _queue = const [];
  int _cursor = 0;
  int _runToken = 0;
  ReaderState _state = ReaderState.idle;

  /// 上一次定位到的小节（用于"从当前位置/继续"）
  int _lastSectionIndex = 0;

  // ===== 只读状态 =====
  List<KnowledgeSection> get sections => _sections;
  ReaderState get state => _state;
  bool get isPlaying => _state == ReaderState.playing;
  bool get isPaused => _state == ReaderState.paused;
  bool get isActive => _state != ReaderState.idle;

  /// 当前朗读的小节下标（idle 时为上次位置）
  int get currentSectionIndex =>
      _queue.isEmpty || _cursor >= _queue.length
          ? _lastSectionIndex
          : _queue[_cursor].sectionIndex;

  /// 当前朗读的段落下标（-1 表示标题/不可高亮）
  int get currentParagraphIndex =>
      _queue.isEmpty || _cursor >= _queue.length ? -1 : _queue[_cursor].unit.paragraphIndex;

  /// 当前朗读的句子文本
  String? get currentSentence =>
      _queue.isEmpty || _cursor >= _queue.length ? null : _queue[_cursor].unit.text;

  /// 当前句在该小节中的序号 / 该小节总句数
  int get currentUnitInSection => _unitIndexInSection(_cursor, _sectionOf(_cursor));

  int get currentSectionUnitCount {
    final sec = _sectionOf(_cursor);
    return sec < 0 ? 0 : _unitCountInSection(sec);
  }

  /// 整体进度 0~1（已读完句数 / 队列总句数）
  double get progress => _queue.isEmpty ? 0 : (_cursor / _queue.length).clamp(0.0, 1.0);

  int _sectionOf(int cursor) =>
      cursor >= 0 && cursor < _queue.length ? _queue[cursor].sectionIndex : -1;

  int _unitIndexInSection(int cursor, int sectionIndex) {
    if (sectionIndex < 0 || cursor >= _queue.length) return 0;
    var n = 0;
    for (var i = 0; i < cursor; i++) {
      if (_queue[i].sectionIndex == sectionIndex) n++;
    }
    return n;
  }

  int _unitCountInSection(int sectionIndex) =>
      _queue.where((e) => e.sectionIndex == sectionIndex).length;

  /// 载入考点小节数据（页面数据到达后调用）
  void loadSections(List<KnowledgeSection> sections) {
    _sections = List.unmodifiable(sections);
    if (_lastSectionIndex >= _sections.length) _lastSectionIndex = 0;
    notifyListeners();
  }

  /// 从 [startSection] 开始朗读；[untilSection] 为结束小节（不含），
  /// 省略则读到最后一节。已处于播放/暂停且同一范围时切换暂停/继续。
  Future<void> startFrom(
    int startSection, {
    int? untilSection,
    int startParagraph = -1,
  }) async {
    if (_sections.isEmpty) return;
    final start = startSection.clamp(0, _sections.length - 1);
    final end = (untilSection ?? _sections.length).clamp(start + 1, _sections.length);

    _buildQueue(start, end, startParagraph: startParagraph);
    _lastSectionIndex = start;
    _state = ReaderState.playing;
    notifyListeners();
    await _runLoop();
  }

  /// 队列起点（供 UI 判断"继续"还是"从新位置重新开始"）
  int get queueStartSection => _queueStartSection;
  int get queueStartParagraph => _queueStartParagraph;

  int _queueStartSection = -1;
  int _queueStartParagraph = -1;
  bool _queueIsSingleSection = false;

  /// 该范围是否与当前队列一致
  bool isSameRange(int startSection, int? untilSection, int startParagraph) {
    if (!isActive || _queue.isEmpty) return false;
    final end = untilSection ?? _sections.length;
    final queueEnd = _queue.last.sectionIndex + 1;
    return _queueStartSection == startSection &&
        queueEnd == end &&
        _queueStartParagraph == startParagraph &&
        _queueIsSingleSection == (untilSection == startSection + 1);
  }

  /// 构建朗读队列。
  ///
  /// [startParagraph] >= 0 时表示"从该小节内的指定段落开始"（用于段落级
  /// "从当前位置朗读"）：丢弃该段落之前的内容，以及小节标题语音（paragraphIndex = -1）。
  void _buildQueue(int start, int end, {int startParagraph = -1}) {
    final q = <_QueueEntry>[];
    final skipToParagraph = startParagraph >= 0;
    for (var i = start; i < end; i++) {
      for (final u in _sections[i].speechUnits()) {
        if (i == start && skipToParagraph) {
          // 标题语音（-1）与早于起点的段落一并跳过
          if (u.paragraphIndex < startParagraph) continue;
        }
        q.add(_QueueEntry(i, u));
      }
    }
    _queue = q;
    _cursor = 0;
    _queueStartSection = start;
    _queueStartParagraph = startParagraph;
    _queueIsSingleSection = (end == start + 1);
  }

  /// 暂停（保留游标，可 [resume] 续读）
  Future<void> pause() async {
    if (!isPlaying) return;
    _state = ReaderState.paused;
    notifyListeners();
    // 停止引擎：waitForCompletion 会以 false 返回，循环据此退出但不重置游标
    await _stopSpeaker();
  }

  /// 从暂停处继续（重读当前句）
  Future<void> resume() async {
    if (!isPaused) return;
    _state = ReaderState.playing;
    notifyListeners();
    await _runLoop();
  }

  /// 停止并复位
  Future<void> stop() async {
    _state = ReaderState.idle;
    _runToken++; // 使正在运行的循环失效
    _cursor = 0;
    _queue = const [];
    notifyListeners();
    await _stopSpeaker();
  }

  /// 单循环：逐句朗读；暂停/停止/被新运行取代时安全退出。
  Future<void> _runLoop() async {
    final token = ++_runToken;
    while (true) {
      if (token != _runToken) return; // 已被新运行/停止取代
      if (_state != ReaderState.playing) return; // 暂停或空闲
      if (_cursor >= _queue.length) break; // 读完

      final entry = _queue[_cursor];
      _lastSectionIndex = entry.sectionIndex;
      notifyListeners(); // 更新高亮/进度

      final ok = await _speak(entry.unit.text, waitForCompletion: true);

      if (token != _runToken) return; // 等待期间被停止/重启
      if (_state != ReaderState.playing) return; // 被暂停

      if (!ok) {
        // 单句失败：跳过后继续（避免整段中断），连续失败过多则结束
        _consecutiveFailures++;
        if (_consecutiveFailures >= 3) {
          await stop();
          return;
        }
      } else {
        _consecutiveFailures = 0;
      }
      _cursor++;
    }
    if (token != _runToken) return;
    // 自然读完
    _state = ReaderState.idle;
    _cursor = 0;
    _queue = const [];
    notifyListeners();
  }

  int _consecutiveFailures = 0;

  /// 记录"当前可见位置"，供 UI 的"从当前位置朗读"使用
  void setAnchorSection(int index) {
    _lastSectionIndex = index.clamp(0, _sections.isEmpty ? 0 : _sections.length - 1);
  }

  @override
  void dispose() {
    _runToken++;
    _state = ReaderState.idle;
    _stopSpeaker();
    super.dispose();
  }
}
