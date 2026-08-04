import 'dart:async';
import 'dart:io';
import 'dart:ui';

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

  /// 朗读代际计数器，用于防止旧的 stop() 异步清空新的 speak() 回调
  static int _speakGeneration = 0;

  /// 标记回调是否已注册，避免重复注册
  static bool _handlersRegistered = false;

  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.android_app/tts_helper');

  static bool get isSpeaking => _isSpeaking;
  static bool get isAvailable => _isAvailable;

  /// 初始化 TTS 引擎
  static Future<bool> initialize() {
    if (_isAvailable) return Future.value(true);
    _initFuture ??= _doInitialize();
    return _initFuture!;
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
        _onComplete?.call();
        _onComplete = null;
      });

      _flutterTts.setErrorHandler((message) {
        debugPrint('TTS: onError 触发: $message');
        _isSpeaking = false;
        _onComplete?.call();
        _onComplete = null;
      });

      _handlersRegistered = true;
    }

    try {
      await _flutterTts.setSharedInstance(true);

      if (Platform.isAndroid) {
        final defaultEngine = await _flutterTts.getDefaultEngine;
        debugPrint('TTS: 系统默认引擎: $defaultEngine');

        if (defaultEngine == null || defaultEngine.toString().isEmpty) {
          final engineBound = await _tryBindEngine();
          if (!engineBound) {
            debugPrint('TTS: 无法绑定 TTS 引擎');
            _isAvailable = false;
            return false;
          }
        }

        // 等待原生层初始化完成
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 尝试设置语言（完全非阻塞）
      await _trySetLanguage();

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

  /// 朗读文本
  ///
  /// 核心策略（基于诊断修复）：
  /// - speak() 返回 1 即视为成功，不等待 onStart 回调
  ///   （小米引擎可能不触发 onStart，但实际在播放声音）
  /// - onStart 仅用于更新 _isSpeaking 状态
  /// - onDone/onError 用于重置状态和触发回调
  /// - 如果 speak() 返回 0，重试一次（重新初始化）
  /// - 自动对文本进行预处理（括号替换等）
  static Future<bool> speak(String text, {VoidCallback? onComplete}) async {
    final speechText = preprocessText(text);
    if (speechText.isEmpty) {
      onComplete?.call();
      return false;
    }

    // 递增代际计数器，使旧的 stop() 异步回调不再干扰本次朗读
    final gen = _speakGeneration + 1;
    _speakGeneration = gen;

    // 最多重试 2 次
    for (int attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        debugPrint('TTS: 重试朗读 (第 ${attempt + 1} 次)');
        // 只重置 initFuture，不重置 _isAvailable
        _initFuture = null;
        await Future.delayed(const Duration(milliseconds: 300));
        // 等待期间若有新的 speak() 被调用则放弃
        if (_speakGeneration != gen) {
          debugPrint('TTS: 检测到新的朗读请求，放弃重试');
          return false;
        }
      }

      // 确保引擎已初始化
      bool ready = false;
      try {
        ready = await initialize().timeout(
          const Duration(seconds: 5),
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
        // 先停止之前的朗读
        try {
          await _flutterTts.stop();
        } catch (_) {}

        // 设置完成回调（回调处理器在 _doInitialize 中已注册）
        _onComplete = onComplete;

        // 调用 speak()
        final result = await _flutterTts.speak(speechText);
        debugPrint('TTS: speak() 返回 $result');

        if (result == 1) {
          // speak() 返回 1 = 引擎已接受朗读请求
          // 不等待 onStart 回调（小米引擎可能不触发 onStart）
          _isSpeaking = true;
          debugPrint('TTS: 朗读已提交，引擎将播放');
          return true;
        }

        // speak() 返回 0，可能引擎未就绪，重试
        debugPrint('TTS: speak 返回失败，准备重试');
      } catch (e, stackTrace) {
        debugPrint('TTS speak异常: $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    debugPrint('TTS: 所有重试均失败');
    _isSpeaking = false;
    _onComplete = null;
    onComplete?.call();
    return false;
  }

  /// 停止朗读
  static Future<void> stop() async {
    // 记录当前代际，防止异步完成后清空新 speak() 设置的回调
    final gen = _speakGeneration;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
    // 仅当代际未变化时才清空，避免覆盖新 speak() 的回调
    if (gen == _speakGeneration) {
      _isSpeaking = false;
      _onComplete = null;
    }
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
