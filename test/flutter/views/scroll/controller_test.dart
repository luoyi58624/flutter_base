import 'package:flutter_base/ui.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/virtual_test_host.dart';

/// 常驻散 child 载具：10 行 × 100（视口 600 → max 400），可追加行 / 指定行长高。
class _ListHost extends StatefulWidget {
  const _ListHost({super.key, required this.controller, this.pinToEnd = false});

  final ScrollController controller;
  final bool pinToEnd;

  @override
  State<_ListHost> createState() => _ListHostState();
}

class _ListHostState extends State<_ListHost> {
  int count = 10;
  int? grownIndex;

  void append() => setState(() => count++);

  void grow(int index) => setState(() => grownIndex = index);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ElScrollView(
          controller: widget.controller,
          pinToEnd: widget.pinToEnd,
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(key: ValueKey('r$i'), height: i == grownIndex ? 300 : 100, width: 300),
          ],
        ),
      ),
    );
  }
}

/// 虚拟段载具：裸 ElListView 自动虚拟化，等高 40 行，itemCount 可追加。
class _VirtualHost extends StatefulWidget {
  const _VirtualHost({super.key, required this.controller, this.pinToEnd = false});

  final ScrollController controller;
  final bool pinToEnd;

  @override
  State<_VirtualHost> createState() => _VirtualHostState();
}

class _VirtualHostState extends State<_VirtualHost> {
  int count = 50;

  void append() => setState(() => count++);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ElScrollView(
          controller: widget.controller,
          pinToEnd: widget.pinToEnd,
          children: [
            ElListView.builder(
              itemCount: count,
              itemBuilder: (context, index) => SizedBox(key: ValueKey('v$index'), height: 40, width: 300),
            ),
          ],
        ),
      ),
    );
  }
}

/// 均匀 item 宿主。cacheExtent 默认给足以覆盖测试范围——保证目标 index 之前
/// 的 item 全部被 mount 度量后再断言 offset，否则未度量 item 的 32px estimate
/// 会污染前缀和。
Widget _uniformHost({
  required ElScrollController controller,
  int itemCount = 50,
  double itemExtent = 40,
  double viewportExtent = 200,
  double cacheExtent = 5000,
  ValueChanged<ElVisibleRange>? onVisibleRangeChanged,
  ValueListenable<double>? variableItemExtent,
  int variableItemIndex = 0,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 300,
        height: viewportExtent,
        child: buildVirtualTestView(
          controller: controller,
          scrollbar: const ElNoScrollBar(),
          physics: const ClampingScrollPhysics(),
          cacheExtent: cacheExtent,
          onVisibleRangeChanged: onVisibleRangeChanged,
          children: List<Widget>.generate(
            itemCount,
            (index) => variableItemExtent != null && index == variableItemIndex
                ? ValueListenableBuilder<double>(
                    valueListenable: variableItemExtent,
                    builder: (_, extent, _) => SizedBox(key: ValueKey('item-$index'), height: extent, width: 300),
                  )
                : SizedBox(key: ValueKey('item-$index'), height: itemExtent, width: 300),
          ),
        ),
      ),
    ),
  );
}

/// 变高宿主：前 20 个 20px、后 30 个 80px，cacheExtent 大——所有 item 都被
/// 度量后可断言精确 offset。
Widget _mixedHost({required ElScrollController controller}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 300,
        height: 200,
        child: buildVirtualTestView(
          controller: controller,
          scrollbar: const ElNoScrollBar(),
          physics: const ClampingScrollPhysics(),
          cacheExtent: 10000,
          children: [
            for (var i = 0; i < 20; i++) SizedBox(key: ValueKey('narrow-$i'), width: 300, height: 20),
            for (var i = 0; i < 30; i++) SizedBox(key: ValueKey('wide-$i'), width: 300, height: 80),
          ],
        ),
      ),
    ),
  );
}

/// scrollToIndex 返回的 Future 靠 post-frame 回调链驱动收敛，测试构建下必须
/// 用 pumpAndSettle 推进——先发射再 pump 再 await 保持每个 case 简洁。
Future<void> _driveScroll(WidgetTester tester, Future<void> future) async {
  await tester.pumpAndSettle();
  await future;
}

Widget _list(ElScrollController controller) => Directionality(
  textDirection: .ltr,
  child: Align(
    alignment: .topLeft,
    child: ElView(
      style: const ElStyle(width: 300, height: 200),
      child: ElScrollView(
        controller: controller,
        physics: const ClampingScrollPhysics(),
        smoothScroll: null,
        scrollbar: const ElNoScrollBar(),
        children: [
          ElListView.builder(
            itemCount: 100,
            itemBuilder: (_, _) => const ElView(style: ElStyle(height: 40)),
            fixedSize: true,
          ),
        ],
      ),
    ),
  ),
);

void main() {
  group('末端跟随', () {
    Future<void> pumpFrames(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    Future<void> settleAtBottom(WidgetTester tester, ScrollController controller) async {
      for (var i = 0; i < 6; i++) {
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        await tester.pump();
      }
      expect(controller.position.pixels, controller.position.maxScrollExtent, reason: '前置：已稳定贴底');
    }

    testWidgets('默认：贴底追加成员保留 pixels，新内容在视口下方（web 口径）', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final hostKey = GlobalKey<_ListHostState>();
      await tester.pumpWidget(_ListHost(key: hostKey, controller: controller));
      await pumpFrames(tester);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.position.pixels, 400.0, reason: '前置：贴底（1000 − 600）');
      expect(tester.getRect(find.byKey(const ValueKey('r9'))).bottom, 600.0);

      hostKey.currentState!.append();
      await pumpFrames(tester);

      expect(controller.position.pixels, 400.0, reason: '追加不驱动滚动，位置保留');
      expect(controller.position.maxScrollExtent, 500.0, reason: '内容 +100 → max 400 → 500');
      expect(tester.getRect(find.byKey(const ValueKey('r9'))).bottom, 600.0, reason: '可见内容原地不动');
      expect(tester.getRect(find.byKey(const ValueKey('r10'))).top, 600.0, reason: '新行出现在视口下方');
    });

    testWidgets('默认：贴底行自身长高保留 pixels，增长在视口下方（web 口径）', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final hostKey = GlobalKey<_ListHostState>();
      await tester.pumpWidget(_ListHost(key: hostKey, controller: controller));
      await pumpFrames(tester);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.position.pixels, 400.0);
      final r9Before = tester.getRect(find.byKey(const ValueKey('r9')));
      expect(r9Before.top, 500.0, reason: '前置：末行顶在 900 − 400');

      hostKey.currentState!.grow(9);
      await pumpFrames(tester);

      expect(controller.position.pixels, 400.0, reason: '长高不驱动滚动，位置保留');
      expect(controller.position.maxScrollExtent, 600.0, reason: '内容 +200 → max 400 → 600');
      expect(tester.getRect(find.byKey(const ValueKey('r9'))).top, 500.0, reason: '可见内容原地不动，增长向下延伸');
    });

    testWidgets('pinToEnd：贴底追加成员钉住新 max，新行贴视口底可见', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final hostKey = GlobalKey<_ListHostState>();
      await tester.pumpWidget(_ListHost(key: hostKey, controller: controller, pinToEnd: true));
      await pumpFrames(tester);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.position.pixels, 400.0);

      hostKey.currentState!.append();
      await pumpFrames(tester);

      expect(controller.position.maxScrollExtent, 500.0);
      expect(controller.position.pixels, 500.0, reason: '贴底跟随：钉到新 max');
      expect(tester.getRect(find.byKey(const ValueKey('r10'))).bottom, 600.0, reason: '新行贴视口底可见');
    });

    testWidgets('pinToEnd：贴底行自身长高钉住新 max（流式输出跟随）', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final hostKey = GlobalKey<_ListHostState>();
      await tester.pumpWidget(_ListHost(key: hostKey, controller: controller, pinToEnd: true));
      await pumpFrames(tester);

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(controller.position.pixels, 400.0);

      hostKey.currentState!.grow(9);
      await pumpFrames(tester);

      expect(controller.position.maxScrollExtent, 600.0);
      expect(controller.position.pixels, 600.0, reason: '贴底跟随：底边钉住新 max');
      expect(tester.getRect(find.byKey(const ValueKey('r9'))).bottom, 600.0, reason: '长高行底边贴住视口底');
    });

    testWidgets('默认 + 虚拟段：贴底追加 item 保留 pixels', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final hostKey = GlobalKey<_VirtualHostState>();
      await tester.pumpWidget(_VirtualHost(key: hostKey, controller: controller));
      await pumpFrames(tester);
      await settleAtBottom(tester, controller);
      final pixelsBefore = controller.position.pixels;
      final maxBefore = controller.position.maxScrollExtent;

      hostKey.currentState!.append();
      await pumpFrames(tester);

      expect(controller.position.pixels, pixelsBefore, reason: '追加不驱动滚动，位置保留');
      expect(controller.position.maxScrollExtent, closeTo(maxBefore + 40, 0.5), reason: '内容 +40');
    });

    testWidgets('默认：不等高虚拟行 jumpTo(max) 仍收敛到真实底部（首测钉边是估算 artifact，恒钉）', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElScrollView(
              controller: controller,
              children: [
                ElListView.builder(
                  itemCount: 80,
                  itemBuilder: (context, index) =>
                      SizedBox(key: ValueKey('u$index'), height: 30.0 + (index * 7) % 50, width: 300),
                ),
              ],
            ),
          ),
        ),
      );
      await pumpFrames(tester);

      // 单次 jump 到（估算的）max，不重复跳——收敛必须由引擎自己完成。
      controller.jumpTo(controller.position.maxScrollExtent);
      for (var i = 0; i < 6; i++) {
        await tester.pump();
      }

      expect(controller.position.pixels, controller.position.maxScrollExtent, reason: '估算误差收敛后仍贴真实底部');
      expect(tester.getRect(find.byKey(const ValueKey('u79'))).bottom, closeTo(600.0, 0.5), reason: '末行贴视口底可见');
    });

    testWidgets('pinToEnd + 虚拟段：贴底追加 item 钉住新 max（chat/feed）', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ScrollController();
      addTearDown(controller.dispose);
      final hostKey = GlobalKey<_VirtualHostState>();
      await tester.pumpWidget(_VirtualHost(key: hostKey, controller: controller, pinToEnd: true));
      await pumpFrames(tester);
      await settleAtBottom(tester, controller);
      final maxBefore = controller.position.maxScrollExtent;

      hostKey.currentState!.append();
      await pumpFrames(tester);

      expect(controller.position.maxScrollExtent, closeTo(maxBefore + 40, 0.5), reason: '内容 +40');
      expect(controller.position.pixels, controller.position.maxScrollExtent, reason: '贴底跟随：钉到新 max');
      expect(tester.getRect(find.byKey(const ValueKey('v50'))).bottom, closeTo(600.0, 0.5), reason: '新 item 贴视口底可见');
    });
  });

  group('索引定位控制器', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    testWidgets('jumpToIndex：均匀 item 精确落到 index*extent（大 cache 保证已度量）', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      await _driveScroll(tester, controller.scrollToIndex(10));

      expect(controller.offset, closeTo(400.0, 0.5), reason: '10 * 40 = 400，item 全部已度量下 offset 精确');
      // item-10 出现在视口顶部（top=0 相对视口）。
      final item = tester.getRect(find.byKey(const ValueKey('item-10')));
      expect(item.top, closeTo(0.0, 0.5));
    });

    testWidgets('jumpToIndex：alignment 0/0.5/1 对齐视口顶/中/底', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      // alignment 0.0：item 顶对齐视口顶。
      await _driveScroll(tester, controller.scrollToIndex(20, alignment: 0.0));
      expect(tester.getRect(find.byKey(const ValueKey('item-20'))).top, closeTo(0.0, 0.5));

      // alignment 0.5：item 顶对齐视口中心（视口 200 减 item 40 = 160，160/2 = 80）。
      await _driveScroll(tester, controller.scrollToIndex(20, alignment: 0.5));
      expect(tester.getRect(find.byKey(const ValueKey('item-20'))).top, closeTo(80.0, 0.5));

      // alignment 1.0：item 底对齐视口底（top = 200 - 40 = 160）。
      await _driveScroll(tester, controller.scrollToIndex(20, alignment: 1.0));
      expect(tester.getRect(find.byKey(const ValueKey('item-20'))).top, closeTo(160.0, 0.5));
    });

    testWidgets('jumpToIndex：estimate 收敛——变高列表跳到后段仍精确落位', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_mixedHost(controller: controller));
      await tester.pumpAndSettle();

      // 目标：wide-15（全局 index 35）。真实 offset = 20*20 + 15*80 = 1600。
      // 首次 jump 时前缀和大量为 estimate（32px 默认），预测目标会偏——post-frame
      // 回调链下所有 item 度量收敛后 offset 精确到 1600。
      await _driveScroll(tester, controller.scrollToIndex(35));

      final rect = tester.getRect(find.byKey(const ValueKey('wide-15')));
      expect(rect.top, closeTo(0.0, 0.5), reason: '收敛后 wide-15 顶部精确对齐视口顶');
      expect(controller.offset, closeTo(1600.0, 0.5));
    });

    testWidgets('animateToIndex：动画期间过渡、结束后精确落位', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      final future = controller.scrollToIndex(15, duration: const Duration(milliseconds: 100));
      // 动画期间：pump 一帧，offset 应处于初始 → 目标的中间态。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.offset, greaterThan(0.0));
      expect(controller.offset, lessThan(600.0));

      // 动画结束 + jump 收敛。
      await tester.pumpAndSettle();
      await future;

      expect(controller.offset, closeTo(600.0, 0.5), reason: '15 * 40 = 600');
      expect(tester.getRect(find.byKey(const ValueKey('item-15'))).top, closeTo(0.0, 0.5));
    });

    testWidgets('带结果门面区分普通完成与显式 jump 取消，取消后窗口不再推进', (tester) async {
      final controller = ElScrollController();
      final ranges = <ElVisibleRange>[];
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller, onVisibleRangeChanged: ranges.add));
      await tester.pumpAndSettle();

      final completed = controller.scrollToIndexWithResult(10);
      await tester.pumpAndSettle();
      expect(await completed, isTrue);
      expect(controller.offset, closeTo(400, 0.5));
      expect(controller.cancelScrollToIndex(), isFalse, reason: '已完成请求不能被重复取消');

      final canceled = controller.scrollToIndexWithResult(35);
      final pixelsAtCancel = controller.offset;
      expect(controller.cancelScrollToIndex(), isTrue);
      expect(await canceled, isFalse);
      await tester.pump();
      ranges.clear();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.offset, closeTo(pixelsAtCancel, 0.01), reason: '旧 post-frame 收敛不得在取消后继续改 pixels');
      expect(ranges, isEmpty, reason: '取消并发布当前窗口后，旧定位不得继续推动虚拟窗口');
    });

    testWidgets('带结果门面达到有限迭代上限仍未收敛时返回 false', (tester) async {
      final controller = ElScrollController();
      final targetExtent = ValueNotifier<double>(40);
      addTearDown(controller.dispose);
      addTearDown(targetExtent.dispose);

      await tester.pumpWidget(
        _uniformHost(controller: controller, variableItemExtent: targetExtent, variableItemIndex: 10),
      );
      await tester.pumpAndSettle();

      final request = controller.scrollToIndexWithResult(10, alignment: 0.5);
      for (var i = 0; i < 12; i++) {
        targetExtent.value = i.isEven ? 20 : 80;
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(await request, isFalse, reason: '未进 0.5px 容差不能因耗尽迭代预算冒充 completed');
    });

    testWidgets('显式取消 animateToIndex 会冻结当前 pixels，且不误伤普通 pixel 动画', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      final request = controller.scrollToIndexWithResult(40, duration: const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(controller.offset, greaterThan(0));
      final canceled = controller.cancelScrollToIndex();
      final stoppedPixels = controller.offset;
      expect(canceled, isTrue);
      expect(await request, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(controller.offset, closeTo(stoppedPixels, 0.01), reason: 'index animation 的活动本身必须被停止');

      final pixelAnimation = controller.animateTo(
        400,
        duration: const Duration(milliseconds: 100),
        curve: Curves.linear,
      );
      expect(controller.cancelScrollToIndex(), isFalse, reason: '没有 index operation 时不得取消普通 pixel 动画');
      await tester.pumpAndSettle();
      await pixelAnimation;
      expect(controller.offset, closeTo(400, 0.5));
    });

    testWidgets('结构换代明确取消活动 index 动画，后续帧不再追旧目标', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();
      final request = controller.scrollToIndexWithResult(40, duration: const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 80));

      await tester.pumpWidget(_uniformHost(controller: controller, itemCount: 60));
      await tester.pumpAndSettle();
      expect(await request, isFalse);
      final stoppedPixels = controller.offset;

      await tester.pump(const Duration(seconds: 2));
      expect(controller.offset, closeTo(stoppedPixels, 0.01));
    });

    testWidgets('scrollToIndex latest-wins：旧 jump 收敛不得回拉新目标', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      final oldRequest = controller.scrollToIndexWithResult(40);
      final latestRequest = controller.scrollToIndexWithResult(6);
      await tester.pumpAndSettle();
      expect(await Future.wait([oldRequest, latestRequest]), [isFalse, isTrue]);
      expect(controller.offset, closeTo(240.0, 0.5));
      expect(tester.getRect(find.byKey(const ValueKey('item-6'))).top, closeTo(0.0, 0.5));

      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.offset, closeTo(240.0, 0.5), reason: '旧 post-frame 迭代已经失效，后续帧不能回拉 index 40');
    });

    testWidgets('scrollToIndex latest-wins：旧 animate 完成后不得启动落点收敛', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      final oldRequest = controller.scrollToIndexWithResult(30, duration: const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 80));
      final latestRequest = controller.scrollToIndexWithResult(4);
      await tester.pumpAndSettle();
      expect(await Future.wait([oldRequest, latestRequest]), [isFalse, isTrue]);
      expect(controller.offset, closeTo(160.0, 0.5));

      await tester.pump(const Duration(milliseconds: 600));
      expect(controller.offset, closeTo(160.0, 0.5), reason: '旧动画 future 返回后也不能重启 index 30 的 jump 修正');
    });

    testWidgets('活动 scrollToIndex 卸载时 future 正常结清且不留幽灵回调', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();
      final request = controller.scrollToIndexWithResult(30, duration: const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: SizedBox.shrink()));
      await tester.pump();
      expect(await request.timeout(const Duration(seconds: 1)), isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('越界 index：在 debug 构建触发 assert', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      // 越界断言在同步栈里抛出。
      expect(() {
        controller.scrollToIndex(999);
      }, throwsA(isA<AssertionError>()));
    });

    testWidgets('未挂载 controller：调用 scrollToIndex 触发 assert', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      // 不 pumpWidget，controller 未挂到任何 ElVirtualScrollView。
      expect(() {
        controller.scrollToIndex(0);
      }, throwsA(isA<AssertionError>()));
    });

    testWidgets('detach：view 被销毁后 controller 可挂到新 view 上继续工作', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      await _driveScroll(tester, controller.scrollToIndex(5));
      expect(controller.offset, closeTo(200.0, 0.5));

      // 换 widget 树 → 旧 view 销毁 → controller detach。
      await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: SizedBox.shrink()));
      await tester.pumpAndSettle();

      // 重挂到新 view：无 double-attach 断言。
      await tester.pumpWidget(_uniformHost(controller: controller));
      await tester.pumpAndSettle();

      await _driveScroll(tester, controller.scrollToIndex(8));
      expect(controller.offset, closeTo(320.0, 0.5));
      expect(tester.getRect(find.byKey(const ValueKey('item-8'))).top, closeTo(0.0, 0.5));
    });
  });

  group('运动所有权', () {
    for (final hold in [false, true]) {
      testWidgets('活动开始通知内${hold ? 'hold 接管' : '取消'}，原活动必须立即退出', (tester) async {
        final controller = ElScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_list(controller));
        await tester.pump();
        final position = controller.position;
        ScrollHoldController? held;
        var handled = false;
        void takeOver() {
          if (handled || !position.isScrollingNotifier.value) return;
          handled = true;
          if (hold) {
            held = position.hold(() {});
          } else {
            controller.cancelScrollToIndex();
          }
        }

        position.isScrollingNotifier.addListener(takeOver);
        final old = controller.scrollToIndexWithResult(50, duration: const Duration(milliseconds: 400));
        position.isScrollingNotifier.removeListener(takeOver);
        expect(handled, isTrue);
        expect(position.isScrollingNotifier.value, isFalse);
        held?.cancel();
        await tester.pumpAndSettle();
        expect(await old, isFalse);
        expect(controller.offset, 0);
      });
    }

    testWidgets('旧 index 操作取消不能停止已经接管的 raw 像素动画', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_list(controller));
      await tester.pump();
      final old = controller.scrollToIndexWithResult(50, duration: const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final replacement = controller.animateTo(200, duration: const Duration(milliseconds: 200), curve: Curves.linear);
      controller.cancelScrollToIndex();
      await tester.pumpAndSettle();
      await replacement;
      expect(await old, isFalse);
      expect(controller.offset, closeTo(200, .01));
    });

    testWidgets('旧动画开始通知内的新命令不会被旧调用栈继续覆盖', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_list(controller));
      await tester.pump();
      Future<void>? replacement;
      void takeOver() {
        if (replacement != null || !controller.position.isScrollingNotifier.value) return;
        replacement = controller.animateTo(200, duration: const Duration(milliseconds: 200), curve: Curves.linear);
      }

      controller.position.isScrollingNotifier.addListener(takeOver);
      final old = controller.scrollToIndexWithResult(50, duration: const Duration(milliseconds: 400));
      controller.position.isScrollingNotifier.removeListener(takeOver);
      expect(replacement, isNotNull);
      await tester.pumpAndSettle();
      await replacement;
      expect(await old, isFalse);
      expect(controller.offset, closeTo(200, .01));
    });

    testWidgets('新的 raw 像素命令接管后，旧 index 操作不能恢复后续修正', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_list(controller));
      await tester.pump();
      final old = controller.scrollToIndexWithResult(50, duration: const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      controller.jumpTo(120);
      await tester.pumpAndSettle();
      expect(await old, isFalse);
      expect(controller.offset, 120);
    });

    testWidgets('jump 定位等待下一帧收敛时，直接滚动接管会同步失效旧操作', (tester) async {
      final controller = ElScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_list(controller));
      await tester.pump();
      final old = controller.scrollToIndexWithResult(50);
      controller.position.pointerScroll(80);
      final claimed = controller.offset;
      await tester.pumpAndSettle();
      expect(await old, isFalse);
      expect(controller.offset, claimed);
    });
  });
}
