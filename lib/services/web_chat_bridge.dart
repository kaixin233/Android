import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 常驻网页端桥接器（方案 B：WebView 常驻 + 驱动真实界面）
///
/// 设计要点：
/// - 全局只有一个 [WebViewController]，挂载在 App 根（隐藏保活）。登录态、
///   会话 Cookie 全部由这个真实浏览器会话保管，App 后台**不再**直接发 HTTP 请求，
///   因此天然绕过 DeepSeek 网页端的 PoW 算力验证与会话 Cookie 校验。
/// - 发问时往真实聊天界面「填值 → 点击发送 → 等回答渲染 → 读回文本」，
///   复用页面既有的鉴权与会话，避免手抄 Token。
/// - JS 通过覆盖 `window.fetch` 与 `XMLHttpRequest` 被动抓取 SSE 流（两种传输都覆盖），
///   并把回答通过 [JavascriptChannel]（名为 `DsBridge`）回传给 Dart。
///
/// 局限：依赖 DeepSeek 网页端 DOM 结构（输入框/发送按钮/回答气泡）。若官网改版，
/// 可能需要调整 [kBridgeScript] 中的选择器；失败时回传的 error 文案会指出卡在哪一步。
class WebChatBridge {
  WebChatBridge._() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'DsBridge',
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _scriptInjected = false; // 新页面需重新注入
            unawaited(checkLogin());
          },
        ),
      )
      ..loadRequest(Uri.parse(_baseUrl));
  }

  static final WebChatBridge instance = WebChatBridge._();

  static const String _baseUrl = 'https://chat.deepseek.com';

  late final WebViewController _controller;
  WebViewController get controller => _controller;

  /// 是否让常驻 WebView 全屏可见可交互（用于登录）。
  final ValueNotifier<bool> visible = ValueNotifier<bool>(false);

  /// 是否显示登录控制浮层。
  final ValueNotifier<bool> loginOverlay = ValueNotifier<bool>(false);

  /// 是否已登录（界面出现输入框即视为已登录）。
  final ValueNotifier<bool> loggedIn = ValueNotifier<bool>(false);

  bool _scriptInjected = false;
  final Map<String, Completer<String>> _pending = <String, Completer<String>>{};
  int _seq = 0;

  /// 让常驻 WebView 全屏显示并打开登录控制浮层。
  void beginLogin(BuildContext context) {
    visible.value = true;
    loginOverlay.value = true;
    unawaited(checkLogin());
  }

  /// 结束登录浮层，把 WebView 重新隐藏保活。
  void endLogin() {
    loginOverlay.value = false;
    visible.value = false;
    unawaited(checkLogin());
  }

  /// 检测当前 WebView 是否为已登录态（存在聊天输入框）。
  Future<bool> checkLogin() async {
    try {
      final res = await _controller.runJavaScriptReturningResult(r'''
        (function() {
          try {
            var ta = document.querySelector('textarea');
            var token = null;
            try { token = localStorage.getItem('userToken'); } catch (e) {}
            return !!(ta || (token && token.length > 10));
          } catch (e) { return false; }
        })()
      ''');
      final ok = res == true ||
          res.toString().trim() == 'true' ||
          res.toString().trim() == '1';
      loggedIn.value = ok;
      return ok;
    } catch (_) {
      loggedIn.value = false;
      return false;
    }
  }

  /// 发问：把 [prompt] 作为一条消息发到 DeepSeek 网页端，返回回答文本。
  /// 要求在已登录会话上调用（先 [checkLogin] 或 [beginLogin]）。
  Future<String> sendPrompt(String prompt) async {
    await _ensureScript();
    final id = '${++_seq}';
    final completer = Completer<String>();
    _pending[id] = completer;
    // 通过通道回传的 Promise 由 JS 主动 postMessage 驱动，这里发起即可。
    await _controller.runJavaScript(
      'window.__dsSend(${jsonEncode(prompt)}, "$id");',
    );
    try {
      return await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          _pending.remove(id);
          throw const WebChatException('回答等待超时（120s），请重试');
        },
      );
    } on WebChatException {
      rethrow;
    } catch (e) {
      _pending.remove(id);
      throw WebChatException('网页端调用失败：$e');
    }
  }

  Future<void> _ensureScript() async {
    if (!_scriptInjected) {
      await _controller.runJavaScript(kBridgeScript);
      _scriptInjected = true;
    }
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    late Map<String, dynamic> data;
    try {
      data = jsonDecode(message.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = data['id'] as String?;
    final type = data['type'] as String?;
    final text = data['text'] as String? ?? '';
    if (type == 'login') {
      loggedIn.value = text == '1';
      return;
    }
    if (id == null) return;
    final completer = _pending[id];
    if (completer == null) return;
    if (type == 'answer') {
      _pending.remove(id);
      if (!completer.isCompleted) completer.complete(text);
    } else if (type == 'error') {
      _pending.remove(id);
      if (!completer.isCompleted) completer.completeError(WebChatException(text));
    }
    // type == 'log' 仅用于调试，可在此打印
  }
}

/// 网页端桥接异常，[message] 可直接展示给用户。
class WebChatException implements Exception {
  const WebChatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 注入页面的桥接脚本。
///
/// 职责：
/// 1. 覆盖 `window.fetch` 与 `XMLHttpRequest`（被动透传），抓取
///    `/api/v0/chat/completion` 的 SSE 流，把逐字增量拼到 `window.__dsAnswer`。
/// 2. `window.__dsSend(prompt, id)`：定位 textarea → 用 React 原生 setter 填值并派发
///    input 事件 → 定位发送按钮并点击 → 轮询等待回答稳定 → 通过 DsBridge 回传。
///
/// 不使用 JS 模板字符串（避免与 Dart 字符串插值冲突），全部用字符串拼接。
const String kBridgeScript = r'''
(function () {
  if (window.__dsBridgeReady) return;
  window.__dsBridgeReady = true;

  // ---------- SSE 抓取（fetch / XHR 双覆盖，被动透传） ----------
  window.__dsCapturing = false;
  window.__dsAnswer = null;

  function parseSse(text) {
    var ans = '';
    var lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = (lines[i] || '').trim();
      if (line.indexOf('data:') !== 0) continue;
      var d = line.slice(5).trim();
      if (d === '[DONE]' || d === '') continue;
      try {
        var j = JSON.parse(d);
        var c = j && j.choices && j.choices[0] && j.choices[0].delta && j.choices[0].delta.content;
        if (c) ans += c;
      } catch (e) {}
    }
    return ans;
  }

  var isCompletion = function (u) {
    return (u || '').indexOf('/api/v0/chat/completion') !== -1;
  };

  // fetch 覆盖
  var origFetch = window.fetch ? window.fetch.bind(window) : null;
  if (origFetch) {
    window.fetch = function (input, init) {
      var url = (typeof input === 'string') ? input : (input && input.url) || '';
      return origFetch(input, init).then(function (resp) {
        if (window.__dsCapturing && isCompletion(url)) {
          try {
            var clone = resp.clone();
            clone.text().then(function (full) {
              var a = parseSse(full);
              if (a) window.__dsAnswer = a;
            }).catch(function () {});
          } catch (e) {}
        }
        return resp;
      });
    };
  }

  // XHR 覆盖
  var OrigXhr = window.XMLHttpRequest;
  if (OrigXhr) {
    var origOpen = OrigXhr.prototype.open;
    var origSend = OrigXhr.prototype.send;
    OrigXhr.prototype.open = function (method, url) {
      this.__dsUrl = url || '';
      return origOpen.apply(this, arguments);
    };
    OrigXhr.prototype.send = function (body) {
      var self = this;
      if (window.__dsCapturing && isCompletion(self.__dsUrl)) {
        this.addEventListener('readystatechange', function () {
          if (self.readyState === 4) {
            try {
              var a = parseSse(self.responseText || '');
              if (a) window.__dsAnswer = a;
            } catch (e) {}
          }
        });
      }
      return origSend.apply(this, arguments);
    };
  }

  // ---------- 回传 ----------
  function post(obj) {
    try { window.DsBridge.postMessage(JSON.stringify(obj)); } catch (e) {}
  }

  // ---------- 发送并等待 ----------
  window.__dsSend = function (prompt, id) {
    window.__dsCapturing = true;
    window.__dsAnswer = null;
    post({ id: id, type: 'log', text: 'start' });

    function fail(msg) {
      window.__dsCapturing = false;
      post({ id: id, type: 'error', text: msg });
    }

    var ta = document.querySelector('textarea');
    if (!ta) { fail('未找到输入框（textarea），请确认已在网页端登录'); return; }

    // 用 React 原生 setter 填值并派发 input 事件
    try {
      var proto = Object.getPrototypeOf(ta);
      var setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
      setter.call(ta, prompt);
      ta.dispatchEvent(new Event('input', { bubbles: true }));
      ta.dispatchEvent(new Event('change', { bubbles: true }));
    } catch (e) {
      ta.value = prompt;
      ta.dispatchEvent(new Event('input', { bubbles: true }));
    }
    post({ id: id, type: 'log', text: 'filled' });

    // 定位发送按钮：在输入框所在容器内自底向上找启用且有“发送/箭头”语义的 button
    function findSend() {
      var parent = ta.parentElement;
      for (var depth = 0; depth < 8 && parent; depth++) {
        var btns = parent.querySelectorAll('button');
        for (var i = 0; i < btns.length; i++) {
          var b = btns[i];
          if (b.disabled) continue;
          var html = (b.innerHTML || '').toLowerCase();
          var label = (b.getAttribute('aria-label') || b.textContent || '').toLowerCase();
          if (label.indexOf('发送') !== -1 || label.indexOf('send') !== -1) return b;
          if (html.indexOf('svg') !== -1 && (html.indexOf('arrow') !== -1 || html.indexOf('up') !== -1 || html.indexOf('paper-plane') !== -1 || html.indexOf('send') !== -1)) return b;
        }
        parent = parent.parentElement;
      }
      // 兜底：页面内任意“发送”语义按钮
      var all = document.querySelectorAll('button');
      for (var j = 0; j < all.length; j++) {
        if (all[j].disabled) continue;
        var l = (all[j].getAttribute('aria-label') || all[j].textContent || '').toLowerCase();
        if (l.indexOf('发送') !== -1 || l.indexOf('send') !== -1) return all[j];
      }
      return null;
    }

    var sendBtn = findSend();
    if (!sendBtn) { fail('未找到发送按钮'); return; }
    sendBtn.click();
    post({ id: id, type: 'log', text: 'clicked' });

    // 轮询等待回答稳定
    var start = Date.now();
    var lastCaptured = '';
    var lastScraped = '';
    var stableCaptured = 0;
    var stableScraped = 0;

    function scrape() {
      // 优先：找到最后一个“复制”按钮，上溯到消息容器取文本
      var copyBtns = [];
      var bs = document.querySelectorAll('button');
      for (var k = 0; k < bs.length; k++) {
        var t = (bs[k].getAttribute('aria-label') || bs[k].textContent || '').toLowerCase();
        if (t.indexOf('复制') !== -1 || t.indexOf('copy') !== -1) copyBtns.push(bs[k]);
      }
      if (copyBtns.length) {
        var el = copyBtns[copyBtns.length - 1];
        for (var p = 0; p < 6 && el; p++) el = el.parentElement;
        if (el) {
          var txt = (el.innerText || el.textContent || '').replace(/复制/g, '').trim();
          return txt;
        }
      }
      return '';
    }

    var timer = setInterval(function () {
      var cap = window.__dsAnswer || '';
      if (cap && cap === lastCaptured) stableCaptured++; else { stableCaptured = 0; lastCaptured = cap; }
      if (cap && stableCaptured >= 2) {
        clearInterval(timer);
        window.__dsCapturing = false;
        post({ id: id, type: 'answer', text: cap });
        return;
      }

      var scr = scrape();
      if (scr && scr === lastScraped) stableScraped++; else { stableScraped = 0; lastScraped = scr; }
      if (scr && stableScraped >= 3) {
        clearInterval(timer);
        window.__dsCapturing = false;
        post({ id: id, type: 'answer', text: scr });
        return;
      }

      if (Date.now() - start > 115000) {
        clearInterval(timer);
        window.__dsCapturing = false;
        fail('未能读取到回答（可能页面结构变化或生成超时）');
      }
    }, 1000);
  };
})();
''';
