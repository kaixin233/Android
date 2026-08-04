import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 语音播报服务 - 用于朗读题目和选项
///
/// 修复要点：
/// 1. 添加 [awaitSpeakCompletion] 确保朗读完成后再回调
/// 2. 检查 [speak] 返回值（1=成功，0=失败），失败时及时重置状态
/// 3. 初始化失败时不再静默吞错，提供 [isAvailable] 供调用方判断
/// 4. 将 handler 注册移至 try 块之前，确保即使部分配置失败也能正常工作
class TtsService {
  TtsService._();

  static final FlutterTts _flutterTts = FlutterTts();
  static bool _initialized = false;
  static bool _isSpeaking = false;
  static bool _isAvailable = false;

  /// 是否正在朗读
  static bool get isSpeaking => _isSpeaking;

  /// TTS 引擎是否可用（初始化成功且语言设置成功）
  static bool get isAvailable => _isAvailable;

  /// 初始化 TTS 引擎
  ///
  /// 在应用启动时调用可提前预热引擎，避免首次朗读时延迟。
  /// 即使初始化失败，[speak] 方法内部也会尝试重新初始化。
  static Future<void> initialize() async {
    if (_initialized) return;

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

      // 设置语言
      _isAvailable = await _setPreferredLanguage();
      if (!_isAvailable) {
        debugPrint('TTS: 未找到可用的中文语音引擎，语音功能可能不可用');
      }

      // 设置语音参数
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSilence(0);

      // 让 speak() 的 Future 在朗读完成后才返回
      await _flutterTts.awaitSpeakCompletion(true);

      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint('TTS initialize failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      _initialized = false;
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
        for (final language in preferredLanguages) {
          final normalizedLanguage = language.toLowerCase().replaceAll('-', '');
          final hasMatch = languages.any((candidate) {
            final value = candidate.toString().toLowerCase().replaceAll('-', '');
            return value.contains(normalizedLanguage);
          });
          if (hasMatch) {
            final result = await _flutterTts.setLanguage(language);
            return result == 1;
          }
        }
      }

      // 尝试直接设置中文
      final result = await _flutterTts.setLanguage('zh-CN');
      return result == 1;
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
  static Future<bool> speak(String text, {VoidCallback? onComplete}) async {
    final speechText = text.trim();
    if (speechText.isEmpty) return false;

    await initialize();

    // 如果引擎不可用，直接通知调用方
    if (!_isAvailable) {
      debugPrint('TTS: 引擎不可用，无法朗读');
      onComplete?.call();
      return false;
    }

    // 每次朗读前重新设置回调，确保 onComplete 能正确触发
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });
    _flutterTts.setErrorHandler((message) {
      debugPrint('TTS speak error: $message');
      _isSpeaking = false;
      onComplete?.call();
    });

    try {
      // 先停止之前的朗读
      await _flutterTts.stop();

      final result = await _flutterTts.speak(speechText);
      // speak() 返回 1 表示成功，0 表示失败
      if (result == 1) {
        _isSpeaking = true;
        return true;
      } else {
        debugPrint('TTS speak returned failure (result=$result)');
        _isSpeaking = false;
        onComplete?.call();
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('TTS speak failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isSpeaking = false;
      onComplete?.call();
      return false;
    }
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

  /// 释放资源
  static Future<void> dispose() async {
    await _flutterTts.stop();
    _initialized = false;
    _isSpeaking = false;
    _isAvailable = false;
  }
}
