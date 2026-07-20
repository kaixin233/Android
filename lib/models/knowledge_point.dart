import 'question.dart';

class KnowledgePoint {
  KnowledgePoint({
    required this.id,
    required this.name,
    this.subject,
    this.chapter,
    this.parentId,
    this.children = const [],
    this.totalQuestions = 0,
    this.correctCount = 0,
    this.masteryLevel = 0.0,
  });

  final String id;
  final String name;
  final QuestionSubject? subject;
  final String? chapter;
  final String? parentId;
  final List<KnowledgePoint> children;
  final int totalQuestions;
  final int correctCount;
  final double masteryLevel;

  double get accuracy => totalQuestions == 0 ? 0 : correctCount / totalQuestions;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'subject': subject?.name,
      'chapter': chapter,
      'parentId': parentId,
      'totalQuestions': totalQuestions,
      'correctCount': correctCount,
      'masteryLevel': masteryLevel,
    };
  }

  factory KnowledgePoint.fromJson(Map<String, dynamic> json) {
    return KnowledgePoint(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      subject: json['subject'] != null
          ? QuestionSubjectExtension.fromName(json['subject'] as String)
          : null,
      chapter: json['chapter'] as String?,
      parentId: json['parentId'] as String?,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      masteryLevel: json['masteryLevel'] as double? ?? 0.0,
    );
  }
}

class KnowledgePointStats {
  KnowledgePointStats({
    required this.point,
    this.wrongCount = 0,
    this.practiceCount = 0,
    this.lastPracticeDate,
    this.trend = const [],
  });

  final KnowledgePoint point;
  final int wrongCount;
  final int practiceCount;
  final DateTime? lastPracticeDate;
  final List<double> trend;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'point': point.toJson(),
      'wrongCount': wrongCount,
      'practiceCount': practiceCount,
      'lastPracticeDate': lastPracticeDate?.toIso8601String(),
      'trend': trend,
    };
  }

  factory KnowledgePointStats.fromJson(Map<String, dynamic> json) {
    return KnowledgePointStats(
      point: KnowledgePoint.fromJson(json['point'] as Map<String, dynamic>),
      wrongCount: json['wrongCount'] as int? ?? 0,
      practiceCount: json['practiceCount'] as int? ?? 0,
      lastPracticeDate: json['lastPracticeDate'] != null
          ? DateTime.parse(json['lastPracticeDate'] as String)
          : null,
      trend: (json['trend'] as List<dynamic>?)?.map((e) => e as double).toList() ?? [],
    );
  }
}