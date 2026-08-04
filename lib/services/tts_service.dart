import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 语音播报服务 - 用于朗读题目和选项
///
/// 针对小米/MIUI 设备优化要点：
/// 1. 小米自带 TTS 引擎包名为 com.xiaomi.mibrain.speech（非 com.xiaomi.mi.speech）
/// 2. 不强制调用 setEngine()：FlutterTts 创建时已自动绑定系统默认引擎，
///    重复调用 setEngine() 反而可能导致引擎重绑失败
/// 3. 语言设置非阻塞：小米引擎可能不通过 getLanguages() 报告支持中文，
///    但实际可以朗读中文，因此语言设置失败时不阻止朗读
/// 4. 不使用 awaitSpeakCompletion(true)，避免引擎静默失败时 speak() 永久挂起
/// 5. 使用 onStart 回调检测朗读是否真正启动，3秒超时判定失败后自动重试
class TtsService {
  TtsService._();

  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isSpeaking = false;
  static bool _isAvailable = false;

  /// 缓存初始化 Future，避免并发初始化竞态
  static Future<bool>? _initFuture;

  /// 原生通道：打开 TTS 设置、安装语音数据等
  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.android_app/tts_helper');

  /// 是否正在朗读
  static bool get isSpeaking => _isSpeaking;

  /// TTS 引擎是否可用
  static bool get isAvailable => _isAvailable;

  /// 初始化 TTS 引擎
  static Future<bool> initialize() {
    if (_isAvailable) return Future.value(true);
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  static Future<bool> _doInitialize() async {
    // 注册回调
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((message) {
      debugPrint('TTS error: $message');
      _isSpeaking = false;
    });

    try {
      await _flutterTts.setSharedInstance(true);

      if (Platform.isAndroid) {
        // 检查默认引擎是否存在（不强制 setEngine）
        final defaultEngine = await _flutterTts.getDefaultEngine;
        debugPrint('TTS: 系统默认引擎: $defaultEngine');

        if (defaultEngine == null || defaultEngine.toString().isEmpty) {
          // 没有默认引擎，尝试手动绑定
          final engineBound = await _tryBindEngine();
          if (!engineBound) {
            debugPrint('TTS: 无法绑定 TTS 引擎，设备可能未安装语音引擎');
            _isAvailable = false;
            return false;
          }
        }

        // 引擎已就绪，等待原生层初始化完成
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 尝试设置语言（非阻塞：失败不阻止朗读）
      await _trySetLanguage();

      // 设置语音参数
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);

      // 不使用 awaitSpeakCompletion(true)，避免小米设备上 speak() 永久挂起
      await _flutterTts.awaitSpeakCompletion(false);

      debugPrint('TTS: 初始化成功');
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
        debugPrint('TTS: 设备未安装任何 TTS 引擎');
        return false;
      }

      debugPrint('TTS: 已安装引擎列表: $engines');

      // 已知引擎包名（正确的包名）
      const preferredEngines = [
        'com.xiaomi.mibrain.speech', // 小米系统语音引擎
        'com.google.android.tts',     // Google TTS
        'com.iflytek.speechsuite',    // 讯飞语音
        'com.baidu.duersdk.opensdk',  // 百度语音
        'com.huawei.hiai',            // 华为语音引擎
      ];

      // 先尝试首选引擎
      for (final preferred in preferredEngines) {
        for (final engine in engines) {
          final candidate = engine.toString().trim();
          if (candidate == preferred) {
            debugPrint('TTS: 尝试绑定首选引擎: $candidate');
            final result = await _flutterTts.setEngine(candidate);
            if (result == 1) {
              debugPrint('TTS: 引擎绑定成功: $candidate');
              return true;
            }
          }
        }
      }

      // 再尝试任意可用引擎
      for (final engine in engines) {
        final candidate = engine.toString().trim();
        if (candidate.isNotEmpty) {
          debugPrint('TTS: 尝试绑定引擎: $candidate');
          final result = await _flutterTts.setEngine(candidate);
          if (result == 1) {
            debugPrint('TTS: 引擎绑定成功: $candidate');
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('TTS _tryBindEngine failed: $e');
      return false;
    }
  }

  /// 尝试设置首选语言（非阻塞）
  ///
  /// 小米引擎可能不通过 getLanguages() 报告支持中文，
  /// 但实际可以朗读中文，因此即使语言设置失败也不阻止朗读
  static Future<void> _trySetLanguage() async {
    const preferredLanguages = <String>[
      'zh-CN',
      'zh-Hans-CN',
      'zh-Hans',
      'cmn-CN',
      'en-US',
    ];

    try {
      final languages = await _flutterTts.getLanguages;
      if (languages is List<dynamic> && languages.isNotEmpty) {
        debugPrint('TTS: 可用语言: $languages');
        for (final language in preferredLanguages) {
          final normalizedLanguage =
              language.toLowerCase().replaceAll('-', '');
          final hasMatch = languages.any((candidate) {
            final value =
                candidate.toString().toLowerCase().replaceAll('-', '');
            return value.contains(normalizedLanguage);
          });
          if (hasMatch) {
            final result = await _flutterTts.setLanguage(language);
            if (result == 1) {
              debugPrint('TTS: 语言设置成功: $language');
              return;
            }
          }
        }
      } else {
        debugPrint('TTS: 引擎未报告可用语言列表，尝试直接设置');
      }

      // 尝试直接设置中文
      final result = await _flutterTts.setLanguage('zh-CN');
      if (result == 1) {
        debugPrint('TTS: 语言设置成功: zh-CN (直接设置)');
        return;
      }

      // 尝试英文降级
      final enResult = await _flutterTts.setLanguage('en-US');
      if (enResult == 1) {
        debugPrint('TTS: 降级使用英文');
        return;
      }

      // 语言设置全部失败，但不阻止朗读
      // 小米引擎可能内部支持中文但不通过标准 API 报告
      debugPrint('TTS: 语言设置失败，但仍标记为可用（引擎可能内部支持中文）');
    } catch (e) {
      debugPrint('TTS _trySetLanguage failed: $e（不阻止朗读）');
    }
  }

  /// 朗读文本
  ///
  /// 核心机制：
  /// - speak() 立即返回（不等待朗读完成）
  /// - 通过 onStart 回调检测朗读是否真正启动，3秒超时判定失败
  /// - 失败后自动重试（最多3次），每次重试重新初始化
  static Future<bool> speak(String text, {VoidCallback? onComplete}) async {
    final speechText = text.trim();
    if (speechText.isEmpty) {
      onComplete?.call();
      return false;
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        debugPrint('TTS: 重试朗读 (第 ${attempt + 1} 次)');
        _initFuture = null;
        _isAvailable = false;
        await Future.delayed(const Duration(milliseconds: 300));
      }

      bool ready = false;
      try {
        ready = await initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('TTS: 初始化超时（5秒）');
            return false;
          },
        );
      } catch (e) {
        debugPrint('TTS: 初始化异常: $e');
      }

      if (!ready || !_isAvailable) {
        debugPrint('TTS: 引擎不可用 (第 ${attempt + 1} 次)');
        continue;
      }

      // 使用 Completer 检测 onStart
      final startCompleter = Completer<void>();

      _flutterTts.setStartHandler(() {
        debugPrint('TTS: onStart 回调触发');
        _isSpeaking = true;
        if (!startCompleter.isCompleted) {
          startCompleter.complete();
        }
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS: onDone 回调触发');
        _isSpeaking = false;
        onComplete?.call();
      });

      _flutterTts.setErrorHandler((message) {
        debugPrint('TTS: onError 回调触发: $message');
        _isSpeaking = false;
        if (!startCompleter.isCompleted) {
          startCompleter.completeError('TTS error: $message');
        }
        onComplete?.call();
      });

      try {
        // 先停止之前的朗读
        try {
          await _flutterTts.stop();
        } catch (e) {
          debugPrint('TTS: stop 异常（可忽略）: $e');
        }

        final result = await _flutterTts.speak(speechText);

        if (result != 1) {
          debugPrint('TTS: speak 返回失败 (result=$result)');
          continue;
        }

        // 等待 onStart 回调（最多 3 秒）
        try {
          await startCompleter.future.timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('TTS: onStart 未在3秒内触发，引擎可能未真正启动');
            },
          );

          if (startCompleter.isCompleted) {
            debugPrint('TTS: 朗读成功启动');
            return true;
          }
        } catch (e) {
          debugPrint('TTS: 等待 onStart 异常: $e');
        }

        // onStart 未触发，停止并重试
        try {
          await _flutterTts.stop();
        } catch (_) {}
        _isSpeaking = false;
        debugPrint('TTS: 朗读未启动，准备重试');
      } catch (e, stackTrace) {
        debugPrint('TTS speak failed: $e');
        debugPrintStack(stackTrace: stackTrace);
        _isSpeaking = false;
      }
    }

    debugPrint('TTS: 所有重试均失败，语音不可用');
    _isSpeaking = false;
    onComplete?.call();
    return false;
  }

  /// 停止朗读
  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop failed: $e');
    }
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
    await _flutterTts.setSpeechRate(rate);
  }

  /// 打开系统 TTS 设置页面（Android 专用）
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

  /// 打开语音数据安装页面（Android 专用）
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

  /// 获取诊断信息（用于调试和错误提示）
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
      }
    } catch (e) {
      info['error'] = e.toString();
    }
    return info;
  }

  /// 重置 TTS 状态（用于手动重试）
  static Future<void> reset() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _initFuture = null;
    _isSpeaking = false;
    _isAvailable = false;
  }

  /// 释放资源
  static Future<void> dispose() async {
    await _flutterTts.stop();
    _initFuture = null;
    _isSpeaking = false;
    _isAvailable = false;
  }
}
