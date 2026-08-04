import 'dart:ui';

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

    await _flutterTts.setLanguage('zh-CN');
    await _flutterTts.setSpeechRate(0.45); // 适中语速
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((message) {
      _isSpeaking = false;
    });

    _initialized = true;
  }

  /// 朗读文本
  static Future<void> speak(String text, {VoidCallback? onComplete}) async {
    await initialize();
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });
    _flutterTts.setErrorHandler((message) {
      _isSpeaking = false;
      onComplete?.call();
    });
    await _flutterTts.speak(text);
    _isSpeaking = true;
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