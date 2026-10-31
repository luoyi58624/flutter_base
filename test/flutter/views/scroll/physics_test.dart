import 'dart:math' as math;
import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/flutter/views/scroll/common/pointer/scroll_pointer_chain.dart';
import 'package:flutter_base/src/flutter/views/scroll/common/viewport/scroll_engine_position.dart';
import 'package:flutter_base/src/flutter/views/scroll/smooth_scroll/smooth_pointer_scroll.dart';
import 'package:flutter_base/src/flutter/views/scroll/smooth_scroll/smooth_scroll.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/virtual_test_host.dart';

FixedScrollMetrics _metrics({required double pixels, double min = 0.0, double max = 1000.0, double viewport = 600.0}) {
  return FixedScrollMetrics(
    minScrollExtent: min,
    maxScrollExtent: max,
    pixels: pixels,
    viewportDimension: viewport,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 3.0,
  );
}

/// 采样 simulation 在 [0, cap] 秒内的 x 轨迹（isDone 即停）。
List<double> _sampleX(Simulation sim, {double cap = 6.0, double step = 1 / 60}) {
  final xs = <double>[];
  for (var t = 0.0; t <= cap; t += step) {
    xs.add(sim.x(t));
    if (sim.isDone(t)) break;
  }
  return xs;
}

class _StubMetrics implements ScrollMetrics {
  const _StubMetrics({required this.pixels, this.minScrollExtent = 0.0, this.maxScrollExtent = 10000.0});

  @override
  final double pixels;
  @override
  final double minScrollExtent;
  @override
  final double maxScrollExtent;
  @override
  double get viewportDimension => 600.0;
  @override
  AxisDirection get axisDirection => AxisDirection.down;
  @override
  Axis get axis => Axis.vertical;
  @override
  bool get outOfRange => pixels < minScrollExtent || pixels > maxScrollExtent;
  @override
  bool get atEdge => pixels == minScrollExtent || pixels == maxScrollExtent;
  @override
  double get devicePixelRatio => 1.0;
  @override
  bool get hasContentDimensions => true;
  @override
  bool get hasPixels => true;
  @override
  bool get hasViewportDimension => true;
  @override
  double get extentBefore => math.max(0.0, pixels - minScrollExtent);
  @override
  double get extentAfter => math.max(0.0, maxScrollExtent - pixels);
  @override
  double get extentInside => math.min(viewportDimension, maxScrollExtent - minScrollExtent);
  @override
  double get extentTotal => maxScrollExtent - minScrollExtent;
  @override
  ScrollMetrics copyWith({
    double? minScrollExtent,
    double? maxScrollExtent,
    double? pixels,
    double? viewportDimension,
    AxisDirection? axisDirection,
    double? devicePixelRatio,
  }) {
    return _StubMetrics(
      pixels: pixels ?? this.pixels,
      minScrollExtent: minScrollExtent ?? this.minScrollExtent,
      maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
    );
  }
}

final double _rate = math.log(0.78) / math.log(0.9);

const double _coeff = 0.015 * 9.80665 * 39.37 * 160.0 * 0.84;

double _officialDuration(double v) {
  final l = math.log(0.35 * v.abs() / _coeff);
  return math.exp(l / (_rate - 1.0));
}

double _officialDistance(double v) {
  final l = math.log(0.35 * v.abs() / _coeff);
  return _coeff * math.exp(_rate / (_rate - 1.0) * l);
}

final bool _skipMouseWheelClassificationTests = !ElPlatform.isDesktop || ElPlatform.isMacOS;

Future<BuildContext> _pumpScrollContext(WidgetTester tester) async {
  const key = ValueKey('scroll-context');
  await tester.pumpWidget(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(key: key, width: 1, height: 1),
    ),
  );
  return tester.element(find.byKey(key));
}

final class _PointerScrollHarness {
  _PointerScrollHarness(BuildContext context) : position = _RecordingScrollPosition(context) {
    controller = SmoothPointerScrollController(
      // 动画路径单测显式注入算法（默认 null=直滚）。
      algorithm: const ElChromiumSmoothScroll(),
      position: () => position,
      targetOffsetForDelta: (delta, {double? from}) {
        final base = from ?? position.pixels;
        return (base + delta).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
      },
    );
  }

  final _RecordingScrollPosition position;
  late final SmoothPointerScrollController controller;

  void dispose() {
    controller.dispose();
    position.dispose();
  }
}

final class _RecordingScrollPosition extends ScrollPositionWithSingleContext {
  _RecordingScrollPosition(BuildContext context)
    : super(
        physics: const ClampingScrollPhysics(),
        context: _TestScrollContext(context),
        initialPixels: 0,
        keepScrollOffset: false,
      ) {
    applyViewportDimension(100);
    applyContentDimensions(0, 300);
  }

  final List<ScrollActivity> activities = <ScrollActivity>[];

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity != null) activities.add(newActivity);
    super.beginActivity(newActivity);
  }
}

final class _FallbackScrollPosition implements ScrollPosition {
  double _pixels = 0;

  int setPixelsCalls = 0;
  int animateToCalls = 0;

  @override
  double get pixels => _pixels;

  @override
  bool get hasPixels => true;

  @override
  double get minScrollExtent => 0;

  @override
  double get maxScrollExtent => 600;

  @override
  bool get hasContentDimensions => true;

  @override
  double setPixels(double newPixels) {
    setPixelsCalls++;
    final clamped = newPixels.clamp(minScrollExtent, maxScrollExtent).toDouble();
    final overscroll = newPixels - clamped;
    _pixels = clamped;
    return overscroll;
  }

  @override
  Future<void> animateTo(double to, {required Duration duration, required Curve curve}) {
    animateToCalls++;
    return Future<void>.value();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TestScrollContext implements ScrollContext {
  const _TestScrollContext(this.context);

  final BuildContext context;

  @override
  AxisDirection get axisDirection => AxisDirection.down;

  @override
  double get devicePixelRatio => 1.0;

  @override
  BuildContext? get notificationContext => context;

  @override
  BuildContext get storageContext => context;

  @override
  TickerProvider get vsync => const _TestTickerProvider();

  @override
  void saveOffset(double offset) {}

  @override
  void setCanDrag(bool value) {}

  @override
  void setIgnorePointer(bool value) {}

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {}
}

final class _TestTickerProvider implements TickerProvider {
  const _TestTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

class _Linear extends ElSmoothScroll {
  const _Linear();
  @override
  double stepForEvent(double rawDelta, int burstTicks) => rawDelta;
  @override
  Duration segmentDuration(double delta, double velocity) => const Duration(milliseconds: 100);
  @override
  Curve curveFor(double initialSlope) => Curves.linear;
}

class _Probe extends StatefulWidget {
  const _Probe({super.key, required this.correct});
  final bool correct;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with ElScrollMixin<_Probe> {
  double header = 0;
  bool corrected = false;
  final updates = <ElScrollSnapshot>[];
  late final track = ElScrollEffectTrack(
    effectId: #header,
    minValue: 0,
    maxValue: 40,
    pixelsPerUnit: 1,
    readValue: () => header,
    updateValue: (value) => header = value,
  );
  @override
  Iterable<ElScrollEffectTrack> get scrollEffectTracks => [track];
  @override
  Object get scrollInputSlot => #header;
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    if (widget.correct && !corrected) {
      corrected = true;
      (requireScrollPosition as ScrollEnginePosition).correctLayoutPixels(requireScrollPosition.pixels + 30);
    }
    final consumed = rest.clamp(0.0, 40 - header);
    header += consumed;
    return rest - consumed;
  }

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    super.onScrollUpdate(details);
    updates.add(details.snapshot);
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 2000));
}

class _NoChromeBehavior extends ScrollBehavior {
  const _NoChromeBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

const _frame = Duration(milliseconds: 16);

const _androidDeviceSettings = DeviceGestureSettings(touchSlop: 8.0);

class _VideoCard extends StatefulWidget {
  const _VideoCard({super.key, required this.index});

  final int index;

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) {
    final palette = const [
      (Color(0xFF7C3AED), Icons.support_agent, '客户回访池', '中'),
      (Color(0xFF0891B2), Icons.fact_check_outlined, '内容审核流', '低'),
      (Color(0xFF0F9F6E), Icons.inventory_2_outlined, '库存预警规则', '中'),
    ];
    final item = palette[widget.index % palette.length];
    final sprint = widget.index ~/ palette.length + 1;

    return ElView(
      event: ElEvent(onTap: (_) => setState(() => _selected = !_selected)),
      style: ElStyle(
        width: '100%',
        height: 96,
        margin: const .only(bottom: 12, left: 12, right: 12),
        padding: const .all(12),
        backgroundColor: _selected ? const Color(0xFFEAF2FF) : Colors.white,
        borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
        border: .all(borderColor: _selected ? const Color(0xFF2868D8) : const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x100F172A), blurRadius: 10, offset: Offset(0, 3))],
        onTap: const ElStyle(backgroundColor: Color(0xFFE8F1FF), transform: ElTransform.scale(0.99, 0.99)),
        transition: const [ElTransition.all(Duration(milliseconds: 120), Curves.easeOut)],
      ),
      child: ElView(
        style: const ElStyle(),
        child: [
          ElView(
            style: ElStyle(
              width: 40,
              height: 40,
              backgroundColor: item.$1,
              borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
            ),
            child: Icon(item.$2, color: Colors.white, size: 21),
          ),
          ElView(
            style: const ElStyle(),
            child: [
              ElView(
                style: const ElStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  maxLines: 1,
                  textOverflow: TextOverflow.ellipsis,
                ),
                child: '${item.$3} #${widget.index + 1}',
              ),
              const ElView(
                style: ElStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  lineHeight: 1.25,
                  maxLines: 2,
                  textOverflow: TextOverflow.ellipsis,
                ),
                child: '按最近互动、客户等级和响应时间排序，让高价值任务优先露出。',
              ),
              ElView(
                style: const ElStyle(width: '100%'),
                child: [
                  ElView(
                    style: const ElStyle(color: Color(0xFF64748B), fontSize: 11),
                    child: 'Sprint $sprint',
                  ),
                  ElView(
                    style: const ElStyle(color: Color(0xFF64748B), fontSize: 11),
                    child: item.$4,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Trace {
  final List<double> overscrolls = [];
  int scrollStarts = 0;
  int scrollEnds = 0;

  double get totalOverscroll => overscrolls.fold<double>(0, (a, b) => a + b);

  void reset() {
    overscrolls.clear();
    scrollStarts = 0;
    scrollEnds = 0;
  }

  @override
  String toString() => 'Trace(starts: $scrollStarts, ends: $scrollEnds, overscrolls: $overscrolls)';
}

class _FixedStepSmoothScroll extends ElSmoothScroll {
  const _FixedStepSmoothScroll(this.step);

  final double step;

  @override
  double stepForEvent(double rawDelta, int burstTicks) => rawDelta.sign * step;

  @override
  Duration segmentDuration(double delta, double velocity) => const Duration(milliseconds: 80);

  @override
  Curve curveFor(double initialSlope) => Curves.linear;
}

const Duration _smoothWheelFeelFrame = Duration(microseconds: 16667);

final bool _skip = !ElPlatform.isDesktop || ElPlatform.isMacOS;

/// 编排测试专用算法:步长恒等 + 固定段时长 + 线性曲线。与产品算法解耦,
/// 产品手感怎么调都不影响编排结构断言。
final class _LinearTestSmoothScroll extends ElSmoothScroll {
  const _LinearTestSmoothScroll();

  static const Duration _duration = Duration(milliseconds: 200);

  @override
  double stepForEvent(double rawDelta, int burstTicks) => rawDelta;

  @override
  Duration segmentDuration(double delta, double velocity) => _duration;

  @override
  Curve curveFor(double initialSlope) => Curves.linear;
}

Future<BuildContext> _smoothWheelFeelPumpScrollContext(WidgetTester tester) async {
  const key = ValueKey('wheel-feel-context');
  await tester.pumpWidget(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(key: key, width: 1, height: 1),
    ),
  );
  return tester.element(find.byKey(key));
}

final class _WheelHarness {
  _WheelHarness(BuildContext context, ElSmoothScroll algorithm) : position = _WheelScrollPosition(context) {
    controller = SmoothPointerScrollController(
      algorithm: algorithm,
      position: () => position,
      targetOffsetForDelta: (delta, {double? from}) {
        final base = from ?? position.pixels;
        return (base + delta).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
      },
    );
  }

  final _WheelScrollPosition position;
  late final SmoothPointerScrollController controller;

  void dispose() {
    controller.dispose();
    position.dispose();
  }
}

final class _WheelScrollPosition extends ScrollPositionWithSingleContext {
  _WheelScrollPosition(BuildContext context)
    : super(
        physics: const ClampingScrollPhysics(),
        context: _WheelScrollContext(context),
        initialPixels: 0,
        keepScrollOffset: false,
      ) {
    applyViewportDimension(100);
    applyContentDimensions(0, 1000000);
  }

  double get animationVelocity => activity?.velocity ?? 0;
}

final class _WheelScrollContext implements ScrollContext {
  const _WheelScrollContext(this.context);

  final BuildContext context;

  @override
  AxisDirection get axisDirection => AxisDirection.down;

  @override
  double get devicePixelRatio => 1.0;

  @override
  BuildContext? get notificationContext => context;

  @override
  BuildContext get storageContext => context;

  @override
  TickerProvider get vsync => const _WheelTickerProvider();

  @override
  void saveOffset(double offset) {}

  @override
  void setCanDrag(bool value) {}

  @override
  void setIgnorePointer(bool value) {}

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {}
}

final class _WheelTickerProvider implements TickerProvider {
  const _WheelTickerProvider();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  group('反向回弹惯性', () {
    group('ElBouncingScrollPhysics simulation', () {
      // 缺陷核心场景：顶边越界（pixels < min），速度指向界内（正=向 max 方向）。
      // 官方 sim 会 spring 回 min 且不越过；修正版必须真正穿回界内。
      testWidgets('leading overscroll + inward fling re-enters content instead of springing back', (tester) async {
        const physics = ElBouncingScrollPhysics();
        // 顶边拉伸 80px 处，以 1600px/s 朝界内（向下滚 = pixels 增）甩。
        final metrics = _metrics(pixels: -80.0);
        final sim = physics.createBallisticSimulation(metrics, 1600.0)!;
        final xs = _sampleX(sim);

        // 起点在界外。
        expect(xs.first, lessThan(0.0));
        // 必须穿过边界进入界内（这正是官方缺陷所在——官方最大值 ≈ min=0）。
        expect(
          xs.reduce((a, b) => a > b ? a : b),
          greaterThan(20.0),
          reason: 'inward fling must carry momentum back into content, not stop at the boundary',
        );
        // 全程单调不退（同一条摩擦曲线，无回弹反复）。
        for (var i = 1; i < xs.length; i++) {
          expect(
            xs[i],
            greaterThanOrEqualTo(xs[i - 1] - 0.01),
            reason: 'trajectory must not oscillate back (frame $i)',
          );
        }
      });

      testWidgets('trailing overscroll + inward fling re-enters content', (tester) async {
        const physics = ElBouncingScrollPhysics();
        // 底边越界 80px（pixels=1080 > max=1000），以 -1600px/s 朝界内（向上滚）甩。
        final metrics = _metrics(pixels: 1080.0);
        final sim = physics.createBallisticSimulation(metrics, -1600.0)!;
        final xs = _sampleX(sim);

        expect(xs.first, greaterThan(1000.0));
        expect(
          xs.reduce((a, b) => a < b ? a : b),
          lessThan(980.0),
          reason: 'inward fling at trailing edge must carry back into content',
        );
        for (var i = 1; i < xs.length; i++) {
          expect(xs[i], lessThanOrEqualTo(xs[i - 1] + 0.01), reason: 'trajectory must not oscillate back (frame $i)');
        }
      });

      // 越界起步但速度太小、摩擦到不了边界 → 回退官方 spring 回弹（收敛到边界）。
      testWidgets('leading overscroll + weak inward fling falls back to official spring', (tester) async {
        const el = ElBouncingScrollPhysics();
        const official = BouncingScrollPhysics();
        final metrics = _metrics(pixels: -80.0);
        // 20px/s：远不足以穿回界内。
        final elSim = el.createBallisticSimulation(metrics, 20.0)!;
        final offSim = official.createBallisticSimulation(metrics, 20.0)!;
        final elXs = _sampleX(elSim);
        final offXs = _sampleX(offSim);
        // 回退到官方实现 → 逐帧等值。
        final n = elXs.length < offXs.length ? elXs.length : offXs.length;
        for (var i = 0; i < n; i++) {
          expect(elXs[i], closeTo(offXs[i], 0.01), reason: 'weak inward fling must match official spring (frame $i)');
        }
      });

      // 不回归：界内起步 fling 与官方逐帧等值。
      testWidgets('in-range fling matches official frame by frame', (tester) async {
        const el = ElBouncingScrollPhysics();
        const official = BouncingScrollPhysics();
        final metrics = _metrics(pixels: 300.0);
        final elSim = el.createBallisticSimulation(metrics, 2000.0)!;
        final offSim = official.createBallisticSimulation(metrics, 2000.0)!;
        final elXs = _sampleX(elSim);
        final offXs = _sampleX(offSim);
        final n = elXs.length < offXs.length ? elXs.length : offXs.length;
        expect((elXs.length - offXs.length).abs(), lessThanOrEqualTo(1));
        for (var i = 0; i < n; i++) {
          expect(elXs[i], closeTo(offXs[i], 0.01), reason: 'in-range fling diverges from official (frame $i)');
        }
      });

      // 不回归：越界起步、速度朝界外（继续拉伸方向）→ 官方 spring 回弹，逐帧等值。
      testWidgets('overscroll + outward fling matches official spring frame by frame', (tester) async {
        const el = ElBouncingScrollPhysics();
        const official = BouncingScrollPhysics();
        final metrics = _metrics(pixels: -80.0);
        // 负速度 = 继续朝界外（越顶方向）。
        final elSim = el.createBallisticSimulation(metrics, -600.0)!;
        final offSim = official.createBallisticSimulation(metrics, -600.0)!;
        final elXs = _sampleX(elSim);
        final offXs = _sampleX(offSim);
        final n = elXs.length < offXs.length ? elXs.length : offXs.length;
        for (var i = 0; i < n; i++) {
          expect(elXs[i], closeTo(offXs[i], 0.01), reason: 'outward fling must match official (frame $i)');
        }
      });

      // 静止越界回弹（velocity≈0）→ 官方 spring，逐帧等值。
      testWidgets('overscroll at rest springs back matching official', (tester) async {
        const el = ElBouncingScrollPhysics();
        const official = BouncingScrollPhysics();
        final metrics = _metrics(pixels: -80.0);
        final elSim = el.createBallisticSimulation(metrics, 0.0)!;
        final offSim = official.createBallisticSimulation(metrics, 0.0)!;
        final elXs = _sampleX(elSim);
        final offXs = _sampleX(offSim);
        final n = elXs.length < offXs.length ? elXs.length : offXs.length;
        for (var i = 0; i < n; i++) {
          expect(elXs[i], closeTo(offXs[i], 0.01), reason: 'rest spring-back must match official (frame $i)');
        }
      });

      testWidgets('upgrade replaces official BouncingScrollPhysics head, preserves subclass', (tester) async {
        expect(ElBouncingScrollPhysics.upgrade(const BouncingScrollPhysics()), isA<ElBouncingScrollPhysics>());
        // decelerationRate 保留。
        final fast = ElBouncingScrollPhysics.upgrade(
          const BouncingScrollPhysics(decelerationRate: ScrollDecelerationRate.fast),
        );
        expect((fast as ElBouncingScrollPhysics).decelerationRate, ScrollDecelerationRate.fast);
        // 已是修正版：原样返回同类型。
        expect(ElBouncingScrollPhysics.upgrade(const ElBouncingScrollPhysics()), isA<ElBouncingScrollPhysics>());
        // 非 bouncing 不动。
        expect(ElBouncingScrollPhysics.upgrade(const ClampingScrollPhysics()), isA<ClampingScrollPhysics>());
      });
    });

    group('ElScrollView iOS bouncing widget wiring', () {
      const scrollKey = ValueKey('ios-bounce');

      // 平台 override 只影响 build/position 创建期的 physics 解析；pump 后链条
      // 已定型即复位，避免 foundation debug 变量在 body 结束时仍被改动（该不变量
      // 在 addTearDown 之前校验）。
      Future<void> pumpIosScroll(WidgetTester tester, ScrollController c) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox.expand(
                child: ElScrollView(
                  key: scrollKey,
                  controller: c,
                  children: [for (var i = 0; i < 200; i++) ElView(key: ValueKey('ios-row-$i'), child: 'row - $i')],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;
      }

      // 运行时接线证明：iOS 平台下，实际 ScrollPosition 生效的 physics 链必须
      // 含 ElBouncingScrollPhysics（否则越界反向甩仍走官方缺陷路径）。
      testWidgets('live position physics chain contains ElBouncingScrollPhysics on iOS', (tester) async {
        final c = ScrollController();
        addTearDown(c.dispose);
        await pumpIosScroll(tester, c);

        var node = c.position.physics;
        var found = false;
        while (true) {
          if (node is ElBouncingScrollPhysics) {
            found = true;
            break;
          }
          final next = node.parent;
          if (next == null) break;
          node = next;
        }
        expect(found, isTrue, reason: 'iOS 生效 physics 链必须含 ElBouncingScrollPhysics');
      });

      // 端到端：越界反向甩不响应缺陷的直接复现。深度过度滚动后，在**仍越界**时
      // 通过实际生效的 physics 驱动 ballistic：修正版 sim 必须穿回界内（缺陷版
      // 官方 sim 会卡在边界，终值 ≈ 0）。用真实 position + 真实 physics 链，
      // 不构造孤立 physics。
      testWidgets('runtime ballistic at overscroll + inward velocity re-enters content on iOS', (tester) async {
        final c = ScrollController();
        addTearDown(c.dispose);
        await pumpIosScroll(tester, c);

        final position = c.position;
        // 深度顶边越界快照（pixels < minScrollExtent）。
        final overscrolled = FixedScrollMetrics(
          minScrollExtent: position.minScrollExtent,
          maxScrollExtent: position.maxScrollExtent,
          pixels: position.minScrollExtent - 120.0,
          viewportDimension: position.viewportDimension,
          axisDirection: position.axisDirection,
          devicePixelRatio: tester.view.devicePixelRatio,
        );
        // 朝界内（正=向 max 滚）猛甩，用运行时真实 physics 链结算。
        final sim = position.physics.createBallisticSimulation(overscrolled, 1800.0)!;
        final xs = _sampleX(sim);
        expect(xs.first, lessThan(position.minScrollExtent));
        expect(
          xs.reduce((a, b) => a > b ? a : b),
          greaterThan(position.minScrollExtent + 20.0),
          reason: 'iOS 运行时链：越界反向甩必须带动量穿回内容区，而非卡在边界回弹',
        );
      });
    });
  });

  group('浏览器滚动物理', () {
    group('ElBrowserScrollPhysics.createBallisticSimulation(官方样条公式)', () {
      test('距离与时长逐速度锁官方解析解(v0 = 1000/2000/5000/8000)', () {
        const physics = ElBrowserScrollPhysics();
        const metrics = _StubMetrics(pixels: 500.0, maxScrollExtent: 100000.0);
        for (final v in const [1000.0, 2000.0, 5000.0, 8000.0]) {
          final sim = physics.createBallisticSimulation(metrics, v)!;
          final duration = _officialDuration(v);
          final distance = _officialDistance(v);
          // 时长:isDone 恰在 T 处翻转。
          expect(sim.isDone(duration - 0.001), isFalse, reason: 'v=$v: T=$duration 前未结束');
          expect(sim.isDone(duration + 0.001), isTrue, reason: 'v=$v: T=$duration 后已结束');
          // 距离:终点位移 = D。
          expect(sim.x(duration + 1.0) - 500.0, closeTo(distance, distance * 1e-6 + 0.01), reason: 'v=$v: 总位移 = D');
          // 关键量级锁(防公式抄错):v=1000 → D≈194px/T≈0.56s;v=5000 → D≈3178px/T≈1.82s。
          if (v == 1000.0) {
            expect(distance, closeTo(194.0, 4.0));
            expect(duration, closeTo(0.56, 0.02));
          }
          if (v == 5000.0) {
            expect(distance, closeTo(3178.0, 40.0));
            expect(duration, closeTo(1.82, 0.05));
          }
        }
      });

      test('与官方 ClampingScrollSimulation 总距离相等、时长为其 1/0.8254 倍', () {
        const chrome = ElBrowserScrollPhysics();
        const metrics = _StubMetrics(pixels: 0.0, maxScrollExtent: 100000.0);
        for (final v in const [1500.0, 4000.0]) {
          final cSim = chrome.createBallisticSimulation(metrics, v)!;
          final fSim = ClampingScrollSimulation(position: 0.0, velocity: v);
          // Flutter 官方把时长缩到 rate×inflexion 倍以换取无记忆性,总距离不变。
          expect(cSim.x(100.0), closeTo(fSim.x(100.0), math.max(1.0, fSim.x(100.0) * 1e-3)), reason: 'v=$v: D 同源');
          final flutterDuration = _officialDuration(v) * _rate * 0.35;
          expect(fSim.isDone(flutterDuration + 0.01), isTrue, reason: 'v=$v: Flutter 时长口径核对');
          expect(cSim.isDone(flutterDuration + 0.01), isFalse, reason: 'v=$v: 真样条尾段比 Flutter 长(爬行尾)');
        }
      });

      test('样条形状:初速连续(dx(0)≈v0)、半程距离占比 ≈85.8%、速度单调不增', () {
        const physics = ElBrowserScrollPhysics();
        const metrics = _StubMetrics(pixels: 0.0, maxScrollExtent: 100000.0);
        final sim = physics.createBallisticSimulation(metrics, 4000.0)!;
        final duration = _officialDuration(4000.0);
        final distance = _officialDistance(4000.0);

        // 初速连续:松手瞬间速度不得跳变(查表首段弦斜率,容差 3%)。
        expect(sim.dx(0.0), closeTo(4000.0, 4000.0 * 0.03));
        // 真样条(P1=0.175/P2=0.35/tension 0.5)半程覆盖 ~85.8%(幂律近似为 80.5%,
        // 这条锁防退化回幂律)。
        expect(sim.x(duration / 2) / distance, closeTo(0.858, 0.01));
        // 速度单调不增且非负(减速曲线无回摆)。
        var prev = sim.dx(0.0);
        for (var i = 1; i <= 50; i++) {
          final v = sim.dx(duration * i / 50);
          expect(v, lessThanOrEqualTo(prev + 0.5), reason: '样条速度须单调衰减(t=${duration * i / 50})');
          expect(v, greaterThanOrEqualTo(-0.01));
          prev = v;
        }
        // 终点速度归零。
        expect(sim.dx(duration), closeTo(0.0, 1.0));
      });

      test('负速度对称:v0 = -3000 与 +3000 的位移量镜像', () {
        const physics = ElBrowserScrollPhysics();
        const metrics = _StubMetrics(pixels: 5000.0);
        final up = physics.createBallisticSimulation(metrics, -3000.0)!;
        final down = physics.createBallisticSimulation(metrics, 3000.0)!;

        final upDelta = up.x(1.0) - 5000.0;
        final downDelta = down.x(1.0) - 5000.0;
        expect(upDelta, closeTo(-downDelta, 0.1));
      });

      test('停止速度 = 0:低于官方 tolerance 门槛的低速照样成 fling、走完样条自然归零', () {
        const physics = ElBrowserScrollPhysics();
        const metrics = _StubMetrics(pixels: 500.0);
        // 官方门槛(20/dpr px/s)以下的低速不许判停(用户裁决 2026-07-20:
        // 停止速度 0)——尾段被 goBallistic 重启时低速续走,不在阈值处硬切。
        final sim = physics.createBallisticSimulation(metrics, 5.0);
        expect(sim, isNotNull, reason: '低速 fling 不得在阈值处硬停');
        final duration = _officialDuration(5.0);
        expect(
          sim!.isDone(duration + 1e-4),
          isTrue,
          reason: '样条时长随速度收敛(5px/s ≈ ${(duration * 1000).round()}ms),微 fling 瞬时走完',
        );
        expect(sim.dx(duration), closeTo(0.0, 0.5), reason: '速度连续归零,无阈值硬切');
        // 真 0 速度(hold / 收场的 goBallistic(0))仍返回 null → goIdle。
        expect(physics.createBallisticSimulation(metrics, 0.0), isNull);
      });

      test('已在边界且朝界外方向:无 fling', () {
        const physics = ElBrowserScrollPhysics();
        const atTop = _StubMetrics(pixels: 0.0);
        const atBottom = _StubMetrics(pixels: 10000.0);
        // 朝上撞顶
        expect(physics.createBallisticSimulation(atTop, -5000.0), isNull);
        // 朝下撞底
        expect(physics.createBallisticSimulation(atBottom, 5000.0), isNull);
        // 反向可 fling
        expect(physics.createBallisticSimulation(atTop, 5000.0), isNotNull);
        expect(physics.createBallisticSimulation(atBottom, -5000.0), isNotNull);
      });

      test('越界 → 走父级 ClampingScrollPhysics 的 spring 回弹', () {
        const physics = ElBrowserScrollPhysics();
        final applied = physics.applyTo(null); // 会自动 buildParent 到 ClampingScrollPhysics
        const outOfBounds = _StubMetrics(pixels: -100.0);
        final sim = applied.createBallisticSimulation(outOfBounds, 0.0);
        expect(sim, isNotNull, reason: '越界必须返回 spring simulation 回弹');
        // ClampingScrollPhysics 的 spring 是 ScrollSpringSimulation,
        // 起手朝 minScrollExtent(0)方向。
        final endPos = sim!.x(2.0);
        expect(endPos, closeTo(0.0, 5.0), reason: 'spring 应回到 minScrollExtent 附近');
      });
    });

    group('maxFlingDuration 时长封顶(规避 ROM 高刷保持窗口到期降 60Hz)', () {
      test('默认 4s;窗口内的速度(T ≤ 4s)完全不受影响', () {
        const physics = ElBrowserScrollPhysics();
        expect(physics.maxFlingDuration, elBrowserMaxFlingDuration);
        expect(physics.maxFlingDuration, const Duration(milliseconds: 4000));
        const metrics = _StubMetrics(pixels: 0.0, maxScrollExtent: 1000000.0);
        // 单手势上限 16000px/s 的自然时长 4.28s 会被压一点;12000 的 3.46s 不受影响。
        for (final v in const [1000.0, 8000.0, 12000.0]) {
          final T = _officialDuration(v);
          expect(T, lessThan(4.0), reason: 'v=$v 的自然时长应在窗口内');
          final sim = physics.createBallisticSimulation(metrics, v)!;
          expect(sim.isDone(T - 0.001), isFalse, reason: 'v=$v 未被截断');
          expect(sim.isDone(T + 0.001), isTrue, reason: 'v=$v 未被截断');
          expect(sim.x(T + 1.0), closeTo(_officialDistance(v), _officialDistance(v) * 1e-6 + 0.01));
        }
      });

      test('超限速度按 D = 0.35·v·T 反解距离,时长恰为上限', () {
        const physics = ElBrowserScrollPhysics();
        const metrics = _StubMetrics(pixels: 0.0, maxScrollExtent: 10000000.0);
        // 连甩叠加出的量级:v0=48000 自然 9.6s/16.1万px → 压到 4s/6.7万px。
        for (final v in const [24000.0, 48000.0]) {
          expect(_officialDuration(v), greaterThan(4.0), reason: 'v=$v 自然时长须超限才有意义');
          final sim = physics.createBallisticSimulation(metrics, v)!;
          expect(sim.isDone(3.999), isFalse);
          expect(sim.isDone(4.001), isTrue);
          // 恒等式反解:D' = inflexion·v·Tmax。
          expect(sim.x(5.0), closeTo(0.35 * v * 4.0, 0.35 * v * 4.0 * 1e-6 + 0.01));
          // 被压短但仍是显著位移(不得退化成短促停顿)。
          expect(sim.x(5.0), greaterThan(_officialDistance(v) * 0.35));
          expect(sim.x(5.0), lessThan(_officialDistance(v)));
        }
      });

      test('截断后曲线仍良性:初速连续、单调衰减、终点归零', () {
        const physics = ElBrowserScrollPhysics();
        const metrics = _StubMetrics(pixels: 0.0, maxScrollExtent: 10000000.0);
        final sim = physics.createBallisticSimulation(metrics, 48000.0)!;
        // 初速连续是关键:截断不得让松手瞬间速度跳变(查表首段弦斜率,容差 3%)。
        expect(sim.dx(0.0), closeTo(48000.0, 48000.0 * 0.03));
        var prev = sim.dx(0.0);
        for (var i = 1; i <= 50; i++) {
          final v = sim.dx(4.0 * i / 50);
          expect(v, lessThanOrEqualTo(prev + 0.5), reason: '截断后速度仍须单调衰减');
          expect(v, greaterThanOrEqualTo(-0.01));
          prev = v;
        }
        expect(sim.dx(4.0), closeTo(0.0, 1.0), reason: '终点速度归零(非硬切留残速)');
        // 半程距离占比与未截断样条一致(归一化形状不变)。
        expect(sim.x(2.0) / sim.x(5.0), closeTo(0.858, 0.01));
      });

      test('Duration.zero = 不限,退回纯官方样条时长', () {
        const physics = ElBrowserScrollPhysics(maxFlingDuration: Duration.zero);
        const metrics = _StubMetrics(pixels: 0.0, maxScrollExtent: 10000000.0);
        final T = _officialDuration(48000.0);
        final sim = physics.createBallisticSimulation(metrics, 48000.0)!;
        expect(sim.isDone(T - 0.01), isFalse);
        expect(sim.isDone(T + 0.01), isTrue);
        expect(sim.x(T + 1.0), closeTo(_officialDistance(48000.0), _officialDistance(48000.0) * 1e-6 + 0.01));
      });

      test('flingVelocityAt 与截断一致(拖拽层 boost 判活跃用同一口径)', () {
        const physics = ElBrowserScrollPhysics();
        // 4s 上限之后视为已结束,不得再报非零速度。
        expect(physics.flingVelocityAt(startVelocity: 48000.0, elapsedSeconds: 4.01), 0.0);
        expect(physics.flingVelocityAt(startVelocity: 48000.0, elapsedSeconds: 3.9), greaterThan(0.0));
        // 截断使同一时刻速度低于未截断版本(曲线更陡)。
        const uncapped = ElBrowserScrollPhysics(maxFlingDuration: Duration.zero);
        expect(
          physics.flingVelocityAt(startVelocity: 48000.0, elapsedSeconds: 2.0),
          lessThan(uncapped.flingVelocityAt(startVelocity: 48000.0, elapsedSeconds: 2.0)),
        );
      });

      test('自定义上限生效', () {
        const physics = ElBrowserScrollPhysics(maxFlingDuration: Duration(milliseconds: 1500));
        const metrics = _StubMetrics(pixels: 0.0, maxScrollExtent: 1000000.0);
        final sim = physics.createBallisticSimulation(metrics, 16000.0)!;
        expect(sim.isDone(1.499), isFalse);
        expect(sim.isDone(1.501), isTrue);
        expect(sim.x(2.0), closeTo(0.35 * 16000.0 * 1.5, 1.0));
      });
    });

    group('maxFlingVelocity + FlingBooster 连甩', () {
      test('单手势上限默认 elBrowserMaxFlingVelocity(16000,官方 8000 的 2 倍)', () {
        const physics = ElBrowserScrollPhysics();
        expect(physics.maxFlingVelocity, elBrowserMaxFlingVelocity);
        expect(physics.maxFlingVelocity, 16000.0);
        // 明确不再沿父链落到官方上限。
        expect(physics.maxFlingVelocity, kMaxFlingVelocity * 2);
      });

      test('maxFlingVelocity 可显式覆盖', () {
        const physics = ElBrowserScrollPhysics(maxFlingVelocity: 20000.0);
        expect(physics.maxFlingVelocity, 20000.0);
      });

      test('boost 全额叠加(官方 velocity += previous):carriedMomentum(v) = v', () {
        const physics = ElBrowserScrollPhysics();
        expect(physics.carriedMomentum(5000.0), closeTo(5000.0, 0.01));
        expect(physics.carriedMomentum(-8000.0), closeTo(-8000.0, 0.01));
      });

      test('低于 350px/s 门槛不 boost(官方 kMinBoostFlingSpeed)', () {
        const physics = ElBrowserScrollPhysics();
        expect(physics.carriedMomentum(349.0), 0.0);
        expect(physics.carriedMomentum(-200.0), 0.0);
        expect(physics.carriedMomentum(0.0), 0.0);
        // 门槛之上全额通过。
        expect(physics.carriedMomentum(351.0), closeTo(351.0, 0.01));
        expect(physics.carriedMomentum(-351.0), closeTo(-351.0, 0.01));
      });

      test('默认无 boostCap(官方 FlingBooster 不设上限);显式 cap 生效', () {
        const uncapped = ElBrowserScrollPhysics();
        expect(uncapped.carriedMomentum(50000.0), closeTo(50000.0, 0.01));
        const capped = ElBrowserScrollPhysics(boostCap: 12000.0);
        expect(capped.carriedMomentum(20000.0), closeTo(12000.0, 0.01));
        expect(capped.carriedMomentum(-20000.0), closeTo(-12000.0, 0.01));
        expect(capped.carriedMomentum(10000.0), closeTo(10000.0, 0.01));
      });

      test('applyTo 保留所有参数', () {
        const physics = ElBrowserScrollPhysics(
          friction: 0.02,
          maxFlingVelocity: 25000.0,
          maxFlingDuration: Duration(milliseconds: 2500),
          boostFactor: 0.7,
          boostCap: 15000.0,
          boostMinVelocity: 400.0,
        );
        final applied = physics.applyTo(null);
        expect(applied.friction, 0.02);
        expect(applied.maxFlingVelocity, 25000.0);
        expect(applied.maxFlingDuration, const Duration(milliseconds: 2500));
        expect(applied.boostFactor, 0.7);
        expect(applied.boostCap, 15000.0);
        expect(applied.boostMinVelocity, 400.0);
      });

      test('ElFlingBoostSpec 常量:150px/s 滚动门/50ms 窗口(官方 FlingBooster)', () {
        const physics = ElBrowserScrollPhysics();
        expect(physics.boostMinScrollVelocity, 150.0);
        expect(physics.boostTimeout, const Duration(milliseconds: 50));
      });

      test('combineBoostedVelocity:等差全额叠加不塌方,受 boostCap 约束', () {
        const physics = ElBrowserScrollPhysics();
        // 官方 velocity += previous_fling_starting_velocity。
        expect(physics.combineBoostedVelocity(5000.0, 8000.0), closeTo(13000.0, 0.01));
        expect(physics.combineBoostedVelocity(-5000.0, -8000.0), closeTo(-13000.0, 0.01));
        // 连甩:8000 → 16000 → 24000(等差;官方 carried 路径会在 16000 后
        // 因 0.5× 门整体丢弃塌回 8000,此断言防那条路径回归)。
        var v = 8000.0;
        v = physics.combineBoostedVelocity(8000.0, v);
        expect(v, closeTo(16000.0, 0.01));
        v = physics.combineBoostedVelocity(8000.0, v);
        expect(v, closeTo(24000.0, 0.01));
        // cap 版本 clamp。
        const capped = ElBrowserScrollPhysics(boostCap: 20000.0);
        expect(capped.combineBoostedVelocity(8000.0, 16000.0), closeTo(20000.0, 0.01));
      });

      test('flingVelocityAt:样条速度采样,起点≈v0、结束后为 0', () {
        const physics = ElBrowserScrollPhysics();
        final duration = _officialDuration(6000.0);
        // 起点速度连续(查表首段弦斜率,容差 3%)。
        expect(physics.flingVelocityAt(startVelocity: 6000.0, elapsedSeconds: 0.0), closeTo(6000.0, 6000.0 * 0.03));
        // 中段仍在衰减(0 < v < v0)。
        final mid = physics.flingVelocityAt(startVelocity: 6000.0, elapsedSeconds: duration / 2);
        expect(mid, greaterThan(0.0));
        expect(mid, lessThan(6000.0));
        // 负速度符号跟随。
        expect(
          physics.flingVelocityAt(startVelocity: -6000.0, elapsedSeconds: duration / 2),
          closeTo(-mid, mid * 0.01),
        );
        // 结束后为 0。
        expect(physics.flingVelocityAt(startVelocity: 6000.0, elapsedSeconds: duration + 0.1), 0.0);
        expect(physics.flingVelocityAt(startVelocity: 0.0, elapsedSeconds: 0.0), 0.0);
      });
    });

    group('端到端:ElScrollView + ElBrowserScrollPhysics', () {
      testWidgets('fling 结束后的位移量对齐 simulation 解析解', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 200,
              height: 300,
              child: ElScrollView(
                controller: controller,
                physics: const ElBrowserScrollPhysics(),
                children: List<Widget>.generate(
                  80,
                  (i) => ElView(
                    key: ValueKey('i-$i'),
                    style: ElStyle(width: 200, height: 60, backgroundColor: Color(0xff222222 + i)),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // 起 fling(velocity ~2500 px/s)。官方公式 D(2500) ≈ 998px;手势层
        // 起手动量测算有偏差,锁量级区间——同时排除旧指数模型(同速 ~1667px)
        // 与"过短"退化。
        await tester.fling(find.byType(ElScrollView), const Offset(0, -300), 2500);
        await tester.pumpAndSettle();

        final expected = _officialDistance(2500.0);
        expect(controller.offset, greaterThan(expected * 0.6), reason: '位移量级须落在官方 D(v) 附近(下界)');
        expect(controller.offset, lessThan(expected * 1.5), reason: '位移量级须落在官方 D(v) 附近(上界,防指数模型回归)');
      });

      testWidgets('FlingBooster 连甩:活跃 fling 上的同向再甩速度等差叠加、突破单手势上限', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 200,
              height: 600,
              child: ElScrollView(
                controller: controller,
                physics: const ElBrowserScrollPhysics(),
                children: List<Widget>.generate(
                  2000,
                  (i) => ElView(
                    key: ValueKey('i-$i'),
                    style: ElStyle(width: 200, height: 60, backgroundColor: Color(0xff222222 + i)),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final target = find.byType(ElScrollView);
        // 基线:单甩(6000px/s)冷启动的总位移。
        await tester.fling(target, const Offset(0, -300), 6000);
        await tester.pumpAndSettle();
        final singleFlingTravel = controller.offset;
        expect(singleFlingTravel, greaterThan(0));

        // 复位后连甩:第一甩起飞,fling 早期(~10 帧,速度仍高)落下第二甩。
        controller.jumpTo(0);
        await tester.pump();
        await tester.fling(target, const Offset(0, -300), 6000);
        await tester.pump(); // ballistic 起飞
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final beforeSecond = controller.offset;
        expect(beforeSecond, lessThan(singleFlingTravel), reason: '第二甩必须落在第一 fling 进行中');
        await tester.fling(target, const Offset(0, -300), 6000);
        await tester.pumpAndSettle();
        final boostedTravel = controller.offset;

        // 无 boost 的两次独立甩位移 ≈ 2×单甩(第二甩打断第一甩会更小)。
        // boost 后第二 fling 起始速度 ≈ 6000 + 6000 = 12000,样条距离 ∝ v^1.74
        // → 第二段单独 ≈ 3.3×单甩;总位移显著超过 2×单甩即证明叠加生效且未被
        // 官方 carried 的 0.5× 门/单手势 clamp 吃掉。
        expect(boostedTravel, greaterThan(singleFlingTravel * 2.4), reason: '连甩总位移须显著超过两次独立 fling(等差叠加生效)');
      });

      testWidgets('FlingBooster 反向甩断链:不叠加、不反向加速', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 200,
              height: 600,
              child: ElScrollView(
                controller: controller,
                physics: const ElBrowserScrollPhysics(),
                children: List<Widget>.generate(
                  2000,
                  (i) => ElView(
                    key: ValueKey('i-$i'),
                    style: ElStyle(width: 200, height: 60, backgroundColor: Color(0xff222222 + i)),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final target = find.byType(ElScrollView);

        // 反向基线:静止时朝回甩 3000 的位移量。
        controller.jumpTo(30000);
        await tester.pump();
        await tester.fling(target, const Offset(0, 300), 3000);
        await tester.pumpAndSettle();
        final coldReverseTravel = 30000 - controller.offset;
        expect(coldReverseTravel, greaterThan(0));

        // 前进 fling 进行中反向甩:必须按新手势独立起飞(位移量 ≈ 冷启动反甩),
        // 不得叠加前一 fling 速度(等差叠加若未判同向会放大反甩)。
        controller.jumpTo(30000);
        await tester.pump();
        await tester.fling(target, const Offset(0, -300), 6000);
        await tester.pump();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final beforeReverse = controller.offset;
        await tester.fling(target, const Offset(0, 300), 3000);
        await tester.pumpAndSettle();
        final reverseTravel = beforeReverse - controller.offset;
        expect(reverseTravel, greaterThan(0), reason: '反向甩须立即反向滚动');
        expect(reverseTravel, lessThan(coldReverseTravel * 1.3), reason: '反向甩不得携带前一 fling 的动量(断链)');
      });
    });
  });

  group('平滑指针滚动', () {
    tearDown(SmoothPointerScrollController.debugResetTouchpadSession);

    testWidgets('touchpad pointer scroll session is shared across controllers', (tester) async {
      final context = await _pumpScrollContext(tester);
      final outer = _PointerScrollHarness(context);
      final inner = _PointerScrollHarness(context);
      try {
        outer.controller.applyPointerScroll(
          const PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, 12),
            timeStamp: Duration(milliseconds: 1),
          ),
          12,
        );

        expect(outer.position.pixels, 12);
        expect(SmoothPointerScrollController.debugTouchpadSessionActive, isTrue);

        inner.controller.applyPointerScroll(
          const PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, 48),
            timeStamp: Duration(milliseconds: 16),
          ),
          48,
        );

        expect(inner.position.pixels, 48);
      } finally {
        outer.dispose();
        inner.dispose();
        SmoothPointerScrollController.debugResetTouchpadSession();
      }
    }, skip: _skipMouseWheelClassificationTests);

    testWidgets('touchpad pointer scroll session expires after the burst window', (tester) async {
      final context = await _pumpScrollContext(tester);
      final outer = _PointerScrollHarness(context);
      final inner = _PointerScrollHarness(context);
      try {
        outer.controller.applyPointerScroll(
          const PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, 12),
            timeStamp: Duration(milliseconds: 1),
          ),
          12,
        );

        await tester.pump(const Duration(milliseconds: 81));
        expect(SmoothPointerScrollController.debugTouchpadSessionActive, isFalse);

        inner.controller.applyPointerScroll(
          const PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, 48),
            timeStamp: Duration(milliseconds: 100),
          ),
          48,
        );

        expect(inner.position.pixels, 0);
      } finally {
        outer.dispose();
        inner.dispose();
        SmoothPointerScrollController.debugResetTouchpadSession();
      }
    }, skip: _skipMouseWheelClassificationTests);

    testWidgets('canConsumeDelta remains true while animated pixels can still move', (tester) async {
      final context = await _pumpScrollContext(tester);
      final harness = _PointerScrollHarness(context);
      try {
        harness.position.jumpTo(120);

        harness.controller.applyPointerScroll(
          const PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, 480),
            timeStamp: Duration(milliseconds: 1),
          ),
          480,
        );
        await tester.pump();

        expect(harness.position.pixels, lessThan(harness.position.maxScrollExtent));
        expect(harness.controller.canConsumeDelta(480), isTrue);
      } finally {
        harness.dispose();
      }
    }, skip: _skipMouseWheelClassificationTests);

    testWidgets('reset cancels active wheel activity without leaving scroll state active', (tester) async {
      final context = await _pumpScrollContext(tester);
      final harness = _PointerScrollHarness(context);
      try {
        harness.position.jumpTo(120);

        harness.controller.applyPointerScroll(
          const PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, 480),
            timeStamp: Duration(milliseconds: 1),
          ),
          480,
        );
        await tester.pump();

        final offsetAfterStart = harness.position.pixels;
        expect(harness.position.isScrollingNotifier.value, isTrue);

        harness.controller.reset();
        await tester.pump(const Duration(milliseconds: 120));

        expect(harness.position.isScrollingNotifier.value, isFalse);
        expect(harness.position.pixels, offsetAfterStart);
      } finally {
        harness.dispose();
      }
    }, skip: _skipMouseWheelClassificationTests);

    testWidgets('fallback pointer scroll applies synchronously without uncancelable animation', (tester) async {
      final position = _FallbackScrollPosition();
      final controller = SmoothPointerScrollController(
        // 控制器的 algorithm 默认 null=直滚（平台分派在 behavior 层）；动画
        // 路径单测显式注入 Chromium 档。
        algorithm: const ElChromiumSmoothScroll(),
        position: () => position,
        targetOffsetForDelta: (delta, {double? from}) {
          final base = from ?? position.pixels;
          return (base + delta).clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
        },
      );

      try {
        controller.applyPointerScroll(
          const PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, 120),
            timeStamp: Duration(milliseconds: 1),
          ),
          120,
        );

        expect(position.pixels, 120);
        expect(position.setPixelsCalls, 1);
        expect(position.animateToCalls, 0);

        controller.reset();
        await tester.pump(const Duration(milliseconds: 120));

        expect(position.pixels, 120);
        expect(position.animateToCalls, 0);
      } finally {
        controller.dispose();
      }
    }, skip: _skipMouseWheelClassificationTests);
  });

  group('内容速度', () {
    testWidgets('惯性只推进头部时，正文速度为已测得的零', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_ProbeState>();
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 200, height: 200),
              child: ElScrollView(
                controller: controller,
                physics: const ElClampingScrollPhysics(),
                scrollbar: const ElNoScrollBar(),
                children: [_Probe(key: key, correct: false)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      (controller.position as ScrollPositionWithSingleContext).goBallistic(1200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(key.currentState!.header, greaterThan(0));
      expect(controller.offset, 0);
      expect(key.currentState!.scrollSnapshot.activity, ElScrollActivityType.ballistic);
      expect(key.currentState!.scrollSnapshot.velocity, 0);
      expect(key.currentState!.scrollSnapshot.velocitySource, ElScrollVelocitySource.frameEstimate);
      controller.jumpTo(0);
      expect(key.currentState!.scrollSnapshot.velocity, 0);
      expect(key.currentState!.scrollSnapshot.velocitySource, ElScrollVelocitySource.stationary);
      expect(tester.takeException(), isNull);
    });

    testWidgets('正文写入回调的新 raw 命令先结算旧样本，旧通知不再覆盖来源', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final key = GlobalKey<_ProbeState>();
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 200, height: 200),
              child: ElScrollView(
                controller: controller,
                physics: const ElClampingScrollPhysics(),
                smoothScroll: const _Linear(),
                scrollbar: const ElNoScrollBar(),
                children: [_Probe(key: key, correct: false)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      var taken = false;
      controller.addListener(() {
        if (taken || controller.offset <= 0) return;
        taken = true;
        controller.jumpTo(300);
      });
      controller.dispatchPointerScroll(
        PointerScrollEvent(
          position: const Offset(100, 100),
          kind: PointerDeviceKind.mouse,
          scrollDelta: const Offset(0, 100),
          timeStamp: tester.binding.currentSystemFrameTimeStamp,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      final motion = key.currentState!.updates.where((sample) => sample.motionDelta != 0).toList();
      expect(motion.map((sample) => sample.motionDelta), [10, 290]);
      expect(motion.map((sample) => sample.cause), [
        ElScrollUpdateCause.userInput,
        ElScrollUpdateCause.externalCommand,
      ]);
      expect(motion.first.velocity, closeTo(200, .001));
      expect(motion.last.velocity, isNull);
      expect(motion.last.sessionId, isNull);
      expect(controller.offset, 300);
      expect(tester.takeException(), isNull);
    }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);

    for (final correction in [false, true]) {
      testWidgets('正文速度只来自实际分账位移，layout correction=$correction 不参与', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final key = GlobalKey<_ProbeState>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 200, height: 200),
                child: ElScrollView(
                  controller: controller,
                  physics: const ElClampingScrollPhysics(),
                  smoothScroll: const _Linear(),
                  scrollbar: const ElNoScrollBar(),
                  children: [_Probe(key: key, correct: correction)],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        controller.dispatchPointerScroll(
          PointerScrollEvent(
            position: const Offset(100, 100),
            kind: PointerDeviceKind.mouse,
            scrollDelta: const Offset(0, 100),
            timeStamp: tester.binding.currentSystemFrameTimeStamp,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final first = key.currentState!.scrollSnapshot;
        expect(first.contentOffset, correction ? 40 : 10);
        expect(first.motionDelta, 10);
        expect(first.correctionDelta, correction ? 30 : 0);
        expect(first.velocitySource, ElScrollVelocitySource.frameEstimate);
        expect(first.velocity, closeTo(200, .001), reason: '前50px中头部接受40px，正文仅移动10px');
        await tester.pump(const Duration(milliseconds: 50));
        final second = key.currentState!.scrollSnapshot;
        expect(second.velocity, closeTo(1000, .001));
        expect(second.timeStamp! - first.timeStamp!, const Duration(milliseconds: 50));
        expect(second.sessionId, first.sessionId);
        await tester.pumpAndSettle();
        expect(key.currentState!.scrollSnapshot.velocity, 0);
        expect(tester.takeException(), isNull);
      }, skip: !ElPlatform.isDesktop || ElPlatform.isMacOS);
    }
  });

  group('越界与按住停止', () {
    const scrollKey = ValueKey('scroll');

    Widget shell({
      required ScrollController controller,
      required List<OverscrollNotification> collected,
      int itemCount = 20,
      double itemExtent = 40,
      ScrollPhysics? physics,
    }) {
      return MaterialApp(
        scrollBehavior: const _NoChromeBehavior(),
        home: Align(
          alignment: Alignment.topLeft,
          child: NotificationListener<OverscrollNotification>(
            onNotification: (n) {
              collected.add(n);
              return false;
            },
            child: SizedBox(
              key: scrollKey,
              width: 120,
              height: 100,
              child: ElScrollView(
                controller: controller,
                physics: physics ?? const ClampingScrollPhysics(),
                children: List<Widget>.generate(
                  itemCount,
                  (i) => ElView(
                    key: ValueKey('item-$i'),
                    style: ElStyle(width: 120, height: itemExtent, backgroundColor: Color(0xff222222 + i)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget pipelineShell({
      required ScrollController controller,
      required List<OverscrollNotification> collected,
      required List<double> overflowSeen,
      int itemCount = 20,
      double itemExtent = 40,
    }) {
      return MaterialApp(
        scrollBehavior: const _NoChromeBehavior(),
        home: Align(
          alignment: Alignment.topLeft,
          child: NotificationListener<OverscrollNotification>(
            onNotification: (n) {
              collected.add(n);
              return false;
            },
            child: SizedBox(
              width: 120,
              height: 100,
              child: ElView(
                // dragProxy-only 宿主（无 drag 回调 → 无 drag shape → 不与 driver 竞争）
                event: ElEvent(
                  dragProxy: ElDragProxy(
                    axis: Axis.vertical,
                    onDragPreUpdate: (_) {},
                    onDragOverflow: (e) {
                      final d = e.remainingPrimaryDelta(.vertical);
                      if (d.abs() > precisionErrorTolerance) {
                        overflowSeen.add(d);
                        e.consumePrimaryDelta(.vertical, d);
                      }
                    },
                  ),
                ),
                child: SizedBox(
                  key: scrollKey,
                  width: 120,
                  height: 100,
                  child: ElScrollView(
                    controller: controller,
                    physics: const ClampingScrollPhysics(),
                    children: List<Widget>.generate(
                      itemCount,
                      (i) => ElView(
                        key: ValueKey('pipe-item-$i'),
                        style: ElStyle(width: 120, height: itemExtent, backgroundColor: Color(0xff444444 + i)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('single scroll at top: down-drag reports negative overscroll on every dragUpdate frame', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final collected = <OverscrollNotification>[];

      await tester.pumpWidget(shell(controller: controller, collected: collected));
      await tester.pump();
      expect(controller.offset, 0);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();
      // 首帧 accept（dragStart 纯信号，seed=0 不触达 didOverscrollBy）。
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      // 后续三帧 dragUpdate 全部在顶部越界：吞余量 + didOverscrollBy。
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      await gesture.up();
      await tester.pump();

      // 每帧 dragUpdate 都携带越界量。
      expect(collected.length, greaterThanOrEqualTo(3));
      // 下拉在顶部 → applyBoundaryConditions 返回 **负** overscroll（朝 start 方向）。
      expect(collected.every((n) => n.overscroll < 0), isTrue, reason: 'down-drag at top overscroll polarity');
      // 累计越界量 ≈ 3 帧 × 40px（首帧 dragStart 不累计）。
      final total = collected.fold<double>(0, (a, n) => a + n.overscroll.abs());
      expect(total, closeTo(120, 1.0), reason: 'cumulative overscroll ≈ swallowed frame deltas');
    });

    testWidgets('single scroll at bottom: up-drag reports positive overscroll', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final collected = <OverscrollNotification>[];

      await tester.pumpWidget(shell(controller: controller, collected: collected));
      await tester.pump();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();
      // 首帧 accept + 后续三帧 dragUpdate 越界。
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      await gesture.up();
      await tester.pump();

      expect(collected.length, greaterThanOrEqualTo(3));
      // 上拉在底部 → overscroll 正号（朝 end 方向）。
      expect(collected.every((n) => n.overscroll > 0), isTrue, reason: 'up-drag at end overscroll polarity');
    });

    testWidgets('mid-scroll drag does not fire OverscrollNotification', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final collected = <OverscrollNotification>[];

      await tester.pumpWidget(shell(controller: controller, collected: collected));
      await tester.pump();
      controller.jumpTo(200);
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();
      // 从 200 上拉 3 帧 × 20 = 60 → 260，未到 max（20*40=800）也未到 0，全程在界内。
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(collected, isEmpty, reason: 'no boundary hit → no OverscrollNotification');
    });

    testWidgets('pipeline route: overscroll delta bubbles to overflow instead of firing notification', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final collected = <OverscrollNotification>[];
      final overflowSeen = <double>[];

      await tester.pumpWidget(pipelineShell(controller: controller, collected: collected, overflowSeen: overflowSeen));
      await tester.pump();
      expect(controller.offset, 0);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();
      // accept + 3 帧 dragUpdate 全部在顶下拉。
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // 管线路径下越界归 overflow 分账，不派 OverscrollNotification。
      expect(collected, isEmpty, reason: 'pipeline path routes residual through overflow stage');
      // overflow 至少拿到 3 帧余量。
      expect(overflowSeen.length, greaterThanOrEqualTo(3));
      expect(overflowSeen.every((d) => d > 0), isTrue);
    });

    testWidgets('ballistic path lands cleanly at boundary (fling-in-tester overscroll timing is fragile)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final collected = <OverscrollNotification>[];

      await tester.pumpWidget(
        shell(controller: controller, collected: collected, physics: const BouncingScrollPhysics()),
      );
      await tester.pump();
      controller.jumpTo(120);
      await tester.pump();

      // 向下 fling（finger 向下 = 到顶方向）。
      await tester.fling(find.byKey(scrollKey), const Offset(0, 400), 2500);
      await tester.pumpAndSettle();

      // ballistic 终态：稳定停在 min（0）——BouncingScrollSimulation 走完后
      // spring-back 到界内。
      expect(controller.offset, 0.0);
    });

    testWidgets('pointer down during fling stops ballistic; tap without drag does not freeze scroll', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final collected = <OverscrollNotification>[];

      await tester.pumpWidget(shell(controller: controller, collected: collected, itemCount: 80));
      await tester.pump();

      // 起个 fling 让 ballistic 跑起来。
      await tester.fling(find.byKey(scrollKey), const Offset(0, -260), 3000);
      // 让 ballistic 跑一帧，确认在运动中。
      await tester.pump(const Duration(milliseconds: 16));
      final offsetDuringBallistic = controller.offset;
      expect(offsetDuringBallistic, greaterThan(0));

      // pointer down 建立 hold → activity 从 ballistic 转成 hold（isScrolling=false）
      // → 后续帧 pixels 冻结（即使有 duration 也不再 apply ballistic）。
      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      final offsetAfterDown = controller.offset;
      // hold 期间 pixels 不动（也可能 hold 之后 goBallistic(0) 立刻 idle → 也不动）。
      expect(offsetAfterDown, offsetDuringBallistic, reason: 'hold freezes ballistic pixels');

      // 纯 tap：直接 up，没有触发 dragStart。hold 应主动释放走 goBallistic(0) → idle。
      await gesture.up();
      await tester.pump();

      // 后续 fling 仍能推进（hold 不永久冻结）。
      await tester.fling(find.byKey(scrollKey), const Offset(0, -120), 2000);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        controller.offset,
        greaterThan(offsetAfterDown),
        reason: 'a bare tap must not leave a hold blocking the next fling',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('start jitter guard: 40px accept move applies zero at dragStart, next frame follows', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final collected = <OverscrollNotification>[];

      // itemCount 大到有 room 可滚，不到底。
      await tester.pumpWidget(shell(controller: controller, collected: collected, itemCount: 40));
      await tester.pump();
      // 起 offset 已经在界内 20，避免顶部越界干扰。
      controller.jumpTo(20);
      await tester.pump();
      final startOffset = controller.offset;

      final gesture = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();

      // 首帧 40px（远超 slop 18）→ accept 帧 dragStart 纯信号，position 不变。
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(
        controller.offset,
        startOffset,
        reason: 'accept frame is a pure lifecycle signal - no position jump even on 40px first move',
      );

      // 下一帧 40px → 首个 dragUpdate 帧正常 apply。
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(
        controller.offset,
        closeTo(startOffset + 40, 0.1),
        reason: 'first dragUpdate frame applies frame delta normally',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('反向越界', () {
    const scrollKey = ValueKey('reverse-lock');

    Future<List<double>> run(WidgetTester tester, Widget Function(ScrollController) build) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: Text('reverse-lock')),
            body: SizedBox.expand(child: build(c)),
          ),
        ),
      );
      await tester.pump();
      final offsets = <double>[];
      final g = await tester.createGesture(kind: .touch);
      addTearDown(g.removePointer);
      await g.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();
      // 阶段 1：顶边大幅下拉 8 帧 × 50px（全程越界，走吞余量分支）。
      for (var i = 0; i < 8; i++) {
        await g.moveBy(const Offset(0, 50));
        await tester.pump();
        offsets.add(c.offset);
      }
      // 阶段 2：不抬手反向上拖 20 帧 × 40px（跨越"一定距离"，必须持续跟手）。
      for (var i = 0; i < 20; i++) {
        await g.moveBy(const Offset(0, -40));
        await tester.pump();
        offsets.add(c.offset);
      }
      // 阶段 3：再改回向下 6 帧 × 40px（反向后再反转，仍须跟手）。
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(0, 40));
        await tester.pump();
        offsets.add(c.offset);
      }
      await g.up();
      await tester.pumpAndSettle();
      return offsets;
    }

    Widget officialShell(ScrollController c) =>
        ListView.builder(key: scrollKey, controller: c, itemCount: 200, itemBuilder: (_, i) => Text('row - $i'));

    Widget elShell(ScrollController c) => ElScrollView(
      key: scrollKey,
      controller: c,
      children: [for (var i = 0; i < 200; i++) ElView(key: ValueKey('rev-$i'), child: 'row - $i')],
    );

    void expectReverseParity(List<double> el, List<double> official, {required String scene}) {
      // 阶段 1（帧 0-7）：双方都被顶边夹死在 0。
      for (var i = 0; i < 8; i++) {
        expect(el[i], 0, reason: '$scene: overscroll phase pins offset at 0 (frame $i)');
      }
      // 阶段 2（帧 8-27）：反向必须每帧推进（冻结回归在此变平）。
      for (var i = 9; i < 28; i++) {
        expect(
          el[i],
          greaterThan(el[i - 1]),
          reason: '$scene: reverse drag must keep scrolling every frame (frame $i)\n  el=$el',
        );
      }
      // 阶段 3（帧 28-33）：再反转同样必须每帧推进（向回滚）。
      for (var i = 29; i < 34; i++) {
        expect(
          el[i],
          lessThan(el[i - 1]),
          reason: '$scene: second reversal must keep scrolling every frame (frame $i)\n  el=$el',
        );
      }
      // 逐帧与官方等值（值域锁定，防"能动但幅度漂移"）。
      for (var i = 0; i < el.length; i++) {
        expect(
          el[i],
          closeTo(official[i], 0.01),
          reason: '$scene: offset diverges from official at frame $i\n  el=$el\n  official=$official',
        );
      }
    }

    testWidgets('ElScrollView: overscroll then reverse without lift tracks official frame by frame', (tester) async {
      final official = await run(tester, officialShell);
      final el = await run(tester, elShell);
      expectReverseParity(el, official, scene: 'simple');
    });

    Widget elVirtualShell(ScrollController c) => buildVirtualTestViewBuilder(
      key: scrollKey,
      controller: c,
      itemCount: 200,
      itemBuilder: (_, i) => ElView(key: ValueKey('rev-v-$i'), child: 'row - $i'),
    );

    Widget videoVirtualShell(ScrollController c) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(gestureSettings: _androidDeviceSettings),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('VirtualScroll - Text'),
            actions: const [Switch(value: false, onChanged: null)],
          ),
          body: SizedBox.expand(
            child: buildVirtualTestView(
              key: scrollKey,
              controller: c,
              padding: const .only(top: 8),
              children: [for (var i = 0; i < 360; i++) _VideoCard(index: i)],
            ),
          ),
        ),
      ),
    );

    Widget lowCacheVideoVirtualShell(ScrollController c) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(gestureSettings: _androidDeviceSettings),
        child: Scaffold(
          appBar: AppBar(title: const Text('VirtualScroll - Text')),
          body: SizedBox.expand(
            child: buildVirtualTestView(
              key: scrollKey,
              controller: c,
              cacheExtent: 0,
              padding: const .only(top: 8),
              children: [for (var i = 0; i < 360; i++) _VideoCard(key: ValueKey('low-cache-card-$i'), index: i)],
            ),
          ),
        ),
      ),
    );

    testWidgets('虚拟管线: overscroll then reverse without lift tracks official frame by frame', (tester) async {
      final official = await run(tester, officialShell);
      final el = await run(tester, elVirtualShell);
      expectReverseParity(el, official, scene: 'virtual');
    });

    testWidgets('虚拟管线: video-like mid-list reverse drag does not freeze before finger up', (tester) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(videoVirtualShell(c));
      await tester.pump();
      c.jumpTo(720);
      await tester.pump();
      await tester.pump();

      final startOffset = c.offset;
      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 812);
      addTearDown(g.removePointer);
      var t = tester.binding.currentSystemFrameTimeStamp;

      Future<double> move(double dy) async {
        t += _frame;
        await g.moveBy(Offset(0, dy), timeStamp: t);
        await tester.pump(_frame);
        return c.offset;
      }

      await g.down(tester.getCenter(find.byKey(scrollKey)) + const Offset(0, 120), timeStamp: t);
      await tester.pump(_frame);

      final down = <double>[];
      for (var i = 0; i < 8; i++) {
        down.add(await move(32));
      }

      final reverseUp = <double>[];
      for (var i = 0; i < 22; i++) {
        reverseUp.add(await move(-28));
      }

      final reverseDown = <double>[];
      for (var i = 0; i < 10; i++) {
        reverseDown.add(await move(26));
      }

      await g.up(timeStamp: t + _frame);
      await tester.pumpAndSettle();

      expect(down.last, lessThan(startOffset - 120), reason: '视频同构阶段 1：下拖必须先让 virtual list 明显向回滚');
      expect(reverseUp.last, greaterThan(down.last + 420), reason: '阶段 2：同一根手指反向上拖一段距离后仍必须持续向下滚，不能死停');
      expect(
        reverseUp.last - reverseUp[reverseUp.length - 7],
        greaterThan(120),
        reason: '阶段 2 尾部仍应持续推进；冻结 bug 会在这里变成近似 0 位移',
      );
      expect(reverseDown.last, lessThan(reverseUp.last - 150), reason: '阶段 3：不抬手再改回下拖，滚动仍必须恢复反向推进');
      expect(
        reverseDown[reverseDown.length - 7] - reverseDown.last,
        greaterThan(90),
        reason: '阶段 3 尾部也不能卡死；若上下都无法滚动，这里会变平',
      );
    });

    testWidgets('虚拟管线: drag keeps scrolling after the pressed child unmounts', (tester) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      await tester.pumpWidget(lowCacheVideoVirtualShell(c));
      await tester.pump();
      await tester.pump();

      final g = await tester.createGesture(kind: PointerDeviceKind.touch, pointer: 913);
      addTearDown(g.removePointer);
      await g.down(tester.getCenter(find.byKey(const ValueKey('low-cache-card-0'))));
      await tester.pump();

      final offsets = <double>[];
      for (var i = 0; i < 26; i++) {
        await g.moveBy(const Offset(0, -24));
        await tester.pump();
        offsets.add(c.offset);
      }

      expect(
        find.byKey(const ValueKey('low-cache-card-0')),
        findsNothing,
        reason: '前置：最初按下的卡片必须已经离开 virtual mounted window，才能覆盖真实长拖路径',
      );

      final tailBeforeReverse = offsets.last;
      final reverseOffsets = <double>[];
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(0, 24));
        await tester.pump();
        reverseOffsets.add(c.offset);
      }

      await g.up();
      await tester.pumpAndSettle();

      expect(offsets.last, greaterThan(420), reason: '首按卡片卸载前后，同一根手指向上拖必须持续滚动');
      expect(
        offsets.last - offsets[offsets.length - 8],
        greaterThan(120),
        reason: '首按卡片卸载后的尾部 move 仍必须生效；事件序列若随 child detach 被释放，这里会变平',
      );
      expect(reverseOffsets.last, lessThan(tailBeforeReverse - 120), reason: '首按 child 已卸载后，同一根手指反向拖也必须继续响应，不能上下都失效');
    });
  });

  group('拉伸效果', () {
    const scrollKey = ValueKey('scroll-parity');

    Widget shell({required Widget child, required _Trace trace}) {
      return MaterialApp(
        scrollBehavior: const _NoChromeBehavior(),
        home: Align(
          alignment: .topLeft,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              switch (n) {
                case OverscrollNotification(:final overscroll):
                  trace.overscrolls.add(overscroll);
                case ScrollStartNotification():
                  trace.scrollStarts++;
                case ScrollEndNotification():
                  trace.scrollEnds++;
                default:
                  break;
              }
              return false;
            },
            child: SizedBox(width: 120, height: 100, child: child),
          ),
        ),
      );
    }

    Widget officialShell(ScrollController c, _Trace trace) => shell(
      trace: trace,
      child: ListView.builder(
        key: scrollKey,
        controller: c,
        physics: const ClampingScrollPhysics(),
        itemCount: 20,
        itemExtent: 40,
        itemBuilder: (_, i) => SizedBox(width: 120, height: 40),
      ),
    );

    Widget elShell(ScrollController c, _Trace trace) => shell(
      trace: trace,
      // clamping 物理由 MaterialApp 级 _NoChromeBehavior 提供
      // （2026-07-21 瘦身：physics 参数已移除）,与官方侧同源。
      child: ElScrollView(
        key: scrollKey,
        controller: c,
        children: [
          for (var i = 0; i < 20; i++) ElView(key: ValueKey('parity-item-$i'), style: ElStyle(width: 120, height: 40)),
        ],
      ),
    );

    Future<_Trace> run(
      WidgetTester tester,
      Widget Function(ScrollController, _Trace) build, {
      required List<Offset> moves,
      double startOffset = 0,
    }) async {
      final c = ScrollController();
      addTearDown(c.dispose);
      final trace = _Trace();
      await tester.pumpWidget(build(c, trace));
      await tester.pump();
      if (startOffset != 0) {
        c.jumpTo(startOffset);
        await tester.pump();
      }
      trace.reset();
      final g = await tester.createGesture(kind: .touch);
      addTearDown(g.removePointer);
      await g.down(tester.getCenter(find.byKey(scrollKey)));
      await tester.pump();
      for (final m in moves) {
        await g.moveBy(m);
        await tester.pump();
      }
      await g.up();
      await tester.pump();
      return trace;
    }

    void expectParity(_Trace el, _Trace official, {required String scene}) {
      expect(official.scrollStarts, 1, reason: '$scene: official baseline sanity');
      expect(official.scrollEnds, 1, reason: '$scene: official baseline sanity');
      expect(el.scrollStarts, 1, reason: '$scene: El must not churn ScrollStart mid-gesture\n  el=$el');
      expect(
        el.scrollEnds,
        1,
        reason: '$scene: El must not churn ScrollEnd mid-gesture (stretch ratchet root cause)\n  el=$el',
      );
      expect(
        el.overscrolls.length,
        official.overscrolls.length - 1,
        reason:
            '$scene: frame count = official - 1 (seed=0 accept-frame contract)\n  el=${el.overscrolls}\n  official=${official.overscrolls}',
      );
      for (var i = 0; i < el.overscrolls.length; i++) {
        expect(
          el.overscrolls[i],
          closeTo(official.overscrolls[i], 0.01),
          reason:
              '$scene: per-frame overscroll value mismatch at frame $i\n  el=${el.overscrolls}\n  official=${official.overscrolls}',
        );
      }
    }

    testWidgets('top edge: 10 frames of 30px down-drag — notification stream matches official', (tester) async {
      final moves = List<Offset>.filled(10, const Offset(0, 30));
      final official = await run(tester, officialShell, moves: moves);
      final el = await run(tester, elShell, moves: moves);

      // 官方基线自检：顶边下拉全程越界，每帧负号（朝 start 方向）。
      expect(official.overscrolls, everyElement(lessThan(0)));
      expectParity(el, official, scene: 'top edge');
    });

    testWidgets('bottom edge: 10 frames of 30px up-drag — notification stream matches official', (tester) async {
      final moves = List<Offset>.filled(10, const Offset(0, -30));
      // 20×40 内容 / 100 视口 → maxScrollExtent = 700，两侧一致。
      final official = await run(tester, officialShell, moves: moves, startOffset: 700);
      final el = await run(tester, elShell, moves: moves, startOffset: 700);

      expect(official.overscrolls, everyElement(greaterThan(0)));
      expectParity(el, official, scene: 'bottom edge');
    });

    testWidgets('cross boundary: in-range then overscroll — notification stream matches official', (tester) async {
      final moves = List<Offset>.filled(8, const Offset(0, 30));
      final official = await run(tester, officialShell, moves: moves, startOffset: 50);
      final el = await run(tester, elShell, moves: moves, startOffset: 50);

      expect(official.overscrolls, everyElement(lessThan(0)));
      expectParity(el, official, scene: 'cross boundary');
    });
  });

  group('平滑滚动算法', () {
    const scrollKey = ValueKey('smooth-scroll');

    Widget shell(
      ScrollController controller, {
      ElSmoothScroll? smoothScroll,
      ElScrollbar? scrollbar,
      ElSmoothScroll? providerSmoothScroll,
    }) {
      final child = ElScrollView(
        key: scrollKey,
        controller: controller,
        smoothScroll: smoothScroll,
        scrollbar: scrollbar,
        children: [for (var i = 0; i < 100; i++) ElView(key: ValueKey('row-$i'), child: 'row - $i')],
      );
      return MaterialApp(
        home: ElViewProvider(
          smoothScrollBuilder: (_) => providerSmoothScroll,
          child: SizedBox(width: 300, height: 300, child: child),
        ),
      );
    }

    Future<void> wheel(WidgetTester tester, {double dy = 53.0}) async {
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(find.byKey(scrollKey)));
      await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
      await tester.pumpAndSettle();
    }

    Future<void> startWheel(WidgetTester tester, {double dy = 53.0}) async {
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(tester.getCenter(find.byKey(scrollKey)));
      await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
      await tester.pump();
    }

    test('SMOOTH-0: resolveDefaultSmoothScroll Windows 客户端默认 Windows 算法', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(resolveDefaultSmoothScroll(), isA<ElWindowsSmoothScroll>());

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(resolveDefaultSmoothScroll(), isNull);
    });

    test('SMOOTH-0b: Windows 10 算法结构性质——首格保原始步长、连击累加有封顶、时长恒定', () {
      // 手感数值（倍率/封顶档位/时长毫秒/缓动曲线）随时会被手调，不进断言；
      // 只验结构性质：首格 = 原始 delta、连击单调放大、深连击封顶、时长与
      // delta/速度无关。
      const algorithm = ElWindowsSmoothScroll();

      expect(algorithm.stepForEvent(53.0, 0), 53.0, reason: '首格保留平台原始滚动距离');
      expect(algorithm.stepForEvent(53.0, 1), greaterThan(algorithm.stepForEvent(53.0, 0)));
      expect(algorithm.stepForEvent(53.0, 2), greaterThan(algorithm.stepForEvent(53.0, 1)));
      expect(algorithm.stepForEvent(-53.0, 8), algorithm.stepForEvent(-53.0, 20), reason: '深连击步长封顶');
      expect(algorithm.stepForEvent(-53.0, 8), lessThan(0.0), reason: '方向跟随 delta 符号');
      expect(
        algorithm.segmentDuration(53.0, 0.0),
        algorithm.segmentDuration(480.0, 2400.0),
        reason: '固定时长档：与 delta / 在途速度无关',
      );
      expect(algorithm.segmentDuration(53.0, 0.0), greaterThan(Duration.zero));
    });

    testWidgets('SMOOTH-1: 容器 scrollBehavior 直配的算法接管步长决策', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller, smoothScroll: _FixedStepSmoothScroll(100.0)));

      // raw 53px：Chromium 默认保留 53px，fake 固定 100 → 两值互斥，
      // 证明算法真被消费。
      await wheel(tester);
      expect(controller.offset, closeTo(100.0, 0.5), reason: '直配 behavior 的算法 stepForEvent 必须接管步长');
    });

    testWidgets('SMOOTH-2: ElViewProvider 生效且被容器直配压过', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller, providerSmoothScroll: _FixedStepSmoothScroll(100.0)));
      await wheel(tester);
      expect(controller.offset, closeTo(100.0, 0.5), reason: 'Provider 默认算法生效');

      // 容器 smoothScroll 直配压过 Provider。
      await tester.pumpWidget(
        shell(
          controller,
          providerSmoothScroll: _FixedStepSmoothScroll(100.0),
          smoothScroll: _FixedStepSmoothScroll(200.0),
        ),
      );
      final before = controller.offset;
      await wheel(tester);
      expect(controller.offset - before, closeTo(200.0, 0.5), reason: '容器 smoothScroll 直配恒压过 Provider');
    });

    testWidgets('SMOOTH-3: 组件按平台选择默认算法，ElNoSmoothScroll 可关闭', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(shell(controller));
      await startWheel(tester);
      await tester.pump(const Duration(milliseconds: 60));
      // 曲线无关断言：中途值随缓动曲线（可手调手感）任意变化，只验"还在
      // 飞行中"（既没停在 0 也没瞬移到位），落点验整步抵达。
      expect(controller.offset, greaterThan(0.0), reason: 'Windows 默认档动画中途应已推进');
      expect(controller.offset, lessThan(52.5), reason: 'Windows 默认档不瞬跳，中途未抵达终点');
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(53.0, 0.5));

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await tester.pumpWidget(shell(controller));
      var before = controller.offset;
      await wheel(tester);
      expect(controller.offset - before, closeTo(53.0, 0.5), reason: '非 Windows 平台默认直滚');

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(shell(controller, smoothScroll: const ElNoSmoothScroll()));
      before = controller.offset;
      await wheel(tester);
      expect(controller.offset - before, closeTo(53.0, 0.5), reason: 'ElNoSmoothScroll 显式关闭 Windows 平滑滚动');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('SMOOTH-4: controller 转发外部 wheel 沿用视口平滑编排', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller, smoothScroll: const _FixedStepSmoothScroll(100)));

      final handled = controller.dispatchPointerScroll(
        const PointerScrollEvent(
          position: Offset(1000, 1000),
          scrollDelta: Offset(0, 53),
          kind: PointerDeviceKind.mouse,
        ),
      );
      expect(handled, isTrue);
      expect(controller.offset, 0, reason: '外部 wheel 必须进平滑编排，不得直接改偏移');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(controller.offset, greaterThan(0));
      expect(controller.offset, lessThan(100));

      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(100, 0.5));
    });

    testWidgets('SMOOTH-5: 滚动条上的 wheel 与正文同速', (tester) async {
      final contentController = ElScrollController();
      final trackController = ElScrollController();
      addTearDown(contentController.dispose);
      addTearDown(trackController.dispose);
      addTearDown(ScrollPointerChain.debugReset);
      await tester.pumpWidget(
        shell(contentController, smoothScroll: const ElWindowsSmoothScroll(), scrollbar: const ElWindowScrollBar()),
      );
      await tester.pump();

      Future<double> wheelBurst(ScrollController controller, Offset position) async {
        for (var i = 0; i < 3; i++) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: position,
              scrollDelta: const Offset(0, 53),
              timeStamp: Duration(milliseconds: i * 40),
              kind: PointerDeviceKind.mouse,
            ),
          );
          if (i == 0) await tester.pump();
          await tester.pump(const Duration(milliseconds: 40));
        }
        return controller.offset;
      }

      final contentOffset = await wheelBurst(contentController, tester.getCenter(find.byKey(scrollKey)));
      expect(contentOffset, greaterThan(100), reason: 'Windows 三连 wheel 前置必须真正进入加速段');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      ScrollPointerChain.debugReset();

      await tester.pumpWidget(
        shell(trackController, smoothScroll: const ElWindowsSmoothScroll(), scrollbar: const ElWindowScrollBar()),
      );
      await tester.pump();
      final strip = find.byKey(const ValueKey<String>('el-scrollbar-win-strip-vertical'));
      final trackOffset = await wheelBurst(trackController, tester.getCenter(strip));

      expect(trackOffset, closeTo(contentOffset, 0.5), reason: 'Windows 滚动条轨道命中不得丢失连击步长或平滑速度');
    });
  });

  group('平滑滚轮参数', () {
    PointerScrollEvent wheel(double delta, Duration timeStamp) {
      return PointerScrollEvent(kind: PointerDeviceKind.mouse, scrollDelta: Offset(0, delta), timeStamp: timeStamp);
    }

    testWidgets('慢速逐格滚动全程单会话:活动经宽限续接不逐格拆建', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final context = await _smoothWheelFeelPumpScrollContext(tester);
      final harness = _WheelHarness(context, const _LinearTestSmoothScroll());
      try {
        var scrollingToggles = 0;
        var wasScrolling = harness.position.isScrollingNotifier.value;
        harness.position.isScrollingNotifier.addListener(() {
          if (harness.position.isScrollingNotifier.value != wasScrolling) {
            wasScrolling = harness.position.isScrollingNotifier.value;
            scrollingToggles++;
          }
        });

        // 每 9 帧(≈150ms,超出 90ms 连击窗口、小于段时长)一格 × 4:
        // 会话不得拆毁重建。
        for (var f = 0; f < 40; f++) {
          if (f % 9 == 0 && f ~/ 9 < 4) {
            harness.controller.applyPointerScroll(
              wheel(120, Duration(microseconds: f * _smoothWheelFeelFrame.inMicroseconds)),
              120,
            );
          }
          await tester.pump(_smoothWheelFeelFrame);
          if (f > 0 && f < 28) {
            expect(harness.position.isScrollingNotifier.value, isTrue, reason: '滚动输入进行中 f=$f 不得掉出会话');
          }
        }

        // 输入停止后:段尾 + 宽限期满 → 结算,一切归零(宽限从抵达目标的
        // tick 起算,补一帧让它期满)。
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 300));
        expect(harness.position.isScrollingNotifier.value, isFalse);
        expect(harness.controller.isActive, isFalse);
        // 会话恰好开启/关闭各一次(进入 true、结算 false)。
        expect(scrollingToggles, 2);
        // 线性测试算法步长恒等:总位移 = 格数 × 原始步长。
        expect(harness.position.pixels, closeTo(480.0, 0.5));
      } finally {
        harness.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    }, skip: _skip);

    testWidgets('动画直接使用 Ticker 原始时间,不量化到自建帧网格', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final context = await _smoothWheelFeelPumpScrollContext(tester);
      final harness = _WheelHarness(context, const _LinearTestSmoothScroll());
      try {
        harness.controller.applyPointerScroll(wheel(120, Duration.zero), 120);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 10));

        // 线性 200ms 段在 Ticker 原始 58ms 处应为 120 * 58 / 200。
        // 若恢复应用层时钟网格,10ms 尾帧会被量化并使该断言失败。
        expect(harness.position.pixels, closeTo(34.8, 0.01));
      } finally {
        harness.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    }, skip: _skip);

    group('Chromium 原生曲线', () {
      void testChromium(String name, Future<void> Function(WidgetTester, _WheelHarness) body) {
        testWidgets(name, (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          final harness = _WheelHarness(await _smoothWheelFeelPumpScrollContext(tester), ElChromiumSmoothScroll());
          try {
            await body(tester, harness);
          } finally {
            harness.dispose();
            debugDefaultTargetPlatformOverride = null;
            SmoothPointerScrollController.debugResetTouchpadSession();
          }
        });
      }

      test('默认保留平台距离，不叠加下限、连击倍率或大步截断', () {
        final algorithm = ElChromiumSmoothScroll();
        for (final delta in [0.0, 12.0, 53.0, 120.0, 480.0, 2000.0, -53.0, -2000.0]) {
          for (final burst in [0, 1, 5, 20]) {
            expect(algorithm.stepForEvent(delta, burst), delta);
          }
        }
        expect(algorithm.segmentDuration(120, 0), const Duration(milliseconds: 200));
        expect(algorithm.segmentDuration(300, 0), const Duration(milliseconds: 150));
        expect(algorithm.segmentDuration(480, 0), const Duration(milliseconds: 100));
        expect(algorithm.segmentDuration(120, 6000), const Duration(milliseconds: 50));
      });

      testChromium('单格位置与瞬时速度符合 Chromium ease-in-out 基准', (tester, harness) async {
        harness.controller.applyPointerScroll(wheel(120, Duration.zero), 120);
        await tester.pump();
        // Chromium ScrollOffsetAnimationCurve：120px / 200ms，独立求解的参考采样。
        // https://chromium.googlesource.com/chromium/src/+/HEAD/cc/animation/scroll_offset_animation_curve.cc
        final samples = <(int, double, double)>[
          (20, 2.366694426, 241.346531290),
          (40, 9.799182752, 503.881316896),
          (80, 39.826064412, 958.300365410),
          (100, 60, 1034.482758621),
          (160, 110.200817248, 503.881316896),
          (180, 117.633305574, 241.346531290),
          (200, 120, 0),
        ];
        var previous = 0;
        for (final (ms, pixels, velocity) in samples) {
          await tester.pump(Duration(milliseconds: ms - previous));
          expect(harness.position.pixels, closeTo(pixels, 0.00001), reason: '位置 t=$ms');
          expect(harness.position.animationVelocity, closeTo(velocity, 0.0001), reason: '瞬时速度 t=$ms');
          previous = ms;
        }
      });

      for (final frameMs in [5, 10, 20, 40]) {
        testChromium('换段接续瞬时速度，与此前帧间隔 ${frameMs}ms 无关', (tester, harness) async {
          harness.controller.applyPointerScroll(wheel(120, Duration.zero), 120);
          await tester.pump();
          for (var elapsed = 0; elapsed < 40; elapsed += frameMs) {
            await tester.pump(Duration(milliseconds: frameMs));
          }
          harness.controller.applyPointerScroll(wheel(120, const Duration(milliseconds: 40)), 120);
          expect(harness.position.animationVelocity, closeTo(503.881316896, 0.0001));
          expect(harness.controller.debugTargetPixels, 240);
          // t=40ms 更新目标至 240px：新时长 169389us，首斜率 0.3707717175。
          await tester.pump(const Duration(milliseconds: 16));
          expect(harness.position.pixels, closeTo(21.016546649, 0.00001));
          await tester.pump(const Duration(milliseconds: 16));
          expect(harness.position.pixels, closeTo(38.885262953, 0.00001));
          await tester.pump(const Duration(milliseconds: 32));
          expect(harness.position.pixels, closeTo(94.045419038, 0.00001));
          await tester.pumpAndSettle();
          expect(harness.position.pixels, 240);
        });
      }

      testChromium('本帧 ticker 之前收到输入也按本帧曲线位置换段', (tester, harness) async {
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          SchedulerBinding.instance.scheduleFrameCallback((_) {
            harness.controller.applyPointerScroll(wheel(120, const Duration(milliseconds: 40)), 120);
          });
        });
        harness.controller.applyPointerScroll(wheel(120, Duration.zero), 120);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(harness.position.pixels, closeTo(9.799182752, 0.00001));
        await tester.pump(const Duration(milliseconds: 16));
        expect(harness.position.pixels, closeTo(21.016546649, 0.00001));
      });

      testChromium('重复滚向同一边界不会重启尾段', (tester, harness) async {
        harness.position.applyContentDimensions(0, 120);
        harness.controller.applyPointerScroll(wheel(120, Duration.zero), 120);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        harness.controller.applyPointerScroll(wheel(120, const Duration(milliseconds: 80)), 120);
        await tester.pump(const Duration(milliseconds: 20));
        expect(harness.position.pixels, closeTo(60, 0.00001));
        await tester.pump(const Duration(milliseconds: 100));
        expect(harness.position.pixels, 120);
      });

      testChromium('反向输入抵消在途目标，反转曲线保留原瞬时速度', (tester, harness) async {
        harness.position.jumpTo(300);
        harness.controller.applyPointerScroll(wheel(120, Duration.zero), 120);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final before = harness.position.pixels;
        harness.controller.applyPointerScroll(wheel(-180, const Duration(milliseconds: 80)), -180);
        expect(harness.controller.debugTargetPixels, 240);
        expect(harness.position.animationVelocity, closeTo(958.300365410, 0.0001));
        await tester.pump(const Duration(milliseconds: 1));
        expect(harness.position.pixels, greaterThan(before), reason: '先平滑减速再反转，不瞬间反转速度');
        await tester.pumpAndSettle();
        expect(harness.position.pixels, 240);
        expect(harness.controller.isActive, isFalse);
      });

      testChromium('同帧相反输入相抵后不残留位置与活动', (tester, harness) async {
        harness.position.jumpTo(300);
        harness.controller.applyPointerScroll(wheel(120, Duration.zero), 120);
        harness.controller.applyPointerScroll(wheel(-120, const Duration(milliseconds: 1)), -120);
        await tester.pumpAndSettle();
        expect(harness.position.pixels, 300);
        expect(harness.controller.isActive, isFalse);
      });
    });

    group('参数接线(显式定制)', () {
      test('Windows 档:增量与封顶来自实例参数', () {
        const flat = ElWindowsSmoothScroll(accelerationPerTick: 0, maxAcceleration: 1);
        for (final burst in [0, 1, 5, 20]) {
          expect(flat.stepForEvent(120, burst), 120, reason: '零增量恒为原始步长');
        }

        const capped = ElWindowsSmoothScroll(accelerationPerTick: 1, maxAcceleration: 2);
        expect(capped.stepForEvent(120, 20), 240, reason: '大连击封顶在实例 maxAcceleration');
      });

      test('Chromium 档:步长下限/上限来自实例参数', () {
        const custom = ElChromiumSmoothScroll(minStep: 40, maxStep: 200);
        expect(custom.stepForEvent(10, 0), 40, reason: '小 delta 取实例下限');
        expect(custom.stepForEvent(2000, 30).abs(), 200, reason: '大 delta 大连击封顶在实例上限');
        expect(custom.stepForEvent(-10, 0), -40, reason: '方向保持');
      });

      test('Chromium 档:时长上下限来自实例参数', () {
        const pinned = ElChromiumSmoothScroll(
          minDuration: Duration(milliseconds: 180),
          maxDuration: Duration(milliseconds: 180),
        );
        for (final delta in [40.0, 120.0, 300.0, 900.0]) {
          expect(pinned.segmentDuration(delta, 0), const Duration(milliseconds: 180), reason: 'delta=$delta');
        }
      });
    });
  });
}
