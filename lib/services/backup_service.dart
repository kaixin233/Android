import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'annotation_store.dart';
import 'storage_service.dart';

/// 本地自动备份：把题库/记录/收藏/批注等打包写入应用私有目录（Documents/backups）。
///
/// 个人项目不上云，用"应用私有目录 + 周期备份"替代云同步，防重装/误清数据丢失。
String _pad(int n) => n < 10 ? '0$n' : '$n';

class BackupService {
  /// 最多保留的自动备份份数，超出后删除最旧的，避免备份文件无限增长占满存储。
  static const int _keepBackups = 20;

  /// 备份目录（应用私有，USB/文件管理器可取出）。
  static Future<Directory> backupDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 立即执行一次备份；返回生成的文件。
  static Future<File> backupNow() async {
    await AnnotationStore.ensureLoaded();
    final data = await StorageService.exportAllData();
    final annotations = AnnotationStore.exportJson();
    final dir = await backupDir();
    final now = DateTime.now();
    final ts =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}';
    final file = File('${dir.path}/auto_backup_$ts.json');
    // 用 Map 拼写 JSON，避免字符串拼接导致的脆弱性（data / annotations 均为合法 JSON 对象）
    final payload = {
      'backupAt': now.toIso8601String(),
      'data': jsonDecode(data),
      'annotations': jsonDecode(annotations),
    };
    await file.writeAsString(jsonEncode(payload));
    await StorageService.saveLastAutoBackup(now.millisecondsSinceEpoch);
    await _pruneOldBackups(dir);
    return file;
  }

  /// 仅保留最近 [_keepBackups] 份自动备份，删除最旧的，防止备份无限堆积。
  static Future<void> _pruneOldBackups(Directory dir) async {
    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('auto_backup_'))
          .toList();
      files.sort((a, b) => a.path.compareTo(b.path));
      while (files.length > _keepBackups) {
        await files.removeAt(0).delete();
      }
    } catch (_) {
      // 清理失败不影响本次备份
    }
  }

  /// 启动后按需触发：开启自动备份且距上次超过 7 天则备份。
  static Future<void> runIfNeeded() async {
    try {
      final enabled = await StorageService.loadAutoBackupEnabled();
      if (!enabled) return;
      final last = await StorageService.loadLastAutoBackup();
      final now = DateTime.now().millisecondsSinceEpoch;
      const week = 7 * 24 * 60 * 60 * 1000;
      if (last == 0 || now - last > week) {
        await backupNow();
      }
    } catch (_) {
      // 备份失败不影响正常使用
    }
  }
}
