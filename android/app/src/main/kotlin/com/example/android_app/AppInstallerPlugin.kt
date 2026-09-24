package com.example.android_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 应用内更新安装插件。
 *
 * 解决"下载 APK 后点击安装却弹出 GitHub app"的问题：之前依赖第三方插件 +
 * 失败兜底打开 GitHub 链接，会被 GitHub app 接管。这里改为直接用系统安装器 Intent
 * 安装本地 APK：
 *  - APK 通过自身 FileProvider 生成 content:// URI（Android 7+ 禁止 file:// 暴露）；
 *  - 显式指定 MIME `application/vnd.android.package-archive`，确保由系统安装器处理；
 *  - Android 8+ 若未授予"安装未知应用"权限，跳转该权限设置页并返回 permission。
 */
class AppInstallerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AppInstallerPlugin"
        private const val CHANNEL_NAME = "com.example.android_app/app_installer"
        private const val APK_MIME = "application/vnd.android.package-archive"
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        Log.i(TAG, "AppInstallerPlugin attached")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installApk" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrEmpty()) {
                    result.error("INVALID_ARG", "path is null or empty", null)
                } else {
                    result.success(installApk(path))
                }
            }
            "openInstallPermissionSettings" -> result.success(openInstallPermissionSettings())
            "canInstall" -> result.success(canInstall())
            else -> result.notImplemented()
        }
    }

    /** 是否已允许安装未知应用（Android 8+ 需运行时授予） */
    private fun canInstall(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /** 返回 "ok" / "permission" / "failed" */
    private fun installApk(path: String): String {
        return try {
            val file = File(path)
            if (!file.exists() || file.length() <= 0) {
                Log.e(TAG, "APK 不存在或为空: $path")
                return "failed"
            }
            if (!canInstall()) {
                openInstallPermissionSettings()
                return "permission"
            }

            val uri: Uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )

            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, APK_MIME)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            // 部分 ROM 下 ACTION_INSTALL_PACKAGE 更可靠，优先尝试
            val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                data = uri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (installIntent.resolveActivity(context.packageManager) != null) {
                context.startActivity(installIntent)
            } else {
                context.startActivity(viewIntent)
            }
            "ok"
        } catch (e: Exception) {
            Log.e(TAG, "installApk failed", e)
            "failed"
        }
    }

    /** 打开"安装未知应用"授权页（针对本应用） */
    private fun openInstallPermissionSettings(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "openInstallPermissionSettings failed", e)
            false
        }
    }
}
