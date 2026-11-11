import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show SystemChannels;
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  home: Align(alignment: Alignment.topLeft, child: child),
);

/// 有效光标 = 命中路径上**第一个** cursor 非 defer 的 `MouseTrackerAnnotation`
/// （MouseTracker 自己的解析口径：first-in-path-wins）。
///
/// 不能改读 `render.cursor` —— inline span 的 cursor 现在由 MouseTracker 直接
/// 消费（`TextSpan` 本身是 `MouseTrackerAnnotation`，且在命中路径里排在
/// `ElRenderView` 之前），宿主 getter 返回 defer 是**正确**的。本 helper 顺带
/// 锁住"span 必须排在 render 之前"这个次序不变量。
MouseCursor effectiveCursorAt(WidgetTester tester, Offset global) {
  final result = HitTestResult();
  tester.binding.hitTestInView(result, global, tester.view.viewId);
  for (final entry in result.path) {
    final target = entry.target;
    // span 与 render 都是 MouseTrackerAnnotation；按路径序取第一个非 defer 的，
    // 这正是 MouseTracker 的解析口径，也顺带锁住「span 必须排在 render 之前」。
    if (target is TextSpan && target.mouseCursor != MouseCursor.defer) return target.mouseCursor;
    if (target is ElRenderView && target.cursor != MouseCursor.defer) return target.cursor;
  }
  return MouseCursor.defer;
}

void main() {
  group('最小文本合约', () {
    testWidgets('普通文本沿 ElView 继承并在颜色更新时保持布局', (tester) async {
      final key = UniqueKey();
      Widget tree(Color color) => _app(
        ElView(
          style: ElStyle(color: color, fontSize: 20),
          child: ElView(key: key, child: '继承文字'),
        ),
      );
      await tester.pumpWidget(tree(Colors.red));
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      final layouts = render.debugLayoutCount;
      await tester.pumpWidget(tree(Colors.blue));
      final span = (render.content as TextEngine?)!.painterForTest.text! as TextSpan;
      expect(span.style!.color, Colors.blue);
      expect(span.style!.fontSize, 20);
      expect(render.debugLayoutCount, layouts);
      expect(find.byType(RichText), findsNothing);
    });

    testWidgets('TextSpan 保留嵌套、局部覆盖和 inherit:false', (tester) async {
      final key = UniqueKey();
      await tester.pumpWidget(
        _app(
          ElView(
            key: key,
            style: ElStyle(color: Colors.red, fontSize: 18),
            child: TextSpan(
              text: '父',
              children: [
                TextSpan(text: '继承'),
                TextSpan(
                  text: '覆盖',
                  style: TextStyle(color: Colors.blue),
                ),
                TextSpan(text: '隔离', style: TextStyle(inherit: false, fontSize: 10)),
              ],
            ),
          ),
        ),
      );
      final engine = (tester.renderObject<ElRenderView>(find.byKey(key)).content as TextEngine?)!;
      final span = engine.painterForTest.text! as TextSpan;
      expect(span.toPlainText(), '父继承覆盖隔离');
      expect(span.children![0].style!.color, Colors.red);
      expect(span.children![1].style!.color, Colors.blue);
      expect(span.children![2].style!.color, isNull);
      expect(span.children![2].style!.fontSize, 10);
    });

    testWidgets('宽容数组只归一为 TextSpan 和 WidgetSpan，ElView 保留真实子树', (tester) async {
      final key = UniqueKey();
      final childKey = UniqueKey();
      await tester.pumpWidget(
        _app(
          ElView(
            key: key,
            child: [
              'a',
              1,
              null,
              [true, TextSpan(text: 'T')],
              ElView(key: childKey, child: '独立子项'),
            ],
          ),
        ),
      );
      final engine = (tester.renderObject<ElRenderView>(find.byKey(key)).content as TextEngine?)!;
      expect(engine.painterForTest.text!.toPlainText(), 'a1trueT\ufffc');
      expect(engine.structure.spans.single.child, isA<ElView>());
      expect(find.byKey(childKey), findsOneWidget);
    });

    for (final alignment in PlaceholderAlignment.values) {
      testWidgets('WidgetSpan 对齐、缩放和只读测量：$alignment', (tester) async {
        final key = UniqueKey();
        final childKey = UniqueKey();
        await tester.pumpWidget(
          _app(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: ElView(
                key: key,
                style: ElStyle(fontSize: 14, width: 220),
                child: TextSpan(
                  children: [
                    TextSpan(text: 'A'),
                    WidgetSpan(
                      alignment: alignment,
                      baseline: TextBaseline.alphabetic,
                      child: SizedBox(key: childKey, width: 12, height: 8),
                    ),
                    TextSpan(text: 'Z'),
                  ],
                ),
              ),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byKey(key));
        final child = tester.renderObject<RenderBox>(find.byKey(childKey));
        final origin = child.localToGlobal(Offset.zero);
        expect((child.localToGlobal(Offset(12, 0)) - origin).dx, closeTo(24, .01));
        final before = (render.content as TextEngine?)!.painterForTest.text;
        final offset = (child.parentData as ElTextParentData).offset;
        final dry = render.getDryLayout(render.constraints);
        expect(dry, render.size);
        expect((render.content as TextEngine?)!.painterForTest.text, same(before));
        expect((child.parentData as ElTextParentData).offset, offset);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('真实 WidgetSpan 子项保留事件，缩放后命中坐标一致', (tester) async {
      final childKey = UniqueKey();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ElView(
              child: TextSpan(
                children: [
                  TextSpan(text: '前'),
                  WidgetSpan(
                    child: ElView(
                      key: childKey,
                      style: ElStyle(width: 30, height: 20),
                      event: ElEvent(onTap: (_) => taps++),
                    ),
                  ),
                  TextSpan(text: '后'),
                ],
              ),
            ),
          ),
        ),
      );
      final child = tester.renderObject<RenderBox>(find.byKey(childKey));
      await tester.tapAt(child.localToGlobal(Offset(15, 10)));
      expect(taps, 1);
    });

    testWidgets('TextSpan 的原始 recognizer、鼠标回调与自定义事件只派发一次', (tester) async {
      final key = UniqueKey();
      var taps = 0;
      var enters = 0;
      var exits = 0;
      final recognizer = TapGestureRecognizer()..onTap = () => taps++;
      addTearDown(recognizer.dispose);
      await tester.pumpWidget(
        _app(
          ElView(
            key: key,
            child: TextSpan(
              text: '原生 span',
              recognizer: recognizer,
              onEnter: (_) => enters++,
              onExit: (_) => exits++,
              mouseCursor: SystemMouseCursors.click,
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset(700, 500));
      await mouse.moveTo(tester.getCenter(find.byKey(key)));
      await tester.pump();
      await tester.tap(find.byKey(key));
      expect(taps, 1);
      expect(enters, 1);
      await mouse.moveTo(Offset(700, 500));
      await tester.pump();
      expect(exits, 1);
      await mouse.removePointer();
    });
  });

  group('字符串颜色同步', () {
    Widget shell(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('父 color 非动画切换 → 子 String 快路径 painter.text 必须更新为新 color', (tester) async {
      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFF000000), fontSize: 14),
              child: 'inherited text',
            ),
          ),
        ),
      );

      final child = tester.renderObject<ElRenderView>(find.byType(ElView));

      final initialSpan = ((child.content as TextEngine?)?.painterForTest.text);
      expect(initialSpan, isA<TextSpan>());
      expect(
        (initialSpan as TextSpan).style?.color,
        const Color(0xFF000000),
        reason: 'mount 后子 painter.text 应含父继承的初始 color',
      );

      // 父 color 切换到红（无 transition → 立即生效）
      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFFFF0000), fontSize: 14),
              child: 'inherited text',
            ),
          ),
        ),
      );
      // 多 pump 一次让 paint 走完
      await tester.pump();

      // **核心断言**：子 painter.text 的 color 必须同步为红
      final updatedSpan = ((child.content as TextEngine?)?.painterForTest.text);
      expect(updatedSpan, isA<TextSpan>());
      expect(
        (updatedSpan as TextSpan).style?.color,
        const Color(0xFFFF0000),
        reason:
            '父 color 非动画切换是 paint-only damage，子不重 layout，但 paint '
            '阶段必须把新继承 color 同步到 painter.text，否则画的是旧色',
      );

      // 子 committed inheritedText.color 也应为红（cascade 经 propagator 已更新）
      expect(child.committedResolvedStyle.inheritedText.color, const Color(0xFFFF0000));
    });

    testWidgets('子继承 color 多帧 paint：painter.text 持续追踪 committed 状态', (tester) async {
      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFF000000), fontSize: 14),
              child: 'leaf',
            ),
          ),
        ),
      );

      final child = tester.renderObject<ElRenderView>(find.byType(ElView));

      // 切到红
      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFFFF0000), fontSize: 14),
              child: 'leaf',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        (((child.content as TextEngine?)?.painterForTest.text) as TextSpan?)?.style?.color,
        const Color(0xFFFF0000),
      );

      // 切到蓝
      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFF0000FF), fontSize: 14),
              child: 'leaf',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        (((child.content as TextEngine?)?.painterForTest.text) as TextSpan?)?.style?.color,
        const Color(0xFF0000FF),
      );
    });

    testWidgets('父 color 非动画切换：直文本 ElView 不触发 performLayout 但同步 painter.text', (tester) async {
      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFF000000), fontSize: 14),
              child: 'leaf',
            ),
          ),
        ),
      );
      final child = tester.renderObject<ElRenderView>(find.byType(ElView));
      final before = child.debugLayoutCount;

      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFFFF0000), fontSize: 14),
              child: 'leaf',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(child.debugLayoutCount, before, reason: '直文本 ElView 的 color 更新应保持 paint-only，不触发 performLayout');
      expect(
        (((child.content as TextEngine?)?.painterForTest.text) as TextSpan?)?.style?.color,
        const Color(0xFFFF0000),
      );
    });

    testWidgets('父 color 非动画切换：直文本 ElView 不主动刷 TextPainter.layout（T21 paint-only 分级）', (tester) async {
      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFF000000), fontSize: 14),
              child: 'leaf',
            ),
          ),
        ),
      );
      final child = tester.renderObject<ElRenderView>(find.byType(ElView));
      final before = (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);

      await tester.pumpWidget(
        shell(
          const SizedBox(
            width: 240,
            child: ElView(
              style: ElStyle(color: Color(0xFFFF0000), fontSize: 14),
              child: 'leaf',
            ),
          ),
        ),
      );
      await tester.pump();

      // **T21**：ensureStringPainterFresh 内 compareTo 分级把 paint-only 差异只 set text
      // 不 layout（SDK TextPainter 内部保 _layoutCache，paint 时惰性重建 paragraph）。
      expect(
        (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0),
        before,
        reason: 'T21：paint-only color 差异走 compareTo=paint 分档，painter.layout() 不再被显式调用',
      );
      expect(
        (((child.content as TextEngine?)?.painterForTest.text) as TextSpan?)?.style?.color,
        const Color(0xFFFF0000),
      );

      final rects = (child.content as TextEngine).selectionPaintRectsForRange(const ui.TextRange(start: 0, end: 4));
      expect(rects, isNotEmpty);
      final result = BoxHitTestResult();
      child.hitTest(result, position: child.size.center(Offset.zero));
      await tester.pump();

      expect(
        (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0),
        before,
        reason: '后续 selection / hit-test / paint 复用已刷新的 painter，不应继续主动 layout。',
      );
    });

    testWidgets('fontSize 变化：直文本 ElView 主动刷新 TextPainter.layout', (tester) async {
      Widget build(double fontSize) => shell(
        SizedBox(
          width: 240,
          child: ElView(
            style: ElStyle(color: const Color(0xFF000000), fontSize: fontSize),
            child: 'leaf',
          ),
        ),
      );

      await tester.pumpWidget(build(14));
      final child = tester.renderObject<ElRenderView>(find.byType(ElView));
      final before = (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);

      await tester.pumpWidget(build(24));
      await tester.pump();

      expect(
        (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0),
        greaterThan(before),
        reason: 'fontSize 影响 text metrics，必须刷新 TextPainter.layout。',
      );
      expect((((child.content as TextEngine?)?.painterForTest.text) as TextSpan?)?.style?.fontSize, 24);
    });
  });

  group('文字溢出探测', () {
    const k = ValueKey('t');

    ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byKey(k));

    Widget host({required ElStyle style, Object? child}) => MaterialApp(
      home: Stack(
        children: [ElView(key: k, style: style, child: child)],
      ),
    );

    testWidgets('maxLines=1 + ellipsis 截断 → true', (tester) async {
      await tester.pumpWidget(
        host(
          style: const ElStyle(
            width: 60,
            fontSize: 16,
            maxLines: 1,
            textOverflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          child: '这是一段远超六十像素宽度的长文本内容',
        ),
      );
      expect(((renderOf(tester).content as TextEngine?)?.textOverflows ?? false), isTrue);
    });

    testWidgets('文本完整放下 → false', (tester) async {
      await tester.pumpWidget(host(style: const ElStyle(width: 300, fontSize: 16), child: '短文本'));
      expect(((renderOf(tester).content as TextEngine?)?.textOverflows ?? false), isFalse);
    });

    testWidgets('单行不换行超宽（clip）→ true', (tester) async {
      await tester.pumpWidget(
        host(
          style: const ElStyle(width: 60, fontSize: 16, softWrap: false, textOverflow: TextOverflow.clip),
          child: '这是一段远超六十像素宽度的长文本内容',
        ),
      );
      expect(((renderOf(tester).content as TextEngine?)?.textOverflows ?? false), isTrue);
    });

    testWidgets('overflow 未声明（visible）超宽同样可探测', (tester) async {
      await tester.pumpWidget(
        host(style: const ElStyle(width: 60, fontSize: 16, softWrap: false), child: '这是一段远超六十像素宽度的长文本内容'),
      );
      expect(((renderOf(tester).content as TextEngine?)?.textOverflows ?? false), isTrue);
    });

    testWidgets('无文本载荷恒 false', (tester) async {
      await tester.pumpWidget(host(style: const ElStyle(width: 60, height: 40, backgroundColor: Color(0xFF222222))));
      expect(((renderOf(tester).content as TextEngine?)?.textOverflows ?? false), isFalse);
    });
  });

  group('文字绘制失效', () {
    Widget shell(Widget child) => MaterialApp(home: Scaffold(body: child));

    ElRenderView viewOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    group('T21 paint-only 文本失效路由（纯字符串子）', () {
      testWidgets('父字面 color 翻转 → 子 painter 换色但 layout 计数不增', (tester) async {
        const parentKey = ValueKey('parent');
        const childKey = ValueKey('child');
        Widget build(Color color) => shell(
          ElView(
            key: parentKey,
            style: .new(width: 240, height: 40, color: color, fontSize: 14),
            child: ElView(key: childKey, style: .new(width: 240, height: 20), child: 'inherited'),
          ),
        );

        await tester.pumpWidget(build(const Color(0xff000000)));
        await tester.pump();
        final child = viewOf(tester, childKey);
        final baselineLayoutCount = (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);
        final baselineDebugLayout = child.debugLayoutCount;

        await tester.pumpWidget(build(const Color(0xffff0000)));
        await tester.pump();

        final span = ((child.content as TextEngine?)?.painterForTest.text) as TextSpan?;
        expect(
          span?.style?.color,
          const Color(0xffff0000),
          reason: 'paint-only 失效路径下 ensureStringPainterFresh 仍必须把新 color 同步到 painter.text',
        );

        expect(
          (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0),
          baselineLayoutCount,
          reason: 'paint-only color 变化必须走 markTextPaintDirty，不主动 painter.layout()',
        );
        expect(child.debugLayoutCount, baselineDebugLayout, reason: 'paint-only 变化不应触发本节点 performLayout');
      });

      testWidgets('父 fontSize 翻转 → 子 layout 计数增加（回归保护）', (tester) async {
        const parentKey = ValueKey('parent-fs');
        const childKey = ValueKey('child-fs');
        Widget build(double fontSize) => shell(
          ElView(
            key: parentKey,
            style: .new(width: 240, height: 60, color: const Color(0xff000000), fontSize: fontSize),
            child: ElView(key: childKey, style: .new(width: 240, height: 30), child: 'font size sample'),
          ),
        );

        await tester.pumpWidget(build(14));
        await tester.pump();
        final child = viewOf(tester, childKey);
        final baselineLayoutCount = (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);

        await tester.pumpWidget(build(24));
        await tester.pump();

        expect(
          (((child.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0),
          greaterThan(baselineLayoutCount),
          reason: 'fontSize 影响 metrics，必须重新 layout（回归保护 T21 不误伤）',
        );
      });

      testWidgets('color transition 中间帧稳态：layout 计数不随帧增长', (tester) async {
        const key = ValueKey('color-trans');
        Widget build(Color color) => shell(
          ElView(
            key: key,
            style: .new(
              width: 200,
              height: 30,
              color: color,
              fontSize: 14,
              transition: [ElTransition.field(.color, Duration(milliseconds: 200))],
            ),
            child: 'transition sample',
          ),
        );

        await tester.pumpWidget(build(const Color(0xff000000)));
        await tester.pump();
        final render = viewOf(tester, key);
        await tester.pumpWidget(build(const Color(0xff2563eb)));
        await tester.pump();
        final atStartLayoutCount = (((render.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);

        await tester.pump(const Duration(milliseconds: 40));
        final at40 = (((render.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);
        await tester.pump(const Duration(milliseconds: 40));
        final at80 = (((render.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);
        await tester.pump(const Duration(milliseconds: 40));
        final at120 = (((render.content as TextEngine?)?.stringPainterLayoutCountForTest) ?? 0);

        expect(at40, atStartLayoutCount, reason: 'color transition 中段不应 relayout');
        expect(at80, atStartLayoutCount, reason: 'color transition 中段不应 relayout');
        expect(at120, atStartLayoutCount, reason: 'color transition 中段不应 relayout');

        await tester.pump(const Duration(milliseconds: 220));
        final endSpan = ((render.content as TextEngine?)?.painterForTest.text) as TextSpan?;
        expect(endSpan?.style?.color, const Color(0xff2563eb));
      });
    });

    group('T21 paint-only 文本失效路由（rich inline 子）', () {
      testWidgets('父字面 color 翻转 → richtext_fc relayout 计数不增', (tester) async {
        // 单 const TextSpan 作 raw child——setTextPayload 的 identical rawChild 早退
        // 让 rich-inline 路径的 IFC 不被 child 变化误伤，我们只想观察 color 变化
        // 单独触发的失效路径。
        const key = ValueKey('rich-parent');
        const richChild = TextSpan(
          children: [
            TextSpan(text: 'rich '),
            TextSpan(
              text: 'inline ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: 'text'),
          ],
        );
        Widget build(Color color) => shell(
          ElView(
            key: key,
            style: .new(width: 260, height: 30, color: color, fontSize: 14),
            child: richChild,
          ),
        );

        await tester.pumpWidget(build(const Color(0xff000000)));
        await tester.pump();
        final render = viewOf(tester, key);
        final fc = (render.content as TextEngine?)!;
        final baselineRelayout = fc.stringPainterLayoutCountForTest;
        final baselineDebugLayout = render.debugLayoutCount;

        await tester.pumpWidget(build(const Color(0xffff0000)));
        await tester.pump();
        await tester.pump();

        expect(
          fc.stringPainterLayoutCountForTest,
          baselineRelayout,
          reason: 'rich inline paint-only 失效路径，painter.layout() 不应被调用',
        );
        expect(render.debugLayoutCount, baselineDebugLayout, reason: 'paint-only 变化不应触发本节点 performLayout');

        // direct rich span 的 root TextSpan 无 style，颜色烙在子 span 上。
        final painterSpan = fc.painterForTest.text as TextSpan?;
        final firstChild = painterSpan?.children?.first as TextSpan?;
        expect(
          firstChild?.style?.color,
          const Color(0xffff0000),
          reason: 'paint-only 分级仍会 set text，让 span 树各文本 span 拿到新色',
        );
      });
    });
  });

  group('文字盒协议', () {
    const paddedKey = ValueKey('baseline-padded');

    const plainKey = ValueKey('baseline-plain');

    const hostKey = ValueKey('dry-host');

    group('baseline 委托', () {
      Future<void> expectBaselineAligned(
        WidgetTester tester, {
        required Object paddedChild,
        required Object plainChild,
      }) async {
        await tester.pumpWidget(
          _app(
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                ElView(
                  key: paddedKey,
                  style: .new(fontSize: 20, padding: const EdgeInsets.only(top: 10)),
                  child: paddedChild,
                ),
                ElView(key: plainKey, style: .new(fontSize: 20), child: plainChild),
              ],
            ),
          ),
        );
        await tester.pump();
        final paddedTop = tester.getTopLeft(find.byKey(paddedKey)).dy;
        final plainTop = tester.getTopLeft(find.byKey(plainKey)).dy;
        // 两者字体与内容同款：基线生效 ⇒ 带 padding.top:10 的盒子整体上移 10。
        // 基线丢失（null）⇒ RenderFlex 顶对齐 ⇒ 差值为 0 → 红。
        expect(
          paddedTop,
          moreOrLessEquals(plainTop - 10, epsilon: 0.01),
          reason: '文本 ElView 必须上报基线（padding.top 应体现在基线距离里）',
        );
      }

      testWidgets('纯 String 文本参与 Row 基线对齐', (tester) async {
        await expectBaselineAligned(tester, paddedChild: 'Xy', plainChild: 'Xy');
      });

      testWidgets('rich-inline 文本参与 Row 基线对齐', (tester) async {
        await expectBaselineAligned(
          tester,
          paddedChild: [
            'X',
            ElView(
              style: .new(color: const Color(0xFF3311FF)),
              child: 'y',
            ),
          ],
          plainChild: [
            'X',
            ElView(
              style: .new(color: const Color(0xFF3311FF)),
              child: 'y',
            ),
          ],
        );
      });
    });

    group('dry layout 委托', () {
      Future<void> expectDryHeightMatchesLayout(WidgetTester tester, Object child) async {
        await tester.pumpWidget(
          _app(
            ElView(
              key: hostKey,
              style: .new(fontSize: 20, padding: const EdgeInsets.fromLTRB(48, 36, 12, 12)),
              child: child,
            ),
          ),
        );
        await tester.pump();
        final render = tester.renderObject<ElRenderView>(find.byKey(hostKey));
        // 宽有界 / 高无界：dry 高度必须来自真实文本测量（回退 0-intrinsic 时
        // 会塌成 padding-only 高度）。宽度沿用旧口径（有界维度填满）不在此锁。
        final dry = render.getDryLayout(const BoxConstraints(maxWidth: 300));
        expect(dry.height, moreOrLessEquals(render.size.height, epsilon: 0.01), reason: '文本节点 dry 高度必须等于实际布局高度');
        expect(dry.height, greaterThan(48.01), reason: 'dry 高度必须包含文本行高，不能塌成 padding-only');
      }

      testWidgets('纯 String 文本 dry 高度与布局一致', (tester) async {
        await expectDryHeightMatchesLayout(tester, 'Hello 干布局');
      });

      testWidgets('rich-inline 文本 dry 高度与布局一致', (tester) async {
        await expectDryHeightMatchesLayout(tester, [
          'Hello ',
          ElView(
            style: .new(color: const Color(0xFF3311FF)),
            child: '干布局',
          ),
        ]);
      });

      testWidgets('纯 String 双向有界约束：dry 尺寸等于真实布局，不虚胖成 biggest', (tester) async {
        await tester.pumpWidget(_app(ElView(key: hostKey, style: .new(fontSize: 20), child: 'dry both')));
        await tester.pump();
        final render = tester.renderObject<ElRenderView>(find.byKey(hostKey));
        // 双向有界曾走「直接返回 constraints.biggest」捷径：auto 尺寸文本节点在
        // 任何双向有界父级下 dry 虚胖成 300x200，与 wet 布局尺寸违约。
        final dry = render.getDryLayout(const BoxConstraints(maxWidth: 300, maxHeight: 200));
        expect(dry.width, lessThan(299), reason: 'dry 宽度必须是文本实测宽，不得填满有界约束');
        expect(dry.height, lessThan(199), reason: 'dry 高度必须是文本实测高，不得填满有界约束');
        expect(dry.width, moreOrLessEquals(render.size.width, epsilon: 0.01), reason: 'dry/wet 宽度一致');
        expect(dry.height, moreOrLessEquals(render.size.height, epsilon: 0.01), reason: 'dry/wet 高度一致');
      });
    });

    group('rich-inline 原子子节点约束', () {
      testWidgets('嵌套 ElView 的 infinity 高度不会逃逸成无限尺寸', (tester) async {
        const fillKey = ValueKey('rich-inline-fill');

        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 240,
              height: 160,
              child: ElView(
                child: [
                  ElView(
                    style: const ElStyle(),
                    child: [
                      ElView(
                        key: fillKey,
                        style: const ElStyle(
                          width: double.infinity,
                          height: double.infinity,
                          backgroundColor: Color(0xFFFF66AA),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'rich-inline placeholder layout must pass finite constraints to atomic ElView children',
        );
        if (exception != null) return;

        final render = tester.renderObject<ElRenderView>(find.byKey(fillKey));
        expect(render.size.width.isFinite, isTrue);
        expect(render.size.height.isFinite, isTrue);
        expect(render.size.height, lessThanOrEqualTo(160));
      });
    });
  });

  group('富文本固有尺寸稳定性', () {
    Widget framed(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          // 限宽不限高：文本换行，高度反映行数
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 120), child: child),
        ),
      ),
    );

    ElRenderView renderText(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView));

    testWidgets('intrinsic 查询不污染 layout painter（IFC 换行文本 size 稳定）', (tester) async {
      // List child → IFC 路径（非纯 String 快路径）。窄宽 → 多行。
      await tester.pumpWidget(
        framed(
          const ElView(
            style: ElStyle(fontSize: 14),
            child: <Object>['The quick brown fox ', 'jumps over the lazy dog again and again'],
          ),
        ),
      );
      final rt = renderText(tester);
      final sizeBefore = rt.size;
      expect(sizeBefore.height, greaterThan(20), reason: '窄宽应换多行（前置条件）');

      // 交错 intrinsic 查询（旧实现在此污染共享 _painter）
      final maxW = rt.getMaxIntrinsicWidth(double.infinity);
      expect(maxW, greaterThan(sizeBefore.width), reason: 'max intrinsic（不换行单行宽）应大于换行后的窄宽');

      // 同输入再 layout 一次 → 命中 fast-path
      rt.markNeedsLayout();
      await tester.pump();

      expect(rt.size, sizeBefore, reason: 'intrinsic 查询不得污染 layout painter → 二次 layout size 稳定');
    });

    testWidgets('rich text intrinsic height 使用段落布局而不是累加 atomic 高度', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: const ElView(
                  style: ElStyle(fontSize: 14),
                  child: <Object>['A ', SizedBox(width: 40, height: 40), ' B ', SizedBox(width: 30, height: 40), ' C'],
                ),
              ),
            ),
          ),
        ),
      );

      final rt = renderText(tester);
      final intrinsic = rt.getMinIntrinsicHeight(300);

      expect(intrinsic, closeTo(rt.size.height, 0.001));
      expect(intrinsic, lessThan(70), reason: '两个 inline widget 同行时高度不应变成 40 + 40');
    });
  });

  group('内联原子绘制对齐', () {
    const hostKey = ValueKey('atomic-align-host');

    const blockAtomKey = ValueKey('atomic-align-inline-block');

    const widgetAtomKey = ValueKey('atomic-align-raw-widget');

    const hostPadding = EdgeInsets.fromLTRB(48, 36, 12, 12);

    ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byKey(hostKey));

    Rect placeholderGap(ElRenderView render, int ordinal) {
      final text = (render.content as TextEngine?)!.painterForTest.text!.toPlainText();
      var index = -1;
      for (var i = 0; i <= ordinal; i++) {
        index = text.indexOf('￼', index + 1);
        expect(index, greaterThanOrEqualTo(0), reason: 'textContent 应含第 ${ordinal + 1} 个原子占位符');
      }
      final boxes = (render.content as TextEngine?)!.getBoxesForSelectionForTest(index, index + 1);
      expect(boxes, isNotEmpty, reason: 'painter 应能给出占位符 #$ordinal 的空隙盒');
      return boxes.first.toRect();
    }

    void expectAtomFillsGap(WidgetTester tester, ElRenderView render, Key atomKey, int ordinal) {
      final gap = placeholderGap(render, ordinal);
      final atom = tester.renderObject(find.byKey(atomKey)) as RenderBox;
      final actual = atom.localToGlobal(Offset.zero);
      final expected = render.localToGlobal(render.contentOrigin + gap.topLeft);
      expect(
        actual,
        offsetMoreOrLessEquals(expected, epsilon: 0.01),
        reason: '原子 #$ordinal 必须画在文字流预留的空隙上（多加/少加一次 contentOrigin 都会偏）',
      );
      expect(atom.size.width, moreOrLessEquals(gap.width, epsilon: 0.01), reason: '空隙宽度应等于原子宽度');
      expect(atom.size.height, moreOrLessEquals(gap.height, epsilon: 0.01), reason: '空隙高度应等于原子高度');
    }

    testWidgets('padding 宿主下 ElView 原子与 raw Widget 原子均与占位空隙重合', (tester) async {
      await tester.pumpWidget(
        _app(
          ElView(
            key: hostKey,
            style: .new(fontSize: 20, padding: hostPadding),
            child: [
              '前缀 ',
              ElView(
                key: blockAtomKey,
                style: .new(width: 40, height: 18, backgroundColor: const Color(0xFF3311FF)),
              ),
              ' 中缀 ',
              SizedBox(key: widgetAtomKey, width: 24, height: 24),
              ' 后缀',
            ],
          ),
        ),
      );
      await tester.pump();
      final render = renderOf(tester);
      expect(render.contentOrigin, const Offset(48, 36), reason: '前置：padding 应转化为 contentOrigin（口径变了本锁要重标定）');

      expectAtomFillsGap(tester, render, blockAtomKey, 0);
      expectAtomFillsGap(tester, render, widgetAtomKey, 1);
    });
  });

  group('选区覆盖形状', () {
    testWidgets('多行部分选中：N 次裁剪重绘只对应 ≤1 次 overlay shape', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ElSelectionController();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: ElSelectionView(
                controller: controller,
                child: const ElView(
                  style: ElStyle(
                    fontSize: 14,
                    onSelection: ElStyle(backgroundColor: Color(0x553b82f6), color: Color(0xffffffff)),
                  ),
                  child: 'aaa bbb ccc ddd eee fff ggg hhh iii jjj kkk lll mmm nnn ooo ppp qqq rrr sss ttt',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final render = tester.renderObject<ElRenderView>(find.byType(ElView).first);
      final size = render.size;

      // 鼠标拖选：从第一行中段拖到倒数第二行中段 —— 部分选中（非全选），跨多行，
      // 于是走逐 rect clip 分支。
      final start = render.localToGlobal(Offset(size.width * 0.4, 8));
      final end = render.localToGlobal(Offset(size.width * 0.6, size.height - 12));
      final mouse = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await mouse.moveTo(end);
      await tester.pump();
      await mouse.up();
      await tester.pump();

      final sel = controller.text;
      expect(sel, isNotNull, reason: '拖选后必须有选区');

      // 计一帧：重绘时逐 rect 裁剪的次数 vs overlay 真 shape 次数。
      final clipBefore = (((render.content as TextEngine?)?.debugSelectionClipRectOverlayCount) ?? 0);
      BenchmarkProbe.reset();
      render.markNeedsPaint();
      await tester.pump();
      final clips = (((render.content as TextEngine?)?.debugSelectionClipRectOverlayCount) ?? 0) - clipBefore;
      final shapes = BenchmarkProbe.selectionOverlayLayoutCount;

      // ignore: avoid_print
      print('[选中 overlay] 本帧裁剪重绘=$clips  overlay shape=$shapes');
      expect(clips, 1, reason: '部分选中走并集 path 一次裁剪重绘（不再是逐行 N 次）');
      expect(shapes, lessThanOrEqualTo(1), reason: 'overlay 与 rect 无关：裁剪重绘只该 shape ≤1 次');

      controller.clear();
      await tester.pump();
    });
  });

  group('选区重绘几何', () {
    for (final rich in [false, true]) {
      testWidgets('固定选区重绘及排版变化使用正确矩形 rich=$rich', (tester) async {
        final controller = ElSelectionController();
        addTearDown(controller.dispose);
        final key = GlobalKey();
        final color = Color(0xff3377bb);
        var width = 260.0;
        var fontSize = 14.0;
        var padding = 0.0;
        var alignment = Alignment.topLeft;
        var scale = 1.0;
        var text = 'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu';

        Future<void> mount() async {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: .ltr,
                child: ElView(
                  style: ElStyle(alignment: .topLeft),
                  child: ElSelectionView(
                    controller: controller,
                    child: ElView(
                      key: key,
                      style: ElStyle(
                        width: width,
                        height: 240,
                        fontSize: fontSize,
                        padding: .all(padding),
                        alignment: alignment,
                        onSelection: ElStyle(backgroundColor: color),
                      ),
                      child: rich ? TextSpan(text: text) : text,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        void expectCurrentGeometry() {
          final render = key.currentContext!.findRenderObject()! as ElRenderView;
          final range = selectionParticipantOf(render)!.currentSelectionRange!;
          // 独立即时查询作为几何基准，验证实际绘制没有沿用变化前的选区。
          final rects = selectionParticipantOf(render)!.adjustedSelectionPaintRectsForRange(range);
          expect(rects, isNotEmpty);
          final pattern = paints;
          for (final rect in rects) {
            pattern.rect(rect: rect, color: color);
          }
          expect(render, pattern);
        }

        await mount();
        controller.selectAll();
        await tester.pump();
        expectCurrentGeometry();
        expectCurrentGeometry();
        width = 190;
        await mount();
        expectCurrentGeometry();
        padding = 12;
        alignment = .center;
        await mount();
        expectCurrentGeometry();
        fontSize = 18;
        scale = 1.25;
        await mount();
        expectCurrentGeometry();
        text = 'replacement with different glyphs and line breaks';
        await mount();
        controller.selectAll();
        await tester.pump();
        expectCurrentGeometry();
        expect(controller.text, text);

        controller.clear();
        await tester.pump();
        final render = key.currentContext!.findRenderObject()! as ElRenderView;
        expect(render, isNot(paints..rect(color: color)));
        final gesture = await tester.startGesture(render.localToGlobal(Offset(30, 110)), kind: .mouse);
        await gesture.moveTo(render.localToGlobal(Offset(130, 160)));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(selectionParticipantOf(render)?.currentSelectionRange, isNotNull);
        expect(selectionParticipantOf(render)?.currentSelectionRange, isNot(TextRange(start: 0, end: text.length)));
        expectCurrentGeometry();
      });
    }
  });

  group('换行与省略号', () {
    ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView));

    testWidgets('pure text softWrap:false still gives ellipsis a finite layout width', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 80,
              child: ElView(
                style: ElStyle(fontSize: 14, softWrap: false, textOverflow: TextOverflow.ellipsis),
                child: 'abcdefghijklmnopqrstuvwxyz',
              ),
            ),
          ),
        ),
      );

      final render = renderOf(tester);
      expect((render.content as TextEngine?)?.rawChild, isA<String>());
      expect(((render.content as TextEngine?)?.painterForTest.width), 80);
      expect(((render.content as TextEngine?)?.painterForTest.didExceedMaxLines), isTrue);
    });

    testWidgets('pure text softWrap:false without ellipsis keeps unconstrained single line layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 80,
              child: ElView(
                style: ElStyle(fontSize: 14, softWrap: false, textOverflow: TextOverflow.clip),
                child: 'abcdefghijklmnopqrstuvwxyz',
              ),
            ),
          ),
        ),
      );

      final render = renderOf(tester);
      expect((render.content as TextEngine?)?.rawChild, isA<String>());
      expect((render.content as TextEngine?)!.painterForTest.width, greaterThan(80));
      expect(renderOf(tester).size.width, 80);
    });

    testWidgets('rich text softWrap:false still gives ellipsis a finite layout width', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 80,
              child: ElView(
                style: ElStyle(fontSize: 14, softWrap: false, textOverflow: TextOverflow.ellipsis),
                child: TextSpan(
                  text: 'abcdefghijklmnopqrstuvwxyz',
                  children: <InlineSpan>[TextSpan(text: '0123456789')],
                ),
              ),
            ),
          ),
        ),
      );

      final fc = (renderOf(tester).content as TextEngine?)!;
      expect(fc.painterForTest.width, 80);
      expect(fc.painterForTest.didExceedMaxLines, isTrue);
    });
  });

  group('系统字体变化重排', () {
    Widget shell(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    ElRenderView renderOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    Future<void> sendFontsChange(WidgetTester tester) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.system.name,
        SystemChannels.system.codec.encodeMessage(<String, dynamic>{'type': 'fontsChange'}),
        (_) {},
      );
    }

    testWidgets('纯文本节点：fontsChange 后 painter 重排 + 本节点重 layout', (tester) async {
      const textKey = ValueKey('text');
      await tester.pumpWidget(shell(const ElView(key: textKey, style: ElStyle(fontSize: 16), child: '中文字体懒加载')));
      await tester.pump();

      final text = renderOf(tester, textKey);
      final baselinePainterLayout = (text.content as TextEngine?)!.stringPainterLayoutCountForTest;
      final baselineNodeLayout = text.debugLayoutCount;

      await sendFontsChange(tester);
      await tester.pump();

      expect(
        (text.content as TextEngine?)!.stringPainterLayoutCountForTest,
        greaterThan(baselinePainterLayout),
        reason: '字体表换代后必须重新 shape（否则非英文字形不刷新）',
      );
      expect(text.debugLayoutCount, greaterThan(baselineNodeLayout), reason: '宿主节点应重 layout');
    });

    testWidgets('富文本节点：fontsChange 后 rich painter 重排', (tester) async {
      const paraKey = ValueKey('para');
      await tester.pumpWidget(
        shell(
          const ElView(
            key: paraKey,
            style: ElStyle(width: 300, fontSize: 14),
            child: [
              '前缀 ',
              ElView(
                child: '代码',
                style: ElStyle(fontWeight: FontWeight.w700),
              ),
              ' 后缀',
            ],
          ),
        ),
      );
      await tester.pump();

      final para = renderOf(tester, paraKey);
      final baseline = (para.content as TextEngine?)!.stringPainterLayoutCountForTest;

      await sendFontsChange(tester);
      await tester.pump();

      expect(
        (para.content as TextEngine?)!.stringPainterLayoutCountForTest,
        greaterThan(baseline),
        reason: '富文本同样重新 shape',
      );
    });

    testWidgets('纯盒节点（无文本载荷）：fontsChange 零动静，不陪跑 layout', (tester) async {
      const boxKey = ValueKey('box');
      await tester.pumpWidget(
        shell(
          const ElView(
            key: boxKey,
            style: ElStyle(width: 80, height: 40, backgroundColor: Color(0xFF3366CC)),
          ),
        ),
      );
      await tester.pump();

      final box = renderOf(tester, boxKey);
      expect((box.content as TextEngine?), isNull, reason: '纯盒不实例化文本引擎（懒加载门）');
      final baseline = box.debugLayoutCount;

      await sendFontsChange(tester);
      await tester.pump();

      expect(box.debugLayoutCount, baseline, reason: '未注册监听 → 不重 layout');
      expect((box.content as TextEngine?), isNull, reason: 'fontsChange 不得诱发文本引擎实例化');
    });

    testWidgets('载荷换成 widget 子 / 卸载后：监听移除，fontsChange 不再触发重排', (tester) async {
      const key = ValueKey('swap');
      await tester.pumpWidget(shell(const ElView(key: key, child: '有文本')));
      await tester.pump();

      // 换成纯盒（文本载荷清空）→ 监听应随 setPayload 移除。
      await tester.pumpWidget(shell(const ElView(key: key, style: ElStyle(width: 80, height: 40))));
      await tester.pump();
      final box = renderOf(tester, key);
      final baseline = box.debugLayoutCount;

      await sendFontsChange(tester);
      await tester.pump();
      expect(box.debugLayoutCount, baseline, reason: '载荷清空后监听已移除');

      // 整树卸载后再发一次：不得抛（dispose 已注销监听）。
      await tester.pumpWidget(shell(const SizedBox()));
      await sendFontsChange(tester);
      await tester.pump();
    });
  });

  group('文字溢出裁剪', () {
    const long = 'ElView 对标 CSS，覆盖布局、样式与继承的每一个字段。';

    ElRenderView textHostOf(WidgetTester tester) {
      final host = tester.allRenderObjects.whereType<ElRenderView>().where((r) => (r.content is TextEngine)).first;
      return host;
    }

    Future<TextEngine> pumpOverflow(WidgetTester tester, TextOverflow? overflow, {Object child = long}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 120,
              child: ElView(
                style: ElStyle(fontSize: 14, softWrap: false, maxLines: 1, textOverflow: overflow),
                child: child,
              ),
            ),
          ),
        ),
      );
      return (textHostOf(tester).content as TextEngine?)!;
    }

    group('纯 String 快路径', () {
      testWidgets('clip 溢出时启用裁剪（无 fade shader）', (tester) async {
        final clipper = await pumpOverflow(tester, TextOverflow.clip);
        expect(clipper.overflowNeedsClipping, isTrue, reason: 'painter 无限宽排版超出节点盒必须裁剪');
        expect(clipper.overflowShader, isNull);
      });

      testWidgets('fade 溢出时启用裁剪 + 渐变 shader', (tester) async {
        final clipper = await pumpOverflow(tester, TextOverflow.fade);
        expect(clipper.overflowNeedsClipping, isTrue);
        expect(clipper.overflowShader, isNotNull, reason: 'fade 必须带末端淡出渐变');
      });

      testWidgets('visible 溢出不裁剪', (tester) async {
        final clipper = await pumpOverflow(tester, TextOverflow.visible);
        expect(clipper.overflowNeedsClipping, isFalse, reason: 'CSS overflow: visible 语义就是溢出');
      });

      testWidgets('未声明 overflow 不裁剪（CSS 默认 visible）', (tester) async {
        final clipper = await pumpOverflow(tester, null);
        expect(clipper.overflowNeedsClipping, isFalse, reason: '布局兜底的 ?? clip 不代表视觉裁剪意图，跟裁会回归存量');
      });

      testWidgets('无溢出时 clip 不裁剪', (tester) async {
        final clipper = await pumpOverflow(tester, TextOverflow.clip, child: 'ab');
        expect(clipper.overflowNeedsClipping, isFalse, reason: '内容未超盒不应产生裁剪成本');
      });

      testWidgets('paint 后 canvas 被裁剪到节点盒（clip）', (tester) async {
        await pumpOverflow(tester, TextOverflow.clip);
        final render = textHostOf(tester);
        expect(render, paints..clipRect(rect: Offset.zero & render.size));
      });

      testWidgets('visible 溢出 paint 不产生 clipRect', (tester) async {
        await pumpOverflow(tester, TextOverflow.visible);
        final render = textHostOf(tester);
        expect(render, isNot(paints..clipRect()));
      });
    });

    group('rich-inline 路径', () {
      testWidgets('clip 溢出时启用裁剪', (tester) async {
        final clipper = await pumpOverflow(
          tester,
          TextOverflow.clip,
          child: [
            'ElView 对标 CSS，',
            const ElView(
              child: '覆盖布局、样式与继承的每一个字段。',
              style: ElStyle(color: Color(0xFF3311FF)),
            ),
          ],
        );
        expect(clipper.overflowNeedsClipping, isTrue);
      });

      testWidgets('visible 溢出不裁剪', (tester) async {
        final clipper = await pumpOverflow(
          tester,
          TextOverflow.visible,
          child: [
            'ElView 对标 CSS，',
            const ElView(
              child: '覆盖布局、样式与继承的每一个字段。',
              style: ElStyle(color: Color(0xFF3311FF)),
            ),
          ],
        );
        expect(clipper.overflowNeedsClipping, isFalse);
      });
    });

    group('布局口径不变（softWrap:false 无限宽排版仍生效）', () {
      testWidgets('clip 溢出时节点 size 仍收在约束内', (tester) async {
        await pumpOverflow(tester, TextOverflow.clip);
        final render = textHostOf(tester);
        expect(render.size.width, 120, reason: '裁剪只发生在 paint 期，layout 结果不变');
      });
    });
  });

  group('文字变换与透明度', () {
    ElRenderView renderText(WidgetTester tester) =>
        tester.renderObject(find.byKey(const ValueKey('text-host'))) as ElRenderView;

    bool hitRender(ElRenderView render, Offset localPosition) {
      final result = BoxHitTestResult();
      render.hitTest(result, position: localPosition);
      return result.path.any((entry) => identical(entry.target, render));
    }

    Rect textBounds(ElRenderView render, int length) {
      final rects = (render.content as TextEngine).selectionPaintRectsForRange(TextRange(start: 0, end: length));
      return rects.reduce((value, rect) => value.expandToInclude(rect));
    }

    group('opacity', () {
      testWidgets('opacity == 0 → 拒命中（CSS quirk 偏离）', (tester) async {
        await tester.pumpWidget(
          _app(const ElView(key: ValueKey('text-host'), style: ElStyle(opacity: 0), child: 'hello world')),
        );
        final render = renderText(tester);
        expect(
          hitRender(render, textBounds(render, 'hello world'.length).center),
          isFalse,
          reason: 'opacity:0 应短路 hit-test',
        );
      });

      testWidgets('opacity > 0 仍命中', (tester) async {
        await tester.pumpWidget(
          _app(const ElView(key: ValueKey('text-host'), style: ElStyle(opacity: 0.3), child: 'hello world')),
        );
        final render = renderText(tester);
        expect(hitRender(render, textBounds(render, 'hello world'.length).center), isTrue);
      });

      testWidgets('opacity 变化只触发 markNeedsPaint，不触发 layout', (tester) async {
        Widget build(double op) => _app(
          ElView(
            key: const ValueKey('text-host'),
            style: ElStyle(opacity: op),
            child: 'hello world',
          ),
        );
        await tester.pumpWidget(build(1.0));
        final render = renderText(tester);
        final layoutsBefore = render.debugLayoutCount;

        await tester.pumpWidget(build(0.5));
        // 同 widget 不同 style → 走 cascade fast patch；paint-only 字段不应触发 layout
        expect(render.debugLayoutCount, layoutsBefore, reason: 'opacity 是 paint-only，不应 markNeedsLayout');
      });

      testWidgets('普通半透明盒使用可复用 OpacityLayer，不再落 canvas saveLayer', (tester) async {
        Widget build(double opacity) => _app(
          ElView(
            key: const ValueKey('text-host'),
            style: ElStyle(width: 120, height: 40, opacity: opacity, backgroundColor: const Color(0xff336699)),
            child: 'disabled',
          ),
        );

        await tester.pumpWidget(build(0.5));
        final render = renderText(tester);
        expect(render.isRepaintBoundary, isTrue);
        expect(render.compositedOpacityLayerForTest, isA<OpacityLayer>());
        final layer = render.compositedOpacityLayerForTest!;
        expect(layer.alpha, 128);

        await tester.pumpWidget(build(0.75));
        expect(render.compositedOpacityLayerForTest, same(layer));
        expect(layer.alpha, 191);

        await tester.pumpWidget(build(1));
        expect(render.isRepaintBoundary, isFalse);
        expect(render.compositedOpacityLayerForTest, isNull);
      });
    });

    group('transform', () {
      testWidgets('translate(20, 0) 后命中区域跟随视觉位置', (tester) async {
        await tester.pumpWidget(
          _app(
            const ElView(
              key: ValueKey('text-host'),
              style: ElStyle(transform: .translate(20, 0)),
              child: 'Hi',
            ),
          ),
        );
        final render = renderText(tester);
        final center = textBounds(render, 'Hi'.length).center;
        // 视觉上整段文字向右平移 20 → 原文字起点 0 在 visual 20 处命中，原 visual 0 处空
        expect(hitRender(render, center), isFalse, reason: '平移前位置已无文字');
        expect(hitRender(render, center + const Offset(20, 0)), isTrue, reason: '平移后区域应命中');
      });

      testWidgets('scale(2) topLeft 后命中区域扩展 2 倍', (tester) async {
        await tester.pumpWidget(
          _app(
            const ElView(
              key: ValueKey('text-host'),
              style: ElStyle(transform: .scale(2, 2), transformOrigin: Alignment.topLeft),
              child: 'X',
            ),
          ),
        );
        final render = renderText(tester);
        final size = render.size;
        // base size 之外、但 2× visual 之内的点应命中
        expect(hitRender(render, Offset(size.width * 1.5, size.height * 0.5)), isTrue);
        // 2× visual 之外不命中
        expect(hitRender(render, Offset(size.width * 2 + 5, size.height * 0.5)), isFalse);
      });

      testWidgets('null transform 走快路径：命中等同 base size', (tester) async {
        await tester.pumpWidget(_app(const ElView(key: ValueKey('text-host'), child: 'Hi')));
        final render = renderText(tester);
        expect(hitRender(render, textBounds(render, 'Hi'.length).center), isTrue);
        expect(hitRender(render, Offset(render.size.width + 5, 1)), isFalse);
      });

      testWidgets('退化矩阵 scale(0, 0) 安全不命中', (tester) async {
        await tester.pumpWidget(
          _app(
            const ElView(
              key: ValueKey('text-host'),
              style: ElStyle(transform: .scale(0, 0), transformOrigin: Alignment.topLeft),
              child: 'X',
            ),
          ),
        );
        final render = renderText(tester);
        // invert 失败 → addWithPaintTransform 自动返回 false，不抛错
        expect(hitRender(render, const Offset(1, 1)), isFalse);
      });

      testWidgets('rotate 90° topLeft 后命中区域随旋转翻转', (tester) async {
        await tester.pumpWidget(
          _app(
            ElView(
              key: const ValueKey('text-host'),
              style: ElStyle(transform: .rotate(math.pi / 2), transformOrigin: Alignment.topLeft),
              child: 'A',
            ),
          ),
        );
        final render = renderText(tester);
        final size = render.size;
        // base rect (0,0,w,h) rotate(π/2) topLeft → visual rect (-h, 0, 0, w)
        // 原 base 内点 (1, 1) 经反变换到 (1, -1)（旋转 -π/2）, 不在 base size 内 → false
        expect(hitRender(render, Offset(size.width / 2, size.height / 2)), isFalse);
        // visual 区内点 (-h/2, w/2) 经反变换到 (w/2, h/2) → 在 base 内 → true
        expect(hitRender(render, Offset(-size.height / 2, size.width / 2)), isTrue);
      });
    });

    group('applyPaintTransform', () {
      testWidgets('父 ElView translate 让子直文本 ElView 的 global 坐标含父 transform', (tester) async {
        await tester.pumpWidget(
          _app(
            const ElView(
              key: ValueKey('parent-host'),
              style: ElStyle(width: 100, height: 50, transform: .translate(30, 0), transformOrigin: Alignment.topLeft),
              child: ElView(key: ValueKey('text-host'), child: 'hello'),
            ),
          ),
        );
        final parent = tester.renderObject<ElRenderView>(find.byKey(const ValueKey('parent-host')));
        final child = renderText(tester);

        final parentOrigin = parent.localToGlobal(Offset.zero);
        // 父 translate(30,0) 经父→子 applyPaintTransform 累积到子 origin
        expect(child.localToGlobal(Offset.zero), parentOrigin + const Offset(30, 0));
      });
    });
  });
}
