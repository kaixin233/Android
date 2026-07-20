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

  Future<void> addHistory(HistoryItem item) async {
    await StorageService.addHistory(item);
    await _loadHistory();
    await _loadStats();
    notifyListeners();
  }

  Future<void> toggleFavorite(String uniqueKey) async {
    await StorageService.toggleFavorite(uniqueKey);
    await _loadFavorites();
    notifyListeners();
  }

  Future<void> addWrongQuestion(String uniqueKey) async {
    await StorageService.addWrongQuestion(uniqueKey);
    await _loadWrongQuestions();
    notifyListeners();
  }

  Future<void> removeWrongQuestion(String uniqueKey) async {
    await StorageService.removeWrongQuestion(uniqueKey);
    await _loadWrongQuestions();
    notifyListeners();
  }

  Future<void> saveNote(Note note) async {
    await StorageService.saveNote(note);
    await _loadNotes();
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await StorageService.deleteNote(id);
    await _loadNotes();
    notifyListeners();
  }

  Future<void> saveStudyPlan(StudyPlan plan) async {
    await StorageService.saveStudyPlan(plan);
    await _loadStudyPlans();
    notifyListeners();
  }

  Future<void> deleteStudyPlan(String id) async {
    await StorageService.deleteStudyPlan(id);
    await _loadStudyPlans();
    notifyListeners();
  }

  Future<void> markChapterCompleted(QuestionSubject subject, String chapterNumber) async {
    await StorageService.markChapterCompleted(subject, chapterNumber);
    await _loadStats();
    notifyListeners();
  }

  Future<void> saveThemeMode(String mode) async {
    await StorageService.saveThemeMode(mode);
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> refresh() async {
    await initialize();
  }

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