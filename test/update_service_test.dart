import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/services/update_service.dart';

void main() {
  group('UpdateService.compareVersions 语义化比较', () {
    test('a 新于 b 返回正数', () {
      expect(UpdateService.compareVersions('1.0.9', '1.0.8') > 0, isTrue);
      expect(UpdateService.compareVersions('1.1.0', '1.0.9') > 0, isTrue);
      expect(UpdateService.compareVersions('2.0.0', '1.9.9') > 0, isTrue);
    });
    test('相同返回 0', () {
      expect(UpdateService.compareVersions('1.0.8', '1.0.8'), 0);
    });
    test('a 旧于 b 返回负数', () {
      expect(UpdateService.compareVersions('1.0.7', '1.0.8') < 0, isTrue);
    });
  });

  group('UpdateService.parseReleasesJson 选取最新含 APK 的语义化发布', () {
    test('跳过 build-N 旧 tag，选中语义化发布', () {
      final json = jsonEncode([
        {
          'tag_name': 'build-123',
          'published_at': '2024-01-01T00:00:00Z',
          'assets': [
            {'name': 'app-release.apk', 'browser_download_url': 'https://x/apk1'}
          ]
        },
        {
          'tag_name': 'v1.0.9',
          'published_at': '2024-02-01T00:00:00Z',
          'assets': [
            {'name': 'app-release.apk', 'browser_download_url': 'https://x/apk2'}
          ]
        },
      ]);
      final res = UpdateService.parseReleasesJson(json, currentVersion: '1.0.8');
      expect(res.hasUpdate, isTrue);
      expect(res.info?.version, '1.0.9');
      expect(res.info?.apkUrl, 'https://x/apk2');
    });

    test('无 APK 的发布被跳过', () {
      final json = jsonEncode([
        {
          'tag_name': 'v1.0.9',
          'published_at': '2024-02-01T00:00:00Z',
          'assets': <dynamic>[]
        },
      ]);
      final res = UpdateService.parseReleasesJson(json, currentVersion: '1.0.8');
      expect(res.hasUpdate, isFalse);
      expect(res.info, isNull);
    });

    test('已是最新时 hasUpdate 为 false', () {
      final json = jsonEncode([
        {
          'tag_name': 'v1.0.8',
          'published_at': '2024-02-01T00:00:00Z',
          'assets': [
            {'name': 'app-release.apk', 'browser_download_url': 'https://x/apk'}
          ]
        },
      ]);
      final res = UpdateService.parseReleasesJson(json, currentVersion: '1.0.8');
      expect(res.hasUpdate, isFalse);
    });

    test('挑选 published_at 最新的语义化发布', () {
      final json = jsonEncode([
        {
          'tag_name': 'v1.0.7',
          'published_at': '2024-01-01T00:00:00Z',
          'assets': [
            {'name': 'a.apk', 'browser_download_url': 'https://x/old'}
          ]
        },
        {
          'tag_name': 'v1.0.9',
          'published_at': '2024-03-01T00:00:00Z',
          'assets': [
            {'name': 'b.apk', 'browser_download_url': 'https://x/new'}
          ]
        },
      ]);
      final res = UpdateService.parseReleasesJson(json, currentVersion: '1.0.8');
      expect(res.info?.version, '1.0.9');
      expect(res.info?.apkUrl, 'https://x/new');
    });

    test('解析发布时正确填充 tagName / version / htmlUrl / isPrerelease', () {
      final json = jsonEncode([
        {
          'tag_name': 'v1.0.9',
          'published_at': '2024-03-01T00:00:00Z',
          'html_url': 'https://github.com/kaixin233/Android/releases/tag/v1.0.9',
          'prerelease': true,
          'assets': [
            {'name': 'app-release.apk', 'browser_download_url': 'https://x/apk'}
          ]
        },
      ]);
      final res = UpdateService.parseReleasesJson(json, currentVersion: '1.0.8');
      expect(res.info?.tagName, 'v1.0.9');
      expect(res.info?.version, '1.0.9');
      expect(res.info?.isPrerelease, isTrue);
      expect(res.info?.htmlUrl,
          'https://github.com/kaixin233/Android/releases/tag/v1.0.9');
    });

    test('空列表 / 非法 JSON 不抛错', () {
      final empty = UpdateService.parseReleasesJson('[]', currentVersion: '1.0.8');
      expect(empty.hasUpdate, isFalse);
      expect(empty.error, isNull);

      final bad = UpdateService.parseReleasesJson('not json', currentVersion: '1.0.8');
      expect(bad.hasUpdate, isFalse);
      expect(bad.error, isNotNull);
    });
  });
}
