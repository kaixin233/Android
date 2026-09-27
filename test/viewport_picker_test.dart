import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:android_app/utils/viewport_picker.dart';

void main() {
  // 三段：100~200 / 200~300 / 300~400
  final rects = <Rect>[
    const Rect.fromLTWH(0, 100, 300, 100),
    const Rect.fromLTWH(0, 200, 300, 100),
    const Rect.fromLTWH(0, 300, 300, 100),
  ];

  test('y 落在某段内 → 返回该段', () {
    expect(pickIndexAtOffset(rects, 100), 0);
    expect(pickIndexAtOffset(rects, 150), 0);
    expect(pickIndexAtOffset(rects, 200), 1);
    expect(pickIndexAtOffset(rects, 299), 1);
    expect(pickIndexAtOffset(rects, 350), 2);
  });

  test('y 落在两段之间的间隙 → 返回下方最近的一段', () {
    final gapped = <Rect>[
      const Rect.fromLTWH(0, 100, 300, 50), // 100~150
      const Rect.fromLTWH(0, 200, 300, 50), // 200~250
    ];
    expect(pickIndexAtOffset(gapped, 170), 1);
  });

  test('y 在所有段之上 → 返回第一段', () {
    expect(pickIndexAtOffset(rects, 0), 0);
  });

  test('y 在所有段之下 → 返回最后一段', () {
    expect(pickIndexAtOffset(rects, 9999), 2);
  });

  test('空列表 → -1', () {
    expect(pickIndexAtOffset(const <Rect>[], 100), -1);
  });

  test('未构建元素（Rect.zero）不干扰定位', () {
    final withZero = <Rect>[
      Rect.zero, // 未构建（滚出缓存区）
      const Rect.fromLTWH(0, 200, 300, 100),
      const Rect.fromLTWH(0, 300, 300, 100),
    ];
    expect(pickIndexAtOffset(withZero, 250), 1);
    expect(pickIndexAtOffset(withZero, 350), 2);
  });
}
