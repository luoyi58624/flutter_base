// ElEventConfig 生效规则：
// - 唯一规则 = 节点直参 + getter 内部默认：配置只对声明它的那个节点生效；
// - 未设置的字段落 ElEventConfig 的 getter 内部默认值，不读任何全局状态；
// - 事件配置不沿 render 树向子组件注入，祖先 config 不影响后代。
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kMinFlingVelocity;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;

void main() {
  setUp(() {
    EventDispatcher.debugResetEagerGestureOwners();
  });

  Widget shell(Widget child) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    );
  }

  Future<void> dragBy(WidgetTester tester, Offset delta) async {
    final g = await tester.createGesture();
    await g.down(const Offset(200, 200));
    await g.moveBy(delta);
    await tester.pump();
    await g.up();
    await tester.pump();
  }

  Future<void> tapWithMove(WidgetTester tester, Offset delta) async {
    final g = await tester.createGesture();
    await g.down(const Offset(200, 200));
    await g.moveBy(delta);
    await g.up();
    await tester.pump();
  }

  testWidgets('CFG-1: 未声明 config 时起拖阈落内部默认（设备自适应）', (tester) async {
    var dragStarts = 0;

    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 400, height: 400),
          event: ElEvent(onDragStart: (_) => dragStarts++, onDragUpdate: (_) {}),
        ),
      ),
    );

    // 存储层默认是 null（设备自适应），不是某个字面阈值。
    expect(ElEventConfig().dragStartDistance, isNull, reason: '内部默认是 null，交给设备口径现算');

    // 自由拖拽走 pan slop（测试环境 hit slop 18 × 2 = 36）。
    await dragBy(tester, const Offset(0, 10));
    expect(dragStarts, 0, reason: '10px 未越默认起拖阈');

    await dragBy(tester, const Offset(0, 40));
    expect(dragStarts, 1, reason: '40px 越过默认起拖阈，未声明 config 也应能起拖');
  });

  testWidgets('CFG-2: 局部 config 只覆盖声明的字段，未设置字段回落内部默认', (tester) async {
    Velocity? endVelocity;

    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 400, height: 400),
          event: ElEvent(
            config: const ElEventConfig(dragStartDistance: 6.0),
            onDragStart: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: (e) => endVelocity = e.velocity,
          ),
        ),
      ),
    );

    final g = await tester.createGesture();
    await g.down(const Offset(200, 100), timeStamp: Duration.zero);
    for (var i = 1; i <= 4; i++) {
      await g.moveBy(const Offset(0, 24), timeStamp: Duration(milliseconds: 12 * i));
    }
    await g.up(timeStamp: const Duration(milliseconds: 48));
    await tester.pump();

    expect(endVelocity, isNotNull);
    expect(
      endVelocity!.pixelsPerSecond.dy,
      greaterThan(kMinFlingVelocity),
      reason: '本地只声明 dragStartDistance，dragMinFlingVelocity 回落内部默认 50——4×24px/48ms 的甩速被判为 fling 得以保留',
    );
  });

  testWidgets('CFG-3: 祖先 event config 不注入后代', (tester) async {
    // 距离取消已是 opt-in（默认走边界口径），两侧各自显式打开 tapCancelByDistance
    // 让 tapCancelDistance 真正参与判定；祖先声明 50、后代声明 10。
    var taps = 0;
    var cancels = 0;

    await tester.pumpWidget(
      shell(
        ElView(
          style: const ElStyle(width: 400, height: 400),
          event: const ElEvent(
            config: ElEventConfig(tapCancelByDistance: true, tapCancelDistance: 50.0),
            onPointerDown: _noop,
          ),
          child: ElView(
            style: const ElStyle(width: 400, height: 400),
            event: ElEvent(
              config: const ElEventConfig(tapCancelByDistance: true, tapCancelDistance: 10.0),
              onTap: (_) => taps++,
              onTapCancel: (_) => cancels++,
            ),
          ),
        ),
      ),
    );

    await tapWithMove(tester, const Offset(30, 0));

    expect(taps, 0, reason: '后代替自己的声明生效：30px > 10px 应被取消');
    expect(cancels, 1, reason: '祖先的 50px 没有注入后代，否则 30px 不足以取消');
  });

  testWidgets('CFG-5: 节点级 config 替换即时生效', (tester) async {
    var taps = 0;
    var cancels = 0;
    ElEventConfig? localConfig = const ElEventConfig(tapCancelByDistance: true, tapCancelDistance: 50.0);
    late StateSetter rebuild;

    await tester.pumpWidget(
      shell(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ElView(
              style: const ElStyle(width: 400, height: 400),
              event: ElEvent(config: localConfig, onTap: (_) => taps++, onTapCancel: (_) => cancels++),
            );
          },
        ),
      ),
    );

    await tapWithMove(tester, const Offset(30, 0));
    expect(taps, 1, reason: '30px < 50px，tap 正常兑现');
    expect(cancels, 0);

    rebuild(() => localConfig = const ElEventConfig(tapCancelByDistance: true, tapCancelDistance: 5.0));
    await tester.pump();

    await tapWithMove(tester, const Offset(30, 0));
    expect(taps, 1, reason: '替换后的 5px 阈值生效，第二次 30px tap 被取消');
    expect(cancels, 1);
  });

  test('CFG-7: withFallback keeps field-level merge semantics', () {
    const base = ElEventConfig(
      longPressCancelDistance: 18.0,
      tapCancelDistance: 50.0,
      deferTap: true,
      dragDevices: {PointerDeviceKind.touch},
      dragMinFlingVelocity: 100.0,
    );
    const child = ElEventConfig(tapCancelDistance: 8.0, dragMaxFlingVelocity: 4000.0);
    final merged = child.withFallback(base);
    expect(merged.tapCancelDistance, 8.0);
    expect(merged.deferTap, isTrue);
    expect(merged.longPressDelay, const Duration(milliseconds: 500));
    expect(merged.longPressCancelDistance, 18.0);
    expect(merged.dragDevices, const {PointerDeviceKind.touch});
    expect(merged.dragMinFlingVelocity, 100.0);
    expect(merged.dragMaxFlingVelocity, 4000.0);
    expect(ElEventConfig().withFallback(base), base);
  });

  test('delayTouchDown 字段合并、拷贝和配置相等判定', () {
    // 出厂默认值是可随时调的手感参数，不在此断言具体数值——那会让每次调参都变成
    // "测试坏了"。这里只验证显式值的合并 / 拷贝 / 相等语义。
    final base = ElEventConfig(delayTouchDown: Duration(milliseconds: 160));
    expect(ElEventConfig(tapCancelDistance: 8).withFallback(base).delayTouchDown, Duration(milliseconds: 160));
    expect(ElEventConfig(delayTouchDown: Duration.zero).withFallback(base).delayTouchDown, Duration.zero);
    expect(base.copyWith(tapCancelDistance: 8).delayTouchDown, Duration(milliseconds: 160));
    expect(base.copyWith(delayTouchDown: Duration.zero), ElEventConfig(delayTouchDown: Duration.zero));
    expect(base, isNot(ElEventConfig()));
    expect(base.hashCode, ElEventConfig(delayTouchDown: Duration(milliseconds: 160)).hashCode);
    expect(() => ElEventConfig(delayTouchDown: Duration(milliseconds: -1)), throwsAssertionError);
  });

  test('旧版触摸反馈配置保留默认值、合并、拷贝与相等语义', () {
    expect(ElEventConfig().delayTouchDown, Duration.zero);
    expect(ElEventConfig().delayTouchUp, Duration(milliseconds: 100));
    final base = ElEventConfig(delayTouchDown: Duration(milliseconds: 20), delayTouchUp: Duration(milliseconds: 160));
    final merged = ElEventConfig(delayTouchUp: Duration.zero).withFallback(base);
    expect(merged.delayTouchDown, Duration(milliseconds: 20));
    expect(merged.delayTouchUp, Duration.zero);
    expect(
      base.copyWith(delayTouchUp: Duration.zero),
      ElEventConfig(delayTouchDown: Duration(milliseconds: 20), delayTouchUp: Duration.zero),
    );
    expect(base.copyWith(tapCancelDistance: 8).delayTouchUp, Duration(milliseconds: 160));
    expect(base, isNot(base.copyWith(delayTouchUp: Duration.zero)));
    expect(base.hashCode, base.copyWith().hashCode);
    expect(() => ElEventConfig(delayTouchUp: Duration(milliseconds: -1)), throwsAssertionError);
  });
}

void _noop(ElEventDetails event) {}
