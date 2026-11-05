import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool enabled = true, bool forceFrames = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: TickerMode(
    enabled: enabled,
    forceFrames: forceFrames,
    child: Align(child: child),
  ),
);

Widget _loop(Key key) => ElView(
  key: key,
  style: ElStyle(
    width: 20,
    height: 20,
    animation: [
      ElAnimation(
        keyframes: {0: ElStyle(opacity: 0.2), 100: ElStyle(opacity: 0.8)},
        animationDuration: Duration(seconds: 1),
        animationIterationCount: double.infinity,
        animationTimingFunction: Curves.linear,
      ),
    ],
  ),
);

bool _hasListeners(ChangeNotifier notifier) {
  // 白盒校验 SDK 持有的通知器是否泄漏，测试无法替换其具体子类。
  // ignore: invalid_use_of_protected_member
  return notifier.hasListeners;
}

void main() {
  testWidgets('El 无限关键帧首次处于禁用 TickerMode 时不调度帧，恢复后继续播放', (tester) async {
    final key = GlobalKey();
    final child = _loop(key);
    await tester.pumpWidget(_host(child, enabled: false));
    await tester.pump(Duration(milliseconds: 160));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_host(child));
    await tester.pump(Duration(milliseconds: 80));
    expect(tester.binding.transientCallbackCount, 1);
    expect(tester.renderObject<ElRenderView>(find.byKey(key)).committedResolvedStyle.box.opacity, greaterThan(0.2));
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('El 无限关键帧隐藏后持续静止且不需要重建原有 ElView', (tester) async {
    final child = _loop(GlobalKey());
    await tester.pumpWidget(_host(child));
    await tester.pump(Duration(milliseconds: 20));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(_host(child, enabled: false));
    await tester.pump(Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_host(child));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('El 有限过渡静音期间时间流逝，恢复首帧提交最终值', (tester) async {
    final key = GlobalKey();
    Widget view(double opacity) => ElView(
      key: key,
      style: ElStyle(
        width: 20,
        height: 20,
        opacity: opacity,
        transition: [ElTransition.all(Duration(milliseconds: 200), Curves.linear)],
      ),
    );
    await tester.pumpWidget(_host(view(1)));
    final changed = view(0.2);
    await tester.pumpWidget(_host(changed));
    await tester.pump(Duration(milliseconds: 40));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    expect(render.hasActiveAnimationsForTest, isTrue);
    await tester.pumpWidget(_host(changed, enabled: false));
    await tester.pump(Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_host(changed));
    await tester.pump();
    expect(render.committedResolvedStyle.box.opacity, closeTo(0.2, 1e-9));
    expect(render.hasActiveAnimationsForTest, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('El 时钟随 GlobalKey 换父重新绑定 TickerMode 并保留 RenderObject', (tester) async {
    final key = GlobalKey();
    final child = _loop(key);
    Widget tree(bool left) => Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          TickerMode(enabled: true, child: left ? child : SizedBox()),
          TickerMode(enabled: false, child: left ? SizedBox() : child),
        ],
      ),
    );
    await tester.pumpWidget(tree(true));
    await tester.pump(Duration(milliseconds: 20));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    await tester.pumpWidget(tree(false));
    await tester.pump(Duration(milliseconds: 20));
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(tree(true));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('El 普通节点不订阅 TickerMode，动画节点卸载后释放监听', (tester) async {
    late ValueNotifier<TickerModeData> notifier;
    Widget tree(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: TickerMode(
        enabled: true,
        child: Builder(
          builder: (context) {
            notifier = TickerMode.getValuesNotifier(context) as ValueNotifier<TickerModeData>;
            return Align(child: child);
          },
        ),
      ),
    );
    await tester.pumpWidget(tree(ElView(style: ElStyle(width: 20, height: 20))));
    expect(_hasListeners(notifier), isFalse);
    await tester.pumpWidget(tree(_loop(GlobalKey())));
    expect(_hasListeners(notifier), isTrue);
    await tester.pumpWidget(tree(SizedBox()));
    expect(_hasListeners(notifier), isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('El 嵌套 TickerMode 遵循外层禁用，祖先变化后恢复', (tester) async {
    final child = TickerMode(enabled: true, child: _loop(GlobalKey()));
    await tester.pumpWidget(_host(child, enabled: false));
    await tester.pump(Duration(milliseconds: 20));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_host(child));
    await tester.pump(Duration(milliseconds: 20));
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('El 时钟传播 TickerMode.forceFrames 且禁用模式优先于强制帧', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final child = _loop(GlobalKey());
    await tester.pumpWidget(_host(child));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    // 暂停后 pumpWidget 的普通帧请求会被框架拒绝，先恢复再更新祖先配置。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(_host(child, forceFrames: true));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(_host(child, enabled: false, forceFrames: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(SizedBox());
  });
}
