import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../models/history_item.dart';
import '../services/storage_service.dart';
import 'knowledge_assessment_page.dart';
import 'note_page.dart';

/// 我的页面 - 个人中心，包含设置、数据导出等
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onThemeChanged});

  final Future<void> Function(String mode) onThemeChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final progress = (app.completedChapters / 12).clamp(0.0, 1.0);
    final totalQuestions = app.history.fold<int>(0, (s, h) => s + h.totalCount);
    final totalCorrect = app.history.fold<int>(0, (s, h) => s + h.correctCount);
    final accuracy = totalQuestions == 0 ? 0.0 : totalCorrect / totalQuestions;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.person_rounded,
                            size: 36, color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('一建备考学员',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('已学习 ${app.completedChapters}/12 章',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress, minHeight: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 统计概览
          Row(
            children: [
              _statCard('累计答题', '$totalQuestions', Icons.quiz_rounded, Colors.blue, theme),
              const SizedBox(width: 12),
              _statCard('正确率', '${(accuracy * 100).toStringAsFixed(0)}%', Icons.trending_up_rounded, Colors.green, theme),
              const SizedBox(width: 12),
              _statCard('练习次数', '${app.history.length}', Icons.history_rounded, Colors.orange, theme),
            ],
          ),
          const SizedBox(height: 16),
          // 主题设置
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_rounded),
                  title: const Text('主题模式'),
                  trailing: DropdownButton<String>(
                    value: app.themeMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                      DropdownMenuItem(value: 'light', child: Text('浅色')),
                      DropdownMenuItem(value: 'dark', child: Text('深色')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await widget.onThemeChanged(value);
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded),
                  title: const Text('答题震动反馈'),
                  subtitle: const Text('正确和错误时使用不同震动模式'),
                  value: app.vibrationEnabled,
                  onChanged: (value) {
                    context.read<AppProvider>().saveVibrationEnabled(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 学习工具
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('学习工具', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.sticky_note_2_rounded, color: Colors.yellow),
                  title: const Text('学习笔记'),
                  subtitle: const Text('记录重点、疑问和总结'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotePage())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.radar_rounded, color: Colors.purple),
                  title: const Text('知识点评估'),
                  subtitle: const Text('查看知识点掌握程度'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KnowledgeAssessmentPage())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 数据管理
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('数据管理', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.blue),
                  title: const Text('导出全部数据'),
                  subtitle: const Text('导出题库、记录、收藏为 JSON 文件'),
                  onTap: _exportData,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload_rounded, color: Colors.green),
                  title: const Text('导入数据'),
                  subtitle: const Text('从备份文件恢复数据'),
                  onTap: _importData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 最近记录
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('最近练习', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                if (app.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Text('暂无练习记录', style: TextStyle(color: Colors.grey)),
                  )
                else
                  ...app.history.reversed.take(5).map((h) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 6,
                          backgroundColor: h.accuracy >= 0.8
                              ? Colors.green
                              : h.accuracy >= 0.6
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        title: Text(h.title),
                        subtitle: Text(
                          '${h.mode.label} · ${h.correctCount}/${h.totalCount} · ${h.accuracyText} · ${h.durationText}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 关于
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('关于'),
                  subtitle: const Text('一级建造师学习助手 v1.0.2'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: '一级建造师学习',
                      applicationVersion: '1.0.2',
                      applicationLegalese: '© 2026',
                      children: [
                        const SizedBox(height: 12),
                        const Text('一款专为一级建造师考试打造的学习助手，包含题库、错题本、考试模式、电子教材等功能。'),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    try {
      final data = await StorageService.exportAllData();
      final bytes = utf8.encode(data);
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '导出数据',
        fileName: 'yijian_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: bytes,
      );
      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据已导出')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      final jsonString = utf8.decode(bytes);
      await StorageService.importAllData(jsonString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据导入成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }
}