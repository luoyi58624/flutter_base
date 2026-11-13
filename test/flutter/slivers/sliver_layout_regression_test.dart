import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/views/scroll/sliver/internal/builder.dart';
import 'package:flutter_base/src/flutter/views/scroll/sliver/internal/layout.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

class _LayoutWork {
  int candidates = 0;
  int queries = 0;
  int measurements = 0;
}

// 在真实布局算法外记录候选工作量，不把诊断计数加入组件 API。
class _CountedSpec extends SliverLayoutSpec {
  // ignore: prefer_const_constructors_in_immutables
  _CountedSpec(this.delegate, this.work);

  final SliverLayoutSpec delegate;
  final _LayoutWork work;

  @override
  SliverLayout createLayout() => _CountedLayout(delegate.createLayout(), work);
}

class _CountedLayout extends SliverLayout {
  _CountedLayout(this.delegate, this.work);

  final SliverLayout delegate;
  final _LayoutWork work;

  @override
  void rebuild(int count, List<Object?> types, SliverConstraints constraints) =>
      delegate.sync(count, types, constraints, force: true);

  @override
  bool get usesEstimates => delegate.usesEstimates;

  @override
  bool get orderedPositions => delegate.orderedPositions;

  @override
  BoxConstraints childConstraints(SliverConstraints constraints) => delegate.childConstraints(constraints);

  @override
  double get total => delegate.total;

  @override
  double startOf(int index) => delegate.startOf(index);

  @override
  double crossOf(int index, Size childSize, SliverConstraints constraints) =>
      delegate.crossOf(index, childSize, constraints);

  @override
  List<int> indicesIn(double start, double end) {
    final result = delegate.indicesIn(start, end);
    work.queries++;
    work.candidates += result.length;
    return result;
  }

  @override
  (int, int) unitOf(int index) => delegate.unitOf(index);

  @override
  bool measure(int index, double extent) {
    work.measurements++;
    return delegate.measure(index, extent);
  }

  @override
  int? anchorAt(double pixels) => delegate.anchorAt(pixels);

  @override
  void beginRetain() => delegate.beginRetain();

  @override
  void retain(int index) => delegate.retain(index);
}

class _CountedSliver extends BuilderSliver {
  _CountedSliver(BuilderSliver original, _LayoutWork work)
    : spec = _CountedSpec(original.spec, work),
      super(delegate: original.delegate, childCount: original.childCount, itemType: original.itemType);

  @override
  final SliverLayoutSpec spec;
}

void _size(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(320, 240);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  for (final kind in ['list', 'grid', 'masonry']) {
    testWidgets('$kind children 只切换 RTL 也更新可见与离屏条目的交叉轴坐标', (tester) async {
      _size(tester);
      final children = [for (var index = 0; index < 20; index++) SizedBox(key: ValueKey(index), width: 80, height: 40)];
      final sliver = switch (kind) {
        'list' => ElSliverList(children: children),
        'grid' => ElSliverGrid(crossAxisCount: 2, children: children),
        _ => ElSliverMasonry(crossAxisCount: 2, children: children),
      };
      final scroll = CustomScrollView(scrollCacheExtent: ScrollCacheExtent.pixels(0), slivers: [sliver]);
      Widget host(TextDirection direction) => Directionality(textDirection: direction, child: scroll);

      await tester.pumpWidget(host(.ltr));
      final initial = [
        for (final index in [0, 19]) tester.getRect(find.byKey(ValueKey(index))),
      ];
      expect(initial.first.left, 0);

      // 保留相同的滚动容器、Sliver 和固定盒子，只让视口接收新的交叉轴方向。
      await tester.pumpWidget(host(.rtl));
      for (var i = 0; i < 2; i++) {
        final actual = tester.getRect(find.byKey(ValueKey(i == 0 ? 0 : 19)));
        expect(actual, Rect.fromLTWH(320 - initial[i].right, initial[i].top, initial[i].width, initial[i].height));
      }

      await tester.pumpWidget(host(.ltr));
      expect(tester.getRect(find.byKey(ValueKey(0))), initial.first);
      expect(tester.getRect(find.byKey(ValueKey(19))), initial.last);
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in ['list', 'grid']) {
    testWidgets('$kind 自然尺寸补测不会反复生成和扫描零高条目的完整前缀', (tester) async {
      _size(tester);
      final work = _LayoutWork();
      final count = 240;
      var built = 0;
      Widget item(BuildContext context, int index) {
        built++;
        return SizedBox(key: ValueKey(index), height: 0);
      }

      final original = switch (kind) {
        'list' => ElSliverList.builder(itemCount: count, itemBuilder: item),
        _ => ElSliverGrid.builder(crossAxisCount: 3, itemCount: count, itemBuilder: item),
      } as BuilderSliver;
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: CustomScrollView(
            controller: controller,
            scrollCacheExtent: ScrollCacheExtent.pixels(0),
            slivers: [_CountedSliver(original, work)],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(built, count);
      expect(controller.position.maxScrollExtent, 0);
      expect(work.measurements, lessThanOrEqualTo(count * 2));
      expect(
        work.candidates,
        lessThanOrEqualTo(count * 4),
        reason: '候选项累计 ${work.candidates}，查询 ${work.queries} 次；补测应按条目或整行推进，不能反复扫描已测前缀。',
      );
    });
  }
}
