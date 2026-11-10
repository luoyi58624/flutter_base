import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
