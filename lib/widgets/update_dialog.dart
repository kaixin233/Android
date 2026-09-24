import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/update_service.dart';

/// 更新提示对话框：展示新版本信息，支持一键下载并安装。
///
/// [auto] 为 true 表示由"启动自动检测"触发；此时仍允许用户关闭（稍后处理）。
///
/// 安装说明：下载后调用原生安装通道（系统安装器）。**不再**在安装失败时自动打开
/// GitHub 发布页——那会被已安装的 GitHub app 接管，导致"点安装却打开 GitHub"。
/// 改为：权限不足时引导授权，失败时提供「重试安装」与「复制下载链接」。
class UpdateDialog {
  const UpdateDialog._();

  static Future<void> showUpdateDialog(
    BuildContext context,
    UpdateInfo info, {
    bool auto = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _UpdateDialogContent(info: info, auto: auto),
    );
  }
}

class _UpdateDialogContent extends StatefulWidget {
  const _UpdateDialogContent({required this.info, required this.auto});

  final UpdateInfo info;
  final bool auto;

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  double _progress = 0;
  bool _downloading = false;
  String? _error;

  /// 最近一次下载成功的 APK 路径，用于失败后"重试安装"（避免重新下载）
  String? _lastApkPath;

  UpdateInfo get info => widget.info;

  Future<void> _downloadAndInstall() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      final apkUrl = info.apkUrl;
      if (apkUrl == null || apkUrl.isEmpty) {
        setState(() {
          _downloading = false;
          _error = '该版本未提供 APK 下载地址';
        });
        return;
      }
      final path = await UpdateService.downloadApk(
        apkUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      _lastApkPath = path;
      setState(() => _downloading = false);
      await _install(path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载失败：$e';
        });
      }
    }
  }

  /// 调用系统安装器安装已下载的 APK
  Future<void> _install(String path) async {
    final result = await UpdateService.installApk(path);
    if (!mounted) return;
    switch (result) {
      case AppInstallResult.ok:
        // 系统安装器已拉起，关闭本弹窗
        Navigator.of(context).pop();
        break;
      case AppInstallResult.permissionRequired:
        await _showPermissionDialog();
        break;
      case AppInstallResult.failed:
        setState(() => _error =
            '无法启动系统安装程序。可点击「重试安装」；若仍失败，请复制下载链接在浏览器中下载安装。');
        break;
    }
  }

  /// 引导用户授予"安装未知应用"权限（Android 8+）
  Future<void> _showPermissionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('需要授权安装')),
          ],
        ),
        content: const Text(
          '系统要求先允许本应用「安装未知应用」。\n\n'
          '点击「去授权」后，打开开关「允许来自此来源的应用」，'
          '再返回本页面点击「重试安装」即可。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await UpdateService.openInstallPermissionSettings();
            },
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  /// 复制下载链接（替代"打开 GitHub 页"——避免被 GitHub app 接管）
  Future<void> _copyDownloadLink() async {
    final url = (info.apkUrl ?? '').isNotEmpty
        ? info.apkUrl!
        : (info.htmlUrl ?? '');
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制下载链接，可在浏览器中打开下载安装')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = info.releaseNotes;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      title: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.auto ? '发现新版本 v${info.version}' : '版本更新',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最新版本：v${info.version}（当前标签 ${info.tagName}）',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (notes != null && notes.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: Text(
                      notes,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
              ),
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress, minHeight: 6),
              const SizedBox(height: 6),
              Text(
                '下载中 ${(_progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('稍后'),
        ),
        if (_error != null && _lastApkPath != null)
          TextButton(
            onPressed: _downloading ? null : () => _install(_lastApkPath!),
            child: const Text('重试安装'),
          ),
        TextButton(
          onPressed: _downloading ? null : _copyDownloadLink,
          child: const Text('复制下载链接'),
        ),
        FilledButton(
          onPressed: _downloading ? null : _downloadAndInstall,
          child: Text(_downloading ? '下载中...' : '立即更新'),
        ),
      ],
    );
  }
}
