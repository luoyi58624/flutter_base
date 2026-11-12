import 'package:example/src/pages/examples/scroll_examples/scroll_mode.dart';
import 'package:example/src/pages/examples/sliver_takeaway/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

// 显式启用有限诊断；debug pump 耗时不能作为设备帧耗时或帧率。
const _diagnose = bool.fromEnvironment('SLIVER_CHILDREN_DIAGNOSE');
const _semantics = bool.fromEnvironment('SLIVER_DIAGNOSE_SEMANTICS', defaultValue: true);

void main() {
  testWidgets('ExcludeSemantics 子树的语义重试次数诊断', (tester) async {
    final probes = <_OwnerProbeRender>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ExcludeSemantics(
          child: CustomScrollView(
            slivers: [ElSliverList(children: List.generate(32, (_) => _OwnerProbe(onCreate: probes.add)))],
          ),
        ),
      ),
    );
    final retries = <int>[];
    for (var i = 0; i < 3; i++) {
      for (final probe in probes) {
        probe.ownerReads = 0;
      }
      tester.binding.rootPipelineOwner.flushSemantics();
      retries.add(probes.fold(0, (sum, probe) => sum + probe.ownerReads));
    }
    // 无布局、构建、绘制变化，只调用语义阶段，观察 SDK 是否仍逐个访问被排除的节点。
    debugPrint('excluded_semantics_owner_reads=$retries, retained_children=${probes.length}');
    expect(probes, hasLength(32));
    expect(tester.takeException(), isNull);
  }, skip: !_diagnose);

  testWidgets(
    '外卖 children 持续滚动只绘制可见子树',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(home: ExcludeSemantics(child: TakeawaySliverPage())),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester.widget<CustomScrollView>(find.byKey(ValueKey('takeaway-sliver'))).controller!;
      final paintCounts = <String, int>{};
      for (final mode in [SliverExampleMode.official, SliverExampleMode.children]) {
        final switchWatch = Stopwatch()..start();
        tester.widget<PopupMenuButton<Object>>(find.byKey(ValueKey('takeaway-sliver-menu'))).onSelected!(mode);
        await tester.pumpAndSettle();
        switchWatch.stop();
        final samples = <int>[];
        debugOnProfilePaint = (object) =>
            paintCounts.update(object.runtimeType.toString(), (count) => count + 1, ifAbsent: () => 1);
        try {
          for (var i = 0; i < 3; i++) {
            paintCounts.clear();
            final watch = Stopwatch()..start();
            scroll.jumpTo((i + 1) * 80);
            await tester.pump(Duration(milliseconds: 16));
            watch.stop();
            samples.add(watch.elapsedMicroseconds);
            if (i == 2) debugPrint('${mode.name}: paints=$paintCounts');
          }
          debugPrint('${mode.name}: mount=${switchWatch.elapsedMilliseconds} ms, scroll_us=$samples');
          final stages = <String, int>{};
          final stageWatch = Stopwatch()..start();
          scroll.jumpTo(800);
          stages['jump'] = stageWatch.elapsedMicroseconds;
          for (final phase in EnginePhase.values) {
            stageWatch.reset();
            await tester.pump(Duration(milliseconds: 16), phase);
            stages[phase.name] = stageWatch.elapsedMicroseconds;
          }
          debugPrint('${mode.name}: phase_us=$stages');
          final eventWatch = Stopwatch()..start();
          final gesture = await tester.startGesture(Offset(200, 300));
          await gesture.moveBy(Offset(0, -80));
          eventWatch.stop();
          debugPrint('${mode.name}: down_move_us=${eventWatch.elapsedMicroseconds}');
          await gesture.cancel();
          await tester.pumpAndSettle();
          expect(paintCounts.values.fold<int>(0, (sum, count) => sum + count), lessThan(2000));
        } finally {
          debugOnProfilePaint = null;
        }
        expect(tester.takeException(), isNull);
      }
    },
    skip: !_diagnose,
    semanticsEnabled: _semantics,
    timeout: Timeout(Duration(seconds: 90)),
  );
}

class _OwnerProbe extends LeafRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OwnerProbe({required this.onCreate});

  final ValueChanged<_OwnerProbeRender> onCreate;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final render = _OwnerProbeRender();
    onCreate(render);
    return render;
  }
}

class _OwnerProbeRender extends RenderConstrainedBox {
  _OwnerProbeRender() : super(additionalConstraints: BoxConstraints.tightFor(width: 80, height: 20));

  int ownerReads = 0;

  @override
  PipelineOwner? get owner {
    ownerReads++;
    return super.owner;
  }
}
