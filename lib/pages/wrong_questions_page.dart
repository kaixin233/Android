import 'package:flutter/material.dart';

import '../models/history_item.dart';
import '../models/question.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import 'practice_page.dart';
import 'wrong_analysis_page.dart';

/// 错题本页面 - 显示错题列表，支持错题重做
class WrongQuestionsPage extends StatefulWidget {
  const WrongQuestionsPage({super.key});

  @override
  State<WrongQuestionsPage> createState() => _WrongQuestionsPageState();
}

class _WrongQuestionsPageState extends State<WrongQuestionsPage> {
  List<Question> _wrongQuestions = [];
  Map<String, int> _wrongCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final keys = await StorageService.loadWrongQuestionKeys();
    final counts = await StorageService.loadWrongCounts();
    final questions = await QuestionService.getByKeys(keys);
    // 按错误次数降序排序
    questions.sort((a, b) => (counts[b.uniqueKey] ?? 0).compareTo(counts[a.uniqueKey] ?? 0));
    setState(() {
      _wrongQuestions = questions;
      _wrongCounts = counts;
      _isLoading = false;
    });
  }

  Future<void> _removeWrong(Question question) async {
    await StorageService.removeWrongQuestion(question.uniqueKey);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除「${question.title}」')),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空错题本'),
        content: const Text('将清空所有错题记录，确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('清空')),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.saveWrongQuestionKeys([]);
      await StorageService.saveWrongCounts({});
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('错题本已清空')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('错题本'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WrongAnalysisPage()),
            ),
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: '分析',
          ),
          if (_wrongQuestions.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: '清空',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wrongQuestions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 64,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '🎉 太棒了！',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '你的错题本是空的，说明你最近的练习表现很好！',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '继续保持，早日通过考试！',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PracticePage(
                                  config: const PracticeConfig(mode: PracticeMode.practice),
                                  onCompleted: (_) async {},
                                ),
                              ),
                            );
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded),
                              SizedBox(width: 8),
                              Text('开始练习'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.shade400, Colors.orange.shade400],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '共 ${_wrongQuestions.length} 道错题',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '反复练习，攻克难点',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PracticePage(
                                    config: const PracticeConfig(mode: PracticeMode.wrong),
                                    onCompleted: (result) async {
                                      await StorageService.addHistory(result);
                                    },
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade700,
                            ),
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('错题重做'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _wrongQuestions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final q = _wrongQuestions[index];
                          final count = _wrongCounts[q.uniqueKey] ?? 1;
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.shade50,
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                q.prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 6,
                                  children: [
                                    _tag(q.subject.label, Colors.blue),
                                    _tag(q.type.label, Colors.green),
                                    _tag('错 $count 次', Colors.red),
                                  ],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => _removeWrong(q),
                                tooltip: '移除',
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PracticePage(
                                      config: PracticeConfig(
                                        subject: q.subject,
                                        type: q.type,
                                      ),
                                      onCompleted: (result) async {
                                        await StorageService.addHistory(result);
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
