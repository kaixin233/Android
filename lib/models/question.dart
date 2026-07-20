import 'package:flutter/material.dart';

enum QuestionType {
  singleChoice,
  multipleChoice,
  trueFalse,
  fillBlank,
}

enum QuestionSubject {
  law,        // 法规
  management, // 管理
  economy,    // 经济
  practice,   // 实务
}

enum QuestionDifficulty {
  easy,
  medium,
  hard,
}

extension QuestionTypeExtension on QuestionType {
  String get name {
    switch (this) {
      case QuestionType.singleChoice:
        return 'singleChoice';
      case QuestionType.multipleChoice:
        return 'multipleChoice';
      case QuestionType.trueFalse:
        return 'trueFalse';
      case QuestionType.fillBlank:
        return 'fillBlank';
    }
  }

  String get label {
    switch (this) {
      case QuestionType.singleChoice:
        return '单选题';
      case QuestionType.multipleChoice:
        return '多选题';
      case QuestionType.trueFalse:
        return '判断题';
      case QuestionType.fillBlank:
        return '填空题';
    }
  }

  static QuestionType fromName(String name) {
    switch (name) {
      case 'singleChoice':
        return QuestionType.singleChoice;
      case 'multipleChoice':
        return QuestionType.multipleChoice;
      case 'trueFalse':
        return QuestionType.trueFalse;
      case 'fillBlank':
        return QuestionType.fillBlank;
      default:
        return QuestionType.singleChoice;
    }
  }
}

extension QuestionSubjectExtension on QuestionSubject {
  String get name {
    switch (this) {
      case QuestionSubject.law:
        return 'law';
      case QuestionSubject.management:
        return 'management';
      case QuestionSubject.economy:
        return 'economy';
      case QuestionSubject.practice:
        return 'practice';
    }
  }

  String get label {
    switch (this) {
      case QuestionSubject.law:
        return '法规';
      case QuestionSubject.management:
        return '管理';
      case QuestionSubject.economy:
        return '经济';
      case QuestionSubject.practice:
        return '实务';
    }
  }

  String get description {
    switch (this) {
      case QuestionSubject.law:
        return '建设工程法规及相关知识';
      case QuestionSubject.management:
        return '建设工程项目管理';
      case QuestionSubject.economy:
        return '建设工程经济';
      case QuestionSubject.practice:
        return '市政公用工程管理与实务';
    }
  }

  Color get color {
    switch (this) {
      case QuestionSubject.law:
        return Colors.blue;
      case QuestionSubject.management:
        return Colors.orange;
      case QuestionSubject.economy:
        return Colors.green;
      case QuestionSubject.practice:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case QuestionSubject.law:
        return Icons.gavel_rounded;
      case QuestionSubject.management:
        return Icons.build_rounded;
      case QuestionSubject.economy:
        return Icons.trending_up_rounded;
      case QuestionSubject.practice:
        return Icons.construction_rounded;
    }
  }

  static QuestionSubject fromName(String name) {
    switch (name) {
      case 'law':
        return QuestionSubject.law;
      case 'management':
        return QuestionSubject.management;
      case 'economy':
        return QuestionSubject.economy;
      case 'practice':
        return QuestionSubject.practice;
      default:
        return QuestionSubject.law;
    }
  }
}

extension QuestionDifficultyExtension on QuestionDifficulty {
  String get name {
    switch (this) {
      case QuestionDifficulty.easy:
        return 'easy';
      case QuestionDifficulty.medium:
        return 'medium';
      case QuestionDifficulty.hard:
        return 'hard';
    }
  }

  String get label {
    switch (this) {
      case QuestionDifficulty.easy:
        return '简单';
      case QuestionDifficulty.medium:
        return '中等';
      case QuestionDifficulty.hard:
        return '困难';
    }
  }

  Color get color {
    switch (this) {
      case QuestionDifficulty.easy:
        return Colors.green;
      case QuestionDifficulty.medium:
        return Colors.orange;
      case QuestionDifficulty.hard:
        return Colors.red;
    }
  }

  static QuestionDifficulty fromName(String name) {
    switch (name) {
      case 'easy':
        return QuestionDifficulty.easy;
      case 'medium':
        return QuestionDifficulty.medium;
      case 'hard':
        return QuestionDifficulty.hard;
      default:
        return QuestionDifficulty.medium;
    }
  }
}

class Question {
  Question({
    required this.title,
    required this.prompt,
    this.type = QuestionType.singleChoice,
    this.subject = QuestionSubject.law,
    this.difficulty = QuestionDifficulty.medium,
    this.options = const [],
    this.answerIndex,
    this.answerIndices = const [],
    this.isCorrect,
    this.acceptableAnswers = const [],
    this.explanation = '',
    this.id,
    this.chapter,
    this.subsection,
    this.knowledgePoints = const [],
  });

  final String? id;
  final String title;
  final String prompt;
  final QuestionType type;
  final QuestionSubject subject;
  final QuestionDifficulty difficulty;
  final List<String> options;
  final int? answerIndex;
  final List<int> answerIndices;
  final bool? isCorrect;
  final List<String> acceptableAnswers;
  final String explanation;
  final String? chapter;
  final String? subsection;
  final List<String> knowledgePoints;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'prompt': prompt,
      'type': type.name,
      'subject': subject.name,
      'difficulty': difficulty.name,
      'options': options,
      'answerIndex': answerIndex,
      'answerIndices': answerIndices,
      'isCorrect': isCorrect,
      'acceptableAnswers': acceptableAnswers,
      'explanation': explanation,
      'chapter': chapter,
      'subsection': subsection,
      'knowledgePoints': knowledgePoints,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      type: QuestionTypeExtension.fromName(json['type'] as String? ?? 'singleChoice'),
      subject: QuestionSubjectExtension.fromName(json['subject'] as String? ?? 'law'),
      difficulty: QuestionDifficultyExtension.fromName(json['difficulty'] as String? ?? 'medium'),
      options: (json['options'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      answerIndex: json['answerIndex'] as int?,
      answerIndices: (json['answerIndices'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [],
      isCorrect: json['isCorrect'] as bool?,
      acceptableAnswers: (json['acceptableAnswers'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      explanation: json['explanation'] as String? ?? '',
      chapter: json['chapter'] as String?,
      subsection: json['subsection'] as String?,
      knowledgePoints: (json['knowledgePoints'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }

  String get uniqueKey => id ?? '$title|$prompt';
}
