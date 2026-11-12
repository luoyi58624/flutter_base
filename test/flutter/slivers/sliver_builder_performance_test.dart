import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

class _Work {
  int builds = 0;
  int layouts = 0;
  final sliverMicros = <int>[];
}

class _TimedSliver extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _TimedSliver(this.work, {required super.child});
  final _Work work;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTimedSliver(work);
}

class _RenderTimedSliver extends RenderProxySliver {
  _RenderTimedSliver(this.work);
  final _Work work;
  @override
  void performLayout() {
    final watch = Stopwatch()..start();
    super.performLayout();
    work.sliverMicros.add(watch.elapsedMicroseconds);
  }
}

class _Probe extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _Probe(this.work, {required super.child});
  final _Work work;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe(work);
}

class _RenderProbe extends RenderProxyBox {
  _RenderProbe(this.work);
  final _Work work;
  @override
  void performLayout() {
    work.layouts++;
    super.performLayout();
  }
}

void main() {
  for (final reverseOrder in [false, true]) {
    testWidgets('reverse=$reverseOrder 1000 项同负载同缓存：builder 与官方布局工作量和滚动耗时', (tester) async {
      tester.view.physicalSize = Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final results = <String, Map<String, Object>>{};
      final order = ['official-list', 'builder-list', 'official-grid', 'builder-grid'];
      for (final mode in reverseOrder ? order.reversed : order) {
        final work = _Work();
        final controller = ScrollController();
        Widget item(BuildContext context, int index) {
          work.builds++;
          return _Probe(
            work,
            child: SizedBox(
              height: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('商品 $index · 自然文本排版', maxLines: 1),
                  Text('销量 ${index % 997} · ¥${index % 89 + 10}', maxLines: 1),
                ],
              ),
            ),
          );
        }

        final sliver = switch (mode) {
          'official-list' => SliverList.builder(itemCount: 1000, itemBuilder: item),
          'builder-list' => ElSliverList.builder(itemCount: 1000, itemBuilder: item),
          'official-grid' => SliverGrid.builder(
            itemCount: 1000,
            itemBuilder: item,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 72),
          ),
          _ => ElSliverGrid.builder(crossAxisCount: 2, itemCount: 1000, itemBuilder: item),
        };
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: CustomScrollView(
              controller: controller,
              scrollCacheExtent: ScrollCacheExtent.pixels(250),
              slivers: [_TimedSliver(work, child: sliver)],
            ),
          ),
        );
        for (var frame = 1; frame <= 12; frame++) {
          controller.jumpTo(frame * 48);
          await tester.pump();
        }
        work
          ..builds = 0
          ..layouts = 0;
        work.sliverMicros.clear();
        final samples = <int>[];
        for (var frame = 13; frame <= 44; frame++) {
          final timer = Stopwatch()..start();
          controller.jumpTo(frame * 48);
          await tester.pump();
          timer.stop();
          samples.add(timer.elapsedMicroseconds);
        }
        samples.sort();
        work.sliverMicros.sort();
        results[mode] = {
          'median_us': samples[samples.length ~/ 2],
          'p95_us': samples[(samples.length * .95).ceil() - 1],
          'builds': work.builds,
          'layouts': work.layouts,
          'sliver_layout_median_us': work.sliverMicros[work.sliverMicros.length ~/ 2],
        };
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(SizedBox.shrink());
        controller.dispose();
      }
      // 计数是稳定回归门槛；无头 debug 的墙钟结果只用于同环境对照，不冒充设备帧时间。
      for (final kind in ['list', 'grid']) {
        final official = results['official-$kind']!;
        final builder = results['builder-$kind']!;
        expect(builder['builds'] as int, lessThanOrEqualTo((official['builds'] as int) + 2));
        expect(builder['layouts'] as int, lessThanOrEqualTo((official['layouts'] as int) + 2));
      }
      debugPrint('SLIVER_BUILDER_PERFORMANCE reverse=$reverseOrder ${jsonEncode(results)}');
    });
  }
}
