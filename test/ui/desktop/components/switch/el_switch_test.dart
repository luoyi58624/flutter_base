import 'package:flutter_base/src/ui/desktop/components/icon/index.dart';
import 'package:flutter_base/desktop.dart' hide ElIcon;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 使用 ElView 已求值的样式，不在测试中重复执行样式回调。
ElStyle? _style(WidgetTester tester, ElView view) =>
    tester.renderObject<ElRenderView>(find.byWidget(view)).style;

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  ElStyle? style,
  bool compact = false,
}) {
  return DefaultTextStyle(
    style: const TextStyle(fontSize: 12),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ElDesktopTheme(
        themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
        style: style,
        compact: compact,
        child: child,
      ),
    ),
  );
}

Finder _rootFinder() => find
    .descendant(of: find.byType(ElSwitch), matching: find.byType(ElView))
    .first;

Iterable<ElView> _views(WidgetTester tester) => tester.widgetList<ElView>(
  find.descendant(of: find.byType(ElSwitch), matching: find.byType(ElView)),
);

/// 轨道 = 全组唯一声明了 border 的那个 ElView（inline 档不锁 width，不能按宽度找）
ElView _core(WidgetTester tester) =>
    _views(tester).firstWhere((v) => _style(tester, v)?.border != null);

ElView _thumb(WidgetTester tester) =>
    _views(tester)
        .firstWhere((v) => _style(tester, v)?.backgroundColor == const Color(0xffffffff));

/// 轨道内显示内容 = child 是给定 Text 的 ElView（取最后一个——测量层在前，显示层在后）
ElView _promptView(WidgetTester tester, String data) =>
    _views(tester)
        .where((v) => v.child is Text && (v.child as Text).data == data)
        .last;

Rect _rectOf(WidgetTester tester, Widget view) =>
    tester.getRect(find.byWidget(view));

const _primary = Color(0xff409eff);
const _lightBorder = Color(0xffdcdfe6);
const _darkBorder = Color(0xff4c4d4f);

double _mix(double from, double to, double progress) =>
    from + (to - from) * progress;

void main() {
  for (final inline in [false, true]) {
    testWidgets('inline=$inline 切换按官方 300ms ease 滑动，圆块全程等大', (tester) async {
      final model = ValueNotifier(false);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _host(
          ElSwitch(
            modelValue: model,
            activeContent: inline ? 'ON' : null,
            inactiveContent: inline ? 'OFF' : null,
            activeActionContent: ElIcons.check,
            inactiveActionContent: ElIcons.close,
          ),
        ),
      );
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
          expect(
            thumb.width,
            closeTo(before.width, 1e-6),
            reason: 'on=$on elapsed=$elapsed 圆块不拉伸',
          );
          expect(thumb.height, closeTo(before.height, 1e-6));
          expect(thumb.width, closeTo(thumb.height, 1e-6));
          expect(
            thumb.left,
            closeTo(
              core.left + 2 + (core.width - 4 - thumb.width) * position,
              0.25,
            ),
          );
          expect(
            find.descendant(
              of: find.byType(ElSwitch),
              matching: find.byType(ScaleTransition),
            ),
            findsNothing,
          );
        }
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('slide=false 时位置和内容直接到终态', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(
        ElSwitch(
          modelValue: model,
          slide: false,
          activeContent: '开启',
          inactiveContent: '关闭',
        ),
      ),
    );
    await tester.pumpAndSettle();
    model.value = true;
    await tester.pump();
    final core = _rectOf(tester, _core(tester));
    final thumb = _rectOf(tester, _thumb(tester));
    expect(core.right - thumb.right, closeTo(2, 0.01));
    expect(thumb.width, 22);
    await tester.pumpAndSettle();
    expect(_rectOf(tester, _thumb(tester)), thumb);
  });

  testWidgets('默认关闭：轨道 45.5×26 取 off 色，滑块贴左', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (_) {})));

    final core = _core(tester);
    expect(_style(tester, core)?.height, 26);
    expect(
      _style(tester, core)?.borderRadius,
      const BorderRadius.all(Radius.circular(13)),
    );
    expect(_style(tester, core)?.backgroundColor, _lightBorder);
    expect(_style(tester, core)?.alignment, Alignment.centerLeft);
    expect(_style(tester, core)?.padding, const EdgeInsets.all(2));

    expect(_style(tester, _thumb(tester))?.width, 22);
    expect(
      _style(tester, _thumb(tester))?.borderRadius,
      const BorderRadius.all(Radius.circular(11)),
    );
  });

  testWidgets('打开：轨道换 on 色并解析成主色，滑块贴右', (tester) async {
    await tester.pumpWidget(_host(ElSwitch(value: true, onChanged: (_) {})));
    await tester.pumpAndSettle();

    final core = _core(tester);
    expect(_style(tester, core)?.backgroundColor, _primary);
    expect(_style(tester, core)?.alignment, Alignment.centerRight);

    final render = tester.renderObject<ElRenderView>(
      find
          .descendant(of: find.byType(ElSwitch), matching: find.byType(ElView))
          .at(1),
    );
    expect(render.committedResolvedStyle.box.backgroundColor, _primary);
  });

  testWidgets('暗色默认 off 色跟随 ElDesktopTheme border token', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(value: false, onChanged: (_) {}),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(_style(tester, _core(tester))?.backgroundColor, _darkBorder);
  });

  testWidgets('点击取反回调，禁用与加载中都不回调', (tester) async {
    bool? next;
    await tester.pumpWidget(
      _host(ElSwitch(value: false, onChanged: (value) => next = value)),
    );
    await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
    await tester.pump();
    expect(next, isTrue);

    next = null;
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: false,
          disabled: true,
          onChanged: (value) => next = value,
        ),
      ),
    );
    await tester.tap(
      _rootFinder(),
      kind: PointerDeviceKind.mouse,
      warnIfMissed: false,
    );
    await tester.pump();
    expect(next, isNull);
    expect(
      _style(tester, tester.widget<ElView>(_rootFinder()))?.onDisabled?.opacity,
      0.6,
    );

    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: false,
          loading: true,
          onChanged: (value) => next = value,
        ),
      ),
    );
    await tester.tap(
      _rootFinder(),
      kind: PointerDeviceKind.mouse,
      warnIfMissed: false,
    );
    await tester.pump();
    expect(next, isNull);
    expect(find.byType(ElLoading), findsOneWidget);

    // 收尾：loading 图标在无限旋转，换掉再结束
    await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (_) {})));
  });

  testWidgets('normal / compact 切换轨道与滑块', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(value: false, onChanged: (_) {}),
        style: ElStyle(),
        compact: true,
      ),
    );
    expect(
      _views(tester).any(
        (v) =>
            _style(tester, v)?.width == 42 && _style(tester, v)?.height == 24,
      ),
      isTrue,
      reason: _views(tester)
          .map(
            (v) => '${_style(tester, v)?.width}x${_style(tester, v)?.height}',
          )
          .join(', '),
    );
    expect(_style(tester, _thumb(tester))?.width, 20);

    await tester.pumpWidget(
      _host(
        ElSwitch(value: false, onChanged: (_) {}),
        style: ElStyle(),
        compact: false,
      ),
    );
    // normal：轨道 45.5×26，滑块 22。
    expect(
      _views(tester).any(
        (v) =>
            _style(tester, v)?.width == 45.5 && _style(tester, v)?.height == 26,
      ),
      isTrue,
      reason: _views(tester)
          .map(
            (v) => '${_style(tester, v)?.width}x${_style(tester, v)?.height}',
          )
          .join(', '),
    );
    expect(_style(tester, _thumb(tester))?.width, 22);
  });

  testWidgets('inlinePrompt 把内容画进轨道并让开滑块一侧', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: true,
          activeContent: Text('开'),
          inactiveContent: Text('关'),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_style(tester, _core(tester))?.alignment, isNull);
    // 内容层 = child 是 ElStackView 的那层（开/关两态内容常驻两层，外层承载让位 padding）
    final prompt = _views(tester).firstWhere(
      (v) => v.child is ClipRect && _style(tester, v)?.border == null,
    );
    // 让位侧 = 滑块直径 + 6（预留按下拉伸 1.18 倍的鼓出），文本侧 6px 呼吸距离
    expect(
      _style(tester, prompt)?.padding,
      const EdgeInsets.only(left: 8, right: 28),
    );
  });

  testWidgets('inlinePrompt 字符串的字形墨迹上下居中', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: true,
          activeContent: '开',
          inactiveContent: '关',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final core = _rectOf(tester, _core(tester));
    final prompt = _views(tester).firstWhere((v) => v.child == '开');
    final promptRect = _rectOf(tester, prompt);
    final render = tester.renderObject<ElRenderView>(find.byWidget(prompt));
    final engine = render.textEngineForTest!;
    final painter = engine.painterForTest;
    final boxes = engine.getBoxesForSelectionForTest(0, 1);
    expect(painter.size.height, 12, reason: '开关短文案不应携带默认行高的额外 leading');
    final glyphBox = boxes.single.toRect().shift(
      promptRect.topLeft + engine.textPaintOrigin,
    );
    expect(glyphBox.center.dy, closeTo(core.center.dy, 0.01));
  });

  group('inlinePrompt 轨道几何', () {
    testWidgets('轨道不锁宽、官方宽度只当下限，内容把轨道顶宽', (tester) async {
      await tester.pumpWidget(
        _host(
          ElSwitch(
            value: false,
            activeContent: Text('ON'),
            inactiveContent: Text('关闭状态'),
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final core = _core(tester);
      expect(
        _style(tester, core)?.width,
        isNull,
        reason: 'inline 档不锁宽，否则内容只能被裁掉',
      );
      expect(_style(tester, core)?.minWidth, 45.5);

      final coreWidth = _rectOf(tester, core).width;
      expect(
        coreWidth,
        greaterThan(45.5),
        reason: '"关闭状态" 放不进 45.5px，轨道必须自己长出来',
      );
      // 轨道 = 内容层（child 是 ElStackView 那层，含让位 padding）+ 两侧各 gaps（2px）内缩
      final prompt = _views(tester).firstWhere(
        (v) => v.child is ClipRect && _style(tester, v)?.border == null,
      );
      expect(coreWidth, closeTo(_rectOf(tester, prompt).width + 4, 0.01));
    });

    testWidgets('无内容时仍恰好是该档官方宽度', (tester) async {
      await tester.pumpWidget(_host(ElSwitch(value: false, onChanged: (_) {})));
      await tester.pumpAndSettle();
      expect(_rectOf(tester, _core(tester)).width, 45.5);
    });

    testWidgets('滑块两态都贴边，且始终让开内容', (tester) async {
      await tester.pumpWidget(
        _host(
          ElSwitch(
            value: false,
            activeContent: Text('ON'),
            inactiveContent: Text('OFF'),
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      var core = _rectOf(tester, _core(tester));
      var thumb = _rectOf(tester, _thumb(tester));
      // 关：贴左。2px 来自 core 的 padding —— border 在 el_ui 里纯绘制、不占布局
      expect(thumb.left - core.left, closeTo(2, 0.01));
      expect(thumb.width, 22);
      expect(thumb.center.dy, closeTo(core.center.dy, 0.01));
      // 文本与滑块的间隙 = 让位(滑块直径+6) - 滑块宽 = 6：拉伸鼓出 3.96 后仍余安全间隙
      final offPrompt = _rectOf(tester, _promptView(tester, 'OFF'));
      expect(offPrompt.left - thumb.right, closeTo(6, 0.01));

      await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      core = _rectOf(tester, _core(tester));
      thumb = _rectOf(tester, _thumb(tester));
      // 开：贴右，文本改让开右侧；ON 层较窄在 ElStackView 内居中，间隙 ≥ 6
      //（精确 6 在 ON 层与对侧层等宽时成立）
      expect(core.right - thumb.right, closeTo(2, 0.01));
      final onPrompt = _rectOf(tester, _promptView(tester, 'ON'));
      expect(thumb.left - onPrompt.right, greaterThanOrEqualTo(6));
    });

    testWidgets('轨道内 Widget 垂直居中，不贴顶', (tester) async {
      await tester.pumpWidget(
        _host(
          ElSwitch(
            value: false,
            inactiveContent: Text('OFF'),
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final core = _rectOf(tester, _core(tester));
      // 用户塞的 Widget 在内容层里垂直居中（内容层高 = 滑块直径，行盒更矮时靠 alignment 居中）
      final text = tester.getRect(find.text('OFF').first);
      expect(text.center.dy, closeTo(core.center.dy, 0.01));
    });

    testWidgets('轨道内图标垂直居中且取用户传入尺寸', (tester) async {
      await tester.pumpWidget(
        _host(
          ElSwitch(
            value: false,
            inactiveContent: const ElIcon(ElIcons.close, size: 11),
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final core = _rectOf(tester, _core(tester));
      final icon = tester.getRect(
        find
            .byWidgetPredicate((w) => w is ElIcon && w.child == ElIcons.close)
            .first,
      );
      expect(icon.center.dy, closeTo(core.center.dy, 0.01));
      // 尺寸由用户 Widget 自控（这里传 11 就渲染 11），不再有档位字号通道
      expect(icon.height, 11);

      // 内容层 alignment 锁 center（解析后的 render 样式上也锁一道），
      // 内容层 = child 是 ElStackView 的那层
      final prompt = _views(tester).firstWhere(
        (v) => v.child is ClipRect && _style(tester, v)?.border == null,
      );
      expect(
        tester
            .renderObject<ElRenderView>(find.byWidget(prompt))
            .committedResolvedStyle
            .box
            .alignment,
        Alignment.center,
      );
    });
  });

  testWidgets('字符串与 IconData 直传内容', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: true,
          activeContent: '开',
          inactiveContent: '关',
          activeActionContent: ElIcons.check,
          inactiveActionContent: ElIcons.close,
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 字符串走 ElView 文本载荷：外壳声明白色 + 12px 向下传递
    final root = tester.widget<ElView>(_rootFinder());
    expect(_style(tester, root)?.color, const Color(0xffffffff));
    expect(_style(tester, root)?.fontSize, 12);
    // 内容层渲染时吃到继承的白色
    final prompt = tester.renderObject<ElRenderView>(
      find.byWidget(_views(tester).firstWhere((v) => v.child == '开')),
    );
    expect(
      prompt.committedResolvedStyle.inheritedText.color,
      const Color(0xffffffff),
    );
    // IconData 被包成 ElIcon 落滑块内，颜色吃 currentColor = 滑块外壳轨道色
    final actionIcon = find.descendant(
      of: find.byWidget(_thumb(tester)),
      matching: find.byWidgetPredicate(
        (w) => w is ElIcon && w.child == ElIcons.check,
      ),
    );
    expect(actionIcon, findsOneWidget);
    final iconRender = tester.renderObject<ElRenderView>(actionIcon);
    expect(iconRender.committedResolvedStyle.inheritedBox.iconColor, _primary);
  });

  testWidgets('activeContent 落轨道内，activeActionContent 落滑块内', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: true,
          activeContent: const ElIcon(ElIcons.check, size: 11),
          activeActionContent: const ElIcon(ElIcons.close),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 轨道内内容层拿到 check（轨道内只有这一个内容位）
    final prompt = _views(tester).firstWhere(
      (v) => v.child is ElIcon && (v.child as ElIcon).child == ElIcons.check,
    );
    expect(
      find.descendant(
        of: find.byWidget(_core(tester)),
        matching: find.byWidget(prompt),
      ),
      findsOneWidget,
    );
    // 滑块内拿到 close
    expect(
      find.descendant(
        of: find.byWidget(_thumb(tester)),
        matching: find.byWidgetPredicate(
          (w) => w is ElIcon && w.child == ElIcons.close,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('切换动画中旧内容朝滑块方向移动（让位滑动方向锁定）', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: false,
          activeContent: Text('ON'),
          inactiveContent: Text('OFF'),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 静止时 OFF 在滑块让位区（贴滑块右缘 6px）
    final offRestingLeft = tester.getRect(find.text('OFF').last).left;

    // 点击切换（off → on）：滑块向右补间，旧内容（OFF）应朝滑块方向移动（左移）
    await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final offMidLeft = tester.getRect(find.text('OFF').last).left;
    expect(
      offMidLeft,
      lessThan(offRestingLeft - 0.5),
      reason: '切换动画中间帧旧内容已朝滑块方向移动',
    );

    await tester.pumpAndSettle();
  });

  testWidgets('文本长度不一致时轨道宽只跟随当前显示内容，不被对侧拉长', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: false,
          activeContent: '开',
          inactiveContent: '很长的关闭文案',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // off 态：轨道宽 = 短文本（'很长的关闭文案' 是 inactive——off 态显示它？）
    // ——off 态显示 inactive（长文本），on 态显示 active（短文本）
    final offWidth = _rectOf(tester, _core(tester)).width;
    expect(offWidth, greaterThan(45.5), reason: '长文本撑宽轨道');

    // 切到 on：轨道应收窄到短文本宽度（不被 inactive 长文本拉住）
    await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    final onWidth = _rectOf(tester, _core(tester)).width;
    expect(onWidth, lessThan(offWidth - 10), reason: 'on 态只显示短文本，轨道不再被长文本拉长');
  });

  testWidgets('内容档挂载后宽度稳定（无跳变）：首帧 Offstage 隐藏测量，可见帧与 500ms 后一致', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: false,
          activeContent: '开',
          inactiveContent: '很长的关闭文案',
          onChanged: (_) {},
        ),
      ),
    );
    // 首帧：内容宽尚未测量回填，组件 Offstage 隐藏（用户看不到官方宽兜底帧）
    expect(find.byType(Offstage), findsOneWidget, reason: '首帧 Offstage 隐藏测量');
    expect(
      tester.widget<Offstage>(find.byType(Offstage)).offstage,
      isTrue,
      reason: '首帧 offstage = true',
    );

    // 推一帧：测量回填生效，Offstage 解除，以正确宽度渲染（可见帧）
    await tester.pump();
    expect(find.byType(Offstage), findsNothing, reason: '测量回填后解除 Offstage');
    final firstWidth = _rectOf(tester, _core(tester)).width;
    expect(firstWidth, greaterThan(45.5), reason: '可见帧已是内容撑宽的实测宽');

    await tester.pump(const Duration(milliseconds: 500));
    final laterWidth = _rectOf(tester, _core(tester)).width;
    expect(laterWidth, closeTo(firstWidth, 0.5), reason: '可见帧与稳定后轨道宽一致，无跳动');
  });

  testWidgets('切换时轨道宽动画过渡（不瞬变），滑块位置精准同步', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: false,
          activeContent: '开',
          inactiveContent: '很长的关闭文案',
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final offWidth = _rectOf(tester, _core(tester)).width;

    // 切换：动画中间帧轨道宽介于新旧之间（不瞬变）
    await tester.tap(_rootFinder(), kind: PointerDeviceKind.mouse);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final midCore = _rectOf(tester, _core(tester));
    final midThumb = _rectOf(tester, _thumb(tester));
    expect(midCore.width, greaterThan(45.5), reason: '宽度动画中，未瞬缩');
    expect(midCore.width, lessThan(offWidth), reason: '宽度动画中，正在收缩');
    // 滑块同步：150ms 时 alignment 补间未完成，滑块在滑动中——既未贴左
    // 也未贴右，位置由「alignment 进度 × 当前滑动范围」决定（比例定位
    // 天然同步宽度动画，终态贴右在 settle 后断言）
    expect(midThumb.left, greaterThan(2), reason: '滑块已离开左端（滑动中）');
    expect(
      midThumb.right,
      lessThan(midCore.right - 2 + 0.5),
      reason: '滑块未到右端（滑动中）',
    );
    expect(
      midThumb.left,
      lessThan(2 + (midCore.width - 4 - 22)),
      reason: '滑块位置在滑动范围内',
    );

    await tester.pumpAndSettle();
    expect(
      _rectOf(tester, _core(tester)).width,
      lessThan(offWidth - 10),
      reason: '动画完成后轨道收窄到短文本',
    );
    expect(
      _rectOf(tester, _core(tester)).right -
          _rectOf(tester, _thumb(tester)).right,
      closeTo(2, 0.01),
    );
  });

  group('值通道', () {
    testWidgets('普通值：内部自持切换，视觉不依赖父级 rebuild', (tester) async {
      bool? next;
      // 父级不做任何 setState，只给初值
      await tester.pumpWidget(
        _host(ElSwitch(value: false, onChanged: (v) => next = v)),
      );
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

  testWidgets('activeColor / inactiveColor 就地覆盖轨道色', (tester) async {
    await tester.pumpWidget(
      _host(
        ElSwitch(
          value: true,
          activeColor: const Color(0xff13ce66),
          onChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final render = tester.renderObject<ElRenderView>(
      find
          .descendant(of: find.byType(ElSwitch), matching: find.byType(ElView))
          .at(1),
    );
    expect(render.committedResolvedStyle.box.backgroundColor, const Color(0xff13ce66));
  });

  testWidgets('显式 height 覆写后行高固定不随档', (tester) async {
    await tester.pumpWidget(
      _host(ElSwitch(value: false, height: 30, onChanged: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(_style(tester, tester.widget<ElView>(_rootFinder()))?.height, 30);

    // 换紧凑密度后仍钉死显式高度 30。
    await tester.pumpWidget(
      _host(
        ElSwitch(value: false, height: 30, onChanged: (_) {}),
        style: ElStyle(),
        compact: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(_style(tester, tester.widget<ElView>(_rootFinder()))?.height, 30);
  });

  testWidgets('显式 widthAspect 与尺寸档高度组合', (tester) async {
    await tester.pumpWidget(
      _host(
        ElView(
          style: ElStyle(vars: {ElDesktopTheme.$compact: true}),
          child: ElSwitch(
            value: false,
            style: ElStyle(),
            widthAspect: 1.6,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_rectOf(tester, _core(tester)).width, closeTo(38.4, 0.01));
  });

  testWidgets('尺寸变化时滑块逐帧跟随轨道几何，不跳位', (tester) async {
    const durationMs = 300;
    const oldHeight = 26.0;
    const newHeight = 30.0;
    const oldGap = 2.0;
    const newGap = 3.0;
    const oldAspect = 1.5;
    const newAspect = 1.8;

    for (final on in [false, true]) {
      await tester.pumpWidget(
        _host(
          ElSwitch(
            value: on,
            height: oldHeight,
            gap: oldGap,
            widthAspect: oldAspect,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(
          ElSwitch(
            value: on,
            height: newHeight,
            gap: newGap,
            widthAspect: newAspect,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      for (var elapsedMs = 0; elapsedMs <= durationMs; elapsedMs += 16) {
        if (elapsedMs != 0) await tester.pump(const Duration(milliseconds: 16));

        final progress = Curves.ease.transform(
          (elapsedMs / durationMs).clamp(0.0, 1.0),
        );
        final height = _mix(oldHeight, newHeight, progress);
        final gap = _mix(oldGap, newGap, progress);
        final width = _mix(
          oldHeight * oldAspect,
          newHeight * newAspect,
          progress,
        );
        final thumbSize = _mix(
          oldHeight - 2 * oldGap,
          newHeight - 2 * newGap,
          progress,
        );
        final core = _rectOf(tester, _core(tester));
        final thumb = _rectOf(tester, _thumb(tester));
        final expectedLeft = on
            ? core.left + width - gap - thumbSize
            : core.left + gap;
        final frame = 'on=$on elapsed=${elapsedMs}ms progress=$progress';

        expect(core.width, closeTo(width, 0.25), reason: '$frame core width');
        expect(
          core.height,
          closeTo(height, 0.25),
          reason: '$frame core height',
        );
        expect(
          thumb.width,
          closeTo(thumbSize, 0.25),
          reason: '$frame thumb size',
        );
        expect(
          thumb.left,
          closeTo(expectedLeft, 0.25),
          reason: '$frame thumb left',
        );
        expect(
          thumb.top,
          closeTo(core.top + gap, 0.25),
          reason: '$frame thumb top',
        );
        expect(
          thumb.center.dy,
          closeTo(core.center.dy, 0.25),
          reason: '$frame thumb center y',
        );
      }
      await tester.pumpAndSettle();
    }
  });

  group('滑块与轨道圆环几何对齐', () {
    // 滑块圆必须与轨道端部半圆弧 100% 同心（贴左对左弧、贴右对右弧）：
    // 圆心重合 ⇒ 圆弧方向间隙处处 = 半径差 = (H-D)/2，再断言它等于直线段
    // 的上下间隙（= gap），两种密度 × 开/关 × inline 两态全锁。
    for (final compact in [false, true]) {
      final gap = 2.0;
      for (final on in [false, true]) {
        for (final inline in [false, true]) {
          testWidgets('compact=$compact on=$on inline=$inline：滑块与端部半圆弧同心，上下/圆弧间隙处处 = $gap', (tester) async {
            // 密度由主题宿主明确注入，普通局部 ElView 仍可覆盖。
            await tester.pumpWidget(
              _host(
                ElSwitch(
                  value: on,
                  activeContent: inline ? Text('ON') : null,
                  inactiveContent: inline ? Text('OFF') : null,
                  onChanged: (_) {},
                ),
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
              final arcCenter = Offset(
                on ? core.right - h / 2 : core.left + h / 2,
                core.center.dy,
              );
              expect((thumb.center - arcCenter).distance, closeTo(0, 0.001));
              // 圆弧间隙 = 轨道半圆半径 - 滑块半径 = (H-D)/2，必须等于上下直线段间隙
              expect(h / 2 - thumb.width / 2, closeTo(gap, 0.001));
            },
          );
        }
      }
    }
  });
}
