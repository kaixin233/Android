import 'package:flutter/foundation.dart';

import '../data/textbooks.dart';
import '../models/history_item.dart';
import '../models/note.dart';
import '../models/question.dart';
import '../models/study_plan.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';

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

  // 语音设置
  bool _ttsAutoPlayExplanation = true;
  bool _ttsAutoReadQuestion = false;
  double _ttsSpeechRate = 0.5;
  double _ttsPitch = 1.0;
  double _ttsVolume = 1.0;

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

  bool get ttsAutoPlayExplanation => _ttsAutoPlayExplanation;
  bool get ttsAutoReadQuestion => _ttsAutoReadQuestion;
  double get ttsSpeechRate => _ttsSpeechRate;
  double get ttsPitch => _ttsPitch;
  double get ttsVolume => _ttsVolume;

  Future<void> initialize() async {
    try {
      // 每个任务独立 catch，避免一个失败影响其他
      final results = await Future.wait([
        _loadHistory().catchError((e) => debugPrint('loadHistory error: $e')),
        _loadNotes().catchError((e) => debugPrint('loadNotes error: $e')),
        _loadStudyPlans().catchError((e) => debugPrint('loadStudyPlans error: $e')),
        _loadFavorites().catchError((e) => debugPrint('loadFavorites error: $e')),
        _loadWrongQuestions().catchError((e) => debugPrint('loadWrongQuestions error: $e')),
        _loadStats().catchError((e) => debugPrint('loadStats error: $e')),
        _loadThemeMode().catchError((e) => debugPrint('loadThemeMode error: $e')),
        _loadVibrationEnabled().catchError((e) => debugPrint('loadVibrationEnabled error: $e')),
        _loadAllQuestions().catchError((e) => debugPrint('loadAllQuestions error: $e')),
        _loadTtsSettings().catchError((e) => debugPrint('loadTtsSettings error: $e')),
      ]);
    } catch (e) {
      debugPrint('Error initializing app: $e');
    }
  }

  Future<void> _loadAllQuestions() async {
    _allQuestions = await QuestionService.getAllQuestions();
  }

  /// 重新加载题目列表（导入/删除题目后调用）
  Future<void> reloadQuestions() async {
    QuestionService.clearCache();
    _allQuestions = await QuestionService.getAllQuestions();
    notifyListeners();
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

  Future<void> _loadTtsSettings() async {
    _ttsAutoPlayExplanation = await StorageService.loadTtsAutoPlayExplanation();
    _ttsAutoReadQuestion = await StorageService.loadTtsAutoReadQuestion();
    _ttsSpeechRate = await StorageService.loadTtsSpeechRate();
    _ttsPitch = await StorageService.loadTtsPitch();
    _ttsVolume = await StorageService.loadTtsVolume();
    // 将用户保存的语音参数应用到 TTS 引擎
    await TtsService.applySpeechParams(
      rate: _ttsSpeechRate,
      pitch: _ttsPitch,
      volume: _ttsVolume,
    );
  }

  // ========== 历史记录 ==========

  Future<void> addHistory(HistoryItem item) async {
    _history.add(item);
    await StorageService.addHistory(item);
    // 一次性更新关联状态，避免多次 notifyListeners
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

  // ========== 语音设置 ==========

  Future<void> saveTtsAutoPlayExplanation(bool enabled) async {
    _ttsAutoPlayExplanation = enabled;
    notifyListeners();
    await StorageService.saveTtsAutoPlayExplanation(enabled);
  }

  Future<void> saveTtsAutoReadQuestion(bool enabled) async {
    _ttsAutoReadQuestion = enabled;
    notifyListeners();
    await StorageService.saveTtsAutoReadQuestion(enabled);
  }

  Future<void> saveTtsSpeechRate(double rate) async {
    _ttsSpeechRate = rate;
    notifyListeners();
    await StorageService.saveTtsSpeechRate(rate);
    await TtsService.applySpeechParams(rate: rate);
  }

  Future<void> saveTtsPitch(double pitch) async {
    _ttsPitch = pitch;
    notifyListeners();
    await StorageService.saveTtsPitch(pitch);
    await TtsService.applySpeechParams(pitch: pitch);
  }

  Future<void> saveTtsVolume(double volume) async {
    _ttsVolume = volume;
    notifyListeners();
    await StorageService.saveTtsVolume(volume);
    await TtsService.applySpeechParams(volume: volume);
  }

  Future<void> refresh() async {
    QuestionService.clearCache();
    await initialize();
  }

  // ========== 统计 ==========

  int get totalChapters => Textbooks.all.fold(0, (sum, book) => sum + book.chapters.length);

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