import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_service.dart';

/// AI 助手设置页 - 配置 DeepSeek API Key 与模型
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final TextEditingController _keyController = TextEditingController();
  bool _obscureKey = true;
  bool _isSaving = false;
  bool _isTesting = false;
  String _model = AiService.defaultModel;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await AiService.getApiKey();
    final model = await AiService.getModel();
    if (!mounted) return;
    setState(() {
      _keyController.text = key;
      _model = model;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await AiService.saveApiKey(_keyController.text);
    await AiService.saveModel(_model);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _testResult = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除 API Key'),
        content: const Text('清除后将使用 DeepSeek 网页端降级模式提问。确定清除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AiService.clearApiKey();
    if (!mounted) return;
    setState(() {
      _keyController.clear();
      _testResult = null;
    });
  }

  Future<void> _test() async {
    await _save();
    if (!mounted) return;
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    try {
      await AiService.testConnection();
      if (!mounted) return;
      setState(() {
        _testSuccess = true;
        _testResult = '连接成功，API Key 可用';
      });
    } on AiApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testSuccess = false;
        _testResult = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testSuccess = false;
        _testResult = '测试失败：$e';
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('AI 助手设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('DeepSeek API',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '填写 DeepSeek 开放平台的 API Key 后，即可在 App 内直接向 AI 提问，'
                    '回答会自动关联保存到对应的学习条目。未填写时将降级为'
                    '"复制问题 + 打开 DeepSeek 网页端"模式。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: 'sk-...',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _model,
                    decoration: InputDecoration(
                      labelText: '模型',
                      prefixIcon: const Icon(Icons.model_training_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'deepseek-chat',
                        child: Text('deepseek-chat（V3，快速）'),
                      ),
                      DropdownMenuItem(
                        value: 'deepseek-reasoner',
                        child: Text('deepseek-reasoner（R1，深度推理）'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _model = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: Text(_isSaving ? '保存中…' : '保存'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _isTesting || _keyController.text.trim().isEmpty
                                  ? null
                                  : _test,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering_rounded,
                                  size: 18),
                          label: Text(_isTesting ? '测试中…' : '测试连接'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _clear,
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: '清除 Key',
                      ),
                    ],
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _testSuccess
                            ? Colors.green.withValues(alpha: 0.1)
                            : theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testSuccess
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            size: 18,
                            color: _testSuccess
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                fontSize: 13,
                                color: _testSuccess
                                    ? Colors.green.shade800
                                    : theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded,
                      color: Colors.blue),
                  title: const Text('获取 API Key'),
                  subtitle:
                      const Text('前往 DeepSeek 开放平台注册并创建 Key（需充值额度）'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => launchUrl(
                    Uri.parse('https://platform.deepseek.com/api_keys'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.public_rounded, color: Colors.teal),
                  title: const Text('DeepSeek 网页端'),
                  subtitle: const Text('未配置 Key 时，可复制问题后在此粘贴提问'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => launchUrl(
                    Uri.parse(AiService.webUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '说明：API Key 仅保存在本机应用私有存储中，不会上传或分享。'
              '调用 DeepSeek API 会产生少量费用，由 DeepSeek 平台按 token 计费。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
