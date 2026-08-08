import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../models/history_item.dart';
import '../providers/app_provider.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../utils/animations.dart';
import '../utils/ai_assistant_launcher.dart';
import '../widgets/ask_ai_selection_area.dart';

/// 练习页面配置
class PracticeConfig {
  const PracticeConfig({
    this.subject,
    this.type,
    this.difficulty,
    this.onlyFavorites = false,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.mode = PracticeMode.practice,
    this.timeLimitSeconds,
    this.questionLimit,
    this.chapterNumber,
    this.subsection,
    this.keyword,
  });

  final QuestionSubject? subject;
  final QuestionType? type;
  final QuestionDifficulty? difficulty;
  final bool onlyFavorites;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final PracticeMode mode;
  final int? timeLimitSeconds;
  final int? questionLimit;
  final String? chapterNumber;
  final String? subsection;
  final String? keyword;
}

/// 答题记录，用于恢复已回答题目的选择状态
class _AnswerRecord {
  final bool isCorrect;
  final int? selectedIndex;
  final Set<int> selectedIndices;
  final bool? selectedBool;
  final String fillBlankText;

  const _AnswerRecord({
    required this.isCorrect,
    this.selectedIndex,
    this.selectedIndices = const {},
    this.selectedBool,
    this.fillBlankText = '',
  });
}

/// 通用练习页面 - 支持普通练习、错题重做、考试模式
class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
    required this.config,
    required this.onCompleted,
  });

  final PracticeConfig config;
  final Future<void> Function(HistoryItem result) onCompleted;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  List<Question> _questions = [];
  int _currentIndex = 0;
  int? _selectedIndex;
  Set<int> _selectedIndices = {};
  bool? _selectedBool;
  final TextEditingController _fillBlankController = TextEditingController();
  int _correctCount = 0;
  bool _isLoading = true;
  bool _submitted = false;
  bool _isCorrect = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  final Set<String> _wrongKeys = {};
  final Map<String, _AnswerRecord> _questionResults = {};
  bool _isSpeaking = false;
  bool _isSpeakingExplanation = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    // 预热 TTS 引擎，避免首次点击朗读时出现明显延迟
    TtsService.initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fillBlankController.dispose();
    TtsService.stop();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final favorites = widget.config.onlyFavorites
        ? await StorageService.loadFavorites()
        : null;

    // 错题重做模式
    if (widget.config.mode == PracticeMode.wrong) {
      var wrongKeys = await StorageService.loadWrongQuestionKeys();
      // 按科目过滤错题（uniqueKey 以科目名开头）
      if (widget.config.subject != null) {
        wrongKeys = wrongKeys
            .where((key) => key.startsWith(widget.config.subject!.name))
            .toList();
      }
      _questions = await QuestionService.getByKeys(wrongKeys);
    } else {
      _questions = await QuestionService.filter(
        subject: widget.config.subject,
        type: widget.config.type,
        difficulty: widget.config.difficulty,
        chapterNumber: widget.config.chapterNumber,
        subsection: widget.config.subsection,
        keyword: widget.config.keyword,
        onlyFavorites: widget.config.onlyFavorites,
        favoriteKeys: favorites,
      );
    }

    if (widget.config.shuffleQuestions) {
      _questions.shuffle();
    }

    if (widget.config.questionLimit != null &&
        _questions.length > widget.config.questionLimit!) {
      _questions = _questions.take(widget.config.questionLimit!).toList();
    }

    if (widget.config.shuffleOptions) {
      _questions = _questions.map(QuestionService.shuffleOptions).toList();
    }

    setState(() {
      _isLoading = false;
    });

    // 始终启动计时器，用于统计练习时长
    _startTimer();

    // 进入练习后自动朗读第一题
    if (mounted && _questions.isNotEmpty) {
      final app = context.read<AppProvider>();
      if (app.ttsAutoReadQuestion) {
        _speakQuestion();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
      });
      // 考试模式：检查时间限制
      final limit = widget.config.timeLimitSeconds;
      if (limit != null) {
        // 剩余时间不足 20% 时震动提醒（每 30 秒一次）
        if (_elapsedSeconds >= limit * 0.8 && (_elapsedSeconds % 30 == 0)) {
          final app = context.read<AppProvider>();
          if (app.vibrationEnabled) {
            HapticFeedback.lightImpact();
          }
        }
        if (_elapsedSeconds >= limit) {
          _timer?.cancel();
          _autoSubmit();
        }
      }
    });
  }

  void _autoSubmit() {
    if (!mounted) return;
    if (!_submitted && _isAnswerSubmitted()) {
      _submitAnswer();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('考试时间到，已自动交卷')),
    );
    _finishPractice();
  }

  bool _isAnswerSubmitted() {
    if (_questions.isEmpty || _currentIndex < 0 || _currentIndex >= _questions.length) return false;
    final question = _questions[_currentIndex];
    switch (question.type) {
      case QuestionType.singleChoice:
        return _selectedIndex != null;
      case QuestionType.multipleChoice:
        return _selectedIndices.isNotEmpty;
      case QuestionType.trueFalse:
        return _selectedBool != null;
      case QuestionType.fillBlank:
        return _fillBlankController.text.isNotEmpty;
    }
  }

  bool _checkAnswer() {
    final question = _questions[_currentIndex];
    switch (question.type) {
      case QuestionType.singleChoice:
        return _selectedIndex == question.answerIndex;
      case QuestionType.multipleChoice:
        return _selectedIndices.length == question.answerIndices.length &&
            _selectedIndices.containsAll(question.answerIndices);
      case QuestionType.trueFalse:
        return _selectedBool == question.isCorrect;
      case QuestionType.fillBlank:
        final input = _fillBlankController.text.trim();
        if (input.isEmpty) return false;
        final normalizedInput = _normalizeAnswer(input);
        return question.acceptableAnswers.any(
          (answer) => normalizedInput == _normalizeAnswer(answer),
        );
    }
  }

  String _normalizeAnswer(String answer) {
    return answer.toLowerCase().replaceAll(RegExp(r'[\s\p{Punct}]'), '');
  }

  void _submitAnswer() {
    if (!_isAnswerSubmitted()) return;
    final correct = _checkAnswer();
    final uniqueKey = _questions[_currentIndex].uniqueKey;
    final previous = _questionResults[uniqueKey];
    final app = context.read<AppProvider>();
    setState(() {
      _submitted = true;
      _isCorrect = correct;
      // 修正已答过题目的正确数
      if (previous != null) {
        if (previous.isCorrect && !correct) {
          _correctCount--;
          _wrongKeys.add(uniqueKey);
          app.addWrongQuestion(uniqueKey);
        } else if (!previous.isCorrect && correct) {
          _correctCount++;
          _wrongKeys.remove(uniqueKey);
          app.removeWrongQuestion(uniqueKey);
        }
      } else {
        if (correct) {
          _correctCount++;
        } else {
          _wrongKeys.add(uniqueKey);
          app.addWrongQuestion(uniqueKey);
        }
      }
      _questionResults[uniqueKey] = _AnswerRecord(
        isCorrect: correct,
        selectedIndex: _selectedIndex,
        selectedIndices: Set.from(_selectedIndices),
        selectedBool: _selectedBool,
        fillBlankText: _fillBlankController.text,
      );
    });
    // 震动反馈
    if (app.vibrationEnabled) {
      if (correct) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }
    // 更新知识点统计（仅在首次答题时）
    if (previous == null) {
      final question = _questions[_currentIndex];
      for (final kp in question.knowledgePoints) {
        StorageService.updateKnowledgePointStats(
          kp,
          isCorrect: correct,
          subject: question.subject,
          chapter: question.chapter,
          pointName: kp,
        );
      }
    }

    // 自动播报解析
    if (app.ttsAutoPlayExplanation && mounted) {
      // 答对且设置了"答对不播报解析"时，仅播报结果
      final skipExplanation = correct && app.ttsSkipExplanationOnCorrect;
      _speakExplanation(correct, skipExplanation: skipExplanation);
    }
  }

  /// 播报答题结果与解析
  Future<void> _speakExplanation(bool isCorrect, {bool skipExplanation = false}) async {
    // 先停止当前朗读
    if (_isSpeaking) {
      await TtsService.stop();
      if (mounted) setState(() => _isSpeaking = false);
    }

    final question = _questions[_currentIndex];
    final buffer = StringBuffer();

    // 答题结果提示
    if (isCorrect) {
      buffer.write('回答正确。');
    } else {
      buffer.write('回答错误。');
      // 错误时播报正确答案
      buffer.write('正确答案是：');
      buffer.write(AiAssistantLauncher.correctAnswerTextOf(question));
      buffer.write('。');
    }

    // 播报解析（skipExplanation 为 true 时跳过）
    if (!skipExplanation && question.explanation.isNotEmpty) {
      buffer.write('解析：');
      buffer.write(question.explanation);
    }

    if (mounted) setState(() => _isSpeakingExplanation = true);
    await TtsService.speak(
      buffer.toString(),
      onComplete: () {
        if (mounted) setState(() => _isSpeakingExplanation = false);
      },
    );
  }

  void _nextQuestion() {
    if (_currentIndex == _questions.length - 1) {
      _finishPractice();
      return;
    }
    _stopSpeakingIfNeeded();
    setState(() {
      _currentIndex++;
      _restoreQuestionState();
    });
    // 自动朗读下一题
    if (mounted) {
      final app = context.read<AppProvider>();
      if (app.ttsAutoReadQuestion && !_submitted) {
        _speakQuestion();
      }
    }
  }

  void _previousQuestion() {
    if (_currentIndex == 0) return;
    _stopSpeakingIfNeeded();
    setState(() {
      _currentIndex--;
      _restoreQuestionState();
    });
    // 自动朗读上一题
    if (mounted) {
      final app = context.read<AppProvider>();
      if (app.ttsAutoReadQuestion && !_submitted) {
        _speakQuestion();
      }
    }
  }

  void _stopSpeakingIfNeeded() {
    if (_isSpeaking || _isSpeakingExplanation) {
      TtsService.stop();
      _isSpeaking = false;
      _isSpeakingExplanation = false;
    }
  }

  /// 恢复当前题目的已答状态
  void _restoreQuestionState() {
    final uniqueKey = _questions[_currentIndex].uniqueKey;
    final record = _questionResults[uniqueKey];
    if (record != null) {
      _submitted = true;
      _isCorrect = record.isCorrect;
      _selectedIndex = record.selectedIndex;
      _selectedIndices = Set.from(record.selectedIndices);
      _selectedBool = record.selectedBool;
      _fillBlankController.text = record.fillBlankText;
    } else {
      _selectedIndex = null;
      _selectedIndices = {};
      _selectedBool = null;
      _fillBlankController.clear();
      _submitted = false;
      _isCorrect = false;
    }
  }

  Future<void> _finishPractice() async {
    _timer?.cancel();
    _stopSpeakingIfNeeded();
    final total = _questions.length;
    final result = HistoryItem(
      title: _getPracticeTitle(),
      answeredAt: DateTime.now(),
      correctCount: _correctCount,
      totalCount: total,
      durationSeconds: _elapsedSeconds,
      subject: widget.config.subject,
      mode: widget.config.mode,
      wrongQuestionKeys: _wrongKeys.toList(),
    );

    // 先保存结果，但不导航——导航由弹窗按钮统一处理
    await widget.onCompleted(result);

    if (!mounted) return;

    final accuracy = total == 0 ? 0 : (_correctCount * 100 ~/ total);
    final hasWrong = _wrongKeys.isNotEmpty;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          decoration: BoxDecoration(
            color: accuracy >= 80
                ? Colors.green.shade50
                : accuracy >= 60
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Icon(
                accuracy >= 80
                    ? Icons.emoji_events_rounded
                    : accuracy >= 60
                        ? Icons.thumb_up_rounded
                        : Icons.refresh_rounded,
                size: 48,
                color: accuracy >= 80
                    ? Colors.amber
                    : accuracy >= 60
                        ? Colors.orange
                        : Colors.red,
              ),
              const SizedBox(height: 8),
              Text(
                accuracy >= 80 ? '优秀！' : accuracy >= 60 ? '不错！' : '继续加油！',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accuracy >= 80
                      ? Colors.green
                      : accuracy >= 60
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // 正确率大字显示
            Center(
              child: Text(
                '$accuracy%',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: accuracy >= 80
                      ? Colors.green
                      : accuracy >= 60
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '答对 $_correctCount / $total 题',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text('用时：${_formatDuration(_elapsedSeconds)}'),
              ],
            ),
            if (hasWrong) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Text('错题 ${_wrongKeys.length} 道已加入错题本',
                      style: TextStyle(color: Colors.red.shade400)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          // 错题回顾按钮（仅有错题时显示）
          if (hasWrong)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // 回到错题重做模式
                setState(() {
                  _currentIndex = 0;
                  _correctCount = 0;
                  _elapsedSeconds = 0;
                  _questionResults.clear();
                  _selectedIndex = null;
                  _selectedIndices = {};
                  _selectedBool = null;
                  _fillBlankController.clear();
                  _submitted = false;
                  // 只保留错题
                  final wrongSet = _wrongKeys.toSet();
                  _questions = _questions
                      .where((q) => wrongSet.contains(q.uniqueKey))
                      .toList();
                  _wrongKeys.clear();
                });
              },
              child: const Text('错题回顾'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() {
                _currentIndex = 0;
                _correctCount = 0;
                _elapsedSeconds = 0;
                _wrongKeys.clear();
                _questionResults.clear();
                _selectedIndex = null;
                _selectedIndices = {};
                _selectedBool = null;
                _fillBlankController.clear();
                _submitted = false;
                _isCorrect = false;
                // 重新洗牌
                if (widget.config.shuffleQuestions) {
                  _questions.shuffle();
                }
                if (widget.config.shuffleOptions) {
                  _questions = _questions.map(QuestionService.shuffleOptions).toList();
                }
              });
              if (widget.config.timeLimitSeconds != null) {
                _startTimer();
              }
            },
            child: const Text('再练一次'),
          ),
        ],
      ),
    );
  }

  String _getPracticeTitle() {
    switch (widget.config.mode) {
      case PracticeMode.practice:
        final subjectLabel = widget.config.subject?.label ?? '全部';
        return '$subjectLabel 练习';
      case PracticeMode.exam:
        return '${widget.config.subject?.label ?? '综合'} 考试';
      case PracticeMode.wrong:
        return '错题重做';
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m分${s.toString().padLeft(2, '0')}秒';
  }

  String _formatRemainingTime() {
    if (widget.config.timeLimitSeconds == null) return '';
    final remaining = max(0, widget.config.timeLimitSeconds! - _elapsedSeconds);
    final m = remaining ~/ 60;
    final s = remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 朗读当前题目和选项
  ///
  /// 分两阶段播报：先朗读题目，停顿后再朗读选项，
  /// 避免题目和选项混在一起无法分辨。
  Future<void> _speakQuestion() async {
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;
    // 如果正在播报解析，先停止
    if (_isSpeakingExplanation) {
      await TtsService.stop();
    }
    setState(() {
      _isSpeaking = true;
      _isSpeakingExplanation = false;
    });

    final question = _questions[_currentIndex];
    final hasOptions = question.options.isNotEmpty;

    // 阶段1：只朗读题目
    final promptText = question.prompt;
    final success = await TtsService.speak(
      promptText,
      onComplete: () {
        // 题目朗读完成后，如果有选项，等待后继续朗读选项
        if (hasOptions && mounted) {
          _speakOptions();
        } else if (mounted) {
          setState(() => _isSpeaking = false);
        }
      },
    );

    // 朗读启动失败时，重置状态并引导用户
    if (!success && mounted) {
      setState(() => _isSpeaking = false);
      _showTtsErrorDialog();
    }
  }

  /// 朗读选项（题目朗读完成后的第二阶段）
  Future<void> _speakOptions() async {
    if (!mounted || _questions.isEmpty || _currentIndex >= _questions.length) return;
    final question = _questions[_currentIndex];
    if (question.options.isEmpty) return;

    // 题目与选项之间停顿，让用户消化题目内容
    await Future.delayed(const Duration(milliseconds: 1500));
    // 停顿期间用户可能按了停止按钮或切换了题目
    if (!mounted || !_isSpeaking) return;

    final buffer = StringBuffer();
    buffer.write('选项如下：');
    for (var i = 0; i < question.options.length; i++) {
      final label = String.fromCharCode('A'.codeUnitAt(0) + i);
      buffer.write('$label，${question.options[i]}。');
    }

    final success = await TtsService.speak(
      buffer.toString(),
      onComplete: () {
        if (mounted) setState(() => _isSpeaking = false);
      },
    );

    if (!success && mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  /// 显示 TTS 错误引导对话框（增强版，含诊断信息和操作按钮）
  void _showTtsErrorDialog() {
    String? diagInfo;
    bool isDiagnosing = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.volume_off, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('语音播报不可用')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '语音引擎未能正常启动朗读。'
                  '小米设备请使用系统自带的「系统语音引擎」'
                  '（包名 com.xiaomi.mibrain.speech）。',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text(
                  '快捷操作：',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('TTS设置', style: TextStyle(fontSize: 13)),
                      onPressed: () async {
                        await TtsService.openTtsSettings();
                      },
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('安装语音', style: TextStyle(fontSize: 13)),
                      onPressed: () async {
                        await TtsService.installTtsData();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: isDiagnosing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 18),
                      label: const Text('诊断', style: TextStyle(fontSize: 13)),
                      onPressed: isDiagnosing
                          ? null
                          : () async {
                              setDialogState(() => isDiagnosing = true);
                              final info = await TtsService.getDiagnostics();
                              setDialogState(() {
                                diagInfo = _formatDiagnostics(info);
                                isDiagnosing = false;
                              });
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '手动设置步骤：',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  '1. 点击上方「TTS设置」按钮\n'
                  '2. 确认语音引擎为「系统语音引擎」\n'
                  '   （小米自带，无需额外安装）\n'
                  '3. 如仍不可用，点击「安装语音」下载数据\n'
                  '4. 返回 App 点击「重试」',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                if (diagInfo != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      diagInfo!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // 重置 TTS 状态后重试
                TtsService.reset().then((_) {
                  if (mounted) _speakQuestion();
                });
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化诊断信息为可读文本
  String _formatDiagnostics(Map<String, dynamic> info) {
    final buffer = StringBuffer();
    buffer.writeln('=== TTS 诊断信息 ===');

    buffer.writeln('引擎可用: ${info['isAvailable']}');
    buffer.writeln('正在朗读: ${info['isSpeaking']}');

    if (info['defaultEngine'] != null) {
      buffer.writeln('默认引擎: ${info['defaultEngine']}');
    }

    if (info['engines'] != null) {
      buffer.writeln('已安装引擎: ${info['engines']}');
    }

    if (info['languages'] != null) {
      buffer.writeln('可用语言: ${info['languages']}');
    }

    if (info['nativeEngines'] != null) {
      final native = info['nativeEngines'] as Map;
      buffer.writeln('原生引擎数: ${native['engineCount']}');
      if (native['engines'] != null) {
        buffer.writeln('原生引擎列表:');
        for (final e in native['engines'] as List) {
          buffer.writeln('  - ${e['packageName']} (${e['label']})');
        }
      }
    }

    if (info['voiceData'] != null) {
      final vd = info['voiceData'] as Map;
      buffer.writeln('--- 语音数据检查 ---');
      buffer.writeln('初始化: ${vd['initStatus']}');
      if (vd['defaultEngine'] != null) {
        buffer.writeln('引擎: ${vd['defaultEngine']}');
      }
      if (vd['chineseStatusText'] != null) {
        buffer.writeln('中文状态: ${vd['chineseStatusText']}');
      }
      if (vd['isChineseAvailable'] != null) {
        buffer.writeln('中文可用: ${vd['isChineseAvailable']}');
      }
      if (vd['needInstallData'] != null) {
        buffer.writeln('需安装数据: ${vd['needInstallData']}');
      }
      if (vd['chineseVoices'] != null) {
        final voices = vd['chineseVoices'] as List;
        buffer.writeln('中文语音数: ${voices.length}');
        for (final v in voices) {
          buffer.writeln('  - ${v['name']} (${v['locale']})');
        }
      }
      if (vd['error'] != null) {
        buffer.writeln('错误: ${vd['error']}');
      }
    }

    if (info['error'] != null) {
      buffer.writeln('错误: ${info['error']}');
    }

    return buffer.toString();
  }

  /// 停止所有朗读
  Future<void> _stopSpeaking() async {
    await TtsService.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isSpeakingExplanation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('加载中...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_getPracticeTitle())),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                widget.config.mode == PracticeMode.wrong
                    ? '错题本为空，继续加油！'
                    : '暂无符合条件的题目',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final isFav = app.favorites.contains(question.uniqueKey);
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPracticeTitle()),
        actions: [
          // 收藏当前题目
          IconButton(
            icon: Icon(
              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFav ? Colors.amber : null,
            ),
            tooltip: isFav ? '取消收藏' : '收藏题目',
            onPressed: () =>
                context.read<AppProvider>().toggleFavorite(question.uniqueKey),
          ),
          // AI 学习助手（以当前题目为上下文提问）
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: '问 AI',
            onPressed: () => _askAiAboutQuestion(question),
          ),
          // 语音播报按钮（朗读题目或停止解析播报）
          IconButton(
            icon: Icon(
              (_isSpeaking || _isSpeakingExplanation)
                  ? Icons.stop_circle_rounded
                  : Icons.volume_up_rounded,
            ),
            tooltip: (_isSpeaking || _isSpeakingExplanation) ? '停止朗读' : '朗读题目',
            onPressed: (_isSpeaking || _isSpeakingExplanation)
                ? _stopSpeaking
                : _speakQuestion,
          ),
          if (widget.config.timeLimitSeconds != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _elapsedSeconds >= widget.config.timeLimitSeconds! * 0.8
                        ? Colors.red.shade100
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_rounded,
                          size: 16,
                          color: _elapsedSeconds >= widget.config.timeLimitSeconds! * 0.8
                              ? Colors.red
                              : theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        _formatRemainingTime(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _elapsedSeconds >= widget.config.timeLimitSeconds! * 0.8
                              ? Colors.red
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 进度行：题号 + 进度条 + 百分比 + 科目标签
              Row(
                children: [
                  Text(
                    '第 ${_currentIndex + 1} / ${_questions.length} 题',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ProgressBarAnimation(
                      progress: progress,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(progress * 100).toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: question.subject.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      question.subject.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: question.subject.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeChip(question.type, theme),
                  const SizedBox(width: 8),
                  _buildDifficultyChip(question.difficulty, theme),
                  const Spacer(),
                  Text('已答对 $_correctCount 题',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSelectableWithAskAi(
                        Text(
                          question.prompt,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        question,
                      ),
                      const SizedBox(height: 20),
                      _buildAnswerArea(question, theme),
                      if (_submitted) ...[
                        const SizedBox(height: 20),
                        _buildExplanationCard(question, theme),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentIndex > 0 ? _previousQuestion : null,
                      child: const Text('上一题'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _submitted
                        ? FilledButton(
                            onPressed: _nextQuestion,
                            child: Text(isLast ? '完成' : '下一题'),
                          )
                        : FilledButton(
                            onPressed: _isAnswerSubmitted() ? _submitAnswer : null,
                            child: const Text('提交答案'),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(QuestionType type, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(QuestionDifficulty difficulty, ThemeData theme) {
    final color = difficulty == QuestionDifficulty.easy
        ? Colors.green
        : difficulty == QuestionDifficulty.medium
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty.label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAnswerArea(Question question, ThemeData theme) {
    switch (question.type) {
      case QuestionType.singleChoice:
        return Column(
          children: List.generate(question.options.length, (index) {
            final option = question.options[index];
            final isSelected = _selectedIndex == index;
            final isCorrectAnswer = index == question.answerIndex;
            Color? bgColor;
            Color? borderColor;
            if (_submitted) {
              if (isCorrectAnswer) {
                bgColor = Colors.green.shade50;
                borderColor = Colors.green;
              } else if (isSelected) {
                bgColor = Colors.red.shade50;
                borderColor = Colors.red;
              }
            } else if (isSelected) {
              bgColor = Colors.green.shade50;
              borderColor = Colors.green;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: _submitted ? null : () => setState(() => _selectedIndex = index),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor ?? Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(16),
                    color: bgColor ?? (theme.brightness == Brightness.dark
                        ? theme.colorScheme.surface
                        : Colors.white),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: borderColor ?? Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(option)),
                      if (_submitted && isCorrectAnswer)
                        const Icon(Icons.check_circle, color: Colors.green),
                      if (_submitted && isSelected && !isCorrectAnswer)
                        const Icon(Icons.cancel, color: Colors.red),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      case QuestionType.multipleChoice:
        return Column(
          children: [
            if (!_submitted)
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedIndices = Set.from(List.generate(question.options.length, (i) => i));
                    }),
                    child: const Text('全选'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedIndices.clear();
                    }),
                    child: const Text('取消全选'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            ...List.generate(question.options.length, (index) {
              final option = question.options[index];
              final isSelected = _selectedIndices.contains(index);
              final isCorrectAnswer = question.answerIndices.contains(index);
              Color? bgColor;
              Color? borderColor;
              if (_submitted) {
                if (isCorrectAnswer) {
                  bgColor = Colors.green.shade50;
                  borderColor = Colors.green;
                } else if (isSelected) {
                  bgColor = Colors.red.shade50;
                  borderColor = Colors.red;
                }
              } else if (isSelected) {
                bgColor = Colors.green.shade50;
                borderColor = Colors.green;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: _submitted
                      ? null
                      : () => setState(() {
                            if (isSelected) {
                              _selectedIndices.remove(index);
                            } else {
                              _selectedIndices.add(index);
                            }
                          }),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor ?? Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(16),
                      color: bgColor ?? (theme.brightness == Brightness.dark
                          ? theme.colorScheme.surface
                          : Colors.white),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: borderColor ?? Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(option)),
                        if (_submitted && isCorrectAnswer)
                          const Icon(Icons.check_circle, color: Colors.green),
                        if (_submitted && isSelected && !isCorrectAnswer)
                          const Icon(Icons.cancel, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      case QuestionType.trueFalse:
        return Row(
          children: [
            Expanded(
              child: _buildBoolButton(
                label: '正确',
                value: true,
                selectedValue: _selectedBool,
                color: Colors.green,
                submitted: _submitted,
                correctValue: question.isCorrect,
                onTap: _submitted
                    ? null
                    : () => setState(() => _selectedBool = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBoolButton(
                label: '错误',
                value: false,
                selectedValue: _selectedBool,
                color: Colors.red,
                submitted: _submitted,
                correctValue: question.isCorrect,
                onTap: _submitted
                    ? null
                    : () => setState(() => _selectedBool = false),
              ),
            ),
          ],
        );
      case QuestionType.fillBlank:
        return TextField(
          controller: _fillBlankController,
          enabled: !_submitted,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: '请输入答案',
            filled: _submitted,
            fillColor: _submitted
                ? (_isCorrect ? Colors.green.shade50 : Colors.red.shade50)
                : null,
          ),
        );
    }
  }

  Widget _buildBoolButton({
    required String label,
    required bool value,
    required bool? selectedValue,
    required bool? correctValue,
    required Color color,
    required bool submitted,
    required VoidCallback? onTap,
  }) {
    final isSelected = selectedValue == value;
    final isCorrect = correctValue == value;
    Color? bgColor;
    Color? fgColor;
    if (submitted) {
      if (isCorrect) {
        bgColor = color.withValues(alpha: 0.1);
        fgColor = color;
      } else if (isSelected) {
        bgColor = Colors.grey.shade200;
        fgColor = Colors.grey;
      }
    } else if (isSelected) {
      bgColor = color.withValues(alpha: 0.1);
      fgColor = color;
    }
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (submitted && isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle, color: Colors.green, size: 18),
            ),
          if (submitted && isSelected && !isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.cancel, color: Colors.red, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildExplanationCard(Question question, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCorrect ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCorrect ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCorrect ? Icons.check_circle : Icons.info,
                color: _isCorrect ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _isCorrect ? '回答正确！' : '回答错误',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isCorrect ? Colors.green : Colors.orange,
                ),
              ),
              const Spacer(),
              // 朗读解析按钮
              if (question.explanation.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _isSpeakingExplanation
                        ? Icons.stop_circle_rounded
                        : Icons.volume_up_rounded,
                    size: 20,
                    color: _isCorrect ? Colors.green : Colors.orange,
                  ),
                  tooltip: _isSpeakingExplanation ? '停止朗读' : '朗读解析',
                  onPressed: () {
                    if (_isSpeakingExplanation) {
                      _stopSpeakingIfNeeded();
                    } else {
                      _speakExplanation(_isCorrect);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isCorrect) ...[
            Text(
              '正确答案：${AiAssistantLauncher.correctAnswerTextOf(question)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          if (question.explanation.isNotEmpty) ...[
            const Text('解析：', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            _buildSelectableWithAskAi(
              Text(
                question.explanation,
                style: TextStyle(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white70
                      : Colors.black87,
                  height: 1.5,
                ),
              ),
              question,
            ),
          ],
        ],
      ),
    );
  }

  /// 将一段内容包裹为可选中文本，并在选择菜单中追加"问 AI"入口
  Widget _buildSelectableWithAskAi(Widget child, Question question) {
    return AskAiSelectionArea(
      onAskAi: (text) => _askAiAboutQuestion(question, selectedText: text),
      child: child,
    );
  }

  /// 以当前题目为上下文向 AI 提问（[selectedText] 为用户选中的片段）
  void _askAiAboutQuestion(Question question, {String? selectedText}) {
    AiAssistantLauncher.showForQuestion(
      context,
      question: question,
      submitted: _submitted,
      selectedText: selectedText,
    );
  }
}
