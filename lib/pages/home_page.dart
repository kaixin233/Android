import 'package:flutter/material.dart';

import '../models/history_item.dart';
import '../services/storage_service.dart';
import 'learn_page.dart';
import 'question_bank_page.dart';
import 'textbook_page.dart';
import 'profile_page.dart';
import 'study_plan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.themeMode, required this.onThemeChanged});

  final String themeMode;
  final Future<void> Function(String mode) onThemeChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<HistoryItem> _history = <HistoryItem>[];
  int _completedChapters = 0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    _history = await StorageService.loadHistory();
    _completedChapters = await StorageService.loadCompletedChapters();
    _streakDays = await StorageService.loadStreakDays();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      LearnPage(
        completedChapters: _completedChapters,
        streakDays: _streakDays,
      ),
      const QuestionBankPage(),
      const TextbookPage(),
      const StudyPlanPage(),
      ProfilePage(
        history: _history,
        completedChapters: _completedChapters,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school_rounded), label: '学习'),
          NavigationDestination(icon: Icon(Icons.quiz_rounded), label: '题库'),
          NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: '教材'),
          NavigationDestination(icon: Icon(Icons.checklist_rounded), label: '计划'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: '我的'),
        ],
      ),
    );
  }
}
