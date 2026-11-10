import 'package:example/src/pages/examples/sliver_recycler_grid.dart';
import 'package:example/src/pages/home.dart';
import 'package:example/src/utils/router.dart';
import 'package:example/src/widgets/example_scrollbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Scene = ({Finder scroll, Finder bar, ScrollPosition position, ScrollbarPainter painter, RenderBox viewport});

typedef _Frame = ({double pixels, double maxExtent, double thumb, Size viewport, Map<int, Rect> cards});

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.75;
  tester.view.physicalSize = Size(1080, 2400);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(Widget page) => ElComponentProvider(
  components: el.mobileComponents,
  child: MaterialApp(
    navigatorKey: RouterUtil.rootNavigatorKey,
    theme: ThemeData(platform: .android),
    home: page,
  ),
);

_Scene _scene(WidgetTester tester, {required bool masonry}) {
  final scroll = find.byKey(ValueKey(masonry ? 'sliver-masonry-scroll' : 'sliver-grid-scroll'));
  final wrapper = find.ancestor(of: scroll, matching: find.byType(RecyclerExampleScrollbar));
  expect(tester.widget<RecyclerExampleScrollbar>(wrapper).stopOnThumbRelease, isFalse);
  final bar = find.ancestor(of: scroll, matching: find.byType(CupertinoScrollbar));
  expect(bar, findsOneWidget);
  final scrollbar = tester.widget<CupertinoScrollbar>(bar);
  expect(scrollbar.controller, same(tester.widget<CustomScrollView>(scroll).controller));
  expect(scrollbar.thumbVisibility, isTrue);
  final state = tester.state<RawScrollbarState<CupertinoScrollbar>>(bar);
  // 命中真实绘制的滑块，不能用内容拖动代替滚动条交互。
  // ignore: invalid_use_of_protected_member
  final painter = state.scrollbarPainter;
  final viewport = find.descendant(of: scroll, matching: find.byWidgetPredicate((widget) => widget is Viewport));
  return (
    scroll: scroll,
    bar: bar,
    position: scrollbar.controller!.position,
    painter: painter,
    viewport: tester.renderObject<RenderBox>(viewport),
  );
}

_Frame _readFrame(WidgetTester tester, _Scene scene) {
  final grid = find.descendant(of: scene.scroll, matching: find.byType(ElSliverRecyclerGrid));
  final cards = find.descendant(of: grid, matching: find.byType(ElCardView));
  final bounds = Offset.zero & scene.viewport.size;
  final visible = <int, Rect>{};
  for (final element in cards.evaluate()) {
    final box = element.findRenderObject()! as RenderBox;
    // 只比较视口内坐标，预测返回整页的正常缩放和平移不属于卡片跳动。
    final rect = box.localToGlobal(Offset.zero, ancestor: scene.viewport) & box.size;
    if (!rect.overlaps(bounds)) continue;
    final card = find.byElementPredicate((candidate) => identical(candidate, element));
    final label = find.descendant(
      of: card,
      matching: find.byWidgetPredicate((widget) => widget is Text && (widget.data?.startsWith('观察记录 ') ?? false)),
    );
    final id = int.parse(tester.widget<Text>(label).data!.substring('观察记录 '.length));
    expect(visible.containsKey(id), isFalse, reason: '可见卡片中不应重复出现记录 $id');
    visible[id] = rect;
  }
  return (
    pixels: scene.position.pixels,
    maxExtent: scene.position.maxScrollExtent,
    thumb: scene.painter.getThumbScrollOffset(),
    viewport: scene.viewport.size,
    cards: visible,
  );
}

void _expectColumns(_Frame frame, {required bool masonry, required String phase}) {
  expect(frame.cards, isNotEmpty, reason: phase);
  for (final left in [true, false]) {
    final column = frame.cards.values.where((rect) => (rect.left < frame.viewport.width / 2) == left).toList()
      ..sort((a, b) => a.top.compareTo(b.top));
    expect(column, isNotEmpty, reason: '$phase，两列都应有可见卡片');
    for (var index = 1; index < column.length; index++) {
      final expectedTop = column[index - 1].bottom + 12;
      expect(column[index].top, greaterThanOrEqualTo(expectedTop - .05), reason: '$phase，同列卡片不应重叠');
      if (masonry) {
        expect(column[index].top, closeTo(expectedTop, .05), reason: '$phase，瀑布流同列不应出现额外空洞');
      }
    }
    if (masonry) {
      expect(column.first.top, lessThanOrEqualTo(12.05), reason: '$phase，列头不应露白');
      expect(column.last.bottom, greaterThanOrEqualTo(frame.viewport.height - 12.05), reason: '$phase，列底不应露白');
    }
  }
}

Set<bool> _expectMotion(_Frame before, _Frame after, double requestedPixels, String phase) {
  final compared = <bool>{};
  for (final MapEntry(key: id, value: oldRect) in before.cards.entries) {
    final rect = after.cards[id];
    if (rect == null) continue;
    compared.add(oldRect.left < before.viewport.width / 2);
    expect(rect.left, closeTo(oldRect.left, .05), reason: '$phase，记录 $id 不应换列');
    expect(rect.width, closeTo(oldRect.width, .05), reason: '$phase，记录 $id 的宽度应稳定');
    expect(rect.height, closeTo(oldRect.height, .05), reason: '$phase，记录 $id 的高度应稳定');
    // 使用布局前请求的位移，实测尺寸引起的合法 scrollOffsetCorrection 不应让画面额外跳动。
    expect(
      rect.top - oldRect.top + requestedPixels - before.pixels,
      closeTo(0, .05),
      reason: '$phase，记录 $id 应只移动本次滚动请求的距离',
    );
  }
  return compared;
}

void _expectStationary(_Frame actual, _Frame expected, String phase) {
  expect(actual.pixels, closeTo(expected.pixels, .01), reason: '$phase，内容滚动位置变化');
  expect(actual.maxExtent, closeTo(expected.maxExtent, .01), reason: '$phase，总滚动范围变化');
  expect(actual.thumb, closeTo(expected.thumb, .01), reason: '$phase，滑块位置变化');
  expect(actual.viewport, expected.viewport, reason: '$phase，视口尺寸变化');
  expect(actual.cards.keys, unorderedEquals(expected.cards.keys), reason: '$phase，可见记录发生替换');
  for (final MapEntry(key: id, value: rect) in actual.cards.entries) {
    final before = expected.cards[id]!;
    expect(rect.left, closeTo(before.left, .05), reason: '$phase，记录 $id 横跳');
    expect(rect.top, closeTo(before.top, .05), reason: '$phase，记录 $id 纵向跳动');
    expect(rect.width, closeTo(before.width, .05), reason: '$phase，记录 $id 宽度变化');
    expect(rect.height, closeTo(before.height, .05), reason: '$phase，记录 $id 高度变化');
  }
}

Offset _thumbStart(WidgetTester tester, _Scene scene) {
  final rail = tester.getRect(scene.bar);
  final local = Offset(rail.width - 4.5, scene.painter.getThumbScrollOffset() + 18);
  expect(scene.painter.hitTestOnlyThumbInteractive(local, .touch), isTrue);
  return rail.topLeft + local;
}

Future<void> _predictiveBack(WidgetTester tester, String method, [double progress = 0]) async {
  final logicalWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    StandardMethodCodec().encodeMethodCall(
      MethodCall(method, {
        'touchOffset': [logicalWidth - 2 - progress * 140, 400.0 + progress * 9],
        'progress': progress,
        'swipeEdge': 1,
      }),
    ),
    (_) {},
  );
  await tester.pump(Duration(milliseconds: 16));
}

void main() {
  for (final masonry in [false, true]) {
    testWidgets('${masonry ? '瀑布流' : '网格'}标准滑块反向拖动、停住和松手不改变卡片位置', (tester) async {
      _viewport(tester);
      await tester.pumpWidget(
        _app(masonry ? ElSliverRecyclerGridExamplePage.masonry() : ElSliverRecyclerGridExamplePage()),
      );
      await tester.pumpAndSettle();
      final scene = _scene(tester, masonry: masonry);
      final start = _thumbStart(tester, scene);
      final travel = scene.position.maxScrollExtent / scene.painter.getTrackToScroll(1);
      final gesture = await tester.startGesture(start);
      var time = Duration(milliseconds: 140);
      await tester.pump(time);

      var previous = _readFrame(tester, scene);
      final comparedColumns = <bool>{};
      for (final fraction in [.13, .31, .52, .73, .60, .49, .37, .251, .25075, .2505, .25025, .25]) {
        final interval = Duration(microseconds: 8333);
        time += interval;
        await gesture.moveTo(start.translate(0, travel * fraction), timeStamp: time);
        final requested = scene.position.pixels;
        await tester.pump(interval);
        final frame = _readFrame(tester, scene);
        _expectColumns(frame, masonry: masonry, phase: '拖至 $fraction');
        comparedColumns.addAll(_expectMotion(previous, frame, requested, '拖至 $fraction'));
        previous = frame;
      }
      expect(comparedColumns, hasLength(2), reason: '反向微调应比较到两列仍然可见的卡片');

      // 用户确实停住后再松手，标准滚动条应以零速度结束，不改变其正常惯性规则。
      final hold = Duration(milliseconds: 160);
      time += hold;
      await tester.pump(hold);
      final stopped = _readFrame(tester, scene);
      _expectStationary(stopped, previous, '保持按住滑块');
      await gesture.up(timeStamp: time);
      expect(scene.position.isScrollingNotifier.value, isFalse);
      for (final delay in [8, 16, 80, 160]) {
        await tester.pump(Duration(milliseconds: delay));
        _expectStationary(_readFrame(tester, scene), stopped, '停住松手后 $delay ms');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }

  testWidgets('瀑布流标准滑块松手保留正常惯性，卡片不换列或回退', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(_app(ElSliverRecyclerGridExamplePage.masonry()));
    await tester.pumpAndSettle();
    final scene = _scene(tester, masonry: true);
    final start = _thumbStart(tester, scene);
    final travel = scene.position.maxScrollExtent / scene.painter.getTrackToScroll(1);
    final gesture = await tester.startGesture(start);
    var time = Duration(milliseconds: 140);
    await tester.pump(time);

    final interval = Duration(milliseconds: 16);
    time += interval;
    await gesture.moveTo(start.translate(0, travel * .2), timeStamp: time);
    await tester.pump(interval);
    var previous = _readFrame(tester, scene);
    for (var step = 1; step <= 10; step++) {
      time += interval;
      // 每 16 ms 移动 2.4 px，速度 150 px/s，超过标准滑块的 50 px/s 甩动阈值。
      await gesture.moveTo(start.translate(0, travel * .2 + step * 2.4), timeStamp: time);
      final requested = scene.position.pixels;
      await tester.pump(interval);
      final frame = _readFrame(tester, scene);
      _expectMotion(previous, frame, requested, '松手前连续拖动 $step');
      previous = frame;
    }

    // 不在最后一次移动与 up 之间停顿，真实速度交给 CupertinoScrollbar 处理。
    await gesture.up(timeStamp: time);
    expect(scene.position.isScrollingNotifier.value, isTrue, reason: '不能通过停用标准滑块惯性让稳定性检查通过');
    var requestedPixels = previous.pixels;
    void recordRequested() {
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.transientCallbacks) {
        requestedPixels = scene.position.pixels;
      }
    }

    scene.position.addListener(recordRequested);
    final comparedColumns = <bool>{};
    var moved = false;
    try {
      for (var frameIndex = 0; frameIndex < 24 && scene.position.isScrollingNotifier.value; frameIndex++) {
        requestedPixels = previous.pixels;
        await tester.pump(Duration(microseconds: 8333));
        final frame = _readFrame(tester, scene);
        _expectColumns(frame, masonry: true, phase: '松手惯性第 $frameIndex 帧');
        final compared = _expectMotion(previous, frame, requestedPixels, '松手惯性第 $frameIndex 帧');
        if (compared.isNotEmpty) {
          expect(requestedPixels, greaterThanOrEqualTo(previous.pixels - .01), reason: '向下拖动松手后不应反向回退');
          moved |= requestedPixels > previous.pixels + .01;
        }
        comparedColumns.addAll(compared);
        previous = frame;
      }
    } finally {
      scene.position.removeListener(recordRequested);
    }
    expect(moved, isTrue, reason: '松手后应观察到真实的前向惯性位移');
    expect(comparedColumns, hasLength(2), reason: '惯性期间应比较到两列卡片');
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    final settled = _readFrame(tester, scene);
    await tester.pump(Duration(milliseconds: 80));
    _expectStationary(_readFrame(tester, scene), settled, '正常惯性结束后');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('首页瀑布流预测返回取消和提交期间保持阅读几何', (tester) async {
    _viewport(tester);
    await tester.pumpWidget(_app(HomePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('home-sliver-recycler-masonry')));
    await tester.pumpAndSettle();
    final scene = _scene(tester, masonry: true);
    scene.position.jumpTo(4000);
    await tester.pumpAndSettle();
    final baseline = _readFrame(tester, scene);
    expect(baseline.pixels, greaterThan(1000));
    _expectColumns(baseline, masonry: true, phase: '开始预测返回前');
    final sliver = find.byType(ElSliverRecyclerGrid);
    final sliverElement = tester.element(sliver);
    final sliverRender = tester.renderObject(sliver);

    await _predictiveBack(tester, 'startBackGesture');
    final route = ModalRoute.of(tester.element(find.byType(ElSliverRecyclerGridExamplePage)))!;
    expect(route.popGestureInProgress, isTrue);
    for (final progress in [.12, .45, .38, .66, .20]) {
      await _predictiveBack(tester, 'updateBackGestureProgress', progress);
      _expectStationary(_readFrame(tester, scene), baseline, '预测返回进度 $progress');
      expect(tester.element(sliver), same(sliverElement));
      expect(tester.renderObject(sliver), same(sliverRender));
      expect(tester.takeException(), isNull);
    }
    await _predictiveBack(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    _expectStationary(_readFrame(tester, scene), baseline, '取消预测返回');

    await _predictiveBack(tester, 'startBackGesture');
    await _predictiveBack(tester, 'updateBackGestureProgress', .6);
    _expectStationary(_readFrame(tester, scene), baseline, '提交预测返回前');
    await _predictiveBack(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ElSliverRecyclerGridExamplePage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
}
