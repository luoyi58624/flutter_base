import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _Log {
  int created = 0;
  int disposed = 0;
}

class _Cell extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Cell(this.index, this.log, {super.key});
  final ValueListenable<int> index;
  final _Log log;
  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  @override
  void initState() {
    super.initState();
    widget.log.created++;
  }

  @override
  void dispose() {
    widget.log.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: widget.index,
    builder: (_, index, _) => SizedBox(
      height: 30.0 + index % 3 * 20,
      child: Text('item $index', textDirection: TextDirection.ltr),
    ),
  );
}

Widget _host(Widget sliver, ScrollController controller) => Directionality(
  textDirection: TextDirection.ltr,
  child: CustomScrollView(controller: controller, scrollCacheExtent: ScrollCacheExtent.pixels(0), slivers: [sliver]),
);

void _size(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(360, 240);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _Kept extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Kept({super.key});
  @override
  State<_Kept> createState() => _KeptState();
}

class _KeptState extends State<_Kept> with AutomaticKeepAliveClientMixin {
  bool keep = true;
  @override
  bool get wantKeepAlive => keep;
  void release() {
    keep = false;
    updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox(height: 50, child: Text('kept'));
  }
}

void main() {
  for (final layout in ['list', 'grid', 'masonry']) {
    testWidgets('$layout builder 响应子项自然高度变化，保留已挂载业务状态', (tester) async {
      _size(tester);
      final controller = ScrollController();
      final height = ValueNotifier(40.0);
      addTearDown(controller.dispose);
      addTearDown(height.dispose);
      var firstBuilds = 0;
      Widget item(BuildContext context, int index) {
        if (index == 0) firstBuilds++;
        return LayoutBuilder(
          builder: (_, constraints) => index == 0
              ? ValueListenableBuilder<double>(
                  valueListenable: height,
                  builder: (_, value, _) => SizedBox(height: value, child: Text('row 0')),
                )
              : SizedBox(height: 40, child: Text('row $index')),
        );
      }

      final sliver = switch (layout) {
        'list' => ElSliverList.builder(itemCount: 1000, spacing: 5, itemBuilder: item),
        'grid' => ElSliverGrid.builder(itemCount: 1000, crossAxisCount: 2, mainAxisSpacing: 5, itemBuilder: item),
        _ => ElSliverMasonry.builder(itemCount: 1000, crossAxisCount: 2, mainAxisSpacing: 5, itemBuilder: item),
      };
      await tester.pumpWidget(_host(sliver, controller));
      final first = tester.element(find.text('row 0'));
      final next = find.text(layout == 'list' ? 'row 1' : 'row 2');
      expect(tester.getTopLeft(next).dy, 45);
      height.value = 100;
      await tester.pump();
      expect(tester.getTopLeft(next).dy, 105);
      expect(tester.element(find.text('row 0')), same(first));
      expect(firstBuilds, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final layout in ['list', 'grid', 'masonry']) {
    for (final mode in ['children', 'builder', 'recycler']) {
      testWidgets('$layout $mode 生命周期、自然尺寸与远跳', (tester) async {
        _size(tester);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final log = _Log();
        Widget item(BuildContext context, int i) => _Cell(AlwaysStoppedAnimation(i), log, key: ValueKey(i));
        Widget recycled(BuildContext context, ValueListenable<int> i) => _Cell(i, log);
        final sliver = switch ((layout, mode)) {
          ('list', 'children') => ElSliverList(
            spacing: 5,
            children: List.generate(1000, (i) => _Cell(AlwaysStoppedAnimation(i), log, key: ValueKey(i))),
          ),
          ('list', 'builder') => ElSliverList.builder(itemCount: 1000, itemBuilder: item, spacing: 5),
          ('list', _) => ElSliverList.recycler(itemCount: 1000, itemBuilder: recycled, spacing: 5),
          ('grid', 'children') => ElSliverGrid(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 8,
            children: List.generate(1000, (i) => _Cell(AlwaysStoppedAnimation(i), log, key: ValueKey(i))),
          ),
          ('grid', 'builder') => ElSliverGrid.builder(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 8,
            itemCount: 1000,
            itemBuilder: item,
          ),
          ('grid', _) => ElSliverGrid.recycler(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 8,
            itemCount: 1000,
            itemBuilder: recycled,
          ),
          (_, 'children') => ElSliverMasonry(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 8,
            children: List.generate(1000, (i) => _Cell(AlwaysStoppedAnimation(i), log, key: ValueKey(i))),
          ),
          (_, 'builder') => ElSliverMasonry.builder(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 8,
            itemCount: 1000,
            itemBuilder: item,
          ),
          _ => ElSliverMasonry.recycler(
            crossAxisCount: 2,
            mainAxisSpacing: 5,
            crossAxisSpacing: 8,
            itemCount: 1000,
            itemBuilder: recycled,
          ),
        };
        await tester.pumpWidget(_host(sliver, controller));
        expect(tester.takeException(), isNull);
        final created = log.created;
        expect(created, mode == 'children' ? 1000 : lessThan(30));
        if (layout == 'list') expect(tester.getTopLeft(find.text('item 1')).dy, 35);
        if (layout == 'grid') expect(tester.getTopLeft(find.text('item 2')).dy, 55);
        if (layout == 'masonry') expect(tester.getTopLeft(find.text('item 2')).dy, 35);
        controller.jumpTo(10000);
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (mode == 'builder') {
          expect(log.disposed, greaterThan(0));
          expect(log.created, lessThan(70), reason: '远跳只构建新窗口，不能构建全部前置子项。');
        } else {
          expect(log.disposed, 0);
          if (mode == 'children') expect(log.created, created);
        }
        controller.jumpTo(0);
        await tester.pump();
        await tester.pump();
        expect(find.text('item 0'), findsOneWidget);
        expect(tester.getTopLeft(find.text('item 0')).dy, closeTo(0, .01));
        await tester.pumpWidget(SizedBox.shrink());
        expect(log.disposed, log.created);
      });
    }
  }

  for (final kind in ['list', 'grid', 'masonry']) {
    for (final mode in ['children', 'builder', 'recycler']) {
      testWidgets('$kind $mode 重绘和语义开关可关闭，仅 builder 自动保活', (tester) async {
        _size(tester);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        Widget item(BuildContext context, int index) => SizedBox(height: 50, child: Text('cell $index'));
        Widget recycled(BuildContext context, ValueListenable<int> index) =>
            ValueListenableBuilder<int>(valueListenable: index, builder: (context, value, _) => item(context, value));
        Widget content(bool enabled) {
          final children = List.generate(3, (index) => SizedBox(height: 50, child: Text('cell $index')));
          return switch ((kind, mode)) {
            ('list', 'children') => ElSliverList(
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
              children: children,
            ),
            ('list', 'builder') => ElSliverList.builder(
              itemCount: 3,
              itemBuilder: item,
              addAutomaticKeepAlives: enabled,
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
            ),
            ('list', _) => ElSliverList.recycler(
              itemCount: 3,
              itemBuilder: recycled,
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
            ),
            ('grid', 'children') => ElSliverGrid(
              crossAxisCount: 2,
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
              children: children,
            ),
            ('grid', 'builder') => ElSliverGrid.builder(
              crossAxisCount: 2,
              itemCount: 3,
              itemBuilder: item,
              addAutomaticKeepAlives: enabled,
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
            ),
            ('grid', _) => ElSliverGrid.recycler(
              crossAxisCount: 2,
              itemCount: 3,
              itemBuilder: recycled,
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
            ),
            (_, 'children') => ElSliverMasonry(
              crossAxisCount: 2,
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
              children: children,
            ),
            (_, 'builder') => ElSliverMasonry.builder(
              crossAxisCount: 2,
              itemCount: 3,
              itemBuilder: item,
              addAutomaticKeepAlives: enabled,
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
            ),
            _ => ElSliverMasonry.recycler(
              crossAxisCount: 2,
              itemCount: 3,
              itemBuilder: recycled,
              addRepaintBoundaries: enabled,
              addSemanticIndexes: enabled,
            ),
          };
        }

        for (final enabled in [true, false, true]) {
          final sliver = content(enabled);
          await tester.pumpWidget(_host(sliver, controller));
          final root = find.byWidget(sliver);
          expect(
            find.descendant(of: root, matching: find.byType(AutomaticKeepAlive)),
            enabled && mode == 'builder' ? findsNWidgets(3) : findsNothing,
          );
          expect(
            find.descendant(of: root, matching: find.byType(IndexedSemantics)),
            enabled ? findsNWidgets(3) : findsNothing,
          );
          final boxes = <RenderObject>[];
          tester.renderObject(root).visitChildren(boxes.add);
          expect(boxes, hasLength(3));
          bool hasBoundary(RenderObject box) {
            if (box.isRepaintBoundary) return true;
            var found = false;
            box.visitChildren((child) {
              found |= hasBoundary(child);
            });
            return found;
          }

          expect(boxes.every((box) => hasBoundary(box) == enabled), isTrue);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final keepAlive in [false, true]) {
    testWidgets('builder KeepAlive=$keepAlive 保活、回访和主动释放', (tester) async {
      _size(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final sliver = ElSliverList.builder(
        itemCount: 100,
        addAutomaticKeepAlives: keepAlive,
        itemBuilder: (_, index) => index == 0 ? _Kept() : SizedBox(height: 50),
      );
      await tester.pumpWidget(_host(sliver, controller));
      final state = tester.state<_KeptState>(find.byType(_Kept));
      controller.jumpTo(1000);
      await tester.pump();
      expect(state.mounted, keepAlive);
      controller.jumpTo(0);
      await tester.pump();
      expect(identical(tester.state(find.byType(_Kept)), state), keepAlive);
      if (keepAlive) {
        controller.jumpTo(1000);
        await tester.pump();
        state.release();
        await tester.pump();
        await tester.pump();
        expect(state.mounted, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('separated 自然分隔符、无尾间隔与业务语义索引', (tester) async {
    _size(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(
        ElSliverList.separated(
          itemCount: 3,
          itemBuilder: (_, i) => SizedBox(height: 30, child: Text('row $i')),
          separatorBuilder: (_, i) => SizedBox(height: 7.0 + i, child: Text('separator $i')),
        ),
        controller,
      ),
    );
    expect(tester.getTopLeft(find.text('row 1')).dy, 37);
    expect(tester.getTopLeft(find.text('row 2')).dy, 75);
    expect(find.text('separator 2'), findsNothing);
    expect(tester.widgetList<IndexedSemantics>(find.byType(IndexedSemantics)).map((w) => w.index), [0, 1, 2]);
  });

  testWidgets('builder 保留显式 KeepAlive，重排后跟随业务 Key', (tester) async {
    _size(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final ids = List.generate(100, (i) => i);
    Widget content() => _host(
      ElSliverList.builder(
        itemCount: ids.length,
        findChildIndexCallback: (key) => ids.indexOf((key as ValueKey<int>).value),
        itemBuilder: (_, i) => ids[i] == 0 ? _Kept(key: ValueKey(0)) : SizedBox(key: ValueKey(ids[i]), height: 50),
      ),
      controller,
    );
    await tester.pumpWidget(content());
    final state = tester.state(find.byType(_Kept));
    controller.jumpTo(1000);
    await tester.pump();
    expect(state.mounted, isTrue);
    controller.jumpTo(0);
    await tester.pump();
    expect(tester.state(find.byType(_Kept)), same(state));
    ids[0] = 1;
    ids[1] = 0;
    await tester.pumpWidget(content());
    expect(tester.state(find.byType(_Kept)), same(state));
    expect(tester.getTopLeft(find.text('kept')).dy, 50);
    expect(tester.takeException(), isNull);
  });
}
