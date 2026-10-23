import 'package:flutter/material.dart';
import 'package:flutter_base/flutter.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('列表条目使用事件后代 context 切换背景并只触发一次点击', (tester) async {
    TestGesture? mouse;
    var down = false;
    var taps = 0;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 240,
              child: ElChildIndex(
                index: 0,
                end: 0,
                child: MyListTile(title: '交互条目', onPressed: () => taps++),
              ),
            ),
          ),
        ),
      );
      final tile = find.byType(MyListTile);
      Color? background() => tester
          .widget<ElView>(
            find.descendant(of: tile, matching: find.byType(ElView)).first,
          )
          .style
          .backgroundColor;
      expect(background(), isNull);
      final position = tester.getCenter(tile);
      mouse = await tester.createGesture(kind: .mouse);
      await mouse.addPointer(location: Offset(500, 500));
      await mouse.moveTo(position);
      await tester.pump();
      expect(background(), Colors.grey.shade100);
      await mouse.down(position);
      down = true;
      await tester.pump();
      expect(background(), Colors.grey.shade300);
      await mouse.up();
      down = false;
      await tester.pump();
      expect(background(), Colors.grey.shade100);
      expect(taps, 1);
      await mouse.moveTo(Offset(500, 500));
      await tester.pump();
      expect(background(), isNull);
    } finally {
      if (down) await mouse?.cancel();
      await mouse?.removePointer();
      await tester.pumpWidget(SizedBox.shrink());
    }
  });
}
