import 'package:flutter/material.dart';

/// 可"选中即问 AI"的文本区域
///
/// 包裹一层 [SelectionArea]，跟踪当前选中文本，并在系统选择菜单末尾
/// 追加"问 AI"入口；点击后以选中文本为参数触发 [onAskAi]。
/// 同时支持追加任意额外的自定义菜单项（如"加注释"），通过 [extraActions] 提供。
class AskAiSelectionArea extends StatefulWidget {
  const AskAiSelectionArea({
    super.key,
    required this.child,
    required this.onAskAi,
    this.extraActions = const [],
  });

  final Widget child;

  /// 参数为用户当前选中的文本
  final ValueChanged<String> onAskAi;

  /// 选择菜单中追加的自定义操作（如"加注释"）。每个 action 的 [label] 显示在
  /// 菜单中，回调参数为当前选中的文本。
  final List<SelectionAction> extraActions;

  @override
  State<AskAiSelectionArea> createState() => _AskAiSelectionAreaState();
}

/// 选择菜单中的自定义操作
class SelectionAction {
  const SelectionAction({required this.label, required this.onSelected});

  final String label;
  final ValueChanged<String> onSelected;
}

class _AskAiSelectionAreaState extends State<AskAiSelectionArea> {
  String _selectedText = '';

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (content) {
        _selectedText = content?.plainText.trim() ?? '';
      },
      contextMenuBuilder: (context, selectableRegionState) {
        final items = <ContextMenuButtonItem>[
          ...selectableRegionState.contextMenuButtonItems,
          if (_selectedText.isNotEmpty)
            ContextMenuButtonItem(
              label: '问 AI',
              onPressed: () {
                final text = _selectedText;
                selectableRegionState.hideToolbar();
                if (text.isNotEmpty) widget.onAskAi(text);
              },
            ),
          for (final action in widget.extraActions)
            if (_selectedText.isNotEmpty)
              ContextMenuButtonItem(
                label: action.label,
                onPressed: () {
                  final text = _selectedText;
                  selectableRegionState.hideToolbar();
                  if (text.isNotEmpty) action.onSelected(text);
                },
              ),
        ];
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: items,
        );
      },
      child: widget.child,
    );
  }
}
