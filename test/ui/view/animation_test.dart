import 'dart:ui' show ColorSpace, ImageByteFormat, PictureRecorder;

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
const _linear = [ElTransition.all(Duration(milliseconds: 100), Curves.linear)];
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

const _widthAndPadding = [
  ElTransition.field(
    ElTransitionField.width,
    Duration(milliseconds: 100),
    Curves.linear,
  ),
  ElTransition.field(
    ElTransitionField.padding,
    Duration(milliseconds: 200),
    Curves.linear,
  ),
];
const _widthAndHeight = [
  ElTransition.field(
    ElTransitionField.width,
    Duration(milliseconds: 100),
    Curves.linear,
  ),
  ElTransition.field(
    ElTransitionField.height,
    Duration(milliseconds: 200),
    Curves.linear,
  ),
];

Future<void> _advanceTo99(WidgetTester tester, {required bool dense}) async {
  if (dense) {
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pump(const Duration(milliseconds: 9));
  } else {
    await tester.pump(const Duration(milliseconds: 99));
  }
}

Offset _childOffset(WidgetTester tester, Key key) =>
    tester.getTopLeft(find.byKey(key)) - tester.getTopLeft(find.byKey(viewKey));

class _NegativeCurve extends Curve {
  const _NegativeCurve();

  @override
  double transformInternal(double t) => -t;
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

Future<void> _advance(WidgetTester tester, int ms) =>
    tester.pump(Duration(milliseconds: ms));

/// 在真实画布上采样当前视图，验证边框覆盖范围和最终可见颜色。
Future<List<Color>> _borderPixels(
  WidgetTester tester,
  List<Offset> positions, {
  Offset offset = const Offset(32, 32),
}) async => (await tester.runAsync(() async {
  const imageWidth = 600;
  final recorder = PictureRecorder();
  viewBox(tester).paint(TestRecordingPaintingContext(Canvas(recorder)), offset);
  final picture = recorder.endRecording();
  final image = await picture.toImage(imageWidth, 400);
  final data = (await image.toByteData(
    format: ImageByteFormat.rawStraightRgba,
  ))!;
  final bytes = data.buffer.asUint8List();
  final colors = positions.map((position) {
    final point = position + offset;
    final index = (point.dy.floor() * imageWidth + point.dx.floor()) * 4;
    return Color.fromARGB(
      bytes[index + 3],
      bytes[index],
      bytes[index + 1],
      bytes[index + 2],
    );
  }).toList();
  image.dispose();
  picture.dispose();
  return colors;
}))!;

void _pixel(Color actual, Color expected) {
  expect(actual.a, closeTo(expected.a, 2 / 255));
  if (expected.a == 0) return;
  expect(actual.r, closeTo(expected.r, 2 / 255));
  expect(actual.g, closeTo(expected.g, 2 / 255));
  expect(actual.b, closeTo(expected.b, 2 / 255));
}

ElStyle _borderStyle(
  BoxBorder? border, {
  List<ElTransition>? transitions = _linear,
}) => ElStyle(width: 100, height: 60, border: border, transitions: transitions);

const _outlineTransition = [
  ElTransition.field(
    ElTransitionField.outline,
    Duration(milliseconds: 100),
    Curves.linear,
  ),
];

ElStyle _outlineStyle(
  ElOutline? outline, {
  List<ElTransition>? transitions = _outlineTransition,
}) =>
    ElStyle(width: 100, height: 60, outline: outline, transitions: transitions);

void main() {
  group('样式过渡与颜色中间值', () {
    for (final fadeIn in [false, true]) {
      testWidgets('颜色曲线过冲时中间帧保持有效透明度：淡入=$fadeIn', (tester) async {
        ElStyle style(Color? color) => ElStyle(
          width: 40,
          height: 30,
          backgroundColor: color,
          transitions: const [
            ElTransition.all(Duration(milliseconds: 100), Curves.easeOutBack),
          ],
        );
        await tester.pumpWidget(viewScene(style(fadeIn ? null : _red)));
        await tester.pumpWidget(viewScene(style(fadeIn ? _red : null)));
        await tester.pump(const Duration(milliseconds: 60));
        expect(_color(viewBox(tester)).a, fadeIn ? 1 : 0);
        expect(viewSize(tester), const Size(40, 30));
        await tester.pump(const Duration(milliseconds: 40));
        if (fadeIn) {
          expect(_color(viewBox(tester)), _red);
        } else {
          expect(viewBox(tester), paintsNothing);
        }
      });
    }
    testWidgets('px 与百分比混合插值，父尺寸变化和中断从当前值接续', (tester) async {
      await tester.pumpWidget(
        viewScene(const ElStyle(width: 100, height: 20, transitions: _linear)),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: '50%', height: 20, transitions: _linear),
        ),
      );
      await _advance(tester, 50);
      expect(viewSize(tester).width, 150);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: '50%', height: 20, transitions: _linear),
          width: 600,
        ),
      );
      expect(viewSize(tester).width, 200);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 80, height: 20, transitions: _linear),
          width: 600,
        ),
      );
      expect(viewSize(tester).width, 200);
      await _advance(tester, 50);
      expect(viewSize(tester).width, 140);
      await _advance(tester, 50);
      expect(viewSize(tester).width, 80);
    });

    testWidgets('相同目标或另一属性变化不重启已有轨道', (tester) async {
      await tester.pumpWidget(
        viewScene(const ElStyle(width: 100, height: 20, transitions: _linear)),
      );
      await tester.pumpWidget(
        viewScene(const ElStyle(width: 200, height: 20, transitions: _linear)),
      );
      await _advance(tester, 25);
      await tester.pumpWidget(
        viewScene(
          ElStyle(width: 200, height: 20, transitions: List.of(_linear)),
        ),
      );
      await _advance(tester, 25);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 200,
            height: 20,
            backgroundColor: _red,
            transitions: _linear,
          ),
        ),
      );
      await _advance(tester, 50);
      expect(viewSize(tester).width, 200);
      expect(_color(viewBox(tester)).a, closeTo(.5, .005));
      await _advance(tester, 50);
    });

    testWidgets('auto 双向过渡使用已更新的真实子布局，支持 LayoutBuilder', (tester) async {
      Widget child(double width, double height) => LayoutBuilder(
        builder: (_, _) => SizedBox(width: width, height: height),
      );
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: _linear), child: child(80, 30)),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 200, height: 100, transitions: _linear),
          child: child(80, 30),
        ),
      );
      expect(viewSize(tester), const Size(80, 30));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(140, 65));
      await _advance(tester, 50);
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: _linear), child: child(120, 40)),
      );
      expect(viewSize(tester), const Size(200, 100));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(160, 70));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(120, 40));
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: _linear), child: child(150, 60)),
      );
      expect(viewSize(tester), const Size(150, 60));
    });

    testWidgets('自动尺寸目标在途中变化保持当前画面和原截止时间', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 200, transitions: _linear),
          child: const SizedBox(width: 100),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(transitions: _linear),
          child: const SizedBox(width: 100),
        ),
      );
      await _advance(tester, 50);
      expect(viewSize(tester).width, 150);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(transitions: _linear),
          child: const SizedBox(width: 180),
        ),
      );
      expect(viewSize(tester).width, 150);
      await _advance(tester, 25);
      expect(viewSize(tester).width, 165);
      await _advance(tester, 25);
      expect(viewSize(tester).width, 180);
    });

    testWidgets('透明色使用预乘 alpha，null 过渡终点停止绘制', (tester) async {
      const transparentBlue = Color(0x000000ff);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 40,
            height: 40,
            backgroundColor: _red,
            transitions: _linear,
          ),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 40,
            height: 40,
            backgroundColor: transparentBlue,
            transitions: _linear,
          ),
        ),
      );
      await _advance(tester, 50);
      var color = _color(viewBox(tester));
      expect(color.r, 1);
      expect(color.b, 0);
      expect(color.a, closeTo(.5, .005));
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 40,
            height: 40,
            backgroundColor: _blue,
            transitions: _linear,
          ),
        ),
      );
      expect(_color(viewBox(tester)), color);
      await _advance(tester, 50);
      color = _color(viewBox(tester));
      expect(color.a, closeTo(.75, .005));
      expect(color.r, closeTo(1 / 3, .005));
      expect(color.b, closeTo(2 / 3, .005));
      await _advance(tester, 50);
      await tester.pumpWidget(
        viewScene(const ElStyle(width: 40, height: 40, transitions: _linear)),
      );
      await _advance(tester, 50);
      expect(_color(viewBox(tester)).b, 1);
      await _advance(tester, 50);
      expect(viewBox(tester), paintsNothing);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 40,
            height: 40,
            backgroundColor: _red,
            transitions: _linear,
          ),
        ),
      );
      await _advance(tester, 50);
      expect(_color(viewBox(tester)).r, 1);
      expect(_color(viewBox(tester)).a, closeTo(.5, .005));
    });

    testWidgets('不同色域与半透明颜色过渡保持有限通道值', (tester) async {
      const p3 = Color.from(
        alpha: .2,
        red: 0,
        green: 1,
        blue: 0,
        colorSpace: ColorSpace.displayP3,
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 40,
            height: 40,
            backgroundColor: _red,
            transitions: _linear,
          ),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 40,
            height: 40,
            backgroundColor: p3,
            transitions: _linear,
          ),
        ),
      );
      await _advance(tester, 50);
      final color = _color(viewBox(tester));
      expect(color.a, closeTo(.6, .005));
      expect([color.r, color.g, color.b].every((v) => v.isFinite), isTrue);
      await _advance(tester, 49);
      final extended = p3.withValues(colorSpace: ColorSpace.extendedSRGB);
      expect(
        _color(viewBox(tester)).r,
        closeTo((.01 + extended.r * .198) / .208, .00001),
      );
      await _advance(tester, 1);
      expect(_color(viewBox(tester)), isSameColorAs(p3));
      expect(_color(viewBox(tester)).colorSpace, p3.colorSpace);
    });

    testWidgets('边距方向变化与显式清空均参与过渡', (tester) async {
      const style = ElStyle(
        width: 100,
        height: 50,
        padding: EdgeInsetsDirectional.only(start: 20),
        margin: EdgeInsets.all(10),
        transitions: _linear,
      );
      const childKey = ValueKey('animated-insets-child');
      const child = SizedBox(key: childKey, width: 10, height: 10);
      await tester.pumpWidget(viewScene(style, child: child));
      await tester.pumpWidget(
        viewScene(
          style.copyWith(margin: null),
          direction: TextDirection.rtl,
          child: child,
        ),
      );
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(110, 60));
      expect(_childOffset(tester, childKey), const Offset(15, 5));
      await _advance(tester, 50);
      expect(_childOffset(tester, childKey), Offset.zero);
    });

    testWidgets('逐字段配置、delay、零时长延迟和移除过渡', (tester) async {
      const config = [
        ElTransition.all(Duration(milliseconds: 100), Curves.linear),
        ElTransition.field(
          ElTransitionField.width,
          Duration.zero,
          Curves.linear,
          Duration(milliseconds: 50),
        ),
      ];
      await tester.pumpWidget(
        viewScene(const ElStyle(width: 100, height: 20, transitions: config)),
      );
      await tester.pumpWidget(
        viewScene(const ElStyle(width: 200, height: 120, transitions: config)),
      );
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(100, 45));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(200, 70));
      await tester.pumpWidget(
        viewScene(const ElStyle(width: 200, height: 120)),
      );
      expect(viewSize(tester), const Size(200, 120));
    });

    testWidgets('声明式过渡不受 TickerMode 与系统动画开关影响', (tester) async {
      Widget host(double width, {bool disableAnimations = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: TickerMode(
          enabled: !disableAnimations,
          child: viewScene(ElStyle(width: width, transitions: _linear)),
        ),
      );

      await tester.pumpWidget(host(100));
      await tester.pumpWidget(host(200, disableAnimations: true));
      await _advance(tester, 50);
      expect(viewSize(tester).width, 150);
      await tester.pumpWidget(host(200));
      await _advance(tester, 25);
      expect(viewSize(tester).width, 175);
      await tester.pumpWidget(host(200, disableAnimations: true));
      await _advance(tester, 25);
      expect(viewSize(tester).width, 200);
    });

    for (final target in <Object>['50%', 100]) {
      testWidgets('百分比参照消失时保持连续：目标 $target', (tester) async {
        Widget host(ElStyle style, {bool bounded = true}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: UnconstrainedBox(
              constrainedAxis: Axis.vertical,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: bounded ? 400 : double.infinity,
                ),
                child: ElView(
                  key: viewKey,
                  style: style,
                  child: const SizedBox(width: 80, height: 20),
                ),
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          host(
            ElStyle(
              width: target is String ? 100 : '50%',
              transitions: _linear,
            ),
          ),
        );
        final end = ElStyle(width: target, transitions: _linear);
        await tester.pumpWidget(host(end));
        await _advance(tester, 50);
        expect(viewSize(tester).width, 150);
        await tester.pumpWidget(host(end, bounded: false));
        expect(viewSize(tester).width, 150);
        await _advance(tester, 25);
        expect(viewSize(tester).width, target is String ? 115 : 125);
        await _advance(tester, 25);
        expect(viewSize(tester).width, target is String ? 80 : 100);
      });
    }

    testWidgets('两个透明端点跨色域不触发 Color.lerp 限制', (tester) async {
      const a = Color.from(alpha: 0, red: 1, green: 0, blue: 0);
      const b = Color.from(
        alpha: 0,
        red: 0,
        green: 0,
        blue: 1,
        colorSpace: ColorSpace.displayP3,
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 20,
            height: 20,
            backgroundColor: a,
            transitions: _linear,
          ),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 20,
            height: 20,
            backgroundColor: b,
            transitions: _linear,
          ),
        ),
      );
      await _advance(tester, 50);
      expect(tester.takeException(), isNull);
      expect(_color(viewBox(tester)).a, 0);
    });

    testWidgets('百分比重新获得参照时从当前尺寸接续到原截止时间', (tester) async {
      Widget host(ElStyle style, bool bounded) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: UnconstrainedBox(
            constrainedAxis: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: bounded ? 400 : double.infinity,
              ),
              child: ElView(
                key: viewKey,
                style: style,
                child: const SizedBox(width: 80),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        host(const ElStyle(width: 200, transitions: _linear), false),
      );
      const target = ElStyle(width: '50%', transitions: _linear);
      await tester.pumpWidget(host(target, false));
      await _advance(tester, 50);
      expect(viewSize(tester).width, 140);
      await tester.pumpWidget(host(target, true));
      expect(viewSize(tester).width, 140);
      await _advance(tester, 25);
      expect(viewSize(tester).width, 170);
      await _advance(tester, 25);
      expect(viewSize(tester).width, 200);
    });

    testWidgets('GlobalKey 重挂后动画从当前尺寸继续到原截止时间', (tester) async {
      final key = GlobalKey();
      Widget host(bool right, double width) {
        final view = ElView(
          key: key,
          style: ElStyle(width: width, height: 20, transitions: _linear),
        );
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Row(
              children: [
                SizedBox(width: 250, child: Center(child: right ? null : view)),
                SizedBox(width: 250, child: Center(child: right ? view : null)),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(host(false, 100));
      await tester.pumpWidget(host(false, 200));
      await _advance(tester, 50);
      await tester.pumpWidget(host(true, 200));
      expect(tester.getSize(find.byKey(key)).width, 150);
      await _advance(tester, 50);
      expect(tester.getSize(find.byKey(key)).width, 200);
    });

    testWidgets('曲线过冲不会产生负尺寸、负边距或越界 alpha', (tester) async {
      const transitions = [
        ElTransition.all(Duration(milliseconds: 100), Curves.easeOutBack),
      ];
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 100,
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.all(10),
            backgroundColor: _red,
            transitions: transitions,
          ),
        ),
      );
      await tester.pumpWidget(
        viewScene(const ElStyle(width: 0, height: 0, transitions: transitions)),
      );
      await _advance(tester, 60);
      expect(viewSize(tester), Size.zero);
      await _advance(tester, 40);
      expect(viewBox(tester), paintsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final (name, from, to, alpha, red, blue)
        in <(String, Color?, Color?, double, double, double)>[
          ('null → 不透明', null, _red, .5, 1, 0),
          ('不透明 → null', _red, null, .5, 1, 0),
          (
            'null → 半透明',
            null,
            Color.from(alpha: .5, red: 0, green: 0, blue: 1),
            .25,
            0,
            1,
          ),
          (
            '半透明 → null',
            Color.from(alpha: .5, red: 0, green: 0, blue: 1),
            null,
            .25,
            0,
            1,
          ),
          (
            '半透明红 → 半透明蓝',
            Color.from(alpha: .5, red: 1, green: 0, blue: 0),
            Color.from(alpha: .5, red: 0, green: 0, blue: 1),
            .5,
            .5,
            .5,
          ),
          (
            '不透明红 → 半透明蓝',
            _red,
            Color.from(alpha: .5, red: 0, green: 0, blue: 1),
            .75,
            2 / 3,
            1 / 3,
          ),
          ('透明蓝 → 不透明红', Color(0x000000ff), _red, .5, 1, 0),
        ]) {
      testWidgets('颜色中间值：$name', (tester) async {
        ElStyle style(Color? color) => ElStyle(
          width: 40,
          height: 30,
          backgroundColor: color,
          transitions: _linear,
        );
        await tester.pumpWidget(viewScene(style(from)));
        await tester.pumpWidget(viewScene(style(to)));
        await tester.pump(const Duration(milliseconds: 50));
        final actual = _color(viewBox(tester));
        expect(actual.a, closeTo(alpha, .00001));
        expect(actual.r, closeTo(red, .00001));
        expect(actual.g, 0);
        expect(actual.b, closeTo(blue, .00001));
        await tester.pump(const Duration(milliseconds: 50));
        if (to == null) {
          expect(viewBox(tester), paintsNothing);
        } else {
          expect(_color(viewBox(tester)), isSameColorAs(to));
        }
      });
    }

    testWidgets('动画中卸载后重新挂载使用新的声明值', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 40,
            height: 30,
            backgroundColor: _red,
            transitions: _linear,
          ),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _blue,
            transitions: _linear,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(70, 45));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 80,
            height: 20,
            backgroundColor: _red,
            transitions: _linear,
          ),
        ),
      );
      expect(viewSize(tester), const Size(80, 20));
      expect(_color(viewBox(tester)), _red);
    });
  });

  group('尺寸、参照与 auto 边界', () {
    for (final restore in [false, true]) {
      testWidgets('等待期间失去百分比参照后，中间尺寸保持正确：恢复=$restore', (tester) async {
        const transitions = [
          ElTransition.all(
            Duration(milliseconds: 100),
            Curves.linear,
            Duration(milliseconds: 50),
          ),
        ];
        Widget host(Object width, {bool bounded = true}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: UnconstrainedBox(
              constrainedAxis: Axis.vertical,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: bounded ? 400 : double.infinity,
                ),
                child: ElView(
                  key: viewKey,
                  style: ElStyle(
                    width: width,
                    height: 20,
                    transitions: transitions,
                  ),
                  child: const SizedBox(width: 80, height: 20),
                ),
              ),
            ),
          ),
        );
        final target = restore ? '75%' : '50%';
        await tester.pumpWidget(host(restore ? '25%' : 100));
        await tester.pumpWidget(host(target));
        await tester.pump(const Duration(milliseconds: 25));
        await tester.pumpWidget(host(target, bounded: false));
        expect(viewSize(tester).width, 100);
        if (restore) {
          await tester.pump(const Duration(milliseconds: 10));
          expect(viewSize(tester).width, 100);
          await tester.pumpWidget(host(target));
        }
        await tester.pump(Duration(milliseconds: restore ? 40 : 50));
        expect(viewSize(tester).width, restore ? 150 : 95);
        await tester.pump(const Duration(milliseconds: 25));
        expect(viewSize(tester).width, restore ? 200 : 90);
        await tester.pump(const Duration(milliseconds: 50));
        expect(viewSize(tester).width, restore ? 300 : 80);
      });
    }
    for (final dense in [false, true]) {
      final sampling = dense ? '逐帧推进' : '跨帧推进';

      testWidgets('auto 宽度与较慢 padding 在截止帧保持连续：$sampling', (tester) async {
        const child = SizedBox(width: 100, height: 20);
        await tester.pumpWidget(
          viewScene(
            const ElStyle(width: 200, transitions: _widthAndPadding),
            child: child,
          ),
        );
        await tester.pumpWidget(
          viewScene(
            const ElStyle(
              padding: EdgeInsets.symmetric(horizontal: 40),
              transitions: _widthAndPadding,
            ),
            child: child,
          ),
        );
        await _advanceTo99(tester, dense: dense);
        final before = viewSize(tester).width;
        await tester.pump(const Duration(milliseconds: 1));
        expect((viewSize(tester).width - before).abs(), lessThan(3));
        expect(viewSize(tester).width, closeTo(140, .001));
        if (dense) {
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
        } else {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(viewSize(tester).width, closeTo(180, .001));
        expect(tester.takeException(), isNull);
      });

      testWidgets('双 auto 与宽高比跨轴耦合在不同截止帧保持连续：$sampling', (tester) async {
        const child = AspectRatio(aspectRatio: 2);
        await tester.pumpWidget(
          viewScene(
            const ElStyle(width: 200, height: 50, transitions: _widthAndHeight),
            child: child,
          ),
        );
        await tester.pumpWidget(
          viewScene(const ElStyle(transitions: _widthAndHeight), child: child),
        );
        await _advanceTo99(tester, dense: dense);
        final before = viewSize(tester).width;
        await tester.pump(const Duration(milliseconds: 1));
        expect((viewSize(tester).width - before).abs(), lessThan(5));
        expect(viewSize(tester).width, closeTo(250, .001));
        expect(viewSize(tester).height, closeTo(125, .001));
        if (dense) {
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
        } else {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(viewSize(tester), const Size(400, 200));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('固定像素宽度按声明曲线插值，child 同步受到可用宽度限制', (tester) async {
      const childKey = ValueKey('pixel-child');
      const child = SizedBox(key: childKey, width: 1000, height: 20);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 100, transitions: _linear),
          child: child,
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 200, transitions: _linear),
          child: child,
        ),
      );
      for (var i = 1; i <= 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final width = 100 + i * 10.0;
        expect(viewSize(tester).width, closeTo(width, .001));
        expect(tester.getSize(find.byKey(childKey)), Size(width, 20));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto 临时测量后嵌套百分比、位置与后代动画仍使用正式几何', (tester) async {
      const columnKey = ValueKey('nested-column');
      const nestedKey = ValueKey('nested-view');
      const leafKey = ValueKey('nested-leaf');
      const padding = EdgeInsets.fromLTRB(7, 11, 13, 17);
      const margin = EdgeInsets.fromLTRB(3, 5, 9, 15);
      const childTransitions = [
        ElTransition.field(
          ElTransitionField.width,
          Duration(milliseconds: 200),
          Curves.linear,
        ),
      ];
      Widget nested(double width) => Column(
        key: columnKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElView(
            key: nestedKey,
            style: ElStyle(
              width: width,
              height: '50%',
              transitions: childTransitions,
            ),
            child: LayoutBuilder(
              builder: (_, _) =>
                  const SizedBox(key: leafKey, width: 30, height: 40),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 200,
            height: 200,
            padding: padding,
            margin: margin,
            transitions: _linear,
          ),
          child: nested(100),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 200,
            padding: padding,
            margin: margin,
            transitions: _linear,
          ),
          child: nested(140),
        ),
      );
      for (var i = 1; i <= 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final nestedSize = tester.getSize(find.byKey(nestedKey));
        final columnSize = tester.getSize(find.byKey(columnKey));
        expect(nestedSize.width, closeTo(100 + i * 2, .001));
        expect(
          _childOffset(tester, columnKey),
          offsetMoreOrLessEquals(const Offset(10, 16)),
        );
        expect(
          tester.getTopLeft(find.byKey(nestedKey)),
          tester.getTopLeft(find.byKey(columnKey)),
        );
        if (i < 10) {
          final contentHeight =
              viewSize(tester).height - margin.vertical - padding.vertical;
          expect(nestedSize.height, closeTo(contentHeight * .5, .001));
        } else {
          expect(viewSize(tester), const Size(212, 88));
          expect(nestedSize.height, 40);
          expect(tester.getSize(find.byKey(leafKey)).height, 40);
        }
        expect(columnSize.height, nestedSize.height);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('auto 宽度与较慢非对称 margin 保持截止帧、背景和内容位置连续', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.width,
          Duration(milliseconds: 100),
          Curves.linear,
        ),
        ElTransition.field(
          ElTransitionField.margin,
          Duration(milliseconds: 200),
          Curves.linear,
        ),
      ];
      const childKey = ValueKey('margin-child');
      const child = SizedBox(key: childKey, width: 400, height: 20);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 200,
            backgroundColor: _red,
            transitions: transitions,
          ),
          child: child,
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            margin: EdgeInsets.fromLTRB(40, 10, 20, 30),
            backgroundColor: _red,
            transitions: transitions,
          ),
          child: child,
        ),
      );
      await tester.pump(const Duration(milliseconds: 99));
      final before = viewSize(tester).width;
      await tester.pump(const Duration(milliseconds: 1));
      expect((viewSize(tester).width - before).abs(), lessThan(3));
      expect(viewSize(tester), const Size(400, 40));
      expect(tester.getSize(find.byKey(childKey)), const Size(370, 20));
      expect(_childOffset(tester, childKey), const Offset(20, 5));
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(20, 5, 370, 20), color: _red),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        expect(viewSize(tester).width, 400);
      }
      expect(viewSize(tester), const Size(400, 60));
      expect(tester.getSize(find.byKey(childKey)), const Size(340, 20));
      expect(_childOffset(tester, childKey), const Offset(40, 10));
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(40, 10, 340, 20), color: _red),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto 端点未变时父约束变化保持原缓动时间线', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.width,
          Duration(milliseconds: 100),
          Curves.easeInQuad,
        ),
      ];
      const child = SizedBox(width: 100, height: 20);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 200, transitions: transitions),
          child: child,
        ),
      );
      const target = ElStyle(transitions: transitions);
      await tester.pumpWidget(viewScene(target, child: child));
      await tester.pump(const Duration(milliseconds: 50));
      final halfway = 200 - 100 * Curves.easeInQuad.transform(.5);
      expect(viewSize(tester).width, closeTo(halfway, .001));
      await tester.pumpWidget(viewScene(target, child: child, width: 500));
      expect(viewSize(tester).width, closeTo(halfway, .001));
      await tester.pump(const Duration(milliseconds: 25));
      expect(
        viewSize(tester).width,
        closeTo(200 - 100 * Curves.easeInQuad.transform(.75), .001),
      );
      await tester.pump(const Duration(milliseconds: 25));
      expect(viewSize(tester).width, 100);
      expect(tester.takeException(), isNull);
    });

    testWidgets('阶跃曲线在阈值前保持原宽度，越过阈值后切换最终尺寸', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.width,
          Duration(milliseconds: 100),
          Threshold(.8),
        ),
      ];
      const childKey = ValueKey('threshold-child');
      const child = SizedBox(key: childKey, width: 1000, height: 20);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 100, transitions: transitions),
          child: child,
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 200, transitions: transitions),
          child: child,
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(viewSize(tester).width, 100);
        expect(tester.getSize(find.byKey(childKey)).width, 100);
      }
      await tester.pump(const Duration(milliseconds: 10));
      expect(viewSize(tester).width, 200);
      expect(tester.getSize(find.byKey(childKey)).width, 200);
      await tester.pump(const Duration(milliseconds: 15));
      expect(viewSize(tester).width, 200);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto 宽度 delay 期间保持当前宽度，padding 正常变化，延迟后完成过渡', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.width,
          Duration(milliseconds: 100),
          Curves.linear,
          Duration(milliseconds: 1000),
        ),
        ElTransition.field(
          ElTransitionField.padding,
          Duration(milliseconds: 200),
          Curves.linear,
        ),
      ];
      const childKey = ValueKey('delayed-child');
      const child = SizedBox(key: childKey, width: 400, height: 20);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 200, transitions: transitions),
          child: child,
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            padding: EdgeInsets.symmetric(horizontal: 40),
            transitions: transitions,
          ),
          child: child,
        ),
      );
      for (var i = 1; i <= 20; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        expect(viewSize(tester).width, 200);
        expect(
          tester.getSize(find.byKey(childKey)).width,
          closeTo(200 - i * 4, .001),
        );
        expect(_childOffset(tester, childKey).dx, closeTo(i * 2, .001));
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(viewSize(tester).width, 200);
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester).width, 300);
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester).width, 400);
      expect(tester.getSize(find.byKey(childKey)).width, 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('紧约束 child 在同一时间戳更新内容后 auto 动画使用新尺寸', (tester) async {
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 0, height: 0, transitions: _linear),
          child: const SizedBox(width: 100),
        ),
      );
      const target = ElStyle(height: 0, transitions: _linear);
      await tester.pumpWidget(
        viewScene(target, child: const SizedBox(width: 100)),
      );
      expect(viewSize(tester), Size.zero);
      await tester.pumpWidget(
        viewScene(target, child: const SizedBox(width: 200)),
      );
      expect(viewSize(tester), Size.zero);
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(100, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(200, 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto 动画中即时修改 padding 保持当前画面与原截止时间', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.width,
          Duration(milliseconds: 100),
          Curves.linear,
        ),
      ];
      const child = SizedBox(width: 100, height: 20);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 200, transitions: transitions),
          child: child,
        ),
      );
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: transitions), child: child),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester).width, 150);
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            padding: EdgeInsets.symmetric(horizontal: 40),
            transitions: transitions,
          ),
          child: child,
        ),
      );
      expect(viewSize(tester).width, 150);
      await tester.pump(const Duration(milliseconds: 25));
      expect(viewSize(tester).width, 165);
      await tester.pump(const Duration(milliseconds: 25));
      expect(viewSize(tester).width, 180);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto 起终点同为零时 child 独立更新仍能改变动画结果', (tester) async {
      final naturalWidth = ValueNotifier<double>(0);
      addTearDown(naturalWidth.dispose);
      final child = ValueListenableBuilder<double>(
        valueListenable: naturalWidth,
        builder: (_, width, _) => SizedBox(width: width),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 0, height: 0, transitions: _linear),
          child: child,
        ),
      );
      await tester.pumpWidget(
        viewScene(const ElStyle(height: 0, transitions: _linear), child: child),
      );
      await tester.pump(const Duration(milliseconds: 25));
      expect(viewSize(tester), Size.zero);
      naturalWidth.value = 200;
      await tester.pump();
      expect(viewSize(tester), Size.zero);
      await tester.pump(const Duration(milliseconds: 25));
      expect(viewSize(tester), const Size(100, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(200, 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto 与百分比双向过渡都按当前父尺寸和自然内容求值', (tester) async {
      const child = SizedBox(width: 80, height: 40);
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: _linear), child: child),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: '50%', height: '50%', transitions: _linear),
          child: child,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(140, 95));
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(200, 150));
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: _linear), child: child),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(140, 95));
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(80, 40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('方向性 padding 与 margin 在 RTL 切换中连续移动内容与背景', (tester) async {
      const childKey = ValueKey('directional-child');
      const child = SizedBox(key: childKey, width: 20, height: 10);
      const style = ElStyle(
        width: 100,
        height: 60,
        padding: EdgeInsetsDirectional.fromSTEB(10, 2, 30, 4),
        margin: EdgeInsetsDirectional.fromSTEB(5, 7, 15, 9),
        backgroundColor: _red,
        transitions: _linear,
      );
      await tester.pumpWidget(viewScene(style, child: child));
      expect(viewSize(tester), const Size(120, 76));
      expect(_childOffset(tester, childKey), const Offset(15, 9));
      await tester.pumpWidget(
        viewScene(style, child: child, direction: TextDirection.rtl),
      );
      expect(_childOffset(tester, childKey), const Offset(15, 9));
      await tester.pump(const Duration(milliseconds: 50));
      expect(viewSize(tester), const Size(120, 76));
      expect(_childOffset(tester, childKey), const Offset(30, 9));
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(10, 7, 100, 60), color: _red),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(_childOffset(tester, childKey), const Offset(45, 9));
      expect(
        viewBox(tester),
        paints..rect(rect: const Rect.fromLTWH(15, 7, 100, 60), color: _red),
      );
      expect(tester.takeException(), isNull);
    });

    for (final animateParent in [false, true]) {
      for (final delay in [Duration.zero, const Duration(milliseconds: 50)]) {
        testWidgets(
          '无界横轴中父子同时转 auto 时，百分比宽度从当前画面接续：父动画=$animateParent，delay=$delay',
          (tester) async {
            final transitions = [
              ElTransition.field(
                ElTransitionField.width,
                const Duration(milliseconds: 100),
                Curves.linear,
                delay,
              ),
            ];
            Widget host({required bool automatic}) => Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: UnconstrainedBox(
                  constrainedAxis: Axis.vertical,
                  child: ElView(
                    style: ElStyle(
                      width: automatic ? null : 200,
                      transitions: animateParent ? transitions : null,
                    ),
                    child: ElView(
                      key: viewKey,
                      style: ElStyle(
                        width: automatic ? null : '50%',
                        transitions: transitions,
                      ),
                      child: const SizedBox(width: 60, height: 20),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpWidget(host(automatic: false));
            expect(viewSize(tester).width, 100);
            await tester.pumpWidget(host(automatic: true));
            expect(viewSize(tester).width, 100);
            if (delay != Duration.zero) {
              await tester.pump(const Duration(milliseconds: 25));
              expect(viewSize(tester).width, 100);
              await tester.pump(const Duration(milliseconds: 25));
              expect(viewSize(tester).width, 100);
            }
            await tester.pump(const Duration(milliseconds: 25));
            expect(viewSize(tester).width, 90);
            await tester.pump(const Duration(milliseconds: 25));
            expect(viewSize(tester).width, 80);
            await tester.pump(const Duration(milliseconds: 50));
            expect(viewSize(tester).width, 60);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('尺寸上下限的中间值', () {
    testWidgets('双轴 min 按当前值撑盒，内容位置、圆角裁剪与轮廓跟随实际尺寸', (tester) async {
      const childKey = ValueKey('min-animation-child');
      const child = SizedBox(key: childKey, width: 40, height: 20);
      ElStyle style(double width, double height) => ElStyle(
        minWidth: width,
        minHeight: height,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        backgroundColor: _red,
        borderRadius: BorderRadius.circular(12),
        outline: const ElOutline(width: 4, offset: 3, color: _blue),
        clipBehavior: Clip.antiAlias,
        transitions: _linear,
      );
      await tester.pumpWidget(viewScene(style(80, 50), child: child));
      await tester.pumpWidget(viewScene(style(200, 130), child: child));
      for (var step = 1; step <= 4; step++) {
        await _advance(tester, 25);
        final width = 80 + step * 30.0, height = 50 + step * 20.0;
        final rect = Rect.fromLTWH(3, 5, width, height);
        expect(viewSize(tester), Size(width + 6, height + 10));
        expect(tester.getSize(find.byKey(childKey)), const Size(40, 20));
        expect(_childOffset(tester, childKey), const Offset(13, 15));
        _background(tester, null, rect: rect);
        _clip(
          tester,
          Clip.antiAlias,
          radius: BorderRadius.circular(12),
          rect: rect,
        );
        final pixels = await _borderPixels(tester, [Offset(3 + width / 2, 0)]);
        _pixel(pixels.single, _blue);
      }
    });

    testWidgets('双轴 max 插值先限制 child，再将 padding 和 margin 计入实际占位', (
      tester,
    ) async {
      const childKey = ValueKey('max-animation-child');
      const child = SizedBox(key: childKey, width: 1000, height: 1000);
      ElStyle style(double width, double height) => ElStyle(
        maxWidth: width,
        maxHeight: height,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        transitions: _linear,
      );
      await tester.pumpWidget(viewScene(style(300, 200), child: child));
      await tester.pumpWidget(viewScene(style(100, 80), child: child));
      for (var step = 1; step <= 4; step++) {
        await _advance(tester, 25);
        final width = 300 - step * 50.0, height = 200 - step * 30.0;
        expect(viewSize(tester), Size(width + 6, height + 10));
        expect(
          tester.getSize(find.byKey(childKey)),
          Size(width - 20, height - 20),
        );
        expect(_childOffset(tester, childKey), const Offset(13, 15));
      }
    });

    testWidgets('min 和 max 的像素百分比混合表达式按当帧父参照求值', (tester) async {
      for (final minimum in [true, false]) {
        final key = ValueKey('limit-percent-$minimum');
        final child = SizedBox(
          width: minimum ? 0 : 1000,
          height: minimum ? 0 : 1000,
        );
        ElStyle style(bool target) => ElStyle(
          minWidth: minimum ? (target ? '50%' : 40) : null,
          minHeight: minimum ? (target ? '50%' : 20) : null,
          maxWidth: minimum ? null : (target ? '50%' : 40),
          maxHeight: minimum ? null : (target ? '50%' : 20),
          transitions: _linear,
        );
        await tester.pumpWidget(
          viewScene(style(false), child: child, key: key),
        );
        await tester.pumpWidget(viewScene(style(true), child: child, key: key));
        await _advance(tester, 50);
        expect(viewSize(tester, key: key), const Size(120, 85));
        await tester.pumpWidget(
          viewScene(
            style(true),
            child: child,
            width: 600,
            height: 500,
            key: key,
          ),
        );
        expect(viewSize(tester, key: key), const Size(170, 135));
        await _advance(tester, 50);
        expect(viewSize(tester, key: key), const Size(300, 250));
      }
    });

    testWidgets('null 上下限双向切换遵守中点离散，不插值无限尺寸或触发 auto 测量', (tester) async {
      const child = SizedBox(width: 20, height: 120);
      ElStyle style(bool limited) => ElStyle(
        minWidth: limited ? 100 : null,
        maxHeight: limited ? 40 : null,
        transitions: _linear,
      );
      await tester.pumpWidget(viewScene(style(false), child: child));
      for (final limited in [true, false]) {
        await tester.pumpWidget(viewScene(style(limited), child: child));
        await _advance(tester, 49);
        expect(
          viewSize(tester),
          limited ? const Size(20, 120) : const Size(100, 40),
        );
        await _advance(tester, 1);
        expect(
          viewSize(tester),
          limited ? const Size(100, 40) : const Size(20, 120),
        );
        await _advance(tester, 50);
        expect(
          viewSize(tester),
          limited ? const Size(100, 40) : const Size(20, 120),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('上下限支持延迟、中断接续、移除过渡与零时长等待', (tester) async {
      const child = SizedBox(width: 20, height: 200);
      const delayed = [
        ElTransition.all(
          Duration(milliseconds: 100),
          Curves.linear,
          Duration(milliseconds: 50),
        ),
      ];
      ElStyle style(Object? minimum, Object? maximum, {bool animate = true}) =>
          ElStyle(
            minWidth: minimum,
            maxHeight: maximum,
            transitions: animate ? delayed : null,
          );
      await tester.pumpWidget(viewScene(style(40, 160), child: child));
      await tester.pumpWidget(viewScene(style(200, 80), child: child));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(40, 160));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(80, 140));
      await tester.pumpWidget(viewScene(style(120, 100), child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(80, 140));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(100, 120));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(120, 100));
      await tester.pumpWidget(
        viewScene(style(null, null, animate: false), child: child),
      );
      expect(viewSize(tester), const Size(20, 200));
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            minWidth: 200,
            maxHeight: 40,
            transitions: [
              ElTransition.all(
                Duration.zero,
                Curves.linear,
                Duration(milliseconds: 20),
              ),
            ],
          ),
          child: child,
        ),
      );
      await _advance(tester, 19);
      expect(viewSize(tester), const Size(20, 200));
      await _advance(tester, 1);
      expect(viewSize(tester), const Size(200, 40));
    });

    testWidgets('负过冲限制到零，min 与 max 相交后由当前 max 决定尺寸', (tester) async {
      const child = SizedBox(width: 10, height: 100);
      ElStyle overshoot(double value) => ElStyle(
        minWidth: value,
        maxHeight: value,
        transitions: const [
          ElTransition.all(Duration(milliseconds: 100), _NegativeCurve()),
        ],
      );
      await tester.pumpWidget(viewScene(overshoot(20), child: child));
      await tester.pumpWidget(viewScene(overshoot(100), child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(10, 0));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(100, 100));
      const crossingKey = ValueKey('crossing-limit-view');
      ElStyle crossing(double minimum, double maximum) =>
          ElStyle(minWidth: minimum, maxWidth: maximum, transitions: _linear);
      await tester.pumpWidget(
        viewScene(crossing(40, 200), child: child, key: crossingKey),
      );
      await tester.pumpWidget(
        viewScene(crossing(200, 80), child: child, key: crossingKey),
      );
      await _advance(tester, 50);
      expect(viewSize(tester, key: crossingKey), const Size(120, 100));
      await _advance(tester, 25);
      expect(viewSize(tester, key: crossingKey), const Size(110, 100));
      await _advance(tester, 25);
      expect(viewSize(tester, key: crossingKey), const Size(80, 100));
      expect(tester.takeException(), isNull);
    });

    for (final dense in [false, true]) {
      testWidgets('auto 端点使用当前上限、padding 与因子，各通道不同截止仍连续：逐帧=$dense', (
        tester,
      ) async {
        const child = SizedBox(width: 100, height: 40);
        const transitions = [
          ElTransition.field(
            ElTransitionField.width,
            Duration(milliseconds: 100),
            Curves.linear,
          ),
          ElTransition.field(
            ElTransitionField.maxWidth,
            Duration(milliseconds: 200),
            Curves.linear,
          ),
          ElTransition.field(
            ElTransitionField.padding,
            Duration(milliseconds: 200),
            Curves.linear,
          ),
          ElTransition.field(
            ElTransitionField.widthFactor,
            Duration(milliseconds: 200),
            Curves.linear,
          ),
        ];
        await tester.pumpWidget(
          viewScene(
            const ElStyle(width: 240, maxWidth: 300, transitions: transitions),
            child: child,
          ),
        );
        await tester.pumpWidget(
          viewScene(
            const ElStyle(
              maxWidth: 140,
              padding: EdgeInsets.symmetric(horizontal: 20),
              widthFactor: 2,
              transitions: transitions,
            ),
            child: child,
          ),
        );
        await _advanceTo99(tester, dense: dense);
        final before = viewSize(tester).width;
        await _advance(tester, 1);
        expect((viewSize(tester).width - before).abs(), lessThan(3));
        expect(viewSize(tester), const Size(180, 40));
        await _advance(tester, 50);
        expect(viewSize(tester), const Size(180, 40));
        await _advance(tester, 50);
        expect(viewSize(tester), const Size(140, 40));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('max 逐帧收紧时真实 child 按新宽度重新计算高度', (tester) async {
      const childKey = ValueKey('max-reflow-child');
      final child = LayoutBuilder(
        builder: (_, constraints) => SizedBox(
          key: childKey,
          width: constraints.maxWidth,
          height: constraints.maxWidth / 2,
        ),
      );
      ElStyle style(double maximum) =>
          ElStyle(maxWidth: maximum, transitions: _linear);
      await tester.pumpWidget(viewScene(style(300), child: child));
      await tester.pumpWidget(viewScene(style(100), child: child));
      for (var step = 1; step <= 4; step++) {
        await _advance(tester, 25);
        final width = 300 - step * 50.0;
        expect(viewSize(tester), Size(width, width / 2));
        expect(tester.getSize(find.byKey(childKey)), Size(width, width / 2));
      }
    });

    testWidgets('动画中的上下限遵守父 tight 约束，嵌套百分比跟随正式内容参照', (tester) async {
      const nestedKey = ValueKey('limit-nested-percent');
      Widget scene(double maximum, {bool tight = false}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: tight ? 240 : 0,
              maxWidth: tight ? 240 : 400,
              maxHeight: 300,
            ),
            child: ElView(
              key: viewKey,
              style: ElStyle(
                width: 400,
                height: 40,
                maxWidth: maximum,
                padding: const EdgeInsets.all(10),
                transitions: _linear,
              ),
              child: const ElView(
                key: nestedKey,
                style: ElStyle(width: '50%', minWidth: '75%', height: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene(300));
      expect(viewSize(tester, key: nestedKey), const Size(210, 20));
      await tester.pumpWidget(scene(100));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(200, 40));
      expect(viewSize(tester, key: nestedKey), const Size(135, 20));
      await tester.pumpWidget(scene(100, tight: true));
      expect(viewSize(tester), const Size(240, 40));
      expect(viewSize(tester, key: nestedKey), const Size(165, 20));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(240, 40));
      await tester.pumpWidget(scene(100));
      expect(viewSize(tester), const Size(150, 40));
      expect(viewSize(tester, key: nestedKey), const Size(97.5, 20));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(100, 40));
      expect(viewSize(tester, key: nestedKey), const Size(60, 20));
      expect(tester.takeException(), isNull);
    });

    testWidgets('混合百分比上限暂失参照时不限制，参照恢复后继续原进度', (tester) async {
      Widget scene(Object maximum, {bool bounded = true}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: UnconstrainedBox(
            constrainedAxis: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: bounded ? 400 : double.infinity,
                maxHeight: 300,
              ),
              child: ElView(
                key: viewKey,
                style: ElStyle(maxWidth: maximum, transitions: _linear),
                child: const SizedBox(width: 300, height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene(100));
      await tester.pumpWidget(scene('50%'));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(125, 40));
      await tester.pumpWidget(scene('50%', bounded: false));
      expect(viewSize(tester), const Size(300, 40));
      await tester.pumpWidget(scene('50%'));
      expect(viewSize(tester), const Size(125, 40));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(150, 40));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(200, 40));
      expect(tester.takeException(), isNull);
    });
  });

  group('自然尺寸因子的中间值', () {
    testWidgets('双轴因子从 null 过渡到 2 再清空，padding 参与缩放但 child 不缩放', (tester) async {
      const childKey = ValueKey('factor-child');
      const child = SizedBox(key: childKey, width: 80, height: 40);
      ElStyle style(double? factor) => ElStyle(
        widthFactor: factor,
        heightFactor: factor,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        backgroundColor: _red,
        transitions: _linear,
      );
      await tester.pumpWidget(viewScene(style(null), child: child));
      expect(viewSize(tester), const Size(106, 70));
      await tester.pumpWidget(viewScene(style(2), child: child));
      for (final size in [const Size(156, 100), const Size(206, 130)]) {
        await _advance(tester, 50);
        expect(viewSize(tester), size);
        expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
        expect(_childOffset(tester, childKey), const Offset(13, 15));
        _background(
          tester,
          null,
          rect: Rect.fromLTWH(3, 5, size.width - 6, size.height - 10),
        );
      }
      await tester.pumpWidget(viewScene(style(null), child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(156, 100));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(106, 70));
    });

    testWidgets('因子过渡到零时只收缩视图占位，负过冲保持零尺寸', (tester) async {
      const childKey = ValueKey('zero-factor-child');
      const child = SizedBox(key: childKey, width: 80, height: 40);
      ElStyle style(double factor, {Curve curve = Curves.linear}) => ElStyle(
        widthFactor: factor,
        heightFactor: factor,
        transitions: [
          ElTransition.all(const Duration(milliseconds: 100), curve),
        ],
      );
      await tester.pumpWidget(viewScene(style(2), child: child));
      await tester.pumpWidget(viewScene(style(0), child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(80, 40));
      await _advance(tester, 50);
      expect(viewSize(tester), Size.zero);
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      await tester.pumpWidget(
        viewScene(style(1, curve: const _NegativeCurve()), child: child),
      );
      await _advance(tester, 50);
      expect(viewSize(tester), Size.zero);
      expect(tester.takeException(), isNull);
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(80, 40));
    });

    testWidgets('因子延迟与中断从当前尺寸接续，移除过渡后立即应用清空值', (tester) async {
      const child = SizedBox(width: 80, height: 40);
      const transitions = [
        ElTransition.field(
          ElTransitionField.widthFactor,
          Duration(milliseconds: 100),
          Curves.linear,
          Duration(milliseconds: 50),
        ),
      ];
      ElStyle style(double? factor, {bool animate = true}) => ElStyle(
        widthFactor: factor,
        transitions: animate ? transitions : null,
      );
      await tester.pumpWidget(viewScene(style(null), child: child));
      await tester.pumpWidget(viewScene(style(3), child: child));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(80, 40));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(120, 40));
      await tester.pumpWidget(viewScene(style(2), child: child));
      expect(viewSize(tester), const Size(120, 40));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(120, 40));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(140, 40));
      await tester.pumpWidget(
        viewScene(style(null, animate: false), child: child),
      );
      expect(viewSize(tester), const Size(80, 40));
      await _advance(tester, 100);
      expect(viewSize(tester), const Size(80, 40));
    });

    testWidgets('因子先结束、padding 后结束时，每帧只缩放一次当前自然盒', (tester) async {
      const childKey = ValueKey('factor-padding-child');
      const child = SizedBox(key: childKey, width: 100, height: 40);
      const transitions = [
        ElTransition.field(
          ElTransitionField.widthFactor,
          Duration(milliseconds: 100),
          Curves.linear,
        ),
        ElTransition.field(
          ElTransitionField.padding,
          Duration(milliseconds: 200),
          Curves.linear,
        ),
      ];
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: transitions), child: child),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            widthFactor: 2,
            padding: EdgeInsets.symmetric(horizontal: 20),
            transitions: transitions,
          ),
          child: child,
        ),
      );
      for (final (width, inset) in [
        (165.0, 5.0),
        (240.0, 10.0),
        (260.0, 15.0),
        (280.0, 20.0),
      ]) {
        await _advance(tester, 50);
        expect(viewSize(tester), Size(width, 40));
        expect(tester.getSize(find.byKey(childKey)), const Size(100, 40));
        expect(_childOffset(tester, childKey), Offset(inset, 0));
      }
    });

    for (final dense in [false, true]) {
      testWidgets('显式宽度转 auto 时跟随较慢因子，截止帧不双乘或跳变：逐帧=$dense', (tester) async {
        const child = SizedBox(width: 100, height: 40);
        const transitions = [
          ElTransition.field(
            ElTransitionField.width,
            Duration(milliseconds: 100),
            Curves.linear,
          ),
          ElTransition.field(
            ElTransitionField.widthFactor,
            Duration(milliseconds: 200),
            Curves.linear,
          ),
        ];
        await tester.pumpWidget(
          viewScene(
            const ElStyle(width: 200, transitions: transitions),
            child: child,
          ),
        );
        await tester.pumpWidget(
          viewScene(
            const ElStyle(widthFactor: 2, transitions: transitions),
            child: child,
          ),
        );
        expect(viewSize(tester), const Size(200, 40));
        await _advanceTo99(tester, dense: dense);
        final before = viewSize(tester).width;
        await _advance(tester, 1);
        expect((viewSize(tester).width - before).abs(), lessThan(3));
        expect(viewSize(tester), const Size(150, 40));
        await _advance(tester, 50);
        expect(viewSize(tester), const Size(175, 40));
        await _advance(tester, 50);
        expect(viewSize(tester), const Size(200, 40));
      });
    }

    testWidgets('百分比与 auto 双向切换时只对自然端点应用因子', (tester) async {
      const child = SizedBox(width: 80, height: 40);
      ElStyle style(Object? width, Object? height) => ElStyle(
        width: width,
        height: height,
        widthFactor: 1.5,
        heightFactor: 1.5,
        padding: const EdgeInsets.all(10),
        transitions: _linear,
      );
      await tester.pumpWidget(viewScene(style(null, null), child: child));
      expect(viewSize(tester), const Size(150, 90));
      await tester.pumpWidget(viewScene(style('50%', '50%'), child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(175, 120));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(200, 150));
      await tester.pumpWidget(viewScene(style(null, null), child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(175, 120));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(150, 90));
    });

    testWidgets('因子运行期间 child 改变自然尺寸，继续缩放当前内容尺寸', (tester) async {
      final natural = ValueNotifier<Size>(const Size(80, 40));
      addTearDown(natural.dispose);
      const childKey = ValueKey('changing-factor-child');
      final child = ValueListenableBuilder<Size>(
        valueListenable: natural,
        builder: (_, size, _) => SizedBox.fromSize(key: childKey, size: size),
      );
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: _linear), child: child),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(widthFactor: 2, heightFactor: 2, transitions: _linear),
          child: child,
        ),
      );
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(120, 60));
      natural.value = const Size(120, 60);
      await tester.pump();
      expect(viewSize(tester), const Size(180, 90));
      expect(tester.getSize(find.byKey(childKey)), const Size(120, 60));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(210, 105));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(240, 120));
    });

    testWidgets('auto 端点在 child 更新后重新求自然盒，保留画面和原截止时间', (tester) async {
      final naturalWidth = ValueNotifier<double>(80);
      addTearDown(naturalWidth.dispose);
      final child = ValueListenableBuilder<double>(
        valueListenable: naturalWidth,
        builder: (_, width, _) => SizedBox(width: width, height: 40),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(width: 200, widthFactor: 2, transitions: _linear),
          child: child,
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(widthFactor: 2, transitions: _linear),
          child: child,
        ),
      );
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(180, 40));
      naturalWidth.value = 120;
      await tester.pump();
      expect(viewSize(tester), const Size(180, 40));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(210, 40));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(240, 40));
    });

    testWidgets('父约束收紧再放宽时，保留因子当前进度且不缩放 child', (tester) async {
      const childKey = ValueKey('bounded-factor-child');
      const child = SizedBox(key: childKey, width: 80, height: 40);
      const target = ElStyle(
        widthFactor: 3,
        heightFactor: 3,
        transitions: _linear,
      );
      await tester.pumpWidget(
        viewScene(const ElStyle(transitions: _linear), child: child),
      );
      await tester.pumpWidget(viewScene(target, child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(160, 80));
      await tester.pumpWidget(viewScene(target, child: child, width: 120));
      expect(viewSize(tester), const Size(120, 80));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(120, 100));
      await tester.pumpWidget(viewScene(target, child: child));
      expect(viewSize(tester), const Size(200, 100));
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      await _advance(tester, 25);
      expect(viewSize(tester), const Size(240, 120));
    });
  });

  group('轮廓中间值与可见结果', () {
    testWidgets('粗细、间距与颜色共同过渡，child 和 Row 兄弟位置保持不变', (tester) async {
      const childKey = ValueKey('outline-animation-child');
      const siblingKey = ValueKey('outline-animation-sibling');
      Widget scene(ElOutline outline) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElView(
                key: viewKey,
                style: _outlineStyle(outline),
                child: const SizedBox(key: childKey, width: 30, height: 20),
              ),
              const SizedBox(key: siblingKey, width: 30, height: 20),
            ],
          ),
        ),
      );
      await tester.pumpWidget(scene(const ElOutline(width: 4, color: _red)));
      final childPosition = tester.getTopLeft(find.byKey(childKey));
      final siblingPosition = tester.getTopLeft(find.byKey(siblingKey));
      await tester.pumpWidget(
        scene(const ElOutline(width: 12, color: _blue, offset: 8)),
      );
      await _advance(tester, 50);
      var pixels = await _borderPixels(tester, const [
        Offset(50, -11),
        Offset(50, -5),
        Offset(50, -13),
        Offset(50, -3),
      ]);
      _pixel(pixels[0], const Color(0xff800080));
      _pixel(pixels[1], const Color(0xff800080));
      _pixel(pixels[2], const Color(0x00000000));
      _pixel(pixels[3], const Color(0x00000000));
      expect(viewSize(tester), const Size(100, 60));
      expect(tester.getSize(find.byKey(childKey)), const Size(30, 20));
      expect(_childOffset(tester, childKey), Offset.zero);
      expect(tester.getTopLeft(find.byKey(childKey)), childPosition);
      expect(tester.getTopLeft(find.byKey(siblingKey)), siblingPosition);
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [
        Offset(50, -18),
        Offset(50, -6),
      ]);
      _pixel(pixels[0], _blue);
      _pixel(pixels[1], const Color(0x00000000));
      expect(tester.getTopLeft(find.byKey(childKey)), childPosition);
      expect(tester.getTopLeft(find.byKey(siblingKey)), siblingPosition);
    });

    testWidgets('null 双向过渡同时收放宽度与 offset，并淡入淡出可见颜色', (tester) async {
      const outline = ElOutline(width: 8, color: _red, offset: 8);
      await tester.pumpWidget(viewScene(_outlineStyle(null)));
      await tester.pumpWidget(viewScene(_outlineStyle(outline)));
      for (final fadingOut in [false, true]) {
        if (fadingOut) {
          await tester.pumpWidget(viewScene(_outlineStyle(null)));
        }
        await _advance(tester, 50);
        final pixels = await _borderPixels(tester, const [
          Offset(50, -6),
          Offset(50, -10),
          Offset(50, -2),
        ]);
        _pixel(pixels[0], const Color(0x80ff0000));
        _pixel(pixels[1], const Color(0x00000000));
        _pixel(pixels[2], const Color(0x00000000));
        await _advance(tester, 50);
      }
      final end = await _borderPixels(tester, const [
        Offset(50, 0),
        Offset(50, -1),
      ], offset: const Offset(32.5, 32.5));
      expect(end.every((color) => color.a == 0), isTrue);
    });

    testWidgets('半透明与带隐藏 RGB 的透明颜色互转，不混入透明端的蓝色', (tester) async {
      const visible = ElOutline(width: 8, color: Color(0x80ff0000), offset: 4);
      const hidden = ElOutline(width: 16, color: Color(0x000000ff), offset: 12);
      await tester.pumpWidget(viewScene(_outlineStyle(visible)));
      await tester.pumpWidget(viewScene(_outlineStyle(hidden)));
      await _advance(tester, 50);
      var pixels = await _borderPixels(tester, const [
        Offset(50, -12),
        Offset(50, -6),
      ]);
      _pixel(pixels[0], const Color(0x40ff0000));
      _pixel(pixels[1], const Color(0x00000000));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, -20)]);
      _pixel(pixels.single, const Color(0x00000000));
      await tester.pumpWidget(viewScene(_outlineStyle(visible)));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, -12)]);
      _pixel(pixels.single, const Color(0x40ff0000));
      await _advance(tester, 50);
    });

    testWidgets('三种渐变与纯色双向切换保持不透明，清空 shader 时终点不跳变', (tester) async {
      const gradients = <Gradient>[
        LinearGradient(colors: [_red, _blue], stops: [0.2, 0.8]),
        RadialGradient(
          colors: [_red, _blue],
          center: Alignment(-0.5, -0.5),
          radius: 1.2,
          stops: [0.2, 0.8],
        ),
        SweepGradient(
          colors: [_red, _blue],
          startAngle: 0.2,
          endAngle: 5.8,
          stops: [0.2, 0.8],
        ),
      ];
      const green = Color(0xff00ff00);
      const positions = [Offset(20, -8), Offset(80, -8)];
      for (var i = 0; i < gradients.length; i++) {
        final gradient = ElOutline(
          width: 8,
          color: green,
          gradient: gradients[i],
          offset: 4,
        );
        const solid = ElOutline(width: 8, color: green, offset: 4);
        await tester.pumpWidget(
          viewScene(_outlineStyle(gradient), key: ValueKey('gradient-$i')),
        );
        // 更换 key 仅隔开渐变类型，随后同一个 ElView 连续接受双向样式更新。
        await tester.pumpWidget(viewScene(_outlineStyle(gradient)));
        for (final toSolid in [true, false]) {
          await tester.pumpWidget(
            viewScene(_outlineStyle(toSolid ? solid : gradient)),
          );
          await _advance(tester, 50);
          var pixels = await _borderPixels(tester, positions);
          for (final pixel in pixels) {
            expect(pixel.a, closeTo(1, 2 / 255));
            expect(pixel.g, closeTo(0.5, 2 / 255));
            expect(pixel.r + pixel.b, closeTo(0.5, 3 / 255));
          }
          await _advance(tester, 49);
          final beforeEnd = await _borderPixels(tester, positions);
          await _advance(tester, 1);
          pixels = await _borderPixels(tester, positions);
          for (var point = 0; point < positions.length; point++) {
            expect(beforeEnd[point].a, closeTo(pixels[point].a, 2 / 255));
            expect(beforeEnd[point].r, closeTo(pixels[point].r, 4 / 255));
            expect(beforeEnd[point].g, closeTo(pixels[point].g, 4 / 255));
            expect(beforeEnd[point].b, closeTo(pixels[point].b, 4 / 255));
            if (toSolid) _pixel(pixels[point], green);
          }
        }
      }
    });

    testWidgets('decal 外域的纯色贡献连续淡入淡出，中断后从当前混合态接续', (tester) async {
      const gradients = <Gradient>[
        LinearGradient(
          begin: Alignment(-0.2, 0),
          end: Alignment(0.2, 0),
          colors: [_red, _blue],
          tileMode: TileMode.decal,
        ),
        RadialGradient(
          radius: 0.2,
          colors: [_red, _blue],
          tileMode: TileMode.decal,
        ),
        SweepGradient(
          startAngle: 0.5,
          endAngle: 1.5,
          colors: [_red, _blue],
          tileMode: TileMode.decal,
        ),
      ];
      const green = Color(0xff00ff00);
      const solid = ElOutline(width: 8, color: green, offset: 4);
      const red = ElOutline(width: 8, color: _red, offset: 4);
      const childKey = ValueKey('outline-decal-child');
      const child = SizedBox(key: childKey, width: 30, height: 20);
      Future<void> sample(Color expected) async => _pixel(
        (await _borderPixels(tester, const [Offset(20, -8)])).single,
        expected,
      );
      for (final gradient in gradients) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(viewScene(_outlineStyle(solid), child: child));
        final childPosition = tester.getTopLeft(find.byKey(childKey));
        final outline = ElOutline(width: 8, gradient: gradient, offset: 4);
        await sample(green);
        await tester.pumpWidget(
          viewScene(_outlineStyle(outline), child: child),
        );
        await _advance(tester, 1);
        await sample(green.withValues(alpha: 0.99));
        await _advance(tester, 49);
        await sample(green.withValues(alpha: 0.5));
        await _advance(tester, 49);
        await sample(green.withValues(alpha: 0.01));
        await _advance(tester, 1);
        await sample(const Color(0x00000000));

        await tester.pumpWidget(viewScene(_outlineStyle(solid), child: child));
        await _advance(tester, 1);
        await sample(green.withValues(alpha: 0.01));
        await _advance(tester, 49);
        await sample(green.withValues(alpha: 0.5));
        await _advance(tester, 49);
        await sample(green.withValues(alpha: 0.99));
        await _advance(tester, 1);
        await sample(green);

        await tester.pumpWidget(
          viewScene(_outlineStyle(outline), child: child),
        );
        await _advance(tester, 50);
        await sample(green.withValues(alpha: 0.5));
        await tester.pumpWidget(viewScene(_outlineStyle(red), child: child));
        await sample(green.withValues(alpha: 0.5));
        await _advance(tester, 1);
        await sample(
          const Color.from(
            alpha: 0.505,
            red: 0.01 / 0.505,
            green: 0.495 / 0.505,
            blue: 0,
          ),
        );
        await _advance(tester, 49);
        await sample(
          const Color.from(alpha: 0.75, red: 2 / 3, green: 1 / 3, blue: 0),
        );
        await _advance(tester, 50);
        await sample(_red);
        expect(viewSize(tester), const Size(100, 60));
        expect(tester.getSize(find.byKey(childKey)), const Size(30, 20));
        expect(tester.getTopLeft(find.byKey(childKey)), childPosition);
      }
    });

    testWidgets('方向性渐变与纯色双向过渡途中改向，颜色立即镜像且保持原尺寸截止时间', (tester) async {
      const gradient = ElOutline(
        width: 8,
        offset: 4,
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [_red, _blue],
        ),
      );
      const solid = ElOutline(width: 16, offset: 12, color: Color(0xff00ff00));
      const positions = [Offset(10, -14), Offset(89, -14)];
      await tester.pumpWidget(viewScene(_outlineStyle(gradient)));
      await tester.pumpWidget(viewScene(_outlineStyle(solid)));
      await _advance(tester, 50);
      var beforeDirection = await _borderPixels(tester, positions);
      expect(beforeDirection[0].r, greaterThan(beforeDirection[1].r));
      for (final pixel in beforeDirection) {
        expect(pixel.a, closeTo(1, 2 / 255));
        expect(pixel.g, closeTo(0.5, 2 / 255));
      }
      await tester.pumpWidget(
        viewScene(_outlineStyle(solid), direction: TextDirection.rtl),
      );
      var afterDirection = await _borderPixels(tester, positions);
      _pixel(afterDirection[0], beforeDirection[1]);
      _pixel(afterDirection[1], beforeDirection[0]);
      await _advance(tester, 25);
      var pixels = await _borderPixels(tester, positions);
      for (final pixel in pixels) {
        expect(pixel.a, closeTo(1, 2 / 255));
        expect(pixel.g, closeTo(0.75, 2 / 255));
        expect(pixel.r + pixel.b, closeTo(0.25, 3 / 255));
      }
      await _advance(tester, 25);
      pixels = await _borderPixels(tester, const [
        Offset(50, -26),
        Offset(50, -30),
        Offset(50, -10),
      ]);
      _pixel(pixels[0], const Color(0xff00ff00));
      _pixel(pixels[1], const Color(0x00000000));
      _pixel(pixels[2], const Color(0x00000000));

      await tester.pumpWidget(
        viewScene(_outlineStyle(gradient), direction: TextDirection.rtl),
      );
      await _advance(tester, 50);
      beforeDirection = await _borderPixels(tester, positions);
      expect(beforeDirection[0].r, lessThan(beforeDirection[1].r));
      await tester.pumpWidget(viewScene(_outlineStyle(gradient)));
      afterDirection = await _borderPixels(tester, positions);
      _pixel(afterDirection[0], beforeDirection[1]);
      _pixel(afterDirection[1], beforeDirection[0]);
      await _advance(tester, 25);
      pixels = await _borderPixels(tester, positions);
      for (final pixel in pixels) {
        expect(pixel.a, closeTo(1, 2 / 255));
        expect(pixel.g, closeTo(0.25, 2 / 255));
        expect(pixel.r + pixel.b, closeTo(0.75, 3 / 255));
      }
      await _advance(tester, 25);
      pixels = await _borderPixels(tester, const [
        Offset(10, -8),
        Offset(50, -14),
        Offset(50, -2),
      ]);
      _pixel(pixels[0], const Color(0xffd60029));
      _pixel(pixels[1], const Color(0x00000000));
      _pixel(pixels[2], const Color(0x00000000));
      expect(viewSize(tester), const Size(100, 60));
    });

    testWidgets('渐变方向与 stops 在过渡中间帧共同变化', (tester) async {
      const a = LinearGradient(colors: [_red, _blue], stops: [0, 0.6]);
      const b = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_red, _blue],
        stops: [0.4, 1],
      );
      ElOutline outline(Gradient gradient) =>
          ElOutline(width: 8, offset: 4, gradient: gradient);
      await tester.pumpWidget(viewScene(_outlineStyle(outline(a))));
      await tester.pumpWidget(viewScene(_outlineStyle(outline(b))));
      await _advance(tester, 50);
      final pixels = await _borderPixels(tester, const [
        Offset(10, -8),
        Offset(90, -8),
        Offset(50, -8),
      ]);
      _pixel(pixels[0], _red);
      // 原生渐变合并两端 stops 后采样颜色，中间帧并非直接平均 stop 位置。
      _pixel(pixels[1], const Color(0xff4100be));
      _pixel(pixels[2], const Color(0xffd2002d));
      await _advance(tester, 50);
      final end = await _borderPixels(tester, const [
        Offset(10, -8),
        Offset(90, -8),
      ]);
      _pixel(end[0], _red);
      _pixel(end[1], _red);
    });

    testWidgets('真正 null 与渐变双向过渡保持渐变色相并同时改变轮廓范围', (tester) async {
      const gradient = ElOutline(
        width: 8,
        offset: 4,
        gradient: LinearGradient(colors: [_red, _blue]),
      );
      await tester.pumpWidget(viewScene(_outlineStyle(null)));
      await tester.pumpWidget(viewScene(_outlineStyle(gradient)));
      for (final fadingOut in [false, true]) {
        if (fadingOut) {
          await tester.pumpWidget(viewScene(_outlineStyle(null)));
        }
        await _advance(tester, 50);
        final pixels = await _borderPixels(tester, const [
          Offset(20, -4),
          Offset(80, -4),
          Offset(50, -8),
        ]);
        for (final pixel in pixels.take(2)) {
          expect(pixel.a, closeTo(0.5, 2 / 255));
          expect(pixel.r + pixel.b, closeTo(1, 3 / 255));
          expect(pixel.g, closeTo(0, 2 / 255));
        }
        expect(pixels[0].r, greaterThan(pixels[1].r));
        expect(pixels[0].b, lessThan(pixels[1].b));
        _pixel(pixels[2], const Color(0x00000000));
        await _advance(tester, 50);
      }
      final end = await _borderPixels(tester, const [Offset(50, 0)]);
      _pixel(end.single, const Color(0x00000000));
    });

    testWidgets('独立 outline 通道遵守延迟、中断接续、移除配置及零时长延迟', (tester) async {
      const delayed = [
        ElTransition.field(
          ElTransitionField.outline,
          Duration(milliseconds: 100),
          Curves.linear,
          Duration(milliseconds: 50),
        ),
      ];
      const red = ElOutline(width: 4, color: _red);
      const blue = ElOutline(width: 12, offset: 8, color: _blue);
      const green = ElOutline(width: 20, offset: 16, color: Color(0xff00ff00));
      await tester.pumpWidget(
        viewScene(_outlineStyle(red, transitions: delayed)),
      );
      await tester.pumpWidget(
        viewScene(_outlineStyle(blue, transitions: delayed)),
      );
      await _advance(tester, 50);
      var pixels = await _borderPixels(tester, const [
        Offset(50, -2),
        Offset(50, -6),
      ]);
      _pixel(pixels[0], _red);
      _pixel(pixels[1], const Color(0x00000000));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, -6)]);
      _pixel(pixels.single, const Color(0xff800080));
      await tester.pumpWidget(
        viewScene(_outlineStyle(green, transitions: delayed)),
      );
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, -6)]);
      _pixel(pixels.single, const Color(0xff800080));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, -14)]);
      _pixel(pixels.single, const Color(0xff408040));
      await tester.pumpWidget(
        viewScene(_outlineStyle(green, transitions: null)),
      );
      pixels = await _borderPixels(tester, const [Offset(50, -24)]);
      _pixel(pixels.single, const Color(0xff00ff00));
      const instant = [
        ElTransition.field(
          ElTransitionField.outline,
          Duration.zero,
          Curves.linear,
          Duration(milliseconds: 30),
        ),
      ];
      await tester.pumpWidget(
        viewScene(_outlineStyle(red, transitions: instant)),
      );
      await _advance(tester, 29);
      pixels = await _borderPixels(tester, const [Offset(50, -24)]);
      _pixel(pixels.single, const Color(0xff00ff00));
      await _advance(tester, 1);
      pixels = await _borderPixels(tester, const [
        Offset(50, -2),
        Offset(50, -8),
      ]);
      _pixel(pixels[0], _red);
      _pixel(pixels[1], const Color(0x00000000));
    });

    testWidgets('宽度负过冲不会出现 hairline，终点恢复实际轮廓', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.outline,
          Duration(milliseconds: 100),
          _NegativeCurve(),
        ),
      ];
      await tester.pumpWidget(
        viewScene(
          _outlineStyle(
            const ElOutline(width: 4, color: _red),
            transitions: transitions,
          ),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          _outlineStyle(
            const ElOutline(width: 12, color: _blue),
            transitions: transitions,
          ),
        ),
      );
      await _advance(tester, 75);
      var pixels = await _borderPixels(tester, const [
        Offset(50, 0),
        Offset(50, -1),
        Offset(0, 30),
      ], offset: const Offset(32.5, 32.5));
      expect(pixels.every((color) => color.a == 0), isTrue);
      await _advance(tester, 25);
      pixels = await _borderPixels(tester, const [Offset(50, -10)]);
      _pixel(pixels.single, _blue);
    });

    testWidgets('负 offset 使中心轮廓塌缩时隐藏，过渡到有效范围后重新出现', (tester) async {
      ElStyle style(num offset) =>
          _outlineStyle(ElOutline(width: 8, color: _red, offset: offset));
      await tester.pumpWidget(viewScene(style(-60)));
      var pixels = await _borderPixels(tester, const [
        Offset(50, 24),
        Offset(50, 30),
      ]);
      expect(pixels.every((color) => color.a == 0), isTrue);
      await tester.pumpWidget(viewScene(style(0)));
      await _advance(tester, 25);
      pixels = await _borderPixels(tester, const [Offset(50, 24)]);
      _pixel(pixels.single, const Color(0x00000000));
      await _advance(tester, 25);
      pixels = await _borderPixels(tester, const [
        Offset(50, 24),
        Offset(50, 0),
      ]);
      _pixel(pixels[0], _red);
      _pixel(pixels[1], const Color(0x00000000));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, -4)]);
      _pixel(pixels.single, _red);
      expect(viewSize(tester), const Size(100, 60));
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto、百分比和圆角边距联动时，轮廓位于 child 裁剪及边框之上', (tester) async {
      const childKey = ValueKey('outline-geometry-child');
      const child = SizedBox(
        key: childKey,
        width: 80,
        height: 40,
        child: ColoredBox(color: Color(0xff00ff00)),
      );
      ElStyle style(bool target) => ElStyle(
        width: target ? '50%' : null,
        padding: EdgeInsets.all(target ? 20 : 10),
        margin: EdgeInsets.all(target ? 10 : 5),
        borderRadius: BorderRadius.circular(target ? 40 : 0),
        border: Border.all(
          color: const Color(0xff000000),
          width: 12,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
        outline: ElOutline(
          width: target ? 12 : 4,
          offset: target ? 8 : 0,
          color: target ? _blue : _red,
        ),
        clipBehavior: Clip.antiAlias,
        transitions: _linear,
      );
      await tester.pumpWidget(viewScene(style(false), child: child));
      expect(viewSize(tester), const Size(110, 70));
      await tester.pumpWidget(viewScene(style(true), child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(161.25, 85));
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      expect(_childOffset(tester, childKey), const Offset(22.5, 22.5));
      _clip(
        tester,
        Clip.antiAlias,
        radius: BorderRadius.circular(20),
        rect: const Rect.fromLTWH(7.5, 7.5, 146.25, 70),
      );
      final pixels = await _borderPixels(tester, const [
        Offset(82, -1),
        Offset(82, 5),
        Offset(-3, -3),
        Offset(40, 40),
      ]);
      _pixel(pixels[0], const Color(0xff800080));
      _pixel(pixels[1], const Color(0xff000000));
      _pixel(pixels[2], const Color(0x00000000));
      _pixel(pixels[3], const Color(0xff00ff00));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(210, 100));
      expect(tester.takeException(), isNull);
    });
  });

  group('边框中间值与可见结果', () {
    testWidgets('宽度、颜色和内外描边共同插值，边框不改变布局', (tester) async {
      const childKey = ValueKey('border-animation-child');
      const siblingKey = ValueKey('border-animation-sibling');
      const child = SizedBox(key: childKey, width: 30, height: 20);
      Widget scene(BoxBorder border) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElView(key: viewKey, style: _borderStyle(border), child: child),
              const SizedBox(key: siblingKey, width: 30, height: 20),
            ],
          ),
        ),
      );
      await tester.pumpWidget(scene(Border.all(color: _red, width: 4)));
      final childPosition = tester.getTopLeft(find.byKey(childKey));
      final siblingPosition = tester.getTopLeft(find.byKey(siblingKey));
      await tester.pumpWidget(
        scene(
          Border.all(
            color: _blue,
            width: 12,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      );
      await _advance(tester, 50);
      final pixels = await _borderPixels(tester, const [
        Offset(50, -3),
        Offset(50, 3),
        Offset(50, -5),
        Offset(50, 5),
      ]);
      _pixel(pixels[0], const Color(0xff800080));
      _pixel(pixels[1], const Color(0xff800080));
      _pixel(pixels[2], const Color(0x00000000));
      _pixel(pixels[3], const Color(0x00000000));
      expect(viewSize(tester), const Size(100, 60));
      expect(tester.getSize(find.byKey(childKey)), const Size(30, 20));
      expect(_childOffset(tester, childKey), Offset.zero);
      expect(tester.getTopLeft(find.byKey(childKey)), childPosition);
      expect(tester.getTopLeft(find.byKey(siblingKey)), siblingPosition);
      await _advance(tester, 50);
      final end = await _borderPixels(tester, const [
        Offset(50, -10),
        Offset(50, 2),
      ]);
      _pixel(end[0], _blue);
      _pixel(end[1], const Color(0x00000000));
      expect(tester.getTopLeft(find.byKey(childKey)), childPosition);
      expect(tester.getTopLeft(find.byKey(siblingKey)), siblingPosition);
    });

    for (final hairline in [false, true]) {
      testWidgets('null 与${hairline ? '细线' : '外描边'}双向过渡保留可见颜色和位置', (
        tester,
      ) async {
        final border = Border.all(
          color: _red,
          width: hairline ? 0 : 8,
          strokeAlign: BorderSide.strokeAlignOutside,
        );
        final offset = hairline
            ? const Offset(32.5, 32.5)
            : const Offset(32, 32);
        final positions = hairline
            ? const [Offset(50, 0), Offset(50, 2)]
            : const [Offset(50, -2), Offset(50, 2), Offset(50, -6)];
        await tester.pumpWidget(viewScene(_borderStyle(null)));
        await tester.pumpWidget(viewScene(_borderStyle(border)));
        await _advance(tester, 50);
        var pixels = await _borderPixels(tester, positions, offset: offset);
        _pixel(pixels.first, const Color(0x80ff0000));
        for (final pixel in pixels.skip(1)) {
          _pixel(pixel, const Color(0x00000000));
        }
        await _advance(tester, 50);
        await tester.pumpWidget(viewScene(_borderStyle(null)));
        await _advance(tester, 50);
        pixels = await _borderPixels(tester, positions, offset: offset);
        _pixel(pixels.first, const Color(0x80ff0000));
        for (final pixel in pixels.skip(1)) {
          _pixel(pixel, const Color(0x00000000));
        }
        await _advance(tester, 50);
        pixels = await _borderPixels(tester, positions, offset: offset);
        expect(pixels.every((color) => color.a == 0), isTrue);
      });
    }

    testWidgets('半透明与带隐藏 RGB 的透明 solid 互转，保留宽度并按预乘颜色淡出', (tester) async {
      final visible = Border.all(color: const Color(0x80ff0000), width: 8);
      final transparent = Border.all(color: const Color(0x000000ff), width: 16);
      await tester.pumpWidget(viewScene(_borderStyle(visible)));
      await tester.pumpWidget(viewScene(_borderStyle(transparent)));
      await _advance(tester, 50);
      var pixels = await _borderPixels(tester, const [
        Offset(50, 10),
        Offset(50, 13),
      ]);
      _pixel(pixels[0], const Color(0x40ff0000));
      _pixel(pixels[1], const Color(0x00000000));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, 2)]);
      _pixel(pixels.single, const Color(0x00000000));
      await tester.pumpWidget(viewScene(_borderStyle(visible)));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, 10)]);
      _pixel(pixels.single, const Color(0x40ff0000));
      await _advance(tester, 50);
    });

    testWidgets('单边 none 的隐藏宽度和颜色不污染 solid 中间值，描边位置仍连续变化', (tester) async {
      const hidden = Border(
        top: BorderSide(
          color: _blue,
          width: 100,
          style: BorderStyle.none,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      );
      const visible = Border(top: BorderSide(color: _red, width: 8));
      await tester.pumpWidget(viewScene(_borderStyle(hidden)));
      await tester.pumpWidget(viewScene(_borderStyle(visible)));
      await _advance(tester, 50);
      var pixels = await _borderPixels(tester, const [
        Offset(50, -1),
        Offset(50, 1),
        Offset(50, 3),
      ]);
      _pixel(pixels[0], const Color(0x80ff0000));
      _pixel(pixels[1], const Color(0x80ff0000));
      _pixel(pixels[2], const Color(0x00000000));
      await _advance(tester, 50);
      await tester.pumpWidget(viewScene(_borderStyle(hidden)));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, -1)]);
      _pixel(pixels.single, const Color(0x80ff0000));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, 0)]);
      _pixel(pixels.single, const Color(0x00000000));
    });

    testWidgets('非均匀四边分别插值宽度、透明度和细线，不借用相邻边结果', (tester) async {
      const a = Border(
        top: BorderSide(color: _red, width: 4),
        right: BorderSide(color: Color(0xff00ff00), width: 8),
        left: BorderSide(color: Color(0x80ff0000), width: 20),
      );
      const b = Border(
        top: BorderSide(color: _blue, width: 12),
        right: BorderSide(color: Color(0xff00ff00), width: 0),
        bottom: BorderSide(color: _blue, width: 8),
        left: BorderSide(color: Color(0x80ff0000), width: 4),
      );
      await tester.pumpWidget(viewScene(_borderStyle(a)));
      await tester.pumpWidget(viewScene(_borderStyle(b)));
      await _advance(tester, 50);
      final pixels = await _borderPixels(tester, const [
        Offset(50, 5),
        Offset(98, 30),
        Offset(50, 58),
        Offset(8, 30),
        Offset(50, 30),
      ]);
      _pixel(pixels[0], const Color(0xff800080));
      _pixel(pixels[1], const Color(0xff00ff00));
      _pixel(pixels[2], const Color(0x800000ff));
      _pixel(pixels[3], const Color(0x80ff0000));
      _pixel(pixels[4], const Color(0x00000000));
      await _advance(tester, 50);
    });

    testWidgets('BorderDirectional 的方向切换从当前物理边框接续', (tester) async {
      final style = _borderStyle(
        const BorderDirectional(
          start: BorderSide(color: _red, width: 8),
          end: BorderSide(color: _blue, width: 4),
        ),
      );
      await tester.pumpWidget(viewScene(style));
      await tester.pumpWidget(viewScene(style, direction: TextDirection.rtl));
      var pixels = await _borderPixels(tester, const [
        Offset(2, 30),
        Offset(98, 30),
      ]);
      _pixel(pixels[0], _red);
      _pixel(pixels[1], _blue);
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [
        Offset(4, 30),
        Offset(95, 30),
      ]);
      _pixel(pixels[0], const Color(0xff800080));
      _pixel(pixels[1], const Color(0xff800080));
      await tester.pumpWidget(viewScene(style));
      pixels = await _borderPixels(tester, const [Offset(4, 30)]);
      _pixel(pixels.single, const Color(0xff800080));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [
        Offset(4, 30),
        Offset(98, 30),
      ]);
      _pixel(pixels[0], const Color(0xffbf0040));
      _pixel(pixels[1], const Color(0xff4000bf));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [
        Offset(6, 30),
        Offset(98, 30),
      ]);
      _pixel(pixels[0], _red);
      _pixel(pixels[1], _blue);
    });

    testWidgets('边框独立配置的 delay、中断、移除与零时长延迟遵守可见时间线', (tester) async {
      const delayed = [
        ElTransition.field(
          ElTransitionField.border,
          Duration(milliseconds: 100),
          Curves.linear,
          Duration(milliseconds: 50),
        ),
      ];
      final red = Border.all(color: _red, width: 4);
      final blue = Border.all(color: _blue, width: 12);
      final green = Border.all(color: const Color(0xff00ff00), width: 20);
      await tester.pumpWidget(
        viewScene(_borderStyle(red, transitions: delayed)),
      );
      await tester.pumpWidget(
        viewScene(_borderStyle(blue, transitions: delayed)),
      );
      await _advance(tester, 50);
      var pixels = await _borderPixels(tester, const [
        Offset(50, 2),
        Offset(50, 5),
      ]);
      _pixel(pixels[0], _red);
      _pixel(pixels[1], const Color(0x00000000));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, 5)]);
      _pixel(pixels.single, const Color(0xff800080));
      await tester.pumpWidget(
        viewScene(_borderStyle(green, transitions: delayed)),
      );
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, 5)]);
      _pixel(pixels.single, const Color(0xff800080));
      await _advance(tester, 50);
      pixels = await _borderPixels(tester, const [Offset(50, 10)]);
      _pixel(pixels.single, const Color(0xff408040));
      await tester.pumpWidget(
        viewScene(_borderStyle(green, transitions: null)),
      );
      pixels = await _borderPixels(tester, const [Offset(50, 18)]);
      _pixel(pixels.single, const Color(0xff00ff00));
      const instant = [
        ElTransition.field(
          ElTransitionField.border,
          Duration.zero,
          Curves.linear,
          Duration(milliseconds: 30),
        ),
      ];
      await tester.pumpWidget(
        viewScene(_borderStyle(red, transitions: instant)),
      );
      await _advance(tester, 29);
      pixels = await _borderPixels(tester, const [Offset(50, 10)]);
      _pixel(pixels.single, const Color(0xff00ff00));
      await _advance(tester, 1);
      pixels = await _borderPixels(tester, const [
        Offset(50, 2),
        Offset(50, 10),
      ]);
      _pixel(pixels[0], _red);
      _pixel(pixels[1], const Color(0x00000000));
    });

    testWidgets('auto 与百分比、边距和圆角联动时，外描边始终绘制在 child 裁剪之外', (tester) async {
      const childKey = ValueKey('border-geometry-child');
      const child = SizedBox(
        key: childKey,
        width: 80,
        height: 40,
        child: ColoredBox(color: Color(0xff00ff00)),
      );
      ElStyle style(bool target) => ElStyle(
        width: target ? '50%' : null,
        padding: EdgeInsets.all(target ? 20 : 10),
        margin: EdgeInsets.all(target ? 10 : 5),
        borderRadius: BorderRadius.circular(target ? 40 : 0),
        border: Border.all(
          color: target ? _blue : _red,
          width: target ? 12 : 4,
          strokeAlign: target
              ? BorderSide.strokeAlignOutside
              : BorderSide.strokeAlignInside,
        ),
        clipBehavior: Clip.antiAlias,
        transitions: _linear,
      );
      await tester.pumpWidget(viewScene(style(false), child: child));
      expect(viewSize(tester), const Size(110, 70));
      await tester.pumpWidget(viewScene(style(true), child: child));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(161.25, 85));
      expect(tester.getSize(find.byKey(childKey)), const Size(80, 40));
      expect(_childOffset(tester, childKey), const Offset(22.5, 22.5));
      _clip(
        tester,
        Clip.antiAlias,
        radius: BorderRadius.circular(20),
        rect: const Rect.fromLTWH(7.5, 7.5, 146.25, 70),
      );
      final pixels = await _borderPixels(tester, const [
        Offset(82, 5),
        Offset(5, 5),
        Offset(40, 40),
      ]);
      _pixel(pixels[0], const Color(0xff800080));
      _pixel(pixels[1], const Color(0x00000000));
      _pixel(pixels[2], const Color(0xff00ff00));
      await _advance(tester, 50);
      expect(viewSize(tester), const Size(210, 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('负过冲导致宽度小于零时不退化成意外细线，终点恢复目标边框', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.border,
          Duration(milliseconds: 100),
          _NegativeCurve(),
        ),
      ];
      await tester.pumpWidget(
        viewScene(
          _borderStyle(
            Border.all(color: _red, width: 4),
            transitions: transitions,
          ),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          _borderStyle(
            Border.all(color: _blue, width: 12),
            transitions: transitions,
          ),
        ),
      );
      await _advance(tester, 75);
      final positions = const [Offset(50, 0), Offset(50, 2), Offset(0, 30)];
      var pixels = await _borderPixels(
        tester,
        positions,
        offset: const Offset(32.5, 32.5),
      );
      expect(pixels.every((color) => color.a == 0), isTrue);
      expect(tester.takeException(), isNull);
      await _advance(tester, 25);
      pixels = await _borderPixels(tester, const [Offset(50, 10)]);
      _pixel(pixels.single, _blue);
    });
  });

  group('圆角中间值', () {
    testWidgets('圆角从零过渡，中断和清空时画面保持连续', (tester) async {
      await tester.pumpWidget(viewScene(_radiusStyle(null)));
      await tester.pumpWidget(
        viewScene(_radiusStyle(BorderRadius.circular(40))),
      );
      _background(tester, null);
      await tester.pump(const Duration(milliseconds: 25));
      _background(tester, BorderRadius.circular(10));
      await tester.pumpWidget(
        viewScene(_radiusStyle(BorderRadius.circular(20))),
      );
      _background(tester, BorderRadius.circular(10));
      await tester.pump(const Duration(milliseconds: 50));
      _background(tester, BorderRadius.circular(15));
      await tester.pump(const Duration(milliseconds: 50));
      _background(tester, BorderRadius.circular(20));
      await tester.pumpWidget(viewScene(_radiusStyle(null)));
      await tester.pump(const Duration(milliseconds: 50));
      _background(tester, BorderRadius.circular(10));
      await tester.pump(const Duration(milliseconds: 50));
      _background(tester, null);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
    });

    for (final end in [
      const Radius.elliptical(20, 20),
      const Radius.elliptical(20, 0),
    ]) {
      testWidgets('退化椭圆角过渡到 $end 时中间帧可见', (tester) async {
        await tester.pumpWidget(
          viewScene(
            _radiusStyle(const BorderRadius.all(Radius.elliptical(0, 20))),
          ),
        );
        _background(tester, null);
        await tester.pumpWidget(viewScene(_radiusStyle(BorderRadius.all(end))));
        _background(tester, null);
        await tester.pump(const Duration(milliseconds: 50));
        _background(
          tester,
          BorderRadius.all(Radius.elliptical(10, (20 + end.y) / 2)),
        );
        expect(_hits(tester, const Offset(1, 1)), isFalse);
        await tester.pump(const Duration(milliseconds: 50));
        _background(tester, end.y == 0 ? null : BorderRadius.all(end));
      });
    }

    testWidgets('颜色、宽高与较慢圆角联动时每个时刻显示正确结果', (tester) async {
      const transitions = [
        ElTransition.all(Duration(milliseconds: 200), Curves.linear),
        ElTransition.field(
          ElTransitionField.width,
          Duration(milliseconds: 100),
          Curves.linear,
        ),
        ElTransition.field(
          ElTransitionField.height,
          Duration(milliseconds: 100),
          Curves.linear,
        ),
      ];
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 100,
            height: 60,
            backgroundColor: _red,
            borderRadius: BorderRadius.all(Radius.circular(110)),
            transitions: transitions,
          ),
        ),
      );
      await tester.pumpWidget(
        viewScene(
          const ElStyle(
            width: 200,
            height: 100,
            backgroundColor: _blue,
            borderRadius: BorderRadius.all(Radius.circular(30)),
            transitions: transitions,
          ),
        ),
      );
      for (final (size, radius, progress) in [
        (const Size(150, 80), 40.0, .25),
        (const Size(200, 100), 50.0, .5),
        (const Size(200, 100), 50.0, .75),
        (const Size(200, 100), 30.0, 1.0),
      ]) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(viewSize(tester), size);
        _background(
          tester,
          BorderRadius.circular(radius),
          rect: Offset.zero & size,
          color: Color.lerp(_red, _blue, progress)!,
        );
      }
    });

    testWidgets('延迟开始前保持矩形，结束等待后显示正确插值', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.borderRadius,
          Duration(milliseconds: 100),
          Curves.linear,
          Duration(milliseconds: 50),
        ),
      ];
      await tester.pumpWidget(
        viewScene(_radiusStyle(null).copyWith(transitions: transitions)),
      );
      await tester.pumpWidget(
        viewScene(
          _radiusStyle(BorderRadius.circular(20))
              .copyWith(transitions: transitions),
        ),
      );
      await tester.pump(const Duration(milliseconds: 49));
      _background(tester, null);
      await tester.pump(const Duration(milliseconds: 1));
      _background(tester, null);
      await tester.pump(const Duration(milliseconds: 50));
      _background(tester, BorderRadius.circular(10));
      await tester.pump(const Duration(milliseconds: 50));
      _background(tester, BorderRadius.circular(20));
    });

    testWidgets('负过冲帧显示方角，过渡结束显示精确椭圆角', (tester) async {
      const transitions = [
        ElTransition.field(
          ElTransitionField.borderRadius,
          Duration(milliseconds: 100),
          _NegativeCurve(),
        ),
      ];
      const radius = BorderRadius.only(
        topLeft: Radius.elliptical(10, 20),
        bottomRight: Radius.elliptical(30, 40),
      );
      await tester.pumpWidget(
        viewScene(_radiusStyle(null).copyWith(transitions: transitions)),
      );
      await tester.pumpWidget(
        viewScene(_radiusStyle(radius).copyWith(transitions: transitions)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      _background(tester, null);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      _background(tester, radius);
      expect(_hits(tester, const Offset(1, 1)), isFalse);
    });
  });

  group('裁剪与动画联动', () {
    testWidgets('动画中打开和关闭裁剪后圆角仍按原截止时间显示', (tester) async {
      await tester.pumpWidget(
        viewScene(
          _clipStyle(radius: null, transitions: _linear),
          child: _overflow,
        ),
      );
      await tester.pumpWidget(
        viewScene(_clipStyle(transitions: _linear), child: _overflow),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        viewBox(tester),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 100, 60),
            const Radius.circular(15),
          ),
          color: _red,
        ),
      );
      await tester.pumpWidget(
        viewScene(
          _clipStyle(clip: Clip.hardEdge, transitions: _linear),
          child: _overflow,
        ),
      );
      _clip(tester, Clip.hardEdge, radius: BorderRadius.circular(15));
      expect(_hits(tester, const Offset(1, 1)), isFalse);
      await tester.pump(const Duration(milliseconds: 25));
      _clip(tester, Clip.hardEdge, radius: BorderRadius.circular(22.5));
      await tester.pumpWidget(
        viewScene(_clipStyle(transitions: _linear), child: _overflow),
      );
      _clip(tester, Clip.none);
      expect(_hits(tester, const Offset(1, 1)), isTrue);
      await tester.pump(const Duration(milliseconds: 25));
      expect(
        viewBox(tester),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 100, 60),
            const Radius.circular(30),
          ),
          color: _red,
        ),
      );
    });

    testWidgets('宽高与圆角动画共同决定裁剪，清空圆角后变为矩形', (tester) async {
      ElStyle style(double width, double height, BorderRadius? radius) =>
          ElStyle(
            width: width,
            height: height,
            backgroundColor: _red,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            transitions: _linear,
          );
      await tester.pumpWidget(
        viewScene(style(100, 60, BorderRadius.circular(110))),
      );
      await tester.pumpWidget(
        viewScene(style(200, 100, BorderRadius.circular(30))),
      );
      for (final (size, radius) in [
        (const Size(150, 80), 40.0),
        (const Size(200, 100), 30.0),
      ]) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(viewSize(tester), size);
        _clip(
          tester,
          Clip.antiAlias,
          radius: BorderRadius.circular(radius),
          rect: Offset.zero & size,
        );
        expect(
          viewBox(tester),
          paints..rect(rect: Offset.zero & size, color: _red),
        );
      }
      await tester.pumpWidget(viewScene(style(200, 100, null)));
      await tester.pump(const Duration(milliseconds: 50));
      _clip(
        tester,
        Clip.antiAlias,
        radius: BorderRadius.circular(15),
        rect: const Rect.fromLTWH(0, 0, 200, 100),
      );
      await tester.pump(const Duration(milliseconds: 50));
      _clip(tester, Clip.antiAlias, rect: const Rect.fromLTWH(0, 0, 200, 100));
      expect(_hits(tester, const Offset(1, 1)), isTrue);
    });
  });
}
