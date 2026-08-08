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
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _themeMode = _parseThemeMode(provider.themeMode);
        _isInitialized = true;
      });
    });
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

  Future<void> _setThemeMode(String mode) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.saveThemeMode(mode);
    setState(() {
      _themeMode = _parseThemeMode(mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: Stack(
        children: <Widget>[
          HomePage(
            themeMode: _themeMode.name,
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