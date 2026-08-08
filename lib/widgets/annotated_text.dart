import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/annotation_store.dart';
import '../services/knowledge_service.dart';
import 'annotation_bubble.dart';

/// 可标注文本渲染组件。
///
/// 把一段 [KnowledgeParagraph] 渲染为"普通文本 + 高亮字段"的组合：
/// - 预置注释来自 [KnowledgeParagraph.segments]（Markdown 中 `[[术语|解释]]`）；
/// - 用户批注来自 [AnnotationStore]（运行时选中添加），按 term 合并到同一字段；
/// 点击任意高亮字段，在其上方/下方弹出 [AnnotationBubble]。
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

  /// 计算当前段落"合并后的片段"：预置 segments 展开为 普通/注释 片段，
  /// 再把用户批注按 term 合并进对应注释片段（note 追加展示）；无法匹配预置
  /// 字段的用户批注，若本段纯文本包含该 term，则独立高亮到本段。
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

    // 用户批注：在本段文本中查找术语出现的位置（可多处），就地高亮
    for (final u in userAnnotations) {
      if (u.term.isEmpty) continue;
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
    // 高亮字段在屏幕中的位置（用全局坐标，Overlay 同坐标系）
    final global = box.localToGlobal(Offset.zero);
    final rect = Rect.fromLTWH(
      global.dx,
      global.dy,
      box.size.width,
      box.size.height,
    );
    AnnotationBubble.show(
      context: context,
      term: seg.text,
      note: seg.annotation ?? '',
      anchorRect: rect,
      kind: seg.kind,
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

  Future<void> _editUserAnnotation(BuildContext context, String term) async {
    final existing =
        userAnnotations.where((a) => a.term == term);
    final initial = existing.isNotEmpty ? existing.first.note : '';
    final updated = await showNoteDialog(context, term, initial);
    if (updated == null) return;
    await _upsertUserAnnotation(term, updated);
    onAnnotationsChanged?.call();
  }

  Future<void> _deleteUserAnnotation(String term) async {
    await AnnotationStore.remove(
      subject.name,
      chapterNumber,
      section.number,
      -1,
      term,
    );
    onAnnotationsChanged?.call();
  }

  /// 新增/更新一处用户批注（整节级：paragraphIndex = -1）。
  Future<void> _upsertUserAnnotation(String term, String note) async {
    await AnnotationStore.upsert(UserAnnotation(
      subject: subject.name,
      chapterNumber: chapterNumber,
      sectionNumber: section.number,
      paragraphIndex: -1,
      term: term,
      note: note,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// 弹出输入框让用户填写批注（null 表示取消）。公开静态以便页面复用。
  static Future<String?> showNoteDialog(
    BuildContext context,
    String term,
    String initial,
  ) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final segs = _mergeSegments();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (final seg in segs)
          if (seg.annotation == null)
            Text(
              seg.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            )
          else
            _buildHighlight(context, seg, isDark),
      ],
    );
  }

  Widget _buildHighlight(
    BuildContext context,
    _MergedSegment seg,
    bool isDark,
  ) {
    final accent = seg.kind == AnnotationKind.preset
        ? (isDark ? Colors.blue.shade200 : Colors.blue.shade700)
        : (isDark ? Colors.orange.shade300 : Colors.orange.shade700);
    return InkWell(
      onTap: () => _onTapField(context, seg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        margin: const EdgeInsets.symmetric(horizontal: 0.5),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
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
