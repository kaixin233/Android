import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 用户批注（运行时在考点知识中选中文本后添加）。
///
/// 与 Markdown 源中的预置注释不同，用户批注由读者创建、本地持久化，
/// 定位到具体的"科目 + 章节 + 小节 + 段落 + 选中词"上，下次打开仍在。
class UserAnnotation {
  final String subject;
  final String chapterNumber;
  final String sectionNumber;
  final int paragraphIndex;

  /// 被标注的原文（用户选中的短语）。同一个段落内相同 term 视为同一处批注。
  final String term;

  /// 用户写的解释/批注内容（气泡中展示）。
  final String note;

  /// 创建时间戳（毫秒），用于排序与展示。
  final int createdAt;

  const UserAnnotation({
    required this.subject,
    required this.chapterNumber,
    required this.sectionNumber,
    required this.paragraphIndex,
    required this.term,
    required this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'chapterNumber': chapterNumber,
        'sectionNumber': sectionNumber,
        'paragraphIndex': paragraphIndex,
        'term': term,
        'note': note,
        'createdAt': createdAt,
      };

  factory UserAnnotation.fromJson(Map<String, dynamic> json) => UserAnnotation(
        subject: json['subject'] as String,
        chapterNumber: json['chapterNumber'] as String,
        sectionNumber: json['sectionNumber'] as String,
        paragraphIndex: json['paragraphIndex'] as int,
        term: json['term'] as String,
        note: json['note'] as String,
        createdAt: json['createdAt'] as int,
      );

  /// 段落内定位主键：相同段落 + 相同 term 视为同一处（用于去重/更新）。
  String get paragraphKey =>
      '$subject|$chapterNumber|$sectionNumber|$paragraphIndex|$term';
}

/// 用户批注持久化（SharedPreferences）。
///
/// 数据以 `List<UserAnnotation>` 整体存于一个 key，读取后做内存索引，
/// 提供按"段落"查询与增删改。注意 SharedPreferences 需先由其它模块初始化，
/// 首次使用前调用 [ensureLoaded] 即可。
class AnnotationStore {
  AnnotationStore._();

  static const String _key = 'userAnnotations';

  static SharedPreferences? _prefs;
  static bool _loaded = false;
  static List<UserAnnotation> _all = [];

  /// 内存索引：paragraphKey -> 批注，便于段落级 O(1) 查询。
  static final Map<String, UserAnnotation> _byKey = {};

  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 确保批注已从本地加载到内存（幂等）。
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await _instance;
    final saved = prefs.getString(_key);
    _all = [];
    _byKey.clear();
    if (saved != null) {
      try {
        final list = jsonDecode(saved) as List<dynamic>;
        for (final e in list) {
          final a = UserAnnotation.fromJson(e as Map<String, dynamic>);
          _all.add(a);
          _byKey[a.paragraphKey] = a;
        }
      } catch (_) {
        _all = [];
        _byKey.clear();
      }
    }
    _loaded = true;
  }

  /// 取某段内的全部批注（按创建时间升序）。
  static List<UserAnnotation> annotationsFor(
    String subject,
    String chapterNumber,
    String sectionNumber,
    int paragraphIndex,
  ) {
    final prefix = '$subject|$chapterNumber|$sectionNumber|$paragraphIndex|';
    return _all.where((a) => a.paragraphKey.startsWith(prefix)).toList()
      ..sort((x, y) => x.createdAt.compareTo(y.createdAt));
  }

  /// 取某小节内的全部批注（跨段落，按创建时间升序）。
  /// 用于 `AnnotatedText` 在段落渲染时按 term 匹配高亮。
  static List<UserAnnotation> annotationsForSection(
    String subject,
    String chapterNumber,
    String sectionNumber,
  ) {
    final prefix = '$subject|$chapterNumber|$sectionNumber|';
    return _all.where((a) => a.paragraphKey.startsWith(prefix)).toList()
      ..sort((x, y) => x.createdAt.compareTo(y.createdAt));
  }

  /// 新增或更新一处批注（按 paragraphKey 去重，已存在则覆盖 note）。
  static Future<void> upsert(UserAnnotation a) async {
    _byKey[a.paragraphKey] = a;
    // 用 _byKey 重新生成有序列表，避免重复
    _all = _byKey.values.toList();
    await _persist();
  }

  /// 删除某段内的全部批注。
  static Future<void> removeAllFor(
    String subject,
    String chapterNumber,
    String sectionNumber,
    int paragraphIndex,
  ) async {
    final prefix = '$subject|$chapterNumber|$sectionNumber|$paragraphIndex|';
    _byKey.removeWhere((k, _) => k.startsWith(prefix));
    _all = _byKey.values.toList();
    await _persist();
  }

  /// 删除指定 term 的一处批注。
  static Future<void> remove(
    String subject,
    String chapterNumber,
    String sectionNumber,
    int paragraphIndex,
    String term,
  ) async {
    final key = '$subject|$chapterNumber|$sectionNumber|$paragraphIndex|$term';
    _byKey.remove(key);
    _all = _byKey.values.toList();
    await _persist();
  }

  static Future<void> _persist() async {
    final prefs = await _instance;
    final jsonList = _all.map((a) => a.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
