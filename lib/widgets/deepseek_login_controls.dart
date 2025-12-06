import 'package:flutter/material.dart';

import '../services/web_chat_bridge.dart';

/// 登录控制浮层
///
/// 不持有 WebView 本身（复用 [WebChatBridge] 的常驻 WebView），只负责在登录态
/// 下叠加状态提示与操作按钮。由 [WebChatBridge.beginLogin] 置 `loginOverlay=true`
/// 触发显示，[WebChatBridge.endLogin] 关闭。
class DeepSeekLoginControls extends StatefulWidget {
  const DeepSeekLoginControls({super.key});

  @override
  State<DeepSeekLoginControls> createState() => _DeepSeekLoginControlsState();
}

class _DeepSeekLoginControlsState extends State<DeepSeekLoginControls> {
  @override
  void initState() {
    super.initState();
    // 登录浮层打开后周期性检测登录态，驱动按钮可用状态。
    WebChatBridge.instance.checkLogin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Stack(
        children: [
          // 顶部提示条
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.92),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '在下方网页内登录 DeepSeek 账号，登录后点“完成”',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: '刷新页面',
                    onPressed: () =>
                        WebChatBridge.instance.controller.reload(),
                  ),
                ],
              ),
            ),
          ),
          // 底部状态 + 完成
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: WebChatBridge.instance.loggedIn,
              builder: (context, loggedIn, _) => Container(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      loggedIn
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 18,
                      color: loggedIn
                          ? Colors.green
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loggedIn
                            ? '已检测到登录态'
                            : '请在网页内完成登录',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => WebChatBridge.instance.endLogin(),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('完成'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
