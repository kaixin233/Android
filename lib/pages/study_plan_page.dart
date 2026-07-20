import 'package:flutter/material.dart';

import '../models/study_plan.dart';
import '../models/question.dart';
import '../models/history_item.dart';
import '../services/storage_service.dart';
import 'practice_page.dart';

class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({super.key});

  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  List<StudyPlan> _plans = [];
  DateTime _selectedDate = DateTime.now();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final plans = await StorageService.loadStudyPlans();
    setState(() {
      _plans = plans;
    });
  }

  Future<void> _createPlan() async {
    final result = await showDialog<StudyPlan>(
      context: context,
      builder: (_) => const _CreatePlanDialog(),
    );
    if (result != null) {
      await StorageService.saveStudyPlan(result);
      await _loadPlans();
    }
  }

  Future<void> _deletePlan(String id) async {
    await StorageService.deleteStudyPlan(id);
    await _loadPlans();
  }

  void _startPlan(StudyPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PracticePage(
          config: PracticeConfig(
            subject: plan.subject,
            questionLimit: plan.targetQuestions,
            mode: PracticeMode.practice,
            shuffleQuestions: true,
          ),
          onCompleted: (result) async {
            await StorageService.addHistory(result);
            await StorageService.markPlanDayCompleted(plan.id);
            await _loadPlans();
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildPlanCard(StudyPlan plan) {
    final theme = Theme.of(context);
    final color = _getSubjectColor(plan.subject);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(plan.type == PlanType.daily ? Icons.calendar_today_rounded : 
                    plan.type == PlanType.weekly ? Icons.calendar_view_week_rounded : 
                    Icons.flag_rounded,
                  color: color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plan.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deletePlan(plan.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip('${plan.subject.label}', color),
                const SizedBox(width: 8),
                _buildInfoChip('${plan.type.label}', theme.colorScheme.secondary),
                const SizedBox(width: 8),
                _buildInfoChip('${plan.targetQuestions}题', theme.colorScheme.tertiary),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: plan.progress,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              borderRadius: BorderRadius.circular(8),
              minHeight: 8,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${plan.completedDays}/${plan.totalDays} 天'),
                Text('${(plan.progress * 100).toInt()}%'),
              ],
            ),
            const SizedBox(height: 16),
            if (plan.isActive && !plan.isCompleted)
              FilledButton(
                onPressed: () => _startPlan(plan),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded),
                    SizedBox(width: 8),
                    Text('开始学习'),
                  ],
                ),
              ),
            if (plan.isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: const Text(
                  '🎉 计划已完成！',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }

  Color _getSubjectColor(QuestionSubject subject) {
    switch (subject) {
      case QuestionSubject.law:
        return const Color(0xFF2196F3);
      case QuestionSubject.management:
        return const Color(0xFFFF9800);
      case QuestionSubject.economy:
        return const Color(0xFF4CAF50);
      case QuestionSubject.practice:
        return const Color(0xFF9C27B0);
    }
  }

  Widget _buildCalendar() {
    final theme = Theme.of(context);
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1).weekday;

    final weeks = <List<DateTime?>>[];
    List<DateTime?> currentWeek = List.filled(7, null);

    for (int i = 1; i <= daysInMonth; i++) {
      currentWeek[(firstDay + i - 2) % 7] = DateTime(_selectedDate.year, _selectedDate.month, i);
      if ((firstDay + i - 1) % 7 == 0) {
        weeks.add(currentWeek);
        currentWeek = List.filled(7, null);
      }
    }
    if (currentWeek.any((d) => d != null)) {
      weeks.add(currentWeek);
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => setState(() {
                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
              }),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              '${_selectedDate.year}年${_selectedDate.month}月',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: () => setState(() {
                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
              }),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: ['日', '一', '二', '三', '四', '五', '六']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(day, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        ...weeks.map((week) => Row(
              children: week.map((day) {
                if (day == null) {
                  return const Expanded(child: SizedBox(height: 40));
                }
                final isToday = day.day == DateTime.now().day &&
                    day.month == DateTime.now().month &&
                    day.year == DateTime.now().year;
                final isSelected = day.day == _selectedDate.day &&
                    day.month == _selectedDate.month &&
                    day.year == _selectedDate.year;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primary : 
                               isToday ? theme.colorScheme.primaryContainer : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : 
                                   isToday ? theme.colorScheme.onPrimaryContainer : null,
                            fontWeight: isToday ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习计划'),
        centerTitle: false,
      ),
      body: DefaultTabController(
        length: 2,
        initialIndex: _currentPage,
        child: Column(
          children: [
            TabBar(
              onTap: (index) => setState(() => _currentPage = index),
              tabs: const [
                Tab(text: '我的计划'),
                Tab(text: '学习日历'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPlansView(theme),
                  _buildCalendarView(theme),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentPage == 0
          ? FloatingActionButton(
              onPressed: _createPlan,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _buildPlansView(ThemeData theme) {
    if (_plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('暂无学习计划', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('点击右下角按钮创建新计划'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: _plans.map(_buildPlanCard).toList(),
    );
  }

  Widget _buildCalendarView(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCalendar(),
          ),
        ),
        const SizedBox(height: 20),
        const Text('今日学习建议'),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.book_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('完成今日章节练习', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('建议学习时间：30分钟', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PracticePage(
                              config: PracticeConfig(subject: QuestionSubject.law, questionLimit: 10),
                              onCompleted: (_) async => Navigator.pop(context),
                            ),
                          ),
                        );
                      },
                      child: const Text('开始'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CreatePlanDialog extends StatefulWidget {
  const _CreatePlanDialog();

  @override
  State<_CreatePlanDialog> createState() => _CreatePlanDialogState();
}

class _CreatePlanDialogState extends State<_CreatePlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _questionsController = TextEditingController(text: '20');
  final _minutesController = TextEditingController(text: '30');
  PlanType _planType = PlanType.daily;
  QuestionSubject _subject = QuestionSubject.law;
  DateTime _startDate = DateTime.now();
  int _days = 7;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _questionsController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final plan = StudyPlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        type: _planType,
        subject: _subject,
        targetQuestions: int.parse(_questionsController.text),
        targetMinutes: int.parse(_minutesController.text),
        startDate: _startDate,
        endDate: _startDate.add(Duration(days: _days)),
        description: _descriptionController.text,
        totalDays: _days,
      );
      Navigator.pop(context, plan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建学习计划'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '计划名称'),
                  validator: (value) => value?.isEmpty ?? true ? '请输入计划名称' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PlanType>(
                  value: _planType,
                  decoration: const InputDecoration(labelText: '计划类型'),
                  items: PlanType.values
                      .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                      .toList(),
                  onChanged: (value) => setState(() => _planType = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<QuestionSubject>(
                  value: _subject,
                  decoration: const InputDecoration(labelText: '科目'),
                  items: QuestionSubject.values
                      .map((subject) => DropdownMenuItem(value: subject, child: Text(subject.label)))
                      .toList(),
                  onChanged: (value) => setState(() => _subject = value!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _questionsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '每日目标题数'),
                        validator: (value) => 
                            (value?.isEmpty ?? true) || int.parse(value!) <= 0 
                                ? '请输入有效数字' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _minutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '每日目标时长(分钟)'),
                        validator: (value) => 
                            (value?.isEmpty ?? true) || int.parse(value!) <= 0 
                                ? '请输入有效数字' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: '描述（可选）'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text('持续天数：$_days 天'),
                    ),
                    Slider(
                      value: _days.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (value) => setState(() => _days = value.toInt()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _submit, child: const Text('创建')),
      ],
    );
  }
}