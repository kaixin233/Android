import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/history_item.dart';
import '../models/question.dart';
import '../services/storage_service.dart';

/// 统计页面 - 展示学习数据可视化
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<HistoryItem> _history = [];
  Map<String, int> _wrongCounts = {};
  List<String> _wrongKeys = [];
  int _streakDays = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _history = await StorageService.loadHistory();
    _wrongCounts = await StorageService.loadWrongCounts();
    _wrongKeys = await StorageService.loadWrongQuestionKeys();
    _streakDays = await StorageService.loadStreakDays();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('学习统计')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalQuestions = _history.fold<int>(0, (sum, h) => sum + h.totalCount);
    final totalCorrect = _history.fold<int>(0, (sum, h) => sum + h.correctCount);
    final overallAccuracy = totalQuestions == 0 ? 0.0 : totalCorrect / totalQuestions;
    final totalDuration = _history.fold<int>(0, (sum, h) => sum + h.durationSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('学习统计')),
      body: _history.isEmpty
          ? _buildEmpty(theme)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryCard(
                  theme,
                  totalQuestions: totalQuestions,
                  totalCorrect: totalCorrect,
                  accuracy: overallAccuracy,
                  duration: totalDuration,
                  practiceCount: _history.length,
                  streakDays: _streakDays,
                ),
                const SizedBox(height: 16),
                _buildAccuracyTrendChart(theme),
                const SizedBox(height: 16),
                _buildSubjectDistribution(theme),
                const SizedBox(height: 16),
                _buildSubjectAccuracy(theme),
                const SizedBox(height: 16),
                _buildModeStats(theme),
                const SizedBox(height: 16),
                _buildTimeDistribution(theme),
                const SizedBox(height: 16),
                _buildRecentHistory(theme),
              ],
            ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insights_rounded, size: 80, color: theme.colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('暂无学习数据',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('完成练习后即可查看统计', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    ThemeData theme, {
    required int totalQuestions,
    required int totalCorrect,
    required double accuracy,
    required int duration,
    required int practiceCount,
    required int streakDays,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('总体概况', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _summaryItem(Icons.quiz_rounded, '$totalQuestions', '累计答题', Colors.blue),
                _summaryItem(Icons.check_circle, '$totalCorrect', '答对题数', Colors.green),
                _summaryItem(Icons.percent_rounded, '${(accuracy * 100).toStringAsFixed(0)}%', '正确率', Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryItem(Icons.timer_rounded, _formatDuration(duration), '总用时', Colors.purple),
                _summaryItem(Icons.history_rounded, '$practiceCount', '练习次数', Colors.teal),
                _summaryItem(Icons.local_fire_department_rounded, '$streakDays', '连续天数', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAccuracyTrendChart(ThemeData theme) {
    final recent = _history.length > 10 ? _history.sublist(_history.length - 10) : _history;
    final spots = <FlSpot>[];
    for (var i = 0; i < recent.length; i++) {
      final accuracy = recent[i].accuracy * 100;
      spots.add(FlSpot(i.toDouble(), accuracy));
    }
    final maxY = 100.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('正确率趋势（最近${recent.length}次）',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('查看你近期的练习表现', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 32),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 24),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectDistribution(ThemeData theme) {
    // 按科目统计练习次数
    final subjectCount = <QuestionSubject, int>{};
    for (final h in _history) {
      if (h.subject != null) {
        subjectCount[h.subject!] = (subjectCount[h.subject!] ?? 0) + 1;
      }
    }
    final sections = <PieChartSectionData>[];
    final colors = <QuestionSubject, Color>{
      QuestionSubject.law: Colors.blue,
      QuestionSubject.management: Colors.orange,
      QuestionSubject.economy: Colors.green,
      QuestionSubject.practice: Colors.purple,
    };
    subjectCount.forEach((subject, count) {
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: colors[subject],
        title: '${subject.label}\n$count次',
        radius: 60,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      ));
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('科目分布', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: sections.isEmpty
                  ? const Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey)))
                  : PieChart(PieChartData(
                      sections: sections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectAccuracy(ThemeData theme) {
    final subjectStats = <QuestionSubject, Map<String, int>>{};
    for (final h in _history) {
      if (h.subject != null) {
        final stats = subjectStats.putIfAbsent(h.subject!, () => {'correct': 0, 'total': 0});
        stats['correct'] = stats['correct']! + h.correctCount;
        stats['total'] = stats['total']! + h.totalCount;
      }
    }

    final subjects = QuestionSubject.values;
    final colors = <QuestionSubject, Color>{
      QuestionSubject.law: Colors.blue,
      QuestionSubject.management: Colors.orange,
      QuestionSubject.economy: Colors.green,
      QuestionSubject.practice: Colors.purple,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('科目正确率', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...subjects.map((subject) {
              final stats = subjectStats[subject];
              if (stats == null || stats['total'] == 0) return const SizedBox.shrink();
              final accuracy = stats['correct']! / stats['total']!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[subject],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(subject.label)),
                        Text('${(accuracy * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: accuracy,
                      backgroundColor: colors[subject]!.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(colors[subject]!),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 8,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildModeStats(ThemeData theme) {
    final modeCount = <PracticeMode, int>{};
    for (final h in _history) {
      modeCount[h.mode] = (modeCount[h.mode] ?? 0) + 1;
    }
    final bars = <BarChartGroupData>[];
    final modes = PracticeMode.values;
    final colors = [Colors.blue, Colors.orange, Colors.red];
    for (var i = 0; i < modes.length; i++) {
      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (modeCount[modes[i]] ?? 0).toDouble(),
            color: colors[i],
            width: 32,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('练习方式统计', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < modes.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(modes[idx].label, style: const TextStyle(fontSize: 11)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: bars,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDistribution(ThemeData theme) {
    final hourCount = <int, int>{};
    for (final h in _history) {
      try {
        final dt = DateTime.parse(h.answeredAt);
        hourCount[dt.hour] = (hourCount[dt.hour] ?? 0) + 1;
      } catch (_) {}
    }

    final bars = <BarChartGroupData>[];
    final hours = List.generate(24, (i) => i);
    for (var i = 0; i < hours.length; i++) {
      bars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (hourCount[hours[i]] ?? 0).toDouble(),
            color: hourCount[hours[i]] != null && hourCount[hours[i]]! > 0
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withOpacity(0.2),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('学习时间分布', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('查看你在一天中哪个时段学习最活跃', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceEvenly,
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 4,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          return Text('${idx}:00', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: bars,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHistory(ThemeData theme) {
    final recent = _history.reversed.take(10).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近记录', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...recent.map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: h.accuracy >= 0.8
                            ? Colors.green
                            : h.accuracy >= 0.6
                                ? Colors.orange
                                : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${h.mode.label} · ${h.correctCount}/${h.totalCount} · ${h.accuracyText} · ${h.durationText}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDate(h.answeredAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}秒';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60) return '${m}分${s}秒';
    final h = m ~/ 60;
    final rm = m % 60;
    return '${h}小时${rm}分';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
