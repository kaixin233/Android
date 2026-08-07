import 'package:flutter/material.dart';

import '../services/ai_service.dart';

/// AI 助手设置页
///
/// 主用：DeepSeek 网页端 Token（免费，直接调用 chat.deepseek.com 后端）。
/// 备用：官方 API Key（api.deepseek.com，按 token 计费）。
class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _proxyController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  bool _obscureToken = true;
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
    final token = await AiService.getWebToken();
    final proxy = await AiService.getProxyUrl();
    final key = await AiService.getApiKey();
    final model = await AiService.getModel();
    if (!mounted) return;
    setState(() {
      _tokenController.text = token;
      _proxyController.text = proxy;
      _keyController.text = key;
      _model = model;
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _proxyController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await AiService.saveWebToken(_tokenController.text);
    await AiService.saveProxyUrl(_proxyController.text);
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

  Future<void> _clearToken() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除网页端 Token'),
        content: const Text('清除后将不再使用网页端免费通道。确定清除吗？'),
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
    await AiService.clearWebToken();
    if (!mounted) return;
    setState(() {
      _tokenController.clear();
      _proxyController.clear();
      _testResult = null;
    });
  }

  Future<void> _clearKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除 API Key'),
        content: const Text('清除后若没有网页端 Token，将无法使用 AI 问答。确定清除吗？'),
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
      final label = await AiService.activeProviderLabel();
      setState(() {
        _testSuccess = true;
        _testResult = '连接成功（$label）';
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
          // 网页端 Token（主用）
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('网页端 Token（免费，优先）',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: _clearToken,
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: '清除 Token',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '从电脑浏览器登录 chat.deepseek.com，打开开发者工具 → '
                    'Application → Cookies，复制 userToken 的值。App 会直接调用'
                    '网页端接口对话，无需跳转网页、免费使用。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tokenController,
                    obscureText: _obscureToken,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: '网页端 Token (userToken)',
                      hintText: '粘贴 chat.deepseek.com 的 userToken',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureToken
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                        onPressed: () =>
                            setState(() => _obscureToken = !_obscureToken),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _proxyController,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: '反代地址（可选）',
                      hintText: '如直连失败（PoW/风控），填自托管地址，如 http://192.168.x.x:8000',
                      prefixIcon: const Icon(Icons.hub_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 官方 API Key（备用）
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
                      Text('官方 API Key（备用）',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: _clearKey,
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: '清除 Key',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '若没有网页端 Token，或希望使用更稳定、有额度的通道，可填写官方 '
                    'API Key（api.deepseek.com，按 token 计费）。未填写网页端 Token 时生效。',
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                  onPressed: _isTesting ? null : _test,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 18),
                  label: Text(_isTesting ? '测试中…' : '测试连接'),
                ),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '说明：网页端 Token / API Key 仅保存在本机应用私有存储中，不会上传或分享。'
              '网页端接口为非官方接口，可能随官网改版变化；官方 API 调用会产生少量费用，'
              '由 DeepSeek 平台按 token 计费。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
