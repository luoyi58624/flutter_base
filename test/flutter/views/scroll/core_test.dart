import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// 固定物理的测试行为：把"环境物理"经官方 [ScrollConfiguration] 通道下发。
///
/// el 已删掉 `el.globalScrollPhysics` 全局表，环境物理统一走这条官方通道，
/// 用例要注入环境物理就在这里点名。
class _FixedPhysicsBehavior extends ScrollBehavior {
  const _FixedPhysicsBehavior(this.physics);

  final ScrollPhysics physics;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => physics;
}

/// [ambientPhysics] 是"环境物理"，走官方 `ScrollConfiguration` 通道。包在
/// `home` 里侧而非 MaterialApp 之外：MaterialApp 自带的 `MaterialScrollBehavior`
/// 会盖住外层的 ScrollConfiguration。
Widget _shell({ScrollPhysics? physics, ScrollPhysics? ambientPhysics, ElScrollbar? scrollbar}) {
  Widget content = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 200,
      height: 120,
      child: ElScrollView(
        physics: physics,
        scrollbar: scrollbar,
        children: [for (var i = 0; i < 20; i++) SizedBox(height: 40, child: ElView(child: 'row $i'))],
      ),
    ),
  );
  if (ambientPhysics != null) {
    content = ScrollConfiguration(behavior: _FixedPhysicsBehavior(ambientPhysics), child: content);
  }
  return MaterialApp(home: content);
}

RenderVirtualScrollView _scrollRender(WidgetTester tester) =>
    tester.allRenderObjects.whereType<RenderVirtualScrollView>().first;

bool _hasPhysics<T extends ScrollPhysics>(ScrollPhysics physics) {
  ScrollPhysics? current = physics;
  while (current != null) {
    if (current is T) return true;
    current = current.parent;
  }
  return false;
}

Widget _frame(Widget child, {double width = 300, double height = 200}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, height: height, child: child),
    ),
  );
}

Widget _scroll({Key? key, ScrollController? controller, required List<Widget> children}) {
  return ElScrollView(
    key: key,
    controller: controller,
    scrollbar: const ElNoScrollBar(),
    physics: const ClampingScrollPhysics(),
    smoothScroll: const ElNoSmoothScroll(),
    cacheExtent: 0,
    children: children,
  );
}

final class _ItemProbe extends StatefulWidget {
  const _ItemProbe({
    super.key,
    this.height = 40,
    this.sticky,
    this.listen = true,
    this.trackVisibility = false,
    this.trackFraction = false,
    this.child,
  });

  final double height;
  final double? sticky;
  final bool listen;
  final bool trackVisibility;
  final bool trackFraction;
  final Widget? child;

  @override
  State<_ItemProbe> createState() => _ItemProbeState();
}

final class _ItemProbeState extends State<_ItemProbe> with ElScrollMixin<_ItemProbe>, ElStickyMixin<_ItemProbe> {
  int buildCount = 0;
  int itemUpdateCount = 0;
  final List<ElScrollItemSnapshot> itemUpdates = <ElScrollItemSnapshot>[];
  final List<ElVisibilityInfo> visibility = <ElVisibilityInfo>[];

  @override
  bool get observesScrollUpdates => false;

  @override
  bool get observesScrollMetrics => false;

  @override
  bool get listenScrollItem => widget.listen;

  @override
  bool get trackScrollItemVisibility => widget.trackVisibility;

  @override
  bool get trackScrollItemVisibleFraction => widget.trackFraction;

  @override
  bool get stickyEnabled => widget.sticky != null;

  @override
  double? get stickyOffset => widget.sticky;

  @override
  void onScrollItemUpdate(ElScrollItemUpdateDetails details) {
    itemUpdateCount++;
    itemUpdates.add(details.snapshot);
    super.onScrollItemUpdate(details);
  }

  @override
  void onScrollItemVisibilityChanged(ElVisibilityInfo info) {
    visibility.add(info);
    super.onScrollItemVisibilityChanged(info);
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return buildSticky(
      context,
      child: SizedBox(height: widget.height, child: widget.child),
    );
  }
}

final class _ListeningItemProbe extends StatefulWidget {
  const _ListeningItemProbe({required this.snapshots, this.stickyEnabled = false});

  final List<ElScrollItemSnapshot> snapshots;
  final bool stickyEnabled;

  @override
  State<_ListeningItemProbe> createState() => _ListeningItemProbeState();
}

final class _ListeningItemProbeState extends State<_ListeningItemProbe>
    with ElScrollMixin<_ListeningItemProbe>, ElStickyMixin<_ListeningItemProbe> {
  @override
  bool get stickyEnabled => widget.stickyEnabled;
  @override
  bool get listenScrollItem => true;
  @override
  Widget build(BuildContext context) {
    widget.snapshots.add(scrollItemSnapshot);
    return const SizedBox(height: 40);
  }
}

Widget _mixinScroll({
  Key? key,
  ScrollController? controller,
  ScrollController? horizontalController,
  Axis? axis = Axis.vertical,
  bool reverse = false,
  ScrollPhysics physics = const ClampingScrollPhysics(),
  required List<Widget> children,
}) {
  return ElScrollView(
    key: key,
    controller: controller,
    horizontalController: horizontalController,
    axis: axis,
    reverse: reverse,
    scrollbar: const ElNoScrollBar(),
    smoothScroll: const ElNoSmoothScroll(),
    physics: physics,
    children: children,
  );
}

final class _MixinProbe extends StatefulWidget {
  const _MixinProbe({
    super.key,
    this.axis,
    this.inputDriver = false,
    this.consumePre = false,
    this.consumePost = false,
    this.consumeFling = false,
    this.rebuildOnUpdate = false,
    this.child = const SizedBox.shrink(),
  });

  final Axis? axis;
  final bool inputDriver;
  final bool consumePre;
  final bool consumePost;
  final bool consumeFling;
  final bool rebuildOnUpdate;
  final Widget child;

  @override
  State<_MixinProbe> createState() => _MixinProbeState();
}

final class _MixinProbeState extends State<_MixinProbe> with ElScrollMixin<_MixinProbe> {
  int buildCount = 0;
  int attachCount = 0;
  int detachCount = 0;
  int startCount = 0;
  int updateCount = 0;
  int endCount = 0;
  int metricsCount = 0;
  int activityCount = 0;
  int preScrollCount = 0;
  int postScrollCount = 0;
  int preFlingCount = 0;
  ElScrollUpdateDetails? lastUpdate;
  ElScrollMetricsDetails? lastMetrics;
  ScrollMetrics? metricsAtAttach;
  final List<ElScrollActivityType> activities = <ElScrollActivityType>[];
  final List<ElScrollInputSource> preSources = <ElScrollInputSource>[];
  bool? _inputDriverOverride;

  @override
  Axis? get requestedScrollAxis => widget.axis;

  @override
  Object? get scrollInputSlot => (_inputDriverOverride ?? widget.inputDriver) ? (widget.key ?? #probe) : null;

  void updateInputDriver(bool value) {
    _inputDriverOverride = value;
    updateScrollEffect();
  }

  @override
  bool get rebuildOnScrollUpdate => widget.rebuildOnUpdate;

  @override
  void onScrollViewAttached(ElScrollViewState scrollView) {
    attachCount++;
    metricsAtAttach = scrollMetrics;
  }

  @override
  void onScrollViewDetached(ElScrollViewState scrollView) {
    detachCount++;
  }

  @override
  void onScrollStart(ElScrollStartDetails details) {
    startCount++;
  }

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    updateCount++;
    lastUpdate = details;
  }

  @override
  void onScrollEnd(ElScrollEndDetails details) {
    endCount++;
  }

  @override
  void onScrollMetricsChanged(ElScrollMetricsDetails details) {
    metricsCount++;
    lastMetrics = details;
  }

  @override
  void onScrollActivityChanged(ElScrollActivityDetails details) {
    activityCount++;
    activities.add(details.activity);
  }

  @override
  double onPreScroll(ElScrollInputDetails details, double remaining) {
    final rest = super.onPreScroll(details, remaining);
    preScrollCount++;
    preSources.add(details.source);
    return widget.consumePre ? 0.0 : rest;
  }

  @override
  double onPostScroll(ElScrollInputDetails details, double remaining) {
    final rest = super.onPostScroll(details, remaining);
    postScrollCount++;
    return widget.consumePost ? 0.0 : rest;
  }

  @override
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    final rest = super.onPreFling(details, remainingVelocity);
    preFlingCount++;
    return widget.consumeFling ? 0.0 : rest;
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return widget.child;
  }
}

final class _SelfCreatingProbe extends StatefulWidget {
  const _SelfCreatingProbe({super.key});

  @override
  State<_SelfCreatingProbe> createState() => _SelfCreatingProbeState();
}

final class _SelfCreatingProbeState extends State<_SelfCreatingProbe> with ElScrollMixin<_SelfCreatingProbe> {
  @override
  Widget build(BuildContext context) {
    return _mixinScroll(children: const <Widget>[SizedBox(height: 500)]);
  }
}

final class _ListeningProbe extends StatefulWidget {
  const _ListeningProbe({required this.snapshots, required this.listen});

  final List<ElScrollSnapshot> snapshots;
  final bool listen;

  @override
  State<_ListeningProbe> createState() => _ListeningProbeState();
}

final class _ListeningProbeState extends State<_ListeningProbe> with ElScrollMixin<_ListeningProbe> {
  @override
  bool get rebuildOnScrollUpdate => widget.listen;
  @override
  Widget build(BuildContext context) {
    widget.snapshots.add(scrollSnapshot);
    return const SizedBox(width: 20, height: 20);
  }
}

mixin _FirstScrollEffect<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  void recordFirstEffect();

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    recordFirstEffect();
    super.onScrollUpdate(details);
  }
}

mixin _SecondScrollEffect<T extends StatefulWidget> on State<T>, ElScrollMixin<T> {
  void recordSecondEffect();

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    recordSecondEffect();
    super.onScrollUpdate(details);
  }
}

final class _CompositeProbe extends StatefulWidget {
  const _CompositeProbe({super.key});

  @override
  State<_CompositeProbe> createState() => _CompositeProbeState();
}

final class _CompositeProbeState extends State<_CompositeProbe>
    with ElScrollMixin<_CompositeProbe>, _FirstScrollEffect<_CompositeProbe>, _SecondScrollEffect<_CompositeProbe> {
  int firstEffectCount = 0;
  int secondEffectCount = 0;

  @override
  void recordFirstEffect() {
    firstEffectCount++;
  }

  @override
  void recordSecondEffect() {
    secondEffectCount++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20);
}

Widget _verticalScroll({Key? key, ScrollController? controller, required List<Widget> children}) {
  return ElScrollView(
    key: key,
    controller: controller,
    scrollbar: const ElNoScrollBar(),
    physics: const ClampingScrollPhysics(),
    smoothScroll: const ElNoSmoothScroll(),
    children: children,
  );
}

final class _ScopeProbe extends StatefulWidget {
  const _ScopeProbe({super.key});

  @override
  State<_ScopeProbe> createState() => _ScopeProbeState();
}

final class _ScopeProbeState extends State<_ScopeProbe> {
  int dependencyCount = 0;
  int buildCount = 0;
  ElScrollViewState? host;
  ElScrollViewState? verticalHost;
  ElScrollViewState? horizontalHost;
  final List<ScrollMetrics?> metricsAtDependency = <ScrollMetrics?>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dependencyCount++;
    host = ElScrollView.maybeOf(context);
    verticalHost = ElScrollView.maybeOf(context, axis: Axis.vertical);
    horizontalHost = ElScrollView.maybeOf(context, axis: Axis.horizontal);
    metricsAtDependency.add(host?.metrics);
  }

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return const SizedBox.shrink();
  }
}

final class _PageCreatesScroll extends StatefulWidget {
  const _PageCreatesScroll({super.key});

  @override
  State<_PageCreatesScroll> createState() => _PageCreatesScrollState();
}

final class _PageCreatesScrollState extends State<_PageCreatesScroll> {
  ElScrollViewState? hostSeenByPage;

  @override
  Widget build(BuildContext context) {
    hostSeenByPage = ElScrollView.maybeOf(context);
    return _verticalScroll(children: const <Widget>[SizedBox(height: 400)]);
  }
}

Widget _mixinClientChannelScroll({
  Key? key,
  ScrollController? controller,
  ScrollController? horizontalController,
  Axis? axis = Axis.vertical,
  required List<Widget> children,
}) {
  return ElScrollView(
    key: key,
    controller: controller,
    horizontalController: horizontalController,
    axis: axis,
    scrollbar: const ElNoScrollBar(),
    physics: const ClampingScrollPhysics(),
    children: children,
  );
}

Widget _verticalTree({
  required GlobalKey<ElScrollViewState> hostKey,
  required GlobalKey<ScrollMixinClientProbeState> probeKey,
  ScrollController? controller,
  bool wantsViewportUpdates = true,
  Object? scrollInputSlot,
  double height = 200,
}) {
  return _frame(
    _mixinClientChannelScroll(
      key: hostKey,
      controller: controller,
      children: <Widget>[
        SizedBox(
          height: 40,
          child: ScrollMixinClientProbe(
            key: probeKey,
            wantsViewportUpdates: wantsViewportUpdates,
            scrollInputSlot: scrollInputSlot,
          ),
        ),
        const SizedBox(height: 1200),
      ],
    ),
    height: height,
  );
}

class _Observer extends StatefulWidget {
  const _Observer({super.key});
  @override
  State<_Observer> createState() => _ObserverState();
}

class _ObserverState extends State<_Observer> with ElScrollMixin<_Observer> {
  final samples = <ElScrollSnapshot>[];
  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    super.onScrollUpdate(details);
    samples.add(details.snapshot);
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 2000));
}

class _TextRow extends StatefulWidget {
  const _TextRow(this.text, {required this.left, required this.layer, super.key});
  final String text;
  final double left;
  final int layer;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  @override
  Widget build(BuildContext context) => ElPositioned(
    left: widget.left,
    top: 0,
    zIndex: widget.layer,
    child: ElView(style: const ElStyle(width: 90, height: 40, fontSize: 14), child: widget.text),
  );
}

Widget _orderProtocolFrame(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(style: const ElStyle(width: 300, height: 100), child: child),
  ),
);

class _Probe extends StatefulWidget {
  const _Probe({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with ElScrollMixin<_Probe> {
  final updates = <ElScrollSnapshot>[];
  final activities = <ElScrollActivityType>[];

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    super.onScrollUpdate(details);
    updates.add(details.snapshot);
  }

  @override
  void onScrollActivityChanged(ElScrollActivityDetails details) {
    super.onScrollActivityChanged(details);
    activities.add(details.activity);
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 0));
}

class _CustomController extends ScrollController {
  int factoryCalls = 0;

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    factoryCalls++;
    return _CustomPosition(physics: physics, context: context, oldPosition: oldPosition);
  }
}

class _CustomPosition extends ScrollPositionWithSingleContext {
  _CustomPosition({required super.physics, required super.context, super.oldPosition});
}

Widget _positionObservationFrame(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(style: const ElStyle(width: 300, height: 200), child: child),
  ),
);

class _Reader extends StatefulWidget {
  const _Reader({super.key, this.axis});
  final Axis? axis;
  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> with ElScrollMixin<_Reader> {
  int dependencies = 0;
  int attachments = 0;
  int detachments = 0;
  @override
  Axis? get requestedScrollAxis => widget.axis;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    dependencies++;
  }

  @override
  void onScrollViewAttached(ElScrollViewState scrollView) {
    super.onScrollViewAttached(scrollView);
    attachments++;
  }

  @override
  void onScrollViewDetached(ElScrollViewState scrollView) {
    super.onScrollViewDetached(scrollView);
    detachments++;
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(width: 0, height: 0));
}

class _Inner extends StatefulWidget {
  const _Inner({super.key, required this.scrollKey, required this.reader});
  final GlobalKey<ElScrollViewState> scrollKey;
  final Widget reader;
  @override
  State<_Inner> createState() => _InnerState();
}

class _InnerState extends State<_Inner> {
  Axis axis = Axis.vertical;
  void makeHorizontal() => setState(() => axis = Axis.horizontal);
  @override
  Widget build(BuildContext context) => ElView(
    style: const ElStyle(width: 300, height: 140),
    child: ElScrollView(
      key: widget.scrollKey,
      axis: axis,
      scrollbar: const ElNoScrollBar(),
      children: [
        widget.reader,
        const ElView(style: ElStyle(width: 1000, height: 400)),
      ],
    ),
  );
}

class _SessionLifecycleProbe extends StatefulWidget {
  const _SessionLifecycleProbe({
    super.key,
    this.consume = false,
    required this.name,
    required this.trace,
    this.onStart,
    this.onEnd,
    this.onCancel,
  });
  final bool consume;
  final String name;
  final List<String> trace;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final VoidCallback? onCancel;
  @override
  State<_SessionLifecycleProbe> createState() => _SessionLifecycleProbeState();
}

class _SessionLifecycleProbeState extends State<_SessionLifecycleProbe> with ElScrollMixin<_SessionLifecycleProbe> {
  final events = <ElScrollSessionDetails>[];
  double accepted = 0;
  bool sessionsEnabled = true;
  void disableSessions() {
    sessionsEnabled = false;
    updateScrollEffect();
  }

  @override
  bool get observesScrollSessions => sessionsEnabled;
  @override
  Object? get scrollInputSlot => widget.consume ? widget.name : null;
  @override
  double onPreScroll(ElScrollInputDetails input, double remaining) {
    final rest = super.onPreScroll(input, remaining);
    if (!widget.consume) return rest;
    accepted += rest;
    return 0;
  }

  @override
  double onPreFling(ElScrollReleaseDetails details, double remainingVelocity) {
    final rest = super.onPreFling(details, remainingVelocity);
    return widget.consume ? 0 : rest;
  }

  void record(String phase, ElScrollSessionDetails details) {
    widget.trace.add('${widget.name}:$phase');
    events.add(details);
  }

  @override
  void onInputStart(ElScrollSessionDetails details) {
    super.onInputStart(details);
    record('start', details);
    widget.onStart?.call();
  }

  @override
  void onInputEnd(ElScrollSessionDetails details) {
    super.onInputEnd(details);
    record('end', details);
    widget.onEnd?.call();
  }

  @override
  void onInputCancel(ElScrollSessionDetails details) {
    super.onInputCancel(details);
    record('inputCancel', details);
    widget.onCancel?.call();
  }

  @override
  void onMotionSettled(ElScrollSessionDetails details) {
    super.onMotionSettled(details);
    record('settled', details);
  }

  @override
  void onMotionCancelled(ElScrollSessionDetails details) {
    super.onMotionCancelled(details);
    record('motionCancel', details);
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 50));
}

Widget _app(ElScrollController controller, List<Widget> probes) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(
      style: const ElStyle(width: 240, height: 200),
      child: ElScrollView(
        controller: controller,
        physics: const ElClampingScrollPhysics(),
        scrollbar: const ElNoScrollBar(),
        smoothScroll: const ElNoSmoothScroll(),
        children: [
          ...probes,
          const ElView(style: ElStyle(height: 3000)),
        ],
      ),
    ),
  ),
);

Future<TestGesture> _drag(WidgetTester tester) async {
  final gesture = await tester.startGesture(const Offset(120, 150));
  await gesture.moveBy(const Offset(0, -30), timeStamp: const Duration(milliseconds: 10));
  await gesture.moveBy(const Offset(0, -20), timeStamp: const Duration(milliseconds: 20));
  return gesture;
}

class _SnapshotProtocolObserver extends StatefulWidget {
  const _SnapshotProtocolObserver(this.samples, {super.key, this.metricSamples, this.observe = true});
  final List<ElScrollSnapshot> samples;
  final List<ScrollMetrics?>? metricSamples;
  final bool observe;
  @override
  State<_SnapshotProtocolObserver> createState() => _SnapshotProtocolObserverState();
}

class _SnapshotProtocolObserverState extends State<_SnapshotProtocolObserver>
    with ElScrollMixin<_SnapshotProtocolObserver> {
  @override
  bool get observesScrollUpdates => widget.observe;

  @override
  bool get observesScrollMetrics => widget.observe;

  @override
  void onScrollUpdate(ElScrollUpdateDetails details) {
    super.onScrollUpdate(details);
    widget.samples.add(details.snapshot);
  }

  @override
  void onScrollMetricsChanged(ElScrollMetricsDetails details) {
    super.onScrollMetricsChanged(details);
    widget.samples.add(details.snapshot);
    widget.metricSamples?.add(details.metrics);
  }

  @override
  Widget build(BuildContext context) => const ElView(style: ElStyle(height: 0));
}

class _HeightRow extends StatefulWidget {
  const _HeightRow({super.key});
  @override
  State<_HeightRow> createState() => _HeightRowState();
}

class _HeightRowState extends State<_HeightRow> {
  double extent = 40;
  void resize(double value) => setState(() => extent = value);
  @override
  Widget build(BuildContext context) => ElView(style: ElStyle(height: extent));
}

void main() {
  group('环境滚动配置', () {
    testWidgets('ScrollConfiguration 环境物理生效，widget 直参压过环境，归位回平台默认', (tester) async {
      // 测试平台（android）内置默认 = ElClampingScrollPhysics，环境点名 bouncing。
      await tester.pumpWidget(_shell(ambientPhysics: const BouncingScrollPhysics()));
      expect(
        _hasPhysics<BouncingScrollPhysics>(_scrollRender(tester).position.physics),
        isTrue,
        reason: '未传 widget 直参时应选中环境 ScrollConfiguration 物理',
      );

      // widget 直参压过环境。
      await tester.pumpWidget(
        _shell(physics: const ClampingScrollPhysics(), ambientPhysics: const BouncingScrollPhysics()),
      );
      expect(
        _hasPhysics<ClampingScrollPhysics>(_scrollRender(tester).position.physics),
        isTrue,
        reason: '直参 clamping 压过环境 bouncing',
      );
      expect(_hasPhysics<BouncingScrollPhysics>(_scrollRender(tester).position.physics), isFalse);
    });

    testWidgets('归位后回平台默认（android clamping 不越界）', (tester) async {
      await tester.pumpWidget(_shell());
      expect(
        _hasPhysics<ClampingScrollPhysics>(_scrollRender(tester).position.physics),
        isTrue,
        reason: '未设环境物理时 android 平台默认 clamping 物理链',
      );
    });
  });

  group('成员绑定与几何', () {
    testWidgets('普通 direct child 绑定真实 item scope 与宿主几何', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ItemProbeState>();

      await tester.pumpWidget(
        _frame(
          _scroll(
            key: hostKey,
            children: [
              _ItemProbe(key: probeKey, height: 48),
              const SizedBox(height: 600),
            ],
          ),
        ),
      );
      await tester.pump();

      final state = probeKey.currentState!;
      final snapshot = state.scrollItemSnapshot;
      expect(state.hasScrollView, isTrue);
      expect(state.hasScrollItem, isTrue);
      expect(state.scrollView, same(hostKey.currentState));
      expect(state.scrollItemIndex, 0);
      expect(snapshot.attached, isTrue);
      expect(snapshot.index, 0);
      expect(snapshot.itemExtent, closeTo(48, 0.001));
      expect(snapshot.viewportExtent, closeTo(200, 0.001));
      expect(snapshot.isMounted, isTrue);
      expect(snapshot.isVisible, isTrue);
      expect(hostKey.currentState!.debugScrollMixinClientCount, 1);
    });

    testWidgets('Sliver builder item 使用同一私有 scope，不依赖旧 ElScrollItem 壳', (tester) async {
      final probeKey = GlobalKey<_ItemProbeState>();

      await tester.pumpWidget(
        _frame(
          _scroll(
            children: [
              ElListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) =>
                    index == 0 ? _ItemProbe(key: probeKey, height: 44) : const SizedBox(height: 44),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(probeKey.currentState!.scrollItemIndex, 0);
      expect(probeKey.currentState!.scrollItemSnapshot.itemExtent, closeTo(44, 0.001));
    });

    testWidgets('item timeline 只重建最小 State，窗口外进度钳到端点', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ItemProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _scroll(
            key: hostKey,
            controller: controller,
            children: [
              _ItemProbe(key: probeKey, height: 80),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();

      final state = probeKey.currentState!;
      final itemBuilds = state.buildCount;
      final hostBuilds = hostKey.currentState!.debugCounters.debugBuildCount;
      controller.jumpTo(120);
      await tester.pump();

      expect(state.itemUpdateCount, greaterThan(0));
      expect(state.buildCount, greaterThan(itemBuilds));
      expect(hostKey.currentState!.debugCounters.debugBuildCount, hostBuilds);
      expect(state.scrollItemSnapshot.isVisible, isFalse);
      expect(state.scrollItemSnapshot.visibleFraction, 0.0);
      expect(state.scrollItemSnapshot.viewProgress, 1.0);
    });

    testWidgets('visibility 在 post-frame 派发进入、连续比例与离开', (tester) async {
      final controller = ScrollController();
      final probeKey = GlobalKey<_ItemProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _scroll(
            controller: controller,
            children: [
              _ItemProbe(key: probeKey, height: 120, listen: false, trackVisibility: true, trackFraction: true),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(probeKey.currentState!.visibility.last.visible, isTrue);
      expect(probeKey.currentState!.visibility.last.visibleFraction, 1.0);

      controller.jumpTo(60);
      await tester.pump();
      expect(probeKey.currentState!.visibility.last.visible, isTrue);
      expect(probeKey.currentState!.visibility.last.visibleFraction, closeTo(0.5, 0.001));

      controller.jumpTo(140);
      await tester.pump();
      expect(probeKey.currentState!.visibility.last.visible, isFalse);
      expect(probeKey.currentState!.visibility.last.visibleFraction, 0.0);
    });

    testWidgets('sticky 由 item client 登记并在滚过自然位置后钉住', (tester) async {
      final controller = ScrollController();
      final probeKey = GlobalKey<_ItemProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _scroll(
            controller: controller,
            children: [
              const SizedBox(height: 60),
              _ItemProbe(key: probeKey, height: 40, sticky: 0),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(probeKey.currentState!.scrollItemSnapshot.isSticky, isTrue);
      expect(probeKey.currentState!.scrollItemSnapshot.isPinned, isFalse);

      controller.jumpTo(80);
      await tester.pump();
      expect(probeKey.currentState!.scrollItemSnapshot.isPinned, isTrue);
    });

    testWidgets('sticky 配置原位更新同一个 client，不重复 attach', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ItemProbeState>();
      addTearDown(controller.dispose);

      Widget tree(double? sticky) => _frame(
        _scroll(
          key: hostKey,
          controller: controller,
          children: [
            const SizedBox(height: 60),
            _ItemProbe(key: probeKey, height: 40, sticky: sticky),
            const SizedBox(height: 1000),
          ],
        ),
      );

      await tester.pumpWidget(tree(null));
      await tester.pump();
      final state = probeKey.currentState!;
      expect(state.scrollItemSnapshot.isSticky, isFalse);

      await tester.pumpWidget(tree(0));
      await tester.pump();
      expect(probeKey.currentState, same(state));
      expect(hostKey.currentState!.debugScrollMixinClientCount, 1);
      expect(state.scrollItemSnapshot.isSticky, isTrue);

      controller.jumpTo(80);
      await tester.pump();
      expect(state.scrollItemSnapshot.isPinned, isTrue);

      await tester.pumpWidget(tree(null));
      await tester.pump();
      expect(state.scrollItemSnapshot.isSticky, isFalse);
      expect(state.scrollItemSnapshot.isPinned, isFalse);
    });

    testWidgets('同一个 item scope 的第二个 sticky owner 立即报错', (tester) async {
      await tester.pumpWidget(
        _frame(
          _scroll(
            children: [
              _ItemProbe(sticky: 0, child: const _ItemProbe(sticky: 0)),
              const SizedBox(height: 600),
            ],
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(error.toString(), contains('只能登记一个 sticky owner'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('keyed item 重排保持 State identity 并原子迁移 index/sticky', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final firstKey = GlobalKey<_ItemProbeState>();
      final secondKey = GlobalKey<_ItemProbeState>();

      Widget tree(bool reversed) {
        final first = _ItemProbe(key: firstKey, height: 40, sticky: 0);
        final second = _ItemProbe(key: secondKey, height: 40);
        return _frame(
          _scroll(
            key: hostKey,
            children: [if (reversed) second else first, if (reversed) first else second, const SizedBox(height: 600)],
          ),
        );
      }

      await tester.pumpWidget(tree(false));
      await tester.pump();
      final firstState = firstKey.currentState!;
      final secondState = secondKey.currentState!;
      expect(firstState.scrollItemIndex, 0);
      expect(secondState.scrollItemIndex, 1);
      expect(firstState.scrollItemSnapshot.isSticky, isTrue);

      await tester.pumpWidget(tree(true));
      await tester.pump();
      expect(firstKey.currentState, same(firstState));
      expect(secondKey.currentState, same(secondState));
      expect(firstState.scrollItemIndex, 1);
      expect(secondState.scrollItemIndex, 0);
      expect(firstState.scrollItemSnapshot.index, 1);
      expect(firstState.scrollItemSnapshot.isSticky, isTrue);
      expect(hostKey.currentState!.debugScrollMixinClientCount, 2);
    });

    testWidgets('SliverGrid cell 得到扁平 item index 与所在行几何', (tester) async {
      final probeKey = GlobalKey<_ItemProbeState>();

      await tester.pumpWidget(
        _frame(
          _scroll(
            children: [
              ElGridView.builder(
                itemCount: 20,
                crossAxisCount: 2,
                mainAxisExtent: 50,
                itemBuilder: (context, index) =>
                    index == 1 ? _ItemProbe(key: probeKey, height: 50) : const SizedBox(height: 50),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final snapshot = probeKey.currentState!.scrollItemSnapshot;
      expect(snapshot.index, 1);
      expect(snapshot.itemExtent, closeTo(50, 0.001));
      expect(snapshot.leadingOffset, closeTo(0, 0.001));
      expect(snapshot.isVisible, isTrue);
    });

    testWidgets('listenScrollItem 随 item timeline 更新并保留 sticky 声明', (tester) async {
      final controller = ScrollController();
      final snapshots = <ElScrollItemSnapshot>[];
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _scroll(
            controller: controller,
            children: [
              _ListeningItemProbe(snapshots: snapshots, stickyEnabled: true),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(snapshots.last.attached, isTrue);
      expect(snapshots.last.index, 0);
      expect(snapshots.last.isSticky, isTrue);

      final before = snapshots.length;
      controller.jumpTo(80);
      await tester.pump();
      expect(snapshots.length, greaterThan(before));
      expect(snapshots.last.isVisible, isFalse);
    });

    testWidgets('滚动容器外的观察与重建 Mixin 都返回 detached item snapshot', (tester) async {
      final probeKey = GlobalKey<_ItemProbeState>();
      final listeningSnapshots = <ElScrollItemSnapshot>[];

      await tester.pumpWidget(
        _frame(
          Column(
            children: [
              _ItemProbe(key: probeKey),
              _ListeningItemProbe(snapshots: listeningSnapshots),
            ],
          ),
        ),
      );

      expect(probeKey.currentState!.scrollItemSnapshot, ElScrollItemSnapshot.detached);
      expect(listeningSnapshots.last, ElScrollItemSnapshot.detached);
    });
  });

  group('滚动 Mixin', () {
    testWidgets('未在滚动后代中时保持 detached，严格 getter 给出结构错误', (tester) async {
      final key = GlobalKey<_MixinProbeState>();
      await tester.pumpWidget(_frame(_MixinProbe(key: key)));

      final state = key.currentState!;
      expect(state.hasScrollView, isFalse);
      expect(state.scrollView, isNull);
      expect(state.scrollController, isNull);
      expect(state.scrollPosition, isNull);
      expect(state.scrollMetrics, isNull);
      expect(state.scrollSnapshot, same(ElScrollSnapshot.detached));
      expect(
        () => state.requireScrollView,
        throwsA(isA<FlutterError>().having((error) => error.toString(), 'message', contains('真实后代'))),
      );
    });

    testWidgets('创建 ElScrollView 的 State 不会向下绑定自己', (tester) async {
      final key = GlobalKey<_SelfCreatingProbeState>();
      await tester.pumpWidget(_frame(_SelfCreatingProbe(key: key)));
      expect(key.currentState!.hasScrollView, isFalse);
      expect(key.currentState!.scrollSnapshot.activity, ElScrollActivityType.detached);
    });

    testWidgets('没有 Mixin client 时宿主不分配登记表或输入分派', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(_mixinScroll(key: hostKey, controller: controller, children: const <Widget>[SizedBox(height: 1200)])),
      );
      await tester.pump();

      expect(hostKey.currentState!.debugScrollMixinClientRegistryAllocated, isFalse);
      controller.jumpTo(120);
      await tester.pump();
      expect(hostKey.currentState!.debugScrollMixinClientRegistryAllocated, isFalse);
    });

    testWidgets('公开 Mixin 绑定真实宿主并提供 controller/position/metrics', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_MixinProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            controller: controller,
            children: [
              SizedBox(height: 40, child: _MixinProbe(key: probeKey)),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();

      final host = hostKey.currentState!;
      final state = probeKey.currentState!;
      expect(state.hasScrollView, isTrue);
      expect(state.scrollView, same(host));
      expect(state.scrollController, same(controller));
      expect(state.scrollPosition, same(controller.position));
      expect(state.scrollMetrics, same(controller.position));
      expect(state.requireScrollView, same(host));
      expect(state.requireScrollController, same(controller));
      expect(state.requireScrollPosition, same(controller.position));
      expect(state.requireScrollMetrics, same(controller.position));
      expect(state.attachCount, 1);
      expect(state.metricsAtAttach, isNull);
      expect(state.metricsCount, 1);
      expect(state.scrollSnapshot.attached, isTrue);
      expect(state.scrollSnapshot.hasMetrics, isTrue);
      expect(state.scrollSnapshot.axis, Axis.vertical);
      expect(state.scrollSnapshot.axisDirection, AxisDirection.down);
      expect(state.scrollSnapshot.contentOffset, 0.0);
      expect(state.scrollSnapshot.atStart, isTrue);
    });

    testWidgets('Sliver item 与 scroll positioned child 都绑定所属宿主', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final sliverKey = GlobalKey<_MixinProbeState>();
      final positionedKey = GlobalKey<_MixinProbeState>();

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            children: [
              ElListView.builder(
                itemCount: 20,
                itemBuilder: (context, index) => index == 0
                    ? SizedBox(
                        height: 40,
                        child: _MixinProbe(key: sliverKey, child: const SizedBox(width: 4, height: 4)),
                      )
                    : const SizedBox(height: 40),
              ),
              ElPositioned(
                left: 0,
                top: 0,
                child: SizedBox(width: 20, height: 20, child: _MixinProbe(key: positionedKey)),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(sliverKey.currentState!.scrollView, same(hostKey.currentState));
      expect(positionedKey.currentState!.scrollView, same(hostKey.currentState));
      expect(hostKey.currentState!.debugScrollMixinClientCount, 2);
    });

    testWidgets('双轴宿主按 requestedScrollAxis 返回真实 controller 与 position', (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final verticalKey = GlobalKey<_MixinProbeState>();
      final horizontalKey = GlobalKey<_MixinProbeState>();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            controller: vertical,
            horizontalController: horizontal,
            axis: null,
            children: [
              SizedBox(
                width: 800,
                height: 600,
                child: Column(
                  children: [
                    _MixinProbe(key: verticalKey),
                    _MixinProbe(key: horizontalKey, axis: Axis.horizontal),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(verticalKey.currentState!.scrollController, same(vertical));
      expect(verticalKey.currentState!.scrollPosition, same(vertical.position));
      expect(verticalKey.currentState!.scrollSnapshot.axis, Axis.vertical);
      expect(horizontalKey.currentState!.scrollController, same(horizontal));
      expect(horizontalKey.currentState!.scrollPosition, same(horizontal.position));
      expect(horizontalKey.currentState!.scrollSnapshot.axis, Axis.horizontal);
      expect(hostKey.currentState!.debugScrollMixinClientCount, 2);
    });

    testWidgets('默认滚动更新不 setState，显式 opt-in 才重建局部 State', (tester) async {
      final controller = ScrollController();
      final passiveKey = GlobalKey<_MixinProbeState>();
      final rebuildingKey = GlobalKey<_MixinProbeState>();
      final hostKey = GlobalKey<ElScrollViewState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            controller: controller,
            children: [
              SizedBox(height: 20, child: _MixinProbe(key: passiveKey)),
              SizedBox(height: 20, child: _MixinProbe(key: rebuildingKey, rebuildOnUpdate: true)),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      );
      await tester.pump();

      final passive = passiveKey.currentState!;
      final rebuilding = rebuildingKey.currentState!;
      final passiveBuilds = passive.buildCount;
      final rebuildingBuilds = rebuilding.buildCount;
      final hostBuilds = hostKey.currentState!.debugCounters.debugBuildCount;

      controller.jumpTo(120);
      await tester.pump();

      expect(passive.updateCount, greaterThan(0));
      expect(rebuilding.updateCount, greaterThan(0));
      expect(passive.buildCount, passiveBuilds);
      expect(rebuilding.buildCount, greaterThan(rebuildingBuilds));
      expect(hostKey.currentState!.debugCounters.debugBuildCount, hostBuilds);
      expect(passive.scrollSnapshot.contentOffset, closeTo(120, 0.001));
      expect(passive.scrollSnapshot.motionDelta, closeTo(120, 0.001));
      expect(passive.scrollSnapshot.direction, ElScrollTravelDirection.towardEnd);
    });

    testWidgets('reverse 轴的 offset/delta 按视觉坐标归一，rawPixels 保持原值', (tester) async {
      final controller = ScrollController();
      final probeKey = GlobalKey<_MixinProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            controller: controller,
            reverse: true,
            children: [
              SizedBox(height: 20, child: _MixinProbe(key: probeKey)),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();

      final state = probeKey.currentState!;
      final max = controller.position.maxScrollExtent;
      expect(state.scrollSnapshot.reverse, isTrue);
      expect(state.scrollSnapshot.rawPixels, 0.0);
      expect(state.scrollSnapshot.contentOffset, closeTo(max, 0.001));

      controller.jumpTo(max);
      await tester.pump();

      expect(state.scrollSnapshot.rawPixels, closeTo(max, 0.001));
      expect(state.scrollSnapshot.contentOffset, 0.0);
      expect(state.scrollSnapshot.direction, ElScrollTravelDirection.towardStart);
      expect(state.scrollSnapshot.atStart, isTrue);
    });

    testWidgets('bounce 越界不把逻辑 offset 变成负数，并分别记录 overscroll', (tester) async {
      final controller = ScrollController();
      final probeKey = GlobalKey<_MixinProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            controller: controller,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              SizedBox(height: 20, child: _MixinProbe(key: probeKey)),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();

      controller.jumpTo(-30);
      final leading = probeKey.currentState!.scrollSnapshot;
      expect(leading.rawPixels, closeTo(-30, 0.001));
      expect(leading.contentOffset, 0.0);
      expect(leading.leadingOverscroll, closeTo(30, 0.001));
      expect(leading.trailingOverscroll, 0.0);

      final beyondEnd = controller.position.maxScrollExtent + 25;
      controller.jumpTo(beyondEnd);
      final trailing = probeKey.currentState!.scrollSnapshot;
      expect(trailing.rawPixels, closeTo(beyondEnd, 0.001));
      expect(trailing.contentOffset, closeTo(controller.position.maxScrollExtent, 0.001));
      expect(trailing.leadingOverscroll, 0.0);
      expect(trailing.trailingOverscroll, closeTo(25, 0.001));
    });

    testWidgets('普通外部 position 的活动不猜来源，但仍独立派发开始与结束', (tester) async {
      final controller = ScrollController();
      final probeKey = GlobalKey<_MixinProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            controller: controller,
            children: [
              SizedBox(height: 20, child: _MixinProbe(key: probeKey)),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();

      final state = probeKey.currentState!;
      final animation = controller.animateTo(160, duration: const Duration(milliseconds: 160), curve: Curves.linear);
      await tester.pump(const Duration(milliseconds: 40));
      expect(state.scrollSnapshot.activity, ElScrollActivityType.unknown);
      expect(state.activities, contains(ElScrollActivityType.unknown));

      await tester.pumpAndSettle();
      await animation;
      expect(state.scrollSnapshot.activity, ElScrollActivityType.idle);
      expect(state.activities, contains(ElScrollActivityType.idle));
      expect(state.startCount, greaterThanOrEqualTo(1));
      expect(state.endCount, greaterThanOrEqualTo(1));
    });

    testWidgets('pointer down 的 hold 与滚动条拖拽 activity 无需 pixels 变化也会通知', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_MixinProbeState>();

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            children: [
              SizedBox(height: 20, child: _MixinProbe(key: probeKey)),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pump();

      final state = probeKey.currentState!;
      final gesture = await tester.startGesture(const Offset(150, 100), kind: PointerDeviceKind.touch);
      await tester.pump();
      expect(state.scrollSnapshot.activity, ElScrollActivityType.hold);
      expect(state.activities, contains(ElScrollActivityType.hold));
      await gesture.up();
      await tester.pump();
      expect(state.scrollSnapshot.activity, ElScrollActivityType.idle);

      final render = hostKey.currentState!.debugScrollMixinViewportRenderObject!;
      render.handleScrollbarDragStarted();
      expect(state.scrollSnapshot.activity, ElScrollActivityType.scrollbarDrag);
      expect(state.activities, contains(ElScrollActivityType.scrollbarDrag));
      render.handleScrollbarDragEnded(null);
      expect(state.scrollSnapshot.activity, ElScrollActivityType.idle);
    });

    testWidgets('同一轴多个 observer 收到同一个 update snapshot 实例', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final keys = List<GlobalKey<_MixinProbeState>>.generate(100, (_) => GlobalKey<_MixinProbeState>());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            controller: controller,
            children: [
              for (final key in keys) SizedBox(height: 1, child: _MixinProbe(key: key)),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      );
      await tester.pump();

      final before = hostKey.currentState!.debugScrollMixinSnapshotBuildCount;
      controller.jumpTo(100);
      await tester.pump();

      final snapshots = <ElScrollSnapshot>[for (final key in keys) key.currentState!.lastUpdate!.snapshot];
      expect(snapshots.skip(1).every((snapshot) => identical(snapshot, snapshots.first)), isTrue);
      expect(hostKey.currentState!.debugScrollMixinSnapshotBuildCount - before, lessThan(10));
      expect(hostKey.currentState!.debugScrollMixinClientCount, 100);
    });

    testWidgets('同一 State 叠加多个效果 Mixin 仍只登记一个 client', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_CompositeProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            controller: controller,
            children: [
              SizedBox(height: 20, child: _CompositeProbe(key: probeKey)),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      );
      await tester.pump();

      controller.jumpTo(80);
      await tester.pump();
      expect(probeKey.currentState!.firstEffectCount, greaterThan(0));
      expect(probeKey.currentState!.secondEffectCount, greaterThan(0));
      expect(hostKey.currentState!.debugScrollMixinClientCount, 1);
    });

    testWidgets('updateScrollEffect 原位切换 observer 与 driver，不重复 attach', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_MixinProbeState>();

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            children: [
              SizedBox(height: 20, child: _MixinProbe(key: probeKey)),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      );
      await tester.pump();

      final state = probeKey.currentState!;
      expect(hostKey.currentState!.debugHasScrollInputParticipants(Axis.vertical), isFalse);
      state.updateInputDriver(true);
      expect(hostKey.currentState!.debugHasScrollInputParticipants(Axis.vertical), isTrue);
      expect(hostKey.currentState!.debugScrollMixinClientCount, 1);
      expect(state.attachCount, 1);
      expect(state.detachCount, 0);

      state.updateInputDriver(false);
      expect(hostKey.currentState!.debugHasScrollInputParticipants(Axis.vertical), isFalse);
      expect(hostKey.currentState!.debugScrollMixinClientCount, 1);
      expect(state.attachCount, 1);
      expect(state.detachCount, 0);
    });

    testWidgets('driver 的 pre-scroll 可同步吃掉 wheel，observer 不安装 driver', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final observerKey = GlobalKey<_MixinProbeState>();
      final driverKey = GlobalKey<_MixinProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: hostKey,
            controller: controller,
            children: [
              SizedBox(height: 20, child: _MixinProbe(key: observerKey)),
              SizedBox(height: 20, child: _MixinProbe(key: driverKey, inputDriver: true, consumePre: true)),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(hostKey.currentState!.debugHasScrollInputParticipants(Axis.vertical), isTrue);
      await tester.sendEventToBinding(
        const PointerScrollEvent(position: Offset(150, 100), kind: PointerDeviceKind.mouse, scrollDelta: Offset(0, 80)),
      );
      await tester.pump();

      final driver = driverKey.currentState!;
      expect(controller.offset, 0.0);
      expect(driver.preScrollCount, 1);
      expect(driver.preSources.single, ElScrollInputSource.pointerSignal);
      expect(observerKey.currentState!.preScrollCount, 0);
      expect(driver.activities, contains(ElScrollActivityType.pointerScroll));
    });

    testWidgets('driver 的 post-scroll 接收边界余量，fling 起飞经过 pre-fling', (tester) async {
      final controller = ScrollController();
      final driverKey = GlobalKey<_MixinProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            controller: controller,
            children: [
              SizedBox(
                height: 40,
                child: _MixinProbe(key: driverKey, inputDriver: true, consumePost: true, consumeFling: true),
              ),
              const SizedBox(height: 1600),
            ],
          ),
        ),
      );
      await tester.pump();

      final boundaryDrag = await tester.startGesture(const Offset(150, 80), kind: PointerDeviceKind.touch);
      await boundaryDrag.moveBy(const Offset(0, 24));
      await boundaryDrag.moveBy(const Offset(0, 60));
      await boundaryDrag.up();
      await tester.pump();
      expect(driverKey.currentState!.postScrollCount, greaterThan(0));

      await tester.fling(find.byType(ElScrollView), const Offset(0, -160), 1800);
      await tester.pump();
      expect(driverKey.currentState!.preFlingCount, greaterThan(0));
    });

    testWidgets('嵌套宿主按 axis 选择最近匹配者', (tester) async {
      final outerKey = GlobalKey<ElScrollViewState>();
      final innerKey = GlobalKey<ElScrollViewState>();
      final nearestKey = GlobalKey<_MixinProbeState>();
      final verticalKey = GlobalKey<_MixinProbeState>();

      await tester.pumpWidget(
        _frame(
          _mixinScroll(
            key: outerKey,
            children: [
              SizedBox(
                height: 100,
                child: _mixinScroll(
                  key: innerKey,
                  axis: Axis.horizontal,
                  children: [
                    SizedBox(width: 40, height: 100, child: _MixinProbe(key: nearestKey)),
                    SizedBox(
                      width: 40,
                      height: 100,
                      child: _MixinProbe(key: verticalKey, axis: Axis.vertical),
                    ),
                    const SizedBox(width: 900, height: 100),
                  ],
                ),
              ),
              const SizedBox(height: 900),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(nearestKey.currentState!.scrollView, same(innerKey.currentState));
      expect(nearestKey.currentState!.scrollSnapshot.axis, Axis.horizontal);
      expect(verticalKey.currentState!.scrollView, same(outerKey.currentState));
      expect(verticalKey.currentState!.scrollSnapshot.axis, Axis.vertical);
    });

    testWidgets('Mixin 自动重建开启时随 tick 重建，关闭时仍更新登记内快照', (tester) async {
      final controller = ScrollController();
      final listening = <ElScrollSnapshot>[];
      final passive = <ElScrollSnapshot>[];
      final hostKey = GlobalKey<ElScrollViewState>();
      addTearDown(controller.dispose);

      Widget tree() {
        return _frame(
          _mixinScroll(
            key: hostKey,
            controller: controller,
            children: [
              SizedBox(height: 20, child: _ListeningProbe(snapshots: listening, listen: true)),
              SizedBox(height: 20, child: _ListeningProbe(snapshots: passive, listen: false)),
              const SizedBox(height: 1200),
            ],
          ),
        );
      }

      await tester.pumpWidget(tree());
      await tester.pump();
      final listeningBuilds = listening.length;
      final passiveBuilds = passive.length;

      controller.jumpTo(140);
      await tester.pump();

      expect(listening.length, greaterThan(listeningBuilds));
      expect(listening.last.contentOffset, closeTo(140, 0.001));
      expect(passive.length, passiveBuilds);

      // 外部 rebuild 后，listen=false 返回期间持续维护的最新快照。
      await tester.pumpWidget(tree());
      expect(passive.length, passiveBuilds + 1);
      expect(passive.last.contentOffset, closeTo(140, 0.001));
      expect(hostKey.currentState!.debugScrollMixinClientCount, 2);
    });

    testWidgets('position 换代和 GlobalKey reparent 不留下旧宿主回调', (tester) async {
      final first = ScrollController();
      final second = ScrollController();
      final firstHostKey = GlobalKey<ElScrollViewState>();
      final secondHostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_MixinProbeState>();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget tree({required bool inFirst}) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              SizedBox(
                width: 250,
                height: 200,
                child: _mixinScroll(
                  key: firstHostKey,
                  controller: first,
                  children: [
                    if (inFirst) SizedBox(height: 20, child: _MixinProbe(key: probeKey)),
                    const SizedBox(height: 1000),
                  ],
                ),
              ),
              SizedBox(
                width: 250,
                height: 200,
                child: _mixinScroll(
                  key: secondHostKey,
                  controller: second,
                  children: [
                    if (!inFirst) SizedBox(height: 20, child: _MixinProbe(key: probeKey)),
                    const SizedBox(height: 1000),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      await tester.pumpWidget(tree(inFirst: true));
      await tester.pump();
      final state = probeKey.currentState!;
      expect(state.scrollView, same(firstHostKey.currentState));

      await tester.pumpWidget(tree(inFirst: false));
      await tester.pump();
      expect(probeKey.currentState, same(state));
      expect(state.scrollView, same(secondHostKey.currentState));
      expect(state.attachCount, 2);
      expect(state.detachCount, 1);

      final updates = state.updateCount;
      first.jumpTo(80);
      await tester.pump();
      expect(state.updateCount, updates);

      second.jumpTo(80);
      await tester.pump();
      expect(state.updateCount, greaterThan(updates));
    });
  });

  group('滚动作用域', () {
    testWidgets('direct child 获取真实公开 State，布局前 metrics 为空、布局后就绪', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ScopeProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _verticalScroll(
            key: hostKey,
            controller: controller,
            children: [
              SizedBox(height: 40, child: _ScopeProbe(key: probeKey)),
              const SizedBox(height: 600),
            ],
          ),
        ),
      );

      final host = hostKey.currentState!;
      final probe = probeKey.currentState!;
      expect(probe.host, same(host));
      expect(probe.verticalHost, same(host));
      expect(probe.horizontalHost, isNull);
      expect(probe.metricsAtDependency.first, isNull);
      expect(host.controller, same(controller));
      expect(host.position, same(controller.position));
      expect(host.axis, Axis.vertical);
      expect(host.axisDirection, AxisDirection.down);
      expect(host.reverse, isFalse);
      expect(host.hasContentDimensions, isTrue);
      expect(host.metrics, same(host.position));
      expect(host.positionFor(Axis.vertical), same(host.position));
      expect(host.positionFor(Axis.horizontal), isNull);
      expect(host.metricsFor(Axis.vertical), same(host.position));
      expect(host.metricsFor(Axis.horizontal), isNull);
    });

    testWidgets('未传 controller 时 State 创建并释放 fallback controller', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      await tester.pumpWidget(_frame(_verticalScroll(key: hostKey, children: const <Widget>[SizedBox(height: 500)])));

      final fallback = hostKey.currentState!.controller;
      expect(hostKey.currentState!.position, same(fallback.position));

      await tester.pumpWidget(const SizedBox.shrink());
      expect(() => fallback.addListener(() {}), throwsFlutterError);
    });

    testWidgets('maybeOf 找不到返回 null，of 给出后代结构提示', (tester) async {
      late BuildContext outsideContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              outsideContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(ElScrollView.maybeOf(outsideContext), isNull);
      expect(
        () => ElScrollView.of(outsideContext, axis: Axis.vertical),
        throwsA(
          isA<FlutterError>()
              .having((error) => error.toString(), 'message', contains('Axis.vertical'))
              .having((error) => error.toString(), 'hint', contains('真实后代'))
              .having((error) => error.toString(), 'context', contains('传入的 context')),
        ),
      );
    });

    testWidgets('嵌套横向滚动按轴跳过不匹配宿主，最近任意宿主仍是内层', (tester) async {
      final outerKey = GlobalKey<ElScrollViewState>();
      final innerKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ScopeProbeState>();

      await tester.pumpWidget(
        _frame(
          _verticalScroll(
            key: outerKey,
            children: [
              SizedBox(
                height: 100,
                child: ElScrollView(
                  key: innerKey,
                  axis: Axis.horizontal,
                  scrollbar: const ElNoScrollBar(),
                  physics: const ClampingScrollPhysics(),
                  children: [SizedBox(width: 800, height: 100, child: _ScopeProbe(key: probeKey))],
                ),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      );

      final probe = probeKey.currentState!;
      expect(probe.host, same(innerKey.currentState));
      expect(probe.horizontalHost, same(innerKey.currentState));
      expect(probe.verticalHost, same(outerKey.currentState));
    });

    testWidgets('嵌套同轴滚动返回最近宿主', (tester) async {
      final outerKey = GlobalKey<ElScrollViewState>();
      final innerKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ScopeProbeState>();

      await tester.pumpWidget(
        _frame(
          _verticalScroll(
            key: outerKey,
            children: [
              SizedBox(
                height: 120,
                child: _verticalScroll(
                  key: innerKey,
                  children: [
                    SizedBox(height: 40, child: _ScopeProbe(key: probeKey)),
                    const SizedBox(height: 500),
                  ],
                ),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      );

      final probe = probeKey.currentState!;
      expect(probe.host, same(innerKey.currentState));
      expect(probe.verticalHost, same(innerKey.currentState));
      expect(probe.verticalHost, isNot(same(outerKey.currentState)));
    });

    testWidgets('双轴宿主同时匹配 vertical 与 horizontal 并返回各自 position', (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ScopeProbeState>();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);

      await tester.pumpWidget(
        _frame(
          ElScrollView(
            key: hostKey,
            axis: null,
            controller: vertical,
            horizontalController: horizontal,
            scrollbar: const ElNoScrollBar(),
            physics: const ClampingScrollPhysics(),
            children: [SizedBox(width: 800, height: 600, child: _ScopeProbe(key: probeKey))],
          ),
        ),
      );

      final host = hostKey.currentState!;
      final probe = probeKey.currentState!;
      expect(host.axis, isNull);
      expect(host.controller, same(vertical));
      expect(host.horizontalController, same(horizontal));
      expect(host.position, same(vertical.position));
      expect(host.horizontalPosition, same(horizontal.position));
      expect(host.positionFor(Axis.vertical), same(vertical.position));
      expect(host.positionFor(Axis.horizontal), same(horizontal.position));
      expect(host.metricsFor(Axis.vertical), same(vertical.position));
      expect(host.metricsFor(Axis.horizontal), same(horizontal.position));
      expect(probe.verticalHost, same(host));
      expect(probe.horizontalHost, same(host));
    });

    testWidgets('physics、reverse 与 axis 换代保持 State identity 并替换 position', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ScopeProbeState>();
      addTearDown(controller.dispose);

      Widget tree({required ScrollPhysics physics, required Axis axis, required bool reverse}) {
        return _frame(
          ElScrollView(
            key: hostKey,
            controller: controller,
            axis: axis,
            reverse: reverse,
            scrollbar: const ElNoScrollBar(),
            smoothScroll: const ElNoSmoothScroll(),
            physics: physics,
            children: [SizedBox(width: 1200, height: 1200, child: _ScopeProbe(key: probeKey))],
          ),
        );
      }

      await tester.pumpWidget(tree(physics: const ClampingScrollPhysics(), axis: Axis.vertical, reverse: false));
      final host = hostKey.currentState!;
      final probe = probeKey.currentState!;
      var previousPosition = host.position;
      var dependencies = probe.dependencyCount;

      await tester.pumpWidget(tree(physics: const BouncingScrollPhysics(), axis: Axis.vertical, reverse: false));
      expect(hostKey.currentState, same(host));
      expect(host.position, isNot(same(previousPosition)));
      expect(probe.dependencyCount, dependencies + 1);
      previousPosition = host.position;
      dependencies = probe.dependencyCount;

      await tester.pumpWidget(tree(physics: const BouncingScrollPhysics(), axis: Axis.vertical, reverse: true));
      expect(hostKey.currentState, same(host));
      expect(host.position, isNot(same(previousPosition)));
      expect(host.reverse, isTrue);
      expect(probe.dependencyCount, dependencies + 1);
      previousPosition = host.position;
      dependencies = probe.dependencyCount;

      await tester.pumpWidget(tree(physics: const BouncingScrollPhysics(), axis: Axis.horizontal, reverse: false));
      expect(hostKey.currentState, same(host));
      expect(host.position, isNot(same(previousPosition)));
      expect(host.axis, Axis.horizontal);
      expect(host.positionFor(Axis.horizontal), same(host.position));
      expect(host.positionFor(Axis.vertical), isNull);
      expect(probe.dependencyCount, dependencies + 1);
      expect(controller.position, same(host.position));
    });

    testWidgets('ElScrollView 自身 context 不会向下找到自己', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      await tester.pumpWidget(_frame(_verticalScroll(key: hostKey, children: const <Widget>[SizedBox(height: 500)])));

      expect(ElScrollView.maybeOf(hostKey.currentState!.context), isNull);
    });

    testWidgets('创建 ElScrollView 的祖先 PageState 不会向下绑定', (tester) async {
      final pageKey = GlobalKey<_PageCreatesScrollState>();
      await tester.pumpWidget(_frame(_PageCreatesScroll(key: pageKey)));
      expect(pageKey.currentState!.hostSeenByPage, isNull);
    });

    testWidgets('根 State rebuild 始终通知一次依赖，同宿主不变且滚动 tick 不重建根或 dependent', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ScopeProbeState>();
      final probeWidget = SizedBox(height: 40, child: _ScopeProbe(key: probeKey));
      final tail = const SizedBox(height: 2000);
      addTearDown(controller.dispose);

      Widget tree() => _frame(_verticalScroll(key: hostKey, controller: controller, children: [probeWidget, tail]));

      await tester.pumpWidget(tree());
      await tester.pump();
      final host = hostKey.currentState!;
      final probe = probeKey.currentState!;
      final initialPosition = host.position;
      final dependencyBeforeRebuild = probe.dependencyCount;
      final buildBeforeRebuild = probe.buildCount;

      await tester.pumpWidget(tree());
      expect(hostKey.currentState, same(host));
      expect(host.position, same(initialPosition));
      expect(probe.host, same(host));
      expect(probe.dependencyCount, dependencyBeforeRebuild + 1);
      expect(probe.buildCount, buildBeforeRebuild + 1);

      final hostBuildBeforeScroll = host.debugCounters.debugBuildCount;
      final dependencyBeforeScroll = probe.dependencyCount;
      final probeBuildBeforeScroll = probe.buildCount;
      final max = controller.position.maxScrollExtent;
      for (var index = 1; index <= 100; index++) {
        controller.jumpTo((index * 17.0) % max);
      }
      await tester.pump();

      expect(host.debugCounters.debugBuildCount, hostBuildBeforeScroll);
      expect(probe.dependencyCount, dependencyBeforeScroll);
      expect(probe.buildCount, probeBuildBeforeScroll);
    });

    testWidgets('touch、wheel 与 fling 热路径均不触发根 State 或 Scope dependent build', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ScopeProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _frame(
          _verticalScroll(
            key: hostKey,
            controller: controller,
            children: [
              SizedBox(height: 40, child: _ScopeProbe(key: probeKey)),
              const SizedBox(height: 20000),
            ],
          ),
        ),
      );
      await tester.pump();

      final host = hostKey.currentState!;
      final probe = probeKey.currentState!;
      final hostBuilds = host.debugCounters.debugBuildCount;
      final dependencies = probe.dependencyCount;
      final probeBuilds = probe.buildCount;

      final drag = await tester.startGesture(const Offset(150, 150), kind: PointerDeviceKind.touch);
      for (var index = 0; index < 100; index++) {
        await drag.moveBy(const Offset(0, -2));
      }
      await drag.up();
      await tester.pumpAndSettle();

      for (var index = 0; index < 100; index++) {
        await tester.sendEventToBinding(
          const PointerScrollEvent(
            position: Offset(150, 150),
            kind: PointerDeviceKind.mouse,
            scrollDelta: Offset(0, 2),
          ),
        );
      }
      await tester.pump();

      await tester.fling(find.byType(ElScrollView), const Offset(0, -500), 2400);
      for (var index = 0; index < 100; index++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(host.debugCounters.debugBuildCount, hostBuilds);
      expect(probe.dependencyCount, dependencies);
      expect(probe.buildCount, probeBuilds);
    });

    testWidgets('嵌套 scroll 的 local positioned descendant 不误绑外层宿主', (tester) async {
      final outerKey = GlobalKey<ElScrollViewState>();
      final innerKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ScopeProbeState>();

      await tester.pumpWidget(
        _frame(
          _verticalScroll(
            key: outerKey,
            children: [
              SizedBox(
                height: 120,
                child: _verticalScroll(
                  key: innerKey,
                  children: [
                    const SizedBox(height: 500),
                    ElPositioned(
                      left: 0,
                      top: 0,
                      child: SizedBox(width: 40, height: 40, child: _ScopeProbe(key: probeKey)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(probeKey.currentState!.host, same(innerKey.currentState));
      expect(probeKey.currentState!.host, isNot(same(outerKey.currentState)));
    });

    testWidgets('Sliver builder item 与 scroll positioned child 都能发现所属宿主', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final sliverProbeKey = GlobalKey<_ScopeProbeState>();
      final positionedProbeKey = GlobalKey<_ScopeProbeState>();

      await tester.pumpWidget(
        _frame(
          _verticalScroll(
            key: hostKey,
            children: [
              ElListView.builder(
                itemCount: 30,
                itemBuilder: (context, index) => index == 0
                    ? SizedBox(height: 40, child: _ScopeProbe(key: sliverProbeKey))
                    : const SizedBox(height: 40),
              ),
              ElPositioned(
                left: 0,
                top: 0,
                child: SizedBox(width: 40, height: 40, child: _ScopeProbe(key: positionedProbeKey)),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(sliverProbeKey.currentState!.host, same(hostKey.currentState));
      expect(positionedProbeKey.currentState!.host, same(hostKey.currentState));
    });
  });

  group('基础滚动行为', () {
    Widget shell(Widget child, {double width = 400, double height = 600}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      );
    }

    testWidgets('普通 children 纵向堆叠时 padding 与 gap 落位', (tester) async {
      await tester.pumpWidget(
        shell(
          ElScrollView(
            padding: const EdgeInsets.all(20),
            gap: 10,
            children: const [
              SizedBox(key: ValueKey('a'), width: 100, height: 100),
              SizedBox(key: ValueKey('b'), width: 100, height: 100),
            ],
          ),
        ),
      );

      expect(tester.getTopLeft(find.byKey(const ValueKey('a'))), const Offset(20, 20));
      expect(tester.getTopLeft(find.byKey(const ValueKey('b'))), const Offset(20, 130));
    });

    testWidgets('controller jumpTo 平移内容且 extent 包含 gap', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            gap: 10,
            children: [for (var index = 0; index < 20; index++) SizedBox(key: ValueKey('plain-$index'), height: 100)],
          ),
        ),
      );

      expect(controller.position.maxScrollExtent, 1590);
      controller.jumpTo(50);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const ValueKey('plain-0'))).dy, -50);
    });

    testWidgets('触摸拖拽接通滚动输入管线', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            children: [for (var index = 0; index < 20; index++) const SizedBox(height: 100)],
          ),
        ),
      );
      await tester.drag(find.byType(ElScrollView), const Offset(0, -200));
      await tester.pump();

      expect(controller.offset, greaterThan(0));
    });

    testWidgets('横向单轴按水平主轴排列普通 children', (tester) async {
      await tester.pumpWidget(
        shell(
          ElScrollView(
            axis: Axis.horizontal,
            gap: 10,
            children: const [
              SizedBox(key: ValueKey('a'), width: 100, height: 100),
              SizedBox(key: ValueKey('b'), width: 100, height: 100),
            ],
          ),
        ),
      );

      expect(tester.getTopLeft(find.byKey(const ValueKey('a'))), Offset.zero);
      expect(tester.getTopLeft(find.byKey(const ValueKey('b'))), const Offset(110, 0));
    });

    testWidgets('裸 ElListView 窗口化挂载并支持远端跳转', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            cacheExtent: 0,
            children: [
              ElListView.builder(
                itemCount: 1000,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('virtual-$index'), height: 40),
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(const ValueKey('virtual-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('virtual-500')), findsNothing);
      expect(controller.position.maxScrollExtent, greaterThan(30000));

      controller.jumpTo(500 * 40.0);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('virtual-500')), findsOneWidget);
      expect(find.byKey(const ValueKey('virtual-0')), findsNothing);
    });
  });

  group('Mixin 登记与更新通道', () {
    testWidgets('输入 slot 稳态不重复解析顺序、不重建根，诊断明确记录每次分账', (tester) async {
      final key = GlobalKey<ElScrollViewState>();
      await tester.pumpWidget(
        _frame(
          ElScrollView(
            key: key,
            scrollbar: const ElNoScrollBar(),
            smoothScroll: const ElNoSmoothScroll(),
            inputOrder: const {
              Axis.vertical: [#a, #b],
            },
            children: const [
              ScrollMixinClientProbe(scrollInputSlot: #a),
              ScrollMixinClientProbe(scrollInputSlot: #b),
              ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      final host = key.currentState!;
      final resolves = host.debugScrollInputOrderResolveCount;
      final builds = host.debugCounters.debugBuildCount;
      expect(resolves, greaterThan(0));
      host.debugRecordScrollInputTrace();
      for (var index = 0; index < 120; index++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(position: const Offset(150, 100), scrollDelta: const Offset(0, 1)),
        );
        await tester.pump(const Duration(milliseconds: 8));
      }
      expect(host.debugScrollInputOrderResolveCount, resolves);
      expect(host.debugCounters.debugBuildCount, builds);
      expect(host.position.pixels, 120);
      expect(host.debugScrollInputTrace, hasLength(240));
      expect(host.debugScrollInputTrace.first, (slot: #a, phase: 'onPreScroll', input: 1.0, remaining: 1.0));
      expect(host.debugScrollInputTrace[1].slot, #b);
    });

    testWidgets('普通滚动及纯 observer 均不分配输入路由器', (tester) async {
      for (final observer in [false, true]) {
        final key = GlobalKey<ElScrollViewState>();
        await tester.pumpWidget(
          _frame(
            ElScrollView(
              key: key,
              scrollbar: const ElNoScrollBar(),
              children: [
                if (observer) const ScrollMixinClientProbe(),
                const ElView(style: ElStyle(height: 1000)),
              ],
            ),
          ),
        );
        await tester.pump();
        expect(key.currentState!.debugScrollInputRouterAllocated, isFalse);
      }
    });

    testWidgets('后代首次登记一次；同宿主 rebuild 只 update、不重复 attach', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<ScrollMixinClientProbeState>();

      await tester.pumpWidget(_verticalTree(hostKey: hostKey, probeKey: probeKey));
      await tester.pump();

      final host = hostKey.currentState!;
      final probe = probeKey.currentState!;
      expect(probe.scrollView, same(host));
      expect(host.debugScrollMixinClientCount, 1);
      expect(host.debugScrollMixinClientRegistryAllocated, isTrue);
      expect(probe.attachCount, 1);
      expect(probe.detachCount, 0);
      expect(probe.metricsChangedCount, 1);
      expect(probe.lastMetrics, isNot(isA<ScrollPosition>()));
      expect(probe.lastMetrics!.viewportDimension, host.metrics!.viewportDimension);
      expect(probe.lastMetrics!.maxScrollExtent, host.metrics!.maxScrollExtent);

      final dependencyBefore = probe.dependencyCount;
      final buildBefore = probe.buildCount;
      await tester.pumpWidget(_verticalTree(hostKey: hostKey, probeKey: probeKey));
      await tester.pump();

      expect(hostKey.currentState, same(host));
      expect(probeKey.currentState, same(probe));
      expect(probe.dependencyCount, dependencyBefore + 1);
      expect(probe.buildCount, buildBefore + 1);
      expect(probe.attachCount, 1);
      expect(probe.detachCount, 0);
      expect(host.debugScrollMixinClientCount, 1);
    });

    testWidgets('同一个 State 同步多个行为配置仍只占一个 client handle', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<ScrollMixinClientProbeState>();

      await tester.pumpWidget(
        _verticalTree(hostKey: hostKey, probeKey: probeKey, wantsViewportUpdates: false, scrollInputSlot: null),
      );
      await tester.pump();
      final probe = probeKey.currentState!;
      expect(hostKey.currentState!.debugScrollMixinClientCount, 1);
      expect(probe.attachCount, 1);
      expect(probe.metricsChangedCount, 0);
      expect(hostKey.currentState!.debugHasScrollInputParticipants(Axis.vertical), isFalse);

      await tester.pumpWidget(
        _verticalTree(hostKey: hostKey, probeKey: probeKey, wantsViewportUpdates: true, scrollInputSlot: #probe),
      );
      await tester.pump();

      expect(probeKey.currentState, same(probe));
      expect(hostKey.currentState!.debugScrollMixinClientCount, 1);
      expect(hostKey.currentState!.debugHasScrollInputParticipants(Axis.vertical), isTrue);
      expect(probe.attachCount, 1);
      expect(probe.detachCount, 0);
      expect(probe.metricsChangedCount, 1);
    });

    testWidgets('controller/position 换代保留单一 client，旧 position 不再回调', (tester) async {
      final firstController = ScrollController();
      final secondController = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<ScrollMixinClientProbeState>();
      addTearDown(firstController.dispose);
      addTearDown(secondController.dispose);

      Widget tree({required ScrollController primaryController, required bool mountOldController}) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 300,
                height: 200,
                child: _mixinClientChannelScroll(
                  key: hostKey,
                  controller: primaryController,
                  children: <Widget>[
                    SizedBox(height: 40, child: ScrollMixinClientProbe(key: probeKey)),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
              SizedBox(
                width: 300,
                height: 200,
                child: mountOldController
                    ? ListView(controller: firstController, children: const <Widget>[SizedBox(height: 1200)])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }

      await tester.pumpWidget(tree(primaryController: firstController, mountOldController: false));
      await tester.pump();
      final host = hostKey.currentState!;
      final probe = probeKey.currentState!;
      final firstPosition = host.position;
      final dependencyBefore = probe.dependencyCount;

      await tester.pumpWidget(tree(primaryController: secondController, mountOldController: true));
      await tester.pump();

      expect(hostKey.currentState, same(host));
      expect(host.position, isNot(same(firstPosition)));
      expect(host.position, same(secondController.position));
      expect(firstController.position, isNot(same(firstPosition)));
      expect(probe.dependencyCount, dependencyBefore + 1);
      expect(probe.attachCount, 1);
      expect(probe.detachCount, 0);
      expect(host.debugScrollMixinClientCount, 1);

      final startsBeforeOld = probe.scrollStartCount;
      final updatesBeforeOld = probe.scrollUpdateCount;
      final endsBeforeOld = probe.scrollEndCount;
      final oldAnimation = firstController.animateTo(
        120,
        duration: const Duration(milliseconds: 64),
        curve: Curves.linear,
      );
      await tester.pump();
      await tester.pumpAndSettle();
      await oldAnimation;
      expect(probe.scrollStartCount, startsBeforeOld);
      expect(probe.scrollUpdateCount, updatesBeforeOld);
      expect(probe.scrollEndCount, endsBeforeOld);

      final animation = secondController.animateTo(
        240,
        duration: const Duration(milliseconds: 96),
        curve: Curves.linear,
      );
      await tester.pump();
      await tester.pumpAndSettle();
      await animation;

      expect(probe.scrollStartCount, greaterThan(startsBeforeOld));
      expect(probe.scrollUpdateCount, greaterThan(updatesBeforeOld));
      expect(probe.scrollEndCount, greaterThan(endsBeforeOld));
      expect(probe.lastCallbackAxis, Axis.vertical);
      expect(probe.lastPosition, same(secondController.position));
    });

    testWidgets('多个 observer 合法，同一轴重复 input slot 明确报错', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final firstObserver = GlobalKey<ScrollMixinClientProbeState>();
      final secondObserver = GlobalKey<ScrollMixinClientProbeState>();

      await tester.pumpWidget(
        _frame(
          _mixinClientChannelScroll(
            key: hostKey,
            children: <Widget>[
              SizedBox(height: 40, child: ScrollMixinClientProbe(key: firstObserver)),
              SizedBox(height: 40, child: ScrollMixinClientProbe(key: secondObserver)),
              const SizedBox(height: 800),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(hostKey.currentState!.debugScrollMixinClientCount, 2);
      expect(firstObserver.currentState!.attachCount, 1);
      expect(secondObserver.currentState!.attachCount, 1);

      final firstDriver = GlobalKey<ScrollMixinClientProbeState>();
      final secondDriver = GlobalKey<ScrollMixinClientProbeState>();
      await tester.pumpWidget(
        _frame(
          _mixinClientChannelScroll(
            children: <Widget>[
              SizedBox(
                height: 40,
                child: ScrollMixinClientProbe(key: firstDriver, scrollInputSlot: #probe),
              ),
              SizedBox(
                height: 40,
                child: ScrollMixinClientProbe(key: secondDriver, scrollInputSlot: #probe),
              ),
              const SizedBox(height: 800),
            ],
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(error.toString(), contains('重复 input slot'));
      expect(error.toString(), contains('Axis.vertical'));
      expect(error.toString(), contains('ScrollMixinClientProbeState'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('GlobalKey client 从一个 scroll 移到另一个 scroll 时原子换绑', (tester) async {
      final firstHostKey = GlobalKey<ElScrollViewState>();
      final secondHostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<ScrollMixinClientProbeState>();

      Widget tree(bool inFirst) {
        final probe = SizedBox(height: 40, child: ScrollMixinClientProbe(key: probeKey));
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 280,
                height: 200,
                child: _mixinClientChannelScroll(
                  key: firstHostKey,
                  children: <Widget>[if (inFirst) probe, const SizedBox(height: 900)],
                ),
              ),
              SizedBox(
                width: 280,
                height: 200,
                child: _mixinClientChannelScroll(
                  key: secondHostKey,
                  children: <Widget>[if (!inFirst) probe, const SizedBox(height: 900)],
                ),
              ),
            ],
          ),
        );
      }

      await tester.pumpWidget(tree(true));
      await tester.pump();
      final probe = probeKey.currentState!;
      expect(probe.scrollView, same(firstHostKey.currentState));
      expect(firstHostKey.currentState!.debugScrollMixinClientCount, 1);
      expect(secondHostKey.currentState!.debugScrollMixinClientCount, 0);

      await tester.pumpWidget(tree(false));
      await tester.pump();

      expect(probeKey.currentState, same(probe));
      expect(probe.scrollView, same(secondHostKey.currentState));
      expect(probe.attachCount, 2);
      expect(probe.detachCount, 1);
      expect(firstHostKey.currentState!.debugScrollMixinClientCount, 0);
      expect(secondHostKey.currentState!.debugScrollMixinClientCount, 1);
    });

    testWidgets('client dispose 后宿主清空登记，后续滚动不再回调死 State', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<ScrollMixinClientProbeState>();
      addTearDown(controller.dispose);

      Widget tree({required bool showProbe}) {
        return _frame(
          _mixinClientChannelScroll(
            key: hostKey,
            controller: controller,
            children: <Widget>[
              if (showProbe) SizedBox(height: 40, child: ScrollMixinClientProbe(key: probeKey)),
              const SizedBox(height: 1200),
            ],
          ),
        );
      }

      await tester.pumpWidget(tree(showProbe: true));
      await tester.pump();
      final probe = probeKey.currentState!;
      final updatesBeforeDispose = probe.scrollUpdateCount;

      await tester.pumpWidget(tree(showProbe: false));
      await tester.pump();
      expect(probe.mounted, isFalse);
      expect(probe.detachCount, 1);
      expect(hostKey.currentState!.debugScrollMixinClientCount, 0);
      expect(hostKey.currentState!.debugScrollMixinClientRegistryAllocated, isFalse);

      controller.jumpTo(200);
      await tester.pump();
      expect(probe.scrollUpdateCount, updatesBeforeDispose);
    });

    testWidgets('宿主与 client 同时卸载时只 detach 一次且不残留回调', (tester) async {
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<ScrollMixinClientProbeState>();

      await tester.pumpWidget(_verticalTree(hostKey: hostKey, probeKey: probeKey));
      await tester.pump();
      final probe = probeKey.currentState!;
      expect(probe.attachCount, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(probe.mounted, isFalse);
      expect(probe.detachCount, 1);
    });

    testWidgets('viewport 尺寸变化只派发 metrics，普通 pixels 变化不伪造 metrics-only 更新', (tester) async {
      final controller = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<ScrollMixinClientProbeState>();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_verticalTree(hostKey: hostKey, probeKey: probeKey, controller: controller, height: 200));
      await tester.pump();
      final probe = probeKey.currentState!;
      final metricsBeforeScroll = probe.metricsChangedCount;

      controller.jumpTo(160);
      await tester.pump();
      expect(probe.scrollUpdateCount, greaterThan(0));
      expect(probe.metricsChangedCount, metricsBeforeScroll);

      await tester.pumpWidget(_verticalTree(hostKey: hostKey, probeKey: probeKey, controller: controller, height: 140));
      await tester.pump();

      expect(probe.metricsChangedCount, greaterThan(metricsBeforeScroll));
      expect(probe.lastMetrics, isNotNull);
      expect(probe.lastMetrics!.viewportDimension, 140);
      expect(probe.attachCount, 1);
    });

    testWidgets('双轴 horizontal client 监听真实水平 position', (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<ScrollMixinClientProbeState>();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);

      await tester.pumpWidget(
        _frame(
          _mixinClientChannelScroll(
            key: hostKey,
            axis: null,
            controller: vertical,
            horizontalController: horizontal,
            children: <Widget>[
              SizedBox(
                width: 900,
                height: 600,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ScrollMixinClientProbe(key: probeKey, axis: Axis.horizontal),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final host = hostKey.currentState!;
      final probe = probeKey.currentState!;
      expect(probe.scrollView, same(host));
      expect(host.debugScrollMixinClientCount, 1);
      expect(horizontal.position.maxScrollExtent, greaterThan(0));

      final animation = horizontal.animateTo(180, duration: const Duration(milliseconds: 96), curve: Curves.linear);
      await tester.pump();
      await tester.pumpAndSettle();
      await animation;

      expect(probe.scrollStartCount, greaterThanOrEqualTo(1));
      expect(probe.scrollUpdateCount, greaterThan(0));
      expect(probe.scrollEndCount, greaterThanOrEqualTo(1));
      expect(probe.lastCallbackAxis, Axis.horizontal);
      expect(probe.lastPosition, same(host.horizontalPosition));
      expect(probe.lastMetrics, isNot(isA<ScrollPosition>()));
      expect(probe.lastMetrics!.axis, Axis.horizontal);
      expect(probe.lastMetrics!.viewportDimension, host.metricsFor(Axis.horizontal)!.viewportDimension);
      expect(probe.lastMetrics!.pixels, 0, reason: '历史尺寸事件不能随活 position 的后续位移改变');
    });
  });

  group('Mixin 输入来源', () {
    for (final optimized in [false, true]) {
      testWidgets('真实 thumb 拖动归因为用户运动，dragOptimize=$optimized', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final observer = GlobalKey<_ObserverState>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 300, height: 200),
                child: ElScrollView(
                  controller: controller,
                  dragOptimize: optimized,
                  scrollbar: const ElWindowScrollBar(),
                  children: [_Observer(key: observer)],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('el-scrollbar-thumb-vertical'))),
          kind: PointerDeviceKind.mouse,
        );
        addTearDown(gesture.removePointer);
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        expect(controller.offset, greaterThan(100));
        final movement = observer.currentState!.samples.where((sample) => sample.motionDelta.abs() > .01);
        expect(movement, isNotEmpty);
        for (final sample in movement) {
          expect(sample.activity, ElScrollActivityType.scrollbarDrag);
          expect(sample.cause, ElScrollUpdateCause.userInput);
        }
        observer.currentState!.samples.clear();
        controller.jumpTo(30);
        expect(observer.currentState!.samples.last.cause, ElScrollUpdateCause.externalCommand);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('成员顺序协议', () {
    testWidgets('T36 横向并列成员的拖选与复制遵循文档序，不随 zIndex 变化', (tester) async {
      final selection = ElSelectionController();
      addTearDown(() async {
        selection.clear();
        await tester.pumpWidget(const SizedBox.shrink());
        selection.dispose();
      });
      for (final layer in [10, 0]) {
        await tester.pumpWidget(
          _orderProtocolFrame(
            ElSelectionView(
              controller: selection,
              child: ElScrollView(
                scrollbar: const ElNoScrollBar(),
                children: [
                  const _TextRow('AAAAAA', key: ValueKey('a'), left: 0, layer: 0),
                  _TextRow('BBBBBB', key: const ValueKey('b'), left: 90, layer: layer),
                  const _TextRow('CCCCCC', key: ValueKey('c'), left: 180, layer: 0),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        final gesture = await tester.startGesture(const Offset(1, 8), kind: PointerDeviceKind.mouse);
        await gesture.moveTo(const Offset(265, 8));
        await gesture.up();
        await tester.pump();
        expect(selection.text, contains('BBBBBB'), reason: '选择首项至末项应包含中间成员，layer=$layer');
        final text = selection.text!;
        expect(text.indexOf('AAAA'), lessThan(text.indexOf('BBBB')));
        expect(text.indexOf('BBBB'), lessThan(text.indexOf('CCCC')));
        selection.clear();
        await tester.pump();
      }
    });

    testWidgets('T36 显式阅读顺序独立于语义绘制和命中顺序', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final layer in [0, 10]) {
        await tester.pumpWidget(
          _orderProtocolFrame(
            ElScrollView(
              scrollbar: const ElNoScrollBar(),
              children: [
                ElPositioned(
                  left: 0,
                  top: 0,
                  zIndex: layer,
                  child: ElView(
                    semantics: ElSemantics(
                      container: true,
                      properties: const SemanticsProperties(
                        label: 'first',
                        sortKey: OrdinalSortKey(0),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    style: const ElStyle(width: 100, height: 40),
                  ),
                ),
                ElPositioned(
                  left: 0,
                  top: 0,
                  child: ElView(
                    semantics: ElSemantics(
                      container: true,
                      properties: const SemanticsProperties(
                        label: 'second',
                        sortKey: OrdinalSortKey(1),
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    style: const ElStyle(width: 100, height: 40),
                  ),
                ),
              ],
            ),
          ),
        );
        List<String> labels(DebugSemanticsDumpOrder order) {
          final result = <String>[];
          void collect(SemanticsNode node) {
            if (node.label == 'first' || node.label == 'second') result.add(node.label);
            for (final child in node.debugListChildrenInOrder(order)) {
              collect(child);
            }
          }

          // ignore: deprecated_member_use
          collect(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
          return result;
        }

        expect(labels(DebugSemanticsDumpOrder.traversalOrder), ['first', 'second']);
        expect(labels(DebugSemanticsDumpOrder.inverseHitTest), layer == 0 ? ['first', 'second'] : ['second', 'first']);
      }
      semantics.dispose();
    });
  });

  group('位置观察', () {
    for (final explicit in [false, true]) {
      testWidgets('真实可观测 position：${explicit ? 'ElScrollController' : '默认控制器'}', (tester) async {
        final hostKey = GlobalKey<ElScrollViewState>();
        final probeKey = GlobalKey<_ProbeState>();
        final provided = explicit ? ElScrollController() : null;
        if (provided != null) addTearDown(provided.dispose);
        await tester.pumpWidget(
          _positionObservationFrame(
            ElScrollView(
              key: hostKey,
              controller: provided,
              physics: const ClampingScrollPhysics(),
              scrollbar: const ElNoScrollBar(),
              children: [
                _Probe(key: probeKey),
                const ElView(style: ElStyle(height: 1000)),
              ],
            ),
          ),
        );
        await tester.pump();
        final probe = probeKey.currentState!;
        final controller = probe.scrollController!;
        expect(controller.positions, hasLength(1));
        expect(probe.scrollPosition, same(hostKey.currentState!.position));
        expect(probe.scrollPosition, same(controller.position));
        if (provided != null) expect(controller, same(provided));
        if (provided != null) {
          final additional = provided.createScrollPosition(provided.position.physics, provided.position.context, null);
          expect(() => provided.attach(additional), throwsA(isA<FlutterError>()));
          additional.dispose();
          expect(provided.positions, hasLength(1));
        }

        probe.updates.clear();
        controller.jumpTo(80);
        final motion = probe.updates.where((snapshot) => snapshot.motionDelta != 0).single;
        expect(motion.cause, ElScrollUpdateCause.externalCommand);
        expect(motion.motionDelta, 80);

        final animation = controller.animateTo(200, duration: const Duration(milliseconds: 160), curve: Curves.linear);
        expect(probe.scrollSnapshot.activity, ElScrollActivityType.programmatic);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(probe.updates.last.cause, ElScrollUpdateCause.externalCommand);
        await tester.pumpAndSettle();
        await animation;
        expect(controller.offset, 200);
        expect(probe.scrollSnapshot.activity, ElScrollActivityType.idle);

        final hold = controller.position.hold(() {});
        expect(probe.scrollSnapshot.activity, ElScrollActivityType.hold);
        hold.cancel();
        expect(probe.scrollSnapshot.activity, ElScrollActivityType.idle);
        expect(probe.activities, containsAll([ElScrollActivityType.programmatic, ElScrollActivityType.hold]));
        await tester.pumpWidget(const ElView());
        expect(controller.hasClients, isFalse);
      });
    }

    testWidgets('外部自定义 controller 工厂真实生效，不猜测其 activity', (tester) async {
      final controller = _CustomController();
      addTearDown(controller.dispose);
      final probeKey = GlobalKey<_ProbeState>();
      await tester.pumpWidget(
        _positionObservationFrame(
          ElScrollView(
            controller: controller,
            scrollbar: const ElNoScrollBar(),
            children: [
              _Probe(key: probeKey),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(controller.factoryCalls, greaterThan(0));
      expect(controller.position, isA<_CustomPosition>());
      final animation = controller.animateTo(100, duration: const Duration(milliseconds: 100), curve: Curves.linear);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(probeKey.currentState!.scrollSnapshot.activity, ElScrollActivityType.unknown);
      expect(probeKey.currentState!.updates.last.cause, ElScrollUpdateCause.unknown);
      await tester.pumpAndSettle();
      await animation;
    });

    testWidgets('ElScrollController 随真实宿主重父化成对摘挂位置与索引桥', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final hostKey = GlobalKey<ElScrollViewState>();
      final probeKey = GlobalKey<_ProbeState>();
      var left = true;
      late StateSetter update;
      await tester.pumpWidget(
        _positionObservationFrame(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              final scroll = ElScrollView(
                key: hostKey,
                controller: controller,
                smoothScroll: const ElNoSmoothScroll(),
                scrollbar: const ElNoScrollBar(),
                children: [
                  _Probe(key: probeKey),
                  const ElView(style: ElStyle(height: 1000)),
                ],
              );
              return Row(
                children: [
                  Expanded(child: left ? scroll : const ElView()),
                  Expanded(child: left ? const ElView() : scroll),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      final host = hostKey.currentState;
      update(() => left = false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(hostKey.currentState, same(host));
      expect(probeKey.currentState!.scrollView, same(host));
      expect(controller.positions, hasLength(1));
      expect(
        controller.dispatchPointerScroll(
          PointerScrollEvent(position: tester.getCenter(find.byKey(hostKey)), scrollDelta: const Offset(0, 80)),
        ),
        isTrue,
      );
      expect(controller.offset, 80);
    });
  });

  group('作用域换绑', () {
    for (final outerSupportsAxis in [false, true]) {
      testWidgets('T33 被跳过的 inner 新增匹配轴后独立接管（outer支持=$outerSupportsAxis）', (tester) async {
        final outer = GlobalKey<ElScrollViewState>();
        final inner = GlobalKey<ElScrollViewState>();
        final changer = GlobalKey<_InnerState>();
        final reader = GlobalKey<_ReaderState>();
        final outerReader = GlobalKey<_ReaderState>();
        final child = _Reader(key: reader, axis: Axis.horizontal);
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 300, height: 400),
                child: ElScrollView(
                  key: outer,
                  axis: outerSupportsAxis ? null : Axis.vertical,
                  scrollbar: const ElNoScrollBar(),
                  children: [
                    _Reader(key: outerReader),
                    _Inner(key: changer, scrollKey: inner, reader: child),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(reader.currentState!.scrollView, outerSupportsAxis ? same(outer.currentState) : isNull);
        final before = outerReader.currentState!.dependencies;
        changer.currentState!.makeHorizontal();
        await tester.pump();
        expect(outerReader.currentState!.dependencies, before, reason: 'outer Scope 未广播');
        expect(reader.currentState!.scrollView, same(inner.currentState));
        expect(reader.currentState!.attachments, outerSupportsAxis ? 2 : 1);
        expect(reader.currentState!.detachments, outerSupportsAxis ? 1 : 0);
      });
    }
  });

  group('滚动会话生命周期', () {
    testWidgets('实际停顿后松手保留零释放速度，不启动旧速度的惯性', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      final key = GlobalKey<_SessionLifecycleProbeState>();
      await tester.pumpWidget(_app(controller, [_SessionLifecycleProbe(key: key, name: 'a', trace: trace)]));
      await tester.pump();
      final gesture = await _drag(tester);
      final offset = controller.offset;
      await gesture.up(timeStamp: const Duration(milliseconds: 500));
      expect(key.currentState!.events[1].releaseVelocity, 0);
      expect(trace, ['a:start', 'a:end', 'a:settled']);
      await tester.pumpAndSettle();
      expect(controller.offset, offset);
      expect(tester.takeException(), isNull);
    });

    testWidgets('raw 取消回调不允许同步重入独立输入', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      var checked = false;
      await tester.pumpWidget(
        _app(controller, [
          _SessionLifecycleProbe(
            name: 'a',
            trace: trace,
            consume: true,
            onCancel: () {
              expect(
                () => controller.dispatchPointerScroll(
                  const PointerScrollEvent(position: Offset(120, 100), scrollDelta: Offset(0, 20)),
                ),
                throwsFlutterError,
              );
              checked = true;
            },
          ),
        ]),
      );
      await tester.pump();
      final gesture = await _drag(tester);
      controller.jumpTo(200);
      expect(tester.takeException(), isNull);
      expect(checked, isTrue);
      await gesture.up();
      expect(trace, ['a:start', 'a:inputCancel', 'a:motionCancel']);
      expect(controller.offset, 200);
    });

    testWidgets('纯观察者在 end 中关闭订阅也延迟到整批 input end 之后提交', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      final a = GlobalKey<_SessionLifecycleProbeState>();
      await tester.pumpWidget(
        _app(controller, [
          _SessionLifecycleProbe(key: a, name: 'a', trace: trace, onEnd: () => a.currentState!.disableSessions()),
          _SessionLifecycleProbe(name: 'b', trace: trace),
        ]),
      );
      await tester.pump();
      final gesture = await _drag(tester);
      await gesture.up(timeStamp: const Duration(milliseconds: 32));
      await tester.pumpAndSettle();
      expect(trace, ['a:start', 'b:start', 'a:end', 'b:end', 'a:motionCancel', 'b:settled']);
      expect(tester.takeException(), isNull);
    });

    for (final action in ['none', 'command', 'reentry']) {
      testWidgets('直滚结束 $action 仍在输入事务内，只结算原组一次', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final trace = <String>[];
        var checked = false;
        await tester.pumpWidget(
          _app(controller, [
            _SessionLifecycleProbe(
              name: 'a',
              trace: trace,
              onEnd: () {
                if (action == 'command') controller.jumpTo(300);
                if (action == 'reentry') {
                  expect(
                    () => controller.dispatchPointerScroll(
                      const PointerScrollEvent(position: Offset(120, 100), scrollDelta: Offset(0, 20)),
                    ),
                    throwsFlutterError,
                  );
                }
                checked = true;
              },
            ),
          ]),
        );
        await tester.pump();
        controller.dispatchPointerScroll(
          const PointerScrollEvent(position: Offset(120, 100), scrollDelta: Offset(0, 20)),
        );
        expect(checked, isTrue);
        expect(trace, ['a:start', 'a:end', action == 'command' ? 'a:motionCancel' : 'a:settled']);
        expect(controller.offset, action == 'command' ? 300 : 20);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('State 解绑先取消自身输入与运动订阅，旧设备尾段不会重复通知', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      await tester.pumpWidget(_app(controller, [_SessionLifecycleProbe(name: 'a', trace: trace, consume: true)]));
      await tester.pump();
      final gesture = await _drag(tester);
      await tester.pumpWidget(_app(controller, const []));
      expect(trace, ['a:start', 'a:inputCancel', 'a:motionCancel']);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(trace.length, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('一个结束回调抛错仍结清其他订阅，下一次输入可继续', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      await tester.pumpWidget(
        _app(controller, [
          _SessionLifecycleProbe(name: 'a', trace: trace, onEnd: () => throw StateError('session end failure')),
          _SessionLifecycleProbe(name: 'b', trace: trace),
        ]),
      );
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        controller.dispatchPointerScroll(
          const PointerScrollEvent(position: Offset(120, 100), scrollDelta: Offset(0, 20)),
        );
        expect(tester.takeException(), isA<StateError>());
      }
      expect(trace, [
        for (var i = 0; i < 2; i++) ...['a:start', 'b:start', 'a:end', 'b:end', 'a:settled', 'b:settled'],
      ]);
      expect(controller.offset, 40);
      expect(tester.takeException(), isNull);
    });

    testWidgets('头部独占输入、正文没有活动也有一次开始结束与 settled', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      final key = GlobalKey<_SessionLifecycleProbeState>();
      await tester.pumpWidget(
        _app(controller, [_SessionLifecycleProbe(key: key, name: 'a', trace: trace, consume: true)]),
      );
      await tester.pump();
      final gesture = await _drag(tester);
      expect(trace, ['a:start']);
      expect(controller.offset, 0);
      expect(key.currentState!.accepted, 20);
      await gesture.up(timeStamp: const Duration(milliseconds: 32));
      expect(trace, ['a:start', 'a:end', 'a:settled']);
      expect(key.currentState!.events.map((event) => event.sessionId).toSet().length, 1);
      expect(key.currentState!.events.map((event) => event.motionId).toSet().length, 1);
      expect(key.currentState!.events.first.sessionId, isNotNull);
      expect(key.currentState!.events[1].releaseVelocity, greaterThan(0), reason: '过滤后的零惯性不覆盖原始释放详情');
      await tester.pumpAndSettle();
      expect(trace.length, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('纯观察 Mixin 也能区分 input end 和后续惯性 settled', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      final key = GlobalKey<_SessionLifecycleProbeState>();
      await tester.pumpWidget(_app(controller, [_SessionLifecycleProbe(key: key, name: 'a', trace: trace)]));
      await tester.pump();
      final gesture = await _drag(tester);
      await gesture.moveBy(const Offset(0, -20), timeStamp: const Duration(milliseconds: 30));
      await gesture.up(timeStamp: const Duration(milliseconds: 32));
      expect(trace, ['a:start', 'a:end']);
      final offset = controller.offset;
      final end = key.currentState!.events.last;
      expect(end.releaseVelocity, greaterThan(0));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(offset));
      expect(trace, ['a:start', 'a:end', 'a:settled']);
      expect(key.currentState!.events.last.sessionId, end.sessionId);
      expect(key.currentState!.events.last.motionId, end.motionId);
      expect(tester.takeException(), isNull);
    });

    testWidgets('raw 命令接管只取消原输入和运动，旧抬手不补 end', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      await tester.pumpWidget(_app(controller, [_SessionLifecycleProbe(name: 'a', trace: trace, consume: true)]));
      await tester.pump();
      final gesture = await _drag(tester);
      controller.jumpTo(200);
      expect(trace, ['a:start', 'a:inputCancel', 'a:motionCancel']);
      await gesture.moveBy(const Offset(0, -10));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(trace.length, 3);
      expect(controller.offset, 200);
      expect(tester.takeException(), isNull);
    });

    for (final takeover in ['start', 'end']) {
      testWidgets('$takeover 中的新命令不会重复或打乱原组终态', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final trace = <String>[];
        void replace() => controller.jumpTo(300);
        await tester.pumpWidget(
          _app(controller, [
            _SessionLifecycleProbe(
              name: 'a',
              trace: trace,
              onStart: takeover == 'start' ? replace : null,
              onEnd: takeover == 'end' ? replace : null,
            ),
            _SessionLifecycleProbe(name: 'b', trace: trace),
          ]),
        );
        await tester.pump();
        final gesture = await _drag(tester);
        await gesture.up(timeStamp: const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(
          trace,
          takeover == 'start'
              ? ['a:start', 'a:inputCancel', 'a:motionCancel']
              : ['a:start', 'b:start', 'a:end', 'b:end', 'a:motionCancel', 'b:motionCancel'],
        );
        expect(controller.offset, 300);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('input end 内拒绝重入独立 wheel，退出后仍能建立新输入', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final trace = <String>[];
      var checked = false;
      await tester.pumpWidget(
        _app(controller, [
          _SessionLifecycleProbe(
            name: 'a',
            trace: trace,
            consume: true,
            onEnd: () {
              expect(
                () => controller.dispatchPointerScroll(
                  const PointerScrollEvent(position: Offset(120, 100), scrollDelta: Offset(0, 20)),
                ),
                throwsFlutterError,
              );
              checked = true;
            },
          ),
        ]),
      );
      await tester.pump();
      final first = await _drag(tester);
      await first.up(timeStamp: const Duration(milliseconds: 500));
      expect(checked, isTrue);
      final second = await _drag(tester);
      await second.up(timeStamp: const Duration(milliseconds: 500));
      expect(trace, ['a:start', 'a:end', 'a:settled', 'a:start', 'a:end', 'a:settled']);
      expect(tester.takeException(), isNull);
    });
  });

  group('快照协议', () {
    testWidgets('关闭历史订阅后主动读取仍是当前位置，不补造运动历史', (tester) async {
      final samples = <ElScrollSnapshot>[];
      final observer = GlobalKey<_SnapshotProtocolObserverState>();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _positionObservationFrame(
          ElScrollView(
            controller: controller,
            scrollbar: const ElNoScrollBar(),
            children: [
              _SnapshotProtocolObserver(samples, key: observer, observe: false),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      final initial = observer.currentState!.scrollSnapshot;
      expect(initial.hasMetrics, isTrue);
      expect(initial.bindingGeneration, greaterThan(0));
      expect(initial.layoutRevision, greaterThan(0));
      expect(initial.sampleId, greaterThan(0));
      expect(initial.timeStamp, SchedulerBinding.instance.currentSystemFrameTimeStamp);
      controller.jumpTo(100);
      final current = observer.currentState!.scrollSnapshot;
      expect(current.contentOffset, 100);
      expect(current.motionDelta, 0);
      expect(current.correctionDelta, 0);
      expect(current.velocity, anyOf(isNull, 0));
      expect(current.bindingGeneration, initial.bindingGeneration);
      expect(current.layoutRevision, initial.layoutRevision);
      expect(current.sampleId, greaterThan(initial.sampleId));
      expect(samples, isEmpty);
      expect(observer.currentState!.scrollSnapshot, same(current));
      expect(initial.contentOffset, 0);
      await tester.pump();
      expect(observer.currentState!.scrollSnapshot.layoutRevision, initial.layoutRevision);
    });

    testWidgets('绑定代次来自真实 position，重新订阅不重置本轴观察序号', (tester) async {
      final samples = <ElScrollSnapshot>[];
      final observer = GlobalKey<_SnapshotProtocolObserverState>();
      final first = ScrollController();
      final second = ScrollController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var controller = first;
      var show = true;
      var reverse = false;
      late StateSetter update;
      await tester.pumpWidget(
        _positionObservationFrame(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElScrollView(
                controller: controller,
                reverse: reverse,
                scrollbar: const ElNoScrollBar(),
                children: [
                  if (show) _SnapshotProtocolObserver(samples, key: observer, observe: false),
                  const ElView(style: ElStyle(height: 1000)),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();
      final initial = observer.currentState!.scrollSnapshot;
      update(() => show = false);
      await tester.pump();
      update(() => show = true);
      await tester.pump();
      final rebound = observer.currentState!.scrollSnapshot;
      expect(rebound.bindingGeneration, initial.bindingGeneration);
      expect(rebound.sampleId, greaterThan(initial.sampleId));
      expect(rebound.layoutRevision, greaterThan(initial.layoutRevision));
      update(() => controller = second);
      await tester.pump();
      final replaced = observer.currentState!.scrollSnapshot;
      expect(first.hasClients, isFalse);
      expect(second.hasClients, isTrue);
      expect(replaced.bindingGeneration, greaterThan(rebound.bindingGeneration));
      expect(replaced.coordinateReset, isTrue);
      expect(replaced.motionDelta, 0);
      update(() => reverse = true);
      await tester.pump();
      final reversed = observer.currentState!.scrollSnapshot;
      expect(reversed.bindingGeneration, greaterThan(replaced.bindingGeneration));
      expect(reversed.axisDirection, AxisDirection.up);
      expect(reversed.sampleId, greaterThan(replaced.sampleId));
      expect(reversed.coordinateReset, isTrue);
    });

    testWidgets('提前读取当前位置不会吃掉其他订阅者尚未派发的运动', (tester) async {
      final samples = <ElScrollSnapshot>[];
      final reader = GlobalKey<_SnapshotProtocolObserverState>();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      ElScrollSnapshot? pulled;
      // 在宿主登记之前监听，保证真实通知中先主动读取、后由宿主派发运动。
      controller.addListener(() => pulled = reader.currentState?.scrollSnapshot);
      await tester.pumpWidget(
        _positionObservationFrame(
          ElScrollView(
            controller: controller,
            scrollbar: const ElNoScrollBar(),
            children: [
              _SnapshotProtocolObserver(samples),
              _SnapshotProtocolObserver([], key: reader, observe: false),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      samples.clear();
      controller.jumpTo(100);
      expect(pulled!.contentOffset, 100);
      expect(pulled!.motionDelta, 0);
      expect(samples.where((sample) => sample.motionDelta == 100), hasLength(1));
    });

    for (final reverse in [false, true]) {
      testWidgets('T16 静止追加不制造方向与速度，仅 reverse 坐标重基（reverse=$reverse）', (tester) async {
        final samples = <ElScrollSnapshot>[];
        var count = 100;
        late StateSetter update;
        await tester.pumpWidget(
          _positionObservationFrame(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return ElScrollView(
                  reverse: reverse,
                  scrollbar: const ElNoScrollBar(),
                  children: [
                    _SnapshotProtocolObserver(samples),
                    ElListView.builder(
                      itemCount: count,
                      itemBuilder: (context, index) => const ElView(style: ElStyle(height: 40)),
                      fixedSize: true,
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        final previous = samples.last;
        samples.clear();
        update(() => count += 100);
        await tester.pump();
        await tester.pump();
        expect(samples, isNotEmpty);
        expect(samples.last.maxScrollExtent, greaterThan(previous.maxScrollExtent));
        expect(samples.every((sample) => sample.motionDelta == 0), isTrue);
        expect(samples.every((sample) => sample.direction == ElScrollTravelDirection.idle), isTrue);
        expect(samples.any((sample) => sample.coordinateReset), reverse);
        expect(samples.every((sample) => sample.velocity == null || sample.velocity == 0), isTrue);
      });
    }

    testWidgets('外部像素命令可观察真实位移，但不按回调执行间隔伪造速度', (tester) async {
      final samples = <ElScrollSnapshot>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _positionObservationFrame(
          ElScrollView(
            controller: controller,
            scrollbar: const ElNoScrollBar(),
            children: [
              _SnapshotProtocolObserver(samples),
              ElListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) => const ElView(style: ElStyle(height: 40)),
                fixedSize: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      samples.clear();
      controller.jumpTo(100);
      final motion = samples.where((sample) => sample.motionDelta != 0).toList();
      expect(motion, hasLength(1));
      expect(motion.single.motionDelta, 100);
      expect(motion.single.velocity, isNull);
      expect(motion.single.velocitySource, ElScrollVelocitySource.unknown);
    });

    testWidgets('总范围不变的前方行高修正只记 correctionDelta', (tester) async {
      final samples = <ElScrollSnapshot>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final keys = List.generate(50, (_) => GlobalKey<_HeightRowState>());
      await tester.pumpWidget(
        _positionObservationFrame(
          ElScrollView(
            controller: controller,
            preserveAnchor: true,
            scrollbar: const ElNoScrollBar(),
            children: [
              _SnapshotProtocolObserver(samples),
              for (final key in keys) _HeightRow(key: key),
            ],
          ),
        ),
      );
      await tester.pump();
      controller.jumpTo(600);
      await tester.pump();
      final previous = samples.last;
      samples.clear();
      keys[1].currentState!.resize(60);
      keys[49].currentState!.resize(20);
      await tester.pump();
      await tester.pump();
      expect(controller.offset, 620);
      expect(samples.last.maxScrollExtent, previous.maxScrollExtent);
      expect(samples.any((sample) => sample.correctionDelta == 20), isTrue);
      expect(samples.every((sample) => sample.motionDelta == 0), isTrue);
      expect(samples.every((sample) => sample.direction == ElScrollTravelDirection.idle), isTrue);
    });

    testWidgets('metrics 详情保存不可变历史值，不暴露活 position 作为快照', (tester) async {
      final samples = <ElScrollSnapshot>[];
      final metrics = <ScrollMetrics?>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _positionObservationFrame(
          ElScrollView(
            controller: controller,
            scrollbar: const ElNoScrollBar(),
            children: [
              _SnapshotProtocolObserver(samples, metricSamples: metrics),
              const ElView(style: ElStyle(height: 1000)),
            ],
          ),
        ),
      );
      await tester.pump();
      final before = metrics.whereType<ScrollMetrics>().last;
      expect(before.pixels, 0);
      controller.jumpTo(100);
      expect(before.pixels, 0);
      expect(before, isNot(isA<ScrollPosition>()));
    });
  });
}
