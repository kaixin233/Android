/// AI 学习助手问答记录模型
///
/// 一条记录（[AiQaRecord]）对应一个学习内容条目（考点知识小节或一道题目），
/// 内部按时间顺序保存多轮问答（[AiQaMessage]）。
library;

/// 单轮问答
class AiQaMessage {
  AiQaMessage({
    required this.question,
    required this.answer,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 用户提问（含快捷提问）
  final String question;

  /// AI 回答
  final String answer;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'question': question,
        'answer': answer,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AiQaMessage.fromJson(Map<String, dynamic> json) => AiQaMessage(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

/// 某个学习内容条目关联的完整问答记录
class AiQaRecord {
  AiQaRecord({
    required this.itemId,
    required this.itemType,
    required this.itemTitle,
    required this.contextText,
    List<AiQaMessage>? messages,
    DateTime? updatedAt,
  })  : messages = messages ?? <AiQaMessage>[],
        updatedAt = updatedAt ?? DateTime.now();

  /// 条目唯一标识，例如 `know:law:1:1.2` 或 `q:<questionUniqueKey>`
  final String itemId;

  /// 条目类型：`knowledge`（考点知识）或 `question`（题目）
  final String itemType;

  /// 条目展示标题（考点小节标题 / 题目标题）
  final String itemTitle;

  /// 提问时携带的上下文快照（条目正文）
  String contextText;

  /// 多轮问答，按时间升序
  final List<AiQaMessage> messages;

  DateTime updatedAt;

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => <String, dynamic>{
        'itemId': itemId,
        'itemType': itemType,
        'itemTitle': itemTitle,
        'contextText': contextText,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AiQaRecord.fromJson(Map<String, dynamic> json) => AiQaRecord(
        itemId: json['itemId'] as String? ?? '',
        itemType: json['itemType'] as String? ?? 'knowledge',
        itemTitle: json['itemTitle'] as String? ?? '',
        contextText: json['contextText'] as String? ?? '',
        messages: (json['messages'] as List<dynamic>?)
            ?.map((e) => AiQaMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}
