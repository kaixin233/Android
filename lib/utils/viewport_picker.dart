import 'dart:ui' show Rect;

/// 从一组"元素矩形"中选出屏幕顶部所在的元素下标。
///
/// 用于"从当前位置朗读"：把当前视口顶部 Y 传进来，返回正在显示的那一段。
/// 规则（按优先级）：
/// 1. 覆盖 [y] 的元素（`top <= y < bottom`）——最精确；
/// 2. 否则取 [y] 下方最近的元素（视口顶部落在两段之间的间隙/图片上时）；
/// 3. 都在上方则取最后一个；
/// 4. 空列表返回 -1。
///
/// 纯函数，便于单测。
int pickIndexAtOffset(List<Rect> rects, double y) {
  if (rects.isEmpty) return -1;
  var bestBelow = -1;
  var bestBelowTop = double.infinity;
  for (var i = 0; i < rects.length; i++) {
    final r = rects[i];
    if (r.top <= y && r.bottom > y) return i;
    if (r.top > y && r.top < bestBelowTop) {
      bestBelowTop = r.top;
      bestBelow = i;
    }
  }
  if (bestBelow >= 0) return bestBelow;
  return rects.length - 1;
}
