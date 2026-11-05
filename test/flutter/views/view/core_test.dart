import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter_test/flutter_test.dart';

const _instant = [ElTransition.all(Duration.zero)];

const _darkSurface = Color(0xFF1E293B);

Widget _box(Key key, ElStyle style) {
  return ElView(
    key: key,
    style: style.copyWith(
      width: style.width ?? 96,
      height: style.height ?? 40,
      transition: style.transition ?? _instant,
    ),
  );
}

void main() {
  test('状态监听固定登记时的筛选范围，空集合接收全部状态', () {
    final source = ViewStateSource();
    final selected = {ViewState.focus};
    final empty = <ViewState>{};
    var allCalls = 0, emptyCalls = 0, selectedCalls = 0;
    source.addListener(() => allCalls++);
    source.addListener(() => emptyCalls++, states: empty);
    source.addListener(() => selectedCalls++, states: selected);
    selected
      ..clear()
      ..add(ViewState.hover);
    empty.add(ViewState.focus);
    source.updateNodeStateBits(1 << ViewState.hover.index);
    expect((allCalls, emptyCalls, selectedCalls), (1, 1, 0));
    source.updateNodeStateBits((1 << ViewState.hover.index) | (1 << ViewState.focus.index));
    expect((allCalls, emptyCalls, selectedCalls), (2, 2, 1));
  });

  test('状态监听支持用重复读取的实例方法退订', () {
    final source = ViewStateSource();
    final listener = _StateListenerProbe();
    source.addListener(listener.changed);
    expect(source.hasListeners, isTrue);
    source.removeListener(listener.changed);
    expect(source.hasListeners, isFalse);
    source.updateNodeStateBits(1 << ViewState.hover.index);
    expect(listener.calls, 0);
  });

  testWidgets('ElView.of 的具体只读实例直接查询交互、主题和断点', (tester) async {
    late ElStyleContext view;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElView(
          themeMode: ElThemeMode(brightness: .dark),
          child: Builder(
            builder: (context) {
              view = ElView.of(context);
              return SizedBox(width: 20, height: 20);
            },
          ),
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(find.byType(ElView));
    expect(
      (view.hasHover, view.hasTap, view.hasFocus, view.hasFocusWithin, view.hasFocusVisible),
      (false, false, false, false, false),
    );
    expect((view.isDark, view.brightness, view.isDisabled, view.xl), (true, Brightness.dark, false, true));
    render.setHover(true);
    render.setTap(true);
    render.setFocus(true, focusVisible: true);
    render.setFocusWithin(true);
    expect(
      (view.hasHover, view.hasTap, view.hasFocus, view.hasFocusWithin, view.hasFocusVisible),
      (true, true, true, true, true),
    );
    render.event = ElEvent(disabled: true);
    expect((view.isDisabled, view.hasHover, view.hasTap), (true, false, false));
  });

  test('语义便利声明保持值相等，并兼容复用同一 properties 的完整声明', () {
    final first = ElSemantics(label: '打开', button: true);
    final equivalent = ElSemantics(label: '打开', button: true);
    final reused = ElSemantics(properties: first.properties);
    final independent = ElSemantics(properties: SemanticsProperties(label: '打开', button: true));
    expect(equivalent, first);
    expect(equivalent.hashCode, first.hashCode);
    expect(reused, first);
    expect(reused.hashCode, first.hashCode);
    expect(independent, isNot(first));
  });

  testWidgets('响应式断点不会触发键盘焦点外观', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ElView(
          style: ElStyle(
            backgroundColor: Color(0xff112233),
            xl: ElStyle(backgroundColor: Color(0xff445566)),
            onFocusVisible: ElStyle(backgroundColor: Color(0xff778899)),
          ),
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(find.byType(ElView));
    expect(render.internalStateHas(ViewState.xl), isTrue);
    expect(render.internalStateHas(ViewState.focusVisible), isFalse);
    expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff445566));
  });

  group('事件配置光标与禁用', () {
    Widget shell(Widget child) => Directionality(
      textDirection: .ltr,
      child: Align(alignment: .topLeft, child: child),
    );

    testWidgets('样式 hover/tap cursor 覆盖事件基础光标，移除后恢复', (tester) async {
      final key = GlobalKey();
      var taps = 0;
      var cancels = 0;
      Widget tree(MouseCursor cursor, bool variants) => shell(
        ElView(
          key: key,
          style: ElStyle(
            width: 100,
            height: 80,
            onHover: variants ? ElStyle(cursor: SystemMouseCursors.text) : null,
            onTap: variants ? ElStyle(cursor: SystemMouseCursors.grabbing) : null,
          ),
          event: ElEvent(cursor: cursor, onTap: (_) => taps++, onTapCancel: (_) => cancels++),
        ),
      );
      await tester.pumpWidget(tree(SystemMouseCursors.click, true));
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(render.cursor, SystemMouseCursors.click);
      final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset(150, 20));
      await mouse.moveTo(Offset(20, 20));
      await tester.pump();
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);
      await mouse.down(Offset(20, 20));
      await tester.pump();
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.grabbing);
      await tester.pumpWidget(tree(SystemMouseCursors.help, true));
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.grabbing);
      await mouse.up();
      await tester.pump();
      expect(taps, 1);
      expect(cancels, 0);
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);
      await tester.pumpWidget(tree(SystemMouseCursors.help, false));
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.help);
      expect(tester.renderObject(find.byKey(key)), same(render));
    });

    testWidgets('程序更新事件 cursor 只刷新光标，不重排', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        shell(
          ElView(
            key: key,
            style: ElStyle(width: 100, height: 80),
            event: ElEvent(cursor: SystemMouseCursors.click),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset(20, 20));
      await tester.pump();
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final layouts = render.debugLayoutCount;
      render.event = render.event!.copyWith(cursor: SystemMouseCursors.text);
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(render.debugNeedsPaint, isFalse);
      await tester.pump();
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.text);
      expect(render.debugLayoutCount, layouts);
    });

    testWidgets('事件是禁用的唯一来源，同步样式、焦点与静止光标', (tester) async {
      final key = GlobalKey();
      final node = FocusNode();
      addTearDown(node.dispose);
      var taps = 0;
      Widget tree(bool eventDisabled, {bool hasEvent = true}) => shell(
        ElView(
          key: key,

          focusNode: node,
          style: ElStyle(
            width: 100,
            height: 80,
            backgroundColor: Color(0xff112233),
            cursor: SystemMouseCursors.click,
            onDisabled: ElStyle(backgroundColor: Color(0xff445566), cursor: SystemMouseCursors.text),
          ),
          event: hasEvent
              ? ElEvent(disabled: eventDisabled, cursor: SystemMouseCursors.help, onTap: (_) => taps++)
              : null,
        ),
      );
      await tester.pumpWidget(tree(true));
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(render.disabled, isTrue);
      expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff445566));
      expect(node.canRequestFocus, isFalse);
      final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset(20, 20));
      await tester.pump();
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.forbidden);
      await tester.tapAt(Offset(20, 20));
      expect(taps, 0);
      await tester.pumpWidget(tree(true));
      expect(render.disabled, isTrue);
      expect(node.canRequestFocus, isFalse);
      await tester.pumpWidget(tree(false));
      expect(render.disabled, isFalse);
      expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff112233));
      expect(node.canRequestFocus, isTrue);
      expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.click);
      await tester.tapAt(Offset(20, 20));
      expect(taps, 1);
      await tester.pumpWidget(tree(true));
      await tester.pumpWidget(tree(false, hasEvent: false));
      expect(render.disabled, isFalse);
      expect(node.canRequestFocus, isTrue);
      expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff112233));
    });
  });

  group('状态订阅', () {
    Widget shell(Widget child) => MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: child),
    );

    Future<void> hoverAt(WidgetTester tester, Finder finder) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(finder));
      await tester.pump();
    }

    testWidgets('主题状态和变量在同一 build 帧通知各自的读者', (tester) async {
      var isDark = false;
      var stateBuilds = 0;
      var varsBuilds = 0;
      int? surface;
      final readers = Column(
        children: [
          Builder(
            builder: (context) {
              stateBuilds++;
              isDark = ElView.of(context).isDark;
              return SizedBox.shrink();
            },
          ),
          Builder(
            builder: (context) {
              varsBuilds++;
              surface = ElView.of(context).getVar<int>('surface');
              return SizedBox.shrink();
            },
          ),
        ],
      );
      late StateSetter rebuild;
      var brightness = Brightness.light;
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ElView(
                themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
                style: ElStyle(
                  vars: {'surface': 1},
                  onDark: ElStyle(vars: {'surface': 2}),
                ),
                child: readers,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect((isDark, surface, stateBuilds, varsBuilds), (false, 1, 1, 1));

      rebuild(() => brightness = Brightness.dark);
      await tester.pump();

      expect((isDark, surface, stateBuilds, varsBuilds), (true, 2, 2, 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    for (final duringLayout in [false, true]) {
      testWidgets('变量提交同帧通知后代，延期通知 Overlay（layout=$duringLayout）', (tester) async {
        late StateSetter rebuild;
        late BuildContext sourceContext;
        var width = 100.0;
        int? localValue;
        int? overlayValue;
        final reader = Builder(
          builder: (context) {
            sourceContext = context;
            localValue = ElView.of(context).getVar<int>('width');
            return SizedBox.shrink();
          },
        );
        Widget source(double width) => ElView(
          style: ElStyle(vars: {'width': width.toInt()}),
          child: reader,
        );
        await tester.pumpWidget(
          shell(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SizedBox(
                  width: width,
                  child: duringLayout
                      ? LayoutBuilder(builder: (_, constraints) => source(constraints.maxWidth))
                      : source(width),
                );
              },
            ),
          ),
        );
        final captured = InheritedTheme.captureAll(
          sourceContext,
          Builder(
            builder: (context) {
              overlayValue = ElView.of(context).getVar<int>('width');
              return SizedBox.shrink();
            },
          ),
        );
        final entry = OverlayEntry(builder: (_) => captured);
        Overlay.of(sourceContext).insert(entry);
        addTearDown(() {
          entry.remove();
          entry.dispose();
        });
        await tester.pumpAndSettle();
        expect((localValue, overlayValue), (100, 100));

        rebuild(() => width = 200);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect((localValue, overlayValue), (200, 100));
        expect(tester.binding.hasScheduledFrame, isTrue);
        await tester.pump();
        expect(overlayValue, 200);
      });
    }

    testWidgets('延期变量以读者在本帧重新读到的值为基准', (tester) async {
      final key = GlobalKey();
      late BuildContext sourceContext;
      ElStyle style(int first, int second) => ElStyle(vars: {'first': first, 'second': second});
      await tester.pumpWidget(
        shell(
          ElView(
            key: key,
            style: style(1, 1),
            child: Builder(
              builder: (context) {
                sourceContext = context;
                return SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      final source = tester.renderObject<ElRenderView>(find.byKey(key));
      late StateSetter rebuild;
      var updateDuringRead = false;
      int? first;
      int? second;
      final captured = InheritedTheme.captureAll(
        sourceContext,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            if (updateDuringRead) source.style = style(2, 2);
            first = ElView.of(context).getVar<int>('first');
            if (updateDuringRead) {
              updateDuringRead = false;
              source.style = style(1, 2);
            }
            second = ElView.of(context).getVar<int>('second');
            return SizedBox.shrink();
          },
        ),
      );
      final entry = OverlayEntry(builder: (_) => captured);
      Overlay.of(sourceContext).insert(entry);
      addTearDown(() {
        entry.remove();
        entry.dispose();
      });
      await tester.pumpAndSettle();
      expect((first, second), (1, 1));

      rebuild(() => updateDuringRead = true);
      await tester.pump();
      expect((first, second), (2, 2));

      await tester.pump();
      expect((first, second), (1, 2));
    });

    testWidgets('ElView.of 读取即订阅：仅被读取的状态位翻转才重建', (tester) async {
      const key = ValueKey('box');
      var hoverBuilds = 0;
      var disabledBuilds = 0;
      var lastHover = false;

      await tester.pumpWidget(
        shell(
          ElView(
            key: key,

            style: const ElStyle(width: 40, height: 40, backgroundColor: Color(0xFF000000)),
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    hoverBuilds++;
                    lastHover = ElView.of(context).hasHover;
                    return const SizedBox.shrink();
                  },
                ),
                Builder(
                  builder: (context) {
                    disabledBuilds++;
                    ElView.of(context).isDisabled;
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(hoverBuilds, 1);
      expect(disabledBuilds, 1);
      expect(lastHover, isFalse);

      await hoverAt(tester, find.byKey(key));
      await tester.pump();

      expect(hoverBuilds, 2, reason: 'hover 翻转重建 onHover 读取者');
      expect(disabledBuilds, 1, reason: 'onDisabled 读取者不因 hover 翻转重建');
      expect(lastHover, isTrue);
    });

    testWidgets('移除最后一个状态读者后即时退订，不依赖下次状态变化', (tester) async {
      final key = GlobalKey();
      var showReader = true;
      late StateSetter rebuild;
      await tester.pumpWidget(
        shell(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ElView(
                key: key,
                child: Column(
                  children: [
                    if (showReader)
                      Builder(
                        builder: (context) {
                          ElView.of(context).hasHover;
                          return SizedBox();
                        },
                      ),
                    SizedBox(),
                  ],
                ),
              );
            },
          ),
        ),
      );
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final source = render.stateSource;
      expect(source.hasListenerFor(ViewState.hover), isTrue);
      rebuild(() => showReader = false);
      await tester.pump();
      expect(render.stateSource, same(source));
      expect(source.hasListeners, isFalse);
      expect(source.hasListenerFor(ViewState.hover), isFalse);
      render.setTap(true);
      expect(render.internalStateHas(ViewState.tap), isTrue);
    });

    testWidgets('ElView.maybeOf：ElView 子树之外返回 null', (tester) async {
      ElStyleContext? ctx;
      await tester.pumpWidget(
        shell(
          Builder(
            builder: (context) {
              ctx = ElView.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(ctx, isNull);
    });

    for (final richInline in [false, true]) {
      testWidgets('状态读者换父后重新订阅最近宿主（rich=$richInline）', (tester) async {
        final firstKey = GlobalKey();
        final secondKey = GlobalKey();
        final readerKey = GlobalKey();
        var moved = false;
        var builds = 0;
        var hover = false;
        late StateSetter rebuild;
        final reader = Builder(
          key: readerKey,
          builder: (context) {
            builds++;
            hover = ElView.of(context).hasHover;
            return SizedBox(width: 10, height: 10);
          },
        );
        Object payload() => richInline ? [reader] : reader;
        await tester.pumpWidget(
          shell(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Row(
                  children: [
                    ElView(key: firstKey, child: moved ? null : payload()),
                    ElView(key: secondKey, child: moved ? payload() : null),
                  ],
                );
              },
            ),
          ),
        );
        final first = tester.renderObject<ElRenderView>(find.byKey(firstKey));
        final second = tester.renderObject<ElRenderView>(find.byKey(secondKey));
        final readerElement = readerKey.currentContext;
        first.setHover(true);
        await tester.pump();
        expect(hover, isTrue);

        rebuild(() => moved = true);
        await tester.pump();
        expect(readerKey.currentContext, same(readerElement));
        expect(hover, isFalse);
        expect(first.stateSource.hasListenerFor(ViewState.hover), isFalse);
        expect(second.stateSource.hasListenerFor(ViewState.hover), isTrue);

        final buildsAfterMove = builds;
        first.setHover(false);
        await tester.pump();
        expect(builds, buildsAfterMove, reason: '旧宿主已退订，状态变化不再重建读者');
        second.setHover(true);
        await tester.pump();
        expect(builds, buildsAfterMove + 1);
        expect(hover, isTrue);
      });
    }
  });

  group('组合场景', () {
    Widget shell(Widget child) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400, maxHeight: 1000), child: child),
      ),
    );

    ElRenderView viewOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    Future<void> pumpExample(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(shell(child));
      await tester.pump();
    }

    Future<void> hover(WidgetTester tester, Key key) async {
      viewOf(tester, key).setHover(true);
      await tester.pump();
    }

    group('组合状态', () {
      testWidgets('state variants commit hover, active, focus, focusWithin, disabled, and dark styles', (tester) async {
        const hoverKey = ValueKey('state-hover');
        const activeKey = ValueKey('state-active');
        const focusKey = ValueKey('state-focus');
        const focusWithinKey = ValueKey('state-focus-within');
        const disabledKey = ValueKey('state-disabled');
        const darkKey = ValueKey('state-dark');

        await pumpExample(
          tester,
          Column(
            children: [
              _box(
                hoverKey,
                const ElStyle(
                  backgroundColor: Colors.white,
                  onHover: ElStyle(backgroundColor: Color(0xFF3B82F6)),
                ),
              ),
              _box(
                activeKey,
                const ElStyle(
                  backgroundColor: Colors.white,
                  onTap: ElStyle(backgroundColor: Color(0xFFCBD5E1)),
                ),
              ),
              _box(
                focusKey,
                const ElStyle(
                  backgroundColor: Colors.white,
                  onFocus: ElStyle(outline: ElOutline(outlineColor: Color(0xFF3B82F6), outlineWidth: 2.5, outlineOffset: 3)),
                ),
              ),
              _box(
                focusWithinKey,
                const ElStyle(
                  backgroundColor: Colors.white,
                  onFocusWithin: ElStyle(backgroundColor: Color(0xFF3B82F6)),
                ),
              ),
              _box(
                disabledKey,
                const ElStyle(
                  backgroundColor: Colors.white,
                  onDisabled: ElStyle(backgroundColor: Color(0xFFCBD5E1), opacity: 0.4),
                ),
              ),
              _box(
                darkKey,
                const ElStyle(
                  backgroundColor: Colors.white,
                  onDark: ElStyle(backgroundColor: _darkSurface),
                ),
              ),
            ],
          ),
        );

        await hover(tester, hoverKey);
        viewOf(tester, activeKey).setTap(true);
        viewOf(tester, focusKey).setFocus(true);
        viewOf(tester, focusWithinKey).setFocusWithin(true);
        viewOf(tester, disabledKey).event = (viewOf(tester, disabledKey).event ?? ElEvent()).copyWith(disabled: true);
        viewOf(tester, darkKey).setDark(true);
        await tester.pump();

        expect(viewOf(tester, hoverKey).committedResolvedStyle.box.backgroundColor, const Color(0xFF3B82F6));
        expect(viewOf(tester, activeKey).committedResolvedStyle.box.backgroundColor, const Color(0xFFCBD5E1));
        expect(viewOf(tester, focusKey).committedResolvedStyle.box.outline!.outlineWidth, 2.5);
        expect(viewOf(tester, focusWithinKey).committedResolvedStyle.box.backgroundColor, const Color(0xFF3B82F6));
        expect(viewOf(tester, disabledKey).committedResolvedStyle.box.opacity, 0.4);
        expect(viewOf(tester, darkKey).committedResolvedStyle.box.backgroundColor, _darkSurface);
      });
    });
  });

  group('载荷引用复用', () {
    Widget shell(Widget child) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400), child: child),
      ),
    );

    testWidgets('List<Widget> 全量子项走零拷贝仍按序布局', (tester) async {
      const aKey = ValueKey('zc-a');
      const bKey = ValueKey('zc-b');
      const cKey = ValueKey('zc-c');

      await tester.pumpWidget(
        shell(
          const ElView(
            style: ElStyle(width: 200, height: 40),
            child: <Widget>[
              ElView(
                key: aKey,
                style: ElStyle(width: 30, height: 20, backgroundColor: Color(0xffff0000)),
              ),
              ElView(
                key: bKey,
                style: ElStyle(width: 30, height: 20, backgroundColor: Color(0xff00ff00)),
              ),
              ElView(
                key: cKey,
                style: ElStyle(width: 30, height: 20, backgroundColor: Color(0xff0000ff)),
              ),
            ],
          ),
        ),
      );

      final ax = tester.getTopLeft(find.byKey(aKey)).dx;
      final bx = tester.getTopLeft(find.byKey(bKey)).dx;
      final cx = tester.getTopLeft(find.byKey(cKey)).dx;
      expect(bx - ax, 30, reason: '快路径复用原列表不得打乱树序');
      expect(cx - bx, 30);
      expect(tester.getSize(find.byKey(bKey)), const Size(30, 20));
    });
  });

  group('禁用态指针', () {
    Widget shell(Widget child) => Directionality(
      textDirection: .ltr,
      child: ElView(
        style: ElStyle(alignment: .topLeft),
        child: child,
      ),
    );

    MouseCursor? activeCursor(WidgetTester tester) => tester.binding.mouseTracker.debugDeviceActiveCursor(1);

    for (final focusVariant in [false, true]) {
      testWidgets('禁用波纹按钮的文字和留白统一光标，焦点变体：$focusVariant', (tester) async {
        var taps = 0;
        Widget build(bool disabled) => shell(
          ElRippleTap(
            disabled: disabled,
            onPressed: () => taps++,
            style: ElStyle(
              width: 160,
              height: 60,
              alignment: .center,
              cursor: SystemMouseCursors.click,
              onFocusVisible: focusVariant ? ElStyle(backgroundColor: Color(0xffeeeeee)) : null,
            ),
            child: 'Button',
          ),
        );

        await tester.pumpWidget(build(true));
        final rect = tester.getRect(find.byType(ElRippleTap));
        final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: rect.center);
        await tester.pump();
        expect(activeCursor(tester), SystemMouseCursors.forbidden);
        await tester.tapAt(rect.center);
        expect(taps, 0);

        await mouse.moveTo(rect.topLeft + Offset(4, 4));
        await tester.pump();
        expect(activeCursor(tester), SystemMouseCursors.forbidden);

        await mouse.moveTo(rect.center);
        await tester.pumpWidget(build(false));
        expect(activeCursor(tester), SystemMouseCursors.click, reason: '鼠标不移动，解除禁用也应恢复');
        await tester.tapAt(rect.center);
        await tester.pumpAndSettle();
        expect(taps, 1);

        await tester.pumpWidget(build(true));
        expect(activeCursor(tester), SystemMouseCursors.forbidden);
      });
    }

    testWidgets('禁用命中边界拦住独立子事件与光标，解除后原样恢复', (tester) async {
      final hostKey = GlobalKey();
      final childKey = GlobalKey();
      var taps = 0;
      var enters = 0;
      var exits = 0;
      await tester.pumpWidget(
        shell(
          ElView(
            key: hostKey,
            style: ElStyle(width: 160, height: 60, alignment: .center),
            child: Row(
              mainAxisSize: .min,
              children: [
                ElView(
                  key: childKey,
                  style: ElStyle(cursor: SystemMouseCursors.click),
                  event: ElEvent(onTap: (_) => taps++, onPointerEnter: (_) => enters++, onPointerExit: (_) => exits++),
                  child: 'Child',
                ),
              ],
            ),
          ),
        ),
      );
      final host = tester.renderObject<ElRenderView>(find.byKey(hostKey));
      final child = tester.renderObject<ElRenderView>(find.byKey(childKey));
      final center = tester.getCenter(find.byKey(childKey));
      final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: center);
      await tester.pump();
      expect(activeCursor(tester), SystemMouseCursors.click);
      expect(enters, 1);

      host.event = (host.event ?? ElEvent()).copyWith(disabled: true);
      expect(tester.binding.hasScheduledFrame, isTrue, reason: '无视觉变体也要调度光标更新');
      await tester.pump();
      expect(activeCursor(tester), SystemMouseCursors.forbidden);
      expect(exits, 1, reason: '后代退出悬停，避免残留反馈');
      await tester.tapAt(center);
      expect(taps, 0);

      host.event = (host.event ?? ElEvent()).copyWith(disabled: false);
      await tester.pump();
      expect(activeCursor(tester), SystemMouseCursors.click);
      expect(enters, 2);
      expect(tester.renderObject(find.byKey(childKey)), same(child));
      await tester.tapAt(center);
      expect(taps, 1);
    });

    testWidgets('禁用宿主拦住原生 TextSpan 的点击和光标', (tester) async {
      final hostKey = GlobalKey();
      var taps = 0;
      final recognizer = TapGestureRecognizer()..onTap = () => taps++;
      addTearDown(recognizer.dispose);
      await tester.pumpWidget(
        shell(
          ElView(
            key: hostKey,
            event: ElEvent(disabled: true),
            style: ElStyle(width: 160, height: 60, alignment: .center),
            child: TextSpan(text: 'Span', mouseCursor: SystemMouseCursors.click, recognizer: recognizer),
          ),
        ),
      );
      final center = tester.getCenter(find.byKey(hostKey));
      final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: center);
      await tester.pump();
      expect(activeCursor(tester), SystemMouseCursors.forbidden);
      await tester.tapAt(center);
      expect(taps, 0);

      tester.renderObject<ElRenderView>(find.byKey(hostKey)).event =
          (tester.renderObject<ElRenderView>(find.byKey(hostKey)).event ?? ElEvent()).copyWith(disabled: false);
      await tester.pump();
      expect(activeCursor(tester), SystemMouseCursors.click);
      await tester.tapAt(center);
      expect(taps, 1);
    });

    testWidgets('禁用命中遵守圆角和 pointerEvents，不穿透按钮内部', (tester) async {
      final hostKey = GlobalKey();
      var taps = 0;
      Widget build({bool transparent = false}) => shell(
        ElStackView(
          children: [
            ElView(
              style: ElStyle(width: 120, height: 120, cursor: SystemMouseCursors.click),
              event: ElEvent(onTap: (_) => taps++),
            ),
            ElView(
              key: hostKey,
              event: ElEvent(disabled: true),
              style: ElStyle(
                width: 80,
                height: 80,
                borderRadius: BorderRadius.all(Radius.circular(9999)),
                clipBehavior: .antiAlias,
                pointerEvents: transparent ? .none : null,
              ),
              child: ElView(style: ElStyle(width: 80, height: 80, cursor: SystemMouseCursors.click)),
            ),
          ],
        ),
      );
      await tester.pumpWidget(build());
      final rect = tester.getRect(find.byKey(hostKey));
      final mouse = await tester.createGesture(kind: .mouse, pointer: 1);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: rect.center);
      await tester.pump();
      expect(activeCursor(tester), SystemMouseCursors.forbidden);
      await tester.tapAt(rect.center);
      expect(taps, 0);

      final corner = rect.topLeft + Offset(1, 1);
      await mouse.moveTo(corner);
      await tester.pump();
      expect(activeCursor(tester), SystemMouseCursors.click);
      await tester.tapAt(corner);
      expect(taps, 1);

      await mouse.moveTo(rect.center);
      await tester.pumpWidget(build(transparent: true));
      expect(activeCursor(tester), SystemMouseCursors.click);
      await tester.tapAt(rect.center);
      expect(taps, 2);
    });
  });

  group('事件禁用与上层样式', () {
    ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView));

    testWidgets('上层切换普通样式即可更新选中外观', (tester) async {
      Widget build(bool selected) => MaterialApp(
        home: ElView(style: ElStyle(backgroundColor: selected ? Color(0xFF22FF22) : Color(0xFF111111))),
      );
      for (final selected in [false, true, false]) {
        await tester.pumpWidget(build(selected));
        expect(renderOf(tester).committedResolvedStyle.box.backgroundColor, selected ? Color(0xFF22FF22) : Color(0xFF111111));
      }
    });

    group('disabled 样式', () {
      testWidgets('disabled=true 命中 onDisabled', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              event: ElEvent(disabled: true),
              style: ElStyle(
                backgroundColor: Color(0xFF111111),
                onDisabled: ElStyle(backgroundColor: Color(0xFF999999)),
              ),
            ),
          ),
        );
        expect(renderOf(tester).committedResolvedStyle.box.backgroundColor, const Color(0xFF999999));
      });

      testWidgets('disabled 优先级最高：冲突字段压过普通选中样式', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              event: ElEvent(disabled: true),

              style: ElStyle(
                backgroundColor: Color(0xFF22FF22),
                onDisabled: ElStyle(backgroundColor: Color(0xFF999999)),
              ),
            ),
          ),
        );
        expect(
          renderOf(tester).committedResolvedStyle.box.backgroundColor,
          const Color(0xFF999999),
          reason: 'disabled 是最高优先级，同字段冲突时压过普通样式',
        );
      });

      testWidgets('disabled 优先级最高：冲突字段压过 dark', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              event: ElEvent(disabled: true),
              style: ElStyle(
                backgroundColor: Color(0xFF111111),
                onDark: ElStyle(backgroundColor: Color(0xFF333333)),
                onDisabled: ElStyle(backgroundColor: Color(0xFF999999)),
              ),
            ),
          ),
        );
        final render = renderOf(tester);
        render.setDark(true);
        await tester.pump();
        expect(
          render.committedResolvedStyle.box.backgroundColor,
          const Color(0xFF999999),
          reason: 'disabled 压过 dark（dark 在新库原本优先级更高，现 disabled 置顶）',
        );
      });
    });

    group('disabled 事件门禁', () {
      testWidgets('disabled 时 tap 不触发', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ElView(
              style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF111111)),
              event: ElEvent(disabled: true, onTap: (_) => taps++),
            ),
          ),
        );
        await tester.tapAt(const Offset(50, 50));
        await tester.pump();
        expect(taps, 0, reason: 'disabled 吞掉指针事件，onTap 不应触发');
      });

      testWidgets('enabled 时 tap 正常触发', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ElView(
              style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF111111)),
              event: ElEvent(onTap: (_) => taps++),
            ),
          ),
        );
        await tester.tapAt(const Offset(50, 50));
        await tester.pump();
        expect(taps, 1);
      });

      testWidgets('运行时启用→禁用：tap 从触发变为不触发', (tester) async {
        var taps = 0;
        Widget build(bool disabled) => MaterialApp(
          home: ElView(
            style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF111111)),
            event: ElEvent(disabled: disabled, onTap: (_) => taps++),
          ),
        );

        await tester.pumpWidget(build(false));
        await tester.tapAt(const Offset(50, 50));
        await tester.pump();
        expect(taps, 1);

        await tester.pumpWidget(build(true));
        await tester.tapAt(const Offset(50, 50));
        await tester.pump();
        expect(taps, 1, reason: '禁用后再次 tap 不应增加计数');
      });

      testWidgets('按住期间进入 disabled 会取消 pending 序列且不污染下一次 tap', (tester) async {
        var taps = 0;
        var cancels = 0;
        var longPresses = 0;

        Widget build(bool disabled) => MaterialApp(
          home: ElView(
            style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF111111)),
            event: ElEvent(
              disabled: disabled,
              config: const ElEventConfig(longPressDelay: Duration(milliseconds: 20)),
              onTap: (_) => taps++,
              onTapCancel: (_) => cancels++,
              onLongPress: (_) => longPresses++,
            ),
          ),
        );

        await tester.pumpWidget(build(false));
        final gesture = await tester.startGesture(const Offset(50, 50));
        await tester.pump();

        await tester.pumpWidget(build(true));
        await tester.pump(const Duration(milliseconds: 40));
        await gesture.up();
        await tester.pump();

        expect(taps, 0);
        expect(cancels, 1);
        expect(longPresses, 0, reason: 'disabled must cancel the long press recognizer timer');

        await tester.pumpWidget(build(false));
        await tester.tapAt(const Offset(50, 50));
        await tester.pump();

        expect(taps, 1, reason: 'cleared pending state must not poison the next enabled tap');
      });

      testWidgets('GlobalKey reparent cancels held pointer sequence without losing event config', (tester) async {
        final key = GlobalKey();
        var taps = 0;

        Widget build({required bool right}) {
          final child = ElView(
            key: key,
            style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF111111)),
            event: ElEvent(onTap: (_) => taps++),
          );
          return MaterialApp(
            home: Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: 260,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      top: 0,
                      width: 120,
                      height: 120,
                      child: !right ? Center(child: child) : const SizedBox(),
                    ),
                    Positioned(
                      left: 140,
                      top: 0,
                      width: 120,
                      height: 120,
                      child: right ? Center(child: child) : const SizedBox(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(build(right: false));
        final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
        await tester.pump();

        await tester.pumpWidget(build(right: true));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(taps, 0, reason: 'reparent detach must cancel the old held pointer instead of completing a stale tap');

        await tester.tap(find.byKey(key));
        await tester.pump();
        expect(taps, 1, reason: 'preserved event config must keep working after reattach');
      });
    });

    group('disabled 光标', () {
      testWidgets('disabled 的事件表面显示 forbidden 光标', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ElView(
              style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF111111)),
              event: ElEvent(disabled: true, onTap: (_) {}),
            ),
          ),
        );
        expect(renderOf(tester).cursor, SystemMouseCursors.forbidden);
      });

      testWidgets('enabled 时无自定义光标 → defer', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ElView(
              style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF111111)),
              event: ElEvent(onTap: (_) {}),
            ),
          ),
        );
        expect(renderOf(tester).cursor, MouseCursor.defer);
      });
    });

    group('disabled 清除瞬时交互态', () {
      testWidgets('进入 disabled 清 hover；解除后不残留', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              style: ElStyle(
                backgroundColor: Color(0xFF111111),
                onHover: ElStyle(backgroundColor: Color(0xFFFF0000)),
                onDisabled: ElStyle(backgroundColor: Color(0xFF999999)),
              ),
            ),
          ),
        );
        final render = renderOf(tester);

        render.setHover(true);
        await tester.pump();
        expect(render.committedResolvedStyle.box.backgroundColor, const Color(0xFFFF0000), reason: 'hover 命中');

        render.event = (render.event ?? ElEvent()).copyWith(disabled: true);
        await tester.pump();
        expect(render.committedResolvedStyle.box.backgroundColor, const Color(0xFF999999), reason: 'disabled 胜出');

        render.event = (render.event ?? ElEvent()).copyWith(disabled: false);
        await tester.pump();
        expect(
          render.committedResolvedStyle.box.backgroundColor,
          const Color(0xFF111111),
          reason: '进入 disabled 时 hover 瞬时态已清，解除后回到基础样式而非残留 hover',
        );
      });
    });
  });

  group('挂载分配', () {
    const n = 100;

    Widget wrap(Widget child) => MediaQuery(
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    Widget rows(Widget Function(int i) row) =>
        Column(mainAxisSize: MainAxisSize.min, children: <Widget>[for (var i = 0; i < n; i++) row(i)]);

    void enlargeViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<Map<String, int>> mount(WidgetTester tester, Widget child) async {
      // 预热一轮：把 const canonical intern / 静态 memo 之类的一次性成本排除，
      // 只测稳态挂载的边际分配。
      await tester.pumpWidget(wrap(child));
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      BenchmarkProbe.reset();
      await tester.pumpWidget(wrap(child));
      return BenchmarkProbe.snapshot();
    }

    void report(String label, Map<String, int> s) {
      const keys = <String>[
        'paintControllerInstantiateCount',
        'textLayerInstantiateCount',
        'intrinsicsCacheInstantiateCount',
        'stateSourceInstantiateCount',
        'animDriverInstantiateCount',
        'focusStateInstantiateCount',
        'forgottenChildrenAllocCount',
      ];
      final buf = StringBuffer('\n[$label] N=$n\n');
      for (final k in keys) {
        buf.writeln('  ${k.replaceAll('InstantiateCount', '').replaceAll('AllocCount', '').padRight(22)} ${s[k]}');
      }
      // ignore: avoid_print
      print(buf);
    }

    testWidgets('裸行 × N：所有协作体分配恒 0', (tester) async {
      enlargeViewport(tester);
      final s = await mount(tester, rows((_) => const ElView()));
      report('裸行 ElView()', s);

      expect(s['paintControllerInstantiateCount'], 0, reason: '无盒装饰不得建 PaintController');
      expect(s['textLayerInstantiateCount'], 0, reason: '无文本载荷不得建 TextEngine');
      expect(s['intrinsicsCacheInstantiateCount'], 0, reason: '无 intrinsic 上游不得建 IntrinsicsCache');
      expect(s['stateSourceInstantiateCount'], 0, reason: '无 listener/group 不得建 ViewStateSource');
      expect(s['animDriverInstantiateCount'], 0, reason: '无 transitions 不得建 driver');
      expect(s['focusStateInstantiateCount'], 0, reason: '不可聚焦节点不得建焦点状态');
      expect(s['forgottenChildrenAllocCount'], 0, reason: '非多子路径不得建 _forgottenChildren');
    });

    testWidgets('纯文本行 × N：只建 TextEngine', (tester) async {
      enlargeViewport(tester);
      final s = await mount(tester, rows((i) => ElView(child: 'row $i')));
      report('纯文本行', s);

      expect(s['textLayerInstantiateCount'], n, reason: '每个文本节点恰一个 painter');
      expect(s['paintControllerInstantiateCount'], 0);
      expect(s['intrinsicsCacheInstantiateCount'], 0);
      expect(s['stateSourceInstantiateCount'], 0);
      expect(s['animDriverInstantiateCount'], 0);
      expect(s['focusStateInstantiateCount'], 0);
      expect(s['forgottenChildrenAllocCount'], 0);
    });

    testWidgets('有背景色的行 × N：只额外建 PaintController', (tester) async {
      enlargeViewport(tester);
      final s = await mount(
        tester,
        rows((_) => const ElView(style: ElStyle(width: 100, height: 8, backgroundColor: Color(0xff112233)))),
      );
      report('bgColor 行', s);

      expect(s['paintControllerInstantiateCount'], n, reason: '有绘制 op 每节点恰一个');
      expect(s['textLayerInstantiateCount'], 0);
      expect(s['intrinsicsCacheInstantiateCount'], 0);
      expect(s['animDriverInstantiateCount'], 0);
      expect(s['focusStateInstantiateCount'], 0);
      expect(s['forgottenChildrenAllocCount'], 0);
    });

    testWidgets('挂载 / 卸载往返 × 3：计数线性，无跨轮残留', (tester) async {
      enlargeViewport(tester);
      final child = rows((i) => ElView(child: 'row $i'));
      await tester.pumpWidget(wrap(child));
      await tester.pumpWidget(wrap(const SizedBox.shrink()));

      BenchmarkProbe.reset();
      for (var round = 0; round < 3; round++) {
        await tester.pumpWidget(wrap(child));
        await tester.pumpWidget(wrap(const SizedBox.shrink()));
      }
      final s = BenchmarkProbe.snapshot();
      report('往返 ×3（文本行）', s);

      // 每轮重新挂载 = 重新建 painter，3 轮 3N；超出说明同一轮内重复 ensure。
      expect(s['textLayerInstantiateCount'], 3 * n);
      expect(s['paintControllerInstantiateCount'], 0);
      expect(s['focusStateInstantiateCount'], 0);
      expect(s['forgottenChildrenAllocCount'], 0);
    });
  });

  group('指针事件穿透', () {
    const topKey = ValueKey('top');

    const bottomKey = ValueKey('bottom');

    Widget buildStack({
      required ElStyle topStyle,
      required VoidCallback onTopTap,
      required VoidCallback onBottomTap,
      Object? topChild,
    }) {
      return MaterialApp(
        home: Stack(
          children: [
            ElView(
              key: bottomKey,
              style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF222222)),
              event: ElEvent(onTap: (e) => onBottomTap()),
            ),
            ElView(
              key: topKey,
              style: topStyle,
              event: ElEvent(onTap: (e) => onTopTap()),
              child: topChild,
            ),
          ],
        ),
      );
    }

    group('pointer-events: none 基础穿透', () {
      testWidgets('none 覆盖层不吃 tap，命中穿透到下层', (tester) async {
        var topTapped = false, bottomTapped = false;
        await tester.pumpWidget(
          buildStack(
            topStyle: const ElStyle(pointerEvents: .none, width: 100, height: 100, backgroundColor: Color(0xFFFF0000)),
            onTopTap: () => topTapped = true,
            onBottomTap: () => bottomTapped = true,
          ),
        );
        await tester.tapAt(tester.getCenter(find.byKey(topKey)));
        expect(topTapped, isFalse);
        expect(bottomTapped, isTrue);
      });

      testWidgets('对照组：未声明时覆盖层正常吃 tap', (tester) async {
        var topTapped = false, bottomTapped = false;
        await tester.pumpWidget(
          buildStack(
            topStyle: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFFFF0000)),
            onTopTap: () => topTapped = true,
            onBottomTap: () => bottomTapped = true,
          ),
        );
        await tester.tapAt(tester.getCenter(find.byKey(topKey)));
        expect(topTapped, isTrue);
        expect(bottomTapped, isFalse);
      });

      testWidgets('none 下 onHover 变体不激活', (tester) async {
        await tester.pumpWidget(
          buildStack(
            topStyle: const ElStyle(
              pointerEvents: .none,
              width: 100,
              height: 100,
              backgroundColor: Color(0xFF111111),
              onHover: ElStyle(backgroundColor: Color(0xFF22FF22)),
            ),
            onTopTap: () {},
            onBottomTap: () {},
          ),
        );
        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.byKey(topKey)));
        await tester.pump();
        final render = tester.renderObject<ElRenderView>(find.byKey(topKey));
        expect(render.committedResolvedStyle.box.backgroundColor, const Color(0xFF111111));
      });
    });

    group('继承与重新启用', () {
      testWidgets('隔着纯布局 widget 的未声明 El 后代一并透明', (tester) async {
        var childTapped = false, bottomTapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Stack(
              children: [
                ElView(
                  key: bottomKey,
                  style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFF222222)),
                  event: ElEvent(onTap: (e) => bottomTapped = true),
                ),
                ElView(
                  key: topKey,
                  style: const ElStyle(pointerEvents: .none, width: 100, height: 100),
                  child: Row(
                    children: [
                      ElView(
                        style: const ElStyle(width: 50, height: 50, backgroundColor: Color(0xFF3333FF)),
                        event: ElEvent(onTap: (e) => childTapped = true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        // 落点在蓝色孙节点内（左上 50×50 区域中心）。
        final origin = tester.getTopLeft(find.byKey(topKey));
        await tester.tapAt(origin + const Offset(25, 25));
        expect(childTapped, isFalse);
        expect(bottomTapped, isTrue);
      });

      testWidgets('El 后代显式 auto 重新启用，事件冒泡回 none 祖先', (tester) async {
        var ancestorTapped = false, childTapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: ElView(
              key: topKey,
              style: const ElStyle(pointerEvents: .none, width: 100, height: 100),
              event: ElEvent(onTap: (e) => ancestorTapped = true),
              child: ElView(
                style: const ElStyle(pointerEvents: .auto, width: 50, height: 50, backgroundColor: Color(0xFF3333FF)),
                event: ElEvent(onTap: (e) => childTapped = true),
              ),
            ),
          ),
        );
        final origin = tester.getTopLeft(find.byKey(topKey));
        // 后代内：后代命中 + 冒泡链穿过 none 祖先（DOM 传播口径）。
        await tester.tapAt(origin + const Offset(25, 25));
        expect(childTapped, isTrue);
        expect(ancestorTapped, isTrue);

        // 后代外、祖先盒内：祖先自身仍透明。
        ancestorTapped = false;
        childTapped = false;
        await tester.tapAt(origin + const Offset(80, 80));
        expect(childTapped, isFalse);
        expect(ancestorTapped, isFalse);
      });

      testWidgets('非 El 内容（Icon）不能自行重新启用', (tester) async {
        var bottomTapped = false;
        await tester.pumpWidget(
          buildStack(
            topStyle: const ElStyle(pointerEvents: .none, width: 100, height: 100, alignment: .center),
            onTopTap: () {},
            onBottomTap: () => bottomTapped = true,
            topChild: const Icon(Icons.star, size: 48),
          ),
        );
        // 落点在图标上：icon 的 render 命中被 none 闸门整体丢弃，穿透到下层。
        await tester.tapAt(tester.getCenter(find.byIcon(Icons.star)));
        expect(bottomTapped, isTrue);
      });

      testWidgets('文本字形命中被 none 关闭', (tester) async {
        var topTapped = false, bottomTapped = false;
        await tester.pumpWidget(
          buildStack(
            topStyle: const ElStyle(pointerEvents: .none, width: 100, height: 100, fontSize: 40),
            onTopTap: () => topTapped = true,
            onBottomTap: () => bottomTapped = true,
            topChild: 'MMMM',
          ),
        );
        // 落点在首字形内。
        final origin = tester.getTopLeft(find.byKey(topKey));
        await tester.tapAt(origin + const Offset(15, 20));
        expect(topTapped, isFalse);
        expect(bottomTapped, isTrue);
      });
    });

    group('运行时切换与合成', () {
      testWidgets('none ↔ 未声明 翻转即时生效', (tester) async {
        var topTapped = false, bottomTapped = false;
        Widget build(ElPointerEvents? pe) => buildStack(
          topStyle: ElStyle(pointerEvents: pe, width: 100, height: 100, backgroundColor: const Color(0xFFFF0000)),
          onTopTap: () => topTapped = true,
          onBottomTap: () => bottomTapped = true,
        );

        await tester.pumpWidget(build(.none));
        await tester.tapAt(tester.getCenter(find.byKey(topKey)));
        expect(topTapped, isFalse);
        expect(bottomTapped, isTrue);

        bottomTapped = false;
        await tester.pumpWidget(build(null));
        await tester.tapAt(tester.getCenter(find.byKey(topKey)));
        expect(topTapped, isTrue);
        expect(bottomTapped, isFalse);
      });

      test('copyWith / merge 携带 pointerEvents', () {
        const base = ElStyle(backgroundColor: Color(0xFF111111));
        final copied = base.copyWith(pointerEvents: ElPointerEvents.none);
        expect(copied.pointerEvents, ElPointerEvents.none);
        expect(copied.backgroundColor, const Color(0xFF111111));

        const overlay = ElStyle(pointerEvents: .none);
        final merged = base.merge(overlay);
        expect(merged.pointerEvents, ElPointerEvents.none);

        // merge 空值不清除已有声明。
        final kept = overlay.merge(const ElStyle(backgroundColor: Color(0xFF222222)));
        expect(kept.pointerEvents, ElPointerEvents.none);
      });
    });
  });

  group('空视图与对象复用', () {
    Widget shell(Widget child) {
      return MediaQuery(
        data: MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 800, maxHeight: 600), child: child),
          ),
        ),
      );
    }

    group('T28 — EmptyView 零税基线', () {
      testWidgets('EmptyView × 10：5 计数器全 0', (tester) async {
        BenchmarkProbe.reset();
        await tester.pumpWidget(shell(Wrap(children: List<Widget>.generate(10, (i) => ElView()))));
        final snap = BenchmarkProbe.snapshot();
        expect(snap['stateSourceInstantiateCount'], 0, reason: '空 ElView 不应触发 stateSource alloc');
        expect(snap['animDriverInstantiateCount'], 0, reason: '空 ElView 无 transitions 不应触发 driver alloc');
        expect(snap['textLayerInstantiateCount'], 0, reason: '空 ElView 无文本内容不应触发 TextEngine alloc');
        expect(snap['textLayerInstantiateCount'], 0, reason: '空 ElView 无文本载荷不应触发 textLayer alloc');
        expect(
          snap['intrinsicsCacheInstantiateCount'],
          0,
          reason: '空 ElView 无 IntrinsicWidth 上游包裹不应触发 intrinsicsCache alloc',
        );
      });

      testWidgets('SizedBox 静态 style 无变体：5 计数器全 0', (tester) async {
        BenchmarkProbe.reset();
        await tester.pumpWidget(
          shell(
            Wrap(
              children: List<Widget>.generate(
                10,
                (i) => ElView(style: .new(width: 20, height: 20, backgroundColor: Color(0xff00ff00))),
              ),
            ),
          ),
        );
        final snap = BenchmarkProbe.snapshot();
        expect(snap['stateSourceInstantiateCount'], 0);
        expect(snap['animDriverInstantiateCount'], 0);
        expect(snap['textLayerInstantiateCount'], 0);
        expect(snap['textLayerInstantiateCount'], 0);
        expect(snap['intrinsicsCacheInstantiateCount'], 0);
      });

      testWidgets('Column 多子（Flutter 布局）：5 计数器全 0', (tester) async {
        BenchmarkProbe.reset();
        await tester.pumpWidget(
          shell(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(
                5,
                (i) => ElView(style: .new(width: 30, height: 30, backgroundColor: Color(0xff0000ff))),
              ),
            ),
          ),
        );
        final snap = BenchmarkProbe.snapshot();
        expect(snap['stateSourceInstantiateCount'], 0, reason: '无变体 ElView 子：不应有 stateSource');
        expect(snap['animDriverInstantiateCount'], 0);
        expect(snap['textLayerInstantiateCount'], 0);
        expect(snap['textLayerInstantiateCount'], 0);
        expect(snap['intrinsicsCacheInstantiateCount'], 0);
      });

      testWidgets('widget 子 ElView：textLayer 不 alloc', (tester) async {
        BenchmarkProbe.reset();
        await tester.pumpWidget(
          shell(
            ElView(
              style: .new(width: 100, height: 100, backgroundColor: Color(0xffcccccc)),
              child: SizedBox(width: 50, height: 50),
            ),
          ),
        );
        final snap = BenchmarkProbe.snapshot();
        expect(snap['textLayerInstantiateCount'], 0, reason: 'widget 子不是文本载荷，不应触发 textLayer alloc');
        expect(snap['textLayerInstantiateCount'], 0);
      });
    });

    group('T28 — 命中路径行为不变', () {
      testWidgets('文本节点：TextEngine alloc', (tester) async {
        BenchmarkProbe.reset();
        await tester.pumpWidget(
          shell(
            SizedBox(
              width: 240,
              child: ElView(style: .new(fontSize: 14), child: 'hello'),
            ),
          ),
        );
        final snap = BenchmarkProbe.snapshot();
        // 有文本内容：TextEngine 必然 alloc（setTextPayload 即 ensure）。
        expect(snap['textLayerInstantiateCount'], greaterThanOrEqualTo(1));
        // 但 stateSource / animDriver / groupWalker 应该仍 0
        // （无 hover 变体 / 无 transitions）。
        expect(snap['stateSourceInstantiateCount'], 0);
        expect(snap['animDriverInstantiateCount'], 0);
      });

      testWidgets('IntrinsicWidth 上游包裹：正确测量且无需额外缓存对象', (tester) async {
        BenchmarkProbe.reset();
        await tester.pumpWidget(shell(IntrinsicWidth(child: ElView(style: .new(width: 40, height: 40)))));
        final snap = BenchmarkProbe.snapshot();
        expect(tester.getSize(find.byType(ElView)), const Size(40, 40));
        expect(snap['intrinsicsCacheInstantiateCount'], 0);
      });

      testWidgets('transitions 声明：仅 mount 不 alloc driver；style 变化后 alloc', (tester) async {
        Widget build(Color color) => shell(
          ElView(
            style: .new(
              width: 40,
              height: 40,
              backgroundColor: color,
              transition: [ElTransition.all(Duration(milliseconds: 200))],
            ),
          ),
        );
        BenchmarkProbe.reset();
        await tester.pumpWidget(build(Color(0xffff0000)));
        // T28 语义：mount 期 `_transitionsEnabled=false`（CSS 首次出现不过渡），
        // `_reresolve` 传 driver=null，不 alloc；只在真正触发动画（style 变化 +
        // 已启闸门）时才 ensure。
        expect(BenchmarkProbe.animDriverInstantiateCount, 0, reason: 'mount 期不应 alloc driver');
        // 触发 style 变化：闸门已开、有 transitions → ensure driver。
        await tester.pumpWidget(build(Color(0xff0000ff)));
        await tester.pump();
        expect(
          BenchmarkProbe.animDriverInstantiateCount,
          greaterThanOrEqualTo(1),
          reason: 'style 变化触发的 _reresolve 应 ensure driver',
        );
      });

      testWidgets('变体声明 transitions（base 为 null）：hover 过渡仍动画、driver 按需 alloc', (tester) async {
        // **回归锁**：driver 懒化门禁若只看 base `_style?.transitions`，会把
        // "base 为 null、onHover 变体声明过渡"的节点动画静默禁用（effective
        // transitions 按 CSS longhand 覆盖语义可来自 各个嵌套变体，
        // 见 mayDeclareTransitionsOf）。
        const key = ValueKey('t28-variant-transition');
        BenchmarkProbe.reset();
        await tester.pumpWidget(
          shell(
            ElView(
              key: key,
              style: .new(
                width: 100,
                height: 40,
                backgroundColor: Color(0xffff0000),
                onHover: .new(backgroundColor: Color(0xff0000ff), transition: [ElTransition.all(Duration(milliseconds: 200))]),
              ),
            ),
          ),
        );
        expect(BenchmarkProbe.animDriverInstantiateCount, 0, reason: 'mount 期闸门未开，不 alloc');

        final render = tester.renderObject<ElRenderView>(find.byKey(key));
        render.setHover(true);
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100));
        final mid = render.committedResolvedStyle.box.backgroundColor;
        expect(mid, isNot(Color(0xffff0000)), reason: '过渡中途不应停在起点（变体过渡被静默禁用的症状）');
        expect(mid, isNot(Color(0xff0000ff)), reason: '过渡中途不应瞬移到终点（无动画直接 snap 的症状）');
        expect(BenchmarkProbe.animDriverInstantiateCount, greaterThanOrEqualTo(1));

        await tester.pump(Duration(milliseconds: 150));
        expect(render.committedResolvedStyle.box.backgroundColor, Color(0xff0000ff));
      });

      testWidgets('内部重绘订阅按需创建状态源', (tester) async {
        const key = ValueKey('t28-state-source');
        BenchmarkProbe.reset();
        await tester.pumpWidget(shell(ElView(key: key, style: .new(width: 40, height: 40))));
        tester.renderObject<ElRenderView>(find.byKey(key)).stateSource.addListener(() {});
        final snap = BenchmarkProbe.snapshot();
        expect(snap['stateSourceInstantiateCount'], greaterThanOrEqualTo(1));
      });
    });

    group('T28 — 空守卫等价性', () {
      testWidgets('EmptyView markNeedsLayout 循环：不摸活 intrinsics', (tester) async {
        Key key = UniqueKey();
        await tester.pumpWidget(shell(ElView(key: key)));
        BenchmarkProbe.reset();
        final rv = tester.renderObject(find.byKey(key));
        rv.markNeedsLayout();
        rv.markNeedsLayout();
        rv.markNeedsLayout();
        await tester.pump();
        final snap = BenchmarkProbe.snapshot();
        expect(snap['intrinsicsCacheInstantiateCount'], 0);
      });
    });
  });
}

class _StateListenerProbe {
  int calls = 0;
  void changed() => calls++;
}
