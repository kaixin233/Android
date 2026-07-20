import 'question.dart';

/// 学习历史记录条目 - 记录每次练习/考试的详细数据
class HistoryItem {
  HistoryItem({
    required this.title,
    required this.answeredAt,
    this.correctCount = 0,
    this.totalCount = 0,
    this.durationSeconds = 0,
    this.subject,
    this.mode = PracticeMode.practice,
    this.wrongQuestionKeys = const [],
  });

  final String title;
  final String answeredAt;
  final int correctCount;
  final int totalCount;
  final int durationSeconds;
  final QuestionSubject? subject;
  final PracticeMode mode;
  final List<String> wrongQuestionKeys;

  double get accuracy => totalCount == 0 ? 0 : correctCount / totalCount;

  String get accuracyText => '${(accuracy * 100).toStringAsFixed(0)}%';

  String get durationText {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m}分${s.toString().padLeft(2, '0')}秒';
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'answeredAt': answeredAt,
      'correctCount': correctCount,
      'totalCount': totalCount,
      'durationSeconds': durationSeconds,
      'subject': subject?.name,
      'mode': mode.name,
      'wrongQuestionKeys': wrongQuestionKeys,
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      title: json['title'] as String? ?? '练习记录',
      answeredAt: json['answeredAt'] as String? ?? DateTime.now().toIso8601String(),
      correctCount: json['correctCount'] as int? ?? 0,
      totalCount: json['totalCount'] as int? ?? 0,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      subject: json['subject'] != null
          ? QuestionSubjectExtension.fromName(json['subject'] as String)
          : null,
      mode: PracticeModeExtension.fromName(json['mode'] as String? ?? 'practice'),
      wrongQuestionKeys: (json['wrongQuestionKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

enum PracticeMode {
  practice, // 普通练习
  exam,     // 考试模式
  wrong,    // 错题重做
}

extension PracticeModeExtension on PracticeMode {
  String get name {
    switch (this) {
      case PracticeMode.practice:
        return 'practice';
      case PracticeMode.exam:
        return 'exam';
      case PracticeMode.wrong:
        return 'wrong';
    }
  }

  String get label {
    switch (this) {
      case PracticeMode.practice:
        return '练习';
      case PracticeMode.exam:
        return '考试';
      case PracticeMode.wrong:
        return '错题重做';
    }
  }

  static PracticeMode fromName(String name) {
    switch (name) {
      case 'practice':
        return PracticeMode.practice;
      case 'exam':
        return PracticeMode.exam;
      case 'wrong':
        return PracticeMode.wrong;
      default:
        return PracticeMode.practice;
    }
  }
}
