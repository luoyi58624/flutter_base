import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, BoxParentData;
import 'package:flutter_test/flutter_test.dart';

Widget _alignedScaffoldApp(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600), child: child),
    ),
  ),
);

const _instant = [ElTransition.all(Duration.zero)];

const _darkSurface = Color(0xFF1E293B);

const _darkText = Color(0xFFE2E8F0);

const _darkBase = ElStyle(backgroundColor: _darkSurface, color: _darkText);

Widget _box(Key key, ElStyle style) {
  return ElView(
    key: key,
    style: style.copyWith(
      width: style.width ?? 96,
      height: style.height ?? 40,
      transition: style.transition ?? _instant,
    ),
  );
}

void main() {
  group('组合场景', () {
    Widget shell(Widget child) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400, maxHeight: 1000), child: child),
      ),
    );

    ElRenderView viewOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    Future<void> pumpExample(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(shell(child));
      await tester.pump();
    }

    Future<void> hover(WidgetTester tester, Key key) async {
      viewOf(tester, key).setHover(true);
      await tester.pump();
    }

    bool hit(ElRenderView render, Offset position) {
      final result = BoxHitTestResult();
      return render.hitTest(result, position: position);
    }

    group('盒模型状态更新', () {
      testWidgets('width pixels hover: 150 -> 200 keeps explicit height and dark variant', (tester) async {
        const key = ValueKey('box-width-pixels');
        await pumpExample(
          tester,
          const ElView(
            key: key,
            style: ElStyle(
              width: 150,
              height: 48,
              backgroundColor: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
              borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
              padding: .symmetric(horizontal: 14),
              alignment: Alignment.center,
              transition: _instant,
              onDark: _darkBase,
              onHover: ElStyle(width: 200, backgroundColor: Colors.green),
            ),
            child: ElView(style: ElStyle(fontSize: 13), child: 'width 150 -> 200'),
          ),
        );

        final render = viewOf(tester, key);
        expect(render.size, const Size(150, 48));
        expect(render.committedResolvedStyle.box.width, const ElDimension.pixels(150));
        expect(render.committedResolvedStyle.box.padding, const EdgeInsets.symmetric(horizontal: 14));

        await hover(tester, key);
        expect(render.size, const Size(200, 48));
        expect(render.committedResolvedStyle.box.backgroundColor, Colors.green);

        render.setDark(true);
        await tester.pump();
        expect(render.committedResolvedStyle.inheritedText.color, _darkText);
      });

      testWidgets('width auto hover: intrinsic width can become explicit 200', (tester) async {
        const key = ValueKey('box-width-auto');
        await pumpExample(
          tester,
          const ElView(
            key: key,
            style: ElStyle(
              height: 48,
              backgroundColor: Colors.white,
              alignment: Alignment.center,
              padding: .symmetric(horizontal: 14),
              transition: _instant,
              onHover: ElStyle(width: 200, backgroundColor: Colors.green),
            ),
            child: SizedBox(width: 80, height: 20),
          ),
        );

        final render = viewOf(tester, key);
        expect(render.size, const Size(400, 48), reason: 'alignment: center makes auto width fill the available width');
        expect(render.committedResolvedStyle.box.width, isNull);

        await hover(tester, key);
        expect(render.size, const Size(200, 48));
        expect(render.committedResolvedStyle.box.width, const ElDimension.pixels(200));
      });

      testWidgets('width percent hover: 50% -> 100% resolves against parent constraint', (tester) async {
        const key = ValueKey('box-width-percent');
        await pumpExample(
          tester,
          const ElView(
            key: key,
            style: ElStyle(
              width: '50%',
              height: 48,
              backgroundColor: Colors.white,
              alignment: Alignment.center,
              padding: .symmetric(horizontal: 14),
              transition: _instant,
              onHover: ElStyle(width: '100%', backgroundColor: Colors.green),
            ),
            child: SizedBox(width: 20, height: 20),
          ),
        );

        final render = viewOf(tester, key);
        expect(render.size, const Size(200, 48));
        expect(render.committedResolvedStyle.box.width, const ElDimension.percent(50));

        await hover(tester, key);
        expect(render.size, const Size(400, 48));
        expect(render.committedResolvedStyle.box.width, const ElDimension.percent(100));
      });

      testWidgets('margin hover: margin is self-contained and hit-test excludes the margin band', (tester) async {
        const key = ValueKey('box-margin');
        await pumpExample(
          tester,
          const ElView(
            key: key,
            style: ElStyle(
              width: 100,
              height: 48,
              backgroundColor: Colors.white,
              margin: .zero,
              alignment: Alignment.center,
              transition: _instant,
              onHover: ElStyle(margin: .all(8)),
            ),
            child: ElView(style: ElStyle(fontSize: 13), child: 'margin'),
          ),
        );

        final render = viewOf(tester, key);
        expect(render.size, const Size(100, 48));
        expect(render.boxOrigin, Offset.zero);
        expect(hit(render, const Offset(1, 1)), isTrue);

        await hover(tester, key);
        expect(render.size, const Size(116, 64));
        expect(render.boxOrigin, const Offset(8, 8));
        expect(render.boxSize, const Size(100, 48));
        expect(hit(render, const Offset(4, 4)), isFalse);
        expect(hit(render, const Offset(12, 12)), isTrue);
      });

      testWidgets('padding hover: padding grows the visual box around intrinsic content', (tester) async {
        const key = ValueKey('box-padding');
        await pumpExample(
          tester,
          const ElView(
            key: key,
            style: ElStyle(
              backgroundColor: Colors.white,
              padding: .all(8),
              alignment: Alignment.center,
              transition: _instant,
              onHover: ElStyle(padding: .all(20)),
            ),
            child: SizedBox(width: 30, height: 10),
          ),
        );

        final render = viewOf(tester, key);
        expect(
          render.size,
          const Size(400, 600),
          reason: 'alignment: center makes auto width/height fill loose available constraints',
        );
        expect(render.contentOrigin, const Offset(8, 8));

        await hover(tester, key);
        expect(render.size, const Size(400, 600));
        expect(render.contentOrigin, const Offset(20, 20));
      });
    });

    group('变换与宽高比', () {
      testWidgets('transform hover variants commit transform, opacity, and aspect ratio', (tester) async {
        const scaleKey = ValueKey('transform-scale');
        const scaleXKey = ValueKey('transform-scale-x');
        const rotateKey = ValueKey('transform-rotate');
        const rotateOriginKey = ValueKey('transform-rotate-origin');
        const translateKey = ValueKey('transform-translate');
        const opacityKey = ValueKey('transform-opacity');
        const elevateKey = ValueKey('transform-elevate');
        const aspectKey = ValueKey('transform-aspect');
        const skewKey = ValueKey('transform-skew');

        await pumpExample(
          tester,
          Column(
            children: [
              _box(scaleKey, const ElStyle(onHover: ElStyle(transform: ElTransform.scale(1.2)))),
              _box(scaleXKey, const ElStyle(onHover: ElStyle(transform: ElTransform.scaleX(1.35)))),
              _box(rotateKey, ElStyle(onHover: ElStyle(transform: ElTransform.rotate(math.pi / 12)))),
              _box(
                rotateOriginKey,
                ElStyle(onHover: ElStyle(transform: ElTransform.rotate(math.pi / 18).alignment(Alignment.topLeft))),
              ),
              _box(translateKey, const ElStyle(onHover: ElStyle(transform: ElTransform.translate(12, -8)))),
              _box(opacityKey, const ElStyle(opacity: 1.0, onHover: ElStyle(opacity: 0.4))),
              _box(
                elevateKey,
                const ElStyle(
                  onHover: ElStyle(
                    transform: ElTransform.translate(0, -6),
                    boxShadow: [BoxShadow(color: Color(0x40009688), blurRadius: 24, offset: Offset(0, 12))],
                  ),
                ),
              ),
              _box(
                aspectKey,
                const ElStyle(width: 64, height: 64, aspectRatio: 1.0, onHover: ElStyle(aspectRatio: 2.0)),
              ),
              _box(skewKey, ElStyle(onHover: ElStyle(transform: ElTransform.skewX(math.pi / 18)))),
            ],
          ),
        );

        for (final key in [
          scaleKey,
          scaleXKey,
          rotateKey,
          rotateOriginKey,
          translateKey,
          opacityKey,
          elevateKey,
          aspectKey,
          skewKey,
        ]) {
          await hover(tester, key);
        }

        expect(viewOf(tester, scaleKey).committedResolvedStyle.box.transform, const ElTransform.scale(1.2));
        expect(viewOf(tester, scaleXKey).committedResolvedStyle.box.transform, const ElTransform.scaleX(1.35));
        expect(viewOf(tester, rotateKey).committedResolvedStyle.box.transform, ElTransform.rotate(math.pi / 12));
        expect(viewOf(tester, rotateOriginKey).committedResolvedStyle.box.transform!.origin, Alignment.topLeft);
        expect(viewOf(tester, translateKey).committedResolvedStyle.box.transform, const ElTransform.translate(12, -8));
        expect(viewOf(tester, opacityKey).committedResolvedStyle.box.opacity, 0.4);
        expect(
          (viewOf(tester, elevateKey).committedResolvedStyle.box.boxShadow as List<BoxShadow>).single.blurRadius,
          24,
        );
        expect(viewOf(tester, aspectKey).committedResolvedStyle.box.aspectRatio, 2.0);
        expect(viewOf(tester, skewKey).committedResolvedStyle.box.transform, ElTransform.skewX(math.pi / 18));
      });
    });
  });

  group('盒模型等价布局', () {
    const elKey = ValueKey<String>('el');

    const flKey = ValueKey<String>('fl');

    RenderBox boxOf(WidgetTester tester, Key key) => tester.renderObject(find.byKey(key));

    Widget coloredBox(Key key, Size size) => ColoredBox(
      key: key,
      color: const Color(0xFF00FF00),
      child: SizedBox.fromSize(size: size),
    );

    Future<void> expectParity(
      WidgetTester tester, {
      required Widget Function(Widget child) host,
      Size? childBoxSize,
      AlignmentGeometry? alignment,
      EdgeInsets? padding,
      double? width,
      double? height,
    }) async {
      final elChildKey = GlobalKey(debugLabel: 'el-leaf');
      final flChildKey = GlobalKey(debugLabel: 'fl-leaf');
      final Widget? elChild = childBoxSize == null ? null : coloredBox(elChildKey, childBoxSize);
      final Widget? flChild = childBoxSize == null ? null : coloredBox(flChildKey, childBoxSize);

      Widget buildSide({required Key key, required bool useEl}) {
        if (useEl) {
          return host(
            ElView(
              key: key,
              style: ElStyle(
                width: width,
                height: height,
                alignment: alignment,
                padding: padding == null
                    ? null
                    : EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, padding.bottom),
              ),
              child: elChild,
            ),
          );
        }
        return host(
          Container(key: key, width: width, height: height, alignment: alignment, padding: padding, child: flChild),
        );
      }

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSide(key: elKey, useEl: true),
              buildSide(key: flKey, useEl: false),
            ],
          ),
        ),
      );

      final el = boxOf(tester, elKey);
      final fl = boxOf(tester, flKey);
      expect(el.size, fl.size, reason: 'host size');

      // 显式宽高 + 无 alignment：ElView 宽松子约束，叶子不必与 Container tight 拉伸一致。
      final compareLeaf = childBoxSize != null && (alignment != null || (width == null && height == null));
      if (compareLeaf) {
        final elLeaf = elChildKey.currentContext!.findRenderObject()! as RenderBox;
        final flLeaf = flChildKey.currentContext!.findRenderObject()! as RenderBox;
        expect(elLeaf.size, flLeaf.size, reason: 'leaf size');
        final elOrigin = el.localToGlobal(Offset.zero);
        final flOrigin = fl.localToGlobal(Offset.zero);
        final elLeafTopLeft = elLeaf.localToGlobal(Offset.zero) - elOrigin;
        final flLeafTopLeft = flLeaf.localToGlobal(Offset.zero) - flOrigin;
        expect(elLeafTopLeft, flLeafTopLeft, reason: 'leaf offset in host');
      }
    }

    group('Container equivalence', () {
      final hosts = <String, Widget Function(Widget child)>{
        'loose': (c) => SizedBox(
          width: 400,
          height: 300,
          child: Align(alignment: Alignment.topLeft, child: c),
        ),
        'tight': (c) => SizedBox(width: 240, height: 180, child: c),
        'unbounded': (c) => UnconstrainedBox(child: c),
      };

      final children = <String, Size?>{'none': null, 'small': const Size(40, 24), 'large': const Size(320, 220)};

      final alignments = <String, AlignmentGeometry?>{
        'noAlign': null,
        'center': Alignment.center,
        'bottomRight': Alignment.bottomRight,
      };

      final paddings = <String, EdgeInsets?>{'noPad': null, 'asym': const EdgeInsets.fromLTRB(8, 2, 20, 14)};

      final sizes = <String, (double?, double?)>{'auto': (null, null), 'w': (120, null), 'wh': (120, 80)};

      for (final host in hosts.entries) {
        for (final child in children.entries) {
          for (final align in alignments.entries) {
            for (final pad in paddings.entries) {
              for (final size in sizes.entries) {
                if (host.key == 'unbounded' && align.value != null) continue;
                if (host.key == 'loose' && child.value == null && (size.value.$1 == null || size.value.$2 == null)) {
                  continue;
                }
                testWidgets('${host.key}/${child.key}/${align.key}/${pad.key}/${size.key}', (tester) async {
                  await expectParity(
                    tester,
                    host: host.value,
                    childBoxSize: child.value,
                    alignment: align.value,
                    padding: pad.value,
                    width: size.value.$1,
                    height: size.value.$2,
                  );
                });
              }
            }
          }
        }
      }
    });
  });

  group('内容对齐', () {
    ElRenderView findRender(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    Widget wrap200x100({required Widget child}) => MaterialApp(
      home: Center(child: SizedBox(width: 200, height: 100, child: child)),
    );

    testWidgets('alignment=null：容器 hug child，child 贴 0,0', (tester) async {
      const outer = ValueKey('outer');
      const inner = ValueKey('inner');
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: ElView(
              key: outer,
              style: ElStyle(),
              child: ElView(
                key: inner,
                style: ElStyle(width: 50, height: 30, backgroundColor: Color(0xffff0000)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final outerBox = findRender(tester, outer);
      final innerBox = findRender(tester, inner);
      expect(outerBox.size.width, closeTo(50, 1e-9), reason: 'alignment=null 时 Container 口径 hug child');
      expect(outerBox.size.height, closeTo(30, 1e-9));

      final pd = innerBox.parentData as BoxParentData;
      expect(pd.offset, Offset.zero, reason: 'alignment=null 时 child 贴 0,0');
    });

    testWidgets('alignment=.center：容器撑满 + child 居中', (tester) async {
      const outer = ValueKey('outer');
      const inner = ValueKey('inner');
      await tester.pumpWidget(
        wrap200x100(
          child: const ElView(
            key: outer,
            style: ElStyle(alignment: Alignment.center),
            child: ElView(
              key: inner,
              style: ElStyle(width: 50, height: 30, backgroundColor: Color(0xffff0000)),
            ),
          ),
        ),
      );
      await tester.pump();

      final outerBox = findRender(tester, outer);
      final innerBox = findRender(tester, inner);
      expect(outerBox.size.width, closeTo(200, 1e-9));
      expect(outerBox.size.height, closeTo(100, 1e-9));

      final pd = innerBox.parentData as BoxParentData;
      expect(pd.offset.dx, closeTo(75, 1e-9), reason: 'center → x 偏移 = (200-50)/2 = 75');
      expect(pd.offset.dy, closeTo(35, 1e-9), reason: 'center → y 偏移 = (100-30)/2 = 35');
    });

    testWidgets('alignment=.bottomRight：child 贴右下', (tester) async {
      const inner = ValueKey('inner');
      await tester.pumpWidget(
        wrap200x100(
          child: const ElView(
            style: ElStyle(alignment: Alignment.bottomRight),
            child: ElView(
              key: inner,
              style: ElStyle(width: 50, height: 30, backgroundColor: Color(0xff00ff00)),
            ),
          ),
        ),
      );
      await tester.pump();

      final pd = findRender(tester, inner).parentData as BoxParentData;
      expect(pd.offset.dx, closeTo(150, 1e-9));
      expect(pd.offset.dy, closeTo(70, 1e-9));
    });

    testWidgets('AlignmentDirectional 按 textDirection 解析', (tester) async {
      const inner = ValueKey('inner');
      // 默认 LTR：centerStart 等价 centerLeft → x=0
      await tester.pumpWidget(
        wrap200x100(
          child: const ElView(
            style: ElStyle(alignment: AlignmentDirectional.centerStart),
            child: ElView(key: inner, style: ElStyle(width: 50, height: 30)),
          ),
        ),
      );
      await tester.pump();

      final pd = findRender(tester, inner).parentData as BoxParentData;
      expect(pd.offset.dx, closeTo(0, 1e-9), reason: 'LTR + centerStart → 贴左');
      expect(pd.offset.dy, closeTo(35, 1e-9));
    });
  });

  group('宽高比', () {
    ElRenderView outer(WidgetTester tester) => tester.renderObjectList<ElRenderView>(find.byType(ElView)).first;

    group('规则 1：显式 width + aspectRatio → height 算出', () {
      testWidgets('width=200 + aspectRatio=2 → size = 200x100', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(const ElView(style: ElStyle(width: 200, aspectRatio: 2), child: SizedBox())),
        );
        expect(outer(tester).size, const Size(200, 100));
      });

      testWidgets('width=160 + aspectRatio=16/9 → size = 160x90', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              style: ElStyle(width: 160, aspectRatio: 16 / 9),
              child: SizedBox(),
            ),
          ),
        );
        expect(outer(tester).size, const Size(160, 90));
      });

      testWidgets('显式 w + ratio 覆盖 child contentSize.h', (tester) async {
        // child=50x50，但 width=200 + aspectRatio=2 → h=100（覆盖 contentSize.h=50）
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(style: ElStyle(width: 200, aspectRatio: 2), child: SizedBox(width: 50, height: 50)),
          ),
        );
        expect(outer(tester).size, const Size(200, 100));
      });

      testWidgets('width + aspectRatio 会约束 alignment 的容器高度', (tester) async {
        const inner = ValueKey('aspect-inner');

        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              style: ElStyle(width: 200, aspectRatio: 2, alignment: Alignment.center),
              child: SizedBox(key: inner, width: 50, height: 30),
            ),
          ),
        );

        final child = tester.renderObject<RenderBox>(find.byKey(inner));
        final pd = child.parentData as BoxParentData;
        expect(outer(tester).size, const Size(200, 100));
        expect(pd.offset, const Offset(75, 35));
      });
    });

    group('规则 2：显式 height + aspectRatio → width 算出', () {
      testWidgets('height=100 + aspectRatio=2 → size = 200x100', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(const ElView(style: ElStyle(height: 100, aspectRatio: 2), child: SizedBox())),
        );
        expect(outer(tester).size, const Size(200, 100));
      });

      testWidgets('height=90 + aspectRatio=16/9 → size = 160x90', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              style: ElStyle(height: 90, aspectRatio: 16 / 9),
              child: SizedBox(),
            ),
          ),
        );
        expect(outer(tester).size, const Size(160, 90));
      });

      testWidgets('height + aspectRatio 会约束 alignment 的容器宽度', (tester) async {
        const inner = ValueKey('aspect-inner-height');

        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              style: ElStyle(height: 100, aspectRatio: 2, alignment: Alignment.center),
              child: SizedBox(key: inner, width: 50, height: 30),
            ),
          ),
        );

        final child = tester.renderObject<RenderBox>(find.byKey(inner));
        final pd = child.parentData as BoxParentData;
        expect(outer(tester).size, const Size(200, 100));
        expect(pd.offset, const Offset(75, 35));
      });
    });

    group('规则 3：都没显式 + aspectRatio → 用 contentSize.w', () {
      testWidgets('contentSize=100x50 + aspectRatio=2 → size = 100x50', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              style: ElStyle(aspectRatio: 2),
              child: SizedBox(width: 100, height: 999), // child h 被覆盖
            ),
          ),
        );
        expect(outer(tester).size, const Size(100, 50));
      });

      testWidgets('contentSize=100x50 + padding=10 + aspectRatio=2 → w=120, h=60', (tester) async {
        // w = 100 + padding 10*2 = 120; h = 120 / 2 = 60
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              style: ElStyle(padding: .all(10), aspectRatio: 2),
              child: SizedBox(width: 100, height: 200),
            ),
          ),
        );
        expect(outer(tester).size, const Size(120, 60));
      });
    });

    group('规则 4：都显式 + aspectRatio → ratio 被忽略', () {
      testWidgets('width=200 + height=100 + aspectRatio=10：ratio 不生效', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(style: ElStyle(width: 200, height: 100, aspectRatio: 10), child: SizedBox()),
          ),
        );
        // 如果 ratio 生效 h = 200/10 = 20；实际 h = 100（显式优先）
        expect(outer(tester).size, const Size(200, 100));
      });
    });

    group('aspectRatio + min/max clamp（clamp 优先级更高）', () {
      testWidgets('width=200 + ratio=2 → h=100，但 minHeight=150 → h clamp 到 150', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(style: ElStyle(width: 200, aspectRatio: 2, minHeight: 150), child: SizedBox()),
          ),
        );
        // ratio 算 h=100，但 minHeight=150 强制提升到 150
        expect(outer(tester).size, const Size(200, 150));
      });

      testWidgets('width=200 + ratio=0.5 → h=400，但 maxHeight=200 → h clamp 到 200', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(style: ElStyle(width: 200, aspectRatio: 0.5, maxHeight: 200), child: SizedBox()),
          ),
        );
        expect(outer(tester).size, const Size(200, 200));
      });
    });

    group('无 aspectRatio：行为与现有一致（无回归）', () {
      testWidgets('显式 w/h：照旧', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(const ElView(style: ElStyle(width: 200, height: 100), child: SizedBox())),
        );
        expect(outer(tester).size, const Size(200, 100));
      });

      testWidgets('content 驱动：照旧', (tester) async {
        await tester.pumpWidget(_alignedScaffoldApp(const ElView(child: SizedBox(width: 100, height: 50))));
        // Container 口径：无 alignment / 无显式尺寸 → hug child（不再 CSS block 撑满）。
        expect(outer(tester).size, const Size(100, 50));
      });
    });

    group('damage 路由', () {
      testWidgets('onHover 切 aspectRatio：触发 layout（不是 paint）', (tester) async {
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              style: ElStyle(width: 200, aspectRatio: 2, onHover: ElStyle(width: 200, aspectRatio: 4)),
              child: SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final r = outer(tester);
        final layoutsBefore = r.debugLayoutCount;

        r.setHover(true);
        await tester.pump();

        expect(r.debugLayoutCount, greaterThan(layoutsBefore), reason: 'aspectRatio layout-affecting，hover 应重 layout');
        // 200/4 = 50
        expect(r.size, const Size(200, 50));
      });
    });
  });

  group('空盒自动尺寸', () {
    const targetKey = ValueKey('target');

    Widget looseHost(ElStyle? style) {
      return MaterialApp(
        home: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 100),
            child: ElView(key: targetKey, style: style),
          ),
        ),
      );
    }

    group('空盒 auto 尺寸', () {
      testWidgets('宽松有界约束下 width/height 均收缩为 0', (tester) async {
        await tester.pumpWidget(looseHost(null));
        expect(tester.getSize(find.byKey(targetKey)), Size.zero);
        final render = tester.renderObject<RenderBox>(find.byKey(targetKey));
        expect(
          render.getDryLayout(const BoxConstraints(maxWidth: 200, maxHeight: 100)),
          Size.zero,
          reason: 'dry layout 必须与真实布局一致',
        );

        await tester.pumpWidget(looseHost(const ElStyle(alignment: .center)));
        expect(tester.getSize(find.byKey(targetKey)), Size.zero, reason: '慢路径也不能因父级 max 自动扩张');
      });

      testWidgets('padding 与 minWidth/minHeight 仍决定空盒下限', (tester) async {
        await tester.pumpWidget(looseHost(const ElStyle(padding: .all(8))));
        expect(tester.getSize(find.byKey(targetKey)), const Size(16, 16));

        await tester.pumpWidget(looseHost(const ElStyle(minWidth: 40, minHeight: 30)));
        expect(tester.getSize(find.byKey(targetKey)), const Size(40, 30));
      });

      testWidgets('父级 tight 约束仍具有最高优先级', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: SizedBox(width: 200, height: 100, child: ElView(key: targetKey)),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(targetKey)), const Size(200, 100));
      });
    });

    group('auto 中间节点的百分比后代', () {
      testWidgets('有限约束跨过 auto 中间节点继续作为百分比参照', (tester) async {
        const rootKey = ValueKey('root');
        const middleKey = ValueKey('middle');
        const leafKey = ValueKey('leaf');
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                key: rootKey,
                style: ElStyle(width: 200, height: 100),
                child: ElView(
                  key: middleKey,
                  child: ElView(
                    key: leafKey,
                    style: ElStyle(width: '50%', height: '50%'),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(rootKey)), const Size(200, 100));
        expect(tester.getSize(find.byKey(leafKey)), const Size(100, 50));
        expect(tester.getSize(find.byKey(middleKey)), const Size(100, 50), reason: 'auto 中间节点应收缩到百分比后代');
      });

      testWidgets('无界中间约束沿参照链读取显式祖先尺寸', (tester) async {
        const middleKey = ValueKey('unbounded-middle');
        const leafKey = ValueKey('unbounded-leaf');
        await tester.pumpWidget(
          const MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: ElView(
                style: ElStyle(width: 400, height: 200),
                child: UnconstrainedBox(
                  alignment: Alignment.topLeft,
                  child: ElView(
                    key: middleKey,
                    child: ElView(
                      key: leafKey,
                      style: ElStyle(width: '50%', height: '50%'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(leafKey)), const Size(200, 100));
        expect(tester.getSize(find.byKey(middleKey)), const Size(200, 100));
      });
    });
  });

  group('百分比尺寸', () {
    group('percent dimensions', () {
      testWidgets("'50%' / '25%' 在固定父约束下折算成 pixels", (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                child: const ElView(
                  key: ValueKey('target'),
                  style: ElStyle(width: '50%', height: '25%'),
                ),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(const ValueKey('target'))), const Size(100, 50));
      });

      testWidgets('num + percent 混用', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                child: const ElView(
                  key: ValueKey('target'),
                  style: ElStyle(width: 80, height: '40%'),
                ),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(const ValueKey('target'))), const Size(80, 80));
      });

      testWidgets('不支持的字符串 → auto → 退化到 child intrinsic', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const Center(
              child: ElView(
                key: ValueKey('target'),
                style: ElStyle(width: 'calc(100% - 8px)', height: 'bad'),
                child: SizedBox(width: 24, height: 16),
              ),
            ),
          ),
        );

        // 非法 width → auto → Container 口径 hug child；height 跟 child。
        expect(tester.getSize(find.byKey(const ValueKey('target'))).height, 16);
        expect(tester.getSize(find.byKey(const ValueKey('target'))).width, 24);
      });

      testWidgets('percent min/max 也参与 clamp', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
                child: const ElView(
                  key: ValueKey('target'),
                  style: ElStyle(
                    width: 260,
                    height: 10,
                    minWidth: '20%',
                    maxWidth: '40%',
                    minHeight: 30,
                    maxHeight: 90,
                  ),
                ),
              ),
            ),
          ),
        );

        // minWidth = 60, maxWidth = 120 → width 被 maxWidth=120 clamp
        // minHeight = 30 → height=10 提升到 30
        expect(tester.getSize(find.byKey(const ValueKey('target'))), const Size(120, 30));
      });

      testWidgets('percent + 无限父约束 → 退化为 auto（用 child intrinsic）', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: const ElView(
                  key: ValueKey('target'),
                  style: ElStyle(width: '50%', height: 40),
                  child: SizedBox(width: 20, height: 40),
                ),
              ),
            ),
          ),
        );

        // SingleChildScrollView 横向无限 → percent 退化为 null → child intrinsic 20
        expect(tester.getSize(find.byKey(const ValueKey('target'))).width, 20);
      });

      testWidgets('显式 width 父给子宽松约束：子 50% 相对内容盒，且可小于父', (tester) async {
        const parent = ValueKey('parent');
        const child = ValueKey('child');
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                key: parent,
                style: ElStyle(width: 200, height: 100),
                child: ElView(
                  key: child,
                  style: ElStyle(width: '50%', height: '50%'),
                ),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(parent)), const Size(200, 100));
        expect(tester.getSize(find.byKey(child)), const Size(100, 50), reason: 'width 只当 max，子 % 相对内容盒');
      });

      testWidgets('显式 width 不 tight 拉伸小子', (tester) async {
        const parent = ValueKey('parent');
        const leaf = ValueKey('leaf');
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                key: parent,
                style: ElStyle(width: 200, height: 100),
                child: SizedBox(key: leaf, width: 40, height: 24),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(parent)), const Size(200, 100));
        expect(tester.getSize(find.byKey(leaf)), const Size(40, 24), reason: 'min=0 max=width，子保持 intrinsic');
      });

      testWidgets('maxWidth 优先于 width 作为子 max', (tester) async {
        const child = ValueKey('child');
        await tester.pumpWidget(
          const MaterialApp(
            home: Center(
              child: ElView(
                style: ElStyle(width: 200, maxWidth: 120, height: 80),
                child: ElView(
                  key: child,
                  style: ElStyle(width: '100%', height: 20),
                ),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(child)).width, 120, reason: 'maxWidth > width');
      });

      testWidgets('显式 num 和 percent 在 ElStyle 字段层各自生效', (tester) async {
        // 验证 ElStyle.width Object? 接受 num + String，不会因类型不同出错
        const styles = [ElStyle(width: 100), ElStyle(width: '50%'), ElStyle(width: 100.5), ElStyle(width: null)];
        for (final s in styles) {
          await tester.pumpWidget(
            MaterialApp(
              home: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                child: ElView(key: const ValueKey('s'), style: s, child: const SizedBox(width: 30, height: 30)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('s')), findsOneWidget);
        }
      });
    });
  });

  group('尺寸因子', () {
    Size sizeOf(WidgetTester tester, Key key) => tester.renderObject<RenderBox>(find.byKey(key)).size;

    group('尺寸因子布局', () {
      testWidgets('widthFactor 只缩宿主宽度，不收紧 child', (tester) async {
        const hostKey = ValueKey('host');
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              key: hostKey,
              style: ElStyle(widthFactor: 0.5),
              child: SizedBox(key: childKey, width: 100, height: 40),
            ),
          ),
        );

        expect(sizeOf(tester, hostKey), const Size(50, 40));
        expect(sizeOf(tester, childKey), const Size(100, 40));
      });

      testWidgets('heightFactor 只缩宿主高度，不收紧 child', (tester) async {
        const hostKey = ValueKey('host');
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              key: hostKey,
              style: ElStyle(heightFactor: 0.5),
              child: SizedBox(key: childKey, width: 100, height: 40),
            ),
          ),
        );

        expect(sizeOf(tester, hostKey), const Size(100, 20));
        expect(sizeOf(tester, childKey), const Size(100, 40));
      });

      testWidgets('factor 作用于包含 padding 的自然盒尺寸', (tester) async {
        const hostKey = ValueKey('host');
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              key: hostKey,
              style: ElStyle(widthFactor: 0.5, heightFactor: 0.5, padding: .all(10)),
              child: SizedBox(width: 80, height: 40),
            ),
          ),
        );

        expect(sizeOf(tester, hostKey), const Size(50, 30));
      });

      testWidgets('alignment 不会让声明 factor 的轴改为撑满父约束', (tester) async {
        const hostKey = ValueKey('host');
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              key: hostKey,
              style: ElStyle(widthFactor: 0.5, heightFactor: 0.5, alignment: .bottomRight),
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );

        expect(sizeOf(tester, hostKey), const Size(50, 20));
      });

      testWidgets('显式 width / height 优先于同轴 factor', (tester) async {
        const hostKey = ValueKey('host');
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              key: hostKey,
              style: ElStyle(width: 80, height: 30, widthFactor: 0, heightFactor: 0),
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );

        expect(sizeOf(tester, hostKey), const Size(80, 30));
      });

      testWidgets('有效 factor 与 aspectRatio 同时声明时 factor 独立生效', (tester) async {
        const hostKey = ValueKey('host');
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              key: hostKey,
              style: ElStyle(widthFactor: 0.5, aspectRatio: 10),
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );

        expect(sizeOf(tester, hostKey), const Size(50, 40));
      });

      testWidgets('min/max 在 factor 之后执行最终约束', (tester) async {
        const hostKey = ValueKey('host');
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              key: hostKey,
              style: ElStyle(heightFactor: 0, minHeight: 12),
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );

        expect(sizeOf(tester, hostKey), const Size(100, 12));
      });

      testWidgets('intrinsic 尺寸同步包含 factor', (tester) async {
        const hostKey = ValueKey('host');
        await tester.pumpWidget(
          _alignedScaffoldApp(
            const ElView(
              key: hostKey,
              style: ElStyle(widthFactor: 0.5, heightFactor: 0.5),
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );

        final render = tester.renderObject<RenderBox>(find.byKey(hostKey));
        expect(render.getMinIntrinsicWidth(double.infinity), 50);
        expect(render.getMaxIntrinsicWidth(double.infinity), 50);
        expect(render.getMinIntrinsicHeight(100), 20);
        expect(render.getMaxIntrinsicHeight(100), 20);
      });

      test('factor 拒绝负数和非有限值', () {
        expect(() => validStyleFactor(-0.1), throwsAssertionError);
        expect(() => validStyleFactor(double.infinity), throwsAssertionError);
      });
    });

    group('尺寸因子 var 与 transition', () {
      testWidgets('heightFactor transition 连续改变宿主高度，child 保持自然尺寸', (tester) async {
        const hostKey = ValueKey('host');
        const childKey = ValueKey('child');

        Widget subject(double factor) => _alignedScaffoldApp(
          ElView(
            key: hostKey,
            style: ElStyle(
              heightFactor: factor,
              transition: const [ElTransition.field(.heightFactor, Duration(milliseconds: 100), Curves.linear)],
            ),
            child: const SizedBox(key: childKey, width: 100, height: 40),
          ),
        );

        await tester.pumpWidget(subject(0));
        expect(sizeOf(tester, hostKey), const Size(100, 0));

        await tester.pumpWidget(subject(1));
        await tester.pump(const Duration(milliseconds: 50));
        expect(sizeOf(tester, hostKey).height, moreOrLessEquals(20, epsilon: 0.1));
        expect(sizeOf(tester, childKey), const Size(100, 40));

        await tester.pump(const Duration(milliseconds: 50));
        expect(sizeOf(tester, hostKey), const Size(100, 40));
      });
    });
  });

  group('首次挂载参考尺寸', () {
    for (final axis in Axis.values) {
      for (final generalLayout in [false, true]) {
        testWidgets('祖先 $axis 尺寸变化且 Flex 子约束不变时百分比仍更新（通用布局=$generalLayout）', (tester) async {
          const targetKey = ValueKey('percent-size');
          final horizontal = axis == Axis.horizontal;
          // 固定 child 实例，确保测到的是祖先参照变化，而不是 widget 更新附带的重排。
          final target = ElView(
            key: targetKey,
            style: ElStyle(
              width: horizontal ? '50%' : 20,
              height: horizontal ? 20 : '50%',
              minWidth: generalLayout ? 1 : null,
            ),
          );

          Widget page(double extent) => Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: ElStyle(
                  width: horizontal ? extent : 80,
                  height: horizontal ? 80 : extent,
                  minWidth: generalLayout ? 1 : null,
                ),
                child: Flex(direction: axis, mainAxisSize: .min, children: [target]),
              ),
            ),
          );

          await tester.pumpWidget(page(300));
          expect(tester.getSize(find.byKey(targetKey)), horizontal ? const Size(150, 20) : const Size(20, 150));
          await tester.pumpWidget(page(400));
          expect(tester.getSize(find.byKey(targetKey)), horizontal ? const Size(200, 20) : const Size(20, 200));
          await tester.pumpWidget(page(240));
          expect(tester.getSize(find.byKey(targetKey)), horizontal ? const Size(120, 20) : const Size(20, 120));
        });
      }
    }

    testWidgets('移除近层显式宽度后百分比回退到更远祖先参照', (tester) async {
      const targetKey = ValueKey('fallback-reference');
      final target = ElView(
        key: targetKey,
        style: const ElStyle(width: '50%', height: 20),
      );

      Widget page(double? width) => Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: ElView(
            style: const ElStyle(width: 500, height: 100),
            child: ElView(
              style: ElStyle(width: width, height: 80),
              child: Row(mainAxisSize: .min, children: [target]),
            ),
          ),
        ),
      );

      await tester.pumpWidget(page(300));
      expect(tester.getSize(find.byKey(targetKey)), const Size(150, 20));
      await tester.pumpWidget(page(null));
      expect(tester.getSize(find.byKey(targetKey)), const Size(250, 20));
      await tester.pumpWidget(page(200));
      expect(tester.getSize(find.byKey(targetKey)), const Size(100, 20));
    });

    testWidgets('祖先参照更新保持固定子尺寸且不会越过近层参照', (tester) async {
      const fixedKey = ValueKey('fixed-size');
      const directKey = ValueKey('outer-reference');
      const nestedKey = ValueKey('inner-reference');
      final contents = Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            mainAxisSize: .min,
            children: [
              const ElView(key: fixedKey, style: ElStyle(width: 48, height: 20)),
              const ElView(
                key: directKey,
                style: ElStyle(width: '50%', height: 20),
              ),
            ],
          ),
          const ElView(
            style: ElStyle(width: 200, height: 20),
            child: Row(
              mainAxisSize: .min,
              children: [
                ElView(
                  key: nestedKey,
                  style: ElStyle(width: '50%', height: 20),
                ),
              ],
            ),
          ),
        ],
      );

      Widget page(double width) => Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: ElView(
            style: ElStyle(width: width, height: 80),
            child: contents,
          ),
        ),
      );

      await tester.pumpWidget(page(300));
      expect(tester.getSize(find.byKey(fixedKey)), const Size(48, 20));
      expect(tester.getSize(find.byKey(directKey)), const Size(150, 20));
      expect(tester.getSize(find.byKey(nestedKey)), const Size(100, 20));
      await tester.pumpWidget(page(400));
      expect(tester.getSize(find.byKey(fixedKey)), const Size(48, 20));
      expect(tester.getSize(find.byKey(directKey)), const Size(200, 20));
      expect(tester.getSize(find.byKey(nestedKey)), const Size(100, 20));
    });
  });

  group('文字几何基线', () {
    const hostKey = ValueKey<String>('text-geom-host');

    Widget shell(Widget child) => MaterialApp(
      home: Align(alignment: Alignment.topLeft, child: child),
    );

    ElRenderView renderOf(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byKey(hostKey));

    Rect glyphBounds(ElRenderView render, int length) {
      final engine = (render.content as TextEngine?)!;
      return engine
          .getBoxesForSelectionForTest(0, length)
          .map((box) => box.toRect().shift(engine.textPaintOrigin))
          .reduce((a, b) => a.expandToInclude(b));
    }

    group('text geometry baseline (asymmetric padding)', () {
      testWidgets('pure string selection rects sit inside padded content box', (tester) async {
        await tester.pumpWidget(
          shell(
            const Padding(
              padding: EdgeInsets.only(left: 30, top: 40),
              child: ElView(
                key: hostKey,
                style: ElStyle(padding: EdgeInsets.fromLTRB(11, 7, 19, 13), fontSize: 18, color: Color(0xFF111111)),
                child: 'geom',
              ),
            ),
          ),
        );

        final host = renderOf(tester);
        expect(host.contentOrigin, const Offset(11, 7));

        final engine = host.content as TextEngine;
        final rects = engine.selectionPaintRectsForRange(const ui.TextRange(start: 0, end: 4));
        expect(engine.selectionParticipant, isNull, reason: '独立文字几何查询不启用选区参与者');
        expect(rects, isNotEmpty);
        final bounds = rects.reduce((a, b) => a.expandToInclude(b));
        expect(bounds.left, greaterThanOrEqualTo(11 - 0.5));
        expect(bounds.top, greaterThanOrEqualTo(7 - 0.5));
        expect(bounds.right, lessThanOrEqualTo(host.boxSize.width - 19 + 0.5));
        expect(bounds.bottom, lessThanOrEqualTo(host.boxSize.height - 13 + 0.5));
      });

      testWidgets('alignment centers pure string inside padded content box', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              key: hostKey,
              style: ElStyle(
                width: 220,
                height: 120,
                padding: EdgeInsets.fromLTRB(10, 6, 18, 14),
                alignment: Alignment.center,
                fontSize: 20,
              ),
              child: 'pad',
            ),
          ),
        );

        final host = renderOf(tester);
        final rects = (host.content as TextEngine).selectionPaintRectsForRange(const ui.TextRange(start: 0, end: 3));
        final bounds = rects.reduce((a, b) => a.expandToInclude(b));
        final contentOrigin = host.contentOrigin;
        final contentSize = Size(host.boxSize.width - 10 - 18, host.boxSize.height - 6 - 14);
        final contentCenter = contentOrigin + contentSize.center(Offset.zero);
        expect(bounds.center.dx, closeTo(contentCenter.dx, 1.5));
        expect(bounds.center.dy, closeTo(contentCenter.dy, 1.5));
      });

      testWidgets('alignment:null leaves pure string selection at contentOrigin', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              key: hostKey,
              style: ElStyle(padding: EdgeInsets.fromLTRB(9, 5, 17, 11), fontSize: 16),
              child: 'tl',
            ),
          ),
        );

        final host = renderOf(tester);
        expect(host.contentOrigin, const Offset(9, 5));
        final rects = (host.content as TextEngine).selectionPaintRectsForRange(const ui.TextRange(start: 0, end: 2));
        expect(rects, isNotEmpty);
        final bounds = rects.reduce((a, b) => a.expandToInclude(b));
        expect(bounds.left, closeTo(host.contentOrigin.dx, 1.0));
        expect(bounds.top, closeTo(host.contentOrigin.dy, 1.0));
      });

      testWidgets('明确宽度内短文本按 textAlign center 使用完整内容盒', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              key: hostKey,
              style: ElStyle(width: 200, padding: .fromLTRB(10, 0, 20, 0), fontSize: 16, textAlign: .center),
              child: 'center',
            ),
          ),
        );

        final host = renderOf(tester);
        final bounds = glyphBounds(host, 6);
        expect(host.boxSize.width, 200);
        expect(bounds.center.dx, closeTo((10 + 180) / 2, 1.0));
      });

      testWidgets('明确宽度内短文本按 textAlign right 贴内容盒右边', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              key: hostKey,
              style: ElStyle(width: 200, padding: .fromLTRB(10, 0, 20, 0), fontSize: 16, textAlign: .right),
              child: 'right',
            ),
          ),
        );

        final host = renderOf(tester);
        expect(glyphBounds(host, 5).right, closeTo(180, 1.0));
      });

      testWidgets('tight 父宽度内短文本按 textAlign center 居中', (tester) async {
        await tester.pumpWidget(
          shell(
            const SizedBox(
              width: 200,
              child: ElView(
                key: hostKey,
                style: ElStyle(fontSize: 16, textAlign: .center),
                child: 'tight',
              ),
            ),
          ),
        );

        final host = renderOf(tester);
        expect(host.boxSize.width, 200);
        expect(glyphBounds(host, 5).center.dx, closeTo(100, 1.0));
      });

      testWidgets('auto 宽度短文本继续 hug，不因 textAlign 撑满父约束', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              key: hostKey,
              style: ElStyle(fontSize: 16, textAlign: .center),
              child: 'hug',
            ),
          ),
        );

        final host = renderOf(tester);
        final bounds = glyphBounds(host, 3);
        expect(host.boxSize.width, lessThan(80));
        expect(host.boxSize.width, closeTo(bounds.width, 1.0));
      });
    });
  });

  group('布局参考约束', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    ElRenderView renderViewOf(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    testWidgets('链上无提供者时百分比退回 auto：UnconstrainedBox 直接包 100% 宽 ElView', (tester) async {
      const targetKey = ValueKey('no-reference');

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: UnconstrainedBox(
              child: ElView(
                key: targetKey,
                style: ElStyle(width: '100%', height: 40),
                child: SizedBox(width: 80, height: 20),
              ),
            ),
          ),
        ),
      );

      // 根 RenderView 不是 LayoutReferenceBox 提供者，UnconstrainedBox 又把
      // width 约束打成 ∞ → percent 折回 null → 退 auto，宽 = 内容宽（含 padding）。
      final render = renderViewOf(tester, targetKey);
      expect(render.size.width, 80.0);
    });
  });

  group('固有尺寸', () {
    Widget shell(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    ElRenderView render(WidgetTester tester) => tester.renderObjectList<ElRenderView>(find.byType(ElView)).first;

    group('IntrinsicWidth：ElView 应能被宽度推导', () {
      testWidgets('短 String 子：getMaxIntrinsicWidth 返回正值（不再是 0）', (tester) async {
        await tester.pumpWidget(
          shell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: const ElView(style: ElStyle(fontSize: 14), child: 'short'),
            ),
          ),
        );
        final r = render(tester);
        final maxW = r.getMaxIntrinsicWidth(double.infinity);
        final minW = r.getMinIntrinsicWidth(double.infinity);
        // 接通前默认 RenderBox 返回 0；现在应返回真实 painter intrinsic
        expect(maxW, greaterThan(0), reason: 'getMaxIntrinsicWidth 应委托 painter 算出真实文本宽');
        expect(minW, greaterThan(0));
        expect(minW, lessThanOrEqualTo(maxW), reason: 'min ≤ max（CSS 标准）');
      });

      testWidgets('显式 width：覆盖 intrinsic', (tester) async {
        await tester.pumpWidget(shell(const IntrinsicWidth(child: ElView(style: ElStyle(width: 120, fontSize: 14)))));
        // 显式 width=120 应被 intrinsic 直接返回
        final r = render(tester);
        expect(r.size.width, 120);
      });

      testWidgets('显式 width 仍受 maxWidth 约束', (tester) async {
        await tester.pumpWidget(
          shell(const IntrinsicWidth(child: ElView(style: ElStyle(width: 300, maxWidth: 200, height: 40)))),
        );

        final r = render(tester);
        expect(r.getMaxIntrinsicWidth(double.infinity), 200);
        expect(r.size.width, 200);
      });

      testWidgets('内容 intrinsic 仍受 minWidth 约束', (tester) async {
        await tester.pumpWidget(
          shell(
            const IntrinsicWidth(
              child: ElView(style: ElStyle(minWidth: 200, height: 40), child: SizedBox(width: 50, height: 20)),
            ),
          ),
        );

        final r = render(tester);
        expect(r.getMaxIntrinsicWidth(double.infinity), 200);
        expect(r.size.width, 200);
      });

      testWidgets('padding 加到 intrinsic 上', (tester) async {
        // 内容 ~ 'X' 宽度 + padding 10*2 = 20
        await tester.pumpWidget(
          shell(
            const IntrinsicWidth(
              child: ElView(style: ElStyle(padding: .all(10), fontSize: 14)),
            ),
          ),
        );
        final r = render(tester);
        expect(r.size.width, greaterThanOrEqualTo(20), reason: 'IntrinsicWidth 至少包含 padding 20px');
      });
    });

    group('getMaxIntrinsicWidth：直接调用', () {
      testWidgets('显式 width=200 时直接返回 200', (tester) async {
        await tester.pumpWidget(shell(const ElView(style: ElStyle(width: 200), child: SizedBox())));
        final r = render(tester);
        expect(r.getMaxIntrinsicWidth(double.infinity), 200);
        expect(r.getMinIntrinsicWidth(double.infinity), 200);
      });

      testWidgets('无显式 width + 文本 child：ElView 返回 painter.maxIntrinsicWidth', (tester) async {
        await tester.pumpWidget(shell(const ElView(style: ElStyle(fontSize: 14), child: 'hello world')));
        final r = render(tester);
        final maxW = r.getMaxIntrinsicWidth(double.infinity);
        // 'hello world' 大约 ~70px；下界宽松
        expect(maxW, greaterThan(50));
      });

      testWidgets('无显式 width + TextSpan child：ElView 返回 rich text intrinsic 而不是 TextSpan.toString 宽度', (tester) async {
        const span = TextSpan(
          text: 'hello ',
          children: <InlineSpan>[TextSpan(text: 'span')],
        );
        await tester.pumpWidget(shell(const ElView(style: ElStyle(fontSize: 14), child: span)));

        final r = render(tester);
        final expectedPainter = TextPainter(text: span, textDirection: TextDirection.ltr)
          ..layout(maxWidth: double.infinity);
        addTearDown(expectedPainter.dispose);

        expect((r.content as TextEngine?)?.painterForTest.text?.toPlainText().isNotEmpty ?? false, isTrue);
        expect(r.getMaxIntrinsicWidth(double.infinity), closeTo(expectedPainter.maxIntrinsicWidth, 0.01));
      });
    });

    group('getMaxIntrinsicHeight：直接调用', () {
      testWidgets('显式 height 直接返回', (tester) async {
        await tester.pumpWidget(shell(const ElView(style: ElStyle(height: 80), child: SizedBox())));
        final r = render(tester);
        expect(r.getMaxIntrinsicHeight(double.infinity), 80);
        expect(r.getMinIntrinsicHeight(double.infinity), 80);
      });

      testWidgets('显式 height 仍受 maxHeight 约束', (tester) async {
        await tester.pumpWidget(
          shell(const IntrinsicHeight(child: ElView(style: ElStyle(width: 40, height: 100, maxHeight: 60)))),
        );

        final r = render(tester);
        expect(r.getMaxIntrinsicHeight(double.infinity), 60);
        expect(r.size.height, 60);
      });

      testWidgets('纯 String + 受限宽度：高度根据 wrap 算出', (tester) async {
        await tester.pumpWidget(
          shell(const ElView(style: ElStyle(fontSize: 14), child: 'one two three four five six')),
        );
        final r = render(tester);
        // 给 60px 宽度逼着换行，height 应 > 单行 14
        final h = r.getMaxIntrinsicHeight(60);
        expect(h, greaterThan(14));
      });
    });

    group('aspectRatio intrinsic 与 layout 规则一致', () {
      testWidgets('比例和交叉尺寸已确定时不查询子节点 intrinsic', (tester) async {
        for (final (style, width, expected) in [
          (ElStyle(height: 80, aspectRatio: 2), true, 160.0),
          (ElStyle(width: 200, aspectRatio: 2), false, 100.0),
        ]) {
          await tester.pumpWidget(
            shell(
              ElView(
                style: style,
                child: LayoutBuilder(builder: (_, _) => SizedBox(width: 10, height: 10)),
              ),
            ),
          );
          final r = render(tester);
          // LayoutBuilder 不支持 intrinsic；已知比例的父盒应独立得出结果。
          expect(width ? r.getMinIntrinsicWidth(double.infinity) : r.getMinIntrinsicHeight(double.infinity), expected);
          expect(width ? r.getMaxIntrinsicWidth(double.infinity) : r.getMaxIntrinsicHeight(double.infinity), expected);
        }
      });

      testWidgets('height + aspectRatio 派生 intrinsic width', (tester) async {
        await tester.pumpWidget(shell(const ElView(style: ElStyle(height: 100, aspectRatio: 2), child: SizedBox())));
        final r = render(tester);

        expect(r.getMinIntrinsicWidth(double.infinity), 200);
        expect(r.getMaxIntrinsicWidth(double.infinity), 200);
        expect(r.size, const Size(200, 100));
      });

      testWidgets('width + aspectRatio 派生 intrinsic height', (tester) async {
        await tester.pumpWidget(shell(const ElView(style: ElStyle(width: 200, aspectRatio: 2), child: SizedBox())));
        final r = render(tester);

        expect(r.getMinIntrinsicHeight(double.infinity), 100);
        expect(r.getMaxIntrinsicHeight(double.infinity), 100);
        expect(r.size, const Size(200, 100));
      });

      testWidgets('无显式宽高 + aspectRatio 用内容 intrinsic width 推导 height', (tester) async {
        await tester.pumpWidget(
          shell(const ElView(style: ElStyle(aspectRatio: 2), child: SizedBox(width: 100, height: 999))),
        );
        final r = render(tester);

        expect(r.getMaxIntrinsicWidth(double.infinity), 100);
        expect(r.getMaxIntrinsicHeight(double.infinity), 50);
        expect(r.size, const Size(100, 50));
      });

      testWidgets('aspectRatio 派生尺寸先 clamp 再加 margin', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(width: 200, aspectRatio: 0.5, maxHeight: 200, margin: .symmetric(vertical: 8)),
              child: SizedBox(),
            ),
          ),
        );
        final r = render(tester);

        expect(r.getMaxIntrinsicHeight(double.infinity), 216);
        expect(r.size, const Size(200, 216));
      });

      testWidgets('height + aspectRatio 不重复叠加 padding，但会加 margin', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(height: 100, aspectRatio: 2, padding: .all(10), margin: .symmetric(horizontal: 4)),
              child: SizedBox(width: 50, height: 50),
            ),
          ),
        );
        final r = render(tester);

        expect(r.getMaxIntrinsicWidth(double.infinity), 208);
        expect(r.size, const Size(208, 100));
      });
    });

    group('回归：现有 layout 路径不受 intrinsic 影响', () {
      testWidgets('不被 IntrinsicWidget 包裹时 ElView 正常 layout', (tester) async {
        await tester.pumpWidget(
          shell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300, maxHeight: 600),
              child: const ElView(
                style: ElStyle(width: 100, height: 50, backgroundColor: Color(0xFFFF0000)),
                child: SizedBox(),
              ),
            ),
          ),
        );
        final r = render(tester);
        expect(r.size, const Size(100, 50));
      });
    });
  });

  group('逻辑边距', () {
    const k = ValueKey('box');

    Widget build(TextDirection dir) => MaterialApp(
      home: Stack(
        children: [
          ElView(
            key: k,
            style: ElStyle(
              width: 100,
              height: 50,
              direction: dir,
              padding: const EdgeInsetsDirectional.only(start: 10, end: 30),
            ),
            child: 'x',
          ),
        ],
      ),
    );

    testWidgets('LTR：start=左 10，内容原点 dx=10', (tester) async {
      await tester.pumpWidget(build(TextDirection.ltr));
      final render = tester.renderObject<ElRenderView>(find.byKey(k));
      expect(render.contentOrigin.dx, 10);
    });

    testWidgets('RTL：start=右，内容原点 dx=end=30', (tester) async {
      await tester.pumpWidget(build(TextDirection.rtl));
      final render = tester.renderObject<ElRenderView>(find.byKey(k));
      expect(render.contentOrigin.dx, 30);
    });

    test('lerp：同逻辑形态逐边插值', () {
      final mid = EdgeInsetsGeometry.lerp(
        const EdgeInsetsDirectional.only(start: 0, end: 20),
        const EdgeInsetsDirectional.only(start: 10, end: 40),
        0.5,
      )!;
      expect(mid.resolve(TextDirection.ltr), const EdgeInsets.only(left: 5, right: 30));
      expect(mid.resolve(TextDirection.rtl), const EdgeInsets.only(left: 30, right: 5));
    });

    test('lerp：物理与逻辑边距按原生规则连续混合', () {
      const physical = EdgeInsets.only(left: 10);
      const logical = EdgeInsetsDirectional.only(start: 30);
      final early = EdgeInsetsGeometry.lerp(physical, logical, 0.25)!;
      final late_ = EdgeInsetsGeometry.lerp(physical, logical, 0.75)!;
      expect(early.resolve(TextDirection.ltr), const EdgeInsets.only(left: 15));
      expect(early.resolve(TextDirection.rtl), const EdgeInsets.only(left: 7.5, right: 7.5));
      expect(late_.resolve(TextDirection.ltr), const EdgeInsets.only(left: 25));
      expect(late_.resolve(TextDirection.rtl), const EdgeInsets.only(left: 2.5, right: 22.5));
    });
  });
}
