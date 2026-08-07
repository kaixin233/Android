import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_qa_record.dart';

/// AI 问答记录持久化服务
///
/// 以条目 ID 为 key 关联存储问答记录：
/// - 同一条目再次提问时自动带出历史回答，无需重复提问；
/// - 支持追加问答（连续追问）、覆盖（重新生成）、删除与全量历史查询。
class AiQaStorageService {
  AiQaStorageService._();

  static const String _recordsKey = 'aiQaRecords';

  /// 最多保留的记录条数（超出后按最近更新时间淘汰最旧的）
  static const int _maxRecords = 300;

  /// 单条记录最多保留的问答轮数
  static const int _maxMessagesPerRecord = 50;

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<Map<String, AiQaRecord>> _loadAll() async {
    final prefs = await _instance;
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) =>
          MapEntry(k, AiQaRecord.fromJson(v as Map<String, dynamic>)));
    } catch (e) {
      return {};
    }
  }

  static Future<void> _saveAll(Map<String, AiQaRecord> records) async {
    // 淘汰最旧的记录，防止无限增长
    if (records.length > _maxRecords) {
      final sorted = records.values.toList()
        ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      final removeCount = records.length - _maxRecords;
      for (final r in sorted.take(removeCount)) {
        records.remove(r.itemId);
      }
    }
    final prefs = await _instance;
    await prefs.setString(
      _recordsKey,
      jsonEncode(records.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  /// 读取指定条目的问答记录；不存在时返回 null
  static Future<AiQaRecord?> loadRecord(String itemId) async {
    final all = await _loadAll();
    return all[itemId];
  }

  /// 保存（新增或覆盖）一条记录
  static Future<void> saveRecord(AiQaRecord record) async {
    final all = await _loadAll();
    record.touch();
    all[record.itemId] = record;
    await _saveAll(all);
  }

  /// 向指定条目追加一轮问答；记录不存在时自动创建
  static Future<AiQaRecord> appendMessage({
    required String itemId,
    required String itemType,
    required String itemTitle,
    required String contextText,
    required AiQaMessage message,
  }) async {
    final all = await _loadAll();
    final record = all[itemId] ??
        AiQaRecord(
          itemId: itemId,
          itemType: itemType,
          itemTitle: itemTitle,
          contextText: contextText,
        );
    // 上下文以最新一次提问时的内容为准（教材可能更新）
    record.contextText = contextText;
    record.messages.add(message);
    if (record.messages.length > _maxMessagesPerRecord) {
      record.messages.removeRange(
          0, record.messages.length - _maxMessagesPerRecord);
    }
    record.touch();
    all[itemId] = record;
    await _saveAll(all);
    return record;
  }

  /// 替换最后一条回答（重新生成场景）
  static Future<void> replaceLastMessage(String itemId, AiQaMessage message) async {
    final all = await _loadAll();
    final record = all[itemId];
    if (record == null) return;
    if (record.messages.isNotEmpty) {
      record.messages[record.messages.length - 1] = message;
    } else {
      record.messages.add(message);
    }
    record.touch();
    await _saveAll(all);
  }

  /// 删除指定条目的记录
  static Future<void> deleteRecord(String itemId) async {
    final all = await _loadAll();
    if (all.remove(itemId) != null) {
      await _saveAll(all);
    }
  }

  /// 全量历史，按最近更新倒序
  static Future<List<AiQaRecord>> loadAllRecords() async {
    final all = await _loadAll();
    final list = all.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// 清空全部问答记录
  static Future<void> clearAll() async {
    final prefs = await _instance;
    await prefs.remove(_recordsKey);
  }
}
