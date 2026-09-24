import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_app_installer/flutter_app_installer.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// GitHub 发布版本更新信息
class UpdateInfo {
  const UpdateInfo({
    required this.tagName,
    required this.version,
    this.releaseNotes,
    this.apkUrl,
    this.publishedAt,
    this.isPrerelease = false,
    this.htmlUrl,
    this.buildNumber,
  });

  final String tagName;

  /// 归一化后的语义化版本（如 1.0.123）
  final String version;
  final String? releaseNotes;
  final String? apkUrl;
  final DateTime? publishedAt;
  final bool isPrerelease;
  final String? htmlUrl;

  /// 从版本号末段推断的构建号（如 1.0.123 → 123），用于同级版本比较
  final int? buildNumber;
}

/// 更新检查结果
class UpdateCheckResult {
  const UpdateCheckResult({this.hasUpdate = false, this.info, this.error});

  final bool hasUpdate;
  final UpdateInfo? info;

  /// 错误信息（网络/限流/解析失败）；为空表示成功
  final String? error;
}

/// GitHub 自动更新服务
///
/// 设计要点：
/// - 使用 releases 列表接口（含预发布），而非 /releases/latest（后者会排除预发布，
///   而本项目的 CI 默认打 prerelease，用 /latest 会 404）。
/// - 只接受 tag 可解析为语义化版本（vX.Y.Z）的发布，自动跳过旧的 build-N 等非语义化 tag。
/// - 版本比较基于 versionName 的语义化三段；若版本相同再用 buildNumber 兜底。
/// - 下载走 http 流式读取以报告进度；安装走 flutter_app_installer（需
///   REQUEST_INSTALL_PACKAGES 权限，插件自带 FileProvider）。
class UpdateService {
  UpdateService._();

  static const String _repoOwner = 'kaixin233';
  static const String _repoName = 'Android';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases?per_page=20';

  /// 检查是否有新版本。
  ///
  /// [currentVersion] 为 package_info_plus 的 version（如 "1.0.8"）。
  /// [currentBuildNumber] 为 buildNumber（如 9）。
  /// 返回结果中包含是否可更新、最新发布信息、或错误原因。
  static Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
    int? currentBuildNumber,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final response = await c
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 403) {
        return const UpdateCheckResult(error: 'GitHub 接口限流，请稍后再试');
      }
      if (response.statusCode == 429) {
        return const UpdateCheckResult(error: 'GitHub 接口请求过于频繁，请稍后再试');
      }
      if (response.statusCode != 200) {
        return UpdateCheckResult(error: '检查更新失败（HTTP ${response.statusCode}）');
      }
      return parseReleasesJson(
        response.body,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
      );
    } on TimeoutException {
      return const UpdateCheckResult(error: '检查更新超时，请检查网络');
    } catch (e) {
      return UpdateCheckResult(error: '检查更新失败：$e');
    } finally {
      if (client == null) c.close();
    }
  }

  /// 纯函数：解析 releases JSON，挑选最新、含 APK、且 tag 为语义化版本的发布，
  /// 并与当前版本比较。可单独单测（无需网络）。
  static UpdateCheckResult parseReleasesJson(
    String jsonBody, {
    required String currentVersion,
    int? currentBuildNumber,
  }) {
    try {
      final decoded = jsonDecode(jsonBody);
      final list = decoded is List ? decoded : const <dynamic>[];
      final info = selectLatestRelease(list);
      if (info == null) {
        return const UpdateCheckResult(hasUpdate: false);
      }
      final cmp = compareVersions(info.version, currentVersion);
      final hasUpdate = cmp > 0 ||
          (cmp == 0 &&
              currentBuildNumber != null &&
              info.buildNumber != null &&
              info.buildNumber! > currentBuildNumber);
      return UpdateCheckResult(hasUpdate: hasUpdate, info: info);
    } catch (e) {
      return UpdateCheckResult(error: '解析更新信息失败：$e');
    }
  }

  /// 从发布列表（API 默认按发布时间倒序）中挑选第一个：
  /// 含 .apk 资产 且 tag 可解析为语义化版本。
  ///
  /// 复制列表后按 published_at 倒序排序，确保"最新"判断不受接口排序变化影响。
  static UpdateInfo? selectLatestRelease(List<dynamic> releases) {
    final sorted = List<dynamic>.from(releases);
    sorted.sort((a, b) {
      final ta = DateTime.tryParse((a['published_at'] as String?) ?? '');
      final tb = DateTime.tryParse((b['published_at'] as String?) ?? '');
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1; // 无发布时间的排后面
      if (tb == null) return -1;
      return tb.compareTo(ta); // 新的在前
    });

    for (final r in sorted) {
      final map = r as Map<String, dynamic>;
      final tag = (map['tag_name'] as String?) ?? '';
      final version = _normalizeTag(tag);
      if (version == null) continue; // 跳过非语义化 tag（如旧 build-N）

      final assets = (map['assets'] as List<dynamic>?) ?? <dynamic>[];
      String? apkUrl;
      for (final a in assets) {
        final am = a as Map<String, dynamic>;
        final name = (am['name'] as String? ?? '').toLowerCase();
        final ct = (am['content_type'] as String? ?? '').toLowerCase();
        final isApk = name.endsWith('.apk') ||
            (ct.contains('android') && ct.contains('package-archive'));
        if (isApk) {
          apkUrl = am['browser_download_url'] as String?;
          break;
        }
      }
      if (apkUrl == null) continue; // 该发布无 APK，跳过

      final published = map['published_at'] != null
          ? DateTime.tryParse(map['published_at'] as String)
          : null;
      final body = map['body'] as String?;
      return UpdateInfo(
        tagName: tag,
        version: version,
        releaseNotes: (body?.trim().isEmpty ?? true) ? null : body,
        apkUrl: apkUrl,
        publishedAt: published,
        isPrerelease: map['prerelease'] as bool? ?? false,
        htmlUrl: map['html_url'] as String?,
        buildNumber: _buildNumberFromVersion(version),
      );
    }
    return null;
  }

  /// 归一化 tag 为语义化版本号（去掉前导 v/V，取首个 x.y.z）。
  /// 无法识别（如 build-123）返回 null。
  static String? _normalizeTag(String tag) {
    var t = tag.trim();
    if (t.toLowerCase().startsWith('v')) t = t.substring(1);
    final m = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(t);
    return m?.group(1);
  }

  static int? _buildNumberFromVersion(String version) {
    final parts = version.split('.');
    if (parts.length >= 3) return int.tryParse(parts[2]);
    return null;
  }

  /// 语义化版本比较：a 新于 b 返回正数，相同返回 0，a 旧于 b 返回负数。
  static int compareVersions(String a, String b) {
    final pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final n = pa.length > pb.length ? pa.length : pb.length;
    while (pa.length < n) pa.add(0);
    while (pb.length < n) pb.add(0);
    for (var i = 0; i < n; i++) {
      if (pa[i] != pb[i]) return pa[i] - pb[i];
    }
    return 0;
  }

  /// 下载 APK 到应用私有目录，[onProgress] 报告 0~1 进度。
  /// 返回本地文件路径。失败抛出异常。
  static Future<String> downloadApk(
    String url, {
    Function(double progress)? onProgress,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await c.send(request).timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw Exception('下载失败：HTTP ${response.statusCode}');
      }

      final total = response.contentLength ?? 0;
      final dir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final filePath =
          '${dir.path}/android_app_update_${DateTime.now().millisecondsSinceEpoch}.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.close();

      if (received == 0) {
        throw Exception('下载内容为空');
      }
      return filePath;
    } finally {
      if (client == null) c.close();
    }
  }

  /// 调用系统安装器安装 APK（非静默，会弹出系统安装界面）。
  /// 需要 Android 8+ 已授予"允许安装未知应用"权限。
  /// 成功返回 true；失败（如权限未授予、文件无效）返回 false。
  static Future<bool> installApk(String path) async {
    try {
      final installer = FlutterAppInstaller();
      await installer.installApk(filePath: path);
      return true;
    } catch (e) {
      debugPrint('安装 APK 失败: $e');
      return false;
    }
  }

  /// 兜底：用浏览器打开 GitHub 发布页（无 APK 或未授权安装时引导用户手动更新）。
  static Future<bool> openReleasePage(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('打开发布页失败: $e');
      return false;
    }
  }
}
