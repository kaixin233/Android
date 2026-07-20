import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import '../models/history_item.dart';
import '../models/study_plan.dart';
import '../models/note.dart';
import '../models/knowledge_point.dart';

/// 持久化存储服务 - 封装 SharedPreferences 操作
class StorageService {
  static const String _importedQuestionsKey = 'importedQuestions';
  static const String _historyKey = 'history';
  static const String _completedChaptersKey = 'completedChapters';
  static const String _favoritesKey = 'favorites';
  static const String _wrongQuestionsKey = 'wrongQuestions';
  static const String _wrongCountKey = 'wrongCounts';
  static const String _themeModeKey = 'themeMode';
  static const String _streakDaysKey = 'streakDays';
  static const String _lastPracticeDateKey = 'lastPracticeDate';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ========== 题目相关 ==========

  static Future<List<Question>> loadImportedQuestions() async {
    final prefs = await _instance;
    final saved = prefs.getString(_importedQuestionsKey);
    if (saved == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(saved) as List<dynamic>;
      return jsonList
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveImportedQuestions(List<Question> questions) async {
    final prefs = await _instance;
    await prefs.setString(
      _importedQuestionsKey,
      jsonEncode(questions.map((q) => q.toJson()).toList()),
    );
  }

  static Future<List<Question>> importQuestions(List<Question> newQuestions) async {
    final existing = await loadImportedQuestions();
    final existingKeys = existing.map((q) => q.uniqueKey).toSet();
    final uniqueNew = newQuestions.where((q) => !existingKeys.contains(q.uniqueKey)).toList();
    final all = [...existing, ...uniqueNew];
    await saveImportedQuestions(all);
    return uniqueNew;
  }

  static Future<void> deleteImportedQuestion(String uniqueKey) async {
    final existing = await loadImportedQuestions();
    final filtered = existing.where((q) => q.uniqueKey != uniqueKey).toList();
    await saveImportedQuestions(filtered);
  }

  static Future<void> clearImportedQuestions() async {
    final prefs = await _instance;
    await prefs.remove(_importedQuestionsKey);
  }

  // ========== 学习历史 ==========

  static Future<List<HistoryItem>> loadHistory() async {
    final prefs = await _instance;
    final raw = prefs.getStringList(_historyKey) ?? <String>[];
    return raw
        .map((item) => HistoryItem.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveHistory(List<HistoryItem> history) async {
    final prefs = await _instance;
    await prefs.setStringList(
      _historyKey,
      history.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<void> addHistory(HistoryItem item) async {
    final history = await loadHistory();
    history.add(item);
    await saveHistory(history);
    await _updateStreak();
  }

  // ========== 已学章节 ==========

  static Future<int> loadCompletedChapters() async {
    final prefs = await _instance;
    return prefs.getInt(_completedChaptersKey) ?? 0;
  }

  static Future<void> saveCompletedChapters(int value) async {
    final prefs = await _instance;
    await prefs.setInt(_completedChaptersKey, value);
  }

  // ========== 收藏 ==========

  static Future<Set<String>> loadFavorites() async {
    final prefs = await _instance;
    return (prefs.getStringList(_favoritesKey) ?? <String>[]).toSet();
  }

  static Future<void> saveFavorites(Set<String> favorites) async {
    final prefs = await _instance;
    await prefs.setStringList(_favoritesKey, favorites.toList());
  }

  static Future<void> toggleFavorite(String uniqueKey) async {
    final favorites = await loadFavorites();
    if (favorites.contains(uniqueKey)) {
      favorites.remove(uniqueKey);
    } else {
      favorites.add(uniqueKey);
    }
    await saveFavorites(favorites);
  }

  // ========== 错题本 ==========

  static Future<List<String>> loadWrongQuestionKeys() async {
    final prefs = await _instance;
    return prefs.getStringList(_wrongQuestionsKey) ?? <String>[];
  }

  static Future<void> saveWrongQuestionKeys(List<String> keys) async {
    final prefs = await _instance;
    await prefs.setStringList(_wrongQuestionsKey, keys);
  }

  static Future<void> addWrongQuestion(String uniqueKey) async {
    final keys = await loadWrongQuestionKeys();
    if (!keys.contains(uniqueKey)) {
      keys.add(uniqueKey);
      await saveWrongQuestionKeys(keys);
    }
    // 增加错误次数
    final counts = await loadWrongCounts();
    counts[uniqueKey] = (counts[uniqueKey] ?? 0) + 1;
    await saveWrongCounts(counts);
  }

  static Future<void> removeWrongQuestion(String uniqueKey) async {
    final keys = await loadWrongQuestionKeys();
    keys.remove(uniqueKey);
    await saveWrongQuestionKeys(keys);
  }

  static Future<Map<String, int>> loadWrongCounts() async {
    final prefs = await _instance;
    final raw = prefs.getString(_wrongCountKey);
    if (raw == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (e) {
      return {};
    }
  }

  static Future<void> saveWrongCounts(Map<String, int> counts) async {
    final prefs = await _instance;
    await prefs.setString(_wrongCountKey, jsonEncode(counts));
  }

  // ========== 主题模式 ==========

  static Future<String> loadThemeMode() async {
    final prefs = await _instance;
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  static Future<void> saveThemeMode(String mode) async {
    final prefs = await _instance;
    await prefs.setString(_themeModeKey, mode);
  }

  // ========== 连续学习天数 ==========

  static Future<int> loadStreakDays() async {
    final prefs = await _instance;
    return prefs.getInt(_streakDaysKey) ?? 0;
  }

  static Future<void> _updateStreak() async {
    final prefs = await _instance;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastDate = prefs.getString(_lastPracticeDateKey);
    final currentStreak = prefs.getInt(_streakDaysKey) ?? 0;

    if (lastDate == null) {
      await prefs.setInt(_streakDaysKey, 1);
      await prefs.setString(_lastPracticeDateKey, todayStr);
    } else if (lastDate != todayStr) {
      final last = DateTime.parse(lastDate);
      final diff = today.difference(last).inDays;
      if (diff == 1) {
        await prefs.setInt(_streakDaysKey, currentStreak + 1);
      } else if (diff > 1) {
        await prefs.setInt(_streakDaysKey, 1);
      }
      await prefs.setString(_lastPracticeDateKey, todayStr);
    }
  }

  // ========== 章节完成状态 ==========

  static const String _chapterProgressKey = 'chapterProgress';
  static const String _readProgressKey = 'readProgress';

  static Future<void> markChapterCompleted(QuestionSubject subject, String chapterNumber) async {
    final prefs = await _instance;
    final progress = await _loadChapterProgress();
    final key = '${subject.name}_$chapterNumber';
    progress[key] = true;
    await _saveChapterProgress(progress);
    await _updateCompletedChapterCount();
  }

  static Future<bool> isChapterCompleted(QuestionSubject subject, String chapterNumber) async {
    final progress = await _loadChapterProgress();
    return progress['${subject.name}_$chapterNumber'] ?? false;
  }

  static Future<Map<String, bool>> _loadChapterProgress() async {
    final prefs = await _instance;
    final raw = prefs.getString(_chapterProgressKey);
    if (raw == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as bool));
    } catch (e) {
      return {};
    }
  }

  static Future<void> _saveChapterProgress(Map<String, bool> progress) async {
    final prefs = await _instance;
    await prefs.setString(_chapterProgressKey, jsonEncode(progress));
  }

  static Future<void> _updateCompletedChapterCount() async {
    final progress = await _loadChapterProgress();
    await saveCompletedChapters(progress.values.where((v) => v).length);
  }

  // ========== 阅读进度 ==========

  static Future<void> saveReadProgress(QuestionSubject subject, int page) async {
    final prefs = await _instance;
    final progress = await _loadReadProgress();
    progress[subject.name] = page;
    await _saveReadProgress(progress);
  }

  static Future<int> loadReadProgress(QuestionSubject subject) async {
    final progress = await _loadReadProgress();
    return progress[subject.name] ?? 1;
  }

  static Future<Map<String, int>> _loadReadProgress() async {
    final prefs = await _instance;
    final raw = prefs.getString(_readProgressKey);
    if (raw == null) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (e) {
      return {};
    }
  }

  static Future<void> _saveReadProgress(Map<String, int> progress) async {
    final prefs = await _instance;
    await prefs.setString(_readProgressKey, jsonEncode(progress));
  }

  // ========== 数据导出 ==========

  static Future<String> exportAllData() async {
    final imported = await loadImportedQuestions();
    final history = await loadHistory();
    final favorites = await loadFavorites();
    final wrongKeys = await loadWrongQuestionKeys();
    final completedChapters = await loadCompletedChapters();
    final streakDays = await loadStreakDays();
    final chapterProgress = await _loadChapterProgress();
    final readProgress = await _loadReadProgress();

    final data = {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'importedQuestions': imported.map((q) => q.toJson()).toList(),
      'history': history.map((h) => h.toJson()).toList(),
      'favorites': favorites.toList(),
      'wrongQuestionKeys': wrongKeys,
      'completedChapters': completedChapters,
      'streakDays': streakDays,
      'chapterProgress': chapterProgress,
      'readProgress': readProgress,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ========== 数据导入 ==========

  static Future<void> importAllData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final prefs = await _instance;

      if (data.containsKey('importedQuestions')) {
        final questions = (data['importedQuestions'] as List<dynamic>)
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList();
        await saveImportedQuestions(questions);
      }

      if (data.containsKey('history')) {
        final history = (data['history'] as List<dynamic>)
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        await saveHistory(history);
      }

      if (data.containsKey('favorites')) {
        final favorites = (data['favorites'] as List<dynamic>).cast<String>().toSet();
        await saveFavorites(favorites);
      }

      if (data.containsKey('wrongQuestionKeys')) {
        final wrongKeys = (data['wrongQuestionKeys'] as List<dynamic>).cast<String>();
        await saveWrongQuestionKeys(wrongKeys);
      }

      if (data.containsKey('completedChapters')) {
        await saveCompletedChapters(data['completedChapters'] as int);
      }

      if (data.containsKey('streakDays')) {
        await prefs.setInt(_streakDaysKey, data['streakDays'] as int);
      }

      if (data.containsKey('chapterProgress')) {
        await prefs.setString(_chapterProgressKey, jsonEncode(data['chapterProgress']));
      }

      if (data.containsKey('readProgress')) {
        await prefs.setString(_readProgressKey, jsonEncode(data['readProgress']));
      }
    } catch (e) {
      rethrow;
    }
  }

  // ========== 学习计划 ==========

  static const String _studyPlansKey = 'studyPlans';
  static const String _planProgressKey = 'planProgress';

  static Future<List<StudyPlan>> loadStudyPlans() async {
    final prefs = await _instance;
    final raw = prefs.getStringList(_studyPlansKey) ?? <String>[];
    final plans = raw
        .map((item) => StudyPlan.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
    await _updatePlanProgress(plans);
    return plans;
  }

  static Future<void> saveStudyPlan(StudyPlan plan) async {
    final plans = await loadStudyPlans();
    final index = plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.add(plan);
    }
    final prefs = await _instance;
    await prefs.setStringList(
      _studyPlansKey,
      plans.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  static Future<void> deleteStudyPlan(String id) async {
    final plans = await loadStudyPlans();
    plans.removeWhere((p) => p.id == id);
    final prefs = await _instance;
    await prefs.setStringList(
      _studyPlansKey,
      plans.map((p) => jsonEncode(p.toJson())).toList(),
    );
    await prefs.remove('${_planProgressKey}_$id');
  }

  static Future<void> markPlanDayCompleted(String planId) async {
    final prefs = await _instance;
    final progress = await _loadPlanProgress(planId);
    progress.add(DateTime.now().toIso8601String());
    await prefs.setString('${_planProgressKey}_$planId', jsonEncode(progress));
    await _updatePlanProgress(await loadStudyPlans());
  }

  static Future<List<String>> _loadPlanProgress(String planId) async {
    final prefs = await _instance;
    final raw = prefs.getString('${_planProgressKey}_$planId');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _updatePlanProgress(List<StudyPlan> plans) async {
    final prefs = await _instance;
    for (final plan in plans) {
      final progress = await _loadPlanProgress(plan.id);
      final uniqueDays = progress.map((d) {
        final date = DateTime.parse(d);
        return '${date.year}-${date.month}-${date.day}';
      }).toSet().length;
      final updatedPlan = StudyPlan(
        id: plan.id,
        title: plan.title,
        type: plan.type,
        subject: plan.subject,
        targetQuestions: plan.targetQuestions,
        targetMinutes: plan.targetMinutes,
        startDate: plan.startDate,
        endDate: plan.endDate,
        description: plan.description,
        completedDays: uniqueDays,
        totalDays: plan.totalDays,
      );
      await prefs.setString('${_studyPlansKey}_${plan.id}', jsonEncode(updatedPlan.toJson()));
    }
  }

  // ========== 学习笔记 ==========

  static const String _notesKey = 'notes';

  static Future<List<Note>> loadNotes() async {
    final prefs = await _instance;
    final raw = prefs.getString(_notesKey);
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList()
          ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime.now())
              .compareTo(a.updatedAt ?? a.createdAt ?? DateTime.now()));
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveNote(Note note) async {
    final notes = await loadNotes();
    final index = notes.indexWhere((n) => n.id == note.id);
    if (index >= 0) {
      notes[index] = note;
    } else {
      notes.add(note);
    }
    final prefs = await _instance;
    await prefs.setString(_notesKey, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }

  static Future<void> deleteNote(String id) async {
    final notes = await loadNotes();
    notes.removeWhere((n) => n.id == id);
    final prefs = await _instance;
    await prefs.setString(_notesKey, jsonEncode(notes.map((n) => n.toJson()).toList()));
  }

  static Future<List<Note>> searchNotes(String query) async {
    final notes = await loadNotes();
    if (query.isEmpty) return notes;
    final lowerQuery = query.toLowerCase();
    return notes.where((note) =>
        note.title.toLowerCase().contains(lowerQuery) ||
        note.content.toLowerCase().contains(lowerQuery) ||
        note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))).toList();
  }

  // ========== 知识点统计 ==========

  static const String _knowledgeStatsKey = 'knowledgeStats';

  static Future<List<KnowledgePointStats>> loadKnowledgeStats() async {
    final prefs = await _instance;
    final raw = prefs.getString(_knowledgeStatsKey);
    if (raw == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      return jsonList
          .map((e) => KnowledgePointStats.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveKnowledgeStats(List<KnowledgePointStats> stats) async {
    final prefs = await _instance;
    await prefs.setString(_knowledgeStatsKey, jsonEncode(stats.map((s) => s.toJson()).toList()));
  }

  static Future<void> updateKnowledgePointStats(
    String pointId, {
    required bool isCorrect,
    String? subjectName,
  }) async {
    final stats = await loadKnowledgeStats();
    final index = stats.indexWhere((s) => s.point.id == pointId);
    
    if (index >= 0) {
      final current = stats[index];
      stats[index] = KnowledgePointStats(
        point: KnowledgePoint(
          id: current.point.id,
          name: current.point.name,
          subject: current.point.subject,
          chapter: current.point.chapter,
          totalQuestions: current.point.totalQuestions + 1,
          correctCount: current.point.correctCount + (isCorrect ? 1 : 0),
          masteryLevel: _calculateMastery(current.point.totalQuestions + 1, current.point.correctCount + (isCorrect ? 1 : 0)),
        ),
        wrongCount: current.wrongCount + (isCorrect ? 0 : 1),
        practiceCount: current.practiceCount + 1,
        lastPracticeDate: DateTime.now(),
        trend: _updateTrend(current.trend, isCorrect ? 1.0 : 0.0),
      );
    }
    
    await saveKnowledgeStats(stats);
  }

  static double _calculateMastery(int total, int correct) {
    if (total == 0) return 0.0;
    final accuracy = correct / total;
    return accuracy * (1 - 1 / (1 + total / 5));
  }

  static List<double> _updateTrend(List<double> trend, double value) {
    final newTrend = List<double>.from(trend);
    newTrend.add(value);
    if (newTrend.length > 7) {
      newTrend.removeAt(0);
    }
    return newTrend;
  }
}
