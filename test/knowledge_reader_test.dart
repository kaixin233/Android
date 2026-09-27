import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/services/knowledge_reader.dart';
import 'package:android_app/services/knowledge_service.dart';

KnowledgeSection _sec(String number, String title, List<String> paras) =>
    KnowledgeSection(
      number: number,
      title: title,
      paragraphs: [for (final t in paras) KnowledgeParagraph(text: t)],
    );

Future<void> _tick([int n = 4]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late List<String> spoken;
  late List<Completer<bool>> gates;
  late KnowledgeReaderController reader;

  setUp(() {
    spoken = [];
    gates = [];
    reader = KnowledgeReaderController(
      speak: (text, {waitForCompletion = false}) {
        spoken.add(text);
        final c = Completer<bool>();
        gates.add(c);
        return c.future;
      },
      stopSpeaker: () async {},
    );
  });

  tearDown(() => reader.dispose());

  final sections = [
    _sec('1.1', '第一节', ['甲。乙。']), // 标题 + 2 句
    _sec('1.2', '第二节', ['丙。']), // 标题 + 1 句
  ];

  test('顺序朗读：逐句推进，读完自动回到 idle', () async {
    reader.loadSections(sections);
    final f = reader.startFrom(0, untilSection: 1); // 仅第一节
    await _tick();

    expect(reader.state, ReaderState.playing);
    expect(spoken.first, '第一节');
    expect(reader.currentSectionIndex, 0);

    // 逐句放行
    for (var i = 0; i < 10 && reader.state == ReaderState.playing; i++) {
      if (gates.length > i) gates[i].complete(true);
      await _tick();
    }
    await f;
    expect(spoken, ['第一节', '甲。', '乙。']);
    expect(reader.state, ReaderState.idle);
    expect(reader.progress, 0);
  });

  test('暂停保留位置，继续从当前句重读', () async {
    reader.loadSections(sections);
    final f = reader.startFrom(0, untilSection: 1);
    await _tick();
    expect(spoken, ['第一节']);

    gates[0].complete(true);
    await _tick();
    expect(spoken.last, '甲。');

    // 播放中暂停：游标停在"甲。"
    await reader.pause();
    gates[1].complete(false); // 引擎停止 → speak 以 false 返回
    await _tick();
    await f;

    expect(reader.state, ReaderState.paused);
    expect(reader.currentSentence, '甲。');

    // 继续：重读"甲。"（游标未前进）
    final f2 = reader.resume();
    await _tick();
    expect(spoken.last, '甲。');
    await reader.stop();
    gates.last.complete(false);
    await _tick();
    await f2;
    expect(reader.state, ReaderState.idle);
  });

  test('stop 复位并失效正在运行的循环', () async {
    reader.loadSections(sections);
    final f = reader.startFrom(0);
    await _tick();
    await reader.stop();
    expect(reader.state, ReaderState.idle);
    gates.first.complete(false);
    await _tick();
    await f;
    expect(reader.state, ReaderState.idle);
  });

  test('同一范围再次 startFrom 等价于暂停/继续切换', () async {
    reader.loadSections(sections);
    final f = reader.startFrom(0, untilSection: 1);
    await _tick();
    // 再次 startFrom 同范围 → 暂停
    unawaited(reader.startFrom(0, untilSection: 1));
    await _tick();
    expect(reader.state, ReaderState.paused);
    gates.first.complete(false);
    await _tick();
    await f;
  });

  test('小节进度：当前句序号与总句数', () async {
    reader.loadSections(sections);
    final f = reader.startFrom(0, untilSection: 1);
    await _tick();
    expect(reader.currentSectionUnitCount, 3); // 标题 + 2 句
    expect(reader.currentUnitInSection, 0);
    gates[0].complete(true);
    await _tick();
    expect(reader.currentUnitInSection, 1);
    await reader.stop();
    gates.last.complete(false);
    await _tick();
    await f;
  });

  test('连续失败 3 次后自动结束（不卡死）', () async {
    reader.loadSections(sections);
    final f = reader.startFrom(0, untilSection: 1);
    await _tick();
    for (var i = 0; i < 6 && reader.state != ReaderState.idle; i++) {
      if (gates.length > i) gates[i].complete(false);
      await _tick();
    }
    await f;
    expect(reader.state, ReaderState.idle);
  });

  test('setAnchorSection 供"从当前位置朗读"使用', () {
    reader.loadSections(sections);
    reader.setAnchorSection(1);
    expect(reader.currentSectionIndex, 1);
  });

  test('从指定小节开始朗读：首句必须是该小节的内容（而非从头）', () async {
    reader.loadSections(sections);
    final f = reader.startFrom(1); // 从第二节开始
    await _tick();
    expect(spoken.first, '第二节'); // 不是"第一节"
    expect(reader.currentSectionIndex, 1);
    await reader.stop();
    gates.last.complete(false);
    await _tick();
    await f;
  });

  test('playAllFromStart 语义：startFrom(0) 从第一节开始', () async {
    reader.loadSections(sections);
    final f = reader.startFrom(0);
    await _tick();
    expect(spoken.first, '第一节');
    await reader.stop();
    gates.last.complete(false);
    await _tick();
    await f;
  });
}
