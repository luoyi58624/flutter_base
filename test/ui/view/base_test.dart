import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// 场景中接受样式的视图标识。
const viewKey = ValueKey('view');

/// 在方向、父约束和 child 都真实参与布局的环境中挂载视图。
Widget viewScene(
  ElStyle style, {
  Widget? child,
  double width = 400,
  double height = 300,
  TextDirection direction = TextDirection.ltr,
  Key key = viewKey,
}) => Directionality(
  textDirection: direction,
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: height),
      child: ElView(key: key, style: style, child: child),
    ),
  ),
);

/// 获取已挂载视图的实际渲染结果，不读取组件内部状态。
RenderBox viewBox(WidgetTester tester, {Key key = viewKey}) =>
    tester.renderObject<RenderBox>(find.byKey(key));

/// 读取包含 margin 的实际占位。
Size viewSize(WidgetTester tester, {Key key = viewKey}) =>
    tester.getSize(find.byKey(key));

/// 记录实际绘制输出，用于验证背景、圆角与裁剪的可见结果。
List<Invocation> recordView(
  WidgetTester tester, {
  Key key = viewKey,
  Offset offset = Offset.zero,
}) {
  final canvas = TestRecordingCanvas();
  viewBox(tester, key: key).paint(TestRecordingPaintingContext(canvas), offset);
  return canvas.invocations.map((entry) => entry.invocation).toList();
}

const _red = Color(0xffff0000), _blue = Color(0xff0000ff);
const _radiusTransition = [
  ElTransition.field(
    ElTransitionField.borderRadius,
    Duration(milliseconds: 100),
    Curves.linear,
  ),
];

ElStyle _radiusStyle(BorderRadiusGeometry? radius, {Color? color = _red}) =>
    ElStyle(
      width: 100,
      height: 60,
      backgroundColor: color,
      borderRadius: radius,
      transitions: _radiusTransition,
    );

void _background(
  WidgetTester tester,
  BorderRadius? radius, {
  Rect rect = const Rect.fromLTWH(0, 0, 100, 60),
  Color color = _red,
}) => expect(
  viewBox(tester),
  radius == null
      ? (paints..rect(rect: rect, color: color))
      : (paints..rrect(rrect: radius.toRRect(rect).scaleRadii(), color: color)),
);

const _overflowKey = ValueKey('clip-overflow-child');
const _overflow = OverflowBox(
  alignment: Alignment.topLeft,
  minWidth: 160,
  maxWidth: 160,
  minHeight: 100,
  maxHeight: 100,
  child: ColoredBox(key: _overflowKey, color: _blue),
);

ElStyle _clipStyle({
  Clip? clip,
  BorderRadiusGeometry? radius = const BorderRadius.all(Radius.circular(30)),
  Color? color = _red,
  List<ElTransition>? transitions,
}) => ElStyle(
  width: 100,
  height: 60,
  backgroundColor: color,
  borderRadius: radius,
  clipBehavior: clip,
  transitions: transitions,
);

Iterable<Invocation> _calls(List<Invocation> calls, Symbol method) =>
    calls.where((call) => call.memberName == method);

bool _hits(WidgetTester tester, Offset position, {Key key = viewKey}) =>
    viewBox(tester, key: key).hitTest(BoxHitTestResult(), position: position);

void _clip(
  WidgetTester tester,
  Clip clip, {
  BorderRadius? radius,
  Rect rect = const Rect.fromLTWH(0, 0, 100, 60),
  Offset offset = Offset.zero,
  Key key = viewKey,
}) {
  final calls = recordView(tester, key: key, offset: offset);
  if (clip == Clip.none) {
    expect(calls.map((call) => call.memberName), isNot(contains(#clipRect)));
    expect(calls.map((call) => call.memberName), isNot(contains(#clipRRect)));
    return;
  }
  final invocation = _calls(
    calls,
    radius == null ? #clipRect : #clipRRect,
  ).first;
  expect(
    invocation.positionalArguments.first,
    radius == null
        ? rect.shift(offset)
        : radius.toRRect(rect).scaleRadii().shift(offset),
  );
  expect(invocation.namedArguments[#doAntiAlias], clip != Clip.hardEdge);
  if (clip == Clip.antiAliasWithSaveLayer) {
    expect(
      _calls(calls, #saveLayer).first.positionalArguments.first,
      rect.shift(offset),
    );
  }
}

Color _color(RenderBox box) {
  Color? result;
  expect(
    box,
    paints..something((method, arguments) {
      if (method != #drawRect) return false;
      result = (arguments[1] as Paint).color;
      return true;
    }),
  );
  return result!;
}

void main() {
  group('基础盒模型与样式声明', () {
    testWidgets('空样式使用自然尺寸，复制、合并和显式清空后布局与背景正确', (tester) async {
      const child = SizedBox(width: 80, height: 40);
      const style = ElStyle(width: 120, height: 60, backgroundColor: _red);
      await tester.pumpWidget(viewScene(const ElStyle(), child: child));
      expect(viewSize(tester), const Size(80, 40));
      expect(viewBox(tester), paintsNothing);
      await tester.pumpWidget(viewScene(style, child: child));
      expect(viewSize(tester), const Size(120, 60));
      expect(_color(viewBox(tester)), _red);
      await tester.pumpWidget(
        viewScene(
          style.merge(const ElStyle(height: 90, backgroundColor: _blue)),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(120, 90));
      expect(_color(viewBox(tester)), _blue);
      await tester.pumpWidget(
        viewScene(
          style.copyWith(width: null, height: null, backgroundColor: null),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(80, 40));
      expect(viewBox(tester), paintsNothing);
      await tester.pumpWidget(viewScene(const ElStyle()));
      expect(viewSize(tester), Size.zero);
    });

    testWidgets('尺寸包含 padding，背景覆盖视觉盒，margin 只参与占位', (tester) async {
      const childKey = ValueKey('basic-child');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 120,
            height: 80,
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.all(5),
            backgroundColor: _red,
          ),
          child: const SizedBox(key: childKey, width: 20, height: 15),
        ),
      );
      expect(viewSize(tester), const Size(130, 90));
      expect(tester.getSize(find.byKey(childKey)), const Size(20, 15));
      expect(
        tester.getTopLeft(find.byKey(childKey)) -
            tester.getTopLeft(find.byKey(viewKey)),
        const Offset(15, 15),
      );
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(5, 5, 120, 80), color: _red),
      );
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      expect(_hits(tester, const Offset(6, 6)), isTrue);
    });

    testWidgets('方向性 padding 在 RTL 中影响自然尺寸与内容位置', (tester) async {
      const childKey = ValueKey('directional-child');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(padding: EdgeInsetsDirectional.fromSTEB(10, 2, 30, 4)),
          direction: TextDirection.rtl,
          child: const SizedBox(key: childKey, width: 20, height: 15),
        ),
      );
      expect(viewSize(tester), const Size(60, 21));
      expect(
        tester.getTopLeft(find.byKey(childKey)) -
            tester.getTopLeft(find.byKey(viewKey)),
        const Offset(30, 2),
      );
    });

    testWidgets('双轴 factor 乘包含 padding 的自然盒，margin、背景与 child 位置保持正确', (
      tester,
    ) async {
      const childKey = ValueKey('factored-child');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            widthFactor: 1.5,
            heightFactor: 2,
            padding: EdgeInsets.fromLTRB(5, 7, 15, 13),
            margin: EdgeInsets.fromLTRB(4, 3, 6, 9),
            backgroundColor: _red,
          ),
          child: const SizedBox(key: childKey, width: 80, height: 40),
        ),
      );
      expect(viewSize(tester), const Size(160, 132));
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      expect(
        tester.getTopLeft(find.byKey(childKey)) -
            tester.getTopLeft(find.byKey(viewKey)),
        const Offset(9, 10),
      );
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(4, 3, 150, 120), color: _red),
      );
    });

    testWidgets('单轴、零和大于一的 factor 只改变占位，不缩放或自动裁剪 child', (tester) async {
      const childKey = ValueKey('factor-overflow-child');
      for (final (widthFactor, heightFactor, size)
          in <(double?, double?, Size)>[
            (0.5, null, const Size(40, 40)),
            (null, 2, const Size(80, 80)),
            (0, 0, Size.zero),
            (2, 1.5, const Size(160, 60)),
          ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(widthFactor: widthFactor, heightFactor: heightFactor),
            child: const ColoredBox(
              key: childKey,
              color: _blue,
              child: SizedBox(width: 80, height: 40),
            ),
          ),
        );
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
        expect(
          viewBox(tester),
          paints..rect(rect: const Rect.fromLTWH(0, 0, 80, 40), color: _blue),
        );
        final methods = recordView(tester).map((call) => call.memberName);
        expect(methods, isNot(contains(#clipRect)));
        expect(methods, isNot(contains(#clipRRect)));
      }
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            widthFactor: 0.5,
            heightFactor: 0.5,
            clipBehavior: Clip.hardEdge,
          ),
          child: const ColoredBox(
            key: childKey,
            color: _blue,
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      );
      expect(viewSize(tester), const Size(40, 20));
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      _clip(tester, Clip.hardEdge, rect: const Rect.fromLTWH(0, 0, 40, 20));
    });

    testWidgets('显式宽高优先于对应 factor，另一条 auto 轴仍使用 factor', (tester) async {
      const childKey = ValueKey('factor-explicit-child');
      for (final (style, size) in [
        (
          const ElStyle(width: 120, widthFactor: 0.5, heightFactor: 2),
          const Size(120, 80),
        ),
        (
          const ElStyle(height: 90, widthFactor: 0.5, heightFactor: 0),
          const Size(40, 90),
        ),
        (
          const ElStyle(
            width: 120,
            height: 90,
            widthFactor: 0,
            heightFactor: 0,
          ),
          const Size(120, 90),
        ),
      ]) {
        await tester.pumpWidget(
          viewScene(
            style,
            child: const SizedBox(key: childKey, width: 80, height: 40),
          ),
        );
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      }
    });

    testWidgets('百分比有参照时忽略 factor，无参照时按自然盒应用 factor', (tester) async {
      const style = ElStyle(
        width: '50%',
        height: '25%',
        widthFactor: 2,
        heightFactor: 0.5,
        margin: EdgeInsets.all(10),
      );
      const child = SizedBox(width: 80, height: 40);
      await tester.pumpWidget(viewScene(style, child: child));
      expect(viewSize(tester), const Size(210, 90));
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: UnconstrainedBox(
              child: ElView(key: viewKey, style: style, child: child),
            ),
          ),
        ),
      );
      expect(viewSize(tester), const Size(180, 40));
    });

    testWidgets('父最小、最大和紧约束最终限制 factor，child 沿用原约束', (tester) async {
      const childKey = ValueKey('factor-parent-child');
      Widget host(BoxConstraints constraints, double factor) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ConstrainedBox(
            constraints: constraints,
            child: ElView(
              key: viewKey,
              style: ElStyle(widthFactor: factor, heightFactor: factor),
              child: const SizedBox(key: childKey, width: 80, height: 40),
            ),
          ),
        ),
      );
      const range = BoxConstraints(
        minWidth: 100,
        maxWidth: 160,
        minHeight: 60,
        maxHeight: 90,
      );
      for (final (factor, size) in [
        (0.5, const Size(100, 60)),
        (2.0, const Size(160, 90)),
      ]) {
        await tester.pumpWidget(host(range, factor));
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(100, 60));
      }
      for (final factor in [0.5, 2.0]) {
        await tester.pumpWidget(
          host(const BoxConstraints.tightFor(width: 100, height: 80), factor),
        );
        expect(viewSize(tester), const Size(100, 80));
        expect(tester.getSize(find.byKey(childKey)), const Size(100, 80));
      }
    });

    testWidgets('无 child 时 factor 作用于 padding，自然尺寸为零时仍为零', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            widthFactor: 2,
            heightFactor: 0.5,
            padding: EdgeInsets.fromLTRB(4, 5, 6, 7),
            margin: EdgeInsets.all(3),
          ),
        ),
      );
      expect(viewSize(tester), const Size(26, 12));
      await tester.pumpWidget(
        viewScene(const ElStyle(widthFactor: 2, heightFactor: 0.5)),
      );
      expect(viewSize(tester), Size.zero);
    });

    testWidgets('factor 复制、合并和显式清空后实际占位同步变化', (tester) async {
      final int widthFactor = 2, heightFactor = 3;
      final style = ElStyle(
        widthFactor: widthFactor,
        heightFactor: heightFactor,
      );
      const child = SizedBox(width: 40, height: 20);
      await tester.pumpWidget(viewScene(style, child: child));
      expect(viewSize(tester), const Size(80, 60));
      await tester.pumpWidget(
        viewScene(
          const ElStyle().copyWith(widthFactor: 2, heightFactor: 3),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(80, 60));
      await tester.pumpWidget(
        viewScene(
          style.merge(const ElStyle(widthFactor: 0.5, heightFactor: 2)),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(20, 40));
      await tester.pumpWidget(
        viewScene(style.merge(const ElStyle()), child: child),
      );
      expect(viewSize(tester), const Size(80, 60));
      await tester.pumpWidget(
        viewScene(
          style.copyWith(widthFactor: null, heightFactor: null),
          child: child,
        ),
      );
      expect(viewSize(tester), const Size(40, 20));
    });

    testWidgets('父约束限制显式尺寸，auto 保留紧约束', (tester) async {
      const childKey = ValueKey('constrained-child');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 1000, height: 1000),
          child: const SizedBox(key: childKey, width: 20, height: 15),
        ),
      );
      expect(viewSize(tester), const Size(400, 300));
      expect(tester.getSize(find.byKey(childKey)), const Size(20, 15));
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 100,
              height: 80,
              child: ElView(
                key: viewKey,
                child: SizedBox(key: childKey, width: 20, height: 15),
              ),
            ),
          ),
        ),
      );
      expect(viewSize(tester), const Size(100, 80));
      expect(tester.getSize(find.byKey(childKey)), const Size(100, 80));
    });

    for (final horizontal in [true, false]) {
      testWidgets('${horizontal ? "宽度" : "高度"}的 auto、像素、百分比、零和无效声明符合父约束', (
        tester,
      ) async {
        for (final (value, width, height) in <(Object?, double, double)>[
          (null, 80, 40),
          ('invalid', 80, 40),
          (double.infinity, 80, 40),
          (-20, 0, 0),
          (0, 0, 0),
          ('-25%', 0, 0),
          (120, 120, 120),
          ('120', 120, 120),
          ('25%', 100, 75),
          (' 50% ', 200, 150),
          ('150%', 400, 300),
        ]) {
          await tester.pumpWidget(
            viewScene(
              ElStyle(
                width: horizontal ? value : 120,
                height: horizontal ? 60 : value,
              ),
              child: const SizedBox(width: 80, height: 40),
            ),
          );
          expect(
            viewSize(tester),
            horizontal ? Size(width, 60) : Size(120, height),
          );
        }
      });
    }

    testWidgets('百分比基于扣除 margin 的父约束，嵌套再使用扣除 padding 的内容区域', (tester) async {
      const nestedKey = ValueKey('nested-percent');
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: '50%',
            height: '50%',
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.all(10),
          ),
          child: const ElView(
            key: nestedKey,
            style: ElStyle(width: '50%', height: '50%'),
          ),
        ),
      );
      expect(viewSize(tester), const Size(210, 160));
      expect(tester.getSize(find.byKey(nestedKey)), const Size(85, 60));
    });

    for (final vertical in [false, true]) {
      testWidgets(
        '${vertical ? "IntrinsicHeight" : "IntrinsicWidth"} 场景包含 factor 与内外边距',
        (tester) async {
          const child = ElView(
            key: viewKey,
            style: ElStyle(
              widthFactor: 1.5,
              heightFactor: 2,
              padding: EdgeInsets.all(4),
              margin: EdgeInsets.all(2),
            ),
            child: SizedBox(width: 32, height: 18),
          );
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: vertical
                    ? const IntrinsicHeight(child: child)
                    : const IntrinsicWidth(child: child),
              ),
            ),
          );
          expect(viewSize(tester), const Size(64, 56));
        },
      );
    }

    testWidgets('真实 Row 在 factor 改变占位后仍按 child 和内外边距对齐基线', (tester) async {
      const textKey = ValueKey('baseline-child');
      const referenceKey = ValueKey('baseline-reference');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  ElView(
                    key: viewKey,
                    style: ElStyle(
                      widthFactor: 0.5,
                      heightFactor: 2,
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.all(3),
                    ),
                    child: Text('a', key: textKey),
                  ),
                  Text('a', key: referenceKey),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(textKey)).dy,
        tester.getTopLeft(find.byKey(referenceKey)).dy,
      );
      final child = tester.getSize(find.byKey(textKey));
      expect(
        viewSize(tester),
        Size((child.width + 16) * 0.5 + 6, (child.height + 16) * 2 + 6),
      );
    });

    testWidgets('背景声明为 null、透明、半透明和不透明时绘制结果正确', (tester) async {
      for (final color in <Color?>[
        null,
        const Color(0x000000ff),
        const Color(0x80ff0000),
        _blue,
      ]) {
        await tester.pumpWidget(
          viewScene(ElStyle(width: 40, height: 30, backgroundColor: color)),
        );
        expect(viewSize(tester), const Size(40, 30));
        if (color == null) {
          expect(viewBox(tester), paintsNothing);
        } else {
          expect(
            viewBox(tester),
            paints..rect(rect: const Rect.fromLTWH(0, 0, 40, 30), color: color),
          );
        }
      }
    });

    testWidgets('首次挂载即显示声明值，过渡配置不改变初始画面', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            borderRadius: BorderRadius.all(Radius.circular(12)),
            transitions: [ElTransition.all()],
          ),
        ),
      );
      expect(viewSize(tester), const Size(100, 60));
      _background(tester, BorderRadius.circular(12));
    });
  });

  group('祖先参照与重挂', () {
    testWidgets('无界 Column 中最近祖先在 auto 与确定尺寸间切换百分比参照', (tester) async {
      const middleKey = ValueKey('reference-middle');
      const percentKey = ValueKey('reference-percent');
      const descendant = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElView(
            key: percentKey,
            style: ElStyle(width: 10, height: '50%'),
          ),
        ],
      );
      Widget host(double? middleHeight) => viewScene(
        const ElStyle(width: 200, height: 300, padding: EdgeInsets.all(10)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElView(
              key: middleKey,
              style: ElStyle(
                height: middleHeight,
                padding: const EdgeInsets.all(5),
              ),
              child: descendant,
            ),
          ],
        ),
      );
      await tester.pumpWidget(host(null));
      expect(tester.getSize(find.byKey(percentKey)).height, 140);
      expect(tester.getSize(find.byKey(middleKey)).height, 150);
      await tester.pumpWidget(host(160));
      expect(tester.getSize(find.byKey(percentKey)).height, 75);
      expect(tester.getSize(find.byKey(middleKey)).height, 160);
      await tester.pumpWidget(host(null));
      expect(tester.getSize(find.byKey(percentKey)).height, 140);
      expect(tester.getSize(find.byKey(middleKey)).height, 150);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GlobalKey 重挂后百分比跟随新父尺寸，旧父变化不影响当前画面', (tester) async {
      final movedKey = GlobalKey();
      final moved = ElView(
        key: movedKey,
        style: const ElStyle(width: 10, height: '50%'),
        child: const SizedBox(width: 10, height: 1000),
      );
      Widget host({
        required bool right,
        double leftHeight = 200,
        double rightHeight = 300,
      }) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElView(
                style: ElStyle(width: 160, height: leftHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [if (!right) moved],
                ),
              ),
              ElView(
                style: ElStyle(width: 160, height: rightHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [if (right) moved],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(host(right: false));
      expect(tester.getSize(find.byKey(movedKey)).height, 100);
      final left = tester.getTopLeft(find.byKey(movedKey));
      await tester.pumpWidget(host(right: true));
      expect(tester.getSize(find.byKey(movedKey)).height, 150);
      final right = tester.getTopLeft(find.byKey(movedKey));
      expect(right - left, const Offset(160, 0));
      await tester.pumpWidget(host(right: true, leftHeight: 240));
      expect(tester.getSize(find.byKey(movedKey)).height, 150);
      expect(tester.getTopLeft(find.byKey(movedKey)), right);
      await tester.pumpWidget(
        host(right: true, leftHeight: 240, rightHeight: 360),
      );
      expect(tester.getSize(find.byKey(movedKey)).height, 180);
      expect(tester.takeException(), isNull);
    });
  });

  group('圆角的实际画面与命中', () {
    testWidgets('样式复制、合并和清空后实际背景同步变化', (tester) async {
      const base = ElStyle(width: 100, height: 60, backgroundColor: _red);
      final rounded = base.copyWith(borderRadius: BorderRadius.circular(12));
      await tester.pumpWidget(viewScene(rounded));
      _background(tester, BorderRadius.circular(12));
      await tester.pumpWidget(
        viewScene(
          base.merge(
            const ElStyle(
              backgroundColor: _blue,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
            ),
          ),
        ),
      );
      _background(
        tester,
        const BorderRadius.only(topLeft: Radius.circular(20)),
        color: _blue,
      );
      await tester.pumpWidget(viewScene(rounded.copyWith(borderRadius: null)));
      _background(tester, null);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
    });

    testWidgets('无背景时圆角不产生可见内容，零与退化圆角显示矩形', (tester) async {
      await tester.pumpWidget(
        viewScene(_radiusStyle(BorderRadius.circular(20), color: null)),
      );
      expect(viewBox(tester), paintsNothing);
      expect(_hits(tester, const Offset(50, 30)), isFalse);
      for (final radius in [
        BorderRadius.zero,
        const BorderRadius.all(Radius.elliptical(0, 12)),
        const BorderRadius.all(Radius.elliptical(12, 0)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: 100,
              height: 60,
              backgroundColor: _red,
              borderRadius: radius,
            ),
          ),
        );
        _background(tester, null);
        expect(_hits(tester, const Offset(1, 1)), isTrue);
      }
    });

    testWidgets('独立椭圆角、padding、margin 和 child 位置保持各自几何', (tester) async {
      const childKey = ValueKey('radius-child');
      const radius = BorderRadius.only(
        topLeft: Radius.elliptical(20, 30),
        topRight: Radius.circular(8),
        bottomLeft: Radius.elliptical(12, 7),
        bottomRight: Radius.circular(3),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            padding: EdgeInsets.all(5),
            margin: EdgeInsets.fromLTRB(3, 7, 11, 13),
            borderRadius: radius,
          ),
          child: const SizedBox(key: childKey, width: 30, height: 20),
        ),
      );
      expect(viewSize(tester), const Size(114, 80));
      _background(tester, radius, rect: const Rect.fromLTWH(3, 7, 100, 60));
      expect(
        tester.getTopLeft(find.byKey(childKey)) -
            viewBox(tester).localToGlobal(Offset.zero),
        const Offset(8, 12),
      );
      expect(tester.getSize(find.byKey(childKey)), const Size(30, 20));
      expect(_hits(tester, const Offset(4, 8)), isFalse);
      expect(_hits(tester, const Offset(50, 30)), isTrue);
      expect(_hits(tester, const Offset(1, 30)), isFalse);
    });

    testWidgets('物理、方向性和混合圆角在 LTR 与 RTL 中绘制正确', (tester) async {
      const physical = BorderRadius.only(topLeft: Radius.elliptical(3, 5));
      const directional = BorderRadiusDirectional.only(
        topStart: Radius.elliptical(14, 20),
        bottomEnd: Radius.elliptical(7, 11),
      );
      for (final radius in [physical, directional, physical.add(directional)]) {
        for (final direction in TextDirection.values) {
          await tester.pumpWidget(
            viewScene(
              ElStyle(
                width: 100,
                height: 60,
                backgroundColor: _red,
                margin: const EdgeInsets.fromLTRB(3, 5, 7, 11),
                borderRadius: radius,
              ),
              direction: direction,
            ),
          );
          _background(
            tester,
            radius.resolve(direction),
            rect: const Rect.fromLTWH(3, 5, 100, 60),
          );
          expect(viewSize(tester), const Size(110, 76));
        }
      }
    });

    testWidgets('超大椭圆角随显式尺寸和 auto 内容变化适配，命中与画面一致', (tester) async {
      const radius = BorderRadius.only(
        topLeft: Radius.elliptical(200, 100),
        topRight: Radius.elliptical(100, 70),
        bottomLeft: Radius.elliptical(30, 90),
        bottomRight: Radius.elliptical(80, 30),
      );
      for (final size in [const Size(100, 60), const Size(200, 100)]) {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: size.width,
              height: size.height,
              backgroundColor: _red,
              margin: const EdgeInsets.all(10),
              borderRadius: radius,
            ),
          ),
        );
        final rect = Rect.fromLTWH(10, 10, size.width, size.height);
        _background(tester, radius, rect: rect);
        final shape = radius.toRRect(rect).scaleRadii();
        for (final point in [
          const Offset(11, 11),
          rect.center,
          Offset(rect.right - 1, rect.bottom - 1),
          Offset(5, rect.center.dy),
        ]) {
          expect(_hits(tester, point), shape.contains(point), reason: '$point');
        }
      }
      for (final size in [const Size(40, 30), const Size(160, 70)]) {
        await tester.pumpWidget(
          viewScene(
            const ElStyle(backgroundColor: _red, borderRadius: radius),
            child: SizedBox(width: size.width, height: size.height),
          ),
        );
        expect(viewSize(tester), size);
        _background(tester, radius, rect: Offset.zero & size);
      }
    });

    testWidgets('只设置圆角时 child 仍可绘制和命中背景角落', (tester) async {
      await tester.pumpWidget(
        viewScene(
          _radiusStyle(BorderRadius.circular(30)),
          child: const OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 160,
            maxWidth: 160,
            minHeight: 100,
            maxHeight: 100,
            child: ColoredBox(color: _blue),
          ),
        ),
      );
      _background(tester, BorderRadius.circular(30));
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(0, 0, 160, 100), color: _blue),
      );
      expect(_hits(tester, const Offset(1, 1)), isTrue);
      expect(
        recordView(tester).map((call) => call.memberName),
        isNot(contains(#clipRRect)),
      );
    });
  });

  group('裁剪与内容布局', () {
    testWidgets('all 过渡下裁剪模式切换和清空仍立即生效', (tester) async {
      const transitions = [
        ElTransition.all(Duration(milliseconds: 100), Curves.linear),
      ];
      await tester.pumpWidget(
        viewScene(_clipStyle(transitions: transitions), child: _overflow),
      );
      for (final clip in [
        Clip.hardEdge,
        Clip.antiAlias,
        Clip.antiAliasWithSaveLayer,
        Clip.none,
        Clip.hardEdge,
        null,
      ]) {
        await tester.pumpWidget(
          viewScene(
            _clipStyle(clip: clip, transitions: transitions),
            child: _overflow,
          ),
        );
        _clip(tester, clip ?? Clip.none, radius: BorderRadius.circular(30));
        expect(
          _hits(tester, const Offset(1, 1)),
          clip == null || clip == Clip.none,
        );
        expect(viewSize(tester), const Size(100, 60));
      }
    });
    testWidgets('复制、合并和清空裁剪声明后用户命中与画面同步变化', (tester) async {
      final base = _clipStyle(clip: Clip.hardEdge);
      await tester.pumpWidget(viewScene(base, child: _overflow));
      _clip(tester, Clip.hardEdge, radius: BorderRadius.circular(30));
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      await tester.pumpWidget(
        viewScene(base.copyWith(clipBehavior: Clip.none), child: _overflow),
      );
      _clip(tester, Clip.none);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
      await tester.pumpWidget(
        viewScene(
          base.merge(const ElStyle(clipBehavior: Clip.antiAliasWithSaveLayer)),
          child: _overflow,
        ),
      );
      _clip(
        tester,
        Clip.antiAliasWithSaveLayer,
        radius: BorderRadius.circular(30),
      );
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      await tester.pumpWidget(
        viewScene(base.copyWith(clipBehavior: null), child: _overflow),
      );
      _clip(tester, Clip.none);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
    });

    testWidgets('默认和显式 none 允许 child 绘制溢出并命中背景角落', (tester) async {
      for (final clip in [null, Clip.none]) {
        await tester.pumpWidget(
          viewScene(_clipStyle(clip: clip), child: _overflow),
        );
        _clip(tester, Clip.none);
        expect(
          viewBox(tester),
          paints..rect(rect: const Rect.fromLTWH(0, 0, 160, 100), color: _blue),
        );
        expect(_hits(tester, const Offset(1, 1)), isTrue);
        expect(tester.getSize(find.byKey(_overflowKey)), const Size(160, 100));
      }
    });

    for (final clip in [
      Clip.hardEdge,
      Clip.antiAlias,
      Clip.antiAliasWithSaveLayer,
    ]) {
      testWidgets('$clip 将背景和溢出 child 裁剪到不含 margin 的矩形', (tester) async {
        await tester.pumpWidget(
          viewScene(
            ElStyle(
              width: 100,
              height: 60,
              backgroundColor: _red,
              margin: const EdgeInsets.fromLTRB(7, 11, 13, 17),
              padding: const EdgeInsets.all(4),
              clipBehavior: clip,
            ),
            child: _overflow,
          ),
        );
        _clip(
          tester,
          clip,
          rect: const Rect.fromLTWH(7, 11, 100, 60),
          offset: const Offset(23, 31),
        );
        expect(viewSize(tester), const Size(120, 88));
        expect(
          tester.getTopLeft(find.byKey(_overflowKey)) -
              viewBox(tester).localToGlobal(Offset.zero),
          const Offset(11, 15),
        );
        final calls = recordView(tester);
        expect(
          calls.map((call) => call.memberName),
          containsAllInOrder([#clipRect, #drawRect, #drawRect, #restore]),
        );
        expect(
          viewBox(tester),
          paints..rect(rect: const Rect.fromLTWH(7, 11, 100, 60), color: _red),
        );
        expect(_hits(tester, const Offset(1, 30)), isFalse);
        expect(_hits(tester, const Offset(50, 30)), isTrue);
      });

      testWidgets('$clip 按超大椭圆角的最终形状裁剪并限制用户命中', (tester) async {
        const radius = BorderRadius.only(
          topLeft: Radius.elliptical(200, 100),
          topRight: Radius.elliptical(100, 70),
          bottomLeft: Radius.elliptical(30, 90),
          bottomRight: Radius.elliptical(80, 30),
        );
        await tester.pumpWidget(
          viewScene(
            _clipStyle(clip: clip, radius: radius),
            child: _overflow,
          ),
        );
        _clip(tester, clip, radius: radius);
        final shape = radius
            .toRRect(const Rect.fromLTWH(0, 0, 100, 60))
            .scaleRadii();
        for (final point in [
          const Offset(1, 1),
          const Offset(50, 30),
          const Offset(99, 59),
        ]) {
          expect(_hits(tester, point), shape.contains(point), reason: '$point');
        }
        expect(
          recordView(tester).map((call) => call.memberName),
          containsAllInOrder([#clipRRect, #drawRect, #drawRect, #restore]),
        );
      });
    }

    testWidgets('无背景时仍裁剪溢出 child，圆角外和 margin 内不响应命中', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            margin: EdgeInsets.all(10),
            borderRadius: BorderRadius.all(Radius.circular(30)),
            clipBehavior: Clip.hardEdge,
          ),
          child: _overflow,
        ),
      );
      _clip(
        tester,
        Clip.hardEdge,
        radius: BorderRadius.circular(30),
        rect: const Rect.fromLTWH(10, 10, 100, 60),
      );
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(10, 10, 160, 100), color: _blue),
      );
      expect(_hits(tester, const Offset(11, 11)), isFalse);
      expect(_hits(tester, const Offset(5, 40)), isFalse);
      expect(_hits(tester, const Offset(60, 40)), isTrue);
    });

    testWidgets('auto 内容尺寸变化后裁剪适配实际占位', (tester) async {
      const radius = BorderRadius.all(Radius.elliptical(120, 80));
      for (final size in [const Size(40, 30), const Size(160, 70)]) {
        await tester.pumpWidget(
          viewScene(
            const ElStyle(
              backgroundColor: _red,
              borderRadius: radius,
              clipBehavior: Clip.hardEdge,
            ),
            child: SizedBox(width: size.width, height: size.height),
          ),
        );
        expect(viewSize(tester), size);
        _clip(tester, Clip.hardEdge, radius: radius, rect: Offset.zero & size);
        expect(_hits(tester, size.center(Offset.zero)), isTrue);
        expect(_hits(tester, const Offset(1, 1)), isFalse);
      }
    });

    testWidgets('父约束与百分比嵌套尺寸变化后两级裁剪和 child 位置同步', (tester) async {
      const nestedKey = ValueKey('clip-percent-child');
      const style = ElStyle(
        width: '50%',
        height: '50%',
        backgroundColor: _red,
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.all(8),
        borderRadius: BorderRadius.all(Radius.circular(30)),
        clipBehavior: Clip.hardEdge,
      );
      const child = ElView(
        key: nestedKey,
        style: ElStyle(
          width: '50%',
          height: '50%',
          backgroundColor: _blue,
          borderRadius: BorderRadius.all(Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
        ),
      );
      for (final (width, height, outer, inner) in [
        (400.0, 300.0, const Size(192, 142), const Size(86, 61)),
        (600.0, 400.0, const Size(292, 192), const Size(136, 86)),
      ]) {
        await tester.pumpWidget(
          viewScene(style, child: child, width: width, height: height),
        );
        expect(viewSize(tester), Size(outer.width + 16, outer.height + 16));
        expect(viewSize(tester, key: nestedKey), inner);
        expect(
          viewBox(tester, key: nestedKey).localToGlobal(Offset.zero) -
              viewBox(tester).localToGlobal(Offset.zero),
          const Offset(18, 18),
        );
        _clip(
          tester,
          Clip.hardEdge,
          radius: BorderRadius.circular(30),
          rect: Rect.fromLTWH(8, 8, outer.width, outer.height),
        );
        _clip(
          tester,
          Clip.antiAlias,
          radius: BorderRadius.circular(20),
          rect: Offset.zero & inner,
          key: nestedKey,
        );
        expect(_hits(tester, const Offset(1, 1), key: nestedKey), isFalse);
        expect(
          _hits(tester, inner.center(Offset.zero), key: nestedKey),
          isTrue,
        );
      }
    });

    testWidgets('带 RepaintBoundary 的真实子树在启用、切换、移除和重挂后正常绘制命中', (tester) async {
      const child = RepaintBoundary(child: _overflow);
      for (final (clip, radius) in [
        (Clip.antiAliasWithSaveLayer, BorderRadius.circular(30)),
        (Clip.hardEdge, BorderRadius.circular(12)),
        (Clip.antiAlias, null),
        (Clip.none, BorderRadius.circular(30)),
        (Clip.antiAliasWithSaveLayer, BorderRadius.circular(30)),
      ]) {
        await tester.pumpWidget(
          viewScene(
            _clipStyle(clip: clip, radius: radius),
            child: child,
          ),
        );
        _clip(tester, clip, radius: radius);
        expect(
          _hits(tester, const Offset(1, 1)),
          clip == Clip.none || radius == null,
        );
        expect(_hits(tester, const Offset(50, 30)), isTrue);
        final childPaint = _calls(recordView(tester), #drawRect).firstWhere(
          (call) => (call.positionalArguments[1] as Paint).color == _blue,
        );
        expect(
          childPaint.positionalArguments.first,
          const Rect.fromLTWH(0, 0, 160, 100),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        viewScene(_clipStyle(clip: Clip.hardEdge), child: child),
      );
      _clip(tester, Clip.hardEdge, radius: BorderRadius.circular(30));
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      expect(_hits(tester, const Offset(50, 30)), isTrue);
    });
  });
}
