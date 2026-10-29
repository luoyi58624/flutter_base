import 'dart:typed_data';

import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final Uint8List _png = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);

void main() {
  test('冷启动与向下滚动按扁平索引从上到下、同行从左到右取槽', () async {
    final indices = List<int>.generate(15, (index) => index);
    final order = await ImageDecodePipeline.debugScheduleDecodePriorities(indices, forward: true);
    expect(order, indices);
    expect(order.take(5), <int>[0, 1, 2, 3, 4], reason: '5 列网格第一列不得落后于同排其余列');
  });

  test('向上滚动按扁平索引从下到上取槽', () async {
    final indices = List<int>.generate(15, (index) => index);
    final order = await ImageDecodePipeline.debugScheduleDecodePriorities(indices, forward: false);
    expect(order, indices.reversed);
  });

  test('旧队列仍积压时反向，无需新请求也立即重排', () async {
    final indices = List<int>.generate(10, (index) => index);
    final order = await ImageDecodePipeline.debugScheduleDecodePriorities(
      indices,
      forward: true,
      reverseAfterStarts: 1,
    );
    expect(order, <int>[0, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
  });

  test('可见图片始终先于 cacheExtent 预挂载图片，同级仍服从方向', () async {
    final indices = List<int>.generate(15, (index) => index);
    final order = await ImageDecodePipeline.debugScheduleDecodePriorities(
      indices,
      forward: true,
      visibleIndices: <int>{5, 6, 7, 8, 9},
    );
    expect(order.take(5), <int>[5, 6, 7, 8, 9]);
    expect(order.skip(5), <int>[0, 1, 2, 3, 4, 10, 11, 12, 13, 14]);
  });

  test('等待队列中部的图片新进入可见区后立即晋级', () async {
    final visible = <int>{0};
    final indices = List<int>.generate(10, (index) => index);
    final order = await ImageDecodePipeline.debugScheduleDecodePriorities(
      indices,
      forward: true,
      visibleIndices: visible,
      onStarted: (count) {
        if (count == 1) visible.add(5);
      },
    );
    expect(order, <int>[0, 5, 1, 2, 3, 4, 6, 7, 8, 9]);
  });

  testWidgets('虚拟网格把初始、下滚、上滚方向实时传给 ElImageView', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    ImageDecodePipeline.instance.debugClear();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 400,
          child: ElScrollView(
            controller: controller,
            children: [
              ElGridView.builder(
                crossAxisCount: 5,
                mainAxisExtent: 80,
                itemCount: 100,
                itemBuilder: (_, index) =>
                    ElImageView.memory(_png, key: ValueKey('image-$index'), width: 80, height: 80),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_renderOf(tester, 4).debugDecodePriority, 4, reason: '冷启动默认向下');

    controller.jumpTo(800);
    await tester.pump();
    expect(_renderOf(tester, 50).debugDecodePriority, 50, reason: '向下滚保持小 index 优先');

    controller.jumpTo(320);
    await tester.pump();
    expect(_renderOf(tester, 20).debugDecodePriority, -20, reason: '向上滚切为大 index 优先');
  });
}

RenderImageView _renderOf(WidgetTester tester, int index) {
  return tester.renderObject<RenderImageView>(find.byKey(ValueKey('image-$index'), skipOffstage: false));
}
