import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 14, height: 1.4, color: Color(0xff111111));

Widget _host(
  EditableController controller,
  GlobalKey<EditableViewTestState> key, {
  double width = 320,
  double height = 120,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: .topLeft,
    child: SizedBox(
      width: width,
      height: height,
      child: EditableView(
        key: key,
        controller: controller,
        style: EditableConfiguration(autofocus: true, textStyle: _style),
      ),
    ),
  ),
);

Future<void> _pumpGeometry(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Rect _lastPlatformRect(WidgetTester tester, String method) {
  final call = tester.testTextInput.log.lastWhere((entry) => entry.method == method);
  final arguments = (call.arguments as Map<dynamic, dynamic>);
  return Rect.fromLTWH(
    (arguments['x'] as num).toDouble(),
    (arguments['y'] as num).toDouble(),
    (arguments['width'] as num).toDouble(),
    (arguments['height'] as num).toDouble(),
  );
}

void _expectRectNear(Rect actual, Rect expected, {String? reason}) {
  expect(actual.left, closeTo(expected.left, 0.01), reason: reason);
  expect(actual.top, closeTo(expected.top, 0.01), reason: reason);
  expect(actual.right, closeTo(expected.right, 0.01), reason: reason);
  expect(actual.bottom, closeTo(expected.bottom, 0.01), reason: reason);
}

Rect _selectionRectInEditor(WidgetTester tester, EditableController controller, TextSelection selection) {
  final editor = tester.renderObject<RenderBox>(find.byType(EditableView));
  Rect? result;
  for (final line
      in tester
          .renderObjectList<RenderEditableLine>(find.byType(EditableLineView))
          .where((line) => identical(line.scope.controller, controller))) {
    final boxes = line.scope.selectionBoxesInLine(line.index, selection);
    final transform = line.getTransformTo(editor);
    for (final box in boxes) {
      final rect = MatrixUtils.transformRect(transform, box.toRect());
      result = result?.expandToInclude(rect) ?? rect;
    }
  }
  return result!;
}

Rect _glyphBounds(RenderEditableLine line, int start, int end) {
  Rect? result;
  for (final box in line.layoutedPainter!.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))) {
    result = result?.expandToInclude(box.toRect()) ?? box.toRect();
  }
  return result!;
}

Rect _selectionBand(RenderEditableLine line, int start, int end) => line
    .selectionBoxesForLineRange(start, end)
    .map((box) => box.toRect())
    .reduce((bounds, rect) => bounds.expandToInclude(rect));

Rect _globalRect(RenderEditableLine line, Rect local) => MatrixUtils.transformRect(line.getTransformTo(null), local);

void _expectPhysicalNear(double actual, double expected, double dpr, {String? reason}) {
  expect((actual - expected).abs() * dpr, lessThanOrEqualTo(1), reason: reason);
}

void main() {
  testWidgets('Windows 横滚到长文本末尾后全选，首字母候选锚点始终留在输入视口', (tester) async {
    const channel = MethodChannel('el.ui/windows_ime');
    final messages = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      messages.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final text = 'abcdefghij ' * 100;
    final controller = EditableController(text: text, singleLine: true)..collapseTo(text.length);
    final horizontal = ScrollController();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(horizontal.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: Transform.translate(
            offset: Offset(120, 30),
            child: SizedBox(
              width: 240,
              height: 40,
              child: EditableView(
                key: key,
                controller: controller,
                horizontalScrollController: horizontal,
                style: EditableConfiguration(
                  autofocus: true,
                  softWrap: false,
                  selectAllRevealsCaret: false,
                  contentPadding: .all(8),
                  textStyle: _style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 16; i++) {
      await tester.pump(Duration(milliseconds: 16));
    }
    expect(horizontal.position.maxScrollExtent, greaterThan(100));
    horizontal.jumpTo(horizontal.position.maxScrollExtent);
    await _pumpGeometry(tester);
    expect(horizontal.offset, greaterThan(100));
    final beforeScroll = horizontal.offset;
    controller.selectAll();
    await _pumpGeometry(tester);
    expect(horizontal.offset, closeTo(beforeScroll, .01), reason: '全选继续保留原视口');
    expect(key.currentState!.rectAtOffset(0)!.left, lessThan(0), reason: '原始选区起点确实已经滚出左侧');
    void expectVisibleAnchor() {
      final snapshot = messages.lastWhere((call) => call.method == 'update').arguments as Map;
      for (final name in ['anchor', 'end', 'caret']) {
        final rect = (snapshot[name] as List).cast<double>();
        expect(rect[0], greaterThanOrEqualTo(128), reason: '$name 不能使用横滚后的负坐标');
        expect(rect[2], lessThanOrEqualTo(352));
      }
      final marked = _lastPlatformRect(tester, 'TextInput.setMarkedTextRect');
      expect(marked.left, greaterThanOrEqualTo(8));
      expect(marked.right, lessThanOrEqualTo(232));
    }

    expectVisibleAnchor();
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(Duration(milliseconds: 16));
      expectVisibleAnchor();
    }
    expect(controller.text, 'a');
    await tester.pumpWidget(SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows 按需补充组合内部的 bidi 与跨行位置，不改写输入状态', (tester) async {
    const channel = MethodChannel('el.ui/windows_ime');
    final messages = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      messages.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'ab אבג cd\nxy efg');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, key));
    controller.imeUpdateSelection(TextSelection.collapsed(offset: 14), TextRange(start: 1, end: 14));
    await _pumpGeometry(tester);
    final snapshot = messages.lastWhere((call) => call.method == 'update').arguments as Map;
    final revision = controller.docRevision;
    tester.testTextInput.log.clear();
    for (final offset in [2, 4, 10]) {
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          MethodCall('requestPosition', {
            'owner': snapshot['owner'],
            'generation': snapshot['generation'],
            'offset': offset,
          }),
        ),
        (_) {},
      );
    }
    await _pumpGeometry(tester);
    final cache = messages.singleWhere((call) => call.method == 'cache');
    final positions = cache.arguments['positions'] as List;
    expect(positions, hasLength(3));
    final box = tester.renderObject<RenderBox>(find.byType(EditableView));
    for (final entry in positions) {
      final values = (entry['rect'] as List).cast<double>();
      final actual = Rect.fromLTRB(values[0], values[1], values[2], values[3]);
      final expected = MatrixUtils.transformRect(
        box.getTransformTo(null),
        key.currentState!.rectAtOffset(1 + entry['offset'] as int)!,
      );
      _expectRectNear(actual, expected);
    }
    expect(controller.docRevision, revision);
    expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.setEditingState'), isEmpty);
    await tester.pumpWidget(SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('首字母候选跟随宿主重定位，空闲和组字期间都不等待下一次输入', (tester) async {
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = EditableController(singleLine: true);
    final focus = FocusNode();
    final key = GlobalKey<EditableViewTestState>();
    final top = ValueNotifier(8.0);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    addTearDown(top.dispose);
    final editable = EditableView(
      key: key,
      controller: controller,
      focusNode: focus,
      style: EditableConfiguration(
        softWrap: false,
        lineHeightMode: .fixed,
        textStyle: TextStyle(fontFamily: 'Ahem', fontSize: 14, height: 20 / 14),
        contentPadding: .fromLTRB(12, 10, 12, 10),
        // 与单行输入组件一致关闭滚动条：Windows 条带的固定 gutter 会让 40px 宿主变成可纵向滚动。
        scrollbars: false,
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: ValueListenableBuilder<double>(
            valueListenable: top,
            builder: (_, value, child) => Padding(
              padding: .only(top: value),
              child: child,
            ),
            child: SizedBox(width: 320, height: 40, child: editable),
          ),
        ),
      ),
    );
    focus.requestFocus();
    Future<void> settleGeometry() async {
      // 结清自动 reveal，避免它的附带同步掩盖纯宿主几何变更漏通知。
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(Duration(milliseconds: 16));
      }
    }

    Rect platformMarkedGlobal() {
      final arguments =
          tester.testTextInput.log
                  .lastWhere((entry) => entry.method == 'TextInput.setEditableSizeAndTransform')
                  .arguments
              as Map;
      final matrix = Matrix4.fromList(
        (arguments['transform'] as List).cast<num>().map((value) => value.toDouble()).toList(),
      );
      return MatrixUtils.transformRect(matrix, _lastPlatformRect(tester, 'TextInput.setMarkedTextRect'));
    }

    await settleGeometry();
    top.value = 20;
    await settleGeometry();
    _expectRectNear(platformMarkedGlobal(), key.currentState!.caretRectGlobal()!, reason: '空输入时预置正确候选锚点');

    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await settleGeometry();
    final before = platformMarkedGlobal();
    top.value = 32;
    await settleGeometry();
    final moved = platformMarkedGlobal();
    _expectRectNear(moved, before.shift(Offset(0, 12)), reason: '首字母出现后宿主下移，候选锚点必须在没有后续输入时同步');
    _expectRectNear(moved, key.currentState!.caretRectGlobal()!, reason: 'Windows 写入与查询共用当前 caret 行带');
    expect(controller.text, 'a');

    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await settleGeometry();
    final second = platformMarkedGlobal();
    expect(second.top, moved.top);
    expect(second.bottom, moved.bottom, reason: '第二个字母不应再纠正纵向位置');
    expect(second.left, greaterThan(moved.left));
    expect(second.width, moved.width, reason: 'Windows 候选跟随 caret，不把扩展的组合包围盒左边当光标');
    final geometryCount = tester.testTextInput.log
        .where((entry) => entry.method.contains('Rect') || entry.method.contains('Transform'))
        .length;
    await tester.pump(Duration(milliseconds: 501));
    expect(
      tester.testTextInput.log
          .where((entry) => entry.method.contains('Rect') || entry.method.contains('Transform'))
          .length,
      geometryCount,
      reason: '位置不变的光标闪烁不重复发送平台几何',
    );
    await tester.pumpWidget(SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('Windows 跨行组合候选使用当前输入位置，组字内移动也不跳回起点', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abc\ndef');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, key, width: 160, height: 120));
    await _pumpGeometry(tester);
    for (final offset in [6, 5]) {
      controller.imeUpdateSelection(TextSelection.collapsed(offset: offset), TextRange(start: 1, end: 6));
      await _pumpGeometry(tester);
      _expectRectNear(
        _lastPlatformRect(tester, 'TextInput.setMarkedTextRect'),
        key.currentState!.rectAtOffset(offset)!,
        reason: 'marked rect 在 Windows 是候选光标，不是跨行组合的包围盒',
      );
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('非折叠正反向选区的 IME caret 都锚 selection.start', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abcdef');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, key));
    await _pumpGeometry(tester);
    expect(key.currentState!.focusNode.hasFocus, isTrue);

    tester.testTextInput.log.clear();
    controller.setSelection(const TextSelection(baseOffset: 1, extentOffset: 4));
    await _pumpGeometry(tester);
    final forward = _lastPlatformRect(tester, 'TextInput.setCaretRect');
    _expectRectNear(forward, key.currentState!.rectAtOffset(1)!, reason: '正向选区不能锚 active/end');

    tester.testTextInput.log.clear();
    controller.setSelection(const TextSelection(baseOffset: 5, extentOffset: 2));
    await _pumpGeometry(tester);
    final reversed = _lastPlatformRect(tester, 'TextInput.setCaretRect');
    _expectRectNear(reversed, key.currentState!.rectAtOffset(2)!, reason: '反向选区仍按文档有序 start，而不是 base/active');
  });

  testWidgets('IME marked rect 覆盖 soft-wrap 与 bidi composing 的全部字形盒', (tester) async {
    const text = 'ab אבג cdefghijklmnop';
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: text);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, key, width: 70, height: 160));
    await _pumpGeometry(tester);

    const composing = TextRange(start: 1, end: 19);
    tester.testTextInput.log.clear();
    controller.imeUpdateSelection(const TextSelection.collapsed(offset: 19), composing);
    await _pumpGeometry(tester);

    final expected = _selectionRectInEditor(tester, controller, const TextSelection(baseOffset: 1, extentOffset: 19));
    expect(expected.height, greaterThan(_style.fontSize! * _style.height!), reason: '反例必须真实跨越多条视觉行');
    _expectRectNear(_lastPlatformRect(tester, 'TextInput.setMarkedTextRect'), expected);
  });

  testWidgets('IME marked rect 合并跨逻辑行 composing，空闲时回退 start caret', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abc\ndef');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, key, width: 160, height: 120));
    await _pumpGeometry(tester);

    const composing = TextRange(start: 1, end: 6);
    tester.testTextInput.log.clear();
    controller.imeUpdateSelection(const TextSelection.collapsed(offset: 6), composing);
    await _pumpGeometry(tester);
    final expected = _selectionRectInEditor(tester, controller, const TextSelection(baseOffset: 1, extentOffset: 6));
    _expectRectNear(_lastPlatformRect(tester, 'TextInput.setMarkedTextRect'), expected);

    tester.testTextInput.log.clear();
    controller.imeUpdateSelection(const TextSelection(baseOffset: 5, extentOffset: 2), TextRange.empty);
    await _pumpGeometry(tester);
    _expectRectNear(_lastPlatformRect(tester, 'TextInput.setMarkedTextRect'), key.currentState!.rectAtOffset(2)!);
  });

  testWidgets('fixed 在五档 DPR 下保持 CJK、Latin、emoji composing 的全局纵向几何', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const scenarios = <({String label, String text, String composing})>[
      (label: '纯中文加入 Latin', text: '产地', composing: 'a'),
      (label: 'emoji 与中文加入 Latin', text: '产😀地', composing: 'a'),
      (label: '中英数字混排加入中文 Latin', text: '产A1地', composing: '中a'),
    ];

    for (final dpr in <double>[1, 1.25, 1.5, 1.75, 2]) {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(700 * dpr, 160 * dpr);
      for (final scenario in scenarios) {
        final key = GlobalKey<EditableViewTestState>();
        final controller = EditableController(text: scenario.text, singleLine: true)..collapseTo(scenario.text.length);
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey<String>('${scenario.label}-$dpr'),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: .topLeft,
                child: SizedBox(
                  width: 700,
                  height: 40,
                  child: EditableView(
                    key: key,
                    controller: controller,
                    style: EditableConfiguration(
                      autofocus: true,
                      softWrap: false,
                      lineHeightMode: EditableLineHeightMode.fixed,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        height: 20 / 14,
                        leadingDistribution: TextLeadingDistribution.even,
                        color: Color(0xff0f172a),
                      ),
                      scrollbars: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await _pumpGeometry(tester);

        final reason = 'DPR=$dpr，${scenario.label}';
        final lineFinder = find.byType(EditableLineView);
        final line = tester.renderObject<RenderEditableLine>(lineFinder);
        final beforeLineRect = tester.getRect(lineFinder);
        final beforePainter = line.layoutedPainter!;
        final beforeMetric = beforePainter.computeLineMetrics().single;
        final beforeGlyph = _globalRect(line, _glyphBounds(line, 0, 1));
        final beforeGlyphMax = _globalRect(line, _selectionBand(line, 0, 1));
        final beforeBaseline = line.localToGlobal(Offset(0, beforeMetric.baseline)).dy;
        final beforeCaret = key.currentState!.caretRectGlobal()!;
        final strut = beforePainter.strutStyle;
        expect(strut, isNotNull, reason: '$reason：fixed 行必须注入 strut');
        expect(strut!.forceStrutHeight, isTrue, reason: '$reason：fixed 必须使用强制 strut');
        expect(strut.fontSize, 14);
        expect(strut.height, 20 / 14);
        expect(strut.leadingDistribution, TextLeadingDistribution.even);
        _expectPhysicalNear(beforeLineRect.height, 20, dpr, reason: reason);

        controller.setSelection(const TextSelection(baseOffset: 0, extentOffset: 1));
        await _pumpGeometry(tester);
        final selectionBand = _globalRect(line, _selectionBand(line, 0, 1));
        expect(line.paintStateForTest.selections, hasLength(1));
        expect(line.paintStateForTest.selections.single.start, 0);
        expect(line.paintStateForTest.selections.single.end, 1);
        _expectPhysicalNear(selectionBand.top, beforeGlyphMax.top, dpr, reason: '$reason：选区顶边必须使用同一 fixed 行带');
        _expectPhysicalNear(selectionBand.bottom, beforeGlyphMax.bottom, dpr, reason: '$reason：选区底边必须使用同一 fixed 行带');

        final composingStart = scenario.text.length;
        final composingEnd = composingStart + scenario.composing.length;
        controller.collapseTo(composingStart);
        await _pumpGeometry(tester);
        tester.testTextInput.log.clear();
        controller.imeReplace(
          composingStart,
          composingStart,
          scenario.composing,
          selection: TextSelection.collapsed(offset: composingEnd),
          composing: TextRange(start: composingStart, end: composingEnd),
        );
        await _pumpGeometry(tester);

        final afterPainter = line.layoutedPainter!;
        final afterMetric = afterPainter.computeLineMetrics().single;
        final afterGlyph = _globalRect(line, _glyphBounds(line, 0, 1));
        final afterGlyphMax = _globalRect(line, _selectionBand(line, 0, 1));
        final composingBand = _globalRect(line, _selectionBand(line, composingStart, composingEnd));
        final afterBaseline = line.localToGlobal(Offset(0, afterMetric.baseline)).dy;
        final afterCaret = key.currentState!.caretRectGlobal()!;
        expect(tester.getRect(lineFinder), beforeLineRect, reason: '$reason：composing 不得移动或压缩 fixed 行盒');
        _expectPhysicalNear(afterMetric.height, beforeMetric.height, dpr);
        _expectPhysicalNear(afterMetric.ascent, beforeMetric.ascent, dpr);
        _expectPhysicalNear(afterMetric.descent, beforeMetric.descent, dpr);
        _expectPhysicalNear(
          afterMetric.baseline,
          beforeMetric.baseline,
          dpr,
          reason: '$reason：fallback run 不得重算 local baseline',
        );
        _expectPhysicalNear(afterBaseline, beforeBaseline, dpr, reason: '$reason：全局 baseline 不得随候选上下跳动');
        for (final edge in <({double actual, double expected, String label})>[
          (actual: afterGlyph.top, expected: beforeGlyph.top, label: 'tight top'),
          (actual: afterGlyph.bottom, expected: beforeGlyph.bottom, label: 'tight bottom'),
          (actual: afterGlyphMax.top, expected: beforeGlyphMax.top, label: 'max top'),
          (actual: afterGlyphMax.bottom, expected: beforeGlyphMax.bottom, label: 'max bottom'),
          (actual: afterCaret.top, expected: beforeCaret.top, label: 'caret top'),
          (actual: afterCaret.bottom, expected: beforeCaret.bottom, label: 'caret bottom'),
          (actual: composingBand.top, expected: selectionBand.top, label: 'composing top'),
          (actual: composingBand.bottom, expected: selectionBand.bottom, label: 'composing bottom'),
        ]) {
          _expectPhysicalNear(edge.actual, edge.expected, dpr, reason: '$reason：${edge.label}');
        }
        expect(line.paintStateForTest.composingStart, composingStart);
        expect(line.paintStateForTest.composingEnd, composingEnd);
        final expectedMarked = _selectionRectInEditor(
          tester,
          controller,
          TextSelection(baseOffset: composingStart, extentOffset: composingEnd),
        );
        _expectRectNear(
          _lastPlatformRect(tester, 'TextInput.setMarkedTextRect'),
          expectedMarked,
          reason: '$reason：平台 marked rect 必须覆盖真实 composing 行带',
        );

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      }
    }
  });
}
