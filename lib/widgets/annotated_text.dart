import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/annotation_store.dart';
import '../services/knowledge_service.dart';
import 'annotation_bubble.dart';

/// 可标注文本渲染组件。
///
/// 把一段 [KnowledgeParagraph] 渲染为"普通文本 + 内联高亮字段"的组合：
/// - 预置注释来自 [KnowledgeParagraph.segments]（Markdown 中 `[[术语|解释]]`）；
/// - 用户批注来自 [AnnotationStore]（运行时选中添加），按 term 合并到同一字段；
/// 点击任意高亮字段，在其上方/下方弹出 [AnnotationBubble]。
///
/// 关键：整段用**单个 `Text.rich`** 渲染，高亮字段以 `WidgetSpan` 内联嵌入，
/// 因此文本保持连续换行流，不会因高亮而把段落拆成独立盒子、破坏排版结构。
class AnnotatedText extends StatelessWidget {
  const AnnotatedText({
    super.key,
    required this.paragraph,
    required this.subject,
    required this.chapterNumber,
    required this.section,
    required this.userAnnotations,
    this.color = Colors.blue,
    this.onAskAi,
    this.onAnnotationsChanged,
  });

  final KnowledgeParagraph paragraph;
  final QuestionSubject subject;
  final String chapterNumber;
  final KnowledgeSection section;

  /// 该小节全部用户批注（跨段落），由父级传入。渲染时按 term 在本段文本中
  /// 匹配高亮，无需精确知道段落索引。
  final List<UserAnnotation> userAnnotations;
  final Color color;

  /// 点击"问 AI 解释"时回调，参数为 `术语：注释`
  final ValueChanged<String>? onAskAi;

  /// 用户批注增删后回调（用于父级刷新相关状态）
  final VoidCallback? onAnnotationsChanged;

  /// 计算当前段落"合并后的片段"：把预置注释（来自 [KnowledgeParagraph.segments]）
  /// 与用户批注（运行时选中添加）都按其在正文中的实际位置高亮，而非追加到段尾。
  ///
  /// - 预置片段：segments 的文本顺序拼接即为段落干净文本，因此可用累加偏移精确定位；
  /// - 用户批注：在段落文本中查找术语出现的位置（可多处），就地高亮；
  /// - 若用户批注与某预置术语重合，合并两者 note（展示为橙色"我的批注"）。
  List<_MergedSegment> _mergeSegments() {
    final text = paragraph.text;
    if (text.isEmpty) return const [];

    // 1) 收集所有"标记区间"（按在文本中的起止位置）
    final marks = <_Mark>[];

    // 预置注释：用 segments 累加偏移定位
    final segs = paragraph.segments;
    if (segs != null) {
      var offset = 0;
      for (final s in segs) {
        if (s.annotation != null) {
          marks.add(_Mark(
            start: offset,
            end: offset + s.text.length,
            term: s.text,
            note: s.annotation!,
            kind: AnnotationKind.preset,
          ));
        }
        offset += s.text.length;
      }
    }

    // 用户批注：先按 term 去重（同一术语可能同时有"当前字段"与"全局"批注），
    // 优先保留"当前字段"，同范围则保留最新；再在本段文本中查找术语位置就地高亮。
    final userByTerm = <String, UserAnnotation>{};
    for (final u in userAnnotations) {
      if (u.term.isEmpty) continue;
      final prev = userByTerm[u.term];
      if (prev == null) {
        userByTerm[u.term] = u;
      } else if (prev.scope != u.scope) {
        // 更具体的"当前字段"优先于"全局"
        if (prev.scope != AnnotationScope.field) userByTerm[u.term] = u;
      } else if (u.createdAt > prev.createdAt) {
        userByTerm[u.term] = u;
      }
    }
    for (final u in userByTerm.values) {
      var idx = text.indexOf(u.term);
      while (idx != -1) {
        marks.add(_Mark(
          start: idx,
          end: idx + u.term.length,
          term: u.term,
          note: u.note,
          kind: AnnotationKind.user,
        ));
        idx = text.indexOf(u.term, idx + u.term.length);
      }
    }

    // 2) 处理重叠：按起始排序，重叠时优先保留先放置的；若预置与用户术语相同，
    //    则合并 note（保留预置解释，追加用户批注），并以"用户"类型展示。
    marks.sort((a, b) => a.start.compareTo(b.start));
    final placed = <_Mark>[];
    for (final m in marks) {
      final last = placed.isEmpty ? null : placed.last;
      if (last != null && m.start < last.end) {
        if (last.term == m.term) {
          final presetNote =
              last.kind == AnnotationKind.preset ? last.note : m.note;
          final userNote =
              last.kind == AnnotationKind.user ? last.note : m.note;
          placed[placed.length - 1] = _Mark(
            start: last.start,
            end: last.end,
            term: last.term,
            note: userNote.isEmpty
                ? presetNote
                : '$presetNote\n\n— 我的批注 —\n$userNote',
            kind: AnnotationKind.user,
          );
        }
        // 术语不同的重叠（如用户批注落在预置长术语内部）：保留先放置者，忽略后者
        continue;
      }
      placed.add(m);
    }

    // 3) 按位置切出"普通文本 + 高亮片段"
    final result = <_MergedSegment>[];
    var pos = 0;
    for (final m in placed) {
      if (m.start > pos) {
        result.add(_MergedSegment(text: text.substring(pos, m.start)));
      }
      result.add(_MergedSegment(
        text: m.term,
        annotation: m.note,
        kind: m.kind,
      ));
      pos = m.end;
    }
    if (pos < text.length) {
      result.add(_MergedSegment(text: text.substring(pos)));
    }
    return result;
  }

  void _onTapField(BuildContext context, _MergedSegment seg) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    // 高亮词在屏幕中的位置（用全局坐标，Overlay 同坐标系）
    final global = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      global.dx,
      global.dy,
      box.size.width,
      box.size.height,
    );
    final ann = seg.kind == AnnotationKind.user ? _findUserAnnotation(seg.text) : null;
    AnnotationBubble.show(
      context: context,
      term: seg.text,
      note: seg.annotation ?? '',
      anchorRect: rect,
      kind: seg.kind,
      scope: ann?.scope,
      onAskAi: onAskAi == null
          ? null
          : () => onAskAi!('${seg.text}：${seg.annotation ?? ''}'),
      onEdit: seg.kind == AnnotationKind.user
          ? () => _editUserAnnotation(context, seg.text)
          : null,
      onDelete: seg.kind == AnnotationKind.user
          ? () => _deleteUserAnnotation(seg.text)
          : null,
    );
  }

  /// 在当前小节批注列表中定位某术语对应的批注对象（保留原始 scope/章节）。
  /// 优先"当前字段"，同范围取最新。
  UserAnnotation? _findUserAnnotation(String term) {
    UserAnnotation? best;
    for (final a in userAnnotations) {
      if (a.term != term) continue;
      if (best == null) {
        best = a;
      } else if (best.scope != a.scope) {
        if (best.scope != AnnotationScope.field) best = a;
      } else if (a.createdAt > best.createdAt) {
        best = a;
      }
    }
    return best;
  }

  Future<void> _editUserAnnotation(BuildContext context, String term) async {
    final existing = _findUserAnnotation(term);
    if (existing == null) return;
    final result =
        await showNoteDialog(context, term, existing.note, initialScope: existing.scope);
    if (result == null) return;
    // 沿用原批注对象（保留主键与 scope），仅更新内容与范围
    await AnnotationStore.upsert(
      existing.copyWith(note: result.note, scope: result.scope),
    );
    onAnnotationsChanged?.call();
  }

  Future<void> _deleteUserAnnotation(String term) async {
    final target = _findUserAnnotation(term);
    if (target == null) return;
    await AnnotationStore.removeAnnotation(target);
    onAnnotationsChanged?.call();
  }

  /// 弹出输入框让用户填写批注，并选择生效范围。
  /// 返回 [AnnotationResult]（note + scope）；取消时返回 null。公开静态以便页面复用。
  static Future<AnnotationResult?> showNoteDialog(
    BuildContext context,
    String term,
    String initial, {
    AnnotationScope initialScope = AnnotationScope.field,
  }) async {
    final controller = TextEditingController(text: initial);
    var scope = initialScope;
    return showDialog<AnnotationResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(initial.isEmpty ? '添加批注' : '编辑批注'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '标注内容：$term',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '写下你的理解、解释或备注…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('生效范围', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              SegmentedButton<AnnotationScope>(
                selected: {scope},
                onSelectionChanged: (s) => setState(() => scope = s.first),
                segments: const [
                  ButtonSegment(
                    value: AnnotationScope.field,
                    label: Text('当前字段'),
                  ),
                  ButtonSegment(
                    value: AnnotationScope.global,
                    label: Text('全局'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                scope == AnnotationScope.global
                    ? '全局：本科目内所有同名术语都会显示此批注'
                    : '当前字段：仅在本小节内显示此批注',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(
                AnnotationResult(controller.text.trim(), scope),
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final segs = _mergeSegments();

    final baseStyle = TextStyle(
      fontSize: 14,
      height: 1.7,
      color: isDark ? Colors.white70 : Colors.black87,
    );

    final spans = <InlineSpan>[];
    for (final seg in segs) {
      if (seg.annotation == null) {
        spans.add(TextSpan(text: seg.text, style: baseStyle));
        continue;
      }
      final accent = seg.kind == AnnotationKind.preset
          ? (isDark ? Colors.blue.shade200 : Colors.blue.shade700)
          : (isDark ? Colors.orange.shade300 : Colors.orange.shade700);
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => _onTapField(ctx, seg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border(
                  bottom: BorderSide(color: accent, width: 1.4),
                ),
              ),
              child: Text(
                seg.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ));
    }

    // 用单个 Text.rich 渲染：普通文本连续成段、正常换行；高亮以 WidgetSpan 内联，
    // 不会像 Wrap 那样把段落拆成独立盒子而破坏排版结构。
    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: TextAlign.start,
    );
  }
}

/// 标记区间：文本中 [start, end) 范围内的高亮片段及其注释
class _Mark {
  final int start;
  final int end;
  final String term;
  final String note;
  final AnnotationKind kind;

  const _Mark({
    required this.start,
    required this.end,
    required this.term,
    required this.note,
    required this.kind,
  });
}

/// 合并后的渲染片段
class _MergedSegment {
  final String text;
  final String? annotation;
  final AnnotationKind kind;

  const _MergedSegment({
    required this.text,
    this.annotation,
    this.kind = AnnotationKind.preset,
  });
}
