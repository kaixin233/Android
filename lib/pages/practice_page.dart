import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../models/history_item.dart';
import '../providers/app_provider.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../utils/animations.dart';

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

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fillBlankController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final favorites = widget.config.onlyFavorites
        ? await StorageService.loadFavorites()
        : null;

    // 错题重做模式
    if (widget.config.mode == PracticeMode.wrong) {
      final wrongKeys = await StorageService.loadWrongQuestionKeys();
      _questions = await QuestionService.getByKeys(wrongKeys);
    } else {
      _questions = await QuestionService.filter(
        subject: widget.config.subject,
        type: widget.config.type,
        difficulty: widget.config.difficulty,
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

    if (widget.config.timeLimitSeconds != null) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final limit = widget.config.timeLimitSeconds!;
      setState(() {
        _elapsedSeconds++;
      });
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
    });
  }

  void _autoSubmit() {
    if (!_submitted && _isAnswerSubmitted()) {
      _submitAnswer();
    }
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
    setState(() {
      _submitted = true;
      _isCorrect = correct;
      // 修正已答过题目的正确数
      if (previous != null) {
        if (previous.isCorrect && !correct) {
          _correctCount--;
          _wrongKeys.add(uniqueKey);
          StorageService.addWrongQuestion(uniqueKey);
        } else if (!previous.isCorrect && correct) {
          _correctCount++;
          _wrongKeys.remove(uniqueKey);
          StorageService.removeWrongQuestion(uniqueKey);
        }
      } else {
        if (correct) {
          _correctCount++;
        } else {
          _wrongKeys.add(uniqueKey);
          StorageService.addWrongQuestion(uniqueKey);
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
    final app = context.read<AppProvider>();
    if (app.vibrationEnabled) {
      if (correct) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _nextQuestion() {
    if (_currentIndex == _questions.length - 1) {
      _finishPractice();
      return;
    }
    setState(() {
      _currentIndex++;
      _restoreQuestionState();
    });
  }

  void _previousQuestion() {
    if (_currentIndex == 0) return;
    setState(() {
      _currentIndex--;
      _restoreQuestionState();
    });
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
    await widget.onCompleted(result);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('练习完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('答对：$_correctCount / $total 题',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('正确率：${total == 0 ? 0 : (_correctCount * 100 ~/ total)}%'),
            const SizedBox(height: 4),
            Text('用时：${_formatDuration(_elapsedSeconds)}'),
            if (_wrongKeys.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('错题数：${_wrongKeys.length}（已加入错题本）',
                  style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
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
    return '${m}分${s.toString().padLeft(2, '0')}秒';
  }

  String _formatRemainingTime() {
    if (widget.config.timeLimitSeconds == null) return '';
    final remaining = max(0, widget.config.timeLimitSeconds! - _elapsedSeconds);
    final m = remaining ~/ 60;
    final s = remaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPracticeTitle()),
        actions: [
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
              // 进度条
              Row(
                children: [
                  Text(
                    '第 ${_currentIndex + 1} / ${_questions.length} 题',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: question.subject == QuestionSubject.law
                          ? Colors.blue.shade50
                          : question.subject == QuestionSubject.management
                              ? Colors.orange.shade50
                              : question.subject == QuestionSubject.economy
                                  ? Colors.green.shade50
                                  : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      question.subject.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: question.subject == QuestionSubject.law
                            ? Colors.blue
                            : question.subject == QuestionSubject.management
                                ? Colors.orange
                                : question.subject == QuestionSubject.economy
                                    ? Colors.green
                                    : Colors.purple,
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
              const SizedBox(height: 12),
              ProgressBarAnimation(
                progress: (_currentIndex + 1) / _questions.length,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('第 ${_currentIndex + 1} / ${_questions.length} 题'),
                  Text('进度: ${((_currentIndex + 1) / _questions.length * 100).toInt()}%'),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.prompt,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
        color: color.withOpacity(0.1),
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
        bgColor = color.withOpacity(0.1);
        fgColor = color;
      } else if (isSelected) {
        bgColor = Colors.grey.shade200;
        fgColor = Colors.grey;
      }
    } else if (isSelected) {
      bgColor = color.withOpacity(0.1);
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
            ],
          ),
          const SizedBox(height: 8),
          if (!_isCorrect) ...[
            Text(
              '正确答案：${_getCorrectAnswerText(question)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          if (question.explanation.isNotEmpty) ...[
            const Text('解析：', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              question.explanation,
              style: TextStyle(color: Colors.black87, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  String _getCorrectAnswerText(Question question) {
    switch (question.type) {
      case QuestionType.singleChoice:
        if (question.answerIndex != null && question.answerIndex! < question.options.length) {
          return question.options[question.answerIndex!];
        }
        return '未知';
      case QuestionType.multipleChoice:
        return question.answerIndices
            .where((i) => i < question.options.length)
            .map((i) => question.options[i])
            .join('、');
      case QuestionType.trueFalse:
        return question.isCorrect == true ? '正确' : '错误';
      case QuestionType.fillBlank:
        return question.acceptableAnswers.join(' / ');
    }
  }
}
