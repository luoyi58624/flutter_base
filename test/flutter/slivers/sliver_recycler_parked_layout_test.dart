import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver, ScrollCacheExtent;
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _Record extends ChangeNotifier {
  _Record(int index) : label = 'record $index';

  String label;
  double height = 240;

  void update({required String label, required double height}) {
    this.label = label;
    this.height = height;
    notifyListeners();
  }
}

class _Log {
  final live = <_NestedLayoutState>{};
  int created = 0;
  int disposed = 0;
}

class _NestedLayout extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _NestedLayout({required this.index, required this.records, required this.log});

  final ValueListenable<int> index;
  final List<_Record> records;
  final _Log log;

  @override
  State<_NestedLayout> createState() => _NestedLayoutState();
}

class _NestedLayoutState extends State<_NestedLayout> {
  late _Record _record;
  final bodyKey = GlobalKey();
  bool tickerEnabled = true;
  int layouts = 0;

  @override
  void initState() {
    super.initState();
    widget.log.created++;
    widget.log.live.add(this);
    _record = widget.records[widget.index.value]..addListener(_refresh);
    widget.index.addListener(_bind);
  }

  void _bind() {
    final next = widget.records[widget.index.value];
    if (!identical(next, _record)) {
      _record.removeListener(_refresh);
      _record = next..addListener(_refresh);
    }
    _refresh();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => TickerMode(
      enabled: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 根部保留自然高度，紧约束会提前建立布局边界，掩盖停放后的父依赖问题。
          LayoutBuilder(
            builder: (context, constraints) {
              tickerEnabled = TickerMode.valuesOf(context).enabled;
              layouts++;
              return SizedBox(
                key: bodyKey,
                height: _record.height,
                child: Center(child: Text(_record.label)),
              );
            },
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    widget.index.removeListener(_bind);
    _record.removeListener(_refresh);
    widget.log.live.remove(this);
    widget.log.disposed++;
    super.dispose();
  }
}

Future<void> _settle(WidgetTester tester) =>
    tester.pumpAndSettle(Duration(milliseconds: 16), EnginePhase.sendSemanticsUpdate, Duration(seconds: 3));

void main() {
  for (final masonry in [false, true]) {
    final name = masonry ? 'Masonry' : 'List';
    testWidgets('$name 停放的自然高嵌套 LayoutBuilder 独立布局，复用后恢复父尺寸依赖', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(320, 240);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = ScrollController();
      final count = ValueNotifier(10);
      final records = List.generate(10, _Record.new);
      final log = _Log();
      addTearDown(controller.dispose);
      addTearDown(count.dispose);
      addTearDown(() {
        for (final record in records) {
          record.dispose();
        }
      });

      Widget row(BuildContext context, ValueListenable<int> index) =>
          _NestedLayout(index: index, records: records, log: log);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<int>(
            valueListenable: count,
            builder: (context, value, child) => CustomScrollView(
              controller: controller,
              scrollCacheExtent: ScrollCacheExtent.pixels(0),
              slivers: [
                if (masonry)
                  ElSliverRecyclerGrid.masonry(
                    crossAxisCount: 1,
                    itemCount: value,
                    itemType: (index) => index % 2,
                    maxRecycledItems: 2,
                    itemBuilder: row,
                  )
                else
                  ElSliverRecyclerList(
                    itemCount: value,
                    itemType: (index) => index % 2,
                    maxRecycledItems: 2,
                    itemBuilder: row,
                  ),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      final original = log.live.singleWhere((state) => state.widget.index.value == 0);
      final originalWidget = original.widget;
      final originalElement = original.context;
      final originalRender = original.context.findRenderObject();
      expect(original.tickerEnabled, isTrue);
      expect(tester.getSize(find.byKey(original.bodyKey)).height, 240);

      controller.jumpTo(240);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(original.mounted, isTrue);
      expect(original.widget.index.value, 0);
      expect(original.tickerEnabled, isFalse);
      expect(find.text('record 1').hitTestable(), findsOneWidget);
      final render = tester.renderObject<RenderSliver>(
        find.byType(masonry ? ElSliverRecyclerGrid : ElSliverRecyclerList),
      );
      final beforeParkedUpdate = render.geometry!;
      final visible = log.live.singleWhere((state) => state.widget.index.value == 1);
      final visibleRect = tester.getRect(find.byKey(visible.bodyKey));
      final parkedLayouts = original.layouts;

      records[0].update(label: 'parked update', height: 300);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(original.layouts, greaterThan(parkedLayouts));
      expect(tester.getSize(find.byKey(original.bodyKey, skipOffstage: false)).height, 300);
      expect(original.tickerEnabled, isFalse);
      expect(controller.offset, 240);
      expect(render.geometry!.scrollExtent, beforeParkedUpdate.scrollExtent);
      expect(render.geometry!.paintExtent, beforeParkedUpdate.paintExtent);
      expect(render.geometry!.layoutExtent, beforeParkedUpdate.layoutExtent);
      expect(tester.getRect(find.byKey(visible.bodyKey)), visibleRect);
      expect(find.text('parked update', skipOffstage: false).hitTestable(), findsNothing);

      controller.jumpTo(480);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final rebound = log.live.singleWhere((state) => state.widget.index.value == 2);
      expect(rebound, same(original));
      expect(rebound.widget, same(originalWidget));
      expect(rebound.context, same(originalElement));
      expect(rebound.context.findRenderObject(), same(originalRender));
      expect(rebound.tickerEnabled, isTrue);
      expect(find.text('record 2').hitTestable(), findsOneWidget);
      expect(tester.getSize(find.byKey(rebound.bodyKey)).height, 240);
      expect(controller.offset, 480);
      final beforeActiveUpdate = render.geometry!.scrollExtent;

      records[2].update(label: 'active update', height: 300);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(rebound.bodyKey)).height, 300);
      expect(render.geometry!.scrollExtent, greaterThan(beforeActiveUpdate));
      expect(controller.offset, 480);
      controller.jumpTo(600);
      await _settle(tester);
      final following = log.live.singleWhere((state) => state.widget.index.value == 3);
      expect(tester.getTopLeft(find.byKey(following.bodyKey)).dy, 180);

      count.value = 0;
      await _settle(tester);
      expect(log.live, isEmpty);
      expect(log.disposed, log.created);
      expect(original.mounted, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox.shrink());
    });
  }
}
