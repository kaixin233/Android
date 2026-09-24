import 'package:flutter/material.dart';

import '../services/update_service.dart';

/// 更新提示对话框：展示新版本信息，支持一键下载并安装。
///
/// [auto] 为 true 表示由"启动自动检测"触发；此时仍允许用户关闭（稍后处理）。
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
        await _openBrowser();
        return;
      }
      final path = await UpdateService.downloadApk(
        apkUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _downloading = false);

      final installed = await UpdateService.installApk(path);
      if (!mounted) return;
      if (installed) {
        // 系统安装器已拉起，关闭本弹窗
        Navigator.of(context).pop();
      } else {
        // 安装未成功启动（常见于未授予"允许安装未知应用"权限），引导去浏览器
        await _openBrowser();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载失败：$e';
        });
      }
    }
  }

  Future<void> _openBrowser() async {
    final url = info.htmlUrl ?? 'https://github.com/kaixin233/Android/releases';
    final ok = await UpdateService.openReleasePage(url);
    if (!ok && mounted) {
      setState(() => _error = '无法打开浏览器，请前往发布页手动更新');
    } else if (mounted) {
      Navigator.of(context).pop();
    }
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
        if (_error != null)
          TextButton(
            onPressed: _downloading ? null : _openBrowser,
            child: const Text('去浏览器下载'),
          ),
        FilledButton(
          onPressed: _downloading ? null : _downloadAndInstall,
          child: Text(_downloading ? '下载中...' : '立即更新'),
        ),
      ],
    );
  }
}
