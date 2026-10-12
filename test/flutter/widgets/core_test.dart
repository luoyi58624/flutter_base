import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('精确监听器跳过未改变选择结果的通知', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    var builds = 0;
    await tester.pumpWidget(
      ElListenableBuilder<_Model, int>(
        listenable: model,
        select: (value) => value.count,
        builder: (_, _) {
          builds++;
          return Text('${model.count}', textDirection: TextDirection.ltr);
        },
      ),
    );
    model.refresh();
    await tester.pump();
    expect(builds, 1);
    model.count = 1;
    model.refresh();
    await tester.pump();
    expect(builds, 2);
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('临时布局将探测尺寸传给实际内容', (tester) async {
    Size? measured;
    await tester.pumpWidget(
      Center(
        child: ElChildSizeBuilder(
          tempChild: SizedBox(width: 30, height: 20),
          builder: (size) {
            measured = size;
            return SizedBox(
              key: ValueKey('actual'),
              width: size.width + 5,
              height: size.height,
            );
          },
        ),
      ),
    );
    expect(measured, Size(30, 20));
    expect(tester.getSize(find.byKey(ValueKey('actual'))), Size(35, 20));
  });

  testWidgets('透明度过渡响应显示状态', (tester) async {
    Widget scene(bool show) =>
        ElFadeAnimation(show, child: SizedBox(width: 10, height: 10));
    await tester.pumpWidget(scene(false));
    expect(
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value,
      0,
    );
    await tester.pumpWidget(scene(true));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value,
      1,
    );
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('折叠完成后按 keepState 参数移除内容', (tester) async {
    Widget scene(bool show) => ElCollapseAnimation(
      show,
      keepState: false,
      child: SizedBox(key: ValueKey('content'), width: 20, height: 20),
    );
    await tester.pumpWidget(scene(true));
    expect(find.byKey(ValueKey('content')), findsOneWidget);
    await tester.pumpWidget(scene(false));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('content')), findsNothing);
  });

  testWidgets('加载动画卸载后停止 ticker', (tester) async {
    await tester.pumpWidget(ElLoading(child: SizedBox(width: 10, height: 10)));
    await tester.pump(Duration(milliseconds: 100));
    expect(find.byType(RotationTransition), findsOneWidget);
    await tester.pumpWidget(SizedBox());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('无限滚动检查不足一屏的内容并响应禁用状态切换', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var loads = 0;
    Widget scene(bool disabled) => ElInfiniteScroll(
      controller: controller,
      disabled: disabled,
      delay: Duration.zero,
      onLoad: () => loads++,
      child: SingleChildScrollView(
        controller: controller,
        child: SizedBox(height: 100),
      ),
    );
    await tester.pumpWidget(scene(false));
    await tester.pump(Duration(milliseconds: 1));
    expect(loads, 1);
    await tester.pumpWidget(scene(true));
    await tester.pump(Duration(milliseconds: 1));
    expect(loads, 1);
    await tester.pumpWidget(scene(false));
    await tester.pump(Duration(milliseconds: 1));
    expect(loads, 2);
    await tester.pumpWidget(SizedBox());
  });

  test('帧率统计按窗口结算并忽略重复时间戳', () {
    final counter = ElFpsCounter();
    expect(counter.addBatch([0, 500000, 1000000]), isNull);
    expect(counter.addBatch([1000000, 1000001]), 2);
    counter.reset();
    expect(counter.addBatch([0, 1000000, 1000001]), 1);
  });

  test('帧率报告按给定刷新率计算掉帧和卡顿', () {
    final recorder = ElFpsRecorder(expectedRefreshRate: 100);
    recorder.addFrames([0, 10000, 30000, 30000]);
    final report = recorder.report();
    expect(report.frameCount, 3);
    expect(report.averageFps, closeTo(66.6667, 0.001));
    expect(report.droppedFrames, 1);
    expect(report.jankFrames, 1);
    expect(report.worstInterval, Duration(milliseconds: 20));
    recorder.reset();
    expect(recorder.frameCount, 0);
  });
}

class _Model extends ChangeNotifier {
  int count = 0;
  void refresh() => notifyListeners();
}
