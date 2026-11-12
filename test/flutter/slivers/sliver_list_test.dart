import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show BoxHitTestResult, Constraints, PaintingContext, RenderProxyBox, ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

ScrollController _setup(WidgetTester tester, {Size? size}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size ?? Size(320, 240);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  return controller;
}

Widget _page(
  ScrollController controller,
  List<Widget> slivers, {
  Axis axis = Axis.vertical,
  bool reverse = false,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  home: Directionality(
    textDirection: direction,
    child: CustomScrollView(
      controller: controller,
      scrollDirection: axis,
      reverse: reverse,
      physics: ClampingScrollPhysics(),
      scrollCacheExtent: ScrollCacheExtent.pixels(0),
      slivers: slivers,
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(Duration(milliseconds: 16), EnginePhase.sendSemanticsUpdate, Duration(seconds: 2));
  expect(tester.takeException(), isNull);
}

class _Record {
  int mounts = 0;
  int disposals = 0;
  int builds = 0;
  int layoutCalls = 0;
  int layouts = 0;
  int paints = 0;
  int hitTests = 0;
  int renderCreates = 0;
  int renderDisposals = 0;
  _ProbeItemState? state;
  _ProbeRender? render;

  (int, int, int, int, int) get work => (builds, layoutCalls, layouts, renderCreates, renderDisposals);
}

class _ProbeItem extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ProbeItem({super.key, required this.id, required this.record, this.height = 40, this.onTap});

  final int id;
  final _Record record;
  final double height;
  final VoidCallback? onTap;

  @override
  State<_ProbeItem> createState() => _ProbeItemState();
}

class _ProbeItemState extends State<_ProbeItem> {
  @override
  void initState() {
    super.initState();
    widget.record.mounts++;
    widget.record.state = this;
  }

  @override
  Widget build(BuildContext context) {
    widget.record.builds++;
    return _LayoutProbe(
      record: widget.record,
      child: SizedBox(
        width: 120,
        height: widget.height,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: Text('条目 ${widget.id}')),
      ),
    );
  }

  @override
  void dispose() {
    widget.record.disposals++;
    super.dispose();
  }
}

class _LayoutProbe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _LayoutProbe({required this.record, required super.child});

  final _Record record;

  @override
  RenderProxyBox createRenderObject(BuildContext context) {
    record.renderCreates++;
    return record.render = _ProbeRender(record);
  }
}

class _ProbeRender extends RenderProxyBox {
  _ProbeRender(this.record);

  final _Record record;

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    // 同时记录入口与真实布局，防止相同约束的 layout 早退掩盖全量遍历。
    record.layoutCalls++;
    super.layout(constraints, parentUsesSize: parentUsesSize);
  }

  @override
  void performLayout() {
    record.layouts++;
    super.performLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    record.paints++;
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    record.hitTests++;
    return super.hitTest(result, position: position);
  }

  @override
  void dispose() {
    record.renderDisposals++;
    super.dispose();
  }
}

class _RepaintLayoutProbe extends _LayoutProbe {
  _RepaintLayoutProbe({required super.record, required super.child});

  @override
  RenderProxyBox createRenderObject(BuildContext context) {
    record.renderCreates++;
    return record.render = _RepaintProbeRender(record);
  }
}

class _RepaintProbeRender extends _ProbeRender {
  _RepaintProbeRender(super.record);

  @override
  bool get isRepaintBoundary => true;
}

void main() {
  testWidgets('自带重绘边界的离屏子项不会独立重画，滚回恢复绘制且不重新布局', (tester) async {
    final controller = _setup(tester);
    final records = List.generate(24, (_) => _Record());
    await tester.pumpWidget(
      _page(controller, [
        ElSliverList(
          children: [
            for (var index = 0; index < records.length; index++)
              _RepaintLayoutProbe(
                record: records[index],
                child: SizedBox(width: 120, height: 80, child: Text('图层 $index')),
              ),
          ],
        ),
      ]),
    );
    await _settle(tester);
    final first = records.first.render!;
    expect(first.isRepaintBoundary, isTrue);
    expect(records.first.paints, greaterThan(0), reason: '先让首项可见，确保已经建立真实图层。');
    final before = [for (final record in records) record.work];

    controller.jumpTo(800);
    await tester.pump();
    expect(find.text('图层 0').hitTestable(), findsNothing);
    final offscreenPaints = records.first.paints;
    first.markNeedsPaint();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(records.first.paints, offscreenPaints, reason: '离屏边界不能因旧图层仍挂接而独立重画。');
    expect([for (final record in records) record.work], before);

    controller.jumpTo(0);
    await tester.pump();
    expect(find.text('图层 0').hitTestable(), findsOneWidget);
    expect(records.first.paints, greaterThan(offscreenPaints), reason: '回到视口后必须绘制离屏期间积累的脏内容。');
    expect(records.first.render, same(first));
    expect([for (final record in records) record.work], before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('常驻列表与 Recycler 同视口混排，跨段往返保持状态和自然滚动范围', (tester) async {
    final controller = _setup(tester);
    final records = List.generate(3, (_) => _Record());
    final heights = [60.0, 80.0, 100.0];
    final taps = <int>[];
    var factories = 0;
    await tester.pumpWidget(
      _page(controller, [
        SliverToBoxAdapter(child: SizedBox(height: 30)),
        ElSliverList(
          spacing: 10,
          children: [
            for (var index = 0; index < records.length; index++)
              _ProbeItem(key: ValueKey('混排常驻 $index'), id: index, record: records[index], height: heights[index]),
          ],
        ),
        ElSliverList.recycler(
          itemCount: 30,
          maxRecycledItems: 2,
          itemBuilder: (_, index) {
            factories++;
            return SizedBox(
              height: 40,
              child: ValueListenableBuilder<int>(
                valueListenable: index,
                builder: (_, value, _) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps.add(index.value),
                  child: Text('混排回收 $value'),
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: SizedBox(key: ValueKey('混排尾部'), height: 50)),
      ]),
    );
    await _settle(tester);
    final states = [for (final record in records) record.state];
    final renders = [for (final record in records) record.render];
    final before = [for (final record in records) record.work];
    expect(tester.getRect(find.byKey(ValueKey('混排常驻 0'))), Rect.fromLTWH(0, 30, 120, 60));
    expect(tester.getRect(find.byKey(ValueKey('混排常驻 2'))), Rect.fromLTWH(0, 190, 120, 100));
    expect(controller.position.maxScrollExtent, closeTo(1300, .01));

    controller.jumpTo(290);
    await _settle(tester);
    expect(find.text('混排回收 0').hitTestable(), findsOneWidget);
    await tester.tapAt(Offset(160, 20));
    expect(taps, [0]);
    final firstWindowFactories = factories;

    controller.jumpTo(890);
    await _settle(tester);
    expect(find.text('混排回收 15').hitTestable(), findsOneWidget);
    await tester.tapAt(Offset(160, 20));
    expect(taps, [0, 15]);
    expect(factories, firstWindowFactories, reason: '混排不能破坏 Recycler 同类槽位的跨窗口复用。');

    controller.jumpTo(controller.position.maxScrollExtent);
    await _settle(tester);
    expect(controller.position.maxScrollExtent, closeTo(1300, .01));
    expect(find.text('混排回收 29').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byKey(ValueKey('混排尾部'))), Rect.fromLTWH(0, 190, 320, 50));

    controller.jumpTo(0);
    await _settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('混排常驻 0'))), Rect.fromLTWH(0, 30, 120, 60));
    expect(tester.getRect(find.byKey(ValueKey('混排常驻 2'))), Rect.fromLTWH(0, 190, 120, 100));
    expect([for (final record in records) record.state], states);
    expect([for (final record in records) record.render], renders);
    expect([for (final record in records) record.work], before);
    expect(records.map((record) => record.mounts), everyElement(1));

    await tester.pumpWidget(SizedBox.shrink());
    expect(records.map((record) => record.disposals), everyElement(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('全部子项一次挂载，普通滚动不调用子项 layout 且仅绘制命中可见项', (tester) async {
    final controller = _setup(tester);
    final records = List.generate(80, (_) => _Record());
    final keys = List.generate(80, (index) => ValueKey('常驻 $index'));
    final taps = <int>[];
    final children = [
      for (var index = 0; index < records.length; index++)
        _ProbeItem(key: keys[index], id: index, record: records[index], onTap: () => taps.add(index)),
    ];
    await tester.pumpWidget(_page(controller, [ElSliverList(children: children)]));
    await _settle(tester);

    expect(find.byType(_ProbeItem, skipOffstage: false), findsNWidgets(80));
    expect(records.map((record) => record.mounts), everyElement(1));
    expect(records.map((record) => record.builds), everyElement(1));
    expect(records.map((record) => record.layouts), everyElement(greaterThan(0)));
    expect(
      [
        for (var index = 0; index < records.length; index++)
          if (records[index].paints > 0) index,
      ],
      [0, 1, 2, 3, 4, 5],
    );
    final elements = [for (final key in keys) tester.element(find.byKey(key, skipOffstage: false))];
    final states = [for (final record in records) record.state];
    final renders = [for (final record in records) record.render];
    final baseline = [for (final record in records) record.work];

    for (final scenario in [(first: 20, offset: 800.0), (first: 40, offset: 1600.0)]) {
      for (final record in records) {
        record.paints = 0;
        record.hitTests = 0;
      }
      controller.jumpTo(scenario.offset);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect([for (final record in records) record.work], baseline, reason: '普通滚动不能再次调用任何条目的 layout 或 build。');
      expect([
        for (var index = 0; index < records.length; index++)
          if (records[index].paints > 0) index,
      ], List.generate(6, (offset) => scenario.first + offset));
      for (var index = 0; index < records.length; index++) {
        expect(tester.element(find.byKey(keys[index], skipOffstage: false)), same(elements[index]));
        expect(records[index].state, same(states[index]));
        expect(records[index].render, same(renders[index]));
      }

      await tester.tapAt(Offset(60, 20));
      await tester.pump();
      expect(taps.last, scenario.first);
      final tested = [
        for (var index = 0; index < records.length; index++)
          if (records[index].hitTests > 0) index,
      ];
      expect(tested, isNotEmpty);
      expect(tested, everyElement(inInclusiveRange(scenario.first, scenario.first + 5)));
      expect([for (final record in records) record.work], baseline);
    }

    expect(taps, [20, 40]);
    await tester.pumpWidget(SizedBox.shrink());
    expect(records.map((record) => record.disposals), everyElement(1));
    expect(records.map((record) => record.renderDisposals), everyElement(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('自然尺寸、间距和居中在 SliverPadding 与前后 Sliver 中保持连续几何和命中', (tester) async {
    final controller = _setup(tester);
    final keys = [ValueKey('自然一'), ValueKey('自然二'), ValueKey('自然三')];
    final taps = <int>[];
    final sizes = [Size(100, 40), Size(140, 60), Size(80, 30)];
    await tester.pumpWidget(
      _page(controller, [
        SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(10, 12, 14, 16),
          sliver: ElSliverList(
            spacing: 8,
            center: true,
            children: [
              for (var index = 0; index < sizes.length; index++)
                SizedBox(
                  key: keys[index],
                  width: sizes[index].width,
                  height: sizes[index].height,
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps.add(index)),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(key: ValueKey('自然后续'), height: 100)),
      ]),
    );
    await _settle(tester);

    expect(tester.getRect(find.byKey(keys[0])), Rect.fromLTWH(108, 32, 100, 40));
    expect(tester.getRect(find.byKey(keys[1])), Rect.fromLTWH(88, 80, 140, 60));
    expect(tester.getRect(find.byKey(keys[2])), Rect.fromLTWH(118, 148, 80, 30));
    expect(tester.getRect(find.byKey(ValueKey('自然后续'))), Rect.fromLTWH(0, 194, 320, 100));
    expect(controller.position.maxScrollExtent, closeTo(54, .01));
    await tester.tapAt(Offset(150, 76));
    expect(taps, isEmpty, reason: '条目间距不能误命中相邻条目。');
    await tester.tapAt(tester.getCenter(find.byKey(keys[1])));
    expect(taps, [1]);

    controller.jumpTo(54);
    await tester.pump();
    expect(tester.getRect(find.byKey(ValueKey('自然后续'))), Rect.fromLTWH(0, 140, 320, 100));
    expect(tester.getRect(find.byKey(keys[2])), Rect.fromLTWH(118, 94, 80, 30));
    await tester.tapAt(tester.getCenter(find.byKey(keys[2])));
    expect(taps, [1, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL 按交叉轴起点排布，切换居中保留自然宽度和命中位置', (tester) async {
    final controller = _setup(tester);
    final taps = <int>[];
    final children = [
      SizedBox(
        key: ValueKey('RTL 一'),
        width: 80,
        height: 40,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps.add(0)),
      ),
      SizedBox(
        key: ValueKey('RTL 二'),
        width: 120,
        height: 60,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps.add(1)),
      ),
    ];
    Widget page(bool center) =>
        _page(controller, [ElSliverList(center: center, spacing: 6, children: children)], direction: TextDirection.rtl);

    await tester.pumpWidget(page(false));
    await _settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('RTL 一'))), Rect.fromLTWH(240, 0, 80, 40));
    expect(tester.getRect(find.byKey(ValueKey('RTL 二'))), Rect.fromLTWH(200, 46, 120, 60));
    await tester.tapAt(Offset(260, 76));
    expect(taps, [1]);

    await tester.pumpWidget(page(true));
    await _settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('RTL 一'))), Rect.fromLTWH(120, 0, 80, 40));
    expect(tester.getRect(find.byKey(ValueKey('RTL 二'))), Rect.fromLTWH(100, 46, 120, 60));
    await tester.tapAt(Offset(160, 20));
    expect(taps, [1, 0]);
  });

  testWidgets('横向反向滚动的自然尺寸、居中、变换和点击坐标一致', (tester) async {
    final controller = _setup(tester, size: Size(320, 200));
    final taps = <int>[];
    await tester.pumpWidget(
      _page(
        controller,
        [
          ElSliverList(
            spacing: 5,
            center: true,
            children: [
              SizedBox(
                key: ValueKey('反向一'),
                width: 180,
                height: 50,
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps.add(0)),
              ),
              SizedBox(
                key: ValueKey('反向二'),
                width: 180,
                height: 70,
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps.add(1)),
              ),
            ],
          ),
        ],
        axis: Axis.horizontal,
        reverse: true,
      ),
    );
    await _settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('反向一'))), Rect.fromLTWH(140, 75, 180, 50));
    expect(tester.getRect(find.byKey(ValueKey('反向二'))), Rect.fromLTWH(-45, 65, 180, 70));
    expect(controller.position.maxScrollExtent, closeTo(45, .01));
    await tester.tapAt(Offset(230, 100));
    await tester.tapAt(Offset(45, 100));
    expect(taps, [0, 1]);

    controller.jumpTo(35);
    await tester.pump();
    expect(tester.getRect(find.byKey(ValueKey('反向一'))), Rect.fromLTWH(175, 75, 180, 50));
    expect(tester.getRect(find.byKey(ValueKey('反向二'))), Rect.fromLTWH(-10, 65, 180, 70));
    await tester.tapAt(Offset(80, 100));
    expect(taps, [0, 1, 1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('子项局部变高与视口变窄会更新后续位置和总范围', (tester) async {
    final controller = _setup(tester);
    final height = ValueNotifier(40.0);
    addTearDown(height.dispose);
    final resident = ElSliverList(
      spacing: 8,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: height,
          builder: (_, value, _) => SizedBox(key: ValueKey('动态高度'), width: 120, height: value),
        ),
        SizedBox(key: ValueKey('固定尺寸'), width: 160, height: 50),
        Text(
          List.filled(10, 'natural width').join(' '),
          key: ValueKey('自然换行'),
          style: TextStyle(fontSize: 16, height: 1.25),
        ),
      ],
    );
    await tester.pumpWidget(
      _page(controller, [resident, SliverToBoxAdapter(child: SizedBox(key: ValueKey('动态后续'), height: 60))]),
    );
    await _settle(tester);
    final beforeTextHeight = tester.getSize(find.byKey(ValueKey('自然换行'))).height;
    expect(tester.getRect(find.byKey(ValueKey('固定尺寸'))).top, 48);
    expect(tester.getRect(find.byKey(ValueKey('自然换行'))).top, 106);

    height.value = 90;
    await _settle(tester);
    expect(tester.widget<ElSliverList>(find.byWidgetPredicate((widget) => widget is ElSliverList)), same(resident));
    expect(tester.getSize(find.byKey(ValueKey('动态高度'))), Size(120, 90));
    expect(tester.getRect(find.byKey(ValueKey('固定尺寸'))).top, 98);
    expect(tester.getRect(find.byKey(ValueKey('自然换行'))).top, 156);

    tester.view.physicalSize = Size(180, 240);
    await _settle(tester);
    final textRect = tester.getRect(find.byKey(ValueKey('自然换行')));
    // 页脚已被推到屏外，仍需校验它的真实布局位置。
    final footer = tester.getRect(find.byKey(ValueKey('动态后续'), skipOffstage: false));
    expect(tester.getSize(find.byKey(ValueKey('动态高度'))), Size(120, 90));
    expect(textRect.width, lessThanOrEqualTo(180));
    expect(textRect.height, greaterThan(beforeTextHeight));
    expect(textRect.top, 156);
    expect(footer.top, closeTo(textRect.bottom, .01));
    expect(controller.position.maxScrollExtent, closeTo(footer.bottom - 240, .01));

    height.value = 20;
    await _settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('固定尺寸'))).top, 28);
    expect(tester.getRect(find.byKey(ValueKey('自然换行'))).top, 86);
  });

  testWidgets('增删重排保留带键子项身份，间距更新与清空重新计算范围', (tester) async {
    final controller = _setup(tester);
    final records = List.generate(4, (_) => _Record());
    final heights = [40.0, 50.0, 60.0, 70.0];
    var order = [0, 1, 2];
    var spacing = 6.0;
    Widget page() => _page(controller, [
      ElSliverList(
        spacing: spacing,
        children: [
          for (final id in order) _ProbeItem(key: ValueKey('顺序 $id'), id: id, record: records[id], height: heights[id]),
        ],
      ),
    ]);
    await tester.pumpWidget(page());
    await _settle(tester);
    final retainedStates = [records[0].state, records[2].state];
    final retainedRenders = [records[0].render, records[2].render];
    final retainedElements = [
      tester.element(find.byKey(ValueKey('顺序 0'))),
      tester.element(find.byKey(ValueKey('顺序 2'))),
    ];

    order = [2, 0, 3];
    await tester.pumpWidget(page());
    await _settle(tester);
    expect(records[1].disposals, 1);
    expect(records[1].renderDisposals, 1);
    expect(records[3].mounts, 1);
    expect([records[0].state, records[2].state], retainedStates);
    expect([records[0].render, records[2].render], retainedRenders);
    expect(tester.element(find.byKey(ValueKey('顺序 0'))), same(retainedElements[0]));
    expect(tester.element(find.byKey(ValueKey('顺序 2'))), same(retainedElements[1]));
    expect(tester.getRect(find.byKey(ValueKey('顺序 2'))).top, 0);
    expect(tester.getRect(find.byKey(ValueKey('顺序 0'))).top, 66);
    expect(tester.getRect(find.byKey(ValueKey('顺序 3'))).top, 112);

    spacing = 10;
    await tester.pumpWidget(page());
    await _settle(tester);
    expect(tester.getRect(find.byKey(ValueKey('顺序 0'))).top, 70);
    expect(tester.getRect(find.byKey(ValueKey('顺序 3'))).top, 120);
    expect([records[0].state, records[2].state], retainedStates);

    order = [];
    await tester.pumpWidget(page());
    await _settle(tester);
    expect(find.byType(_ProbeItem, skipOffstage: false), findsNothing);
    expect(records.map((record) => record.disposals), everyElement(1));
    expect(controller.position.maxScrollExtent, 0);
  });

  testWidgets('ensureVisible 能定位从未显示但已经挂载的远处子项', (tester) async {
    final controller = _setup(tester);
    final target = GlobalKey();
    final records = List.generate(80, (_) => _Record());
    await tester.pumpWidget(
      _page(controller, [
        ElSliverList(
          children: [
            for (var index = 0; index < records.length; index++)
              _ProbeItem(key: index == 75 ? target : ValueKey(index), id: index, record: records[index]),
          ],
        ),
      ]),
    );
    await _settle(tester);
    expect(target.currentContext, isNotNull);
    expect(tester.getRect(find.byKey(target)).top, 3000);
    expect(records[75].mounts, 1);
    final before = [for (final record in records) record.work];

    await Scrollable.ensureVisible(target.currentContext!, alignment: .5, duration: Duration.zero);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.offset, closeTo(2900, .01));
    expect(tester.getRect(find.byKey(target)), Rect.fromLTWH(0, 100, 120, 40));
    expect([for (final record in records) record.work], before);
    expect(records.map((record) => record.mounts), everyElement(1));
  });

  testWidgets('SelectionArea 全选包含从未滚入视口的离屏段落并保持文档顺序', (tester) async {
    final controller = _setup(tester);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final keys = List.generate(24, (_) => GlobalKey());
    final labels = List.generate(24, (index) => '段落 [$index]');
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: SelectionArea(
          focusNode: focus,
          onSelectionChanged: (content) => selected = content?.plainText,
          child: CustomScrollView(
            controller: controller,
            physics: ClampingScrollPhysics(),
            scrollCacheExtent: ScrollCacheExtent.pixels(0),
            slivers: [
              ElSliverList(
                children: [
                  for (var index = 0; index < labels.length; index++)
                    SizedBox(
                      height: 64,
                      child: Text(labels[index], key: keys[index], style: TextStyle(fontSize: 16)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(keys.last.currentContext, isNotNull);
    expect(tester.getRect(find.byKey(keys.last)).top, greaterThan(240));
    expect(controller.offset, 0);

    focus.requestFocus();
    await tester.pump();
    // 使用官方全选意图，验证完整选择注册链，不直接读取或拼接业务文本。
    Actions.invoke(keys.first.currentContext!, SelectAllTextIntent(SelectionChangedCause.keyboard));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(selected, isNotNull);
    var previous = -1;
    for (final label in labels) {
      final position = selected!.indexOf(label);
      expect(position, greaterThan(previous), reason: '全选结果应包含全部常驻段落并保持顺序：$label');
      previous = position;
    }
    expect(controller.offset, 0, reason: '离屏段落不需要先滚入视口才能参与全选。');

    await tester.pumpWidget(SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
