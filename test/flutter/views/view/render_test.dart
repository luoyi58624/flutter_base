import 'paint_recording.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Codec;
import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_base/src/flutter/utils/internal/bit_mask.dart';
import 'package:flutter_base/src/flutter/views/view/style/inheritance/inheritable_node.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _viewport(Widget child) => MediaQuery(
  data: const MediaQueryData(size: Size(800, 600)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

Widget _app(Widget child) => MaterialApp(
  home: Align(alignment: Alignment.topLeft, child: child),
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

class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  const _PendingImageProvider([this.id = 'base']);

  final String id;

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) async => this;

  @override
  ImageStreamCompleter loadImage(_PendingImageProvider key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }

  @override
  bool operator ==(Object other) => other is _PendingImageProvider && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 永远 pending 的假 image provider（不实际加载，让 paint 走完不抛错）。
class _FakeImageProvider extends ImageProvider<_FakeImageProvider> {
  const _FakeImageProvider();

  @override
  Future<_FakeImageProvider> obtainKey(ImageConfiguration configuration) async {
    return this;
  }

  @override
  ImageStreamCompleter loadImage(_FakeImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(codec: Completer<Codec>().future, scale: 1);
  }
}

/// T9：damage_router 直接单测 —— 三个不变量：
/// 1. layout 字段→ markNeedsLayout（含或不含 paint，都不再叠加 markPaint）
/// 2. paint-only 字段→ markNeedsPaint
/// 3. inherit 字段→ 递归 InheritancePropagator.propagate
class _MarkRecordingBox extends RenderBox {
  int layoutCalls = 0;
  int paintCalls = 0;

  @override
  void markNeedsLayout() {
    layoutCalls++;
  }

  @override
  void markNeedsPaint() {
    paintCalls++;
  }

  @override
  void performLayout() {
    size = constraints.smallest;
  }
}

class _InheritStub implements InheritableNode {
  _InheritStub({this.children = const [], this.themeMaskToBlock = FieldMask.empty});

  @override
  ResolvedStyle? get committedResolvedStyle => null;

  @override
  bool get effectiveDarkForInheritance => false;

  /// **T11**：test stub 显式空集 → mask 恒 0（走 default fold 也是 0，直写省
  /// 一次 iterable 遍历）。
  @override
  FieldMask get explicitlySetMask => FieldMask.empty;

  final FieldMask themeMaskToBlock;

  final List<_InheritStub> children;

  final List<Set<ElTransitionField>> reresolveCalls = <Set<ElTransitionField>>[];
  final List<FieldMask> themeAnimationMaskCalls = <FieldMask>[];

  @override
  void visitInheritableChildren(void Function(InheritableNode child) visitor) {
    for (final c in children) {
      visitor(c);
    }
  }

  @override
  void reresolveVarsFromInheritance(ResolvedStyle? newParentResolved) {
    visitInheritableChildren((child) => child.reresolveVarsFromInheritance(newParentResolved));
  }

  @override
  FieldMask reresolveFromInheritance(
    ResolvedStyle? newParentResolved,
    FieldMask changedMask, {
    FieldMask inheritedThemeAnimationMask = FieldMask.empty,
  }) {
    reresolveCalls.add(changedMask.fields.toSet());
    themeAnimationMaskCalls.add(inheritedThemeAnimationMask);
    return maskAndNot(inheritedThemeAnimationMask, themeMaskToBlock);
  }

  @override
  bool inheritDarkFromAncestor(bool dark) => true;

  /// **T-variant2** — stub 无响应式基准 → 位恒 0。
  @override
  int get responsiveBitsForInheritance => 0;

  /// **T-variant2** — stub 透明转发（无位需要清）。
  @override
  bool inheritResponsiveFromAncestor(int bits) => true;
}

Widget _hitOverflowBoundsApp(Widget child) {
  return MaterialApp(
    home: Align(alignment: .topLeft, child: child),
  );
}

/// 用户侧宿主范本：render 层手动持有 ElRenderView，收尾自己 dispose
class _HostWidget extends LeafRenderObjectWidget {
  const _HostWidget({super.key, required this.create});

  final ElRenderView Function() create;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHost(create());
}

class _RenderHost extends RenderProxyBox {
  _RenderHost(ElRenderView label) {
    child = label;
  }

  ElRenderView get label => child! as ElRenderView;

  @override
  void dispose() {
    final detached = child;
    child = null;
    detached?.dispose();
    super.dispose();
  }
}

Widget _tree(ElRenderView Function() create, {ElStyle? ancestorStyle, ElThemeMode? themeMode}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: ElView(
        themeMode: themeMode,
        style: ancestorStyle,
        // LeafRenderObjectWidget 同类型复用 element 时不会重跑 createRenderObject，
        // create 闭包会被静默忽略——每次 pump 强制重挂，保证拿到本轮构造的 render
        child: _HostWidget(key: UniqueKey(), create: create),
      ),
    ),
  );
}

ElRenderView _label(WidgetTester tester) => tester.renderObject<_RenderHost>(find.byType(_HostWidget)).label;

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

    group('装饰状态更新', () {
      testWidgets('decoration hover variants commit every visual field used by examples', (tester) async {
        const radiusKey = ValueKey('decoration-radius');
        const roundKey = ValueKey('decoration-round');
        const circleKey = ValueKey('decoration-circle');
        const borderKey = ValueKey('decoration-border');
        const borderBottomKey = ValueKey('decoration-border-bottom');
        const shadowKey = ValueKey('decoration-shadow');
        const multiShadowKey = ValueKey('decoration-multi-shadow');
        const clipKey = ValueKey('decoration-clip');
        const outlineKey = ValueKey('decoration-outline');

        await pumpExample(
          tester,
          Column(
            children: [
              _box(
                radiusKey,
                const ElStyle(
                  borderRadius: .zero,
                  onHover: ElStyle(borderRadius: BorderRadius.all(Radius.elliptical(16, 16))),
                ),
              ),
              _box(
                roundKey,
                ElStyle(
                  borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
                  onHover: const ElStyle(borderRadius: BorderRadius.all(Radius.circular(20))),
                ),
              ),
              _box(
                circleKey,
                ElStyle(
                  borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
                  onHover: const ElStyle(clipPath: ShapeBorderClipper(shape: CircleBorder())),
                ),
              ),
              _box(
                borderKey,
                ElStyle(
                  border: .all(borderWidth: 0, borderStyle: ElBorderStyle.none),
                  borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
                  onHover: ElStyle(border: .all(borderColor: const Color(0xFF3B82F6), borderWidth: 2)),
                ),
              ),
              _box(
                borderBottomKey,
                const ElStyle(
                  border: .only(borderBottom: ElBorderSide.none),
                  borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
                  onHover: ElStyle(
                    border: .only(borderBottom: ElBorderSide(borderColor: Color(0xFF3B82F6), borderWidth: 2)),
                  ),
                ),
              ),
              _box(
                shadowKey,
                const ElStyle(
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                  onHover: ElStyle(
                    boxShadow: [BoxShadow(color: Color(0x403B82F6), blurRadius: 20, offset: Offset(0, 8))],
                  ),
                ),
              ),
              _box(
                multiShadowKey,
                const ElStyle(
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  onHover: ElStyle(
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      BoxShadow(color: Color(0x403B82F6), blurRadius: 16, offset: Offset(0, 6)),
                    ],
                  ),
                ),
              ),
              _box(
                clipKey,
                const ElStyle(
                  clipBehavior: Clip.none,
                  onHover: ElStyle(clipBehavior: Clip.hardEdge),
                ),
              ),
              _box(
                outlineKey,
                const ElStyle(
                  onHover: ElStyle(outline: ElOutline(outlineColor: Color(0xFF3B82F6), outlineWidth: 2.5, outlineOffset: 3)),
                ),
              ),
            ],
          ),
        );

        for (final key in [
          radiusKey,
          roundKey,
          circleKey,
          borderKey,
          borderBottomKey,
          shadowKey,
          multiShadowKey,
          clipKey,
          outlineKey,
        ]) {
          await hover(tester, key);
        }

        expect(
          viewOf(tester, radiusKey).committedResolvedStyle.box.borderRadius?.resolve(TextDirection.ltr).topLeft.x,
          16,
        );
        expect(
          viewOf(tester, roundKey).committedResolvedStyle.box.borderRadius?.resolve(TextDirection.ltr).topLeft.x,
          20,
        );
        expect(viewOf(tester, circleKey).committedResolvedStyle.box.clipPath, isA<ShapeBorderClipper>());
        expect(viewOf(tester, borderKey).committedResolvedStyle.box.border!.borderTop.borderWidth, 2);
        expect(viewOf(tester, borderBottomKey).committedResolvedStyle.box.border!.borderBottom.borderWidth, 2);
        expect(
          (viewOf(tester, shadowKey).committedResolvedStyle.box.boxShadow as List<BoxShadow>).single.blurRadius,
          20,
        );
        expect(viewOf(tester, multiShadowKey).committedResolvedStyle.box.boxShadow, hasLength(2));
        expect(viewOf(tester, clipKey).committedResolvedStyle.box.clipBehavior, Clip.hardEdge);
        expect(viewOf(tester, outlineKey).committedResolvedStyle.box.outline!.outlineOffset, 3);
      });

      testWidgets('zero-width border with radius is not painted as a Flutter hairline border', (tester) async {
        await pumpExample(
          tester,
          ElView(
            style: ElStyle(
              width: 80,
              height: 40,
              backgroundColor: Colors.white,
              borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
              border: .only(borderBottom: ElBorderSide(borderColor: Colors.transparent, borderWidth: 0)),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('animated zero-width border with radius never reaches Flutter hairline paint', (tester) async {
        const key = ValueKey('decoration-animated-border-bottom');
        await pumpExample(
          tester,
          ElView(
            key: key,
            style: ElStyle(
              width: 96,
              height: 64,
              backgroundColor: Colors.white,
              borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
              border: .only(borderBottom: ElBorderSide(borderColor: Colors.transparent, borderWidth: 0)),
              transition: const [ElTransition.all(Duration(milliseconds: 250))],
              onHover: const ElStyle(
                border: .only(borderBottom: ElBorderSide(borderColor: Color(0xFF3B82F6), borderWidth: 2)),
              ),
            ),
          ),
        );

        final render = viewOf(tester, key);
        render.setHover(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 124));
        await tester.pump(const Duration(milliseconds: 125));

        expect(tester.takeException(), isNull);
        expect(render.committedResolvedStyle.box.border!.borderBottom.borderWidth, 2);
      });

      testWidgets('animated BorderSide.none bottom border with radius matches decoration example', (tester) async {
        const key = ValueKey('decoration-border-side-none-bottom');
        await pumpExample(
          tester,
          const ElView(
            key: key,
            style: ElStyle(
              width: 96,
              height: 64,
              backgroundColor: Colors.white,
              borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
              border: .only(borderBottom: ElBorderSide.none),
              transition: [ElTransition.all(Duration(milliseconds: 250))],
              onHover: ElStyle(
                border: .only(borderBottom: ElBorderSide(borderColor: Color(0xFF3B82F6), borderWidth: 2)),
              ),
            ),
          ),
        );

        final render = viewOf(tester, key);
        render.setHover(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 108));
        await tester.pump(const Duration(milliseconds: 125));

        expect(tester.takeException(), isNull);
        expect(render.committedResolvedStyle.box.border!.borderBottom.borderWidth, 2);
      });

      testWidgets('animated BorderSide.none bottom border with radius exits without Flutter hairline border', (
        tester,
      ) async {
        const key = ValueKey('decoration-border-side-none-bottom-exit');
        await pumpExample(
          tester,
          ElView(
            themeMode: const ElThemeMode(brightness: Brightness.light),
            style: const ElStyle(fontSize: 13),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const .symmetric(vertical: 8),
              child: Row(
                spacing: 16,
                children: [
                  ElView(
                    key: key,
                    style: ElStyle(
                      height: 64,
                      backgroundColor: Colors.white,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      border: .only(borderBottom: ElBorderSide.none),
                      borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
                      alignment: Alignment.center,
                      padding: const .symmetric(horizontal: 16),
                      transition: const [ElTransition.all()],
                      onDark: _darkBase,
                      onHover: const ElStyle(
                        border: .only(borderBottom: ElBorderSide(borderColor: Color(0xFF3B82F6), borderWidth: 2)),
                      ),
                    ),
                    child: 'border-bottom',
                  ),
                ],
              ),
            ),
          ),
        );

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: const Offset(-10, -10));
        await tester.pump();
        await mouse.moveTo(tester.getCenter(find.byKey(key)));
        await tester.pump();
        // ElTransition.all() 默认 300ms。
        await tester.pump(const Duration(milliseconds: 300));
        await mouse.moveTo(const Offset(-10, -10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 299));
        await tester.pump(const Duration(milliseconds: 1));

        expect(tester.takeException(), isNull);
        final render = viewOf(tester, key);
        expect(render.committedResolvedStyle.box.border!.borderBottom, ElBorderSide.none);
      });
    });

    group('渐变与背景效果', () {
      testWidgets('gradient hover variants commit gradient, backdrop filter, and backgroundImage', (tester) async {
        const linearKey = ValueKey('gradient-linear');
        const radialKey = ValueKey('gradient-radial');
        const sweepKey = ValueKey('gradient-sweep');
        const bgToGradientKey = ValueKey('gradient-bg-to-gradient');
        const backdropKey = ValueKey('gradient-backdrop');
        const bgImageKey = ValueKey('gradient-bg-image');

        const imageA = DecorationImage(image: _PendingImageProvider(), fit: BoxFit.cover);
        const imageB = DecorationImage(image: _PendingImageProvider('hover'), fit: BoxFit.cover);

        await pumpExample(
          tester,
          Column(
            children: [
              ElView(
                key: linearKey,
                style: ElStyle(
                  width: 120,
                  height: 60,
                  gradient: LinearGradient(
                    colors: [Color(0xff667eea), Color(0xff764ba2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  onHover: ElStyle(
                    gradient: LinearGradient(
                      colors: [Color(0xff667eea), Color(0xff764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              ElView(
                key: radialKey,
                style: ElStyle(
                  width: 120,
                  height: 60,
                  gradient: RadialGradient(colors: [Color(0xfff093fb), Color(0xfff5576c)]),
                  onHover: ElStyle(
                    gradient: RadialGradient(
                      colors: [Color(0xfff093fb), Color(0xfff5576c)],
                      focal: Alignment(-0.3, -0.3),
                      focalRadius: 0.2,
                    ),
                  ),
                ),
              ),
              ElView(
                key: sweepKey,
                style: ElStyle(
                  width: 120,
                  height: 60,
                  gradient: SweepGradient(
                    colors: [Color(0xff667eea), Color(0xfff5576c), Color(0xff00f2fe), Color(0xff667eea)],
                  ),
                  onHover: ElStyle(
                    gradient: SweepGradient(
                      colors: [Color(0xff00f2fe), Color(0xff667eea), Color(0xff764ba2), Color(0xff00f2fe)],
                      startAngle: 0.5,
                    ),
                  ),
                ),
              ),
              ElView(
                key: bgToGradientKey,
                style: ElStyle(
                  width: 120,
                  height: 60,
                  backgroundColor: Color(0xff4facfe),
                  onHover: ElStyle(
                    gradient: LinearGradient(
                      colors: [Color(0xff4facfe), Color(0xff00f2fe)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              ElView(
                key: backdropKey,
                style: ElStyle(
                  width: 120,
                  height: 60,
                  backgroundColor: Color(0xff667eea),
                  onHover: ElStyle(backdropFilter: const ElFilter(blur: 4), backgroundColor: const Color(0x66ffffff)),
                ),
              ),
              ElView(
                key: bgImageKey,
                style: ElStyle(
                  width: 120,
                  height: 60,
                  backgroundImage: imageA,
                  onHover: ElStyle(backgroundImage: imageB),
                ),
              ),
            ],
          ),
        );

        for (final key in [linearKey, radialKey, sweepKey, bgToGradientKey, backdropKey, bgImageKey]) {
          await hover(tester, key);
        }

        final linear = viewOf(tester, linearKey).committedResolvedStyle.box.gradient! as LinearGradient;
        final radial = viewOf(tester, radialKey).committedResolvedStyle.box.gradient! as RadialGradient;
        final sweep = viewOf(tester, sweepKey).committedResolvedStyle.box.gradient! as SweepGradient;

        expect(linear.begin, Alignment.topLeft);
        expect(radial.focal, const Alignment(-0.3, -0.3));
        expect(sweep.startAngle, 0.5);
        expect(viewOf(tester, bgToGradientKey).committedResolvedStyle.box.gradient, isA<LinearGradient>());
        expect(viewOf(tester, backdropKey).committedResolvedStyle.box.backdropFilter, isNotNull);
        expect(viewOf(tester, backdropKey).committedResolvedStyle.box.backgroundColor, const Color(0x66ffffff));
        expect(viewOf(tester, bgImageKey).committedResolvedStyle.box.backgroundImage, same(imageB));
      });
    });
  });

  group('背景图片生命周期', () {
    Widget shell(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    ElRenderView render(WidgetTester tester) => tester.renderObjectList<ElRenderView>(find.byType(ElView)).first;

    group('backgroundImage painter lifecycle', () {
      testWidgets('image 引用不变（identical）：painter 跨 pump 复用', (tester) async {
        const image = DecorationImage(image: _FakeImageProvider());
        // pump 第一次：创建 painter
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(width: 100, height: 100, backgroundImage: image),
              child: SizedBox(),
            ),
          ),
        );
        final r = render(tester);
        final painter1 = (r.paintControllerForTest?.bgImagePainter);
        final imageFor1 = (r.paintControllerForTest?.bgImagePainterFor);
        expect(painter1, isNotNull, reason: '首次 paint 后应创建 painter');
        expect(identical(imageFor1, image), isTrue, reason: 'image identity 与持有的引用一致');

        // pump 第二次：同样的 ElStyle(..., backgroundImage: image)（image 仍 const identical）
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(width: 100, height: 100, backgroundImage: image),
              child: SizedBox(),
            ),
          ),
        );
        await tester.pump();
        final painter2 = (r.paintControllerForTest?.bgImagePainter);
        expect(identical(painter1, painter2), isTrue, reason: 'image identical → painter 应复用（不重 create）');
      });

      testWidgets('image 引用变化：dispose 旧 painter + create 新的', (tester) async {
        // 用不同 fit 让 const constructor 不能共享实例
        const imageA = DecorationImage(image: _FakeImageProvider(), fit: BoxFit.cover);
        const imageB = DecorationImage(image: _FakeImageProvider(), fit: BoxFit.contain);
        expect(identical(imageA, imageB), isFalse, reason: '前置：测试构造的 imageA / imageB 必须不 identical');

        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(width: 100, height: 100, backgroundImage: imageA),
              child: SizedBox(),
            ),
          ),
        );
        final r = render(tester);
        final painterA = (r.paintControllerForTest?.bgImagePainter);
        expect(painterA, isNotNull);

        // 切到 imageB
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(width: 100, height: 100, backgroundImage: imageB),
              child: SizedBox(),
            ),
          ),
        );
        await tester.pump();
        final painterB = (r.paintControllerForTest?.bgImagePainter);
        expect(painterB, isNotNull);
        expect(identical(painterA, painterB), isFalse, reason: 'image 切换应 create 新 painter');
        expect(identical((r.paintControllerForTest?.bgImagePainterFor), imageB), isTrue);
      });

      testWidgets('backgroundImage 从有到 null：painter 被 dispose 清空', (tester) async {
        const image = DecorationImage(image: _FakeImageProvider());
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(width: 100, height: 100, backgroundImage: image),
              child: SizedBox(),
            ),
          ),
        );
        final r = render(tester);
        expect((r.paintControllerForTest?.bgImagePainter), isNotNull);

        // 移除 backgroundImage
        await tester.pumpWidget(shell(const ElView(style: ElStyle(width: 100, height: 100), child: SizedBox())));
        await tester.pump();
        expect((r.paintControllerForTest?.bgImagePainter), isNull, reason: 'backgroundImage 移除后 painter 应清空');
        expect((r.paintControllerForTest?.bgImagePainterFor), isNull);
      });

      testWidgets('backgroundImage 从 null 到有：lazy create painter', (tester) async {
        // 初始无 backgroundImage
        await tester.pumpWidget(shell(const ElView(style: ElStyle(width: 100, height: 100), child: SizedBox())));
        final r = render(tester);
        expect((r.paintControllerForTest?.bgImagePainter), isNull);

        // 加 backgroundImage
        const image = DecorationImage(image: _FakeImageProvider());
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(width: 100, height: 100, backgroundImage: image),
              child: SizedBox(),
            ),
          ),
        );
        await tester.pump();
        expect((r.paintControllerForTest?.bgImagePainter), isNotNull, reason: '首次设置 backgroundImage 应 create painter');
      });

      testWidgets('onHover 切 backgroundImage：painter 被 dispose 重建', (tester) async {
        const imageA = DecorationImage(image: _FakeImageProvider(), fit: BoxFit.cover);
        const imageB = DecorationImage(image: _FakeImageProvider(), fit: BoxFit.contain);
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(
                width: 100,
                height: 100,
                backgroundImage: imageA,
                onHover: ElStyle(backgroundImage: imageB),
              ),
              child: SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final r = render(tester);
        final painterA = (r.paintControllerForTest?.bgImagePainter);

        r.setHover(true);
        await tester.pump();

        final painterB = (r.paintControllerForTest?.bgImagePainter);
        expect(identical(painterA, painterB), isFalse, reason: 'hover 后 image 切换应 dispose 旧 + create 新 painter');
        expect(identical((r.paintControllerForTest?.bgImagePainterFor), imageB), isTrue);
      });
    });
  });

  group('边框对齐', () {
    const red = Color(0xFFEF4444);

    const rect = Rect.fromLTWH(0, 0, 100, 60);

    group('原生大圆角边框', () {
      for (final align in ElBorderAlign.values) {
        for (final lineStyle in [ElBorderStyle.solid, ElBorderStyle.dashed, ElBorderStyle.dotted]) {
          test('$align / $lineStyle：分色边框先缩放圆角，路径留在盒子附近', () {
            final box = Rect.fromLTWH(10, 20, 34, 34);
            final border = ElBorder.only(
              borderTop: ElBorderSide(borderColor: Color(0xff409eff), borderWidth: 3, borderStyle: lineStyle),
              borderRight: ElBorderSide(borderColor: Color(0xffe4e7ed), borderWidth: 3, borderStyle: lineStyle),
              borderBottom: ElBorderSide(borderColor: Color(0xffe4e7ed), borderWidth: 3, borderStyle: lineStyle),
              borderLeft: ElBorderSide(borderColor: Color(0xffe4e7ed), borderWidth: 3, borderStyle: lineStyle),
              align: align,
            );
            final huge = recordBorderPaints(rect: box, border: border, borderRadius: BorderRadius.circular(9999))!;
            final fitted = recordBorderPaints(rect: box, border: border, borderRadius: BorderRadius.circular(17))!;
            expect(huge, hasLength(fitted.length));
            for (var i = 0; i < huge.length; i++) {
              final path = huge[i].$1 as Path;
              final expectedPath = fitted[i].$1 as Path;
              final bounds = path.getBounds();
              expect(bounds.left, greaterThanOrEqualTo(box.left - 3.001));
              expect(bounds.right, lessThanOrEqualTo(box.right + 3.001));
              expect(bounds.top, greaterThanOrEqualTo(box.top - 3.001));
              expect(bounds.bottom, lessThanOrEqualTo(box.bottom + 3.001));
              final actualMetrics = path.computeMetrics().toList();
              final expectedMetrics = expectedPath.computeMetrics().toList();
              expect(actualMetrics, hasLength(expectedMetrics.length));
              for (var j = 0; j < actualMetrics.length; j++) {
                expect(actualMetrics[j].length, closeTo(expectedMetrics[j].length, 1e-3));
              }
            }
          });
        }
      }

      test('非方盒与不对称椭圆角按相邻半径之和等比缩放', () {
        final rect = Rect.fromLTWH(0, 0, 100, 60);
        final raw = BorderRadius.only(
          topLeft: Radius.elliptical(150, 60),
          topRight: Radius.elliptical(100, 80),
          bottomLeft: Radius.elliptical(120, 200),
          bottomRight: Radius.elliptical(90, 150),
        );
        // 左边两角高度合计 260，限制全体半径按 60/260 缩放。
        final expected = BorderRadius.only(
          topLeft: Radius.elliptical(150 * 3 / 13, 60 * 3 / 13),
          topRight: Radius.elliptical(100 * 3 / 13, 80 * 3 / 13),
          bottomLeft: Radius.elliptical(120 * 3 / 13, 200 * 3 / 13),
          bottomRight: Radius.elliptical(90 * 3 / 13, 150 * 3 / 13),
        );
        final border = ElBorder.only(
          borderTop: ElBorderSide(borderWidth: 3, borderColor: Colors.blue),
          borderRight: ElBorderSide(borderWidth: 2, borderColor: Colors.red),
          borderBottom: ElBorderSide(borderWidth: 4, borderColor: Colors.green),
          borderLeft: ElBorderSide(borderWidth: 1, borderColor: Colors.orange),
        );
        final actual = recordBorderPaints(rect: rect, border: border, borderRadius: raw)!;
        final fitted = recordBorderPaints(rect: rect, border: border, borderRadius: expected)!;
        for (var i = 0; i < actual.length; i++) {
          final a = (actual[i].$1 as Path).computeMetrics().single;
          final b = (fitted[i].$1 as Path).computeMetrics().single;
          expect(a.length, closeTo(b.length, 1e-3));
          for (final t in [0.0, 0.25, 0.5, 0.75]) {
            expect(
              (a.getTangentForOffset(a.length * t)!.position - b.getTangentForOffset(b.length * t)!.position).distance,
              lessThan(1e-3),
            );
          }
        }
      });

      testWidgets('34 像素分色 spinner 旋转时不会向盒外绘制长线', (tester) async {
        final boundaryKey = GlobalKey();
        final spinnerKey = GlobalKey();
        await tester.pumpWidget(
          _viewport(
            RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 120,
                height: 90,
                child: Center(
                  child: ElView(
                    key: spinnerKey,
                    style: ElStyle(
                      width: 34,
                      height: 34,
                      borderRadius: BorderRadius.all(Radius.circular(9999)),
                      border: ElBorder.only(
                        borderTop: ElBorderSide(borderColor: Color(0xff409eff), borderWidth: 3),
                        borderRight: ElBorderSide(borderColor: Color(0xffe4e7ed), borderWidth: 3),
                        borderBottom: ElBorderSide(borderColor: Color(0xffe4e7ed), borderWidth: 3),
                        borderLeft: ElBorderSide(borderColor: Color(0xffe4e7ed), borderWidth: 3),
                      ),
                      animation: [
                        ElAnimation(
                          keyframes: {
                            0: ElStyle(transform: .identity()),
                            100: ElStyle(transform: .rotate(2 * math.pi)),
                          },
                          animationDuration: Duration(milliseconds: 900),
                          animationTimingFunction: Curves.linear,
                          animationIterationCount: double.infinity,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        for (final step in [Duration.zero, Duration(milliseconds: 75), Duration(milliseconds: 150)]) {
          await tester.pump(step);
          expect(tester.getSize(find.byKey(spinnerKey)), Size(34, 34));
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
              var painted = 0;
              for (var y = 0; y < image.height; y++) {
                for (var x = 0; x < image.width; x++) {
                  final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
                  if (alpha == 0) continue;
                  painted++;
                  expect(
                    (Offset(x + 0.5, y + 0.5) - Offset(60, 45)).distance,
                    lessThanOrEqualTo(18),
                    reason: '圆环之外不应出现长线，推进时间 $step',
                  );
                }
              }
              expect(painted, greaterThan(100));
            } finally {
              image.dispose();
            }
          });
        }
      });
    });

    group('边框逻辑像素摆位', () {
      test('inside：声明宽度不变，中心线向盒内偏移半宽', () {
        final ops = recordBorderPaints(
          rect: const Rect.fromLTWH(10.3, 5.2, 100.5, 60.5),
          border: ElBorder.all(borderWidth: 1, borderColor: red),
          borderRadius: null,
        )!;

        expect(ops.single.$1, const Rect.fromLTRB(10.8, 5.7, 110.3, 65.2));
        expect(ops.single.$2.strokeWidth, 1);
      });

      test('center / outside：只按声明半宽移动，不做物理像素量化', () {
        final center = recordBorderPaints(
          rect: rect,
          border: ElBorder.all(borderWidth: 2, borderColor: red, align: .center),
          borderRadius: null,
        )!;
        final outside = recordBorderPaints(
          rect: rect,
          border: ElBorder.all(borderWidth: 2, borderColor: red, align: .outside),
          borderRadius: null,
        )!;

        expect(center.single.$1, rect);
        expect(outside.single.$1, const Rect.fromLTRB(-1, -1, 101, 61));
        expect(center.single.$2.strokeWidth, 2);
        expect(outside.single.$2.strokeWidth, 2);
      });

      test('per-side：保留声明宽度', () {
        final ops = recordBorderPaints(
          rect: rect,
          border: ElBorder.only(borderBottom: ElBorderSide(borderColor: red, borderWidth: 1)),
          borderRadius: null,
        )!;

        expect((ops.single.$1 as Path).getBounds().top, closeTo(59, 1e-4));
      });

      test('缺省黑色与显式黑色共同使用 uniform 路径', () {
        final implicit = ElBorderSide(borderWidth: 2, borderColor: null, borderStyle: .dashed);
        final explicit = ElBorderSide(borderWidth: 2, borderStyle: .dashed);
        final ops = recordBorderPaints(
          rect: rect,
          border: ElBorder.only(borderTop: implicit, borderRight: explicit, borderBottom: implicit, borderLeft: explicit),
          borderRadius: BorderRadius.circular(8),
        )!;
        expect(ops, hasLength(1));
        expect(ops.single.$2.color, Colors.black);
        expect(ops.single.$2.style, PaintingStyle.stroke);
        expect(ops.single.$2.strokeWidth, 2);
        expect((ops.single.$1 as Path).getBounds(), rect.deflate(1));
      });

      test('透明与零宽边不参与圆弧归属，无可见边时不产出绘制', () {
        final ops = recordBorderPaints(
          rect: rect,
          border: ElBorder.only(
            borderTop: ElBorderSide(borderWidth: 3, borderColor: Colors.transparent, borderStyle: .dashed),
            borderRight: ElBorderSide(borderWidth: 0, borderStyle: .dotted),
            borderBottom: ElBorderSide(borderWidth: null),
            borderLeft: ElBorderSide(borderWidth: -2, borderStyle: .none),
          ),
          borderRadius: BorderRadius.circular(8),
        );
        expect(ops, isNull);
        expect(
          () => recordBorderPaints(rect: rect, border: ElBorder.all(borderWidth: -1), borderRadius: null),
          throwsAssertionError,
        );
      });
    });

    group('paint 管线', () {
      Widget wrap(Widget child) => MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      );

      testWidgets('1px uniform 边框完整落在盒内', (tester) async {
        await tester.pumpWidget(
          wrap(
            ElView(
              style: ElStyle(width: 100, height: 60, border: .all(borderColor: red, borderWidth: 1)),
            ),
          ),
        );

        expect(
          find.byType(ElView),
          paints..rect(
            rect: const Rect.fromLTRB(0.5, 0.5, 99.5, 59.5),
            color: red,
            style: PaintingStyle.stroke,
            strokeWidth: 1,
          ),
        );
      });

      testWidgets('圆角 inside 边框保持同心内缩', (tester) async {
        await tester.pumpWidget(
          wrap(
            ElView(
              style: ElStyle(
                width: 100,
                height: 60,
                borderRadius: const .all(Radius.circular(8)),
                border: .all(borderColor: red, borderWidth: 2),
              ),
            ),
          ),
        );

        expect(
          find.byType(ElView),
          paints..rrect(
            rrect: RRect.fromRectAndRadius(const Rect.fromLTRB(1, 1, 99, 59), const Radius.circular(7)),
            color: red,
            style: PaintingStyle.stroke,
            strokeWidth: 2,
          ),
        );
      });
    });
  });

  group('虚线边框', () {
    const red = Color(0xFFEF4444);

    List<(Object, Paint)>? opsOf(ElBorder border, {Rect? rect, BorderRadius? radius}) {
      return recordBorderPaints(rect: rect ?? const Rect.fromLTWH(0, 0, 100, 60), border: border, borderRadius: radius);
    }

    group('uniform 线型', () {
      test('solid 维持 RRect/Rect stroke 快路径（回归锁）', () {
        final ops = opsOf(ElBorder.all(borderWidth: 2, borderColor: red))!;
        expect(ops, hasLength(1));
        expect(ops.single.$1, isA<Rect>(), reason: '无圆角 solid → Rect stroke');

        final rounded = opsOf(ElBorder.all(borderWidth: 2, borderColor: red), radius: BorderRadius.circular(8))!;
        expect(rounded.single.$1, isA<RRect>(), reason: '圆角 solid → RRect stroke');
      });

      test('dashed 矩形：dash Path + 整周期对齐（100×60 inside 中心线周长 312 → 26 段）', () {
        final ops = opsOf(ElBorder.all(borderWidth: 2, borderColor: red))!;
        final dashed = opsOf(ElBorder.all(borderWidth: 2, borderColor: red, borderStyle: ElBorderStyle.dashed))!;
        expect(dashed, hasLength(1));
        final (shape, paint) = dashed.single;
        expect(shape, isA<Path>());
        expect(paint.style, PaintingStyle.stroke);
        expect(paint.strokeWidth, 2);
        expect(paint.strokeCap, StrokeCap.butt);
        expect(paint.color, isSameColorAs(red));
        // dash 3w=6 / gap 3w=6，周期 12；inside 中心线 = 盒边缘内移 w/2=1 →
        // 98×58，周长 2×(98+58) = 312 → round(312/12) = 26 段，每段一个独立
        // contour。
        final contours = (shape as Path).computeMetrics().length;
        expect(contours, 26);
        // 几何包络与 solid stroke 中心线一致（线型不改几何）。
        final solidRect = ops.single.$1 as Rect;
        expect(solidRect, const Rect.fromLTRB(1, 1, 99, 59), reason: 'inside 中心线 = 盒边缘内移 w/2');
        expect(shape.getBounds(), rectMoreOrLessEquals(solidRect, epsilon: 0.01));
      });

      test('dashed + 圆角：contour 多段、包络贴 inside 中心线 RRect', () {
        final dashed = opsOf(
          ElBorder.all(borderWidth: 2, borderColor: red, borderStyle: ElBorderStyle.dashed),
          radius: BorderRadius.circular(12),
        )!;
        final (shape, paint) = dashed.single;
        expect(shape, isA<Path>());
        expect(paint.style, PaintingStyle.stroke);
        final path = shape as Path;
        expect(path.computeMetrics().length, greaterThan(10));
        expect(path.getBounds(), rectMoreOrLessEquals(const Rect.fromLTRB(1, 1, 99, 59), epsilon: 0.01));
      });

      test('dotted：round cap 圆点', () {
        final dotted = opsOf(ElBorder.all(borderWidth: 2, borderColor: red, borderStyle: ElBorderStyle.dotted))!;
        final (shape, paint) = dotted.single;
        expect(paint.strokeCap, StrokeCap.round);
        // 中心距 2w=4，inside 中心线周长 312 → 78 个点。
        expect((shape as Path).computeMetrics().length, 78);
        for (final m in shape.computeMetrics().take(3)) {
          expect(m.length, lessThan(1.0), reason: '点线段长近零，圆点直径由 strokeWidth 承担');
        }
      });
    });

    group('per-side 线型', () {
      test('bottom-only dashed：中心线开放段、两端都落 dash（首尾不秃）', () {
        const bottom = ElBorder.only(
          borderBottom: ElBorderSide(borderWidth: 2, borderColor: red, borderStyle: ElBorderStyle.dashed),
        );
        final ops = opsOf(bottom)!;
        expect(ops, hasLength(1));
        final (shape, paint) = ops.single;
        expect(shape, isA<Path>());
        expect(paint.style, PaintingStyle.stroke);
        expect(paint.strokeWidth, 2);
        final bounds = (shape as Path).getBounds();
        // 开放段 fit：n 段 dash + n-1 段 gap 撑满全长 → 首尾都是 dash；
        // inside 摆位下中心线 = 盒底缘内移 w/2 → y=59，包络精确覆盖
        // (0,59)-(100,59)。
        expect(bounds.left, moreOrLessEquals(0, epsilon: 0.01));
        expect(bounds.right, moreOrLessEquals(100, epsilon: 0.01));
        expect(bounds.top, moreOrLessEquals(59, epsilon: 0.01));
        expect(bounds.bottom, moreOrLessEquals(59, epsilon: 0.01));
        // 长 100、dash 6/gap 6 → n = round((100+6)/12) = 9 段。
        expect(shape.computeMetrics().length, 9);
      });

      test('top solid + bottom dashed 混排：solid 走 fill path，dashed 走 stroke path', () {
        const mixed = ElBorder.only(
          borderTop: ElBorderSide(borderWidth: 2, borderColor: red),
          borderBottom: ElBorderSide(borderWidth: 2, borderColor: red, borderStyle: ElBorderStyle.dashed),
        );
        final ops = opsOf(mixed)!;
        expect(ops, hasLength(2));
        // CSS 边序 top → bottom。
        final (topShape, topPaint) = ops[0];
        expect(topShape, isA<Path>());
        expect(topPaint.style, PaintingStyle.fill, reason: 'solid per-side 维持闭合 fill 带');
        final (bottomShape, bottomPaint) = ops[1];
        expect(bottomPaint.style, PaintingStyle.stroke);
        expect((bottomShape as Path).computeMetrics().length, greaterThan(1));
      });

      test('bottom-only dashed + 圆角：孤边接管全弧，中心线延伸进两个底角', () {
        const bottom = ElBorder.only(
          borderBottom: ElBorderSide(borderWidth: 2, borderColor: red, borderStyle: ElBorderStyle.dashed),
        );
        final ops = opsOf(bottom, radius: BorderRadius.circular(10))!;
        final bounds = (ops.single.$1 as Path).getBounds();
        // 孤边全弧：inside 中心线经底角弧卷到左右两边中线（x 方向到达
        // 1 / 99 = 盒边缘内移 w/2，y 方向向上卷入 ≈ 圆角半径）。
        expect(bounds.left, moreOrLessEquals(1, epsilon: 0.5));
        expect(bounds.right, moreOrLessEquals(99, epsilon: 0.5));
        expect(bounds.top, lessThan(56), reason: '弧向上卷入圆角区域');
        expect(bounds.bottom, moreOrLessEquals(59, epsilon: 0.5));
      });

      test('style: none 边不产出 op', () {
        const border = ElBorder.only(
          borderTop: ElBorderSide(borderWidth: 2, borderColor: red, borderStyle: ElBorderStyle.none),
          borderBottom: ElBorderSide(borderWidth: 2, borderColor: red),
        );
        final ops = opsOf(border)!;
        expect(ops, hasLength(1), reason: 'none 边在 resolveToFlutterBorder 即变 BorderSide.none');
      });
    });

    group('值类语义', () {
      test('ElBorderSide.lerp 线型 step（t<0.5 取 a，否则 b）', () {
        const a = ElBorderSide(borderWidth: 1, borderColor: red, borderStyle: ElBorderStyle.dashed);
        const b = ElBorderSide(borderWidth: 3, borderColor: red);
        expect(ElBorderSide.lerp(a, b, 0.25).borderStyle, ElBorderStyle.dashed);
        expect(ElBorderSide.lerp(a, b, 0.75).borderStyle, ElBorderStyle.solid);
        expect(ElBorderSide.lerp(a, b, 0.5).borderWidth, 2.0, reason: '宽度数值插值不受线型影响');
      });
    });

    group('widget 集成', () {
      testWidgets('ElView 声明 dashed border → 画 stroke path', (tester) async {
        const key = ValueKey('dash');
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: ElView(
                key: key,
                style: ElStyle(
                  width: 100,
                  height: 60,
                  border: ElBorder.all(borderWidth: 2, borderColor: red, borderStyle: ElBorderStyle.dashed),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(key), paints..path(color: red, strokeWidth: 2, style: PaintingStyle.stroke));
      });
    });
  });

  group('边框外缘覆盖', () {
    const bgWhite = Color(0xFFFFFFFF);

    const borderBlue = Color(0xFF3B82F6);

    const cardKey = ValueKey('border-white-ring-card');

    const fracBox = Rect.fromLTWH(0, 0, 260.5, 100.5);

    group('分数盒 inside 外缘贴盒', () {
      test('分数盒 + 3px：右/底外缘 = 逻辑盒边', () {
        final ops = recordBorderPaints(
          rect: fracBox,
          border: ElBorder.all(borderWidth: 3, borderColor: borderBlue),
          borderRadius: null,
        )!;
        final center = ops.single.$1 as Rect;
        final w = ops.single.$2.strokeWidth;
        expect(w, 3);
        expect(center.left - w / 2, fracBox.left);
        expect(center.top - w / 2, fracBox.top);
        expect(center.right + w / 2, fracBox.right);
        expect(center.bottom + w / 2, fracBox.bottom);
      });

      test('整数盒对照：外缘贴盒', () {
        const box = Rect.fromLTWH(0, 0, 260, 100);
        final ops = recordBorderPaints(
          rect: box,
          border: ElBorder.all(borderWidth: 3, borderColor: borderBlue),
          borderRadius: null,
        )!;
        final center = ops.single.$1 as Rect;
        final w = ops.single.$2.strokeWidth;
        expect(center.left - w / 2, 0);
        expect(center.top - w / 2, 0);
        expect(center.right + w / 2, 260);
        expect(center.bottom + w / 2, 100);
      });
    });

    group('边框绘制：分数盒描边覆盖到盒边', () {
      test('3px + 圆角 10：stroke 外接（含半宽）贴盒', () {
        final ops = recordBorderPaints(
          rect: fracBox,
          border: ElBorder.all(borderWidth: 3, borderColor: borderBlue),
          borderRadius: BorderRadius.circular(10),
        )!;
        final stroke = ops.single.$1 as RRect;
        final w = ops.single.$2.strokeWidth;
        final covered = stroke.outerRect.inflate(w / 2);
        expect(covered.right, closeTo(fracBox.right, 1e-9));
        expect(covered.bottom, closeTo(fracBox.bottom, 1e-9));
      });
    });

    group('像素级：分数尺寸白底卡外缘为边框色', () {
      const pixelRatio = 4.0;

      Future<({ui.Image image, ByteData bytes})> rasterize(WidgetTester tester) async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
        late final ui.Image image;
        await tester.runAsync(() async {
          image = await boundary.toImage(pixelRatio: pixelRatio);
        });
        late final ByteData bytes;
        await tester.runAsync(() async {
          bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        });
        return (image: image, bytes: bytes);
      }

      Color pixelAt(({ui.Image image, ByteData bytes}) raster, int x, int y) {
        final offset = (y * raster.image.width + x) * 4;
        final d = raster.bytes;
        return Color.fromARGB(
          d.getUint8(offset + 3),
          d.getUint8(offset),
          d.getUint8(offset + 1),
          d.getUint8(offset + 2),
        );
      }

      int colorDistanceSq(Color a, Color b) {
        int ch(double x) => (x * 255).round();
        final dr = ch(a.r) - ch(b.r), dg = ch(a.g) - ch(b.g), db = ch(a.b) - ch(b.b);
        return dr * dr + dg * dg + db * db;
      }

      bool closerTo(Color sample, Color target, Color other) =>
          colorDistanceSq(sample, target) < colorDistanceSq(sample, other);

      testWidgets('分数尺寸白底卡：底/右外缘内侧半像素更近蓝边', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: Size(800, 600), devicePixelRatio: 1),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RepaintBoundary(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ElView(
                    key: cardKey,
                    style: ElStyle(
                      width: 260.5,
                      height: 100.5,
                      backgroundColor: bgWhite,
                      borderRadius: BorderRadius.all(Radius.elliptical(10, 10)),
                      border: .all(borderColor: borderBlue, borderWidth: 3),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
        final card = tester.renderObject<RenderBox>(find.byKey(cardKey));
        final topLeft = card.localToGlobal(Offset.zero, ancestor: boundary);
        final raster = await rasterize(tester);

        // 贴外缘向内 0.25 逻辑像素（描边带宽内），应是蓝而非白。
        final midX = ((topLeft.dx + card.size.width / 2) * pixelRatio).round();
        final midY = ((topLeft.dy + card.size.height / 2) * pixelRatio).round();
        final yNearBottom = ((topLeft.dy + card.size.height - 0.25) * pixelRatio).round();
        final xNearRight = ((topLeft.dx + card.size.width - 0.25) * pixelRatio).round();

        expect(closerTo(pixelAt(raster, midX, yNearBottom), borderBlue, bgWhite), isTrue);
        expect(closerTo(pixelAt(raster, xNearRight, midY), borderBlue, bgWhite), isTrue);
      });
    });
  });

  group('边框不参与布局', () {
    ElRenderView findRv(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    group('border 仅绘制 —— 布局零参与', () {
      testWidgets('onTap 边框 1px→4px：performLayout 零增量 + 兄弟/子偏移与 size 全部不变', (tester) async {
        const target = Key('t31-target');
        const child = Key('t31-child');
        const sibling = Key('t31-sibling');
        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElView(
                    key: target,
                    style: const ElStyle(
                      padding: .all(8),
                      border: .fromSide(ElBorderSide(borderColor: Color(0xFF3B82F6), borderWidth: 1)),
                      onTap: ElStyle(border: .fromSide(ElBorderSide(borderColor: Color(0xFF3B82F6), borderWidth: 4))),
                    ),
                    child: const ElView(key: child, style: ElStyle(width: 80, height: 30)),
                  ),
                  const ElView(key: sibling, style: ElStyle(width: 60, height: 20)),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rv = findRv(tester, target);
        final sizeBefore = rv.size;
        final boxSizeBefore = rv.boxSize;
        final childOffsetBefore = tester.getTopLeft(find.byKey(child));
        final siblingOffsetBefore = tester.getTopLeft(find.byKey(sibling));

        BenchmarkProbe.reset();
        rv.setTap(true);
        await tester.pump();

        // 变体确实生效（先证明不是"没触发"）
        expect(rv.committedResolvedStyle.box.border!.borderTop.borderWidth, 4, reason: 'onTap 变体应已 cascade 到 committed');
        // 布局零参与
        expect(BenchmarkProbe.performLayoutCount, 0, reason: 'border 变粗是 paint-only damage，禁止任何 performLayout');
        expect(rv.size, sizeBefore, reason: '自身 size 不变');
        expect(rv.boxSize, boxSizeBefore, reason: '视觉盒 size 不变');
        expect(tester.getTopLeft(find.byKey(child)), childOffsetBefore, reason: '子偏移不许平移');
        expect(tester.getTopLeft(find.byKey(sibling)), siblingOffsetBefore, reason: '兄弟不许平移');
      });

      testWidgets('getDryLayout 与实际 layout 一致且都不含 border', (tester) async {
        const target = Key('t31-dry');
        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: ElView(
                key: target,
                style: const ElStyle(padding: .all(10), border: .fromSide(ElBorderSide(borderWidth: 6))),
                child: const SizedBox(width: 80, height: 30),
              ),
            ),
          ),
        );
        final rv = findRv(tester, target);
        // padding 10×2 + child 80×30 = 内容 100×50；width:auto 撑满父 max；border 不占
        expect(rv.size.height, 50);
        expect(rv.size.width, greaterThanOrEqualTo(100));
        final dry = rv.getDryLayout(const BoxConstraints(maxWidth: 800, maxHeight: 600));
        expect(dry, rv.size, reason: 'dry layout 与实际一致，都不含 border');
      });
    });
  });

  group('盒绘制', () {
    const bgBlue = Color(0xFF2196F3);

    const borderBlack = Color(0xFF000000);

    const shadowGrey = Color(0xFF9E9E9E);

    testWidgets('九步顺序：shadow → bg → gradient → border（radius 形态，按 color 锁序）', (tester) async {
      await tester.pumpWidget(
        _viewport(
          ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              backgroundColor: bgBlue,
              borderRadius: const .all(Radius.circular(8)),
              border: .all(borderColor: borderBlack, borderWidth: 2),
              boxShadow: const [BoxShadow(color: shadowGrey, blurRadius: 4)],
              gradient: const LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF00FF00)]),
            ),
          ),
        ),
      );
      expect(
        find.byType(ElView),
        paints
          // 1. shadow（测试环境 debugDisableShadows 清空 maskFilter，按 color 锁）
          ..rrect(color: shadowGrey)
          // 2. bg 最底
          ..rrect(color: bgBlue)
          // 4. gradient（shader 填充，在 bg 之上）
          ..rrect(style: PaintingStyle.fill)
          // 8. border（uniform → 单笔 stroke）
          ..rrect(color: borderBlack, style: PaintingStyle.stroke, strokeWidth: 2),
      );
    });

    testWidgets('clipBehavior 裁 children 不裁 border：bg → clipRRect → border', (tester) async {
      await tester.pumpWidget(
        _viewport(
          ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              backgroundColor: bgBlue,
              borderRadius: const .all(Radius.circular(8)),
              border: .all(borderColor: borderBlack, borderWidth: 2),
              clipBehavior: Clip.antiAlias,
            ),
          ),
        ),
      );
      final content = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 60), const Radius.circular(8));
      expect(
        find.byType(ElView),
        paints
          ..rrect(rrect: content, color: bgBlue)
          ..clipRRect(rrect: content)
          // border 在 clip restore 之后（CSS spec：border 不被 overflow clip 裁）
          ..rrect(color: borderBlack, style: PaintingStyle.stroke),
      );
    });

    testWidgets('无 radius：bg 与 uniform border 都是 rect op（矩形不再借道零圆角 rrect）', (tester) async {
      await tester.pumpWidget(
        _viewport(
          ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              backgroundColor: bgBlue,
              border: .all(borderColor: borderBlack, borderWidth: 2),
            ),
          ),
        ),
      );
      expect(
        find.byType(ElView),
        paints
          ..rect(rect: const Rect.fromLTWH(0, 0, 100, 60), color: bgBlue)
          // border inside 摆位（2026-07-16 裁决）：中心线 = 盒边缘内移 w/2=1。
          ..rect(
            rect: const Rect.fromLTRB(1, 1, 99, 59),
            color: borderBlack,
            style: PaintingStyle.stroke,
            strokeWidth: 2,
          ),
      );
    });

    testWidgets('uniform border inside 位置几何：中心线 rrect = 盒内移 w/2、弧半径同心内缩', (tester) async {
      await tester.pumpWidget(
        _viewport(
          ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              borderRadius: const .all(Radius.circular(8)),
              border: .all(borderColor: borderBlack, borderWidth: 2),
            ),
          ),
        ),
      );
      expect(
        find.byType(ElView),
        paints
          // inside 摆位（2026-07-16 裁决）：外缘贴盒边缘，中心线内移 w/2=1，
          // 弧半径 8-1=7（描边外弧与盒圆角重合）。
          ..rrect(
            rrect: RRect.fromRectAndRadius(const Rect.fromLTRB(1, 1, 99, 59), const Radius.circular(7)),
            color: borderBlack,
            style: PaintingStyle.stroke,
            strokeWidth: 2,
          ),
      );
    });

    testWidgets('shadow 偏移 + spread 精确几何（plan 预构建 RRect 与 CSS 语义一致）', (tester) async {
      await tester.pumpWidget(
        _viewport(
          ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              backgroundColor: bgBlue,
              borderRadius: const .all(Radius.circular(8)),
              boxShadow: const [BoxShadow(color: shadowGrey, offset: Offset(2, 3), blurRadius: 4, spreadRadius: 5)],
            ),
          ),
        ),
      );
      // 沿 content RRect shift(2,3) 再 spread 膨胀 5：角半径同步 +5。
      expect(
        find.byType(ElView),
        paints
          ..rrect(
            rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(-3, -2, 110, 70), const Radius.circular(13)),
            color: shadowGrey,
          )
          ..rrect(color: bgBlue),
      );
    });
  });

  group('内阴影', () {
    test('copy, scale, and lerp preserve inset metadata', () {
      const inset = ElBoxShadow(
        color: Color(0xff102030),
        offset: Offset(2, 4),
        blurRadius: 8,
        spreadRadius: 3,
        inset: true,
      );

      expect(inset.copyWith(color: Colors.white).inset, isTrue);
      expect(inset.scale(0.5).inset, isTrue);

      final faded = ElBoxShadow.lerpList(const [inset], null, 0.5)!.single as ElBoxShadow;
      expect(faded.inset, isTrue);

      final switched = ElBoxShadow.lerp(inset, const BoxShadow(), 0.75) as ElBoxShadow;
      expect(switched.inset, isFalse);
    });

    testWidgets('inset shadow is clipped inside the box after its background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElView(
                style: ElStyle(
                  width: 80,
                  height: 60,
                  backgroundColor: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  boxShadow: [ElBoxShadow(color: Colors.black, offset: Offset(0, 4), inset: true)],
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byType(ElView),
        paints
          ..rrect(color: Colors.white)
          ..save()
          ..clipRRect()
          ..path(color: Colors.black)
          ..restore(),
      );
    });

    test('多条内阴影共用裁剪且保持声明顺序，外阴影通道互不混入', () {
      final bounds = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 80, 60), Radius.circular(8));
      final shadows = [
        BoxShadow(color: Colors.green),
        ElBoxShadow(color: Colors.red, inset: true),
        ElBoxShadow(color: Colors.blue, inset: true),
      ];
      final canvas = TestRecordingCanvas();
      ViewBoxPainter.paintShadows(canvas, outerRRect: bounds, shadows: shadows, inset: true);
      expect(canvas.invocations.map((call) => call.invocation.memberName), [
        #save,
        #clipRRect,
        #drawPath,
        #drawPath,
        #restore,
      ]);
      expect(canvas.getSaveCount(), 0);
      expect(
        canvas.invocations
            .where((call) => call.invocation.memberName == #drawPath)
            .map((call) => (call.invocation.positionalArguments[1] as Paint).color),
        [isSameColorAs(Colors.red), isSameColorAs(Colors.blue)],
      );
      final outer = TestRecordingCanvas();
      ViewBoxPainter.paintShadows(outer, outerRRect: bounds, shadows: shadows, inset: false);
      expect(outer.invocations.map((call) => call.invocation.memberName), [#drawRRect]);
    });

    test('没有内阴影时不保存或裁剪 Canvas', () {
      final canvas = TestRecordingCanvas();
      ViewBoxPainter.paintShadows(
        canvas,
        outerRRect: RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 80, 60), Radius.circular(8)),
        shadows: [BoxShadow(color: Colors.green)],
        inset: true,
      );
      expect(canvas.invocations, isEmpty);
    });

    test('inset shadow 实际绘制挖洞 Path', () {
      final ops = recordInsetShadowPaints(
        outerRRect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 80, 60), const Radius.circular(8)),
        shadows: const [ElBoxShadow(color: Colors.black, offset: Offset(-1, -1), inset: true)],
      );

      expect(ops, hasLength(1));
      expect(ops.single.$1, isA<Path>());
      expect(ops.single.$1.fillType, PathFillType.evenOdd);
      expect(ops.single.$1.getBounds(), const Rect.fromLTRB(-2, -2, 81, 61));
    });
  });

  group('附加视觉效果绘制', () {
    const outlinePurple = Color(0xFF9C27B0);

    const borderBlack = Color(0xFF000000);

    testWidgets('outline outside + offset：无 radius 精确 stroke 矩形', (tester) async {
      await tester.pumpWidget(
        _viewport(
          const ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              backgroundColor: Color(0xFF2196F3),
              outline: ElOutline(outlineColor: outlinePurple, outlineWidth: 2, outlineOffset: 3),
            ),
          ),
        ),
      );
      // outside → 外推 width(2)，再外推 offset(3)，stroke 中心线 deflate(w/2)：
      // (0,0,100,60) → (-2,-2,102,62) → (-5,-5,105,65) → (-4,-4,104,64)。
      expect(
        find.byType(ElView),
        paints
          ..rect(rect: const Rect.fromLTWH(0, 0, 100, 60))
          ..rect(
            rect: const Rect.fromLTRB(-4, -4, 104, 64),
            color: outlinePurple,
            style: PaintingStyle.stroke,
            strokeWidth: 2,
          ),
      );
    });

    testWidgets('gradient 描边 outline：shader stroke（覆盖纯色）', (tester) async {
      await tester.pumpWidget(
        _viewport(
          const ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              outline: ElOutline(
                outlineColor: outlinePurple,
                outlineWidth: 2,
                gradient: LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF00FF00)]),
              ),
            ),
          ),
        ),
      );
      // shader 覆盖 color：断言 stroke op 存在且未落纯色通道。
      expect(find.byType(ElView), paints..rect(style: PaintingStyle.stroke, strokeWidth: 2));
    });

    testWidgets('堆叠顺序：border 先于 outline（radius 形态）', (tester) async {
      await tester.pumpWidget(
        _viewport(
          ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              borderRadius: const .all(Radius.circular(8)),
              border: .all(borderColor: borderBlack, borderWidth: 2),
              outline: const ElOutline(outlineColor: outlinePurple, outlineWidth: 2),
            ),
          ),
        ),
      );
      expect(
        find.byType(ElView),
        paints
          ..rrect(color: borderBlack, style: PaintingStyle.stroke)
          ..rrect(color: outlinePurple, style: PaintingStyle.stroke),
      );
    });
  });

  group('失效路由', () {
    group('damage 通道路由', () {
      test('layout 字段（width）：markNeedsLayout 1 次，paint 0 次', () {
        final host = _MarkRecordingBox();
        DamageRouter.route(
          host: host,
          changedMask: fieldsMask({ElTransitionField.width}),
          inheritableHost: _InheritStub(),
        );
        expect(host.layoutCalls, 1);
        expect(host.paintCalls, 0);
      });

      test('paint-only 字段（backgroundColor）：markNeedsPaint 1 次，layout 0 次', () {
        final host = _MarkRecordingBox();
        DamageRouter.route(
          host: host,
          changedMask: fieldsMask({ElTransitionField.backgroundColor}),
          inheritableHost: _InheritStub(),
        );
        expect(host.paintCalls, 1);
        expect(host.layoutCalls, 0);
      });

      test('layout + paint 同时（如 border、overflow）：两个通道都各 mark 一次', () {
        final host = _MarkRecordingBox();
        DamageRouter.route(
          host: host,
          changedMask: fieldsMask({ElTransitionField.textOverflow}), // overflow = layout + paint
          inheritableHost: _InheritStub(),
        );
        // DamageRouter 现在使用独立 if：layout 和 paint 分别 mark；Flutter 自己合并。
        // 这样 layout 字段同时携带 paint-only 通道时也不会漏 mark。
        expect(host.layoutCalls, 1);
        expect(host.paintCalls, 1);
      });

      test('cursor（inherit-only，无 layout / paint）：两者都 0', () {
        final host = _MarkRecordingBox();
        DamageRouter.route(
          host: host,
          changedMask: fieldsMask({ElTransitionField.cursor}),
          inheritableHost: _InheritStub(),
        );
        expect(host.layoutCalls, 0);
        expect(host.paintCalls, 0, reason: 'cursor 只走 inherit 不动 RenderObject');
      });

      test('多个字段混合（width + backgroundColor）：两通道各 mark 一次', () {
        final host = _MarkRecordingBox();
        DamageRouter.route(
          host: host,
          changedMask: fieldsMask({ElTransitionField.width, ElTransitionField.backgroundColor}),
          inheritableHost: _InheritStub(),
        );
        // 独立 if：width 触发 layout，backgroundColor 触发 paint —— 不互斥，让 Flutter 合并。
        expect(host.layoutCalls, 1);
        expect(host.paintCalls, 1);
      });

      test('空 changedFields：什么都不做', () {
        final host = _MarkRecordingBox();
        DamageRouter.route(host: host, changedMask: fieldsMask({}), inheritableHost: _InheritStub());
        expect(host.layoutCalls, 0);
        expect(host.paintCalls, 0);
      });
    });

    group('继承传播', () {
      test('inherit 字段（color）：propagate 触发 child.reresolveFromInheritance', () {
        final host = _MarkRecordingBox();
        final child = _InheritStub();
        final parent = _InheritStub(children: [child]);
        DamageRouter.route(host: host, changedMask: fieldsMask({ElTransitionField.color}), inheritableHost: parent);
        // child 应被 reresolveFromInheritance 调用 1 次，含 color
        expect(child.reresolveCalls, hasLength(1));
        expect(child.reresolveCalls[0], contains(ElTransitionField.color));
      });

      test('非 inherit 字段（width）：propagate 不被触发', () {
        final host = _MarkRecordingBox();
        final child = _InheritStub();
        final parent = _InheritStub(children: [child]);
        DamageRouter.route(host: host, changedMask: fieldsMask({ElTransitionField.width}), inheritableHost: parent);
        expect(child.reresolveCalls, isEmpty, reason: 'width 非 inherit 字段，不应触发 propagate');
      });

      test('只 inherit 字段 + paint-only damage：propagate + markNeedsPaint', () {
        // color = inherit + paint
        final host = _MarkRecordingBox();
        final child = _InheritStub();
        final parent = _InheritStub(children: [child]);
        DamageRouter.route(host: host, changedMask: fieldsMask({ElTransitionField.color}), inheritableHost: parent);
        expect(host.paintCalls, 1);
        expect(host.layoutCalls, 0);
        expect(child.reresolveCalls, hasLength(1));
      });

      test('theme mask 只携带 inherit 变化位，并原样传到整条继承链', () {
        final host = _MarkRecordingBox();
        final grandchild = _InheritStub();
        final child = _InheritStub(children: [grandchild]);
        final parent = _InheritStub(children: [child]);
        final colorBit = maskBit(ElTransitionField.color.index);
        final widthBit = maskBit(ElTransitionField.width.index);

        DamageRouter.route(
          host: host,
          changedMask: fieldsMask({ElTransitionField.color, ElTransitionField.width}),
          inheritableHost: parent,
          themeAnimationMask: maskOr(colorBit, widthBit),
        );

        expect(child.themeAnimationMaskCalls, [colorBit]);
        expect(grandchild.themeAnimationMaskCalls, [colorBit]);
      });

      test('active 变体仍更新本节点 parent，但截断的 theme 字段不再送到孙节点', () {
        final host = _MarkRecordingBox();
        final grandchild = _InheritStub();
        final colorBit = maskBit(ElTransitionField.color.index);
        final child = _InheritStub(children: [grandchild], themeMaskToBlock: colorBit);
        final parent = _InheritStub(children: [child]);

        DamageRouter.route(
          host: host,
          changedMask: fieldsMask({ElTransitionField.color}),
          inheritableHost: parent,
          themeAnimationMask: colorBit,
        );

        expect(child.reresolveCalls.single, {ElTransitionField.color});
        expect(child.themeAnimationMaskCalls, [colorBit]);
        expect(grandchild.reresolveCalls, isEmpty);
        expect(grandchild.themeAnimationMaskCalls, isEmpty);
      });

      test('active 变体按字段部分截断，同批未占用 theme 字段继续传播', () {
        final host = _MarkRecordingBox();
        final grandchild = _InheritStub();
        final colorBit = maskBit(ElTransitionField.color.index);
        final cursorBit = maskBit(ElTransitionField.cursor.index);
        final child = _InheritStub(children: [grandchild], themeMaskToBlock: colorBit);
        final parent = _InheritStub(children: [child]);

        DamageRouter.route(
          host: host,
          changedMask: fieldsMask({ElTransitionField.color, ElTransitionField.cursor}),
          inheritableHost: parent,
          themeAnimationMask: maskOr(colorBit, cursorBit),
        );

        expect(child.reresolveCalls.single, {ElTransitionField.color, ElTransitionField.cursor});
        expect(child.themeAnimationMaskCalls, [maskOr(colorBit, cursorBit)]);
        expect(grandchild.reresolveCalls.single, {ElTransitionField.cursor});
        expect(grandchild.themeAnimationMaskCalls, [cursorBit]);
      });
    });
  });

  group('溢出命中边界', () {
    testWidgets('transform 子溢出父盒：溢出区可点、父自身区域外父不吞命中', (tester) async {
      var childTaps = 0;
      var parentTaps = 0;
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 100, height: 100, backgroundColor: Color(0xFFEEEEEE)),
            event: ElEvent(onTap: (_) => parentTaps++),
            child: ElView(
              style: const ElStyle(width: 60, height: 60, transform: .translate(80, 80), backgroundColor: Color(0xFF2196F3)),
              event: ElEvent(onTap: (_) => childTaps++),
            ),
          ),
        ),
      );

      // 溢出区（父盒外、子盒内）：child 命中。
      await tester.tapAt(const Offset(120, 120));
      await tester.pump();
      expect(childTaps, 1, reason: '溢出区必须命中 transform 子');

      // 父盒内、子盒内重叠区照常命中子。
      await tester.tapAt(const Offset(90, 90));
      await tester.pump();
      expect(childTaps, 2);

      // 溢出边界外（既不在父也不在子）：都不命中。
      final parentTapsBefore = parentTaps;
      await tester.tapAt(const Offset(160, 40));
      await tester.pump();
      expect(childTaps, 2);
      expect(parentTaps, parentTapsBefore, reason: '溢出边界外父不得吞命中');
    });

    testWidgets('transform translate 全移出父盒：视觉位置可点、原布局位置不可点', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 100, height: 100),
            child: ElView(
              style: const ElStyle(width: 40, height: 40, transform: .translate(120, 120), backgroundColor: Color(0xFF4CAF50)),
              event: ElEvent(onTap: (_) => taps++),
            ),
          ),
        ),
      );

      // 视觉位置（120..160）命中。
      await tester.tapAt(const Offset(140, 140));
      await tester.pump();
      expect(taps, 1, reason: 'transform 位移后的视觉位置必须命中');

      // 原布局位置（0..40）不命中（反变换精确性不变）。
      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(taps, 1, reason: '移走后的原布局位置不得命中');
    });

    testWidgets('rotate 45°：视觉菱形内命中、AABB 空角不命中', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 30, height: 30),
            child: ElView(
              // 子被父 30×30 紧约束钳成 30×30（现行布局语义），绕中心 (15,15)
              // 旋转 45°：半对角线 15√2≈21.2，菱形 |dx|+|dy|≤21.2，
              // AABB (-6.2..36.2)²——下顶点 (15,36.2) 溢出父盒。
              style: ElStyle(width: 30, height: 30, transform: .rotate(math.pi / 4), backgroundColor: const Color(0xFFFF9800)),
              event: ElEvent(onTap: (_) => taps++),
            ),
          ),
        ),
      );

      // 旋转后中心不动：中心恒命中。
      await tester.tapAt(const Offset(15, 15));
      await tester.pump();
      expect(taps, 1);

      // 菱形下顶点附近（|dx|+|dy| = 18 < 21.2，y=33 已出父盒）：命中。
      await tester.tapAt(const Offset(15, 33));
      await tester.pump();
      expect(taps, 2, reason: '旋转后视觉形状内（父盒外）必须命中');

      // AABB 空角（|dx|+|dy| = 38 > 21.2，仍在 AABB 36.2 内）：不命中。
      await tester.tapAt(const Offset(34, 34));
      await tester.pump();
      expect(taps, 2, reason: 'AABB 空角不得命中（反变换精确性）');
    });

    testWidgets('裁剪封口：clipBehavior 祖先外溢出区不可点', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 100, height: 100, clipBehavior: Clip.hardEdge, backgroundColor: Color(0xFFEEEEEE)),
            child: ElView(
              style: const ElStyle(width: 60, height: 60, transform: .translate(80, 80), backgroundColor: Color(0xFF2196F3)),
              event: ElEvent(onTap: (_) => taps++),
            ),
          ),
        ),
      );

      // 裁剪内的重叠区照常命中。
      await tester.tapAt(const Offset(90, 90));
      await tester.pump();
      expect(taps, 1);

      // 裁剪外的溢出区：画不出来也点不到。
      await tester.tapAt(const Offset(120, 120));
      await tester.pump();
      expect(taps, 1, reason: '裁剪节点封口，溢出区不得命中');
    });

    testWidgets('多级溢出传播：孙溢出穿两层无溢出父仍可点', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 60, height: 60),
            child: ElView(
              style: const ElStyle(width: 60, height: 60),
              child: ElView(
                style: const ElStyle(
                  width: 40,
                  height: 40,
                  transform: .translate(100, 100),
                  backgroundColor: Color(0xFF9C27B0),
                ),
                event: ElEvent(onTap: (_) => taps++),
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(120, 120));
      await tester.pump();
      expect(taps, 1, reason: '孙溢出边界必须逐级聚合到最外层');
    });

    testWidgets('鼠标 hover：溢出区 onHover 生效', (tester) async {
      var hovered = false;
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 100, height: 100),
            child: ElView(
              style: const ElStyle(width: 60, height: 60, transform: .translate(80, 80), backgroundColor: Color(0xFF2196F3)),
              event: ElEvent(onPointerEnter: (e) => hovered = true),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: const Offset(200, 200));
      await tester.pump();
      await gesture.moveTo(const Offset(120, 120));
      await tester.pump();
      expect(hovered, isTrue, reason: '溢出区 hover 必须触发');
    });

    testWidgets('无溢出树零开销探针：hitBounds 缓存为自身盒短路', (tester) async {
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 100, height: 100),
            child: ElView(style: const ElStyle(width: 50, height: 50, backgroundColor: Color(0xFF000000))),
          ),
        ),
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      for (final render in tester.allRenderObjects.whereType<ElRenderView>()) {
        expect(render.hasHitBoundsOverflow, isFalse, reason: '无溢出树不得出现聚合扩张');
      }
    });

    testWidgets('transform 动画中途：命中边界逐帧跟随插值位置（paint-only dirty 传播）', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 50, height: 50),
            child: ElView(
              key: const ValueKey('animated'),
              style: const ElStyle(
                width: 40,
                height: 40,
                transform: .translate(0, 0),
                transition: [ElTransition.all(Duration(milliseconds: 300))],
                backgroundColor: Color(0xFF4CAF50),
                onHover: ElStyle(transform: .translate(200, 200)),
              ),
              event: ElEvent(onTap: (_) => taps++),
            ),
          ),
        ),
      );
      await tester.pump();

      final render = tester.renderObject<ElRenderView>(find.byKey(const ValueKey('animated')));
      // 预热 bounds 缓存：动画前全树聚合一遍。没有 DamageRouter 的 paint-only
      // 失效钩子时，动画期不 relayout、缓存恒陈旧 → 后续溢出 tap 必 miss；
      // 本预热保证测试锁的是 dirty 传播而非首次懒计算。
      for (final r in tester.allRenderObjects.whereType<ElRenderView>()) {
        r.hitBoundsPre;
      }
      render.setHover(true);
      await tester.pump();
      // 动画中途（150/300ms）：取子当前视觉中心。节点自身 transform 由节点内部
      // 应用（localToGlobal 不含），先经 hitBoundsTransform 映射再走祖先链；
      // 命中新鲜性的独立证据是 tapAt 真实派发命中。
      await tester.pump(const Duration(milliseconds: 150));
      final selfTransform = render.hitBoundsTransform;
      final mapped = selfTransform == null
          ? const Offset(20, 20)
          : MatrixUtils.transformPoint(selfTransform, const Offset(20, 20));
      final visualCenter = render.localToGlobal(mapped);
      // 前置：中途位置必须已溢出父盒（50×50），否则没测到溢出剪枝。
      expect(visualCenter.dx, greaterThan(50), reason: '前置：动画中途子已移出父盒');
      await tester.tapAt(visualCenter);
      await tester.pump();
      expect(taps, 1, reason: '动画中途视觉位置必须命中（bounds 逐帧新鲜）');

      // 泵到动画结束：终点命中、中途旧位置不命中。
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(220, 220));
      await tester.pump();
      expect(taps, 2, reason: '动画终点位置必须命中');
      await tester.tapAt(visualCenter - const Offset(30, 30));
      await tester.pump();
      expect(taps, 2, reason: '动画结束后中途位置不得残留命中');
    });

    testWidgets('ElView 富文本 inline atomic transform 溢出：视觉位置可点', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _hitOverflowBoundsApp(
          ElView(
            style: const ElStyle(width: 200, height: 60),
            child: ElView(
              child: [
                'prefix ',
                ElView(
                  style: const ElStyle(width: 30, height: 16, transform: .translate(0, 80), backgroundColor: Color(0xFFE91E63)),
                  event: ElEvent(onTap: (_) => taps++),
                ),
                ' suffix',
              ],
            ),
          ),
        ),
      );

      // atomic 视觉位置：inline 布局位 x≈prefix 宽度、y + 80 → 出 ElView 盒。
      final atomic = tester.allRenderObjects.whereType<ElRenderView>().firstWhere(
        (r) => r.size.width == 30 && r.size.height == 16,
      );
      final origin = atomic.localToGlobal(Offset.zero);
      await tester.tapAt(origin + const Offset(15, 80 + 8));
      await tester.pump();
      expect(taps, 1, reason: 'ElView atomic transform 溢出的视觉位置必须命中');
    });
  });

  group('Render 宿主', () {
    testWidgets('文本载荷经默认构造直喂，裸挂载即渲染', (tester) async {
      await tester.pumpWidget(
        _tree(() => ElRenderView(child: 'Hello', style: const ElStyle(fontSize: 20, lineHeight: 1.0))),
      );

      final label = _label(tester);
      expect(label.hasTextPayload, isTrue);
      final glyphs = label.textEngineForTest!.getBoxesForSelectionForTest(0, 'Hello'.length);
      expect(glyphs.single.toRect().height, 20);
      expect(label.size.width, greaterThan(0));
    });

    testWidgets('暗色随祖先 themeMode 同步，onDark 变体命中', (tester) async {
      const lightBg = Color(0xFF111111);
      const darkBg = Color(0xFFEEEEEE);
      await tester.pumpWidget(
        _tree(
          () => ElRenderView(
            child: 'D',
            style: const ElStyle(
              backgroundColor: lightBg,
              onDark: ElStyle(backgroundColor: darkBg),
            ),
          ),
          themeMode: const ElThemeMode(brightness: Brightness.dark),
        ),
      );

      expect(_label(tester).committedResolvedStyle.box.backgroundColor, darkBg);
    });

    testWidgets('textScaler 未传走 platformDispatcher 现取，显式传则关闭兜底', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _tree(() => ElRenderView(child: 'M', style: const ElStyle(fontSize: 10, lineHeight: 1.0))),
      );
      final scaled = _label(tester);
      expect(scaled.textScaler.scale(10), 20, reason: '兜底现取平台缩放（同 dpr 0 值口径）');
      expect(scaled.textEngineForTest!.getBoxesForSelectionForTest(0, 1).single.toRect().height, 20);

      await tester.pumpWidget(
        _tree(
          () => ElRenderView(
            child: 'M',
            textScaler: TextScaler.noScaling,
            style: const ElStyle(fontSize: 10, lineHeight: 1.0),
          ),
        ),
      );
      expect(_label(tester).textEngineForTest!.getBoxesForSelectionForTest(0, 1).single.toRect().height, 10);
    });

    testWidgets('显式 setter 推送永久关闭兜底，值相等也不得跳过关闭', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _tree(() => ElRenderView(child: 'M', style: const ElStyle(fontSize: 10, lineHeight: 1.0))),
      );
      final label = _label(tester);
      // 兜底态：读到平台 2x。宿主显式推 noScaling——与字段初值相等，但必须关掉兜底
      label.textScaler = TextScaler.noScaling;
      await tester.pump();
      expect(label.textScaler.scale(10), 10);
      expect(label.textEngineForTest!.getBoxesForSelectionForTest(0, 1).single.toRect().height, 10);
    });

    testWidgets('宿主更新走 set style / setTextPayload', (tester) async {
      const a = Color(0xFF123456);
      const b = Color(0xFF654321);
      await tester.pumpWidget(
        _tree(
          () => ElRenderView(
            child: 'x',
            style: const ElStyle(backgroundColor: a, lineHeight: 1.0),
          ),
        ),
      );

      final label = _label(tester);
      expect(label.committedResolvedStyle.box.backgroundColor, a);

      label.style = const ElStyle(backgroundColor: b, lineHeight: 1.0);
      await tester.pump();
      expect(label.committedResolvedStyle.box.backgroundColor, b);

      label.setTextPayload('xyz');
      await tester.pump();
      expect(label.textEngineForTest!.getBoxesForSelectionForTest(0, 3), hasLength(1));
    });

    testWidgets('富文本 InlineSpan 直喂', (tester) async {
      await tester.pumpWidget(
        _tree(
          () => ElRenderView(
            style: const ElStyle(fontSize: 14, lineHeight: 1.0),
            child: const TextSpan(
              text: 'a',
              children: [
                TextSpan(
                  text: 'b',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );

      final label = _label(tester);
      expect(label.hasTextPayload, isTrue);
      // TextSpan 带 children 走 rich-inline 路径（纯字符串快路径探针恒 null）
      expect((label.textEngineForTest?.painterForTest.text), isNotNull);
      expect(label.size.width, greaterThan(0));
    });

    testWidgets('事件照常：tap 回调 + onHover/onTap 变体在宿主形态翻转', (tester) async {
      const base = Color(0xFF409EFF);
      const hover = Color(0xFF79BBFF);
      const active = Color(0xFF337ECC);
      var taps = 0;
      await tester.pumpWidget(
        _tree(
          () => ElRenderView(
            child: 'btn',
            event: ElEvent(onTap: (_) => taps++),
            style: const ElStyle(
              backgroundColor: base,
              lineHeight: 1.0,
              onHover: ElStyle(backgroundColor: hover),
              onTap: ElStyle(backgroundColor: active),
            ),
          ),
        ),
      );
      final label = _label(tester);
      expect(label.committedResolvedStyle.box.backgroundColor, base);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(_HostWidget)));
      await tester.pump();
      expect(label.committedResolvedStyle.box.backgroundColor, hover, reason: 'MouseTrackerAnnotation 悬停命中');

      await gesture.down(tester.getCenter(find.byType(_HostWidget)));
      await tester.pump();
      expect(label.committedResolvedStyle.box.backgroundColor, active, reason: '按压期 onTap（active）变体');

      await gesture.up();
      await tester.pump();
      expect(taps, 1);
      expect(label.committedResolvedStyle.box.backgroundColor, hover, reason: '抬起回悬停态');
    });

    test('门禁：Widget child 在构造现场拒收', () {
      expect(() => ElRenderView(child: const SizedBox()), throwsAssertionError);
    });

    test('门禁：hosted 的 setTextPayload 拒收 Widget，不静默丢弃', () {
      final label = ElRenderView(child: 'ok');
      addTearDown(label.dispose);
      // 构造门禁只守 child 参数；setter 通道此前把 Widget 归一成 null → 按钮静默变空
      expect(() => label.setTextPayload(const SizedBox()), throwsAssertionError);
      expect(
        () => label.setTextPayload(Container(color: const Color(0xFF000000), child: const Text('x'))),
        throwsAssertionError,
      );
      // 拒收不留副作用：原文本载荷仍在
      expect(label.hasTextPayload, isTrue);
    });

    test('门禁深检：嵌套 widget（Iterable 混排项 / WidgetSpan）也在现场拒收', () {
      // 此前只查顶层 is! Widget，这两种会溜进排版、死在 TextPainter 的洞数断言里
      expect(() => ElRenderView(child: ['a', const SizedBox(), 'b']), throwsAssertionError);
      expect(
        () => ElRenderView(
          child: const TextSpan(
            text: 'a',
            children: [WidgetSpan(child: SizedBox())],
          ),
        ),
        throwsAssertionError,
      );

      // setter 通道同一道闸
      final label = ElRenderView(child: 'ok');
      addTearDown(label.dispose);
      expect(() => label.setTextPayload(['x', const SizedBox()]), throwsAssertionError);
      expect(label.hasTextPayload, isTrue, reason: '拒收不留副作用');
    });

    testWidgets('hosted 纯文本混排 Iterable 不触发深检，照常排版', (tester) async {
      await tester.pumpWidget(
        _tree(
          () => ElRenderView(
            style: const ElStyle(fontSize: 14, lineHeight: 1.0),
            child: const [
              'a',
              TextSpan(
                text: 'b',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              'c',
            ],
          ),
        ),
      );

      final label = _label(tester);
      expect(label.hasTextPayload, isTrue);
      expect(label.size.width, greaterThan(0));
    });

    testWidgets('element 路径富文本混排 widget 不受深检误伤', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            // ViewElement 会把混排里的 widget 抽成 placeholders 充气——深检的
            // !_hosted 早退必须放行这条路径
            child: ElView(
              style: ElStyle(fontSize: 14, lineHeight: 1.0),
              child: ['行内', SizedBox(width: 20, height: 10), '混排'],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.renderObject<RenderBox>(find.byType(SizedBox)).size, const Size(20, 10));
    });

    testWidgets('element 路径不受门禁影响：Widget 子照常充气挂载', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ElView(
              style: ElStyle(width: 40, height: 40),
              // ViewElement → setTextPayload(Widget) 合法：归一为 null 表示"不进文本
              // 引擎"，widget 子由 element 正常充气。hosted 的 assert 不得误伤这条路径
              child: SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.renderObject<RenderBox>(find.byType(SizedBox)).size, const Size(20, 20));
    });
  });

  group('内阴影更新', () {
    const bgBlue = Color(0xFF2196F3);

    const borderBlack = Color(0xFF000000);

    const shadowGrey = Color(0xFF9E9E9E);

    testWidgets('boxShadow 移除后 stale inset 不再发射（bg+border 走 plan 管线形态）', (tester) async {
      Widget build({required bool withShadow}) => _viewport(
        ElView(
          style: ElStyle(
            width: 100,
            height: 60,
            backgroundColor: bgBlue,
            border: .all(borderColor: borderBlack, borderWidth: 2),
            boxShadow: withShadow ? const [ElBoxShadow(color: shadowGrey, blurRadius: 4, inset: true)] : null,
          ),
        ),
      );

      await tester.pumpWidget(build(withShadow: true));
      expect(find.byType(ElView), paints..path(color: shadowGrey));

      await tester.pumpWidget(build(withShadow: false));
      expect(find.byType(ElView), isNot(paints..path()));
      expect(
        find.byType(ElView),
        paints
          ..rect(color: bgBlue)
          ..rect(color: borderBlack, style: PaintingStyle.stroke),
      );
    });

    testWidgets('boxShadow 移除后 stale inset 不再发射（bg-only 直发快路径形态）', (tester) async {
      Widget build({required bool withShadow}) => _viewport(
        ElView(
          style: ElStyle(
            width: 100,
            height: 60,
            backgroundColor: bgBlue,
            boxShadow: withShadow ? const [ElBoxShadow(color: shadowGrey, blurRadius: 4, inset: true)] : null,
          ),
        ),
      );

      await tester.pumpWidget(build(withShadow: true));
      expect(find.byType(ElView), paints..path(color: shadowGrey));

      await tester.pumpWidget(build(withShadow: false));
      expect(find.byType(ElView), isNot(paints..path()));
      expect(find.byType(ElView), paints..rect(color: bgBlue));
    });
  });

  group('装饰更新', () {
    ElStyle decorated({Color bg = const Color(0xFF2196F3), double width = 100}) => ElStyle(
      width: width,
      height: 60,
      backgroundColor: bg,
      borderRadius: const .all(Radius.circular(8)),
      border: .all(borderColor: const Color(0xFF000000), borderWidth: 2),
      boxShadow: const [BoxShadow(color: Color(0xFF9E9E9E), blurRadius: 4)],
    );

    testWidgets('稳态重绘保持装饰几何与颜色', (tester) async {
      await tester.pumpWidget(_viewport(ElView(style: decorated())));
      final render = tester.renderObject<ElRenderView>(find.byType(ElView));
      for (var frame = 0; frame < 3; frame++) {
        render.markNeedsPaint();
        await tester.pump();
        expect(
          find.byType(ElView),
          paints
            ..rrect()
            ..rrect(
              rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 60), const Radius.circular(8)),
              color: const Color(0xFF2196F3),
            ),
        );
      }
    });

    testWidgets('背景色变化后几何保持不变', (tester) async {
      await tester.pumpWidget(_viewport(ElView(style: decorated())));

      await tester.pumpWidget(_viewport(ElView(style: decorated(bg: const Color(0xFFFF5722)))));
      // 视觉正确性：首笔 shadow，第二笔 bg 用新色。
      expect(
        find.byType(ElView),
        paints
          ..rrect()
          ..rrect(
            rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 60), const Radius.circular(8)),
            color: const Color(0xFFFF5722),
          ),
      );
    });

    testWidgets('尺寸变化后使用新的绘制几何', (tester) async {
      await tester.pumpWidget(_viewport(ElView(style: decorated())));

      await tester.pumpWidget(_viewport(ElView(style: decorated(width: 120))));
      expect(
        find.byType(ElView),
        paints
          ..rrect()
          ..rrect(
            rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 120, 60), const Radius.circular(8)),
            color: const Color(0xFF2196F3),
          ),
      );
    });
  });

  group('圆角绘制快路径', () {
    testWidgets('L2R：字面量圆角 + backgroundColor → 单 drawRRect 几何正确', (tester) async {
      await tester.pumpWidget(
        _viewport(
          const ElView(
            style: ElStyle(width: 100, height: 60, backgroundColor: Color(0xFF2196F3), borderRadius: .all(Radius.circular(8))),
          ),
        ),
      );
      expect(
        find.byType(ElView),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 60), const Radius.circular(8)),
          color: const Color(0xFF2196F3),
        ),
      );
    });

    testWidgets('非 L2R 形态（+border）：慢路径完整绘制 bg 与 border', (tester) async {
      await tester.pumpWidget(
        _viewport(
          ElView(
            style: ElStyle(
              width: 100,
              height: 60,
              backgroundColor: const Color(0xFF2196F3),
              borderRadius: const .all(Radius.circular(8)),
              border: .all(borderColor: const Color(0xFF000000), borderWidth: 2),
            ),
          ),
        ),
      );
      // bg rrect + border（uniform 圆角 → drawRRect stroke），两笔都在。
      expect(
        find.byType(ElView),
        paints
          ..rrect()
          ..rrect(),
      );
    });
  });

  group('仅绘制失效', () {
    Future<void> pumpStyled(WidgetTester tester, ElStyle style, {Widget? child}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ElView(
              style: style,
              child: child ?? const ElView(child: 'hello'),
            ),
          ),
        ),
      );
    }

    ElRenderView findRender(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView).first);

    group('盒模型 paint-only 字段变化不触发 layout', () {
      testWidgets('backgroundColor 变化：debugLayoutCount 不增', (tester) async {
        await pumpStyled(tester, const ElStyle(width: 200, height: 60, backgroundColor: Color(0xFFFF0000)));
        final box = findRender(tester);
        final layoutsBefore = box.debugLayoutCount;

        await pumpStyled(tester, const ElStyle(width: 200, height: 60, backgroundColor: Color(0xFF00FF00)));
        await tester.pump();

        expect(box.debugLayoutCount, layoutsBefore, reason: 'bgColor 是节点背景 paint-only damage');
        expect(box.committedResolvedStyle.box.backgroundColor, const Color(0xFF00FF00));
      });
    });

    group('IFC 字段（color / textShadow / textBackgroundColor）变化触发子文本 layout', () {
      // 这些字段进 paragraph (TextStyle / cache key)。ElView 自身持文本时，color
      // fastPatch 走 paint-only，painter 在 paint 阶段 lazy refresh 重 build
      // painter.text；layout 不重跑（改进 vs 旧 ElView 分离节点方案）。
      testWidgets('color 变化不触发 layout（paint-only fastPatch）', (tester) async {
        await pumpStyled(tester, const ElStyle(width: 200, height: 60, color: Color(0xFF000000), fontSize: 14));
        final box = findRender(tester);
        final before = box.debugLayoutCount;

        await pumpStyled(tester, const ElStyle(width: 200, height: 60, color: Color(0xFF0000FF), fontSize: 14));
        await tester.pump();

        expect(box.debugLayoutCount, before, reason: 'color 是 paint-only fastPatch，不进 layout');
        expect(
          box.committedResolvedStyle.inheritedText.color,
          const Color(0xFF0000FF),
          reason: 'ElView cascade 到新 color',
        );
      });

      testWidgets('textShadow 变化不触发 layout（paint-only）', (tester) async {
        await pumpStyled(tester, const ElStyle(width: 200, height: 60, color: Color(0xFF000000)));
        final box = findRender(tester);
        final before = box.debugLayoutCount;

        await pumpStyled(
          tester,
          const ElStyle(
            width: 200,
            height: 60,
            color: Color(0xFF000000),
            textShadow: [Shadow(color: Color(0x66000000), offset: Offset(1, 1), blurRadius: 2)],
          ),
        );
        await tester.pump();

        expect(box.debugLayoutCount, before);
      });

      testWidgets('textBackgroundColor 变化不触发 layout（paint-only）', (tester) async {
        await pumpStyled(tester, const ElStyle(width: 200, height: 60, color: Color(0xFF000000)));
        final box = findRender(tester);
        final before = box.debugLayoutCount;

        await pumpStyled(
          tester,
          const ElStyle(width: 200, height: 60, color: Color(0xFF000000), textBackgroundColor: Color(0xFFFFFF00)),
        );
        await tester.pump();

        expect(box.debugLayoutCount, before);
      });
    });

    group('layout-affecting 字段必须触发 layout', () {
      testWidgets('fontSize 变化：触发 performLayout', (tester) async {
        await pumpStyled(tester, const ElStyle(width: 200, height: 60, fontSize: 14));
        final box = findRender(tester);
        final layoutsBefore = box.debugLayoutCount;

        await pumpStyled(tester, const ElStyle(width: 200, height: 60, fontSize: 24));
        await tester.pump();

        expect(box.debugLayoutCount, greaterThan(layoutsBefore), reason: 'fontSize 变化必须重 layout（影响文本 metric）');
      });

      testWidgets('width 变化：触发 performLayout', (tester) async {
        await pumpStyled(tester, const ElStyle(width: 200, height: 60));
        final box = findRender(tester);
        final layoutsBefore = box.debugLayoutCount;

        await pumpStyled(tester, const ElStyle(width: 300, height: 60));
        await tester.pump();

        expect(box.debugLayoutCount, greaterThan(layoutsBefore));
      });

      testWidgets('fontWeight 变化：触发 performLayout', (tester) async {
        await pumpStyled(tester, const ElStyle(width: 200, height: 60, fontWeight: FontWeight.w400));
        final box = findRender(tester);
        final layoutsBefore = box.debugLayoutCount;

        await pumpStyled(tester, const ElStyle(width: 200, height: 60, fontWeight: FontWeight.w700));
        await tester.pump();

        expect(box.debugLayoutCount, greaterThan(layoutsBefore), reason: 'fontWeight 影响字形宽度，必须重 layout');
      });

      testWidgets('overflow=ellipsis 变化：触发 performLayout', (tester) async {
        await pumpStyled(
          tester,
          const ElStyle(width: 100, height: 60, textOverflow: TextOverflow.clip),
          child: const ElView(child: 'this is a long text that may wrap'),
        );
        final box = findRender(tester);
        final layoutsBefore = box.debugLayoutCount;

        await pumpStyled(
          tester,
          const ElStyle(width: 100, height: 60, textOverflow: TextOverflow.ellipsis),
          child: const ElView(child: 'this is a long text that may wrap'),
        );
        await tester.pump();

        expect(box.debugLayoutCount, greaterThan(layoutsBefore), reason: 'overflow 影响 ellipsis layout');
      });
    });

    group('混合变化：含 layout-affecting 即 layout', () {
      testWidgets('color + fontSize 同时变：仍触发 layout（fontSize 决定）', (tester) async {
        await pumpStyled(tester, const ElStyle(width: 200, height: 60, color: Color(0xFF000000), fontSize: 14));
        final box = findRender(tester);
        final layoutsBefore = box.debugLayoutCount;

        await pumpStyled(
          tester,
          const ElStyle(
            width: 200,
            height: 60,
            color: Color(0xFF0000FF),
            fontSize: 24, // layout-affecting
          ),
        );
        await tester.pump();

        expect(box.debugLayoutCount, greaterThan(layoutsBefore));
      });
    });

    group('hover/active 触发变体的 layout 行为', () {
      testWidgets('hover 切换改 color：paint-only fastPatch，不触发 layout', (tester) async {
        await pumpStyled(
          tester,
          const ElStyle(
            width: 200,
            height: 60,
            color: Color(0xFF000000),
            onHover: ElStyle(color: Color(0xFF0000FF)),
          ),
        );
        final box = findRender(tester);
        final before = box.debugLayoutCount;

        box.setHover(true);
        await tester.pump();

        expect(box.debugLayoutCount, before, reason: 'color 是 paint-only fastPatch，hover 切换不 layout');
        expect(box.committedResolvedStyle.inheritedText.color, const Color(0xFF0000FF));

        box.setHover(false);
        await tester.pump();
        expect(box.committedResolvedStyle.inheritedText.color, const Color(0xFF000000));
      });

      testWidgets('active 切换只改 backgroundColor：debugLayoutCount 不增', (tester) async {
        await pumpStyled(
          tester,
          const ElStyle(
            width: 100,
            height: 100,
            backgroundColor: Color(0xFFFF0000),
            onTap: ElStyle(backgroundColor: Color(0xFF0000FF)),
          ),
        );
        final box = findRender(tester);
        final layoutsBefore = box.debugLayoutCount;

        box.setTap(true);
        await tester.pump();

        expect(box.debugLayoutCount, layoutsBefore, reason: 'onTap 仅切 bgColor → 不应触发 performLayout');
        expect(box.committedResolvedStyle.box.backgroundColor, const Color(0xFF0000FF));
      });
    });
  });

  group('绘制形状分类', () {
    testWidgets('稳态重绘：box identity 不变 → 分类零重算', (tester) async {
      await tester.pumpWidget(
        _viewport(
          const ElView(
            style: ElStyle(width: 100, height: 60, backgroundColor: Color(0xFF2196F3), borderRadius: .all(Radius.circular(8))),
          ),
        ),
      );
      final render = tester.renderObject<ElRenderView>(find.byType(ElView));
      final afterFirstPaint = ((render.paintControllerForTest?.paintShapeClassifyCountForTest) ?? 0);
      expect(afterFirstPaint, greaterThanOrEqualTo(1));

      render.markNeedsPaint();
      await tester.pump();
      render.markNeedsPaint();
      await tester.pump();
      expect(
        ((render.paintControllerForTest?.paintShapeClassifyCountForTest) ?? 0),
        afterFirstPaint,
        reason: '纯重绘（box identity 不变）不得重扫字段分类',
      );
    });

    testWidgets('值真变：backgroundColor 翻转 → 分类恰好 +1，rrect 颜色更新', (tester) async {
      Widget build(Color color) => _viewport(
        ElView(
          style: ElStyle(width: 100, height: 60, backgroundColor: color, borderRadius: const .all(Radius.circular(8))),
        ),
      );

      await tester.pumpWidget(build(const Color(0xFF2196F3)));
      final render = tester.renderObject<ElRenderView>(find.byType(ElView));
      final before = ((render.paintControllerForTest?.paintShapeClassifyCountForTest) ?? 0);

      await tester.pumpWidget(build(const Color(0xFFFF5722)));
      expect(
        ((render.paintControllerForTest?.paintShapeClassifyCountForTest) ?? 0),
        before + 1,
        reason: 'box 换新 identity → 重分类一次（且只一次）',
      );
      expect(
        find.byType(ElView),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 60), const Radius.circular(8)),
          color: const Color(0xFFFF5722),
        ),
      );
    });

    testWidgets('形态迁移：L2R → +border 慢路径 → 撤 border 回 L2R，分类逐次更新', (tester) async {
      Widget build({required bool withBorder}) => _viewport(
        ElView(
          style: ElStyle(
            width: 100,
            height: 60,
            backgroundColor: const Color(0xFF2196F3),
            borderRadius: const .all(Radius.circular(8)),
            border: withBorder ? .all(borderColor: const Color(0xFF000000), borderWidth: 2) : null,
          ),
        ),
      );

      await tester.pumpWidget(build(withBorder: false));
      final render = tester.renderObject<ElRenderView>(find.byType(ElView));
      final base = ((render.paintControllerForTest?.paintShapeClassifyCountForTest) ?? 0);

      // 加 border → 慢路径：bg rrect + border rrect 两笔都在。
      await tester.pumpWidget(build(withBorder: true));
      expect(((render.paintControllerForTest?.paintShapeClassifyCountForTest) ?? 0), base + 1);
      expect(
        find.byType(ElView),
        paints
          ..rrect()
          ..rrect(),
      );

      // 撤 border → 回 L2R 快路径：几何与颜色正确。
      await tester.pumpWidget(build(withBorder: false));
      expect(((render.paintControllerForTest?.paintShapeClassifyCountForTest) ?? 0), base + 2);
      expect(
        find.byType(ElView),
        paints..rrect(
          rrect: RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 60), const Radius.circular(8)),
          color: const Color(0xFF2196F3),
        ),
      );
    });
  });

  group('变换命中', () {
    List<ElRenderView> renderViews(WidgetTester tester) =>
        tester.renderObjectList<ElRenderView>(find.byType(ElView)).toList();

    bool hitRender(ElRenderView render, Offset localPosition) {
      final result = BoxHitTestResult();
      render.hitTest(result, position: localPosition);
      return result.path.any((entry) => identical(entry.target, render));
    }

    testWidgets('translate 后命中区域跟随视觉位置', (tester) async {
      var tapped = 0;

      await tester.pumpWidget(
        _app(
          ElView(
            event: ElEvent(onTap: (_) => tapped++),
            style: const ElStyle(width: 40, height: 40, transform: .translate(20, 0), backgroundColor: Color(0xFF00AA00)),
          ),
        ),
      );

      final box = renderViews(tester).single;

      expect(hitRender(box, const Offset(10, 20)), isFalse);
      expect(hitRender(box, const Offset(30, 20)), isTrue);

      await tester.tapAt(box.localToGlobal(const Offset(30, 20)));
      expect(tapped, 1);
    });

    testWidgets('scale 围绕 topLeft 扩展命中区域', (tester) async {
      await tester.pumpWidget(
        _app(
          ElView(
            event: ElEvent(onTap: (_) {}),
            style: const ElStyle(
              width: 40,
              height: 40,
              transform: .scale(2, 2),
              transformOrigin: Alignment.topLeft,
              backgroundColor: Color(0xFF00AA00),
            ),
          ),
        ),
      );

      final box = renderViews(tester).single;

      expect(hitRender(box, const Offset(60, 20)), isTrue);
      expect(hitRender(box, const Offset(85, 20)), isFalse);
    });

    testWidgets('applyPaintTransform 让子节点 global 坐标包含父 transform', (tester) async {
      await tester.pumpWidget(
        _app(
          const ElView(
            style: ElStyle(width: 100, height: 60, transform: .translate(30, 0), transformOrigin: Alignment.topLeft),
            child: ElView(style: ElStyle(width: 20, height: 20, backgroundColor: Color(0xFF00AA00))),
          ),
        ),
      );

      final views = renderViews(tester);
      final parent = views.first;
      final child = views.last;

      final parentOrigin = parent.localToGlobal(Offset.zero);
      expect(child.localToGlobal(Offset.zero), parentOrigin + const Offset(30, 0));
      expect(parent.globalToLocal(child.localToGlobal(const Offset(10, 10))), const Offset(40, 10));
    });

    testWidgets('rotate 90° 后命中区域随视觉旋转', (tester) async {
      // size 40×20，rotate(π/2) 以 topLeft 为原点，视觉上变成
      // (0, 0) → (0, 0), (40, 0) → (0, 40), (0, 20) → (-20, 0), (40, 20) → (-20, 40)
      // 即 visual rect = (-20, 0, 0, 40)
      await tester.pumpWidget(
        _app(
          ElView(
            event: ElEvent(onTap: (_) {}),
            style: ElStyle(
              width: 40,
              height: 20,
              transform: .rotate(math.pi / 2),
              transformOrigin: Alignment.topLeft,
              backgroundColor: const Color(0xFF00AA00),
            ),
          ),
        ),
      );

      final box = renderViews(tester).single;

      // 旋转后 visual 中心约在 (-10, 20)
      expect(hitRender(box, const Offset(-10, 20)), isTrue, reason: '旋转后视觉中心应命中');
      // 旋转前原点 (10, 10) 在 rotate(π/2)+topLeft 下已不在 visual rect 内
      expect(hitRender(box, const Offset(10, 10)), isFalse, reason: '原 base 位置 (10, 10) 不再属视觉');
      // visual rect 外
      expect(hitRender(box, const Offset(-30, 20)), isFalse, reason: 'visual 外不命中');
    });

    testWidgets('嵌套：祖父 scale + 父 translate 复合累计到孙子', (tester) async {
      await tester.pumpWidget(
        _app(
          const ElView(
            // 祖父
            style: ElStyle(width: 200, height: 200, transform: .scale(2), transformOrigin: Alignment.topLeft),
            child: ElView(
              // 父
              style: ElStyle(
                width: 50,
                height: 50,
                transform: .translate(20, 0),
                transformOrigin: Alignment.topLeft,
              ),
              child: ElView(
                // 孙子
                style: ElStyle(width: 10, height: 10, backgroundColor: Color(0xFF00AA00)),
              ),
            ),
          ),
        ),
      );

      final views = renderViews(tester);
      final grandparent = views[0];
      final grandchild = views[2];
      final gpOrigin = grandparent.localToGlobal(Offset.zero);

      // 孙子在父 base 坐标系的 (0, 0)；父 translate(20, 0) 把孙子起点推到 (20, 0)；
      // 祖父 scale(2) topLeft 把孙子起点放大到 (40, 0)。
      expect(
        grandchild.localToGlobal(Offset.zero),
        gpOrigin + const Offset(40, 0),
        reason: '祖父 scale(2) · 父 translate(20, 0) 必须复合到孙子',
      );

      // 孙子内部 (5, 5)：父链应用为 ((5,5) + 父_offset(0,0)) → +父T(20,0) = (25, 5)
      //   → 祖父 S(2) = (50, 10) → +gpOrigin
      expect(
        grandchild.localToGlobal(const Offset(5, 5)),
        gpOrigin + const Offset(50, 10),
        reason: '孙子内部偏移同样应被两级 transform 累积',
      );
    });

    testWidgets('null transform 走快路径：命中等同 base size', (tester) async {
      await tester.pumpWidget(
        _app(
          ElView(
            event: ElEvent(onTap: (_) {}),
            style: const ElStyle(width: 40, height: 40, backgroundColor: Color(0xFF00AA00)),
          ),
        ),
      );
      final box = renderViews(tester).single;
      expect(hitRender(box, const Offset(20, 20)), isTrue);
      expect(hitRender(box, const Offset(41, 20)), isFalse);
    });

    testWidgets('退化矩阵 scale(0, 0) 安全不命中', (tester) async {
      await tester.pumpWidget(
        _app(
          ElView(
            event: ElEvent(onTap: (_) {}),
            style: const ElStyle(
              width: 40,
              height: 40,
              transform: .scale(0, 0),
              transformOrigin: Alignment.topLeft,
              backgroundColor: Color(0xFF00AA00),
            ),
          ),
        ),
      );
      final box = renderViews(tester).single;
      // 退化矩阵投影后所有点都收缩为 origin (0,0)，命中行为按 Flutter 框架约定
      // （invert 失败 → addWithPaintTransform 返回 false）。
      expect(hitRender(box, const Offset(20, 20)), isFalse, reason: '退化矩阵应安全不命中，不抛错');
      expect(hitRender(box, const Offset(0, 0)), isFalse);
    });
  });

  group('变换后的 hover 稳定性', () {
    ElRenderView findRender(WidgetTester tester, Key key) => tester.renderObject<ElRenderView>(find.byKey(key));

    bool hitRender(ElRenderView render, Offset localPosition) {
      final result = BoxHitTestResult();
      render.hitTest(result, position: localPosition);
      return result.path.any((entry) => identical(entry.target, render));
    }

    Future<TestGesture> arm(WidgetTester tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(() => mouse.removePointer());
      await mouse.addPointer(location: const Offset(-100, -100));
      await tester.pump();
      return mouse;
    }

    group('scale up：hover 区域跟随放大', () {
      testWidgets('hover 进入时命中范围扩到 visual 1.5x', (tester) async {
        const key = ValueKey('hover-scale');
        var enterCount = 0;
        var exitCount = 0;
        await tester.pumpWidget(
          _app(
            ElView(
              key: key,
              event: ElEvent(onPointerEnter: (_) => enterCount++, onPointerExit: (_) => exitCount++),
              style: const ElStyle(
                width: 40,
                height: 40,
                backgroundColor: Color(0xFFFFFFFF),
                transformOrigin: Alignment.center,
                onHover: ElStyle(transform: .scale(1.5)),
              ),
            ),
          ),
        );
        await tester.pump();

        final render = findRender(tester, key);

        // 未 hover 时 base 40×40，visual rect = base：(0,0,40,40)
        expect(hitRender(render, const Offset(20, 20)), isTrue, reason: 'base 中心命中');
        expect(hitRender(render, const Offset(45, 20)), isFalse, reason: '未 hover：base 外不命中');

        // hover 进入（指到 base 内）
        final mouse = await arm(tester);
        await mouse.moveTo(const Offset(20, 20));
        await tester.pump();
        await tester.pump();
        expect(enterCount, 1);
        expect(findRender(tester, key).committedResolvedStyle.box.transform, isNotNull, reason: 'hover 后 transform 写入');

        // hover 后 visual rect = scale(1.5) center on 40×40 = (-10, -10, 50, 50)
        // 此时 (45, 20) 在 visual 内，应命中
        expect(hitRender(render, const Offset(45, 20)), isTrue, reason: 'hover 后视觉扩到 1.5x 命中也 1.5x');
        expect(hitRender(render, const Offset(-5, 20)), isTrue, reason: '左侧扩展也命中');
        expect(hitRender(render, const Offset(55, 20)), isFalse, reason: 'visual rect 之外仍不命中');
      });

      testWidgets('hover 中心稳定不振荡：连续 5 帧 enter/exit 计数不变', (tester) async {
        const key = ValueKey('hover-stable');
        var enterCount = 0;
        var exitCount = 0;
        await tester.pumpWidget(
          _app(
            ElView(
              key: key,
              event: ElEvent(onPointerEnter: (_) => enterCount++, onPointerExit: (_) => exitCount++),
              style: const ElStyle(
                width: 40,
                height: 40,
                backgroundColor: Color(0xFFFFFFFF),
                transformOrigin: Alignment.center,
                onHover: ElStyle(transform: .scale(1.5)),
              ),
            ),
          ),
        );
        await tester.pump();

        final mouse = await arm(tester);
        // 鼠标停在 base 中心 (20, 20)，hover 进入 → scale up → 仍在 visual 内
        await mouse.moveTo(const Offset(20, 20));
        await tester.pump();
        await tester.pump();
        expect(enterCount, 1);
        expect(exitCount, 0);

        // 连续 5 帧不动 mouse，验证不会因 cascade tick 振荡
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(enterCount, 1, reason: '中心位置 hover 状态稳定不振荡');
        expect(exitCount, 0);
      });

      testWidgets('hover 后 visual 外退出：scale up 1.5 边缘 (45, 20) 在 visual 内保持 hover；移到 (60, 20) 退出', (tester) async {
        const key = ValueKey('hover-exit');
        var enterCount = 0;
        var exitCount = 0;
        await tester.pumpWidget(
          _app(
            ElView(
              key: key,
              event: ElEvent(onPointerEnter: (_) => enterCount++, onPointerExit: (_) => exitCount++),
              style: const ElStyle(
                width: 40,
                height: 40,
                backgroundColor: Color(0xFFFFFFFF),
                transformOrigin: Alignment.center,
                onHover: ElStyle(transform: .scale(1.5)),
              ),
            ),
          ),
        );
        await tester.pump();

        final mouse = await arm(tester);
        // 进入：base 中心
        await mouse.moveTo(const Offset(20, 20));
        await tester.pump();
        await tester.pump();
        expect(enterCount, 1);

        // 移到 visual 内 base 外 (45, 20) —— 应保持 hover
        await mouse.moveTo(const Offset(45, 20));
        await tester.pump();
        await tester.pump();
        expect(enterCount, 1, reason: 'visual 内 base 外仍 hover，无新 enter');
        expect(exitCount, 0, reason: '不应 exit');

        // 移到 visual 外 (60, 20) —— 应退出
        await mouse.moveTo(const Offset(60, 20));
        await tester.pump();
        await tester.pump();
        expect(exitCount, 1, reason: 'visual 外应触发 exit');
      });
    });

    group('CSS quirk 形状：行为锁定（不修，但显式记录）', () {
      testWidgets('scale down (0.5)：base 内 visual 外的点被反映射 → 退 hover', (tester) async {
        // 此测试不验"稳定"，只验"按 CSS 语义行为"：hover 后命中区域 = visual rect (= base * 0.5)。
        const key = ValueKey('hover-shrink');
        await tester.pumpWidget(
          _app(
            const ElView(
              key: key,
              style: ElStyle(
                width: 40,
                height: 40,
                backgroundColor: Color(0xFFFFFFFF),
                transform: .scale(0.5),
                transformOrigin: Alignment.center,
              ),
            ),
          ),
        );
        await tester.pump();
        final render = findRender(tester, key);

        // visual rect = scale(0.5) center on 40×40 = (10, 10, 30, 30)
        expect(hitRender(render, const Offset(20, 20)), isTrue, reason: 'visual 中心命中');
        expect(hitRender(render, const Offset(15, 20)), isTrue, reason: 'visual 内命中');
        expect(hitRender(render, const Offset(35, 20)), isFalse, reason: '原 base 内 visual 外不命中（CSS 一致）');
      });

      testWidgets('translate hover：visual rect 完全偏移，是 CSS 设计 quirk', (tester) async {
        // 不在 hover state 下测，避免触发已知的 hover-translate 振荡。
        // 仅锁静态行为：translate 后命中跟视觉一致。
        const key = ValueKey('translate-static');
        await tester.pumpWidget(
          _app(
            const ElView(
              key: key,
              style: ElStyle(
                width: 40,
                height: 40,
                backgroundColor: Color(0xFFFFFFFF),
                transform: .translate(50, 0),
                transformOrigin: Alignment.topLeft,
              ),
            ),
          ),
        );
        await tester.pump();
        final render = findRender(tester, key);
        // base = (0,0,40,40)，translate(50,0) → visual = (50,0,90,40)
        expect(hitRender(render, const Offset(20, 20)), isFalse, reason: '原 base 位置不再视觉占有');
        expect(hitRender(render, const Offset(70, 20)), isTrue, reason: '视觉位置正确命中');
      });
    });
  });
}
