import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/question.dart';

/// JSON 题库加载器 - 从 assets 中按需加载题目
class QuestionLoader {
  QuestionLoader._();

  static final Map<String, List<Question>> _cache = {};
  static bool _loadedAll = false;
  static final List<Question> _allQuestions = [];

  /// 获取所有题目（首次加载后缓存）
  static Future<List<Question>> loadAll() async {
    if (_loadedAll) return List.unmodifiable(_allQuestions);

    final subjects = ['law', 'management', 'practice'];
    final futures = subjects.map((s) => loadSubject(s));
    final results = await Future.wait(futures);
    for (final list in results) {
      _allQuestions.addAll(list);
    }
    _loadedAll = true;
    return List.unmodifiable(_allQuestions);
  }

  /// 加载指定科目的所有题目
  static Future<List<Question>> loadSubject(String subject) async {
    if (_cache.containsKey(subject)) {
      return _cache[subject]!;
    }

    // 加载索引
    final indexJson = await rootBundle.loadString(
      'assets/questions/$subject/index.json',
    );
    final Map<String, dynamic> index = jsonDecode(indexJson);

    final List<Question> questions = [];
    for (final entry in index.entries) {
      final String file = entry.value['file'];
      final chapterQuestions = await _loadChapterFile(subject, file);
      questions.addAll(chapterQuestions);
    }

    _cache[subject] = questions;
    return questions;
  }

  /// 加载指定科目指定章节的题目
  static Future<List<Question>> loadChapter(
    String subject,
    String chapter,
  ) async {
    final key = '${subject}_ch$chapter';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    // 加载索引获取文件名
    final indexJson = await rootBundle.loadString(
      'assets/questions/$subject/index.json',
    );
    final Map<String, dynamic> index = jsonDecode(indexJson);
    final chapterInfo = index[chapter];
    if (chapterInfo == null) return [];

    final String file = chapterInfo['file'];
    final questions = await _loadChapterFile(subject, file);
    _cache[key] = questions;
    return questions;
  }

  /// 加载指定科目的真题
  static Future<List<Question>> loadExams(String subject) async {
    final key = '${subject}_exams';
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final questions = await _loadChapterFile(subject, 'exams.json');
    _cache[key] = questions;
    return questions;
  }

  /// 加载单个 JSON 文件
  static Future<List<Question>> _loadChapterFile(
    String subject,
    String filename,
  ) async {
    final jsonStr = await rootBundle.loadString(
      'assets/questions/$subject/$filename',
    );
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList
        .map((e) => Question.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取科目索引信息
  static Future<Map<String, ChapterIndex>> loadSubjectIndex(
    String subject,
  ) async {
    final indexJson = await rootBundle.loadString(
      'assets/questions/$subject/index.json',
    );
    final Map<String, dynamic> index = jsonDecode(indexJson);
    return index.map(
      (key, value) => MapEntry(
        key,
        ChapterIndex(
          key: key,
          name: value['name'],
          file: value['file'],
          count: value['count'],
        ),
      ),
    );
  }

  /// 清除缓存
  static void clearCache() {
    _cache.clear();
    _loadedAll = false;
    _allQuestions.clear();
  }

  /// 获取已缓存的所有题目（需先调用 loadAll）
  static List<Question> get cachedQuestions {
    if (_loadedAll) return List.unmodifiable(_allQuestions);
    return [];
  }
}

/// 章节索引信息
class ChapterIndex {
  final String key;
  final String name;
  final String file;
  final int count;

  const ChapterIndex({
    required this.key,
    required this.name,
    required this.file,
    required this.count,
  });
}