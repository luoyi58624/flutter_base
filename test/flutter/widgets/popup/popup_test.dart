import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

final _panel = find.byKey(ValueKey('panel'));
final _trigger = find.byKey(ValueKey('trigger'));

Widget _box(String key, Size size) => SizedBox.fromSize(
  key: ValueKey(key),
  size: size,
  child: ColoredBox(
    color: Color(0xff2080f0),
    child: Center(child: Text(key)),
  ),
);

/// 在 800×600 画布的指定位置放一个弹层，面板默认 100×50。
Widget _app({
  Offset at = const Offset(100, 100),
  ElOverlayAnchor anchor = const ElOverlayAnchor(),
  Set<ElPopupTrigger> trigger = const {ElPopupTrigger.click},
  Size panel = const Size(100, 50),
  Size target = const Size(80, 30),
  ElPopupController? controller,
  WidgetBuilder? builder,
  ValueChanged<bool>? onOpenChanged,
  ElEvent? event,
  bool disabled = false,
  bool closeOnScroll = false,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(viewInsets: viewInsets),
    child: child!,
  ),
  home: Scaffold(
    body: Stack(
      children: [
        Positioned(
          left: at.dx,
          top: at.dy,
          child: ElPopup(
            controller: controller,
            trigger: trigger,
            anchor: anchor,
            disabled: disabled,
            closeOnScroll: closeOnScroll,
            onOpenChanged: onOpenChanged,
            event: event,
            hoverIntent: ElHoverIntent(
              openDelay: Duration(milliseconds: 200),
              closeDelay: Duration(milliseconds: 100),
              safePolygon: false,
            ),
            builder: builder ?? (context) => _box('panel', panel),
            child: _box('trigger', target),
          ),
        ),
      ],
    ),
  ),
);

Future<TestGesture> _mouse(WidgetTester tester, [Offset at = Offset.zero]) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: at);
  addTearDown(mouse.removePointer);
  return mouse;
}

void main() {
  group('定位', () {
    testWidgets('默认在目标下方居中，offset 拉开主轴间距', (tester) async {
      await tester.pumpWidget(_app(anchor: ElOverlayAnchor(offset: 6)));
      await tester.tap(_trigger);
      await tester.pump();
      final anchor = tester.getRect(_trigger);
      final panel = tester.getRect(_panel);
      expect(panel.top, anchor.bottom + 6);
      expect(panel.center.dx, anchor.center.dx);
    });

    testWidgets('下方放不下时翻到上方，交叉轴越界时起止对调', (tester) async {
      await tester.pumpWidget(
        _app(
          at: Offset(700, 540),
          anchor: ElOverlayAnchor(placement: .bottomStart, offset: 4),
        ),
      );
      await tester.tap(_trigger);
      await tester.pump();
      final anchor = tester.getRect(_trigger);
      final panel = tester.getRect(_panel);
      expect(panel.bottom, anchor.top - 4);
      // 左对齐会越过右边界，对调为右对齐后放得下。
      expect(panel.right, anchor.right);
      await tester.pump();
      expect(ElPopup.geometryOf(tester.element(_panel))?.placement, ElPlacement.topEnd);
    });

    testWidgets('起止对调后仍放不下时钳到视口边缘', (tester) async {
      await tester.pumpWidget(
        _app(
          at: Offset(740, 100),
          anchor: ElOverlayAnchor(placement: .bottomStart),
        ),
      );
      await tester.tap(_trigger);
      await tester.pump();
      expect(tester.getRect(_panel).right, 800 - 8);
    });

    testWidgets('两侧都放不下时钳进视口安全区，主轴约束取较宽裕一侧', (tester) async {
      await tester.pumpWidget(
        _app(at: Offset(300, 280), panel: Size(1000, 1000), anchor: ElOverlayAnchor(viewportPadding: 10)),
      );
      await tester.tap(_trigger);
      await tester.pump();
      final anchor = tester.getRect(_trigger);
      final panel = tester.getRect(_panel);
      expect(panel.width, 780);
      expect(panel.left, 10);
      // 下方剩余 600 - 10 - 310 = 280，上方 280 - 10 = 270，取下方。
      expect(panel.height, 600 - 10 - anchor.bottom);
      expect(panel.top, anchor.bottom);
    });

    testWidgets('cover 时面板从目标所在位置展开并覆盖目标', (tester) async {
      await tester.pumpWidget(
        _app(
          at: Offset(600, 100),
          anchor: ElOverlayAnchor(placement: .bottomEnd, cover: true),
        ),
      );
      await tester.tap(_trigger);
      await tester.pump();
      final anchor = tester.getRect(_trigger);
      final panel = tester.getRect(_panel);
      expect(panel.topRight, anchor.topRight);
    });

    testWidgets('cover 在下方放不下时向上展开，底边对齐目标底边', (tester) async {
      await tester.pumpWidget(
        _app(
          at: Offset(600, 560),
          anchor: ElOverlayAnchor(placement: .bottomEnd, cover: true),
        ),
      );
      await tester.tap(_trigger);
      await tester.pump();
      expect(tester.getRect(_panel).bottomRight, tester.getRect(_trigger).bottomRight);
    });

    testWidgets('matchWidth 锁定为目标宽度，matchMinWidth 只抬高下限', (tester) async {
      await tester.pumpWidget(_app(target: Size(160, 30), anchor: ElOverlayAnchor(matchWidth: true)));
      await tester.tap(_trigger);
      await tester.pump();
      expect(tester.getSize(_panel).width, 160);

      await tester.pumpWidget(
        _app(
          target: Size(160, 30),
          anchor: ElOverlayAnchor(matchMinWidth: true),
          builder: (context) => Align(
            key: ValueKey('panel'),
            alignment: .topLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox(width: 60, height: 40),
          ),
        ),
      );
      expect(tester.getSize(_panel).width, 160);
    });

    testWidgets('左右方位沿目标侧边展开，start / end 对齐上下边', (tester) async {
      for (final (placement, expected) in [
        (ElPlacement.rightStart, (Rect a, Rect p) => p.left == a.right && p.top == a.top),
        (ElPlacement.leftEnd, (Rect a, Rect p) => p.right == a.left && p.bottom == a.bottom),
      ]) {
        await tester.pumpWidget(
          _app(
            at: Offset(300, 200),
            anchor: ElOverlayAnchor(placement: placement),
          ),
        );
        await tester.tap(_trigger);
        await tester.pump();
        expect(expected(tester.getRect(_trigger), tester.getRect(_panel)), isTrue, reason: '$placement');
        await tester.pumpWidget(SizedBox());
      }
    });

    testWidgets('键盘弹起后可用空间缩小，面板改到目标上方', (tester) async {
      await tester.pumpWidget(_app(at: Offset(100, 380)));
      await tester.tap(_trigger);
      await tester.pump();
      expect(tester.getRect(_panel).top, tester.getRect(_trigger).bottom);

      await tester.pumpWidget(_app(at: Offset(100, 380), viewInsets: EdgeInsets.only(bottom: 200)));
      await tester.pump();
      expect(tester.getRect(_panel).bottom, tester.getRect(_trigger).top);
    });
  });

  group('滚动', () {
    Widget list(ScrollController controller, {bool closeOnScroll = false}) => MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            SizedBox(height: 500),
            Align(
              alignment: .topLeft,
              child: ElPopup(
                closeOnScroll: closeOnScroll,
                builder: (context) => _box('panel', Size(100, 120)),
                child: _box('trigger', Size(80, 30)),
              ),
            ),
            SizedBox(height: 1200),
          ],
        ),
      ),
    );

    testWidgets('滚动时同帧跟随目标并按新空间重选方位，滚出视野时隐藏、滚回后恢复', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(list(controller));
      await tester.tap(_trigger);
      await tester.pump();
      // 目标在 500~530，下方只剩 62，翻到上方。
      expect(tester.getRect(_panel).bottom, tester.getRect(_trigger).top);

      controller.jumpTo(300);
      await tester.pump();
      expect(tester.getRect(_trigger).top, 200);
      expect(tester.getRect(_panel).top, tester.getRect(_trigger).bottom);

      controller.jumpTo(320);
      await tester.pump();
      expect(tester.getRect(_panel).top, tester.getRect(_trigger).bottom);

      controller.jumpTo(600);
      await tester.pump();
      expect(_panel.hitTestable(), findsNothing);
      controller.jumpTo(300);
      await tester.pump();
      expect(_panel.hitTestable(), findsOneWidget);
      expect(tester.getRect(_panel).top, tester.getRect(_trigger).bottom);
    });

    testWidgets('closeOnScroll 时开始滚动即关闭', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(list(controller, closeOnScroll: true));
      await tester.tap(_trigger);
      await tester.pump();
      expect(_panel, findsOneWidget);
      await tester.drag(find.byType(ListView), Offset(0, -40));
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
    });
  });

  group('触发', () {
    testWidgets('点击切换，面板内点击保持打开，外部点击关闭并回调开闭状态', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(_app(onOpenChanged: changes.add));
      await tester.tap(_trigger);
      await tester.pump();
      await tester.tap(_panel);
      await tester.pump();
      expect(_panel, findsOneWidget);
      await tester.tapAt(Offset(700, 500));
      await tester.pump();
      expect(_panel, findsNothing);
      await tester.tap(_trigger);
      await tester.pump();
      await tester.tap(_trigger);
      await tester.pump();
      expect(_panel, findsNothing);
      expect(changes, [true, false, true, false]);
    });

    testWidgets('悬停达到延迟才打开，移进面板保持打开，离开后延迟关闭', (tester) async {
      await tester.pumpWidget(_app(trigger: {.hover}));
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(_trigger));
      await tester.pump(Duration(milliseconds: 150));
      expect(_panel, findsNothing);
      await tester.pump(Duration(milliseconds: 60));
      expect(_panel, findsOneWidget);

      await mouse.moveTo(tester.getCenter(_panel));
      await tester.pump(Duration(milliseconds: 300));
      expect(_panel, findsOneWidget);

      await mouse.moveTo(Offset(700, 500));
      await tester.pump(Duration(milliseconds: 50));
      expect(_panel, findsOneWidget);
      await tester.pump(Duration(milliseconds: 60));
      expect(_panel, findsNothing);
    });

    testWidgets('快速掠过目标不打开', (tester) async {
      await tester.pumpWidget(_app(trigger: {.hover}));
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(_trigger));
      await tester.pump(Duration(milliseconds: 100));
      await mouse.moveTo(Offset(700, 500));
      await tester.pump(Duration(milliseconds: 300));
      expect(_panel, findsNothing);
    });

    testWidgets('悬停触发在触摸设备上点击切换', (tester) async {
      await tester.pumpWidget(_app(trigger: {.hover}));
      await tester.tap(_trigger);
      await tester.pump();
      expect(_panel, findsOneWidget);
      await tester.tap(_trigger);
      await tester.pump();
      expect(_panel, findsNothing);
    });

    testWidgets('右键在指针位置打开，靠近右边界时改到指针左侧，再次右键移动到新位置', (tester) async {
      await tester.pumpWidget(
        _app(
          at: Offset(0, 0),
          target: Size(800, 600),
          trigger: {.contextMenu},
          anchor: ElOverlayAnchor(placement: .bottomStart, viewportPadding: 0),
        ),
      );
      await tester.tapAt(Offset(200, 150), buttons: kSecondaryButton);
      await tester.pump();
      expect(tester.getTopLeft(_panel), Offset(200, 150));

      await tester.tapAt(Offset(760, 580), buttons: kSecondaryButton);
      await tester.pump();
      expect(tester.getBottomRight(_panel), Offset(760, 580));
    });

    testWidgets('长按在按压位置打开', (tester) async {
      await tester.pumpWidget(
        _app(
          at: Offset(0, 0),
          target: Size(800, 600),
          trigger: {.contextMenu},
          anchor: ElOverlayAnchor(placement: .bottomStart),
        ),
      );
      await tester.longPressAt(Offset(300, 200));
      await tester.pump();
      expect(tester.getTopLeft(_panel), Offset(300, 200));
    });

    testWidgets('目标获得焦点时打开，焦点离开后关闭', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElPopup(
                  trigger: {.focus},
                  builder: (context) => _box('panel', Size(100, 50)),
                  child: Focus(focusNode: focus, child: _box('trigger', Size(80, 30))),
                ),
                Focus(child: SizedBox(key: ValueKey('other'), width: 10, height: 10)),
              ],
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      expect(_panel, findsOneWidget);
      focus.unfocus();
      await tester.pump();
      await tester.pump();
      expect(_panel, findsNothing);
    });

    testWidgets('event 先于触发动作执行，preventDefault 阻止打开', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          event: ElEvent(
            onTap: (e) {
              taps++;
              if (taps == 1) e.preventDefault();
            },
          ),
        ),
      );
      await tester.tap(_trigger);
      await tester.pump();
      expect(_panel, findsNothing);
      await tester.tap(_trigger);
      await tester.pump();
      expect(_panel, findsOneWidget);
      expect(taps, 2);
    });

    testWidgets('disabled 忽略触发，打开中禁用时关闭', (tester) async {
      final controller = ElPopupController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller: controller, disabled: true));
      await tester.tap(_trigger);
      controller.open();
      await tester.pump();
      expect(_panel, findsNothing);

      await tester.pumpWidget(_app(controller: controller));
      controller.open();
      await tester.pump();
      expect(_panel, findsOneWidget);
      await tester.pumpWidget(_app(controller: controller, disabled: true));
      await tester.pump();
      expect(_panel, findsNothing);
      expect(controller.isOpen, isFalse);
    });
  });

  group('生命周期', () {
    testWidgets('控制器开闭并通知，关闭时等面板退场，退场中再次打开从当前进度回到进场', (tester) async {
      final controller = ElPopupController();
      addTearDown(controller.dispose);
      var notified = 0;
      controller.addListener(() => notified++);
      await tester.pumpWidget(
        _app(
          controller: controller,
          builder: (context) => ElOverlayTransition(
            duration: Duration(milliseconds: 100),
            builder: (context, animation) =>
                FadeTransition(key: ValueKey('fade'), opacity: animation, child: _box('panel', Size(100, 50))),
          ),
        ),
      );
      controller.open();
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);

      controller.close();
      await tester.pump();
      await tester.pump(Duration(milliseconds: 50));
      expect(controller.isOpen, isFalse);
      expect(_panel, findsOneWidget);
      expect(_panel.hitTestable(), findsNothing);
      final fading = tester.widget<FadeTransition>(find.byKey(ValueKey('fade'))).opacity.value;
      expect(fading, inExclusiveRange(0, 1));

      controller.open();
      await tester.pumpAndSettle();
      expect(_panel.hitTestable(), findsOneWidget);
      expect(tester.widget<FadeTransition>(find.byKey(ValueKey('fade'))).opacity.value, 1);

      controller.close();
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(notified, 4);
    });

    testWidgets('面板内容经 ElPopup.maybeOf 关闭自身', (tester) async {
      await tester.pumpWidget(
        _app(
          builder: (context) =>
              GestureDetector(onTap: () => ElPopup.maybeOf(context)!.close(), child: _box('panel', Size(100, 50))),
        ),
      );
      await tester.tap(_trigger);
      await tester.pump();
      await tester.tap(_panel);
      await tester.pump();
      expect(_panel, findsNothing);
    });

    testWidgets('焦点在面板内时 Esc 关闭并把焦点交还打开前的位置', (tester) async {
      final before = FocusNode();
      final inner = FocusNode();
      addTearDown(before.dispose);
      addTearDown(inner.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(
              focusNode: before,
              child: ElPopup(
                builder: (context) => Focus(focusNode: inner, child: _box('panel', Size(100, 50))),
                child: _box('trigger', Size(80, 30)),
              ),
            ),
          ),
        ),
      );
      before.requestFocus();
      await tester.pump();
      await tester.tap(_trigger);
      await tester.pump();
      inner.requestFocus();
      await tester.pump();
      expect(before.hasPrimaryFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_panel, findsNothing);
      expect(before.hasPrimaryFocus, isTrue);
    });
  });

  group('嵌套', () {
    late FocusNode subFocus;
    setUp(() => subFocus = FocusNode());
    tearDown(() => subFocus.dispose());

    Widget nested() => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: .topLeft,
          child: ElPopup(
            builder: (context) => Focus(
              autofocus: true,
              child: Column(
                mainAxisSize: .min,
                children: [
                  for (final name in ['a', 'b'])
                    ElPopup(
                      trigger: {.hover},
                      anchor: ElOverlayAnchor(placement: .rightStart),
                      hoverIntent: ElHoverIntent(
                        openDelay: Duration(milliseconds: 100),
                        closeDelay: Duration(milliseconds: 100),
                        safePolygon: false,
                      ),
                      builder: (context) => Focus(focusNode: subFocus, child: _box('sub-$name', Size(120, 60))),
                      child: _box('item-$name', Size(100, 30)),
                    ),
                ],
              ),
            ),
            child: _box('trigger', Size(80, 30)),
          ),
        ),
      ),
    );

    testWidgets('悬停子项打开子层，移进子层面板父层保持，切到同级子项时旧子层关闭', (tester) async {
      await tester.pumpWidget(nested());
      await tester.tap(_trigger);
      await tester.pump();
      final mouse = await _mouse(tester, tester.getCenter(find.byKey(ValueKey('item-a'))));
      await tester.pump(Duration(milliseconds: 150));
      final sub = find.byKey(ValueKey('sub-a'));
      expect(sub, findsOneWidget);
      expect(tester.getRect(sub).left, tester.getRect(find.byKey(ValueKey('item-a'))).right);

      await mouse.moveTo(tester.getCenter(sub));
      await tester.pump(Duration(milliseconds: 300));
      expect(sub, findsOneWidget);
      await tester.tap(sub);
      await tester.pump();
      expect(sub, findsOneWidget);
      expect(find.byKey(ValueKey('item-a')), findsOneWidget);

      await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('item-b'))));
      await tester.pump(Duration(milliseconds: 150));
      expect(find.byKey(ValueKey('sub-b')), findsOneWidget);
      expect(sub, findsNothing);

      await tester.tapAt(Offset(700, 500));
      await tester.pump();
      expect(find.byKey(ValueKey('sub-b')), findsNothing);
      expect(find.byKey(ValueKey('item-a')), findsNothing);
    });

    testWidgets('Esc 先关闭最内层，再关闭外层', (tester) async {
      await tester.pumpWidget(nested());
      await tester.tap(_trigger);
      await tester.pump();
      await _mouse(tester, tester.getCenter(find.byKey(ValueKey('item-a'))));
      await tester.pump(Duration(milliseconds: 150));
      expect(find.byKey(ValueKey('sub-a')), findsOneWidget);
      // 面板不主动抢焦点，由菜单等上层组件决定；这里模拟键盘进入子层。
      subFocus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(ValueKey('sub-a')), findsNothing);
      expect(find.byKey(ValueKey('item-a')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(ValueKey('item-a')), findsNothing);
    });

    testWidgets('关闭的弹层不截住 Esc：焦点在其目标内时 Esc 交给外层', (tester) async {
      final inner = FocusNode();
      addTearDown(inner.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: .topLeft,
              child: ElPopup(
                builder: (context) => ElPopup(
                  builder: (context) => _box('tip', Size(60, 30)),
                  child: Focus(focusNode: inner, child: _box('inner', Size(100, 30))),
                ),
                child: _box('trigger', Size(80, 30)),
              ),
            ),
          ),
        ),
      );
      await tester.tap(_trigger);
      await tester.pump();
      inner.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(ValueKey('inner')), findsNothing);
    });
  });

  group('跟随层', () {
    // 目标挂在 CompositedTransformFollower 内，实际位置由合成阶段的 LeaderLayer 决定，例如文本选择工具条。
    Widget follower(LayerLink link, Offset leader, ElPopupController controller) => MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: leader.dx,
              top: leader.dy,
              child: CompositedTransformTarget(link: link, child: SizedBox(width: 10, height: 10)),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: link,
                showWhenUnlinked: false,
                offset: Offset(0, 20),
                child: ElPopup(
                  controller: controller,
                  trigger: {},
                  anchor: ElOverlayAnchor(offset: 4),
                  builder: (context) => _box('panel', Size(100, 50)),
                  child: _box('trigger', Size(80, 30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    testWidgets('按合成后的实际位置定位，跟随层移动后下一帧跟上并重选方位', (tester) async {
      final link = LayerLink();
      final controller = ElPopupController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(follower(link, Offset(100, 100), controller));
      controller.open();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_trigger), Rect.fromLTWH(100, 120, 80, 30));
      expect(tester.getRect(_panel), Rect.fromLTWH(90, 154, 100, 50));

      await tester.pumpWidget(follower(link, Offset(300, 520), controller));
      await tester.pump();
      final anchor = tester.getRect(_trigger);
      final panel = tester.getRect(_panel);
      expect(anchor.topLeft, Offset(300, 540));
      // 下方放不下，翻到目标上方。
      expect(panel.bottom, anchor.top - 4);
      expect(panel.center.dx, anchor.center.dx);
    });

    testWidgets('面板内点击保持打开，外部点击关闭并移除面板', (tester) async {
      final link = LayerLink();
      final controller = ElPopupController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(follower(link, Offset(100, 100), controller));
      controller.open();
      await tester.pump();
      await tester.tapAt(tester.getCenter(_panel));
      await tester.pump();
      expect(controller.isOpen, isTrue);

      await tester.tapAt(Offset(700, 50));
      await tester.pump();
      await tester.pump();
      expect(controller.isOpen, isFalse);
      expect(_panel, findsNothing);
      // 关闭后跟随层继续移动不影响已移除的面板。
      await tester.pumpWidget(follower(link, Offset(200, 200), controller));
      await tester.pump();
      expect(_panel, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
