import 'package:flutter_base/desktop.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 使用 ElView 已求值的样式，不在测试中重复执行样式回调。
ElStyle? _style(WidgetTester tester, ElView view) => tester.renderObject<ElRenderView>(find.byWidget(view)).style;

Widget _host(Widget child, {Brightness brightness = Brightness.light, ElStyle? style, bool compact = false}) {
  return DefaultTextStyle(
    style: const TextStyle(fontSize: 12),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ElView(
        themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
        child: ElComponentProvider(
          components: el.desktopComponents,
          child: ElView(
            style: ElStyle(vars: {ElementPlusThemeData.$compact: compact}).merge(style),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Finder _rootFinder() => find.descendant(of: find.byType(ElSwitch), matching: find.byType(ElView)).first;

Iterable<ElView> _views(WidgetTester tester) =>
    tester.widgetList<ElView>(find.descendant(of: find.byType(ElSwitch), matching: find.byType(ElView)));

/// 轨道 = 全组唯一声明了 border 的那个 ElView（inline 档不锁 width，不能按宽度找）
ElView _core(WidgetTester tester) => _views(tester).firstWhere((v) => _style(tester, v)?.border != null);

ElView _thumb(WidgetTester tester) =>
    _views(tester).firstWhere((v) => _style(tester, v)?.backgroundColor == const Color(0xffffffff));

Rect _rectOf(WidgetTester tester, Widget view) => tester.getRect(find.byWidget(view));

const _primary = Color(0xff409eff);
const _lightBorder = Color(0xffdcdfe6);
const _darkBorder = Color(0xff4c4d4f);

void main() {
  {
    testWidgets('切换按官方 300ms ease 滑动，圆块全程等大', (tester) async {
      final model = ValueNotifier(false);
      addTearDown(model.dispose);
      await tester.pumpWidget(_host(ElSwitch(modelValue: model)));
      await tester.pumpAndSettle();
      for (final on in [true, false]) {
        final before = _rectOf(tester, _thumb(tester));
        model.value = on;
        await tester.pump();
        for (var elapsed = 0; elapsed <= 300; elapsed += 30) {
          if (elapsed > 0) await tester.pump(Duration(milliseconds: 30));
          final thumb = _rectOf(tester, _thumb(tester));
          final core = _rectOf(tester, _core(tester));
          final progress = Cubic(0.25, 0.1, 0.25, 1).transform(elapsed / 300);
          final position = on ? progress : 1 - progress;
          expect(thumb.width, closeTo(before.width, 1e-6), reason: 'on=$on elapsed=$elapsed 圆块不拉伸');
          expect(thumb.height, closeTo(before.height, 1e-6));
          expect(thumb.width, closeTo(thumb.height, 1e-6));
          expect(thumb.left, closeTo(core.left + 2 + (core.width - 4 - thumb.width) * position, 0.25));
          expect(find.descendant(of: find.byType(ElSwitch), matching: find.byType(ScaleTransition)), findsNothing);
        }
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('默认关闭：轨道 45.5×26 取 off 色，滑块贴左', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (_) {})));

    final core = _core(tester);
    expect(_style(tester, core)?.height, 26);
    expect(_style(tester, core)?.borderRadius, const BorderRadius.all(Radius.circular(13)));
    expect(_style(tester, core)?.backgroundColor, _lightBorder);
    expect(_style(tester, core)?.alignment, Alignment.centerLeft);
    expect(_style(tester, core)?.padding, const EdgeInsets.all(2));

    expect(_style(tester, _thumb(tester))?.width, 22);
    expect(_style(tester, _thumb(tester))?.borderRadius, const BorderRadius.all(Radius.circular(11)));
  });

  testWidgets('打开：轨道换 on 色并解析成主色，滑块贴右', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(value: true, onChanged: (_) {})));
    await tester.pumpAndSettle();

    final core = _core(tester);
    expect(_style(tester, core)?.backgroundColor, _primary);
    expect(_style(tester, core)?.alignment, Alignment.centerRight);

    final render = tester.renderObject<ElRenderView>(find.byWidget(core));
    expect(render.committedResolvedStyle.box.backgroundColor, _primary);
  });

  testWidgets('暗色默认 off 色跟随 桌面预设的边框 token', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (_) {}), brightness: Brightness.dark));
    await tester.pumpAndSettle();

    expect(_style(tester, _core(tester))?.backgroundColor, _darkBorder);
  });

  testWidgets('点击取反回调，禁用与加载中都不回调', (tester) async {
    bool? next;
    await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (value) => next = value)));
    await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(next, isTrue);

    next = null;
    await tester.pumpWidget(_host(ElSwitch(value: false, disabled: true, onChanged: (value) => next = value)));
    await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse, warnIfMissed: false);
    await tester.pump();
    expect(next, isNull);
    expect(_style(tester, tester.widget<ElView>(_rootFinder()))?.onDisabled?.opacity, 0.6);

    await tester.pumpWidget(_host(ElSwitch(value: false, loading: true, onChanged: (value) => next = value)));
    await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse, warnIfMissed: false);
    await tester.pump();
    expect(next, isNull);
    expect(find.byType(ElLoading), findsOneWidget);

    // 收尾：loading 图标在无限旋转，换掉再结束
    await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (_) {})));
  });

  testWidgets('normal / compact 切换轨道与滑块', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (_) {}), style: ElStyle(), compact: true));
    expect(
      _views(tester).any((v) => _style(tester, v)?.width == 42 && _style(tester, v)?.height == 24),
      isTrue,
      reason: _views(tester).map((v) => '${_style(tester, v)?.width}x${_style(tester, v)?.height}').join(', '),
    );
    expect(_style(tester, _thumb(tester))?.width, 20);

    await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (_) {}), style: ElStyle(), compact: false));
    // normal：轨道 45.5×26，滑块 22。
    expect(
      _views(tester).any((v) => _style(tester, v)?.width == 45.5 && _style(tester, v)?.height == 26),
      isTrue,
      reason: _views(tester).map((v) => '${_style(tester, v)?.width}x${_style(tester, v)?.height}').join(', '),
    );
    expect(_style(tester, _thumb(tester))?.width, 22);
  });

  group('值通道', () {
    testWidgets('普通值：内部自持切换，视觉不依赖父级 rebuild', (tester) async {
      bool? next;
      // 父级不做任何 setState，只给初值
      await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (v) => next = v)));
      expect(_style(tester, _core(tester))?.alignment, Alignment.centerLeft);

      await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(next, isTrue);
      // 父级没重建，开关自己翻过去了
      expect(_style(tester, _core(tester))?.alignment, Alignment.centerRight);
    });

    testWidgets('modelValue：组内切换回写 Obs，外部改 Obs 组件跟随', (tester) async {
      final model = Obs<bool>(false);
      addTearDown(model.dispose);

      await tester.pumpWidget(_host(ElSwitch(modelValue: model)));
      expect(_style(tester, _core(tester))?.alignment, Alignment.centerLeft);

      // 组件 → 外部
      await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(model.value, isTrue);

      // 外部 → 组件（父级不重建）
      model.value = false;
      await tester.pumpAndSettle();
      expect(_style(tester, _core(tester))?.alignment, Alignment.centerLeft);
    });

    testWidgets('prop + ElForm：与表单 Map 双向直连', (tester) async {
      final form = Obs<Map<String, dynamic>>({'enabled': false});
      addTearDown(form.dispose);

      await tester.pumpWidget(
        _host(
          ElForm(
            modelValue: form,
            child: ElFormItem(prop: 'enabled', child: ElSwitch()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_style(tester, _core(tester))?.alignment, Alignment.centerLeft);

      // 组件 → 表单
      await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(form.value['enabled'], isTrue);

      // 表单 → 组件（值语义：替换整个 Map）
      form.value = {...form.value, 'enabled': false};
      await tester.pumpAndSettle();
      expect(_style(tester, _core(tester))?.alignment, Alignment.centerLeft);
    });

    testWidgets('表单初值在首帧就位，不闪一帧零值', (tester) async {
      final form = Obs<Map<String, dynamic>>({'enabled': true});
      addTearDown(form.dispose);

      await tester.pumpWidget(
        _host(
          ElForm(
            modelValue: form,
            child: ElFormItem(prop: 'enabled', child: ElSwitch()),
          ),
        ),
      );
      // 只 pump 一帧：首帧就应该是打开态
      expect(_style(tester, _core(tester))?.alignment, Alignment.centerRight);
    });
  });

  group('滑块与轨道圆环几何对齐', () {
    // 滑块圆必须与轨道端部半圆弧 100% 同心（贴左对左弧、贴右对右弧）：
    // 圆心重合 ⇒ 圆弧方向间隙处处 = 半径差 = (H-D)/2，再断言它等于直线段
    // 的上下间隙（= gap），两种密度 × 开/关 × inline 两态全锁。
    for (final compact in [false, true]) {
      final gap = 2.0;
      for (final on in [false, true]) {
        {
          testWidgets('compact=$compact on=$on：滑块与端部半圆弧同心，上下/圆弧间隙处处 = $gap', (tester) async {
            // 密度由主题宿主明确注入，普通局部 ElView 仍可覆盖。
            await tester.pumpWidget(
              _host(
                ElSwitch(value: on, onChanged: (_) {}),
                style: ElStyle(),
                compact: compact,
              ),
            );
            await tester.pumpAndSettle();

            final core = _rectOf(tester, _core(tester));
            final thumb = _rectOf(tester, _thumb(tester));
            final h = core.height;

            // 上下间隙：滑块与轨道直线段边缘等距（padding 对称）
            expect(thumb.top - core.top, closeTo(gap, 0.001));
            expect(core.bottom - thumb.bottom, closeTo(gap, 0.001));

            // 滑块圆心与轨道端部半圆圆心重合 → 圆弧方向间隙处处 = 半径差
            final arcCenter = Offset(on ? core.right - h / 2 : core.left + h / 2, core.center.dy);
            expect((thumb.center - arcCenter).distance, closeTo(0, 0.001));
            // 圆弧间隙 = 轨道半圆半径 - 滑块半径 = (H-D)/2，必须等于上下直线段间隙
            expect(h / 2 - thumb.width / 2, closeTo(gap, 0.001));
          });
        }
      }
    }
  });
}
