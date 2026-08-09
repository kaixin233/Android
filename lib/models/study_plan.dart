import '../models/question.dart';

enum PlanType {
  daily,
  weekly,
  custom,
}

extension PlanTypeExtension on PlanType {
  String get name {
    switch (this) {
      case PlanType.daily:
        return 'daily';
      case PlanType.weekly:
        return 'weekly';
      case PlanType.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case PlanType.daily:
        return '每日计划';
      case PlanType.weekly:
        return '每周计划';
      case PlanType.custom:
        return '自定义计划';
    }
  }

  static PlanType fromName(String name) {
    switch (name) {
      case 'daily':
        return PlanType.daily;
      case 'weekly':
        return PlanType.weekly;
      case 'custom':
        return PlanType.custom;
      default:
        return PlanType.daily;
    }
  }
}

class StudyPlan {
  StudyPlan({
    required this.id,
    required this.title,
    required this.type,
    required this.subject,
    required this.targetQuestions,
    required this.targetMinutes,
    required this.startDate,
    required this.endDate,
    this.description = '',
    this.completedDays = 0,
    this.totalDays = 1,
  });

  final String id;
  final String title;
  final PlanType type;
  final QuestionSubject subject;
  final int targetQuestions;
  final int targetMinutes;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final int completedDays;
  final int totalDays;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'type': type.name,
      'subject': subject.name,
      'targetQuestions': targetQuestions,
      'targetMinutes': targetMinutes,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'description': description,
      'completedDays': completedDays,
      'totalDays': totalDays,
    };
  }

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: PlanTypeExtension.fromName(
          json['type']?.toString() ?? 'daily'),
      subject: json['subject'] != null
          ? QuestionSubjectExtension.fromName(json['subject'].toString())
          : QuestionSubject.law,
      targetQuestions: (json['targetQuestions'] as num?)?.toInt() ?? 0,
      targetMinutes: (json['targetMinutes'] as num?)?.toInt() ?? 0,
      startDate: json['startDate'] is String
          ? DateTime.tryParse(json['startDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['endDate'] is String
          ? DateTime.tryParse(json['endDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      description: json['description']?.toString() ?? '',
      completedDays: (json['completedDays'] as num?)?.toInt() ?? 0,
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 1,
    );
  }

  bool get isCompleted => completedDays >= totalDays;

  double get progress => totalDays > 0 ? completedDays / totalDays : 0;

  bool get isActive {
    final today = DateTime.now();
    return today.isAfter(startDate.subtract(const Duration(days: 1))) && 
           today.isBefore(endDate.add(const Duration(days: 1)));
  }
}