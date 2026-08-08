import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// 用户批注的生效范围。
enum AnnotationScope {
  /// 仅在添加处所在的小节生效（默认）。
  field,

  /// 全局生效：同一科目下所有出现该术语的地方都显示此批注。
  global,
}

/// 用户批注的分类，用于阅读时按类型配色区分。
enum AnnotationCategory {
  /// 重点：需要记住的核心结论。
  keyPoint,

  /// 疑问：没理解、待弄清的地方。
  question,

  /// 待背：需要背诵记忆的内容。
  todo,
}

extension AnnotationCategoryX on AnnotationCategory {
  String get label {
    switch (this) {
      case AnnotationCategory.keyPoint:
        return '重点';
      case AnnotationCategory.question:
        return '疑问';
      case AnnotationCategory.todo:
        return '待背';
    }
  }

  /// 批注底色（浅）/ 文字与边框色（深），随主题自适应。
  Color get color {
    switch (this) {
      case AnnotationCategory.keyPoint:
        return const Color(0xFFE65100); // 橙
      case AnnotationCategory.question:
        return const Color(0xFF1565C0); // 蓝
      case AnnotationCategory.todo:
        return const Color(0xFF2E7D32); // 绿
    }
  }
}

/// 添加 / 编辑批注弹窗的返回值。
class AnnotationResult {
  const AnnotationResult(this.note, this.scope, [this.category = AnnotationCategory.keyPoint]);

  /// 批注内容（已 trim）。
  final String note;

  /// 生效范围。
  final AnnotationScope scope;

  /// 分类（重点/疑问/待背）。
  final AnnotationCategory category;
}

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

  /// 生效范围：[AnnotationScope.field] 仅本小节；[AnnotationScope.global] 本科目全局。
  final AnnotationScope scope;

  /// 分类（重点/疑问/待背），用于配色区分。
  final AnnotationCategory category;

  const UserAnnotation({
    required this.subject,
    required this.chapterNumber,
    required this.sectionNumber,
    required this.paragraphIndex,
    required this.term,
    required this.note,
    required this.createdAt,
    this.scope = AnnotationScope.field,
    this.category = AnnotationCategory.keyPoint,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'chapterNumber': chapterNumber,
        'sectionNumber': sectionNumber,
        'paragraphIndex': paragraphIndex,
        'term': term,
        'note': note,
        'createdAt': createdAt,
        'scope': scope.name,
        'category': category.name,
      };

  factory UserAnnotation.fromJson(Map<String, dynamic> json) => UserAnnotation(
        subject: json['subject'] as String,
        chapterNumber: json['chapterNumber'] as String,
        sectionNumber: json['sectionNumber'] as String,
        paragraphIndex: json['paragraphIndex'] as int,
        term: json['term'] as String,
        note: json['note'] as String,
        createdAt: json['createdAt'] as int,
        scope: AnnotationScope.values.firstWhere(
          (e) => e.name == (json['scope'] as String?),
          orElse: () => AnnotationScope.field,
        ),
        category: AnnotationCategory.values.firstWhere(
          (e) => e.name == (json['category'] as String?),
          orElse: () => AnnotationCategory.keyPoint,
        ),
      );

  /// 不可变更新副本（保留原始定位主键，便于原地编辑）。
  UserAnnotation copyWith({
    String? subject,
    String? chapterNumber,
    String? sectionNumber,
    int? paragraphIndex,
    String? term,
    String? note,
    int? createdAt,
    AnnotationScope? scope,
    AnnotationCategory? category,
  }) =>
      UserAnnotation(
        subject: subject ?? this.subject,
        chapterNumber: chapterNumber ?? this.chapterNumber,
        sectionNumber: sectionNumber ?? this.sectionNumber,
        paragraphIndex: paragraphIndex ?? this.paragraphIndex,
        term: term ?? this.term,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        scope: scope ?? this.scope,
        category: category ?? this.category,
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
  ///
  /// 包含两类：
  /// - 本小节内的 [AnnotationScope.field] 批注；
  /// - 同一科目下 [AnnotationScope.global] 的全局批注（本科目任意小节都生效）。
  static List<UserAnnotation> annotationsForSection(
    String subject,
    String chapterNumber,
    String sectionNumber,
  ) {
    final result = <UserAnnotation>[];
    for (final a in _all) {
      if (a.subject != subject) continue;
      if (a.scope == AnnotationScope.global) {
        result.add(a); // 全局：本科目内任意小节都生效
      } else if (a.chapterNumber == chapterNumber &&
          a.sectionNumber == sectionNumber) {
        result.add(a); // 当前字段：仅本小节
      }
    }
    result.sort((x, y) => x.createdAt.compareTo(y.createdAt));
    return result;
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

  /// 删除指定 term 的一处批注（按章节定位，匹配 paragraphKey 前缀）。
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

  /// 删除一处批注（按完整主键定位，保留其原始 scope/章节，适用于全局批注）。
  static Future<void> removeAnnotation(UserAnnotation a) async {
    _byKey.remove(a.paragraphKey);
    _all = _byKey.values.toList();
    await _persist();
  }

  static Future<void> _persist() async {
    final prefs = await _instance;
    final jsonList = _all.map((a) => a.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  /// 全部批注（只读视图），供"我的批注"汇总页展示。
  static List<UserAnnotation> get all => List.unmodifiable(_all);

  /// 当前批注总数。
  static int get count => _all.length;

  /// 导出全部批注为 JSON 字符串（含版本与导出时间，便于将来兼容）。
  static String exportJson() => jsonEncode({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'annotations': _all.map((a) => a.toJson()).toList(),
      });

  /// 从 JSON 字符串导入批注。
  ///
  /// [merge]=true 时按主键合并（冲突以导入内容为准，不会误删本地其它批注）；
  /// [merge]=false 时先清空再整体替换。返回导入的条数。
  static Future<int> importJson(String json, {bool merge = true}) async {
    final decoded = jsonDecode(json);
    final List<dynamic> list;
    if (decoded is Map<String, dynamic> && decoded['annotations'] is List) {
      list = decoded['annotations'] as List<dynamic>;
    } else if (decoded is List) {
      list = decoded;
    } else {
      throw const FormatException('无法识别的批注备份格式');
    }
    final incoming = <UserAnnotation>[
      for (final e in list) UserAnnotation.fromJson(e as Map<String, dynamic>),
    ];
    if (!merge) {
      _all = [];
      _byKey.clear();
    }
    for (final a in incoming) {
      _byKey[a.paragraphKey] = a; // 主键冲突：导入覆盖本地
    }
    _all = _byKey.values.toList();
    await _persist();
    return incoming.length;
  }

  /// 清空全部批注（谨慎使用，通常配合导出备份）。
  static Future<void> clearAll() async {
    _all = [];
    _byKey.clear();
    await _persist();
  }
}
