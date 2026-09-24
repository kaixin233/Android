import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsService.preprocessText 括号处理（Bug2 修复）', () {
    test('全角圆括号：去括号保留内容', () {
      expect(TtsService.preprocessText('施工项目管理的（首要）任务是安全'),
          '施工项目管理的首要任务是安全');
    });

    test('空全角圆括号读作"什么"（填空位）', () {
      expect(TtsService.preprocessText('填空（）应读作什么'), contains('什么'));
    });

    test('半角圆括号同样处理', () {
      expect(TtsService.preprocessText('示例(内容)演示'), '示例内容演示');
      expect(TtsService.preprocessText('空()括号'), contains('什么'));
    });

    test('书名号《》不再被误读为一美元，应去掉并保留内部文字', () {
      // 修复前：preprocessText 未剥离《》，TTS 会把书名号当括号读成"一美元"并吞掉内容
      expect(TtsService.preprocessText('详见《建设工程质量管理条例》的规定'),
          '详见建设工程质量管理条例的规定');
    });

    test('龟甲括号〔〕、单角括号〈〉被剥离', () {
      expect(TtsService.preprocessText('参见〔注释一〕说明'), '参见注释一说明');
      expect(TtsService.preprocessText('标记〈注意〉此处'), '标记注意此处');
    });

    test('直角引号「」、双角引号『』被剥离', () {
      expect(TtsService.preprocessText('他说「开始」了'), '他说开始了');
      expect(TtsService.preprocessText('标题『重要』通知'), '标题重要通知');
    });

    test('方头/方括号【】【】〖〗及半角 [] 被剥离', () {
      expect(TtsService.preprocessText('选项【A】正确'), '选项A正确');
      expect(TtsService.preprocessText('代码[x]示例'), '代码x示例');
      expect(TtsService.preprocessText('注〖说明〗完毕'), '注说明完毕');
    });

    test('全角小圆括号﹙﹚被剥离', () {
      expect(TtsService.preprocessText('﹙备注﹚内容'), '备注内容');
    });

    test('综合：书名号与多层括号混合', () {
      final out = TtsService.preprocessText('根据《规范》第（三）条〔附则〕要求');
      expect(out, '根据规范第三条附则要求');
    });

    test('回归：替换结果不得残留字面量美元记号（会被语音引擎读成"美元"）', () {
      // 历史 bug：String.replaceAll(RegExp, r'$1') 不展开捕获组，会原样输出 "$1"，
      // 语音引擎把 "$" 读成"美元"→ 出现"一美元"。修复为 replaceAllMapped。
      final out = TtsService.preprocessText('根据（甲乙丙）的规定，应该（）。');
      expect(out, isNot(contains(r'$')));
      expect(out, contains('甲乙丙'));
      expect(out, contains('什么'));
    });
  });

  group('TtsService.shouldShowTtsErrorDialog 节流（Bug3 弹窗频繁修复）', () {
    test('初始可展示；展示后置为不可见；关闭后 30s 内仍抑制', () {
      // 初始状态：从未展示过，应允许展示
      expect(TtsService.shouldShowTtsErrorDialog(), isTrue);

      // 标记已展示 -> 去重，不应再次弹出模态弹窗
      TtsService.markTtsErrorDialogShown();
      expect(TtsService.shouldShowTtsErrorDialog(), isFalse);

      // 用户关闭弹窗 -> 仍在 30s 间隔内，应继续抑制（降级为轻量提示）
      TtsService.markTtsErrorDialogClosed();
      expect(TtsService.shouldShowTtsErrorDialog(), isFalse);
    });

    test('展示中再次查询被去重抑制', () {
      TtsService.markTtsErrorDialogShown();
      expect(TtsService.shouldShowTtsErrorDialog(), isFalse);
      TtsService.markTtsErrorDialogClosed();
    });
  });
}
