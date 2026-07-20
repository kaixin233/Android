import 'package:flutter/material.dart';

import '../models/history_item.dart';
import '../models/question.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import 'practice_page.dart';

class WrongAnalysisPage extends StatefulWidget {
  const WrongAnalysisPage({super.key});

  @override
  State<WrongAnalysisPage> createState() => _WrongAnalysisPageState();
}

class _WrongAnalysisPageState extends State<WrongAnalysisPage> {
  List<Question> _wrongQuestions = [];
  Map<QuestionSubject, int> _wrongBySubject = {};
  Map<QuestionType, int> _wrongByType = {};
  Map<String, int> _wrongByDifficulty = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final wrongKeys = await StorageService.loadWrongQuestionKeys();
      final wrongCounts = await StorageService.loadWrongCounts();
      
      final allQuestions = await QuestionService.getAllQuestions();
      _wrongQuestions = allQuestions.where((q) => wrongKeys.contains(q.uniqueKey)).toList();
      
      _wrongBySubject = {};
      _wrongByType = {};
      _wrongByDifficulty = {};
      
      for (final q in _wrongQuestions) {
        _wrongBySubject[q.subject] = (_wrongBySubject[q.subject] ?? 0) + (wrongCounts[q.uniqueKey] ?? 1);
        _wrongByType[q.type] = (_wrongByType[q.type] ?? 0) + (wrongCounts[q.uniqueKey] ?? 1);
        _wrongByDifficulty[q.difficulty.label] = (_wrongByDifficulty[q.difficulty.label] ?? 0) + (wrongCounts[q.uniqueKey] ?? 1);
      }
    } catch (e) {
      debugPrint('Error loading wrong questions analysis: $e');
    }
    setState(() => _isLoading = false);
  }

  Widget _buildSubjectChart(ThemeData theme) {
    if (_wrongBySubject.isEmpty) {
      return const Center(child: Text('暂无错题数据'));
    }
    
    final maxCount = _wrongBySubject.values.reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: _wrongBySubject.entries.map((entry) {
        final percentage = (entry.value / maxCount) * 100;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 80,
                child: Text(entry.key.label, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceVariant,
                  ),
                  child: Container(
                    height: 24,
                    width: percentage,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _getSubjectColor(entry.key),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('${entry.value}', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeChart(ThemeData theme) {
    if (_wrongByType.isEmpty) {
      return const Center(child: Text('暂无错题数据'));
    }
    
    final maxCount = _wrongByType.values.reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: _wrongByType.entries.map((entry) {
        final percentage = (entry.value / maxCount) * 100;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 80,
                child: Text(entry.key.label, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceVariant,
                  ),
                  child: Container(
                    height: 24,
                    width: percentage,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _getTypeColor(entry.key),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('${entry.value}', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDifficultyChart(ThemeData theme) {
    if (_wrongByDifficulty.isEmpty) {
      return const Center(child: Text('暂无错题数据'));
    }
    
    final maxCount = _wrongByDifficulty.values.reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: _wrongByDifficulty.entries.map((entry) {
        final percentage = (entry.value / maxCount) * 100;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 80,
                child: Text(entry.key, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.colorScheme.surfaceVariant,
                  ),
                  child: Container(
                    height: 24,
                    width: percentage,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _getDifficultyColor(entry.key),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text('${entry.value}', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getSubjectColor(QuestionSubject subject) {
    switch (subject) {
      case QuestionSubject.law:
        return const Color(0xFFEF4444);
      case QuestionSubject.management:
        return const Color(0xFF3B82F6);
      case QuestionSubject.economy:
        return const Color(0xFFF59E0B);
      case QuestionSubject.practice:
        return const Color(0xFF10B981);
    }
  }

  Color _getTypeColor(QuestionType type) {
    switch (type) {
      case QuestionType.singleChoice:
        return const Color(0xFF6366F1);
      case QuestionType.multipleChoice:
        return const Color(0xFFEC4899);
      case QuestionType.trueFalse:
        return const Color(0xFF8B5CF6);
      case QuestionType.fillBlank:
        return const Color(0xFF06B6D4);
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case '简单':
        return const Color(0xFF10B981);
      case '中等':
        return const Color(0xFFF59E0B);
      case '困难':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题深度分析'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('错题概况', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard('总错题数', '${_wrongQuestions.length}', Colors.red),
                            _buildStatCard('涉及科目', '${_wrongBySubject.length}', Colors.blue),
                            _buildStatCard('涉及题型', '${_wrongByType.length}', Colors.purple),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('按科目分布', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildSubjectChart(theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('按题型分布', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildTypeChart(theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('按难度分布', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildDifficultyChart(theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('学习建议', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _buildRecommendations(theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _wrongQuestions.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PracticePage(
                              config: PracticeConfig(mode: PracticeMode.wrong),
                              onCompleted: (_) async {
                                await _loadData();
                              },
                            ),
                            ),
                          );
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('开始错题练习'),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildRecommendations(ThemeData theme) {
    final recommendations = <String>[];
    
    if (_wrongBySubject.isNotEmpty) {
      final worstSubject = _wrongBySubject.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      recommendations.add('重点复习「${worstSubject.label}」科目，该科目错题最多');
    }
    
    if (_wrongByType.isNotEmpty) {
      final worstType = _wrongByType.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      recommendations.add('加强「${worstType.label}」题型的练习');
    }
    
    if (_wrongByDifficulty.containsKey('困难') && _wrongByDifficulty['困难']! > 3) {
      recommendations.add('困难题目较多，建议先复习相关知识点再进行练习');
    }
    
    if (recommendations.isEmpty) {
      return const Text('暂无错题，继续保持！');
    }
    
    return Column(
      children: recommendations.map((rec) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(rec, style: theme.textTheme.bodyMedium)),
          ],
        ),
      )).toList(),
    );
  }
}