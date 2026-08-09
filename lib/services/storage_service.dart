import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/question.dart';
import '../models/history_item.dart';
import '../models/study_plan.dart';
import '../models/note.dart';
import '../models/knowledge_point.dart';
import '../services/ai_qa_storage_service.dart';

/// 持久化存储服务 - 封装 SharedPreferences 操作
class StorageService {
  static const String _importedQuestionsKey = 'importedQuestions';
  static const String _historyKey = 'history';
  static const String _completedChaptersKey = 'completedChapters';
  static const String _favoritesKey = 'favorites';
  static const String _wrongQuestionsKey = 'wrongQuestions';
  static const String _wrongCountKey = 'wrongCounts';
  static const String _themeModeKey = 'themeMode';
  static const String _vibrationEnabledKey = 'vibrationEnabled';
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
    // 同步清理错误次数统计，避免错题本移除后该 key 的计数残留导致错题分析页虚高
    final counts = await loadWrongCounts();
    if (counts.containsKey(uniqueKey)) {
      counts.remove(uniqueKey);
      await saveWrongCounts(counts);
    }
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

  // ========== 阅读字号缩放 ==========

  static const String _fontScaleKey = 'fontScale';

  static Future<double> loadFontScale() async {
    final prefs = await _instance;
    return prefs.getDouble(_fontScaleKey) ?? 1.0;
  }

  static Future<void> saveFontScale(double scale) async {
    final prefs = await _instance;
    await prefs.setDouble(_fontScaleKey, scale);
  }

  // ========== 自动本地备份时间戳 ==========

  static const String _lastAutoBackupKey = 'lastAutoBackupAt';

  static Future<int> loadLastAutoBackup() async {
    final prefs = await _instance;
    return prefs.getInt(_lastAutoBackupKey) ?? 0;
  }

  static Future<void> saveLastAutoBackup(int millis) async {
    final prefs = await _instance;
    await prefs.setInt(_lastAutoBackupKey, millis);
  }

  // ========== 自动备份开关 ==========

  static const String _autoBackupKey = 'autoBackupEnabled';

  static Future<bool> loadAutoBackupEnabled() async {
    final prefs = await _instance;
    return prefs.getBool(_autoBackupKey) ?? true;
  }

  static Future<void> saveAutoBackupEnabled(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(_autoBackupKey, enabled);
  }

  // ========== 阅读书签 + 上次阅读 ==========

  static const String _bookmarksKey = 'readingBookmarks';
  static const String _lastReadKey = 'lastReadSection';

  static Future<List<Map<String, dynamic>>> loadBookmarks() async {
    final prefs = await _instance;
    final raw = prefs.getString(_bookmarksKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveBookmarks(List<Map<String, dynamic>> bookmarks) async {
    final prefs = await _instance;
    await prefs.setString(_bookmarksKey, jsonEncode(bookmarks));
  }

  static Future<bool> isBookmarked(String id) async {
    final list = await loadBookmarks();
    return list.any((b) => b['id'] == id);
  }

  /// 切换书签：已存在则移除，否则新增。返回最新是否收藏。
  static Future<bool> toggleBookmark(Map<String, dynamic> bookmark) async {
    final list = await loadBookmarks();
    final idx = list.indexWhere((b) => b['id'] == bookmark['id']);
    final nowBookmarked = idx < 0;
    if (nowBookmarked) {
      list.add(bookmark);
    } else {
      list.removeAt(idx);
    }
    await saveBookmarks(list);
    return nowBookmarked;
  }

  static Future<void> saveLastRead(
    String subject,
    String chapterNumber,
    String sectionNumber,
    String title,
  ) async {
    final prefs = await _instance;
    final map = <String, dynamic>{
      'chapterNumber': chapterNumber,
      'sectionNumber': sectionNumber,
      'title': title,
      'at': DateTime.now().toIso8601String(),
    };
    final all = prefs.getString(_lastReadKey);
    final data = all == null
        ? <String, dynamic>{}
        : (jsonDecode(all) as Map<String, dynamic>);
    data[subject] = map;
    await prefs.setString(_lastReadKey, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> loadLastRead(String subject) async {
    final prefs = await _instance;
    final all = prefs.getString(_lastReadKey);
    if (all == null) return null;
    try {
      final data = jsonDecode(all) as Map<String, dynamic>;
      final entry = data[subject];
      return entry == null ? null : Map<String, dynamic>.from(entry as Map);
    } catch (e) {
      return null;
    }
  }

  /// 读取完整的"上次阅读"映射（科目 -> 进度），用于数据导出。
  static Future<Map<String, dynamic>> loadAllLastRead() async {
    final prefs = await _instance;
    final all = prefs.getString(_lastReadKey);
    if (all == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(all) as Map<String, dynamic>);
    } catch (e) {
      return {};
    }
  }

  // ========== 震动反馈 ==========

  static Future<bool> loadVibrationEnabled() async {
    final prefs = await _instance;
    return prefs.getBool(_vibrationEnabledKey) ?? true;
  }

  static Future<void> saveVibrationEnabled(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(_vibrationEnabledKey, enabled);
  }

  // ========== 语音播报设置 ==========

  static const String _ttsAutoPlayExplanationKey = 'ttsAutoPlayExplanation';
  static const String _ttsAutoReadQuestionKey = 'ttsAutoReadQuestion';
  static const String _ttsSkipExplanationOnCorrectKey = 'ttsSkipExplanationOnCorrect';
  static const String _ttsSpeechRateKey = 'ttsSpeechRate';
  static const String _ttsPitchKey = 'ttsPitch';
  static const String _ttsVolumeKey = 'ttsVolume';

  static Future<bool> loadTtsAutoPlayExplanation() async {
    final prefs = await _instance;
    return prefs.getBool(_ttsAutoPlayExplanationKey) ?? true;
  }

  static Future<void> saveTtsAutoPlayExplanation(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(_ttsAutoPlayExplanationKey, enabled);
  }

  static Future<bool> loadTtsAutoReadQuestion() async {
    final prefs = await _instance;
    return prefs.getBool(_ttsAutoReadQuestionKey) ?? false;
  }

  static Future<void> saveTtsAutoReadQuestion(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(_ttsAutoReadQuestionKey, enabled);
  }

  static Future<bool> loadTtsSkipExplanationOnCorrect() async {
    final prefs = await _instance;
    return prefs.getBool(_ttsSkipExplanationOnCorrectKey) ?? false;
  }

  static Future<void> saveTtsSkipExplanationOnCorrect(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(_ttsSkipExplanationOnCorrectKey, enabled);
  }

  static Future<double> loadTtsSpeechRate() async {
    final prefs = await _instance;
    return prefs.getDouble(_ttsSpeechRateKey) ?? 0.5;
  }

  static Future<void> saveTtsSpeechRate(double rate) async {
    final prefs = await _instance;
    await prefs.setDouble(_ttsSpeechRateKey, rate);
  }

  static Future<double> loadTtsPitch() async {
    final prefs = await _instance;
    return prefs.getDouble(_ttsPitchKey) ?? 1.0;
  }

  static Future<void> saveTtsPitch(double pitch) async {
    final prefs = await _instance;
    await prefs.setDouble(_ttsPitchKey, pitch);
  }

  static Future<double> loadTtsVolume() async {
    final prefs = await _instance;
    return prefs.getDouble(_ttsVolumeKey) ?? 1.0;
  }

  static Future<void> saveTtsVolume(double volume) async {
    final prefs = await _instance;
    await prefs.setDouble(_ttsVolumeKey, volume);
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

  static Future<void> markChapterCompleted(QuestionSubject subject, String chapterNumber) async {
    final progress = await _loadChapterProgress();
    final key = '${subject.name}_$chapterNumber';
    progress[key] = true;
    await _saveChapterProgress(progress);
    // 直接用已加载的 progress 计算，避免重复 IO
    await saveCompletedChapters(progress.values.where((v) => v).length);
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

  // ========== 数据导出 ==========

  /// 导出全部用户数据。注意此方法必须覆盖所有持久化数据集，
  /// 否则"导出全部数据"与自动备份会把未包含的数据变成不可逆丢失。
  static Future<String> exportAllData() async {
    final imported = await loadImportedQuestions();
    final history = await loadHistory();
    final favorites = await loadFavorites();
    final wrongKeys = await loadWrongQuestionKeys();
    final wrongCounts = await loadWrongCounts();
    final completedChapters = await loadCompletedChapters();
    final streakDays = await loadStreakDays();
    final chapterProgress = await _loadChapterProgress();
    final notes = await loadNotes();
    final studyPlans = await loadStudyPlans();
    final knowledgeStats = await loadKnowledgeStats();
    final bookmarks = await loadBookmarks();
    final lastRead = await loadAllLastRead();
    final planProgress = await loadAllPlanProgress();
    final aiQaRecords = await AiQaStorageService.exportAllJson();

    final data = {
      'version': '1.1',
      'exportedAt': DateTime.now().toIso8601String(),
      'importedQuestions': imported.map((q) => q.toJson()).toList(),
      'history': history.map((h) => h.toJson()).toList(),
      'favorites': favorites.toList(),
      'wrongQuestionKeys': wrongKeys,
      'wrongCounts': wrongCounts,
      'completedChapters': completedChapters,
      'streakDays': streakDays,
      'chapterProgress': chapterProgress,
      'notes': notes.map((n) => n.toJson()).toList(),
      'studyPlans': studyPlans.map((p) => p.toJson()).toList(),
      'knowledgeStats': knowledgeStats.map((s) => s.toJson()).toList(),
      'bookmarks': bookmarks,
      'lastRead': lastRead,
      'planProgress': planProgress,
      'aiQaRecords': aiQaRecords,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ========== 数据导入 ==========

  /// 导入全部用户数据。逐字段容错解析，单个字段损坏不影响其它字段，
  /// 且覆盖所有导出的数据集（笔记/计划/统计/书签/阅读进度/AI 问答等）。
  static Future<void> importAllData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final prefs = await _instance;

      if (data.containsKey('importedQuestions')) {
        final questions = (data['importedQuestions'] as List<dynamic>? ?? [])
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList();
        await saveImportedQuestions(questions);
      }

      if (data.containsKey('history')) {
        final history = (data['history'] as List<dynamic>? ?? [])
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
        await saveHistory(history);
      }

      if (data.containsKey('favorites')) {
        final favorites =
            (data['favorites'] as List<dynamic>? ?? []).whereType<String>().toSet();
        await saveFavorites(favorites);
      }

      if (data.containsKey('wrongQuestionKeys')) {
        final wrongKeys =
            (data['wrongQuestionKeys'] as List<dynamic>? ?? []).whereType<String>().toList();
        await saveWrongQuestionKeys(wrongKeys);
      }

      if (data.containsKey('wrongCounts')) {
        final raw = data['wrongCounts'];
        final Map<String, int> counts = {};
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k is String) counts[k] = (v is int) ? v : (int.tryParse(v.toString()) ?? 0);
          });
        }
        await saveWrongCounts(counts);
      }

      if (data.containsKey('completedChapters')) {
        final v = data['completedChapters'];
        if (v is int) await saveCompletedChapters(v);
      }

      if (data.containsKey('streakDays')) {
        final v = data['streakDays'];
        if (v is int) await prefs.setInt(_streakDaysKey, v);
      }

      if (data.containsKey('chapterProgress')) {
        final v = data['chapterProgress'];
        if (v is Map) await prefs.setString(_chapterProgressKey, jsonEncode(v));
      }

      if (data.containsKey('notes')) {
        final notes = (data['notes'] as List<dynamic>? ?? [])
            .map((e) => Note.fromJson(e as Map<String, dynamic>))
            .toList();
        await prefs.setString(
          _notesKey,
          jsonEncode(notes.map((n) => n.toJson()).toList()),
        );
      }

      if (data.containsKey('studyPlans')) {
        final plans = (data['studyPlans'] as List<dynamic>? ?? [])
            .map((e) => StudyPlan.fromJson(e as Map<String, dynamic>))
            .toList();
        await prefs.setStringList(
          _studyPlansKey,
          plans.map((p) => jsonEncode(p.toJson())).toList(),
        );
      }

      if (data.containsKey('knowledgeStats')) {
        final stats = (data['knowledgeStats'] as List<dynamic>? ?? [])
            .map((e) => KnowledgePointStats.fromJson(e as Map<String, dynamic>))
            .toList();
        await saveKnowledgeStats(stats);
      }

      if (data.containsKey('bookmarks')) {
        final bms = (data['bookmarks'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await saveBookmarks(bms);
      }

      if (data.containsKey('lastRead')) {
        final v = data['lastRead'];
        if (v is Map) await prefs.setString(_lastReadKey, jsonEncode(v));
      }

      if (data.containsKey('planProgress')) {
        final Map<String, List<String>> progress = {};
        final raw = data['planProgress'];
        if (raw is Map) {
          raw.forEach((k, v) {
            if (k is String && v is List) {
              progress[k] = v.whereType<String>().toList();
            }
          });
        }
        await saveAllPlanProgress(progress);
      }

      if (data.containsKey('aiQaRecords')) {
        final raw = data['aiQaRecords'];
        final list = raw is List ? raw : (raw is Map ? raw.values.toList() : <dynamic>[]);
        await AiQaStorageService.importAllJson(list);
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
    // 仅在内存中计算进度，不再写回存储（避免每次读取触发写入）
    return _computePlanProgress(plans);
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

  /// 读取全部学习计划打卡进度（id -> 打卡日期列表），用于数据导出。
  static Future<Map<String, List<String>>> loadAllPlanProgress() async {
    final prefs = await _instance;
    final result = <String, List<String>>{};
    const prefix = '${_planProgressKey}_';
    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        final id = key.substring(prefix.length);
        final raw = prefs.getString(key);
        if (raw != null) {
          try {
            result[id] = (jsonDecode(raw) as List<dynamic>).whereType<String>().toList();
          } catch (_) {
            // 单条损坏不影响其它
          }
        }
      }
    }
    return result;
  }

  /// 写入全部学习计划打卡进度（导入数据时使用）。
  static Future<void> saveAllPlanProgress(Map<String, List<String>> progress) async {
    final prefs = await _instance;
    for (final entry in progress.entries) {
      await prefs.setString(
        '${_planProgressKey}_${entry.key}',
        jsonEncode(entry.value),
      );
    }
  }

  static Future<void> markPlanDayCompleted(String planId) async {
    final prefs = await _instance;
    final progress = await _loadPlanProgress(planId);
    progress.add(DateTime.now().toIso8601String());
    await prefs.setString('${_planProgressKey}_$planId', jsonEncode(progress));
    // 不再写回 plans 列表，loadStudyPlans 时会动态计算 completedDays
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

  /// 仅在内存中计算各计划的完成天数，不写回存储
  static Future<List<StudyPlan>> _computePlanProgress(List<StudyPlan> plans) async {
    final updatedPlans = <StudyPlan>[];
    for (final plan in plans) {
      final progress = await _loadPlanProgress(plan.id);
      final uniqueDays = progress.map((d) {
        final date = DateTime.parse(d);
        return '${date.year}-${date.month}-${date.day}';
      }).toSet().length;
      updatedPlans.add(StudyPlan(
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
      ));
    }
    return updatedPlans;
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
    QuestionSubject? subject,
    String? chapter,
    String? pointName,
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
    } else {
      // 新知识点：自动创建统计条目
      stats.add(KnowledgePointStats(
        point: KnowledgePoint(
          id: pointId,
          name: pointName ?? pointId,
          subject: subject,
          chapter: chapter,
          totalQuestions: 1,
          correctCount: isCorrect ? 1 : 0,
          masteryLevel: _calculateMastery(1, isCorrect ? 1 : 0),
        ),
        wrongCount: isCorrect ? 0 : 1,
        practiceCount: 1,
        lastPracticeDate: DateTime.now(),
        trend: [isCorrect ? 1.0 : 0.0],
      ));
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
