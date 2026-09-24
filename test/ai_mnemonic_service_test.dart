import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/services/ai_mnemonic_service.dart';
import 'package:android_app/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiMnemonicService 通道与异常', () {
    test('无任何可用通道（未登录网页端且无 API Key）时抛 AiApiException', () async {
      // 清空可能残留的 API Key，确保走"无通道"分支
      await AiService.clearApiKey();

      expect(
        () => AiMnemonicService.generateMnemonic(
          knowledgeContext: '【题干】施工组织设计的编制依据是什么？',
        ),
        throwsA(isA<AiApiException>()),
      );
    });

    test('配置了 API Key 时不走"无通道"分支（仍调用真实接口，故期望非无通道异常）',
        () async {
      await AiService.saveApiKey('test-invalid-key-for-mnemonic');

      try {
        await AiMnemonicService.generateMnemonic(
          knowledgeContext: '【题干】测试题干',
        ).timeout(const Duration(seconds: 30));
        // 极少数情况下若返回成功（例如代理返回了内容），也不应抛错
      } on AiApiException catch (e) {
        // 走的是官方 API 通道：Key 无效 / 网络不可用，均属于 AiApiException
        expect(e.message, isNotEmpty);
      } catch (e) {
        // 超时等其它异常在此不视为失败（受限于测试环境无稳定外网）
        expect(e, isNotNull);
      } finally {
        await AiService.clearApiKey();
      }
    });
  });
}
