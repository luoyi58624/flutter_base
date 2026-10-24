import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/cores/event/event.dart';
import 'package:flutter_base/src/ui/cores/event/index.dart' show ElEventView;
import 'package:flutter_base/src/ui/cores/view/index.dart' show ElView;
import 'package:flutter_base/src/ui/cores/view/render/index.dart';
import 'package:flutter_base/src/ui/cores/view/style/index.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _scene(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(alignment: .topLeft, child: child),
);

void main() {
  testWidgets('旧事件包装不成为百分比参照，祖先变化仍通知后代', (tester) async {
    final outerKey = GlobalKey(), childKey = GlobalKey();
    await tester.pumpWidget(
      _scene(
        ElView(
          key: outerKey,
          style: ElStyle(width: 400, height: 80),
          child: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 100,
              child: ElEventView(
                child: OverflowBox(
                  alignment: .topLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: ElView(
                    key: childKey,
                    style: ElStyle(width: '50%', height: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(childKey)).width, 200);
    final outer = tester.renderObject<ElRenderView>(find.byKey(outerKey));
    outer.applyStyle(ElStyle(width: 300, height: 80), textDirection: .ltr);
    await tester.pump();
    expect(tester.getSize(find.byKey(childKey)).width, 150);
  });

  testWidgets('普通视图不创建分发器，事件声明使无装饰盒可以命中', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(_Host(key: key)));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    expect(render.eventDispatcher, isNull);
    var taps = 0;
    render.event = ElEvent(onTap: (_) => taps++);
    await tester.tapAt(Offset(20, 20));
    expect(taps, 1);
  });

  testWidgets('原始与识别事件使用相同坐标，包含祖先和自身变换', (tester) async {
    Offset? raw, tap;
    final key = GlobalKey();
    await tester.pumpWidget(
      _scene(
        Transform.scale(
          scale: 2,
          alignment: .topLeft,
          child: _Host(
            key: key,
            style: ElStyle(
              width: 100,
              height: 100,
              transform: ElTransform.translate(20, 10),
            ),
            event: ElEvent(
              onPointerDown: (event) => raw = event.localPosition,
              onTap: (event) => tap = event.localPosition,
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(Offset(60, 40));
    expect(raw, Offset(10, 10));
    expect(tap, raw);
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    expect(render.eventContains(Offset(60, 40)), isTrue);
    expect(render.eventContains(Offset(20, 20)), isFalse);
  });

  testWidgets('事件范围包含 padding、排除 margin 并遵守路径裁剪', (tester) async {
    var taps = 0;
    final key = GlobalKey();
    await tester.pumpWidget(
      _scene(
        _Host(
          key: key,
          style: ElStyle(
            width: 100,
            height: 100,
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(10),
            clipper: _HalfClip(),
          ),
          event: ElEvent(onTap: (_) => taps++),
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    expect(render.eventContains(Offset(5, 5)), isFalse);
    expect(render.eventContains(Offset(25, 25)), isTrue);
    expect(render.eventContains(Offset(95, 25)), isFalse);
    await tester.tapAt(Offset(5, 5));
    await tester.tapAt(Offset(25, 25));
    await tester.tapAt(Offset(95, 25));
    expect(taps, 1);
  });

  testWidgets('禁用节点在自身变换后的区域阻断后代和背后兄弟', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _scene(
        Stack(
          children: [
            GestureDetector(
              behavior: .opaque,
              onTap: () => taps++,
              child: SizedBox(width: 200, height: 100),
            ),
            _Host(
              style: ElStyle(
                width: 100,
                height: 100,
                transform: ElTransform.translateX(50),
              ),
              event: ElEvent(disabled: true),
              child: GestureDetector(
                onTap: () => taps++,
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.tapAt(Offset(75, 25));
    expect(taps, 0);
    await tester.tapAt(Offset(25, 25));
    expect(taps, 1);
  });

  testWidgets('同一事件声明的设备容差变化仍更新识别器', (tester) async {
    var starts = 0;
    final declaration = ElEvent(onHorizontalDragStart: (_) => starts++);
    final key = GlobalKey();
    await tester.pumpWidget(
      _scene(
        _Host(
          key: key,
          event: declaration,
          gestureSettings: DeviceGestureSettings(touchSlop: 60),
        ),
      ),
    );
    final first = await tester.startGesture(Offset(20, 20));
    await first.moveBy(Offset(30, 0));
    expect(starts, 0);
    await first.cancel();
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    render.gestureSettings = DeviceGestureSettings(touchSlop: 2);
    expect(identical(render.event, declaration), isTrue);
    final second = await tester.startGesture(Offset(20, 20));
    await second.moveBy(Offset(30, 0));
    expect(starts, 1);
    await second.up();
  });

  testWidgets('祖先后来声明事件，下一次输入使用更新后的父链', (tester) async {
    final calls = <String>[];
    final parentKey = GlobalKey();
    await tester.pumpWidget(
      _scene(
        _Host(
          key: parentKey,
          child: _Host(event: ElEvent(onTap: (_) => calls.add('child'))),
        ),
      ),
    );
    final parent = tester.renderObject<ElRenderView>(find.byKey(parentKey));
    parent.event = ElEvent(onTap: (_) => calls.add('parent'));
    await tester.tapAt(Offset(20, 20));
    expect(calls, ['child', 'parent']);
  });
}

class _Host extends SingleChildRenderObjectWidget {
  const _Host({
    super.key,
    this.style = const ElStyle(width: 100, height: 100),
    this.event,
    this.gestureSettings,
    super.child,
  });

  final ElStyle style;
  final ElEvent? event;
  final DeviceGestureSettings? gestureSettings;

  @override
  ElRenderView createRenderObject(BuildContext context) =>
      ElRenderView(style, .ltr, event: event, gestureSettings: gestureSettings);

  @override
  void updateRenderObject(BuildContext context, ElRenderView renderObject) {
    renderObject.applyStyle(style, textDirection: .ltr);
    renderObject.gestureSettings = gestureSettings;
    renderObject.event = event;
  }
}

class _HalfClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) =>
      Path()..addRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));

  @override
  bool shouldReclip(_HalfClip oldClipper) => false;
}
