import 'package:flutter/foundation.dart';

import '../data/textbooks.dart';
import '../models/history_item.dart';
import '../models/note.dart';
import '../models/question.dart';
import '../models/study_plan.dart';
import '../services/question_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/backup_service.dart';

class AppProvider extends ChangeNotifier {
  List<Question> _allQuestions = [];
  // 科目/题型题量统计缓存：仅在加载或重载题目时计算一次，
  // 避免每次 notifyListeners 触发 _TextbookCard 等消费者重建时重复遍历约 1.2 万道题。
  Map<QuestionSubject, int>? _cachedSubjectStats;
  Map<QuestionType, int>? _cachedTypeStats;
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
  double _fontScale = 1.0;
  bool _autoBackup = true;
  // 练习与考试设置
  bool _practiceShuffleQuestions = false;
  bool _practiceShuffleOptions = false;
  bool _practiceAutoNext = false;
  int _examQuestionCount = 20;
  int _examDurationMinutes = 30;
  // 学习目标
  int _dailyGoalQuestions = 50;

  // 语音设置
  bool _ttsAutoPlayExplanation = true;
  bool _ttsAutoReadQuestion = false;
  bool _ttsSkipExplanationOnCorrect = false;
  double _ttsSpeechRate = 0.5;
  double _ttsPitch = 1.0;
  double _ttsVolume = 1.0;
  bool _ttsEnabled = true;

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
  double get fontScale => _fontScale;
  bool get autoBackup => _autoBackup;
  bool get practiceShuffleQuestions => _practiceShuffleQuestions;
  bool get practiceShuffleOptions => _practiceShuffleOptions;
  bool get practiceAutoNext => _practiceAutoNext;
  int get examQuestionCount => _examQuestionCount;
  int get examDurationMinutes => _examDurationMinutes;
  int get dailyGoalQuestions => _dailyGoalQuestions;

  bool get ttsEnabled => _ttsEnabled;
  bool get ttsAutoPlayExplanation => _ttsEnabled && _ttsAutoPlayExplanation;
  bool get ttsAutoReadQuestion => _ttsEnabled && _ttsAutoReadQuestion;
  bool get ttsSkipExplanationOnCorrect => _ttsEnabled && _ttsSkipExplanationOnCorrect;
  double get ttsSpeechRate => _ttsSpeechRate;
  double get ttsPitch => _ttsPitch;
  double get ttsVolume => _ttsVolume;

  Future<void> initialize() async {
    try {
      // 每个任务独立 catch，避免一个失败影响其他
      await Future.wait([
        _loadHistory().catchError((e) => debugPrint('loadHistory error: $e')),
        _loadNotes().catchError((e) => debugPrint('loadNotes error: $e')),
        _loadStudyPlans().catchError((e) => debugPrint('loadStudyPlans error: $e')),
        _loadFavorites().catchError((e) => debugPrint('loadFavorites error: $e')),
        _loadWrongQuestions().catchError((e) => debugPrint('loadWrongQuestions error: $e')),
        _loadStats().catchError((e) => debugPrint('loadStats error: $e')),
        _loadThemeMode().catchError((e) => debugPrint('loadThemeMode error: $e')),
        _loadFontScale().catchError((e) => debugPrint('loadFontScale error: $e')),
        _loadAutoBackup().catchError((e) => debugPrint('loadAutoBackup error: $e')),
        _loadVibrationEnabled().catchError((e) => debugPrint('loadVibrationEnabled error: $e')),
        _loadPracticeSettings().catchError((e) => debugPrint('loadPracticeSettings error: $e')),
        _loadAllQuestions().catchError((e) => debugPrint('loadAllQuestions error: $e')),
        _loadTtsSettings().catchError((e) => debugPrint('loadTtsSettings error: $e')),
      ]);
      // 启动后按需触发本地自动备份（失败不影响使用）
      BackupService.runIfNeeded().catchError((e) => debugPrint('autoBackup error: $e'));
    } catch (e) {
      debugPrint('Error initializing app: $e');
    }
  }

  Future<void> _loadAllQuestions() async {
    _allQuestions = await QuestionService.getAllQuestions();
    _recomputeStats();
  }

  /// 重新加载题目列表（导入/删除题目后调用）
  Future<void> reloadQuestions() async {
    QuestionService.clearCache();
    _allQuestions = await QuestionService.getAllQuestions();
    _recomputeStats();
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

  Future<void> _loadFontScale() async {
    _fontScale = await StorageService.loadFontScale();
  }

  Future<void> _loadAutoBackup() async {
    _autoBackup = await StorageService.loadAutoBackupEnabled();
  }

  Future<void> _loadVibrationEnabled() async {
    _vibrationEnabled = await StorageService.loadVibrationEnabled();
  }

  Future<void> _loadPracticeSettings() async {
    _practiceShuffleQuestions = await StorageService.loadPracticeShuffleQuestions();
    _practiceShuffleOptions = await StorageService.loadPracticeShuffleOptions();
    _practiceAutoNext = await StorageService.loadPracticeAutoNext();
    _examQuestionCount = await StorageService.loadExamQuestionCount();
    _examDurationMinutes = await StorageService.loadExamDurationMinutes();
    _dailyGoalQuestions = await StorageService.loadDailyGoalQuestions();
  }

  Future<void> _loadTtsSettings() async {
    _ttsAutoPlayExplanation = await StorageService.loadTtsAutoPlayExplanation();
    _ttsAutoReadQuestion = await StorageService.loadTtsAutoReadQuestion();
    _ttsSkipExplanationOnCorrect = await StorageService.loadTtsSkipExplanationOnCorrect();
    _ttsSpeechRate = await StorageService.loadTtsSpeechRate();
    _ttsPitch = await StorageService.loadTtsPitch();
    _ttsVolume = await StorageService.loadTtsVolume();
    _ttsEnabled = await StorageService.loadTtsEnabled();
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
    // 每次答错都累加计数（与 StorageService 一致），使"错题次数"统计真实可用；
    // 只在首次加入错题集时将其加入集合，但计数始终 +1。
    _wrongQuestions.add(uniqueKey);
    _wrongCounts[uniqueKey] = (_wrongCounts[uniqueKey] ?? 0) + 1;
    notifyListeners();
    await StorageService.addWrongQuestion(uniqueKey);
  }

  Future<void> removeWrongQuestion(String uniqueKey) async {
    _wrongQuestions.remove(uniqueKey);
    _wrongCounts.remove(uniqueKey);
    notifyListeners();
    await StorageService.removeWrongQuestion(uniqueKey);
  }

  /// 清空错题本（同步内存与存储），供错题本页面"清空"操作调用。
  Future<void> clearWrongQuestions() async {
    _wrongQuestions.clear();
    _wrongCounts.clear();
    notifyListeners();
    await StorageService.saveWrongQuestionKeys([]);
    await StorageService.saveWrongCounts({});
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

  Future<void> saveFontScale(double scale) async {
    _fontScale = scale;
    notifyListeners();
    await StorageService.saveFontScale(scale);
  }

  Future<void> saveAutoBackup(bool enabled) async {
    _autoBackup = enabled;
    notifyListeners();
    await StorageService.saveAutoBackupEnabled(enabled);
  }

  Future<void> saveVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    notifyListeners();
    await StorageService.saveVibrationEnabled(enabled);
  }

  // ========== 练习与考试设置 ==========

  Future<void> savePracticeShuffleQuestions(bool enabled) async {
    _practiceShuffleQuestions = enabled;
    notifyListeners();
    await StorageService.savePracticeShuffleQuestions(enabled);
  }

  Future<void> savePracticeShuffleOptions(bool enabled) async {
    _practiceShuffleOptions = enabled;
    notifyListeners();
    await StorageService.savePracticeShuffleOptions(enabled);
  }

  Future<void> savePracticeAutoNext(bool enabled) async {
    _practiceAutoNext = enabled;
    notifyListeners();
    await StorageService.savePracticeAutoNext(enabled);
  }

  Future<void> saveExamQuestionCount(int count) async {
    _examQuestionCount = count;
    notifyListeners();
    await StorageService.saveExamQuestionCount(count);
  }

  Future<void> saveExamDurationMinutes(int minutes) async {
    _examDurationMinutes = minutes;
    notifyListeners();
    await StorageService.saveExamDurationMinutes(minutes);
  }

  Future<void> saveDailyGoalQuestions(int count) async {
    _dailyGoalQuestions = count;
    notifyListeners();
    await StorageService.saveDailyGoalQuestions(count);
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

  Future<void> saveTtsSkipExplanationOnCorrect(bool enabled) async {
    _ttsSkipExplanationOnCorrect = enabled;
    notifyListeners();
    await StorageService.saveTtsSkipExplanationOnCorrect(enabled);
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

  Future<void> saveTtsEnabled(bool enabled) async {
    _ttsEnabled = enabled;
    notifyListeners();
    await StorageService.saveTtsEnabled(enabled);
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

  /// 重新计算科目/题型题量统计（仅在题目集合变化时调用一次）。
  void _recomputeStats() {
    final subjectStats = <QuestionSubject, int>{};
    final typeStats = <QuestionType, int>{};
    for (final q in _allQuestions) {
      subjectStats[q.subject] = (subjectStats[q.subject] ?? 0) + 1;
      typeStats[q.type] = (typeStats[q.type] ?? 0) + 1;
    }
    _cachedSubjectStats = Map.unmodifiable(subjectStats);
    _cachedTypeStats = Map.unmodifiable(typeStats);
  }

  Map<QuestionSubject, int> get subjectStats => _cachedSubjectStats ?? const {};
  Map<QuestionType, int> get typeStats => _cachedTypeStats ?? const {};
}