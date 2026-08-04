import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 语音播报服务 - 用于朗读题目和选项
///
/// 针对小米/MIUI 设备的特殊优化：
/// 1. 不使用 [awaitSpeakCompletion] (true)，避免 TTS 引擎静默失败时 speak() 永久挂起
/// 2. 使用 onStart 回调检测朗读是否真正启动，3秒超时判定失败
/// 3. 失败后自动重试（最多3次），每次重试重新绑定引擎
/// 4. 原生 MethodChannel 提供打开 TTS 设置、安装语音数据等辅助功能
class TtsService {
  TtsService._();

  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isSpeaking = false;
  static bool _isAvailable = false;

  /// 缓存初始化 Future，避免并发初始化竞态
  static Future<bool>? _initFuture;

  /// 已尝试过的引擎列表（用于重试时切换引擎）
  static final List<String> _triedEngines = [];

  /// 原生通道：打开 TTS 设置、安装语音数据等
  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.android_app/tts_helper');

  /// 是否正在朗读
  static bool get isSpeaking => _isSpeaking;

  /// TTS 引擎是否可用（初始化成功且语言设置成功）
  static bool get isAvailable => _isAvailable;

  /// 初始化 TTS 引擎
  ///
  /// 返回是否初始化成功。多次调用只会执行一次真正的初始化。
  static Future<bool> initialize() {
    if (_isAvailable) return Future.value(true);
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  static Future<bool> _doInitialize() async {
    // 先注册回调，确保不会因后续配置失败而遗漏
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
      // iOS 专用，Android 上为空操作
      await _flutterTts.setSharedInstance(true);

      // Android 专用：主动发现并绑定 TTS 引擎
      if (Platform.isAndroid) {
        final engineBound = await _bindEngine();
        if (!engineBound) {
          debugPrint('TTS: 无法绑定 TTS 引擎，设备可能未安装语音引擎');
          _isAvailable = false;
          return false;
        }
        // 引擎绑定后需要等待原生层完成初始化（小米设备需要更长时间）
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 设置语言
      _isAvailable = await _setPreferredLanguage();
      if (!_isAvailable) {
        debugPrint('TTS: 未找到可用的中文语音引擎，语音功能可能不可用');
        return false;
      }

      // 设置语音参数
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);

      // 关键修复：不使用 awaitSpeakCompletion(true)
      // 在小米/MIUI 设备上，TTS 引擎可能返回 SUCCESS 但实际未发声，
      // 此时 onDone 回调永不触发，导致 speak() 的 Future 永久挂起
      // 改为 false，让 speak() 立即返回，通过 onStart 回调检测是否真正启动
      await _flutterTts.awaitSpeakCompletion(false);

      debugPrint('TTS: 初始化成功');
      return true;
    } catch (e, stackTrace) {
      debugPrint('TTS initialize failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isAvailable = false;
      return false;
    }
  }

  /// Android 专用：发现并绑定 TTS 引擎
  ///
  /// 优先尝试已知兼容中文的引擎，然后遍历所有已安装引擎
  static Future<bool> _bindEngine() async {
    try {
      // 1. 优先使用系统默认引擎（跳过已尝试过的）
      final defaultEngine = await _flutterTts.getDefaultEngine;
      var engineName = defaultEngine?.toString().trim() ?? '';

      if (engineName.isNotEmpty && !_triedEngines.contains(engineName)) {
        debugPrint('TTS: 使用默认引擎: $engineName');
        _triedEngines.add(engineName);
        final result = await _flutterTts.setEngine(engineName);
        if (result == 1) return true;
        debugPrint('TTS: 默认引擎 $engineName 绑定失败，尝试其他引擎');
      }

      // 2. 遍历已安装引擎列表
      final engines = await _flutterTts.getEngines;
      if (engines is List<dynamic>) {
        debugPrint('TTS: 已安装引擎列表: $engines');

        // 优先选择已知兼容中文的引擎
        const preferredEngines = [
          'com.google.android.tts',
          'com.xiaomi.mi.speech',
          'com.iflytek.speechsuite',
          'com.baidu.duersdk.opensdk',
        ];

        // 先尝试首选引擎（跳过已尝试过的）
        for (final preferred in preferredEngines) {
          for (final engine in engines) {
            final candidate = engine.toString().trim();
            if (candidate == preferred && !_triedEngines.contains(candidate)) {
              debugPrint('TTS: 尝试首选引擎: $candidate');
              _triedEngines.add(candidate);
              final result = await _flutterTts.setEngine(candidate);
              if (result == 1) {
                debugPrint('TTS: 引擎绑定成功: $candidate');
                return true;
              }
            }
          }
        }

        // 再尝试任意可用引擎（跳过已尝试过的）
        for (final engine in engines) {
          final candidate = engine.toString().trim();
          if (candidate.isNotEmpty &&
              candidate != engineName &&
              !_triedEngines.contains(candidate)) {
            debugPrint('TTS: 尝试引擎: $candidate');
            _triedEngines.add(candidate);
            final result = await _flutterTts.setEngine(candidate);
            if (result == 1) {
              debugPrint('TTS: 引擎绑定成功: $candidate');
              return true;
            }
          }
        }

        // 如果所有引擎都尝试过了，重置已尝试列表并重试默认引擎
        if (_triedEngines.length >= engines.length) {
          debugPrint('TTS: 所有引擎已尝试过，重置列表重试');
          _triedEngines.clear();
          if (engineName.isNotEmpty) {
            _triedEngines.add(engineName);
            final result = await _flutterTts.setEngine(engineName);
            if (result == 1) return true;
          }
        }
      }

      debugPrint('TTS: 未找到可用的 TTS 引擎');
      return false;
    } catch (e) {
      debugPrint('TTS _bindEngine failed: $e');
      return false;
    }
  }

  /// 设置首选语言，返回是否成功设置
  static Future<bool> _setPreferredLanguage() async {
    const preferredLanguages = <String>[
      'zh-CN',
      'zh-Hans-CN',
      'zh-Hans',
      'cmn-CN',
      'en-US',
    ];

    try {
      final languages = await _flutterTts.getLanguages;
      if (languages is List<dynamic>) {
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
              return true;
            }
          }
        }
      }

      // 尝试直接设置中文
      final result = await _flutterTts.setLanguage('zh-CN');
      if (result == 1) {
        debugPrint('TTS: 语言设置成功: zh-CN (直接设置)');
        return true;
      }

      // 如果中文不可用，尝试英文作为降级
      final enResult = await _flutterTts.setLanguage('en-US');
      if (enResult == 1) {
        debugPrint('TTS: 中文不可用，降级使用英文');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('TTS setPreferredLanguage failed: $e');
      return false;
    }
  }

  /// 朗读文本
  ///
  /// [text] 要朗读的文本
  /// [onComplete] 朗读完成（或失败）后的回调
  /// 返回是否成功开始朗读
  ///
  /// 核心改进：
  /// - 不依赖 awaitSpeakCompletion，speak() 立即返回
  /// - 使用 onStart 回调检测朗读是否真正启动
  /// - 3秒内未启动则判定失败，自动重试（最多3次）
  /// - 每次重试重新绑定引擎，尝试不同的 TTS 引擎
  static Future<bool> speak(String text, {VoidCallback? onComplete}) async {
    final speechText = text.trim();
    if (speechText.isEmpty) {
      onComplete?.call();
      return false;
    }

    // 最多重试 3 次
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        debugPrint('TTS: 重试朗读 (第 ${attempt + 1} 次)');
        // 重置初始化状态，强制重新绑定引擎
        _initFuture = null;
        _isAvailable = false;
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 确保 TTS 已初始化
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

      // 设置回调 - 使用 Completer 检测 onStart
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

        // speak() 在 awaitSpeakCompletion(false) 下会立即返回
        final result = await _flutterTts.speak(speechText);

        if (result != 1) {
          debugPrint('TTS: speak 返回失败 (result=$result)');
          // speak 失败可能是引擎绑定丢失
          continue;
        }

        // 等待 onStart 回调（最多 3 秒）
        // 如果 3 秒内 onStart 未触发，说明 TTS 引擎虽返回 SUCCESS
        // 但实际未启动朗读（小米设备常见问题）
        try {
          await startCompleter.future.timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('TTS: onStart 未在3秒内触发，引擎可能未真正启动');
            },
          );

          // onStart 已触发，朗读成功启动
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

    // 所有重试均失败
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
      info['triedEngines'] = List<String>.from(_triedEngines);
      if (Platform.isAndroid) {
        info['defaultEngine'] = await _flutterTts.getDefaultEngine;
        info['engines'] = await _flutterTts.getEngines;
        info['languages'] = await _flutterTts.getLanguages;

        // 尝试获取原生引擎信息
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
    _triedEngines.clear();
  }

  /// 释放资源
  static Future<void> dispose() async {
    await _flutterTts.stop();
    _initFuture = null;
    _isSpeaking = false;
    _isAvailable = false;
    _triedEngines.clear();
  }
}
