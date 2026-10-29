import 'dart:math' as math;
import 'package:flutter_base/src/ui/cores/layout/geometry/grid_geometry.dart';
import 'package:flutter_base/src/ui/cores/layout/geometry/list_geometry.dart';
import 'package:flutter_base/src/ui/cores/scroll/plan/segment_diff.dart';
import 'package:flutter_base/src/ui/cores/scroll/plan/segment_extent_index.dart';
import 'package:flutter_base/src/ui/cores/scroll/plan/segment_plan.dart';
import 'package:flutter_base/src/ui/cores/scroll/spec/segment_resolver.dart';
import 'package:flutter_base/src/ui/cores/scroll/spec/segment_spec.dart';
import 'package:flutter_base/src/ui/cores/scroll/virtual/virtual_extent_index.dart';
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/virtual_test_host.dart';

class _NoChromeScrollBehavior extends ScrollBehavior {
  const _NoChromeScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => ClampingScrollPhysics();
}

/// 始终可见的条带探针：统计视口内 chrome 份数与重建次数。
class _MarkerBar extends ElAndroidScrollBar {
  _MarkerBar(Color color) : super(thumbColor: color, interactive: true);

  /// chrome 子树（条带/corner）的重建次数：只有配置变化才应增加。
  int chromeBuilds = 0;

  @override
  List<Widget> buildChildren(BuildContext context, ElScrollbarDetails details) {
    chromeBuilds++;
    return super.buildChildren(context, details);
  }

  @override
  bool resolveAlwaysVisible(BuildContext context, ElScrollbarAxisDetails axis) => true;
}

Widget _host(Widget child, {double width = 200, double height = 100}) => MaterialApp(
  home: Align(
    alignment: .topLeft,
    child: SizedBox(width: width, height: height, child: child),
  ),
);

ElScrollView _scroll(
  ElListView list, {
  ElScrollController? controller,
  Axis axis = .vertical,
  bool shrinkWrap = false,
}) => ElScrollView(
  controller: controller,
  axis: axis,
  shrinkWrap: shrinkWrap,
  cacheExtent: 0,
  scrollbar: ElNoScrollBar(),
  children: [list],
);

/// 叶子探针：performLayout 真实执行才计数（clean 早退不计）。
class _LayoutProbe extends LeafRenderObjectWidget {
  const _LayoutProbe({super.key, required this.height});

  final double height;

  static int layoutCount = 0;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLayoutProbe(height);

  @override
  void updateRenderObject(BuildContext context, covariant _RenderLayoutProbe renderObject) {
    renderObject.height = height;
  }
}

class _RenderLayoutProbe extends RenderBox {
  _RenderLayoutProbe(this._height);

  double _height;

  set height(double v) {
    if (_height == v) return;
    _height = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    _LayoutProbe.layoutCount++;
    size = constraints.constrain(Size(constraints.maxWidth.isFinite ? constraints.maxWidth : 100, _height));
  }
}

Widget _shell({required List<Widget> children, ScrollController? controller}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 400,
        height: 600,
        child: ElScrollView(controller: controller, physics: const ClampingScrollPhysics(), children: children),
      ),
    ),
  );
}

/// 等高快路径（uniform stride）的可见窗口边界回归：解析式索引在"pixels 恰好
/// 落在行边界"与"行高带浮点噪声"两种形状下都必须与二分路径读的落位数组一致。
/// 守卫从 virtual render 移植过来（D4），此前 simple 是裸解析式。
Widget _uniformVisibleRangeBoundaryShell({
  required ScrollController controller,
  required double rowExtent,
  required int rowCount,
  ValueChanged<ElVisibleRange>? onVisibleRangeChanged,
}) {
  return MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 300,
        height: 200,
        child: ElScrollView(
          controller: controller,
          // cache 归零：mounted 窗口即可视窗口，走 Fenwick 落位二分——与旧
          // virtual render 可视窗口探针同源口径（本守卫移植自它）。
          cacheExtent: 0,
          onVisibleRangeChanged: onVisibleRangeChanged,
          children: List<Widget>.generate(
            rowCount,
            (index) => ElView(
              style: ElStyle(width: 300, height: rowExtent),
              child: 'row $index',
            ),
          ),
        ),
      ),
    ),
  );
}

SegmentExtentIndex _index(List<Widget> children, {double gap = 0}) => SegmentExtentIndex(
  SegmentPlan(resolveScrollSegments(children, scrollAxis: .vertical), outerGap: gap, crossAxisExtent: 300),
  estimatedExtent: 32,
);

int _firstVisibleIndex(WidgetTester tester) {
  var result = 1 << 30;
  for (final widget in tester.widgetList(find.byWidgetPredicate((widget) => widget.key is ValueKey<String>))) {
    final value = (widget.key! as ValueKey<String>).value;
    if (!value.startsWith('page-')) continue;
    final index = int.tryParse(value.substring('page-'.length));
    if (index != null && index < result) result = index;
  }
  return result;
}

final class _CustomDelegate extends SliverChildDelegate {
  @override
  Widget? build(BuildContext context, int index) => index == 0 ? ElView() : null;
  @override
  int? get estimatedChildCount => 1;
  @override
  bool shouldRebuild(covariant _CustomDelegate oldDelegate) => false;
}

Widget _uniformExtentLifecycleHost(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: SizedBox(width: 120, height: 120, child: child),
  ),
);

ElScrollViewState _scrollState(WidgetTester tester) => tester.state<ElScrollViewState>(find.byType(ElScrollView));

final class _MountedRow extends StatefulWidget {
  const _MountedRow(this.index);

  final int index;

  @override
  State<_MountedRow> createState() => _MountedRowState();
}

final class _MountedRowState extends State<_MountedRow> {
  @override
  Widget build(BuildContext context) => SizedBox(height: 40, child: Text('row ${widget.index}'));
}

Widget _scrollHost({ScrollController? controller, required List<Widget> children, bool shrinkWrap = false}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: DefaultTextStyle(
      style: const TextStyle(),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 240,
          height: 120,
          child: ElScrollView(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            cacheExtent: 0,
            shrinkWrap: shrinkWrap,
            children: children,
          ),
        ),
      ),
    ),
  );
}

Finder _probeFinder(String id) {
  return find.byWidgetPredicate((widget) => widget is _LifecycleProbe && widget.id == id);
}

final class _LifecycleTrace {
  int _nextStateId = 0;
  final Map<String, List<int>> initializedStateIds = <String, List<int>>{};
  final Map<String, int> builds = <String, int>{};
  final Map<String, int> updates = <String, int>{};
  final Map<String, int> deactivates = <String, int>{};
  final Map<String, int> activates = <String, int>{};
  final Map<String, int> disposes = <String, int>{};

  int initialize(String id) {
    final stateId = _nextStateId++;
    initializedStateIds.putIfAbsent(id, () => <int>[]).add(stateId);
    return stateId;
  }

  void build(String id) => _increment(builds, id);
  void update(String id) => _increment(updates, id);
  void deactivate(String id) => _increment(deactivates, id);
  void activate(String id) => _increment(activates, id);
  void dispose(String id) => _increment(disposes, id);

  int initsFor(String id) => initializedStateIds[id]?.length ?? 0;
  int updatesFor(String id) => updates[id] ?? 0;
  int deactivatesFor(String id) => deactivates[id] ?? 0;
  int disposesFor(String id) => disposes[id] ?? 0;
  int get totalInits => initializedStateIds.values.fold(0, (total, ids) => total + ids.length);
  int get totalDeactivates => _total(deactivates);
  int get totalDisposes => _total(disposes);

  static void _increment(Map<String, int> target, String id) {
    target.update(id, (count) => count + 1, ifAbsent: () => 1);
  }

  static int _total(Map<String, int> target) => target.values.fold(0, (total, count) => total + count);
}

final class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({super.key, required this.id, required this.revision, required this.trace});

  final String id;
  final int revision;
  final _LifecycleTrace trace;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

final class _LifecycleProbeState extends State<_LifecycleProbe> {
  late final int stateId;

  @override
  void initState() {
    super.initState();
    stateId = widget.trace.initialize(widget.id);
  }

  @override
  void didUpdateWidget(covariant _LifecycleProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.trace.update(widget.id);
  }

  @override
  void deactivate() {
    widget.trace.deactivate(widget.id);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.trace.activate(widget.id);
  }

  @override
  void dispose() {
    widget.trace.dispose(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.trace.build(widget.id);
    return SizedBox(height: 40, child: Text('${widget.id}:${widget.revision}'));
  }
}

Widget _visibleRangeHost({
  required ScrollController controller,
  required int itemCount,
  ValueChanged<ElVisibleRange>? onVisibleRangeChanged,
  double cacheExtent = 0.0,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        height: 120,
        child: buildVirtualTestView(
          controller: controller,
          scrollbar: const ElNoScrollBar(),
          physics: const ClampingScrollPhysics(),
          cacheExtent: cacheExtent,
          onVisibleRangeChanged: onVisibleRangeChanged,
          children: [
            for (var index = 0; index < itemCount; index++)
              SizedBox(key: ValueKey('plain-$index'), height: 40, child: Text('plain $index')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('尺寸测量环境变化', () {
    Widget buildHost({required double width, required ScrollController controller}) {
      return MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: width,
            height: 400,
            child: buildVirtualTestView(
              controller: controller,
              children: [
                // 固定高度行：交叉轴变宽/变窄都不改行高，正是『确认未变』臂的靶场景。
                for (var i = 0; i < 30; i++)
                  ElView(key: ValueKey('row$i'), style: const ElStyle(height: 40), child: 'row-$i'),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('横向 resize + 行高不变：drift 标志被确认未变臂清除、measured 环境推进', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildHost(width: 400, controller: controller));
      await tester.pumpAndSettle();

      final state = tester.state<ElScrollViewState>(find.byType(ElScrollView));
      expect(state.debugExtentEnvironmentDriftedFromMeasured, isFalse, reason: '初始环境即基线，无漂移');
      expect(state.debugMeasuredEnvironmentCrossAxisExtent, 400.0, reason: '基线环境交叉轴 = 视口宽');
      final measuredBefore = state.debugCounters.debugMeasuredItemCount;
      expect(measuredBefore, greaterThan(0), reason: '首帧 mounted 行已度量');
      final appliesBefore = state.debugCounters.debugApplyItemExtentsChangedCount;

      // 视口横向 resize：环境交叉轴变化超过滞回阈值 → drift 立起；行高不变，
      // 同帧 mounted 行重报一致 extent → 收敛臂清除 drift 并推进 measured 环境。
      await tester.pumpWidget(buildHost(width: 300, controller: controller));
      await tester.pumpAndSettle();

      expect(state.debugExtentEnvironmentDriftedFromMeasured, isFalse, reason: '确认未变臂必须落下 drift 标志');
      expect(state.debugMeasuredEnvironmentCrossAxisExtent, 300.0, reason: 'measured 环境必须推进到新交叉轴');
      expect(
        state.debugCounters.debugApplyItemExtentsChangedCount,
        appliesBefore,
        reason: '一致重报走簿记快路径，不得触发全量重置旧路（重置臂会计入 apply 计数）',
      );
      expect(state.debugCounters.debugMeasuredItemCount, measuredBefore, reason: '存量度量必须原样保留，不得因环境漂移被丢弃重测');
    });
  });

  group('网格估高刷新', () {
    testWidgets('估计刷新后 grid 固定行高不被测量均值抹掉，maxScrollExtent 精确', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 316,
                height: 400,
                child: ElScrollView(
                  controller: controller,
                  cacheExtent: 0.0,
                  children: [
                    // 4 个 100px list 行填满首屏：全部被测量，均值 100 vs 估计 32
                    // → ratio 3.1 ≥ 1.25，必触发未测行估计刷新。
                    for (var i = 0; i < 4; i++) SizedBox(key: ValueKey('row$i'), height: 100),
                    // 100 个 grid 行（3 列 × 300 cell，固定 40 高），首帧全部屏外未挂载。
                    buildVirtualGrid(
                      crossAxisCount: 3,
                      itemHeight: 40,
                      gap: 8,
                      itemCount: 300,
                      itemBuilder: (_, i) => Text('c$i', key: ValueKey('c$i')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // 测量上报 + 估计刷新落地。
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // 精确总高：4*100 + 100*40 + 99*8（grid 段内 rowGap）= 5192。
      // 修复前未挂载 grid 行被抹成均值 ~100 → maxScrollExtent 偏大数千 px。
      expect(controller.position.maxScrollExtent, closeTo(5192 - 400, 1.0));

      // 滚到深处 grid 行仍按固定行高落位（不产生逐行重测修正抖动的错位）。
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('c299'), skipOffstage: false), findsOneWidget);
      expect(controller.position.maxScrollExtent, closeTo(5192 - 400, 1.0), reason: '滚动后总高不得漂移');
    });
  });

  group('虚拟网格', () {
    Widget cell(int i) => SizedBox(key: ValueKey('cell$i'), child: Text('c$i'));

    Widget shell({required Widget child, double width = 316, double height = 400}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      );
    }

    Finder cellFinder(int i) => find.byKey(ValueKey('cell$i'), skipOffstage: false);

    group('单 grid 段：3 列 itemHeight 100', () {
      Widget build({int count = 30, double gap = 8, ScrollController? controller}) {
        final built = <int>{};
        return shell(
          child: ElScrollView(
            controller: controller,
            children: [
              buildVirtualGrid(
                crossAxisCount: 3,
                itemHeight: 100,
                gap: gap,
                itemCount: count,
                itemBuilder: (_, i) {
                  built.add(i);
                  return cell(i);
                },
              ),
            ],
          ),
        );
      }

      testWidgets('cell 几何：cellW=(316-16)/3=100，列偏移 108，行首主轴 = row*(100+8)', (tester) async {
        await tester.pumpWidget(build());
        // 视口宽 316：cellW = (316 - 2*8)/3 = 100
        final c0 = tester.getTopLeft(cellFinder(0));
        final c1 = tester.getTopLeft(cellFinder(1));
        final c2 = tester.getTopLeft(cellFinder(2));
        final c3 = tester.getTopLeft(cellFinder(3));
        expect(tester.getSize(cellFinder(0)).width, closeTo(100, 0.01));
        expect(tester.getSize(cellFinder(0)).height, closeTo(100, 0.01));
        // 同行同主轴起点，列偏移 100+8
        expect(c1.dy, closeTo(c0.dy, 0.01));
        expect(c2.dy, closeTo(c0.dy, 0.01));
        expect(c1.dx - c0.dx, closeTo(108, 0.01));
        expect(c2.dx - c1.dx, closeTo(108, 0.01));
        // 次行主轴 = 行高 100 + rowGap 8
        expect(c3.dx, closeTo(c0.dx, 0.01));
        expect(c3.dy - c0.dy, closeTo(108, 0.01));
      });

      testWidgets('虚拟化生效：30 项只挂载视口窗口，深处 cell 未构建', (tester) async {
        await tester.pumpWidget(build(count: 3000));
        // 视口 400 高，行高 108，可见约 4 行 + cache 500/108≈5 行 → 远小于 1000 行
        expect(cellFinder(0), findsOneWidget);
        expect(cellFinder(2999), findsNothing);
        // 挂载的 element 数量有界（可见+cache 窗口 ≈ 10 行 × 3 列 + 余量）
        final textCount = tester.widgetList(find.byType(Text, skipOffstage: false)).length;
        expect(textCount, lessThan(120));
      });

      testWidgets('整行挂载：mounted cell 数恒为 3 的倍数（末行除外）', (tester) async {
        await tester.pumpWidget(build(count: 3000));
        final cells = tester
            .widgetList(find.byType(Text, skipOffstage: false))
            .map((w) => (w as Text).data!)
            .where((t) => t.startsWith('c'))
            .map((t) => int.parse(t.substring(1)))
            .toList();
        expect(cells, isNotEmpty);
        // mounted 集是连续 index 区间且行对齐：min 是 3 的倍数，max+1 是 3 的倍数或 3000
        cells.sort();
        expect(cells.first % 3, 0, reason: 'mounted 首 cell 必须是行首');
        final end = cells.last + 1;
        expect(end % 3 == 0 || end == 3000, isTrue, reason: 'mounted 尾必须是行尾（或列表尾）');
        // 连续性
        for (var i = 1; i < cells.length; i++) {
          expect(cells[i], cells[i - 1] + 1, reason: 'mounted 必须是连续 item 区间');
        }
      });

      testWidgets('滚动条总高精确：totalExtent = 行数*100 + (行数-1)*8', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(build(count: 30, controller: controller));
        await tester.pump();
        // 10 行：10*100 + 9*8 = 1072；maxScrollExtent = 1072 - 400
        expect(controller.position.maxScrollExtent, closeTo(1072 - 400, 0.5));
      });

      testWidgets('滚到深处再滚回，首行位置精确回零', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(build(count: 300, controller: controller));
        await tester.pump();
        controller.jumpTo(2000);
        await tester.pump();
        expect(cellFinder(0), findsNothing);
        controller.jumpTo(0);
        await tester.pump();
        final c0 = tester.getTopLeft(cellFinder(0));
        final container = tester.getTopLeft(find.byType(ElScrollView));
        expect(c0.dy - container.dy, closeTo(0, 0.01));
      });
    });

    group('混排：header + grid + footer', () {
      Widget build() {
        return shell(
          child: ElScrollView(
            gap: 20,
            children: [
              SizedBox(key: const ValueKey('header'), height: 40, child: const Text('header')),
              buildVirtualGrid(
                crossAxisCount: 2,
                itemHeight: 100,
                rowGap: 4,
                columnGap: 6,
                itemCount: 5,
                itemBuilder: (_, i) => cell(i),
              ),
              SizedBox(key: const ValueKey('footer'), height: 40, child: const Text('footer')),
            ],
          ),
        );
      }

      testWidgets('段边界间距用外层 gap，段内用 rowGap', (tester) async {
        await tester.pumpWidget(build());
        // list 段行（header/footer）首帧用估算高，实测经报告在帧尾落地 → 多泵两帧。
        await tester.pump();
        await tester.pump();
        final header = tester.getTopLeft(find.byKey(const ValueKey('header')));
        final c0 = tester.getTopLeft(cellFinder(0));
        final c2 = tester.getTopLeft(cellFinder(2));
        final c4 = tester.getTopLeft(cellFinder(4));
        final footer = tester.getTopLeft(find.byKey(const ValueKey('footer')));
        // header(40) + 外层 gap(20) → grid row0
        expect(c0.dy - header.dy, closeTo(60, 0.01));
        // grid 段内行距 4：row1 = row0 + 100 + 4
        expect(c2.dy - c0.dy, closeTo(104, 0.01));
        // row2（末行，单 cell）
        expect(c4.dy - c2.dy, closeTo(104, 0.01));
        // grid 末行(100) + 外层 gap(20) → footer
        expect(footer.dy - c4.dy, closeTo(120, 0.01));
        // cellW = (316-6)/2 = 155
        expect(tester.getSize(cellFinder(0)).width, closeTo(155, 0.01));
        // 末行不满列：cell4 在列 0
        expect(c4.dx, closeTo(c0.dx, 0.01));
      });

      testWidgets('list 成员照常渲染全宽', (tester) async {
        await tester.pumpWidget(build());
        expect(tester.getSize(find.byKey(const ValueKey('header'))).width, closeTo(316, 0.01));
      });
    });

    group('同页多 grid 段', () {
      testWidgets('两个 grid 段各自独立列数与间距', (tester) async {
        await tester.pumpWidget(
          shell(
            child: ElScrollView(
              gap: 10,
              children: [
                buildVirtualGrid(
                  crossAxisCount: 3,
                  itemHeight: 50,
                  gap: 8,
                  itemCount: 3,
                  itemBuilder: (_, i) => cell(i),
                ),
                buildVirtualGrid(
                  crossAxisCount: 2,
                  itemHeight: 80,
                  gap: 4,
                  itemCount: 2,
                  itemBuilder: (_, i) => SizedBox(key: ValueKey('b$i'), child: Text('b$i')),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        final a0 = tester.getTopLeft(cellFinder(0));
        final b0 = tester.getTopLeft(find.byKey(const ValueKey('b0')));
        final b1 = tester.getTopLeft(find.byKey(const ValueKey('b1')));
        // 段 A 一行(50) + 外层 gap(10) → 段 B
        expect(b0.dy - a0.dy, closeTo(60, 0.01));
        // 段 B cellW = (316-4)/2 = 156，列偏移 160
        expect(b1.dx - b0.dx, closeTo(160, 0.01));
        expect(tester.getSize(find.byKey(const ValueKey('b0'))).height, closeTo(80, 0.01));
      });
    });

    group('结构变化', () {
      testWidgets('grid 段 itemCount 增长：滚动总高随之增长，头部位置不动', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        Widget build(int count) {
          return shell(
            child: ElScrollView(
              controller: controller,
              children: [
                buildVirtualGrid(
                  crossAxisCount: 3,
                  itemHeight: 100,
                  gap: 8,
                  itemCount: count,
                  itemBuilder: (_, i) => cell(i),
                ),
              ],
            ),
          );
        }

        await tester.pumpWidget(build(6));
        await tester.pump();
        // 2 行：2*100+8=208 < 400 → 不可滚
        expect(controller.position.maxScrollExtent, 0);
        final c0Before = tester.getTopLeft(cellFinder(0));
        await tester.pumpWidget(build(30));
        await tester.pump();
        // 10 行：10*100+9*8=1072 → max = 672
        expect(controller.position.maxScrollExtent, closeTo(672, 0.5));
        expect(tester.getTopLeft(cellFinder(0)), c0Before);
      });

      testWidgets('grid 段父级无关 rebuild（同构）不炸不漂', (tester) async {
        var tick = 0;
        late StateSetter rebuild;
        await tester.pumpWidget(
          shell(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                tick++;
                return ElScrollView(
                  children: [
                    buildVirtualGrid(
                      crossAxisCount: 3,
                      itemHeight: 100,
                      gap: 8,
                      itemCount: 30,
                      itemBuilder: (_, i) => cell(i),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        final before = tester.getTopLeft(cellFinder(4));
        rebuild(() {});
        await tester.pump();
        expect(tick, 2);
        expect(tester.getTopLeft(cellFinder(4)), before);
      });
    });

    group('误用：builder 脱离虚拟滚动', () {
      testWidgets('未作为 ElScrollView.children 顶层成员时 assert', (tester) async {
        await tester.pumpWidget(
          shell(
            child: SingleChildScrollView(
              child: buildVirtualGrid(
                crossAxisCount: 3,
                itemHeight: 100,
                gap: 8,
                itemCount: 9,
                itemBuilder: (_, i) => cell(i),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isA<AssertionError>());
        expect(cellFinder(0), findsNothing);
      });
    });

    group('纯 list 零回归探针', () {
      testWidgets('无 grid 成员时 children 原实例直通（无 facade 包装）', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final children = [for (var i = 0; i < 20; i++) SizedBox(key: ValueKey('row$i'), height: 30)];
        await tester.pumpWidget(
          shell(
            child: ElScrollView(controller: controller, gap: 0, children: children),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(const ValueKey('row0')), findsOneWidget);
        // 首屏外行仍可能吃估计高；只断言可滚且首行在。
        expect(controller.position.maxScrollExtent, greaterThan(0));
      });
    });
  });

  group('列表构建与窗口', () {
    Finder scrollRenderFinder() => find.byElementPredicate(
      (element) => element is RenderObjectElement && element.renderObject is RenderVirtualScrollView,
    );

    Widget host({required Widget child}) {
      return MaterialApp(
        scrollBehavior: _NoChromeScrollBehavior(),
        home: Align(
          alignment: .topLeft,
          child: SizedBox(width: 200, height: 300, child: child),
        ),
      );
    }

    testWidgets('builder exposes its build context and index', (tester) async {
      final builtContexts = <int, BuildContext>{};

      await tester.pumpWidget(
        host(
          child: buildVirtualTestViewBuilder(
            itemCount: 10,
            itemBuilder: (context, index) {
              builtContexts[index] = context;
              return SizedBox(height: 32, width: 40, child: Text('item-$index'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(builtContexts[0], isNotNull);
      expect(Theme.of(builtContexts[0]!).brightness, Brightness.light);
      // 构建使用真实 ElListView 的 context。
      expect(builtContexts[0]!.widget, isA<ElListView>());
    });

    testWidgets('builder only materializes rows near the window', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final builtIndices = <int>{};

      await tester.pumpWidget(
        host(
          child: buildVirtualTestViewBuilder(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            itemCount: 100000,
            itemBuilder: (_, index) {
              builtIndices.add(index);
              return SizedBox(height: 32, width: 40, child: Text('item-$index'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('item-0'), findsOneWidget);
      // Far tail must never build while the window sits at the top.
      expect(builtIndices.length, lessThan(200));
      expect(builtIndices.where((i) => i > 1000), isEmpty);
    });

    testWidgets('builder scrolls to arbitrary offsets and keeps extents exact', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        host(
          child: buildVirtualTestViewBuilder(
            controller: controller,
            physics: const ClampingScrollPhysics(),
            itemCount: 10000,
            itemBuilder: (_, index) => SizedBox(height: 32, width: 40, child: Text('item-$index')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scroll = tester.renderObject<RenderVirtualScrollView>(scrollRenderFinder());
      expect(scroll.contentSize.height, 10000 * 32);

      controller.jumpTo(160000);
      await tester.pump();
      expect(find.text('item-5000'), findsOneWidget);
      expect(tester.getTopLeft(find.text('item-5000')).dy, 0);
    });

    testWidgets('itemCount growth extends the list without disturbing the anchor', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      Widget build(int itemCount) => host(
        child: buildVirtualTestViewBuilder(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (_, index) => SizedBox(height: 32, width: 40, child: Text('item-$index')),
        ),
      );

      await tester.pumpWidget(build(100));
      await tester.pumpAndSettle();
      controller.jumpTo(320);
      await tester.pump();
      expect(tester.getTopLeft(find.text('item-10')).dy, 0);

      await tester.pumpWidget(build(200));
      await tester.pumpAndSettle();

      // Tail append: the anchored row stays put, and the new tail is reachable.
      expect(tester.getTopLeft(find.text('item-10')).dy, 0);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(find.text('item-199'), findsOneWidget);
    });

    testWidgets('mounted rows rebuild with fresh builder output on parent rebuild', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      Widget build(String tag) => host(
        child: buildVirtualTestViewBuilder(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          itemCount: 100,
          itemBuilder: (_, index) => SizedBox(height: 32, width: 40, child: Text('$tag-$index')),
        ),
      );

      await tester.pumpWidget(build('a'));
      await tester.pumpAndSettle();
      expect(find.text('a-0'), findsOneWidget);

      await tester.pumpWidget(build('b'));
      await tester.pump();
      expect(find.text('b-0'), findsOneWidget);
      expect(find.text('a-0'), findsNothing);
    });
  });

  group('列表构建策略', () {
    testWidgets('空列表不调用业务或分隔构建器，随后加载数据可锁定首条尺寸', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      var builds = 0;
      Widget build(int count) => _host(
        _scroll(
          ElListView.builder(
            itemCount: count,
            fixedSize: true,
            itemBuilder: (_, index) {
              builds++;
              return SizedBox(height: 20);
            },
            separatorBuilder: (_, index) {
              builds++;
              return SizedBox(height: 5);
            },
          ),
          controller: controller,
        ),
      );
      await tester.pumpWidget(build(0));
      await tester.pump();
      expect(builds, 0);
      expect(controller.position.maxScrollExtent, 0);
      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(builds, 1, reason: '单条业务数据不构建分隔项');
      await tester.pumpWidget(build(20));
      await tester.pump();
      expect(builds, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fixedSize 使用真实第零条且只构建一次，远跳仍按首条强制尺寸', (tester) async {
      final firstKey = GlobalKey();
      final controller = ElScrollController(initialScrollOffset: 400);
      addTearDown(controller.dispose);
      final builds = <int, int>{};
      await tester.pumpWidget(
        _host(
          _scroll(
            ElListView.builder(
              itemCount: 10000,
              fixedSize: true,
              itemBuilder: (_, index) {
                builds.update(index, (count) => count + 1, ifAbsent: () => 1);
                return SizedBox(key: index == 0 ? firstKey : ValueKey(index), height: index == 0 ? 20 : 60);
              },
            ),
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      expect(controller.position.maxScrollExtent, 199900);
      expect(builds[0], 1);
      expect(builds.length, lessThan(50));
      expect(tester.getSize(find.byKey(firstKey)).height, 20);
      final done = controller.scrollToIndex(9000);
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(Duration(milliseconds: 16));
      }
      await done;
      expect(controller.offset, closeTo(180000, 0.01));
      expect(tester.getSize(find.byKey(ValueKey(9000))).height, 20);
      expect(builds[0], 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('固定分隔项按业务索引构建并复用首个尺寸，尾部没有多余分隔项', (tester) async {
      await tester.pumpWidget(
        _host(
          _scroll(
            ElListView.builder(
              itemCount: 3,
              fixedSize: true,
              itemBuilder: (_, index) => SizedBox(key: ValueKey('item-$index'), height: index == 0 ? 20 : 60),
              separatorBuilder: (_, index) => SizedBox(key: ValueKey('separator-$index'), height: (index + 1) * 3),
            ),
            shrinkWrap: true,
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getBottomRight(find.byKey(ValueKey('item-2'))).dy - tester.getTopLeft(find.byKey(ValueKey('item-0'))).dy,
        66,
      );
      for (var index = 0; index < 3; index++) {
        expect(tester.getSize(find.byKey(ValueKey('item-$index'))).height, 20);
      }
      expect(tester.getSize(find.byKey(ValueKey('separator-0'))).height, 3);
      expect(tester.getSize(find.byKey(ValueKey('separator-1'))).height, 3);
      expect(find.byKey(ValueKey('separator-2')), findsNothing);
    });

    testWidgets('声明更新重测首条，追加数据继承统一高度，关闭开关恢复自然尺寸', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      Widget build(int count, double height, bool uniform) => _host(
        _scroll(
          ElListView.builder(
            itemCount: count,
            fixedSize: uniform,
            itemBuilder: (_, index) => SizedBox(key: ValueKey(index), height: index == 0 ? height : 60),
          ),
          controller: controller,
        ),
      );
      await tester.pumpWidget(build(100, 20, true));
      await tester.pump();
      expect(controller.position.maxScrollExtent, 1900);
      await tester.pumpWidget(build(120, 30, true));
      await tester.pump();
      expect(controller.position.maxScrollExtent, 3500);
      expect(tester.getSize(find.byKey(ValueKey(1))).height, 30);
      await tester.pumpWidget(build(120, 30, false));
      await tester.pump();
      expect(tester.getSize(find.byKey(ValueKey(1))).height, 60);
    });

    testWidgets('横向 fixedSize 按首条宽度强制布局', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          _scroll(
            ElListView.builder(
              itemCount: 100,
              fixedSize: true,
              itemBuilder: (_, index) => SizedBox(key: ValueKey(index), width: index == 0 ? 25 : 75, height: 20),
            ),
            axis: .horizontal,
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      expect(controller.position.maxScrollExtent, 2300);
      expect(tester.getSize(find.byKey(ValueKey(1))).width, 25);
    });

    testWidgets('宽度变化重测首条的自然换行高度', (tester) async {
      final list = ElListView.builder(
        itemCount: 100,
        fixedSize: true,
        itemBuilder: (_, index) =>
            ElView(key: ValueKey(index), style: ElStyle(fontSize: 10, lineHeight: 1), child: 'abcdefghij'),
      );
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(_scroll(list, controller: controller), width: 50));
      await tester.pump();
      final narrow = tester.getSize(find.byKey(ValueKey(0))).height;
      await tester.pumpWidget(_host(_scroll(list, controller: controller), width: 100));
      await tester.pump();
      expect(tester.getSize(find.byKey(ValueKey(0))).height, lessThan(narrow));
      expect(tester.getSize(find.byKey(ValueKey(1))).height, tester.getSize(find.byKey(ValueKey(0))).height);
    });

    test('分隔列表的 key 回查由业务索引转换为扁平索引', () {
      final declaration = ElListView.builder(
        itemCount: 4,
        itemBuilder: (_, index) => SizedBox(),
        separatorBuilder: (_, index) => SizedBox(),
        findChildIndexCallback: (key) => key == ValueKey('row') ? 2 : null,
      );
      final segment = resolveScrollSegments([declaration], scrollAxis: .vertical).single as LinearSegment;
      final source = segment.source as BuilderItemSource;
      expect(source.itemCount, 7);
      expect(source.findChildIndex!(ValueKey('row')), 4);
      expect(source.findChildIndex!(ValueKey('missing')), isNull);
    });

    testWidgets('分隔列表插入数据后按业务 key 保留原条目的 Element', (tester) async {
      final ids = List.generate(100, (index) => index);
      Widget build() => _host(
        _scroll(
          ElListView.builder(
            itemCount: ids.length,
            fixedSize: true,
            itemBuilder: (_, index) =>
                ElView(key: ValueKey(ids[index]), style: ElStyle(height: 20), child: '${ids[index]}'),
            separatorBuilder: (_, index) => ElView(style: ElStyle(height: 2)),
            findChildIndexCallback: (key) {
              if (key is! ValueKey<int>) return null;
              final index = ids.indexOf(key.value);
              return index < 0 ? null : index;
            },
          ),
        ),
      );
      await tester.pumpWidget(build());
      await tester.pump();
      final before = tester.element(find.byKey(ValueKey(2)));
      ids.insert(0, -1);
      await tester.pumpWidget(build());
      await tester.pump();
      expect(tester.element(find.byKey(ValueKey(2))), same(before));
      expect(tester.getSize(find.byKey(ValueKey(2))).height, 20);
    });

    testWidgets('统一尺寸随 DPR 变化重测并对齐物理像素', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final list = ElListView.builder(
        itemCount: 100,
        fixedSize: true,
        itemBuilder: (_, index) => SizedBox(key: ValueKey(index), height: 20.2),
      );
      await tester.pumpWidget(_host(_scroll(list)));
      await tester.pump();
      expect(tester.getSize(find.byKey(ValueKey(1))).height, 21);
      tester.view.devicePixelRatio = 1.75;
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(find.byKey(ValueKey(1))).height, closeTo((20.2 * 1.75).ceil() / 1.75, 0.001));
    });

    testWidgets('正文与配置可以混排，非法配置对象在解析阶段明确报错', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          ElScrollView(
            controller: controller,
            cacheExtent: 0,
            scrollbar: ElNoScrollBar(),
            children: [
              ElView(style: ElStyle(height: 30)),
              ElListView.builder(
                itemCount: 100,
                fixedSize: true,
                itemBuilder: (_, index) => ElView(style: ElStyle(height: 20)),
              ),
              ElView(style: ElStyle(height: 40)),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(controller.position.maxScrollExtent, 1970);
      expect(resolveScrollSegments([ElView()], scrollAxis: .vertical).single, isA<StaticSegment>());
    });

    testWidgets('文本缩放改变时复用配置也会重测真实首条', (tester) async {
      final scroll = _scroll(
        ElListView.builder(
          itemCount: 100,
          fixedSize: true,
          itemBuilder: (_, index) => Builder(
            key: ValueKey(index),
            builder: (context) => ElView(style: ElStyle(height: MediaQuery.textScalerOf(context).scale(20))),
          ),
        ),
      );
      Widget build(double scale) => _host(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: scroll,
        ),
      );
      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(tester.getSize(find.byKey(ValueKey(1))).height, 20);
      await tester.pumpWidget(build(2));
      await tester.pump();
      expect(tester.getSize(find.byKey(ValueKey(1))).height, 40);
    });

    testWidgets('首条自然尺寸为零时不回退估高或制造滚动范围', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          _scroll(
            ElListView.builder(
              itemCount: 1000,
              fixedSize: true,
              itemBuilder: (_, index) => ElView(style: ElStyle(height: index == 0 ? 0 : 20)),
            ),
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      expect(controller.position.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('首条尺寸索引', () {
    test('多个 prototype 范围共享一次更新且保留其他行', () {
      final index = VirtualExtentIndex(count: 6, estimatedExtent: 10);
      index.updateMeasuredExtent(0, 5);
      final delta = index.updateMeasuredRanges([(start: 1, end: 3, extent: 20.0), (start: 4, end: 6, extent: 30.0)]);
      expect(delta, 60);
      expect(index.totalExtent, 115);
      expect(index.measuredCount, 5);
      expect(index.extentOf(0), 5);
      expect(index.extentOf(3), 10);
      expect(index.isMeasured(3), isFalse);
      expect(index.offsetOf(5), 85);
      expect(index.indexAt(85), 5);
      expect(index.updateMeasuredRange(1, 3, 20), 0);
      expect(index.totalExtent, 115);
    });

    test('非均匀估计模型也能批量锁定并保留准确前缀', () {
      final index = VirtualExtentIndex(count: 4, estimatedExtent: 10, extentBuilder: (i) => (i + 1).toDouble());
      expect(index.totalExtent, 10);
      expect(index.updateMeasuredRange(1, 3, 5), 5);
      expect(index.totalExtent, 15);
      expect(index.offsetOf(3), 11);
      expect(index.measuredCount, 2);
      expect(index.measuredExtentAverage, 5);
    });

    test('后续范围非法时整个批次不改变数组或 Fenwick 聚合', () {
      final index = VirtualExtentIndex(count: 4, estimatedExtent: 10);
      expect(
        () => index.updateMeasuredRanges([(start: 0, end: 2, extent: 50.0), (start: 3, end: 5, extent: 20.0)]),
        throwsRangeError,
      );
      expect(index.totalExtent, 40);
      expect(index.measuredCount, 0);
      for (var i = 0; i < 4; i++) {
        expect(index.extentOf(i), 10);
        expect(index.offsetOf(i), i * 10);
        expect(index.isMeasured(i), isFalse);
      }
    });

    test('重叠范围后写覆盖，空范围和非法尺寸不污染模型', () {
      final index = VirtualExtentIndex(count: 4, estimatedExtent: 10);
      expect(
        index.updateMeasuredRanges([
          (start: 0, end: 2, extent: 20.0),
          (start: 1, end: 3, extent: 30.0),
          (start: 3, end: 3, extent: 90.0),
          (start: 3, end: 4, extent: double.nan),
        ]),
        50,
      );
      expect(index.totalExtent, 90);
      expect(index.measuredCount, 3);
      expect(index.offsetOf(3), 80);
      expect(index.extentOf(3), 10);
    });
  });

  group('行尺寸重新测量', () {
    testWidgets('虚拟段单行标脏：重排收敛到脏行自身（≤2），不击穿全窗', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _shell(
          controller: controller,
          children: [
            ElListView.builder(itemCount: 2000, itemBuilder: (context, i) => const _LayoutProbe(height: 50.3)),
          ],
        ),
      );
      await tester.pump();
      controller.jumpTo(1000);
      await tester.pump();
      await tester.pump();

      final probes = tester.renderObjectList<_RenderLayoutProbe>(find.byType(_LayoutProbe)).toList();
      expect(probes.length, greaterThan(5), reason: '前置：窗口内应有多行挂载');
      final before = _LayoutProbe.layoutCount;
      probes[probes.length ~/ 2].markNeedsLayout();
      await tester.pump();
      final relayouts = _LayoutProbe.layoutCount - before;
      expect(relayouts, greaterThanOrEqualTo(1), reason: '脏行自身必须重排');
      expect(relayouts, lessThanOrEqualTo(2), reason: '单行标脏不得击穿其余挂载行（旧实现 = 挂载数×2）');
    });

    testWidgets('全常驻单行标脏：重排收敛到脏行自身，不拖全列表', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _shell(controller: controller, children: [for (var i = 0; i < 60; i++) const _LayoutProbe(height: 50.3)]),
      );
      await tester.pump();
      controller.jumpTo(500);
      await tester.pump();

      final probes = tester.renderObjectList<_RenderLayoutProbe>(find.byType(_LayoutProbe)).toList();
      expect(probes.length, 60, reason: '前置：常驻集全部挂载');
      final before = _LayoutProbe.layoutCount;
      probes[30].markNeedsLayout();
      await tester.pump();
      final relayouts = _LayoutProbe.layoutCount - before;
      expect(relayouts, greaterThanOrEqualTo(1));
      expect(relayouts, lessThanOrEqualTo(2), reason: '常驻集无窗口上界，旧实现全量×2 击穿在此最重');
    });

    testWidgets('稳态滚动：已挂载 clean 行零重排（每帧真实重排 ≤ 新挂载行）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _shell(
          controller: controller,
          children: [
            ElListView.builder(itemCount: 2000, itemBuilder: (context, i) => const _LayoutProbe(height: 50.3)),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      // 预热一帧（首窗探测完成），再统计稳态平移。
      controller.jumpTo(40);
      await tester.pump();

      for (var i = 0; i < 20; i++) {
        final before = _LayoutProbe.layoutCount;
        controller.jumpTo(controller.offset + 40);
        await tester.pump();
        final delta = _LayoutProbe.layoutCount - before;
        // 每帧平移 40px < 行高 → 至多 1 行新进窗口，首测双 layout 上界 2；
        // 已挂载 clean 行必须早退（>2 = 缓存被击穿）。
        expect(delta, lessThanOrEqualTo(2), reason: '第 $i 帧：稳态平移只付新挂载行成本');
      }
    });

    testWidgets('变矮防钳死：行内容变矮后 size 收缩、后继行位置上移', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const tallKey = ValueKey('shrink-row');
      var height = 90.3;
      late StateSetter setRowHeight;
      await tester.pumpWidget(
        _shell(
          controller: controller,
          children: [
            const _LayoutProbe(height: 50.3),
            StatefulBuilder(
              builder: (context, setState) {
                setRowHeight = setState;
                return _LayoutProbe(key: tallKey, height: height);
              },
            ),
            const _LayoutProbe(height: 50.3),
          ],
        ),
      );
      await tester.pump();

      final row = tester.renderObject<_RenderLayoutProbe>(find.byKey(tallKey));
      expect(row.size.height, greaterThanOrEqualTo(90.3), reason: '前置：初始高度（网格 ceil 后 ≥ 自然高）');

      setRowHeight(() => height = 30.3);
      await tester.pump();
      // 行级重探必须察觉变矮——gridExtent 下界若不被重探会把行钳在旧高。
      expect(row.size.height, lessThan(31.0), reason: '变矮的行必须收缩（下界钳死 = 重探回归）');
      final thirdTop = tester
          .renderObjectList<_RenderLayoutProbe>(find.byType(_LayoutProbe))
          .toList()[2]
          .localToGlobal(Offset.zero)
          .dy;
      expect(thirdTop, lessThan(90.3 + 50.4), reason: '后继行随收缩上移');
    });

    testWidgets('变高照常生效：行内容变高后 size 变大、后继行位置下移', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const growKey = ValueKey('grow-row');
      var height = 30.3;
      late StateSetter setRowHeight;
      await tester.pumpWidget(
        _shell(
          controller: controller,
          children: [
            const _LayoutProbe(height: 50.3),
            StatefulBuilder(
              builder: (context, setState) {
                setRowHeight = setState;
                return _LayoutProbe(key: growKey, height: height);
              },
            ),
            const _LayoutProbe(height: 50.3),
          ],
        ),
      );
      await tester.pump();

      final row = tester.renderObject<_RenderLayoutProbe>(find.byKey(growKey));
      expect(row.size.height, lessThan(31.0));

      setRowHeight(() => height = 90.3);
      await tester.pump();
      expect(row.size.height, greaterThanOrEqualTo(90.3), reason: '变高的行必须长开');
    });

    testWidgets('交叉轴约束变化：全量重探仍生效（视口宽变化行高全失效）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget build(double width) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 600,
            child: ElScrollView(
              controller: controller,
              physics: const ClampingScrollPhysics(),
              children: [
                ElListView.builder(itemCount: 100, itemBuilder: (context, i) => const _LayoutProbe(height: 50.3)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(400));
      await tester.pump();
      final probesBefore = tester.renderObjectList<_RenderLayoutProbe>(find.byType(_LayoutProbe)).length;

      final before = _LayoutProbe.layoutCount;
      await tester.pumpWidget(build(300));
      final relayouts = _LayoutProbe.layoutCount - before;
      // 宽变了所有行的交叉轴约束变化，Flutter 硬约束不等 → 全部真实重排。
      expect(relayouts, greaterThanOrEqualTo(probesBefore), reason: '交叉轴变化必须全量重探（行级标记不接管这条路）');
    });
  });

  group('统一尺寸可见边界', () {
    testWidgets('等高行：pixels 恰落行边界时可见窗口与落位数组一致', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      // 可视行窗口经 onVisibleRangeChanged 读取（post-frame 合并派发）：统一管线
      // 下 viewport render 单 content 子，基座 children 序数探针不再承载行窗口。
      ElVisibleRange? range;
      await tester.pumpWidget(
        _uniformVisibleRangeBoundaryShell(
          controller: controller,
          rowExtent: 100.0,
          rowCount: 40,
          onVisibleRangeChanged: (r) => range = r,
        ),
      );

      controller.jumpTo(200.0);
      await tester.pump();
      await tester.pump();

      // 视口 200 / 行高 100，pixels=200 → 恰好第 2 行顶边；窗口应为 [2, 4)。
      expect(range, isNotNull);
      expect(range!.mountedFirst, 2);
      expect(range!.mountedLast, 4);
    });

    testWidgets('浮点噪声行高：可见窗口跟随落位数组而非解析式（无 ±1 漂移）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      // 100/3 行高：累加出来的落位数组与 stride × index 的解析式在整数 pixels
      // 处分岔，起点少一行（少画）或终点少一行（尾部露白）两种形状都能复现。
      ElVisibleRange? range;
      await tester.pumpWidget(
        _uniformVisibleRangeBoundaryShell(
          controller: controller,
          rowExtent: 100.0 / 3.0,
          rowCount: 400,
          onVisibleRangeChanged: (r) => range = r,
        ),
      );

      // 解析式给 start=2（多算一行），落位数组的真值是 3。
      controller.jumpTo(100.0);
      await tester.pump();
      await tester.pump();
      expect(range!.mountedFirst, 3);

      // vEnd=400 恰落行 12 顶边（±浮点渣）：落位二分带容差吸渣，恰边界行
      // （露出 0 物理像素）不挂——半开语义与等高用例一致，无视觉露白；
      // 守卫要点是窗口值与落位判据恒一致（无 ±1 随机漂移），非旧实现
      // 浮点累加巧合下的 13。
      controller.jumpTo(200.0);
      await tester.pump();
      await tester.pump();
      expect(range!.mountedLast, 12);
    });
  });

  group('布局段差异', () {
    Widget box([Key? key]) => SizedBox(key: key);

    LinearSegment builderLinear(int count) => LinearSegment(
      source: BuilderItemSource(itemCount: count, builder: (context, index) => box()),
    );

    GridSegment builderGrid(int count, {int columns = 3}) => GridSegment(
      source: BuilderItemSource(itemCount: count, builder: (context, index) => box()),
      geometry: GridLayoutGeometry(crossAxisCount: columns, mainAxisExtent: 40),
    );

    SegmentPlan plan(List<SegmentSpec> segments) => SegmentPlan(segments, outerGap: 8, crossAxisExtent: 300);

    SegmentPlanTransition transition(List<SegmentSpec> oldSegments, List<SegmentSpec> newSegments) {
      return SegmentPlanTransition.compute(
        oldPlan: plan(oldSegments),
        newPlan: plan(newSegments),
        diff: SegmentListDiff.compute(oldSegments, newSegments),
      );
    }

    group('无变化快路径', () {
      test('builder 段 count 不变 → Unchanged（builder 闭包身份不入判定）', () {
        final oldSegments = [StaticSegment(box()), builderLinear(100)];
        final newSegments = [StaticSegment(box()), builderLinear(100)];
        final diff = SegmentListDiff.compute(oldSegments, newSegments);
        expect(diff.anyChange, isFalse);
        expect(transition(oldSegments, newSegments).isEmpty, isTrue);
      });

      test('uniform 身份不变且 count 不变 → Unchanged', () {
        final oldSegments = [
          LinearSegment(
            source: BuilderItemSource(itemCount: 5, builder: (context, index) => box()),
            key: ValueKey('uniform'),
            fixed: FixedSizeSpec()..extent = 24,
          ),
        ];
        final newSegments = [
          LinearSegment(
            source: BuilderItemSource(itemCount: 5, builder: (context, index) => box()),
            key: ValueKey('uniform'),
            fixed: FixedSizeSpec()..extent = 32,
          ),
        ];
        expect(SegmentListDiff.compute(oldSegments, newSegments).anyChange, isFalse);
      });
    });

    group('linear 段内 splice（度量保留的招牌场景）', () {
      test('分页 append（builder 100→120）：尾部 splice，前缀行不动', () {
        final oldSegments = [StaticSegment(box()), builderLinear(100)];
        final newSegments = [StaticSegment(box()), builderLinear(120)];
        final result = transition(oldSegments, newSegments);
        expect(result.rowSplices, hasLength(1));
        final splice = result.rowSplices.single;
        expect(splice.rowStart, 101, reason: 'static 1 行 + 段内 localStart 100');
        expect(splice.deleteRows, 0);
        expect(splice.insertRows, 20);
        expect(result.itemSplices.single.itemStart, 101);
      });

      test('物化 children 中部纯插入：splice 无 keyed map', () {
        final a = box(const ValueKey('a'));
        final b = box(const ValueKey('b'));
        final oldSegments = [
          LinearSegment(source: MaterializedItemSource([a, b])),
        ];
        final newSegments = [
          LinearSegment(source: MaterializedItemSource([a, box(const ValueKey('x')), b])),
        ];
        final diff = SegmentListDiff.compute(oldSegments, newSegments);
        final change = diff.pairings.single.change! as SegmentItemsSpliced;
        expect(change.localStart, 1);
        expect(change.deleteCount, 0);
        expect(change.insertCount, 1);
        expect(change.oldLocalForNewLocal, isNull);
      });

      test('keyed 全重排：oldLocalForNewLocal 双射 + 全局行号平移', () {
        final a = box(const ValueKey('a'));
        final b = box(const ValueKey('b'));
        final c = box(const ValueKey('c'));
        final oldSegments = [
          StaticSegment(box()),
          LinearSegment(source: MaterializedItemSource([a, b, c])),
        ];
        final newSegments = [
          StaticSegment(box()),
          LinearSegment(source: MaterializedItemSource([c, a, b])),
        ];
        final result = transition(oldSegments, newSegments);
        final splice = result.rowSplices.single;
        expect(splice.rowStart, 1);
        expect(splice.deleteRows, 3);
        expect(splice.insertRows, 3);
        expect(splice.oldRowForNewRow, {1: 3, 2: 1, 3: 2}, reason: '段行偏移 1 后的 new→old 全局行映射');
      });

      test('改动窗口含无 key 成员：放弃 keyed map 走普通 splice', () {
        final a = box(const ValueKey('a'));
        final oldSegments = [
          LinearSegment(source: MaterializedItemSource([a, box()])),
        ];
        final newSegments = [
          LinearSegment(source: MaterializedItemSource([box(), a])),
        ];
        final diff = SegmentListDiff.compute(oldSegments, newSegments);
        final change = diff.pairings.single.change! as SegmentItemsSpliced;
        expect(change.oldLocalForNewLocal, isNull);
      });

      test('物化 ↔ builder 形态切换（count 相等）：index 即身份，视为无结构变化', () {
        final oldSegments = [
          LinearSegment(source: MaterializedItemSource([box(), box()])),
        ];
        final newSegments = [builderLinear(2)];
        expect(SegmentListDiff.compute(oldSegments, newSegments).anyChange, isFalse);
      });

      test('fixedSize 开关变化 → 段重建（行高模型变了）', () {
        final oldSegments = [
          LinearSegment(
            source: BuilderItemSource(itemCount: 5, builder: (c, i) => box()),
            fixed: FixedSizeSpec(),
          ),
        ];
        final newSegments = [
          LinearSegment(source: BuilderItemSource(itemCount: 5, builder: (c, i) => box()), fixed: null),
        ];
        final diff = SegmentListDiff.compute(oldSegments, newSegments);
        expect(diff.pairings.single.change, isA<SegmentRebuilt>());
      });

      test('uniform key 变化 → 段重建', () {
        final oldSegments = [
          LinearSegment(
            source: BuilderItemSource(itemCount: 5, builder: (c, i) => box()),
            key: ValueKey('old'),
            fixed: FixedSizeSpec(),
          ),
        ];
        final newSegments = [
          LinearSegment(
            source: BuilderItemSource(itemCount: 5, builder: (c, i) => box()),
            key: ValueKey('new'),
            fixed: FixedSizeSpec(),
          ),
        ];
        final diff = SegmentListDiff.compute(oldSegments, newSegments);
        expect(diff.anyChange, isTrue);
      });
    });

    group('grid 段', () {
      test('尾部 append：首个受影响行起整段行替换、前缀行保留', () {
        final oldSegments = [builderGrid(20)];
        final newSegments = [builderGrid(26)];
        final result = transition(oldSegments, newSegments);
        final splice = result.rowSplices.single;
        expect(splice.rowStart, 6, reason: 'localStart 20 ~/ 3 列');
        expect(splice.deleteRows, 1, reason: '旧 7 行 − 前 6 行');
        expect(splice.insertRows, 3, reason: '新 9 行 − 前 6 行');
        expect(result.itemSplices.single, isA<ItemSplice>());
        expect(result.itemSplices.single.itemStart, 20);
      });

      test('中部变化 → 段重建（列相位平移不可保）', () {
        final a = box(const ValueKey('a'));
        final c = box(const ValueKey('c'));
        final d = box(const ValueKey('d'));
        final oldSegments = [
          GridSegment(
            source: MaterializedItemSource([a, box(const ValueKey('b')), c, d]),
            geometry: GridLayoutGeometry(crossAxisCount: 2, mainAxisExtent: 40),
          ),
        ];
        final newSegments = [
          GridSegment(
            source: MaterializedItemSource([a, box(const ValueKey('x')), c, d]),
            geometry: GridLayoutGeometry(crossAxisCount: 2, mainAxisExtent: 40),
          ),
        ];
        final diff = SegmentListDiff.compute(oldSegments, newSegments);
        expect(diff.pairings.single.change, isA<SegmentRebuilt>());
      });

      test('几何变化（列数 3→4）→ 段重建', () {
        final oldSegments = [builderGrid(12, columns: 3)];
        final newSegments = [builderGrid(12, columns: 4)];
        final diff = SegmentListDiff.compute(oldSegments, newSegments);
        expect(diff.pairings.single.change, isA<SegmentRebuilt>());
        final result = transition(oldSegments, newSegments);
        expect(result.rowSplices.single.deleteRows, 4);
        expect(result.rowSplices.single.insertRows, 3);
      });
    });

    group('段级增删与 static 段', () {
      test('中部插入新段：插入点 = 前段行尾', () {
        final headA = box(const ValueKey('a'));
        final tailB = box(const ValueKey('b'));
        final oldSegments = [StaticSegment(headA), StaticSegment(tailB)];
        final newSegments = [StaticSegment(headA), builderLinear(10), StaticSegment(tailB)];
        final result = transition(oldSegments, newSegments);
        final splice = result.rowSplices.single;
        expect(splice.rowStart, 1);
        expect(splice.deleteRows, 0);
        expect(splice.insertRows, 10);
      });

      test('移除段：整段行删除', () {
        final headA = box(const ValueKey('a'));
        final tailB = box(const ValueKey('b'));
        final oldSegments = [StaticSegment(headA), builderLinear(10), StaticSegment(tailB)];
        final newSegments = [StaticSegment(headA), StaticSegment(tailB)];
        final result = transition(oldSegments, newSegments);
        final splice = result.rowSplices.single;
        expect(splice.rowStart, 1);
        expect(splice.deleteRows, 10);
        expect(splice.insertRows, 0);
      });

      test('static 成员换身份 → 单行重建', () {
        final oldSegments = [StaticSegment(box(const ValueKey('a'))), builderLinear(5)];
        final newSegments = [StaticSegment(box(const ValueKey('b'))), builderLinear(5)];
        final result = transition(oldSegments, newSegments);
        final splice = result.rowSplices.single;
        expect(splice.rowStart, 0);
        expect(splice.deleteRows, 1);
        expect(splice.insertRows, 1);
      });

      test('多段同时变化：splice 序列按 old 坐标升序', () {
        final oldSegments = [builderLinear(10), StaticSegment(box(const ValueKey('s'))), builderLinear(20)];
        final newSegments = [builderLinear(12), StaticSegment(box(const ValueKey('s'))), builderLinear(25)];
        final result = transition(oldSegments, newSegments);
        expect(result.rowSplices, hasLength(2));
        expect(result.rowSplices[0].rowStart, 10);
        expect(result.rowSplices[0].insertRows, 2);
        expect(result.rowSplices[1].rowStart, 31, reason: '10 + 1 + 段内 localStart 20');
        expect(result.rowSplices[1].insertRows, 5);
        expect(result.rowSplices[0].rowStart < result.rowSplices[1].rowStart, isTrue);
      });
    });
  });

  group('布局段尺寸索引', () {
    test('百万级固定列表与网格只存段参数，首测即可确定完整范围', () {
      final index = _index([
        ElListView.builder(
          itemCount: 1000000,
          fixedSize: true,
          itemBuilder: (_, _) => ElView(),
          separatorBuilder: (_, _) => ElView(),
        ),
        ElGridView.builder(
          itemCount: 1000000,
          crossAxisCount: 3,
          mainAxisExtent: 40,
          gap: 2,
          itemBuilder: (_, _) => ElView(),
        ),
      ], gap: 8);
      final before = index.debugStorageSlotCount;
      index.updateFixedSizes(0, itemExtent: 20, separatorExtent: 3);
      expect(index.totalExtent, 1000000 * 20 + 999999 * 3 + 333334 * 40);
      expect(index.debugStorageSlotCount, before);
      expect(before, lessThan(20));
      expect(index.measuredCount, index.count);
      expect(index.offsetOf(1999999), 22999997);
      expect(index.extentOf(index.count - 1), 40);
    });

    test('混合段索引与逐行参考在随机尺寸、零尺寸、间距边界一致', () {
      final random = math.Random(9327);
      for (var turn = 0; turn < 40; turn++) {
        final item = random.nextInt(10).toDouble();
        final separator = random.nextInt(6).toDouble();
        final innerGap = random.nextInt(4).toDouble();
        final outerGap = random.nextInt(4).toDouble();
        final fixedCount = random.nextInt(20) + 1;
        final variableCount = random.nextInt(12);
        final gridCount = random.nextInt(20);
        final index = _index([
          ElListView.builder(
            itemCount: fixedCount,
            fixedSize: true,
            itemBuilder: (_, _) => ElView(),
            separatorBuilder: (_, _) => ElView(),
          ),
          ElListView.builder(itemCount: variableCount, gap: innerGap, itemBuilder: (_, _) => ElView()),
          ElGridView.builder(
            itemCount: gridCount,
            crossAxisCount: 3,
            mainAxisExtent: 4,
            rowGap: innerGap,
            itemBuilder: (_, _) => ElView(),
          ),
        ], gap: outerGap);
        index.updateFixedSizes(0, itemExtent: item, separatorExtent: separator);
        final start = fixedCount * 2 - 1;
        for (var row = 0; row < variableCount; row++) {
          index.updateMeasuredExtent(start + row, random.nextInt(12).toDouble());
        }
        final reference = VirtualExtentIndex(count: index.count, estimatedExtent: 32, extentBuilder: index.extentOf);
        expect(index.totalExtent, reference.totalExtent);
        for (var gap = 0.0; gap < 3; gap++) {
          for (var position = -1.0; position < index.totalExtent + index.count * gap + 1; position += .5) {
            expect(
              index.indexAt(position, gap: gap),
              reference.indexAt(position, gap: gap),
              reason: 'strict turn=$turn position=$position gap=$gap',
            );
            expect(
              index.firstIndexWithStartAtOrAfter(position, gap: gap),
              reference.firstIndexWithStartAtOrAfter(position, gap: gap),
              reason: 'start turn=$turn position=$position gap=$gap',
            );
          }
        }
        final plan = index.plan;
        final total = index.totalExtent + plan.totalSpacing();
        for (var position = -1.0; position <= total + 1; position += .5) {
          var expected = index.count;
          var expectedStart = index.count;
          for (var row = 0; row < index.count; row++) {
            final rowStart = reference.offsetOf(row) + plan.cumulativeSpacingBeforeRow(row);
            if (expected == index.count && rowStart + index.extentOf(row) > position + 1e-10) expected = row;
            if (expectedStart == index.count && rowStart >= position - 1e-10) expectedStart = row;
          }
          if (position < 0) expected = 0;
          if (position <= 0) expectedStart = 0;
          if (position >= total) {
            expected = index.count;
            expectedStart = index.count;
          }
          expect(index.rowAtContentOffset(position), expected, reason: 'layout end turn=$turn at=$position');
          expect(
            index.rowAtContentOffset(position, startAtOrAfter: true),
            expectedStart,
            reason: 'layout start turn=$turn at=$position',
          );
        }
      }
    });

    test('网格改变列数与多个段同时追加，列表实测保留且固定段不展开', () {
      List<Widget> sections(int count, int columns) => [
        ElListView.builder(key: ValueKey('fixed'), itemCount: count, fixedSize: true, itemBuilder: (_, _) => ElView()),
        ElListView.builder(key: ValueKey('variable'), itemCount: count, itemBuilder: (_, _) => ElView()),
        ElGridView.builder(
          key: ValueKey('grid'),
          itemCount: count,
          crossAxisCount: columns,
          mainAxisExtent: 20,
          itemBuilder: (_, _) => ElView(),
        ),
      ];
      final old = _index(sections(100, 2));
      old.updateFixedSizes(0, itemExtent: 12);
      old.updateMeasuredExtent(102, 48);
      final newPlan = _index(sections(120, 3)).plan;
      final next = old.reconfigured(newPlan);
      expect(next.extentOf(122), 48);
      expect(next.isMeasured(122), isTrue);
      expect(next.count, 280);
      expect(next.extentOf(279), 20);
      expect(next.debugStorageSlotCount, lessThan(500));
    });
  });

  group('布局段集成', () {
    Widget shell(Widget child, {double width = 400, double height = 600}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      );
    }

    testWidgets('统一尺寸列表 首帧建立精确 extent 模型', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            children: [
              ElListView.builder(
                itemBuilder: (context, index) => SizedBox(key: ValueKey('fixed-$index'), height: 48),
                itemCount: 500,
                fixedSize: true,
              ),
            ],
          ),
        ),
      );

      expect(controller.position.maxScrollExtent, 24000 - 600);
      expect(find.byKey(const ValueKey('fixed-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('fixed-400'), skipOffstage: false), findsNothing);
    });

    testWidgets('普通 child、ElListView 与尾 child 混排时几何和常驻语义正确', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            gap: 20,
            cacheExtent: 0,
            children: [
              const SizedBox(key: ValueKey('head'), height: 100),
              ElListView.builder(
                itemCount: 200,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('row-$index'), height: 40),
              ),
              const SizedBox(key: ValueKey('tail'), height: 80),
            ],
          ),
        ),
      );
      await tester.pump();

      for (var index = 0; index < 24; index++) {
        controller.jumpTo((controller.offset + 400).clamp(0, controller.position.maxScrollExtent));
        await tester.pump();
        await tester.pump();
      }
      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();

      expect(controller.position.maxScrollExtent, closeTo(7620, 1e-6));
      expect(tester.getTopLeft(find.byKey(const ValueKey('head'))).dy, 0);
      expect(tester.getTopLeft(find.byKey(const ValueKey('row-0'))).dy, 120);
      expect(find.byKey(const ValueKey('tail'), skipOffstage: false), findsOneWidget);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const ValueKey('tail'))).dy, closeTo(520, 1e-6));
    });

    testWidgets('两个 ElListView 跨普通 child 混排时段边界坐标正确', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            cacheExtent: 0,
            children: [
              ElListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('a-$index'), height: 30),
              ),
              const SizedBox(key: ValueKey('mid'), height: 50),
              ElListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('b-$index'), height: 30),
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      for (var index = 0; index < 18; index++) {
        controller.jumpTo((controller.offset + 400).clamp(0, controller.position.maxScrollExtent));
        await tester.pump();
        await tester.pump();
      }

      expect(controller.position.maxScrollExtent, closeTo(5450, 1e-6));
      controller.jumpTo(2700);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('a-99')), findsOneWidget);
      expect(find.byKey(const ValueKey('mid')), findsOneWidget);
      expect(find.byKey(const ValueKey('b-0')), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const ValueKey('mid'))).dy, closeTo(300, 1e-6));
      expect(tester.getTopLeft(find.byKey(const ValueKey('b-0'))).dy, closeTo(350, 1e-6));
    });

    testWidgets('变高 ElListView 全量实测后 maxScrollExtent 收敛到真实总高', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      double extentOf(int index) => switch (index % 3) {
        0 => 20,
        1 => 40,
        _ => 60,
      };

      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            cacheExtent: 0,
            children: [
              ElListView.builder(
                itemCount: 90,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('measure-$index'), height: extentOf(index)),
              ),
            ],
          ),
        ),
      );

      for (var index = 0; index < 12; index++) {
        controller.jumpTo((controller.offset + 400).clamp(0, controller.position.maxScrollExtent));
        await tester.pump();
        await tester.pump();
      }

      expect(controller.position.maxScrollExtent, 3000);
    });

    testWidgets('ElListView 尾部 append 保持当前 offset 与可视锚点', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      Widget page(int count) => shell(
        ElScrollView(
          controller: controller,
          cacheExtent: 0,
          children: [
            ElListView.builder(
              itemCount: count,
              itemBuilder: (context, index) => SizedBox(key: ValueKey('page-$index'), height: 30 + (index % 5) * 10),
            ),
          ],
        ),
      );

      await tester.pumpWidget(page(100));
      controller.jumpTo(1200);
      await tester.pump();
      await tester.pump();
      final offsetBefore = controller.offset;
      final visibleIndexBefore = _firstVisibleIndex(tester);
      final topBefore = tester.getTopLeft(find.byKey(ValueKey('page-$visibleIndexBefore')));

      await tester.pumpWidget(page(120));
      await tester.pump();

      final visibleIndexAfter = _firstVisibleIndex(tester);
      expect(controller.offset, offsetBefore);
      expect(visibleIndexAfter, visibleIndexBefore);
      expect(tester.getTopLeft(find.byKey(ValueKey('page-$visibleIndexAfter'))), topBefore);
    });

    testWidgets('cacheExtent 只预挂载缓存窗口内的 Sliver item', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            cacheExtent: 200,
            children: [
              ElListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('cache-$index'), height: 40),
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(const ValueKey('cache-19'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('cache-25'), skipOffstage: false), findsNothing);
    });
  });

  group('布局段几何计划', () {
    Widget box() => const SizedBox();

    SegmentPlan buildMixedPlan() {
      return SegmentPlan(
        [
          StaticSegment(box()),
          LinearSegment(source: BuilderItemSource(itemCount: 100, builder: (context, index) => box())),
          GridSegment(
            source: BuilderItemSource(itemCount: 10, builder: (context, index) => box()),
            geometry: GridLayoutGeometry(crossAxisCount: 3, rowGap: 6, columnGap: 10, mainAxisExtent: 40),
          ),
          StaticSegment(box()),
        ],
        outerGap: 8,
        crossAxisExtent: 300,
      );
    }

    group('行/item 结构', () {
      test('纯 static 计划：恒等映射 + isAllStatic', () {
        final plan = SegmentPlan([StaticSegment(box()), StaticSegment(box())], outerGap: 8, crossAxisExtent: 300);
        expect(plan.isAllStatic, isTrue);
        expect(plan.totalItemCount, 2);
        expect(plan.totalRowCount, 2);
        expect(plan.rowOfItem(1), 1);
        expect(plan.columnOfItem(1), 0);
        expect(plan.firstItemOfRow(1), 1);
        expect(plan.itemsInRow(1), 1);
        expect(plan.fixedExtentOfRow(0), isNull);
        expect(plan.cellCrossGeometry(1), (cross: 0.0, extent: 300.0));
      });

      test('混排前缀数组与总量', () {
        final plan = buildMixedPlan();
        expect(plan.isAllStatic, isFalse);
        expect(plan.totalItemCount, 112);
        expect(plan.totalRowCount, 106, reason: '1 + 100 + ceil(10/3) + 1');
        expect(plan.itemStartOf(2), 101);
        expect(plan.rowStartOf(2), 101);
        expect(plan.rowCountOf(2), 4);
        expect(plan.columnsOf(2), 3);
      });

      test('item ↔ 行 ↔ 列换算（grid 折行与末行不满列）', () {
        final plan = buildMixedPlan();
        expect(plan.rowOfItem(0), 0);
        expect(plan.rowOfItem(100), 100);
        expect(plan.rowOfItem(101), 101, reason: 'grid item0 → grid 首行');
        expect(plan.rowOfItem(104), 102, reason: 'grid item3 → 第二行');
        expect(plan.columnOfItem(105), 1, reason: 'grid item4 → 第二行列 1');
        expect(plan.firstItemOfRow(103), 107, reason: 'grid 第三行首 item = 101 + 2*3');
        expect(plan.itemsInRow(104), 1, reason: '10 item 3 列末行只剩 1 个');
        expect(plan.rowOfItem(111), 105, reason: '尾 static');
      });

      test('固定行高：linear 实测 null、grid mainAxisExtent 直取', () {
        final plan = buildMixedPlan();
        expect(plan.fixedExtentOfRow(50), isNull);
        expect(plan.fixedExtentOfRow(102), 40);
        expect(plan.fixedExtentOfRow(105), isNull);
      });

      test('fixedSize 段的固定行高', () {
        final plan = SegmentPlan(
          [
            LinearSegment(
              geometry: ListLayoutGeometry(gap: 8),
              source: BuilderItemSource(itemCount: 5, builder: (context, index) => box()),
              fixed: FixedSizeSpec()..extent = 24,
            ),
          ],
          outerGap: 0,
          crossAxisExtent: 300,
        );
        expect(plan.fixedExtentOfRow(3), 24);
      });

      test('uniform 段首测前无固定行高，首测后整段共享', () {
        final uniform = FixedSizeSpec();
        final plan = SegmentPlan(
          [
            LinearSegment(
              geometry: ListLayoutGeometry(gap: 8),
              source: BuilderItemSource(itemCount: 5, builder: (context, index) => box()),
              fixed: uniform,
            ),
          ],
          outerGap: 0,
          crossAxisExtent: 300,
        );
        expect(plan.fixedExtentOfRow(3), isNull);
        uniform.extent = 30;
        expect(plan.fixedExtentOfRow(3), 30);
      });

      test('grid aspectRatio 派生行高与 maxCrossAxisExtent 自动列数', () {
        final plan = SegmentPlan(
          [
            GridSegment(
              source: BuilderItemSource(itemCount: 8, builder: (context, index) => box()),
              geometry: GridLayoutGeometry(crossAxisCount: 3, columnGap: 10, aspectRatio: 2),
            ),
            GridSegment(
              source: BuilderItemSource(itemCount: 8, builder: (context, index) => box()),
              geometry: GridLayoutGeometry(maxCrossAxisExtent: 100),
            ),
          ],
          outerGap: 0,
          crossAxisExtent: 300,
        );
        // usable = 300 - 10*2 = 280；cell = 93.33；ratio 2 → 46.67。
        expect(plan.fixedExtentOfRow(0)!, closeTo(280 / 3 / 2, 0.001));
        // maxCross 100 → ceil(300/100) = 3 列 → 8 item 3 行；cell = 100、ratio 1 → 100。
        expect(plan.columnsOf(1), 3);
        expect(plan.rowCountOf(1), 3);
        expect(plan.fixedExtentOfRow(plan.rowStartOf(1))!, closeTo(100, 0.001));
      });

      test('交叉轴未知（0）：maxCrossAxisExtent 兜底 1 列、aspectRatio 行高 null', () {
        final plan = SegmentPlan(
          [
            GridSegment(
              source: BuilderItemSource(itemCount: 4, builder: (context, index) => box()),
              geometry: GridLayoutGeometry(maxCrossAxisExtent: 100),
            ),
          ],
          outerGap: 0,
          crossAxisExtent: 0,
        );
        expect(plan.columnsOf(0), 1);
        expect(plan.rowCountOf(0), 4);
        expect(plan.fixedExtentOfRow(0), 0);
      });

      test('空段不占行', () {
        final plan = SegmentPlan(
          [LinearSegment(source: MaterializedItemSource(const <Widget>[])), StaticSegment(box())],
          outerGap: 8,
          crossAxisExtent: 300,
        );
        expect(plan.totalRowCount, 1);
        expect(plan.rowStartOf(1), 0);
      });
    });

    group('间距模型（不进 Fenwick，算术叠加）', () {
      test('spacingAfterRow：linear 段内为 0、段边界 outerGap、grid 保留行距', () {
        final plan = buildMixedPlan();
        expect(plan.spacingAfterRow(0), 8, reason: 'static 段末行 → 段边界');
        expect(plan.spacingAfterRow(1), 0, reason: 'ElListView 段内无额外 spacing');
        expect(plan.spacingAfterRow(100), 8, reason: 'linear 末行 → 段边界');
        expect(plan.spacingAfterRow(101), 6, reason: 'grid 段内行距');
        expect(plan.spacingAfterRow(104), 8, reason: 'grid 末行 → 段边界');
        expect(plan.spacingAfterRow(105), 0, reason: '全内容末行');
      });

      test('cumulativeSpacingBeforeRow 与 totalSpacing', () {
        final plan = buildMixedPlan();
        expect(plan.cumulativeSpacingBeforeRow(0), 0);
        expect(plan.cumulativeSpacingBeforeRow(1), 8);
        expect(plan.cumulativeSpacingBeforeRow(2), 8);
        expect(plan.cumulativeSpacingBeforeRow(101), 8 + 8);
        expect(plan.cumulativeSpacingBeforeRow(102), 8 + 8 + 6);
        expect(plan.cumulativeSpacingBeforeRow(105), 8 + 8 + 3 * 6 + 8);
        expect(plan.totalSpacing(), plan.cumulativeSpacingBeforeRow(105));
      });
    });

    group('contentOffsetToRowSpace（layout 空间 → 纯行高空间）', () {
      // 行高全估算 10：offsetOf(r) = 10r，断言可手算。
      VirtualExtentIndex index(SegmentPlan plan) => VirtualExtentIndex(count: plan.totalRowCount, estimatedExtent: 10);

      test('命中段内行内容区：扣掉累计间距', () {
        final plan = buildMixedPlan();
        final fenwick = index(plan);
        expect(plan.contentOffsetToRowSpace(5, fenwick), 5, reason: '首 static 段内');
        expect(plan.contentOffsetToRowSpace(18, fenwick), 10, reason: 'linear 首行起点（跳过段边界 8）');
        expect(plan.contentOffsetToRowSpace(28, fenwick), 20, reason: 'linear 第二行紧接上一行');
      });

      test('落在间距缝里：钉到缝前行尾', () {
        final plan = buildMixedPlan();
        final fenwick = index(plan);
        expect(plan.contentOffsetToRowSpace(12, fenwick), 10, reason: '段边界缝（10~18）→ 首段行尾');
        expect(plan.contentOffsetToRowSpace(1020, fenwick), 1010, reason: 'linear/grid 段边界缝 → linear 末行行尾');
        expect(plan.contentOffsetToRowSpace(1038, fenwick), 1020, reason: 'grid 行间缝 → grid 首行行尾');
      });

      test('越过全部内容：返回 totalExtent', () {
        final plan = buildMixedPlan();
        final fenwick = index(plan);
        expect(plan.contentOffsetToRowSpace(1e9, fenwick), fenwick.totalExtent);
        expect(plan.contentOffsetToRowSpace(-5, fenwick), 0);
      });
    });

    group('交叉轴几何', () {
      test('grid cell 列偏移与宽度；非 grid 铺满', () {
        final plan = buildMixedPlan();
        // usable = 300 - 10*2 = 280，cell = 93.33。
        final cell0 = plan.cellCrossGeometry(101);
        final cell1 = plan.cellCrossGeometry(102);
        expect(cell0.cross, 0);
        expect(cell0.extent, closeTo(280 / 3, 0.001));
        expect(cell1.cross, closeTo(280 / 3 + 10, 0.001));
        expect(plan.cellCrossGeometry(50), (cross: 0.0, extent: 300.0));
      });
    });
  });

  group('布局段解析', () {
    List<SegmentSpec> resolve(List<Widget> children, {Axis axis = .vertical}) =>
        resolveScrollSegments(children, scrollAxis: axis);

    test('普通 Widget 保持常驻，列表配置保留数量与 key 回查', () {
      final header = ElView(child: 'header');
      int? findIndex(Key key) => key == ValueKey('row') ? 7 : null;
      final list = ElListView.builder(
        itemCount: 42,
        itemBuilder: (_, index) => ElView(),
        findChildIndexCallback: findIndex,
      );
      final segments = resolve([header, list]);
      expect((segments.first as StaticSegment).child, same(header));
      final source = (segments.last as LinearSegment).source as BuilderItemSource;
      expect(source.itemCount, 42);
      expect(source.findChildIndex, same(findIndex));
      expect(hasVirtualSegmentDeclaration([header]), isFalse);
      expect(hasVirtualSegmentDeclaration([list]), isTrue);
    });

    test('分隔列表按业务与分隔项交替展开，统一尺寸仅用于业务项', () {
      final segment =
          resolve([
                ElListView.builder(
                  itemCount: 3,
                  fixedSize: true,
                  itemBuilder: (_, index) => ElView(),
                  separatorBuilder: (_, index) => ElView(),
                ),
              ]).single
              as LinearSegment;
      expect(segment.itemCount, 5);
      expect(segment.fixedExtentAt(0), isNull);
      segment.fixed!.extent = 24;
      expect(segment.fixedExtentAt(0), 24);
      expect(segment.fixedExtentAt(1), isNull);
      expect(segment.fixedExtentAt(4), 24);
    });

    test('旧列表入口全部拒绝，解析阶段不会调用旧 delegate', () {
      var builds = 0;
      Widget row(BuildContext context, int index) {
        builds++;
        return ElView();
      }

      // 这些旧类型只用于验证迁移边界，不再承载任何正向用例。
      final legacy = <Widget>[
        SliverList.builder(itemCount: 10, itemBuilder: row),
        SliverList.list(children: [ElView()]),
        SliverList.separated(itemCount: 10, itemBuilder: row, separatorBuilder: row),
        SliverFixedExtentList.builder(itemExtent: 24, itemCount: 10, itemBuilder: row),
        SliverPrototypeExtentList.builder(prototypeItem: ElView(), itemCount: 10, itemBuilder: row),
        SliverVariedExtentList.list(children: [ElView()], itemExtentBuilder: (_, _) => 24),
      ];
      for (final declaration in legacy) {
        expect(
          () => resolve([declaration]),
          throwsA(isA<FlutterError>().having((error) => error.message, 'message', contains('ElListView'))),
        );
        expect(hasVirtualSegmentDeclaration([declaration]), isFalse);
      }
      expect(builds, 0);
    });

    test('网格继续支持固定列数和最大列宽', () {
      final segments = resolve([
        ElGridView(crossAxisCount: 2, children: [ElView(), ElView()]),
        ElGridView(maxCrossAxisExtent: 120, children: [ElView()]),
      ]);
      expect((segments[0] as GridSegment).geometry.crossAxisCount, 2);
      expect((segments[1] as GridSegment).geometry.maxCrossAxisExtent, 120);
    });

    test('横向布局 View 可用，旧网格 delegate 明确拒绝', () {
      expect(
        (resolve([
                  ElGridView(crossAxisCount: 2, children: [ElView()]),
                ], axis: .horizontal).single
                as GridSegment)
            .axis,
        Axis.horizontal,
      );
      expect(
        () => resolve([
          SliverGrid(
            delegate: _CustomDelegate(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
          ),
        ]),
        throwsFlutterError,
      );
    });
  });

  group('统一尺寸生命周期', () {
    for (final axis in Axis.values) {
      for (final reverse in [false, true]) {
        testWidgets('真实首条在 $axis reverse=$reverse 下提供统一尺寸', (tester) async {
          final controller = ElScrollController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            _uniformExtentLifecycleHost(
              ElScrollView(
                controller: controller,
                axis: axis,
                reverse: reverse,
                cacheExtent: 0,
                scrollbar: ElNoScrollBar(),
                children: [
                  ElListView.builder(
                    itemCount: 100,
                    fixedSize: true,
                    itemBuilder: (_, index) => ElView(
                      key: ValueKey(index),
                      style: ElStyle(width: index == 0 ? 20 : 70, height: index == 0 ? 20 : 70),
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pump();
          expect(controller.position.maxScrollExtent, 1880);
          final target = tester.getSize(find.byKey(ValueKey(reverse ? 99 : 0)));
          expect(axis == .vertical ? target.height : target.width, 20);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('多个统一尺寸段同帧测量，移除前段后保留后段尺寸', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      Widget build(bool first) => _uniformExtentLifecycleHost(
        ElScrollView(
          controller: controller,
          cacheExtent: 0,
          scrollbar: ElNoScrollBar(),
          children: [
            if (first)
              ElListView.builder(
                key: ValueKey('a'),
                itemCount: 100,
                fixedSize: true,
                itemBuilder: (_, index) => ElView(style: ElStyle(height: 20)),
              ),
            ElListView.builder(
              key: ValueKey('b'),
              itemCount: 100,
              fixedSize: true,
              itemBuilder: (_, index) => ElView(style: ElStyle(height: 30)),
            ),
          ],
        ),
      );
      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(controller.position.maxScrollExtent, 4880);
      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(controller.position.maxScrollExtent, 2880);
    });

    testWidgets('统一尺寸列表全选包含真实首条且没有隐藏副本载荷', (tester) async {
      final selection = ElSelectionController();
      addTearDown(selection.dispose);
      await tester.pumpWidget(
        _uniformExtentLifecycleHost(
          ElSelectionView(
            controller: selection,
            child: ElScrollView(
              cacheExtent: 0,
              scrollbar: ElNoScrollBar(),
              children: [
                ElListView.builder(
                  itemCount: 3,
                  fixedSize: true,
                  itemBuilder: (_, index) => ElView(style: ElStyle(height: 20), child: 'row $index'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      selection.selectAll();
      await tester.pump();
      expect(RegExp('row 0').allMatches(selection.text ?? '').length, 1);
      expect(selection.text, contains('row 1'));
      expect(selection.text, contains('row 2'));
    });
  });

  group('虚拟化观测计数', () {
    Widget shell({required ScrollController controller, required int itemCount, double cacheExtent = 0}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 600,
            child: ElScrollView(
              controller: controller,
              cacheExtent: cacheExtent,
              physics: const ClampingScrollPhysics(),
              children: [
                ElListView.builder(
                  itemCount: itemCount,
                  itemBuilder: (context, index) => SizedBox(height: 40, child: Text('row $index')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('静止帧零活动：泵帧不触发 build/reconcile/窗口重算增长', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller, itemCount: 1000));
      await tester.pump();
      await tester.pump();

      final state = _scrollState(tester);
      final counters = state.debugCounters;
      final buildBefore = counters.debugBuildCount;
      final reconcileBefore = counters.debugContentReconcileCount;
      final recomputeBefore = counters.debugVisibleRangeRecomputeCount;
      expect(buildBefore, greaterThan(0), reason: '观测开启时必须记录真实宿主构建，不能返回空计数');
      expect(reconcileBefore, greaterThan(0), reason: '首帧挂载必须反映在对账计数中');
      expect(recomputeBefore, greaterThan(0), reason: '首帧必须记录实际窗口计算');

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(counters.debugBuildCount, buildBefore, reason: '静止帧不得 rebuild（推送型自激环红线）');
      expect(counters.debugContentReconcileCount, reconcileBefore, reason: '静止帧不得 reconcile');
      expect(counters.debugVisibleRangeRecomputeCount, recomputeBefore, reason: '静止帧不得重算窗口');
    });

    testWidgets('挂载数上界：可视行 + cache 行 + 结构富余', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      // 视口 600 / 行高 40 = 15 可视行；cache 200 → 每侧 5 行。
      await tester.pumpWidget(shell(controller: controller, itemCount: 1000, cacheExtent: 200));
      await tester.pump();
      controller.jumpTo(5000);
      await tester.pump();
      await tester.pump();

      final state = _scrollState(tester);
      final counters = state.debugCounters;
      expect(counters.debugMaxMountedChildCount, greaterThanOrEqualTo(15), reason: '真实挂载量至少覆盖 15 行可见内容');
      // 上界 = 15 可视 + 2×5 cache + 4 结构富余（部分行/边界行/锚点保守）。
      expect(counters.debugMaxMountedChildCount, lessThanOrEqualTo(15 + 10 + 4));
    });

    testWidgets('滚动半屏：增量 reconcile 快路径命中、更新数不超过进入行数', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller, itemCount: 1000));
      await tester.pump();
      await tester.pump();

      final state = _scrollState(tester);
      final counters = state.debugCounters;
      final incrementalBefore = counters.debugContentIncrementalReconcileCount;

      // 半屏平移（300px / 行高 40 = 进入约 8 行）。
      controller.jumpTo(300);
      await tester.pump();
      await tester.pump();

      expect(
        counters.debugContentIncrementalReconcileCount,
        greaterThan(incrementalBefore),
        reason: '窗口平移必须走增量 reconcile 快路径（退全量 = 记账成本回归）',
      );
      // 最近一次 reconcile 的更新数 ≤ 进入行数 + 2 富余（不重建保留行）。
      expect(counters.debugLastContentReconcileUpdateChildCount, lessThanOrEqualTo(8 + 2));
      expect(counters.debugLastContentReconcileSlotMoveCount, 0, reason: '纯平移不得发生 slot 移动');
    });

    testWidgets('等高列表全程滚动：extent 上报批次有界（实测一次不重复上报）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(shell(controller: controller, itemCount: 200));
      await tester.pump();
      await tester.pump();

      final state = _scrollState(tester);
      final counters = state.debugCounters;

      // 全程逐屏滚动到底再回顶。
      for (var i = 0; i < 16; i++) {
        controller.jumpTo((controller.offset + 550).clamp(0, controller.position.maxScrollExtent));
        await tester.pump();
        await tester.pump();
      }
      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();

      final batches = counters.debugItemExtentReportBatchCount;
      final measured = counters.debugMeasuredItemCount;
      expect(measured, 200, reason: '全程滚动后全部行实测');
      // 回程重访已测行不得再上报：批次数以"每个新窗口一批"为界（16 跳 + 首帧
      // + 回顶 + 富余），远小于行数。
      expect(batches, lessThanOrEqualTo(16 + 4), reason: '已测行重访不得重复上报（批次爆炸 = 上报判据回归）');
    });

    testWidgets('1/100/1000 item 首帧挂载规模保持窗口有界', (tester) async {
      Future<({int rowStates, int renderObjects})> measure(int itemCount) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: 600,
                child: ElScrollView(
                  scrollbar: const ElNoScrollBar(),
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 0,
                  children: [
                    ElListView.builder(
                      itemCount: itemCount,
                      itemBuilder: (context, index) => _MountedRow(index),
                      fixedSize: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        var renderObjects = 0;
        void visit(RenderObject renderObject) {
          renderObjects++;
          renderObject.visitChildren(visit);
        }

        final root = tester.element(find.byType(ElScrollView)).findRenderObject();
        if (root != null) visit(root);
        return (
          rowStates: tester.stateList<_MountedRowState>(find.byType(_MountedRow, skipOffstage: false)).length,
          renderObjects: renderObjects,
        );
      }

      final one = await measure(1);
      final hundred = await measure(100);
      final thousand = await measure(1000);

      expect(one.rowStates, 1);
      expect(hundred.rowStates, greaterThan(1));
      expect(hundred.rowStates, lessThanOrEqualTo(20));
      expect(thousand.rowStates, hundred.rowStates, reason: '总 itemCount 增长不得扩大首帧 mounted window');
      expect(thousand.renderObjects, hundred.renderObjects, reason: 'Scope 不得把总 itemCount 放大成 RenderObject 数');
    });

    testWidgets('Phase 1 Scope 对 Phase 0 对象数量的增量基线', (tester) async {
      Widget baseline({required bool useDefaultScrollbar}) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 600,
              child: ElScrollView(
                scrollbar: useDefaultScrollbar ? null : const ElNoScrollBar(),
                physics: const ClampingScrollPhysics(),
                children: [
                  ElListView.builder(
                    itemBuilder: (context, index) => ElView(style: ElStyle(height: 40), child: 'row $index'),
                    itemCount: 100,
                    fixedSize: true,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      ({int builds, int widgets, int elements, int renderObjects, bool clientRegistryAllocated}) snapshot() {
        final root = tester.element(find.byType(ElScrollView));
        var widgets = 0;
        var elements = 0;
        void visitElement(Element element) {
          widgets++;
          elements++;
          element.visitChildElements(visitElement);
        }

        var renderObjects = 0;
        void visitRenderObject(RenderObject renderObject) {
          renderObjects++;
          renderObject.visitChildren(visitRenderObject);
        }

        visitElement(root);
        final renderRoot = root.findRenderObject();
        if (renderRoot != null) visitRenderObject(renderRoot);
        final state = _scrollState(tester);
        return (
          builds: state.debugCounters.debugBuildCount,
          widgets: widgets,
          elements: elements,
          renderObjects: renderObjects,
          clientRegistryAllocated: state.debugScrollMixinClientRegistryAllocated,
        );
      }

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await tester.pumpWidget(baseline(useDefaultScrollbar: false));
      await tester.pump();
      await tester.pump();
      final scroll = snapshot();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await tester.pumpWidget(baseline(useDefaultScrollbar: true));
      await tester.pump();
      await tester.pump();
      final scrollbar = snapshot();
      debugDefaultTargetPlatformOverride = null;

      debugPrint(
        'PHASE7_BASELINE default_scroll '
        'builds=${scroll.builds} widgets=${scroll.widgets} '
        'elements=${scroll.elements} renderObjects=${scroll.renderObjects}',
      );
      debugPrint(
        'PHASE7_BASELINE windows_scrollbar '
        'builds=${scrollbar.builds} widgets=${scrollbar.widgets} '
        'elements=${scrollbar.elements} renderObjects=${scrollbar.renderObjects}',
      );

      expect(scroll.builds, 1);
      expect(scroll.widgets, lessThan(99), reason: 'Phase 7 删除中间内容层、guard 与滚动条包装后节点必须减少');
      expect(scroll.elements, lessThan(99), reason: 'Phase 7 删除中间内容层、guard 与滚动条包装后节点必须减少');
      expect(scroll.renderObjects, lessThan(49), reason: 'Phase 7 删除中间内容层、guard 与滚动条包装后节点必须减少');
      expect(scroll.clientRegistryAllocated, isFalse, reason: '无 Mixin client 时不得分配登记表');
      expect(scrollbar.builds, 1);
      expect(scrollbar.widgets, lessThan(134), reason: 'Phase 7 删除中间内容层、guard 与滚动条包装后节点必须减少');
      expect(scrollbar.elements, lessThan(134), reason: 'Phase 7 删除中间内容层、guard 与滚动条包装后节点必须减少');
      expect(scrollbar.renderObjects, lessThan(70), reason: 'Phase 7 删除中间内容层、guard 与滚动条包装后节点必须减少');
      expect(scrollbar.clientRegistryAllocated, isFalse, reason: '默认滚动条不得隐式创建 Mixin client');
    });
  });

  testWidgets('视口内 chrome 复用一份：纯 offset 滚动不重建，extent 变化重建一次', (tester) async {
    final controller = ElScrollController();
    addTearDown(controller.dispose);
    final marker = Color(0xffff00ff);
    final bar = _MarkerBar(marker);
    Widget host({int itemCount = 200}) => Directionality(
      textDirection: .ltr,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: 200,
          height: 120,
          child: ElScrollView(
            controller: controller,
            cacheExtent: 0,
            scrollbar: bar,
            children: [
              ElListView.builder(
                itemCount: itemCount,
                itemBuilder: (context, index) => ElView(style: ElStyle(height: 36), child: 'row $index'),
              ),
            ],
          ),
        ),
      ),
    );
    final thumb = find.byWidgetPredicate((widget) => widget is ElView && widget.style?.bgColor == marker);
    final rowZero = find.byWidgetPredicate((widget) => widget is ElView && widget.child == 'row 0');

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(thumb, findsOneWidget, reason: '条带只随视口挂载一份');
    expect(
      find.ancestor(of: thumb, matching: find.byType(ElScrollView)),
      findsOneWidget,
      reason: '条带物理归属唯一来源视口',
    );
    expect(find.byType(ElScrollView), findsOneWidget);
    final stripElement = tester.element(thumb);
    expect(rowZero, findsOneWidget);

    controller.jumpTo(600);
    await tester.pumpAndSettle();
    // 首屏挂载后视口先落一次真实 metrics（isScrollable 从 false 变 true）；此后纯 offset 不应再重建。
    final buildsAfterWarmup = bar.chromeBuilds;
    expect(rowZero, findsNothing, reason: '远距滚动后旧行已挂卸');
    expect(tester.element(thumb), same(stripElement), reason: '滚动挂卸复用同一份条带');

    for (final offset in <double>[1200, 1800, 3000, 0]) {
      controller.jumpTo(offset);
      await tester.pumpAndSettle();
      expect(bar.chromeBuilds, buildsAfterWarmup, reason: '纯 offset 滚动（extent 不变）不重建 chrome: $offset');
      expect(tester.element(thumb), same(stripElement), reason: '纯 offset 滚动复用同一份条带: $offset');
    }
    expect(rowZero, findsOneWidget, reason: '滚回顶部后虚拟行重新挂载');

    await tester.pumpWidget(host(itemCount: 1));
    await tester.pumpAndSettle();
    final buildsAfterShrink = bar.chromeBuilds;
    expect(buildsAfterShrink, greaterThan(buildsAfterWarmup), reason: '内容收缩使 isScrollable/extent 变化，允许且应重建 chrome');
    expect(thumb, findsOneWidget);
    expect(tester.element(thumb), same(stripElement), reason: 'extent 变化重建后条带仍复用同一 Widget/State');

    await tester.pumpWidget(host(itemCount: 400));
    await tester.pumpAndSettle();
    expect(thumb, findsOneWidget);
    expect(tester.element(thumb), same(stripElement), reason: '内容增删后条带仍复用同一 Widget/State');
    expect(bar.chromeBuilds, greaterThan(buildsAfterShrink), reason: '内容增删再次改变 extent，应再重建一次 chrome');
    expect(tester.takeException(), isNull);
  });

  group('网格布局段', () {
    Widget shell(Widget child, {double width = 316, double height = 400}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      );
    }

    testWidgets('aspectRatio 派生行高：无 mainAxisExtent 时行高 = 列宽/ratio（补旧 P0 缺口）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            children: [
              ElGridView.builder(
                crossAxisCount: 2,
                aspectRatio: 2,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('ar$index')),
                itemCount: 40,
              ),
            ],
          ),
        ),
      );
      // 列宽 316/2=158，ratio 2 → 行高 79；20 行 ×79=1580 → max=1180。
      expect(tester.getSize(find.byKey(const ValueKey('ar0'))).height, closeTo(79, 0.01));
      expect(controller.position.maxScrollExtent, closeTo(1580 - 400, 0.5));
    });

    testWidgets('maxCrossAxisExtent 自动列数：316/100 → 4 列（补旧 P1 缺口）', (tester) async {
      await tester.pumpWidget(
        shell(
          ElScrollView(
            children: [
              ElGridView.builder(
                maxCrossAxisExtent: 100,
                mainAxisExtent: 50,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('mx$index')),
                itemCount: 12,
              ),
            ],
          ),
        ),
      );
      // ceil(316/100)=4 列 → 列宽 79；同行 4 个（0..3 同 dy）。
      final y0 = tester.getTopLeft(find.byKey(const ValueKey('mx0'))).dy;
      expect(tester.getTopLeft(find.byKey(const ValueKey('mx3'))).dy, y0);
      expect(tester.getTopLeft(find.byKey(const ValueKey('mx4'))).dy, greaterThan(y0));
      expect(tester.getSize(find.byKey(const ValueKey('mx0'))).width, closeTo(79, 0.01));
    });

    testWidgets('findChildIndexCallback keyed 通道：中部插入保实测（滚动位置与可视行不跳）', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      Widget page(List<String> ids) => shell(
        ElScrollView(
          controller: controller,
          preserveAnchor: true,
          cacheExtent: 0,
          children: [
            ElListView.builder(
              itemBuilder: (context, index) =>
                  SizedBox(key: ValueKey('k-${ids[index]}'), height: 30 + (ids[index].hashCode % 4) * 10),
              itemCount: ids.length,
              findChildIndexCallback: (key) {
                final id = (key as ValueKey<String>).value.substring(2);
                final index = ids.indexOf(id);
                return index < 0 ? null : index;
              },
            ),
          ],
        ),
      );
      final ids = [for (var i = 0; i < 120; i++) 'r$i'];
      await tester.pumpWidget(page(ids));
      controller.jumpTo(1500);
      await tester.pump();
      await tester.pump();
      // 记录可视首行（keyed 锚定的真判据 = 同一行的屏幕位置不跳，offset 本身
      // 会随头插内容增长——chat prepend 语义）。
      final anchorKey = find
          .byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('k-'))
          .first;
      final anchorId = (tester.widget(anchorKey).key! as ValueKey<String>).value;
      final anchorTopBefore = tester.getTopLeft(find.byKey(ValueKey(anchorId))).dy;

      // 头部插入 5 项：builder 段 keyed 通道让实测跟 key 走，已滚区不跳。
      final grown = [for (var i = 0; i < 5; i++) 'new$i', ...ids];
      await tester.pumpWidget(page(grown));
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(ValueKey(anchorId))).dy,
        closeTo(anchorTopBefore, 0.5),
        reason: '头部插入后原可视行屏幕位置不跳（keyed 实测保留 + 锚点补偿）',
      );
    });

    testWidgets('ElListView.separatorBuilder：分隔行交替渲染、总长 = n 项 + (n-1) 分隔', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        shell(
          ElScrollView(
            controller: controller,
            children: [
              ElListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => SizedBox(key: ValueKey('it$index'), height: 40),
                separatorBuilder: (context, index) => SizedBox(key: ValueKey('sep$index'), height: 10),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // 交替：item0(40) sep0(10) item1 …；总 = 50*40 + 49*10 = 2490 → max 2090。
      expect(tester.getTopLeft(find.byKey(const ValueKey('sep0'))).dy, 40);
      expect(tester.getTopLeft(find.byKey(const ValueKey('it1'))).dy, 50);
      // 全程实测收敛后断总长。
      for (var i = 0; i < 8; i++) {
        controller.jumpTo((controller.offset + 380).clamp(0, controller.position.maxScrollExtent));
        await tester.pump();
        await tester.pump();
      }
      expect(controller.position.maxScrollExtent, closeTo(2490 - 400, 1e-6));
    });
  });

  group('虚拟成员生命周期', () {
    testWidgets('普通 children 全量常驻，滚动不触发生命周期，父重建更新屏内外成员', (tester) async {
      final controller = ScrollController();
      final trace = _LifecycleTrace();
      addTearDown(controller.dispose);

      Widget build(int revision) => _scrollHost(
        controller: controller,
        children: [
          for (var index = 0; index < 24; index++)
            _LifecycleProbe(key: ValueKey('resident-$index'), id: 'resident-$index', revision: revision, trace: trace),
        ],
      );

      await tester.pumpWidget(build(1));
      await tester.pump();

      expect(trace.totalInits, 24);
      expect(find.byKey(const ValueKey('resident-23'), skipOffstage: false), findsOneWidget);
      final firstState = tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('resident-0')));
      final lastState = tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('resident-23')));
      final buildsBeforeScroll = Map<String, int>.of(trace.builds);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      expect(trace.builds, buildsBeforeScroll);
      expect(trace.totalDeactivates, 0);
      expect(trace.totalDisposes, 0);
      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('resident-0'))), same(firstState));
      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('resident-23'))), same(lastState));

      await tester.pumpWidget(build(2));
      await tester.pump();

      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('resident-0'))), same(firstState));
      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('resident-23'))), same(lastState));
      for (var index = 0; index < 24; index++) {
        expect(trace.updatesFor('resident-$index'), 1);
        expect(find.text('resident-$index:2', skipOffstage: false), findsOneWidget);
      }
      expect(trace.totalDeactivates, 0);
      expect(trace.totalDisposes, 0);
    });

    testWidgets('普通 keyed 与 GlobalKey 成员原地重排后保持 State', (tester) async {
      final trace = _LifecycleTrace();
      final globalKey = GlobalKey<_LifecycleProbeState>();
      final children = <Widget>[
        _LifecycleProbe(key: const ValueKey('keyed-a'), id: 'a', revision: 1, trace: trace),
        _LifecycleProbe(key: globalKey, id: 'global', revision: 1, trace: trace),
        _LifecycleProbe(key: const ValueKey('keyed-b'), id: 'b', revision: 1, trace: trace),
      ];

      await tester.pumpWidget(_scrollHost(children: children));
      final stateA = tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('keyed-a')));
      final stateB = tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('keyed-b')));
      final globalState = globalKey.currentState;

      children
        ..clear()
        ..addAll([
          _LifecycleProbe(key: const ValueKey('keyed-b'), id: 'b', revision: 2, trace: trace),
          _LifecycleProbe(key: const ValueKey('keyed-x'), id: 'x', revision: 2, trace: trace),
          _LifecycleProbe(key: globalKey, id: 'global', revision: 2, trace: trace),
          _LifecycleProbe(key: const ValueKey('keyed-a'), id: 'a', revision: 2, trace: trace),
        ]);
      await tester.pumpWidget(_scrollHost(children: children));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('keyed-a'))), same(stateA));
      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('keyed-b'))), same(stateB));
      expect(globalKey.currentState, same(globalState));
      expect(trace.initsFor('a'), 1);
      expect(trace.initsFor('b'), 1);
      expect(trace.initsFor('global'), 1);
      expect(trace.initsFor('x'), 1);
      expect(trace.totalDisposes, 0);
    });

    testWidgets('普通无 key 成员重排按扁平位置复用 State', (tester) async {
      final trace = _LifecycleTrace();

      Widget build(List<String> ids, int revision) => _scrollHost(
        children: [for (final id in ids) _LifecycleProbe(id: id, revision: revision, trace: trace)],
      );

      await tester.pumpWidget(build(const ['left', 'right'], 1));
      final stateAtLeft = tester.state<_LifecycleProbeState>(_probeFinder('left'));
      final stateAtRight = tester.state<_LifecycleProbeState>(_probeFinder('right'));

      await tester.pumpWidget(build(const ['right', 'left'], 2));

      expect(tester.state<_LifecycleProbeState>(_probeFinder('right')), same(stateAtLeft));
      expect(tester.state<_LifecycleProbeState>(_probeFinder('left')), same(stateAtRight));
      expect(trace.totalInits, 2);
      expect(trace.totalDisposes, 0);
    });

    testWidgets('列表 builder 刷新窗口内行，离窗释放，回窗读取最新 source', (tester) async {
      final controller = ScrollController();
      final trace = _LifecycleTrace();
      addTearDown(controller.dispose);

      Widget build(int revision) => _scrollHost(
        controller: controller,
        children: [
          ElListView.builder(
            itemBuilder: (context, index) =>
                _LifecycleProbe(key: ValueKey('sliver-$index'), id: 'sliver-$index', revision: revision, trace: trace),
            itemCount: 100,
            fixedSize: true,
          ),
        ],
      );

      await tester.pumpWidget(build(1));
      await tester.pump();
      final firstState = tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('sliver-1')));
      expect(trace.initsFor('sliver-99'), 0);

      await tester.pumpWidget(build(2));
      await tester.pump();
      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('sliver-1'))), same(firstState));
      expect(trace.updatesFor('sliver-1'), 1);

      controller.jumpTo(800);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('sliver-1'), skipOffstage: false), findsNothing);
      expect(trace.deactivatesFor('sliver-1'), 1);
      expect(trace.disposesFor('sliver-1'), 1);
      expect(find.byKey(const ValueKey('sliver-0'), skipOffstage: false), findsOneWidget, reason: '真实首条承担统一尺寸测量并保活');

      await tester.pumpWidget(build(3));
      await tester.pump();
      controller.jumpTo(0);
      await tester.pump();
      await tester.pump();

      final remountedState = tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('sliver-1')));
      expect(remountedState, isNot(same(firstState)));
      expect(trace.initsFor('sliver-1'), 2);
      expect(find.text('sliver-1:3'), findsOneWidget);
    });

    testWidgets('shrinkWrap 下列表配置 全量常驻并刷新全部 State', (tester) async {
      final controller = ScrollController();
      final trace = _LifecycleTrace();
      addTearDown(controller.dispose);

      Widget build(int revision) => _scrollHost(
        controller: controller,
        shrinkWrap: true,
        children: [
          ElListView.builder(
            itemBuilder: (context, index) =>
                _LifecycleProbe(key: ValueKey('shrink-$index'), id: 'shrink-$index', revision: revision, trace: trace),
            itemCount: 20,
            fixedSize: true,
          ),
        ],
      );

      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(trace.totalInits, 20);
      final firstState = tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('shrink-0')));
      final lastState = tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('shrink-19')));

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(find.byKey(const ValueKey('shrink-0'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('shrink-19'), skipOffstage: false), findsOneWidget);
      expect(trace.totalDeactivates, 0);
      expect(trace.totalDisposes, 0);

      await tester.pumpWidget(build(2));
      await tester.pump();
      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('shrink-0'))), same(firstState));
      expect(tester.state<_LifecycleProbeState>(find.byKey(const ValueKey('shrink-19'))), same(lastState));
      for (var index = 0; index < 20; index++) {
        expect(trace.updatesFor('shrink-$index'), 1);
        expect(find.text('shrink-$index:2', skipOffstage: false), findsOneWidget);
      }
      expect(trace.totalDisposes, 0);
    });
  });

  group('变高窗口同帧填充', () {
    for (final axis in Axis.values) {
      testWidgets('变高列表 $axis 零缓存穿过短行时，本帧正文仍铺满窗口', (tester) async {
        tester.view.devicePixelRatio = 1.75;
        tester.view.physicalSize = Size(560, 560);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: ElScrollView(
              controller: controller,
              axis: axis,
              cacheExtent: 0,
              scrollbar: ElNoScrollBar(),
              children: [
                ElListView.builder(
                  itemCount: 10000,
                  itemBuilder: (_, i) {
                    final extent = i < 30
                        ? 88.0
                        : i % 7 == 0
                        ? 22.1
                        : 44.0;
                    return ElView(
                      key: ValueKey('row-$i'),
                      style: ElStyle(
                        width: axis == .horizontal ? extent : null,
                        height: axis == .vertical ? extent : null,
                        bgColor: Color(0xff224466),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        controller.jumpTo(150000);
        await tester.pump();
        for (final direction in [1, -1]) {
          for (var frame = 0; frame < 24; frame++) {
            controller.jumpTo(controller.offset + direction * [2.0, 81.0, 300.0, 700.0][frame % 4]);
            await tester.pump();
            final children = tester.renderObjectList<RenderBox>(
              find.byWidgetPredicate((widget) => widget is ElView && widget.key is ValueKey<String>),
            );
            final spans = [for (final child in children) child.localToGlobal(Offset.zero) & child.size]
              ..sort((a, b) => axis == .vertical ? a.top.compareTo(b.top) : a.left.compareTo(b.left));
            expect(spans, isNotEmpty);
            // 自然盒与占位盒最多相差一个物理像素，不能把量化间隙误报为缺行。
            expect(axis == .vertical ? spans.first.top : spans.first.left, lessThanOrEqualTo(1 / 1.75 + .001));
            expect(
              axis == .vertical ? spans.last.bottom : spans.last.right,
              greaterThanOrEqualTo(320 - 1 / 1.75 - .001),
              reason: 'frame=$frame 短行实测后须立即补挂，不能靠下一帧填充正文',
            );
            for (var i = 1; i < spans.length; i++) {
              final gap = axis == .vertical ? spans[i].top - spans[i - 1].bottom : spans[i].left - spans[i - 1].right;
              expect(gap, inInclusiveRange(-.001, 1 / 1.75 + .001));
            }
          }
        }
        await tester.pumpWidget(ElView());
      });
    }
  });

  group('可见范围', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    testWidgets('可见范围初始收敛、滚动更新且值不变不重复', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final ranges = <ElVisibleRange>[];

      await tester.pumpWidget(
        _visibleRangeHost(controller: controller, itemCount: 20, onVisibleRangeChanged: ranges.add),
      );
      await tester.pumpAndSettle();

      expect(ranges, isNotEmpty);
      expect(ranges.last.first, 0);
      expect(ranges.last.last, 3);

      final settledCount = ranges.length;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(ranges.length, settledCount);

      controller.jumpTo(40);
      await tester.pumpAndSettle();
      expect(ranges.length, greaterThan(settledCount));
      expect(ranges.last.first, 1);
      expect(ranges.last.last, 4);

      final countBefore = ranges.length;
      controller.jumpTo(40);
      await tester.pumpAndSettle();
      expect(ranges.length, countBefore);
    });

    testWidgets('mounted 范围反映 cache 窗口', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final ranges = <ElVisibleRange>[];

      await tester.pumpWidget(
        _visibleRangeHost(controller: controller, itemCount: 20, onVisibleRangeChanged: ranges.add, cacheExtent: 40),
      );
      await tester.pumpAndSettle();

      expect(ranges.last.first, 0);
      expect(ranges.last.last, 3);
      expect(ranges.last.mountedFirst, 0);
      expect(ranges.last.mountedLast, greaterThanOrEqualTo(4));
    });

    testWidgets('仅范围回调消费普通列表时不构建完整 item 快照', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      final ranges = <ElVisibleRange>[];
      await tester.pumpWidget(
        _visibleRangeHost(controller: controller, itemCount: 40, onVisibleRangeChanged: ranges.add, cacheExtent: 40),
      );
      await tester.pumpAndSettle();
      final state = tester.state<ElScrollViewState>(find.byType(ElScrollView));
      for (final (offset, first, last) in [(0.0, 0, 3), (40.0, 1, 4), (60.0, 1, 5), (120.0, 3, 6)]) {
        controller.jumpTo(offset);
        await tester.pumpAndSettle();
        expect(ranges.last.first, first);
        expect(ranges.last.last, last);
        expect(ranges.last.mountedFirst, lessThanOrEqualTo(first));
        expect(ranges.last.mountedLast, greaterThanOrEqualTo(last));
        expect(state.debugCounters.debugItemSnapshotBuildCount, 0, reason: '范围只需要可见性，不能为每个挂载行构造完整几何快照');
      }
    });

    testWidgets('范围按定位项真实视口位置计入，负层级隐藏后立即排除', (tester) async {
      final ranges = <ElVisibleRange>[];
      late StateSetter rebuild;
      var layer = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: SizedBox(
              width: 200,
              height: 120,
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return ElScrollView(
                    scrollbar: const ElNoScrollBar(),
                    cacheExtent: 1000,
                    onVisibleRangeChanged: ranges.add,
                    children: [
                      const SizedBox(height: 800),
                      ElPositioned(top: 20, left: 0, width: 100, height: 40, zIndex: layer, child: const SizedBox()),
                      const SizedBox(height: 1),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(ranges.last.first, 0);
      expect(ranges.last.last, 2, reason: '定位项虽排在 800px 正文之后，仍在视口内显示');
      rebuild(() => layer = -1);
      await tester.pump();
      expect(ranges.last.last, 1, reason: '负层级项没有可见面积，不能继续撑大可见范围');
      rebuild(() => layer = 0);
      await tester.pump();
      expect(ranges.last.last, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('无消费者时跳过派发，接入回调后补发当前范围', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_visibleRangeHost(controller: controller, itemCount: 40));
      await tester.pumpAndSettle();
      controller.jumpTo(400);
      await tester.pumpAndSettle();

      final state = tester.state<ElScrollViewState>(find.byType(ElScrollView));
      expect(state.debugCounters.debugVisibilityDispatchCount, 0);

      final ranges = <ElVisibleRange>[];
      await tester.pumpWidget(
        _visibleRangeHost(controller: controller, itemCount: 40, onVisibleRangeChanged: ranges.add),
      );
      await tester.pumpAndSettle();

      expect(state.debugCounters.debugVisibilityDispatchCount, greaterThan(0));
      expect(ranges, isNotEmpty);
      expect(ranges.last.first, 10);
    });
  });
}
