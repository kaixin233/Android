import 'package:flutter/foundation.dart';

import '../models/history_item.dart';
import '../models/note.dart';
import '../models/question.dart';
import '../models/study_plan.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  List<Question> _allQuestions = [];
  List<HistoryItem> _history = [];
  List<Note> _notes = [];
  List<StudyPlan> _studyPlans = [];
  Set<String> _favorites = {};
  Set<String> _wrongQuestions = {};
  Map<String, int> _wrongCounts = {};
  int _completedChapters = 0;
  int _streakDays = 0;
  String _themeMode = 'system';
  bool _vibrationEnabled = true;
  bool _isLoading = false;

  List<Question> get allQuestions => _allQuestions;
  List<HistoryItem> get history => _history;
  List<Note> get notes => _notes;
  List<StudyPlan> get studyPlans => _studyPlans;
  Set<String> get favorites => _favorites;
  Set<String> get wrongQuestions => _wrongQuestions;
  Map<String, int> get wrongCounts => _wrongCounts;
  int get completedChapters => _completedChapters;
  int get streakDays => _streakDays;
  String get themeMode => _themeMode;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    try {
      await Future.wait([
        _loadQuestions(),
        _loadHistory(),
        _loadNotes(),
        _loadStudyPlans(),
        _loadFavorites(),
        _loadWrongQuestions(),
        _loadStats(),
        _loadThemeMode(),
        _loadVibrationEnabled(),
      ]);
    } catch (e) {
      debugPrint('Error initializing app: $e');
    }
  }

  Future<void> _loadQuestions() async {
    _allQuestions = await QuestionService.getAllQuestions();
  }

  Future<void> _loadHistory() async {
    _history = await StorageService.loadHistory();
  }

  Future<void> _loadNotes() async {
    _notes = await StorageService.loadNotes();
  }

  Future<void> _loadStudyPlans() async {
    _studyPlans = await StorageService.loadStudyPlans();
  }

  Future<void> _loadFavorites() async {
    _favorites = await StorageService.loadFavorites();
  }

  Future<void> _loadWrongQuestions() async {
    _wrongQuestions = (await StorageService.loadWrongQuestionKeys()).toSet();
    _wrongCounts = await StorageService.loadWrongCounts();
  }

  Future<void> _loadStats() async {
    _completedChapters = await StorageService.loadCompletedChapters();
    _streakDays = await StorageService.loadStreakDays();
  }

  Future<void> _loadThemeMode() async {
    _themeMode = await StorageService.loadThemeMode();
  }

  Future<void> _loadVibrationEnabled() async {
    _vibrationEnabled = await StorageService.loadVibrationEnabled();
  }

  // ========== 历史记录 ==========

  Future<void> addHistory(HistoryItem item) async {
    _history.add(item);
    notifyListeners();
    await StorageService.addHistory(item);
    _streakDays = await StorageService.loadStreakDays();
    _completedChapters = await StorageService.loadCompletedChapters();
    notifyListeners();
  }

  // ========== 收藏 ==========

  Future<void> toggleFavorite(String uniqueKey) async {
    if (_favorites.contains(uniqueKey)) {
      _favorites.remove(uniqueKey);
    } else {
      _favorites.add(uniqueKey);
    }
    notifyListeners();
    await StorageService.saveFavorites(_favorites);
  }

  // ========== 错题 ==========

  Future<void> addWrongQuestion(String uniqueKey) async {
    if (!_wrongQuestions.contains(uniqueKey)) {
      _wrongQuestions.add(uniqueKey);
      _wrongCounts[uniqueKey] = (_wrongCounts[uniqueKey] ?? 0) + 1;
      notifyListeners();
      await StorageService.addWrongQuestion(uniqueKey);
    }
  }

  Future<void> removeWrongQuestion(String uniqueKey) async {
    _wrongQuestions.remove(uniqueKey);
    notifyListeners();
    await StorageService.removeWrongQuestion(uniqueKey);
  }

  // ========== 笔记 ==========

  Future<void> saveNote(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      _notes[index] = note;
    } else {
      _notes.add(note);
    }
    notifyListeners();
    await StorageService.saveNote(note);
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    notifyListeners();
    await StorageService.deleteNote(id);
  }

  // ========== 学习计划 ==========

  Future<void> saveStudyPlan(StudyPlan plan) async {
    final index = _studyPlans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      _studyPlans[index] = plan;
    } else {
      _studyPlans.add(plan);
    }
    notifyListeners();
    await StorageService.saveStudyPlan(plan);
  }

  Future<void> deleteStudyPlan(String id) async {
    _studyPlans.removeWhere((p) => p.id == id);
    notifyListeners();
    await StorageService.deleteStudyPlan(id);
  }

  Future<void> markChapterCompleted(QuestionSubject subject, String chapterNumber) async {
    await StorageService.markChapterCompleted(subject, chapterNumber);
    _completedChapters = await StorageService.loadCompletedChapters();
    notifyListeners();
  }

  // ========== 主题 ==========

  Future<void> saveThemeMode(String mode) async {
    _themeMode = mode;
    notifyListeners();
    await StorageService.saveThemeMode(mode);
  }

  Future<void> saveVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    notifyListeners();
    await StorageService.saveVibrationEnabled(enabled);
  }

  Future<void> refresh() async {
    await initialize();
  }

  // ========== 统计 ==========

  int get totalQuestions => _allQuestions.length;

  int get totalAnswered => _history.fold(0, (sum, item) => sum + item.totalCount);

  int get totalCorrect => _history.fold(0, (sum, item) => sum + item.correctCount);

  double get overallAccuracy => totalAnswered == 0 ? 0 : totalCorrect / totalAnswered;

  int get totalNotes => _notes.length;

  int get totalStudyPlans => _studyPlans.length;

  Map<QuestionSubject, int> get subjectStats {
    final stats = <QuestionSubject, int>{};
    for (final q in _allQuestions) {
      stats[q.subject] = (stats[q.subject] ?? 0) + 1;
    }
    return stats;
  }

  Map<QuestionType, int> get typeStats {
    final stats = <QuestionType, int>{};
    for (final q in _allQuestions) {
      stats[q.type] = (stats[q.type] ?? 0) + 1;
    }
    return stats;
  }
}