import '../models/question.dart';
import '../services/question_loader.dart';

/// 默认题库 - 从二级建造师题库 JSON 文件加载
class DefaultQuestions {
  DefaultQuestions._();

  /// 所有题目（首次调用时异步加载并缓存）
  static Future<List<Question>> loadAll() async {
    return QuestionLoader.loadAll();
  }

  /// 同步获取已缓存的题目（需先调用 loadAll）
  static List<Question> get cachedAll => QuestionLoader.cachedQuestions;

  /// 按科目加载题目
  static Future<List<Question>> loadBySubject(QuestionSubject subject) async {
    return QuestionLoader.loadSubject(subject.name);
  }

  /// 按章节加载题目
  static Future<List<Question>> loadByChapter(
    QuestionSubject subject,
    String chapter,
  ) async {
    return QuestionLoader.loadChapter(subject.name, chapter);
  }

  /// 加载真题/模拟题
  static Future<List<Question>> loadExams(QuestionSubject subject) async {
    return QuestionLoader.loadExams(subject.name);
  }
}