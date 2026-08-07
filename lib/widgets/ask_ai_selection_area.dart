import 'package:flutter/material.dart';

/// 可"选中即问 AI"的文本区域
///
/// 包裹一层 [SelectionArea]，跟踪当前选中文本，并在系统选择菜单末尾
/// 追加"问 AI"入口；点击后以选中文本为参数触发 [onAskAi]。
class AskAiSelectionArea extends StatefulWidget {
  const AskAiSelectionArea({
    super.key,
    required this.child,
    required this.onAskAi,
  });

  final Widget child;

  /// 参数为用户当前选中的文本
  final ValueChanged<String> onAskAi;

  @override
  State<AskAiSelectionArea> createState() => _AskAiSelectionAreaState();
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
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: selectableRegionState.contextMenuAnchors,
          buttonItems: [
            ...selectableRegionState.contextMenuButtonItems,
            ContextMenuButtonItem(
              label: '问 AI',
              onPressed: () {
                final text = _selectedText;
                selectableRegionState.hideToolbar();
                if (text.isNotEmpty) {
                  widget.onAskAi(text);
                }
              },
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
