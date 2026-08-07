import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// App 内置 DeepSeek 网页端
///
/// 未配置 API Key 时的降级提问入口：在 App 内打开 DeepSeek 网页，
/// 用户登录后粘贴已自动复制的提问内容即可提问。
class DeepseekWebPage extends StatefulWidget {
  const DeepseekWebPage({
    super.key,
    this.promptText,
    this.initialUrl,
    this.pageTitle = 'DeepSeek 网页端',
  });

  /// 需要用户粘贴的提问内容（进入页面时已自动复制到剪贴板）
  final String? promptText;

  /// 自定义起始 URL，默认为 DeepSeek 对话页
  final String? initialUrl;

  final String pageTitle;

  static const String defaultUrl = 'https://chat.deepseek.com/';

  @override
  State<DeepseekWebPage> createState() => _DeepseekWebPageState();
}

class _DeepseekWebPageState extends State<DeepseekWebPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;
  String _errorMessage = '';
  bool _bannerVisible = true;

  String get _targetUrl => widget.initialUrl ?? DeepseekWebPage.defaultUrl;

  @override
  void initState() {
    super.initState();
    // 自动复制提问内容，方便用户直接粘贴
    if (widget.promptText != null && widget.promptText!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: widget.promptText!));
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _hasError = false);
        },
        onWebResourceError: (error) {
          // 仅主框架加载失败时展示错误页（忽略图片/脚本等子资源失败）
          if (error.isForMainFrame ?? false) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = '网页加载失败（${error.errorCode}），请检查网络';
              });
            }
          }
        },
      ))
      ..loadRequest(Uri.parse(_targetUrl));
  }

  Future<void> _reload() async {
    setState(() {
      _hasError = false;
      _progress = 0;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPrompt =
        widget.promptText != null && widget.promptText!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: _reload,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: '在浏览器中打开',
            onPressed: () => launchUrl(
              Uri.parse(_targetUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
        bottom: _progress < 100 && !_hasError
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: Column(
        children: [
          // 提问内容已复制提示横幅
          if (hasPrompt && _bannerVisible)
            Material(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.content_copy_rounded,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '提问内容已复制，登录后在输入框粘贴发送即可',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(
                            ClipboardData(text: widget.promptText!));
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('已重新复制'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Text('重新复制'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _bannerVisible = false),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _hasError
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            size: 64,
                            color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(_errorMessage,
                            style:
                                TextStyle(color: theme.colorScheme.outline)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('重新加载'),
                        ),
                      ],
                    ),
                  )
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
