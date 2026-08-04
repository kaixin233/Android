import '../models/question.dart';
import '../data/default_questions.dart';
import 'storage_service.dart';

/// 题目管理服务 - 统一管理默认题库和导入题库
class QuestionService {
  QuestionService._();

  /// 全局缓存：合并后的所有题目，避免重复加载和拼接
  static List<Question>? _cachedAll;

  /// 清除缓存（导入/删除题目后调用）
  static void clearCache() {
    _cachedAll = null;
  }

  /// 获取所有题目（默认 + 导入），首次加载后缓存
  static Future<List<Question>> getAllQuestions() async {
    if (_cachedAll != null) return _cachedAll!;
    final defaults = await DefaultQuestions.loadAll();
    final imported = await StorageService.loadImportedQuestions();
    _cachedAll = [...defaults, ...imported];
    return _cachedAll!;
  }

  /// 按科目获取题目
  static Future<List<Question>> getBySubject(QuestionSubject subject) async {
    final all = await getAllQuestions();
    return all.where((q) => q.subject == subject).toList();
  }

  /// 按题型获取题目
  static Future<List<Question>> getByType(QuestionType type) async {
    final all = await getAllQuestions();
    return all.where((q) => q.type == type).toList();
  }

  /// 按条件筛选
  static Future<List<Question>> filter({
    QuestionSubject? subject,
    QuestionType? type,
    QuestionDifficulty? difficulty,
    String? keyword,
    String? chapterNumber,
    String? subsection,
    Set<String>? favoriteKeys,
    bool onlyFavorites = false,
  }) async {
    final all = await getAllQuestions();
    return all.where((q) {
      if (subject != null && q.subject != subject) return false;
      if (type != null && q.type != type) return false;
      if (difficulty != null && q.difficulty != difficulty) return false;
      if (chapterNumber != null && chapterNumber.isNotEmpty) {
        if (q.chapter == null || q.chapter != chapterNumber) return false;
      }
if (subsection != null && subsection.isNotEmpty) {
        if (q.subsection == null || q.subsection != subsection) return false;
      }
      if (keyword != null && keyword.isNotEmpty) {
        final kw = keyword.toLowerCase();
        final matchesTitle = q.title.toLowerCase().contains(kw);
        final matchesPrompt = q.prompt.toLowerCase().contains(kw);
        final matchesKnowledgePoints = q.knowledgePoints.any(
          (kp) => kp.toLowerCase().contains(kw) || kw.contains(kp.toLowerCase()),
        );
        if (!matchesTitle && !matchesPrompt && !matchesKnowledgePoints) {
          return false;
        }
      }
      if (onlyFavorites && favoriteKeys != null && !favoriteKeys.contains(q.uniqueKey)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 获取指定科目指定章节的考点列表（去重）
  static Future<List<String>> getKnowledgePointsByChapter({
    required QuestionSubject subject,
    required String chapterNumber,
  }) async {
    final questions = await filter(
      subject: subject,
      chapterNumber: chapterNumber,
    );
    final points = <String>{};
    for (final q in questions) {
      points.addAll(q.knowledgePoints);
    }
    return points.toList()..sort();
  }

  /// 根据唯一键集合获取题目
  static Future<List<Question>> getByKeys(List<String> keys) async {
    final keySet = keys.toSet();
    // 直接使用全局缓存，避免重复加载
    final all = await getAllQuestions();
    return all.where((q) => keySet.contains(q.uniqueKey)).toList();
  }

  /// 导入题目（去重）
  static Future<int> importQuestions(List<Question> newQuestions) async {
    final unique = await StorageService.importQuestions(newQuestions);
    clearCache();
    return unique.length;
  }

  /// 删除导入的题目
  static Future<void> deleteImported(String uniqueKey) async {
    await StorageService.deleteImportedQuestion(uniqueKey);
    clearCache();
  }

  /// 清空导入的题目
  static Future<void> clearImported() async {
    await StorageService.clearImportedQuestions();
    clearCache();
  }

  /// 随机抽取题目
  static List<Question> randomPick(List<Question> source, int count) {
    if (source.length <= count) return List.of(source);
    final shuffled = List<Question>.from(source)..shuffle();
    return shuffled.take(count).toList();
  }

  /// 打乱选项顺序（同时调整答案索引）
  static Question shuffleOptions(Question question) {
    if (question.options.isEmpty) return question;
    final indices = List<int>.generate(question.options.length, (i) => i);
    indices.shuffle();
    final newOptions = indices.map((i) => question.options[i]).toList();

    int? newAnswerIndex;
    if (question.answerIndex != null) {
      newAnswerIndex = indices.indexOf(question.answerIndex!);
    }
    List<int> newAnswerIndices = [];
    if (question.answerIndices.isNotEmpty) {
      newAnswerIndices = question.answerIndices.map((i) => indices.indexOf(i)).toList();
    }
    return Question(
      id: question.id,
      title: question.title,
      prompt: question.prompt,
      type: question.type,
      subject: question.subject,
      difficulty: question.difficulty,
      options: newOptions,
      answerIndex: newAnswerIndex,
      answerIndices: newAnswerIndices,
      isCorrect: question.isCorrect,
      acceptableAnswers: question.acceptableAnswers,
      explanation: question.explanation,
      chapter: question.chapter,
      subsection: question.subsection,
      knowledgePoints: question.knowledgePoints,
    );
  }
}
