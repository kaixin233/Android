import 'package:flutter/material.dart';

import 'question.dart';

enum NoteCategory {
  important,
  doubt,
  summary,
  custom,
}

extension NoteCategoryExtension on NoteCategory {
  String get name {
    switch (this) {
      case NoteCategory.important:
        return 'important';
      case NoteCategory.doubt:
        return 'doubt';
      case NoteCategory.summary:
        return 'summary';
      case NoteCategory.custom:
        return 'custom';
    }
  }

  String get label {
    switch (this) {
      case NoteCategory.important:
        return '重点';
      case NoteCategory.doubt:
        return '疑问';
      case NoteCategory.summary:
        return '总结';
      case NoteCategory.custom:
        return '自定义';
    }
  }

  Color get color {
    switch (this) {
      case NoteCategory.important:
        return const Color(0xFFEF4444);
      case NoteCategory.doubt:
        return const Color(0xFF3B82F6);
      case NoteCategory.summary:
        return const Color(0xFF10B981);
      case NoteCategory.custom:
        return const Color(0xFF8B5CF6);
    }
  }

  static NoteCategory fromName(String name) {
    switch (name) {
      case 'important':
        return NoteCategory.important;
      case 'doubt':
        return NoteCategory.doubt;
      case 'summary':
        return NoteCategory.summary;
      case 'custom':
        return NoteCategory.custom;
      default:
        return NoteCategory.custom;
    }
  }
}

class Note {
  Note({
    required this.id,
    required this.title,
    required this.content,
    this.category = NoteCategory.custom,
    this.subject,
    this.tags = const [],
    this.questionKey,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final NoteCategory category;
  final QuestionSubject? subject;
  final List<String> tags;
  final String? questionKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'category': category.name,
      'subject': subject?.name,
      'tags': tags,
      'questionKey': questionKey,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      category: NoteCategoryExtension.fromName(json['category'] as String? ?? 'custom'),
      subject: json['subject'] != null
          ? QuestionSubjectExtension.fromName(json['subject'] as String)
          : null,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      questionKey: json['questionKey'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }
}