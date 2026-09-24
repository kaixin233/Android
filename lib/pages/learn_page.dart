import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/textbooks.dart';
import '../models/question.dart';
import '../providers/app_provider.dart';
import 'exam_mode_page.dart';
import 'practice_page.dart';
import 'textbook_page.dart';
import 'wrong_questions_page.dart';
import 'stats_page.dart';
import 'review_page.dart';
import '../services/review_service.dart';
import '../services/storage_service.dart';

/// 学习首页
class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  ReviewStats _reviewStats = const ReviewStats(
    total: 0,
    due: 0,
    dueToday: 0,
    within3Days: 0,
    within7Days: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadReviewStats();
  }

  Future<void> _loadReviewStats() async {
    final items = await StorageService.loadReviewItems();
    final stats = ReviewService.summarize(items);
    if (!mounted) return;
    setState(() => _reviewStats = stats);
    await _maybeRemind(stats);
  }

  /// 有到期题目时按天提醒一次（可在「我的 → 复习提醒」关闭）。
  Future<void> _maybeRemind(ReviewStats stats) async {
    if (!stats.hasDue) return;
    if (!mounted) return;
    final app = context.read<AppProvider>();
    if (!app.reviewReminderEnabled) return;
    final today = _todayKey();
    final last = await StorageService.loadReviewReminderDate();
    if (last == today) return;
    await StorageService.saveReviewReminderDate(today);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('有 ${stats.due} 道题到了复习时间，别让记忆溜走～'),
          action: SnackBarAction(label: '去复习', onPressed: _openReview),
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  String _todayKey() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReviewPage()),
    );
    if (mounted) await _loadReviewStats();
  }

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
        title: const Text('二级建造师'),
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
                        color: colorScheme.onPrimary.withValues(alpha: 0.2),
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
          // 艾宾浩斯复习入口（含到期提醒）
          _buildReviewCard(theme, colorScheme),
          const SizedBox(height: 16),
          // 快速入口
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: '已学章节',
                  value: '${app.completedChapters}/${app.totalChapters}',
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
                onBookTap: () {
                  final book = Textbooks.all.firstWhere(
                    (b) => b.subject == subject,
                    orElse: () => Textbooks.all.first,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TextbookDetailPage(book: book)),
                  );
                },
              )),
        ],
      ),
    );
  }

  /// 艾宾浩斯复习入口卡片：展示到期数量，点击进入复习训练。
  Widget _buildReviewCard(ThemeData theme, ColorScheme colorScheme) {
    final due = _reviewStats.due;
    final hasDue = due > 0;
    final accent = hasDue ? Colors.deepOrange : colorScheme.primary;
    return Material(
      color: theme.brightness == Brightness.dark
          ? theme.colorScheme.surface
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openReview,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            color: hasDue ? accent.withValues(alpha: 0.06) : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accent.withValues(alpha: 0.14),
                child: Icon(Icons.psychology_alt_rounded, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('复习训练',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        if (hasDue) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10)),
                            child: Text('$due 待复习',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _reviewStats.total == 0
                          ? '做过的题会按遗忘曲线安排复习'
                          : (hasDue
                              ? '按艾宾浩斯遗忘曲线，有 $due 道题该复习了'
                              : '今天没有到期题目，共 ${_reviewStats.total} 题在计划中'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
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
            // 通过 AppProvider 更新状态，确保 UI 同步刷新
            await context.read<AppProvider>().addHistory(result);
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
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
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
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withValues(alpha: 0.12),
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
                  tooltip: '查看大纲',
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