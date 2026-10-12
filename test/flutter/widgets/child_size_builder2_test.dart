import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('首帧测量 child 并用文本显示 size，builder 可以不显示 child', (tester) async {
    await tester.pumpWidget(
      _scene(SizedBox(width: 80, height: 40), showChild: false),
    );
    expect(find.text('size: Size(80.0, 40.0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('测量和显示只创建一个 State，更新尺寸时保持实例', (tester) async {
    final model = ValueNotifier(Size(80, 40));
    final events = <String>[];
    final key = GlobalKey<_ContentState>();
    addTearDown(model.dispose);
    Widget scene() => _scene(_Content(key: key, model: model, events: events));
    await tester.pumpWidget(scene());
    final state = key.currentState;
    expect(events, ['init']);
    expect(find.text('size: Size(80.0, 40.0)'), findsOneWidget);
    model.value = Size(120, 60);
    await tester.pump();
    expect(find.text('size: Size(120.0, 60.0)'), findsOneWidget);
    expect(key.currentState, same(state));
    await tester.pumpWidget(scene());
    expect(key.currentState, same(state));
    expect(events, ['init']);
    await tester.pumpWidget(SizedBox());
    expect(events, ['init', 'dispose']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('带外部 FocusNode 的真实内容只挂载一次并保持键盘输入', (tester) async {
    final node = FocusNode();
    final controller = TextEditingController();
    final key = GlobalKey();
    addTearDown(node.dispose);
    addTearDown(controller.dispose);
    Widget scene(double width) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElChildSizeBuilder2(
            child: SizedBox(
              width: width,
              child: TextField(
                key: key,
                autofocus: true,
                focusNode: node,
                controller: controller,
              ),
            ),
            builder: (size, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('size: $size'), child],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene(200));
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    final state = key.currentState;
    await tester.enterText(find.byKey(key), 'kept');
    final editing = TextEditingValue(
      text: 'kept',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 1, end: 3),
    );
    tester.testTextInput.updateEditingValue(editing);
    tester.testTextInput.log.clear();
    await tester.pumpWidget(scene(250));
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    expect(key.currentState, same(state));
    expect(controller.text, 'kept');
    expect(controller.value, editing);
    expect(tester.testTextInput.hasAnyClients, isTrue);
    expect(
      tester.testTextInput.log.where(
        (call) => call.method == 'TextInput.clearClient',
      ),
      isEmpty,
    );
    expect(find.byType(TextField), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(node.hasPrimaryFocus, isTrue);
    await tester.enterText(find.byKey(key), 'still editable');
    expect(controller.text, 'still editable');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('不显示 child 时，测量内容不能抢走外部焦点或处理键盘', (tester) async {
    final outer = FocusNode();
    final measured = FocusNode();
    addTearDown(outer.dispose);
    addTearDown(measured.dispose);
    var hiddenKeys = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Focus(focusNode: outer, child: Text('outside')),
              ElChildSizeBuilder2(
                child: Focus(
                  focusNode: measured,
                  autofocus: true,
                  onKeyEvent: (_, _) {
                    hiddenKeys++;
                    return KeyEventResult.handled;
                  },
                  child: SizedBox(width: 80, height: 40),
                ),
                builder: (size, _) => Text('size: $size'),
              ),
            ],
          ),
        ),
      ),
    );
    outer.requestFocus();
    await tester.pump();
    measured.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(outer.hasPrimaryFocus, isTrue);
    expect(measured.canRequestFocus, isFalse);
    expect(hiddenKeys, 0);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('首帧只有真实内容进入语义树，没有测量副本', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _scene(
          Semantics(label: 'content', child: SizedBox(width: 80, height: 40)),
        ),
      );
      expect(find.bySemanticsLabel('content'), findsOneWidget);
      expect(find.bySemanticsLabel('size: Size(80.0, 40.0)'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('指定测量约束改变后首帧显示新尺寸', (tester) async {
    await tester.pumpWidget(
      _scene(
        SizedBox(width: 200, height: 100),
        constraints: BoxConstraints.tight(Size(90, 30)),
      ),
    );
    expect(find.text('size: Size(90.0, 30.0)'), findsOneWidget);
    await tester.pumpWidget(
      _scene(
        SizedBox(width: 200, height: 100),
        constraints: BoxConstraints.tight(Size(70, 20)),
      ),
    );
    expect(find.text('size: Size(70.0, 20.0)'), findsOneWidget);
  });

  testWidgets('父约束改变后重新测量换行文本', (tester) async {
    late Size measured;
    Widget scene(double width) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          child: ElChildSizeBuilder2(
            child: Text('a long piece of text that wraps over several lines'),
            builder: (size, child) {
              measured = size;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text('size: $size'), child],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene(200));
    final wide = measured;
    await tester.pumpWidget(scene(80));
    expect(measured.width, lessThanOrEqualTo(80));
    expect(measured.height, greaterThan(wide.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('尺寸不变也应用新 builder 的外层结构', (tester) async {
    await tester.pumpWidget(
      _scene(SizedBox(width: 80, height: 40), prefix: 'first'),
    );
    await tester.pumpWidget(
      _scene(SizedBox(width: 80, height: 40), prefix: 'second'),
    );
    expect(find.text('second: Size(80.0, 40.0)'), findsOneWidget);
    expect(find.text('first: Size(80.0, 40.0)'), findsNothing);
  });

  testWidgets('仅重复布局不会再次调用 builder 或重新挂载内容', (tester) async {
    var builds = 0;
    await tester.pumpWidget(
      _scene(SizedBox(width: 80, height: 40), onBuild: (_) => builds++),
    );
    tester.renderObject(find.byType(ElChildSizeBuilder2)).markNeedsLayout();
    await tester.pump();
    expect(builds, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builder 抛异常时显示错误内容，下次更新正常恢复', (tester) async {
    Widget scene(bool fail) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: ElChildSizeBuilder2(
          child: SizedBox(width: 80, height: 40),
          builder: (size, child) {
            if (fail) throw StateError('builder failed');
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('size: $size'), child],
            );
          },
        ),
      ),
    );
    await tester.pumpWidget(scene(true));
    expect(tester.takeException(), isA<StateError>());
    expect(find.byType(ErrorWidget), findsOneWidget);
    await tester.pumpWidget(scene(false));
    expect(find.text('size: Size(80.0, 40.0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('显示与隐藏内容反复切换时仍保留原 State', (tester) async {
    final events = <String>[];
    final model = ValueNotifier(Size(80, 40));
    final key = GlobalKey<_ContentState>();
    addTearDown(model.dispose);
    Widget scene(bool show) => _scene(
      _Content(key: key, model: model, events: events),
      showChild: show,
    );
    await tester.pumpWidget(scene(true));
    final state = key.currentState;
    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    expect(key.currentState, same(state));
    expect(events, ['init']);
    await tester.pumpWidget(SizedBox());
    expect(events, ['init', 'dispose']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GlobalKey 移动整个组件后渲染深度正确且内容不丢失', (tester) async {
    final key = GlobalKey();
    Widget scene(bool deep) {
      Widget result = ElChildSizeBuilder2(
        key: key,
        child: SizedBox(width: 80, height: 40),
        builder: (size, child) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('size: $size'), child],
        ),
      );
      if (deep) {
        for (var i = 0; i < 6; i++) {
          result = Padding(padding: EdgeInsets.all(1), child: result);
        }
      }
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: result),
      );
    }

    await tester.pumpWidget(scene(false));
    await tester.pumpWidget(scene(true));
    _expectRenderDepths(tester.renderObject(find.byKey(key)));
    expect(find.text('size: Size(80.0, 40.0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('嵌套第二版在首帧得到尺寸且没有重复 Key', (tester) async {
    await tester.pumpWidget(
      _scene(
        ElChildSizeBuilder2(
          child: SizedBox(width: 30, height: 20),
          builder: (size, child) =>
              Padding(padding: EdgeInsets.all(1), child: child),
        ),
      ),
    );
    expect(find.text('size: Size(32.0, 22.0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('内容被固定尺寸的布局边界包裹后，自身更新仍刷新测量文本', (tester) async {
    final model = ValueNotifier(Size(80, 40));
    addTearDown(model.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ElChildSizeBuilder2(
            child: ValueListenableBuilder<Size>(
              valueListenable: model,
              builder: (_, size, _) => SizedBox.fromSize(size: size),
            ),
            builder: (size, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('size: $size'),
                SizedBox(width: 200, height: 100, child: child),
              ],
            ),
          ),
        ),
      ),
    );
    model.value = Size(120, 60);
    await tester.pump();
    expect(find.text('size: Size(120.0, 60.0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('异步内容到达后同一帧更新尺寸', (tester) async {
    final complete = Completer<Size>();
    await tester.pumpWidget(
      _scene(
        FutureBuilder<Size>(
          future: complete.future,
          builder: (_, snapshot) =>
              SizedBox.fromSize(size: snapshot.data ?? Size(30, 20)),
        ),
      ),
    );
    expect(find.text('size: Size(30.0, 20.0)'), findsOneWidget);
    complete.complete(Size(120, 60));
    // 先清空 Future 的微任务，随后检查它请求的第一个渲染帧。
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pump();
    expect(find.text('size: Size(120.0, 60.0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('继承的文本缩放变化后更新尺寸', (tester) async {
    late Size measured;
    Widget scene(double scale) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 100,
            child: ElChildSizeBuilder2(
              child: Text('text that wraps over several lines'),
              builder: (size, child) {
                measured = size;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('size: $size'), child],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene(1));
    final normal = measured;
    await tester.pumpWidget(scene(2));
    expect(measured.height, greaterThan(normal.height));
    expect(find.text('size: $measured'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('更换外层结构不会丢失内容 State 或临时清空焦点', (tester) async {
    final node = FocusNode();
    final controller = TextEditingController();
    final key = GlobalKey();
    addTearDown(node.dispose);
    addTearDown(controller.dispose);
    var losses = 0;
    node.addListener(() {
      if (!node.hasFocus) losses++;
    });
    Widget scene(bool padded) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElChildSizeBuilder2(
            child: SizedBox(
              width: 200,
              child: TextField(
                key: key,
                focusNode: node,
                controller: controller,
              ),
            ),
            builder: (size, child) => padded
                ? Padding(padding: EdgeInsets.all(10), child: child)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('size: $size'), child],
                  ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene(false));
    await tester.tap(find.byKey(key));
    await tester.enterText(find.byKey(key), 'kept');
    final state = key.currentState;
    await tester.pumpWidget(scene(true));
    await tester.pump();
    expect(key.currentState, same(state));
    expect(node.hasPrimaryFocus, isTrue);
    expect(controller.text, 'kept');
    expect(losses, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('真实内容只响应一次点击，测量位置没有额外命中', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _scene(
        GestureDetector(
          key: ValueKey('content'),
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: SizedBox(width: 80, height: 40),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('content')));
    expect(taps, 1);
    expect(find.byKey(ValueKey('content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('两种布局阶段都能识别，最终内容位于真实构建位置', (tester) async {
    final stages = <bool>[];
    await tester.pumpWidget(
      _scene(
        Builder(
          builder: (context) {
            stages.add(ElChildSizeBuilder2.isTempLayout(context));
            return SizedBox(width: 80, height: 40);
          },
        ),
      ),
    );
    expect(stages, containsAll([true, false]));
    final context = tester.element(
      find.byWidgetPredicate(
        (widget) => widget is Builder && stages.isNotEmpty,
      ),
    );
    expect(ElChildSizeBuilder2.isTempLayout(context), isFalse);
  });

  testWidgets('未显示的内容动画保持静默，显示后启用并正常释放', (tester) async {
    var ticks = 0;
    Widget scene(bool show) =>
        _scene(_AnimatedContent(onTick: () => ticks++), showChild: show);
    await tester.pumpWidget(scene(false));
    await tester.pump(Duration(milliseconds: 100));
    expect(ticks, 0);
    await tester.pumpWidget(scene(true));
    await tester.pump(Duration(milliseconds: 100));
    expect(ticks, greaterThan(0));
    await tester.pumpWidget(SizedBox());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}

Widget _scene(
  Widget child, {
  BoxConstraints? constraints,
  String prefix = 'size',
  bool showChild = true,
  ValueChanged<Size>? onBuild,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: ElChildSizeBuilder2(
      constraints: constraints,
      child: child,
      builder: (size, child) {
        onBuild?.call(size);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('$prefix: $size'), if (showChild) child],
        );
      },
    ),
  ),
);

void _expectRenderDepths(RenderObject parent) {
  parent.visitChildren((child) {
    expect(child.depth, greaterThan(parent.depth));
    _expectRenderDepths(child);
  });
}

class _Content extends StatefulWidget {
  const _Content({super.key, required this.model, required this.events});
  final ValueNotifier<Size> model;
  final List<String> events;
  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  @override
  void initState() {
    super.initState();
    widget.events.add('init');
  }

  @override
  void dispose() {
    widget.events.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Size>(
    valueListenable: widget.model,
    builder: (_, size, _) => SizedBox.fromSize(size: size),
  );
}

class _AnimatedContent extends StatefulWidget {
  const _AnimatedContent({required this.onTick});
  final VoidCallback onTick;
  @override
  State<_AnimatedContent> createState() => _AnimatedContentState();
}

class _AnimatedContentState extends State<_AnimatedContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(vsync: this, duration: Duration(seconds: 1))
          ..addListener(widget.onTick)
          ..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(width: 80, height: 40);
}
