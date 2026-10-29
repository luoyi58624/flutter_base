import 'package:flutter_base/src/ui/cores/image/image_prefetch_controller.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('方向预取从 mounted 边界向滚动方向推进，不回头争抢可见图片', () async {
    final requested = <String>[];
    ImagePrefetchController.debugForceEnabled = true;
    ImagePrefetchController.debugPreloadOverride = (source, _, _, _) async => requested.add(source);
    final controller = ImagePrefetchController(workerCount: 1, lookAhead: Duration.zero);
    try {
      controller.update(
        first: 0,
        last: 5,
        mountedFirst: 0,
        mountedLast: 10,
        sources: [for (var i = 0; i < 40; i++) '$i.jpg'],
        size: const Size.square(50),
        devicePixelRatio: 1,
      );
      await Future<void>.delayed(Duration.zero);
      expect(requested, isEmpty, reason: '初次布局不得启动预取与首屏争槽');
      controller.update(
        first: 1,
        last: 6,
        mountedFirst: 0,
        mountedLast: 11,
        sources: [for (var i = 0; i < 40; i++) '$i.jpg'],
        size: const Size.square(50),
        devicePixelRatio: 1,
      );
      final timeout = Stopwatch()..start();
      while (controller.debugCompleted < 20 && timeout.elapsed < const Duration(seconds: 2)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(controller.debugCompleted, 20);
      expect(requested, [for (var i = 11; i < 31; i++) '$i.jpg']);
    } finally {
      controller.dispose();
      ImagePrefetchController.debugForceEnabled = false;
      ImagePrefetchController.debugPreloadOverride = null;
    }
  });

  test('跨屏瞬移取消跳过区域预取，连续滚动后再恢复', () async {
    final requested = <String>[];
    ImagePrefetchController.debugForceEnabled = true;
    ImagePrefetchController.debugPreloadOverride = (source, _, _, _) async => requested.add(source);
    final controller = ImagePrefetchController(workerCount: 1, lookAhead: Duration.zero);
    final sources = [for (var i = 0; i < 100; i++) '$i.jpg'];
    try {
      controller.update(
        first: 0,
        last: 10,
        mountedFirst: 0,
        mountedLast: 15,
        sources: sources,
        size: const Size.square(50),
        devicePixelRatio: 1,
      );
      controller.update(
        first: 60,
        last: 70,
        mountedFirst: 55,
        mountedLast: 75,
        sources: sources,
        size: const Size.square(50),
        devicePixelRatio: 1,
      );
      await Future<void>.delayed(Duration.zero);
      expect(requested, isEmpty, reason: '滚动条跳过的区域不得启动方向预取');

      await Future<void>.delayed(const Duration(milliseconds: 210));
      controller.update(
        first: 61,
        last: 71,
        mountedFirst: 56,
        mountedLast: 76,
        sources: sources,
        size: const Size.square(50),
        devicePixelRatio: 1,
      );
      final timeout = Stopwatch()..start();
      while (controller.debugCompleted < 24 && timeout.elapsed < const Duration(seconds: 2)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(requested, [for (var i = 76; i < 100; i++) '$i.jpg']);

      controller.update(
        first: 60,
        last: 70,
        mountedFirst: 55,
        mountedLast: 75,
        sources: sources,
        size: const Size.square(50),
        devicePixelRatio: 1,
      );
      await Future<void>.delayed(Duration.zero);
      expect(requested, hasLength(24), reason: '快速反向时不得立刻预取另一整片区域');
    } finally {
      controller.dispose();
      ImagePrefetchController.debugForceEnabled = false;
      ImagePrefetchController.debugPreloadOverride = null;
    }
  });
}
