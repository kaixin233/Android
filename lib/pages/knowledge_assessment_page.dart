import 'dart:math';

import 'package:flutter/material.dart';

import '../models/history_item.dart';
import '../models/knowledge_point.dart';
import '../services/storage_service.dart';
import 'practice_page.dart';

class KnowledgeAssessmentPage extends StatefulWidget {
  const KnowledgeAssessmentPage({super.key});

  @override
  State<KnowledgeAssessmentPage> createState() => _KnowledgeAssessmentPageState();
}

class _KnowledgeAssessmentPageState extends State<KnowledgeAssessmentPage> {
  List<KnowledgePointStats> _stats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _stats = await StorageService.loadKnowledgeStats();
    } catch (e) {
      debugPrint('Error loading knowledge stats: $e');
    }
    setState(() => _isLoading = false);
  }

  String _getMasteryLevel(double mastery) {
    if (mastery >= 0.9) return '优秀';
    if (mastery >= 0.7) return '良好';
    if (mastery >= 0.5) return '中等';
    if (mastery >= 0.3) return '薄弱';
    return '需加强';
  }

  Color _getMasteryColor(double mastery) {
    if (mastery >= 0.9) return const Color(0xFF10B981);
    if (mastery >= 0.7) return const Color(0xFF3B82F6);
    if (mastery >= 0.5) return const Color(0xFFF59E0B);
    if (mastery >= 0.3) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  Widget _buildRadarChart(ThemeData theme) {
    if (_stats.isEmpty) {
      return const Center(child: Text('暂无知识点数据'));
    }

    final maxMastery = _stats.fold(0.0, (max, s) => s.point.masteryLevel > max ? s.point.masteryLevel : max);
    
    return SizedBox(
      height: 300,
      child: CustomPaint(
        painter: RadarChartPainter(_stats, theme),
      ),
    );
  }

  List<KnowledgePointStats> _getWeakPoints() {
    return _stats
        .where((s) => s.point.masteryLevel < 0.6)
        .toList()
      ..sort((a, b) => a.point.masteryLevel.compareTo(b.point.masteryLevel));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weakPoints = _getWeakPoints();

    return Scaffold(
      appBar: AppBar(
        title: const Text('知识点掌握评估'),
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
                        Text('知识点雷达图', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 16),
                        _buildRadarChart(theme),
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
                        Text('知识点列表', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        _stats.isEmpty
                            ? const Center(child: Text('暂无知识点数据'))
                            : Column(
                                children: _stats.map((stat) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(stat.point.name, style: theme.textTheme.bodyMedium),
                                                Text(
                                                  '正确率: ${((stat.point.correctCount / (stat.point.totalQuestions > 0 ? stat.point.totalQuestions : 1)) * 100).toStringAsFixed(0)}%',
                                                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              color: _getMasteryColor(stat.point.masteryLevel).withOpacity(0.1),
                                            ),
                                            child: Text(
                                              _getMasteryLevel(stat.point.masteryLevel),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: _getMasteryColor(stat.point.masteryLevel),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )).toList(),
                              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (weakPoints.isNotEmpty)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('薄弱知识点', style: theme.textTheme.titleMedium?.copyWith(color: Colors.orange.shade700)),
                          const SizedBox(height: 12),
                          Column(
                            children: weakPoints.map((stat) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning, color: Colors.orange.shade600, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(stat.point.name)),
                                      Text(
                                        '${(stat.point.masteryLevel * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(color: Colors.orange),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PracticePage(
                              config: PracticeConfig(mode: PracticeMode.practice),
                              onCompleted: (_) async => _loadData(),
                            ),
                                ),
                              );
                            },
                            child: const Text('针对薄弱点练习'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<KnowledgePointStats> stats;
  final ThemeData theme;

  RadarChartPainter(this.stats, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    if (stats.isEmpty) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 2 - 40;
    final count = stats.length;
    final angleStep = (2 * 3.14159) / count;

    final gridPaint = Paint()
      ..color = theme.colorScheme.outlineVariant
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int level = 1; level <= 5; level++) {
      final r = radius * level / 5;
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = angleStep * i - 3.14159 / 2;
        final x = centerX + r * cos(angle);
        final y = centerY + r * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (int i = 0; i < count; i++) {
      final angle = angleStep * i - 3.14159 / 2;
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      canvas.drawLine(Offset(centerX, centerY), Offset(x, y), gridPaint);
    }

    final dataPaint = Paint()
      ..color = theme.colorScheme.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dataPath = Path();
    for (int i = 0; i < count; i++) {
      final angle = angleStep * i - 3.14159 / 2;
      final value = stats[i].point.masteryLevel;
      final r = radius * value;
      final x = centerX + r * cos(angle);
      final y = centerY + r * sin(angle);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);

    final dataFillPaint = Paint()
      ..color = theme.colorScheme.primary.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, dataFillPaint);

    final textStyle = theme.textTheme.labelSmall;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < count; i++) {
      final angle = angleStep * i - 3.14159 / 2;
      final r = radius + 20;
      final x = centerX + r * cos(angle);
      final y = centerY + r * sin(angle);

      textPainter.text = TextSpan(text: stats[i].point.name, style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}