import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _fixedStyle = TextStyle(
  fontSize: 14,
  height: 20 / 14,
  leadingDistribution: TextLeadingDistribution.even,
  color: Color(0xff111111),
);

Widget _host(
  EditableController controller, {
  required EditableLineHeightMode lineHeightMode,
  EditableComposer composer = EditableComposer.plain,
  TextStyle textStyle = _fixedStyle,
  bool softWrap = false,
  EdgeInsets padding = EdgeInsets.zero,
  double width = 480,
  double height = 180,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      height: height,
      child: EditableView(
        controller: controller,
        style: EditableConfiguration(
          composer: composer,
          lineHeightMode: lineHeightMode,
          softWrap: softWrap,
          contentPadding: padding,
          textStyle: textStyle,
          scrollbar: const ElNoScrollBar(),
        ),
      ),
    ),
  ),
);

List<RenderEditableLine> _lines(WidgetTester tester) {
  final result = tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView)).toList()
    ..sort((left, right) => left.index.compareTo(right.index));
  return result;
}

ElScrollView _scrollView(WidgetTester tester) =>
    tester.widget<ElScrollView>(find.descendant(of: find.byType(EditableView), matching: find.byType(ElScrollView)));

ElListView _lineListItem(WidgetTester tester) {
  final scrollView = _scrollView(tester);
  expect(scrollView.children, hasLength(1));
  return scrollView.children.single as ElListView;
}

void _expectPhysicalNear(double actual, double expected, double dpr, {String? reason}) {
  expect((actual - expected).abs() * dpr, lessThanOrEqualTo(1), reason: reason);
}

void main() {
  testWidgets('fixed 在五档 DPR 下统一 CJK、Latin、数字、emoji 与混排行高和 baseline', (tester) async {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const text = '中文输入\nLatin text\n0123456789\n😀👩‍💻\n混合 A1😀文本';

    for (final dpr in <double>[1, 1.25, 1.5, 1.75, 2]) {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(480 * dpr, 180 * dpr);
      final controller = EditableController(text: text);
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey<double>(dpr),
          child: _host(controller, lineHeightMode: EditableLineHeightMode.fixed),
        ),
      );
      await tester.pump();
      await tester.pump();

      final lines = _lines(tester);
      expect(lines, hasLength(5), reason: 'DPR=$dpr 时全部逻辑行都应挂载');
      final firstMetric = lines.first.layoutedPainter!.computeLineMetrics().single;
      final firstHeight = lines.first.size.height;
      _expectPhysicalNear(firstHeight, 20, dpr, reason: 'DPR=$dpr 时 fixed 标称行高应为20 DIP');
      for (final line in lines) {
        final painter = line.layoutedPainter!;
        final metric = painter.computeLineMetrics().single;
        expect(
          painter.strutStyle?.forceStrutHeight,
          isTrue,
          reason: 'DPR=$dpr 第${line.index}行必须使用强制 strut 落实 fixed 合同',
        );
        _expectPhysicalNear(line.size.height, firstHeight, dpr, reason: 'DPR=$dpr 第${line.index}行不得因脚本或 fallback 改变高度');
        _expectPhysicalNear(
          metric.height,
          firstMetric.height,
          dpr,
          reason: 'DPR=$dpr 第${line.index}行的 Paragraph 行高必须统一',
        );
        _expectPhysicalNear(
          metric.baseline,
          firstMetric.baseline,
          dpr,
          reason: 'DPR=$dpr 第${line.index}行的 baseline 必须统一',
        );
        _expectPhysicalNear(metric.ascent, firstMetric.ascent, dpr);
        _expectPhysicalNear(metric.descent, firstMetric.descent, dpr);
      }

      final item = _lineListItem(tester);
      expect(
        item,
        isA<ElListView>().having((value) => value.fixedSize, 'fixedSize', isTrue),
        reason: 'DPR=$dpr 时 fixed 必须使用显式定高的虚拟列表快路径',
      );

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }
  });

  testWidgets('fixed + softWrap 固定每条视觉行度量，但逻辑行仍使用可变高 列表配置', (tester) async {
    const dpr = 1.75;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = const Size(180, 220) * dpr;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = EditableController(text: List<String>.filled(10, '中文Latin123😀混排').join());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(controller, lineHeightMode: EditableLineHeightMode.fixed, softWrap: true, width: 180, height: 220),
    );
    await tester.pump();
    await tester.pump();

    final lines = _lines(tester);
    expect(lines, hasLength(1));
    final line = lines.single;
    final metrics = line.layoutedPainter!.computeLineMetrics();
    expect(metrics.length, greaterThan(3), reason: '测试文本必须真实折成多条视觉行');
    final fixedLineHeight = line.preferredLineHeight;
    _expectPhysicalNear(fixedLineHeight, 20, dpr);
    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      _expectPhysicalNear(metric.height, fixedLineHeight, dpr, reason: '第$index条视觉行必须使用同一 fixed 行高');
      if (index > 0) {
        _expectPhysicalNear(
          metric.baseline - metrics[index - 1].baseline,
          fixedLineHeight,
          dpr,
          reason: '相邻视觉行 baseline 间距必须等于 fixedLineHeight',
        );
      }
    }
    _expectPhysicalNear(
      line.size.height,
      metrics.length * fixedLineHeight,
      dpr,
      reason: '逻辑 Render 行高必须等于视觉行数 × fixedLineHeight',
    );
    final item = _lineListItem(tester);
    expect(
      item,
      isA<ElListView>().having((value) => value.fixedSize, 'fixedSize', isFalse),
      reason: 'softWrap 后每个逻辑行的视觉行数不同，禁止冒充 统一尺寸列表',
    );
  });

  testWidgets('fixed + nowrap 的总内容高度精确，换色与继续输入后不退回变高列表', (tester) async {
    const dpr = 1.75;
    const padding = EdgeInsets.only(top: 7, bottom: 11, left: 12, right: 12);
    const lineCount = 10;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = const Size(320, 80) * dpr;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = EditableController(
      text: List<String>.generate(lineCount, (index) => '第$index行 Latin $index').join('\n'),
    );
    addTearDown(controller.dispose);

    Widget editor(TextStyle style) => _host(
      controller,
      lineHeightMode: EditableLineHeightMode.fixed,
      textStyle: style,
      padding: padding,
      width: 320,
      height: 80,
    );

    void expectFixedScrollGeometry(String phase) {
      final scrollView = _scrollView(tester);
      final position = scrollView.controller!.position;
      final fixedLineHeight = _lines(tester).first.preferredLineHeight;
      final expectedContentHeight = lineCount * fixedLineHeight + padding.vertical;
      final expectedRange = (expectedContentHeight - position.viewportDimension).clamp(0.0, double.infinity);
      _expectPhysicalNear(
        position.maxScrollExtent - position.minScrollExtent,
        expectedRange,
        dpr,
        reason: '$phase：最大滚动范围必须由 lineCount × lineHeight + padding 唯一决定',
      );
      _expectPhysicalNear(
        position.maxScrollExtent - position.minScrollExtent + position.viewportDimension,
        expectedContentHeight,
        dpr,
        reason: '$phase：滚动内容总高度必须精确包含上下 padding',
      );
      final item = _lineListItem(tester);
      expect(
        item,
        isA<ElListView>().having((value) => value.fixedSize, 'fixedSize', isTrue),
        reason: '$phase：fixed nowrap 不得退回变高 列表配置',
      );
    }

    await tester.pumpWidget(editor(_fixedStyle));
    await tester.pump();
    await tester.pump();
    expectFixedScrollGeometry('初始布局');

    await tester.pumpWidget(editor(_fixedStyle.copyWith(color: const Color(0xff2563eb))));
    await tester.pump();
    await tester.pump();
    expectFixedScrollGeometry('正文换色后');

    controller.collapseTo(0);
    controller.insertText('新增中文 A1😀 ');
    await tester.pump();
    await tester.pump();
    expect(controller.document.lineCount, lineCount);
    expectFixedScrollGeometry('继续输入后');
  });

  testWidgets('content 允许富文本大字号撑高，fixed 保持统一且模式热切不换 controller', (tester) async {
    final controller = EditableController(text: 'small\nlarge');
    addTearDown(controller.dispose);
    const composer = _LargeSecondLineComposer();

    await tester.pumpWidget(_host(controller, lineHeightMode: EditableLineHeightMode.fixed, composer: composer));
    await tester.pump();
    await tester.pump();
    var lines = _lines(tester);
    expect(lines, hasLength(2));
    expect(lines[1].size.height, lines[0].size.height);
    var item = _lineListItem(tester);
    expect(item, isA<ElListView>().having((value) => value.fixedSize, 'fixedSize', isTrue));

    await tester.pumpWidget(_host(controller, lineHeightMode: EditableLineHeightMode.content, composer: composer));
    await tester.pump();
    await tester.pump();
    lines = _lines(tester);
    expect(lines, hasLength(2));
    expect(lines[1].size.height, greaterThan(lines[0].size.height), reason: 'content 模式不得用基础 strut 压扁富文本大字号行');
    expect(lines[1].size.height, greaterThanOrEqualTo(36));
    expect(
      tester.widget<EditableView>(find.byType(EditableView)).controller,
      same(controller),
      reason: '行高模式热切只能重排，不能替换文档模型',
    );
    item = _lineListItem(tester);
    expect(
      item,
      isA<ElListView>().having((value) => value.fixedSize, 'fixedSize', isFalse),
      reason: 'content 变高行不得冒充定高虚拟列表',
    );
  });
}

final class _LargeSecondLineComposer extends EditableComposer {
  const _LargeSecondLineComposer();

  @override
  InlineSpan compose(EditableLineContext context) => TextSpan(
    text: context.text,
    style: context.line == 1 ? context.baseStyle.copyWith(fontSize: 36, height: 1) : context.baseStyle,
  );
}
