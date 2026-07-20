import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/history_item.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import 'practice_page.dart';

/// 考试模式页面 - 倒计时、自动交卷
class ExamModePage extends StatefulWidget {
  const ExamModePage({super.key});

  @override
  State<ExamModePage> createState() => _ExamModePageState();
}

class _ExamModePageState extends State<ExamModePage> {
  QuestionSubject? _selectedSubject;
  int _questionCount = 20;
  int _durationMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('考试模式')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text('模拟考试',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '设定时长和题量，模拟真实考试环境。到时自动交卷，检验你的真实水平。',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('选择科目', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSubjectChoice(null, '综合', theme),
              ...QuestionSubject.values.map((s) => _buildSubjectChoice(s, s.label, theme)),
            ],
          ),
          const SizedBox(height: 24),
          Text('题目数量：$_questionCount 题', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Slider(
            value: _questionCount.toDouble(),
            min: 10,
            max: 50,
            divisions: 8,
            label: '$_questionCount',
            onChanged: (v) => setState(() => _questionCount = v.round()),
          ),
          const SizedBox(height: 16),
          Text('考试时长：$_durationMinutes 分钟', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Slider(
            value: _durationMinutes.toDouble(),
            min: 10,
            max: 120,
            divisions: 11,
            label: '$_durationMinutes',
            onChanged: (v) => setState(() => _durationMinutes = v.round()),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _startExam,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('开始考试'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('考试说明', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• 题目顺序随机生成'),
                  const Text('• 选项顺序随机打乱'),
                  const Text('• 倒计时结束自动交卷'),
                  const Text('• 答错的题目自动加入错题本'),
                  const Text('• 考试结果计入学习统计'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChoice(QuestionSubject? subject, String label, ThemeData theme) {
    final selected = _selectedSubject == subject;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedSubject = subject),
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : null),
    );
  }

  Future<void> _startExam() async {
    // 检查题量是否足够
    final available = await QuestionService.filter(subject: _selectedSubject);
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该科目暂无题目，请先导入题库')),
        );
      }
      return;
    }

    final actualCount = available.length < _questionCount ? available.length : _questionCount;

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PracticePage(
            config: PracticeConfig(
              subject: _selectedSubject,
              mode: PracticeMode.exam,
              shuffleQuestions: true,
              shuffleOptions: true,
              questionLimit: actualCount,
              timeLimitSeconds: _durationMinutes * 60,
            ),
            onCompleted: (HistoryItem result) async {
              await StorageService.addHistory(result);
            },
          ),
        ),
      );
    }
  }
}
