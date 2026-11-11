import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _Harness {
  final controller = ElPreview2Controller();
  final indexLog = <int>[];
  final events = <String>[];
  double verticalDistance = 0;
  int taps = 0;

  Widget build({int count = 3, bool vertical = false, double spacing = 0}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 400,
        height: 400,
        child: ElPreview2View(
          itemCount: count,
          controller: controller,
          pageSpacing: spacing,
          onTap: () => taps++,
          onIndexChanged: indexLog.add,
          onVerticalDragStart: vertical ? (_) => events.add('start') : null,
          onVerticalDragUpdate: vertical ? (details) => verticalDistance += details.primaryDelta! : null,
          onVerticalDragEnd: vertical ? (_) => events.add('end') : null,
          itemBuilder: (context, index) =>
              ColoredBox(key: ValueKey('item-$index'), color: Color(0xFF000000 + index * 0x303030)),
        ),
      ),
    ),
  );
}

Future<_Harness> _pump(WidgetTester tester, {int count = 3, bool vertical = false, double spacing = 0}) async {
  final harness = _Harness();
  addTearDown(harness.controller.dispose);
  await tester.pumpWidget(harness.build(count: count, vertical: vertical, spacing: spacing));
  return harness;
}

Offset _center(WidgetTester tester) => tester.getCenter(find.byType(ElPreview2View));

Future<void> _doubleTap(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(Duration(milliseconds: 50));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

/// 停住后再抬手，让松手速度为零。
Future<void> _holdAndUp(WidgetTester tester, TestGesture gesture, int t) async {
  await gesture.moveBy(Offset.zero, timeStamp: Duration(milliseconds: t + 300));
  await gesture.up(timeStamp: Duration(milliseconds: t + 316));
  await tester.pumpAndSettle();
}

/// 两指以 [center] 为中心、半径 50 对称落下，按 3° 步进转动，直到当前项旋转越过 [target]。
Future<(TestGesture, TestGesture, double)> _rotateUntil(WidgetTester tester, _Harness h, double target) async {
  final c = _center(tester);
  Offset arm(double angle) => Offset(math.cos(angle), math.sin(angle)) * 50;
  final a = await tester.startGesture(c - arm(0), pointer: 1);
  final b = await tester.startGesture(c + arm(0), pointer: 2);
  final step = target.sign * math.pi / 60;
  var angle = 0.0;
  for (var i = 0; i < 200; i++) {
    final reached = target > 0 ? h.controller.rotation >= target : h.controller.rotation <= target;
    if (reached) break;
    angle += step;
    await a.moveTo(c - arm(angle));
    await b.moveTo(c + arm(angle));
  }
  await tester.pump();
  return (a, b, angle);
}

Future<double> _releaseAndTrack(WidgetTester tester, _Harness h, (TestGesture, TestGesture, double) fingers) async {
  final start = h.controller.rotation;
  await fingers.$1.up();
  await fingers.$2.up();
  await tester.pump();
  await tester.pump(Duration(milliseconds: 60));
  final middle = h.controller.rotation;
  await tester.pumpAndSettle();
  expect(middle, isNot(moreOrLessEquals(start)), reason: '松手后应以动画转到吸附角度');
  return middle;
}

/// 双击中心放大到 2.5 倍，横纵可平移范围均为 300。
Future<void> _zoomAtCenter(WidgetTester tester, _Harness h) async {
  await _doubleTap(tester, _center(tester));
  expect(h.controller.scale, 2.5);
  expect(h.controller.translation, Offset.zero);
}

void main() {
  testWidgets('未缩放单指横滑过半，停住松手吸附到下一项', (tester) async {
    final h = await _pump(tester);
    final gesture = await tester.startGesture(_center(tester));
    var t = 0;
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(Offset(-20, 0), timeStamp: Duration(milliseconds: t += 16));
    }
    await tester.pump();
    expect(h.controller.page.value, moreOrLessEquals(0.6));
    await _holdAndUp(tester, gesture, t);
    expect(h.controller.index, 1);
    expect(h.controller.page.value, 1);
    expect(h.indexLog, [1]);
  });

  testWidgets('不足半页慢速松手回到当前项，快速短滑则翻页', (tester) async {
    final h = await _pump(tester);
    var gesture = await tester.startGesture(_center(tester));
    var t = 0;
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(Offset(-20, 0), timeStamp: Duration(milliseconds: t += 16));
    }
    await _holdAndUp(tester, gesture, t);
    expect(h.controller.index, 0);
    expect(h.controller.page.value, 0);

    gesture = await tester.startGesture(_center(tester));
    t = 1000;
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(-20, 0), timeStamp: Duration(milliseconds: t += 10));
    }
    await gesture.up(timeStamp: Duration(milliseconds: t += 10));
    await tester.pumpAndSettle();
    expect(h.controller.index, 1);
  });

  testWidgets('组件自己排布相邻项：按翻页位置横向平移并保留间隔', (tester) async {
    final h = await _pump(tester, spacing: 16);
    final left = tester.getTopLeft(find.byType(ElPreview2View)).dx;
    final gesture = await tester.startGesture(_center(tester));
    // 步长为 400 + 16，拖动 208 正好半页。
    await gesture.moveBy(Offset(-20, 0));
    await gesture.moveBy(Offset(-188, 0));
    await tester.pump();
    expect(h.controller.page.value, moreOrLessEquals(0.5));
    expect(tester.getTopLeft(find.byKey(ValueKey('item-0'))).dx, moreOrLessEquals(left - 208));
    expect(tester.getTopLeft(find.byKey(ValueKey('item-1'))).dx, moreOrLessEquals(left + 208));
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('翻页拖过半时第二指落下：操作项切到下一项并吸附，捏合缩放的是下一项', (tester) async {
    final h = await _pump(tester);
    final c = _center(tester);
    final a = await tester.startGesture(c, pointer: 1);
    for (var i = 0; i < 12; i++) {
      await a.moveBy(Offset(-20, 0));
    }
    expect(h.controller.page.value, moreOrLessEquals(0.6));
    final b = await tester.startGesture(c + Offset(60, 0), pointer: 2);
    expect(h.controller.index, 1, reason: '更靠近中间的是下一项');
    for (var i = 0; i < 4; i++) {
      await a.moveBy(Offset(-15, 0));
      await b.moveBy(Offset(15, 0));
      await tester.pump(Duration(milliseconds: 16));
    }
    expect(h.controller.scale, greaterThan(1.3));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(h.controller.page.value, 1);
    expect(h.controller.index, 1);
    expect(h.controller.scale, greaterThan(1.3), reason: '缩放保留在下一项上');
  });

  testWidgets('离开某一项并吸附到其他项后，它的缩放复位', (tester) async {
    final h = await _pump(tester);
    final c = _center(tester);
    await _doubleTap(tester, c);
    expect(h.controller.scale, 2.5);
    await tester.pump(Duration(milliseconds: 500));
    h.controller.animateToPage(1);
    await tester.pumpAndSettle();
    h.controller.animateToPage(0);
    await tester.pumpAndSettle();
    expect(h.controller.scale, 1);
  });

  testWidgets('两指先后落下：第一指少量横移后第二指落下仍进入捏合，翻页不动', (tester) async {
    final h = await _pump(tester);
    final c = _center(tester);
    final a = await tester.startGesture(c - Offset(50, 0), pointer: 1);
    await a.moveBy(Offset(-8, 0));
    await a.moveBy(Offset(-8, 0));
    final b = await tester.startGesture(c + Offset(50, 0), pointer: 2);
    for (var i = 0; i < 4; i++) {
      await a.moveBy(Offset(-15, 0));
      await b.moveBy(Offset(15, 0));
    }
    await tester.pump();
    expect(h.controller.scale, greaterThan(1.5));
    expect(h.controller.page.value, 0);
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  });

  testWidgets('缩放模式：先拉开间距后再扭转，旋转保持锁定', (tester) async {
    final h = await _pump(tester);
    final c = _center(tester);
    final a = await tester.startGesture(c - Offset(50, 0), pointer: 1);
    final b = await tester.startGesture(c + Offset(50, 0), pointer: 2);
    for (var i = 0; i < 3; i++) {
      await a.moveBy(Offset(-10, 0));
      await b.moveBy(Offset(10, 0));
    }
    for (var i = 0; i < 4; i++) {
      await a.moveBy(Offset(0, -15));
      await b.moveBy(Offset(0, 15));
    }
    await tester.pump();
    expect(h.controller.scale, greaterThan(1.2));
    expect(h.controller.rotation, 0);
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  });

  testWidgets('旋转模式：先扭转进入旋转，之后拉开间距同时缩放', (tester) async {
    final h = await _pump(tester);
    final c = _center(tester);
    final a = await tester.startGesture(c - Offset(50, 0), pointer: 1);
    final b = await tester.startGesture(c + Offset(50, 0), pointer: 2);
    for (var i = 0; i < 4; i++) {
      await a.moveBy(Offset(0, -15));
      await b.moveBy(Offset(0, 15));
    }
    final angle = h.controller.rotation;
    expect(angle, greaterThan(0.2));
    for (var i = 0; i < 3; i++) {
      await a.moveBy(Offset(-20, 0));
      await b.moveBy(Offset(20, 0));
    }
    await tester.pump();
    expect(h.controller.scale, greaterThan(1.1));
    expect(h.controller.rotation, isNot(0));
    final scale = h.controller.scale;
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(h.controller.rotation, 0, reason: '松手后旋转复位');
    expect(h.controller.scale, moreOrLessEquals(scale), reason: '缩放保留');
  });

  testWidgets('捏合后松开一指，剩下的手指继续平移且不跳变', (tester) async {
    final h = await _pump(tester);
    final c = _center(tester);
    final a = await tester.startGesture(c - Offset(50, 0), pointer: 1);
    final b = await tester.startGesture(c + Offset(50, 0), pointer: 2);
    for (var i = 0; i < 3; i++) {
      await a.moveBy(Offset(-30, 0));
      await b.moveBy(Offset(30, 0));
    }
    final scale = h.controller.scale;
    final before = h.controller.translation;
    await b.up();
    expect(h.controller.translation, before);
    await a.moveBy(Offset(-30, 0));
    expect(h.controller.translation.dx, moreOrLessEquals(before.dx - 30));
    expect(h.controller.scale, scale);
    expect(h.controller.page.value, 0);
    await a.up();
    await tester.pumpAndSettle();
  });

  testWidgets('已缩放平移到边缘后同一手势进入翻页，反向先收回再平移，继续可跨到下一项', (tester) async {
    final h = await _pump(tester);
    final c = _center(tester);
    await _doubleTap(tester, c);
    expect(h.controller.scale, 2.5);
    // 2.5 倍时横向可平移范围为 (400 * 2.5 - 400) / 2 = 300。
    final gesture = await tester.startGesture(c);
    var t = 0;
    await gesture.moveBy(Offset(-20, 0), timeStamp: Duration(milliseconds: t += 16));
    expect(h.controller.translation.dx, moreOrLessEquals(-20));
    await gesture.moveBy(Offset(-300, 0), timeStamp: Duration(milliseconds: t += 16));
    expect(h.controller.translation.dx, moreOrLessEquals(-300));
    expect(h.controller.page.value, moreOrLessEquals(0.05));

    await gesture.moveBy(Offset(50, 0), timeStamp: Duration(milliseconds: t += 16));
    expect(h.controller.page.value, 0);
    expect(h.controller.translation.dx, moreOrLessEquals(-270));

    await gesture.moveBy(Offset(-30, 0), timeStamp: Duration(milliseconds: t += 16));
    expect(h.controller.translation.dx, moreOrLessEquals(-300));
    await gesture.moveBy(Offset(-400, 0), timeStamp: Duration(milliseconds: t += 16));
    expect(h.controller.index, 1, reason: '整页越过后当前项切换，手势不中断');
    expect(h.controller.scale, 1);
    await _holdAndUp(tester, gesture, t);
    expect(h.controller.index, 1);
    expect(h.controller.page.value, 1);
  });

  testWidgets('双击放大到目标倍数，再次双击还原', (tester) async {
    final h = await _pump(tester);
    final c = _center(tester);
    await _doubleTap(tester, c + Offset(40, 0));
    expect(h.controller.scale, 2.5);
    expect(h.controller.translation.dx, moreOrLessEquals(-60));
    await tester.pump(Duration(milliseconds: 500));
    await _doubleTap(tester, c);
    expect(h.controller.scale, 1);
    expect(h.controller.translation, Offset.zero);
    expect(h.taps, 0, reason: '双击不触发单击');
  });

  testWidgets('单击在双击判定窗口结束后回调', (tester) async {
    final h = await _pump(tester);
    await tester.tapAt(_center(tester));
    await tester.pump(Duration(milliseconds: 100));
    expect(h.taps, 0);
    await tester.pump(Duration(milliseconds: 300));
    expect(h.taps, 1);
  });

  testWidgets('鼠标滚轮围绕指针缩放', (tester) async {
    final h = await _pump(tester);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(_center(tester)));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, -200)));
    await tester.pump();
    expect(h.controller.scale, moreOrLessEquals(1.4918, epsilon: 1e-3));
    await tester.sendEventToBinding(pointer.scroll(Offset(0, 1000)));
    await tester.pump();
    expect(h.controller.scale, 1);
  });

  testWidgets('声明纵向回调后，未缩放纵向拖动交给上层，翻页不动', (tester) async {
    final h = await _pump(tester, vertical: true);
    final gesture = await tester.startGesture(_center(tester));
    await gesture.moveBy(Offset(0, 30));
    await gesture.moveBy(Offset(0, 50));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.events, ['start', 'end']);
    expect(h.verticalDistance, moreOrLessEquals(80));
    expect(h.controller.page.value, 0);
  });

  testWidgets('控制器动画与跳转只驱动翻页位置并更新当前项', (tester) async {
    final h = await _pump(tester);
    final done = h.controller.animateToPage(2);
    await tester.pumpAndSettle();
    await done;
    expect(h.controller.index, 2);
    expect(h.controller.page.value, 2);
    h.controller.jumpToPage(0);
    await tester.pump();
    expect(h.controller.index, 0);
    expect(h.indexLog, [2, 0]);
  });

  group('松手旋转按最近直角、沿最短方向吸附', () {
    testWidgets('不足 45° 时往回转到 0°，过程中单调减小', (tester) async {
      final h = await _pump(tester);
      final fingers = await _rotateUntil(tester, h, 0.4);
      final start = h.controller.rotation;
      expect(start, inInclusiveRange(0.4, math.pi / 4));
      final middle = await _releaseAndTrack(tester, h, fingers);
      expect(middle, inExclusiveRange(0, start));
      expect(h.controller.rotation, moreOrLessEquals(0));
    });

    testWidgets('超过 45° 时沿当前方向补到 90°，不往回转', (tester) async {
      final h = await _pump(tester);
      final fingers = await _rotateUntil(tester, h, 1.0);
      final start = h.controller.rotation;
      expect(start, inInclusiveRange(1.0, 3 * math.pi / 4));
      final middle = await _releaseAndTrack(tester, h, fingers);
      expect(middle, inExclusiveRange(start, math.pi / 2));
      expect(h.controller.rotation, moreOrLessEquals(math.pi / 2));
    });

    testWidgets('逆时针超过 45° 时补到 -90°', (tester) async {
      final h = await _pump(tester);
      final fingers = await _rotateUntil(tester, h, -1.0);
      final start = h.controller.rotation;
      final middle = await _releaseAndTrack(tester, h, fingers);
      expect(middle, inExclusiveRange(-math.pi / 2, start));
      expect(h.controller.rotation, moreOrLessEquals(-math.pi / 2));
    });

    testWidgets('超过 135° 时补到 180°，旋转越过半圈仍保持连续', (tester) async {
      final h = await _pump(tester);
      final fingers = await _rotateUntil(tester, h, 2.5);
      final start = h.controller.rotation;
      expect(start, inInclusiveRange(2.5, math.pi), reason: '累计角度不应在越过 180° 时翻到负值');
      await _releaseAndTrack(tester, h, fingers);
      expect(math.cos(h.controller.rotation), moreOrLessEquals(-1));
    });

    testWidgets('吸附保留缩放倍数；吸附到 90° 后双击回到 0° 与原始大小', (tester) async {
      final h = await _pump(tester);
      final fingers = await _rotateUntil(tester, h, 1.0);
      // 沿手指连线方向向外拉开，只改变间距不改变角度。
      final outward = Offset(math.cos(fingers.$3), math.sin(fingers.$3)) * 12;
      for (var i = 0; i < 3; i++) {
        await fingers.$1.moveBy(-outward);
        await fingers.$2.moveBy(outward);
      }
      final scale = h.controller.scale;
      expect(scale, greaterThan(1.2));
      await _releaseAndTrack(tester, h, fingers);
      expect(h.controller.rotation, moreOrLessEquals(math.pi / 2));
      expect(h.controller.scale, moreOrLessEquals(scale));
      await tester.pump(Duration(milliseconds: 500));
      await _doubleTap(tester, _center(tester));
      expect(h.controller.rotation, moreOrLessEquals(0));
      expect(h.controller.scale, 1);
    });
  });

  group('放大后贴边进入翻页：只做横向移动', () {
    testWidgets('贴边后斜向拖动，余量只推动翻页，图片纵向不动', (tester) async {
      final h = await _pump(tester);
      await _zoomAtCenter(tester, h);
      final gesture = await tester.startGesture(_center(tester));
      await gesture.moveBy(Offset(-20, 0));
      await gesture.moveBy(Offset(-280, 0));
      expect(h.controller.translation, Offset(-300, 0));
      expect(h.controller.page.value, 0);

      await gesture.moveBy(Offset(-40, -30));
      expect(h.controller.page.value, moreOrLessEquals(0.1));
      expect(h.controller.translation, Offset(-300, 0), reason: '进入翻页的这一下纵向也不平移图片');
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('翻页偏离期间纯纵向拖动，既不平移图片也不改变翻页', (tester) async {
      final h = await _pump(tester);
      await _zoomAtCenter(tester, h);
      final gesture = await tester.startGesture(_center(tester));
      await gesture.moveBy(Offset(-20, 0));
      await gesture.moveBy(Offset(-320, 0));
      final page = h.controller.page.value;
      expect(page, moreOrLessEquals(0.1));
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(Offset(0, 25));
      }
      expect(h.controller.page.value, page);
      expect(h.controller.translation, Offset(-300, 0));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('反向收回到当前项的那一下仍只做横向，之后恢复图片双轴平移', (tester) async {
      final h = await _pump(tester);
      await _zoomAtCenter(tester, h);
      final gesture = await tester.startGesture(_center(tester));
      await gesture.moveBy(Offset(-20, 0));
      await gesture.moveBy(Offset(-320, 0));
      expect(h.controller.page.value, moreOrLessEquals(0.1));

      await gesture.moveBy(Offset(60, 30));
      expect(h.controller.page.value, 0);
      expect(h.controller.translation, Offset(-280, 0));

      await gesture.moveBy(Offset(10, 30));
      expect(h.controller.translation, Offset(-270, 30));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('未贴边时斜向拖动正常平移图片两轴，翻页不动', (tester) async {
      final h = await _pump(tester);
      await _zoomAtCenter(tester, h);
      final gesture = await tester.startGesture(_center(tester));
      await gesture.moveBy(Offset(-20, -20));
      await gesture.moveBy(Offset(-30, 40));
      expect(h.controller.translation, Offset(-50, 20));
      expect(h.controller.page.value, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('跨入下一项后继续拖动仍是横向翻页', (tester) async {
      final h = await _pump(tester);
      await _zoomAtCenter(tester, h);
      final gesture = await tester.startGesture(_center(tester));
      await gesture.moveBy(Offset(-20, 0));
      await gesture.moveBy(Offset(-280, 0));
      await gesture.moveBy(Offset(-400, -60));
      expect(h.controller.index, 1);
      await gesture.moveBy(Offset(-40, 50));
      expect(h.controller.page.value, moreOrLessEquals(1.1));
      expect(h.controller.translation, Offset.zero);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
