import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_base/ui.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart' show ElScrollViewStateTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Navbar extends StatefulWidget {
  const _Navbar({super.key, this.snap = false, this.fade = false, this.border = false, this.padding = EdgeInsets.zero});
  final bool snap, fade, border;
  final EdgeInsets padding;
  @override
  State<_Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<_Navbar> with ElScrollMixin<_Navbar>, ElLargeTitleNavbarMixin<_Navbar> {
  double bottomHeight = 48;
  int searchTaps = 0;
  void growBottom() => setState(() => bottomHeight = 80);
  @override
  bool get largeTitleNavbarSnap => widget.snap;
  @override
  bool get largeTitleNavbarScale => !widget.fade;
  @override
  bool get largeTitleNavbarFade => widget.fade;
  @override
  bool get largeTitleNavbarCenterTitle => false;
  @override
  EdgeInsetsGeometry get largeTitleNavbarBottomPadding => widget.padding;
  @override
  BorderSide? get largeTitleNavbarBottomBorder => widget.border ? const BorderSide(color: Color(0xffabcde1)) : null;
  @override
  Widget build(BuildContext context) => buildLargeTitleNavbar(
    context,
    largeTitle: const ElView(key: ValueKey('large'), style: ElStyle(width: 200, height: 40)),
    compactTitle: const ElView(key: ValueKey('compact'), style: ElStyle(width: 80, height: 20)),
    leading: const ElView(style: ElStyle(width: 56, height: 56)),
    bottom: ElView(
      key: const ValueKey('search'),
      style: ElStyle(height: bottomHeight, backgroundColor: const Color(0xffabcde1)),
      event: ElEvent(onTap: (_) => searchTaps++),
      semantics: ElSemantics(container: true, label: '搜索内容'),
    ),
  );
}

Future<void> _mount(
  WidgetTester tester,
  GlobalKey<_NavbarState> key,
  ElScrollController controller, {
  bool snap = false,
  bool fade = false,
  bool border = false,
  EdgeInsets padding = EdgeInsets.zero,
  Widget? body,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture'),
      child: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
        child: Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 300, height: 400),
              child: ElScrollView(
                controller: controller,
                physics: const ElClampingScrollPhysics(),
                scrollbar: const ElWindowScrollBar(),
                smoothScroll: null,
                children: [
                  _Navbar(key: key, snap: snap, fade: fade, border: border, padding: padding),
                  body ?? const ElView(key: ValueKey('body'), style: ElStyle(height: 2400)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _wheel(WidgetTester tester, double delta) async {
  await tester.sendEventToBinding(PointerScrollEvent(position: const Offset(150, 320), scrollDelta: Offset(0, delta)));
  await tester.pumpAndSettle();
}

Future<({Rect rect, int bands})> _searchPaintBounds(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
  final height = tester.getSize(find.byType(_Navbar)).height;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    var left = image.width, top = image.height, right = 0, bottom = 0, bands = 0;
    var previousRow = false;
    for (var y = 0; y < (height * 2).ceil(); y++) {
      var row = false;
      for (var x = 0; x < 600; x++) {
        final index = (y * image.width + x) * 4;
        if (bytes[index] == 0xab && bytes[index + 1] == 0xcd && bytes[index + 2] == 0xe1 && bytes[index + 3] == 255) {
          if (x < left) left = x;
          if (y < top) top = y;
          if (x + 1 > right) right = x + 1;
          if (y + 1 > bottom) bottom = y + 1;
          row = true;
        }
      }
      if (row && !previousRow) bands++;
      previousRow = row;
    }
    image.dispose();
    return (rect: Rect.fromLTRB(left / 2, top / 2, right / 2, bottom / 2), bands: bands);
  }))!;
}

class _LargeTitleNavbarNavbar extends StatefulWidget {
  const _LargeTitleNavbarNavbar({
    super.key,
    this.scale = true,
    this.fade = false,
    this.center = true,
    this.snap = true,
    this.stretch = false,
  });
  final bool scale;
  final bool fade;
  final bool center;
  final bool snap;
  final bool stretch;
  @override
  State<_LargeTitleNavbarNavbar> createState() => _LargeTitleNavbarNavbarState();
}

class _LargeTitleNavbarNavbarState extends State<_LargeTitleNavbarNavbar>
    with ElScrollMixin<_LargeTitleNavbarNavbar>, ElLargeTitleNavbarMixin<_LargeTitleNavbarNavbar> {
  int builds = 0;
  int snapshotReads = 0;
  double extraHeight = 0;
  ElScrollSnapshot? _sample;
  double get measuredRange => scrollEffectTracks.single.pixelsPerUnit;
  void growTitle() => setState(() => extraHeight += 30);
  void rebuild() => setState(() {});
  @override
  Object? get scrollInputSlot => widget.key ?? super.scrollInputSlot;
  @override
  ElScrollSnapshot get scrollSnapshot {
    snapshotReads++;
    return _sample ?? super.scrollSnapshot;
  }

  void sampleStretch(double overscroll, {double viewport = 240, bool metrics = false}) {
    final previous = scrollSnapshot;
    final snapshot = _sample = ElScrollSnapshot(
      attached: true,
      hasMetrics: true,
      axis: .vertical,
      axisDirection: .down,
      bindingGeneration: previous.bindingGeneration,
      layoutRevision: previous.layoutRevision,
      sampleId: previous.sampleId + 1,
      timeStamp: previous.timeStamp,
      reverse: false,
      contentOffset: 0,
      rawPixels: -overscroll,
      motionDelta: 0,
      rawContentOffset: -overscroll,
      correctionDelta: 0,
      coordinateReset: false,
      cause: .userInput,
      velocitySource: .unknown,
      velocity: null,
      direction: .idle,
      activity: .touchDrag,
      viewportExtent: viewport,
      minScrollExtent: 0,
      maxScrollExtent: previous.maxScrollExtent,
      leadingOverscroll: overscroll,
      trailingOverscroll: 0,
      atStart: true,
      atEnd: false,
    );
    if (metrics) {
      onScrollMetricsChanged(
        ElScrollMetricsDetails(
          scrollView: scrollView!,
          axis: .vertical,
          position: scrollPosition!,
          previousSnapshot: previous,
          snapshot: snapshot,
          metrics: null,
        ),
      );
      return;
    }
    onScrollUpdate(
      ElScrollUpdateDetails(
        scrollView: scrollView!,
        axis: .vertical,
        position: scrollPosition!,
        previousSnapshot: previous,
        snapshot: snapshot,
      ),
    );
  }

  @override
  bool get largeTitleNavbarScale => widget.scale;
  @override
  bool get largeTitleNavbarFade => widget.fade;
  @override
  bool get largeTitleNavbarCenterTitle => widget.center;
  @override
  bool get largeTitleNavbarSnap => widget.snap;
  @override
  bool get largeTitleNavbarStretch => widget.stretch;
  @override
  Widget build(BuildContext context) {
    builds++;
    return buildLargeTitleNavbar(
      context,
      largeTitle: ElView(
        key: const ValueKey('large'),
        style: ElStyle(width: 200, height: 40 + extraHeight, backgroundColor: const Color(0xffef4444)),
        semantics: ElSemantics(container: true, label: '大标题内容'),
      ),
      compactTitle: ElView(
        key: const ValueKey('compact'),
        style: const ElStyle(width: 80, height: 20, backgroundColor: Color(0xff2563eb)),
        semantics: ElSemantics(container: true, label: '小标题内容'),
      ),
      leading: const ElView(style: ElStyle(width: 30, height: 40)),
      actions: const [ElView(style: ElStyle(width: 50, height: 32))],
    );
  }
}

Future<void> _largeTitleNavbarMount(
  WidgetTester tester,
  GlobalKey<_LargeTitleNavbarNavbarState> navbar,
  ElScrollController controller, {
  bool center = true,
  bool scale = true,
  bool fade = false,
  bool snap = true,
  bool stretch = false,
  bool thumb = false,
  bool optimize = true,
  bool virtualBody = false,
  double bodyHeight = 2400,
  TextDirection direction = .ltr,
  ElRefresher? refresher,
  Future<void> Function()? onRefresh,
  ElRefreshEdge refreshEdge = .leading,
  GlobalKey<_LargeTitleNavbarNavbarState>? extraNavbar,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('capture'),
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600), padding: EdgeInsets.only(top: 24)),
        child: Directionality(
          textDirection: direction,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 300, height: 240, backgroundColor: Color(0xffffffff)),
              child: ElScrollView(
                controller: controller,
                inputOrder: {
                  if (extraNavbar != null) .vertical: [navbar, extraNavbar],
                },
                refresher: refresher,
                onRefresh: onRefresh,
                refreshEdge: refreshEdge,
                physics: const ElClampingScrollPhysics(),
                scrollbar: thumb ? const ElWindowScrollBar() : const ElNoScrollBar(),
                dragOptimize: optimize,
                smoothScroll: null,
                children: [
                  _LargeTitleNavbarNavbar(
                    key: navbar,
                    center: center,
                    scale: scale,
                    fade: fade,
                    snap: snap,
                    stretch: stretch,
                  ),
                  if (extraNavbar != null) _LargeTitleNavbarNavbar(key: extraNavbar, snap: snap),
                  if (virtualBody)
                    ElListView.builder(
                      itemCount: (bodyHeight / 40).round(),
                      itemBuilder: (_, _) => const ElView(style: ElStyle(height: 40)),
                      fixedSize: true,
                    )
                  else
                    ElView(
                      key: const ValueKey('body'),
                      style: ElStyle(height: bodyHeight),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _IosRefresh extends ElIosRefresher {
  const _IosRefresh({this.capture});
  final ValueChanged<ElRefreshDetails>? capture;
  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    capture?.call(details);
    return const ElView(key: ValueKey('refresh-region'));
  }
}

class _AndroidRefresh extends ElAndroidRefresher {
  const _AndroidRefresh();
  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) =>
      const ElView(key: ValueKey('refresh-region'));
}

Future<({int red, int blue})> _titlePixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    var red = 0, blue = 0;
    for (var i = 0; i < data.length; i += 4) {
      if (data[i] == 239 && data[i + 1] == 68 && data[i + 2] == 68 && data[i + 3] == 255) red++;
      if (data[i + 2] > data[i] + 30 && data[i + 2] > data[i + 1] + 30) blue++;
    }
    image.dispose();
    return (red: red, blue: blue);
  }))!;
}

List<String> _liveTitleLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    final label = node.getSemanticsData().label;
    if (label == '大标题内容' || label == '小标题内容') labels.add(label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(ElScrollView)));
  return labels;
}

class _Header extends StatefulWidget {
  const _Header({super.key, this.expanded = 123.5, this.collapsed = 35.25, this.snap = false});
  final double expanded;
  final double collapsed;
  final bool snap;
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with ElScrollMixin<_Header>, ElScrollCollapseMixin<_Header> {
  @override
  ElScrollCollapseMode get scrollCollapseMode => .consumeDelta;
  @override
  bool get scrollCollapseSnap => widget.snap;
  @override
  Widget build(BuildContext context) => buildScrollCollapse(
    context,
    expanded: ElView(
      style: ElStyle(height: widget.expanded, backgroundColor: const Color(0xff336699)),
    ),
    collapsed: ElView(
      style: ElStyle(height: widget.collapsed, backgroundColor: const Color(0xff557799)),
    ),
  );
}

Future<void> _collapseLayoutMount(
  WidgetTester tester,
  GlobalKey<_HeaderState> header,
  ElScrollController controller, {
  double expanded = 123.5,
  double collapsed = 35.25,
  bool snap = false,
  double imageHeight = 0,
  bool preserveAnchor = false,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: ElView(
          style: const ElStyle(width: 300, height: 240),
          child: ElScrollView(
            controller: controller,
            preserveAnchor: preserveAnchor,
            physics: const ElClampingScrollPhysics(),
            scrollbar: const ElNoScrollBar(),
            smoothScroll: null,
            children: [
              _Header(key: header, expanded: expanded, collapsed: collapsed, snap: snap),
              ElView(style: ElStyle(height: imageHeight)),
              const ElView(key: ValueKey('body'), style: ElStyle(height: 2400)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _collapseLayoutWheel(WidgetTester tester, double delta) async {
  tester.binding.handlePointerEvent(
    PointerScrollEvent(position: const Offset(150, 180), scrollDelta: Offset(0, delta)),
  );
  await tester.pumpAndSettle();
}

class _Toolbar extends StatefulWidget {
  const _Toolbar({super.key, this.height = 43.25, this.commands = false, this.mode = .direction, this.snap = true});
  final double height;
  final bool commands;
  final ElScrollCollapseMode mode;
  final bool snap;
  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> with ElScrollMixin<_Toolbar>, ElScrollCollapseMixin<_Toolbar> {
  int builds = 0;
  ElScrollEffectTrack get collapseTrack => scrollEffectTracks.single;
  @override
  ElScrollCollapseMode get scrollCollapseMode => widget.mode;
  @override
  bool get scrollCollapseSnap => widget.snap;
  @override
  bool get scrollCollapseFade => true;
  @override
  bool get scrollCollapseRespondToCommands => widget.commands;
  @override
  Widget build(BuildContext context) {
    builds++;
    return buildScrollCollapse(
      context,
      child: ElView(
        key: const ValueKey('toolbar-content'),
        style: ElStyle(height: widget.height, backgroundColor: const Color(0xff2456aa)),
        child: '工具栏',
      ),
    );
  }
}

Future<void> _collapseMixinMount(
  WidgetTester tester,
  GlobalKey<_ToolbarState> key, {
  ElScrollController? controller,
  ElSmoothScroll? smooth,
  bool optimize = true,
  bool commands = false,
  ElScrollCollapseMode mode = .direction,
  bool snap = true,
  double height = 43.25,
  bool reduce = false,
  bool focus = false,
  ElEvent? bodyEvent,
}) async {
  // 焦点场景按需建节点：滚动容器自身或 body 二选一挂载。
  final focusNode = focus ? FocusNode(debugLabel: 'effects-focus') : null;
  if (focusNode != null) addTearDown(focusNode.dispose);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: RepaintBoundary(
            child: ElView(
              style: const ElStyle(width: 300, height: 240, backgroundColor: Color(0xffeeeeee)),
              child: ElScrollView(
                focusNode: focus && bodyEvent == null ? focusNode : null,
                controller: controller,
                physics: const ElClampingScrollPhysics(),
                scrollbar: const ElWindowScrollBar(),
                smoothScroll: smooth,
                dragOptimize: optimize,
                children: [
                  ElView(
                    event: bodyEvent,
                    focusNode: focus && bodyEvent != null ? focusNode : null,
                    style: const ElStyle(height: 2400),
                  ),
                  ElPositioned(
                    top: 0,
                    left: 0,
                    right: 15,
                    child: _Toolbar(key: key, height: height, commands: commands, mode: mode, snap: snap),
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
  if (focusNode != null) {
    focusNode.requestFocus();
    await tester.pump();
  }
}

SemanticsNode _scrollSemantics(SemanticsNode root) {
  if (root.getSemanticsData().hasAction(SemanticsAction.scrollUp)) return root;
  SemanticsNode? result;
  root.visitChildren((child) {
    if (child.getSemanticsData().hasAction(SemanticsAction.scrollUp)) result = child;
    return result == null;
  });
  return result!;
}

class _EffectSettleHeader extends StatefulWidget {
  const _EffectSettleHeader({super.key, required this.events, required this.settled});
  final List<(String, int)> events;
  final List<(int, double, double)> settled;
  @override
  State<_EffectSettleHeader> createState() => _EffectSettleHeaderState();
}

class _EffectSettleHeaderState extends State<_EffectSettleHeader>
    with ElScrollMixin<_EffectSettleHeader>, ElScrollCollapseMixin<_EffectSettleHeader> {
  VoidCallback? beforeSettle;

  @override
  Future<void>? onScrollSettle(ElScrollSessionDetails details) {
    beforeSettle?.call();
    return super.onScrollSettle(details);
  }

  @override
  ElScrollCollapseMode get scrollCollapseMode => .consumeDelta;
  @override
  void onInputEnd(ElScrollSessionDetails details) {
    super.onInputEnd(details);
    widget.events.add(('inputEnd', details.motionId));
  }

  @override
  void onMotionSettled(ElScrollSessionDetails details) {
    super.onMotionSettled(details);
    widget.events.add(('settled', details.motionId));
    widget.settled.add((
      details.motionId,
      scrollCollapseProgress,
      (context.findRenderObject()! as RenderBox).size.height,
    ));
  }

  @override
  void onMotionCancelled(ElScrollSessionDetails details) {
    super.onMotionCancelled(details);
    widget.events.add(('cancelled', details.motionId));
  }

  @override
  Widget build(BuildContext context) => buildScrollCollapse(
    context,
    expanded: const ElView(style: ElStyle(height: 120)),
    collapsed: const ElView(style: ElStyle(height: 40)),
  );
}

Future<void> _effectSettleMount(
  WidgetTester tester,
  ElScrollController controller,
  GlobalKey<_EffectSettleHeaderState> header,
  List<(String, int)> events,
  List<(int, double, double)> settled, {
  bool show = true,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: ElView(
          style: const ElStyle(width: 300, height: 240),
          child: ElScrollView(
            controller: controller,
            physics: const ElClampingScrollPhysics(),
            scrollbar: const ElNoScrollBar(),
            children: [
              if (show) _EffectSettleHeader(key: header, events: events, settled: settled),
              const ElView(style: ElStyle(height: 2400)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _beginSnap(WidgetTester tester) async {
  final drag = await tester.startGesture(const Offset(150, 180));
  addTearDown(drag.removePointer);
  await drag.moveBy(const Offset(0, -30));
  await drag.moveBy(const Offset(0, -60));
  await tester.pump();
  await drag.up(timeStamp: const Duration(seconds: 2));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
}

class _FollowFilterHeader extends StatefulWidget {
  const _FollowFilterHeader({super.key, this.maximum = 320, this.tolerance = 10});
  final double maximum, tolerance;
  @override
  State<_FollowFilterHeader> createState() => _FollowFilterHeaderState();
}

class _FollowFilterHeaderState extends State<_FollowFilterHeader>
    with ElScrollMixin<_FollowFilterHeader>, ElScrollCollapseMixin<_FollowFilterHeader> {
  @override
  ElScrollCollapseMode get scrollCollapseMode => .followDelta;
  @override
  double get scrollCollapseFollowMaxVelocity => widget.maximum;
  @override
  double get scrollCollapseFollowReverseTolerance => widget.tolerance;
  @override
  bool get scrollCollapseRespondToCommands => true;
  double get shift => scrollCollapseProgress * scrollCollapseRange;
  @override
  Widget build(BuildContext context) => buildScrollCollapse(
    context,
    child: ElView(
      style: const ElStyle(height: 56, backgroundColor: Color(0xff2456aa)),
      child: '导航',
    ),
  );
}

Future<({ElScrollController controller, GlobalKey<_FollowFilterHeaderState> header})> _followFilterMount(
  WidgetTester tester, {
  double maximum = 320,
  double tolerance = 10,
  double hz = 60,
  double dpr = 1,
  ScrollPhysics physics = const ElClampingScrollPhysics(),
}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(300 * dpr, 240 * dpr);
  tester.view.display.refreshRate = hz;
  addTearDown(tester.view.reset);
  addTearDown(tester.view.display.resetRefreshRate);
  final controller = ElScrollController();
  addTearDown(controller.dispose);
  final header = GlobalKey<_FollowFilterHeaderState>();
  await tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: ElScrollView(
        key: UniqueKey(),
        controller: controller,
        physics: physics,
        smoothScroll: null,
        scrollbar: const ElWindowScrollBar(),
        children: [
          const ElView(style: ElStyle(height: 5000)),
          ElPositioned(
            top: 0,
            left: 0,
            right: 15,
            child: _FollowFilterHeader(key: header, maximum: maximum, tolerance: tolerance),
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (controller: controller, header: header);
}

void _send(WidgetTester tester, double delta) => tester.binding.handlePointerEvent(
  PointerScrollEvent(
    position: const Offset(150, 180),
    scrollDelta: Offset(0, delta),
    timeStamp: tester.binding.currentSystemFrameTimeStamp,
  ),
);

Future<void> _step(WidgetTester tester, double delta, {Duration elapsed = const Duration(microseconds: 16667)}) async {
  await tester.pump(elapsed);
  _send(tester, delta);
  await tester.pump();
}

class _Card extends StatefulWidget {
  const _Card({
    super.key,
    this.once = false,
    this.parallax = true,
    this.horizontal = false,
    this.trackVisibility = false,
  });
  final bool once;
  final bool parallax;
  final bool horizontal;
  final bool trackVisibility;
  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> with ElScrollMixin<_Card>, ElScrollRevealMixin<_Card>, ElParallaxMixin<_Card> {
  int builds = 0;
  final visibility = <ElVisibilityInfo>[];
  bool? visibilityOverride;
  ValueChanged<ElVisibilityInfo>? onVisibility;
  void enableVisibility() {
    visibilityOverride = true;
    updateScrollEffect();
  }

  @override
  bool get trackScrollItemVisibility => visibilityOverride ?? widget.trackVisibility;
  @override
  void onScrollItemVisibilityChanged(ElVisibilityInfo info) {
    super.onScrollItemVisibilityChanged(info);
    visibility.add(info);
    onVisibility?.call(info);
  }

  @override
  bool get scrollRevealOnce => widget.once;
  @override
  double get parallaxFactor => widget.parallax ? .4 : 0;
  @override
  Widget build(BuildContext context) {
    builds++;
    return buildScrollReveal(
      context,
      child: buildParallax(
        context,
        child: ElView(
          key: const ValueKey('card-content'),
          style: ElStyle(width: widget.horizontal ? 100 : null, height: 100, backgroundColor: const Color(0xff4488aa)),
        ),
      ),
    );
  }
}

class _Progress extends StatefulWidget {
  const _Progress({super.key});
  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> with ElScrollMixin<_Progress>, ElScrollProgressMixin<_Progress> {
  @override
  Widget build(BuildContext context) => buildScrollProgress(context);
}

class _GlobalFirst extends StatefulWidget {
  const _GlobalFirst({super.key});
  @override
  State<_GlobalFirst> createState() => _GlobalFirstState();
}

class _GlobalFirstState extends State<_GlobalFirst>
    with ElScrollMixin<_GlobalFirst>, ElScrollProgressMixin<_GlobalFirst>, ElScrollRevealMixin<_GlobalFirst> {
  @override
  Widget build(BuildContext context) => buildScrollReveal(context, child: const ElView(style: ElStyle(height: 100)));
}

Future<void> _itemEffectsMount(
  WidgetTester tester,
  ElScrollController controller,
  GlobalKey<_CardState> card,
  GlobalKey<_ProgressState> progress, {
  bool once = false,
  bool parallax = true,
  double tail = 1200,
  bool reduce = false,
  bool trackVisibility = false,
  ValueChanged<ElVisibleRange>? onVisibleRangeChanged,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Directionality(
        textDirection: .ltr,
        child: Align(
          alignment: .topLeft,
          child: ElView(
            style: const ElStyle(width: 300, height: 240),
            child: ElScrollView(
              controller: controller,
              onVisibleRangeChanged: onVisibleRangeChanged,
              physics: const ElClampingScrollPhysics(),
              scrollbar: const ElWindowScrollBar(),
              children: [
                const ElView(style: ElStyle(height: 250)),
                _Card(key: card, once: once, parallax: parallax, trackVisibility: trackVisibility),
                ElView(style: ElStyle(height: tail)),
                ElPositioned(top: 0, left: 0, right: 15, child: _Progress(key: progress)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SizeProbe extends StatefulWidget {
  const _SizeProbe({super.key, required this.height});
  final double height;
  @override
  State<_SizeProbe> createState() => _SizeProbeState();
}

class _SizeProbeState extends State<_SizeProbe> with ElScrollMixin<_SizeProbe> {
  final sizes = <double>[];
  @override
  bool get observesScrollUpdates => false;
  @override
  bool get observesScrollMetrics => false;
  @override
  bool get observesScrollSessions => false;
  @override
  bool get observesScrollItemSize => true;
  @override
  void onScrollItemUpdate(ElScrollItemUpdateDetails details) {
    super.onScrollItemUpdate(details);
    sizes.add(details.snapshot.itemExtent);
  }

  @override
  Widget build(BuildContext context) => ElView(style: ElStyle(height: widget.height));
}

class _PresetNestedNavbar extends StatefulWidget {
  const _PresetNestedNavbar({super.key, required this.events});
  final List<(String, int)> events;
  @override
  State<_PresetNestedNavbar> createState() => _PresetNestedNavbarState();
}

class _PresetNestedNavbarState extends State<_PresetNestedNavbar>
    with ElScrollMixin<_PresetNestedNavbar>, ElLargeTitleNavbarMixin<_PresetNestedNavbar> {
  @override
  void onInputEnd(ElScrollSessionDetails details) {
    super.onInputEnd(details);
    widget.events.add(('end', details.motionId));
  }

  @override
  void onMotionSettled(ElScrollSessionDetails details) {
    super.onMotionSettled(details);
    widget.events.add(('settled', details.motionId));
  }

  @override
  void onMotionCancelled(ElScrollSessionDetails details) {
    super.onMotionCancelled(details);
    widget.events.add(('cancelled', details.motionId));
  }

  @override
  Widget build(BuildContext context) => buildLargeTitleNavbar(
    context,
    largeTitle: const ElView(style: ElStyle(width: 160, height: 40)),
    compactTitle: const ElView(style: ElStyle(width: 80, height: 20)),
  );
}

class _Refresh extends ElIosRefresher {
  const _Refresh();
  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) =>
      const ElView(key: ValueKey('inner-indicator'));
}

Future<void> _presetNestedMount(
  WidgetTester tester,
  ElScrollController outer,
  ElScrollController inner,
  GlobalKey<_PresetNestedNavbarState> navbar,
  List<(String, int)> events, {
  String tab = 'a',
  Future<void> Function()? onRefresh,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: ElView(
          style: const ElStyle(width: 300, height: 300),
          child: ElScrollView(
            controller: outer,
            physics: const ElClampingScrollPhysics(),
            scrollbar: const ElNoScrollBar(),
            smoothScroll: null,
            children: [
              _PresetNestedNavbar(key: navbar, events: events),
              ElView(
                style: const ElStyle(height: 260),
                child: ElScrollView(
                  key: ValueKey(tab),
                  controller: inner,
                  physics: const ElClampingScrollPhysics(),
                  scrollbar: const ElNoScrollBar(),
                  smoothScroll: null,
                  refresher: onRefresh == null ? null : const _Refresh(),
                  onRefresh: onRefresh,
                  children: const [ElView(style: ElStyle(height: 2000))],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('大标题底部搜索槽', () {
    testWidgets('搜索栏折成一条线后才向两侧展开边框，往返无重复线条或断帧', (tester) async {
      final key = GlobalKey<_NavbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _mount(tester, key, controller, border: true, padding: const EdgeInsets.fromLTRB(20, 4, 30, 12));
      final width = tester.getSize(find.byType(_Navbar)).width;
      var previous = 0.0;
      final samples = <double, Rect>{};
      for (final distance in [0.0, 60.0, 90.0, 91.9, 92.0, 100.0, 110.0, 120.0, 110.0, 100.0, 92.0, 90.0, 60.0, 0.0]) {
        await _wheel(tester, distance - previous);
        final painted = await _searchPaintBounds(tester);
        expect(painted.bands, 1, reason: '搜索背景与边框只能接续，不能重复出现或一起消失');
        if (distance <= 92) {
          expect(painted.rect.left, closeTo(20, .5));
          expect(painted.rect.right, closeTo(width - 30, .5), reason: '搜索折叠完成前不得提前铺满边框');
        } else {
          expect(painted.rect.width, greaterThan(width - 50));
        }
        if (distance >= 91.9) expect(painted.rect.height, closeTo(1, .5));
        if (samples[distance] case final original?) {
          expect(painted.rect, original, reason: '反向恢复同一绘制位置');
        } else {
          samples[distance] = painted.rect;
        }
        previous = distance;
      }
      expect(samples[100]!.width, lessThan(samples[110]!.width));
      expect(samples[110]!.width, lessThan(samples[120]!.width));
      expect(samples[120]!.left, 0);
      expect(samples[120]!.right, width);
      expect(samples[120]!.bottom, 80);
      expect((samples[91.9]!.top - samples[92]!.top).abs(), lessThanOrEqualTo(.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('搜索内容完全淡出前保持自然高度，折叠中正文与搜索底边间距恒定', (tester) async {
      final key = GlobalKey<_NavbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _mount(tester, key, controller, padding: const EdgeInsets.fromLTRB(16, 4, 16, 12));
      final search = find.byKey(const ValueKey('search'));
      final body = find.byKey(const ValueKey('body'));
      final initial = tester.getRect(search);
      for (var sample = 1; sample <= 18; sample++) {
        await _wheel(tester, 5);
        final rect = tester.getRect(search);
        final opacity = key.currentState!.largeTitleNavbarBottomOpacity;
        if (opacity > 0) {
          expect(rect.size, initial.size, reason: '只淡出内容的阶段不压缩');
        } else {
          expect(rect.height, lessThan(initial.height));
        }
        expect(tester.getRect(body).top - rect.bottom, closeTo(12, .001), reason: 'sample=$sample');
        expect(rect.width, initial.width);
      }
    });

    testWidgets('拖柄收起搜索时正文不重复位移，交还滚轮后仍保持间距并完整回顶', (tester) async {
      final key = GlobalKey<_NavbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _mount(tester, key, controller, padding: const EdgeInsets.fromLTRB(16, 4, 16, 12));
      final search = find.byKey(const ValueKey('search'));
      final body = find.byKey(const ValueKey('body'));
      final thumb = tester.getCenter(find.byKey(const ValueKey('el-scrollbar-thumb-vertical')));
      final gesture = await tester.startGesture(thumb, kind: .mouse);
      addTearDown(gesture.removePointer);
      for (final delta in [3.0, 6.0, 10.0, 8.0, 4.0]) {
        await gesture.moveTo(thumb + Offset(0, delta));
        await tester.pumpAndSettle();
        expect(tester.getRect(body).top - tester.getRect(search).bottom, closeTo(12, 1));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      final before = tester.getRect(body).top;
      await _wheel(tester, 5);
      expect(tester.getRect(body).top, closeTo(before - 5, 1));
      expect(tester.getRect(body).top - tester.getRect(search).bottom, closeTo(12, 1));
      await _wheel(tester, -120);
      expect(controller.offset, 0);
      expect(key.currentState!.largeTitleNavbarProgress, 0);
      expect(tester.getRect(body).top - tester.getRect(search).bottom, closeTo(12, 1));
      expect(tester.takeException(), isNull);
    });

    for (final virtual in [false, true]) {
      testWidgets('绝对定位只计算一次折叠行程，正文末端保持可达 virtual=$virtual', (tester) async {
        final key = GlobalKey<_NavbarState>();
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await _mount(
          tester,
          key,
          controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          body: virtual
              ? ElListView.builder(
                  itemCount: 60,
                  itemBuilder: (_, index) => ElView(
                    key: ValueKey(
                      index == 0
                          ? 'body'
                          : index == 59
                          ? 'body-last'
                          : 'row-$index',
                    ),
                    style: const ElStyle(height: 40),
                  ),
                  fixedSize: true,
                )
              : null,
        );
        final search = find.byKey(const ValueKey('search'));
        final body = find.byKey(const ValueKey('body'));
        for (final offset in [5.0, 25.0, 60.0, 90.0, 25.0, 0.0]) {
          controller.jumpTo(offset);
          await tester.pumpAndSettle();
          expect(tester.getRect(body).top - tester.getRect(search).bottom, closeTo(12, 1));
        }
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(tester.getRect(virtual ? find.byKey(const ValueKey('body-last')) : body).bottom, closeTo(400, 1));
        expect(key.currentState!.largeTitleNavbarProgress, 1);
        expect(tester.takeException(), isNull);
      });
    }

    for (final fade in [false, true]) {
      testWidgets('视频开头：标题与搜索框同时上移，搜索消失前标题已过渡，反向恢复相同几何 fade=$fade', (tester) async {
        final key = GlobalKey<_NavbarState>();
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await _mount(tester, key, controller, fade: fade);
        final large = find.byKey(const ValueKey('large'));
        final original = tester.getRect(large);
        final search = find.byKey(const ValueKey('search'));
        final originalSearch = tester.getRect(search);
        expect(tester.getSize(find.byType(_Navbar)).height, 184);
        await _wheel(tester, 20);
        final earlyTitle = tester.getRect(large);
        final earlySearch = tester.getRect(search);
        expect(earlyTitle.top, lessThan(original.top));
        expect(earlyTitle.width, greaterThan(original.width * .9), reason: '起手以平移为主，字号变化较慢');
        expect(earlySearch.top, lessThan(originalSearch.top));
        expect(earlySearch.height, inExclusiveRange(0, originalSearch.height));
        expect(controller.offset, 0);
        expect(tester.getSize(find.byType(_Navbar)).height, closeTo(164, .001));
        await _wheel(tester, 28);
        final middleTitle = tester.getRect(large);
        final middleSearch = tester.getRect(search);
        expect(middleTitle.top, lessThan(earlyTitle.top));
        expect(middleTitle.width, fade ? original.width : lessThan(original.width * .95));
        expect(middleSearch.height, inExclusiveRange(0, earlySearch.height), reason: '标题已缩小时搜索框仍然可见');
        expect(tester.getSize(find.byType(_Navbar)).height, closeTo(136, .001));
        await _wheel(tester, 28);
        expect(controller.offset, 0);
        expect(tester.getRect(large).top, lessThan(original.top));
        expect(tester.getRect(large).width, fade ? original.width : lessThan(original.width));
        expect(tester.getRect(search).height, closeTo(0, .001));
        expect(tester.getRect(large).width, greaterThan(tester.getSize(find.byKey(const ValueKey('compact'))).width));
        await _wheel(tester, 228);
        expect(controller.offset, closeTo(200, .001));
        expect(tester.getSize(find.byType(_Navbar)).height, closeTo(80, .001));
        await _wheel(tester, -100);
        expect(controller.offset, closeTo(100, .001));
        expect(tester.getSize(find.byType(_Navbar)).height, closeTo(80, .001));
        await _wheel(tester, -100);
        await _wheel(tester, -28);
        expect(tester.getSize(find.byType(_Navbar)).height, closeTo(108, .001));
        await _wheel(tester, -28);
        expect(tester.getRect(large), middleTitle);
        expect(tester.getRect(search), middleSearch);
        expect(tester.getSize(find.byType(_Navbar)).height, closeTo(136, .001));
        await _wheel(tester, -28);
        expect(tester.getRect(large), earlyTitle);
        expect(tester.getRect(search), earlySearch);
        await _wheel(tester, -20);
        expect(tester.getRect(large), original);
        expect(tester.getSize(find.byType(_Navbar)).height, closeTo(184, .001));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('滚动条在搜索、标题、正文之间连续往返，顶部几何不振荡', (tester) async {
      final key = GlobalKey<_NavbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _mount(tester, key, controller);
      final original = tester.getRect(find.byKey(const ValueKey('large')));
      final thumb = tester.getCenter(find.byKey(const ValueKey('el-scrollbar-thumb-vertical')));
      final gesture = await tester.startGesture(thumb, kind: .mouse);
      addTearDown(gesture.removePointer);
      var sawSearch = false;
      var sawTitle = false;
      for (final offset in [1.0, 3.0, 6.0, 10.0, 18.0, 28.0, 100.0, 80.0, 28.0, 18.0, 10.0, 6.0, 3.0, 1.0, 0.0]) {
        await gesture.moveTo(thumb + Offset(0, offset));
        await tester.pumpAndSettle();
        final height = tester.getSize(find.byType(_Navbar)).height;
        if (height > 136.01 && height < 183.99) {
          sawSearch = true;
          expect(tester.getRect(find.byKey(const ValueKey('large'))).top, lessThan(original.top));
          expect(tester.getRect(find.byKey(const ValueKey('search'))).height, greaterThan(0));
        } else if (height > 80.01 && height < 135.99) {
          sawTitle = true;
        }
        if (offset >= 80) expect(height, closeTo(80, .01));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.getSize(find.byType(_Navbar)).height, closeTo(height, .001));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(sawSearch, isTrue);
      expect(sawTitle, isTrue);
      expect(tester.getSize(find.byType(_Navbar)).height, closeTo(184, .001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('搜索槽按自然高度重新测量，隐藏后不再暴露搜索语义', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final key = GlobalKey<_NavbarState>();
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await _mount(tester, key, controller);
        key.currentState!.growBottom();
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(_Navbar)).height, 216);
        expect(find.bySemanticsLabel('搜索内容'), findsOneWidget);
        final original = tester.getRect(find.byKey(const ValueKey('large')));
        await _wheel(tester, 80);
        expect(tester.getRect(find.byKey(const ValueKey('large'))).top, lessThan(original.top));
        expect(tester.getSize(find.byType(_Navbar)).height, 136);
        expect(tester.getRect(find.byKey(const ValueKey('search'))).height, greaterThan(0));
        await _wheel(tester, 28);
        // 查实际提交的语义树，已离树的 RenderObject 仍可能保留旧 semanticsNode。
        expect(tester.getSemantics(find.byType(ElScrollView)).toStringDeep(), isNot(contains('搜索内容')));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('启用吸附时使用整体展开和收起端点，不停在旧的分段边界', (tester) async {
      final key = GlobalKey<_NavbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _mount(tester, key, controller, snap: true);
      final original = tester.getRect(find.byKey(const ValueKey('large')));
      await _wheel(tester, 35);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const ValueKey('large'))), original);
      expect(tester.getSize(find.byType(_Navbar)).height, closeTo(184, .001));
      await _wheel(tester, 60);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(_Navbar)).height, closeTo(80, .001));
      expect(controller.offset, 0);
    });

    testWidgets('搜索框变矮后命中跟随绘制位置，原来的区域不会继续接收点击', (tester) async {
      final key = GlobalKey<_NavbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _mount(tester, key, controller);
      final search = find.byKey(const ValueKey('search'));
      final original = tester.getRect(search);
      await _wheel(tester, 48);
      final current = tester.getRect(search);
      await tester.tapAt(current.center);
      await tester.pumpAndSettle();
      expect(key.currentState!.searchTaps, 1);
      await tester.tapAt(original.bottomCenter - const Offset(0, 2));
      await tester.pumpAndSettle();
      expect(key.currentState!.searchTaps, 1);
      await _wheel(tester, 28);
      await tester.tapAt(current.center);
      await tester.pumpAndSettle();
      expect(key.currentState!.searchTaps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('搜索背景真实绘制保持不透明，缩成窄条后仍保留颜色', (tester) async {
      final key = GlobalKey<_NavbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _mount(tester, key, controller);
      await _wheel(tester, 65);
      final rect = tester.getRect(find.byKey(const ValueKey('search')));
      expect(rect.height, inExclusiveRange(2, 10));
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
      final color = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
        final point = boundary.globalToLocal(rect.center);
        final index = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        final color = Color.fromARGB(data[index + 3], data[index], data[index + 1], data[index + 2]);
        image.dispose();
        return color;
      });
      expect(color, const Color(0xffabcde1));
    });
  });

  group('大标题导航', () {
    testWidgets('未开启标题拉伸时同配置构建不读取滚动快照', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
      await _largeTitleNavbarMount(tester, navbar, controller, snap: false);
      final state = navbar.currentState!;
      final builds = state.builds;
      final reads = state.snapshotReads;
      state.rebuild();
      await tester.pump(Duration.zero, EnginePhase.build);
      expect(state.builds, builds + 1);
      expect(state.snapshotReads, reads);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('导航头同配置重建不请求布局，子标题长高仍自然测量', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
      await _largeTitleNavbarMount(tester, navbar, controller, snap: false);
      final layout = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_LargeTitleNavbarLayout');
      final render = tester.renderObject<RenderBox>(layout);
      navbar.currentState!.rebuild();
      await tester.pump(Duration.zero, EnginePhase.build);
      expect(render.debugNeedsLayout, isFalse);
      await tester.pumpAndSettle();
      final builds = navbar.currentState!.builds;
      final title = tester.renderObject<ElRenderView>(find.byKey(const ValueKey('large')));
      title.style = const ElStyle(width: 200, height: 70, backgroundColor: Color(0xffef4444));
      expect(render.debugNeedsLayout, isTrue);
      await tester.pumpAndSettle();
      expect(navbar.currentState!.builds, builds);
      expect(navbar.currentState!.measuredRange, 86);
      expect(tester.getSize(find.byType(_LargeTitleNavbarNavbar)).height, 150);
      expect(tester.takeException(), isNull);
    });

    testWidgets('导航布局同值配置仍替换测量回调', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final first = GlobalKey<_LargeTitleNavbarNavbarState>();
      final second = GlobalKey<_LargeTitleNavbarNavbarState>();
      await _largeTitleNavbarMount(tester, first, controller, snap: false, extraNavbar: second);
      final layouts = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_LargeTitleNavbarLayout');
      final render = tester.renderObject<RenderBox>(layouts.first);
      // 两份真实 State 提供相同布局参数，只有回调接收者不同。
      final dynamic replacement = tester.widget(layouts.last);
      replacement.updateRenderObject(first.currentContext!, render);
      final title = tester.renderObject<ElRenderView>(
        find.descendant(of: find.byKey(first), matching: find.byKey(const ValueKey('large'))),
      );
      title.style = const ElStyle(width: 200, height: 70, backgroundColor: Color(0xffef4444));
      await tester.pumpAndSettle();
      expect(first.currentState!.measuredRange, 56);
      expect(second.currentState!.measuredRange, 86);
      expect(tester.takeException(), isNull);
    });

    testWidgets('导航标题拉伸仅在视觉值变化时构建，饱和后回落恢复', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
      await _largeTitleNavbarMount(tester, navbar, controller, snap: false, stretch: true);
      final state = navbar.currentState!;
      for (final sample in [(12.0, 210.0), (24.0, 220.0), (60.0, 230.0)]) {
        final builds = state.builds;
        state.sampleStretch(sample.$1);
        await tester.pumpAndSettle();
        expect(state.builds - builds, 1);
        expect(tester.getRect(find.byKey(const ValueKey('large'))).width, closeTo(sample.$2, .001));
      }
      final saturatedBuilds = state.builds;
      state.sampleStretch(90);
      await tester.pumpAndSettle();
      expect(state.builds, saturatedBuilds);
      state.sampleStretch(24);
      await tester.pumpAndSettle();
      expect(state.builds - saturatedBuilds, 1);
      expect(tester.getRect(find.byKey(const ValueKey('large'))).width, closeTo(220, .001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('导航标题拉伸同时响应视口变化，越过饱和阈值后重新取值', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
      await _largeTitleNavbarMount(tester, navbar, controller, snap: false, stretch: true);
      final state = navbar.currentState!;
      state.sampleStretch(60);
      await tester.pumpAndSettle();
      final builds = state.builds;
      state.sampleStretch(60, viewport: 800, metrics: true);
      await tester.pumpAndSettle();
      expect(state.builds - builds, 1);
      expect(tester.getRect(find.byKey(const ValueKey('large'))).width, closeTo(215, .001));
      state.sampleStretch(60, viewport: 1200, metrics: true);
      await tester.pumpAndSettle();
      expect(state.builds - builds, 2);
      expect(tester.getRect(find.byKey(const ValueKey('large'))).width, closeTo(210, .001));
      expect(tester.takeException(), isNull);
    });

    for (final virtualBody in [false, true]) {
      for (final optimize in [false, true]) {
        testWidgets('拖柄在顶部连续往返，不二值跳变 virtual=$virtualBody optimize=$optimize', (tester) async {
          final controller = ElScrollController();
          addTearDown(controller.dispose);
          final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
          await _largeTitleNavbarMount(
            tester,
            navbar,
            controller,
            thumb: true,
            optimize: optimize,
            virtualBody: virtualBody,
            bodyHeight: 400,
          );
          final thumb = tester.getRect(find.byKey(const ValueKey('el-scrollbar-thumb-vertical')));
          final gesture = await tester.startGesture(thumb.center, kind: .mouse);
          addTearDown(gesture.removePointer);
          final outbound = <double, double>{};
          var sawPartial = false;
          var previous = 0.0;
          for (final dy in [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0, 32.0]) {
            await gesture.moveTo(thumb.center + Offset(0, dy));
            await tester.pumpAndSettle();
            final progress = navbar.currentState!.largeTitleNavbarProgress;
            sawPartial |= progress > .05 && progress < .95;
            expect(progress, greaterThanOrEqualTo(previous));
            expect(progress - previous, lessThan(.4), reason: '小幅拖动不能突然从展开跳到收起');
            outbound[dy] = progress;
            previous = progress;
          }
          expect(sawPartial, isTrue);
          for (final dy in [28.0, 24.0, 20.0, 16.0, 12.0, 8.0, 4.0, 0.0]) {
            await gesture.moveTo(thumb.center + Offset(0, dy));
            await tester.pumpAndSettle();
            expect(
              navbar.currentState!.largeTitleNavbarProgress,
              closeTo(outbound[dy]!, .02),
              reason: '同一拖柄位置不应因方向不同而改变标题状态',
            );
          }
          await gesture.up();
          await tester.pumpAndSettle();
          expect(navbar.currentState!.largeTitleNavbarProgress, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final source in ['jump', 'animate', 'thumb', 'thumbNoOptimize', 'wheel']) {
      testWidgets('$source 正文中反向滚动不展开大标题', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
        await _largeTitleNavbarMount(
          tester,
          navbar,
          controller,
          snap: false,
          thumb: source.startsWith('thumb'),
          optimize: source != 'thumbNoOptimize',
        );
        controller.jumpTo(600);
        await tester.pumpAndSettle();
        void expectCompact() {
          expect(controller.offset, greaterThan(56));
          expect(navbar.currentState!.largeTitleNavbarProgress, 1);
          expect(tester.getSize(find.byType(_LargeTitleNavbarNavbar)).height, 64);
        }

        expectCompact();
        if (source.startsWith('thumb')) {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('el-scrollbar-thumb-vertical'))),
            kind: .mouse,
          );
          addTearDown(gesture.removePointer);
          for (final delta in [10.0, -8.0, 12.0, -10.0]) {
            await gesture.moveBy(Offset(0, delta));
            await tester.pumpAndSettle();
            expectCompact();
          }
          await gesture.up();
        } else {
          for (final delta in [40.0, -30.0, 50.0, -40.0]) {
            if (source == 'wheel') {
              tester.binding.handlePointerEvent(
                PointerScrollEvent(position: const Offset(150, 180), scrollDelta: Offset(0, delta)),
              );
            } else if (source == 'animate') {
              final motion = controller.animateTo(
                controller.offset + delta,
                duration: const Duration(milliseconds: 100),
                curve: Curves.linear,
              );
              await tester.pumpAndSettle();
              await motion;
            } else {
              controller.jumpTo(controller.offset + delta);
            }
            await tester.pumpAndSettle();
            expectCompact();
          }
        }
        await tester.pumpAndSettle();
        expectCompact();
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        expect(navbar.currentState!.largeTitleNavbarProgress, 0);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('从正文回到顶部后，只用剩余输入展开标题', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
      await _largeTitleNavbarMount(tester, navbar, controller, snap: false);
      controller.jumpTo(600);
      await tester.pumpAndSettle();
      tester.binding.handlePointerEvent(
        const PointerScrollEvent(position: Offset(150, 180), scrollDelta: Offset(0, -575)),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, 25);
      expect(navbar.currentState!.largeTitleNavbarProgress, 1);
      tester.binding.handlePointerEvent(
        const PointerScrollEvent(position: Offset(150, 180), scrollDelta: Offset(0, -53)),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(navbar.currentState!.largeTitleNavbarProgress, closeTo(.5, .001));
      expect(tester.takeException(), isNull);
    });

    testWidgets('正文中重新挂载导航头时直接显示小标题', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _largeTitleNavbarMount(tester, GlobalKey<_LargeTitleNavbarNavbarState>(), controller, snap: false);
      controller.jumpTo(600);
      await tester.pumpAndSettle();
      final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
      await _largeTitleNavbarMount(tester, navbar, controller, snap: false);
      expect(controller.offset, greaterThan(56));
      expect(navbar.currentState!.largeTitleNavbarProgress, 1);
      expect(tester.getSize(find.byType(_LargeTitleNavbarNavbar)).height, 64);
    });

    for (final phase in [0.0, .5, 1.0]) {
      testWidgets('程序刷新保留导航头当前折叠状态 $phase，区域从其底边开始', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
        final completion = Completer<void>();
        late ElRefreshDetails refresh;
        await _largeTitleNavbarMount(
          tester,
          navbar,
          controller,
          snap: false,
          refresher: _IosRefresh(capture: (details) => refresh = details),
          onRefresh: () => completion.future,
        );
        if (phase > 0) {
          tester.binding.handlePointerEvent(
            PointerScrollEvent(position: const Offset(150, 180), scrollDelta: Offset(0, 56 * phase)),
          );
          await tester.pumpAndSettle();
        }
        expect(navbar.currentState!.largeTitleNavbarProgress, phase);
        refresh.requestRefresh();
        await tester.pumpAndSettle();
        expect(navbar.currentState!.largeTitleNavbarProgress, phase);
        final height = tester.getSize(find.byType(_LargeTitleNavbarNavbar)).height;
        expect(tester.getTopLeft(find.byKey(const ValueKey('refresh-region'))).dy, height);
        expect(refresh.contentViewportRect!.top, height);
        completion.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('末端刷新仍贴视口末边，紧凑导航头保持固定', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
      final completion = Completer<void>();
      late ElRefreshDetails refresh;
      await _largeTitleNavbarMount(
        tester,
        navbar,
        controller,
        refresher: _IosRefresh(capture: (details) => refresh = details),
        refreshEdge: .trailing,
        onRefresh: () => completion.future,
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      refresh.requestRefresh();
      await tester.pumpAndSettle();
      expect(navbar.currentState!.largeTitleNavbarProgress, 1);
      expect(tester.getTopLeft(find.byType(_LargeTitleNavbarNavbar)).dy, 0);
      expect(refresh.snapshot.value.anchoredAtViewportStart, isFalse);
      expect(tester.getBottomRight(find.byKey(const ValueKey('refresh-region'))).dy, 240);
      completion.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final config in [
      (true, false, true, TextDirection.ltr),
      (true, true, false, TextDirection.rtl),
      (false, true, true, TextDirection.rtl),
      (false, false, false, TextDirection.ltr),
    ]) {
      testWidgets('两 bool 标题动画半程和往返 $config', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
        await _largeTitleNavbarMount(
          tester,
          navbar,
          controller,
          scale: config.$1,
          fade: config.$2,
          center: config.$3,
          direction: config.$4,
          snap: false,
        );
        tester.binding.handlePointerEvent(
          PointerScrollEvent(position: const Offset(150, 180), scrollDelta: const Offset(0, 28)),
        );
        await tester.pumpAndSettle();
        expect(navbar.currentState!.largeTitleNavbarProgress, closeTo(.5, .001));
        final largeBox = tester.getRect(find.byKey(const ValueKey('large')));
        expect(largeBox.width, config.$1 ? 140 : 200);
        expect(largeBox.top, config.$1 ? 54 : 44);
        Object? opacity(String name) {
          final child = tester.widget(find.byKey(ValueKey(name)));
          return tester
              .widget<ElView>(find.byWidgetPredicate((widget) => widget is ElView && identical(widget.child, child)))
              .style!
              .opacity;
        }

        final crossFade = !config.$1 && config.$2;
        expect(opacity('large'), crossFade ? .5 : 1);
        expect(opacity('compact'), crossFade ? .5 : 0);
        tester.binding.handlePointerEvent(
          PointerScrollEvent(position: const Offset(150, 180), scrollDelta: const Offset(0, -28)),
        );
        await tester.pumpAndSettle();
        expect(navbar.currentState!.largeTitleNavbarProgress, 0);
        expect(tester.getTopLeft(find.byKey(const ValueKey('large'))).dy, 72);
        expect(tester.takeException(), isNull);
      });
    }

    for (final refresher in [const _IosRefresh(), const _AndroidRefresh()]) {
      testWidgets('${refresher.runtimeType} 在实测导航头下布局，刷新中标题长高同帧更新区域', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
        final completion = Completer<void>();
        var calls = 0;
        await _largeTitleNavbarMount(
          tester,
          navbar,
          controller,
          refresher: refresher,
          onRefresh: () {
            calls++;
            return completion.future;
          },
        );
        expect(tester.getTopLeft(find.byKey(const ValueKey('refresh-region'))).dy, 120);
        expect(tester.getSize(find.byKey(const ValueKey('refresh-region'))).height, 120);
        final gesture = await tester.startGesture(const Offset(150, 150));
        addTearDown(gesture.removePointer);
        await gesture.moveBy(const Offset(0, 30));
        await gesture.moveBy(const Offset(0, 180));
        await tester.pump();
        expect(tester.getTopLeft(find.byType(_LargeTitleNavbarNavbar)).dy, 0);
        expect(tester.getTopLeft(find.byKey(const ValueKey('refresh-region'))).dy, 120);
        await gesture.up(timeStamp: const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(calls, 1);
        navbar.currentState!.growTitle();
        await tester.pump();
        expect(tester.getSize(find.byType(_LargeTitleNavbarNavbar)).height, 150);
        expect(tester.getTopLeft(find.byKey(const ValueKey('refresh-region'))).dy, 150);
        expect(tester.getSize(find.byKey(const ValueKey('refresh-region'))).height, 90);
        completion.complete();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    for (final center in [true, false]) {
      testWidgets('自动测量任意标题 Widget，过渡到实际${center ? "居中" : "起边"}小标题位置', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
        await _largeTitleNavbarMount(tester, navbar, controller, center: center);
        expect(tester.getSize(find.byType(_LargeTitleNavbarNavbar)).height, 120);
        expect(tester.getTopLeft(find.byKey(const ValueKey('large'))), const Offset(16, 72));
        tester.binding.handlePointerEvent(
          PointerScrollEvent(position: const Offset(150, 180), scrollDelta: const Offset(0, 100)),
        );
        await tester.pumpAndSettle();
        expect(navbar.currentState!.largeTitleNavbarProgress, 1);
        expect(tester.getSize(find.byType(_LargeTitleNavbarNavbar)).height, 64);
        expect(controller.offset, closeTo(44, .01));
        final compact = tester.getCenter(find.byKey(const ValueKey('compact')));
        expect(compact.dx, center ? 150 : 86);
        expect(compact.dy, 44);
        expect(tester.getCenter(find.byKey(const ValueKey('large'))), compact);
        controller.jumpTo(300);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byType(_LargeTitleNavbarNavbar)).dy, 0);
        expect(tester.takeException(), isNull);
      });
    }

    for (final scale in [true, false]) {
      for (final fade in [false, true]) {
        testWidgets('标题真实绘制与语义在各阶段一致 scale=$scale fade=$fade', (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final controller = ElScrollController();
            addTearDown(controller.dispose);
            final navbar = GlobalKey<_LargeTitleNavbarNavbarState>();
            await _largeTitleNavbarMount(tester, navbar, controller, scale: scale, fade: fade, snap: false);
            final crossFade = !scale && fade;
            var previous = 0.0;
            for (final phase in [0.0, .25, .5, .75, 1.0, .75, .5, .25, 0.0]) {
              if (phase != previous) {
                tester.binding.handlePointerEvent(
                  PointerScrollEvent(position: const Offset(150, 180), scrollDelta: Offset(0, 56 * (phase - previous))),
                );
                await tester.pumpAndSettle();
              }
              expect(navbar.currentState!.largeTitleNavbarProgress, closeTo(phase, .001));
              final pixels = await _titlePixels(tester);
              if (!crossFade && phase < 1) {
                expect(pixels.red, greaterThan(0), reason: '移动中的标题应保持不透明');
                expect(pixels.blue, 0, reason: '交接之前不能在终点再绘制一份小标题');
              } else if (phase == 1) {
                expect(pixels.red, 0);
                expect(pixels.blue, greaterThan(0));
              } else if (crossFade && phase > 0) {
                expect(pixels.blue, greaterThan(0), reason: '非缩放模式保留小标题同步淡入');
              }
              final compactOwnsSemantics = phase >= (crossFade ? .5 : 1);
              expect(_liveTitleLabels(tester), [compactOwnsSemantics ? '小标题内容' : '大标题内容']);
              previous = phase;
            }
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  });

  group('折叠成员布局', () {
    testWidgets('同帧折叠 12 与图片增长 30，仅对图片保位', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final header = GlobalKey<_HeaderState>();
      await _collapseLayoutMount(tester, header, controller, imageHeight: 70, preserveAnchor: true);
      await _collapseLayoutWheel(tester, 40);
      controller.jumpTo(250);
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.byKey(const ValueKey('body'))).dy;
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: const Offset(150, 180), scrollDelta: const Offset(0, 12)),
      );
      await _collapseLayoutMount(tester, header, controller, imageHeight: 100, preserveAnchor: true);
      expect(controller.offset, closeTo(280, .01));
      expect(tester.getTopLeft(find.byKey(const ValueKey('body'))).dy, closeTo(before - 12, .01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('输入结束后实际头部吸附端点，静止时不遗留动画', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final header = GlobalKey<_HeaderState>();
      await _collapseLayoutMount(tester, header, controller, snap: true);
      await _collapseLayoutWheel(tester, 60);
      expect(header.currentState!.scrollCollapseProgress, 1);
      expect(tester.getSize(find.byType(_Header)).height, 35.25);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('自然端点先折叠真实占位，余量推动正文，反向先正文再展开', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final header = GlobalKey<_HeaderState>();
      await _collapseLayoutMount(tester, header, controller);
      expect(tester.getSize(find.byType(_Header)).height, 123.5);
      expect(header.currentState!.scrollCollapseRange, 88.25);
      await _collapseLayoutWheel(tester, 40);
      expect(tester.getSize(find.byType(_Header)).height, closeTo(83.5, .01));
      expect(controller.offset, 0);
      expect(tester.getTopLeft(find.byKey(const ValueKey('body'))).dy, closeTo(84, 1));
      await _collapseLayoutWheel(tester, 70);
      expect(tester.getSize(find.byType(_Header)).height, closeTo(35.25, .01));
      expect(controller.offset, closeTo(21.75, .01));
      await _collapseLayoutWheel(tester, -31.75);
      expect(controller.offset, 0);
      expect(tester.getSize(find.byType(_Header)).height, closeTo(45.25, .01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('折叠端点近零浮点残差不会反号触发输入合同', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final header = GlobalKey<_HeaderState>();
      await _collapseLayoutMount(tester, header, controller);
      await _collapseLayoutWheel(tester, 85.02716283542858);
      await _collapseLayoutWheel(tester, 3.2228371645714233);
      expect(tester.getSize(find.byType(_Header)).height, closeTo(35.25, .01));
      expect(controller.offset, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('折叠期间更新展开内容仍按自然端点测量，不把裁剪尺寸当端点', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final header = GlobalKey<_HeaderState>();
      await _collapseLayoutMount(tester, header, controller);
      await _collapseLayoutWheel(tester, 44.125);
      expect(header.currentState!.scrollCollapseProgress, closeTo(.5, .001));
      await _collapseLayoutMount(tester, header, controller, expanded: 203.5);
      expect(tester.getSize(find.byType(_Header)).height, closeTo(119.375, .01));
      await _collapseLayoutMount(tester, header, controller, expanded: 203.5, collapsed: 55.5);
      expect(header.currentState!.scrollCollapseRange, 148);
      expect(tester.getSize(find.byType(_Header)).height, closeTo(129.5, .01));
      await _collapseLayoutWheel(tester, -200);
      expect(tester.getSize(find.byType(_Header)).height, closeTo(203.5, .01));
      expect(tester.takeException(), isNull);
    });
  });

  group('折叠行为', () {
    testWidgets('尺寸折叠到端点后连续定位不重复构建', (tester) async {
      final key = GlobalKey<_ToolbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _collapseMixinMount(tester, key, controller: controller, commands: true, mode: .consumeDelta, snap: false);
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      expect(key.currentState!.scrollCollapseProgress, 1);
      final builds = key.currentState!.builds;
      for (final offset in [200.0, 300.0, 400.0]) {
        controller.jumpTo(offset);
        await tester.pumpAndSettle();
        expect(key.currentState!.scrollCollapseProgress, 1);
        expect(key.currentState!.builds, builds);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('尺寸折叠一次进度更新只构建一次，尺寸观察保持发布', (tester) async {
      final key = GlobalKey<_ToolbarState>();
      await _collapseMixinMount(tester, key, height: 80, mode: .consumeDelta, snap: false);
      await tester.pumpAndSettle();
      final state = key.currentState!;
      final builds = state.builds;
      state.collapseTrack.updateValue(.5);
      await tester.pumpAndSettle();
      expect(state.scrollCollapseProgress, .5);
      expect(state.scrollItemSnapshot.layoutSize!.height, 40);
      expect(state.builds - builds, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('同值定位仍取消尚未完成的尺寸吸附', (tester) async {
      final key = GlobalKey<_ToolbarState>();
      await _collapseMixinMount(tester, key, height: 80, mode: .consumeDelta);
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(120, 150));
      addTearDown(gesture.removePointer);
      await gesture.moveBy(const Offset(0, -30));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.up(timeStamp: const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      final state = key.currentState!;
      final progress = state.scrollCollapseProgress;
      expect(progress, inExclusiveRange(.75, 1));
      state.collapseTrack.updateValue(progress);
      await tester.pumpAndSettle();
      expect(state.scrollCollapseProgress, progress);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    for (final source in [
      'touch',
      'wheel',
      'smooth',
      'thumb',
      'thumbNoOptimize',
      'button',
      'keyboard',
      'semantics',
      'pan',
    ]) {
      testWidgets('$source 驱动真实工具栏平移显隐，无需配置自身高度', (tester) async {
        final key = GlobalKey<_ToolbarState>();
        final semantics = source == 'semantics' || source == 'button' ? tester.ensureSemantics() : null;
        await _collapseMixinMount(
          tester,
          key,
          optimize: source != 'thumbNoOptimize',
          smooth: source == 'smooth' ? const ElWindowsSmoothScroll() : null,
          focus: source == 'keyboard',
        );
        expect(key.currentState!.scrollItemSnapshot.layoutSize!.height, 43.25);
        if (source.startsWith('thumb')) {
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('el-scrollbar-thumb-vertical'))),
            kind: .mouse,
          );
          addTearDown(gesture.removePointer);
          await gesture.moveBy(const Offset(0, 70));
          await tester.pumpAndSettle();
          expect(key.currentState!.scrollCollapseHidden, isTrue);
          await gesture.moveBy(const Offset(0, -35));
          await tester.pumpAndSettle();
          await gesture.up();
        } else if (source == 'button') {
          await tester.tap(find.bySemanticsLabel('Scroll down'));
          await tester.pumpAndSettle();
          expect(key.currentState!.scrollCollapseHidden, isTrue);
          await tester.tap(find.bySemanticsLabel('Scroll up'));
          await tester.pumpAndSettle();
        } else if (source == 'keyboard') {
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          await tester.pumpAndSettle();
          expect(key.currentState!.scrollCollapseHidden, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
          await tester.pumpAndSettle();
        } else if (source == 'semantics') {
          final node = _scrollSemantics(tester.getSemantics(find.byType(ElScrollView)));
          node.owner!.performAction(node.id, SemanticsAction.scrollUp);
          await tester.pumpAndSettle();
          expect(key.currentState!.scrollCollapseHidden, isTrue);
          node.owner!.performAction(node.id, SemanticsAction.scrollDown);
          await tester.pumpAndSettle();
        } else if (source == 'pan') {
          const center = Offset(120, 150);
          await tester.sendEventToBinding(const PointerPanZoomStartEvent(pointer: 3, position: center));
          await tester.sendEventToBinding(
            const PointerPanZoomUpdateEvent(
              pointer: 3,
              position: center,
              pan: Offset(0, -70),
              panDelta: Offset(0, -70),
              timeStamp: Duration(milliseconds: 40),
            ),
          );
          await tester.pumpAndSettle();
          expect(key.currentState!.scrollCollapseHidden, isTrue);
          await tester.sendEventToBinding(
            const PointerPanZoomUpdateEvent(
              pointer: 3,
              position: center,
              pan: Offset(0, -40),
              panDelta: Offset(0, 30),
              timeStamp: Duration(milliseconds: 500),
            ),
          );
          await tester.pumpAndSettle();
          await tester.sendEventToBinding(
            const PointerPanZoomEndEvent(pointer: 3, position: center, timeStamp: Duration(seconds: 2)),
          );
        } else if (source == 'touch') {
          final gesture = await tester.startGesture(const Offset(120, 150));
          addTearDown(gesture.removePointer);
          await gesture.moveBy(const Offset(0, -30));
          await gesture.moveBy(const Offset(0, -60));
          await tester.pumpAndSettle();
          expect(key.currentState!.scrollCollapseHidden, isTrue);
          await gesture.moveBy(const Offset(0, 30));
          await tester.pumpAndSettle();
          await gesture.up(timeStamp: const Duration(seconds: 3));
        } else {
          tester.binding.handlePointerEvent(
            PointerScrollEvent(position: const Offset(120, 150), scrollDelta: const Offset(0, 80)),
          );
          await tester.pumpAndSettle();
          expect(key.currentState!.scrollCollapseHidden, isTrue);
          expect(tester.getTopLeft(find.byKey(const ValueKey('toolbar-content'))).dy, closeTo(-43.25, .01));
          tester.binding.handlePointerEvent(
            PointerScrollEvent(position: const Offset(120, 150), scrollDelta: const Offset(0, -30)),
          );
          await tester.pumpAndSettle();
        }
        expect(key.currentState!.scrollCollapseProgress, 0);
        expect(tester.getTopLeft(find.byKey(const ValueKey('toolbar-content'))).dy, closeTo(0, .01));
        expect(tester.takeException(), isNull);
        semantics?.dispose();
      });
    }

    testWidgets('隐藏后内容变高会更新真实平移尺寸，静止状态不空转', (tester) async {
      final key = GlobalKey<_ToolbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _collapseMixinMount(tester, key, controller: controller, commands: true);
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      expect(key.currentState!.scrollCollapseHidden, isTrue);
      await _collapseMixinMount(tester, key, controller: controller, commands: true, height: 76.5);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('toolbar-content'))).dy, closeTo(-76.5, .01));
      final builds = key.currentState!.builds;
      await tester.pump(const Duration(seconds: 1));
      expect(key.currentState!.builds, builds);
      expect(tester.takeException(), isNull);
    });

    testWidgets('子项阻止默认按键及组合快捷键不触发页面滚动', (tester) async {
      final key = GlobalKey<_ToolbarState>();
      var calls = 0;
      await _collapseMixinMount(
        tester,
        key,
        focus: true,
        bodyEvent: ElEvent(
          onKeyDown: (event) {
            calls++;
            event.preventDefault();
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(key.currentState!.scrollPosition!.pixels, 0);
      await _collapseMixinMount(tester, key, focus: true);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(key.currentState!.scrollPosition!.pixels, 0);
    });

    testWidgets('显示动画中移除 State 不遗留 ticker 或旧宿主回调', (tester) async {
      final key = GlobalKey<_ToolbarState>();
      await _collapseMixinMount(tester, key);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: const Offset(120, 150), scrollDelta: const Offset(0, 80)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(key.currentState!.scrollCollapseProgress, inExclusiveRange(0, 1));
      await tester.pumpWidget(const Directionality(textDirection: .ltr, child: ElView()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('默认不因程序命令隐藏，允许通过 getter 开启；减少动态效果直接到端点', (tester) async {
      final key = GlobalKey<_ToolbarState>();
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await _collapseMixinMount(tester, key, controller: controller);
      controller.jumpTo(100);
      await tester.pumpAndSettle();
      expect(key.currentState!.scrollCollapseProgress, 0);
      await _collapseMixinMount(tester, key, controller: controller, commands: true, reduce: true);
      controller.jumpTo(200);
      await tester.pump();
      expect(key.currentState!.scrollCollapseHidden, isTrue);
      controller.jumpTo(0);
      await tester.pump();
      expect(key.currentState!.scrollCollapseProgress, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('效果收尾', () {
    for (final takeover in ['command', 'error']) {
      testWidgets('收尾回调内 $takeover 不启动失效组的吸附', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final header = GlobalKey<_EffectSettleHeaderState>();
        final events = <(String, int)>[];
        final settled = <(int, double, double)>[];
        await _effectSettleMount(tester, controller, header, events, settled);
        header.currentState!.beforeSettle = () {
          if (takeover == 'error') throw StateError('测试收尾异常');
          controller.jumpTo(100);
        };
        await _beginSnap(tester);
        if (takeover == 'error') expect(tester.takeException(), isStateError);
        final progress = header.currentState!.scrollCollapseProgress;
        await tester.pumpAndSettle();
        expect(events.where((event) => event.$1 == 'cancelled'), hasLength(1));
        expect(settled, isEmpty);
        expect(header.currentState!.scrollCollapseProgress, progress);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('吸附完成且最终布局提交后才发出整组 motionSettled', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final header = GlobalKey<_EffectSettleHeaderState>();
      final events = <(String, int)>[];
      final settled = <(int, double, double)>[];
      await _effectSettleMount(tester, controller, header, events, settled);
      await _beginSnap(tester);
      expect(header.currentState!.scrollCollapseProgress, inExclusiveRange(.75, 1));
      expect(events.where((event) => event.$1 == 'inputEnd'), hasLength(1));
      expect(settled, isEmpty);
      await tester.pumpAndSettle();
      expect(settled, hasLength(1));
      expect(settled.single.$2, 1);
      expect(settled.single.$3, 40);
    });

    for (final takeover in ['command', 'pointer', 'remove']) {
      testWidgets('吸附期间 $takeover 接管只取消旧组，旧终态不回写', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final header = GlobalKey<_EffectSettleHeaderState>();
        final events = <(String, int)>[];
        final settled = <(int, double, double)>[];
        await _effectSettleMount(tester, controller, header, events, settled);
        await _beginSnap(tester);
        final oldId = events.firstWhere((event) => event.$1 == 'inputEnd').$2;
        final value = header.currentState!.scrollCollapseProgress;
        TestGesture? next;
        if (takeover == 'command') {
          controller.jumpTo(100);
        } else if (takeover == 'pointer') {
          next = await tester.startGesture(const Offset(150, 180));
          addTearDown(next.removePointer);
        } else {
          await _effectSettleMount(tester, controller, header, events, settled, show: false);
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(events.where((event) => event == ('cancelled', oldId)), hasLength(1));
        expect(settled.where((event) => event.$1 == oldId), isEmpty);
        if (header.currentState != null) expect(header.currentState!.scrollCollapseProgress, value);
        await next?.up(timeStamp: const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('折叠方向与速度过滤', () {
    testWidgets('低速保持 1:1 并累计亚像素，正文位移始终完整保留', (tester) async {
      final fixture = await _followFilterMount(tester, dpr: 1.75);
      for (var i = 1; i <= 20; i++) {
        await _step(tester, .4);
        expect(fixture.header.currentState!.shift, closeTo(i * .4, .5 / 1.75));
        expect(fixture.controller.offset, closeTo(i * .4, .001));
      }
    });

    testWidgets('快速输入只移动一帧额度，停手不补追，长空闲不积累额度', (tester) async {
      final fixture = await _followFilterMount(tester);
      await _step(tester, 100);
      final shift = fixture.header.currentState!.shift;
      expect(shift, inInclusiveRange(4, 6));
      expect(fixture.controller.offset, 100);
      await tester.pump(const Duration(seconds: 1));
      expect(fixture.header.currentState!.shift, shift);
      expect(tester.binding.transientCallbackCount, 0);
      _send(tester, 100);
      await tester.pump();
      expect(fixture.header.currentState!.shift - shift, inInclusiveRange(4, 6));
      expect(fixture.controller.offset, 200);
    });

    testWidgets('同帧事件拆分不改变导航位移，也不能反复领取限速额度', (tester) async {
      Future<double> trace(int events) async {
        final fixture = await _followFilterMount(tester);
        await tester.pump(const Duration(microseconds: 16667));
        for (var i = 0; i < events; i++) {
          _send(tester, 80 / events);
        }
        await tester.pump();
        expect(fixture.controller.offset, 80);
        return fixture.header.currentState!.shift;
      }

      expect(await trace(16), closeTo(await trace(1), .001));
    });

    testWidgets('60Hz 与 120Hz 相同时间的跟手距离一致，高速上限不随刷新率变化', (tester) async {
      Future<double> trace(int hz) async {
        final fixture = await _followFilterMount(tester, hz: hz.toDouble());
        for (var i = 0; i < hz ~/ 10; i++) {
          await _step(tester, 2000 / hz, elapsed: Duration(microseconds: (1000000 / hz).round()));
        }
        expect(fixture.controller.offset, closeTo(200, .001));
        expect(fixture.header.currentState!.shift, inInclusiveRange(29, 33));
        return fixture.header.currentState!.shift;
      }

      expect(await trace(60), closeTo(await trace(120), 1));
    });

    testWidgets('反向先确认 10px，仅使用跨过门槛后的余量，不补走已过滤距离', (tester) async {
      final fixture = await _followFilterMount(tester);
      for (var i = 0; i < 8; i++) {
        await _step(tester, 2);
      }
      final before = fixture.header.currentState!.shift;
      await _step(tester, -4);
      await _step(tester, -4);
      expect(fixture.header.currentState!.shift, before);
      await _step(tester, -4);
      expect(fixture.header.currentState!.shift, before - 2);
      expect(fixture.controller.offset, 4);
    });

    testWidgets('微小来回扰动不积累成反向展开，高速反转单帧也不跳到端点', (tester) async {
      final fixture = await _followFilterMount(tester);
      for (var i = 0; i < 6; i++) {
        await _step(tester, 100);
      }
      var previous = fixture.header.currentState!.shift;
      for (var i = 0; i < 3; i++) {
        await _step(tester, -8);
        expect(fixture.header.currentState!.shift, previous);
        await _step(tester, 2);
        previous = fixture.header.currentState!.shift;
      }
      await _step(tester, -100);
      expect(previous - fixture.header.currentState!.shift, inInclusiveRange(4, 6));
      expect(fixture.header.currentState!.shift, inExclusiveRange(0, 56));
    });

    testWidgets('到顶平顺归位，新输入可接管归位，明确跳转顶部直接恢复', (tester) async {
      final fixture = await _followFilterMount(tester);
      fixture.controller.jumpTo(500);
      await tester.pumpAndSettle();
      await _step(tester, -600);
      expect(fixture.controller.offset, 0);
      expect(fixture.header.currentState!.shift, greaterThan(40));
      await tester.pump(const Duration(milliseconds: 60));
      expect(fixture.header.currentState!.shift, inExclusiveRange(0, 56));
      await _step(tester, 2);
      final interrupted = fixture.header.currentState!.shift;
      await tester.pumpAndSettle();
      expect(fixture.header.currentState!.shift, interrupted);
      fixture.controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(fixture.header.currentState!.shift, 0);
      fixture.controller.jumpTo(500);
      await tester.pumpAndSettle();
      await _step(tester, -600);
      await tester.pumpAndSettle();
      expect(fixture.header.currentState!.shift, 0);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('底部纯回弹不会让限速导航反向展开，移除时归位动画及时释放', (tester) async {
      final fixture = await _followFilterMount(tester, physics: const ElBouncingScrollPhysics());
      fixture.controller.jumpTo(fixture.controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      fixture.controller.jumpTo(fixture.controller.position.maxScrollExtent + 80);
      await tester.pumpAndSettle();
      expect(fixture.header.currentState!.shift, 56);
      fixture.controller.jumpTo(100);
      await tester.pumpAndSettle();
      await _step(tester, -200);
      await tester.pumpWidget(const Directionality(textDirection: .ltr, child: ElView()));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('成员效果', () {
    for (final reverse in [false, true]) {
      testWidgets('横向 RTL reverse=$reverse 在 DPR 1.75 按自然宽度渐显', (tester) async {
        tester.view.devicePixelRatio = 1.75;
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        final card = GlobalKey<_CardState>();
        await tester.pumpWidget(
          Directionality(
            textDirection: .rtl,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 300, height: 240),
                child: ElScrollView(
                  axis: .horizontal,
                  reverse: reverse,
                  controller: controller,
                  scrollbar: const ElNoScrollBar(),
                  children: [
                    const ElView(style: ElStyle(width: 300)),
                    _Card(key: card, horizontal: true),
                    const ElView(style: ElStyle(width: 1200)),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pixels = axisDirectionIsReversed(controller.position.axisDirection)
            ? controller.position.maxScrollExtent - 32
            : 32.0;
        controller.jumpTo(pixels);
        await tester.pumpAndSettle();
        expect(card.currentState!.scrollItemSnapshot.layoutSize!.width, 100);
        expect(card.currentState!.scrollRevealProgress, closeTo(.5, .01));
        final builds = card.currentState!.builds;
        await tester.pump(const Duration(seconds: 1));
        expect(card.currentState!.builds, builds);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('十万项虚拟列表组合预设只保留窗口成员，滚动不重建根', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final host = GlobalKey<ElScrollViewState>();
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 300, height: 240),
              child: ElScrollView(
                key: host,
                controller: controller,
                scrollbar: const ElNoScrollBar(),
                children: [ElListView.builder(itemCount: 100000, itemBuilder: (_, i) => _Card(key: ValueKey(i)))],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final builds = host.currentState!.debugCounters.debugBuildCount;
      for (var frame = 1; frame <= 120; frame++) {
        controller.jumpTo(frame * 8);
        await tester.pump(const Duration(milliseconds: 8));
        expect(host.currentState!.debugScrollMixinClientCount, lessThan(12));
      }
      await tester.pumpAndSettle();
      expect(host.currentState!.debugCounters.debugBuildCount, builds);
      expect(host.currentState!.debugCounters.debugVisibilityDispatchCount, 0, reason: '渐显和视差消费几何，不应调度没有订阅者的可见性派发');
      expect(tester.takeException(), isNull);
    });

    testWidgets('几何效果原位开关可见性订阅，仅实际订阅期间派发', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final card = GlobalKey<_CardState>();
      final progress = GlobalKey<_ProgressState>();
      await _itemEffectsMount(tester, controller, card, progress);
      final host = tester.state<ElScrollViewState>(find.byType(ElScrollView));
      controller.jumpTo(40);
      await tester.pumpAndSettle();
      expect(host.debugCounters.debugVisibilityDispatchCount, 0);
      final original = card.currentState!;
      await _itemEffectsMount(tester, controller, card, progress, trackVisibility: true);
      expect(card.currentState, same(original));
      expect(original.visibility, isNotEmpty);
      expect(original.visibility.last.visible, isTrue);
      controller.jumpTo(400);
      await tester.pumpAndSettle();
      expect(original.visibility.last.visible, isFalse);
      await _itemEffectsMount(tester, controller, card, progress);
      final dispatches = host.debugCounters.debugVisibilityDispatchCount;
      final events = original.visibility.length;
      controller.jumpTo(42);
      await tester.pumpAndSettle();
      expect(original.scrollRevealProgress, closeTo(.5, .01));
      expect(original.visibility.length, events);
      expect(host.debugCounters.debugVisibilityDispatchCount, dispatches);
      expect(tester.takeException(), isNull);
    });

    testWidgets('范围回调内启用可见性订阅，同一帧继续派发给新订阅', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final card = GlobalKey<_CardState>();
      final progress = GlobalKey<_ProgressState>();
      final order = <String>[];
      var enable = false;
      await _itemEffectsMount(
        tester,
        controller,
        card,
        progress,
        onVisibleRangeChanged: (_) {
          if (!enable) return;
          enable = false;
          order.add('range');
          card.currentState!.enableVisibility();
        },
      );
      expect(card.currentState!.visibility, isEmpty);
      card.currentState!.onVisibility = (_) => order.add('visibility');
      enable = true;
      controller.jumpTo(40);
      await tester.pump();
      expect(order, ['range', 'visibility']);
      expect(card.currentState!.visibility.single.visible, isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('减少动态效果可来回切换，重新启用时使用当前位置', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final card = GlobalKey<_CardState>();
      final progress = GlobalKey<_ProgressState>();
      await _itemEffectsMount(tester, controller, card, progress);
      controller.jumpTo(42);
      await tester.pumpAndSettle();
      await _itemEffectsMount(tester, controller, card, progress, reduce: true);
      expect(card.currentState!.scrollRevealProgress, 1);
      expect(card.currentState!.parallaxOffset, 0);
      expect(tester.getTopLeft(find.byKey(const ValueKey('card-content'))).dy, 208);
      controller.jumpTo(200);
      await tester.pumpAndSettle();
      await _itemEffectsMount(tester, controller, card, progress);
      expect(card.currentState!.scrollRevealProgress, 1);
      expect(card.currentState!.parallaxOffset, 8);
      expect(tester.getTopLeft(find.byKey(const ValueKey('card-content'))).dy, 58);
    });

    testWidgets('几何预设不会关闭前面进度预设需要的全局观察', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final combo = GlobalKey<_GlobalFirstState>();
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 300, height: 240),
              child: ElScrollView(
                controller: controller,
                scrollbar: const ElNoScrollBar(),
                children: [
                  const ElView(style: ElStyle(height: 250)),
                  _GlobalFirst(key: combo),
                  const ElView(style: ElStyle(height: 1200)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(42);
      await tester.pumpAndSettle();
      expect(combo.currentState!.scrollRevealProgress, .5);
      expect(combo.currentState!.scrollProgressValue, closeTo(42 / 1310, .0001));
    });

    testWidgets('空内容进度为零，不产生非有限宽度', (tester) async {
      final progress = GlobalKey<_ProgressState>();
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ElView(
            style: const ElStyle(width: 300, height: 240),
            child: ElScrollView(
              scrollbar: const ElNoScrollBar(),
              children: [ElPositioned(top: 0, left: 0, right: 0, child: _Progress(key: progress))],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(progress.currentState!.scrollProgressValue, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reveal 与 Parallax 组合取自然几何，程序滚动也更新且不会被自身变换反馈', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final card = GlobalKey<_CardState>();
      final progress = GlobalKey<_ProgressState>();
      await _itemEffectsMount(tester, controller, card, progress);
      controller.jumpTo(42);
      await tester.pumpAndSettle();
      expect(card.currentState!.scrollRevealProgress, closeTo(.5, .001));
      expect(card.currentState!.parallaxOffset, closeTo(-55.2, .001));
      expect(card.currentState!.scrollItemSnapshot.leadingOffset, 208);
      expect(tester.getTopLeft(find.byKey(const ValueKey('card-content'))).dy, closeTo(164.8, .01));
      final builds = card.currentState!.builds;
      await tester.pump(const Duration(seconds: 1));
      expect(card.currentState!.builds, builds);
      expect(progress.currentState!.scrollProgressValue, closeTo(42 / 1310, .0001));
      final bar = find.descendant(of: find.byType(_Progress), matching: find.byType(ElView)).last;
      expect(tester.getSize(bar).width, closeTo(285 * 42 / 1310, .01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('once 完成后保留显示并停止自身更新，Progress 随内容范围变化重新计算', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final card = GlobalKey<_CardState>();
      final progress = GlobalKey<_ProgressState>();
      await _itemEffectsMount(tester, controller, card, progress, once: true, parallax: false);
      controller.jumpTo(200);
      await tester.pumpAndSettle();
      expect(card.currentState!.scrollRevealProgress, 1);
      final builds = card.currentState!.builds;
      controller.jumpTo(600);
      await tester.pumpAndSettle();
      expect(card.currentState!.scrollRevealProgress, 1);
      expect(card.currentState!.builds, builds);
      await _itemEffectsMount(tester, controller, card, progress, once: true, parallax: false, tail: 1500);
      expect(progress.currentState!.scrollProgressValue, closeTo(controller.offset / 1610, .0001));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(progress.currentState!.scrollProgressValue, 1);
    });

    testWidgets('真实 thumb 同时驱动三个预设', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final card = GlobalKey<_CardState>();
      final progress = GlobalKey<_ProgressState>();
      await _itemEffectsMount(tester, controller, card, progress);
      final before = card.currentState!.parallaxOffset;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('el-scrollbar-thumb-vertical'))),
        kind: .mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.moveBy(const Offset(0, 20));
      await tester.pumpAndSettle();
      expect(card.currentState!.scrollRevealProgress, greaterThan(0));
      expect(card.currentState!.parallaxOffset, isNot(before));
      expect(progress.currentState!.scrollProgressValue, greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('成员尺寸观察', () {
    testWidgets('只订阅真实成员尺寸，正文平移不派发几何回调', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final probe = GlobalKey<_SizeProbeState>();
      Future<void> pump(double height) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Align(
              alignment: .topLeft,
              child: ElView(
                style: const ElStyle(width: 300, height: 200),
                child: ElScrollView(
                  controller: controller,
                  scrollbar: const ElNoScrollBar(),
                  children: [
                    const ElView(style: ElStyle(height: 2000)),
                    ElPositioned(
                      top: 0,
                      left: 0,
                      width: 120,
                      child: _SizeProbe(key: probe, height: height),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump(50);
      expect(probe.currentState!.sizes, contains(50));
      probe.currentState!.sizes.clear();
      controller.jumpTo(90);
      await tester.pump();
      expect(probe.currentState!.sizes, isEmpty);
      await pump(80);
      expect(probe.currentState!.sizes, [80]);
      expect(tester.takeException(), isNull);
    });
  });

  group('预设效果嵌套', () {
    testWidgets('保留 State 的非活动 Tab 也会退役旧组，不继续推动共享导航头', (tester) async {
      final outer = ElScrollController();
      final inner = ElScrollController();
      final active = ValueNotifier(true);
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      addTearDown(active.dispose);
      final navbar = GlobalKey<_PresetNestedNavbarState>();
      final events = <(String, int)>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: ElView(
              style: const ElStyle(width: 300, height: 300),
              child: ElScrollView(
                controller: outer,
                physics: const ElClampingScrollPhysics(),
                scrollbar: const ElNoScrollBar(),
                children: [
                  _PresetNestedNavbar(key: navbar, events: events),
                  ValueListenableBuilder<bool>(
                    valueListenable: active,
                    builder: (_, enabled, child) => TickerMode(enabled: enabled, child: child!),
                    child: ElView(
                      style: const ElStyle(height: 260),
                      child: ElScrollView(
                        controller: inner,
                        physics: const ElClampingScrollPhysics(),
                        scrollbar: const ElNoScrollBar(),
                        children: const [ElView(style: ElStyle(height: 2000))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final drag = await tester.startGesture(const Offset(150, 200));
      addTearDown(drag.removePointer);
      await drag.moveBy(const Offset(0, -30));
      await drag.moveBy(const Offset(0, -28));
      await tester.pump();
      await drag.up(timeStamp: const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      final oldId = events.firstWhere((event) => event.$1 == 'end').$2;
      final progress = navbar.currentState!.largeTitleNavbarProgress;
      active.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(navbar.currentState!.largeTitleNavbarProgress, progress);
      expect(events.where((event) => event == ('cancelled', oldId)), hasLength(1));
      expect(events.where((event) => event == ('settled', oldId)), isEmpty);
      active.value = true;
      await tester.pumpAndSettle();
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: const Offset(150, 200), scrollDelta: const Offset(0, 40)),
      );
      await tester.pumpAndSettle();
      expect(navbar.currentState!.largeTitleNavbarProgress, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('按住内层惯性后同一手势仍可继续拖动内层', (tester) async {
      final outer = ElScrollController();
      final inner = ElScrollController();
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      final navbar = GlobalKey<_PresetNestedNavbarState>();
      await _presetNestedMount(tester, outer, inner, navbar, []);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: const Offset(150, 200), scrollDelta: const Offset(0, 100)),
      );
      await tester.pumpAndSettle();
      await tester.flingFrom(const Offset(150, 200), const Offset(0, -80), 1500);
      await tester.pump(const Duration(milliseconds: 16));
      final drag = await tester.startGesture(const Offset(150, 180));
      addTearDown(drag.removePointer);
      final before = inner.offset;
      await drag.moveBy(const Offset(0, -30));
      await drag.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(inner.offset, greaterThan(before));
      expect(outer.offset, 0);
      await drag.up(timeStamp: const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('内层真实输入先折叠外层导航头，余量只推动内层正文', (tester) async {
      final outer = ElScrollController();
      final inner = ElScrollController();
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      final navbar = GlobalKey<_PresetNestedNavbarState>();
      await _presetNestedMount(tester, outer, inner, navbar, []);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: const Offset(150, 200), scrollDelta: const Offset(0, 100)),
      );
      await tester.pumpAndSettle();
      expect(navbar.currentState!.largeTitleNavbarProgress, 1);
      expect(inner.offset, 44);
      expect(outer.offset, 0);
      expect(tester.getTopLeft(find.byType(_PresetNestedNavbar)).dy, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('内层 Tab 换代取消旧吸附组，新 Tab 可继续驱动共享导航头', (tester) async {
      final outer = ElScrollController();
      final first = ElScrollController();
      final second = ElScrollController();
      addTearDown(outer.dispose);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final navbar = GlobalKey<_PresetNestedNavbarState>();
      final events = <(String, int)>[];
      await _presetNestedMount(tester, outer, first, navbar, events);
      final drag = await tester.startGesture(const Offset(150, 200));
      addTearDown(drag.removePointer);
      await drag.moveBy(const Offset(0, -30));
      await drag.moveBy(const Offset(0, -28));
      await tester.pump();
      await drag.up(timeStamp: const Duration(seconds: 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      final oldId = events.firstWhere((event) => event.$1 == 'end').$2;
      final progress = navbar.currentState!.largeTitleNavbarProgress;
      await _presetNestedMount(tester, outer, second, navbar, events, tab: 'b');
      await tester.pump(const Duration(milliseconds: 300));
      expect(events.where((event) => event == ('cancelled', oldId)), hasLength(1));
      expect(events.where((event) => event == ('settled', oldId)), isEmpty);
      expect(navbar.currentState!.largeTitleNavbarProgress, progress);
      expect(second.offset, 0);
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: const Offset(150, 200), scrollDelta: const Offset(0, 40)),
      );
      await tester.pumpAndSettle();
      expect(navbar.currentState!.largeTitleNavbarProgress, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('嵌套下拉只触发内层刷新，并显示在共享导航头下方', (tester) async {
      final outer = ElScrollController();
      final inner = ElScrollController();
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      final navbar = GlobalKey<_PresetNestedNavbarState>();
      final completion = Completer<void>();
      var calls = 0;
      await _presetNestedMount(
        tester,
        outer,
        inner,
        navbar,
        [],
        onRefresh: () {
          calls++;
          return completion.future;
        },
      );
      final drag = await tester.startGesture(const Offset(150, 200));
      addTearDown(drag.removePointer);
      await drag.moveBy(const Offset(0, 30));
      await drag.moveBy(const Offset(0, 160));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('inner-indicator'))).dy,
        tester.getBottomRight(find.byType(_PresetNestedNavbar)).dy,
      );
      await drag.up(timeStamp: const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(outer.offset, 0);
      completion.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
