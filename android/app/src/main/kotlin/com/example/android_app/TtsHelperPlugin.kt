package com.example.android_app

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * TTS 辅助插件 - 提供原生层 TTS 诊断和系统设置跳转功能
 */
class TtsHelperPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "TtsHelperPlugin"
        private const val CHANNEL_NAME = "com.example.android_app/tts_helper"
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        Log.i(TAG, "TtsHelperPlugin attached")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openTtsSettings" -> openTtsSettings(result)
            "installTtsData" -> installTtsData(result)
            "getEnginesInfo" -> getEnginesInfo(result)
            "checkVoiceData" -> checkVoiceData(result)
            else -> result.notImplemented()
        }
    }

    /**
     * 打开系统 TTS 设置页面
     */
    private fun openTtsSettings(result: MethodChannel.Result) {
        try {
            val intents = listOf(
                Intent("com.android.settings.TTS_SETTINGS"),
                Intent("android.settings.TTS_SETTINGS")
            )

            for (intent in intents) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(intent)
                    Log.i(TAG, "Opened TTS settings")
                    result.success(true)
                    return
                }
            }

            // Fallback: open accessibility settings
            val accessibilityIntent = Intent("android.settings.ACCESSIBILITY_SETTINGS")
            accessibilityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (accessibilityIntent.resolveActivity(context.packageManager) != null) {
                context.startActivity(accessibilityIntent)
                Log.i(TAG, "Opened accessibility settings (TTS is in submenu)")
                result.success(true)
                return
            }

            result.success(false)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open TTS settings", e)
            result.success(false)
        }
    }

    /**
     * 打开语音数据安装页面
     */
    private fun installTtsData(result: MethodChannel.Result) {
        try {
            val intent = Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                Log.i(TAG, "Opened TTS data install page")
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open TTS data install", e)
            result.success(false)
        }
    }

    /**
     * 通过 PackageManager 查询已安装的 TTS 引擎（不创建 TextToSpeech 实例）
     */
    private fun getEnginesInfo(result: MethodChannel.Result) {
        try {
            val pm = context.packageManager
            val intent = Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE)
            val resolveInfos = pm.queryIntentServices(intent, 0)

            val engines: MutableList<Map<String, Any>> = mutableListOf()
            for (resolveInfo in resolveInfos) {
                val serviceInfo = resolveInfo.serviceInfo
                val appInfo = serviceInfo.applicationInfo
                val label = pm.getApplicationLabel(appInfo).toString()
                engines.add(mapOf(
                    "packageName" to serviceInfo.packageName,
                    "label" to label
                ))
            }

            Log.i(TAG, "Found ${engines.size} TTS engines")
            result.success(mapOf(
                "engineCount" to engines.size,
                "engines" to engines
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query TTS engines", e)
            result.success(mapOf(
                "engineCount" to 0,
                "engines" to emptyList<Map<String, Any>>(),
                "error" to (e.message ?: "unknown error")
            ))
        }
    }

    /**
     * 检查语音数据可用性（创建临时 TextToSpeech 实例）
     */
    private fun checkVoiceData(result: MethodChannel.Result) {
        Thread {
            var tts: TextToSpeech? = null
            try {
                val latch = CountDownLatch(1)
                var checkResult: Map<String, Any> = emptyMap()

                tts = TextToSpeech(context) { status ->
                    try {
                        if (status == TextToSpeech.SUCCESS) {
                            val ttsInstance = tts
                            if (ttsInstance != null) {
                                val defaultEngine = ttsInstance.defaultEngine
                                val engines = ttsInstance.engines
                                val chineseStatus = ttsInstance.isLanguageAvailable(Locale.SIMPLIFIED_CHINESE)
                                val voices = ttsInstance.voices

                                val chineseVoices: MutableList<Map<String, Any>> = mutableListOf()
                                if (voices != null) {
                                    for (voice in voices) {
                                        val locale = voice.locale
                                        if (locale != null && locale.language == "zh") {
                                            chineseVoices.add(mapOf(
                                                "name" to voice.name,
                                                "locale" to locale.toLanguageTag()
                                            ))
                                        }
                                    }
                                }

                                val engineList: MutableList<Map<String, Any>> = mutableListOf()
                                if (engines != null) {
                                    for (engine in engines) {
                                        engineList.add(mapOf(
                                            "name" to engine.name,
                                            "label" to engine.label
                                        ))
                                    }
                                }

                                val chineseStatusText: String = when (chineseStatus) {
                                    TextToSpeech.LANG_AVAILABLE -> "LANG_AVAILABLE"
                                    TextToSpeech.LANG_COUNTRY_AVAILABLE -> "LANG_COUNTRY_AVAILABLE"
                                    TextToSpeech.LANG_COUNTRY_VAR_AVAILABLE -> "LANG_COUNTRY_VAR_AVAILABLE"
                                    TextToSpeech.LANG_MISSING_DATA -> "LANG_MISSING_DATA (need install)"
                                    TextToSpeech.LANG_NOT_SUPPORTED -> "LANG_NOT_SUPPORTED"
                                    else -> "UNKNOWN($chineseStatus)"
                                }

                                checkResult = mapOf(
                                    "initStatus" to "SUCCESS",
                                    "defaultEngine" to (defaultEngine ?: "unknown"),
                                    "engineCount" to engineList.size,
                                    "engines" to engineList,
                                    "chineseStatus" to chineseStatus,
                                    "chineseStatusText" to chineseStatusText,
                                    "voiceCount" to (voices?.size ?: 0),
                                    "chineseVoices" to chineseVoices,
                                    "isChineseAvailable" to (chineseStatus != TextToSpeech.LANG_NOT_SUPPORTED),
                                    "needInstallData" to (chineseStatus == TextToSpeech.LANG_MISSING_DATA)
                                )

                                Log.i(TAG, "Voice data check: $checkResult")
                            }
                        } else {
                            checkResult = mapOf(
                                "initStatus" to "ERROR",
                                "error" to "TTS init failed (status=$status)",
                                "isChineseAvailable" to false,
                                "needInstallData" to true
                            )
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Voice data check error", e)
                        checkResult = mapOf(
                            "initStatus" to "ERROR",
                            "error" to "check error: ${e.message}",
                            "isChineseAvailable" to false,
                            "needInstallData" to true
                        )
                    } finally {
                        latch.countDown()
                    }
                }

                latch.await(5, TimeUnit.SECONDS)

                try {
                    tts?.shutdown()
                } catch (_) {}

                if (checkResult.isEmpty()) {
                    checkResult = mapOf(
                        "initStatus" to "TIMEOUT",
                        "error" to "TTS init timeout (5s)",
                        "isChineseAvailable" to false,
                        "needInstallData" to true
                    )
                }

                val finalResult = checkResult
                Handler(Looper.getMainLooper()).post {
                    result.success(finalResult)
                }
            } catch (e: Exception) {
                Log.e(TAG, "checkVoiceData exception", e)
                try {
                    tts?.shutdown()
                } catch (_) {}
                Handler(Looper.getMainLooper()).post {
                    result.success(mapOf(
                        "initStatus" to "ERROR",
                        "error" to "exception: ${e.message}",
                        "isChineseAvailable" to false,
                        "needInstallData" to true
                    ))
                }
            }
        }.start()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Log.i(TAG, "TtsHelperPlugin detached")
    }
}
