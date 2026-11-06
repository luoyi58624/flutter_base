import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final distance in [1.0, 250.0]) {
    testWidgets('滚动${distance}px只更新列表自身，外部静态内容不重画且条目绘制仍正确', (tester) async {
      final controller = ScrollController();
      final rows = _Rows();
      final outside = _PaintCount();
      final layout = rv.LinearLayoutManager()..setItemPrefetchEnabled(false);
      final list = rv.RecyclerView(controller: controller)
        ..setAdapter(rows)
        ..setLayoutManager(layout)
        ..setItemViewCacheSize(0);
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Align(
            alignment: .topLeft,
            child: RepaintBoundary(
              child: _PaintProbe(
                outside,
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: ScrollConfiguration(behavior: _NoChrome(), child: list),
                ),
              ),
            ),
          ),
        ),
      );
      controller.jumpTo(.1);
      await tester.pump();
      outside.paints = 0;
      for (final row in rows.holders) {
        row.paints.paints = 0;
      }
      final firstBefore = layout.findFirstVisibleItemPosition();
      controller.jumpTo(.1 + distance);
      await tester.pump();
      expect(outside.paints, 0, reason: '视口滚动不能让未变化的祖先和其它页面内容一起重画');
      final painted = rows.holders.fold(0, (sum, row) => sum + row.paints.paints);
      if (distance < 50) {
        expect(painted, 0, reason: '每项独立边界继续复用已有正文的绘制结果');
        expect(layout.findFirstVisibleItemPosition(), firstBefore);
      } else {
        expect(painted, greaterThan(0), reason: '换绑后的真实新文字仍须绘制，不能冻结条目来降低计数');
        expect(find.text('记录 5').hitTestable(), findsOneWidget);
        expect(find.text('记录 9').hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
      controller.dispose();
      for (final row in rows.holders) {
        row.value.dispose();
      }
    });
  }
}

class _NoChrome extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

class _PaintCount {
  int paints = 0;
}

class _PaintProbe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _PaintProbe(this.count, {required super.child});
  final _PaintCount count;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaintProbe(count);
}

class _RenderPaintProbe extends RenderProxyBox {
  _RenderPaintProbe(this.count);
  final _PaintCount count;

  @override
  void paint(PaintingContext context, Offset offset) {
    count.paints++;
    super.paint(context, offset);
  }
}

class _Rows extends rv.Adapter<_Holder> {
  final holders = <_Holder>[];

  @override
  int getItemCount() => 10000;
  @override
  _Holder onCreateViewHolder(rv.RecyclerView parent, int viewType) {
    final holder = _Holder(ValueNotifier(-1), _PaintCount());
    holders.add(holder);
    return holder;
  }

  @override
  void onBindViewHolder(_Holder holder, int position, [List<Object> payloads = const []]) =>
      holder.value.value = position;
}

class _Holder extends rv.ViewHolder {
  _Holder(this.value, this.paints)
    : super(
        _PaintProbe(
          paints,
          child: ValueListenableBuilder(
            valueListenable: value,
            builder: (_, position, _) => SizedBox(height: 50, child: Text('记录 $position')),
          ),
        ),
      );
  final ValueNotifier<int> value;
  final _PaintCount paints;
}
