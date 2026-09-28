import 'dart:async';

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
    void Function(void Function(int start, int end)?)? bindProgress,
    double Function()? rateProvider,
    Duration Function(String text, double rate)? durationEstimator,
  })  : _speak = speak ??
            ((text, {waitForCompletion = false}) =>
                TtsService.speak(text, waitForCompletion: waitForCompletion)),
        _stopSpeaker = stopSpeaker ?? TtsService.stop,
        _bindProgress = bindProgress ?? TtsService.setRangeProgressListener,
        _rateProvider = rateProvider ?? (() => TtsService.currentSpeechRate),
        _estimateDuration = durationEstimator ??
            ((text, rate) => TtsService.estimateSpeechDuration(text, rate: rate));

  final Future<bool> Function(String text, {bool waitForCompletion}) _speak;
  final Future<void> Function() _stopSpeaker;
  final void Function(void Function(int start, int end)?) _bindProgress;
  final double Function() _rateProvider;
  final Duration Function(String text, double rate) _estimateDuration;

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

  /// 当前句在**其所属段落内**的序号（0 基）；标题语音（段落 -1）或空闲返回 -1。
  /// 用于"逐字高亮"精确定位到段落中的第几句。
  int get currentSentenceIndexInParagraph {
    if (_queue.isEmpty || _cursor >= _queue.length) return -1;
    final target = _queue[_cursor];
    if (target.unit.paragraphIndex < 0) return -1;
    var n = 0;
    for (var i = 0; i < _cursor; i++) {
      final e = _queue[i];
      if (e.sectionIndex != target.sectionIndex) continue;
      if (e.unit.paragraphIndex != target.unit.paragraphIndex) continue;
      n++;
    }
    return n;
  }

  int get currentSectionUnitCount {
    final sec = _sectionOf(_cursor);
    return sec < 0 ? 0 : _unitCountInSection(sec);
  }

  /// 整体进度 0~1（已读完句数 / 队列总句数）
  double get progress => _queue.isEmpty ? 0 : (_cursor / _queue.length).clamp(0.0, 1.0);

  // ===== 逐字高亮进度（真实语音进度优先，估算兜底）=====

  int _unitTextLength = 0;
  double _unitPos = 0;
  bool _liveProgressSeen = false;
  Timer? _estTimer;
  int _lastProgressNotifyMs = 0;

  /// 当前朗读单元的字符总数
  int get unitTextLength => _unitTextLength;

  /// 当前朗读单元内**已读到的字符数**（0 ~ [unitTextLength]）。
  ///
  /// 引擎上报实时进度时即为真实值；否则按语速估算推进（大致同步）。
  int get unitCharEnd => _unitPos.round().clamp(0, _unitTextLength);

  /// 本句是否收到了引擎的**真实**逐字进度
  bool get hasLiveProgress => _liveProgressSeen;

  void _beginUnit(String text) {
    _unitTextLength = text.length;
    _unitPos = 0;
    _liveProgressSeen = false;
    _bindProgress(_onRangeProgress);
    _startEstimator();
  }

  void _endUnit() {
    _estTimer?.cancel();
    _estTimer = null;
    _bindProgress(null);
    _unitPos = _unitTextLength.toDouble();
  }

  void _onRangeProgress(int start, int end) {
    if (_state != ReaderState.playing || _unitTextLength <= 0) return;
    // 部分引擎（Android < 26）只在开始时上报"整段"范围，对逐字无意义 → 忽略
    if (start <= 0 && end >= _unitTextLength) return;
    _liveProgressSeen = true;
    _unitPos = end.toDouble().clamp(0.0, _unitTextLength.toDouble());
    // 真实进度接管后不再需要估算
    _estTimer?.cancel();
    _estTimer = null;
    _notifyProgress();
  }

  /// 估算推进：按语速折算总时长，每 40ms 前进 `len / ticks` 个字符。
  /// 注意用**浮点累加**，避免 `ceil` 取整导致高亮提前跑完（旧实现的问题）。
  void _startEstimator() {
    _estTimer?.cancel();
    final len = _unitTextLength;
    if (len <= 0) return;

    double rate = 1.0;
    try {
      rate = _rateProvider();
    } catch (_) {}
    if (rate <= 0.05) rate = 0.05;

    Duration total;
    try {
      total = _estimateDuration(_currentUnitText, rate);
    } catch (_) {
      total = Duration(milliseconds: (len * 260 * (0.5 / rate)).round());
    }
    // 引擎起播有约 200~400ms 的预热延迟，补一小段缓冲让高亮不至于抢跑
    final int totalMs = (total.inMilliseconds + 240).clamp(200, 90000).toInt();
    const int tickMs = 40;
    final double ticks = (totalMs / tickMs).clamp(1, 3000).toDouble();
    final double perTick = len / ticks;

    _estTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (_state != ReaderState.playing || _liveProgressSeen) {
        t.cancel();
        _estTimer = null;
        return;
      }
      _unitPos = (_unitPos + perTick).clamp(0.0, len.toDouble());
      if (_unitPos >= len) {
        t.cancel();
        _estTimer = null;
      }
      _notifyProgress();
    });
  }

  /// 节流通知（逐字进度可能很密集，避免过度重建）
  void _notifyProgress() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProgressNotifyMs < 40) return;
    _lastProgressNotifyMs = now;
    notifyListeners();
  }

  String get _currentUnitText =>
      _queue.isEmpty || _cursor >= _queue.length ? '' : _queue[_cursor].unit.text;

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
    _estTimer?.cancel();
    _estTimer = null;
    _bindProgress(null);
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
    _estTimer?.cancel();
    _estTimer = null;
    _bindProgress(null);
    _unitPos = 0;
    _unitTextLength = 0;
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
      _beginUnit(entry.unit.text);
      notifyListeners(); // 更新高亮/进度

      final ok = await _speak(entry.unit.text, waitForCompletion: true);
      _endUnit();

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
    _estTimer?.cancel();
    _estTimer = null;
    _bindProgress(null);
    _stopSpeaker();
    super.dispose();
  }
}
