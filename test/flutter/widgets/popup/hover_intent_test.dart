import 'package:flutter_base/src/flutter/widgets/popup/hover_intent.dart' show HoverIntentMachine;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 悬停意图机器：凸包几何（触发器与弹层之间的桥接走廊）。
///
/// 原来的 `AnchoredShell` 宿主已删除，这里只保留机器本体的几何契约；
/// 宿主层面的悬停开合由 `ElPopup` 的 `hoverIntent` 承担。
void main() {
  group('凸包几何', () {
    test('两矩形凸包包含桥接区点、排除外点', () {
      // 触发器 (100,100,80x40) 与其右下方弹层 (220,220,120x60)。
      const trigger = Rect.fromLTWH(100, 100, 80, 40);
      const popup = Rect.fromLTWH(220, 220, 120, 60);
      final hull = HoverIntentMachine.convexHull([
        trigger.topLeft,
        trigger.topRight,
        trigger.bottomRight,
        trigger.bottomLeft,
        popup.topLeft,
        popup.topRight,
        popup.bottomRight,
        popup.bottomLeft,
      ]);
      // 对角桥接区中点（两矩形之间的斜线走廊内）。
      expect(HoverIntentMachine.pointInConvexPolygon(const Offset(200, 180), hull), isTrue);
      // 两矩形内部照常包含。
      expect(HoverIntentMachine.pointInConvexPolygon(const Offset(140, 120), hull), isTrue);
      expect(HoverIntentMachine.pointInConvexPolygon(const Offset(280, 250), hull), isTrue);
      // 走廊之外（左下远角 / 右上远角）。
      expect(HoverIntentMachine.pointInConvexPolygon(const Offset(100, 300), hull), isFalse);
      expect(HoverIntentMachine.pointInConvexPolygon(const Offset(400, 100), hull), isFalse);
    });
  });
}
