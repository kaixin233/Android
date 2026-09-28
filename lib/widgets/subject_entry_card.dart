import 'package:flutter/material.dart';

import '../models/question.dart';

/// 统计某科目的错题数（错题 key 以科目名开头）。
///
/// 学习页与教材页都要用，放这里避免两处各写一遍。
int subjectWrongCount(Iterable<String> wrongKeys, QuestionSubject subject) =>
    wrongKeys.where((k) => k.startsWith(subject.name)).length;

/// 科目/练习入口的统一样式组件（学习页与教材页共用同一实现）。
///
/// 之所以抽出来：此前「学习页」与「教材页」各自维护了一套几乎相同的科目卡片，
/// 导致两处重复、样式与入口不一致。现在两页只提供数据，渲染统一在这里。
///
/// - [compact] = true：紧凑单行（学习页"快速开始练习"用），一屏可容纳全部科目；
/// - [compact] = false：详细卡片（教材页"大纲与考点"用），展示封面块与标签。
class SubjectEntryCard extends StatelessWidget {
  const SubjectEntryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.tags = const [],
    this.onPractice,
    this.onOutline,
    this.compact = false,
    this.practiceLabel = '练习',
    this.outlineLabel = '大纲',
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// 详情标签（仅详细模式展示），如「6章」「1200题」「13错题」
  final List<String> tags;

  /// 点击"练习"；为 null 时隐藏该按钮
  final VoidCallback? onPractice;

  /// 点击"大纲/考点"；为 null 时隐藏该按钮
  final VoidCallback? onOutline;

  /// 紧凑模式（单行）
  final bool compact;

  final String practiceLabel;
  final String outlineLabel;

  /// 是否强调（例如"继续学习"的目标科目）
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact(context) : _buildFull(context);
  }

  // ===== 紧凑单行 =====
  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark ? theme.colorScheme.surface : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPractice ?? onOutline,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: highlight ? 0.6 : 0.22),
              width: highlight ? 1.5 : 1,
            ),
            color: highlight ? color.withValues(alpha: 0.06) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              if (onOutline != null)
                IconButton(
                  onPressed: onOutline,
                  tooltip: outlineLabel,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.menu_book_rounded, size: 19, color: color),
                ),
              if (onPractice != null)
                FilledButton(
                  onPressed: onPractice,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: Text(practiceLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 详细卡片 =====
  Widget _buildFull(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOutline,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 62,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final t in tags) _buildTag(t),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onPractice != null)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onPractice,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(practiceLabel,
                              style: const TextStyle(fontSize: 13)),
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                      ),
                    if (onPractice != null && onOutline != null)
                      const SizedBox(width: 10),
                    if (onOutline != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onOutline,
                          icon: const Icon(Icons.menu_book_rounded, size: 17),
                          label: Text(outlineLabel,
                              style: const TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: color,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
