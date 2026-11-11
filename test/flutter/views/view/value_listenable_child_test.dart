import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/views/view/element/view_element.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('通知直接换字，保留 Element、Render 和 painter，且不触发 Widget 更新', (tester) async {
    final source = _TrackedNotifier('初始文本');
    addTearDown(source.dispose);
    final semantics = tester.ensureSemantics();
    final key = GlobalKey();
    final counts = _UpdateCounts();
    final view = _ObservedView(
      key: key,
      counts: counts,
      style: ElStyle(width: 240, fontSize: 14),
      semantics: ElSemantics(container: true),
      child: source,
    );
    await tester.pumpWidget(_scene(view));
    final element = tester.element(find.byKey(key));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = (render.content as TextEngine?)!;
    final painter = engine.painterForTest;
    expect(painter.text!.toPlainText(), '初始文本');
    expect(tester.getSemantics(find.byKey(key)).label, '初始文本');
    expect(source.listenerCount, 1);
    counts.reset();

    source.value = '更新后的文本';
    await tester.pump();

    expect(tester.element(find.byKey(key)), same(element));
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect((render.content as TextEngine?), same(engine));
    expect(engine.painterForTest, same(painter));
    expect(painter.text!.toPlainText(), '更新后的文本');
    expect(tester.getSemantics(find.byKey(key)).label, '更新后的文本');
    expect(counts.work, (0, 0, 0), reason: '换字不应经过 Element.update、performRebuild 或 updateRenderObject');

    final layouts = render.debugLayoutCount;
    source.ping();
    await tester.pump();
    expect(render.debugLayoutCount, layouts, reason: '重复通知同一文本不应再次排版');
    expect(counts.work, (0, 0, 0));
    expect(tester.takeException(), isNull);
    semantics.dispose();
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('同源不重复订阅，换源、普通 child 和卸载都释放旧监听', (tester) async {
    final first = _TrackedNotifier('第一来源');
    final second = _TrackedNotifier('第二来源');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final key = GlobalKey();
    final counts = _UpdateCounts();
    Widget scene(Object? child) =>
        _scene(_ObservedView(key: key, counts: counts, style: ElStyle(width: 240, fontSize: 14), child: child));

    await tester.pumpWidget(scene(first));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    await tester.pumpWidget(scene(first));
    expect(first.listenerCount, 1);
    expect(first.addCalls, 1);
    expect(first.removeCalls, 0);

    await tester.pumpWidget(scene(second));
    expect(first.listenerCount, 0);
    expect(second.listenerCount, 1);
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '第二来源');
    first.value = '旧来源不得覆盖新值';
    await tester.pump();
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '第二来源');

    second.value = '新来源仍能更新';
    await tester.pump();
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '新来源仍能更新');
    await tester.pumpWidget(scene('普通文本'));
    expect(second.listenerCount, 0);
    second.value = '已退订';
    await tester.pump();
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '普通文本');

    await tester.pumpWidget(scene(second));
    expect(second.listenerCount, 1);
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '已退订');
    await tester.pumpWidget(SizedBox.shrink());
    expect(first.listenerCount, 0);
    expect(second.listenerCount, 0);
    expect(first.disposed, isFalse);
    expect(second.disposed, isFalse);
    first.value = '卸载后仍由调用方持有';
    second.value = '卸载后继续使用';
    expect(tester.takeException(), isNull);
  });

  testWidgets('空值和普通值直接切换，首次文字使用最新的环境缩放', (tester) async {
    final source = _TrackedNotifier<Object?>(null);
    addTearDown(source.dispose);
    final key = GlobalKey();
    final counts = _UpdateCounts();
    final view = _ObservedView(key: key, counts: counts, style: ElStyle(width: 240, fontSize: 14), child: source);
    await tester.pumpWidget(_scene(view));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    expect((render.content as TextEngine?), isNull);
    await tester.pumpWidget(_scene(view, scale: 2));
    counts.reset();

    source.value = 42;
    await tester.pump();
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '42');
    expect((render.content as TextEngine?)!.painterForTest.textScaler.scale(10), 20);
    counts.reset();
    source.value = true;
    await tester.pump();
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), 'true');
    expect(counts.work, (0, 0, 0), reason: '文本模式内普通值换字仍应直接更新引擎');
    source.value = null;
    await tester.pump();
    expect((render.content as TextEngine?), isNull);
    source.value = '恢复文本';
    await tester.pump();
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '恢复文本');
    expect((render.content as TextEngine?)!.painterForTest.textScaler.scale(10), 20);
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('动态独立图标不缩放，切回文字恢复环境缩放', (tester) async {
    final icon = IconData(0x41, fontFamily: 'Ahem');
    final source = _TrackedNotifier<Object?>(icon);
    addTearDown(source.dispose);
    final staticKey = GlobalKey();
    final dynamicKey = GlobalKey();
    final counts = _UpdateCounts();
    final style = ElStyle(iconSize: 24, fontSize: 14);
    await tester.pumpWidget(
      _scene(
        Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            ElView(key: staticKey, style: style, child: icon),
            _ObservedView(key: dynamicKey, counts: counts, style: style, child: source),
          ],
        ),
        scale: 2,
      ),
    );
    final reference = tester.renderObject<ElRenderView>(find.byKey(staticKey));
    final render = tester.renderObject<ElRenderView>(find.byKey(dynamicKey));
    expect((reference.content as TextEngine).painterForTest.textScaler.scale(10), 10);
    expect((render.content as TextEngine).painterForTest.textScaler.scale(10), 10);
    expect(render.size, reference.size);
    expect(render.size, Size.square(24));

    source.value = '文字';
    await tester.pump();
    expect((render.content as TextEngine).painterForTest.textScaler.scale(10), 20);
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '文字');
    counts.reset();
    source.value = '后续文字仍直接更新';
    await tester.pump();
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '后续文字仍直接更新');
    expect(counts.work, (0, 0, 0));

    source.value = icon;
    await tester.pump();
    expect(tester.renderObject(find.byKey(dynamicKey)), same(render));
    expect((render.content as TextEngine).painterForTest.textScaler.scale(10), 10);
    expect(render.size, reference.size);
    expect(source.listenerCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('文字和 Widget、WidgetSpan 切换时同步维护实际子树', (tester) async {
    final source = _TrackedNotifier<Object?>('纯文字');
    addTearDown(source.dispose);
    final key = GlobalKey();
    final boxKey = ValueKey('普通子项');
    final inlineKey = ValueKey('行内子项');
    await tester.pumpWidget(_scene(ElView(key: key, style: ElStyle(width: 240, fontSize: 14), child: source)));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));

    source.value = SizedBox(key: boxKey, width: 32, height: 18);
    await tester.pump();
    expect(find.byKey(boxKey), findsOneWidget);
    expect(render.childCount, 1);
    expect((render.content as TextEngine?), isNull);

    source.value = TextSpan(
      children: [
        TextSpan(text: '前'),
        WidgetSpan(child: SizedBox(key: inlineKey, width: 14, height: 10)),
        TextSpan(text: '后'),
      ],
    );
    await tester.pump();
    expect(find.byKey(boxKey), findsNothing);
    expect(find.byKey(inlineKey), findsOneWidget);
    expect(render.childCount, 1);
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), contains('前'));
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), contains('后'));

    source.value = '恢复纯文字';
    await tester.pump();
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect(find.byKey(inlineKey), findsNothing);
    expect(render.childCount, 0);
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '恢复纯文字');
    expect(source.listenerCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('GlobalKey 换父期间改值，激活后读到最新值且继续直接更新', (tester) async {
    final source = _TrackedNotifier('移动前');
    addTearDown(source.dispose);
    final key = GlobalKey();
    final counts = _UpdateCounts();
    final view = _ObservedView(key: key, counts: counts, style: ElStyle(width: 180, fontSize: 14), child: source);
    Widget scene(bool moved) => _scene(
      Row(
        children: [
          SizedBox(width: 200, child: moved ? null : view),
          SizedBox(width: 200, child: moved ? view : null),
        ],
      ),
    );

    await tester.pumpWidget(scene(false));
    final element = tester.element(find.byKey(key));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    counts.onDeactivate = () => source.value = '停用期间的新值';
    await tester.pumpWidget(scene(true));
    counts.onDeactivate = null;

    expect(tester.element(find.byKey(key)), same(element));
    expect(tester.renderObject(find.byKey(key)), same(render));
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '停用期间的新值');
    expect(source.listenerCount, 1);
    counts.reset();
    source.value = '移动后仍直接更新';
    await tester.pump();
    expect((render.content as TextEngine?)!.painterForTest.text!.toPlainText(), '移动后仍直接更新');
    expect(counts.work, (0, 0, 0));
    await tester.pumpWidget(SizedBox.shrink());
    expect(source.listenerCount, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('纯盒即使声明高级文本样式也不订阅文本环境', (tester) async {
    final key = GlobalKey();
    final counts = _UpdateCounts();
    final view = _ObservedView(
      key: key,
      counts: counts,
      style: ElStyle(width: 80, height: 40, textOptions: ElTextOptions(locale: Locale('ja')), wordSpacing: 2),
      child: SizedBox(width: 20, height: 20),
    );
    await tester.pumpWidget(_scene(view));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final layouts = render.debugLayoutCount;
    counts.reset();
    await tester.pumpWidget(_scene(view, scale: 2, bold: true));
    await tester.binding.handleSystemMessage({'type': 'fontsChange'});
    await tester.pump();
    expect(render.content, isNull);
    expect(selectionParticipantOf(render), isNull);
    expect(render.debugLayoutCount, layouts);
    expect(counts.work, (0, 0, 0));
  });

  for (final widgetChild in [false, true]) {
    testWidgets('文本退出到 ${widgetChild ? 'Widget' : 'null'} 后释放环境，恢复使用当前设置', (tester) async {
      final source = _TrackedNotifier<Object?>('before');
      addTearDown(source.dispose);
      final key = GlobalKey();
      final counts = _UpdateCounts();
      final view = _ObservedView(
        key: key,
        counts: counts,
        style: ElStyle(width: 160, height: 40, fontSize: 10),
        child: source,
      );
      await tester.pumpWidget(_scene(view));
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final previous = render.content;
      expect(previous, isA<TextEngine>());
      source.value = widgetChild ? SizedBox(width: 12, height: 12) : null;
      await tester.pump();
      expect(render.content, isNull);
      expect(selectionParticipantOf(render), isNull);
      final layouts = render.debugLayoutCount;
      counts.reset();
      await tester.pumpWidget(_scene(view, scale: 2, bold: true));
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pump();
      expect(render.content, isNull);
      expect(render.debugLayoutCount, layouts);
      expect(counts.work, (0, 0, 0), reason: '退出文本后不能留下 MediaQuery 或字体监听');
      source.value = 'restored';
      await tester.pump();
      final engine = render.content as TextEngine;
      expect(engine, isNot(same(previous)));
      expect(engine.painterForTest.textScaler.scale(10), 20);
      expect(engine.painterForTest.text!.style!.fontWeight, FontWeight.bold);
      expect(tester.renderObject(find.byKey(key)), same(render));
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _scene(Widget child, {double scale = 1, bool bold = false}) => Directionality(
  textDirection: .ltr,
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale), boldText: bold),
    child: Align(alignment: .topLeft, child: child),
  ),
);

class _UpdateCounts {
  int elementUpdates = 0;
  int rebuilds = 0;
  int renderUpdates = 0;
  VoidCallback? onDeactivate;

  (int, int, int) get work => (elementUpdates, rebuilds, renderUpdates);

  void reset() {
    elementUpdates = 0;
    rebuilds = 0;
    renderUpdates = 0;
  }
}

class _ObservedView extends ElView {
  // 观测节点按测试约定不使用 const 构造。
  // ignore: prefer_const_constructors_in_immutables
  _ObservedView({required this.counts, super.key, super.child, super.style, super.semantics});

  final _UpdateCounts counts;

  @override
  RenderObjectElement createElement() => _ObservedElement(this, counts);

  @override
  void updateRenderObject(BuildContext context, ElRenderView renderObject) {
    counts.renderUpdates++;
    super.updateRenderObject(context, renderObject);
  }
}

class _ObservedElement extends ViewElement {
  _ObservedElement(super.widget, this.counts);

  final _UpdateCounts counts;

  @override
  void update(covariant ElView newWidget) {
    counts.elementUpdates++;
    super.update(newWidget);
  }

  @override
  void performRebuild() {
    counts.rebuilds++;
    super.performRebuild();
  }

  @override
  void deactivate() {
    super.deactivate();
    counts.onDeactivate?.call();
  }
}

class _TrackedNotifier<T> extends ValueNotifier<T> {
  _TrackedNotifier(super.value);

  final List<VoidCallback> _listeners = [];
  int addCalls = 0;
  int removeCalls = 0;
  bool disposed = false;

  int get listenerCount => _listeners.length;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners.add(listener);
    addCalls++;
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners.remove(listener);
    removeCalls++;
  }

  void ping() => notifyListeners();

  @override
  void dispose() {
    disposed = true;
    _listeners.clear();
    super.dispose();
  }
}
