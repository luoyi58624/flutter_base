import 'dart:async';

import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Preview 两个构造默认关闭缩放惯性并使用更积极的捏合增益', () {
    final children = ElPreviewView(children: const []);
    final builder = ElPreviewView.builder(itemCount: 0, itemBuilder: (_, _) => const SizedBox.shrink());

    for (final preview in <ElPreviewView>[children, builder]) {
      expect(preview.scaleInertia, isFalse);
      expect(preview.scaleSensitivity, 1.25);
      expect(preview.maxScale, 6, reason: '捏合增益与最大缩放上限必须保持独立可调');
    }
  });

  test('未挂载 controller 的索引与变换命令立即落值并完成 Future', () async {
    final controller = ElPreviewController(initialIndex: 2);
    addTearDown(controller.dispose);

    expect(controller.index, 2);
    expect(controller.currentTransform, const ElZoomTransform());

    await controller.next(animate: false).timeout(const Duration(seconds: 1));
    expect(controller.index, 3);
    await controller.previous(animate: false).timeout(const Duration(seconds: 1));
    expect(controller.index, 2);

    controller.jumpToIndex(8);
    expect(controller.index, 8);
    await controller.animateToIndex(4).timeout(const Duration(seconds: 1));
    expect(controller.index, 4);

    const jumped = ElZoomTransform(scale: 2, offset: Offset(12, -8));
    controller.jumpToTransform(jumped);
    expect(controller.currentTransform, jumped);

    const animated = ElZoomTransform(scale: 3, rotation: 0.2, offset: Offset(-6, 10));
    await controller.animateTransform(animated).timeout(const Duration(seconds: 1));
    expect(controller.currentTransform, animated);
    await controller.resetCurrent(animate: false).timeout(const Duration(seconds: 1));
    expect(controller.currentTransform, const ElZoomTransform());
  });

  testWidgets('children 与 builder 构造都接受任意 Widget', (tester) async {
    final childrenController = ElPreviewController(initialIndex: 1);
    final builderController = ElPreviewController();
    addTearDown(childrenController.dispose);
    addTearDown(builderController.dispose);

    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: childrenController,
          children: const [
            SizedBox(key: ValueKey('child-a')),
            SizedBox(key: ValueKey('child-b')),
          ],
        ),
      ),
    );
    expect(childrenController.index, 1);
    expect(find.byKey(const ValueKey('child-b')), findsOneWidget);

    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          controller: builderController,
          itemCount: 3,
          itemBuilder: (context, index) => SizedBox(key: ValueKey('builder-$index')),
        ),
      ),
    );
    expect(builderController.index, 0);
    expect(find.byKey(const ValueKey('builder-0')), findsOneWidget);
  });

  testWidgets('同一 ElPreviewController 不允许绑定第二个 live host', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 600,
          height: 240,
          child: Row(
            children: [
              Expanded(
                child: ElPreviewView(controller: controller, children: const [SizedBox.expand()]),
              ),
              Expanded(
                child: ElPreviewView(controller: controller, children: const [SizedBox.expand()]),
              ),
            ],
          ),
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('ElPreviewController'));
  });

  testWidgets('新命令、controller 替换与宿主卸载都会完成被打断的翻页 Future', (tester) async {
    final first = ElPreviewController();
    final second = ElPreviewController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget preview(ElPreviewController controller) => _shell(
      ElPreviewView(controller: controller, children: const [SizedBox.expand(), SizedBox.expand(), SizedBox.expand()]),
    );
    await tester.pumpWidget(preview(first));

    final jumped = first.animateToIndex(2);
    await tester.pump(const Duration(milliseconds: 16));
    first.jumpToIndex(1);
    await jumped.timeout(const Duration(seconds: 1));
    expect(first.index, 1);

    first.jumpToTransform(const ElZoomTransform(scale: 2));
    await tester.pump();

    final replaced = first.animateToIndex(2);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(preview(second));
    await replaced.timeout(const Duration(seconds: 1));
    expect(second.index, 0);

    second.jumpToIndex(1);
    await tester.pump();
    expect(second.currentTransform, const ElZoomTransform(), reason: 'controller 替换离开的旧页不得残留变换');

    final interruptedTransform = second.animateTransform(const ElZoomTransform(scale: 3));
    var transformCompleted = false;
    unawaited(interruptedTransform.then((_) => transformCompleted = true));
    await tester.pump(const Duration(milliseconds: 16));
    second.jumpToIndex(2);
    await tester.pump();
    expect(transformCompleted, isTrue, reason: '切页必须立即终止旧 current 的 Zoom ticker 与 Future');

    final unmounted = second.animateToIndex(0);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(const SizedBox.shrink());
    await unmounted.timeout(const Duration(seconds: 1));
  });

  testWidgets('loop 下 empty 返回空态且命令 no-op，single 始终停在唯一页', (tester) async {
    final emptyController = ElPreviewController(initialIndex: 9);
    final singleController = ElPreviewController(initialIndex: 9);
    addTearDown(emptyController.dispose);
    addTearDown(singleController.dispose);

    var dynamicCount = 0;
    Widget dynamicPreview() => _shell(
      ElPreviewView.builder(
        controller: emptyController,
        itemCount: dynamicCount,
        loop: true,
        itemBuilder: (context, index) => SizedBox.expand(key: ValueKey('dynamic-$index')),
      ),
    );
    await tester.pumpWidget(dynamicPreview());
    expect(emptyController.index, isNull);
    expect(emptyController.currentTransform, const ElZoomTransform());
    await emptyController.next().timeout(const Duration(seconds: 1));
    await emptyController.previous().timeout(const Duration(seconds: 1));
    await emptyController.resetCurrent().timeout(const Duration(seconds: 1));
    emptyController.jumpToIndex(100);
    expect(emptyController.index, isNull);
    expect(emptyController.currentTransform, const ElZoomTransform());

    dynamicCount = 3;
    await tester.pumpWidget(dynamicPreview());
    expect(emptyController.index, 2, reason: '空数据期间保存的请求应在数据出现后统一钳制');

    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: singleController,
          loop: true,
          preloadCount: 999,
          children: const [SizedBox(key: ValueKey('only-page'))],
        ),
      ),
    );
    expect(singleController.index, 0);
    expect(find.byKey(const ValueKey('only-page')), findsOneWidget);
    await singleController.next(animate: false);
    await singleController.previous(animate: false);
    singleController.jumpToIndex(20);
    expect(singleController.index, 0);
    expect(find.byKey(const ValueKey('only-page')), findsOneWidget);
    expect(find.byType(ElZoomView), findsOneWidget, reason: '循环单页不得为首尾复制页实例');
  });

  testWidgets('loop 双项始终只挂载各一份 State，相对命令循环而绝对索引仍钳制', (tester) async {
    final controller = ElPreviewController();
    final tracker = _LifecycleTracker();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          controller: controller,
          itemCount: 2,
          itemIdBuilder: (index) => index,
          itemBuilder: (context, index) => _LifecycleProbe(id: index, tracker: tracker),
          loop: true,
          preloadCount: 999,
        ),
      ),
    );

    final initialSerials = Map<Object, int>.of(tracker.stateSerialById);
    expect(controller.index, 0);
    expect(tracker.mountedIds, {0, 1});
    expect(tracker.nextSerial, 2);
    expect(find.byType(_LifecycleProbe), findsNWidgets(2));
    expect(find.byType(ElZoomView), findsNWidgets(2), reason: '超大 preloadCount 也不得超过 itemCount');

    await controller.previous(animate: false);
    await tester.pump();
    expect(controller.index, 1, reason: 'loop previous 应从首页绕到末页');
    expect(tracker.stateSerialById, initialSerials);

    await controller.next(animate: false);
    await tester.pump();
    expect(controller.index, 0, reason: 'loop next 应从末页绕回首页');
    expect(tracker.stateSerialById, initialSerials);

    controller.jumpToIndex(99);
    await tester.pump();
    expect(controller.index, 1, reason: '绝对索引命令仍应钳制，不按 loop 取模');
    expect(tracker.mountedIds, {0, 1});
    expect(tracker.stateSerialById, initialSerials);
    expect(tracker.disposedIds, isEmpty);
    expect(tracker.nextSerial, 2);
  });

  testWidgets('loop 远距动画与 jump 的挂载峰值不超过稳态三页加单一目标', (tester) async {
    final controller = ElPreviewController();
    final tracker = _LifecycleTracker();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          controller: controller,
          itemCount: 100,
          itemIdBuilder: (index) => index,
          itemBuilder: (context, index) => _LifecycleProbe(id: index, tracker: tracker),
          loop: true,
          preloadCount: 1,
        ),
      ),
    );
    expect(tracker.mountedIds, {99, 0, 1});
    expect(tracker.maxMountedCount, 3);

    final animated = controller.animateToIndex(50);
    await tester.pump();
    expect(tracker.mountedIds, {99, 0, 1, 50}, reason: '远距动画期只允许额外挂载真实 target');
    expect(tracker.maxMountedCount, 4);
    final animatedTargetSerial = tracker.stateSerialById[50];

    await tester.pump(const Duration(milliseconds: 600));
    expect(tracker.mountedIds, {50}, reason: 'commit 帧应先卸载旧窗口，不创建即将丢弃的新邻页');
    expect(tracker.maxMountedCount, lessThanOrEqualTo(4));
    expect(tracker.stateSerialById[50], animatedTargetSerial);

    await tester.pump();
    await animated;
    expect(tracker.mountedIds, {49, 50, 51});
    expect(tracker.stateSerialById[50], animatedTargetSerial, reason: '动画 target 应原位成为 current');
    expect(tracker.maxMountedCount, lessThanOrEqualTo(4));
    expect(tracker.nextSerial, 6, reason: '恢复窗口只应新建目标两侧的两页');

    tracker.maxMountedCount = tracker.mountedIds.length;
    controller.jumpToIndex(80);
    await tester.pump();
    expect(tracker.mountedIds, {80}, reason: '远距 jump 也应先结清旧窗口');
    expect(tracker.maxMountedCount, lessThanOrEqualTo(4));
    final jumpedTargetSerial = tracker.stateSerialById[80];

    await tester.pump();
    expect(controller.index, 80);
    expect(tracker.mountedIds, {79, 80, 81});
    expect(tracker.stateSerialById[80], jumpedTargetSerial);
    expect(tracker.maxMountedCount, lessThanOrEqualTo(4));
    expect(tracker.nextSerial, 9, reason: 'jump 恢复窗口不得产生短命邻页');
  });

  testWidgets('稳态仅挂载 current±preloadCount，离窗页面立即 dispose', (tester) async {
    final controller = ElPreviewController(initialIndex: 4);
    final tracker = _LifecycleTracker();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          controller: controller,
          itemCount: 9,
          preloadCount: 1,
          itemIdBuilder: (index) => index,
          itemBuilder: (context, index) => _LifecycleProbe(id: index, tracker: tracker),
        ),
      ),
    );
    expect(tracker.mountedIds, {3, 4, 5});
    expect(tracker.mountedIds.length, lessThanOrEqualTo(3));
    expect(
      tester.widgetList<ElZoomView>(find.byType(ElZoomView)).where((view) => view.interactionEnabled),
      hasLength(1),
      reason: '只有 current 页启用 Preview 自有的 Zoom 手势入口与 ticker',
    );

    controller.jumpToIndex(5);
    await tester.pump();
    controller.jumpToIndex(4);
    await tester.pump();
    expect(
      tester.widgetList<ElZoomView>(find.byType(ElZoomView)).where((view) => view.interactionEnabled),
      hasLength(1),
      reason: '预加载页反复失活/激活也只能保留一个 Preview 自有交互宿主',
    );

    controller.jumpToIndex(7);
    await tester.pump();
    await tester.pump();
    expect(tracker.mountedIds, {6, 7, 8});
    expect(tracker.disposedIds, containsAll(<Object>[3, 4, 5]));
    expect(tracker.mountedIds.length, lessThanOrEqualTo(3));
    expect(
      tester.widgetList<ElZoomView>(find.byType(ElZoomView)).where((view) => view.interactionEnabled),
      hasLength(1),
    );
  });

  testWidgets('onIndexChanged 触发前 controller 已同步到提交后的页', (tester) async {
    final controller = ElPreviewController();
    final observations = <(int, int?)>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          onIndexChanged: (index) => observations.add((index, controller.index)),
          children: const [SizedBox.expand(), SizedBox.expand()],
        ),
      ),
    );

    controller.jumpToIndex(1);
    await tester.pump();
    expect(observations, [(1, 1)]);
  });

  testWidgets('远距反向动画只绘制 current 与真实 target，不让相邻预加载页叠盖', (tester) async {
    final controller = ElPreviewController(initialIndex: 70);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          controller: controller,
          itemCount: 100,
          preloadCount: 1,
          itemBuilder: (context, index) => SizedBox.expand(key: ValueKey('remote-$index')),
        ),
      ),
    );

    final command = controller.animateToIndex(30);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_nearestRepaintBoundary(tester.renderObject(find.byKey(const ValueKey('remote-30')))).debugLayer, isNotNull);
    expect(
      _nearestRepaintBoundary(tester.renderObject(find.byKey(const ValueKey('remote-69')))).debugLayer,
      isNull,
      reason: '反向远距目标不能被 index=69 的预加载页叠画',
    );

    await _finishPageMotion(tester);
    await command;
    expect(controller.index, 30);
  });

  testWidgets('切页事务中视口宽度变化会取消旧像素轨迹并回到稳定 current', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);
    Widget preview(double width) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 240,
          child: ElPreviewView(
            controller: controller,
            children: const [
              SizedBox.expand(key: ValueKey('resize-0')),
              SizedBox.expand(key: ValueKey('resize-1')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(preview(300));

    final command = controller.animateToIndex(1);
    var completed = false;
    unawaited(command.then((_) => completed = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(find.byKey(const ValueKey('resize-0'))).dx, lessThan(0));

    await tester.pumpWidget(preview(600));
    await tester.pump();
    expect(completed, isTrue);
    expect(controller.index, 0);
    expect(tester.getTopLeft(find.byKey(const ValueKey('resize-0'))).dx, closeTo(0, 1e-6));
    expect(tester.getTopLeft(find.byKey(const ValueKey('resize-1'))).dx, closeTo(600, 1e-6));
  });

  testWidgets('活动远距动画中数据集重排并删除 target 会终止旧命令且按 ID 跟随 current', (tester) async {
    final controller = ElPreviewController();
    var ids = <String>['a', 'b', 'c', 'd'];
    addTearDown(controller.dispose);
    Widget preview() => _shell(
      ElPreviewView.builder(
        controller: controller,
        itemCount: ids.length,
        itemIdBuilder: (index) => ids[index],
        itemBuilder: (context, index) => SizedBox.expand(key: ValueKey(ids[index])),
      ),
    );
    await tester.pumpWidget(preview());

    final command = controller.animateToIndex(3);
    var completed = false;
    unawaited(command.then((_) => completed = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    ids = <String>['b', 'a'];
    await tester.pumpWidget(preview());
    await tester.pump();
    expect(completed, isTrue);
    expect(controller.index, 1, reason: '原 current=a 应跟随稳定 ID，而不是提交已删除的旧 target=d');
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.index, 1, reason: '旧动画 terminal 后不得再次 stale commit');
  });

  testWidgets('半页状态 jumpToIndex(current) 只归位，不重复报告索引变化', (tester) async {
    final controller = ElPreviewController();
    final changes = <int>[];
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _shell(
        ElPreviewView(
          controller: controller,
          onIndexChanged: changes.add,
          children: const [
            SizedBox.expand(key: ValueKey('same-index-0')),
            SizedBox.expand(key: ValueKey('same-index-1')),
          ],
        ),
      ),
    );

    final command = controller.animateToIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    controller.jumpToIndex(0);
    await command;
    await tester.pump();
    expect(controller.index, 0);
    expect(changes, isEmpty);
    expect(tester.getTopLeft(find.byKey(const ValueKey('same-index-0'))).dx, closeTo(0, 1e-6));
  });

  testWidgets('stable itemId 保持 State，重排时 current 跟随 ID 且只通知一次', (tester) async {
    final controller = ElPreviewController(initialIndex: 1);
    final tracker = _LifecycleTracker();
    final changes = <int>[];
    var ids = <String>['a', 'b', 'c'];
    addTearDown(controller.dispose);

    Widget preview() => _shell(
      ElPreviewView.builder(
        controller: controller,
        itemCount: ids.length,
        preloadCount: 1,
        itemIdBuilder: (index) => ids[index],
        itemBuilder: (context, index) => _LifecycleProbe(id: ids[index], tracker: tracker),
        onIndexChanged: changes.add,
      ),
    );

    await tester.pumpWidget(preview());
    final stateBefore = tracker.stateSerialById['b'];
    expect(controller.index, 1);
    changes.clear();

    ids = <String>['b', 'a', 'c'];
    await tester.pumpWidget(preview());

    expect(controller.index, 0);
    expect(changes, [0]);
    expect(tracker.stateSerialById['b'], stateBefore);
  });

  testWidgets('整个 live dataset 的重复 itemId 即使离窗也抛 FlutterError', (tester) async {
    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          itemCount: 4,
          preloadCount: 0,
          itemIdBuilder: (index) => index < 2 ? index : 'duplicate',
          itemBuilder: (context, index) => const SizedBox.expand(),
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('itemId'));
  });

  testWidgets('预加载页不命中、不进 semantics、不可聚焦，切为 current 后原子激活', (tester) async {
    final controller = ElPreviewController();
    final focusNodes = List.generate(2, (index) => FocusNode(debugLabel: 'preview-$index'));
    final taps = <int>[0, 0];
    addTearDown(controller.dispose);
    addTearDown(() {
      for (final node in focusNodes) {
        node.dispose();
      }
    });

    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          controller: controller,
          itemCount: 2,
          preloadCount: 1,
          itemBuilder: (context, index) => ElView(
            key: ValueKey('interactive-$index'),
            focusNode: focusNodes[index],
            semantics: ElSemantics(container: true, label: 'preview page $index'),
            event: ElEvent(onTap: (_) => taps[index]++),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('interactive-1')), findsOneWidget, reason: '相邻页应已预加载');

    final semantics = tester.ensureSemantics();
    try {
      expect(find.semantics.byLabel('preview page 0'), findsOne);
      expect(find.semantics.byLabel('preview page 1'), findsNothing);

      focusNodes[1].requestFocus();
      await tester.pump();
      expect(focusNodes[1].hasFocus, isFalse);

      await tester.tap(find.byKey(const ValueKey('interactive-1')), warnIfMissed: false);
      await tester.pump();
      expect(taps[1], 0);

      await tester.tap(find.byKey(const ValueKey('interactive-0')));
      await tester.pump();
      expect(taps[0], 1);

      controller.jumpToIndex(1);
      await tester.pump();
      expect(find.semantics.byLabel('preview page 0'), findsNothing);
      expect(find.semantics.byLabel('preview page 1'), findsOne);

      focusNodes[1].requestFocus();
      await tester.pump();
      expect(focusNodes[1].hasPrimaryFocus, isTrue);
      await tester.tap(find.byKey(const ValueKey('interactive-1')));
      await tester.pump();
      expect(taps[1], 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('preserveItemTransform=false 时离页即重置', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          controller: controller,
          itemCount: 2,
          preloadCount: 0,
          preserveItemTransform: false,
          itemBuilder: (context, index) => const SizedBox.expand(),
        ),
      ),
    );
    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    await tester.pump();
    expect(controller.currentTransform.scale, 2);

    controller.jumpToIndex(1);
    await tester.pump();
    controller.jumpToIndex(0);
    await tester.pump();
    expect(controller.currentTransform, const ElZoomTransform());
  });

  testWidgets('preserveItemTransform=true 基本往返保留且 LRU 容量有界', (tester) async {
    final controller = ElPreviewController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _shell(
        ElPreviewView.builder(
          controller: controller,
          itemCount: 3,
          preloadCount: 0,
          preserveItemTransform: true,
          transformCacheCapacity: 1,
          itemBuilder: (context, index) => const SizedBox.expand(),
        ),
      ),
    );

    controller.jumpToTransform(const ElZoomTransform(scale: 2));
    controller.jumpToIndex(1);
    await tester.pump();
    controller.jumpToIndex(0);
    await tester.pump();
    expect(controller.currentTransform.scale, 2, reason: '容量 1 足以覆盖一次基本往返');

    controller.jumpToIndex(1);
    await tester.pump();
    controller.jumpToTransform(const ElZoomTransform(scale: 3));
    controller.jumpToIndex(2);
    await tester.pump();
    controller.jumpToIndex(0);
    await tester.pump();
    expect(controller.currentTransform, const ElZoomTransform(), reason: '第二个离窗变换进入后，最旧页必须被驱逐');
  });
}

RenderObject _nearestRepaintBoundary(RenderObject renderObject) {
  var current = renderObject;
  while (!current.isRepaintBoundary) {
    current = current.parent!;
  }
  return current;
}

Future<void> _finishPageMotion(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 16));
}

Widget _shell(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, height: 240, child: child),
    ),
  );
}

class _LifecycleTracker {
  final Set<Object> mountedIds = <Object>{};
  final Set<Object> disposedIds = <Object>{};
  final Map<Object, int> stateSerialById = <Object, int>{};
  int nextSerial = 0;
  int maxMountedCount = 0;

  void mount(Object id, int serial) {
    mountedIds.add(id);
    stateSerialById[id] = serial;
    if (mountedIds.length > maxMountedCount) maxMountedCount = mountedIds.length;
  }

  void replace(Object oldId, Object newId, int serial) {
    mountedIds.remove(oldId);
    mountedIds.add(newId);
    stateSerialById[newId] = serial;
    if (mountedIds.length > maxMountedCount) maxMountedCount = mountedIds.length;
  }

  void dispose(Object id) {
    mountedIds.remove(id);
    disposedIds.add(id);
  }
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.id, required this.tracker});

  final Object id;
  final _LifecycleTracker tracker;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  late final int _serial;

  @override
  void initState() {
    super.initState();
    _serial = ++widget.tracker.nextSerial;
    widget.tracker.mount(widget.id, _serial);
  }

  @override
  void didUpdateWidget(covariant _LifecycleProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      widget.tracker.replace(oldWidget.id, widget.id, _serial);
    }
  }

  @override
  void dispose() {
    widget.tracker.dispose(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
