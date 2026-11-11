import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/src/flutter/views/view/text/text_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _nodeCount = 24;
const _width = 180.0;
const _height = 64.0;

enum _Implementation { elView, native }

enum _Content { empty, color, text, decorated }

enum _Operation { recreate, sameConfig, equalConfig, changeText, changeColor }

void main() {
  final cases = <(_Content, _Operation)>[
    for (final content in _Content.values) ...[(content, _Operation.recreate), (content, _Operation.sameConfig)],
    for (final content in [_Content.text, _Content.decorated]) ...[
      (content, _Operation.equalConfig),
      (content, _Operation.changeText),
    ],
    for (final content in [_Content.color, _Content.decorated]) (content, _Operation.changeColor),
  ];

  for (final (content, operation) in cases) {
    testWidgets('view ${content.name} ${operation.name}', (tester) async {
      _setup(tester);
      final counts = BenchCounts()..observeRebuilds();
      for (var pass = 0; pass < benchmarkPasses; pass++) {
        final order = pass.isEven ? _Implementation.values : _Implementation.values.reversed;
        for (final implementation in order) {
          final fixture = _Fixture(counts, implementation, content);
          await tester.pumpWidget(fixture.scene());
          final initialElement = tester.element(find.byKey(_nodeKey(0)));
          final initialRender = initialElement.renderObject;
          var lastIteration = 0;
          final result = await measureBench(
            tester,
            suite: 'view',
            name: '${implementation.name}/${content.name}/${operation.name}',
            pass: pass,
            counts: counts,
            action: (iteration) async {
              lastIteration = iteration;
              if (operation == .recreate) await tester.pumpWidget(SizedBox.shrink());
              await tester.pumpWidget(fixture.scene(operation: operation, iteration: iteration));
            },
          );
          final finalElement = tester.element(find.byKey(_nodeKey(0)));
          expect(tester.getSize(find.byKey(_nodeKey(0))), Size(_width, _height));
          if (operation == .recreate) {
            expect(finalElement, isNot(same(initialElement)));
            final prefix = implementation == .elView ? 'view' : 'native';
            expect(result.total('${prefix}_render_create'), greaterThanOrEqualTo(_nodeCount * benchmarkSamples));
            expect(result.total('${prefix}_unmount'), result.total('${prefix}_render_create'));
          } else {
            expect(finalElement, same(initialElement));
            expect(finalElement.renderObject, same(initialRender));
            expect(result.total('view_render_create') + result.total('native_render_create'), 0);
          }
          if (content == .text || content == .decorated) {
            fixture.expectText(tester, operation == .changeText ? _text(lastIteration) : _text(0));
          }
          if (operation == .changeText && implementation == .elView) {
            expect(result.total('view_layout'), greaterThanOrEqualTo(_nodeCount * benchmarkSamples));
          }
          if (content == .decorated) {
            await tester.tap(find.byKey(_nodeKey(0)));
            expect(fixture.taps, 1, reason: '计时后检查两套装饰节点都保留真实点击行为。');
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(SizedBox.shrink());
        }
      }
    });
  }

  testWidgets('view 稳定 Widget child 的外壳重建', (tester) async {
    _setup(tester);
    final counts = BenchCounts()..observeRebuilds();
    for (var pass = 0; pass < benchmarkPasses; pass++) {
      final order = pass.isEven ? _Implementation.values : _Implementation.values.reversed;
      for (final implementation in order) {
        final children = List.generate(
          _nodeCount,
          (index) => _NativeText(counts, key: ValueKey('fixed-$index'), text: _span(_text(0), _textStyle())),
        );
        final style = ElStyle(width: _width, height: _height);
        Widget scene() => _grid([
          for (var i = 0; i < _nodeCount; i++)
            if (implementation == .elView)
              BenchView(counts: counts, key: _nodeKey(i), style: style, child: children[i])
            else
              _NativeBox(counts, key: _nodeKey(i), child: children[i]),
        ]);
        await tester.pumpWidget(scene());
        final child = tester.element(find.byKey(ValueKey('fixed-0')));
        final render = child.renderObject;
        final result = await measureBench(
          tester,
          suite: 'view',
          name: '${implementation.name}/widgetChild/sameConfig',
          counts: counts,
          pass: pass,
          action: (_) => tester.pumpWidget(scene()),
        );
        expect(tester.element(find.byKey(ValueKey('fixed-0'))), same(child));
        expect(child.renderObject, same(render));
        expect(child.widget, same(children.first));
        expect(result.total('native_text_update'), 0);
        expect(result.total('view_render_create') + result.total('native_render_create'), 0);
        await tester.pumpWidget(SizedBox.shrink());
      }
    }
  });

  for (final changed in [false, true]) {
    testWidgets('view 通知直达文本 ${changed ? '变值' : '等值'}', (tester) async {
      _setup(tester);
      final counts = BenchCounts()..observeRebuilds();
      for (var pass = 0; pass < benchmarkPasses; pass++) {
        final order = pass.isEven ? _Implementation.values : _Implementation.values.reversed;
        for (final implementation in order) {
          final sources = List.generate(_nodeCount, (_) => BenchValue(_text(0)));
          try {
            final style = ElStyle(width: _width, height: _height, fontSize: 14, color: Color(0xff202020), maxLines: 1);
            final nativeStyle = _textStyle();
            await tester.pumpWidget(
              _grid([
                for (var i = 0; i < _nodeCount; i++)
                  if (implementation == .elView)
                    BenchView(counts: counts, key: _nodeKey(i), style: style, child: sources[i])
                  else
                    _NativeBox(
                      counts,
                      key: _nodeKey(i),
                      child: ValueListenableBuilder<String>(
                        valueListenable: sources[i],
                        builder: (_, value, _) {
                          counts.add('business_builder');
                          return _NativeText(counts, text: _span(value, nativeStyle));
                        },
                      ),
                    ),
              ]),
            );
            final root = tester.element(find.byKey(_nodeKey(0)));
            final widget = root.widget;
            final render = root.renderObject;
            var lastText = _text(0);
            final result = await measureBench(
              tester,
              suite: 'view',
              name: '${implementation.name}/listenable/${changed ? 'changed' : 'equal'}',
              counts: counts,
              pass: pass,
              action: (iteration) async {
                lastText = changed ? _text(iteration) : String.fromCharCodes(_text(0).codeUnits);
                for (final source in sources) {
                  source.emit(lastText);
                }
                await tester.pump();
              },
            );
            expect(tester.element(find.byKey(_nodeKey(0))), same(root));
            expect(root.widget, same(widget));
            expect(root.renderObject, same(render));
            _expectText(tester, implementation, lastText);
            expect(result.total('view_render_create') + result.total('native_render_create'), 0);
            if (implementation == .elView) {
              expect(result.total('view_element_update'), 0);
              expect(result.total('view_render_update'), 0);
              expect(result.total('view_perform_rebuild'), 0);
              expect(result.total('view_layout'), changed ? greaterThanOrEqualTo(_nodeCount * benchmarkSamples) : 0);
            }
            await tester.pumpWidget(SizedBox.shrink());
          } finally {
            for (final source in sources) {
              source.dispose();
            }
          }
        }
      }
    });
  }
}

void _setup(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(800, 600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Key _nodeKey(int index) => ValueKey('view-node-$index');

String _text(int iteration) => '条目 ${(1000 + iteration).toString()}';

Color _color(int iteration) => iteration.isEven ? Color(0xffe8eef7) : Color(0xffd8e5dc);

TextStyle _textStyle() => TextStyle(fontSize: 14, color: Color(0xff202020));

TextSpan _span(String value, TextStyle style) => TextSpan(text: value, style: style);

Widget _grid(List<Widget> children) => benchScene(
  Align(
    alignment: .topLeft,
    child: Wrap(spacing: 8, runSpacing: 8, children: children),
  ),
);

void _expectText(WidgetTester tester, _Implementation implementation, String expected) {
  if (implementation == .elView) {
    final render = tester.renderObject<ElRenderView>(find.byKey(_nodeKey(0)));
    expect((render.content as TextEngine).painterForTest.text!.toPlainText(), expected);
  } else {
    expect(
      tester.widgetList<_NativeText>(find.byType(_NativeText)).every((widget) => widget.text.toPlainText() == expected),
      isTrue,
    );
  }
}

class _Fixture {
  _Fixture(this.counts, this.implementation, this.content) {
    style = createStyle(_color(0));
    onTap = () => taps++;
    event = ElEvent(onTap: (_) => onTap());
  }

  final BenchCounts counts;
  final _Implementation implementation;
  final _Content content;
  final nativeTextStyle = _textStyle();
  final nativeDecoration = BoxDecoration(color: _color(0), borderRadius: BorderRadius.circular(8));
  final fixedText = _text(0);
  late final ElStyle style;
  late final ElEvent event;
  late final VoidCallback onTap;
  int taps = 0;

  bool get hasText => content == .text || content == .decorated;

  ElStyle createStyle(Color color) => ElStyle(
    width: _width,
    height: _height,
    fontSize: hasText ? 14 : null,
    color: hasText ? Color(0xff202020) : null,
    maxLines: hasText ? 1 : null,
    backgroundColor: content == .color || content == .decorated ? color : null,
    borderRadius: content == .decorated ? BorderRadius.circular(8) : null,
    padding: content == .decorated ? EdgeInsets.all(8) : null,
  );

  Widget scene({_Operation operation = .sameConfig, int iteration = 0}) {
    final color = operation == .changeColor ? _color(iteration) : _color(0);
    final text = operation == .changeText ? _text(iteration) : fixedText;
    final freshStyle = operation == .equalConfig || operation == .changeColor;
    final currentStyle = freshStyle ? createStyle(color) : style;
    final currentTextStyle = operation == .equalConfig ? _textStyle() : nativeTextStyle;
    final decoration = freshStyle
        ? BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))
        : nativeDecoration;
    return _grid([
      for (var i = 0; i < _nodeCount; i++)
        if (implementation == .elView)
          BenchView(
            counts: counts,
            key: _nodeKey(i),
            style: currentStyle,
            event: content == .decorated ? event : null,
            child: hasText ? (operation == .equalConfig ? String.fromCharCodes(text.codeUnits) : text) : null,
          )
        else
          _NativeBox(
            counts,
            key: _nodeKey(i),
            child: switch (content) {
              .empty => null,
              .color => _NativeColor(counts, color: color),
              .text => _NativeText(
                counts,
                text: _span(operation == .equalConfig ? String.fromCharCodes(text.codeUnits) : text, currentTextStyle),
              ),
              .decorated => GestureDetector(
                behavior: .opaque,
                onTap: onTap,
                child: _NativeDecoration(
                  counts,
                  decoration: decoration,
                  child: _NativePadding(
                    counts,
                    padding: EdgeInsets.all(8),
                    child: _NativeText(
                      counts,
                      text: _span(
                        operation == .equalConfig ? String.fromCharCodes(text.codeUnits) : text,
                        currentTextStyle,
                      ),
                    ),
                  ),
                ),
              ),
            },
          ),
    ]);
  }

  void expectText(WidgetTester tester, String expected) => _expectText(tester, implementation, expected);
}

// 只统计以下明确包装的原生节点，GestureDetector 内部节点不冒充完整 Render 树计数。
mixin _NativeSingleProbe on SingleChildRenderObjectWidget {
  BenchCounts get counts;

  @override
  SingleChildRenderObjectElement createElement() => _NativeSingleElement(this, counts);
}

mixin _NativeElementProbe on RenderObjectElement {
  BenchCounts get counts;

  @override
  void mount(Element? parent, Object? newSlot) {
    counts.add('native_render_create');
    super.mount(parent, newSlot);
  }

  @override
  void update(covariant RenderObjectWidget newWidget) {
    counts.add('native_element_update');
    if (newWidget is _NativeText) counts.add('native_text_update');
    super.update(newWidget);
  }

  @override
  void unmount() {
    counts.add('native_unmount');
    super.unmount();
  }
}

class _NativeSingleElement extends SingleChildRenderObjectElement with _NativeElementProbe {
  _NativeSingleElement(super.widget, this.counts);

  @override
  final BenchCounts counts;
}

class _NativeTextElement extends MultiChildRenderObjectElement with _NativeElementProbe {
  _NativeTextElement(super.widget, this.counts);

  @override
  final BenchCounts counts;
}

class _NativeBox extends SizedBox with _NativeSingleProbe {
  _NativeBox(this.counts, {super.key, super.child}) : super(width: _width, height: _height) {
    counts.add('native_widget_create');
  }

  @override
  final BenchCounts counts;
}

class _NativeColor extends ColoredBox with _NativeSingleProbe {
  _NativeColor(this.counts, {required super.color}) {
    counts.add('native_widget_create');
  }

  @override
  final BenchCounts counts;
}

class _NativeDecoration extends DecoratedBox with _NativeSingleProbe {
  _NativeDecoration(this.counts, {required super.decoration, super.child}) {
    counts.add('native_widget_create');
  }

  @override
  final BenchCounts counts;
}

class _NativePadding extends Padding with _NativeSingleProbe {
  _NativePadding(this.counts, {required super.padding, super.child}) {
    counts.add('native_widget_create');
  }

  @override
  final BenchCounts counts;
}

class _NativeText extends RichText {
  _NativeText(this.counts, {super.key, required super.text}) : super(maxLines: 1, textDirection: .ltr) {
    counts.add('native_widget_create');
  }

  final BenchCounts counts;

  @override
  MultiChildRenderObjectElement createElement() => _NativeTextElement(this, counts);
}
