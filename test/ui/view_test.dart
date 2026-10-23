import 'dart:ui' show ColorSpace;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = ValueKey('view');
const _red = Color(0xffff0000), _blue = Color(0xff0000ff);
const _linear = [ElTransition.all(Duration(milliseconds: 100), Curves.linear)];

Widget _scene(
  ElStyle style, {
  Widget? child,
  double width = 400,
  double height = 300,
  TextDirection direction = TextDirection.ltr,
  bool enabled = true,
  bool disabled = false,
}) => Directionality(
  textDirection: direction,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: disabled),
    child: TickerMode(
      enabled: enabled,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: height),
          child: ElView(key: _key, style: style, child: child),
        ),
      ),
    ),
  ),
);

RenderBox _box(WidgetTester tester) => tester.renderObject(find.byKey(_key));
Size _size(WidgetTester tester) => _box(tester).size;
Future<void> _advance(WidgetTester tester, int ms) =>
    tester.pump(Duration(milliseconds: ms));

Color _color(RenderBox box) {
  Color? result;
  expect(
    box,
    paints..something((method, arguments) {
      if (method != #drawRect) return false;
      result = (arguments[1] as Paint).color;
      return true;
    }),
  );
  return result!;
}

void main() {
  test('生成的复制支持显式置空，合并保留未声明字段并替换列表', () {
    const a = ElStyle(width: 80, backgroundColor: _red, transitions: _linear);
    expect(a.copyWith(), a);
    expect(
      a.copyWith(width: null, backgroundColor: null, transitions: null),
      const ElStyle(),
    );
    expect(a.merge(const ElStyle(height: 40)), a.copyWith(height: 40));
    expect(
      a.merge(const ElStyle(transitions: [])),
      a.copyWith(transitions: <ElTransition>[]),
    );
    expect(
      a,
      ElStyle(width: 80, backgroundColor: _red, transitions: List.of(_linear)),
    );
    expect(a.hashCode, a.copyWith().hashCode);
  });

  testWidgets('单渲染对象：盒模型、绘制范围、命中、干布局和固有尺寸', (tester) async {
    const childKey = ValueKey('child');
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 120,
          height: 80,
          padding: EdgeInsets.all(10),
          margin: EdgeInsets.all(5),
          backgroundColor: _red,
        ),
        child: const SizedBox(key: childKey, width: 20, height: 15),
      ),
    );
    final box = _box(tester),
        child = tester.renderObject<RenderBox>(find.byKey(childKey));
    expect(child.parent, same(box));
    expect(_size(tester), const Size(130, 90));
    expect(child.size, const Size(20, 15));
    expect((child.parentData! as BoxParentData).offset, const Offset(15, 15));
    expect(
      box.getDryLayout(const BoxConstraints(maxWidth: 400, maxHeight: 300)),
      box.size,
    );
    expect(box.getMaxIntrinsicWidth(300), 130);
    expect(box.getMaxIntrinsicHeight(400), 90);
    expect(
      box,
      paints..rect(rect: const Rect.fromLTWH(5, 5, 120, 80), color: _red),
    );
    expect(
      box.hitTest(BoxHitTestResult(), position: const Offset(1, 1)),
      isFalse,
    );
    expect(
      box.hitTest(BoxHitTestResult(), position: const Offset(6, 6)),
      isTrue,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('自动尺寸、方向性边距和父最小约束', (tester) async {
    await tester.pumpWidget(
      _scene(
        const ElStyle(padding: EdgeInsetsDirectional.fromSTEB(10, 2, 30, 4)),
        direction: TextDirection.rtl,
        child: const SizedBox(width: 20, height: 15),
      ),
    );
    expect(_size(tester), const Size(60, 21));
    final child = (_box(tester) as RenderShiftedBox).child!;
    expect((child.parentData! as BoxParentData).offset, const Offset(30, 2));
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: ElView(key: _key, child: SizedBox(width: 20, height: 15)),
          ),
        ),
      ),
    );
    expect((_box(tester) as RenderShiftedBox).child!.size, const Size(100, 80));
    await tester.pumpWidget(_scene(const ElStyle()));
    expect(_size(tester), Size.zero);
  });

  testWidgets('百分比按去除 margin 的可用尺寸求值，嵌套使用内容尺寸', (tester) async {
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: '50%',
          height: '50%',
          margin: EdgeInsets.all(10),
          padding: EdgeInsets.all(10),
        ),
        child: const ElView(
          style: ElStyle(width: '50%', height: '50%'),
        ),
      ),
    );
    expect(_size(tester), const Size(210, 160));
    expect((_box(tester) as RenderShiftedBox).child!.size, const Size(85, 60));
  });

  testWidgets('无界轴穿过 Column 寻找确定的祖先参照，参照变化使后代失效', (tester) async {
    const childKey = ValueKey('percent');
    const child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElView(
          key: childKey,
          style: ElStyle(width: 10, height: '50%'),
        ),
      ],
    );
    await tester.pumpWidget(_scene(const ElStyle(height: 200), child: child));
    expect(tester.getSize(find.byKey(childKey)).height, 100);
    await tester.pumpWidget(_scene(const ElStyle(height: 280), child: child));
    expect(tester.getSize(find.byKey(childKey)).height, 140);
    await tester.pumpWidget(
      _scene(
        const ElStyle(),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElView(
              key: childKey,
              style: ElStyle(height: '50%'),
              child: SizedBox(height: 20),
            ),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(childKey)).height, 20);
  });

  testWidgets('px 与百分比混合插值，父尺寸变化和中断从当前值接续', (tester) async {
    await tester.pumpWidget(
      _scene(const ElStyle(width: 100, height: 20, transitions: _linear)),
    );
    await tester.pumpWidget(
      _scene(const ElStyle(width: '50%', height: 20, transitions: _linear)),
    );
    await _advance(tester, 50);
    expect(_size(tester).width, 150);
    await tester.pumpWidget(
      _scene(
        const ElStyle(width: '50%', height: 20, transitions: _linear),
        width: 600,
      ),
    );
    expect(_size(tester).width, 200);
    await tester.pumpWidget(
      _scene(
        const ElStyle(width: 80, height: 20, transitions: _linear),
        width: 600,
      ),
    );
    expect(_size(tester).width, 200);
    await _advance(tester, 50);
    expect(_size(tester).width, 140);
    await _advance(tester, 50);
    expect(_size(tester).width, 80);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('相同目标或另一属性变化不重启已有轨道', (tester) async {
    await tester.pumpWidget(
      _scene(const ElStyle(width: 100, transitions: _linear)),
    );
    await tester.pumpWidget(
      _scene(const ElStyle(width: 200, transitions: _linear)),
    );
    await _advance(tester, 25);
    await tester.pumpWidget(
      _scene(ElStyle(width: 200, transitions: List.of(_linear))),
    );
    await _advance(tester, 25);
    await tester.pumpWidget(
      _scene(
        const ElStyle(width: 200, backgroundColor: _red, transitions: _linear),
      ),
    );
    await _advance(tester, 50);
    expect(_size(tester).width, 200);
    expect(_color(_box(tester)).a, closeTo(.5, .005));
    await _advance(tester, 50);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('auto 双向过渡使用已更新的真实子布局，支持 LayoutBuilder', (tester) async {
    Widget child(double width, double height) => LayoutBuilder(
      builder: (_, _) => SizedBox(width: width, height: height),
    );
    await tester.pumpWidget(
      _scene(const ElStyle(transitions: _linear), child: child(80, 30)),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(width: 200, height: 100, transitions: _linear),
        child: child(80, 30),
      ),
    );
    expect(_size(tester), const Size(80, 30));
    await _advance(tester, 50);
    expect(_size(tester), const Size(140, 65));
    await _advance(tester, 50);
    await tester.pumpWidget(
      _scene(const ElStyle(transitions: _linear), child: child(120, 40)),
    );
    expect(_size(tester), const Size(200, 100));
    await _advance(tester, 50);
    expect(_size(tester), const Size(160, 70));
    await _advance(tester, 50);
    expect(_size(tester), const Size(120, 40));
    await tester.pumpWidget(
      _scene(const ElStyle(transitions: _linear), child: child(150, 60)),
    );
    expect(_size(tester), const Size(150, 60));
  });

  testWidgets('自动尺寸目标在途中变化保持当前画面和原截止时间', (tester) async {
    await tester.pumpWidget(
      _scene(
        const ElStyle(width: 200, transitions: _linear),
        child: const SizedBox(width: 100),
      ),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(transitions: _linear),
        child: const SizedBox(width: 100),
      ),
    );
    await _advance(tester, 50);
    expect(_size(tester).width, 150);
    await tester.pumpWidget(
      _scene(
        const ElStyle(transitions: _linear),
        child: const SizedBox(width: 180),
      ),
    );
    expect(_size(tester).width, 150);
    await _advance(tester, 25);
    expect(_size(tester).width, 165);
    await _advance(tester, 25);
    expect(_size(tester).width, 180);
  });

  testWidgets('透明色使用预乘 alpha，null 过渡终点停止绘制', (tester) async {
    const transparentBlue = Color(0x000000ff);
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 40,
          height: 40,
          backgroundColor: _red,
          transitions: _linear,
        ),
      ),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 40,
          height: 40,
          backgroundColor: transparentBlue,
          transitions: _linear,
        ),
      ),
    );
    await _advance(tester, 50);
    var color = _color(_box(tester));
    expect(color.r, 1);
    expect(color.b, 0);
    expect(color.a, closeTo(.5, .005));
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 40,
          height: 40,
          backgroundColor: _blue,
          transitions: _linear,
        ),
      ),
    );
    expect(_color(_box(tester)), color);
    await _advance(tester, 50);
    color = _color(_box(tester));
    expect(color.a, closeTo(.75, .005));
    expect(color.r, closeTo(1 / 3, .005));
    expect(color.b, closeTo(2 / 3, .005));
    await _advance(tester, 50);
    await tester.pumpWidget(
      _scene(const ElStyle(width: 40, height: 40, transitions: _linear)),
    );
    await _advance(tester, 50);
    expect(_color(_box(tester)).b, 1);
    await _advance(tester, 50);
    expect(_box(tester), paintsNothing);
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 40,
          height: 40,
          backgroundColor: _red,
          transitions: _linear,
        ),
      ),
    );
    await _advance(tester, 50);
    expect(_color(_box(tester)).r, 1);
    expect(_color(_box(tester)).a, closeTo(.5, .005));
  });

  testWidgets('不同色域与半透明颜色过渡保持有限通道值', (tester) async {
    const p3 = Color.from(
      alpha: .2,
      red: 0,
      green: 1,
      blue: 0,
      colorSpace: ColorSpace.displayP3,
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 40,
          height: 40,
          backgroundColor: _red,
          transitions: _linear,
        ),
      ),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 40,
          height: 40,
          backgroundColor: p3,
          transitions: _linear,
        ),
      ),
    );
    await _advance(tester, 50);
    final color = _color(_box(tester));
    expect(color.a, closeTo(.6, .005));
    expect([color.r, color.g, color.b].every((v) => v.isFinite), isTrue);
    await _advance(tester, 49);
    final extended = p3.withValues(colorSpace: ColorSpace.extendedSRGB);
    expect(
      _color(_box(tester)).r,
      closeTo((.01 + extended.r * .198) / .208, .00001),
    );
    await _advance(tester, 1);
    expect(_color(_box(tester)), isSameColorAs(p3));
    expect(_color(_box(tester)).colorSpace, p3.colorSpace);
  });

  testWidgets('边距方向变化与显式清空均参与过渡', (tester) async {
    const style = ElStyle(
      width: 100,
      height: 50,
      padding: EdgeInsetsDirectional.only(start: 20),
      margin: EdgeInsets.all(10),
      transitions: _linear,
    );
    const child = SizedBox(width: 10, height: 10);
    await tester.pumpWidget(_scene(style, child: child));
    await tester.pumpWidget(
      _scene(
        style.copyWith(margin: null),
        direction: TextDirection.rtl,
        child: child,
      ),
    );
    await _advance(tester, 50);
    expect(_size(tester), const Size(110, 60));
    final renderChild = (_box(tester) as RenderShiftedBox).child!;
    expect(
      (renderChild.parentData! as BoxParentData).offset,
      const Offset(15, 5),
    );
    await _advance(tester, 50);
    expect((renderChild.parentData! as BoxParentData).offset, Offset.zero);
  });

  testWidgets('逐字段配置、delay、零时长延迟和移除过渡', (tester) async {
    const config = [
      ElTransition.all(Duration(milliseconds: 100), Curves.linear),
      ElTransition.field(
        ElTransitionField.width,
        Duration.zero,
        Curves.linear,
        Duration(milliseconds: 50),
      ),
    ];
    await tester.pumpWidget(
      _scene(const ElStyle(width: 100, height: 20, transitions: config)),
    );
    await tester.pumpWidget(
      _scene(const ElStyle(width: 200, height: 120, transitions: config)),
    );
    await _advance(tester, 25);
    expect(_size(tester), const Size(100, 45));
    await _advance(tester, 25);
    expect(_size(tester), const Size(200, 70));
    await tester.pumpWidget(_scene(const ElStyle(width: 200, height: 120)));
    expect(_size(tester), const Size(200, 120));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('TickerMode 静音期间新目标使用自己的起点，减少动态效果立即结束', (tester) async {
    await tester.pumpWidget(
      _scene(const ElStyle(width: 100, transitions: _linear)),
    );
    await tester.pumpWidget(
      _scene(const ElStyle(width: 200, transitions: _linear)),
    );
    await _advance(tester, 25);
    await tester.pumpWidget(
      _scene(const ElStyle(width: 200, transitions: _linear), enabled: false),
    );
    await _advance(tester, 100);
    expect(_size(tester).width, 125);
    await tester.pumpWidget(
      _scene(const ElStyle(width: 300, transitions: _linear), enabled: false),
    );
    await _advance(tester, 50);
    await tester.pumpWidget(
      _scene(const ElStyle(width: 300, transitions: _linear)),
    );
    await tester.pump();
    expect(_size(tester).width, 212.5);
    await tester.pumpWidget(
      _scene(const ElStyle(width: 300, transitions: _linear), disabled: true),
    );
    expect(_size(tester).width, 300);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('颜色帧只重绘，不布局或重建 child；卸载释放 ticker', (tester) async {
    var builds = 0;
    final child = Builder(
      builder: (_) {
        builds++;
        return const SizedBox(width: 20, height: 20);
      },
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(backgroundColor: _red, transitions: _linear),
        child: child,
      ),
    );
    final box = _box(tester);
    await tester.pumpWidget(
      _scene(
        const ElStyle(backgroundColor: _blue, transitions: _linear),
        child: child,
      ),
    );
    await tester.pump(const Duration(milliseconds: 50), EnginePhase.build);
    expect(box.debugNeedsLayout, isFalse);
    expect(box.debugNeedsPaint, isTrue);
    expect(builds, 1);
    expect(_box(tester), same(box));
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final target in <Object>['50%', 100]) {
    testWidgets('百分比参照消失时保持连续：目标 $target', (tester) async {
      Widget host(ElStyle style, {bool bounded = true}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: UnconstrainedBox(
            constrainedAxis: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: bounded ? 400 : double.infinity,
              ),
              child: ElView(
                key: _key,
                style: style,
                child: const SizedBox(width: 80, height: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        host(
          ElStyle(width: target is String ? 100 : '50%', transitions: _linear),
        ),
      );
      final end = ElStyle(width: target, transitions: _linear);
      await tester.pumpWidget(host(end));
      await _advance(tester, 50);
      expect(_size(tester).width, 150);
      await tester.pumpWidget(host(end, bounded: false));
      expect(_size(tester).width, 150);
      await _advance(tester, 25);
      expect(_size(tester).width, target is String ? 115 : 125);
      await _advance(tester, 25);
      expect(_size(tester).width, target is String ? 80 : 100);
    });
  }

  testWidgets('两个透明端点跨色域不触发 Color.lerp 限制', (tester) async {
    const a = Color.from(alpha: 0, red: 1, green: 0, blue: 0);
    const b = Color.from(
      alpha: 0,
      red: 0,
      green: 0,
      blue: 1,
      colorSpace: ColorSpace.displayP3,
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 20,
          height: 20,
          backgroundColor: a,
          transitions: _linear,
        ),
      ),
    );
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 20,
          height: 20,
          backgroundColor: b,
          transitions: _linear,
        ),
      ),
    );
    await _advance(tester, 50);
    expect(tester.takeException(), isNull);
    expect(_color(_box(tester)).a, 0);
  });

  testWidgets('百分比重新获得参照时从当前尺寸接续到原截止时间', (tester) async {
    Widget host(ElStyle style, bool bounded) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: UnconstrainedBox(
          constrainedAxis: Axis.vertical,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: bounded ? 400 : double.infinity,
            ),
            child: ElView(
              key: _key,
              style: style,
              child: const SizedBox(width: 80),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      host(const ElStyle(width: 200, transitions: _linear), false),
    );
    const target = ElStyle(width: '50%', transitions: _linear);
    await tester.pumpWidget(host(target, false));
    await _advance(tester, 50);
    expect(_size(tester).width, 140);
    await tester.pumpWidget(host(target, true));
    expect(_size(tester).width, 140);
    await _advance(tester, 25);
    expect(_size(tester).width, 170);
    await _advance(tester, 25);
    expect(_size(tester).width, 200);
  });

  testWidgets('GlobalKey 重挂接保留渲染对象与正在运行的动画', (tester) async {
    final key = GlobalKey();
    Widget host(bool right, double width) {
      final view = ElView(
        key: key,
        style: ElStyle(width: width, height: 20, transitions: _linear),
      );
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Row(
            children: [
              SizedBox(width: 250, child: Center(child: right ? null : view)),
              SizedBox(width: 250, child: Center(child: right ? view : null)),
            ],
          ),
        ),
      );
    }

    await tester.pumpWidget(host(false, 100));
    final box = tester.renderObject<RenderBox>(find.byKey(key));
    await tester.pumpWidget(host(false, 200));
    await _advance(tester, 50);
    await tester.pumpWidget(host(true, 200));
    expect(tester.renderObject(find.byKey(key)), same(box));
    expect(box.size.width, 150);
    await _advance(tester, 50);
    expect(box.size.width, 200);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('真实基线与干基线一致，包含 margin 和 padding', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Baseline(
            baseline: 80,
            baselineType: TextBaseline.alphabetic,
            child: ElView(
              key: _key,
              style: ElStyle(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.all(3),
              ),
              child: Text('baseline', style: TextStyle(fontSize: 20)),
            ),
          ),
        ),
      ),
    );
    final box = _box(tester), child = (_box(tester) as RenderShiftedBox).child!;
    final baseline =
        child.getDryBaseline(child.constraints, TextBaseline.alphabetic)! + 11;
    expect((box.parentData! as BoxParentData).offset.dy + baseline, 80);
    expect(
      box.getDryBaseline(box.constraints, TextBaseline.alphabetic),
      baseline,
    );
  });

  testWidgets('曲线过冲不会产生负尺寸、负边距或越界 alpha', (tester) async {
    const transitions = [
      ElTransition.all(Duration(milliseconds: 100), Curves.easeOutBack),
    ];
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          width: 100,
          height: 100,
          padding: EdgeInsets.all(10),
          margin: EdgeInsets.all(10),
          backgroundColor: _red,
          transitions: transitions,
        ),
      ),
    );
    await tester.pumpWidget(
      _scene(const ElStyle(width: 0, height: 0, transitions: transitions)),
    );
    await _advance(tester, 60);
    expect(_size(tester), Size.zero);
    expect(_color(_box(tester)).a, 0);
    await _advance(tester, 40);
    expect(_box(tester), paintsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('固有尺寸的交叉轴百分比与真实盒模型使用相同的 margin 参照', (tester) async {
    await tester.pumpWidget(
      _scene(
        const ElStyle(
          height: '50%',
          padding: EdgeInsets.all(5),
          margin: EdgeInsets.all(10),
        ),
        child: const AspectRatio(aspectRatio: 2),
      ),
    );
    final box = _box(tester);
    expect(box.getMinIntrinsicWidth(100), 90);
    expect(box.getMaxIntrinsicWidth(100), 90);
    expect(
      box.getDryLayout(const BoxConstraints(maxWidth: 400, maxHeight: 100)),
      const Size(90, 60),
    );
  });
}
