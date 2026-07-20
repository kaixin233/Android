import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';
import 'exam_mode_page.dart';
import 'practice_page.dart';
import 'textbook_page.dart';
import 'wrong_questions_page.dart';
import 'stats_page.dart';

/// 学习首页
class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? null
          : const Color(0xFFF5FFF7),
      appBar: AppBar(
        title: const Text('一级建造师'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 今日练习卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日练习',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('选择科目开始你的学习之旅',
                    style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onPrimary)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _startPractice(context, subject: null),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('综合练习'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.onPrimary,
                          foregroundColor: colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('${app.streakDays} 天',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 快速入口
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '已学章节',
                  value: '${app.completedChapters}/12',
                  icon: Icons.menu_book_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TextbookPage()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '考试模式',
                  value: '模拟考',
                  icon: Icons.timer_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExamModePage()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '错题本',
                  value: '复习',
                  icon: Icons.error_outline_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WrongQuestionsPage()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: '学习统计',
                  value: '查看',
                  icon: Icons.insights_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsPage()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 科目列表
          Text('选择科目练习', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...QuestionSubject.values.map((subject) => _SubjectCard(
                subject: subject,
                onTap: () => _startPractice(context, subject: subject),
                onBookTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TextbookPage()),
                ),
              )),
        ],
      ),
    );
  }

  void _startPractice(BuildContext context, {QuestionSubject? subject}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          config: PracticeConfig(
            subject: subject,
            shuffleQuestions: true,
          ),
          onCompleted: (result) async {
            await StorageService.addHistory(result);
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.onTap, required this.onBookTap});

  final QuestionSubject subject;
  final VoidCallback onTap;
  final VoidCallback onBookTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = subject.color;
    final icon = subject.icon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subject.label,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subject.description,
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onBookTap,
                  icon: const Icon(Icons.menu_book_rounded),
                  tooltip: '查看教材',
                ),
                FilledButton.tonal(
                  onPressed: onTap,
                  child: const Text('开始'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}