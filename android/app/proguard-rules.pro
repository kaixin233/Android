-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 保守保留常用插件入口，避免 R8 误删（反射/方法通道相关类）
-keep class com.tekartik.file_picker.** { *; }
-keep class com.lyc.file_picker.** { *; }
-keep class path_provider.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class dev.flutter.plugins.** { *; }

# WebView / TTS 等相关类不要被 R8 误删
-keep class androidx.webkit.** { *; }

# 忽略 Flutter 动态特性（Play Core / App Bundle）相关缺失类。
# 本项目仅打单文件 APK、不上架 Play 商店，不依赖 deferred components，可安全忽略。
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
