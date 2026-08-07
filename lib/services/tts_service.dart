import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 语音播报服务 - 用于朗读题目和选项
///
/// 针对小米/MIUI 设备的优化（基于实际诊断数据）：
///
/// 诊断发现：小米引擎报告可用语言为 [zh, en, zh-Hans, zh-Hant]，
/// 但 setLanguage('zh-CN') 和 setLanguage('zh-Hans') 均返回 0（失败）。
///
/// 核心修复：
/// 1. 语言设置：直接用 getLanguages() 返回的原始字符串调用 setLanguage()
/// 2. 语言设置完全非阻塞：无论成功失败都标记引擎可用
/// 3. speak() 返回 1 即视为成功，不依赖 onStart 回调
///    （小米引擎可能不触发 onStart，但实际在播放）
/// 4. 不使用 awaitSpeakCompletion(true)，避免永久挂起
class TtsService {
  TtsService._();

  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isSpeaking = false;
  static bool _isAvailable = false;

  static Future<bool>? _initFuture;

  /// 当前朗读完成回调（由 speak() 设置，由回调处理器调用）
  static VoidCallback? _onComplete;
  static Completer<bool>? _currentCompletionCompleter;

  /// 朗读代际计数器，用于防止旧的 stop() 异步清空新的 speak() 回调
  static int _speakGeneration = 0;

  /// 标记回调是否已注册，避免重复注册
  static bool _handlersRegistered = false;
  // 串行化 speak 请求，避免并发导致播放顺序混乱
  static Future<void> _lastSpeak = Future.value();

  /// 过渡标记：speak() 内部调用 stop() 时设为 true，
  /// 让完成/错误处理器忽略 stop() 触发的回调，避免新回调被提前消费
  static bool _isStoppingForRestart = false;

  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.android_app/tts_helper');

  static bool get isSpeaking => _isSpeaking;
  static bool get isAvailable => _isAvailable;

  /// 初始化 TTS 引擎
  static Future<bool> initialize() {
    if (_isAvailable) return Future.value(true);
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initializeWithRetry().then((success) {
      if (!success) {
        _initFuture = null;
      }
      return success;
    });
    return _initFuture!;
  }

  /// 带重试的初始化：冷启动时引擎绑定较慢，单次 initialize() 常失败，
  /// 这里在内部重试多次（每次带超时 + 间隔），避免调用方一次失败就放弃——
  /// 修复「考点页首次播放无效、需先去练习页播一次才能用」的问题
  /// （练习页逐段 speak 自带重试，会把引擎预热；集中到这里后所有入口都受益）。
  static Future<bool> _initializeWithRetry() async {
    const maxAttempts = 4;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      bool ok = false;
      try {
        ok = await _doInitialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('TTS: 初始化超时（5秒，第 ${attempt + 1} 次）');
            return false;
          },
        );
      } catch (e) {
        debugPrint('TTS: 初始化异常（第 ${attempt + 1} 次）: $e');
        ok = false;
      }
      if (ok) return true;
      if (attempt < maxAttempts - 1) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    return false;
  }

  static Future<bool> _doInitialize() async {
    // 注册回调（仅注册一次）
    if (!_handlersRegistered) {
      _flutterTts.setStartHandler(() {
        debugPrint('TTS: onStart 触发');
        _isSpeaking = true;
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS: onDone 触发');
        _isSpeaking = false;
        // 忽略 stop() 触发的完成事件，防止新回调被提前消费
        if (_isStoppingForRestart) {
          debugPrint('TTS: 忽略 stop() 触发的完成回调');
          return;
        }
        _onComplete?.call();
        _onComplete = null;
      });

      _flutterTts.setErrorHandler((message) {
        debugPrint('TTS: onError 触发: $message');
        _isSpeaking = false;
        // 忽略 stop() 触发的错误事件
        if (_isStoppingForRestart) {
          debugPrint('TTS: 忽略 stop() 触发的错误回调');
          return;
        }
        _onComplete?.call();
        _onComplete = null;
      });

      _handlersRegistered = true;
    }

    try {
      if (!kIsWeb && Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
      }

      if (Platform.isAndroid) {
        final defaultEngine = await _flutterTts.getDefaultEngine;
        debugPrint('TTS: 系统默认引擎: $defaultEngine');

        if (defaultEngine == null || defaultEngine.toString().isEmpty) {
          final engineBound = await _tryBindEngine();
          if (!engineBound) {
            debugPrint('TTS: 无法绑定推荐引擎，继续初始化并尝试用系统默认配置');
            // 不将初始化直接视为失败，继续尝试后续设置以提高容错性
          }
        }

        // 等待原生层初始化完成
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 尝试设置语言（完全非阻塞）
      await _trySetLanguage();
      if (Platform.isAndroid) {
        await _trySetPreferredVoice();
      }

      // 设置语音参数
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);

      // 不使用 awaitSpeakCompletion(true)
      await _flutterTts.awaitSpeakCompletion(false);

      debugPrint('TTS: 初始化成功（语言设置可能未成功，但不阻止朗读）');
      _isAvailable = true;
      return true;
    } catch (e, stackTrace) {
      debugPrint('TTS initialize failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isAvailable = false;
      return false;
    }
  }

  /// 仅在没有默认引擎时才尝试手动绑定
  static Future<bool> _tryBindEngine() async {
    try {
      final engines = await _flutterTts.getEngines;
      if (engines is! List<dynamic> || engines.isEmpty) {
        return false;
      }

      debugPrint('TTS: 已安装引擎: $engines');

      const preferredEngines = [
        'com.xiaomi.mibrain.speech',
        'com.google.android.tts',
        'com.iflytek.speechsuite',
        'com.baidu.duersdk.opensdk',
        'com.huawei.hiai',
      ];

      for (final preferred in preferredEngines) {
        for (final engine in engines) {
          final candidate = engine.toString().trim();
          if (candidate == preferred) {
            final result = await _flutterTts.setEngine(candidate);
            if (result == 1) return true;
          }
        }
      }

      for (final engine in engines) {
        final candidate = engine.toString().trim();
        if (candidate.isNotEmpty) {
          final result = await _flutterTts.setEngine(candidate);
          if (result == 1) return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('TTS _tryBindEngine failed: $e');
      return false;
    }
  }

  /// 尝试设置首选语言（完全非阻塞）
  ///
  /// 诊断发现：小米引擎报告 [zh, en, zh-Hans, zh-Hant]，
  /// 但 setLanguage('zh-Hans') 可能返回 0。
  /// 修复：直接用 getLanguages() 返回的原始字符串逐个尝试 setLanguage()。
  /// 即使全部失败，也不阻止朗读——引擎可能内部支持中文。
  static Future<void> _trySetLanguage() async {
    try {
      final languages = await _flutterTts.getLanguages;
      if (languages is! List<dynamic> || languages.isEmpty) {
        debugPrint('TTS: 引擎未报告可用语言，跳过语言设置');
        return;
      }

      debugPrint('TTS: 可用语言: $languages');

      // 策略1：优先尝试中文相关语言（直接用引擎返回的原始字符串）
      for (final lang in languages) {
        final langStr = lang.toString();
        final langLower = langStr.toLowerCase();
        if (langLower.startsWith('zh') || langLower.contains('cmn')) {
          debugPrint('TTS: 尝试 setLanguage("$langStr")');
          final result = await _flutterTts.setLanguage(langStr);
          debugPrint('TTS: setLanguage("$langStr") => $result');
          if (result == 1) {
            debugPrint('TTS: 语言设置成功: $langStr');
            return;
          }
        }
      }

      // 策略2：尝试标准中文 locale
      const standardLocales = ['zh-CN', 'zh-Hans', 'zh', 'cmn-CN', 'en-US'];
      for (final locale in standardLocales) {
        final result = await _flutterTts.setLanguage(locale);
        debugPrint('TTS: setLanguage("$locale") => $result');
        if (result == 1) {
          debugPrint('TTS: 语言设置成功: $locale');
          return;
        }
      }

      // 策略3：尝试引擎返回的任意语言
      for (final lang in languages) {
        final langStr = lang.toString();
        final result = await _flutterTts.setLanguage(langStr);
        if (result == 1) {
          debugPrint('TTS: 语言设置成功(降级): $langStr');
          return;
        }
      }

      // 全部失败，但不阻止朗读
      debugPrint('TTS: 所有语言设置均失败，但仍标记为可用（引擎可能内部支持中文）');
    } catch (e) {
      debugPrint('TTS: _trySetLanguage 异常: $e（不阻止朗读）');
    }
  }

  /// 尝试选择首选语音，用于修复小米/MIUI上语言引擎无法正确选择的问题
  static Future<void> _trySetPreferredVoice() async {
    try {
      final voices = await _flutterTts.getVoices;
      debugPrint('TTS: 可用语音: $voices');
      if (voices is! List<dynamic> || voices.isEmpty) {
        return;
      }

      // 尝试选择首个中文语音
      for (final voice in voices) {
        if (voice == null) continue;
        final rawMap = voice as Map<dynamic, dynamic>;
        final locale = (rawMap['locale'] ?? rawMap['name'] ?? '').toString().toLowerCase();
        if (locale.contains('zh') || locale.contains('cn')) {
          final voiceMap = rawMap.map((key, value) => MapEntry(key.toString(), value.toString()));
          try {
            final result = await _flutterTts.setVoice(voiceMap);
            debugPrint('TTS: setVoice($voiceMap) => $result');
            if (result == 1) {
              debugPrint('TTS: 选择中文语音成功: $voiceMap');
              return;
            }
          } catch (e) {
            debugPrint('TTS: 设置语音失败: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('TTS: _trySetPreferredVoice 异常: $e');
    }
  }

  /// 设置语音参数
  static Future<void> applySpeechParams({
    double? rate,
    double? pitch,
    double? volume,
  }) async {
    try {
      if (rate != null) await _flutterTts.setSpeechRate(rate);
      if (pitch != null) await _flutterTts.setPitch(pitch);
      if (volume != null) await _flutterTts.setVolume(volume);
    } catch (e) {
      debugPrint('TTS: applySpeechParams failed: $e');
    }
  }

  /// 文本预处理 - 将题目文本转换为更适合语音播报的形式
  ///
  /// 处理规则：
  /// - （）或() 空括号 → "什么"
  /// - （内容）有内容的括号 → 去掉括号保留内容
  /// - _____ 连续下划线 → "什么"
  /// - 【】 方括号 → 去掉括号保留内容
  /// - □ ○ ◇ 等选择符号 → "什么"
  /// - → ← ↑ ↓ 箭头 → 替换为文字描述
  /// - ※ § 等特殊符号 → 清除
  /// —— 破折号 → 逗号（语音停顿）
  /// - · 间隔号 → 逗号
  /// - Markdown 标记清理
  /// - 多余空格和标点合并
  static String preprocessText(String text) {
    var result = text;

    // 1. 空括号（）() → "什么"
    result = result.replaceAll(RegExp(r'[（(]\s*[）)]'), '什么');

    // 2. 有内容的括号：去掉括号保留内容（语音不需要括号）
    result = result.replaceAll(RegExp(r'[（(]([^）)]+)[）)]'), r'$1');

    // 3. 方括号【】[] → 去掉括号保留内容
    result = result.replaceAll(RegExp(r'[【\[]([^】\]]+)[】\]]'), r'$1');

    // 4. 连续下划线（填空横线）→ "什么"
    result = result.replaceAll(RegExp(r'_{2,}'), '什么');

    // 5. 单个下划线如果出现在空格位置也替换
    result = result.replaceAll(RegExp(r'(?<=[\s，。、])_(?=[\s，。、])'), '什么');

    // 6. 选择符号 □ ○ ◇ → "什么"
    result = result.replaceAll(RegExp(r'[□○◇]'), '什么');

    // 7. 箭头符号 → 文字描述
    result = result.replaceAll('→', '变为');
    result = result.replaceAll('←', '反向变为');
    result = result.replaceAll('↑', '上升至');
    result = result.replaceAll('↓', '下降至');

    // 8. 破折号 → 逗号（语音停顿）
    result = result.replaceAll('——', '，');
    result = result.replaceAll('—', '，');

    // 9. 间隔号 → 逗号
    result = result.replaceAll('·', '，');

    // 10. 清除特殊符号
    result = result.replaceAll(RegExp(r'[※§★☆◆●○■□△▲▽▼]'), '');

    // 11. 清理 Markdown 加粗标记
    result = result.replaceAll('**', '');
    result = result.replaceAll(RegExp(r'`([^`]+)`'), r'$1');

    // 12. 清理 Markdown 标题标记
    result = result.replaceAll(RegExp(r'^#+\s*'), '');
    result = result.replaceAll(RegExp(r'\n#+\s*'), '\n');

    // 13. 清理 Markdown 列表标记
    result = result.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');

    // 14. 连续相同标点合并（如。。。→。）
    result = result.replaceAll(RegExp(r'([，。！？、；：])\1+'), r'$1');

    // 15. 多余空白合并
    result = result.replaceAll(RegExp(r'\s{2,}'), ' ');

    // 16. 标点前的空格清除
    result = result.replaceAll(RegExp(r'\s+([，。！？、；：）」』])'), r'$1');

    // 17. 标点后的多余空格清除
    result = result.replaceAll(RegExp(r'([（「『])\s+'), r'$1');

    return result.trim();
  }

  /// 将原始文本/HTML 清洗为纯文本，并按语音友好的句子或长度分块返回
  ///
  /// 供需要长文分段连续朗读的场景使用（如考点知识播放）。
  static List<String> cleanAndChunk(String raw) {
    // 移除常见 HTML 标签与实体（简单处理，复杂 HTML 可用后端预处理）
    var text = raw.replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) return [];

    // 先按中文句号、问号、感叹号或英文标点拆分为句子
    final sentenceSep = RegExp(r'(?<=[。！？!?;；.])\s*');
    final parts = text
        .split(sentenceSep)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // 合并句子以控制每块长度（目标 160-260 字符）
    const int targetLength = 220;
    final chunks = <String>[];
    var buffer = StringBuffer();

    for (final part in parts) {
      if (buffer.isEmpty) {
        buffer.write(part);
      } else if ((buffer.length + part.length) <= targetLength) {
        buffer.write(' ');
        buffer.write(part);
      } else {
        chunks.add(buffer.toString());
        buffer = StringBuffer(part);
      }
    }
    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    // 如果没有切出句子（比如整段无标点），再按长度切分
    if (chunks.isEmpty) {
      for (var i = 0; i < text.length; i += targetLength) {
        chunks.add(text.substring(i, (i + targetLength).clamp(0, text.length)));
      }
    }

    return chunks;
  }

  /// 朗读文本
  ///
  /// 核心策略（基于诊断修复）：
  /// - speak() 返回 1 即视为成功，不等待 onStart 回调
  ///   （小米引擎可能不触发 onStart，但实际在播放声音）
  /// - onStart 仅用于更新 _isSpeaking 状态
  /// - onDone/onError 用于重置状态和触发回调
  /// - 如果 speak() 返回 0，重试一次（重新初始化）
  /// - 自动对文本进行预处理（括号替换等）
  static Future<bool> speak(String text, {VoidCallback? onComplete, bool waitForCompletion = false}) async {
    final speechText = preprocessText(text);
    if (speechText.isEmpty) {
      // 空文本不算失败，直接回调继续下一节
      debugPrint('TTS: 文本为空，跳过朗读');
      onComplete?.call();
      return true;
    }

    // 递增代际计数器，使旧的 stop() 异步回调不再干扰本次朗读
    final gen = _speakGeneration + 1;
    _speakGeneration = gen;

    // 使用串行化链，确保多个 speak 请求按发起顺序执行
    final response = Completer<bool>();
    _lastSpeak = _lastSpeak.then((_) async {
      // 最多重试 2 次
      for (int attempt = 0; attempt < 2; attempt++) {
        if (attempt > 0) {
          debugPrint('TTS: 重试朗读 (第 ${attempt + 1} 次)');
          _initFuture = null;
          await Future.delayed(const Duration(milliseconds: 300));
          if (_speakGeneration != gen) {
            debugPrint('TTS: 检测到新的朗读请求/取消，放弃本次重试');
            response.complete(false);
            return;
          }
        }

        // 确保引擎已初始化（可以等待更久以避免启动时失败）
        bool ready = false;
        try {
          ready = await initialize().timeout(
            const Duration(seconds: 8),
            onTimeout: () => false,
          );
        } catch (e) {
          debugPrint('TTS: 初始化异常: $e');
        }

        if (!ready) {
          debugPrint('TTS: 初始化失败 (第 ${attempt + 1} 次)');
          continue;
        }

        try {
          // 1. 先清空回调，防止上一句的完成事件调用新回调
          _onComplete = null;

          // 2. 仅当确实在朗读时才打断上一句。顺序播放（waitForCompletion）时
          //    上一句已经读完，不应再 stop()，否则会截断尾音 / 引发引擎竞争，
          //    导致「播放顺序混乱」。用户主动停止或切换段落由页面层先 stop()。
          if (_isSpeaking) {
            // 设置过渡标记，让完成/错误处理器忽略 stop() 触发的回调
            _isStoppingForRestart = true;
            try {
              await _flutterTts.stop();
            } catch (_) {}
            // 让事件循环处理 stop() 可能触发的完成/错误事件
            await Future.delayed(const Duration(milliseconds: 50));
            _isStoppingForRestart = false;
          }

          // 6. 设置新的完成回调（此时 stop() 的回调已被安全忽略）
          Completer<bool>? completionCompleter;
          bool completed = false;
          if (waitForCompletion) {
            completionCompleter = Completer<bool>();
            _currentCompletionCompleter = completionCompleter;
            _onComplete = () {
              if (completed) return;
              completed = true;
              onComplete?.call();
              if (!completionCompleter!.isCompleted) {
                completionCompleter.complete(true);
              }
              _currentCompletionCompleter = null;
            };
          } else {
            _onComplete = onComplete;
          }

          // 7. 调用 speak()，添加超时防止挂起
          final result = await _flutterTts.speak(speechText).timeout(
            const Duration(seconds: 4),
            onTimeout: () {
              debugPrint('TTS: speak() 超时（4秒无响应）');
              return 0;
            },
          );
          debugPrint('TTS: speak() 返回 $result');

          if (result == 1) {
            _isSpeaking = true;
            debugPrint('TTS: 朗读已提交，引擎将播放');

            if (!waitForCompletion) {
              response.complete(true);
              return;
            }

            // 如果正常回调未触发，则在语音预计播放结束后自动继续
            final fallbackDuration = _estimateSpeechDuration(speechText);
            Future.delayed(fallbackDuration, () {
              if (!completed && _speakGeneration == gen) {
                debugPrint('TTS: speak() 完成回调超时，触发回退完成');
                completed = true;
                // 复位状态，避免顺序播放下一句误判「仍在朗读」而多余 stop()
                _isSpeaking = false;
                onComplete?.call();
                if (!completionCompleter!.isCompleted) {
                  completionCompleter.complete(true);
                }
                _currentCompletionCompleter = null;
              }
            });

            final val = await completionCompleter!.future;
            response.complete(val);
            return;
          }

          debugPrint('TTS: speak 返回失败，准备重试');
        } catch (e, stackTrace) {
          debugPrint('TTS speak异常: $e');
          debugPrintStack(stackTrace: stackTrace);
          _isStoppingForRestart = false;
        }
      }

      debugPrint('TTS: 所有重试均失败');
      _isSpeaking = false;
      _onComplete = null;
      _currentCompletionCompleter = null;
      onComplete?.call();
      response.complete(false);
    });

    // 等待队列执行完成并返回结果
    return response.future;
  }

  static Duration _estimateSpeechDuration(String text) {
    // 中文按字符数估算：中文没有空格，若按拉丁分词会恒为 1 个单词→3秒，
    // 导致长段落被提前切走、下一段提前插入，表现为「播放顺序混乱」。
    final chars = text.replaceAll(RegExp(r'\s+'), '').length;
    // 英文 / 数字单词单独估算（与中文混排时）
    final latinPart = text.replaceAll(RegExp(r'[\u4e00-\u9fff]'), ' ');
    final latinWords = latinPart
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    final millis = chars * 260 + latinWords * 400;
    // 上限放宽到 60 秒，避免长段落被提前切走；下限 2 秒
    return Duration(milliseconds: millis.clamp(2000, 60000));
  }

  /// 停止朗读
  static Future<void> stop() async {
    // 先清空回调，防止 stop() 触发的完成事件调用旧回调
    _onComplete = null;
    _isStoppingForRestart = true;
    _speakGeneration++;
    if (_currentCompletionCompleter != null && !_currentCompletionCompleter!.isCompleted) {
      _currentCompletionCompleter!.complete(false);
      _currentCompletionCompleter = null;
    }
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
    // 让事件循环处理 stop() 可能触发的完成事件
    await Future.delayed(const Duration(milliseconds: 50));
    _isStoppingForRestart = false;
    _isSpeaking = false;
  }

  /// 暂停朗读
  static Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      debugPrint('TTS pause failed: $e');
    }
  }

  /// 获取可用语言列表
  static Future<List<dynamic>> getLanguages() async {
    final result = await _flutterTts.getLanguages;
    return result as List<dynamic>;
  }

  /// 设置语速 (0.0 - 1.0)
  static Future<void> setSpeechRate(double rate) async {
    await applySpeechParams(rate: rate);
  }

  /// 打开系统 TTS 设置页面
  static Future<bool> openTtsSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _nativeChannel.invokeMethod('openTtsSettings');
      return result == true;
    } catch (e) {
      debugPrint('TTS: 打开设置失败: $e');
      return false;
    }
  }

  /// 打开语音数据安装页面
  static Future<bool> installTtsData() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _nativeChannel.invokeMethod('installTtsData');
      return result == true;
    } catch (e) {
      debugPrint('TTS: 安装语音数据失败: $e');
      return false;
    }
  }

  /// 获取诊断信息
  static Future<Map<String, dynamic>> getDiagnostics() async {
    final info = <String, dynamic>{};
    try {
      info['isAvailable'] = _isAvailable;
      info['isSpeaking'] = _isSpeaking;
      if (Platform.isAndroid) {
        info['defaultEngine'] = await _flutterTts.getDefaultEngine;
        info['engines'] = await _flutterTts.getEngines;
        info['languages'] = await _flutterTts.getLanguages;

        try {
          final nativeEngines =
              await _nativeChannel.invokeMethod('getEnginesInfo');
          info['nativeEngines'] = nativeEngines;
        } catch (_) {}

        // 原生语音数据检查
        try {
          final voiceData =
              await _nativeChannel.invokeMethod('checkVoiceData');
          info['voiceData'] = voiceData;
        } catch (_) {}
      }
    } catch (e) {
      info['error'] = e.toString();
    }
    return info;
  }

  /// 重置 TTS 状态
  static Future<void> reset() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _speakGeneration++;
    _initFuture = null;
    _isSpeaking = false;
    _isAvailable = false;
    _onComplete = null;
  }

  /// 释放资源
  static Future<void> dispose() async {
    await _flutterTts.stop();
    _initFuture = null;
    _isSpeaking = false;
    _isAvailable = false;
    _onComplete = null;
  }
}

