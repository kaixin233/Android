import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'pages/home_page.dart';
import 'providers/app_provider.dart';
import 'services/tts_service.dart';
import 'services/web_chat_bridge.dart';
import 'widgets/deepseek_login_controls.dart';

void main() {
  // 预热 TTS 引擎，不阻塞应用启动
  TtsService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.initialize();
    if (mounted) setState(() => _isInitialized = true);
  }

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 护眼（米黄）主题：暖色调、低蓝光，适合长时间阅读。
  ThemeData get _eyeCareTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB08968),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5ECD8),
        cardColor: const Color(0xFFFBF4E6),
      );

  ({ThemeData theme, ThemeData darkTheme, ThemeMode mode}) _resolveTheme(String mode) {
    if (mode == 'eyeCare') {
      return (theme: _eyeCareTheme, darkTheme: _eyeCareTheme, mode: ThemeMode.light);
    }
    return (
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      mode: _parseThemeMode(mode),
    );
  }

  Future<void> _setThemeMode(String mode) async {
    // 仅负责持久化；主题由 watch(provider) 响应式刷新
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_rounded, size: 72, color: Colors.green),
                SizedBox(height: 16),
                Text('二级建造师学习',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }

    final resolved = _resolveTheme(provider.themeMode);

    return MaterialApp(
      title: '二级建造师学习',
      debugShowCheckedModeBanner: false,
      // 强制中文界面：选择菜单等系统文案（复制/全选）显示为中文而非英文
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      theme: resolved.theme,
      darkTheme: resolved.darkTheme,
      themeMode: resolved.mode,
      // 全局字号缩放：阅读/题库等所有文字随设置放大或缩小
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(provider.fontScale)),
        child: child!,
      ),
      home: Stack(
        children: <Widget>[
          HomePage(
            themeMode: provider.themeMode,
            onThemeChanged: _setThemeMode,
          ),
          // 常驻网页端 WebView（隐藏保活；登录时全屏可交互）。
          // 与 App 内 AI 助手共享同一已登录会话，避免后台直连被 PoW/风控拦截。
          ValueListenableBuilder<bool>(
            valueListenable: WebChatBridge.instance.visible,
            builder: (context, isVisible, _) => Positioned.fill(
              child: Opacity(
                opacity: isVisible ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !isVisible,
                  child: WebViewWidget(
                    controller: WebChatBridge.instance.controller,
                  ),
                ),
              ),
            ),
          ),
          // 登录控制浮层
          ValueListenableBuilder<bool>(
            valueListenable: WebChatBridge.instance.loginOverlay,
            builder: (context, show, _) =>
                show ? const DeepSeekLoginControls() : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}