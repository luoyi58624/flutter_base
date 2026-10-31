import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => Directionality(
  textDirection: .ltr,
  child: MediaQuery(
    data: MediaQueryData(),
    child: Align(alignment: .topLeft, child: child),
  ),
);

ElRenderView _render(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

TextStyle _plainStyle(WidgetTester tester, Key key) =>
    (_render(tester, key).textEngineForTest?.painterForTest.text)!.style!;

double? _wght(TextStyle style) => style.fontVariations?.where((axis) => axis.axis == 'wght').firstOrNull?.value;

class _RecordingSpan extends TextSpan {
  _RecordingSpan(this.onDown)
    : super(
        text: '自定义事件',
        style: TextStyle(fontWeight: .w600),
      );

  final VoidCallback onDown;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) onDown();
  }
}

Map<String, TextStyle> _styles(InlineSpan root) {
  final result = <String, TextStyle>{};
  root.visitChildren((span) {
    if (span is TextSpan && span.text != null) result[span.text!] = span.style!;
    return true;
  });
  return result;
}

void main() {
  testWidgets('显式 wght 原样传递，不随各档 fontWeight 叠加或限制轴值', (tester) async {
    final cases = [1.0, 300.0, 400.0, 590.0, 1000.0];
    final keys = [for (final _ in FontWeight.values) UniqueKey()];
    for (final weight in cases) {
      final axes = [FontVariation('wght', weight), FontVariation('wdth', 90)];
      await tester.pumpWidget(
        _host(
          ElView(
            style: ElStyle(fontVariationSettings: axes),
            child: Column(
              mainAxisSize: .min,
              children: [
                for (var i = 0; i < FontWeight.values.length; i++)
                  ElView(
                    key: keys[i],
                    style: ElStyle(fontWeight: FontWeight.values[i]),
                    child: '字重 ${FontWeight.values[i].value}',
                  ),
              ],
            ),
          ),
        ),
      );
      for (var i = 0; i < keys.length; i++) {
        final style = _plainStyle(tester, keys[i]);
        expect(style.fontWeight, FontWeight.values[i]);
        expect(style.fontVariations, axes);
        expect(style.fontVariations!.last, FontVariation('wdth', 90));
        expect(_render(tester, keys[i]).committedResolvedStyle.inheritedText.fontVariationSettings, same(axes));
      }
    }
  });

  testWidgets('多层继承保留小数轴值，后代 fontWeight 不改变继承轴', (tester) async {
    final normal = UniqueKey();
    final title = UniqueKey();
    final deep = UniqueKey();
    await tester.pumpWidget(
      _host(
        ElView(
          style: ElStyle(fontVariationSettings: [FontVariation('wght', 590.5)]),
          child: Column(
            mainAxisSize: .min,
            children: [
              ElView(key: normal, child: '正文'),
              ElView(
                style: ElStyle(fontWeight: .w500),
                child: ElView(
                  style: ElStyle(fontSize: 18),
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      ElView(key: title, child: '标题'),
                      ElView(
                        key: deep,
                        style: ElStyle(fontWeight: .w600),
                        child: '更粗',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(_wght(_plainStyle(tester, normal)), 590.5);
    expect(_wght(_plainStyle(tester, title)), 590.5);
    expect(_wght(_plainStyle(tester, deep)), 590.5);
  });

  testWidgets('继承轴可动态更新与清除，字重变体不修改轴值或重建后代', (tester) async {
    final value = ValueNotifier<double?>(590);
    addTearDown(value.dispose);
    final key = UniqueKey();
    var builds = 0;
    final leaf = Builder(
      builder: (context) {
        builds++;
        return ElView(
          key: key,
          style: ElStyle(
            fontWeight: .w500,
            onHover: ElStyle(fontWeight: .w700),
          ),
          child: '动态字重',
        );
      },
    );
    await tester.pumpWidget(
      _host(
        ValueListenableBuilder<double?>(
          valueListenable: value,
          child: leaf,
          builder: (context, weight, child) => ElView(
            style: ElStyle(fontVariationSettings: weight == null ? null : [FontVariation('wght', weight)]),
            child: child,
          ),
        ),
      ),
    );
    final initialBuilds = builds;
    expect(_wght(_plainStyle(tester, key)), 590);
    _render(tester, key).setHover(true);
    await tester.pump();
    expect(_plainStyle(tester, key).fontWeight, FontWeight.w700);
    expect(_wght(_plainStyle(tester, key)), 590);
    value.value = 300;
    await tester.pump();
    expect(_wght(_plainStyle(tester, key)), 300);
    _render(tester, key).setHover(false);
    await tester.pump();
    expect(_plainStyle(tester, key).fontWeight, FontWeight.w500);
    expect(_wght(_plainStyle(tester, key)), 300);
    value.value = null;
    await tester.pump();
    expect(_plainStyle(tester, key).fontVariations, isNull);
    expect(_plainStyle(tester, key).fontWeight, FontWeight.w500);
    expect(builds, initialBuilds);
  });

  testWidgets('富文本按 Flutter 规则继承样式，局部轴覆盖与继承隔离均保留原值', (tester) async {
    final key = UniqueKey();
    await tester.pumpWidget(
      _host(
        ElView(
          key: key,
          style: ElStyle(fontWeight: .w500, fontVariationSettings: [FontVariation('wght', 590)]),
          child: TextSpan(
            text: '根',
            children: [
              TextSpan(
                text: '细',
                style: TextStyle(fontWeight: .w200),
                children: [
                  TextSpan(
                    text: '粗',
                    style: TextStyle(fontWeight: .w700),
                  ),
                ],
              ),
              TextSpan(
                text: '父段',
                style: TextStyle(fontWeight: .w600),
                children: [
                  TextSpan(
                    text: '子段',
                    style: TextStyle(fontWeight: .w300),
                  ),
                ],
              ),
              TextSpan(
                text: '局部轴',
                style: TextStyle(fontVariations: [FontVariation('wght', 300)]),
              ),
              TextSpan(
                text: '清除轴',
                style: TextStyle(fontVariations: []),
              ),
              TextSpan(
                text: '隔离',
                style: TextStyle(inherit: false, fontWeight: .w500),
              ),
            ],
          ),
        ),
      ),
    );
    final styles = _styles(_render(tester, key).textEngineForTest!.painterForTest.text!);
    for (final text in ['根', '细', '粗', '父段', '子段']) {
      expect(_wght(styles[text]!), 590);
    }
    expect(_wght(styles['局部轴']!), 300);
    expect(styles['清除轴']!.fontVariations, isEmpty);
    expect(styles['隔离']!.fontVariations, isNull);
  });

  testWidgets('交互 TextSpan 保留声明轴值、recognizer 与语义', (tester) async {
    final key = UniqueKey();
    var taps = 0;
    final recognizer = TapGestureRecognizer()..onTap = () => taps++;
    addTearDown(recognizer.dispose);
    await tester.pumpWidget(
      _host(
        ElView(
          key: key,
          style: ElStyle(fontVariationSettings: [FontVariation('wght', 590)]),
          child: TextSpan(
            text: '点击',
            style: TextStyle(fontWeight: .w500),
            recognizer: recognizer,
            semanticsLabel: '点击标题',
            semanticsIdentifier: 'title',
          ),
        ),
      ),
    );
    final span = _render(tester, key).textEngineForTest!.painterForTest.text! as TextSpan;
    expect(_wght(span.style!), 590);
    expect(span.recognizer, same(recognizer));
    expect(span.semanticsLabel, '点击标题');
    expect(span.semanticsIdentifier, 'title');
    await tester.tap(find.byKey(key));
    expect(taps, 1);
  });

  testWidgets('替换字重样式后继续派发自定义 TextSpan 的事件', (tester) async {
    final key = UniqueKey();
    var downs = 0;
    await tester.pumpWidget(
      _host(
        ElView(
          key: key,
          style: ElStyle(fontVariationSettings: [FontVariation('wght', 590)]),
          child: _RecordingSpan(() => downs++),
        ),
      ),
    );
    final span = _render(tester, key).textEngineForTest!.painterForTest.text! as TextSpan;
    expect(_wght(span.style!), 590);
    await tester.tap(find.byKey(key));
    expect(downs, 1);
  });

  testWidgets('独立图标保留原始轴，没有 wght 的正文不新增字重轴', (tester) async {
    final icon = UniqueKey();
    final text = UniqueKey();
    await tester.pumpWidget(
      _host(
        Column(
          mainAxisSize: .min,
          children: [
            ElView(
              key: icon,
              style: ElStyle(fontWeight: .w500, fontVariationSettings: [FontVariation('wght', 590)]),
              child: IconData(0xe000, fontFamily: 'test-icons'),
            ),
            ElView(
              key: text,
              style: ElStyle(fontWeight: .w500, fontVariationSettings: [FontVariation('wdth', 90)]),
              child: '普通文字',
            ),
          ],
        ),
      ),
    );
    expect(_wght(_plainStyle(tester, icon)), 590);
    expect(_plainStyle(tester, text).fontVariations, [FontVariation('wdth', 90)]);
  });

  testWidgets('表格两种序号托管路径均保留声明的字重轴', (tester) async {
    final controller = ElTableController(
      data: [
        {'name': '正文'},
      ],
      columns: [
        ElTableColumn(type: .index),
        ElTableColumn(prop: 'name'),
      ],
    );
    addTearDown(controller.dispose);
    addTearDown(() => tester.pumpWidget(SizedBox.shrink()));
    for (final interactive in [false, true]) {
      await tester.pumpWidget(
        _host(
          ElView(
            style: ElStyle(fontVariationSettings: [FontVariation('wght', 590)]),
            child: SizedBox(
              width: 300,
              child: ElTable(
                controller: controller,
                height: 160,
                style: ElTableStyle(cell: ElStyle(fontWeight: .w500)),
                onCellTap: interactive ? (_) {} : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nodes = [tester.renderObject<RenderObject>(find.byType(ElTable))];
      final labels = <String>[];
      while (nodes.isNotEmpty) {
        final node = nodes.removeLast();
        if (node is RenderOrdinalGutter) labels.addAll(node.debugPaintEntries.map((entry) => entry.label));
        node.visitChildren(nodes.add);
      }
      expect(labels, ['1']);
      if (interactive) {
        final gutters = tester.widgetList<OrdinalGutterHost>(find.byType(OrdinalGutterHost));
        expect(gutters, isNotEmpty);
        for (final gutter in gutters) {
          expect(gutter.styles.map(_wght), everyElement(590));
        }
      }
    }
  });
}
