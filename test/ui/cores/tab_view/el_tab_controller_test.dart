import 'package:flutter_base/ui.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller clamps initial index and jump target', () {
    final controller = ElTabController(length: 3, initialIndex: 8);

    expect(controller.index, 2);
    expect(controller.position, 2);

    controller.jumpTo(-4);

    expect(controller.index, 0);
    expect(controller.position, 0);

    controller.dispose();
  });

  test('controller animateTo delegates to attached tab view', () async {
    final calls = <int>[];
    final controller = ElTabController(length: 3);
    Future<void> animate(int index, {Duration? duration, Curve? curve}) async {
      calls.add(index);
    }

    controller.attach(animateTo: animate, jumpTo: (_) {});

    await controller.animateTo(2);

    expect(calls, <int>[2]);

    controller.detach(animateTo: animate, jumpTo: (_) {});
    controller.dispose();
  });

  test('controller length changes clamp index and position', () {
    final controller = ElTabController(length: 5, initialIndex: 4);

    controller.debugSetLength(2);

    expect(controller.length, 2);
    expect(controller.index, 1);
    expect(controller.position, 1);

    controller.dispose();
  });
}
