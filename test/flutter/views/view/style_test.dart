import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Codec;
import 'dart:ui' show ImageFilter;

import 'package:flutter_base/src/flutter/views/view/style/resolved/builder.dart';
import 'package:flutter_base/src/flutter/utils/internal/bit_mask.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _semanticsFreeApp(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: ExcludeSemantics(child: child)),
  ),
);

class _FakeImageProvider extends ImageProvider<_FakeImageProvider> {
  const _FakeImageProvider();
  @override
  Future<_FakeImageProvider> obtainKey(ImageConfiguration configuration) async {
    return this;
  }

  @override
  ImageStreamCompleter loadImage(_FakeImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: Completer<Codec>().future, // 永远 pending
      scale: 1,
    );
  }
}

class _OvalClipper extends CustomClipper<Path> {
  const _OvalClipper();
  @override
  Path getClip(Size size) => Path()..addOval(Offset.zero & size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RectClipper extends CustomClipper<Path> {
  const _RectClipper();
  @override
  Path getClip(Size size) => Path()..addRect(Offset.zero & size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TogglingClipper extends CustomClipper<Path> {
  _TogglingClipper() : this._(ChangeNotifier());

  _TogglingClipper._(this.notifier) : super(reclip: notifier);

  bool _showFull = false;
  int clipCount = 0;
  final ChangeNotifier notifier;

  bool get showFull => _showFull;
  set showFull(bool value) {
    if (_showFull == value) return;
    _showFull = value;
    notifier.notifyListeners();
  }

  @override
  Path getClip(Size size) {
    clipCount++;
    final width = _showFull ? size.width : size.width / 2;
    return Path()..addRect(Rect.fromLTWH(0, 0, width, size.height));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Debug 期跑 assert 应触发 AssertionError；release 走静默兜底（此测试
/// 只在 debug 期运行有意义）。
void _expectDebugAssert(void Function() action) {
  if (kReleaseMode) return; // release 无 assert
  expect(action, throwsAssertionError);
}

void main() {
  group('盒模型字段', () {
    ElRenderView findRender(WidgetTester tester) => tester.renderObjectList<ElRenderView>(find.byType(ElView)).first;

    group('字段元数据（spec 表）', () {
      test('所有 13 个新字段都属 Box group', () {
        const newBox = <ElTransitionField>[
          ElTransitionField.padding,
          ElTransitionField.margin,
          ElTransitionField.border,
          ElTransitionField.borderRadius,
          ElTransitionField.boxShadow,
          ElTransitionField.minWidth,
          ElTransitionField.maxWidth,
          ElTransitionField.minHeight,
          ElTransitionField.maxHeight,
          ElTransitionField.opacity,
          ElTransitionField.transform,
          ElTransitionField.transformAlignment,
          ElTransitionField.clipBehavior,
        ];
        for (final f in newBox) {
          final spec = fieldSpecs[f]!;
          expect(maskHas(boxGroupMask, f.index), isTrue, reason: f.name);
          expect(spec.isInherited, isFalse, reason: '${f.name} 应非继承');
        }
      });

      test('layout-only：padding / margin / minWidth / maxWidth / minHeight / maxHeight', () {
        const layoutOnly = <ElTransitionField>[
          ElTransitionField.padding,
          ElTransitionField.margin,
          ElTransitionField.minWidth,
          ElTransitionField.maxWidth,
          ElTransitionField.minHeight,
          ElTransitionField.maxHeight,
        ];
        for (final f in layoutOnly) {
          final s = fieldSpecs[f]!;
          expect(s.affectsLayout, isTrue, reason: '${f.name} 应是 layout');
          expect(s.affectsPaint, isFalse, reason: '${f.name} 不应 paint');
          expect(s.isInherited, isFalse, reason: '${f.name} 不应 inherit');
        }
      });

      test('paint-only：borderRadius / boxShadow / opacity / transform / transformAlignment / clipBehavior', () {
        const paintOnly = <ElTransitionField>[
          ElTransitionField.borderRadius,
          ElTransitionField.boxShadow,
          ElTransitionField.opacity,
          ElTransitionField.transform,
          ElTransitionField.transformAlignment,
          ElTransitionField.clipBehavior,
        ];
        for (final f in paintOnly) {
          final s = fieldSpecs[f]!;
          expect(s.affectsPaint, isTrue, reason: '${f.name} 应 paint');
          expect(s.affectsLayout, isFalse, reason: '${f.name} 不应 layout');
        }
      });

      test('连续字段非 discrete：border / opacity / min-max / padding / margin / borderRadius', () {
        const continuous = <ElTransitionField>[
          ElTransitionField.border,
          ElTransitionField.opacity,
          ElTransitionField.minWidth,
          ElTransitionField.maxWidth,
          ElTransitionField.minHeight,
          ElTransitionField.maxHeight,
          ElTransitionField.padding,
          ElTransitionField.margin,
          ElTransitionField.borderRadius,
        ];
        for (final f in continuous) {
          expect(fieldSpecs[f]!.isDiscrete, isFalse, reason: '${f.name} 应可 lerp');
        }
      });

      test('transform 可连续插值', () {
        final spec = fieldSpecs[ElTransitionField.transform]!;
        expect(spec.isDiscrete, isFalse);
        expect(spec.lerp, same(lerpTransform));
      });

      test('border 使用 Border.lerp', () {
        final spec = fieldSpecs[ElTransitionField.border]!;
        expect(spec.isDiscrete, isFalse);
        expect(spec.lerp, same(lerpBorderValue));
      });

      test('聚合类型：boxShadow 可 lerp，clipBehavior step 切换', () {
        expect(fieldSpecs[ElTransitionField.boxShadow]!.isDiscrete, isFalse);
        expect(fieldSpecs[ElTransitionField.boxShadow]!.lerp, same(lerpBoxShadowListValue));

        const discrete = <ElTransitionField>[ElTransitionField.clipBehavior];
        for (final f in discrete) {
          expect(fieldSpecs[f]!.isDiscrete, isTrue, reason: '${f.name} 应 step 切换');
        }
      });
    });

    group('cascade 端到端写入', () {
      testWidgets('padding / margin 写入 box', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(padding: .all(8), margin: .symmetric(horizontal: 4, vertical: 12)),
            ),
          ),
        );
        final box = findRender(tester).committedResolvedStyle.box;
        expect(box.padding, const EdgeInsets.all(8));
        expect(box.margin, const EdgeInsets.symmetric(horizontal: 4, vertical: 12));
      });

      testWidgets('boxShadow 列表保留顺序', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(
                boxShadow: [
                  BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
                  BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 8)),
                ],
              ),
            ),
          ),
        );
        final shadows = findRender(tester).committedResolvedStyle.box.boxShadow;
        expect(shadows, hasLength(2));
        expect(shadows![0].blurRadius, 8);
        expect(shadows[1].blurRadius, 20);
      });

      testWidgets('min/max 几何约束写入', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(const ElView(style: ElStyle(minWidth: 100, maxWidth: 300, minHeight: 40, maxHeight: 80))),
        );
        final box = findRender(tester).committedResolvedStyle.box;
        expect(box.minWidth, const ElDimension.pixels(100));
        expect(box.maxWidth, const ElDimension.pixels(300));
        expect(box.minHeight, const ElDimension.pixels(40));
        expect(box.maxHeight, const ElDimension.pixels(80));
      });

      testWidgets('opacity / transformAlignment / clipBehavior 写入', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(opacity: 0.5, transformAlignment: Alignment.center, clipBehavior: Clip.hardEdge),
            ),
          ),
        );
        final box = findRender(tester).committedResolvedStyle.box;
        expect(box.opacity, 0.5);
        expect(box.transformAlignment, Alignment.center);
        expect(box.clipBehavior, Clip.hardEdge);
      });

      testWidgets('transform scale 写入', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(transform: .scale(1.5)),
              child: Text('x'),
            ),
          ),
        );
        final box = findRender(tester).committedResolvedStyle.box;
        expect(box.transform, const ElTransform.scale(1.5));
        expect(box.transform!.toMatrix4().storage[0], 1.5);
        expect(box.transform!.toMatrix4().storage[5], 1.5);
      });

      test('transform scale 构造支持单轴、双轴和三轴缩放', () {
        final uniform = const ElTransform.scale(1.5).toMatrix4();
        expect(uniform.storage[0], 1.5);
        expect(uniform.storage[5], 1.5);
        expect(uniform.storage[10], 1.0);

        final xy = const ElTransform.scale(1.5, 0.8).toMatrix4();
        expect(xy.storage[0], 1.5);
        expect(xy.storage[5], 0.8);
        expect(xy.storage[10], 1.0);

        final xyz = const ElTransform.scale(1.5, 0.8, 2.0).toMatrix4();
        expect(xyz.storage[0], 1.5);
        expect(xyz.storage[5], 0.8);
        expect(xyz.storage[10], 2.0);
      });

      test('transform scaleX / scaleY / scaleZ / scale3d 构造写入对应轴', () {
        final x = const ElTransform.scaleX(2).toMatrix4();
        expect(x.storage[0], 2);
        expect(x.storage[5], 1);
        expect(x.storage[10], 1);

        final y = const ElTransform.scaleY(3).toMatrix4();
        expect(y.storage[0], 1);
        expect(y.storage[5], 3);
        expect(y.storage[10], 1);

        final z = const ElTransform.scaleZ(4).toMatrix4();
        expect(z.storage[0], 1);
        expect(z.storage[5], 1);
        expect(z.storage[10], 4);

        final xyz = const ElTransform.scale3d(2, 3, 4).toMatrix4();
        expect(xyz.storage[0], 2);
        expect(xyz.storage[5], 3);
        expect(xyz.storage[10], 4);
      });

      test('transform translate 便捷构造写入对应轴', () {
        final xy = const ElTransform.translate(12, 8).toMatrix4();
        expect(xy.storage[12], 12);
        expect(xy.storage[13], 8);
        expect(xy.storage[14], 0);

        final xyz = const ElTransform.translate(12, 8, 4).toMatrix4();
        expect(xyz.storage[12], 12);
        expect(xyz.storage[13], 8);
        expect(xyz.storage[14], 4);

        expect(const ElTransform.translateX(3).toMatrix4().storage[12], 3);
        expect(const ElTransform.translateY(5).toMatrix4().storage[13], 5);
        expect(const ElTransform.translateZ(7).toMatrix4().storage[14], 7);
      });

      test('transform rotate / skew / perspective 便捷构造写入矩阵', () {
        final rz = ElTransform.rotate(math.pi / 2).toMatrix4();
        expect(rz.storage[0], closeTo(0, 0.0001));
        expect(rz.storage[1], closeTo(1, 0.0001));
        expect(rz.storage[4], closeTo(-1, 0.0001));
        expect(rz.storage[5], closeTo(0, 0.0001));

        final rx = ElTransform.rotateX(math.pi / 2).toMatrix4();
        expect(rx.storage[5], closeTo(0, 0.0001));
        expect(rx.storage[6], closeTo(1, 0.0001));
        expect(rx.storage[9], closeTo(-1, 0.0001));

        final ry = ElTransform.rotateY(math.pi / 2).toMatrix4();
        expect(ry.storage[0], closeTo(0, 0.0001));
        expect(ry.storage[2], closeTo(-1, 0.0001));
        expect(ry.storage[8], closeTo(1, 0.0001));

        final skewed = ElTransform.skewX(math.pi / 4).toMatrix4();
        expect(skewed.storage[4], closeTo(1, 0.0001));

        final projected = const ElTransform.perspective(500).toMatrix4();
        expect(projected.storage[11], closeTo(-0.002, 0.000001));
      });

      testWidgets('transform matrix4 入口保留完整矩阵分量', (tester) async {
        final m = Matrix4.identity()
          ..translateByDouble(12, 8, 0, 1)
          ..scaleByDouble(1, 1, 2, 1);
        await tester.pumpWidget(
          _semanticsFreeApp(
            ElView(
              style: ElStyle(transform: ElTransform.matrix4(m)),
              child: const Text('x'),
            ),
          ),
        );
        final matrix = findRender(tester).committedResolvedStyle.box.transform!.toMatrix4();
        expect(matrix.storage[12], 12);
        expect(matrix.storage[13], 8);
        expect(matrix.storage[10], 2);
      });

      test('ElTransform.alignment() 链式产出带 origin 的副本', () {
        const base = ElTransform.scale(2);
        expect(base.origin, isNull, reason: '原始 .scale 无 origin');
        final tl = base.alignment(Alignment.topLeft);
        final br = base.alignment(Alignment.bottomRight);
        expect(tl.origin, Alignment.topLeft);
        expect(br.origin, Alignment.bottomRight);
        // 矩阵分量不变（仅换 origin 字段）
        expect(tl.toMatrix4().storage[0], 2);
        expect(tl.toMatrix4().storage[5], 2);
        // 不同 origin 的 ElTransform 不相等
        expect(tl == br, isFalse);
        // 相同 origin 相等（同时 == 依赖 16 分量 + origin 均相等）
        expect(tl, base.alignment(Alignment.topLeft));
      });

      testWidgets('.alignment(topLeft) 链式 origin：未设 transformAlignment 时绕 topLeft', (tester) async {
        // 验回退顺序 transformAlignment ?? transform.origin ?? center 真的尊重 transform.origin。
        // 100×100 box，scale(2)。没有 transformAlignment：
        //   - origin = transform.origin = topLeft → effective: T(0,0)·S(2)·T(0,0) = S(2)
        //   - paint 时画到 (0, 0, 200, 200)
        // 如果 origin 错误退回 center：S 围绕 (50,50) → 画到 (-50, -50, 150, 150)
        final t = const ElTransform.scale(2).alignment(Alignment.topLeft);
        await tester.pumpWidget(
          _semanticsFreeApp(
            ElView(
              style: ElStyle(width: 100, height: 100, transform: t),
              child: const Text('x'),
            ),
          ),
        );
        final box = findRender(tester).committedResolvedStyle.box;
        expect(box.transform!.origin, Alignment.topLeft);
        expect(box.transformAlignment, isNull, reason: 'field 未设，回退到 transform.origin');
      });

      testWidgets('Box.transformAlignment 覆盖 transform.origin', (tester) async {
        final t = const ElTransform.scale(2).alignment(Alignment.topLeft);
        await tester.pumpWidget(
          _semanticsFreeApp(
            ElView(
              style: ElStyle(transform: t, transformAlignment: Alignment.bottomRight),
              child: const Text('x'),
            ),
          ),
        );
        final box = findRender(tester).committedResolvedStyle.box;
        // 两源同时存在时，field 优先（document spec）
        expect(box.transformAlignment, Alignment.bottomRight);
        // transform 的 origin 字段保留不变（仅 paint / hit-test 选 field）
        expect(box.transform!.origin, Alignment.topLeft);
      });

      test('ElTransform.rotate3d 极小 axis 退化到 identity（避免 NaN 污染）', () {
        // 沿 axis (1e-200, 0, 0) 旋转 π —— length=1e-200，归一化会产 ±Inf/NaN。
        // B2 修复：length < 1e-12 直接返回 identity。
        final m = ElTransform.rotate3d(1e-200, 0, 0, math.pi).toMatrix4();
        // identity 矩阵分量
        expect(m.storage[0], 1.0);
        expect(m.storage[5], 1.0);
        expect(m.storage[10], 1.0);
        // 无 NaN
        for (var i = 0; i < 16; i++) {
          expect(m.storage[i].isFinite, isTrue, reason: 'storage[$i] 不能是 NaN/Inf');
        }
      });
    });

    group('非继承约束（CSS 盒模型字段子不继承）', () {
      testWidgets('父 padding 不传到子', (tester) async {
        const parentKey = ValueKey('padding-parent');
        const childKey = ValueKey('padding-child');

        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              key: parentKey,
              style: ElStyle(padding: .all(16)),
              child: ElView(key: childKey, child: 'child'),
            ),
          ),
        );
        final parent = tester.renderObject<ElRenderView>(find.byKey(parentKey));
        final child = tester.renderObject<ElRenderView>(find.byKey(childKey));
        expect(parent.committedResolvedStyle.box.padding, const EdgeInsets.all(16));
        expect(child.committedResolvedStyle.box.padding, isNull, reason: '子节点 padding 必须为 null（CSS 不继承）');
      });

      testWidgets('父 boxShadow / opacity 不传到子', (tester) async {
        const childKey = ValueKey('shadow-opacity-child');

        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(opacity: 0.5, boxShadow: [BoxShadow(blurRadius: 4)]),
              child: ElView(key: childKey, child: 'c'),
            ),
          ),
        );
        final child = tester.renderObject<ElRenderView>(find.byKey(childKey));
        expect(child.committedResolvedStyle.box.opacity, isNull);
        expect(child.committedResolvedStyle.box.boxShadow, isNull);
      });
    });

    group('状态变体 + paint-only damage 不变量', () {
      testWidgets('onHover 切 opacity：不触发父 markNeedsLayout', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const SizedBox(
              width: 200,
              height: 40,
              child: ElView(style: ElStyle(opacity: 1.0, onHover: ElStyle(opacity: 0.5))),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final r = findRender(tester);
        final layoutsBefore = r.debugLayoutCount;

        r.setHover(true);
        await tester.pump();

        // cascade 后 opacity 切到 0.5
        expect(r.committedResolvedStyle.box.opacity, 0.5);
        // opacity 是 paint-only → 不应 relayout
        expect(r.debugLayoutCount, layoutsBefore, reason: 'opacity paint-only damage：hover 切换不应 markNeedsLayout');
      });

      testWidgets('onHover 切 boxShadow / borderRadius：仅 paint', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const SizedBox(
              width: 200,
              height: 40,
              child: ElView(
                style: ElStyle(
                  borderRadius: BorderRadius.all(Radius.elliptical(4, 4)),
                  boxShadow: [BoxShadow(blurRadius: 2)],
                  onHover: ElStyle(
                    borderRadius: BorderRadius.all(Radius.elliptical(16, 16)),
                    boxShadow: [BoxShadow(blurRadius: 12)],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final r = findRender(tester);
        final layoutsBefore = r.debugLayoutCount;

        r.setHover(true);
        await tester.pump();

        final box = r.committedResolvedStyle.box;
        expect(box.borderRadius?.resolve(TextDirection.ltr).topLeft.x, 16);
        expect((box.boxShadow as List<BoxShadow>)[0].blurRadius, 12);
        expect(r.debugLayoutCount, layoutsBefore);
      });
    });
  });

  group('附加视觉字段', () {
    Widget shell(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

    ElRenderView render(WidgetTester tester) => tester.renderObjectList<ElRenderView>(find.byType(ElView)).first;

    group('cascade 端到端写入', () {
      testWidgets('gradient 写入 box', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(gradient: LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF0000FF)])),
            ),
          ),
        );
        final box = render(tester).committedResolvedStyle.box;
        expect(box.gradient, isA<LinearGradient>());
        expect((box.gradient! as LinearGradient).colors, [const Color(0xFFFF0000), const Color(0xFF0000FF)]);
      });

      testWidgets('bgImage（DecorationImage 单字段）写入 box', (tester) async {
        // 用 fake provider（永远 pending） —— 让 paint 时 image 还没 resolve，
        // DecorationImagePainter 早退，不抛错。
        const image = DecorationImage(
          image: _FakeImageProvider(),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          repeat: ImageRepeat.noRepeat,
        );
        await tester.pumpWidget(shell(const ElView(style: ElStyle(bgImage: image))));
        final box = render(tester).committedResolvedStyle.box;
        expect(box.bgImage, isNotNull);
        expect(box.bgImage!.fit, BoxFit.cover);
        expect(box.bgImage!.repeat, ImageRepeat.noRepeat);
      });

      testWidgets('aspectRatio 写入 box', (tester) async {
        await tester.pumpWidget(shell(const ElView(style: ElStyle(aspectRatio: 16 / 9))));
        expect(render(tester).committedResolvedStyle.box.aspectRatio, 16 / 9);
      });

      testWidgets('backdropFilter 写入 box', (tester) async {
        const filter = ElFilter(blur: 8);
        await tester.pumpWidget(shell(ElView(style: ElStyle(backdropFilter: filter))));
        expect(render(tester).committedResolvedStyle.box.backdropFilter, same(filter));
      });
    });

    group('damage 路由（spec 元数据）', () {
      test('paint-only：gradient / bgImage / outline / filter / backdropFilter', () {
        const paintOnly = <ElTransitionField>[
          ElTransitionField.gradient,
          ElTransitionField.bgImage,
          ElTransitionField.outline,
          ElTransitionField.filter,
          ElTransitionField.backdropFilter,
        ];
        for (final f in paintOnly) {
          final s = fieldSpecs[f]!;
          expect(s.affectsPaint, isTrue, reason: '${f.name} 应 paint');
          expect(s.affectsLayout, isFalse, reason: '${f.name} 不应 layout');
          expect(s.isInherited, isFalse, reason: '${f.name} 不应 inherit');
        }
      });

      test('aspectRatio：layout-only', () {
        final s = fieldSpecs[ElTransitionField.aspectRatio]!;
        expect(s.affectsLayout, isTrue);
        expect(s.affectsPaint, isFalse);
        expect(s.isInherited, isFalse);
      });

      test('aspectRatio 可 lerp（数值）', () {
        expect(fieldSpecs[ElTransitionField.aspectRatio]!.isDiscrete, isFalse);
      });

      test('可插值视觉字段：gradient / outline / aspectRatio', () {
        expect(fieldSpecs[ElTransitionField.gradient]!.isDiscrete, isFalse);
        expect(fieldSpecs[ElTransitionField.gradient]!.lerp, same(lerpGradientValue));
        expect(fieldSpecs[ElTransitionField.outline]!.isDiscrete, isFalse);
        expect(fieldSpecs[ElTransitionField.outline]!.lerp, same(lerpOutline));
        expect(fieldSpecs[ElTransitionField.aspectRatio]!.isDiscrete, isFalse);
      });

      test('无法平滑插值的引用字段 step 切换：bgImage', () {
        expect(fieldSpecs[ElTransitionField.bgImage]!.isDiscrete, isTrue);
      });

      test('filter / backdropFilter 可平滑插值（ElFilter 聚合 lerp）', () {
        for (final f in <ElTransitionField>[ElTransitionField.filter, ElTransitionField.backdropFilter]) {
          expect(fieldSpecs[f]!.isDiscrete, isFalse, reason: f.name);
          expect(fieldSpecs[f]!.lerp, same(lerpFilter), reason: f.name);
        }
      });
    });

    group('非继承约束', () {
      testWidgets('父 gradient / outline / aspectRatio 不传给子（无 bgImage 避免资源加载）', (tester) async {
        const parentKey = ValueKey('visual-parent');
        const childKey = ValueKey('visual-child');

        await tester.pumpWidget(
          shell(
            const ElView(
              key: parentKey,
              style: ElStyle(
                gradient: LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF0000FF)]),
                outline: ElOutline(color: Color(0xFF000000), width: 1),
                aspectRatio: 2,
              ),
              child: ElView(key: childKey, child: 'inner'),
            ),
          ),
        );
        final parent = tester.renderObject<ElRenderView>(find.byKey(parentKey));
        final child = tester.renderObject<ElRenderView>(find.byKey(childKey));
        expect(parent.committedResolvedStyle.box.gradient, isNotNull);
        expect(child.committedResolvedStyle.box.gradient, isNull, reason: 'gradient 非继承');
        expect(child.committedResolvedStyle.box.outline, isNull, reason: 'outline 非继承');
        expect(child.committedResolvedStyle.box.aspectRatio, isNull, reason: 'aspectRatio 非继承');
      });
    });

    group('状态变体切换', () {
      testWidgets('onHover 切 gradient：cascade 后值变化', (tester) async {
        await tester.pumpWidget(
          shell(
            const SizedBox(
              width: 200,
              height: 40,
              child: ElView(
                style: ElStyle(
                  gradient: LinearGradient(colors: [Color(0xFFFF0000), Color(0xFFFF8800)]),
                  onHover: ElStyle(gradient: LinearGradient(colors: [Color(0xFF00FF00), Color(0xFF008800)])),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final r = render(tester);
        // 初始：红
        final init = r.committedResolvedStyle.box.gradient! as LinearGradient;
        expect(init.colors.first, const Color(0xFFFF0000));

        r.setHover(true);
        await tester.pump();

        // hover 后：绿
        final hover = r.committedResolvedStyle.box.gradient! as LinearGradient;
        expect(hover.colors.first, const Color(0xFF00FF00));
      });
    });
  });

  group('裁剪路径', () {
    test('方向预设在非正方形盒中保留箭头与杆部比例', () {
      final probes = <AxisDirection, (Offset, Offset, Offset)>{
        .right: (Offset(98, 20), Offset(5, 20), Offset(5, 2)),
        .left: (Offset(2, 20), Offset(95, 20), Offset(95, 2)),
        .down: (Offset(50, 39), Offset(50, 2), Offset(2, 2)),
        .up: (Offset(50, 1), Offset(50, 38), Offset(2, 38)),
      };
      for (final entry in probes.entries) {
        final path = ElClipper.arrow(pointTo: entry.key).getClip(Size(100, 40));
        expect(path.getBounds(), Rect.fromLTWH(0, 0, 100, 40));
        expect(path.contains(entry.value.$1), isTrue);
        expect(path.contains(entry.value.$2), isTrue);
        expect(path.contains(entry.value.$3), isFalse);
      }
    });

    test('圆内接预设在非正方形盒中保持等比，返回路径可独立修改', () {
      for (final clipper in [ElClipper.star(), ElClipper.polygon(sides: 4)]) {
        final wide = clipper.getClip(Size(100, 40));
        expect(wide.getBounds().left, greaterThanOrEqualTo(30));
        expect(wide.getBounds().right, lessThanOrEqualTo(70));
        expect(wide.contains(Offset(50, 20)), isTrue);
        wide.reset();
        final tall = clipper.getClip(Size(40, 100));
        expect(tall.getBounds().top, greaterThanOrEqualTo(30));
        expect(tall.getBounds().bottom, lessThanOrEqualTo(70));
        expect(tall.contains(Offset(20, 50)), isTrue);
        expect(clipper.getClip(Size(100, 40)).contains(Offset(50, 20)), isTrue);
      }
    });

    group('ElClipper 预设 == / hashCode', () {
      test('triangle 相同参数 == true', () {
        const a = ElClipper.triangle();
        const b = ElClipper.triangle();
        const c = ElClipper.triangle(pointTo: AxisDirection.down);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
        expect(a == c, isFalse);
      });

      test('star 相同参数 == true', () {
        const a = ElClipper.star();
        const b = ElClipper.star();
        const c = ElClipper.star(points: 6);
        expect(a, equals(b));
        expect(a == c, isFalse);
      });

      test('diamond 无参 所有实例相等', () {
        expect(const ElClipper.diamond() == const ElClipper.diamond(), isTrue);
      });

      test('parallelogram skew 不同 != ', () {
        expect(const ElClipper.parallelogram(skew: 0.2) == const ElClipper.parallelogram(skew: 0.3), isFalse);
      });

      test('跨 variant != ', () {
        expect(const ElClipper.triangle() == const ElClipper.diamond(), isFalse);
      });
    });

    group('ElClipper.triangle 几何', () {
      test('pointTo: up → 顶点 (w/2, 0)，底边 (0,h) (w,h)', () {
        const c = ElClipper.triangle();
        final path = c.getClip(const Size(100, 80));
        // 中线靠底 → 三角内部
        expect(path.contains(const Offset(50, 60)), isTrue);
        // 顶点稍下方 → 三角内部
        expect(path.contains(const Offset(50, 10)), isTrue);
        // 上方角落不在三角内
        expect(path.contains(const Offset(2, 2)), isFalse);
        expect(path.contains(const Offset(98, 2)), isFalse);
      });

      test('pointTo: down → 顶点 (w/2, h)', () {
        const c = ElClipper.triangle(pointTo: AxisDirection.down);
        final path = c.getClip(const Size(100, 80));
        // 顶部中线（朝下三角的"底边"）
        expect(path.contains(const Offset(50, 10)), isTrue);
        // 顶部左侧（仍在底边内）
        expect(path.contains(const Offset(10, 5)), isTrue);
        // 底部两角不在
        expect(path.contains(const Offset(2, 75)), isFalse);
        expect(path.contains(const Offset(98, 75)), isFalse);
      });
    });

    group('ElClipper.diamond 几何', () {
      test('4 边中点连线', () {
        const c = ElClipper.diamond();
        final path = c.getClip(const Size(100, 80));
        // 中心命中
        expect(path.contains(const Offset(50, 40)), isTrue);
        // 4 角不命中
        expect(path.contains(const Offset(0, 0)), isFalse);
        expect(path.contains(const Offset(100, 0)), isFalse);
        expect(path.contains(const Offset(0, 80)), isFalse);
        expect(path.contains(const Offset(100, 80)), isFalse);
      });
    });

    group('ElClipper.star 几何', () {
      test('5 角星 默认参数 中心命中、角外区不命中', () {
        const c = ElClipper.star();
        final path = c.getClip(const Size(100, 100));
        // 中心
        expect(path.contains(const Offset(50, 50)), isTrue);
        // 顶部尖角附近（外半径 = 50，朝上 → (50, 0) 附近）
        expect(path.contains(const Offset(50, 2)), isTrue);
        // 四角空白
        expect(path.contains(const Offset(2, 2)), isFalse);
        expect(path.contains(const Offset(98, 98)), isFalse);
      });
    });

    group('ElClipper.polygon 几何', () {
      test('六边形 默认 rotation=0 第一个顶点在右', () {
        const c = ElClipper.polygon();
        final path = c.getClip(const Size(100, 100));
        // 中心
        expect(path.contains(const Offset(50, 50)), isTrue);
        // 右侧顶点 (100, 50) 附近
        expect(path.contains(const Offset(98, 50)), isTrue);
        // 四角不在
        expect(path.contains(const Offset(2, 2)), isFalse);
      });
    });

    group('ElClipper.trapezoid 几何', () {
      test('topRatio: 0.6 等腰梯形，顶边内缩', () {
        const c = ElClipper.trapezoid();
        final path = c.getClip(const Size(100, 80));
        // 底边居中命中
        expect(path.contains(const Offset(50, 78)), isTrue);
        // 顶边窄了：(20, 0) ~ (80, 0) 范围内命中
        expect(path.contains(const Offset(50, 2)), isTrue);
        // 顶边外的角落不命中
        expect(path.contains(const Offset(2, 2)), isFalse);
        expect(path.contains(const Offset(98, 2)), isFalse);
      });
    });

    group('Box.clipper 字段管线', () {
      test('Box.initial.clipper 是 null', () {
        expect(Box.initial.clipper, isNull);
      });

      test('buffer flush 写 clipper 返回新对象，Box.initial 不变', () {
        const clipper = ElClipper.triangle();
        final updated = (BoxStyleBuffer()..writeClipper(clipper)).flush(Box.initial);
        expect(updated.clipper, same(clipper));
        expect(Box.initial.clipper, isNull);
      });

      test('clipper 字段元数据：paint damage, discrete, !inherited, lerp = step', () {
        final spec = fieldSpecs[ElTransitionField.clipper];
        expect(spec, isNotNull);
        expect(maskHas(boxGroupMask, ElTransitionField.clipper.index), isTrue);
        expect(spec!.isInherited, isFalse);
        expect(spec.isDiscrete, isTrue);
        expect(spec.lerp, same(lerpStep));
        expect(spec.affectsPaint, isTrue);
        expect(spec.affectsLayout, isFalse);
      });
    });

    group('cascade 端到端', () {
      testWidgets('ElStyle.clipper 写到 committed box.clipper', (tester) async {
        const clipper = ElClipper.triangle();
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ElView(
                style: ElStyle(width: 100, height: 80, bgColor: Color(0xFFFF0000), clipper: clipper),
              ),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byType(ElView));
        expect(render.committedResolvedStyle.box.clipper, same(clipper));
      });
    });

    group('hitTest：clip path 外不命中', () {
      Widget shell(Widget child) => MaterialApp(
        home: Align(alignment: Alignment.topLeft, child: child),
      );

      bool hitRender(ElRenderView render, Offset localPosition) {
        final result = BoxHitTestResult();
        render.hitTest(result, position: localPosition);
        return result.path.any((entry) => identical(entry.target, render));
      }

      testWidgets('triangle 朝上：底边中线命中，左上角不命中', (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          shell(
            ElView(
              event: ElEvent(onTap: (_) => tapped++),
              style: const ElStyle(width: 100, height: 80, bgColor: Color(0xFFFF0000), clipper: ElClipper.triangle()),
            ),
          ),
        );

        final render = tester.renderObject<ElRenderView>(find.byType(ElView));
        // 顶点附近（接近 50, 0）命中
        expect(hitRender(render, const Offset(50, 4)), isTrue);
        // 底边中部命中
        expect(hitRender(render, const Offset(50, 78)), isTrue);
        // 左上角（base 内 path 外）不命中
        expect(hitRender(render, const Offset(2, 2)), isFalse);
        // 右上角不命中
        expect(hitRender(render, const Offset(98, 2)), isFalse);
        // base 外肯定不命中
        expect(hitRender(render, const Offset(150, 50)), isFalse);

        // 事件路径也对：顶点 tap 触发
        await tester.tapAt(const Offset(50, 78));
        expect(tapped, 1);
      });

      testWidgets('diamond：中心命中、4 角不命中', (tester) async {
        await tester.pumpWidget(
          shell(
            ElView(
              event: ElEvent(onTap: (_) {}),
              style: const ElStyle(width: 100, height: 80, bgColor: Color(0xFFFF0000), clipper: ElClipper.diamond()),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byType(ElView));
        expect(hitRender(render, const Offset(50, 40)), isTrue);
        expect(hitRender(render, const Offset(2, 2)), isFalse);
        expect(hitRender(render, const Offset(98, 78)), isFalse);
      });

      testWidgets('自定义 CustomClipper<Path>：圆形裁剪', (tester) async {
        await tester.pumpWidget(
          shell(
            ElView(
              event: ElEvent(onTap: (_) {}),
              style: const ElStyle(width: 100, height: 100, bgColor: Color(0xFFFF0000), clipper: _OvalClipper()),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byType(ElView));
        // 中心命中
        expect(hitRender(render, const Offset(50, 50)), isTrue);
        // 4 角不命中（圆外）
        expect(hitRender(render, const Offset(2, 2)), isFalse);
        expect(hitRender(render, const Offset(98, 98)), isFalse);
      });

      testWidgets('borderRadius + clipBehavior：圆角外不命中', (tester) async {
        await tester.pumpWidget(
          shell(
            ElView(
              event: ElEvent(onTap: (_) {}),
              style: const ElStyle(
                width: 100,
                height: 100,
                bgColor: Color(0xFFFF0000),
                borderRadius: BorderRadius.all(Radius.elliptical(50, 50)),
                clipBehavior: Clip.antiAlias,
              ),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byType(ElView));
        expect(hitRender(render, const Offset(50, 50)), isTrue);
        expect(hitRender(render, const Offset(2, 2)), isFalse);
        expect(hitRender(render, const Offset(98, 98)), isFalse);
      });

      testWidgets('circle + clipBehavior：圆形外不命中', (tester) async {
        await tester.pumpWidget(
          shell(
            ElView(
              event: ElEvent(onTap: (_) {}),
              style: const ElStyle(
                width: 100,
                height: 100,
                bgColor: Color(0xFFFF0000),
                borderRadius: BorderRadius.all(Radius.circular(9999)),
                clipBehavior: Clip.antiAlias,
              ),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byType(ElView));
        expect(hitRender(render, const Offset(50, 50)), isTrue);
        expect(hitRender(render, const Offset(2, 2)), isFalse);
        expect(hitRender(render, const Offset(98, 98)), isFalse);
      });

      testWidgets('clipper 优先级高于 hover 合成出的 borderRadius hit-test', (tester) async {
        await tester.pumpWidget(
          shell(
            ElView(
              event: ElEvent(onTap: (_) {}),
              style: const ElStyle(
                width: 100,
                height: 100,
                bgColor: Color(0xFFFF0000),
                clipper: _RectClipper(),
                clipBehavior: Clip.antiAlias,
                onHover: ElStyle(borderRadius: BorderRadius.all(Radius.elliptical(50, 50))),
              ),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byType(ElView));
        render.setHover(true);
        await tester.pump();

        expect(render.committedResolvedStyle.box.clipper, isNotNull);
        expect(hitRender(render, const Offset(2, 2)), isTrue, reason: 'custom clipper 命中后不应再叠加圆角裁剪');
      });

      testWidgets('CustomClipper reclip notifier 触发同实例重新裁剪', (tester) async {
        final clipper = _TogglingClipper();
        await tester.pumpWidget(
          shell(
            ElView(
              event: ElEvent(onTap: (_) {}),
              style: ElStyle(width: 100, height: 100, bgColor: const Color(0xFFFF0000), clipper: clipper),
            ),
          ),
        );
        final render = tester.renderObject<ElRenderView>(find.byType(ElView));

        expect(hitRender(render, const Offset(75, 50)), isFalse, reason: '初始裁剪只保留左半边');

        clipper.showFull = true;
        await tester.pump();

        expect(hitRender(render, const Offset(75, 50)), isTrue, reason: 'reclip 后同一个 clipper 实例应重新使用新 path');
        expect(clipper.clipCount, greaterThanOrEqualTo(2));
      });
    });
  });

  group('原生圆角字段', () {
    test('逻辑圆角在字段读写后仍按方向解析', () {
      final radius = BorderRadiusDirectional.only(topStart: Radius.circular(4), bottomEnd: Radius.circular(12));
      final builder = ResolvedStyleBuilder.empty();
      fieldSpecOf(ElTransitionField.borderRadius).write(builder, radius);
      final box = builder.build().box;
      expect(identical(box.borderRadius, radius), isTrue);
      final rtl = ViewBoxPainter.effectiveBorderRadius(box, textDirection: TextDirection.rtl)!;
      expect(rtl.topRight, Radius.circular(4));
      expect(rtl.bottomLeft, Radius.circular(12));
      expect(rtl.topLeft, Radius.zero);
    });

    test('物理与逻辑圆角连续插值，null 端从零圆角进入', () {
      final mid = lerpBorderRadiusValue(
        BorderRadius.all(Radius.circular(4)),
        BorderRadiusDirectional.only(topStart: Radius.circular(20)),
        0.5,
      ) as BorderRadiusGeometry;
      expect(mid.resolve(TextDirection.rtl).topRight.x, 12);
      expect(mid.resolve(TextDirection.rtl).topLeft.x, 2);
      final fromNull = lerpBorderRadiusValue(null, BorderRadius.all(Radius.circular(20)), 0.5) as BorderRadiusGeometry;
      expect(fromNull.resolve(TextDirection.ltr).topLeft.x, 10);
    });

    testWidgets('原生 CircleBorder 在长方形视图中保留内接圆的绘制与命中', (tester) async {
      final boundaryKey = GlobalKey();
      final clipper = ShapeBorderClipper(shape: CircleBorder());
      await tester.pumpWidget(
        _semanticsFreeApp(
          RepaintBoundary(
            key: boundaryKey,
            child: ElView(
              style: ElStyle(width: 80, height: 40, bgColor: Color(0xFFFF0000), clipper: clipper),
            ),
          ),
        ),
      );
      final render = tester.renderObject<ElRenderView>(find.byType(ElView));
      expect(clipper.getClip(Size(80, 40)).getBounds(), Rect.fromLTWH(20, 0, 40, 40));
      expect(render.hitTest(BoxHitTestResult(), position: Offset(5, 20)), isFalse);
      expect(render.hitTest(BoxHitTestResult(), position: Offset(40, 20)), isTrue);
      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          expect(pixels.getUint8((20 * image.width + 5) * 4 + 3), 0);
          expect(pixels.getUint8((20 * image.width + 40) * 4), 255);
          expect(pixels.getUint8((20 * image.width + 40) * 4 + 3), 255);
        } finally {
          image.dispose();
        }
      });
    });
  });

  group('边框值', () {
    group('值语义', () {
      test('.all 四边统一', () {
        final b = ElBorder.all(width: 2, color: const Color(0xFF112233));
        expect(b.isUniform, isTrue);
        expect(b.top.width, 2);
        expect(b.top.color, const Color(0xFF112233));
        expect(b.top, b.left);
      });

      test('.all const 可用（uniform 双存储形态）', () {
        const b = ElBorder.all(width: 2, color: Color(0xFF112233), style: ElBorderStyle.dashed);
        expect(b.isUniform, isTrue);
        expect(b.top, const ElBorderSide(width: 2, color: Color(0xFF112233), style: ElBorderStyle.dashed));
        // const 规范化：同参数 const 实例 identical
        expect(
          identical(b, const ElBorder.all(width: 2, color: Color(0xFF112233), style: ElBorderStyle.dashed)),
          isTrue,
        );
        // 默认值与旧 factory 口径一致
        const d = ElBorder.all();
        expect(d.top, const ElBorderSide());
      });

      test('uniform / sides 双形态跨形态等值', () {
        const side = ElBorderSide(width: 2, color: Color(0xFF112233));
        const all = ElBorder.all(width: 2, color: Color(0xFF112233));
        const fromSide = ElBorder.fromSide(side);
        const only = ElBorder.only(top: side, right: side, bottom: side, left: side);
        expect(all, fromSide);
        expect(all, only);
        expect(all.hashCode, fromSide.hashCode);
        expect(all.hashCode, only.hashCode);
        // copyWith 从 uniform 形态出发仍正确
        expect(all.copyWith(top: ElBorderSide.none).top, ElBorderSide.none);
        expect(all.copyWith(top: ElBorderSide.none).bottom, side);
      });

      test('.only 单边，未声明边为 none', () {
        const b = ElBorder.only(bottom: ElBorderSide(width: 1));
        expect(b.bottom.width, 1);
        expect(b.top, ElBorderSide.none);
        expect(b.isUniform, isFalse);
      });

      test('.symmetric', () {
        const b = ElBorder.symmetric(horizontal: ElBorderSide(width: 3));
        expect(b.top.width, 3);
        expect(b.bottom.width, 3);
        expect(b.left, ElBorderSide.none);
      });

      test('.fromSide const 可用', () {
        const b = ElBorder.fromSide(ElBorderSide(width: 2, color: Color(0xFF000000)));
        expect(b.isUniform, isTrue);
      });

      test('等值 / 哈希', () {
        expect(ElBorder.all(width: 2), ElBorder.all(width: 2));
        expect(ElBorder.all(width: 2).hashCode, ElBorder.all(width: 2).hashCode);
        expect(ElBorder.all(width: 2) == ElBorder.all(width: 3), isFalse);
      });
    });

    group('值级 lerp', () {
      test('width 数值级插值 + color lerp', () {
        final mid = ElBorder.lerp(ElBorder.all(width: 0), ElBorder.all(width: 10), 0.5)!;
        expect(mid.top.width, 5.0);
      });

      test('单侧 null step（多 side 无通用零值替换）', () {
        final to = ElBorder.all(width: 2);
        expect(ElBorder.lerp(null, to, 0.4), isNull);
        expect(identical(ElBorder.lerp(null, to, 0.6), to), isTrue);
      });
    });
  });

  group('原生边距字段', () {
    test('逻辑边距不做数值包装，读写与等值构建保留原引用', () {
      final padding = EdgeInsetsDirectional.only(start: 12, top: 4, end: 8);
      final builder = ResolvedStyleBuilder.empty();
      fieldSpecOf(ElTransitionField.padding).write(builder, padding);
      final first = builder.build();
      expect(identical(first.box.padding, padding), isTrue);
      expect(first.box.padding!.resolve(TextDirection.rtl), EdgeInsets.fromLTRB(8, 4, 12, 0));
      final unchanged = ResolvedStyleBuilder.fromExisting(first)..writePadding(padding);
      expect(identical(unchanged.build().box, first.box), isTrue);
    });

    test('物理与逻辑边距平滑插值，两种方向都正确', () {
      final mid = lerpEdgeInsetsValue(
        EdgeInsets.only(left: 8),
        EdgeInsetsDirectional.only(start: 12),
        0.5,
      ) as EdgeInsetsGeometry;
      expect(mid.resolve(TextDirection.ltr), EdgeInsets.only(left: 10));
      expect(mid.resolve(TextDirection.rtl), EdgeInsets.only(left: 4, right: 6));
      final fromNull = lerpEdgeInsetsValue(null, EdgeInsets.all(10), 0.5) as EdgeInsetsGeometry;
      expect(fromNull.resolve(TextDirection.ltr), EdgeInsets.all(5));
    });
  });

  group('滤镜值', () {
    group('ElFilter 值语义', () {
      test('结构等值 ==', () {
        expect(const ElFilter(blur: 8, saturate: 1.4), const ElFilter(blur: 8, saturate: 1.4));
        expect(const ElFilter(blur: 8), isNot(const ElFilter(blur: 9)));
        expect(const ElFilter(blur: 8).hashCode, const ElFilter(blur: 8).hashCode);
      });

      test('isIdentity：全 null 恒等；任一分量声明即非恒等', () {
        expect(const ElFilter().isIdentity, isTrue);
        expect(ElFilter.identity.isIdentity, isTrue);
        expect(const ElFilter(blur: 4).isIdentity, isFalse);
        expect(const ElFilter(saturate: 1.2).isIdentity, isFalse);
      });

      test('blur 与 blurX/blurY 互斥 assert', () {
        expect(() => ElFilter(blur: 4, blurX: 2), throwsAssertionError);
        expect(() => ElFilter(blur: 4, blurY: 2), throwsAssertionError);
        expect(ElFilter(blurX: 2, blurY: 4), isA<ElFilter>());
      });
    });

    group('ElFilter.lerp', () {
      test('null ↔ value：分量从各自 CSS 恒等默认值渐入', () {
        final mid = ElFilter.lerp(null, const ElFilter(blur: 10, saturate: 2), 0.5)!;
        expect(mid.blur, 5.0); // blur 恒等值 0
        expect(mid.saturate, 1.5); // saturate 恒等值 1
      });

      test('双侧数值插值', () {
        final mid = ElFilter.lerp(const ElFilter(blur: 0), const ElFilter(blur: 20), 0.25)!;
        expect(mid.blur, 5.0);
      });

      test('双侧 null 分量保持 null（完成态不残留恒等值）', () {
        final mid = ElFilter.lerp(const ElFilter(blur: 4), const ElFilter(blur: 8), 0.5)!;
        expect(mid.blur, 6.0);
        expect(mid.saturate, isNull);
        expect(mid.grayscale, isNull);
      });

      test('identical 短路', () {
        const f = ElFilter(blur: 4);
        expect(identical(ElFilter.lerp(f, f, 0.5), f), isTrue);
      });
    });

    group('resolveToImageFilter', () {
      test('恒等滤镜 → null（零开销跳过 layer）', () {
        expect(const ElFilter().resolveToImageFilter(), isNull);
        // 显式恒等值同样折算为 null。
        expect(const ElFilter(saturate: 1, brightness: 1, grayscale: 0).resolveToImageFilter(), isNull);
        expect(const ElFilter(blur: 0).resolveToImageFilter(), isNull);
      });

      test('纯 blur → ImageFilter.blur 等价（sigma 即 CSS blur(x) 数值）', () {
        final resolved = const ElFilter(blur: 8).resolveToImageFilter();
        expect(resolved, ImageFilter.blur(sigmaX: 8, sigmaY: 8));
      });

      test('各向异性 blurX / blurY', () {
        final resolved = const ElFilter(blurX: 4, blurY: 12).resolveToImageFilter();
        expect(resolved, ImageFilter.blur(sigmaX: 4, sigmaY: 12));
      });

      test('纯颜色分量 → ColorFilter（非 null）', () {
        expect(const ElFilter(saturate: 1.4).resolveToImageFilter(), isNotNull);
        expect(const ElFilter(grayscale: 1).resolveToImageFilter(), isNotNull);
        expect(const ElFilter(hueRotate: 90).resolveToImageFilter(), isNotNull);
      });

      test('反相、亮度、对比度依次合成，alpha 独立缩放', () {
        final resolved = ElFilter(invert: 0.25, brightness: 1.5, contrast: 0.5, opacity: 0.3).resolveToImageFilter();
        expect(
          resolved,
          ColorFilter.matrix([
            0.375, 0, 0, 0, 111.5625, //
            0, 0.375, 0, 0, 111.5625,
            0, 0, 0.375, 0, 111.5625,
            0, 0, 0, 0.3, 0,
          ]),
        );
      });

      test('颜色分量保留各自的范围钳制规则', () {
        final resolved = ElFilter(invert: 2, brightness: -2, contrast: 2, opacity: 2).resolveToImageFilter();
        expect(
          resolved,
          ColorFilter.matrix([
            0, 0, 0, 0, -127.5, //
            0, 0, 0, 0, -127.5,
            0, 0, 0, 0, -127.5,
            0, 0, 0, 1, 0,
          ]),
        );
      });

      test('blur + 颜色分量 → compose 复合（非 null 且非纯 blur）', () {
        final composed = const ElFilter(blur: 12, saturate: 1.4).resolveToImageFilter();
        expect(composed, isNotNull);
        expect(composed, isNot(ImageFilter.blur(sigmaX: 12, sigmaY: 12)));
      });
    });

    group('cascade 集成', () {
      Widget shell(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

      ElRenderView render(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView).first);

      testWidgets('filter 写入 box', (tester) async {
        const f = ElFilter(blur: 56);
        await tester.pumpWidget(shell(ElView(style: ElStyle(filter: f))));
        expect(render(tester).committedResolvedStyle.box.filter, same(f));
      });

      testWidgets('hover 变体切换 filter（渐入自恒等）', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(
                width: 100,
                height: 100,
                bgColor: Color(0xff2196f3),
                onHover: ElStyle(filter: ElFilter(blur: 6)),
              ),
            ),
          ),
        );
        expect(render(tester).committedResolvedStyle.box.filter, isNull);

        render(tester).setHover(true);
        await tester.pumpAndSettle();

        expect(render(tester).committedResolvedStyle.box.filter, const ElFilter(blur: 6));
      });

      testWidgets('filter + backdropFilter 同节点共存不 crash', (tester) async {
        await tester.pumpWidget(
          shell(
            const ElView(
              style: ElStyle(
                width: 80,
                height: 80,
                bgColor: Color(0x882196f3),
                filter: ElFilter(saturate: 1.2),
                backdropFilter: ElFilter(blur: 12),
              ),
            ),
          ),
        );
        final box = render(tester).committedResolvedStyle.box;
        expect(box.filter, const ElFilter(saturate: 1.2));
        expect(box.backdropFilter, const ElFilter(blur: 12));
      });
    });
  });

  group('线性渐变值', () {
    const blue = Color(0xff41d1ff);

    const purple = Color(0xffbd34fe);

    group('resolvePoints 几何（CSS 语义）', () {
      void expectOffset(Offset actual, Offset expected) {
        expect(actual.dx, closeTo(expected.dx, 1e-9));
        expect(actual.dy, closeTo(expected.dy, 1e-9));
      }

      test('90deg = 左→右，线长 = 宽', () {
        const g = ElLinearGradient(angle: 90, colors: [blue, purple]);
        final rect = const Rect.fromLTWH(0, 0, 200, 50);
        final (:begin, :end) = g.resolvePoints(rect);
        expectOffset(begin, const Offset(0, 25));
        expectOffset(end, const Offset(200, 25));
      });

      test('0deg = 下→上，线长 = 高', () {
        const g = ElLinearGradient(angle: 0, colors: [blue, purple]);
        final rect = const Rect.fromLTWH(0, 0, 200, 50);
        final (:begin, :end) = g.resolvePoints(rect);
        expectOffset(begin, const Offset(100, 50));
        expectOffset(end, const Offset(100, 0));
      });

      test('斜角与宽高比无关：150deg 在宽扁盒上仍显著倾斜', () {
        const g = ElLinearGradient(angle: 150, colors: [blue, purple]);
        final rect = const Rect.fromLTWH(0, 0, 570, 90);
        final (:begin, :end) = g.resolvePoints(rect);
        final axis = end - begin;
        // 官方 LinearGradient(topLeft→bottomRight) 在此盒上倾角仅 ~9°；
        // CSS 150deg 恒为 60°（相对水平），dy/dx = tan60 ≈ 1.732
        expect(axis.dy / axis.dx, closeTo(1.732, 0.01));
      });

      test('CSS 渐变线长度公式：两对角在轴上的投影恰为 ±L/2', () {
        const g = ElLinearGradient(angle: 150, colors: [blue, purple]);
        final rect = const Rect.fromLTWH(0, 0, 570, 90);
        final (:begin, :end) = g.resolvePoints(rect);
        final axis = end - begin;
        final len = axis.distance;
        final dir = axis / len;
        double project(Offset corner) {
          final v = corner - rect.center;
          return v.dx * dir.dx + v.dy * dir.dy;
        }

        // 0%/100% 色恰好扫到矩形两对角（150deg 落在 topLeft / bottomRight 对）
        expect(project(rect.topLeft), closeTo(-len / 2, 1e-6));
        expect(project(rect.bottomRight), closeTo(len / 2, 1e-6));
      });

      test('空矩形不抛异常', () {
        const g = ElLinearGradient(angle: 150, colors: [blue, purple]);
        expect(() => g.createShader(Rect.zero), returnsNormally);
      });
    });

    group('lerp（含 null 端，CSS 口径渐隐）', () {
      const g = ElLinearGradient(angle: 150, colors: [blue, purple], stops: [0, 0.7]);

      test('null → g：向透明版渐入', () {
        final mid = ElLinearGradient.lerp(null, g, 0.5)!;
        expect(mid.angle, 150);
        expect(mid.colors.first.a, closeTo(0.5, 0.01));
        expect(mid.stops, [0, 0.7]);
      });

      test('g → null：向透明版渐出', () {
        final mid = ElLinearGradient.lerp(g, null, 0.75)!;
        expect(mid.colors.last.a, closeTo(0.25, 0.01));
      });

      test('同型两端逐字段插值，且 Gradient.lerp 走同型路径', () {
        const g2 = ElLinearGradient(angle: 90, colors: [purple, blue], stops: [0, 1]);
        final mid = Gradient.lerp(g, g2, 0.5)! as ElLinearGradient;
        expect(mid.angle, 120);
        expect(mid.stops, [0, 0.85]);
      });
    });

    test('值相等：同参 const 实例 == 且 hashCode 一致', () {
      const a = ElLinearGradient(angle: 150, colors: [blue, purple], stops: [0, 0.7]);
      const b = ElLinearGradient(angle: 150, colors: [blue, purple], stops: [0, 0.7]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('样式合并', () {
    const red = Color(0xFFFF0000);

    const blue = Color(0xFF0000FF);

    group('merge / vars', () {});

    group('merge 深合并', () {});

    group('merge / transitions 整体替换(护栏)', () {
      test('other 声明即整表覆前表,不做拼接', () {
        const base = ElStyle(transitions: [ElTransition.all(Duration(milliseconds: 100))]);
        const other = ElStyle(transitions: [ElTransition.field(ElTransitionField.width, Duration(milliseconds: 200))]);
        final merged = base.merge(other);
        expect(merged.transitions!.length, 1, reason: '整体替换而非拼接');
        expect(identical(merged.transitions, other.transitions), isTrue);
        // other 未声明 → 保留 base
        expect(identical(base.merge(const ElStyle(width: 1)).transitions, base.transitions), isTrue);
      });
    });

    group('merge / 嵌套变体深合并', () {
      test('onHover 深合并,base 未覆盖字段保留', () {
        const base = ElStyle(onHover: ElStyle(bgColor: red, width: 10));
        const other = ElStyle(onHover: ElStyle(bgColor: blue));
        final merged = base.merge(other);
        expect(merged.onHover!.bgColor, blue);
        expect(merged.onHover!.width, 10);
      });
    });

    group('copyWith 三态', () {});
  });

  group('字段元数据', () {
    group('字段表完整性', () {
      // flex 布局字段已拆除，不再有 spec-less 例外。
      const specLessFields = <ElTransitionField>{};

      test('除 spec-less 例外外，每个 ElTransitionField 都有 FieldSpec', () {
        final missing = [
          for (final field in ElTransitionField.values)
            if (!specLessFields.contains(field) && !fieldSpecs.containsKey(field)) field.name,
        ];
        expect(missing, isEmpty, reason: 'CascadeTick / driver 会通过 fieldSpecOf 查表，非例外字段缺 spec 是运行时错误');
      });

      test('spec-less 例外字段严禁在 fieldSpecs 里（防意外补 spec 让路径错走）', () {
        for (final f in specLessFields) {
          expect(
            fieldSpecs.containsKey(f),
            isFalse,
            reason: '${f.name} 是 spec-less 例外，见 field_spec.dart fieldSpecOf 防御 assert',
          );
        }
      });
    });

    group('paint-only 关键不变量（防 cascade 路由把 paint-only 误改 layout）', () {
      test('color: inherit + paint，NOT layout', () {
        final spec = fieldSpecs[ElTransitionField.color]!;
        expect(spec.isInherited, isTrue);
        expect(spec.affectsPaint, isTrue);
        expect(spec.affectsLayout, isFalse, reason: 'color 必须是 paint-only —— 本重构最核心的不变量');
      });
    });

    group('layout-affecting 关键不变量', () {
      test('字体 metrics 都是 inherit + layout', () {
        const metricFields = [
          ElTransitionField.fontSize,
          ElTransitionField.fontWeight,
          ElTransitionField.fontStyle,
          ElTransitionField.fontFamily,
          ElTransitionField.lineHeight,
          ElTransitionField.letterSpacing,
          ElTransitionField.wordSpacing,
          ElTransitionField.textAlign,
        ];
        for (final f in metricFields) {
          final spec = fieldSpecs[f]!;
          expect(spec.isInherited, isTrue, reason: '${f.name} 应继承');
          expect(spec.affectsLayout, isTrue, reason: '${f.name} 字体度量变化必须 relayout');
        }
      });

      test('overflow: layout + paint 双通道', () {
        final spec = fieldSpecs[ElTransitionField.overflow]!;
        expect(spec.affectsLayout, isTrue);
        expect(spec.affectsPaint, isTrue);
        expect(spec.isInherited, isFalse);
      });

      test('textDirection: 跨 InheritedBox 组的 inherit + layout', () {
        final spec = fieldSpecs[ElTransitionField.textDirection]!;
        expect(spec.isInherited, isTrue);
        expect(spec.affectsLayout, isTrue);
      });
    });

    group('特殊 damage 形态', () {
      test('cursor: inherit only（NO layout、NO paint）', () {
        final spec = fieldSpecs[ElTransitionField.cursor]!;
        expect(spec.isInherited, isTrue);
        expect(spec.affectsLayout, isFalse);
        expect(spec.affectsPaint, isFalse);
      });
    });
  });

  group('图标字段', () {
    ElRenderView findFirstRender(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView).first);

    const glyph = IconData(0xe716, fontFamily: 'MaterialIcons');

    group('pure 载荷默认（顺序隔离验证）', () {
      testWidgets('无声明时图标吃引擎默认 24/次级灰，不回落文本通道', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(fontSize: 14, color: Color(0xff000000)),
              child: glyph,
            ),
          ),
        );
        final r = findFirstRender(tester);
        final span = (r.textEngineForTest?.painterForTest.text) as TextSpan?;
        expect(span!.style!.fontSize, 24, reason: 'InheritedBox.initial.iconSize 默认');
        expect(span.style!.color, const Color(0xff909399), reason: 'InheritedBox.initial.iconColor 默认');
        expect(span.style!.fontFamily, 'MaterialIcons');
      });
    });

    group('iconSize / iconColor 声明与继承', () {
      testWidgets('cascade 出字段写入 inheritedBox', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(iconSize: 20, iconColor: Color(0xff909399), fontSize: 14, color: Color(0xff000000)),
              child: '图标',
            ),
          ),
        );
        final r = findFirstRender(tester);
        expect(r.committedResolvedStyle.inheritedBox.iconSize, 20);
        expect(r.committedResolvedStyle.inheritedBox.iconColor, const Color(0xff909399));
      });

      testWidgets('子未声明时沿 render 树继承父值', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(iconSize: 24, iconColor: Color(0xffdcdfe6)),
              child: ElView(child: '子文本'),
            ),
          ),
        );
        final r = findFirstRender(tester);
        // 只有根 ElView 一个节点有 committedStyle（子 ElView 是 inline run）
        expect(r.committedResolvedStyle.inheritedBox.iconSize, 24);
      });
    });

    group('pure 载荷渲染注入', () {
      testWidgets('IconData glyph 用 iconSize/iconColor 覆盖 fontSize/color', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(fontSize: 14, color: Color(0xff000000), iconSize: 24, iconColor: Color(0xff409eff)),
              child: glyph,
            ),
          ),
        );
        final r = findFirstRender(tester);
        final span = (r.textEngineForTest?.painterForTest.text) as TextSpan?;
        expect(span, isNotNull);
        expect(span!.text, String.fromCharCode(0xe716));
        expect(span.style!.fontSize, 24);
        expect(span.style!.color, const Color(0xff409eff));
        expect(span.style!.fontFamily, 'MaterialIcons');
      });
    });

    group('状态变体', () {
      testWidgets('onHover 变体可覆盖 iconColor', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(
                iconSize: 18,
                iconColor: Color(0xff909399),
                onHover: ElStyle(iconColor: Color(0xffff0000)),
              ),
              child: glyph,
            ),
          ),
        );
        final r = findFirstRender(tester);
        final hover = r.committedResolvedStyle.inheritedBox;
        expect(hover.iconColor, const Color(0xff909399));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(ElView)));
        await tester.pumpAndSettle();
        expect(((r.textEngineForTest?.painterForTest.text) as TextSpan).style!.color, Color(0xffff0000));
        await mouse.removePointer();
      });

      testWidgets('父节点 iconColor 过渡驱动后代实际 glyph，中间帧与退出颜色正确', (tester) async {
        final iconKey = GlobalKey();
        final hostKey = GlobalKey();
        await tester.pumpWidget(
          _semanticsFreeApp(
            ElView(
              key: hostKey,
              style: ElStyle(
                width: 30,
                height: 30,
                alignment: .center,
                iconSize: 16,
                iconColor: Color(0xff000000),
                onHover: ElStyle(iconColor: Color(0xffffffff)),
                transitions: [ElTransition.field(.iconColor, Duration(milliseconds: 200), Curves.linear)],
              ),
              child: ElView(key: iconKey, child: glyph),
            ),
          ),
        );
        final r = tester.renderObject<ElRenderView>(find.byKey(iconKey));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byKey(hostKey)));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 100));
        final middle = ((r.textEngineForTest?.painterForTest.text) as TextSpan).style!.color!;
        expect(middle.r, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
        expect(((r.textEngineForTest?.painterForTest.text) as TextSpan).style!.color, Color(0xffffffff));
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(((r.textEngineForTest?.painterForTest.text) as TextSpan).style!.color, Color(0xff000000));
        await mouse.removePointer();
      });
    });

    group('富文本混排', () {
      testWidgets('数组里的 IconData run 使用图标通道', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(fontSize: 14, iconSize: 22, iconColor: Color(0xff67c23a)),
              child: <Object>['前文', glyph],
            ),
          ),
        );
        final r = findFirstRender(tester);
        final span = (r.textEngineForTest?.painterForTest.text) as TextSpan?;
        expect(span, isNotNull);
        final children = span!.children!;
        expect(children, hasLength(2));
        expect(children[1], isA<WidgetSpan>());
        // 图标 run 现在由 WidgetSpan 内的独立 ElView 绘制，仍校验实际 glyph 的全部样式。
        final icon = tester.renderObject<ElRenderView>(find.byWidget((children[1] as WidgetSpan).child));
        final iconSpan = icon.textEngineForTest!.painterForTest.text! as TextSpan;
        expect(iconSpan.text, String.fromCharCode(0xe716));
        expect(iconSpan.style!.fontSize, 22);
        expect(iconSpan.style!.color, const Color(0xff67c23a));
        expect(iconSpan.style!.fontFamily, 'MaterialIcons');
      });
    });
  });

  group('数值解析', () {
    test('copyWith 接受整数数字并保持显式 null 清空语义', () {
      const base = ElStyle(fontSize: 20);
      final copied = base.copyWith(fontSize: 14, iconSize: 16, opacity: 1, widthFactor: 1);
      expect(copied.fontSize, isA<double>());
      expect(copied.fontSize, 14.0);
      expect(copied.iconSize, 16.0);
      expect(copied.opacity, 1.0);
      expect(copied.widthFactor, 1.0);
      expect(copied.copyWith(fontSize: null).fontSize, isNull);
      expect(copied.copyWith().fontSize, 14.0);
    });

    ResolvedStyle emit(ElTransitionField field, Object? value) {
      final b = ResolvedStyleBuilder.fromExisting(ResolvedStyle.initial);
      fieldSpecOf(field).write(b, value);
      return b.build();
    }

    group('double slot（fontSize / opacity / aspectRatio 等）', () {
      test('int → double（toDouble） - 数值等价', () {
        final r = emit(ElTransitionField.fontSize, 16);
        expect(r.inheritedText.fontSize, 16.0);
        expect(r.inheritedText.fontSize, isA<num>());
      });

      test('double 直通', () {
        final r = emit(ElTransitionField.fontSize, 14.5);
        expect(r.inheritedText.fontSize, 14.5);
      });

      test('null → null（未声明）', () {
        final r = emit(ElTransitionField.fontSize, null);
        expect(r.inheritedText.fontSize, isNull);
      });

      test("百分号字符串（非 var-ref）→ assert（debug）+ null（release/兜底）", () {
        _expectDebugAssert(() => emit(ElTransitionField.fontSize, '50%'));
      });
    });

    group('int slot（maxLines）', () {
      test('int 直通', () {
        final r = emit(ElTransitionField.maxLines, 3);
        expect(r.inheritedText.maxLines, 3);
      });

      test('null → null', () {
        final r = emit(ElTransitionField.maxLines, null);
        expect(r.inheritedText.maxLines, isNull);
      });

      test('double 3.5 → assert（int 槽拒非整数）', () {
        _expectDebugAssert(() => emit(ElTransitionField.maxLines, 3.5));
      });

      test('非 var-ref 字符串 → assert', () {
        _expectDebugAssert(() => emit(ElTransitionField.maxLines, 'bad'));
      });
    });

    group('dimension slot（width / height / min* / max*）', () {
      test('num → ElDimension.pixels', () {
        final r = emit(ElTransitionField.width, 80);
        expect(r.box.width, const ElDimension.pixels(80));
      });

      test('"50%" → ElDimension.percent', () {
        final r = emit(ElTransitionField.width, '50%');
        expect(r.box.width, const ElDimension.percent(50));
      });

      test('ElDimension 直通', () {
        final r = emit(ElTransitionField.width, const ElDimension.pixels(120));
        expect(r.box.width, const ElDimension.pixels(120));
      });

      test('null → null', () {
        final r = emit(ElTransitionField.width, null);
        expect(r.box.width, isNull);
      });

      test('垃圾字符串 → null（容错，与既有 ElDimension.parse 口径一致）', () {
        final r = emit(ElTransitionField.width, 'bad');
        expect(r.box.width, isNull);
      });
    });

    group('归一化对 aspectRatio（double slot）', () {
      test('数值直通，非法字符串被拒绝', () {
        expect(emit(ElTransitionField.aspectRatio, 1.5).box.aspectRatio, 1.5);
        _expectDebugAssert(() => emit(ElTransitionField.aspectRatio, '2:1'));
      });
    });

    group('归一化对尺寸 factor（double slot）', () {
      test('num 转 double，非法字符串被拒绝', () {
        expect(emit(ElTransitionField.widthFactor, 1).box.widthFactor, 1.0);
        expect(emit(ElTransitionField.heightFactor, .5).box.heightFactor, .5);
        _expectDebugAssert(() => emit(ElTransitionField.heightFactor, '50%'));
      });
    });
  });

  group('文字扩展字段', () {
    ElRenderView findFirstRender(WidgetTester tester) => tester.renderObject<ElRenderView>(find.byType(ElView));

    group('fontVariations 字段', () {
      testWidgets('cascade 出的可变轴列表保留顺序', (tester) async {
        const variations = <ui.FontVariation>[ui.FontVariation('wght', 600), ui.FontVariation('wdth', 110)];
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(fontSize: 14, fontFamily: 'Roboto Flex', fontVariations: variations),
              child: 'variable',
            ),
          ),
        );
        final r = findFirstRender(tester);
        final cascaded = r.committedResolvedStyle.inheritedText.fontVariations;
        expect(cascaded, hasLength(2));
        expect(cascaded![0].axis, 'wght');
        expect(cascaded[0].value, 600);
        expect(cascaded[1].axis, 'wdth');
      });
    });

    group('leadingDistribution 字段', () {
      testWidgets('cascade 出的 leadingDistribution 写入 inheritedText', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(fontSize: 14, lineHeight: 2.0, leadingDistribution: TextLeadingDistribution.even),
              child: 'leading even',
            ),
          ),
        );
        final r = findFirstRender(tester);
        expect(r.committedResolvedStyle.inheritedText.leadingDistribution, TextLeadingDistribution.even);
      });
    });

    group('textBaseline 字段', () {
      testWidgets('cascade 出的 textBaseline 写入 inheritedText', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(fontSize: 14, textBaseline: TextBaseline.ideographic),
              child: 'baseline 中',
            ),
          ),
        );
        final r = findFirstRender(tester);
        expect(r.committedResolvedStyle.inheritedText.textBaseline, TextBaseline.ideographic);
      });
    });
  });

  group('盒解析值', () {
    group('Box', () {
      test('initial 全 null', () {
        expect(Box.initial.width, isNull);
        expect(Box.initial.height, isNull);
        expect(Box.initial.bgColor, isNull);
      });

      // 旧 withX 已由生成器剥离；字段级独立写入统一走 BoxStyleBuffer flush，
      // 每步 buffer 累积字段覆盖，flush 一次性 alloc 新 Box。
      test('buffer flush 独立写入 width / height / bgColor', () {
        final buf = BoxStyleBuffer()
          ..writeWidth(ElDimension.parse(100))
          ..writeHeight(ElDimension.parse(50))
          ..writeBgColor(const Color(0xFFFF0000));
        final s = buf.flush(Box.initial);

        expect(s.width, const ElDimension.pixels(100));
        expect(s.height, const ElDimension.pixels(50));
        expect(s.bgColor, const Color(0xFFFF0000));
        // 未写入的字段仍是 initial
        expect(s.padding, isNull);
        expect(s.border, isNull);
      });

      test('buffer flush：写入相同值触发等值短路，返回 base', () {
        const base = Box(width: ElDimension.pixels(100));
        final buf = BoxStyleBuffer()..writeWidth(ElDimension.parse(100));
        final after = buf.flush(base);
        expect(identical(after, base), isTrue, reason: '所有 dirty 字段与 base 相等 → 返回 base');
      });

      test('buffer flush：未写任何字段直接返回 base', () {
        const base = Box(width: ElDimension.pixels(100));
        final after = BoxStyleBuffer().flush(base);
        expect(identical(after, base), isTrue);
      });

      test('== / hashCode', () {
        const a = Box(width: ElDimension.pixels(100), height: ElDimension.pixels(50), bgColor: Color(0xFFFF0000));
        const b = Box(width: ElDimension.pixels(100), height: ElDimension.pixels(50), bgColor: Color(0xFFFF0000));
        const c = Box(width: ElDimension.pixels(101), height: ElDimension.pixels(50), bgColor: Color(0xFFFF0000));
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
      });
    });
  });

  group('解析值构建器', () {
    group('ResolvedStyleBuilder.empty', () {
      test('build 等价 initial', () {
        final b = ResolvedStyleBuilder.empty();
        final s = b.build();
        expect(s, ResolvedStyle.initial);
      });

      test('写入后 build 反映变化', () {
        final b = ResolvedStyleBuilder.empty()
          ..writeColor(const Color(0xFFFF0000))
          ..writeFontSize(16)
          ..writeWidth(const ElDimension.pixels(100))
          ..writeBgColor(const Color(0xFFFFFFFF));
        final s = b.build();
        expect(s.inheritedText.color, const Color(0xFFFF0000));
        expect(s.inheritedText.fontSize, 16);
        expect(s.box.width, const ElDimension.pixels(100));
        expect(s.box.bgColor, const Color(0xFFFFFFFF));
      });
    });

    group('ResolvedStyleBuilder.fromParent — 关键 identical 共享', () {
      test('未写入任何字段时三组都 identical 父', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(textDirection: TextDirection.ltr),
          box: Box(width: ElDimension.pixels(100)),
        );
        final b = ResolvedStyleBuilder.fromParent(parent);

        final out = b.build();
        expect(identical(out.inheritedText, parent.inheritedText), isTrue);
        expect(identical(out.inheritedBox, parent.inheritedBox), isTrue);
        // box 不借父，是 initial
        expect(identical(out.box, Box.initial), isTrue);
      });

      test('写入 inheritedText 字段后断 identical', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(),
          box: Box(),
        );
        final b = ResolvedStyleBuilder.fromParent(parent)..writeColor(const Color(0xFF00FF00));

        final out = b.build();
        expect(identical(out.inheritedText, parent.inheritedText), isFalse);
        expect(identical(out.inheritedBox, parent.inheritedBox), isTrue);
        expect(out.inheritedText.color, const Color(0xFF00FF00));
      });

      test('写入 inheritedText 字段同值时 identical 保持（buffer 同值短路）', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(),
          box: Box(),
        );
        final b = ResolvedStyleBuilder.fromParent(parent)..writeColor(const Color(0xFFFF0000)); // 同值

        final out = b.build();
        expect(identical(out.inheritedText, parent.inheritedText), isTrue);
      });

      test('写入 inheritedBox 字段独立断开 identical', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(textDirection: TextDirection.ltr),
          box: Box(),
        );
        final b = ResolvedStyleBuilder.fromParent(parent)..writeCursor(SystemMouseCursors.click);

        final out = b.build();
        expect(identical(out.inheritedText, parent.inheritedText), isTrue);
        expect(identical(out.inheritedBox, parent.inheritedBox), isFalse);
        expect(out.inheritedBox.cursor, SystemMouseCursors.click);
        expect(out.inheritedBox.textDirection, TextDirection.ltr, reason: '原 textDirection 必须保留');
      });

      test('写入 box 字段不影响任何继承组', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(textDirection: TextDirection.ltr),
          box: Box(width: ElDimension.pixels(100)),
        );
        final b = ResolvedStyleBuilder.fromParent(parent)..writeWidth(const ElDimension.pixels(200));

        final out = b.build();
        expect(identical(out.inheritedText, parent.inheritedText), isTrue);
        expect(identical(out.inheritedBox, parent.inheritedBox), isTrue);
        // box 不继承，写入 200 应生效，旧 100 不保留
        expect(out.box.width, const ElDimension.pixels(200));
      });
    });
  });

  group('盒继承值', () {
    group('InheritedBox', () {
      test('initial 全 null', () {
        expect(InheritedBox.initial.textDirection, isNull);
        expect(InheritedBox.initial.cursor, isNull);
      });

      // 旧 withX 已由生成器剥离；字段级独立写入统一走 InheritedBoxStyleBuffer flush。
      test('buffer flush 独立写入 textDirection / cursor', () {
        final buf = InheritedBoxStyleBuffer()
          ..writeTextDirection(TextDirection.ltr)
          ..writeCursor(SystemMouseCursors.click);
        final s = buf.flush(InheritedBox.initial);
        expect(s.textDirection, TextDirection.ltr);
        expect(s.cursor, SystemMouseCursors.click);
      });

      test('buffer flush：写入相同值触发等值短路，返回 base', () {
        const base = InheritedBox(textDirection: TextDirection.ltr);
        final buf = InheritedBoxStyleBuffer()..writeTextDirection(TextDirection.ltr);
        final after = buf.flush(base);
        expect(identical(after, base), isTrue);
      });

      test('== / hashCode', () {
        const a = InheritedBox(textDirection: TextDirection.ltr, cursor: SystemMouseCursors.click);
        const b = InheritedBox(textDirection: TextDirection.ltr, cursor: SystemMouseCursors.click);
        const c = InheritedBox(textDirection: TextDirection.rtl, cursor: SystemMouseCursors.click);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
      });
    });
  });

  group('文字继承值', () {
    group('InheritedText', () {
      // 旧 withX 已由生成器剥离；字段级独立写入统一走 InheritedTextStyleBuffer flush。
      test('buffer flush 独立写入 color 返回新对象，只 color 变化', () {
        const before = InheritedText(fontSize: 16);
        final after = (InheritedTextStyleBuffer()..writeColor(const Color(0xFFFF0000))).flush(before);
        expect(after, isNot(same(before)));
        expect(after.color, const Color(0xFFFF0000));
        expect(after.fontSize, 16, reason: '其他字段必须保留');
      });

      test('buffer flush：写入相同值触发等值短路，返回 base', () {
        const red = Color(0xFFFF0000);
        const before = InheritedText(color: red);
        final after = (InheritedTextStyleBuffer()..writeColor(red)).flush(before);
        expect(identical(after, before), isTrue);
      });

      test('buffer flush：值类型（fontSize）写入相同值也短路', () {
        const before = InheritedText(fontSize: 16);
        final after = (InheritedTextStyleBuffer()..writeFontSize(16.0)).flush(before);
        expect(identical(after, before), isTrue);
      });

      test('buffer flush：显式写 null 也能替换掉原有值', () {
        const before = InheritedText(color: Color(0xFFFF0000));
        final after = (InheritedTextStyleBuffer()..writeColor(null)).flush(before);
        expect(after.color, isNull);
        expect(identical(after, before), isFalse);
      });

      test('多字段串行写入不会互相污染', () {
        const start = InheritedText.initial;
        final a = (InheritedTextStyleBuffer()..writeColor(const Color(0xFFFF0000))).flush(start);
        final b = (InheritedTextStyleBuffer()..writeFontSize(20.0)).flush(a);
        expect(start.color, InheritedText.initial.color);
        expect(start.fontSize, InheritedText.initial.fontSize);
        expect(a.color, const Color(0xFFFF0000));
        expect(a.fontSize, InheritedText.initial.fontSize);
        expect(b.color, const Color(0xFFFF0000));
        expect(b.fontSize, 20);
      });

      test('fromInheritedParent 只保留 CSS 继承字段', () {
        const parent = InheritedText(
          color: Color(0xFFFF0000),
          fontSize: 20,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF0000FF),
          decorationThickness: 2,
          textBackgroundColor: Color(0xFFFFFF00),
          letterSpacing: 0.5,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        );

        final childBase = InheritedText.fromInheritedParent(parent);

        expect(childBase.color, const Color(0xFFFF0000));
        expect(childBase.fontSize, 20);
        expect(childBase.decorationColor, const Color(0xFF0000FF));
        expect(childBase.decorationThickness, 2);
        expect(childBase.letterSpacing, 0.5);
        expect(childBase.decoration, isNull);
        expect(childBase.textBackgroundColor, isNull);
        expect(childBase.softWrap, isNull);
        expect(childBase.overflow, isNull);
        expect(childBase.maxLines, isNull);
      });

      test('fromInheritedParent 在非继承字段为 initial 时复用父引用', () {
        const parent = InheritedText(color: Color(0xFFFF0000), fontSize: 20);

        final childBase = InheritedText.fromInheritedParent(parent);

        expect(identical(childBase, parent), isTrue);
      });

      test('== 全字段比较', () {
        const a = InheritedText(color: Color(0xFF000000), fontSize: 16, fontWeight: FontWeight.w400);
        const b = InheritedText(color: Color(0xFF000000), fontSize: 16, fontWeight: FontWeight.w400);
        const c = InheritedText(color: Color(0xFF000000), fontSize: 17, fontWeight: FontWeight.w400);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
      });

      test('textShadow 列表深比较', () {
        const a = InheritedText(textShadow: [Shadow(blurRadius: 1), Shadow(blurRadius: 2)]);
        const b = InheritedText(textShadow: [Shadow(blurRadius: 1), Shadow(blurRadius: 2)]);
        const c = InheritedText(textShadow: [Shadow(blurRadius: 1), Shadow(blurRadius: 3)]);
        expect(a, b);
        expect(a, isNot(c));
      });

      test('全 15 字段都可通过 buffer 独立写入', () {
        final buf = InheritedTextStyleBuffer()
          ..writeColor(const Color(0xFF000000))
          ..writeFontSize(16.0)
          ..writeFontWeight(FontWeight.bold)
          ..writeFontStyle(FontStyle.italic)
          ..writeFontFamily('Roboto')
          ..writeLineHeight(1.5)
          ..writeLetterSpacing(0.5)
          ..writeWordSpacing(1.0)
          ..writeTextAlign(TextAlign.center)
          ..writeTextShadow(const [Shadow(blurRadius: 2)])
          ..writeDecoration(TextDecoration.underline)
          ..writeTextBackgroundColor(const Color(0xFFFFFF00))
          ..writeSoftWrap(false)
          ..writeOverflow(TextOverflow.ellipsis)
          ..writeMaxLines(2);
        final s = buf.flush(InheritedText.initial);

        expect(s.color, const Color(0xFF000000));
        expect(s.fontSize, 16);
        expect(s.fontWeight, FontWeight.bold);
        expect(s.fontStyle, FontStyle.italic);
        expect(s.fontFamily, 'Roboto');
        expect(s.lineHeight, 1.5);
        expect(s.letterSpacing, 0.5);
        expect(s.wordSpacing, 1.0);
        expect(s.textAlign, TextAlign.center);
        expect(s.textShadow, hasLength(1));
        expect(s.decoration, TextDecoration.underline);
        expect(s.textBackgroundColor, const Color(0xFFFFFF00));
        expect(s.softWrap, isFalse);
        expect(s.overflow, TextOverflow.ellipsis);
        expect(s.maxLines, 2);
      });

      group('copyWithResolvedColors (theme paint 热路径)', () {});
    });
  });

  group('解析样式', () {
    group('ResolvedStyle', () {
      test('initial 三组都是 initial', () {
        expect(identical(ResolvedStyle.initial.inheritedText, InheritedText.initial), isTrue);
        expect(identical(ResolvedStyle.initial.inheritedBox, InheritedBox.initial), isTrue);
        expect(identical(ResolvedStyle.initial.box, Box.initial), isTrue);
      });

      test('fromParent 子节点 identical 共享父可继承组', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000), fontSize: 16),
          inheritedBox: InheritedBox(textDirection: TextDirection.ltr),
          box: Box(width: ElDimension.pixels(100), height: ElDimension.pixels(50), bgColor: Color(0xFFFFFFFF)),
        );
        final child = ResolvedStyleBuilder.fromParent(parent).build();

        // 关键不变量：identical 共享父引用
        expect(
          identical(child.inheritedText, parent.inheritedText),
          isTrue,
          reason: '子节点必须 identical 共享父的 inheritedText',
        );
        expect(identical(child.inheritedBox, parent.inheritedBox), isTrue, reason: '子节点必须 identical 共享父的 inheritedBox');
        // box 不继承，子节点 initial
        expect(identical(child.box, Box.initial), isTrue);
      });

      test('fromParent 会清掉 InheritedText group 内的 CSS 非继承字段', () {
        const parent = ResolvedStyle(
          inheritedText: InheritedText(
            color: Color(0xFFFF0000),
            decoration: TextDecoration.underline,
            textBackgroundColor: Color(0xFFFFFF00),
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          inheritedBox: InheritedBox(textDirection: TextDirection.ltr),
          box: Box(width: ElDimension.pixels(100)),
        );

        final child = ResolvedStyleBuilder.fromParent(parent).build();

        expect(child.inheritedText.color, const Color(0xFFFF0000));
        expect(child.inheritedText.decoration, isNull);
        expect(child.inheritedText.textBackgroundColor, isNull);
        expect(child.inheritedText.softWrap, isNull);
        expect(child.inheritedText.overflow, isNull);
        expect(child.inheritedText.maxLines, isNull);
        expect(identical(child.inheritedBox, parent.inheritedBox), isTrue);
        expect(identical(child.box, Box.initial), isTrue);
      });

      test('copyWith 替换单组', () {
        const a = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(),
          box: Box(width: ElDimension.pixels(100)),
        );
        final b = a.copyWith(box: const Box(width: ElDimension.pixels(200)));
        expect(b.box.width, const ElDimension.pixels(200));
        expect(identical(b.inheritedText, a.inheritedText), isTrue, reason: '未指定 group 应保持 identical');
        expect(identical(b.inheritedBox, a.inheritedBox), isTrue);
      });

      test('== 全 group 比较', () {
        const a = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(),
          box: Box(width: ElDimension.pixels(100)),
        );
        const b = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(),
          box: Box(width: ElDimension.pixels(100)),
        );
        const c = ResolvedStyle(
          inheritedText: InheritedText(color: Color(0xFFFF0000)),
          inheritedBox: InheritedBox(),
          box: Box(width: ElDimension.pixels(200)),
        );
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(c));
      });
    });
  });

  group('文字渐变', () {
    const blue = Color(0xff41d1ff);

    const purple = Color(0xffbd34fe);

    const gradient = ElLinearGradient(angle: 90, colors: [blue, purple]);

    group('cascade 与继承', () {
      testWidgets('ElStyle.textGradient 写入 inheritedText', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(textGradient: gradient),
              child: 'grad',
            ),
          ),
        );
        final r = tester.renderObject<ElRenderView>(find.byType(ElView));
        expect(r.committedResolvedStyle.inheritedText.textGradient, gradient);
      });

      testWidgets('color 族口径：嵌套 El 文本继承 textGradient', (tester) async {
        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElView(
              style: ElStyle(textGradient: gradient),
              child: ElView(key: ValueKey('inner'), child: 'nested'),
            ),
          ),
        );
        final inner = tester.renderObject<ElRenderView>(find.byKey(const ValueKey('inner')));
        expect(inner.committedResolvedStyle.inheritedText.textGradient, gradient);
      });
    });

    group('lerp（CSS 对齐 null 端渐隐）', () {
      Object? lerp(Object? a, Object? b, double t) => fieldSpecs[ElTransitionField.textGradient]!.lerp(a, b, t);

      test('null → g：向透明版渐入', () {
        final mid = lerp(null, gradient, 0.25)! as Gradient;
        expect(mid.colors.first.a, closeTo(0.25, 0.01));
      });

      test('g → null：向透明版渐出', () {
        final mid = lerp(gradient, null, 0.75)! as Gradient;
        expect(mid.colors.first.a, closeTo(0.25, 0.01));
      });
    });

    testWidgets('像素回归：90deg 渐变字形左蓝右紫，节点底色不被蒙版', (tester) async {
      tester.view.physicalSize = const Size(400, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _semanticsFreeApp(
          const RepaintBoundary(
            child: ElView(
              key: ValueKey('grad'),
              // 白底节点承载渐变文字：底色像素必须保持白（渐变只蒙字形，
              // ShaderMask 式整树蒙版会把底色一起灌成渐变）
              style: ElStyle(
                bgColor: Color(0xffffffff),
                padding: .all(8),
                fontSize: 40,
                fontWeight: .w800,
                textGradient: gradient,
              ),
              child: 'Element',
            ),
          ),
        ),
      );

      final box = tester.renderObject<RenderBox>(find.byKey(const ValueKey('grad')));
      RenderObject boundary = box;
      while (!boundary.isRepaintBoundary) {
        boundary = boundary.parent!;
      }
      final image = (await tester.runAsync(() => (boundary.debugLayer! as OffsetLayer).toImage(boundary.paintBounds)))!;
      final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
      final origin = box.localToGlobal(Offset.zero, ancestor: boundary);

      (int r, int g, int b)? saturatedAt(int x, int y) {
        final i = (y * image.width + x) * 4;
        if (i < 0 || i + 3 >= bytes.lengthInBytes) return null;
        final r = bytes.getUint8(i), g = bytes.getUint8(i + 1), b = bytes.getUint8(i + 2);
        if (bytes.getUint8(i + 3) < 200) return null;
        final maxC = [r, g, b].reduce((a, c) => a > c ? a : c);
        final minC = [r, g, b].reduce((a, c) => a < c ? a : c);
        return maxC - minC < 60 ? null : (r, g, b);
      }

      final left = origin.dx.round(), top = origin.dy.round();
      final w = box.size.width.round(), h = box.size.height.round();
      (int, int, int)? leftMost, rightMost;
      for (var x = left; x < left + w; x++) {
        for (var y = top; y < top + h; y++) {
          final p = saturatedAt(x, y);
          if (p == null) continue;
          leftMost ??= p;
          rightMost = p;
        }
      }
      expect(leftMost, isNotNull, reason: '盒内应有渐变字形像素');
      expect(leftMost!.$2, greaterThan(150), reason: '左端应为蓝（绿通道高），实际 $leftMost');
      expect(rightMost!.$1, greaterThan(150), reason: '右端应为紫（红通道高），实际 $rightMost');

      // 底色不被蒙版：盒左上角 padding 区仍是白
      int channel(int x, int y, int c) => bytes.getUint8((y * image.width + x) * 4 + c);
      final cornerX = left + 2, cornerY = top + 2;
      expect(channel(cornerX, cornerY, 0), greaterThan(240), reason: 'padding 角落应保持白底');
      expect(channel(cornerX, cornerY, 1), greaterThan(240));
      expect(channel(cornerX, cornerY, 2), greaterThan(240));
    });

    testWidgets('选中渐变文字：高亮矩形不被渐变蒙版（ShaderMask 事故形态回归）', (tester) async {
      // 桌面平台才有鼠标 4px 拖选；复位必须在测试体内（框架不变量校验早于 tearDown）
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = const Size(400, 200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _semanticsFreeApp(
            const ElSelectionView(
              child: RepaintBoundary(
                child: ElView(
                  key: ValueKey('grad'),
                  style: ElStyle(bgColor: Color(0xffffffff), fontSize: 40, fontWeight: .w800, textGradient: gradient),
                  child: 'Element',
                ),
              ),
            ),
          ),
        );

        final rect = tester.getRect(find.byKey(const ValueKey('grad')));
        final gesture = await tester.startGesture(rect.centerLeft + const Offset(2, 0), kind: PointerDeviceKind.mouse);
        await tester.pump();
        await gesture.moveTo(rect.center);
        await tester.pump();
        await gesture.moveTo(rect.centerRight - const Offset(2, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        final box = tester.renderObject<RenderBox>(find.byKey(const ValueKey('grad')));
        RenderObject boundary = box;
        while (!boundary.isRepaintBoundary) {
          boundary = boundary.parent!;
        }
        final image = (await tester.runAsync(
          () => (boundary.debugLayer! as OffsetLayer).toImage(boundary.paintBounds),
        ))!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        final origin = box.localToGlobal(Offset.zero, ancestor: boundary);

        (int r, int g, int b) pixelAt(int x, int y) {
          final i = (y * image.width + x) * 4;
          return (bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2));
        }

        // 字形上方的选中背景行：取盒顶部第 2 行，行内左右两点
        final y = origin.dy.round() + 2;
        final pLeft = pixelAt(origin.dx.round() + 5, y);
        final pRight = pixelAt((origin.dx + box.size.width).round() - 5, y);

        // 选中确实发生：背景行不再是白底
        bool nearWhite((int, int, int) p) => p.$1 > 240 && p.$2 > 240 && p.$3 > 240;
        expect(nearWhite(pLeft), isFalse, reason: '选中后背景行应有高亮色，实际 $pLeft（选区未生效？）');

        // 高亮矩形应为均匀色：整树蒙版事故下这一行是蓝→紫斜坡，
        // 左右端绿通道落差 >100；均匀高亮色落差应接近 0
        expect(
          (pLeft.$2 - pRight.$2).abs(),
          lessThan(40),
          reason: '选中背景行左右应同色，实际 left=$pLeft right=$pRight（渐变淹没了高亮矩形）',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
