import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _Log {
  int mounts = 0;
  int disposals = 0;
  final live = <_RowState>{};
}

class _Row extends StatefulWidget {
  _Row(this.index, this.log, this.extent, {super.key});

  final int index;
  final _Log log;
  final double extent;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  @override
  void initState() {
    super.initState();
    widget.log.mounts++;
    widget.log.live.add(this);
  }

  @override
  void dispose() {
    widget.log.live.remove(this);
    widget.log.disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: widget.extent, child: Text('项 ${widget.index}'));
  }
}

void main() {
  testWidgets('不定高条目按实测总长滚动，换绑更新原 State', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(320, 240);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final log = _Log();
    const extents = [20.0, 40.0, 60.0];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElRecyclerView2(
          controller: controller,
          itemCount: 30,
          maxRecycledItems: 0,
          cacheExtent: 0,
          itemType: (index) => index % extents.length,
          itemBuilder: (context, index) => _Row(index, log, extents[index % extents.length]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('项 0'), findsOneWidget);
    final position = controller.position;
    expect(position.maxScrollExtent + position.viewportDimension, 20 * 10 + 40 * 10 + 60 * 10);
    final mountedAtStart = log.mounts;

    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(find.text('项 29'), findsOneWidget);
    expect(log.mounts, mountedAtStart);
    expect(log.disposals, 0);
    expect(log.live.any((state) => state.widget.index == 29), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('根控件 Key 随序号变化时不能复用 State', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(320, 200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final log = _Log();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElRecyclerView2(
          controller: controller,
          itemCount: 20,
          maxRecycledItems: 0,
          cacheExtent: 0,
          itemBuilder: (context, index) => _Row(index, log, 50),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final stableMounts = log.mounts;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElRecyclerView2(
          controller: controller,
          itemCount: 20,
          maxRecycledItems: 0,
          cacheExtent: 0,
          itemBuilder: (context, index) => _Row(index, log, 50, key: ValueKey(index)),
        ),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(log.mounts, greaterThan(stableMounts));
    expect(log.disposals, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
