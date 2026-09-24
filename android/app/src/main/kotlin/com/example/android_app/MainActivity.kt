package com.example.android_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册 TTS 辅助插件（原生通道：打开设置、安装语音数据、诊断）
        flutterEngine.plugins.add(TtsHelperPlugin())
        // 注册应用安装插件（原生通道：用系统安装器安装下载的 APK）
        flutterEngine.plugins.add(AppInstallerPlugin())
    }
}
