import 'package:flutter/material.dart';

/// 标签注释气泡。
///
/// 由 [AnnotatedText] 在点击高亮字段时调用：根据高亮字段在屏幕中的位置，
/// 自动决定把气泡显示在字段**上方**还是**下方**（空间不够时翻转到另一侧），
/// 点击气泡外区域或自身关闭。可选展示"问 AI""编辑""删除"等操作。
class AnnotationBubble extends StatefulWidget {
  const AnnotationBubble({
    super.key,
    required this.term,
    required this.note,
    required this.anchorRect,
    this.kind = AnnotationKind.preset,
    this.onAskAi,
    this.onEdit,
    this.onDelete,
    this.onClose,
  });

  /// 被标注的术语（气泡标题）
  final String term;

  /// 注释内容（气泡正文）
  final String note;

  /// 触发气泡的高亮字段在屏幕坐标系（[Overlay] 的全局坐标系）中的矩形
  final Rect anchorRect;

  /// 注释类型：预置 / 用户批注（影响操作按钮与配色）
  final AnnotationKind kind;

  /// "问 AI 解释"回调（仅预置注释默认提供）
  final VoidCallback? onAskAi;

  /// 编辑回调（仅用户批注提供）
  final VoidCallback? onEdit;

  /// 删除回调（仅用户批注提供）
  final VoidCallback? onDelete;

  /// 关闭气泡的回调（点击空白区域 / 关闭按钮时调用）
  final VoidCallback? onClose;

  /// 在 [Overlay] 中显示气泡，返回关闭函数
  static Future<void> show({
    required BuildContext context,
    required String term,
    required String note,
    required Rect anchorRect,
    AnnotationKind kind = AnnotationKind.preset,
    VoidCallback? onAskAi,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => AnnotationBubble(
        term: term,
        note: note,
        anchorRect: anchorRect,
        kind: kind,
        onAskAi: onAskAi == null
            ? null
            : () {
                entry.remove();
                onAskAi();
              },
        onEdit: onEdit == null
            ? null
            : () {
                entry.remove();
                onEdit();
              },
        onDelete: onDelete == null
            ? null
            : () {
                entry.remove();
                onDelete();
              },
        onClose: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
    return Future.value();
  }

  @override
  State<AnnotationBubble> createState() => _AnnotationBubbleState();
}

class _AnnotationBubbleState extends State<AnnotationBubble> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;

    const bubbleWidth = 260.0;
    const maxBubbleHeight = 280.0;
    const vGap = 10.0;

    // 水平居中对齐高亮字段，但避免超出屏幕
    var left = widget.anchorRect.left + widget.anchorRect.width / 2 - bubbleWidth / 2;
    left = left.clamp(12.0, screenW - bubbleWidth - 12.0);

    // 优先显示在下方；空间不足（底部留白 < 气泡需要）则翻到上方
    final belowSpace = screenH - widget.anchorRect.bottom - vGap;
    final aboveSpace = widget.anchorRect.top - vGap;
    final placeBelow = belowSpace >= 120 || belowSpace >= aboveSpace;

    final top = placeBelow
        ? widget.anchorRect.bottom + vGap
        : widget.anchorRect.top - vGap - maxBubbleHeight;

    final accent = widget.kind == AnnotationKind.preset
        ? (isDark ? Colors.blue.shade200 : Colors.blue.shade700)
        : (isDark ? Colors.orange.shade200 : Colors.orange.shade700);

    return Stack(
      children: [
        // 透明全屏层：点击任意处关闭气泡（气泡本身覆盖在上方，点击气泡不会命中此处）
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: top.clamp(12.0, screenH - maxBubbleHeight - 12.0),
          width: bubbleWidth,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            color: isDark ? theme.colorScheme.surfaceContainerHigh : Colors.white,
            child: Container(
              constraints: const BoxConstraints(maxHeight: maxBubbleHeight),
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 3, right: 8),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.term,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                        // 关闭按钮
                        if (widget.onClose != null)
                          GestureDetector(
                            onTap: widget.onClose,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: theme.hintColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.note.isEmpty ? '（暂无注释内容）' : widget.note,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    if (widget.onAskAi != null ||
                        widget.onEdit != null ||
                        widget.onDelete != null)
                      const SizedBox(height: 12),
                    if (widget.onAskAi != null ||
                        widget.onEdit != null ||
                        widget.onDelete != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.onAskAi != null)
                            _ActionChip(
                              icon: Icons.auto_awesome_rounded,
                              label: '问 AI',
                              color: accent,
                              onTap: widget.onAskAi!,
                            ),
                          if (widget.onEdit != null)
                            _ActionChip(
                              icon: Icons.edit_outlined,
                              label: '编辑',
                              color: Colors.grey.shade600,
                              onTap: widget.onEdit!,
                            ),
                          if (widget.onDelete != null)
                            _ActionChip(
                              icon: Icons.delete_outline_rounded,
                              label: '删除',
                              color: Colors.red.shade400,
                              onTap: widget.onDelete!,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12.5, color: color)),
          ],
        ),
      ),
    );
  }
}

/// 注释类型
enum AnnotationKind {
  /// Markdown 源中预置的标签注释
  preset,

  /// 用户在运行时添加的批注
  user,
}
