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
 *
 * 方法：
 * - openTtsSettings: 打开系统 TTS 设置页面
 * - installTtsData: 打开语音数据安装页面
 * - getEnginesInfo: 通过 PackageManager 查询已安装的 TTS 引擎
 * - checkVoiceData: 创建临时 TextToSpeech 实例检查语音数据可用性
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
        Log.i(TAG, "TtsHelperPlugin 已挂载")
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
     * 小米设备路径：设置 → 更多设置 → 无障碍 → 文字转语音输出
     */
    private fun openTtsSettings(result: MethodChannel.Result) {
        try {
            // 尝试多种 Intent，适配不同厂商
            val intents = listOf(
                Intent("com.android.settings.TTS_SETTINGS"),
                Intent("android.settings.TTS_SETTINGS"),
                Intent().apply {
                    action = "android.speech.tts.engine.config.TTS_SETTINGS"
                }
            )

            for (intent in intents) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(intent)
                    Log.i(TAG, "已打开 TTS 设置页面")
                    result.success(true)
                    return
                }
            }

            // 如果以上 Intent 都不行，尝试直接打开无障碍设置
            val accessibilityIntent = Intent("android.settings.ACCESSIBILITY_SETTINGS")
            accessibilityIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (accessibilityIntent.resolveActivity(context.packageManager) != null) {
                context.startActivity(accessibilityIntent)
                Log.i(TAG, "已打开无障碍设置页面（TTS 设置在其中的子菜单）")
                result.success(true)
                return
            }

            Log.w(TAG, "未找到 TTS 设置 Activity")
            result.success(false)
        } catch (e: Exception) {
            Log.e(TAG, "打开 TTS 设置失败", e)
            result.success(false)
        }
    }

    /**
     * 打开语音数据安装页面
     * 用于引导用户下载/安装中文语音包
     */
    private fun installTtsData(result: MethodChannel.Result) {
        try {
            val intent = Intent(TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                Log.i(TAG, "已打开语音数据安装页面")
                result.success(true)
            } else {
                Log.w(TAG, "未找到语音数据安装 Activity")
                result.success(false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "打开语音数据安装页面失败", e)
            result.success(false)
        }
    }

    /**
     * 通过 PackageManager 查询已安装的 TTS 引擎
     * 不创建 TextToSpeech 实例，不会干扰 flutter_tts 插件
     */
    private fun getEnginesInfo(result: MethodChannel.Result) {
        try {
            val pm = context.packageManager
            val intent = Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE)
            val resolveInfos = pm.queryIntentServices(intent, 0)

            val engines = resolveInfos.map { resolveInfo ->
                val serviceInfo = resolveInfo.serviceInfo
                val appInfo = serviceInfo.applicationInfo
                mapOf(
                    "packageName" to serviceInfo.packageName,
                    "label" to pm.getApplicationLabel(appInfo).toString(),
                    "enabled" to resolveInfo.isEnabled
                )
            }

            Log.i(TAG, "查询到 ${engines.size} 个 TTS 引擎: $engines")
            result.success(mapOf(
                "engineCount" to engines.size,
                "engines" to engines
            ))
        } catch (e: Exception) {
            Log.e(TAG, "查询 TTS 引擎失败", e)
            result.success(mapOf(
                "engineCount" to 0,
                "engines" to emptyList<Any>(),
                "error" to (e.message ?: "未知错误")
            ))
        }
    }

    /**
     * 检查语音数据可用性
     * 创建一个临时 TextToSpeech 实例，检查中文语音数据状态后立即关闭
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

                                val chineseVoices = voices?.filter {
                                    it.locale?.language == "zh"
                                }?.map {
                                    mapOf(
                                        "name" to it.name,
                                        "locale" to (it.locale?.toLanguageTag() ?: "unknown"),
                                        "quality" to when (it.quality) {
                                            TextToSpeech.VOICE_QUALITY_VERY_HIGH -> "VERY_HIGH"
                                            TextToSpeech.VOICE_QUALITY_HIGH -> "HIGH"
                                            TextToSpeech.VOICE_QUALITY_NORMAL -> "NORMAL"
                                            TextToSpeech.VOICE_QUALITY_LOW -> "LOW"
                                            TextToSpeech.VOICE_QUALITY_VERY_LOW -> "VERY_LOW"
                                            else -> "UNKNOWN"
                                        }
                                    )
                                } ?: emptyList<Any>()

                                val chineseStatusText = when (chineseStatus) {
                                    TextToSpeech.LANG_AVAILABLE -> "LANG_AVAILABLE (语言可用，但可能无语音数据)"
                                    TextToSpeech.LANG_COUNTRY_AVAILABLE -> "LANG_COUNTRY_AVAILABLE (语言和国家可用)"
                                    TextToSpeech.LANG_COUNTRY_VAR_AVAILABLE -> "LANG_COUNTRY_VAR_AVAILABLE (完全可用)"
                                    TextToSpeech.LANG_MISSING_DATA -> "LANG_MISSING_DATA (缺少语音数据，需要安装)"
                                    TextToSpeech.LANG_NOT_SUPPORTED -> "LANG_NOT_SUPPORTED (不支持中文)"
                                    else -> "UNKNOWN($chineseStatus)"
                                }

                                checkResult = mapOf(
                                    "initStatus" to "SUCCESS",
                                    "defaultEngine" to (defaultEngine ?: "unknown"),
                                    "engineCount" to (engines?.size ?: 0),
                                    "engines" to (engines?.map {
                                        mapOf("name" to it.name, "label" to it.label)
                                    } ?: emptyList<Any>()),
                                    "chineseStatus" to chineseStatus,
                                    "chineseStatusText" to chineseStatusText,
                                    "voiceCount" to (voices?.size ?: 0),
                                    "chineseVoices" to chineseVoices,
                                    "isChineseAvailable" to (chineseStatus != TextToSpeech.LANG_NOT_SUPPORTED),
                                    "needInstallData" to (chineseStatus == TextToSpeech.LANG_MISSING_DATA)
                                )

                                Log.i(TAG, "语音数据检查结果: $checkResult")
                            }
                        } else {
                            checkResult = mapOf(
                                "initStatus" to "ERROR",
                                "error" to "TTS 引擎初始化失败 (status=$status)",
                                "isChineseAvailable" to false,
                                "needInstallData" to true
                            )
                            Log.e(TAG, "TTS 引擎初始化失败: status=$status")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "语音数据检查异常", e)
                        checkResult = mapOf(
                            "initStatus" to "ERROR",
                            "error" to "检查异常: ${e.message}",
                            "isChineseAvailable" to false,
                            "needInstallData" to true
                        )
                    } finally {
                        latch.countDown()
                    }
                }

                // 等待初始化回调，最多5秒
                latch.await(5, TimeUnit.SECONDS)

                // 关闭临时实例
                try {
                    tts?.shutdown()
                } catch (_) {}

                // 如果超时
                if (checkResult.isEmpty()) {
                    checkResult = mapOf(
                        "initStatus" to "TIMEOUT",
                        "error" to "TTS 引擎初始化超时（5秒），设备可能未安装可用的 TTS 引擎",
                        "isChineseAvailable" to false,
                        "needInstallData" to true
                    )
                }

                // 在主线程返回结果
                val finalResult = checkResult
                Handler(Looper.getMainLooper()).post {
                    result.success(finalResult)
                }
            } catch (e: Exception) {
                Log.e(TAG, "checkVoiceData 异常", e)
                try {
                    tts?.shutdown()
                } catch (_) {}
                Handler(Looper.getMainLooper()).post {
                    result.success(mapOf(
                        "initStatus" to "ERROR",
                        "error" to "检查异常: ${e.message}",
                        "isChineseAvailable" to false,
                        "needInstallData" to true
                    ))
                }
            }
        }.start()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        Log.i(TAG, "TtsHelperPlugin 已卸载")
    }
}
