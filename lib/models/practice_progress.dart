import 'answer_outcome.dart';
import 'history_item.dart';

/// 单题作答记录（可序列化），用于保存与恢复练习进度。
class SavedAnswer {
  const SavedAnswer({
    required this.outcome,
    this.selectedIndex,
    this.selectedIndices = const [],
    this.selectedBool,
    this.fillBlankText = '',
  });

  final AnswerOutcome outcome;
  final int? selectedIndex;
  final List<int> selectedIndices;
  final bool? selectedBool;
  final String fillBlankText;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'outcome': outcome.name,
        'selectedIndex': selectedIndex,
        'selectedIndices': selectedIndices,
        'selectedBool': selectedBool,
        'fillBlankText': fillBlankText,
      };

  factory SavedAnswer.fromJson(Map<String, dynamic> json) {
    return SavedAnswer(
      outcome: AnswerOutcomeX.fromName(json['outcome'] as String? ?? 'wrong'),
      selectedIndex: (json['selectedIndex'] as num?)?.toInt(),
      selectedIndices: (json['selectedIndices'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      selectedBool: json['selectedBool'] as bool?,
      fillBlankText: json['fillBlankText'] as String? ?? '',
    );
  }
}

/// 未完成练习的进度快照。
///
/// 退出练习时若该节点题目未全部作答完成，则保存本快照；首页据此提示"继续练习"。
/// 全部作答完成或主动完成后清除。
class PracticeProgress {
  const PracticeProgress({
    required this.title,
    required this.modeName,
    required this.questionKeys,
    required this.answers,
    required this.currentIndex,
    required this.correctCount,
    required this.savedAt,
    this.subjectName,
    this.chapterNumber,
    this.subsection,
  });

  /// 展示用标题（如"法规 练习"）
  final String title;

  /// 练习模式名（PracticeMode.name）
  final String modeName;

  final String? subjectName;
  final String? chapterNumber;
  final String? subsection;

  /// 本次练习的题目唯一键（保持顺序）
  final List<String> questionKeys;

  /// 已作答记录：uniqueKey -> SavedAnswer
  final Map<String, SavedAnswer> answers;

  final int currentIndex;
  final int correctCount;
  final DateTime savedAt;

  int get total => questionKeys.length;
  int get answeredCount => answers.length;
  bool get isFinished => total > 0 && answeredCount >= total;
  double get ratio => total == 0 ? 0 : answeredCount / total;

  PracticeMode get mode => PracticeModeExtension.fromName(modeName);

  /// 进度百分比文本（如 "3/10"）
  String get progressText => '$answeredCount/$total';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'modeName': modeName,
        'subjectName': subjectName,
        'chapterNumber': chapterNumber,
        'subsection': subsection,
        'questionKeys': questionKeys,
        'answers': answers.map((k, v) => MapEntry(k, v.toJson())),
        'currentIndex': currentIndex,
        'correctCount': correctCount,
        'savedAt': savedAt.toIso8601String(),
      };

  factory PracticeProgress.fromJson(Map<String, dynamic> json) {
    final rawAnswers = json['answers'] as Map<String, dynamic>? ?? const {};
    return PracticeProgress(
      title: json['title'] as String? ?? '练习',
      modeName: json['modeName'] as String? ?? 'practice',
      subjectName: json['subjectName'] as String?,
      chapterNumber: json['chapterNumber'] as String?,
      subsection: json['subsection'] as String?,
      questionKeys: (json['questionKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      answers: rawAnswers.map((k, v) => MapEntry(
            k,
            SavedAnswer.fromJson(Map<String, dynamic>.from(v as Map)),
          )),
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      savedAt: json['savedAt'] is String
          ? (DateTime.tryParse(json['savedAt'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
