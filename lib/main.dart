import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '一级建造师学习',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
        useMaterial3: true,
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 1,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<_HistoryItem> _history = <_HistoryItem>[];
  int _completedChapters = 3;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getStringList('history') ?? <String>[];
    final history = rawHistory
        .map((item) => _HistoryItem.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
    setState(() {
      _history = history;
      _completedChapters = prefs.getInt('completedChapters') ?? 3;
    });
  }

  Future<void> _persistHistory(List<_HistoryItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      history.map((item) => jsonEncode(item.toJson())).toList(),
    );
    setState(() {
      _history = history;
    });
  }

  Future<void> _persistProgress(int completedChapters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('completedChapters', completedChapters);
    setState(() {
      _completedChapters = completedChapters;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _LearnPage(
        completedChapters: _completedChapters,
        onStartPractice: () => setState(() => _selectedIndex = 1),
        onHistoryChanged: _persistHistory,
        onProgressChanged: _persistProgress,
      ),
      _QuestionBankPage(
        history: _history,
        onHistoryChanged: _persistHistory,
      ),
      _ProfilePage(history: _history, completedChapters: _completedChapters),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school_rounded), label: '学习'),
          NavigationDestination(icon: Icon(Icons.quiz_rounded), label: '题库'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: '我的'),
        ],
      ),
    );
  }
}

class _LearnPage extends StatefulWidget {
  const _LearnPage({
    super.key,
    required this.completedChapters,
    required this.onStartPractice,
    required this.onHistoryChanged,
    required this.onProgressChanged,
  });

  final int completedChapters;
  final VoidCallback onStartPractice;
  final Future<void> Function(List<_HistoryItem> history) onHistoryChanged;
  final Future<void> Function(int completedChapters) onProgressChanged;

  @override
  State<_LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<_LearnPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final lessons = <_LessonData>[
      _LessonData('基础概念', '第 1 章', '12 题', Icons.school_rounded, Colors.green.shade600),
      _LessonData('工程法规', '第 2 章', '8 题', Icons.gavel_rounded, Colors.blue.shade600),
      _LessonData('施工管理', '第 3 章', '10 题', Icons.build_rounded, Colors.orange.shade700),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5FFF7),
      appBar: AppBar(
        title: const Text('一级建造师'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('暂无新通知，继续保持学习节奏吧。')),
              );
            },
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
                Text(
                  '今日练习',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '继续你的学习之旅，完成 3 道题拿到今日奖励。',
                  style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onPrimary),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          widget.onStartPractice();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PracticePage(
                                onHistoryChanged: widget.onHistoryChanged,
                                onProgressChanged: widget.onProgressChanged,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('开始练习'),
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
                      child: const Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: Colors.white),
                          SizedBox(width: 6),
                          Text('3 天', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(title: '已学章节', value: '${widget.completedChapters}/12', icon: Icons.menu_book_rounded),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _StatCard(title: '正确率', value: '82%', icon: Icons.trending_up_rounded),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('课程路线', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: '基础题型'),
              _Chip(label: '法规考点'),
              _Chip(label: '实务案例'),
              _Chip(label: '模拟冲刺'),
            ],
          ),
          const SizedBox(height: 20),
          Text('推荐模块', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...lessons.map((lesson) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      widget.onStartPractice();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PracticePage(
                            onHistoryChanged: widget.onHistoryChanged,
                            onProgressChanged: widget.onProgressChanged,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: lesson.color.withOpacity(0.12),
                            child: Icon(lesson.icon, color: lesson.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(lesson.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(lesson.subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(lesson.count, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              FilledButton.tonal(
                                onPressed: () {
                                  widget.onStartPractice();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PracticePage(
                                        onHistoryChanged: widget.onHistoryChanged,
                                        onProgressChanged: widget.onProgressChanged,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('继续'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _QuestionBankPage extends StatelessWidget {
  const _QuestionBankPage({super.key, required this.history, required this.onHistoryChanged});

  final List<_HistoryItem> history;
  final Future<void> Function(List<_HistoryItem> history) onHistoryChanged;

  @override
  Widget build(BuildContext context) {
    final questions = <_QuestionBankItem>[
      _QuestionBankItem('1. 施工阶段质量控制的重点是什么？', '可练习 · 已收藏'),
      _QuestionBankItem('2. 施工合同中的索赔条件有哪些？', '可练习 · 已收藏'),
      _QuestionBankItem('3. 施工组织设计的核心要素是什么？', '可练习 · 已收藏'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('题库')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = questions[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.quiz_rounded),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () async {
                final nextHistory = List<_HistoryItem>.from(history)
                  ..add(_HistoryItem(title: item.title, answeredAt: DateTime.now().toIso8601String(), correctCount: 0));
                await onHistoryChanged(nextHistory);
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PracticePage(
                        onHistoryChanged: onHistoryChanged,
                        onProgressChanged: (progress) async {},
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({super.key, required this.history, required this.completedChapters});

  final List<_HistoryItem> history;
  final int completedChapters;

  @override
  Widget build(BuildContext context) {
    final progress = (completedChapters / 12).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('学习进度', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('已完成 $completedChapters/12 个章节', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.calendar_today_rounded), title: Text('连续学习 ${history.isEmpty ? 0 : history.length} 天')),
          ListTile(leading: const Icon(Icons.score_rounded), title: Text('累计答题 ${history.length * 3} 题')),
          ListTile(leading: const Icon(Icons.emoji_events_rounded), title: Text('今日奖励 ${history.isEmpty ? 0 : 2}/3')),
        ],
      ),
    );
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({super.key, required this.onHistoryChanged, required this.onProgressChanged});

  final Future<void> Function(List<_HistoryItem> history) onHistoryChanged;
  final Future<void> Function(int completedChapters) onProgressChanged;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final List<_Question> _questions = const [
    _Question(
      title: '题目 1',
      prompt: '以下哪项是施工质量控制的重点？',
      options: ['材料进场验收', '工序交接检查', '设备调试', '隐蔽工程记录'],
      answerIndex: 1,
    ),
    _Question(
      title: '题目 2',
      prompt: '合同索赔的基本依据通常是什么？',
      options: ['施工许可证', '合同条款与事实依据', '劳动合同', '组织架构图'],
      answerIndex: 1,
    ),
    _Question(
      title: '题目 3',
      prompt: '建设工程项目管理的核心目标是什么？',
      options: ['扩大面积', '提高效益和控制风险', '增加人员', '降低工资'],
      answerIndex: 1,
    ),
  ];

  int _currentIndex = 0;
  int? _selectedIndex;
  int _correctCount = 0;

  Future<void> _persistResult() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList('history') ?? <String>[];
    final history = savedHistory
        .map((entry) => _HistoryItem.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList();
    history.add(
      _HistoryItem(
        title: '练习记录',
        answeredAt: DateTime.now().toIso8601String(),
        correctCount: _correctCount,
      ),
    );
    await widget.onHistoryChanged(history);
    final previousChapters = prefs.getInt('completedChapters') ?? 3;
    final nextChapters = (previousChapters + 1).clamp(0, 12);
    await widget.onProgressChanged(nextChapters);
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentIndex];
    final isLast = _currentIndex == _questions.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text(question.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.prompt, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              ...List.generate(question.options.length, (index) {
                final option = question.options[index];
                final isSelected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                        if (index == question.answerIndex) {
                          _correctCount += 1;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(16),
                        color: isSelected ? Colors.green.shade50 : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(option)),
                          if (_selectedIndex != null && index == question.answerIndex)
                            const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentIndex > 0
                          ? () {
                              setState(() {
                                _currentIndex -= 1;
                                _selectedIndex = null;
                              });
                            }
                          : null,
                      child: const Text('上一题'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selectedIndex == null
                          ? null
                          : () {
                              if (isLast) {
                                showDialog<void>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('练习完成'),
                                    content: Text('你答对了 $_correctCount/${_questions.length} 题，继续保持节奏吧。'),
                                    actions: [
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await _persistResult();
                                          if (mounted) {
                                            setState(() {
                                              _currentIndex = 0;
                                              _selectedIndex = null;
                                              _correctCount = 0;
                                            });
                                          }
                                        },
                                        child: const Text('再练一次'),
                                      ),
                                      FilledButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await _persistResult();
                                          if (mounted) {
                                            Navigator.of(context).pop();
                                          }
                                        },
                                        child: const Text('返回首页'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                setState(() {
                                  _currentIndex += 1;
                                  _selectedIndex = null;
                                });
                              }
                            },
                      child: Text(isLast ? '完成' : '下一题'),
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
              Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
    );
  }
}

class _LessonData {
  const _LessonData(this.title, this.subtitle, this.count, this.icon, this.color);

  final String title;
  final String subtitle;
  final String count;
  final IconData icon;
  final Color color;
}

class _Question {
  const _Question({required this.title, required this.prompt, required this.options, required this.answerIndex});

  final String title;
  final String prompt;
  final List<String> options;
  final int answerIndex;
}

class _QuestionBankItem {
  const _QuestionBankItem(this.title, this.subtitle);

  final String title;
  final String subtitle;
}

class _HistoryItem {
  const _HistoryItem({required this.title, required this.answeredAt, required this.correctCount});

  final String title;
  final String answeredAt;
  final int correctCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'answeredAt': answeredAt,
      'correctCount': correctCount,
    };
  }

  factory _HistoryItem.fromJson(Map<String, dynamic> json) {
    return _HistoryItem(
      title: json['title'] as String? ?? '练习记录',
      answeredAt: json['answeredAt'] as String? ?? DateTime.now().toIso8601String(),
      correctCount: json['correctCount'] as int? ?? 0,
    );
  }
}
