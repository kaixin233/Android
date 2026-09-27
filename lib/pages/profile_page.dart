import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../models/history_item.dart';
import '../services/storage_service.dart';
import '../services/backup_service.dart';
import '../services/tts_service.dart';
import '../widgets/update_dialog.dart';
import 'knowledge_assessment_page.dart';
import 'note_page.dart';
import 'ai_settings_page.dart';
import 'ai_qa_history_page.dart';

/// 我的页面 - 个人中心，包含设置、数据导出等
///
/// 布局原则：**分组折叠 + 状态摘要**。每组卡片折叠时在副标题里直接显示当前状态
/// （如"已开启 · 语速 1.0 · 音量 100%"），既简洁又不必逐项展开查看。
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

    final app = context.read<AppProvider>();
    await TtsService.applySpeechParams(
      rate: app.ttsSpeechRate,
      pitch: app.ttsPitch,
      volume: app.ttsVolume,
    );

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

  String _themeLabel(String mode) {
    switch (mode) {
      case 'light':
        return '浅色';
      case 'dark':
        return '深色';
      case 'eyeCare':
        return '护眼';
      default:
        return '跟随系统';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppProvider>();
    final progress = app.totalChapters == 0
        ? 0.0
        : (app.completedChapters / app.totalChapters).clamp(0.0, 1.0);
    final totalAnswered = app.history.fold<int>(0, (s, h) => s + h.totalCount);
    final totalCorrect = app.history.fold<int>(0, (s, h) => s + h.correctCount);
    final accuracy = totalAnswered == 0 ? 0.0 : totalCorrect / totalAnswered;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ===== 用户卡片 =====
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.person_rounded,
                            size: 34,
                            color: theme.colorScheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('二建备考学员',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                                '已学习 ${app.completedChapters}/${app.totalChapters} 章',
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
          const SizedBox(height: 12),

          // ===== 统计概览 =====
          Row(
            children: [
              _statCard('累计答题', '$totalAnswered', Icons.quiz_rounded,
                  Colors.blue, theme),
              const SizedBox(width: 12),
              _statCard('正确率', '${(accuracy * 100).toStringAsFixed(0)}%',
                  Icons.trending_up_rounded, Colors.green, theme),
              const SizedBox(width: 12),
              _statCard('练习次数', '${app.history.length}',
                  Icons.history_rounded, Colors.orange, theme),
            ],
          ),
          const SizedBox(height: 12),

          // ===== 学习目标（常显今日进度） =====
          _SettingsGroup(
            title: '学习目标',
            icon: Icons.flag_rounded,
            color: Colors.teal,
            summary: '目标 ${app.dailyGoalQuestions} 题/天',
            initiallyExpanded: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _buildDailyGoalProgress(app, theme),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: Colors.teal),
                title: const Text('每日练习目标'),
                subtitle: Slider(
                  value: app.dailyGoalQuestions.toDouble(),
                  min: 10,
                  max: 200,
                  divisions: 19,
                  label: '${app.dailyGoalQuestions} 题',
                  onChanged: (value) {
                    context
                        .read<AppProvider>()
                        .saveDailyGoalQuestions(value.round());
                  },
                ),
                trailing: Text('${app.dailyGoalQuestions}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ===== 外观与体验 =====
          _SettingsGroup(
            title: '外观与体验',
            icon: Icons.palette_rounded,
            color: Colors.deepPurple,
            summary: '${_themeLabel(app.themeMode)} · '
                '字号 ${(app.fontScale * 100).toInt()}% · '
                '震动${app.vibrationEnabled ? '开' : '关'}',
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
                leading: const Icon(Icons.text_fields_rounded,
                    color: Colors.blue),
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
                trailing: Text('${(app.fontScale * 100).toInt()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('答题震动反馈'),
                value: app.vibrationEnabled,
                onChanged: (value) {
                  context.read<AppProvider>().saveVibrationEnabled(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ===== 语音播报 =====
          _SettingsGroup(
            title: '语音播报',
            icon: Icons.record_voice_over_rounded,
            color: Colors.teal,
            summary: app.ttsEnabled
                ? '已开启 · 语速 ${app.ttsSpeechRate.toStringAsFixed(1)} · '
                    '音量 ${(app.ttsVolume * 100).toInt()}%'
                : '已关闭（答题与考点朗读均不发声）',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_rounded,
                    color: Colors.teal),
                title: const Text('启用语音播报'),
                value: app.ttsEnabled,
                onChanged: (value) {
                  context.read<AppProvider>().saveTtsEnabled(value);
                },
              ),
              const Divider(height: 1),
              _groupLabel('播报内容', theme),
              SwitchListTile(
                secondary: const Icon(Icons.article_rounded,
                    color: Colors.indigo),
                title: const Text('自动播报解析'),
                value: app.ttsAutoPlayExplanation,
                onChanged: app.ttsEnabled
                    ? (value) {
                        context
                            .read<AppProvider>()
                            .saveTtsAutoPlayExplanation(value);
                      }
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary:
                    const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                title: const Text('答对不播报解析'),
                value: app.ttsSkipExplanationOnCorrect,
                onChanged: (app.ttsEnabled && app.ttsAutoPlayExplanation)
                    ? (value) {
                        context
                            .read<AppProvider>()
                            .saveTtsSkipExplanationOnCorrect(value);
                      }
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary:
                    const Icon(Icons.playlist_play_rounded, color: Colors.indigo),
                title: const Text('自动朗读题目'),
                value: app.ttsAutoReadQuestion,
                onChanged: app.ttsEnabled
                    ? (value) {
                        context
                            .read<AppProvider>()
                            .saveTtsAutoReadQuestion(value);
                      }
                    : null,
              ),
              const Divider(height: 1),
              _groupLabel('声音参数', theme),
              _speechParamTile(
                icon: Icons.speed_rounded,
                color: Colors.blue,
                title: '语速',
                value: app.ttsSpeechRate,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                labelBuilder: (v) =>
                    v < 0.3 ? '慢速' : (v > 0.7 ? '快速' : '正常'),
                trailing: app.ttsSpeechRate.toStringAsFixed(1),
                onChanged: app.ttsEnabled
                    ? (v) => context.read<AppProvider>().saveTtsSpeechRate(v)
                    : null,
              ),
              const Divider(height: 1),
              _speechParamTile(
                icon: Icons.graphic_eq_rounded,
                color: Colors.purple,
                title: '音调',
                value: app.ttsPitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                labelBuilder: (v) =>
                    v < 0.8 ? '低沉' : (v > 1.2 ? '高亢' : '正常'),
                trailing: app.ttsPitch.toStringAsFixed(1),
                onChanged: app.ttsEnabled
                    ? (v) => context.read<AppProvider>().saveTtsPitch(v)
                    : null,
              ),
              const Divider(height: 1),
              _speechParamTile(
                icon: Icons.volume_up_rounded,
                color: Colors.orange,
                title: '音量',
                value: app.ttsVolume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                labelBuilder: (v) => '${(v * 100).toInt()}%',
                trailing: '${(app.ttsVolume * 100).toInt()}%',
                onChanged: app.ttsEnabled
                    ? (v) => context.read<AppProvider>().saveTtsVolume(v)
                    : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  _isTestingVoice
                      ? Icons.stop_circle_rounded
                      : Icons.play_circle_rounded,
                  color: Colors.teal,
                ),
                title: Text(_isTestingVoice ? '停止试听' : '试听语音效果'),
                trailing: const Icon(Icons.chevron_right_rounded),
                enabled: app.ttsEnabled,
                onTap: app.ttsEnabled ? _testVoice : null,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_voice_rounded,
                    color: Colors.grey),
                title: const Text('系统语音引擎设置'),
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
          const SizedBox(height: 12),

          // ===== 练习与考试 =====
          _SettingsGroup(
            title: '练习与考试',
            icon: Icons.fact_check_rounded,
            color: Colors.blue,
            summary: '乱序${app.practiceShuffleQuestions ? '开' : '关'} · '
                '选项乱序${app.practiceShuffleOptions ? '开' : '关'} · '
                '考试 ${app.examQuestionCount} 题/${app.examDurationMinutes} 分',
            children: [
              _groupLabel('练习', theme),
              SwitchListTile(
                secondary: const Icon(Icons.shuffle_rounded, color: Colors.blue),
                title: const Text('题目乱序'),
                value: app.practiceShuffleQuestions,
                onChanged: (value) {
                  context
                      .read<AppProvider>()
                      .savePracticeShuffleQuestions(value);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.swap_horiz_rounded,
                    color: Colors.indigo),
                title: const Text('选项乱序'),
                value: app.practiceShuffleOptions,
                onChanged: (value) {
                  context.read<AppProvider>().savePracticeShuffleOptions(value);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary:
                    const Icon(Icons.skip_next_rounded, color: Colors.green),
                title: const Text('答对后自动下一题'),
                value: app.practiceAutoNext,
                onChanged: (value) {
                  context.read<AppProvider>().savePracticeAutoNext(value);
                },
              ),
              const Divider(height: 1),
              _groupLabel('考试默认', theme),
              ListTile(
                leading: const Icon(Icons.format_list_numbered_rounded,
                    color: Colors.orange),
                title: const Text('默认考试题量'),
                subtitle: Slider(
                  value: app.examQuestionCount.toDouble(),
                  min: 10,
                  max: 50,
                  divisions: 8,
                  label: '${app.examQuestionCount}',
                  onChanged: (value) {
                    context
                        .read<AppProvider>()
                        .saveExamQuestionCount(value.round());
                  },
                ),
                trailing: Text('${app.examQuestionCount}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.timer_rounded, color: Colors.red),
                title: const Text('默认考试时长'),
                subtitle: Slider(
                  value: app.examDurationMinutes.toDouble(),
                  min: 10,
                  max: 120,
                  divisions: 11,
                  label: '${app.examDurationMinutes} 分钟',
                  onChanged: (value) {
                    context
                        .read<AppProvider>()
                        .saveExamDurationMinutes(value.round());
                  },
                ),
                trailing: Text('${app.examDurationMinutes} 分',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ===== 学习工具 =====
          _SettingsGroup(
            title: '学习工具',
            icon: Icons.handyman_rounded,
            color: Colors.deepOrange,
            summary: '口诀${app.aiMnemonicEnabled ? '开' : '关'} · '
                '复习提醒${app.reviewReminderEnabled ? '开' : '关'}',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.indigo),
                title: const Text('AI 考点记忆口诀'),
                value: app.aiMnemonicEnabled,
                onChanged: (value) {
                  context.read<AppProvider>().saveAiMnemonicEnabled(value);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.psychology_alt_rounded,
                    color: Colors.deepOrange),
                title: const Text('复习提醒'),
                value: app.reviewReminderEnabled,
                onChanged: (value) {
                  context.read<AppProvider>().saveReviewReminderEnabled(value);
                },
              ),
              const Divider(height: 1),
              _navTile(
                icon: Icons.sticky_note_2_rounded,
                color: Colors.amber,
                title: '学习笔记',
                page: const NotePage(),
              ),
              const Divider(height: 1),
              _navTile(
                icon: Icons.radar_rounded,
                color: Colors.purple,
                title: '知识点评估',
                page: const KnowledgeAssessmentPage(),
              ),
              const Divider(height: 1),
              _navTile(
                icon: Icons.smart_toy_rounded,
                color: Colors.deepPurple,
                title: 'AI 助手设置',
                page: const AiSettingsPage(),
              ),
              const Divider(height: 1),
              _navTile(
                icon: Icons.forum_rounded,
                color: Colors.indigo,
                title: 'AI 问答记录',
                page: const AiQaHistoryPage(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ===== 数据与关于 =====
          _SettingsGroup(
            title: '数据与关于',
            icon: Icons.storage_rounded,
            color: Colors.teal,
            summary: '自动备份${app.autoBackup ? '开' : '关'} · '
                'v${app.appVersion}'
                '${app.updateAvailable ? '（可更新）' : ''}',
            children: [
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
                onTap: _backupNow,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.blue),
                title: const Text('导出全部数据'),
                onTap: _exportData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_rounded, color: Colors.green),
                title: const Text('导入数据'),
                onTap: _importData,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.system_update_alt_rounded,
                    color: Colors.deepPurple),
                title: const Text('检查更新'),
                subtitle: app.updateAvailable
                    ? Text('发现新版本 v${app.latestUpdate!.version}',
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w600))
                    : Text('当前版本 v${app.appVersion}'),
                trailing: app.updateAvailable
                    ? const Icon(Icons.arrow_circle_up_rounded,
                        color: Colors.green)
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _checkUpdate,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('关于'),
                subtitle: Text('二级建造师学习助手 v${app.appVersion}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showAbout,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ===== 最近练习 =====
          _SettingsGroup(
            title: '最近练习',
            icon: Icons.history_rounded,
            color: Colors.orange,
            summary: app.history.isEmpty ? '暂无记录' : '共 ${app.history.length} 次',
            children: [
              if (app.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text('暂无练习记录', style: TextStyle(color: Colors.grey)),
                )
              else
                ...app.history.reversed.take(5).map((h) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 6,
                        backgroundColor: h.accuracy >= 0.8
                            ? Colors.green
                            : (h.accuracy >= 0.6
                                ? Colors.orange
                                : Colors.red),
                      ),
                      title: Text(h.title),
                      subtitle: Text(
                        '${h.mode.label} · ${h.correctCount}/${h.totalCount} · '
                        '${h.accuracyText} · ${h.durationText}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    final app = context.read<AppProvider>();
    final result = await app.checkForUpdate(manual: true);
    if (!mounted) return;
    if (result.hasUpdate && result.info != null) {
      UpdateDialog.showUpdateDialog(context, result.info!);
    } else if (result.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error!)));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已是最新版本')));
    }
  }

  void _showAbout() {
    final app = context.read<AppProvider>();
    showAboutDialog(
      context: context,
      applicationName: '二级建造师学习',
      applicationVersion: 'v${app.appVersion}',
      applicationLegalese: '© 2026',
      children: const [
        SizedBox(height: 12),
        Text('一款专为二级建造师考试打造的学习助手，'
            '包含题库、错题本、考试模式、电子教材、'
            'AI 学习助手与语音朗读等功能。'),
      ],
    );
  }

  /// 可折叠设置分组：折叠时副标题即为当前状态摘要
  Widget _navTile({
    required IconData icon,
    required Color color,
    required String title,
    required Widget page,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color, ThemeData theme) {
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
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  /// 设置组内小标题，用于把同类选项归组，提升可读性。
  Widget _groupLabel(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// 统一的"声音参数"滑块行：左侧图标、标题 + 滑块、右侧数值。
  /// [onChanged] 为 null 时整行禁用（置灰），用于总开关关闭时收起调节项。
  Widget _speechParamTile({
    required IconData icon,
    required Color color,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) labelBuilder,
    required String trailing,
    required ValueChanged<double>? onChanged,
  }) {
    return ListTile(
      enabled: onChanged != null,
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: labelBuilder(value),
        onChanged: onChanged,
      ),
      trailing: Text(
        trailing,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  /// 学习目标的今日进度：统计今日已完成题数并与目标对比展示。
  Widget _buildDailyGoalProgress(AppProvider app, ThemeData theme) {
    final today = DateTime.now();
    final done = app.history.where((h) {
      final a = h.answeredAt;
      return a.year == today.year &&
          a.month == today.month &&
          a.day == today.day;
    }).fold<int>(0, (s, h) => s + h.totalCount);
    final goal = app.dailyGoalQuestions;
    final ratio = goal <= 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
    final reached = done >= goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('今日已完成 $done 题',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(
              reached ? '已达标' : '目标 $goal 题',
              style: TextStyle(
                color: reached ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: ratio, minHeight: 8),
      ],
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

/// 可折叠设置分组卡片：标题 + 一行状态摘要，展开后显示具体设置项。
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.children,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String summary;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // 去掉 ExpansionTile 展开时的默认分隔线，视觉更干净
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(icon, size: 18, color: color),
          ),
          title: Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          subtitle: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          childrenPadding: EdgeInsets.zero,
          children: children,
        ),
      ),
    );
  }
}
