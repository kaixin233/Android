import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/ai_service.dart';

/// DeepSeek 网页端登录页
///
/// 用户在 App 内打开 chat.deepseek.com 并完成登录，本页通过注入 JavaScript
/// 从页面 `localStorage` 读取 `userToken`（DeepSeek 网页端将登录令牌存于
/// 此处而非 Cookie，值为 JSON，真实 JWT 在 `.value` 字段），自动保存进
/// [AiService]，免去手动从浏览器开发者工具复制 Token 的麻烦与泄露风险。
class DeepSeekLoginPage extends StatefulWidget {
  const DeepSeekLoginPage({super.key});

  @override
  State<DeepSeekLoginPage> createState() => _DeepSeekLoginPageState();
}

class _DeepSeekLoginPageState extends State<DeepSeekLoginPage> {
  static const String _baseUrl = 'https://chat.deepseek.com';

  late final WebViewController _controller;

  bool _isLoading = true;
  double _progress = 0;
  String? _error;
  bool _detected = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() {
            _progress = progress / 100;
            _isLoading = progress < 100;
          }),
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _error = null;
          }),
          onPageFinished: (_) {
            setState(() => _isLoading = false);
            _checkToken();
          },
          onWebResourceError: (error) => setState(() => _error = error.description),
        ),
      )
      ..loadRequest(Uri.parse(_baseUrl));

    _startPolling();
  }

  /// 轻量轮询：每 3 秒检测一次 userToken 是否出现，驱动按钮可用状态。
  void _startPolling() {
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      await _checkToken();
      return mounted;
    });
  }

  Future<void> _checkToken() async {
    final token = await _readUserToken();
    if (!mounted) return;
    final has = token != null && token.isNotEmpty;
    if (has != _detected) setState(() => _detected = has);
  }

  /// 读取 userToken，按优先级尝试：
  /// 1. 页面 `localStorage`（DeepSeek 网页端实际存储位置，值为 JSON，
  ///    真实令牌在 `.value` 字段，纯 JWT 以 `eyJ` 开头）——首选；
  /// 2. 原生 Cookie 存储（部分环境可能以 Cookie 形式下发）；
  /// 3. `document.cookie`（非 HttpOnly 场景）兜底。
  Future<String?> _readUserToken() async {
    // 1) 首选：localStorage（与当前页面同源，可直接读取）
    try {
      final raw = await _controller.runJavaScriptReturningResult('''
        (function() {
          try {
            var s = localStorage.getItem('userToken');
            if (!s) return '';
            try {
              var p = JSON.parse(s);
              if (p && typeof p.value === 'string' && p.value) return p.value;
            } catch (e) {}
            return s;
          } catch (e) { return ''; }
        })()
      ''');
      final js = raw.toString();
      final token = _normalizeToken(js);
      if (token != null) return token;
    } catch (_) {
      // 页面尚未就绪或 JS 不可用，忽略后继续兜底
    }

    // 2) 兜底：原生 Cookie 存储
    const domains = <String>[_baseUrl, 'https://deepseek.com'];
    for (final domain in domains) {
      try {
        final cookies =
            await WebViewCookieManager().getCookies(domain: Uri.parse(domain));
        for (final c in cookies) {
          if (c.name.toLowerCase() == 'usertoken') return c.value;
        }
      } catch (_) {
        // 某些平台对 domain 参数要求不同，忽略后继续兜底
      }
    }

    // 3) 最后兜底：document.cookie（非 HttpOnly 场景）
    try {
      final raw =
          await _controller.runJavaScriptReturningResult('document.cookie');
      final js = raw.toString();
      if (js.isNotEmpty) {
        for (final part in js.split(';')) {
          final kv = part.trim().split('=');
          if (kv.length == 2 && kv[0].trim().toLowerCase() == 'usertoken') {
            return kv[1].trim();
          }
        }
      }
    } catch (_) {
      // document.cookie 在 HttpOnly 场景下读不到，属预期
    }
    return null;
  }

  /// 把 JS 回传结果规整成可用的 userToken。
  /// 处理三种情况：裸 JWT（`eyJ...`）、被引号包裹的字符串、以及 `'null'` 文本。
  String? _normalizeToken(String js) {
    var s = js;
    if (s.startsWith('"') && s.endsWith('"') && s.length > 1) {
      s = s.substring(1, s.length - 1);
    }
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    final token = await _readUserToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() => _capturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未检测到 userToken，请确认已在网页内完成登录')),
        );
      }
      return;
    }
    await AiService.saveWebToken(token);
    if (!mounted) return;
    setState(() => _capturing = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 DeepSeek 网页端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(value: _progress > 0 ? _progress : null)
          else
            const LinearProgressIndicator(value: 1),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.errorContainer,
              child: Column(
                children: [
                  Text('加载失败：$_error',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _error = null);
                      _controller.reload();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          SafeArea(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _detected
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 18,
                        color: _detected
                            ? Colors.green
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _detected
                              ? '已检测到登录态，可获取 Token'
                              : '请在上方网页内登录 DeepSeek 账号',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_detected && !_capturing) ? _capture : null,
                      icon: _capturing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.key_rounded),
                      label: Text(_capturing ? '获取中…' : '获取 Token 并保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
