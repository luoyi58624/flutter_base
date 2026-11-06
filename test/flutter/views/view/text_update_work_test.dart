import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('纯字符串共用无占位结构，富文本仍提取真实 WidgetSpan', () {
    final first = TextContent.parse('Item - 999');
    final second = TextContent.parse('Item - 1000');
    expect(first.span.toPlainText(), 'Item - 999');
    expect(second.span.toPlainText(), 'Item - 1000');
    expect(identical(first.spans, second.spans), isTrue, reason: '普通字符串不必每次分配新的空占位表');
    final embedded = SizedBox(width: 12, height: 8);
    final mixed = TextContent.parse(['before', embedded, 'after']);
    expect(mixed.spans, hasLength(1));
    expect(mixed.spans.single.child, same(embedded));
  });

  testWidgets('已挂载非空字符串换字保留文字通知但不重复扫描选区归属', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(key));
    final host = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = _ObservedEngine()..bindHost(host: host);
    addTearDown(engine.dispose);
    engine.setPayload('Item - 999');
    engine.layoutContent(BoxConstraints(maxWidth: 240), _input(host));
    engine.syncCalls = 0;
    final painter = engine.painterForTest;
    BenchmarkProbe.reset();
    for (var index = 1000; index < 1024; index++) {
      engine.setPayload('Item - $index');
      engine.layoutContent(BoxConstraints(maxWidth: 240), _input(host));
      expect(engine.painterForTest, same(painter));
      expect(engine.selectionTextLength, 'Item - $index'.length);
      expect(engine.selectionTextForRange(TextRange(start: 0, end: engine.selectionTextLength)), 'Item - $index');
    }
    debugPrint('TEXT_UPDATE_WORK ${jsonEncode({'updates': 24, 'selection_ownership_syncs': engine.syncCalls})}');
    expect(engine.syncCalls, 0);
    final configurations = _count('textPainterConfigureCount');
    if (configurations != null) expect(configurations, 0);
  });

  testWidgets('同宽和跨位数换字保留已解析样式，真实布局仍发生但不全量配置', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(key, text: 'Item - 998'));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.textEngineForTest!;
    final painter = engine.painterForTest;
    final style = painter.text!.style;
    var width = painter.maxIntrinsicWidth;
    for (final value in ['Item - 999', 'Item - 1000', 'Item - 1001']) {
      final layouts = render.debugLayoutCount;
      final previousSpan = painter.text;
      BenchmarkProbe.reset();
      await tester.pumpWidget(_scene(key, text: value));
      expect(render.textEngineForTest, same(engine));
      expect(engine.painterForTest, same(painter));
      expect(painter.text, isNot(same(previousSpan)));
      expect(painter.text!.style, same(style));
      expect(painter.text!.toPlainText(), value);
      expect(render.debugLayoutCount, layouts + 1, reason: '换字必须实际排版，不能只保留上一段落');
      if (value == 'Item - 1000') {
        expect(painter.maxIntrinsicWidth, greaterThan(width));
      } else {
        expect(painter.maxIntrinsicWidth, width);
      }
      width = painter.maxIntrinsicWidth;
      final configurations = _count('textPainterConfigureCount');
      if (configurations != null) expect(configurations, 0);
      expect(tester.takeException(), isNull);
    }
  });

  final updates = <String, Widget Function(Key, String)>{
    'color': (key, text) => _scene(key, text: text, color: Color(0xff0055aa)),
    'fontSize': (key, text) => _scene(key, text: text, fontSize: 21),
    'locale': (key, text) => _scene(key, text: text, locale: Locale('ja')),
    'scaler': (key, text) => _scene(key, text: text, scale: 1.5),
    'bold': (key, text) => _scene(key, text: text, bold: true),
    'direction': (key, text) => _scene(key, text: text, rtl: true),
  };
  for (final update in updates.entries) {
    testWidgets('同帧换字及 ${update.key} 变化不能沿用过期主配置', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(_scene(key, text: 'original'));
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final engine = render.textEngineForTest!;
      final painter = engine.painterForTest;
      final layouts = render.debugLayoutCount;
      BenchmarkProbe.reset();
      await tester.pumpWidget(update.value(key, 'updated'));
      expect(engine.painterForTest, same(painter));
      expect(painter.text!.toPlainText(), 'updated');
      expect(render.debugLayoutCount, greaterThan(layouts));
      final configurations = _count('textPainterConfigureCount');
      if (configurations != null) expect(configurations, 1);
      switch (update.key) {
        case 'color':
          expect(painter.text!.style!.color, Color(0xff0055aa));
        case 'fontSize':
          expect(painter.text!.style!.fontSize, 21);
        case 'locale':
          expect(painter.locale, Locale('ja'));
        case 'scaler':
          expect(painter.textScaler.scale(10), 15);
        case 'bold':
          expect(painter.text!.style!.fontWeight, FontWeight.bold);
        case 'direction':
          expect(painter.textDirection, TextDirection.rtl);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('换字保留旧键后，下一次布局仍按新输入重新配置', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(key));
    final host = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = TextEngine()..bindHost(host: host);
    addTearDown(engine.dispose);
    engine.setPayload('first');
    engine.layoutContent(BoxConstraints(maxWidth: 240), _input(host));
    BenchmarkProbe.reset();
    engine.setPayload('second');
    engine.layoutContent(BoxConstraints(maxWidth: 240), (
      style: host.committedResolvedStyle,
      textScaler: TextScaler.linear(2),
      locale: Locale('ja'),
      contentOrigin: Offset(20, 30),
      boldText: true,
    ));
    expect(engine.painterForTest.text!.toPlainText(), 'second');
    expect(engine.painterForTest.textScaler.scale(10), 20);
    expect(engine.painterForTest.locale, Locale('ja'));
    expect(engine.painterForTest.text!.style!.fontWeight, FontWeight.bold);
    final configurations = _count('textPainterConfigureCount');
    if (configurations != null) expect(configurations, 1);
  });

  testWidgets('空文本、富文本、占位子项与图标转换回退完整配置', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(key, text: 'first'));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.textEngineForTest!;
    final painter = engine.painterForTest;
    for (final value in <Object>[
      '',
      'again',
      TextSpan(text: 'rich', style: TextStyle(fontSize: 19)),
      'plain',
      TextSpan(
        children: [
          WidgetSpan(child: SizedBox(width: 12, height: 8)),
          TextSpan(text: 'inline'),
        ],
      ),
      'without placeholder',
      IconData(0x41),
      'restored',
    ]) {
      BenchmarkProbe.reset();
      await tester.pumpWidget(_scene(key, text: value));
      expect(render.textEngineForTest, same(engine));
      expect(engine.painterForTest, same(painter));
      if (value is String) {
        expect(painter.text!.toPlainText(), value);
        expect(painter.text!.style!.fontSize, 14);
        expect(render.childCount, 0);
      } else if (value is InlineSpan) {
        expect(painter.text!.toPlainText(), value.toPlainText());
        expect(render.childCount, value is TextSpan && value.children != null ? 1 : 0);
      } else {
        expect(painter.text!.toPlainText(), 'A');
        expect(painter.text!.style!.fontSize, 24);
      }
      final configurations = _count('textPainterConfigureCount');
      if (configurations != null) expect(configurations, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('首次内容、空值与富文本资格变化仍重新确认选区归属', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(key));
    final engine = _ObservedEngine()..bindHost(host: tester.renderObject<ElRenderView>(find.byKey(key)));
    addTearDown(engine.dispose);
    for (final value in <Object?>['first', '', 'again', TextSpan(text: 'rich'), 'plain', null]) {
      engine.syncCalls = 0;
      engine.setPayload(value);
      expect(engine.syncCalls, 1, reason: '类型和空内容转换不能沿用旧的选择资格');
    }
  });

  testWidgets('主文字布局后绘制不重复配置 painter，普通重画不重新排版', (tester) async {
    final key = GlobalKey();
    BenchmarkProbe.reset();
    await tester.pumpWidget(_scene(key, text: 'Item - 999'));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.textEngineForTest!;
    final painter = engine.painterForTest;
    final initial = _count('textPainterConfigureCount');
    if (initial != null) expect(initial, 1);
    final layouts = render.debugLayoutCount;
    final span = painter.text;
    render.markNeedsPaint();
    await tester.pump();
    expect(render.textEngineForTest, same(engine));
    expect(engine.painterForTest, same(painter));
    expect(painter.text, same(span));
    expect(render.debugLayoutCount, layouts);
    if (initial != null) expect(_count('textPainterConfigureCount'), initial);
  });

  testWidgets('只改颜色刷新 painter，不能被 reposition 的新 input 掩盖', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(key, text: 'unchanged', color: Color(0xffaa1100)));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.textEngineForTest!;
    final layouts = render.debugLayoutCount;
    BenchmarkProbe.reset();
    await tester.pumpWidget(_scene(key, text: 'unchanged', color: Color(0xff0055aa)));
    expect(render.debugLayoutCount, layouts);
    expect(engine.painterForTest.text!.style!.color, Color(0xff0055aa));
    final count = _count('textPainterConfigureCount');
    if (count != null) expect(count, 1);
    render.markNeedsPaint();
    await tester.pump();
    if (count != null) expect(_count('textPainterConfigureCount'), count);
  });

  testWidgets('主配置缓存正确响应字号、缩放、方向、locale 与系统粗体', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(key, text: 'locale changes'));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.textEngineForTest!;
    final painter = engine.painterForTest;
    await tester.pumpWidget(_scene(key, text: 'locale changes', fontSize: 21, scale: 1.5, rtl: true, bold: true));
    expect(engine.painterForTest, same(painter));
    expect(painter.text!.style!.fontSize, 21);
    expect(painter.text!.style!.fontWeight, FontWeight.bold);
    expect(painter.textDirection, TextDirection.rtl);
    expect(painter.textScaler.scale(10), 15);
    expect(painter.locale, Locale('zh', 'CN'));
    await tester.pumpWidget(_scene(key, text: 'restored', fontSize: 14));
    expect(painter.text!.toPlainText(), 'restored');
    expect(painter.text!.style!.fontSize, 14);
    expect(painter.textDirection, TextDirection.ltr);
    expect(painter.textScaler.scale(10), 10);
    expect(painter.locale, Locale('en', 'US'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dry painter 的另一套配置不污染主排版缓存', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(_scene(key, text: 'Item - 1000'));
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.textEngineForTest!;
    final painter = engine.painterForTest;
    final span = painter.text;
    final size = painter.size;
    BenchmarkProbe.reset();
    engine.computeDryMetrics(BoxConstraints(maxWidth: 75), (
      style: render.committedResolvedStyle,
      textScaler: TextScaler.linear(2),
      locale: Locale('ja'),
      contentOrigin: Offset(20, 30),
      boldText: true,
    ));
    expect(painter.text, same(span));
    expect(painter.size, size);
    render.markNeedsPaint();
    await tester.pump();
    expect(painter.text, same(span));
    expect(painter.size, size);
    final count = _count('textPainterConfigureCount');
    if (count != null) expect(count, 0, reason: '只统计主 painter，dry 测量不能清空或覆盖主配置键');
  });

  testWidgets('选择覆盖层与同宽换字、缩短范围继续通知并保持正确主配置', (tester) async {
    final controller = ElSelectionController();
    addTearDown(controller.dispose);
    final key = GlobalKey();
    final changes = <String?>[];
    Widget scene(String text) => Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: ElSelectionView(
          controller: controller,
          onSelectionChanged: changes.add,
          child: ElView(
            key: key,
            style: ElStyle(
              width: 240,
              height: 60,
              fontSize: 16,
              color: Color(0xff333333),
              onSelection: ElStyle(color: Color(0xffffffff), backgroundColor: Color(0xff225588)),
            ),
            child: text,
          ),
        ),
      ),
    );
    await tester.pumpWidget(scene('aaaa'));
    await tester.pumpAndSettle();
    controller.selectAll();
    await tester.pump();
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final engine = render.textEngineForTest!;
    final painter = engine.painterForTest;
    expect(painter.text!.style!.color, Color(0xff333333));
    expect(BenchmarkProbe.selectionOverlayLayoutCount, greaterThan(0));
    BenchmarkProbe.reset();
    await tester.pumpWidget(scene('bbbb'));
    await tester.pump();
    expect(controller.text, 'bbbb');
    expect(changes.last, 'bbbb');
    expect(render.textEngineForTest, same(engine));
    expect(engine.painterForTest, same(painter));
    expect(painter.text!.style!.color, Color(0xff333333));
    final sameWidthConfigurations = _count('textPainterConfigureCount');
    if (sameWidthConfigurations != null) expect(sameWidthConfigurations, 0);
    BenchmarkProbe.reset();
    await tester.pumpWidget(scene('z'));
    await tester.pump();
    expect(controller.text, 'z');
    expect(changes.last, 'z');
    expect(render.currentSelectionRange, TextRange(start: 0, end: 1));
    final shorterConfigurations = _count('textPainterConfigureCount');
    if (shorterConfigurations != null) expect(shorterConfigurations, 0);
    expect(tester.takeException(), isNull);
  });
}

int? _count(String name) => BenchmarkProbe.snapshot()[name];

TextPaintInput _input(ElRenderView host) => (
  style: host.committedResolvedStyle,
  textScaler: TextScaler.noScaling,
  locale: null,
  contentOrigin: Offset.zero,
  boldText: false,
);

Widget _scene(
  Key key, {
  Object? text,
  Color color = const Color(0xff333333),
  double fontSize = 14,
  double scale = 1,
  bool rtl = false,
  bool bold = false,
  Locale? locale,
}) => Directionality(
  textDirection: .ltr,
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale), boldText: bold),
    child: Align(
      alignment: .topLeft,
      child: ElView(
        key: key,
        locale: locale ?? (rtl ? Locale('zh', 'CN') : Locale('en', 'US')),
        style: ElStyle(width: 240, height: 60, color: color, fontSize: fontSize, direction: rtl ? .rtl : .ltr),
        child: text,
      ),
    ),
  ),
);

class _ObservedEngine extends TextEngine {
  int syncCalls = 0;

  @override
  void syncSelectionParticipation() {
    syncCalls++;
    super.syncSelectionParticipation();
  }
}
