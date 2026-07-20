import '../models/question.dart';
import '../data/default_questions.dart';
import 'storage_service.dart';

/// 题目管理服务 - 统一管理默认题库和导入题库
class QuestionService {
  QuestionService._();

  /// 获取所有题目（默认 + 导入）
  static Future<List<Question>> getAllQuestions() async {
    final imported = await StorageService.loadImportedQuestions();
    return [...DefaultQuestions.all, ...imported];
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
    Set<String>? favoriteKeys,
    bool onlyFavorites = false,
  }) async {
    final all = await getAllQuestions();
    return all.where((q) {
      if (subject != null && q.subject != subject) return false;
      if (type != null && q.type != type) return false;
      if (difficulty != null && q.difficulty != difficulty) return false;
      if (keyword != null && keyword.isNotEmpty) {
        final kw = keyword.toLowerCase();
        if (!q.title.toLowerCase().contains(kw) &&
            !q.prompt.toLowerCase().contains(kw)) {
          return false;
        }
      }
      if (onlyFavorites && favoriteKeys != null && !favoriteKeys.contains(q.uniqueKey)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 根据唯一键集合获取题目
  static Future<List<Question>> getByKeys(List<String> keys) async {
    final all = await getAllQuestions();
    final keySet = keys.toSet();
    return all.where((q) => keySet.contains(q.uniqueKey)).toList();
  }

  /// 导入题目（去重）
  static Future<int> importQuestions(List<Question> newQuestions) async {
    final unique = await StorageService.importQuestions(newQuestions);
    return unique.length;
  }

  /// 删除导入的题目
  static Future<void> deleteImported(String uniqueKey) async {
    await StorageService.deleteImportedQuestion(uniqueKey);
  }

  /// 清空导入的题目
  static Future<void> clearImported() async {
    await StorageService.clearImportedQuestions();
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
    );
  }
}
