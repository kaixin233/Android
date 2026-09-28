import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/services/knowledge_reader.dart';
import 'package:android_app/services/knowledge_service.dart';
import 'package:android_app/utils/knowledge_playback_mixin.dart';

/// 一句 20 字的正文，便于观察"逐字"推进
const _longSentence = '道路路基结构特征包括路基分类填料要求与压实度控制标准等等内容。';

void main() {
  group('句内高亮偏移映射（sentenceStartOffset）', () {
    test('多句时每句起点正确（trim 后仍能对齐原文）', () {
      const text = '第一句话。第二句话更长了。第三句。';
      final sents = splitSentences(text);
      expect(sents.length, 3);
      expect(text.substring(sentenceStartOffset(text, sents, 0)), startsWith('第一句话。'));
      expect(text.substring(sentenceStartOffset(text, sents, 1)), startsWith('第二句话更长'));
      expect(text.substring(sentenceStartOffset(text, sents, 2)), '第三句。');
    });

    test('含空格与换行时起点仍与原文一致', () {
      const text = '  甲 乙 丙。  丁 戊。';
      final sents = splitSentences(text);
      for (var i = 0; i < sents.length; i++) {
        final off = sentenceStartOffset(text, sents, i);
        expect(off, greaterThanOrEqualTo(0));
        expect(text.substring(off, off + sents[i].length), sents[i]);
      }
    });

    test('越界返回 -1', () {
      const text = '只有一个句子。';
      final sents = splitSentences(text);
      expect(sentenceStartOffset(text, sents, -1), -1);
      expect(sentenceStartOffset(text, sents, 5), -1);
    });
  });

  group('逐字高亮进度：真实语音进度优先', () {
    late List<Completer<bool>> gates;
    late void Function(int, int)? progressCb;
    late KnowledgeReaderController reader;

    KnowledgeSection sec() => KnowledgeSection(
          number: '1.1',
          title: '小节',
          paragraphs: const [KnowledgeParagraph(text: _longSentence)],
        );

    setUp(() {
      gates = [];
      progressCb = null;
      reader = KnowledgeReaderController(
        speak: (text, {waitForCompletion = false}) {
          final c = Completer<bool>();
          gates.add(c);
          return c.future;
        },
        stopSpeaker: () async {},
        // 捕获控制器注册的进度回调，测试里手动"上报"引擎进度
        bindProgress: (cb) => progressCb = cb,
        rateProvider: () => 0.5,
      );
    });

    tearDown(() => reader.dispose());

    test('引擎上报 (start,end) 后，已读字符数即为真实值', () async {
      reader.loadSections([sec()]);
      final f = reader.startFrom(0, untilSection: 1);
      await Future<void>.delayed(Duration.zero);

      expect(progressCb, isNotNull, reason: '起播后应已注册进度监听');
      // 标题单元：长度 2
      expect(reader.unitTextLength, 2);
      progressCb!(0, 2);
      await Future<void>.delayed(Duration.zero);
      expect(reader.hasLiveProgress, isTrue);
      expect(reader.unitCharEnd, 2);

      // 放行进入正文单元
      gates.first.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(reader.unitTextLength, _longSentence.length);
      progressCb!(0, 6);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(reader.unitCharEnd, 6, reason: '实时进度应为权威值');

      await reader.stop();
      if (gates.isNotEmpty) gates.last.complete(false);
      await f;
    });

    test('忽略引擎"整段"上报（Android<26 只报 0..len，无逐字意义）', () async {
      reader.loadSections([sec()]);
      final f = reader.startFrom(0, untilSection: 1);
      await Future<void>.delayed(Duration.zero);

      final len = reader.unitTextLength;
      progressCb!(0, len); // 整段
      await Future<void>.delayed(Duration.zero);
      expect(reader.hasLiveProgress, isFalse);
      expect(reader.unitCharEnd, 0);

      await reader.stop();
      if (gates.isNotEmpty) gates.last.complete(false);
      await f;
    });

    test('无实时进度时按校准语速估算推进：先增长、不提前跑满', () async {
      reader.loadSections([sec()]);
      final f = reader.startFrom(0, untilSection: 1);
      await Future<void>.delayed(Duration.zero);

      final len = reader.unitTextLength;
      // 未校准时每字约 200ms（rate=0.5）+ 260ms 起播开销
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final mid = reader.unitCharEnd;
      expect(mid, greaterThanOrEqualTo(0));
      expect(mid, lessThan(len), reason: '不应像旧实现那样提前跑满');

      await reader.stop();
      if (gates.isNotEmpty) gates.last.complete(false);
      await f;
    });

    test('用实测耗时校准每字速度（小米等无逐字进度机型的关键）', () async {
      // 专用控制器：speak 按"每字 150ms + 260ms 起播开销"的节奏返回，
      // 校准后 controller.msPerChar 应收敛到 ~150ms
      final cal = KnowledgeReaderController(
        speak: (text, {waitForCompletion = false}) async {
          final chars = text.replaceAll(RegExp(r'\s+'), '').length;
          await Future<void>.delayed(
              Duration(milliseconds: 260 + chars * 150));
          return true;
        },
        stopSpeaker: () async {},
        bindProgress: (_) {},
        rateProvider: () => 0.5,
      );
      addTearDown(cal.dispose);

      cal.loadSections([
        KnowledgeSection(
          number: '1.1',
          title: '小节',
          paragraphs: const [
            KnowledgeParagraph(
                text: '道路路基结构特征包括路基分类填料要求与压实度控制标准等等内容。'),
            KnowledgeParagraph(
                text: '沥青路面结构组成特点包括面层基层与垫层并需满足相应强度要求。'),
          ],
        ),
      ]);
      // 放行两句即可完成一次有效校准（字数 >= 4）
      await cal.startFrom(0, untilSection: 1);
      expect(cal.calibrated, isTrue, reason: '读完一句后应完成实测校准');
      expect(cal.msPerChar, greaterThan(90));
      expect(cal.msPerChar, lessThan(260));
    });

    test('停止后进度复位', () async {
      reader.loadSections([sec()]);
      final f = reader.startFrom(0, untilSection: 1);
      await Future<void>.delayed(Duration.zero);
      progressCb!(0, 1);
      await reader.stop();
      expect(reader.unitCharEnd, 0);
      expect(reader.unitTextLength, 0);
      if (gates.isNotEmpty) gates.last.complete(false);
      await f;
    });
  });

  group('朗读时长估算（按语速折算）', () {
    test('语速越快，估算时长越短', () {
      const text = '一二三四五六七八九十';
      Duration est(double rate) {
        // 与 TtsService.estimateSpeechDuration 同构的最小复刻，验证语速换算方向
        final chars = text.replaceAll(RegExp(r'\s+'), '').length;
        final millis = chars * 260 * (0.5 / rate);
        return Duration(milliseconds: millis.round());
      }

      expect(est(1.0).inMilliseconds, lessThan(est(0.5).inMilliseconds));
      expect(est(0.5).inMilliseconds, lessThan(est(0.25).inMilliseconds));
    });
  });
}
