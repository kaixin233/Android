import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 语音播报服务 - 用于朗读题目和选项
class TtsService {
  TtsService._();

  static final FlutterTts _flutterTts = FlutterTts();
  static bool _initialized = false;
  static bool _isSpeaking = false;

  /// 是否正在朗读
  static bool get isSpeaking => _isSpeaking;

  /// 初始化 TTS 引擎
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _flutterTts.setSharedInstance(true);
      await _setPreferredLanguage();
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSilence(0);

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

      _initialized = true;
    } catch (e, stackTrace) {
      debugPrint('TTS initialize failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      _initialized = false;
    }
  }

  static Future<void> _setPreferredLanguage() async {
    const preferredLanguages = <String>[
      'zh-CN',
      'zh-Hans-CN',
      'zh-Hans',
      'cmn-CN',
      'en-US',
    ];

    final languages = await _flutterTts.getLanguages;
    if (languages is List<dynamic>) {
      for (final language in preferredLanguages) {
        final normalizedLanguage = language.toLowerCase().replaceAll('-', '');
        final hasMatch = languages.any((candidate) {
          final value = candidate.toString().toLowerCase().replaceAll('-', '');
          return value.contains(normalizedLanguage);
        });
        if (hasMatch) {
          await _flutterTts.setLanguage(language);
          return;
        }
      }
    }

    await _flutterTts.setLanguage('zh-CN');
  }

  /// 朗读文本
  static Future<void> speak(String text, {VoidCallback? onComplete}) async {
    final speechText = text.trim();
    if (speechText.isEmpty) return;

    await initialize();
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
      await _flutterTts.speak(speechText);
      _isSpeaking = true;
    } catch (e, stackTrace) {
      debugPrint('TTS speak failed: $e');
      debugPrintStack(stackTrace: stackTrace);
      _isSpeaking = false;
      onComplete?.call();
    }
  }

  /// 停止朗读
  static Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  /// 暂停朗读
  static Future<void> pause() async {
    await _flutterTts.pause();
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
  }
}