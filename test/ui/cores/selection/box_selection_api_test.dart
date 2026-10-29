import 'package:flutter_base/ui.dart' show ElStyle, ElView;
import 'package:flutter_base/src/ui/cores/selection/box/box_selection_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  ElBoxSelectionController controller, {
  bool enabled = true,
  ValueChanged<({Set<Object> added, Set<Object> removed, int selectedCount})>? onChanged,
}) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: SizedBox(
      width: 240,
      height: 120,
      child: ElBoxSelectionView(
        enabled: enabled,
        controller: controller,
        autoScroll: false,
        onSelectionChanged: onChanged,
        child: Row(
          children: [
            for (final value in ['a', 'b'])
              ElBoxSelectable(
                value: value,
                style: ElStyle(width: 80, height: 80),
                child: ElView(child: value),
              ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('独立框选只接收鼠标，触摸和手写笔不会修改对象集合', (tester) async {
    final controller = ElBoxSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.stylus]) {
      final gesture = await tester.createGesture(kind: kind);
      await gesture.down(Offset(10, 10));
      await gesture.moveTo(Offset(150, 70));
      await tester.pump();
      await gesture.up();
      await gesture.removePointer();
      await tester.pump();
      expect(controller.selectedValues, isEmpty, reason: '$kind 不进入桌面框选');
    }
  });

  testWidgets('增量回调使用只读记录，历史差集不随后续集合变化', (tester) async {
    final controller = ElBoxSelectionController();
    addTearDown(controller.dispose);
    final changes = <({Set<Object> added, Set<Object> removed, int selectedCount})>[];
    await tester.pumpWidget(_host(controller, onChanged: changes.add));

    controller.select('a');
    await tester.pump();
    controller.deselect('a');
    controller.select('b');
    await tester.pump();

    expect(changes, hasLength(3));
    expect(changes.first.added, {'a'});
    expect(changes.first.removed, isEmpty);
    expect(changes.last.added, {'b'});
    expect(changes[1].removed, {'a'});
    expect(changes.last.removed, isEmpty);
    expect(changes.last.selectedCount, 1);
    expect(() => changes.first.added.add('other'), throwsUnsupportedError);
    expect(() => changes[1].removed.clear(), throwsUnsupportedError);
    expect(controller.selectedValues, {'b'});
  });

  testWidgets('禁用框选只关闭鼠标交互，外部控制器仍可同步稳定值', (tester) async {
    final controller = ElBoxSelectionController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, enabled: false));
    final mouse = await tester.createGesture(kind: .mouse);
    await mouse.down(Offset(10, 10));
    await mouse.moveTo(Offset(150, 70));
    await tester.pump();
    await mouse.up();
    await mouse.removePointer();
    await tester.pump();
    expect(controller.selectedValues, isEmpty);

    controller.select('b');
    await tester.pump();
    expect(controller.selectedValues, {'b'});
    await tester.pumpWidget(_host(controller));
    await tester.pump();
    expect(controller.selectedValues, {'b'}, reason: '重开交互保留业务控制的稳定值');
  });
}
