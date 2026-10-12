import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('临时布局将探测尺寸传给实际内容', (tester) async {
    Size? measured;
    await tester.pumpWidget(
      Center(
        child: ElChildSizeBuilder(
          tempChild: SizedBox(width: 30, height: 20),
          builder: (size) {
            measured = size;
            return SizedBox(
              key: ValueKey('actual'),
              width: size.width + 5,
              height: size.height,
            );
          },
        ),
      ),
    );
    expect(measured, Size(30, 20));
    expect(tester.getSize(find.byKey(ValueKey('actual'))), Size(35, 20));
  });

  testWidgets('首帧用文本显示子组件尺寸，测量内容不参与绘制和命中', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _scene(
        GestureDetector(
          onTap: () => taps++,
          child: SizedBox(width: 80, height: 40),
        ),
      ),
    );
    expect(find.text('size: Size(80.0, 40.0)'), findsOneWidget);
    await tester.tap(find.text('size: Size(80.0, 40.0)'));
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('测量子树自己更新后，同一帧刷新尺寸文本', (tester) async {
    final model = ValueNotifier(Size(80, 40));
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _scene(
        ValueListenableBuilder<Size>(
          valueListenable: model,
          builder: (_, size, _) => SizedBox.fromSize(size: size),
        ),
      ),
    );
    model.value = Size(120, 60);
    await tester.pump();
    expect(find.text('size: Size(120.0, 60.0)'), findsOneWidget);
  });

  testWidgets('父级宽度和文本缩放变化后重新测量真实排版', (tester) async {
    late Size measured;
    Widget scene(double width, double scale) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: width,
            child: ElChildSizeBuilder(
              tempChild: Text(
                'a long piece of text that wraps over several lines',
              ),
              builder: (size) {
                measured = size;
                return Text('size: $size');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene(200, 1));
    final wide = measured;
    await tester.pumpWidget(scene(80, 1));
    expect(measured.width, lessThanOrEqualTo(80));
    expect(measured.height, greaterThan(wide.height));
    final normal = measured;
    await tester.pumpWidget(scene(80, 2));
    expect(measured.height, greaterThan(normal.height));
    expect(find.text('size: $measured'), findsOneWidget);
  });

  testWidgets('指定约束更新后文本显示受约束的尺寸', (tester) async {
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

  testWidgets('内容尺寸不变也会应用新 builder', (tester) async {
    await tester.pumpWidget(
      _scene(SizedBox(width: 80, height: 40), prefix: 'first'),
    );
    await tester.pumpWidget(
      _scene(SizedBox(width: 80, height: 40), prefix: 'second'),
    );
    expect(find.text('second: Size(80.0, 40.0)'), findsOneWidget);
    expect(find.text('first: Size(80.0, 40.0)'), findsNothing);
  });

  testWidgets('仅重新布局且输入和尺寸未变时不重复调用 builder', (tester) async {
    var builds = 0;
    await tester.pumpWidget(
      _scene(SizedBox(width: 80, height: 40), onBuild: (_) => builds++),
    );
    tester.renderObject(find.byType(ElChildSizeBuilder)).markNeedsLayout();
    await tester.pump();
    expect(builds, 1);
  });

  testWidgets('临时自动聚焦节点不能抢走外部焦点', (tester) async {
    final external = FocusNode();
    final temporary = FocusNode();
    addTearDown(external.dispose);
    addTearDown(temporary.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Focus(focusNode: external, child: Text('external')),
              ElChildSizeBuilder(
                tempChild: Focus(
                  focusNode: temporary,
                  autofocus: true,
                  child: SizedBox(width: 80, height: 40),
                ),
                builder: (size) => Text('size: $size'),
              ),
            ],
          ),
        ),
      ),
    );
    external.requestFocus();
    await tester.pump();
    temporary.requestFocus();
    await tester.pump();
    expect(external.hasPrimaryFocus, isTrue);
    expect(temporary.canRequestFocus, isFalse);
    expect(temporary.hasFocus, isFalse);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('真实输入框保持焦点和输入，尺寸更新不会让探测树接管键盘', (tester) async {
    final actual = FocusNode();
    final temporary = FocusNode();
    final controller = TextEditingController();
    final model = ValueNotifier(Size(80, 40));
    addTearDown(actual.dispose);
    addTearDown(temporary.dispose);
    addTearDown(controller.dispose);
    addTearDown(model.dispose);
    var probeKeys = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElChildSizeBuilder(
            tempChild: Focus(
              focusNode: temporary,
              autofocus: true,
              onKeyEvent: (_, _) {
                probeKeys++;
                return KeyEventResult.handled;
              },
              child: ValueListenableBuilder<Size>(
                valueListenable: model,
                builder: (_, size, _) => SizedBox.fromSize(size: size),
              ),
            ),
            builder: (size) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('size: $size'),
                TextField(
                  key: ValueKey('input'),
                  focusNode: actual,
                  controller: controller,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('input')));
    await tester.enterText(find.byKey(ValueKey('input')), 'kept');
    model.value = Size(120, 60);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    expect(actual.hasPrimaryFocus, isTrue);
    expect(temporary.hasFocus, isFalse);
    expect(controller.text, 'kept');
    expect(probeKeys, 0);
    expect(find.text('size: Size(120.0, 60.0)'), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('测量树不进入语义树，真实内容仍能被访问', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _scene(
          Semantics(
            label: 'measurement only',
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      expect(find.bySemanticsLabel('measurement only'), findsNothing);
      expect(find.bySemanticsLabel('size: Size(80.0, 40.0)'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('临时布局标记只出现在测量子树', (tester) async {
    bool? probe;
    bool? actual;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ElChildSizeBuilder(
            tempChild: Builder(
              builder: (context) {
                probe = ElChildSizeBuilder.isTempLayout(context);
                return SizedBox(width: 80, height: 40);
              },
            ),
            builder: (size) => Builder(
              builder: (context) {
                actual = ElChildSizeBuilder.isTempLayout(context);
                return Text('size: $size');
              },
            ),
          ),
        ),
      ),
    );
    expect(probe, isTrue);
    expect(actual, isFalse);
  });

  testWidgets('嵌套测量在首帧完成，不需要帧后回调', (tester) async {
    await tester.pumpWidget(
      _scene(
        ElChildSizeBuilder(
          tempChild: SizedBox(width: 30, height: 20),
          builder: (size) =>
              SizedBox(width: size.width + 1, height: size.height + 2),
        ),
      ),
    );
    expect(find.text('size: Size(31.0, 22.0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('测量和真实子树分别复用 State，卸载时都释放', (tester) async {
    final events = <String>[];
    Widget scene() => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: ElChildSizeBuilder(
          tempChild: _TrackedBox(tag: 'probe', events: events),
          builder: (size) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('size: $size'),
              _TrackedBox(tag: 'actual', events: events),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene());
    await tester.pumpWidget(scene());
    expect(events, ['init probe', 'init actual']);
    await tester.pumpWidget(SizedBox());
    expect(events.where((event) => event.startsWith('dispose')).toSet(), {
      'dispose probe',
      'dispose actual',
    });
  });

  testWidgets('GlobalKey 移动整个组件后两棵渲染子树的深度都正确', (tester) async {
    final key = GlobalKey();
    Widget scene(bool deep) {
      Widget result = ElChildSizeBuilder(
        key: key,
        tempChild: SizedBox(width: 80, height: 40),
        builder: (size) => Text('size: $size'),
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('真实子组件的 GlobalKey 移到外部后不保留旧 Element 引用', (tester) async {
    final key = GlobalKey();
    final events = <String>[];
    Widget scene(bool outside) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElChildSizeBuilder(
              tempChild: SizedBox(width: 80, height: 40),
              builder: (size) => outside
                  ? Text('size: $size')
                  : _TrackedBox(key: key, tag: 'moved', events: events),
            ),
            if (outside) _TrackedBox(key: key, tag: 'moved', events: events),
          ],
        ),
      ),
    );
    await tester.pumpWidget(scene(false));
    final state = key.currentState;
    await tester.pumpWidget(scene(true));
    expect(key.currentState, same(state));
    expect(find.text('size: Size(80.0, 40.0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    expect(events, ['init moved', 'dispose moved']);
  });

  testWidgets('builder 异常显示错误内容，更新后可以恢复', (tester) async {
    Widget scene(bool fail) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: ElChildSizeBuilder(
          tempChild: SizedBox(width: 80, height: 40),
          builder: (size) {
            if (fail) throw StateError('builder failed');
            return Text('size: $size');
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

  testWidgets('临时动画不持续请求帧，卸载时释放 ticker', (tester) async {
    var ticks = 0;
    await tester.pumpWidget(_scene(_AnimatedBox(onTick: () => ticks++)));
    await tester.pump(Duration(milliseconds: 100));
    expect(ticks, 0);
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
  ValueChanged<Size>? onBuild,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: ElChildSizeBuilder(
      constraints: constraints,
      tempChild: child,
      builder: (size) {
        onBuild?.call(size);
        return Text('$prefix: $size');
      },
    ),
  ),
);

void _expectRenderDepths(RenderObject parent) {
  parent.visitChildren((child) {
    expect(
      child.depth,
      greaterThan(parent.depth),
      reason: 'GlobalKey 迁移后每个子节点必须比父节点更深',
    );
    _expectRenderDepths(child);
  });
}

class _TrackedBox extends StatefulWidget {
  const _TrackedBox({super.key, required this.tag, required this.events});
  final String tag;
  final List<String> events;
  @override
  State<_TrackedBox> createState() => _TrackedBoxState();
}

class _TrackedBoxState extends State<_TrackedBox> {
  @override
  void initState() {
    super.initState();
    widget.events.add('init ${widget.tag}');
  }

  @override
  void dispose() {
    widget.events.add('dispose ${widget.tag}');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(width: 80, height: 40);
}

class _AnimatedBox extends StatefulWidget {
  const _AnimatedBox({required this.onTick});
  final VoidCallback onTick;
  @override
  State<_AnimatedBox> createState() => _AnimatedBoxState();
}

class _AnimatedBoxState extends State<_AnimatedBox>
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
