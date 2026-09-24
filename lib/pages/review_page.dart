import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/history_item.dart';
import '../models/question.dart';
import '../models/review_item.dart';
import '../providers/app_provider.dart';
import '../services/question_service.dart';
import '../services/review_service.dart';
import '../services/storage_service.dart';
import 'practice_page.dart';

/// 艾宾浩斯遗忘曲线 · 复习训练
///
/// 汇总所有"做过的题"（含错题），按遗忘曲线间隔计算到期队列，
/// 支持一键开始复习。入口位于首页。
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _loading = true;
  Map<String, ReviewItem> _items = {};
  Map<String, Question> _questionsByKey = {};
  ReviewStats _stats = const ReviewStats(
    total: 0,
    due: 0,
    dueToday: 0,
    within3Days: 0,
    within7Days: 0,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await StorageService.loadReviewItems();
    final keys = items.keys.toList();
    final questions = keys.isEmpty
        ? <Question>[]
        : await QuestionService.getByKeys(keys);
    if (!mounted) return;
    setState(() {
      _items = items;
      _questionsByKey = {for (final q in questions) q.uniqueKey: q};
      _stats = ReviewService.summarize(items);
      _loading = false;
    });
  }

  /// 可复习的到期题目 key（过滤掉题库中已不存在的题目）
  List<String> get _dueKeys {
    final now = DateTime.now();
    final keys = _items.values
        .where((e) => e.isDue(now) && _questionsByKey.containsKey(e.questionKey))
        .toList()
      ..sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
    return keys.map((e) => e.questionKey).toList();
  }

  List<String> get _allExistingKeys => _questionsByKey.keys.toList();

  Future<void> _startReview(List<String> keys, {required bool isReview}) async {
    if (keys.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          config: PracticeConfig(
            mode: isReview ? PracticeMode.review : PracticeMode.practice,
            questionKeys: keys,
            shuffleQuestions: true,
          ),
          onCompleted: (result) async {
            await context.read<AppProvider>().addHistory(result);
          },
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('复习训练'), centerTitle: false),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState(theme)
              : _buildContent(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded,
                size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('还没有可复习的题目',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '做过的题会自动加入遗忘曲线复习计划，\n到时间会在这里提醒你复习。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final color = theme.colorScheme.primary;
    final dueKeys = _dueKeys;
    final dueList = dueKeys.map((k) => _items[k]!).toList();

    // 未来 7 天内（不含已到期）即将复习
    final now = DateTime.now();
    final upcoming = _items.values
        .where((e) => !e.isDue(now) && e.daysUntilDue(now) <= 7)
        .toList()
      ..sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 概览卡片
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_alt_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('艾宾浩斯遗忘曲线',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _stats.due > 0 ? '有 ${_stats.due} 道题该复习了' : '今天没有到期题目',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '复习计划中共 ${_stats.total} 道题',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: dueKeys.isEmpty
                          ? null
                          : () => _startReview(dueKeys, isReview: true),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        dueKeys.isEmpty ? '暂无到期' : '开始复习（${dueKeys.length}）',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: color,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 复习进度概览
        Row(
          children: [
            Expanded(
              child: _statTile('已到期', '${_stats.due}', Icons.notifications_active_rounded,
                  Colors.red),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statTile('3 天内', '${_stats.within3Days}', Icons.schedule_rounded,
                  Colors.orange),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statTile('7 天内', '${_stats.within7Days}', Icons.event_rounded,
                  Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (dueList.isNotEmpty) ...[
          _sectionTitle('待复习（${dueList.length}）'),
          const SizedBox(height: 8),
          ...dueList.map((e) => _buildItemTile(e, theme, overdue: true)),
          const SizedBox(height: 16),
        ],

        if (upcoming.isNotEmpty) ...[
          _sectionTitle('即将复习'),
          const SizedBox(height: 8),
          ...upcoming.take(20).map((e) => _buildItemTile(e, theme, overdue: false)),
          const SizedBox(height: 16),
        ],

        if (_allExistingKeys.isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: () => _startReview(_allExistingKeys, isReview: false),
            icon: const Icon(Icons.replay_rounded),
            label: Text('复习全部（${_allExistingKeys.length} 题）'),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildItemTile(ReviewItem item, ThemeData theme, {required bool overdue}) {
    final q = _questionsByKey[item.questionKey];
    if (q == null) return const SizedBox.shrink();
    final days = item.daysUntilDue();
    final statusText = overdue
        ? (days < 0 ? '逾期 ${-days} 天' : '今天到期')
        : '$days 天后';
    final statusColor = overdue
        ? (days < 0 ? Colors.red : Colors.orange)
        : Colors.blueGrey;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: q.subject.color.withValues(alpha: 0.15),
          child: Icon(q.subject.icon, color: q.subject.color, size: 16),
        ),
        title: Text(
          q.title.isNotEmpty ? q.title : q.prompt,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${q.subject.label} · 第 ${item.stage + 1}/${ReviewItem.intervals.length} 阶段'
          '${item.wrongCount > 0 ? ' · 错 ${item.wrongCount} 次' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          statusText,
          style: TextStyle(
              fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
