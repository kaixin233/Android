import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../models/history_item.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../services/tts_service.dart';
import 'knowledge_assessment_page.dart';
import 'note_page.dart';
import 'ai_settings_page.dart';
import 'ai_qa_history_page.dart';

/// 我的页面 - 个人中心，包含设置、数据导出等
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.onThemeChanged});

  final Future<void> Function(String mode) onThemeChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isTestingVoice = false;

  /// 试听语音效果
  Future<void> _testVoice() async {
    if (_isTestingVoice) {
      await TtsService.stop();
      setState(() => _isTestingVoice = false);
      return;
    }

    setState(() => _isTestingVoice = true);

    // 应用当前设置的语音参数
    final app = context.read<AppProvider>();
    await TtsService.applySpeechParams(
      rate: app.ttsSpeechRate,
      pitch: app.ttsPitch,
      volume: app.ttsVolume,
    );

    // 试听文本：包含括号等需要预处理的场景
    const sampleText = '这是一段语音试听。当题目中出现括号时，会朗读为：什么。'
        '例如：施工项目管理中，什么是首要任务。'
        '解析：施工项目管理的首要任务是安全管理。';

    final success = await TtsService.speak(
      sampleText,
      onComplete: () {
        if (mounted) setState(() => _isTestingVoice = false);
      },
    );

    if (!success && mounted) {
      setState(() => _isTestingVoice = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音播报不可用，请检查系统语音引擎设置')),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_isTestingVoice) {
      TtsService.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final progress = app.totalChapters == 0 ? 0.0 : (app.completedChapters / app.totalChapters).clamp(0.0, 1.0);
    final totalAnswered = app.history.fold<int>(0, (s, h) => s + h.totalCount);
    final totalCorrect = app.history.fold<int>(0, (s, h) => s + h.correctCount);
    final accuracy = totalAnswered == 0 ? 0.0 : totalCorrect / totalAnswered;

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
                            Text('二建备考学员',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('已学习 ${app.completedChapters}/${app.totalChapters} 章',
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
              _statCard('累计答题', '$totalAnswered', Icons.quiz_rounded, Colors.blue, theme),
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
                      DropdownMenuItem(value: 'eyeCare', child: Text('护眼')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await widget.onThemeChanged(value);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.text_fields_rounded, color: Colors.blue),
                  title: const Text('阅读字号'),
                  subtitle: Slider(
                    value: app.fontScale,
                    min: 0.8,
                    max: 1.4,
                    divisions: 12,
                    label: '${(app.fontScale * 100).toInt()}%',
                    onChanged: (value) {
                      context.read<AppProvider>().saveFontScale(
                        double.parse(value.toStringAsFixed(2)),
                      );
                    },
                  ),
                  trailing: Text(
                    '${(app.fontScale * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
          // 语音播报设置
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('语音播报', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.record_voice_over_rounded, color: Colors.teal),
                  title: const Text('自动播报解析'),
                  subtitle: const Text('答题后自动朗读正确答案和解析'),
                  value: app.ttsAutoPlayExplanation,
                  onChanged: (value) {
                    context.read<AppProvider>().saveTtsAutoPlayExplanation(value);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                  title: const Text('答对不播报解析'),
                  subtitle: const Text('回答正确时仅播报"回答正确"，跳过解析'),
                  value: app.ttsSkipExplanationOnCorrect,
                  onChanged: app.ttsAutoPlayExplanation
                      ? (value) {
                          context.read<AppProvider>().saveTtsSkipExplanationOnCorrect(value);
                        }
                      : null,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.playlist_play_rounded, color: Colors.indigo),
                  title: const Text('自动朗读题目'),
                  subtitle: const Text('进入题目时自动语音播报题目内容'),
                  value: app.ttsAutoReadQuestion,
                  onChanged: (value) {
                    context.read<AppProvider>().saveTtsAutoReadQuestion(value);
                  },
                ),
                const Divider(height: 1),
                // 语速调节
                ListTile(
                  leading: const Icon(Icons.speed_rounded, color: Colors.blue),
                  title: const Text('语速'),
                  subtitle: Slider(
                    value: app.ttsSpeechRate,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: app.ttsSpeechRate < 0.3
                        ? '慢速'
                        : app.ttsSpeechRate > 0.7
                            ? '快速'
                            : '正常',
                    onChanged: (value) {
                      context.read<AppProvider>().saveTtsSpeechRate(value);
                    },
                  ),
                  trailing: Text(
                    app.ttsSpeechRate.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const Divider(height: 1),
                // 音调调节
                ListTile(
                  leading: const Icon(Icons.graphic_eq_rounded, color: Colors.purple),
                  title: const Text('音调'),
                  subtitle: Slider(
                    value: app.ttsPitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: app.ttsPitch < 0.8
                        ? '低沉'
                        : app.ttsPitch > 1.2
                            ? '高亢'
                            : '正常',
                    onChanged: (value) {
                      context.read<AppProvider>().saveTtsPitch(value);
                    },
                  ),
                  trailing: Text(
                    app.ttsPitch.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const Divider(height: 1),
                // 音量调节
                ListTile(
                  leading: const Icon(Icons.volume_up_rounded, color: Colors.orange),
                  title: const Text('音量'),
                  subtitle: Slider(
                    value: app.ttsVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(app.ttsVolume * 100).toInt()}%',
                    onChanged: (value) {
                      context.read<AppProvider>().saveTtsVolume(value);
                    },
                  ),
                  trailing: Text(
                    '${(app.ttsVolume * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const Divider(height: 1),
                // 试听语音按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _testVoice,
                      icon: Icon(_isTestingVoice
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_rounded),
                      label: Text(_isTestingVoice ? '停止试听' : '试听语音效果'),
                    ),
                  ),
                ),
                const Divider(height: 1),
                // TTS 系统设置入口
                ListTile(
                  leading: const Icon(Icons.settings_voice_rounded, color: Colors.grey),
                  title: const Text('系统语音引擎设置'),
                  subtitle: const Text('打开系统 TTS 设置页面'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final success = await TtsService.openTtsSettings();
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('无法打开系统语音设置')),
                      );
                    }
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded, color: Colors.deepPurple),
                  title: const Text('AI 助手设置'),
                  subtitle: const Text('配置网页端 Token 或 API Key，选中即问'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsPage())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.forum_rounded, color: Colors.indigo),
                  title: const Text('AI 问答记录'),
                  subtitle: const Text('查看各条目的历史问答'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiQaHistoryPage())),
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
                SwitchListTile(
                  secondary: const Icon(Icons.backup_rounded, color: Colors.teal),
                  title: const Text('自动本地备份'),
                  subtitle: const Text('每周自动备份到应用私有目录'),
                  value: app.autoBackup,
                  onChanged: (value) {
                    context.read<AppProvider>().saveAutoBackup(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_rounded, color: Colors.teal),
                  title: const Text('立即备份'),
                  subtitle: const Text('把题库、记录、收藏、批注备份到本地'),
                  onTap: _backupNow,
                ),
                const Divider(height: 1),
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
                  subtitle: const Text('二级建造师学习助手 v1.0.8'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: '二级建造师学习',
                      applicationVersion: '1.0.6',
                      applicationLegalese: '© 2026',
                      children: [
                        const SizedBox(height: 12),
                        const Text('一款专为二级建造师考试打造的学习助手，包含题库、错题本、考试模式、电子教材等功能。'),
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

  Future<void> _backupNow() async {
    try {
      final file = await BackupService.backupNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已备份到：${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败：$e')),
        );
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final data = await StorageService.exportAllData();
      final bytes = utf8.encode(data);
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '导出数据',
        fileName: 'erjian_backup_${DateTime.now().millisecondsSinceEpoch}.json',
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

      // 刷新 AppProvider 状态，确保 UI 与存储同步
      if (mounted) {
        final provider = context.read<AppProvider>();
        await provider.refresh();
        if (!mounted) return;
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