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
/// - 发问时往真实聊天界面「填值 → Enter 发送（失败回退点按钮）→ 等回答渲染 → 读回文本」，
///   复用页面既有的鉴权与会话，避免手抄 Token。
/// - JS 通过覆盖 `window.fetch` 与 `XMLHttpRequest` 被动抓取 SSE 流（辅助），并直接读取
///   渲染后的 DOM（`.ds-markdown` 气泡）作为主要回答来源（无论前端传输层如何变化都有效），
///   把过程与结果通过 [JavascriptChannel]（名为 `DsBridge`）回传给 Dart。
///
/// 局限：依赖 DeepSeek 网页端 DOM 结构（输入框/发送按钮/回答气泡）。若官网改版导致抓取
/// 失败，JS 会自动回传 DOM 诊断信息（type:'dump'）帮助快速定位，error 文案也会指出卡点。
class WebChatBridge {
  WebChatBridge._() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
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
    _startKeepAlive();
  }

  static final WebChatBridge instance = WebChatBridge._();

  static const String _baseUrl = 'https://chat.deepseek.com';
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  late final WebViewController _controller;
  WebViewController get controller => _controller;

  /// 是否让常驻 WebView 全屏可见可交互（用于登录）。
  final ValueNotifier<bool> visible = ValueNotifier<bool>(false);

  /// 是否显示登录控制浮层。
  final ValueNotifier<bool> loginOverlay = ValueNotifier<bool>(false);

  /// 是否已登录（界面出现输入框即视为已登录）。
  final ValueNotifier<bool> loggedIn = ValueNotifier<bool>(false);

  /// 调试日志（每次 fill/enter/captured/dump 都会追加，UI 可订阅展示）。
  final ValueNotifier<List<String>> debugLog = ValueNotifier<List<String>>([]);

  bool _scriptInjected = false;
  final Map<String, Completer<String>> _pending = <String, Completer<String>>{};
  final Map<String, void Function(String)> _progress =
      <String, void Function(String)>{};
  int _seq = 0;

  /// 串行化发送链：保证一条回答回来后再发下一条，避免 DOM 抓取串台。
  Future<String>? _sendChain;

  Timer? _keepAliveTimer;

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(checkLogin());
    });
  }

  void addDebug(String msg) {
    final list = List<String>.from(debugLog.value);
    final t = DateTime.now();
    final ts =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    list.add('$ts $msg');
    if (list.length > 60) list.removeRange(0, list.length - 60);
    debugLog.value = list;
  }

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
            var ed = document.querySelector('[contenteditable="true"],[contenteditable=""]');
            var token = null;
            try { token = localStorage.getItem('userToken'); } catch (e) {}
            return !!(ta || ed || (token && token.length > 10));
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

  /// 开启一个全新的对话（点击「新聊天」按钮，找不到则导航回首页）。
  Future<void> newSession() async {
    await _ensureScript();
    await _controller.runJavaScript(r'''
      (function() {
        var btns = document.querySelectorAll('button, div.ds-button');
        for (var i = 0; i < btns.length; i++) {
          var t = (btns[i].getAttribute('aria-label') || btns[i].textContent || '').toLowerCase();
          if (t.indexOf('新聊天') !== -1 || t.indexOf('新建会话') !== -1 || t.indexOf('new chat') !== -1) {
            try { btns[i].click(); } catch (e) {}
            return;
          }
        }
        try { window.location.href = 'https://chat.deepseek.com'; } catch (e) {}
      })()
    ''');
    addDebug('newSession requested');
  }

  /// 发问：把 [prompt] 作为一条消息发到 DeepSeek 网页端，返回回答文本。
  ///
  /// [onProgress] 会在回答逐字生成时回调当前已渲染文本（流式回显用）。
  /// 要求在已登录会话上调用；若未登录会尝试重载恢复，仍失败则抛 [WebChatException]。
  /// 多次调用会自动串行化，避免并发串台。
  Future<String> sendPrompt(
    String prompt, {
    void Function(String partial)? onProgress,
  }) async {
    await _ensureScript();
    final id = '${++_seq}';
    final completer = Completer<String>();
    _pending[id] = completer;
    if (onProgress != null) _progress[id] = onProgress;

    // 发送前确保登录态有效（掉线则尝试重载恢复）
    try {
      await _ensureLoggedIn();
    } catch (e) {
      _pending.remove(id);
      _progress.remove(id);
      final msg = e is WebChatException
          ? e.message
          : '未检测到 DeepSeek 网页端登录会话，请先在「AI 助手设置」中登录';
      throw WebChatException(msg);
    }

    final job = () async {
      try {
        await _ensureScript(); // 重连 reload 后脚本可能被重置，发前再确保注入
        await _controller.runJavaScript(
          'window.__dsSend(${jsonEncode(prompt)}, "$id");',
        );
      } catch (e) {
        _pending.remove(id);
        _progress.remove(id);
        if (!completer.isCompleted) {
          completer.completeError(WebChatException('注入脚本失败：$e'));
        }
      }
      return completer.future;
    };

    // 串行进发送链：上一条完成（或其错误被吞掉）后才发下一条
    final prev = _sendChain ?? Future<String>.value('');
    _sendChain = prev
        .then((_) => job())
        .then((f) => f)
        .catchError((e, s) => Future<String>.value(''));

    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        _pending.remove(id);
        _progress.remove(id);
        // 必须同时结束底层 completer，否则发送链 _sendChain 永久挂起、后续提问卡死
        if (!completer.isCompleted) {
          completer.completeError(
              const WebChatException('回答等待超时（120s），请重试'));
        }
        throw const WebChatException('回答等待超时（120s），请重试');
      },
    );
  }

  Future<void> _ensureScript() async {
    if (!_scriptInjected) {
      await _controller.runJavaScript(kBridgeScript);
      _scriptInjected = true;
    }
  }

  /// 若当前未登录，尝试重载页面恢复网页端会话；仍失败则抛错。
  Future<void> _ensureLoggedIn() async {
    if (await checkLogin()) return;
    try {
      _scriptInjected = false;
      await _controller.reload();
    } catch (_) {
      // 忽略重载异常，继续等待
    }
    await Future.delayed(const Duration(seconds: 2));
    await _ensureScript();
    if (await checkLogin()) return;
    throw const WebChatException(
        '未检测到 DeepSeek 网页端登录会话，请先在「AI 助手设置」中登录');
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
    if (type == 'log') {
      addDebug(text);
      return;
    }
    if (type == 'dump') {
      addDebug('DOM-DUMP: $text');
      return;
    }
    if (type == 'progress') {
      if (id != null) {
        final cb = _progress[id];
        if (cb != null) cb(text);
      }
      return;
    }
    if (id == null) return;
    final completer = _pending[id];
    if (completer == null) return;
    if (type == 'answer') {
      _pending.remove(id);
      _progress.remove(id);
      if (!completer.isCompleted) completer.complete(text);
    } else if (type == 'error') {
      _pending.remove(id);
      _progress.remove(id);
      if (!completer.isCompleted) completer.completeError(WebChatException(text));
    }
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
///    `/api/v0/chat/completion` 的 SSE 流（辅助，文本最干净）。
/// 2. 直接读取渲染后的 DOM（最后一个 `.ds-markdown` 气泡）作为主要回答来源——
///    无论前端用 fetch/XHR/EventSource，最终答案都会渲染进 DOM，因此最稳。
/// 3. `window.__dsSend(prompt, id)`：定位输入框 → 用 React 原生 setter 填值并派发
///    input 事件 → Enter 键发送（300ms 后；若未发送则回退点 `div.ds-button`）→
///    轮询等待回答稳定 → 通过 DsBridge 回传（progress 流式 + answer 终值）。
///
/// 不使用 JS 模板字符串（避免与 Dart 字符串插值冲突），全部用字符串拼接。
/// 顶部 [CFG] 为可调参数集中区。
const String kBridgeScript = r'''
(function () {
  if (window.__dsBridgeReady) return;
  window.__dsBridgeReady = true;

  // ---- 可调参数（如需调整在此集中改）----
  var CFG = {
    timeout: 115000,    // 回答等待上限(ms)
    poll: 1000,         // 轮询间隔(ms)
    stableSse: 2,       // SSE 连续稳定次数（视为完成）
    stableDom: 3,       // DOM 连续稳定次数（视为完成）
    enterDelay: 300,    // 填值后等 React 刷新状态再发 Enter 的延迟
    fallbackDelay: 1000 // Enter 后检测是否已发送、未发则回退点按钮的延迟
  };

  // ---------- SSE 抓取（fetch / XHR 双覆盖，被动透传，辅助） ----------
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

  if (window.fetch) {
    var nativeFetch = window.fetch.bind(window);
    window.fetch = function (input, init) {
      var url = (typeof input === 'string') ? input : (input && input.url) || '';
      return nativeFetch(input, init).then(function (resp) {
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

  // ---------- 回退点发送按钮（点 .ds-button 及其全部后代，覆盖任意层 onClick） ----------
  function clickSend() {
    var bg = document.querySelector('.ds-button__background');
    var el = bg;
    var hit = null;
    for (var d = 0; d < 6 && el; d++) {
      if (el.classList && el.classList.contains('ds-button')) { hit = el; break; }
      el = el.parentElement;
    }
    if (!hit && bg && bg.parentElement) hit = bg.parentElement;
    if (!hit) {
      var scope = document.querySelector('textarea') ||
                  document.querySelector('[contenteditable="true"],[contenteditable=""]');
      var p = scope ? scope.parentElement : document.body;
      for (var s = 0; s < 8 && p; s++) {
        var cands = p.querySelectorAll('div.ds-button');
        for (var i = 0; i < cands.length; i++) {
          var html = (cands[i].innerHTML || '').toLowerCase();
          if (html.indexOf('arrow') !== -1 || html.indexOf('send') !== -1 || html.indexOf('up') !== -1) {
            hit = cands[i]; break;
          }
        }
        if (hit) break;
        p = p.parentElement;
      }
    }
    if (!hit) return false;
    var nodes = [hit];
    var kids = hit.querySelectorAll('*');
    for (var n = 0; n < kids.length; n++) nodes.push(kids[n]);
    for (var m = 0; m < nodes.length; m++) { try { nodes[m].click(); } catch (e) {} }
    return true;
  }

  // ---------- 页面诊断（抓取失败时回传，便于改版定位） ----------
  function dumpDom() {
    var info = {};
    info.textarea = document.querySelectorAll('textarea').length;
    info.editable = document.querySelectorAll('[contenteditable="true"],[contenteditable=""]').length;
    info.dsMarkdown = document.querySelectorAll('.ds-markdown').length;
    info.dsButton = document.querySelectorAll('.ds-button').length;
    var longDivs = [];
    var divs = document.querySelectorAll('div');
    for (var i = 0; i < divs.length && longDivs.length < 20; i++) {
      var t = (divs[i].innerText || '').trim();
      if (t.length > 30) {
        var cls = divs[i].className && divs[i].className.toString ? divs[i].className.toString() : '';
        longDivs.push(cls.substring(0, 60));
      }
    }
    info.longDivs = longDivs;
    var md = document.querySelectorAll('.ds-markdown');
    info.lastMd = md.length ? (md[md.length - 1].innerText || '').substring(0, 200) : '';
    return JSON.stringify(info);
  }

  // ---------- 发送并等待 ----------
  window.__dsSend = function (prompt, id) {
    window.__dsCapturing = true;
    window.__dsAnswer = null;
    post({ id: id, type: 'log', text: 'start' });

    function fail(msg) {
      window.__dsCapturing = false;
      post({ id: id, type: 'log', text: 'fail: ' + msg });
      post({ id: id, type: 'dump', text: dumpDom() });
      post({ id: id, type: 'error', text: msg });
    }

    var ta = document.querySelector('textarea');
    var editable = null;
    if (!ta) {
      editable = document.querySelector('[contenteditable="true"],[contenteditable=""]');
    }
    var inputEl = ta || editable;
    if (!inputEl) { fail('未找到输入框（textarea/contenteditable），请确认已在网页端登录'); return; }

    // 用 React 原生方式填值并派发 input 事件
    if (ta) {
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
    } else {
      try {
        editable.focus();
        editable.innerText = prompt;
        editable.dispatchEvent(new Event('input', { bubbles: true }));
        editable.dispatchEvent(new Event('input', { bubbles: true }));
      } catch (e) {
        editable.textContent = prompt;
        editable.dispatchEvent(new Event('input', { bubbles: true }));
      }
    }
    post({ id: id, type: 'log', text: 'filled' });

    // 桌面模式 + Enter 发送；若一段时间仍未发送，回退点 div.ds-button
    setTimeout(function () {
      try { inputEl.focus(); } catch (e) {}
      try {
        var ev = new KeyboardEvent('keydown', {
          key: 'Enter', code: 'Enter', keyCode: 13, which: 13,
          bubbles: true, cancelable: true
        });
        inputEl.dispatchEvent(ev);
        post({ id: id, type: 'log', text: 'enter-sent' });
      } catch (e) {
        try {
          inputEl.dispatchEvent(new Event('keydown', { key: 'Enter', bubbles: true }));
          post({ id: id, type: 'log', text: 'enter-sent' });
        } catch (e2) {}
      }
      setTimeout(function () {
        try {
          var cur = (inputEl.value || inputEl.innerText || '').trim();
          if (cur.length > 0 && cur.indexOf(prompt.trim()) !== -1) {
            post({ id: id, type: 'log', text: 'enter-ineffective, fallback click' });
            clickSend();
          }
        } catch (e) {}
      }, CFG.fallbackDelay);
    }, CFG.enterDelay);

    // 发送前快照：记录当前最后一条 AI 回答（用于区分本次新回答与历史消息）
    var mdBefore = document.querySelectorAll('.ds-markdown');
    var beforeCount = mdBefore.length;
    var beforeText = (mdBefore.length
        ? (mdBefore[mdBefore.length - 1].innerText || mdBefore[mdBefore.length - 1].textContent || '')
        : '').trim();

    // 轮询等待回答稳定
    var start = Date.now();
    var lastSse = '';
    var stableSse = 0;
    var lastDom = '';
    var stableDom = 0;

    // 取页面上“最后一条 AI 回答”文本（优先 .ds-markdown，桌面/移动兼容）。
    // 这是最稳的兜底：无论前端用 fetch/XHR/EventSource，最终答案都渲染进 DOM。
    function readLastAnswer() {
      var md = document.querySelectorAll('.ds-markdown');
      if (md && md.length) {
        var last = md[md.length - 1];
        var t = (last.innerText || last.textContent || '').trim();
        if (t) return t;
      }
      var copyBtns = [];
      var bs = document.querySelectorAll('button, div.ds-button');
      for (var k = 0; k < bs.length; k++) {
        var bt = (bs[k].getAttribute('aria-label') || bs[k].textContent || '').toLowerCase();
        if (bt.indexOf('复制') !== -1 || bt.indexOf('copy') !== -1) copyBtns.push(bs[k]);
      }
      if (copyBtns.length) {
        var el = copyBtns[copyBtns.length - 1];
        for (var p = 0; p < 6 && el; p++) el = el.parentElement;
        if (el) {
          var txt = (el.innerText || el.textContent || '').replace(/复制/g, '').trim();
          if (txt) return txt;
        }
      }
      return '';
    }

    var timer = setInterval(function () {
      // 1) SSE 抓取优先（本次请求的流，天然是新回答，文本最干净）
      var cap = window.__dsAnswer || '';
      if (cap && cap === lastSse) stableSse++; else { stableSse = 0; lastSse = cap; }
      if (cap && stableSse >= CFG.stableSse) {
        clearInterval(timer);
        window.__dsCapturing = false;
        post({ id: id, type: 'answer', text: cap });
        return;
      }

      // 2) DOM 抓取兜底：必须“比发送前新增/变化”才视为本次新回答，避免误返回历史消息
      var dom = readLastAnswer();
      var mdNow = document.querySelectorAll('.ds-markdown').length;
      var isNew = dom && (mdNow > beforeCount || dom !== beforeText);
      if (isNew) {
        if (dom !== lastDom) {
          lastDom = dom;
          stableDom = 0;
          post({ id: id, type: 'progress', text: dom }); // 流式回传当前已生成文本
        } else {
          stableDom++;
        }
        if (stableDom >= CFG.stableDom) {
          clearInterval(timer);
          window.__dsCapturing = false;
          post({ id: id, type: 'answer', text: dom });
          return;
        }
      }

      if (Date.now() - start > CFG.timeout) {
        clearInterval(timer);
        window.__dsCapturing = false;
        fail('未能读取到回答（可能页面结构变化或生成超时）');
      }
    }, CFG.poll);
  };
})();
''';
