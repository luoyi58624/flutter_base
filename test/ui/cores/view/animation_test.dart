import 'paint_recording.dart';

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_base/src/ui/utils/internal/bit_mask.dart';
import 'package:flutter_base/src/ui/cores/view/style/resolved/builder.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _directionalApp(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

FieldAnimation _anim(ElTransitionField field) => FieldAnimation(
  field: field,
  from: const Color(0xFF000000),
  to: const Color(0xFFFFFFFF),
  duration: const Duration(milliseconds: 200),
);

Map<ElTransitionField, (Object?, Object?)> _transitionSamples() => {
  ElTransitionField.color: (const Color(0xFF000000), const Color(0xFFFFFFFF)),
  ElTransitionField.fontSize: (12.0, 20.0),
  ElTransitionField.fontWeight: (FontWeight.w400, FontWeight.w700),
  ElTransitionField.lineHeight: (1.0, 1.5),
  ElTransitionField.letterSpacing: (0.0, 2.0),
  ElTransitionField.wordSpacing: (0.0, 4.0),
  ElTransitionField.textShadow: (
    const <Shadow>[Shadow(color: Color(0x33000000), blurRadius: 2)],
    const <Shadow>[Shadow(color: Color(0x66000000), blurRadius: 8)],
  ),
  ElTransitionField.decorationColor: (const Color(0xFF000000), const Color(0xFFFF0000)),
  ElTransitionField.decorationThickness: (1.0, 2.0),
  ElTransitionField.textBackgroundColor: (const Color(0x00FFFFFF), const Color(0xFFFFFF00)),
  ElTransitionField.width: (100, 200),
  ElTransitionField.height: (40, 80),
  ElTransitionField.widthFactor: (0.5, 1.0),
  ElTransitionField.heightFactor: (0.25, 1.0),
  ElTransitionField.bgColor: (const Color(0xFF000000), const Color(0xFFFFFFFF)),
  ElTransitionField.padding: (EdgeInsets.zero, const EdgeInsets.all(8)),
  ElTransitionField.margin: (EdgeInsets.zero, const EdgeInsets.all(12)),
  ElTransitionField.alignment: (Alignment.topLeft, Alignment.bottomRight),
  ElTransitionField.border: (
    const ElBorder.fromSide(ElBorderSide(color: Color(0xFF000000), width: 1)),
    const ElBorder.fromSide(ElBorderSide(color: Color(0xFFFF0000), width: 4)),
  ),
  ElTransitionField.borderRadius: (BorderRadius.zero, const BorderRadius.all(Radius.elliptical(12, 12))),
  ElTransitionField.boxShadow: (
    const <BoxShadow>[BoxShadow(color: Color(0x33000000), blurRadius: 2)],
    const <BoxShadow>[BoxShadow(color: Color(0x66000000), blurRadius: 12)],
  ),
  ElTransitionField.minWidth: (80, 120),
  ElTransitionField.maxWidth: (200, 320),
  ElTransitionField.minHeight: (24, 48),
  ElTransitionField.maxHeight: (80, 120),
  ElTransitionField.opacity: (1.0, 0.5),
  ElTransitionField.transform: (const ElTransform.scale(1), const ElTransform.scale(1.2)),
  ElTransitionField.transformAlignment: (Alignment.topLeft, Alignment.center),
  ElTransitionField.gradient: (
    const LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF0000FF)]),
    const LinearGradient(colors: [Color(0xFF00FF00), Color(0xFFFFFF00)]),
  ),
  ElTransitionField.textGradient: (
    const ElLinearGradient(angle: 90, colors: [Color(0xFFFF0000), Color(0xFF0000FF)]),
    const ElLinearGradient(angle: 90, colors: [Color(0xFF00FF00), Color(0xFFFFFF00)]),
  ),
  ElTransitionField.outline: (
    const ElOutline(color: Color(0xFF000000), width: 1, offset: 0),
    const ElOutline(color: Color(0xFF0000FF), width: 3, offset: 6),
  ),
  ElTransitionField.aspectRatio: (1.0, 16 / 9),
  ElTransitionField.iconSize: (12.0, 20.0),
  ElTransitionField.iconColor: (const Color(0xFF000000), const Color(0xFF409EFF)),
  ElTransitionField.filter: (const ElFilter(blur: 2), const ElFilter(blur: 12)),
  ElTransitionField.backdropFilter: (const ElFilter(blur: 4, saturate: 1.0), const ElFilter(blur: 24, saturate: 1.6)),
};

ElStyle _styleFor(ElTransitionField field, Object? value) {
  final transition = ElTransition.field(field, const Duration(milliseconds: 200));
  switch (field) {
    case ElTransitionField.color:
      return ElStyle(color: value as Color?, transitions: [transition]);
    case ElTransitionField.fontSize:
      return ElStyle(fontSize: value as double?, transitions: [transition]);
    case ElTransitionField.fontWeight:
      return ElStyle(fontWeight: value as FontWeight?, transitions: [transition]);
    case ElTransitionField.lineHeight:
      return ElStyle(lineHeight: value as double?, transitions: [transition]);
    case ElTransitionField.letterSpacing:
      return ElStyle(letterSpacing: value as double?, transitions: [transition]);
    case ElTransitionField.wordSpacing:
      return ElStyle(wordSpacing: value as double?, transitions: [transition]);
    case ElTransitionField.textShadow:
      return ElStyle(textShadow: value as List<Shadow>?, transitions: [transition]);
    case ElTransitionField.decorationColor:
      return ElStyle(decorationColor: value as Color?, transitions: [transition]);
    case ElTransitionField.decorationThickness:
      return ElStyle(decorationThickness: value as double?, transitions: [transition]);
    case ElTransitionField.textBackgroundColor:
      return ElStyle(textBackgroundColor: value as Color?, transitions: [transition]);
    case ElTransitionField.width:
      return ElStyle(width: value, transitions: [transition]);
    case ElTransitionField.height:
      return ElStyle(height: value, transitions: [transition]);
    case ElTransitionField.widthFactor:
      return ElStyle(widthFactor: value as double?, transitions: [transition]);
    case ElTransitionField.heightFactor:
      return ElStyle(heightFactor: value as double?, transitions: [transition]);
    case ElTransitionField.bgColor:
      return ElStyle(bgColor: value as Color?, transitions: [transition]);
    case ElTransitionField.padding:
      return ElStyle(padding: value as EdgeInsetsGeometry?, transitions: [transition]);
    case ElTransitionField.margin:
      return ElStyle(margin: value as EdgeInsetsGeometry?, transitions: [transition]);
    case ElTransitionField.alignment:
      return ElStyle(alignment: value as AlignmentGeometry?, transitions: [transition]);
    case ElTransitionField.border:
      return ElStyle(border: value as ElBorder?, transitions: [transition]);
    case ElTransitionField.borderRadius:
      return ElStyle(borderRadius: value as BorderRadiusGeometry?, transitions: [transition]);
    case ElTransitionField.boxShadow:
      return ElStyle(boxShadow: value as List<BoxShadow>?, transitions: [transition]);
    case ElTransitionField.minWidth:
      return ElStyle(minWidth: value, transitions: [transition]);
    case ElTransitionField.maxWidth:
      return ElStyle(maxWidth: value, transitions: [transition]);
    case ElTransitionField.minHeight:
      return ElStyle(minHeight: value, transitions: [transition]);
    case ElTransitionField.maxHeight:
      return ElStyle(maxHeight: value, transitions: [transition]);
    case ElTransitionField.opacity:
      return ElStyle(opacity: value as double?, transitions: [transition]);
    case ElTransitionField.transform:
      return ElStyle(transform: value as ElTransform?, transitions: [transition]);
    case ElTransitionField.transformAlignment:
      return ElStyle(transformAlignment: value as AlignmentGeometry?, transitions: [transition]);
    case ElTransitionField.gradient:
      return ElStyle(gradient: value as Gradient?, transitions: [transition]);
    case ElTransitionField.textGradient:
      return ElStyle(textGradient: value as Gradient?, transitions: [transition]);
    case ElTransitionField.outline:
      return ElStyle(outline: value as ElOutline?, transitions: [transition]);
    case ElTransitionField.aspectRatio:
      return ElStyle(aspectRatio: value as double?, transitions: [transition]);
    case ElTransitionField.iconSize:
      return ElStyle(iconSize: value as double?, transitions: [transition]);
    case ElTransitionField.iconColor:
      return ElStyle(iconColor: value as Color?, transitions: [transition]);
    case ElTransitionField.filter:
      return ElStyle(filter: value as ElFilter?, transitions: [transition]);
    case ElTransitionField.backdropFilter:
      return ElStyle(backdropFilter: value as ElFilter?, transitions: [transition]);
    default:
      throw ArgumentError('No transition sample for ${field.name}');
  }
}

const _themeDuration = Duration(milliseconds: 160);

const _frameDuration = Duration(milliseconds: 16);

const _lightColor = Colors.white;

const _darkColor = Color(0xFF212121);

const _animationDuration = Duration(milliseconds: 200);

const _firstFrameDuration = Duration(milliseconds: 16);

const _elViewBodyKey = ValueKey('demo-el-view-body');

const _contextVarContainerKey = ValueKey('demo-context-var-container');

const _animatedContainerKey = ValueKey('demo-animated-container');

class _DemoHarness extends StatefulWidget {
  const _DemoHarness({super.key});

  @override
  State<_DemoHarness> createState() => _DemoHarnessState();
}

class _DemoHarnessState extends State<_DemoHarness> {
  bool _isDark = false;

  void toggleTheme() => setState(() => _isDark = !_isDark);

  @override
  Widget build(BuildContext context) {
    final brightness = _isDark ? Brightness.dark : Brightness.light;

    return ElView(
      themeMode: ElThemeMode(brightness: brightness, duration: _animationDuration, curve: Curves.linear),
      style: const ElStyle(
        color: _lightColor,
        onDark: ElStyle(color: _darkColor),
      ),
      child: MaterialApp(
        themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
        themeAnimationDuration: _animationDuration,
        themeAnimationCurve: Curves.linear,
        theme: ThemeData(
          brightness: Brightness.light,
          appBarTheme: AppBarThemeData(backgroundColor: _lightColor),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          appBarTheme: AppBarThemeData(backgroundColor: _darkColor),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: ElView(
            key: _elViewBodyKey,
            style: const ElStyle(
              width: '100%',
              height: '100%',
              bgColor: _lightColor,
              onDark: ElStyle(bgColor: _darkColor),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) => AnimatedContainer(
                      key: _contextVarContainerKey,
                      duration: _animationDuration,
                      curve: Curves.linear,
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(color: ElView.of(context).isDark ? _darkColor : _lightColor),
                    ),
                  ),
                  AnimatedContainer(
                    key: _animatedContainerKey,
                    duration: _animationDuration,
                    curve: Curves.linear,
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(color: _isDark ? _darkColor : _lightColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _start = Color(0xFF000000);

const _themeEnd = Color(0xFFFFFFFF);

const _frameCount = 10;

void main() {
  group('对齐插值', () {
    group('双侧非 null：平滑插值', () {
      test('topLeft → center → t=0.5 应为 (-0.5, -0.5)', () {
        final v = lerpAlignment(Alignment.topLeft, Alignment.center, 0.5) as Alignment;
        expect(v.x, closeTo(-0.5, 1e-9));
        expect(v.y, closeTo(-0.5, 1e-9));
      });

      test('topLeft → bottomRight → t=0.5 应为 .center', () {
        final v = lerpAlignment(Alignment.topLeft, Alignment.bottomRight, 0.5) as Alignment;
        expect(v.x, closeTo(0, 1e-9));
        expect(v.y, closeTo(0, 1e-9));
      });

      test('AlignmentDirectional ↔ Alignment 跨类型也能 lerp', () {
        final v = lerpAlignment(AlignmentDirectional.centerStart, Alignment.centerRight, 0.5);
        expect(v, isNotNull);
      });
    });

    group('单侧 null：step（layout 模式切换不能平滑）', () {
      test('null → .center → t=0.3 取 from=null', () {
        expect(lerpAlignment(null, Alignment.center, 0.3), isNull);
      });

      test('null → .center → t=0.7 取 to=.center', () {
        expect(lerpAlignment(null, Alignment.center, 0.7), Alignment.center);
      });

      test('.bottomRight → null → t=0.3 取 from=.bottomRight', () {
        expect(lerpAlignment(Alignment.bottomRight, null, 0.3), Alignment.bottomRight);
      });

      test('.bottomRight → null → t=0.7 取 to=null（必须能回到未声明）', () {
        expect(lerpAlignment(Alignment.bottomRight, null, 0.7), isNull);
      });
    });

    group('退化', () {
      test('双侧均 null → null', () {
        expect(lerpAlignment(null, null, 0.5), isNull);
      });

      test('identical → 直接返回（不算 lerp）', () {
        const a = Alignment.center;
        expect(identical(lerpAlignment(a, a, 0.5), a), isTrue);
      });
    });
  });

  group('边框插值', () {
    testWidgets('onHover border 通过 Border.lerp 平滑过渡', (tester) async {
      const key = ValueKey('border');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                padding: .symmetric(vertical: 8, horizontal: 16),
                border: .fromSide(ElBorderSide(color: Colors.grey, width: 1)),
                transitions: [ElTransition.all(Duration(milliseconds: 250))],
                onHover: ElStyle(border: .fromSide(ElBorderSide(color: Colors.blue, width: 3.5))),
              ),
              child: ElView(child: 'hello'),
            ),
          ),
        ),
      );
      await tester.pump();

      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(render.committedResolvedStyle.box.border!.top.width, 1);
      expect(render.committedResolvedStyle.box.border!.top.color, Colors.grey);

      render.setHover(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 125));

      final middle = render.committedResolvedStyle.box.border!;
      expect(middle.top.width, greaterThan(1));
      expect(middle.top.width, lessThan(3.5));
      expect(middle.top.color, isNot(Colors.grey));
      expect(middle.top.color, isNot(Colors.blue));

      await tester.pump(const Duration(milliseconds: 200));

      final end = render.committedResolvedStyle.box.border!;
      expect(end.top.width, 3.5);
      expect(end.top.color, Colors.blue);
    });

    testWidgets('example2：border align 在过渡中点发生几何跳变', (tester) async {
      const key = ValueKey('example2-border');
      const outerRect = Rect.fromLTWH(0, 0, 60, 60);
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                width: 60,
                height: 60,
                padding: .all(16),
                border: .all(color: Colors.grey),
                borderRadius: .all(Radius.circular(8)),
                transitions: [.all()],
                onHover: ElStyle(
                  border: .all(width: 5, color: Colors.blue, align: .center),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final render = tester.renderObject<ElRenderView>(find.byKey(key));

      (ElBorder border, Rect centerRect, double width) sample() {
        final committed = render.committedResolvedStyle;
        final border = committed.box.border!;
        final ops = recordBorderPaints(
          rect: outerRect,
          border: border,
          borderRadius: ViewBoxPainter.effectiveBorderRadius(
            committed.box,
            textDirection: committed.inheritedBox.textDirection ?? TextDirection.ltr,
          ),
        )!;
        final centerRect = switch (ops.single.$1) {
          Rect value => value,
          RRect value => value.outerRect,
          Path value => value.getBounds(),
          final value => throw StateError('未知 border 几何：${value.runtimeType}'),
        };
        return (border, centerRect, border.top.resolveWidth());
      }

      render.setHover(true);
      await tester.pump();

      var previous = sample();
      var foundJump = false;
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
        final current = sample();
        if (previous.$1.align != current.$1.align) {
          expect(previous.$1.align, ElBorderAlign.inside);
          expect(current.$1.align, ElBorderAlign.center);
          expect(current.$3 - previous.$3, lessThan(0.75), reason: '边宽本身仍是连续插值');
          expect(previous.$2.left - current.$2.left, greaterThan(1), reason: 'align 离散切换使描边中心线瞬间外移');
          foundJump = true;
          break;
        }
        previous = current;
      }

      expect(foundJump, isTrue, reason: 'example2 的 inside → center 应能稳定复现几何跳变');
    });
  });

  group('CSS 初值插值', () {
    group('lerpColor: 透明端点沿用可见端点色相', () {
      test('from=null, to=white → t=0.5 应为 50% alpha 的 white', () {
        final v = lerpColor(null, const Color(0xFFFFFFFF), 0.5) as Color;
        // r/g/b 保持 1.0 (white)，alpha 在 0 → 1 中点 ≈ 0.5
        expect(v.r, closeTo(1.0, 1e-6));
        expect(v.g, closeTo(1.0, 1e-6));
        expect(v.b, closeTo(1.0, 1e-6));
        expect(v.a, closeTo(0.5, 0.01));
      });

      test('from=red, to=null → t=0.5 应为 50% alpha 的 red', () {
        final v = lerpColor(const Color(0xFFFF0000), null, 0.5) as Color;
        expect(v.r, closeTo(1.0, 1e-6));
        expect(v.g, closeTo(0.0, 1e-6));
        expect(v.b, closeTo(0.0, 1e-6));
        expect(v.a, closeTo(0.5, 0.01));
      });

      test('transparent black → blue：t=0.5 保持 blue 色相，仅插值 alpha', () {
        final v = lerpColor(const Color(0x00000000), const Color(0xFF0000FF), 0.5) as Color;
        expect(v.r, closeTo(0.0, 1e-6));
        expect(v.g, closeTo(0.0, 1e-6));
        expect(v.b, closeTo(1.0, 1e-6));
        expect(v.a, closeTo(0.5, 0.01));
      });

      test('blue → transparent black：t=0.5 保持 blue 色相，仅插值 alpha', () {
        final v = lerpColor(const Color(0xFF0000FF), const Color(0x00000000), 0.5) as Color;
        expect(v.r, closeTo(0.0, 1e-6));
        expect(v.g, closeTo(0.0, 1e-6));
        expect(v.b, closeTo(1.0, 1e-6));
        expect(v.a, closeTo(0.5, 0.01));
      });

      test('双侧均 null → null（无可插值端点）', () {
        expect(lerpColor(null, null, 0.5), isNull);
      });

      test('双侧不透明：与 Color.lerp 一致', () {
        final v = lerpColor(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5) as Color;
        expect(v.r, closeTo(0.5, 0.01));
        expect(v.g, closeTo(0.5, 0.01));
        expect(v.b, closeTo(0.5, 0.01));
      });
    });

    group('lerpOpacityValue: 单侧 null → 1.0 替换', () {
      test('from=null, to=0.5 → t=0.5 应为 0.75 (1→0.5 中点)', () {
        expect(lerpOpacityValue(null, 0.5, 0.5), closeTo(0.75, 1e-9));
      });

      test('from=0.2, to=null → t=0.5 应为 0.6 (0.2→1 中点)', () {
        expect(lerpOpacityValue(0.2, null, 0.5), closeTo(0.6, 1e-9));
      });

      test('双侧均 null → null', () {
        expect(lerpOpacityValue(null, null, 0.5), isNull);
      });

      test('双侧非 null：线性插值', () {
        expect(lerpOpacityValue(0.0, 1.0, 0.5), closeTo(0.5, 1e-9));
      });
    });

    group('lerpFactorValue: 单侧 null → 1.0 替换', () {
      test('from=null, to=0.5 → t=0.5 应为 0.75', () {
        expect(lerpFactorValue(null, 0.5, 0.5), closeTo(0.75, 1e-9));
      });

      test('from=0.5, to=null → t=0.5 应为 0.75', () {
        expect(lerpFactorValue(0.5, null, 0.5), closeTo(0.75, 1e-9));
      });

      test('双侧均 null → null', () {
        expect(lerpFactorValue(null, null, 0.5), isNull);
      });

      test('双侧非 null：线性插值', () {
        expect(lerpFactorValue(0.2, 0.8, 0.5), closeTo(0.5, 1e-9));
      });
    });

    group('lerpDoubleZero: 单侧 null → 0.0 替换', () {
      test('from=null, to=10 → t=0.5 应为 5 (0→10 中点)', () {
        expect(lerpDoubleZero(null, 10.0, 0.5), closeTo(5, 1e-9));
      });

      test('from=20, to=null → t=0.5 应为 10 (20→0 中点)', () {
        expect(lerpDoubleZero(20.0, null, 0.5), closeTo(10, 1e-9));
      });

      test('双侧均 null → null', () {
        expect(lerpDoubleZero(null, null, 0.5), isNull);
      });
    });

    group('lerpEdgeInsetsValue: 单侧 null → 原生零边距', () {
      test('from=null, to=EI.all(8) → t=0.5 应为 EI.all(4)', () {
        final v = (lerpEdgeInsetsValue(null, const EdgeInsets.all(8), 0.5) as EdgeInsetsGeometry).resolve(
          TextDirection.ltr,
        );
        expect(v, const EdgeInsets.all(4));
      });

      test('from=EI.all(16), to=null → t=0.5 应为 EI.all(8)', () {
        final v = (lerpEdgeInsetsValue(const EdgeInsets.all(16), null, 0.5) as EdgeInsetsGeometry).resolve(
          TextDirection.ltr,
        );
        expect(v, const EdgeInsets.all(8));
      });

      test('双侧均 null → null', () {
        expect(lerpEdgeInsetsValue(null, null, 0.5), isNull);
      });
    });

    group('lerpBorderRadiusValue: 单侧 null → zero 替换', () {
      test('from=null, to=circular(20) → t=0.5 半径 10', () {
        final v = lerpBorderRadiusValue(null, const BorderRadius.all(Radius.circular(20)), 0.5) as BorderRadiusGeometry;
        final br = v.resolve(TextDirection.ltr);
        expect(br.topLeft.x, closeTo(10, 1e-9));
        expect(br.topLeft.y, closeTo(10, 1e-9));
      });

      test('from=circular(16), to=null → t=0.5 半径 8', () {
        final v = lerpBorderRadiusValue(const BorderRadius.all(Radius.circular(16)), null, 0.5) as BorderRadiusGeometry;
        final br = v.resolve(TextDirection.ltr);
        expect(br.topLeft.x, closeTo(8, 1e-9));
      });

      test('双侧均 null → null', () {
        expect(lerpBorderRadiusValue(null, null, 0.5), isNull);
      });
    });

    group('lerpTransform: 单侧 null → identity 替换', () {
      test('from=null, to=matrix3d → t=0.5 逐矩阵分量向目标插值', () {
        const end = ElTransform.matrix3d(0.8, 0, 0, 0, 0, 0.6, 0, 0, 0, 0, 2, -0.002, 10, 20, 4, 1);

        final v = lerpTransform(null, end, 0.5)! as ElTransform;
        final matrix = v.toMatrix4();

        expect(matrix.storage[0], closeTo(0.9, 0.0001));
        expect(matrix.storage[5], closeTo(0.8, 0.0001));
        expect(matrix.storage[10], closeTo(1.5, 0.0001));
        expect(matrix.storage[11], closeTo(-0.001, 0.0001));
        expect(matrix.storage[12], closeTo(5, 0.0001));
        expect(matrix.storage[13], closeTo(10, 0.0001));
        expect(matrix.storage[14], closeTo(2, 0.0001));
      });

      test('from=scale, to=null → t=0.5 向 identity 插值', () {
        const start = ElTransform.scale(0.8, 0.6, 2);

        final v = lerpTransform(start, null, 0.5)! as ElTransform;
        final matrix = v.toMatrix4();

        expect(matrix.storage[0], closeTo(0.9, 0.0001));
        expect(matrix.storage[5], closeTo(0.8, 0.0001));
        expect(matrix.storage[10], closeTo(1.5, 0.0001));
        expect(lerpTransform(start, null, 1.0), isNull);
      });

      test('双侧均 null → null', () {
        expect(lerpTransform(null, null, 0.5), isNull);
      });
    });

    group('lerpDoubleValue: 单侧 null 仍 step（继承字段 + 无清晰零值字段兜底）', () {
      test('from=null, to=10 → t=0.3 取 from (step)', () {
        expect(lerpDoubleValue(null, 10.0, 0.3), isNull);
      });

      test('from=null, to=10 → t=0.7 取 to (step)', () {
        expect(lerpDoubleValue(null, 10.0, 0.7), 10.0);
      });
    });
  });

  group('动画字段快照', () {
    testWidgets('字段集合不变时复用同一快照实例', (tester) async {
      final d = StyleAnimationDriver(onTick: () {});
      try {
        d.startAnimation(_anim(ElTransitionField.color));
        final first = d.activeFields;
        final second = d.activeFields;
        expect(identical(first, second), isTrue, reason: '稳态逐帧读取应零分配复用');
        expect(first, [ElTransitionField.color]);
      } finally {
        d.dispose();
      }
    });

    testWidgets('字段集合变更后重建快照，旧快照内容不受影响', (tester) async {
      final d = StyleAnimationDriver(onTick: () {});
      try {
        d.startAnimation(_anim(ElTransitionField.color));
        final before = d.activeFields;
        final beforeContent = before.toList();

        d.startAnimation(_anim(ElTransitionField.bgColor));
        final after = d.activeFields;
        expect(identical(before, after), isFalse, reason: '字段集合变更必须换新实例');
        expect(after, unorderedEquals([ElTransitionField.color, ElTransitionField.bgColor]));
        expect(before, beforeContent, reason: '已被持有的旧快照不被原地改写');

        d.cancelAnimation(ElTransitionField.color);
        expect(d.activeFields, [ElTransitionField.bgColor]);

        d.cancelAll();
        expect(d.activeFields, isEmpty);
      } finally {
        d.dispose();
      }
    });
  });

  group('动画长度快照', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    group('lengthSnapshotResolver: null↔px 平滑过渡', () {
      test('from=null, to=100, snapshot=30 → t=0.5 应为 65 (30→100 中点)', () {
        ElTransitionField? queried;
        final d = StyleAnimationDriver(
          onTick: () {},
          lengthSnapshotResolver: (f) {
            queried = f;
            return 30.0;
          },
        );
        try {
          final anim = FieldAnimation(
            field: ElTransitionField.width,
            from: null,
            to: const ElDimension.pixels(100),
            duration: const Duration(milliseconds: 100),
          );
          d.startAnimation(anim);
          expect(queried, ElTransitionField.width, reason: 'driver 应调 resolver 拿快照');

          anim.advance(const Duration(milliseconds: 50));
          final v = anim.currentValue() as ElDimension;
          expect(v.kind, ElLengthKind.pixels);
          expect(v.pxPart, closeTo(65, 1e-9), reason: 'from=null 被替换为 30，从 30 → 100 在 t=0.5 是 65');
        } finally {
          d.dispose();
        }
      });

      test('from=200, to=null, snapshot=50 → t=0.5 应为 125 (200→50 中点)', () {
        final d = StyleAnimationDriver(onTick: () {}, lengthSnapshotResolver: (f) => 50.0);
        try {
          final anim = FieldAnimation(
            field: ElTransitionField.width,
            from: const ElDimension.pixels(200),
            to: null,
            duration: const Duration(milliseconds: 100),
          );
          d.startAnimation(anim);
          anim.advance(const Duration(milliseconds: 50));
          final v = anim.currentValue() as ElDimension;
          expect(v.kind, ElLengthKind.pixels);
          expect(v.pxPart, closeTo(125, 1e-9), reason: 'to=null 被替换为 50，从 200 → 50 在 t=0.5 是 125');
        } finally {
          d.dispose();
        }
      });

      test('完成态精确对齐原始 to=null（保 null 语义）', () {
        final d = StyleAnimationDriver(onTick: () {}, lengthSnapshotResolver: (f) => 80.0);
        try {
          final anim = FieldAnimation(
            field: ElTransitionField.width,
            from: const ElDimension.pixels(200),
            to: null,
            duration: const Duration(milliseconds: 100),
          );
          d.startAnimation(anim);
          anim.advance(const Duration(milliseconds: 100));
          expect(anim.isComplete, isTrue);
          expect(anim.currentValue(), isNull, reason: '完成态仍回原始 to=null —— cascade 收尾可正确回到 auto');
        } finally {
          d.dispose();
        }
      });

      test('height 字段也走快照替换', () {
        final queried = <ElTransitionField>[];
        final d = StyleAnimationDriver(
          onTick: () {},
          lengthSnapshotResolver: (f) {
            queried.add(f);
            return 40.0;
          },
        );
        try {
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.height,
              from: null,
              to: const ElDimension.pixels(120),
              duration: const Duration(milliseconds: 100),
            ),
          );
          expect(queried, [ElTransitionField.height]);
        } finally {
          d.dispose();
        }
      });

      test('to:auto 可在真实 layout 后补入快照，并保留另一侧已归一化端点', () {
        final d = StyleAnimationDriver(onTick: () {}, lengthSnapshotResolver: (f) => null);
        try {
          final anim = FieldAnimation(
            field: ElTransitionField.width,
            from: const ElDimension.pixels(240),
            to: null,
            duration: const Duration(milliseconds: 100),
          );
          d.startAnimation(anim);

          expect(d.resolveDeferredLengthSnapshot(ElTransitionField.width, 80), isTrue);
          anim.advance(const Duration(milliseconds: 50));
          final value = anim.currentValue() as ElDimension;
          expect(value.pxPart, 160, reason: '补入 auto=80 时显式端点仍须为 240');
          expect(anim.from, const ElDimension.pixels(240));
          expect(anim.to, isNull);
        } finally {
          d.dispose();
        }
      });
    });

    group('lengthSnapshotResolver: 跳过 / 降级路径', () {
      test('未注入 resolver → 单侧 null 仍走 lerpStep 瞬跳（旧行为）', () {
        final d = StyleAnimationDriver(onTick: () {});
        try {
          final anim = FieldAnimation(
            field: ElTransitionField.width,
            from: null,
            to: const ElDimension.pixels(100),
            duration: const Duration(milliseconds: 100),
          );
          d.startAnimation(anim);
          anim.advance(const Duration(milliseconds: 30));
          expect(anim.currentValue(), isNull, reason: 't=0.3<0.5 step 取 from=null');
          anim.advance(const Duration(milliseconds: 30));
          expect(anim.currentValue(), const ElDimension.pixels(100), reason: 't=0.6>=0.5 step 切到 to');
        } finally {
          d.dispose();
        }
      });

      test('resolver 返回 null 且未延迟补入 → 退回 step', () {
        final d = StyleAnimationDriver(onTick: () {}, lengthSnapshotResolver: (f) => null);
        try {
          final anim = FieldAnimation(
            field: ElTransitionField.width,
            from: null,
            to: const ElDimension.pixels(100),
            duration: const Duration(milliseconds: 100),
          );
          d.startAnimation(anim);
          anim.advance(const Duration(milliseconds: 30));
          expect(anim.currentValue(), isNull);
          anim.advance(const Duration(milliseconds: 30));
          expect(anim.currentValue(), const ElDimension.pixels(100));
        } finally {
          d.dispose();
        }
      });

      test('非长度字段 → 不调 resolver', () {
        var called = false;
        final d = StyleAnimationDriver(
          onTick: () {},
          lengthSnapshotResolver: (f) {
            called = true;
            return 30.0;
          },
        );
        try {
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.color,
              from: const Color(0xFF000000),
              to: null,
              duration: const Duration(milliseconds: 100),
            ),
          );
          expect(called, isFalse, reason: 'color 不在 _lengthFieldsForSnapshot 集合，应跳过 resolver');
        } finally {
          d.dispose();
        }
      });

      test('min/max width/height 不走快照（null 语义是无约束，不是内容尺寸）', () {
        var called = false;
        final d = StyleAnimationDriver(
          onTick: () {},
          lengthSnapshotResolver: (f) {
            called = true;
            return 30.0;
          },
        );
        try {
          for (final f in const [
            ElTransitionField.minWidth,
            ElTransitionField.maxWidth,
            ElTransitionField.minHeight,
            ElTransitionField.maxHeight,
          ]) {
            d.startAnimation(
              FieldAnimation(
                field: f,
                from: null,
                to: const ElDimension.pixels(100),
                duration: const Duration(milliseconds: 100),
              ),
            );
          }
          expect(called, isFalse, reason: 'min/max 字段的 null 等价于 0 / infinity，不应替换为 auto used-size');
        } finally {
          d.dispose();
        }
      });

      test('双侧非 null → 不调 resolver（直接走 ElDimension.lerp）', () {
        var called = false;
        final d = StyleAnimationDriver(
          onTick: () {},
          lengthSnapshotResolver: (f) {
            called = true;
            return 30.0;
          },
        );
        try {
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.width,
              from: const ElDimension.pixels(100),
              to: const ElDimension.pixels(200),
              duration: const Duration(milliseconds: 100),
            ),
          );
          expect(called, isFalse);
        } finally {
          d.dispose();
        }
      });

      test('双侧均 null → 不调 resolver（无动画可言）', () {
        var called = false;
        final d = StyleAnimationDriver(
          onTick: () {},
          lengthSnapshotResolver: (f) {
            called = true;
            return 30.0;
          },
        );
        try {
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.width,
              from: null,
              to: null,
              duration: const Duration(milliseconds: 100),
            ),
          );
          expect(called, isFalse);
        } finally {
          d.dispose();
        }
      });
    });

    group('FieldAnimation auto 快照', () {
      test('补齐 auto 不影响 from/to 声明', () {
        final anim = FieldAnimation(
          field: ElTransitionField.width,
          from: null,
          to: const ElDimension.pixels(100),
          duration: const Duration(milliseconds: 100),
        );
        expect(anim.from, isNull);
        expect(anim.to, const ElDimension.pixels(100));

        anim.replaceNullLerpEndpoint(const ElDimension.pixels(30));
        expect(anim.from, isNull, reason: 'user-visible from 不应被改');
        expect(anim.to, const ElDimension.pixels(100), reason: 'user-visible to 不应被改');

        anim.advance(const Duration(milliseconds: 50));
        final v = anim.currentValue() as ElDimension;
        expect(v.pxPart, closeTo(65, 1e-9), reason: 'lerp 用替换后的端点 (30, 100)');
      });
    });
  });

  group('动画驱动器', () {
    group('状态管理（无 ticker 推进）', () {
      test('初始：无活跃动画 + hasActiveAnimations=false', () {
        final d = StyleAnimationDriver(onTick: () {});
        try {
          expect(d.activeFields, isEmpty);
          expect(d.hasActiveAnimations, isFalse);
        } finally {
          d.dispose();
        }
      });

      testWidgets('startAnimation：进活跃集合 + animationOf 可取回', (tester) async {
        final d = StyleAnimationDriver(onTick: () {});
        try {
          final anim = FieldAnimation(
            field: ElTransitionField.color,
            from: const Color(0xFF000000),
            to: const Color(0xFFFFFFFF),
            duration: const Duration(milliseconds: 200),
          );
          d.startAnimation(anim);
          expect(d.activeFields, contains(ElTransitionField.color));
          expect(d.hasActiveAnimations, isTrue);
          expect(identical(d.animationOf(ElTransitionField.color), anim), isTrue);
        } finally {
          d.dispose();
        }
      });

      testWidgets('cancelAnimation：从活跃集合移除', (tester) async {
        final d = StyleAnimationDriver(onTick: () {});
        try {
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.color,
              from: const Color(0xFF000000),
              to: const Color(0xFFFFFFFF),
              duration: const Duration(milliseconds: 200),
            ),
          );
          d.cancelAnimation(ElTransitionField.color);
          expect(d.activeFields, isEmpty);
          expect(d.animationOf(ElTransitionField.color), isNull);
        } finally {
          d.dispose();
        }
      });

      testWidgets('cancelAll：清空所有', (tester) async {
        final d = StyleAnimationDriver(onTick: () {});
        try {
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.color,
              from: const Color(0xFF000000),
              to: const Color(0xFFFFFFFF),
              duration: const Duration(milliseconds: 200),
            ),
          );
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.opacity,
              from: 0.0,
              to: 1.0,
              duration: const Duration(milliseconds: 200),
            ),
          );
          expect(d.activeFields, hasLength(2));
          d.cancelAll();
          expect(d.activeFields, isEmpty);
        } finally {
          d.dispose();
        }
      });

      testWidgets('同字段 startAnimation 覆盖旧动画', (tester) async {
        final d = StyleAnimationDriver(onTick: () {});
        try {
          final a1 = FieldAnimation(
            field: ElTransitionField.color,
            from: const Color(0xFF000000),
            to: const Color(0xFFFFFFFF),
            duration: const Duration(milliseconds: 200),
          );
          final a2 = FieldAnimation(
            field: ElTransitionField.color,
            from: const Color(0xFFFF0000),
            to: const Color(0xFF00FF00),
            duration: const Duration(milliseconds: 500),
          );
          d.startAnimation(a1);
          d.startAnimation(a2);
          expect(identical(d.animationOf(ElTransitionField.color), a2), isTrue, reason: '后启动应覆盖');
        } finally {
          d.dispose();
        }
      });
    });

    group('Ticker lifecycle + 帧推进', () {
      testWidgets('完成回调内替换同字段动画，不会被上一条动画的收尾清除', (tester) async {
        final replacement = FieldAnimation(
          field: ElTransitionField.color,
          from: Color(0xffffffff),
          to: Color(0xff000000),
          duration: Duration(milliseconds: 200),
        );
        late StyleAnimationDriver driver;
        var replaced = false;
        driver = StyleAnimationDriver(
          onTick: () {
            if (!replaced && driver.animationOf(ElTransitionField.color)?.isComplete == true) {
              replaced = true;
              driver.startAnimation(replacement);
            }
          },
        );
        addTearDown(driver.dispose);
        driver.startAnimation(
          FieldAnimation(
            field: ElTransitionField.color,
            from: Color(0xff000000),
            to: Color(0xffffffff),
            duration: Duration(milliseconds: 100),
          ),
        );
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100));
        expect(identical(driver.animationOf(ElTransitionField.color), replacement), isTrue);
        await tester.pump(Duration(milliseconds: 50));
        expect(replacement.progress, closeTo(0.25, 0.000001));
        await tester.pump(Duration(milliseconds: 150));
        expect(driver.hasActiveAnimations, isFalse);
      });

      testWidgets('build 帧启动后首个真实 tick 计入完整帧间隔', (tester) async {
        StyleAnimationDriver? driver;
        late final FieldAnimation animation;

        try {
          await tester.pumpWidget(
            Builder(
              builder: (context) {
                if (driver == null) {
                  animation = FieldAnimation(
                    field: ElTransitionField.color,
                    from: const Color(0xFF000000),
                    to: const Color(0xFFFFFFFF),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.linear,
                  );
                  driver = StyleAnimationDriver(onTick: () {})..startAnimation(animation);
                }
                return const SizedBox();
              },
            ),
          );

          await tester.pump(const Duration(milliseconds: 16));

          expect(animation.progress, closeTo(0.08, 0.000001));
        } finally {
          driver?.dispose();
        }
      });

      testWidgets('startAnimation 触发 onTick；动画完成后自动清理 + 停 ticker', (tester) async {
        var tickCount = 0;
        final d = StyleAnimationDriver(onTick: () => tickCount++);
        try {
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.color,
              from: const Color(0xFF000000),
              to: const Color(0xFFFFFFFF),
              duration: const Duration(milliseconds: 100),
              curve: Curves.linear,
            ),
          );
          // idle 阶段启动的 Ticker 首次回调 elapsed=0，后续 pump 累计推进。
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          expect(tickCount, greaterThan(0), reason: 'onTick 应被调用');
          expect(d.activeFields, isEmpty, reason: '动画完成 → 从活跃集合移除');
        } finally {
          d.dispose();
        }
      });

      testWidgets('多字段并发：各字段独立 lerp', (tester) async {
        final d = StyleAnimationDriver(onTick: () {});
        try {
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.color,
              from: const Color(0xFF000000),
              to: const Color(0xFFFFFFFF),
              duration: const Duration(milliseconds: 200),
            ),
          );
          d.startAnimation(
            FieldAnimation(
              field: ElTransitionField.opacity,
              from: 0.0,
              to: 1.0,
              duration: const Duration(milliseconds: 100), // 较短
            ),
          );

          // 推进几帧；此处 driver 在 idle 阶段启动，首次回调 elapsed=0。
          await tester.pump(const Duration(milliseconds: 16));
          await tester.pump(const Duration(milliseconds: 50));
          final pColor = d.animationOf(ElTransitionField.color)?.progress ?? 1.0;
          final pOpacity = d.animationOf(ElTransitionField.opacity)?.progress ?? 1.0;

          // opacity duration 较短 → 同样 elapsed 时 progress 更大（或已完成清空）
          expect(pOpacity, greaterThanOrEqualTo(pColor), reason: '不同 duration 字段独立推进');
        } finally {
          d.dispose();
        }
      });
    });

    testWidgets('dispose：取消所有 + 释放 ticker', (tester) async {
      final d = StyleAnimationDriver(onTick: () {});
      d.startAnimation(
        FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
        ),
      );
      d.dispose();
      expect(d.activeFields, isEmpty);
      // dispose 后再调 dispose / cancelAll 不抛
      d.cancelAll();
    });
  });

  group('字段动画', () {
    group('progress', () {
      test('未启动（elapsed=0）：progress=0', () {
        final a = FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
        );
        expect(a.progress, 0);
      });

      test('elapsed = delay：progress=0', () {
        final a = FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
          delay: const Duration(milliseconds: 50),
        );
        a.advance(const Duration(milliseconds: 50));
        expect(a.progress, 0);
      });

      test('elapsed = delay + duration / 2：linear → progress ≈ 0.5', () {
        final a = FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
        );
        a.advance(const Duration(milliseconds: 100));
        expect(a.progress, closeTo(0.5, 1e-6));
      });

      test('elapsed >= delay + duration：progress=1', () {
        final a = FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
        );
        a.advance(const Duration(milliseconds: 500));
        expect(a.progress, 1);
        expect(a.isComplete, isTrue);
      });

      test('curve 应用：easeIn 中点 < 0.5', () {
        final a = FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeIn,
        );
        a.advance(const Duration(milliseconds: 100));
        expect(a.progress, lessThan(0.5));
      });
    });

    group('currentValue', () {
      test('color lerp 中点 ≈ 0xFF808080', () {
        final a = FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
        );
        a.advance(const Duration(milliseconds: 100));
        final c = a.currentValue()! as Color;
        // Color.lerp 中点 - 灰（r/g/b 范围 0~1，*255 取整）
        expect((c.r * 255).round(), closeTo(128, 2));
        expect((c.g * 255).round(), closeTo(128, 2));
        expect((c.b * 255).round(), closeTo(128, 2));
      });

      test('double lerp 中点 = (from+to)/2', () {
        final a = FieldAnimation(
          field: ElTransitionField.opacity,
          from: 0.2,
          to: 1.0,
          duration: const Duration(milliseconds: 200),
        );
        a.advance(const Duration(milliseconds: 100));
        final v = a.currentValue()! as double;
        expect(v, closeTo(0.6, 1e-6));
      });

      test('fontWeight 通过 FontWeight.lerp 连续插值', () {
        final a = FieldAnimation(
          field: ElTransitionField.fontWeight,
          from: FontWeight.w400,
          to: FontWeight.w700,
          duration: const Duration(milliseconds: 200),
        );
        a.advance(const Duration(milliseconds: 50)); // progress=0.25
        expect(a.currentValue(), FontWeight.lerp(FontWeight.w400, FontWeight.w700, 0.25));

        a.advance(const Duration(milliseconds: 150)); // progress=1
        expect(a.currentValue(), FontWeight.w700);
      });
    });

    group('advance：累计 + clamp', () {
      test('advance 多次累加', () {
        final a = FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
        );
        a.advance(const Duration(milliseconds: 50));
        a.advance(const Duration(milliseconds: 30));
        expect(a.debugElapsed, const Duration(milliseconds: 80));
      });

      test('advance 超出 duration：elapsed 被 clamp 到 delay+duration', () {
        final a = FieldAnimation(
          field: ElTransitionField.color,
          from: const Color(0xFF000000),
          to: const Color(0xFFFFFFFF),
          duration: const Duration(milliseconds: 200),
          delay: const Duration(milliseconds: 50),
        );
        a.advance(const Duration(milliseconds: 500));
        expect(a.debugElapsed, const Duration(milliseconds: 250));
      });
    });

    group('theme 声明 retarget', () {});
  });

  group('长度插值', () {
    FieldAnimation makeAnim({
      required Object? from,
      required Object? to,
      Duration duration = const Duration(milliseconds: 100),
    }) {
      return FieldAnimation(field: ElTransitionField.width, from: from, to: to, duration: duration);
    }

    group('lerpLengthValue 单测', () {
      test('null + null → null', () {
        expect(lerpLengthValue(null, null, 0.5), isNull);
      });

      test('null 单侧 step（t=0.5 阈值；t>=0.5 必能切到 to，含 to=null）', () {
        // from=null → to=100
        expect(lerpLengthValue(null, const ElDimension.pixels(100), 0.3), isNull);
        expect(lerpLengthValue(null, const ElDimension.pixels(100), 0.7), const ElDimension.pixels(100));
        // from=200 → to=null：t>=0.5 必能回到 null（旧实现 bug：恒返回 from）
        expect(lerpLengthValue(const ElDimension.pixels(200), null, 0.3), const ElDimension.pixels(200));
        expect(lerpLengthValue(const ElDimension.pixels(200), null, 0.7), isNull);
      });

      test('同 kind 数值插值', () {
        expect(
          lerpLengthValue(const ElDimension.pixels(0), const ElDimension.pixels(100), 0.5),
          const ElDimension.pixels(50),
        );
        expect(
          lerpLengthValue(const ElDimension.percent(20), const ElDimension.percent(80), 0.5),
          const ElDimension.percent(50),
        );
      });

      test('跨 kind 走 calc 形态（lazy 像素插值）', () {
        // pixels(100) → percent(80) at t=0.3 → calc(70, 24)
        final r1 = lerpLengthValue(const ElDimension.pixels(100), const ElDimension.percent(80), 0.3) as ElDimension;
        expect(r1.kind, ElLengthKind.calc);
        expect(r1.pxPart, closeTo(70, 1e-9));
        expect(r1.percentPart, closeTo(24, 1e-9));
        // at t=0.7 → calc(30, 56)
        final r2 = lerpLengthValue(const ElDimension.pixels(100), const ElDimension.percent(80), 0.7) as ElDimension;
        expect(r2.kind, ElLengthKind.calc);
        expect(r2.pxPart, closeTo(30, 1e-9));
        expect(r2.percentPart, closeTo(56, 1e-9));
      });
    });

    group('FieldAnimation: ElTransitionField.width 全流程', () {
      test("'80%' → 100：跨 kind 走 calc 连续插值", () {
        final anim = makeAnim(from: const ElDimension.percent(80), to: const ElDimension.pixels(100));
        // 起点：calc(0, 80) 等价于 percent(80)
        var v = anim.currentValue() as ElDimension;
        expect(v.kind, ElLengthKind.calc);
        expect(v.pxPart, closeTo(0, 1e-9));
        expect(v.percentPart, closeTo(80, 1e-9));

        anim.advance(const Duration(milliseconds: 30));
        v = anim.currentValue() as ElDimension;
        expect(v.pxPart, closeTo(30, 1e-9));
        expect(v.percentPart, closeTo(56, 1e-9));

        anim.advance(const Duration(milliseconds: 30));
        v = anim.currentValue() as ElDimension;
        expect(v.pxPart, closeTo(60, 1e-9));
        expect(v.percentPart, closeTo(32, 1e-9));

        anim.advance(const Duration(milliseconds: 50));
        v = anim.currentValue() as ElDimension;
        // 完成：calc(100, 0) 等价于 pixels(100)
        expect(v.pxPart, closeTo(100, 1e-9));
        expect(v.percentPart, closeTo(0, 1e-9));
        expect(anim.isComplete, isTrue);
      });

      test('null → 200：t<0.5 仍 null，t>=0.5 切到 200，完成 200', () {
        final anim = makeAnim(from: null, to: const ElDimension.pixels(200));
        expect(anim.currentValue(), isNull, reason: 't=0 取 from=null');
        anim.advance(const Duration(milliseconds: 30));
        expect(anim.currentValue(), isNull, reason: 't=0.3<0.5 仍 from');
        anim.advance(const Duration(milliseconds: 30));
        expect(anim.currentValue(), const ElDimension.pixels(200), reason: 't=0.6>=0.5 切 to');
        anim.advance(const Duration(milliseconds: 60));
        // isComplete → driver 直接返回 to
        expect(anim.isComplete, isTrue);
        expect(anim.currentValue(), const ElDimension.pixels(200));
      });

      test('200 → null：t<0.5 仍 200，t>=0.5 必能回到 null（核心修复点）', () {
        final anim = makeAnim(from: const ElDimension.pixels(200), to: null);
        expect(anim.currentValue(), const ElDimension.pixels(200));
        anim.advance(const Duration(milliseconds: 30));
        expect(anim.currentValue(), const ElDimension.pixels(200), reason: 't=0.3<0.5 取 from');
        anim.advance(const Duration(milliseconds: 30));
        expect(anim.currentValue(), isNull, reason: 't=0.6 step 切到 to=null');
        anim.advance(const Duration(milliseconds: 60));
        expect(anim.isComplete, isTrue);
        expect(anim.currentValue(), isNull, reason: '完成时对齐 to=null');
      });

      test('100 → 300：纯数值线性插值', () {
        final anim = makeAnim(from: const ElDimension.pixels(100), to: const ElDimension.pixels(300));
        anim.advance(const Duration(milliseconds: 50));
        expect(anim.currentValue(), const ElDimension.pixels(200));
        anim.advance(const Duration(milliseconds: 50));
        expect(anim.currentValue(), const ElDimension.pixels(300));
      });

      test("'20%' → '80%'：percent 线性插值", () {
        final anim = makeAnim(from: const ElDimension.percent(20), to: const ElDimension.percent(80));
        anim.advance(const Duration(milliseconds: 25));
        expect(anim.currentValue(), const ElDimension.percent(35));
        anim.advance(const Duration(milliseconds: 25));
        expect(anim.currentValue(), const ElDimension.percent(50));
      });
    });
  });

  group('长度过渡集成', () {
    ElRenderView findRender(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView));

    Widget boundedTarget({
      required Key key,
      required ElStyle style,
      Widget? child,
      double maxWidth = 300,
      double maxHeight = 100,
    }) {
      return MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
            child: ElView(key: key, style: style, child: child),
          ),
        ),
      );
    }

    testWidgets("ElTransition.all 触发 width 100 → '80%' 跨 kind 连续插值", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
              child: const ElView(
                key: ValueKey('target'),
                style: ElStyle(
                  width: 100,
                  height: 100,
                  bgColor: Color(0xffff0000),
                  transitions: [ElTransition.all()],
                  onHover: ElStyle(width: '80%', bgColor: Color(0xff00ff00)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = findRender(tester);

      expect(box.size.width, 100);
      expect(box.committedResolvedStyle.box.width, const ElDimension.pixels(100));

      box.setHover(true);
      await tester.pump();

      // 跨 kind → calc 形态 lazy 插值。size.width 应在 (100, 320) 区间内单调推进，
      // 而不是 100 → 320 的突变。
      await tester.pump(const Duration(milliseconds: 60));
      final mid = box.size.width;
      expect(mid, greaterThan(100));
      expect(mid, lessThan(320));

      await tester.pump(const Duration(milliseconds: 60));
      final later = box.size.width;
      expect(later, greaterThan(mid), reason: '动画推进 → 像素值应单调增（calc 中 percent 分量增、px 分量减）');
      expect(later, lessThanOrEqualTo(320));

      // 跑完
      await tester.pump(const Duration(milliseconds: 200));
      expect(box.size.width, 320, reason: '最终 percent(80) of 400 = 320');
    });

    testWidgets('同 kind: 100px → 300px 平滑数值插值', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
              child: const ElView(
                key: ValueKey('target'),
                style: ElStyle(
                  width: 100,
                  height: 100,
                  bgColor: Color(0xffff0000),
                  transitions: [ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100))],
                  onHover: ElStyle(width: 300),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = findRender(tester);
      expect(box.size.width, 100);

      box.setHover(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // 中间应平滑过渡（curve 影响具体值，只断在开区间内）
      expect(box.size.width, greaterThan(100));
      expect(box.size.width, lessThan(300));

      await tester.pump(const Duration(milliseconds: 80));
      expect(box.size.width, 300);
    });

    testWidgets('同 kind percent: 20% → 80% 平滑插值', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
              child: const ElView(
                key: ValueKey('target'),
                style: ElStyle(
                  width: '20%',
                  height: 100,
                  bgColor: Color(0xffff0000),
                  transitions: [ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100))],
                  onHover: ElStyle(width: '80%'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = findRender(tester);
      expect(box.size.width, 80, reason: '20% of 400 = 80');

      box.setHover(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // 中间应平滑过渡
      expect(box.size.width, greaterThan(80));
      expect(box.size.width, lessThan(320));

      await tester.pump(const Duration(milliseconds: 80));
      expect(box.size.width, 320, reason: '80% of 400 = 320');
    });

    testWidgets('空 child：120px ↔ auto 收缩到 padding，且起止帧连续', (tester) async {
      const key = ValueKey('empty-auto');
      Widget host(Object? width) {
        return MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 100),
              child: ElView(
                key: key,
                style: ElStyle(
                  width: width,
                  height: 40,
                  padding: .symmetric(horizontal: 12),
                  alignment: .center,
                  transitions: const [
                    ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(host(120));
      await tester.pump();

      final box = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(box.size.width, 120);

      await tester.pumpWidget(host(null));
      expect(box.size.width, 120);

      await tester.pump(const Duration(milliseconds: 50));
      final middle = box.size.width;

      await tester.pump(const Duration(milliseconds: 49));
      final beforeComplete = box.size.width;

      await tester.pump(const Duration(milliseconds: 1));
      final completed = box.size.width;
      expect(completed, 24);
      expect(box.committedResolvedStyle.box.width, isNull);

      await tester.pumpWidget(host(120));
      final reverseStart = box.size.width;

      await tester.pump(const Duration(milliseconds: 50));
      final reverseMiddle = box.size.width;

      await tester.pump(const Duration(milliseconds: 50));
      final reverseCompleted = box.size.width;
      expect(reverseCompleted, 120);
      expect(box.committedResolvedStyle.box.width, const ElDimension.pixels(120));
      expect(
        middle,
        72,
        reason:
            'auto 的真实 used width 是 padding 24，中点应从 120 减至 72；'
            '正向实际时间线为 50ms=$middle、99ms=$beforeComplete、100ms=$completed；'
            '反向实际时间线为 0ms=$reverseStart、50ms=$reverseMiddle、100ms=$reverseCompleted',
      );
      expect(beforeComplete, closeTo(24.96, 0.01), reason: '结束前应连续逼近 padding 宽度 24');
      expect(reverseStart, 24, reason: 'auto → 120 起手必须保留真实 auto used width');
      expect(reverseMiddle, 72, reason: 'auto → 120 中点应从 24 增至 72');
    });

    testWidgets('auto width 有 child 且无 alignment 时 hug child + padding', (tester) async {
      const key = ValueKey('hug-child-auto');
      Widget host(Object? width) => boundedTarget(
        key: key,
        style: ElStyle(
          width: width,
          height: 40,
          padding: .symmetric(horizontal: 10),
          transitions: const [ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear)],
        ),
        child: const ElView(style: ElStyle(width: 60, height: 20)),
      );

      await tester.pumpWidget(host(120));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));

      await tester.pumpWidget(host(null));
      expect(box.size.width, 120);
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.width, 100, reason: 'auto 端点应为 child 60 + padding 20 = 80');
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.width, 80);
    });

    testWidgets('auto width 有 alignment 时填满可用宽度，动画端点不含 margin', (tester) async {
      const key = ValueKey('aligned-auto-with-margin');
      Widget host(Object? width) => boundedTarget(
        key: key,
        style: ElStyle(
          width: width,
          height: 40,
          padding: .symmetric(horizontal: 10),
          margin: .symmetric(horizontal: 10),
          alignment: .center,
          transitions: const [ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear)],
        ),
        child: const ElView(style: ElStyle(width: 60, height: 20)),
      );

      await tester.pumpWidget(host(120));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(box.boxSize.width, 120);
      expect(box.size.width, 140);

      await tester.pumpWidget(host(null));
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.boxSize.width, 200, reason: 'auto width 端点是扣除 margin 后的 280，不是节点总宽 300');
      expect(box.size.width, 220, reason: 'RenderBox 对父布局的占位仍包含 20px margin');
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.boxSize.width, 280);
      expect(box.size.width, 300);
    });

    testWidgets('无界空盒 auto width 仅收缩到 padding，margin 只计入外部占位', (tester) async {
      const key = ValueKey('unbounded-empty-auto');
      Widget host(Object? width) {
        return MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElView(
                  key: key,
                  style: ElStyle(
                    width: width,
                    height: 40,
                    padding: .symmetric(horizontal: 12),
                    margin: .symmetric(horizontal: 8),
                    transitions: const [
                      ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      await tester.pumpWidget(host(120));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));

      await tester.pumpWidget(host(null));
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.boxSize.width, 72, reason: '120 → padding 24 的中点');
      expect(box.size.width, 88, reason: '节点总宽在 box width 之外再包含 16px margin');
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.boxSize.width, 24);
      expect(box.size.width, 40);
    });

    testWidgets('空 child：120px → auto height 收缩到 padding', (tester) async {
      const key = ValueKey('empty-auto-height');
      Widget host(Object? height) => boundedTarget(
        key: key,
        maxWidth: 100,
        maxHeight: 300,
        style: ElStyle(
          width: 40,
          height: height,
          padding: .symmetric(vertical: 12),
          alignment: .center,
          transitions: const [ElTransition.field(ElTransitionField.height, Duration(milliseconds: 100), Curves.linear)],
        ),
      );

      await tester.pumpWidget(host(120));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));

      await tester.pumpWidget(host(null));
      expect(box.size.height, 120);
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.height, 72, reason: '高度快照应与宽度一样取 padding 24');
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.height, 24);
    });

    testWidgets('width 动画中途反向时从当前 used size 连续返回', (tester) async {
      const key = ValueKey('empty-auto-mid-reverse');
      Widget host(Object? width) => boundedTarget(
        key: key,
        style: ElStyle(
          width: width,
          height: 40,
          padding: .symmetric(horizontal: 12),
          alignment: .center,
          transitions: const [ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear)],
        ),
      );

      await tester.pumpWidget(host(120));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));

      await tester.pumpWidget(host(null));
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.width, 72);

      await tester.pumpWidget(host(120));
      expect(box.size.width, 72, reason: '反向起手帧必须保留当前插值，不能跳到任一端点');
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.width, 96, reason: '新时间线应从 72 连续返回 120');
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.width, 120);
    });

    testWidgets('width → auto 同轮 child 变宽时使用新 child 的 used size', (tester) async {
      const key = ValueKey('auto-with-new-child-size');
      Widget host(Object? width, double childWidth) => boundedTarget(
        key: key,
        style: ElStyle(
          width: width,
          height: 40,
          padding: .symmetric(horizontal: 10),
          transitions: const [ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear)],
        ),
        child: ElView(
          key: const ValueKey('resized-child'),
          style: ElStyle(width: childWidth, height: 20),
        ),
      );

      await tester.pumpWidget(host(120, 60));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));

      await tester.pumpWidget(host(null, 160));
      expect(box.size.width, 120);
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.width, 150, reason: '新 auto 端点应为 child 160 + padding 20 = 180');
      await tester.pump(const Duration(milliseconds: 49));
      expect(box.size.width, closeTo(179.4, 0.01), reason: '完成前应连续逼近新 child 决定的 auto 宽度');
      await tester.pump(const Duration(milliseconds: 1));
      expect(box.size.width, 180, reason: '完成帧不能再从旧 child 的 auto 快照跳到新尺寸');
    });

    testWidgets('height → auto 同轮父宽变化时使用新约束下的 child 高度', (tester) async {
      const key = ValueKey('auto-height-with-new-parent-width');
      Widget host(Object? height, double maxWidth) {
        return MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 300),
              child: ElView(
                key: key,
                style: ElStyle(
                  height: height,
                  transitions: const [
                    ElTransition.field(ElTransitionField.height, Duration(milliseconds: 100), Curves.linear),
                  ],
                ),
                child: const ElView(style: ElStyle(width: '100%', aspectRatio: 2)),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(host(120, 100));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(box.size, const Size(100, 120));

      await tester.pumpWidget(host(null, 200));
      expect(box.size.height, 120);
      await tester.pump(const Duration(milliseconds: 50));
      expect(box.size.height, 110, reason: '新父宽 200 使 100% / 2 的 child 高度为 100');
      await tester.pump(const Duration(milliseconds: 49));
      expect(box.size.height, closeTo(100.2, 0.01), reason: '完成前应连续逼近新父约束决定的 auto 高度');
      await tester.pump(const Duration(milliseconds: 1));
      expect(box.size, const Size(200, 100), reason: '完成帧不能从旧父宽对应的高度跳到新高度');
    });

    testWidgets('不支持 dry layout 的 child 仍可连续从显式 width 过渡到 auto', (tester) async {
      const key = ValueKey('auto-with-layout-builder');
      Widget host(Object? width) => boundedTarget(
        key: key,
        style: ElStyle(
          width: width,
          height: 40,
          transitions: const [ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear)],
        ),
        child: LayoutBuilder(builder: (context, constraints) => const ElView(style: ElStyle(width: 180, height: 20))),
      );

      await tester.pumpWidget(host(120));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(box.size.width, 120);

      await tester.pumpWidget(host(null));
      expect(tester.takeException(), isNull, reason: '合法 child 不支持 dry layout 时不能抛异常');
      expect(box.size.width, 120);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(box.size.width, 150, reason: '不能用保留旧宽度直到完成的离散回退');
      await tester.pump(const Duration(milliseconds: 49));
      expect(tester.takeException(), isNull);
      expect(box.size.width, closeTo(179.4, 0.01), reason: '完成前应连续逼近 LayoutBuilder 的真实 auto 宽度');
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull);
      expect(box.size.width, 180);
    });

    testWidgets('rich TextSpan 的 width 与 fontSize 同时过渡时目标探测不污染正式首帧', (tester) async {
      const key = ValueKey('rich-auto-with-font-size');
      Widget host(Object? width, double fontSize) {
        return MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 200),
              child: ElView(
                key: key,
                style: ElStyle(
                  width: width,
                  fontSize: fontSize as double?,
                  softWrap: false,
                  transitions: const [
                    ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear),
                    ElTransition.field(ElTransitionField.fontSize, Duration(milliseconds: 100), Curves.linear),
                  ],
                ),
                child: const TextSpan(text: 'MMMMMM'),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(host(120, 10));
      await tester.pump();
      final box = tester.renderObject<ElRenderView>(find.byKey(key));
      expect((box.textEngineForTest!.painterForTest.text as TextSpan).style!.fontSize, 10);

      await tester.pumpWidget(host(null, 30));
      expect(box.size.width, 120);
      expect(box.targetStyleForTest.inheritedText.fontSize, 30);
      expect(box.committedResolvedStyle.inheritedText.fontSize, 10);
      expect(
        (box.textEngineForTest!.painterForTest.text as TextSpan).style!.fontSize,
        10,
        reason: 'target auto 探测使用 30px 后，正式首帧必须按 committed 10px 重建 rich context',
      );

      await tester.pump(const Duration(milliseconds: 99));
      final beforeComplete = box.size.width;
      expect((box.textEngineForTest!.painterForTest.text as TextSpan).style!.fontSize, closeTo(29.8, 0.01));

      await tester.pump(const Duration(milliseconds: 1));
      final completed = box.size.width;
      expect(completed, greaterThan(120));
      expect(
        beforeComplete,
        closeTo(120 + (completed - 120) * 0.99, 0.01),
        reason: '99ms 应沿冻结的 rich auto 终点连续逼近，完成帧不能重新测量后跳变',
      );
      expect((box.textEngineForTest!.painterForTest.text as TextSpan).style!.fontSize, 30);
    });

    testWidgets('无界轴 host 切到 auto 时清旧参照并让百分比 child 向外取参照', (tester) async {
      const hostKey = ValueKey('unbounded-auto-reference-host');
      const childKey = ValueKey('unbounded-auto-reference-child');
      Widget tree(Object? width) {
        return MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: ElView(
              style: const ElStyle(width: 400, height: 100),
              child: UnconstrainedBox(
                constrainedAxis: Axis.vertical,
                alignment: Alignment.topLeft,
                child: ElView(
                  key: hostKey,
                  style: ElStyle(
                    width: width,
                    height: 40,
                    transitions: const [
                      ElTransition.field(ElTransitionField.width, Duration(milliseconds: 100), Curves.linear),
                    ],
                  ),
                  child: const ElView(
                    key: childKey,
                    style: ElStyle(width: '50%', height: 20),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(tree(120));
      await tester.pump();
      final host = tester.renderObject<ElRenderView>(find.byKey(hostKey));
      expect(host.size.width, 120);
      expect(tester.getSize(find.byKey(childKey)).width, 60);

      await tester.pumpWidget(tree(null));
      expect(host.size.width, 120);
      await tester.pump(const Duration(milliseconds: 50));
      expect(host.size.width, 160, reason: 'auto target 应清 host 的旧 120 参照，child 改向外取 400 × 50% = 200');
      await tester.pump(const Duration(milliseconds: 49));
      expect(host.size.width, closeTo(199.2, 0.01));
      await tester.pump(const Duration(milliseconds: 1));
      expect(host.size.width, 200);
      expect(tester.getSize(find.byKey(childKey)).width, 200);
    });
  });

  group('可空值插值', () {
    ElRenderView findRender(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    Future<TestGesture> arm(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(() => mouse.removePointer());
      await mouse.addPointer(location: const Offset(-10, -10));
      await tester.pump();
      return mouse;
    }

    Future<void> hoverInOut(WidgetTester tester, TestGesture mouse, Key key) async {
      final center = tester.getCenter(find.byKey(key));
      await mouse.moveTo(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      await mouse.moveTo(const Offset(500, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
    }

    testWidgets('borderRadius: null → circular(20) → null', (tester) async {
      const key = ValueKey('br');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                width: 100,
                height: 100,
                bgColor: Color(0xffff0000),
                transitions: [ElTransition.all(Duration(milliseconds: 80))],
                onHover: ElStyle(borderRadius: BorderRadius.all(Radius.elliptical(20, 20))),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = findRender(tester, key);
      expect(box.committedResolvedStyle.box.borderRadius, isNull);

      final mouse = await arm(tester);
      await hoverInOut(tester, mouse, key);

      expect(box.committedResolvedStyle.box.borderRadius, isNull, reason: 'hover 离开后 borderRadius 必须回到 null');
    });

    testWidgets('padding: null → EI(8) → null', (tester) async {
      const key = ValueKey('pad');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                width: 100,
                height: 100,
                bgColor: Color(0xffff0000),
                transitions: [ElTransition.all(Duration(milliseconds: 80))],
                onHover: ElStyle(padding: .all(8)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = findRender(tester, key);
      expect(box.committedResolvedStyle.box.padding, isNull);

      final mouse = await arm(tester);
      await hoverInOut(tester, mouse, key);

      expect(box.committedResolvedStyle.box.padding, isNull);
    });

    testWidgets('width (ElDimension): null → 200 → null', (tester) async {
      const key = ValueKey('w');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                height: 100,
                bgColor: Color(0xffff0000),
                transitions: [ElTransition.all(Duration(milliseconds: 80))],
                onHover: ElStyle(width: 200),
              ),
              child: SizedBox(width: 30, height: 30),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = findRender(tester, key);
      expect(box.committedResolvedStyle.box.width, isNull, reason: '初始 width 未声明');

      final mouse = await arm(tester);
      await hoverInOut(tester, mouse, key);

      expect(box.committedResolvedStyle.box.width, isNull, reason: 'hover 离开后 width 必须回到 null（child intrinsic）');
    });

    testWidgets('opacity (double?): null → 0.5 → null', (tester) async {
      const key = ValueKey('op');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                width: 100,
                height: 100,
                bgColor: Color(0xffff0000),
                transitions: [ElTransition.all(Duration(milliseconds: 80))],
                onHover: ElStyle(opacity: 0.5),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = findRender(tester, key);
      expect(box.committedResolvedStyle.box.opacity, isNull);

      final mouse = await arm(tester);
      await hoverInOut(tester, mouse, key);

      expect(box.committedResolvedStyle.box.opacity, isNull, reason: 'hover 离开后 opacity 必须回到 null');
    });

    testWidgets('transform: null → scale → null 连续过渡', (tester) async {
      const key = ValueKey('transform');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                width: 100,
                height: 100,
                bgColor: const Color(0xffff0000),
                transitions: const [ElTransition.all(Duration(milliseconds: 100))],
                onHover: const ElStyle(transform: .scale(0.8, 0.8)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = findRender(tester, key);
      expect(box.committedResolvedStyle.box.transform, isNull);

      final mouse = await arm(tester);
      await mouse.moveTo(tester.getCenter(find.byKey(key)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final middle = box.committedResolvedStyle.box.transform;
      expect(middle, isNotNull);
      final enterMatrix = middle!.toMatrix4();
      final enterScale = enterMatrix.storage[0];
      expect(enterScale, greaterThanOrEqualTo(0.8), reason: '中间帧不能越过目标 scale');
      expect(enterScale, lessThan(1.0), reason: 'null 应按 identity 参与 scale 插值，而不是半程 step');

      await mouse.moveTo(const Offset(500, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final retreat = box.committedResolvedStyle.box.transform;
      expect(retreat, isNotNull);
      final retreatScale = retreat!.toMatrix4().storage[0];
      expect(retreatScale, greaterThan(enterScale), reason: 'transform -> null 退场也必须向 identity 连续 lerp');
      expect(retreatScale, lessThan(1.0), reason: '退场中间帧不能提前 step 到 null / identity');

      await tester.pump(const Duration(milliseconds: 150));

      expect(box.committedResolvedStyle.box.transform, isNull, reason: 'hover 离开后 transform 必须回到 null');
    });

    testWidgets('transformAlignment 单字段 transition：topLeft → center 平滑过渡', (tester) async {
      const key = ValueKey('ta');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ElView(
              key: key,
              style: ElStyle(
                width: 100,
                height: 100,
                bgColor: Color(0xffff0000),
                transform: .scale(2),
                transformAlignment: Alignment.topLeft,
                transitions: [ElTransition.field(ElTransitionField.transformAlignment, Duration(milliseconds: 100))],
                onHover: ElStyle(transformAlignment: Alignment.center),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final box = findRender(tester, key);
      expect(box.committedResolvedStyle.box.transformAlignment, Alignment.topLeft);

      final mouse = await arm(tester);
      await mouse.moveTo(tester.getCenter(find.byKey(key)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 中间帧应在 topLeft (-1,-1) 与 center (0,0) 之间
      final mid = box.committedResolvedStyle.box.transformAlignment;
      expect(mid, isNotNull);
      expect(mid, isA<Alignment>(), reason: 'AlignmentGeometry.lerp 返回 Alignment 实例');
      final a = mid! as Alignment;
      expect(a.x, greaterThan(-1.0));
      expect(a.x, lessThan(0.0));
      expect(a.y, greaterThan(-1.0));
      expect(a.y, lessThan(0.0));

      await tester.pump(const Duration(milliseconds: 80));
      expect(box.committedResolvedStyle.box.transformAlignment, Alignment.center);

      await mouse.moveTo(const Offset(500, 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(box.committedResolvedStyle.box.transformAlignment, Alignment.topLeft);
    });

    group('lerpStep 单元', () {
      test('双侧非 null：t<0.5 取 from，否则 to', () {
        expect(lerpStep('a', 'b', 0.0), 'a');
        expect(lerpStep('a', 'b', 0.49), 'a');
        expect(lerpStep('a', 'b', 0.5), 'b');
        expect(lerpStep('a', 'b', 1.0), 'b');
      });

      test('to=null：退场时 t>=0.5 必须返回 null（而非永远 from）', () {
        expect(lerpStep('a', null, 0.0), 'a');
        expect(lerpStep('a', null, 0.49), 'a');
        expect(lerpStep('a', null, 0.5), isNull);
        expect(lerpStep('a', null, 1.0), isNull);
      });

      test('from=null：入场时 t<0.5 返回 null', () {
        expect(lerpStep(null, 'b', 0.0), isNull);
        expect(lerpStep(null, 'b', 0.49), isNull);
        expect(lerpStep(null, 'b', 0.5), 'b');
        expect(lerpStep(null, 'b', 1.0), 'b');
      });
    });

    group('lerpTransform 单元', () {
      test('双侧 null：始终 null', () {
        expect(lerpTransform(null, null, 0.0), isNull);
        expect(lerpTransform(null, null, 0.5), isNull);
        expect(lerpTransform(null, null, 1.0), isNull);
      });

      test('t=0：返回 start（含 start=null）', () {
        const a = ElTransform.scale(2.0, 2.0);
        expect(lerpTransform(a, null, 0.0), same(a));
        expect(lerpTransform(a, const ElTransform.translate(20, 0), 0.0), same(a));
        expect(lerpTransform(null, const ElTransform.translate(20, 0), 0.0), isNull);
      });

      test('t=1：返回 end（含 end=null）', () {
        const a = ElTransform.scale(2.0, 2.0);
        const b = ElTransform.translate(20, 0);
        expect(lerpTransform(a, b, 1.0), same(b));
        expect(lerpTransform(a, null, 1.0), isNull);
        expect(lerpTransform(null, b, 1.0), same(b));
      });

      test('单侧 null 以 identity scale(1) 为视觉端点', () {
        const end = ElTransform.matrix3d(0.8, 0, 0, 0, 0, 0.6, 0, 0, 0, 0, 2, -0.002, 10, 20, 4, 1);
        final mid = lerpTransform(null, end, 0.5)! as ElTransform;
        final m = mid.toMatrix4();
        expect(m.storage[0], closeTo(0.9, 1e-4));
        expect(m.storage[5], closeTo(0.8, 1e-4));
        expect(m.storage[10], closeTo(1.5, 1e-4));
        expect(m.storage[11], closeTo(-0.001, 1e-4));
        expect(m.storage[12], closeTo(5, 1e-4));
        expect(m.storage[13], closeTo(10, 1e-4));
        expect(m.storage[14], closeTo(2, 1e-4));
      });

      test('to=null：origin 在 t<0.5 取 start origin，t>=0.5 取 null', () {
        final start = const ElTransform.scale(0.8, 0.6).alignment(Alignment.topLeft);
        final low = lerpTransform(start, null, 0.4)! as ElTransform;
        final high = lerpTransform(start, null, 0.6)! as ElTransform;
        expect(low.origin, Alignment.topLeft, reason: 't<0.5 时 origin 应取 start 的');
        expect(high.origin, isNull, reason: 't>=0.5 时 origin 切到 end (null)');
      });

      test('identical(start, end)：t=0 返回 start，无副本', () {
        const a = ElTransform.scale(1.5);
        expect(lerpTransform(a, a, 0.5), same(a), reason: 'identical 短路返回 from');
      });
    });
  });

  group('预乘颜色插值', () {
    double composite(double src, double srcAlpha, double dst) => src * srcAlpha + dst * (1.0 - srcAlpha);

    group('lerpColorPremul: 不透明 ↔ 半透明（用户报告的 hover 缺陷场景）', () {
      // examples/example main.dart hero 次要按钮实际端点：
      // bgSoft #f6f6f7（不透明近白）→ defaultSoft 0x248e96aa（alpha≈14% 灰蓝）
      const from = Color(0xfff6f6f7);
      const to = Color(0x248e96aa);

      test('中间帧合成到白底后亮度落在两端之间（直通道插值会低于两端）', () {
        final fromComposited = composite(from.r, from.a, 1.0);
        final toComposited = composite(to.r, to.a, 1.0);
        final lo = fromComposited < toComposited ? fromComposited : toComposited;
        final hi = fromComposited < toComposited ? toComposited : fromComposited;
        for (final t in [0.1, 0.25, 0.5, 0.75, 0.9]) {
          final mid = lerpColorPremul(from, to, t)!;
          final midComposited = composite(mid.r, mid.a, 1.0);
          expect(midComposited, greaterThanOrEqualTo(lo - 1e-6), reason: 't=$t 合成亮度低于两端（暗坑）');
          expect(midComposited, lessThanOrEqualTo(hi + 1e-6), reason: 't=$t 合成亮度高于两端');
        }
      });

      test('合成结果 = 两端合成结果的线性插值（CSS 预乘语义，逐通道验证）', () {
        const bg = 0.2; // 任意深色背景
        for (final t in [0.3, 0.5, 0.7]) {
          final mid = lerpColorPremul(from, to, t)!;
          for (final (channel, cf, ct, cm) in [
            ('r', from.r, to.r, mid.r),
            ('g', from.g, to.g, mid.g),
            ('b', from.b, to.b, mid.b),
          ]) {
            final expected = composite(cf, from.a, bg) * (1 - t) + composite(ct, to.a, bg) * t;
            expect(composite(cm, mid.a, bg), closeTo(expected, 1e-6), reason: 'channel=$channel t=$t');
          }
        }
      });

      test('alpha 线性插值（与 CSS 一致）', () {
        final mid = lerpColorPremul(from, to, 0.5)!;
        expect(mid.a, closeTo((from.a + to.a) / 2, 1e-6));
      });
    });

    group('lerpColorPremul: 端点语义', () {
      test('双侧 null → null', () {
        expect(lerpColorPremul(null, null, 0.5), isNull);
      });

      test('单侧 null → 对侧色相 alpha 渐入', () {
        final v = lerpColorPremul(null, const Color(0xFFFFFFFF), 0.5)!;
        expect(v.r, closeTo(1.0, 1e-6));
        expect(v.g, closeTo(1.0, 1e-6));
        expect(v.b, closeTo(1.0, 1e-6));
        expect(v.a, closeTo(0.5, 0.01));
      });

      test('全透明黑 → 可见色：不向中间帧混入黑色', () {
        final v = lerpColorPremul(const Color(0x00000000), const Color(0xFF0000FF), 0.5)!;
        expect(v.r, closeTo(0.0, 1e-6));
        expect(v.g, closeTo(0.0, 1e-6));
        expect(v.b, closeTo(1.0, 1e-6));
        expect(v.a, closeTo(0.5, 0.01));
      });

      test('双侧不透明：退化为普通线性插值（与 Color.lerp 一致）', () {
        final v = lerpColorPremul(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5)!;
        expect(v.r, closeTo(0.5, 0.01));
        expect(v.g, closeTo(0.5, 0.01));
        expect(v.b, closeTo(0.5, 0.01));
        expect(v.a, closeTo(1.0, 1e-6));
      });

      test('t=0 / t=1 精确等于端点', () {
        const a = Color(0xfff6f6f7);
        const b = Color(0x248e96aa);
        final v0 = lerpColorPremul(a, b, 0.0)!;
        final v1 = lerpColorPremul(a, b, 1.0)!;
        expect(v0.r, closeTo(a.r, 1e-6));
        expect(v0.a, closeTo(a.a, 1e-6));
        expect(v1.r, closeTo(b.r, 1e-6));
        expect(v1.g, closeTo(b.g, 1e-6));
        expect(v1.b, closeTo(b.b, 1e-6));
        expect(v1.a, closeTo(b.a, 1e-6));
      });
    });

    group('消费点接线：各颜色 lerper 走预乘', () {
      test('lerpColor（bgColor/color 字段）：半透明中间帧无暗坑', () {
        final mid = lerpColor(const Color(0xfff6f6f7), const Color(0x248e96aa), 0.5)! as Color;
        final expected = lerpColorPremul(const Color(0xfff6f6f7), const Color(0x248e96aa), 0.5)!;
        expect(mid, expected);
      });

      test('ElBorderSide.lerp：color 分量走预乘', () {
        const a = ElBorderSide(width: 1, color: Color(0xfff6f6f7));
        const b = ElBorderSide(width: 1, color: Color(0x248e96aa));
        final mid = ElBorderSide.lerp(a, b, 0.5);
        expect(mid.color, lerpColorPremul(const Color(0xfff6f6f7), const Color(0x248e96aa), 0.5));
      });

      test('ElOutline.lerp：color 分量走预乘', () {
        const a = ElOutline(width: 2, color: Color(0xfff6f6f7));
        const b = ElOutline(width: 2, color: Color(0x248e96aa));
        final mid = ElOutline.lerp(a, b, 0.5)!;
        expect(mid.color, lerpColorPremul(const Color(0xfff6f6f7), const Color(0x248e96aa), 0.5));
      });

      test('ElBoxShadow.lerp：color 分量走预乘，几何分量沿用 Flutter', () {
        const a = BoxShadow(color: Color(0xfff6f6f7), blurRadius: 4);
        const b = BoxShadow(color: Color(0x248e96aa), blurRadius: 12);
        final mid = ElBoxShadow.lerp(a, b, 0.5)!;
        expect(mid.color, lerpColorPremul(const Color(0xfff6f6f7), const Color(0x248e96aa), 0.5));
        expect(mid.blurRadius, closeTo(8.0, 1e-6));
      });

      test('lerpShadowListValue（textShadow 字段）：color 分量走预乘', () {
        const a = [Shadow(color: Color(0xfff6f6f7), blurRadius: 2)];
        const b = [Shadow(color: Color(0x248e96aa), blurRadius: 6)];
        final mid = (lerpShadowListValue(a, b, 0.5)! as List<Shadow>).single;
        expect(mid.color, lerpColorPremul(const Color(0xfff6f6f7), const Color(0x248e96aa), 0.5));
        expect(mid.blurRadius, closeTo(4.0, 1e-6));
      });
    });
  });

  group('变换函数插值', () {
    Matrix4 mat(ElTransform? v) => v!.toMatrix4();

    group('rotate 角度插值', () {
      test('identity → rotate(2π)：spinner 场景，中途帧真在转', () {
        const start = ElTransform.identity();
        final end = ElTransform.rotate(math.pi * 2);
        // t=0.25 → 旋转 π/2。
        final quarter = mat(ElTransform.lerp(start, end, 0.25));
        expect(quarter.storage[0], closeTo(math.cos(math.pi / 2), 1e-9));
        expect(quarter.storage[1], closeTo(1.0, 1e-9));
        // t=0.5 → 旋转 π（旧矩阵插值下这里恒 ≈ identity）。
        final half = mat(ElTransform.lerp(start, end, 0.5));
        expect(half.storage[0], closeTo(-1.0, 1e-9));
        expect(half.storage[5], closeTo(-1.0, 1e-9));
      });

      test('null 端点视为 identity：null → rotate(2π) 同样在转', () {
        final end = ElTransform.rotate(math.pi * 2);
        final half = mat(ElTransform.lerp(null, end, 0.5));
        expect(half.storage[0], closeTo(-1.0, 1e-9));
      });

      test('rotate(π/2) → rotate(π)：角度线性、无缩放塌缩（行列式恒 1）', () {
        final v = mat(ElTransform.lerp(ElTransform.rotate(math.pi / 2), ElTransform.rotate(math.pi), 0.5));
        expect(v.storage[0], closeTo(math.cos(math.pi * 0.75), 1e-9));
        expect(v.storage[1], closeTo(math.sin(math.pi * 0.75), 1e-9));
        final det2d = v.storage[0] * v.storage[5] - v.storage[1] * v.storage[4];
        expect(det2d, closeTo(1.0, 1e-9), reason: '按角度插值不得出现中途缩放');
      });

      test('rotateX 同轴插值', () {
        final v = mat(ElTransform.lerp(ElTransform.rotateX(math.pi / 4), ElTransform.rotateX(math.pi * 0.75), 0.5));
        expect(v.storage[5], closeTo(math.cos(math.pi / 2), 1e-9));
        expect(v.storage[6], closeTo(1.0, 1e-9));
      });

      test('rotate3d 同轴插值：等价于直接构造中间角', () {
        final v = mat(
          ElTransform.lerp(ElTransform.rotate3d(1, 1, 0, math.pi / 2), ElTransform.rotate3d(1, 1, 0, math.pi), 0.5),
        );
        final expected = ElTransform.rotate3d(1, 1, 0, math.pi * 0.75).toMatrix4();
        for (var i = 0; i < 16; i++) {
          expect(v.storage[i], closeTo(expected.storage[i], 1e-9));
        }
      });

      test('零角端点轴任意：rotateZ(0) → rotateX(π) 按 X 轴插角度', () {
        final v = mat(ElTransform.lerp(ElTransform.rotateZ(0), ElTransform.rotateX(math.pi), 0.5));
        final expected = ElTransform.rotateX(math.pi / 2).toMatrix4();
        for (var i = 0; i < 16; i++) {
          expect(v.storage[i], closeTo(expected.storage[i], 1e-9));
        }
      });

      test('轴不同回退矩阵插值：rotateX(π) ↔ rotateZ(π) 中点为元素均值', () {
        final v = mat(ElTransform.lerp(ElTransform.rotateX(math.pi), ElTransform.rotateZ(math.pi), 0.5));
        // 元素均值：m00 = (1 + -1)/2 = 0，m22 = (-1 + 1)/2 = 0。
        expect(v.storage[0], closeTo(0.0, 1e-9));
        expect(v.storage[10], closeTo(0.0, 1e-9));
      });
    });

    group('skew 角度插值', () {
      test('skewX 按角度插值而非 tan 值', () {
        final v = mat(ElTransform.lerp(ElTransform.skewX(0), ElTransform.skewX(math.pi / 3), 0.5));
        // 角度中点 π/6 → tan(π/6) ≈ 0.577；tan 值中点是 tan(π/3)/2 ≈ 0.866。
        expect(v.storage[4], closeTo(math.tan(math.pi / 6), 1e-9));
      });

      test('identity → skew(x, y)：中性 0 角补位', () {
        final v = mat(ElTransform.lerp(const ElTransform.identity(), ElTransform.skew(math.pi / 3, math.pi / 4), 0.5));
        expect(v.storage[4], closeTo(math.tan(math.pi / 6), 1e-9));
        expect(v.storage[1], closeTo(math.tan(math.pi / 8), 1e-9));
      });
    });

    group('translate / scale 与回退路径既有行为不变', () {
      test('scale → null：中性 scale(1) 补位', () {
        final v = mat(ElTransform.lerp(const ElTransform.scale(0.8, 0.6), null, 0.5));
        expect(v.storage[0], closeTo(0.9, 1e-9));
        expect(v.storage[5], closeTo(0.8, 1e-9));
      });

      test('null → translate：中性 translate(0) 补位', () {
        final v = mat(ElTransform.lerp(null, const ElTransform.translate(20, 10), 0.5));
        expect(v.storage[12], closeTo(10.0, 1e-9));
        expect(v.storage[13], closeTo(5.0, 1e-9));
      });

      test('手写 matrix 端点不吃函数插值：identity 同值矩阵 → rotate(2π) 恒静止', () {
        // 与函数插值形成对照：同样的 identity 数值、以 .matrix 构造即失去角度信息。
        const start = ElTransform.matrix(1, 0, 0, 1, 0, 0);
        final half = mat(ElTransform.lerp(start, ElTransform.rotate(math.pi * 2), 0.5));
        expect(half.storage[0], closeTo(1.0, 1e-4));
        expect(half.storage[1], closeTo(0.0, 1e-4));
      });

      test('函数不同类（scale ↔ translate）回退矩阵插值', () {
        final v = mat(ElTransform.lerp(const ElTransform.scale(2.0, 2.0), const ElTransform.translate(20, 0), 0.5));
        expect(v.storage[0], closeTo(1.5, 1e-9));
        expect(v.storage[12], closeTo(10.0, 1e-9));
      });
    });

    group('origin 与插值产物再插值', () {
      test('函数插值路径保持 origin step 规则：t<0.5 取 start，t>=0.5 取 end', () {
        final start = ElTransform.rotate(math.pi).alignment(Alignment.topLeft);
        final end = ElTransform.rotate(math.pi * 2);
        final low = ElTransform.lerp(start, end, 0.4)!;
        final high = ElTransform.lerp(start, end, 0.6)!;
        expect(low.origin, Alignment.topLeft);
        expect(high.origin, isNull);
        // origin 之外角度照常插值。
        expect(mat(low).storage[0], closeTo(math.cos(math.pi * 1.4), 1e-9));
      });

      test('lerp 产物保留来源函数：链式再插值仍按角度', () {
        final end = ElTransform.rotate(math.pi * 2);
        final mid = ElTransform.lerp(const ElTransform.identity(), end, 0.5); // rotate(π)
        final v = mat(ElTransform.lerp(mid, end, 0.5)); // rotate(1.5π)
        expect(v.storage[0], closeTo(math.cos(math.pi * 1.5), 1e-9));
        expect(v.storage[1], closeTo(math.sin(math.pi * 1.5), 1e-9));
      });
    });

    group('关键帧端到端', () {
      testWidgets('spinner：identity → rotate(2π) 无限循环，中途帧真在转', (tester) async {
        const k = ValueKey('spin');
        await tester.pumpWidget(
          MaterialApp(
            home: ElView(
              key: k,
              style: ElStyle(
                width: 40,
                height: 40,
                animations: [
                  ElAnimation(
                    keyframes: {
                      0: const ElStyle(transform: .identity()),
                      100: ElStyle(transform: .rotate(math.pi * 2)),
                    },
                    duration: const Duration(seconds: 1),
                    curve: Curves.linear,
                    iterationCount: double.infinity,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(); // ticker 基线帧
        await tester.pump(const Duration(milliseconds: 250));
        final render = tester.renderObject<ElRenderView>(find.byKey(k));
        final transform = render.committedResolvedStyle.box.transform!;
        final m = transform.toMatrix4();
        // progress 0.25 → 旋转 π/2（修复前恒 ≈ identity）。
        expect(m.storage[0], closeTo(0.0, 0.05));
        expect(m.storage[1], closeTo(1.0, 0.05));
      });
    });
  });

  group('级联帧提交', () {
    final emptyState = 0;

    ResolvedStyle empty() => ResolvedStyleBuilder.empty().build();

    group('newTarget / newCommitted / changedFields 三元组', () {
      test('无 style + 无 parent：newTarget = newCommitted = empty, 无 changes', () {
        final result = CascadeTick.tick(
          style: null,
          parent: null,
          oldCommitted: empty(),
          state: emptyState,

          driver: null,
        );
        expect(result.changedMask.fields.toSet(), isEmpty);
        expect(result.newCommitted.inheritedText.color, InheritedText.initial.color);
      });

      test('style.color：committed/target 都含 color，进 changedFields', () {
        final result = CascadeTick.tick(
          style: const ElStyle(color: Color(0xFFFF0000)),
          parent: null,
          oldCommitted: empty(),
          state: emptyState,

          driver: null,
        );
        expect(result.newTarget.inheritedText.color, const Color(0xFFFF0000));
        expect(result.newCommitted.inheritedText.color, const Color(0xFFFF0000));
        expect(result.changedMask.fields.toSet(), contains(ElTransitionField.color));
      });

      test('字段未变（与 oldCommitted 相同）：不进 changedFields', () {
        final old = ResolvedStyleBuilder.empty();
        old.writeColor(const Color(0xFFFF0000));
        final oldCommitted = old.build();

        final result = CascadeTick.tick(
          style: const ElStyle(color: Color(0xFFFF0000)),
          parent: null,
          oldCommitted: oldCommitted,
          state: emptyState,

          driver: null,
        );
        expect(result.changedMask.fields.toSet(), isNot(contains(ElTransitionField.color)));
      });
    });

    group('transition：进 driver + newCommitted 保留旧值', () {
      testWidgets('有 transition 的字段：driver 收到 startAnimation', (tester) async {
        var ticks = 0;
        final driver = StyleAnimationDriver(onTick: () => ticks++);
        try {
          final old = ResolvedStyleBuilder.empty()..writeColor(const Color(0xFFFF0000));
          final result = CascadeTick.tick(
            style: const ElStyle(
              color: Color(0xFF0000FF),
              transitions: [ElTransition.field(ElTransitionField.color, Duration(milliseconds: 200))],
            ),
            parent: null,
            oldCommitted: old.build(),
            state: emptyState,

            driver: driver,
          );
          // newTarget 是新值
          expect(result.newTarget.inheritedText.color, const Color(0xFF0000FF));
          // newCommitted 保持旧值（动画字段未立即跳）
          expect(
            result.newCommitted.inheritedText.color,
            const Color(0xFFFF0000),
            reason: 'transition 的字段：committed 保持旧值，等 driver 推进',
          );
          // driver 应该有 active animation
          expect(driver.activeFields, contains(ElTransitionField.color));
          // 该字段**不**进 changedFields（动画字段不是立即变化）
          expect(result.changedMask.fields.toSet(), isNot(contains(ElTransitionField.color)));
        } finally {
          driver.dispose();
        }
      });

      test('duration=0 + delay=0：立即生效，不进 driver', () {
        var ticks = 0;
        final driver = StyleAnimationDriver(onTick: () => ticks++);
        try {
          final old = ResolvedStyleBuilder.empty()..writeColor(const Color(0xFFFF0000));
          final result = CascadeTick.tick(
            style: const ElStyle(
              color: Color(0xFF0000FF),
              transitions: [ElTransition.field(ElTransitionField.color, Duration.zero)],
            ),
            parent: null,
            oldCommitted: old.build(),
            state: emptyState,

            driver: driver,
          );
          expect(driver.activeFields, isEmpty, reason: 'duration=0 视为无动画');
          expect(result.changedMask.fields.toSet(), contains(ElTransitionField.color));
        } finally {
          driver.dispose();
        }
      });

      testWidgets('fontWeight 是连续字段：transition 进 driver', (tester) async {
        var ticks = 0;
        final driver = StyleAnimationDriver(onTick: () => ticks++);
        try {
          final old = ResolvedStyleBuilder.empty()..writeFontWeight(FontWeight.w400);
          final result = CascadeTick.tick(
            style: const ElStyle(
              fontWeight: FontWeight.w700,
              transitions: [ElTransition.field(ElTransitionField.fontWeight, Duration(milliseconds: 200))],
            ),
            parent: null,
            oldCommitted: old.build(),
            state: emptyState,

            driver: driver,
          );
          expect(driver.activeFields, contains(ElTransitionField.fontWeight));
          expect(result.newCommitted.inheritedText.fontWeight, FontWeight.w400);
          expect(result.changedMask.fields.toSet(), isNot(contains(ElTransitionField.fontWeight)));
        } finally {
          driver.dispose();
        }
      });

      test('所有非离散字段命中 transition 时都进入 driver', () {
        final samples = _transitionSamples();
        final missing = [
          for (final entry in fieldSpecs.entries)
            if (!entry.value.isDiscrete && !samples.containsKey(entry.key)) entry.key.name,
        ];
        expect(missing, isEmpty, reason: '新增可动画字段必须补 transition 样本，防止漏处理');

        for (final entry in samples.entries) {
          final field = entry.key;
          final (from, to) = entry.value;
          final spec = fieldSpecs[field]!;
          if (spec.isDiscrete) continue;

          var ticks = 0;
          final driver = StyleAnimationDriver(onTick: () => ticks++);
          try {
            final old = ResolvedStyleBuilder.empty();
            spec.write(old, from);
            final result = CascadeTick.tick(
              style: _styleFor(field, to),
              parent: null,
              oldCommitted: old.build(),
              state: emptyState,

              driver: driver,
            );
            expect(driver.activeFields, contains(field), reason: '${field.name} 可 lerp，必须进入动画 driver');
            expect(result.changedMask.fields.toSet(), isNot(contains(field)), reason: '${field.name} 启动动画时不应立即 commit');
          } finally {
            driver.dispose();
          }
        }
      });

      testWidgets('字段值相同：driver 中已有的动画被 cancel', (tester) async {
        var ticks = 0;
        final driver = StyleAnimationDriver(onTick: () => ticks++);
        try {
          // 先启动一个 color 动画
          driver.startAnimation(
            FieldAnimation(
              field: ElTransitionField.color,
              from: const Color(0xFFFF0000),
              to: const Color(0xFF0000FF),
              duration: const Duration(milliseconds: 200),
              curve: Curves.linear,
            ),
          );
          expect(driver.activeFields, contains(ElTransitionField.color));

          final old = ResolvedStyleBuilder.empty()..writeColor(const Color(0xFFFF0000));
          CascadeTick.tick(
            style: const ElStyle(color: Color(0xFFFF0000)),
            parent: null,
            oldCommitted: old.build(),
            state: emptyState,

            driver: driver,
          );
          // tick 见到 target == old → 自动 cancel
          expect(
            driver.activeFields,
            isNot(contains(ElTransitionField.color)),
            reason: 'target 与 old 相等时应 cancel 已有动画',
          );
        } finally {
          driver.dispose();
        }
      });
    });

    group('继承传播：parent → newTarget', () {
      test('parent 有 color，子无 color：newTarget 继承 parent color', () {
        final parentOld = ResolvedStyleBuilder.empty()..writeColor(const Color(0xFFFF0000));
        final result = CascadeTick.tick(
          style: null,
          parent: parentOld.build(),
          oldCommitted: empty(),
          state: emptyState,

          driver: null,
        );
        expect(result.newTarget.inheritedText.color, const Color(0xFFFF0000));
        expect(result.changedMask.fields.toSet(), contains(ElTransitionField.color));
      });
    });

    group('theme animation 接管边界', () {
      testWidgets('继承 theme mask 只强制提交命中字段，其他本地动画保持原实例和进度', (tester) async {
        final driver = StyleAnimationDriver(onTick: () {});
        try {
          final colorAnimation = FieldAnimation(
            field: ElTransitionField.color,
            from: const Color(0xFF000000),
            to: const Color(0xFFFFFFFF),
            duration: const Duration(milliseconds: 200),
          )..advance(const Duration(milliseconds: 40));
          final opacityAnimation = FieldAnimation(
            field: ElTransitionField.opacity,
            from: 0.2,
            to: 0.8,
            duration: const Duration(milliseconds: 200),
          )..advance(const Duration(milliseconds: 40));
          driver.startAnimation(colorAnimation);
          driver.startAnimation(opacityAnimation);

          final old = ResolvedStyleBuilder.empty()
            ..writeColor(colorAnimation.currentValue() as Color?)
            ..writeOpacity(opacityAnimation.currentValue() as double?);
          final parent = ResolvedStyleBuilder.empty()..writeColor(const Color(0xFFFFFFFF));
          final opacityElapsed = opacityAnimation.debugElapsed;

          final result = CascadeTick.tick(
            style: const ElStyle(opacity: 0.8, transitions: [ElTransition.all(Duration(milliseconds: 200))]),
            parent: parent.build(),
            oldCommitted: old.build(),
            state: emptyState,

            driver: driver,
            inheritedThemeAnimationMask: maskBit(ElTransitionField.color.index),
          );

          expect(result.newCommitted.inheritedText.color, const Color(0xFFFFFFFF));
          expect(result.changedMask.fields.toSet(), {ElTransitionField.color});
          expect(driver.animationOf(ElTransitionField.color), isNull, reason: 'mask 命中的旧动画必须取消');
          expect(identical(driver.animationOf(ElTransitionField.opacity), opacityAnimation), isTrue);
          expect(opacityAnimation.debugElapsed, opacityElapsed, reason: '非 mask 字段不能被重启或推进');
          expect(result.newCommitted.box.opacity, opacityAnimation.currentValue());
        } finally {
          driver.dispose();
        }
      });
    });

    group('writeFieldsFromAnimation：driver 中间帧推进', () {
      test('与 old 不等：返回新 committed 和变化字段', () {
        final old = ResolvedStyleBuilder.empty()..writeColor(const Color(0xFFFF0000));
        final (nc, changed) = CascadeTick.writeFieldsFromAnimation(
          oldCommitted: old.build(),
          fieldValues: {ElTransitionField.color: const Color(0xFF0000FF)},
        );
        expect(changed.fields, [ElTransitionField.color]);
        expect(nc.inheritedText.color, const Color(0xFF0000FF));
      });

      test('与 old 相等：复用旧 committed 且无变化字段', () {
        final old = ResolvedStyleBuilder.empty()..writeColor(const Color(0xFFFF0000));
        final oldStyle = old.build();
        final (nc, changed) = CascadeTick.writeFieldsFromAnimation(
          oldCommitted: oldStyle,
          fieldValues: {ElTransitionField.color: const Color(0xFFFF0000)},
        );
        expect(changed.isEmpty, isTrue);
        expect(identical(nc, oldStyle), isTrue, reason: '无变化时返回同实例');
      });
    });
  });

  group('暗色边框过渡', () {
    const cLight = Color(0xFFFFFFFF);

    const cDark = Color(0xFF000000);

    const key = ValueKey('child');

    Widget build(Brightness brightness) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: ElView(
          themeMode: ElThemeMode(
            brightness: brightness,
            duration: const Duration(milliseconds: 200),
            curve: Curves.linear,
          ),
          style: const ElStyle(
            color: cLight,
            onDark: ElStyle(color: cDark),
          ),
          child: ElView(
            key: key,
            style: const ElStyle(
              width: 100,
              height: 60,
              bgColor: cLight,
              border: .all(color: cLight, width: 2),
              onDark: ElStyle(
                bgColor: cDark,
                border: .all(color: cDark, width: 2),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('border 与 bgColor 按同一主题进度插值', (tester) async {
      await tester.pumpWidget(build(Brightness.light));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(Brightness.dark));
      await tester.pump();
      // linear 200ms 中点。
      await tester.pump(const Duration(milliseconds: 100));

      final rv = tester.renderObject<ElRenderView>(find.byKey(key));
      final committed = rv.committedResolvedStyle;
      final bg = committed.box.bgColor;
      final borderColor = committed.box.border?.top.color;
      final mid = Color.lerp(cLight, cDark, 0.5)!;

      expect(bg, isA<Color>(), reason: '过渡中 bgColor 应为插值字面量');
      expect(bg as Color, isSameColorAs(mid), reason: 'bgColor 应在 theme 过渡中点');
      expect(borderColor, isA<Color>(), reason: '过渡中 border 色应为插值字面量（当前 bug：仍持引用 → 瞬跳）');
      expect(borderColor as Color, isSameColorAs(mid), reason: 'border 必须与 bgColor 同一进度（theme 统一过渡）');
    });

    testWidgets('过渡完成态：border 与背景收敛到 dark 端点', (tester) async {
      await tester.pumpWidget(build(Brightness.light));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(Brightness.dark));
      await tester.pumpAndSettle();

      final rv = tester.renderObject<ElRenderView>(find.byKey(key));
      final committed = rv.committedResolvedStyle;
      // 完成后提交值与绘制值均为暗色端点。
      expect(committed.box.border?.top.color, cDark);
      expect(committed.box.bgColor, cDark);
      // paint 产物为 dark 端点色。
      expect(
        find.byKey(key),
        paints
          ..rect(color: cDark)
          ..rect(color: cDark, style: PaintingStyle.stroke),
      );
    });
  });

  group('关键帧动画', () {
    ElRenderView renderOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    const k = ValueKey('anim');

    double? opacityOf(WidgetTester tester) {
      final v = renderOf(tester, k).committedResolvedStyle.box.opacity;
      return v == null ? null : (v as num).toDouble();
    }

    Widget buildOpacityAnim({
      double iterationCount = 1,
      ElAnimationDirection direction = ElAnimationDirection.normal,
      ElAnimationFillMode fillMode = ElAnimationFillMode.none,
      bool paused = false,
      double? baseOpacity,
      List<ElTransition>? transitions,
    }) {
      return MaterialApp(
        home: ElView(
          key: k,
          style: ElStyle(
            width: 50,
            height: 50,
            bgColor: const Color(0xFF222222),
            opacity: baseOpacity,
            transitions: transitions,
            animations: [
              ElAnimation(
                keyframes: const {0: ElStyle(opacity: 0), 100: ElStyle(opacity: 1)},
                duration: const Duration(seconds: 1),
                curve: Curves.linear,
                iterationCount: iterationCount,
                direction: direction,
                fillMode: fillMode,
                paused: paused,
              ),
            ],
          ),
        ),
      );
    }

    group('基础采样', () {
      testWidgets('挂载即应用首帧；中点采样 0.5', (tester) async {
        await tester.pumpWidget(buildOpacityAnim(iterationCount: double.infinity));
        // 挂载同步采样：progress 0 → opacity 0。
        expect(opacityOf(tester), closeTo(0, 0.001));
        await tester.pump(); // ticker 基线帧
        await tester.pump(const Duration(milliseconds: 500));
        expect(opacityOf(tester), closeTo(0.5, 0.02));
      });

      testWidgets('无限循环：第二迭代继续插值', (tester) async {
        await tester.pumpWidget(buildOpacityAnim(iterationCount: double.infinity));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1250));
        // 第二迭代 progress 0.25。
        expect(opacityOf(tester), closeTo(0.25, 0.02));
      });

      testWidgets('direction alternate：奇数迭代反向', (tester) async {
        await tester.pumpWidget(
          buildOpacityAnim(iterationCount: double.infinity, direction: ElAnimationDirection.alternate),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1250));
        // 第 1 次迭代（奇数）反向：p=0.25 → 0.75。
        expect(opacityOf(tester), closeTo(0.75, 0.02));
      });
    });

    group('fillMode 与结束态', () {
      testWidgets('fillMode none：播完回 base', (tester) async {
        await tester.pumpWidget(buildOpacityAnim(baseOpacity: 0.9));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump(const Duration(milliseconds: 100)); // 收尾 tick
        expect(opacityOf(tester), closeTo(0.9, 0.001));
      });

      testWidgets('fillMode forwards：停在末帧', (tester) async {
        await tester.pumpWidget(buildOpacityAnim(baseOpacity: 0.9, fillMode: ElAnimationFillMode.forwards));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump(const Duration(milliseconds: 100));
        expect(opacityOf(tester), closeTo(1.0, 0.001));
      });
    });

    group('隐式端点与暂停', () {
      testWidgets('仅 50% 帧：0→0.5 段从 base 渐出、0.5→1 段渐回 base', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ElView(
              key: k,
              style: const ElStyle(
                width: 50,
                height: 50,
                opacity: 1.0,
                animations: [
                  ElAnimation(
                    keyframes: {50: ElStyle(opacity: 0)},
                    duration: Duration(seconds: 1),
                    curve: Curves.linear,
                    iterationCount: double.infinity,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        // base(1.0) → 0 段的中点。
        expect(opacityOf(tester), closeTo(0.5, 0.02));
        await tester.pump(const Duration(milliseconds: 500));
        // 0 → base(1.0) 段的中点（t=0.75）。
        expect(opacityOf(tester), closeTo(0.5, 0.02));
      });

      testWidgets('paused：时钟冻结在首帧', (tester) async {
        await tester.pumpWidget(buildOpacityAnim(iterationCount: double.infinity, paused: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(opacityOf(tester), closeTo(0, 0.001));
      });
    });

    group('声明变更与级联交互', () {
      testWidgets('声明移除 → 字段回 base', (tester) async {
        await tester.pumpWidget(buildOpacityAnim(iterationCount: double.infinity, baseOpacity: 0.9));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(opacityOf(tester), closeTo(0.5, 0.02));
        // rebuild 无 animations。
        await tester.pumpWidget(
          const MaterialApp(
            home: ElView(
              key: k,
              style: ElStyle(width: 50, height: 50, bgColor: Color(0xFF222222), opacity: 0.9),
            ),
          ),
        );
        expect(opacityOf(tester), closeTo(0.9, 0.001));
      });

      testWidgets('10s transition 不拖慢 1s 动画（动画变化不触发 transition）', (tester) async {
        await tester.pumpWidget(
          buildOpacityAnim(
            iterationCount: double.infinity,
            transitions: [const ElTransition.all(Duration(seconds: 10))],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        // 若被 transition 接管，10s 时长下 500ms 处远小于 0.5。
        expect(opacityOf(tester), closeTo(0.5, 0.02));
      });

      testWidgets('onHover 空表停止动画（longhand 覆盖），离开后从头重启', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            // Stack 给宽松约束：ElView 真实落成 50×50（直接作 home 会被 tight
            // 约束 enforce 成全屏，指针根本移不出盒外）。
            home: Stack(
              children: [
                ElView(
                  key: k,
                  style: const ElStyle(
                    width: 50,
                    height: 50,
                    bgColor: Color(0xFF222222),
                    opacity: 0.9,
                    animations: [
                      ElAnimation(
                        keyframes: {0: ElStyle(opacity: 0), 100: ElStyle(opacity: 1)},
                        duration: Duration(seconds: 1),
                        curve: Curves.linear,
                        iterationCount: double.infinity,
                      ),
                    ],
                    onHover: ElStyle(animations: []),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(opacityOf(tester), closeTo(0.5, 0.02));

        final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await tester.pump();
        await gesture.moveTo(tester.getCenter(find.byKey(k)));
        await tester.pump();
        // hover：空表覆盖 → 动画摘除 → 回 base。
        expect(opacityOf(tester), closeTo(0.9, 0.001));

        await gesture.moveTo(const Offset(200, 200));
        await tester.pump();
        // 离开：动画重启（CSS animation-name 重新出现 → 从头播）→ 首帧 0。
        expect(opacityOf(tester), closeTo(0, 0.001));
      });

      testWidgets('GlobalKey 重挂（父链 resolved 不变）：动画从头重播，不冻结', (tester) async {
        // 安卓预测性返回事故的最小复现：手势开始瞬间路由过渡包装换类型，页面
        // 子树靠 ModalRoute._subtreeKey（GlobalKey）保活 → 整棵 render 子树
        // detach → attach，父链 resolved identical。detach 已按 CSS 摘树口径清零
        // keyframe 时钟，re-attach 必须重建时钟从头播，不许冻死在摘树前最后一帧。
        final gk = GlobalKey();
        // widget 实例保持稳定：重挂时 element 不重建、style 不重设，
        // 时钟重建只能靠 attach 路径自己触发。
        final anim = ElView(
          key: gk,
          style: const ElStyle(
            width: 50,
            height: 50,
            animations: [
              ElAnimation(
                keyframes: {0: ElStyle(opacity: 0), 100: ElStyle(opacity: 1)},
                duration: Duration(seconds: 1),
                curve: Curves.linear,
                iterationCount: double.infinity,
              ),
            ],
          ),
        );
        Widget wrap({required bool nested}) => MaterialApp(
          home: Stack(children: [if (nested) Center(child: anim) else anim]),
        );
        double? gkOpacity() {
          final v = renderOf(tester, gk).committedResolvedStyle.box.opacity;
          return v == null ? null : (v as num).toDouble();
        }

        await tester.pumpWidget(wrap(nested: false));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(gkOpacity(), closeTo(0.25, 0.02));
        // 换包装深度触发 GlobalKey reparent（同帧 detach + attach）。
        await tester.pumpWidget(wrap(nested: true));
        await tester.pump(const Duration(milliseconds: 500));
        // 从头重播 → 500ms 处 0.5；冻结缺陷下卡死在 0.25。
        expect(gkOpacity(), closeTo(0.5, 0.02), reason: '重挂后时钟必须重建从头播');
        await tester.pump(const Duration(milliseconds: 200));
        expect(gkOpacity(), closeTo(0.7, 0.02), reason: '重挂后时钟必须持续推进');
      });
    });
  });

  group('首次挂载过渡', () {
    ElRenderView findRender(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView));

    group('mount 时不启动 transition', () {
      testWidgets('根 transitions=[all()] + 首次 mount：committed=target，不启 animation', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                style: ElStyle(
                  width: 200,
                  height: 60,
                  color: Color(0xFF000000),
                  bgColor: Color(0xFFFF0000),
                  fontSize: 18,
                  transitions: [ElTransition.all()],
                ),
              ),
            ),
          ),
        );

        final box = findRender(tester);
        // committed 直接是目标值（初始 mount → target 应一帧到位）
        expect(box.committedResolvedStyle.inheritedText.color, const Color(0xFF000000));
        expect(box.committedResolvedStyle.box.bgColor, const Color(0xFFFF0000));
        expect(box.committedResolvedStyle.inheritedText.fontSize, 18);

        // 不应启动动画（mount 直接对齐 target）
        expect(box.hasActiveAnimationsForTest, isFalse);
      });

      testWidgets('mount 后立即 setHover：触发 transition（_transitionsEnabled=true）', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                style: ElStyle(
                  width: 200,
                  height: 60,
                  color: Color(0xFF000000),
                  onHover: ElStyle(color: Color(0xFF0000FF)),
                  transitions: [ElTransition.all()],
                ),
              ),
            ),
          ),
        );

        final box = findRender(tester);
        expect(box.hasActiveAnimationsForTest, isFalse, reason: 'mount 后未 hover');

        box.setHover(true);
        await tester.pump();

        expect(
          box.hasActiveAnimationsForTest,
          isTrue,
          reason: 'attach 已完成 → _transitionsEnabled=true → setHover 触发 transition',
        );
      });

      testWidgets('嵌套 ElView：父 + 子 mount 都不启动 transition', (tester) async {
        const parentKey = ValueKey('parent');
        const childKey = ValueKey('child');

        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                key: parentKey,
                style: ElStyle(color: Color(0xFFFF0000), transitions: [ElTransition.all()]),
                child: ElView(
                  key: childKey,
                  style: ElStyle(transitions: [ElTransition.all()]),
                  child: 'inherited',
                ),
              ),
            ),
          ),
        );

        final parent = tester.renderObject<ElRenderView>(find.byKey(parentKey));
        final child = tester.renderObject<ElRenderView>(find.byKey(childKey));
        // 父 + 子都不应有活跃动画（mount 直接对齐 target）
        expect(parent.hasActiveAnimationsForTest, isFalse);
        expect(child.hasActiveAnimationsForTest, isFalse);
        // 子继承父 color
        expect(child.committedResolvedStyle.inheritedText.color, const Color(0xFFFF0000));
      });

      testWidgets('mount 后立即改 widget.style.color：触发 transition', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                style: ElStyle(width: 200, height: 60, color: Color(0xFF000000), transitions: [ElTransition.all()]),
              ),
            ),
          ),
        );

        final box = findRender(tester);
        expect(box.hasActiveAnimationsForTest, isFalse);

        // widget update 改 color
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                style: ElStyle(
                  width: 200,
                  height: 60,
                  color: Color(0xFF0000FF), // 改
                  transitions: [ElTransition.all()],
                ),
              ),
            ),
          ),
        );

        expect(box.hasActiveAnimationsForTest, isTrue, reason: 'attach 后 widget update：style.color 变化 → 走 transition');
      });

      testWidgets('mount 不启 transition：父 color → 子继承到 mount 帧直接生效', (tester) async {
        const childKey = ValueKey('child');

        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                style: ElStyle(color: Color(0xFFFF0000), transitions: [ElTransition.all()]),
                child: ElView(key: childKey, child: 'inherited'),
              ),
            ),
          ),
        );

        final inner = tester.renderObject<ElRenderView>(find.byKey(childKey));
        // 子 mount 时通过 attach 反查到父 color，cascade 立即写入 inheritedText.color
        // —— 这步本身就应该是 mount 阶段，不该启动 transition
        expect(inner.committedResolvedStyle.inheritedText.color, const Color(0xFFFF0000));
        expect(inner.hasActiveAnimationsForTest, isFalse);
      });

      testWidgets('layoutCount 验证：mount 走非动画路径，不会因 driver 触发多帧重绘', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                style: ElStyle(
                  width: 200,
                  height: 60,
                  color: Color(0xFF000000),
                  fontSize: 14,
                  transitions: [ElTransition.all()],
                ),
              ),
            ),
          ),
        );

        final box = findRender(tester);
        final mountCount = box.debugLayoutCount;

        // pump 推进多帧：若 mount 启动了 transition，driver 会让多次 _onAnimTick 触发
        // 哪怕字段是 paint-only color，至少 fontSize 这种 layout-affecting transition
        // 会重排（如果有的话）。本场景只有 color，不影响 layout，但作为冒烟看
        // layoutCount 是否被 driver 间接干扰。
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(box.debugLayoutCount, mountCount, reason: 'mount 不启动 transition → 没有 driver ticker → 不会触发额外重排');
      });
    });
  });

  group('入场与离场', () {
    const k = ValueKey('p');

    double? opacityOf(WidgetTester tester) {
      final v = tester.renderObject<ElRenderView>(find.byKey(k)).committedResolvedStyle.box.opacity;
      return v == null ? null : (v as num).toDouble();
    }

    group('ElStyle.starting', () {
      Widget host({List<ElTransition>? transitions}) => MaterialApp(
        home: Stack(
          children: [
            ElView(
              key: k,
              style: ElStyle(
                width: 50,
                height: 50,
                opacity: 1.0,
                bgColor: const Color(0xFF222222),
                starting: const ElStyle(opacity: 0),
                transitions: transitions,
              ),
            ),
          ],
        ),
      );

      testWidgets('挂载帧钉在起始值，随 transition 播向 base', (tester) async {
        await tester.pumpWidget(host(transitions: [const ElTransition.all(Duration(seconds: 1), Curves.linear)]));
        expect(opacityOf(tester), closeTo(0, 0.001));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(opacityOf(tester), closeTo(0.5, 0.02));
        await tester.pump(const Duration(milliseconds: 600));
        expect(opacityOf(tester), closeTo(1.0, 0.001));
      });

      testWidgets('无 transition 覆盖 → 无效果', (tester) async {
        await tester.pumpWidget(host());
        expect(opacityOf(tester), closeTo(1.0, 0.001));
      });

      testWidgets('reduced-motion 下整体跳过', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pumpWidget(host(transitions: [const ElTransition.all(Duration(seconds: 1))]));
        expect(opacityOf(tester), closeTo(1.0, 0.001));
      });
    });
  });

  group('减少动画偏好', () {
    const k = ValueKey('box');

    Widget build({required bool selected}) => MaterialApp(
      home: Stack(
        children: [
          ElView(
            key: k,

            style: ElStyle(
              width: 50,
              height: 50,
              bgColor: selected ? Color(0xFFFFFFFF) : Color(0xFF000000),
              transitions: [ElTransition.all(Duration(seconds: 10))],
            ),
          ),
        ],
      ),
    );

    Color? bgOf(WidgetTester tester) =>
        tester.renderObject<ElRenderView>(find.byKey(k)).committedResolvedStyle.box.bgColor;

    testWidgets('开启：10s transition 声明被忽略，selected 切换瞬跳', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(build(selected: false));
      await tester.pumpWidget(build(selected: true));
      expect(bgOf(tester), const Color(0xFFFFFFFF));
    });

    testWidgets('对照组：开关关闭时同场景走过渡', (tester) async {
      await tester.pumpWidget(build(selected: false));
      await tester.pumpWidget(build(selected: true));
      // 过渡刚启动：committed 仍钉在旧值。
      expect(bgOf(tester), const Color(0xFF000000));
    });

    testWidgets('keyframe 动画不受开关影响', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              ElView(
                key: k,
                style: const ElStyle(
                  width: 50,
                  height: 50,
                  animations: [
                    ElAnimation(
                      keyframes: {0: ElStyle(opacity: 0), 100: ElStyle(opacity: 1)},
                      duration: Duration(seconds: 1),
                      curve: Curves.linear,
                      iterationCount: double.infinity,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final opacity = tester.renderObject<ElRenderView>(find.byKey(k)).committedResolvedStyle.box.opacity;
      expect((opacity! as num).toDouble(), closeTo(0.5, 0.02));
    });
  });

  group('重挂载过渡', () {
    for (final releaseBeforeReattach in [false, true]) {
      testWidgets('tap 中途重挂清除残留并恢复后续交互：已抬起=$releaseBeforeReattach', (tester) async {
        final pageKey = GlobalKey();
        final viewKey = GlobalKey();
        final white = Color(0xffffffff);
        final black = Color(0xff000000);
        var taps = 0;
        final view = ElView(
          key: viewKey,
          event: ElEvent(onTap: (_) => taps++),
          style: ElStyle(
            width: 100,
            height: 50,
            bgColor: white,
            opacity: 1,
            onTap: ElStyle(width: 150, bgColor: black, opacity: .5),
            transitions: [ElTransition.all(Duration(milliseconds: 300), Curves.linear)],
          ),
        );
        final page = ElView(
          key: pageKey,
          style: ElStyle(width: 300, height: 200, alignment: .topLeft),
          child: view,
        );
        Widget tree(bool nested) => Directionality(
          textDirection: .ltr,
          child: ElView(
            style: ElStyle(alignment: .topLeft),
            child: nested ? Column(mainAxisSize: .min, children: [page]) : page,
          ),
        );
        await tester.pumpWidget(tree(false));
        final render = tester.renderObject<ElRenderView>(find.byKey(viewKey));
        final touch = await tester.startGesture(tester.getCenter(find.byKey(viewKey)));
        await tester.pump();
        if (releaseBeforeReattach) {
          await tester.pumpAndSettle();
          await touch.up();
          await tester.pump();
        }
        await tester.pump(Duration(milliseconds: 90));
        expect(render.hasActiveAnimationsForTest, isTrue);
        expect(render.committedResolvedStyle.box.bgColor, isNot(white));
        expect(render.committedResolvedStyle.box.bgColor, isNot(black));
        expect(render.committedResolvedStyle.box.opacity, inExclusiveRange(.5, 1));
        expect(tester.getSize(find.byKey(viewKey)).width, inExclusiveRange(100, 150));
        expect(render.internalStateHas(ViewState.tap), !releaseBeforeReattach);

        await tester.pumpWidget(tree(true));
        expect(tester.renderObject<ElRenderView>(find.byKey(viewKey)), same(render));
        // 重挂不是手势结束：手指还按着时，按压状态与它对应的目标样式都要原样保留；
        // 已抬手的那一支本来就该回基础态。
        expect(render.internalStateHas(ViewState.tap), !releaseBeforeReattach);
        expect(render.hasActiveAnimationsForTest, isFalse, reason: '重挂首帧直接落到当前状态对应的样式，不残留过渡');
        expect(
          render.committedResolvedStyle.box.bgColor,
          releaseBeforeReattach ? white : black,
          reason: '重挂首帧应恢复当前按压状态对应的颜色，不得留下中间色',
        );
        expect(render.committedResolvedStyle.box.opacity, releaseBeforeReattach ? 1 : .5);
        expect(tester.getSize(find.byKey(viewKey)).width, releaseBeforeReattach ? 100 : 150, reason: '布局字段也应在重挂首帧恢复');
        if (!releaseBeforeReattach) await touch.up();
        // 让离场过渡走完：过渡启动帧只是 Ticker 的基线（首帧 elapsed 恒为 0，
        // 不推进进度），单帧 pump 会让样式停在起始值上。
        await tester.pumpAndSettle();
        expect(taps, 1, reason: '重挂不是手势结束，抬手仍要完成这次点击');
        expect(render.committedResolvedStyle.box.bgColor, white, reason: '离场过渡必须把样式带回常态');
        expect(render.committedResolvedStyle.box.opacity, 1);

        final nextTouch = await tester.startGesture(tester.getCenter(find.byKey(viewKey)));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 90));
        expect(render.internalStateHas(ViewState.tap), isTrue);
        expect(render.hasActiveAnimationsForTest, isTrue);
        expect(render.committedResolvedStyle.box.opacity, inExclusiveRange(.5, 1));
        await tester.pumpAndSettle();
        expect(render.committedResolvedStyle.box.bgColor, black);
        expect(tester.getSize(find.byKey(viewKey)).width, 150);
        await nextTouch.up();
        await tester.pump();
        await tester.pump(Duration(milliseconds: 90));
        expect(render.hasActiveAnimationsForTest, isTrue, reason: '新的抬手退场过渡仍正常播放');
        expect(render.committedResolvedStyle.box.opacity, inExclusiveRange(.5, 1));
        await tester.pumpAndSettle();
        expect(taps, 2);
        expect(render.committedResolvedStyle.box.bgColor, white);
        expect(render.committedResolvedStyle.box.opacity, 1);
        expect(tester.getSize(find.byKey(viewKey)).width, 100);
      });
    }

    testWidgets('GlobalKey reparent 到不同继承上下文：snap 不启 transition', (tester) async {
      final key = GlobalKey();
      // 子声明 transitions:[all()] 且不显式 color → 继承父 color
      Widget child() => ElView(
        key: key,
        style: const ElStyle(transitions: <ElTransition>[ElTransition.all()]),
        child: 'x',
      );

      Widget tree({required bool underBlue}) => MaterialApp(
        home: Column(
          children: <Widget>[
            // parent A：red
            ElView(
              style: const ElStyle(color: Color(0xFFFF0000)),
              child: underBlue ? const SizedBox() : child(),
            ),
            // parent B：blue
            ElView(
              style: const ElStyle(color: Color(0xFF0000FF)),
              child: underBlue ? child() : const SizedBox(),
            ),
          ],
        ),
      );

      await tester.pumpWidget(tree(underBlue: false)); // 子挂在 red 父下
      var rt = key.currentContext!.findRenderObject()! as ElRenderView;
      expect(rt.committedResolvedStyle.inheritedText.color, const Color(0xFFFF0000));
      expect(rt.hasActiveAnimationsForTest, isFalse);

      await tester.pumpWidget(tree(underBlue: true)); // reparent 到 blue 父下
      rt = key.currentContext!.findRenderObject()! as ElRenderView;

      expect(rt.hasActiveAnimationsForTest, isFalse, reason: 'reparent 到不同继承上下文应像 mount 一样 snap，不启 transition');
      expect(
        rt.committedResolvedStyle.inheritedText.color,
        const Color(0xFF0000FF),
        reason: 're-attach 一帧 snap 到新父 blue',
      );
    });
  });

  group('起始样式重挂载', () {
    for (final finish in [false, true]) {
      for (final changeInheritance in [false, true]) {
        testWidgets('starting 重挂不重播：已结束=$finish，换继承=$changeInheritance', (tester) async {
          final key = GlobalKey();
          final view = ElView(
            key: key,
            style: ElStyle(
              width: 50,
              height: 50,
              opacity: 1,
              starting: ElStyle(opacity: 0),
              transitions: [ElTransition.all(Duration(seconds: 1), Curves.linear)],
            ),
          );
          Widget tree(bool nested) => Directionality(
            textDirection: .ltr,
            child: ElView(
              style: ElStyle(color: Color(0xff000000)),
              child: nested
                  ? changeInheritance
                        ? ElView(
                            style: ElStyle(color: Color(0xffff0000)),
                            child: view,
                          )
                        : Column(children: [view])
                  : view,
            ),
          );
          await tester.pumpWidget(tree(false));
          final render = tester.renderObject<ElRenderView>(find.byKey(key));
          expect(render.committedResolvedStyle.box.opacity, 0);
          await tester.pump();
          await tester.pump(Duration(milliseconds: finish ? 1100 : 250));
          expect(render.committedResolvedStyle.box.opacity, closeTo(finish ? 1 : .25, .02));
          await tester.pumpWidget(tree(true));
          expect(tester.renderObject<ElRenderView>(find.byKey(key)), same(render));
          expect(render.committedResolvedStyle.box.opacity, 1);
          expect(render.hasActiveAnimationsForTest, isFalse);
          if (changeInheritance) {
            expect(render.committedResolvedStyle.inheritedText.color, Color(0xffff0000));
          }
          await tester.pump(Duration(milliseconds: 500));
          expect(render.committedResolvedStyle.box.opacity, 1);
        });
      }
    }

    testWidgets('真正卸载后新建仍播放入场，普通样式更新仍有过渡', (tester) async {
      final key = GlobalKey();
      Widget tree({double opacity = 1}) => Directionality(
        textDirection: .ltr,
        child: ElView(
          key: key,
          style: ElStyle(
            width: 50,
            height: 50,
            opacity: opacity,
            starting: ElStyle(opacity: 0),
            transitions: [ElTransition.all(Duration(seconds: 1), Curves.linear)],
          ),
        ),
      );
      await tester.pumpWidget(tree());
      final old = tester.renderObject<ElRenderView>(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.pumpWidget(ElView());
      await tester.pumpWidget(tree());
      final render = tester.renderObject<ElRenderView>(find.byKey(key));
      expect(render, isNot(same(old)));
      expect(render.committedResolvedStyle.box.opacity, 0);
      await tester.pumpAndSettle();
      await tester.pumpWidget(tree(opacity: .2));
      await tester.pump(Duration(milliseconds: 500));
      expect(render.committedResolvedStyle.box.opacity, closeTo(.6, .02));
      await tester.pumpAndSettle();
      expect(render.committedResolvedStyle.box.opacity, .2);
    });
  });

  group('按下态文字继承过渡', () {
    Widget shell(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('tap variant introducing inherited text color does not fade text in from transparent', (tester) async {
      const boxKey = ValueKey('box');
      const textKey = ValueKey('text');

      await tester.pumpWidget(
        shell(
          const ElView(
            key: boxKey,
            style: ElStyle(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              bgColor: Colors.grey,
              transitions: [ElTransition.all(Duration(milliseconds: 200))],
              onTap: ElStyle(width: 80, height: 150, bgColor: Colors.yellow, color: Colors.black),
            ),
            child: ElView(key: textKey, child: 'hello'),
          ),
        ),
      );

      final box = tester.renderObject<ElRenderView>(find.byKey(boxKey));
      final text = tester.renderObject<ElRenderView>(find.byKey(textKey));

      expect(text.committedResolvedStyle.inheritedText.color, Colors.black);

      box.setTap(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(box.hasActiveAnimationsForTest, isTrue, reason: 'width/height/bgColor should still animate');
      expect(
        text.committedResolvedStyle.inheritedText.color,
        Colors.black,
        reason:
            'Text inherited color should start from the CSS default black. '
            'Animating an undeclared root color as transparent -> black makes BoxPage text fade in.',
      );
    });
  });

  group('文字背景色状态过渡', () {
    ElRenderView renderOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    const base = Color(0xFF113355);

    const active = Color(0xFFFFDD22);

    const baseBg = Color(0xFF220044);

    const activeBg = Color(0xFF44AA66);

    final half = Color.lerp(base, active, 0.5)!;

    final halfBg = Color.lerp(baseBg, activeBg, 0.5)!;

    group('事件状态变体过渡', () {
      testWidgets('onHover 换 textBackgroundColor：半程精确 50% lerp，与 bgColor 对照同进度', (tester) async {
        const k = ValueKey('hover');
        await tester.pumpWidget(
          _directionalApp(
            const ElView(
              key: k,
              style: ElStyle(
                width: 120,
                height: 40,
                bgColor: baseBg,
                textBackgroundColor: base,
                onHover: ElStyle(bgColor: activeBg, textBackgroundColor: active),
                transitions: [ElTransition.all(Duration(milliseconds: 400), Curves.linear)],
              ),
              child: 'Hi',
            ),
          ),
        );
        await tester.pump();

        final box = renderOf(tester, k);
        expect(box.committedResolvedStyle.inheritedText.textBackgroundColor, base);

        box.setHover(true);
        await tester.pump();
        expect(box.hasActiveAnimationsForTest, isTrue, reason: 'hover 激活应启动过渡动画');

        await tester.pump(const Duration(milliseconds: 200));
        expect(box.committedResolvedStyle.box.bgColor, halfBg, reason: '对照字段 bgColor 半程 50%（过渡机制本身在跑）');
        expect(
          box.committedResolvedStyle.inheritedText.textBackgroundColor,
          half,
          reason: 'textBackgroundColor 半程应为精确 50% lerp——若已是终点值即瞬跳 bug',
        );

        await tester.pump(const Duration(milliseconds: 210));
        expect(box.committedResolvedStyle.inheritedText.textBackgroundColor, active);
        expect(box.hasActiveAnimationsForTest, isFalse);

        // 反向：hover 撤销同样过渡
        box.setHover(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(box.committedResolvedStyle.inheritedText.textBackgroundColor, half, reason: '撤销 hover 半程同样 50%');
        await tester.pump(const Duration(milliseconds: 210));
        expect(box.committedResolvedStyle.inheritedText.textBackgroundColor, base);
      });

      testWidgets('onTap 换 textBackgroundColor：半程精确 50% lerp', (tester) async {
        const k = ValueKey('tap');
        await tester.pumpWidget(
          _directionalApp(
            const ElView(
              key: k,
              style: ElStyle(
                width: 120,
                height: 40,
                textBackgroundColor: base,
                onTap: ElStyle(textBackgroundColor: active),
                transitions: [ElTransition.all(Duration(milliseconds: 400), Curves.linear)],
              ),
              child: 'Hi',
            ),
          ),
        );
        await tester.pump();

        final box = renderOf(tester, k);
        box.setTap(true);
        await tester.pump();
        expect(box.hasActiveAnimationsForTest, isTrue, reason: 'tap 激活应启动过渡动画');

        await tester.pump(const Duration(milliseconds: 200));
        expect(
          box.committedResolvedStyle.inheritedText.textBackgroundColor,
          half,
          reason: 'textBackgroundColor 半程应为精确 50% lerp——若已是终点值即瞬跳 bug',
        );

        await tester.pump(const Duration(milliseconds: 210));
        expect(box.committedResolvedStyle.inheritedText.textBackgroundColor, active);
      });
    });

    group('暗黑模式过渡', () {
      testWidgets('onDark 直接换 textBackgroundColor：dark 统一过渡半程 50%', (tester) async {
        const k = ValueKey('dark-direct');
        Widget build(Brightness b) => _directionalApp(
          ElView(
            key: k,
            themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 400), curve: Curves.linear),
            style: const ElStyle(
              width: 120,
              height: 40,
              bgColor: baseBg,
              textBackgroundColor: base,
              onDark: ElStyle(bgColor: activeBg, textBackgroundColor: active),
            ),
            child: 'Hi',
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();
        final box = renderOf(tester, k);
        expect(box.committedResolvedStyle.inheritedText.textBackgroundColor, base);

        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(box.committedResolvedStyle.box.bgColor, halfBg, reason: '对照字段 bgColor 半程 50%（dark 统一过渡在跑）');
        expect(
          box.committedResolvedStyle.inheritedText.textBackgroundColor,
          half,
          reason: 'textBackgroundColor 半程应为精确 50% lerp——若已是终点值即瞬跳 bug',
        );

        await tester.pump(const Duration(milliseconds: 210));
        expect(box.committedResolvedStyle.inheritedText.textBackgroundColor, active);
        expect(box.hasActiveAnimationsForTest, isFalse);
      });

      // inline 变体过渡引擎（InlineVariantAnimator）落地后启用：dark 统一过渡
      // 强制覆盖 inline owner（无视自身 transitions 声明，对齐宿主 T-theme10）。
      testWidgets('富文本 inline span（复刻 richtext 示例）：onDark 换 textBackgroundColor 半程 50%', (tester) async {
        // 对应 ui_example richtext.dart 的 inline code 用法：
        // 段落 child 列表里嵌 ElView，span 自带 textBackgroundColor + onDark。
        // 当前 inline ElView 通过 WidgetSpan 挂载，探针读取子节点实际绘制的文字样式。
        const paraKey = ValueKey('inline-para');
        const codeKey = ValueKey('inline-code');
        Widget build(Brightness b) => _directionalApp(
          ElView(
            key: paraKey,
            themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 400), curve: Curves.linear),
            style: const ElStyle(
              width: 400,
              fontSize: 14,
              color: Color(0xFF334155),
              onDark: ElStyle(color: Color(0xFFE2E8F0)),
            ),
            child: const [
              '你也可以嵌入 ',
              ElView(
                key: codeKey,
                child: 'ElStyle',
                style: ElStyle(
                  textBackgroundColor: base,
                  onDark: ElStyle(textBackgroundColor: active),
                ),
              ),
              ' 这样的代码片段。',
            ],
          ),
        );

        TextStyle? codeSpanStyle() =>
            (renderOf(tester, codeKey).textEngineForTest!.painterForTest.text! as TextSpan).style;

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();
        expect(codeSpanStyle()?.backgroundColor, base, reason: 'light 起点');

        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          codeSpanStyle()?.backgroundColor,
          half,
          reason: 'inline span textBackgroundColor 半程应为 50% lerp——若已是终点值即瞬跳 bug',
        );

        await tester.pump(const Duration(milliseconds: 210));
        expect(codeSpanStyle()?.backgroundColor, active);
      });
    });
  });

  group('主题动画帧同步', () {
    Color elViewBackground(WidgetTester tester) {
      final render = tester.renderObject<ElRenderView>(find.byKey(_elViewBodyKey));
      return render.committedResolvedStyle.box.bgColor!;
    }

    Color animatedContainerBackground(WidgetTester tester, Key key) {
      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox)).first,
      );
      return (decoratedBox.decoration as BoxDecoration).color!;
    }

    testWidgets('ElView 与示例 AnimatedContainer 在每次切换的首个真实帧保持同一主题进度', (tester) async {
      final harnessKey = GlobalKey<_DemoHarnessState>();
      await tester.pumpWidget(_DemoHarness(key: harnessKey));

      expect(elViewBackground(tester), _lightColor);
      expect(animatedContainerBackground(tester, _contextVarContainerKey), _lightColor);
      expect(animatedContainerBackground(tester, _animatedContainerKey), _lightColor);

      harnessKey.currentState!.toggleTheme();
      await tester.pump();
      await tester.pump(_firstFrameDuration);

      final expected = Color.lerp(
        _lightColor,
        _darkColor,
        _firstFrameDuration.inMicroseconds / _animationDuration.inMicroseconds,
      )!;
      final contextVarColor = animatedContainerBackground(tester, _contextVarContainerKey);
      final flutterColor = animatedContainerBackground(tester, _animatedContainerKey);

      expect(flutterColor, expected, reason: 'Flutter 对照动画应消费首个 16ms');
      expect(elViewBackground(tester), flutterColor, reason: 'ElView 不应丢弃首个真实 vsync 而比 AnimatedContainer 慢一帧');
      expect(contextVarColor, flutterColor, reason: 'ElView.of(context) 方块应与同帧启动的 Flutter 对照动画同步');

      await tester.pump(_animationDuration - _firstFrameDuration);
      expect(elViewBackground(tester), _darkColor);
      expect(animatedContainerBackground(tester, _contextVarContainerKey), _darkColor);
      expect(animatedContainerBackground(tester, _animatedContainerKey), _darkColor);

      harnessKey.currentState!.toggleTheme();
      await tester.pump();
      await tester.pump(_firstFrameDuration);

      final reverseExpected = Color.lerp(
        _darkColor,
        _lightColor,
        _firstFrameDuration.inMicroseconds / _animationDuration.inMicroseconds,
      )!;
      final reverseContextVarColor = animatedContainerBackground(tester, _contextVarContainerKey);
      final reverseFlutterColor = animatedContainerBackground(tester, _animatedContainerKey);

      expect(reverseFlutterColor, reverseExpected, reason: 'Flutter 对照动画反向时应消费首个 16ms');
      expect(elViewBackground(tester), reverseFlutterColor, reason: 'ElView ticker 重启后仍应与 AnimatedContainer 保持同一首帧进度');
      expect(reverseContextVarColor, reverseFlutterColor, reason: 'ElView.of(context) 方块反向切换时也应同步启动');
    });
  });

  group('主题动画与状态边界', () {
    ElRenderView renderOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    Color backgroundOf(WidgetTester tester, Key key) =>
        renderOf(tester, key).committedResolvedStyle.inheritedText.color!;

    testWidgets('active self 与 nested 动画不被祖先 theme tick 取消', (tester) async {
      const rootKey = ValueKey('variant-root');
      const selfKey = ValueKey('self-variant');
      const nestedKey = ValueKey('nested-variant');
      const selfEnd = Color(0xFFFF0000);
      const nestedEnd = Color(0xFF00FF00);
      const variantDuration = Duration(milliseconds: 320);
      const colorTransition = ElTransition.field(ElTransitionField.color, variantDuration, Curves.linear);

      Widget build(Brightness brightness) => MaterialApp(
        home: ElView(
          key: rootKey,
          themeMode: ElThemeMode(brightness: brightness, duration: _themeDuration, curve: Curves.linear),
          style: const ElStyle(
            color: _start,
            onDark: ElStyle(color: _themeEnd),
          ),
          child: [
            const ElView(
              key: selfKey,
              style: ElStyle(
                transitions: [colorTransition],
                onHover: ElStyle(color: selfEnd),
              ),
            ),
            const ElView(
              key: nestedKey,
              style: ElStyle(
                transitions: [colorTransition],
                onHover: ElStyle(onTap: ElStyle(color: nestedEnd)),
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(build(Brightness.light));
      await tester.pump();
      final root = renderOf(tester, rootKey);
      final self = renderOf(tester, selfKey);
      final nested = renderOf(tester, nestedKey);
      root.setHover(true);
      self.setHover(true);
      nested.setHover(true);
      nested.setTap(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(backgroundOf(tester, selfKey), Color.lerp(_start, selfEnd, 0.25));
      expect(backgroundOf(tester, nestedKey), Color.lerp(_start, nestedEnd, 0.25));

      await tester.pumpWidget(build(Brightness.dark));
      await tester.pump();
      for (var frame = 1; frame <= _frameCount; frame++) {
        await tester.pump(_frameDuration);
        final variantProgress = (80 + frame * 16) / variantDuration.inMilliseconds;
        expect(
          backgroundOf(tester, selfKey),
          Color.lerp(_start, selfEnd, variantProgress),
          reason: 'onHover color 动画在 theme 第 $frame 帧不能被取消',
        );
        expect(
          backgroundOf(tester, nestedKey),
          Color.lerp(_start, nestedEnd, variantProgress),
          reason: 'nested color 动画在 theme 第 $frame 帧不能被取消',
        );
      }
    });

    testWidgets('active 变体解除时立即读取祖先当前主题中间帧', (tester) async {
      const rootKey = ValueKey('snapshot-root');
      const childKey = ValueKey('snapshot-child');
      const hoverColor = Color(0xFFFF0000);

      Widget build(Brightness brightness) => MaterialApp(
        home: ElView(
          key: rootKey,
          themeMode: ElThemeMode(brightness: brightness, duration: _themeDuration, curve: Curves.linear),
          style: const ElStyle(
            color: _start,
            onDark: ElStyle(color: _themeEnd),
          ),
          child: const ElView(
            key: childKey,
            style: ElStyle(onHover: ElStyle(color: hoverColor)),
          ),
        ),
      );

      await tester.pumpWidget(build(Brightness.light));
      await tester.pump();
      final child = renderOf(tester, childKey)..setHover(true);
      await tester.pump();
      expect(backgroundOf(tester, childKey), hoverColor);

      await tester.pumpWidget(build(Brightness.dark));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final rootMiddle = renderOf(tester, rootKey).committedResolvedStyle.inheritedText.color;
      expect(rootMiddle, Color.lerp(_start, _themeEnd, 0.5));
      expect(backgroundOf(tester, childKey), hoverColor);

      child.setHover(false);
      expect(child.targetStyleForTest.inheritedText.color, rootMiddle, reason: 'active 期间也必须持续刷新 parent 快照');
      expect(child.committedResolvedStyle.inheritedText.color, rootMiddle);
      expect(backgroundOf(tester, childKey), rootMiddle);
    });

    testWidgets('active 变体未声明 color 时 theme color mask 仍逐帧传播', (tester) async {
      const childKey = ValueKey('non-color-variant');

      Widget build(Brightness brightness) => MaterialApp(
        home: ElView(
          themeMode: ElThemeMode(brightness: brightness, duration: _themeDuration, curve: Curves.linear),
          style: const ElStyle(
            color: _start,
            onDark: ElStyle(color: _themeEnd),
          ),
          child: const ElView(
            key: childKey,
            style: ElStyle(onHover: ElStyle(width: 120)),
          ),
        ),
      );

      await tester.pumpWidget(build(Brightness.light));
      await tester.pump();
      renderOf(tester, childKey).setHover(true);
      await tester.pump();
      await tester.pumpWidget(build(Brightness.dark));
      await tester.pump();
      for (var frame = 1; frame <= _frameCount; frame++) {
        await tester.pump(_frameDuration);
        expect(
          backgroundOf(tester, childKey),
          Color.lerp(_start, _themeEnd, frame / _frameCount),
          reason: '无 color 声明的 active 变体不能粗暴截断整张 mask',
        );
      }
    });

    testWidgets('active onDark 自有 color 使用统一主题时钟且不被祖先采样覆盖', (tester) async {
      const childKey = ValueKey('on-dark-owner');
      const childDark = Color(0xFFFF0000);

      Widget build(Brightness brightness) => MaterialApp(
        home: ElView(
          themeMode: ElThemeMode(brightness: brightness, duration: _themeDuration, curve: Curves.linear),
          style: const ElStyle(
            color: _start,
            onDark: ElStyle(color: _themeEnd),
          ),
          child: const ElView(
            key: childKey,
            style: ElStyle(onDark: ElStyle(color: childDark)),
          ),
        ),
      );

      await tester.pumpWidget(build(Brightness.light));
      await tester.pump();
      await tester.pumpWidget(build(Brightness.dark));
      await tester.pump();
      for (var frame = 1; frame <= _frameCount; frame++) {
        await tester.pump(_frameDuration);
        expect(
          backgroundOf(tester, childKey),
          Color.lerp(_start, childDark, frame / _frameCount),
          reason: 'child onDark 应在第 $frame 帧保留自己的 theme 动画',
        );
      }
    });
  });

  group('暗色主题统一过渡', () {
    ElRenderView renderOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    group('dark 强制统一过渡（覆盖各自 transitions）', () {
      testWidgets('半程所有后代颜色处于同一进度：50% 精确 lerp 值逐一相等（无 / 100ms / 2s / 异曲线声明全被统一）', (tester) async {
        const lightA = Color(0xFF102030);
        const darkA = Color(0xFFEEEEEE);
        const lightB = Color(0xFF004400);
        const darkB = Color(0xFF88FF88);
        const k1 = ValueKey('u-none');
        const k2 = ValueKey('u-100ms');
        const k3 = ValueKey('u-2s');
        const k4 = ValueKey('u-curve');

        Widget build(Brightness b) => _directionalApp(
          ElView(
            themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 400), curve: Curves.linear),
            style: ElStyle(onDark: ElStyle()),
            child: [
              // 四种声明形态：无 / 短时长 / 超长时长 / 异曲线——统一后半程
              // 颜色必须逐一等于精确 50% lerp 值（割裂感 = 进度不一致）。
              ElView(
                key: k1,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: lightA,
                  onDark: ElStyle().merge(ElStyle(bgColor: darkA)),
                ),
              ),
              ElView(
                key: k2,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: lightA,
                  transitions: [ElTransition.all(Duration(milliseconds: 100))],
                  onDark: ElStyle().merge(ElStyle(bgColor: darkA)),
                ),
              ),
              ElView(
                key: k3,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: lightB,
                  transitions: [ElTransition.all(Duration(seconds: 2))],
                  onDark: ElStyle().merge(ElStyle(bgColor: darkB)),
                ),
              ),
              ElView(
                key: k4,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: lightB,
                  transitions: [ElTransition.all(Duration(milliseconds: 400), Curves.easeInExpo)],
                  onDark: ElStyle().merge(ElStyle(bgColor: darkB)),
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();

        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final halfA = Color.lerp(lightA, darkA, 0.5)!;
        final halfB = Color.lerp(lightB, darkB, 0.5)!;
        expect(renderOf(tester, k1).committedResolvedStyle.box.bgColor, halfA, reason: '无声明节点半程 = 精确 50% lerp');
        expect(
          renderOf(tester, k2).committedResolvedStyle.box.bgColor,
          halfA,
          reason: '100ms 声明被统一为 400ms：半程仍是 50%（若走自身声明早已到位）',
        );
        expect(
          renderOf(tester, k3).committedResolvedStyle.box.bgColor,
          halfB,
          reason: '2s 声明被统一为 400ms：半程 50%（若走自身声明才 10%）',
        );
        expect(
          renderOf(tester, k4).committedResolvedStyle.box.bgColor,
          halfB,
          reason: '异曲线声明被统一为 linear：半程 50%（easeInExpo(0.5)≈3%）',
        );

        // 收尾：全部精确到位。
        await tester.pump(const Duration(milliseconds: 210));
        expect(renderOf(tester, k1).committedResolvedStyle.box.bgColor, darkA);
        expect(renderOf(tester, k2).committedResolvedStyle.box.bgColor, darkA);
        expect(renderOf(tester, k3).committedResolvedStyle.box.bgColor, darkB);
        expect(renderOf(tester, k4).committedResolvedStyle.box.bgColor, darkB);
      });

      testWidgets('R3：祖先继承色同帧动画时，无 transitions 后代的 onDark 过渡不被继承传播打断', (tester) async {
        // 复现自 view 示例（transition 页）：body 根的 color 声明了 onDark →
        // dark 动画每 tick 沿继承链传播（inheritedText.color 变）→ 后代 fast
        // patch 因自身 onDark 命中 bail 到 _reresolve；后代无 transitions 声明
        // 且传播时 pending 已 restore 为 null → 旧判据不给 CascadeTick 传
        // driver → 看不见在跑的 dark 动画 → bgColor 直接写终点（瞬跳），与
        // 声明了 color 的兄弟（不受该传播路径影响）视觉割裂。
        const stageKey = ValueKey('r3-stage'); // 无 color、无 transitions
        const footerKey = ValueKey('r3-footer'); // 声明 color 的对照兄弟
        const lightBg = Color(0xFFF8FAFC);
        const darkBg = Color(0xFF0F172A);
        Widget build(Brightness b) => _directionalApp(
          ElView(
            themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 300), curve: Curves.linear),
            style: const ElStyle(
              color: Color(0xFF334155),
              onDark: ElStyle(color: Color(0xFFE2E8F0)),
            ),
            child: const [
              ElView(
                key: stageKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: lightBg,
                  onDark: ElStyle(bgColor: darkBg),
                ),
              ),
              ElView(
                key: footerKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  color: Color(0xFF64748B),
                  bgColor: lightBg,
                  onDark: ElStyle(bgColor: darkBg),
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();

        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump(); // 首 tick 对齐
        await tester.pump(const Duration(milliseconds: 150));

        final half = Color.lerp(lightBg, darkBg, 0.5)!;
        expect(renderOf(tester, footerKey).committedResolvedStyle.box.bgColor, half, reason: '对照兄弟半程精确 50%');
        expect(
          renderOf(tester, stageKey).committedResolvedStyle.box.bgColor,
          half,
          reason: '无 color 声明的节点同进度——瞬跳到终点即继承传播打断 bug 复发',
        );

        // 收尾精确到位、驱动器清空（无僵尸动画）。
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump();
        expect(renderOf(tester, stageKey).committedResolvedStyle.box.bgColor, darkBg);
        expect(renderOf(tester, stageKey).hasActiveAnimationsForTest, isFalse);
      });

      testWidgets('三种后代：无 transitions / 声明 100ms transitions / 引用不同 var → 半程中间帧一致（400ms 统一）', (tester) async {
        const rootKey = ValueKey('theme-root');
        const aKey = ValueKey('a-no-trans');
        const bKey = ValueKey('b-100ms-trans');
        const cKey = ValueKey('c-diff-var');

        Widget build(Brightness b) => _directionalApp(
          ElView(
            key: rootKey,
            themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 400), curve: Curves.linear),
            style: ElStyle(onDark: ElStyle()),
            child: [
              ElView(
                key: aKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: Color(0xFF102030),
                  onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                ),
              ),
              ElView(
                key: bKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: Color(0xFF102030),
                  transitions: [
                    ElTransition.field(ElTransitionField.bgColor, Duration(milliseconds: 100), Curves.easeIn),
                  ],
                  onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                ),
              ),
              ElView(
                key: cKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: Color(0xFFFAFAFA),
                  onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFF111111))),
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();

        // 初始 light：a/b/--primary=0xFF102030，c/--surface=0xFFFAFAFA
        final a = renderOf(tester, aKey);
        final b = renderOf(tester, bKey);
        final c = renderOf(tester, cKey);
        expect(a.committedResolvedStyle.box.bgColor, const Color(0xFF102030));
        expect(b.committedResolvedStyle.box.bgColor, const Color(0xFF102030));
        expect(c.committedResolvedStyle.box.bgColor, const Color(0xFFFAFAFA));

        // 切 dark
        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();

        // 三者都应该处于过渡中：ElThemeMode 强制统一 400ms 覆盖 100ms 声明
        expect(a.hasActiveAnimationsForTest, isTrue, reason: 'a 无自身 transitions，dark 强制统一启动 400ms 过渡');
        expect(b.hasActiveAnimationsForTest, isTrue, reason: 'b 有 100ms transitions，被强制统一为 400ms');
        expect(c.hasActiveAnimationsForTest, isTrue, reason: 'c 引用不同 var，一并统一');

        // 半程：pump 200ms（400ms 统一时长的一半）
        await tester.pump(const Duration(milliseconds: 200));
        // 100ms 声明如果生效，b 早就到位——本用例锁的是"没有到位"
        expect(b.hasActiveAnimationsForTest, isTrue, reason: '400ms 统一：200ms 时 b 仍在过渡中（不是 100ms 完成）');
        expect(a.hasActiveAnimationsForTest, isTrue);
        expect(c.hasActiveAnimationsForTest, isTrue);

        // 全程：pump 到 400ms（此时已从 setDark 起算共 400ms+ε）
        await tester.pump(const Duration(milliseconds: 210));
        expect(a.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE), reason: 'a 到位');
        expect(b.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE), reason: 'b 到位');
        expect(c.committedResolvedStyle.box.bgColor, const Color(0xFF111111), reason: 'c 到位');
        // 无残留动画
        expect(a.hasActiveAnimationsForTest, isFalse);
        expect(b.hasActiveAnimationsForTest, isFalse);
        expect(c.hasActiveAnimationsForTest, isFalse);
      });
    });

    group('局部 dark 岛（后代自己切 theme）', () {
      testWidgets('后代 theme.brightness=dark 只影响其子树', (tester) async {
        const outerKey = ValueKey('outer');
        const islandKey = ValueKey('island');
        const outsideKey = ValueKey('outside');
        const insideKey = ValueKey('inside');

        Widget tree({required Brightness inner}) => _directionalApp(
          ElView(
            key: outerKey,
            themeMode: const ElThemeMode(brightness: Brightness.light),
            style: ElStyle(onDark: ElStyle()),
            child: [
              ElView(
                key: outsideKey,
                style: ElStyle(
                  width: 20,
                  height: 20,
                  bgColor: Color(0xFF102030),
                  onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                ),
              ),
              ElView(
                key: islandKey,
                themeMode: ElThemeMode(brightness: inner),
                child: ElView(
                  key: insideKey,
                  style: ElStyle(
                    width: 20,
                    height: 20,
                    bgColor: Color(0xFF102030),
                    onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                  ),
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(tree(inner: Brightness.light));
        await tester.pump();
        final outside = renderOf(tester, outsideKey);
        final inside = renderOf(tester, insideKey);
        expect(outside.committedResolvedStyle.box.bgColor, const Color(0xFF102030));
        expect(inside.committedResolvedStyle.box.bgColor, const Color(0xFF102030));

        // island 翻 dark
        await tester.pumpWidget(tree(inner: Brightness.dark));
        await tester.pumpAndSettle();
        expect(inside.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE), reason: '岛内切 dark 后按 onDark.vars');
        expect(outside.committedResolvedStyle.box.bgColor, const Color(0xFF102030), reason: '岛外未受影响，仍 light 值');
      });
    });

    group('逐属性继承矩阵（brightness / duration / curve 独立可空）', () {
      testWidgets('1) 根声明 duration+curve，中层只声明 brightness=dark → 中层子树用根的 500ms+linear', (tester) async {
        const rootKey = ValueKey('m1-root');
        const midKey = ValueKey('m1-mid');
        const leafKey = ValueKey('m1-leaf');

        Widget build({required Brightness midBrightness}) => _directionalApp(
          ElView(
            key: rootKey,
            themeMode: ElThemeMode(duration: const Duration(milliseconds: 500), curve: Curves.linear),
            style: ElStyle(onDark: ElStyle()),
            child: ElView(
              key: midKey,
              themeMode: ElThemeMode(brightness: midBrightness),
              child: ElView(
                key: leafKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: Color(0xFF102030),
                  onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(midBrightness: Brightness.light));
        await tester.pump();
        final leaf = renderOf(tester, leafKey);
        expect(leaf.committedResolvedStyle.box.bgColor, const Color(0xFF102030));

        // 切 dark
        await tester.pumpWidget(build(midBrightness: Brightness.dark));
        await tester.pump();
        // 半程 250ms（500ms 的一半）—— 若默认 300ms，此时早过 250ms，颜色接近末态；
        // 若正确继承根 500ms，此时应处于过渡中且距末态还有明显距离。
        await tester.pump(const Duration(milliseconds: 250));
        expect(leaf.hasActiveAnimationsForTest, isTrue, reason: '继承根 500ms → 250ms 时仍在过渡中');
        // 冲到 500ms 全部完成
        await tester.pump(const Duration(milliseconds: 260));
        expect(leaf.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE));
        expect(leaf.hasActiveAnimationsForTest, isFalse);
      });

      testWidgets('2) 根声明 curve only，子声明 duration only → 独立继承/覆盖', (tester) async {
        const rootKey = ValueKey('m2-root');
        const midKey = ValueKey('m2-mid');
        const leafKey = ValueKey('m2-leaf');

        Widget build(Brightness b) => _directionalApp(
          ElView(
            key: rootKey,
            themeMode: const ElThemeMode(curve: Curves.linear),
            style: ElStyle(onDark: ElStyle()),
            child: ElView(
              key: midKey,
              // 子只声明 duration=200ms，curve 继承根 linear
              themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 200)),
              child: ElView(
                key: leafKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: Color(0xFF102030),
                  onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();
        final leaf = renderOf(tester, leafKey);

        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();
        // 半程 100ms（子 200ms 的一半）
        await tester.pump(const Duration(milliseconds: 100));
        expect(leaf.hasActiveAnimationsForTest, isTrue, reason: '子声明 200ms + 根 linear：100ms 时仍在过渡中');
        await tester.pump(const Duration(milliseconds: 110));
        expect(leaf.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE));
      });

      testWidgets('3) 整条链只有 brightness 声明 → 过渡兜底 300ms/easeOutCubic', (tester) async {
        const rootKey = ValueKey('m3-root');
        const leafKey = ValueKey('m3-leaf');

        Widget build(Brightness b) => _directionalApp(
          ElView(
            key: rootKey,
            themeMode: ElThemeMode(brightness: b), // 只声明 brightness
            style: ElStyle(onDark: ElStyle()),
            child: ElView(
              key: leafKey,
              style: ElStyle(
                width: 40,
                height: 40,
                bgColor: Color(0xFF102030),
                onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();
        final leaf = renderOf(tester, leafKey);

        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();
        // 半程 150ms（兜底 300ms 的一半）
        await tester.pump(const Duration(milliseconds: 150));
        expect(leaf.hasActiveAnimationsForTest, isTrue, reason: '兜底 300ms：150ms 时应仍在过渡中');
        await tester.pump(const Duration(milliseconds: 160));
        expect(leaf.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE));
        expect(leaf.hasActiveAnimationsForTest, isFalse);
      });

      testWidgets('4) 孙层覆盖 duration → 只影响孙子树，兄弟不受影响', (tester) async {
        const rootKey = ValueKey('m4-root');
        const midKey = ValueKey('m4-mid');
        const siblingKey = ValueKey('m4-sib');
        const grandsonKey = ValueKey('m4-grandson');
        const grandsonLeafKey = ValueKey('m4-grandson-leaf');

        Widget build(Brightness b) => _directionalApp(
          ElView(
            key: rootKey,
            themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 400), curve: Curves.linear),
            style: ElStyle(onDark: ElStyle()),
            child: [
              // 兄弟：继承根 400ms
              ElView(
                key: siblingKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: Color(0xFF102030),
                  onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                ),
              ),
              // 孙层覆盖 duration=200ms
              ElView(
                key: midKey,
                child: ElView(
                  key: grandsonKey,
                  themeMode: const ElThemeMode(duration: Duration(milliseconds: 200)),
                  child: ElView(
                    key: grandsonLeafKey,
                    style: ElStyle(
                      width: 40,
                      height: 40,
                      bgColor: Color(0xFF102030),
                      onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();
        final sib = renderOf(tester, siblingKey);
        final grandson = renderOf(tester, grandsonLeafKey);

        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();
        // pump 210ms —— 200ms 孙子已完成，400ms 兄弟仍在过渡
        await tester.pump(const Duration(milliseconds: 210));
        expect(grandson.hasActiveAnimationsForTest, isFalse, reason: '孙子 200ms 已完成');
        expect(grandson.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE));
        expect(sib.hasActiveAnimationsForTest, isTrue, reason: '兄弟继承根 400ms，此时仍在过渡');

        // 冲完
        await tester.pump(const Duration(milliseconds: 200));
        expect(sib.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE));
      });

      testWidgets('5) ElView(theme: null) 完全透明继承（等价无声明）', (tester) async {
        const rootKey = ValueKey('m5-root');
        const passKey = ValueKey('m5-pass'); // theme: null
        const leafKey = ValueKey('m5-leaf');

        Widget build(Brightness b) => _directionalApp(
          ElView(
            key: rootKey,
            themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 300), curve: Curves.linear),
            style: ElStyle(onDark: ElStyle()),
            child: ElView(
              key: passKey,
              themeMode: null, // 透明
              child: ElView(
                key: leafKey,
                style: ElStyle(
                  width: 40,
                  height: 40,
                  bgColor: Color(0xFF102030),
                  onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFEEEEEE))),
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();
        final leaf = renderOf(tester, leafKey);

        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();
        // 半程 150ms（300ms 的一半），theme: null 不阻断继承
        await tester.pump(const Duration(milliseconds: 150));
        expect(leaf.hasActiveAnimationsForTest, isTrue, reason: 'theme: null 透明 → 用根的 300ms');
        await tester.pump(const Duration(milliseconds: 160));
        expect(leaf.committedResolvedStyle.box.bgColor, const Color(0xFFEEEEEE));
      });
    });

    group('过渡中翻回：不跳变（中间帧连续性）', () {
      testWidgets('切 dark 半程再切回 light → 中间值方向反转，不跳变到端点', (tester) async {
        const rootKey = ValueKey('reverse-root');
        const boxKey = ValueKey('reverse-box');

        Widget build(Brightness b) => _directionalApp(
          ElView(
            key: rootKey,
            themeMode: ElThemeMode(brightness: b, duration: const Duration(milliseconds: 400), curve: Curves.linear),
            style: ElStyle(onDark: ElStyle()),
            child: ElView(
              key: boxKey,
              style: ElStyle(
                width: 40,
                height: 40,
                bgColor: Color(0xFF000000),
                onDark: ElStyle().merge(ElStyle(bgColor: Color(0xFFFFFFFF))),
              ),
            ),
          ),
        );

        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();
        final box = renderOf(tester, boxKey);
        expect(box.committedResolvedStyle.box.bgColor, const Color(0xFF000000));

        // 切 dark，进 200ms（半程）
        await tester.pumpWidget(build(Brightness.dark));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        // Box.bgColor 是 Object?（承载 Color | '--key'），显式 cast
        final midToDark = box.committedResolvedStyle.box.bgColor!;
        // 中间态：0x00 + 0xFF 之间，接近 0x80
        final midR = midToDark.r;
        expect(midR > 0.1 && midR < 0.9, isTrue, reason: '半程 R 在 (0.1, 0.9) 之间');

        // 半程翻回 light
        await tester.pumpWidget(build(Brightness.light));
        await tester.pump();
        // 立即断言：不跳变——committed 仍接近 midToDark（不是 0x000000 也不是 0xFFFFFF）
        final immediatelyAfterReverse = box.committedResolvedStyle.box.bgColor!;
        expect((immediatelyAfterReverse.r - midToDark.r).abs() < 0.1, isTrue, reason: '翻回瞬间中间值连续，不跳变');

        // 推进一小段：方向应反向（往 0x000000 接近）
        await tester.pump(const Duration(milliseconds: 100));
        final laterAfterReverse = box.committedResolvedStyle.box.bgColor!;
        expect(laterAfterReverse.r < midToDark.r, isTrue, reason: '翻回后 R 值向 0 方向单调递减（不跳变端点）');

        // 冲完全程
        await tester.pump(const Duration(milliseconds: 400));
        expect(box.committedResolvedStyle.box.bgColor, const Color(0xFF000000));
        expect(box.hasActiveAnimationsForTest, isFalse);
      });
    });
  });
}
