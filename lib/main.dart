import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Material 3 Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material 3 App'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '欢迎',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '这是一个更像真实 Android 应用的 Material 3 页面示例。',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('开始使用'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.dashboard_rounded, color: theme.colorScheme.onPrimaryContainer),
            ),
            title: const Text('仪表盘'),
            subtitle: const Text('查看应用状态和实时数据'),
            trailing: const Icon(Icons.chevron_right_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            onTap: () {},
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.settings_rounded, color: theme.colorScheme.onSecondaryContainer),
            ),
            title: const Text('设置'),
            subtitle: const Text('管理通知和个性化配置'),
            trailing: const Icon(Icons.chevron_right_rounded),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            onTap: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: const Text('新增'),
      ),
    );
  }
}
