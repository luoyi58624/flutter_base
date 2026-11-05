import 'package:flutter_base/desktop.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// 键盘遍历由 Flutter 应用的默认 Shortcuts / Actions 提供。
Widget _host(Widget child, {Brightness brightness = .light}) => WidgetsApp(
  color: Color(0xffffffff),
  builder: (context, _) => FocusScope(
    autofocus: true,
    child: Directionality(
      textDirection: .ltr,
      child: ElDesktopTheme(
        themeMode: ElThemeMode(brightness: brightness),
        child: child,
      ),
    ),
  ),
);
Finder _body() => find
    .descendant(of: find.byType(ElTag), matching: find.byType(ElView))
    .at(1);
ElRenderView _render(WidgetTester tester) =>
    tester.renderObject<ElRenderView>(_body());
Color? _bg(WidgetTester tester) =>
    _render(tester).committedResolvedStyle.box.backgroundColor;
Color? _border(WidgetTester tester) =>
    _render(tester).committedResolvedStyle.box.border?.borderTop.borderColor;
const _white = Color(0xffffffff);
const _primary = Color(0xff409eff);
const _info = Color(0xff909399);
const _success = Color(0xff67c23a);

void main() {
  testWidgets('默认标签采用圆润轮廓、26 高度与柔和底色', (tester) async {
    await tester.pumpWidget(_host(ElTag(child: '标签')));
    final style = _render(tester).style!;
    expect(style.height, 26);
    expect(style.padding, EdgeInsets.symmetric(horizontal: 12));
    expect(style.fontSize, 12);
    expect(style.borderRadius, BorderRadius.all(Radius.circular(26 * .45)));
    expect(_bg(tester), _primary.mix(_white, 90));
    expect(_border(tester), _primary.mix(_white, 80));
  });

  testWidgets('dark、plain、hit 和 round 保留独立外观', (tester) async {
    await tester.pumpWidget(_host(ElTag(effect: .dark, child: '标签')));
    expect(_bg(tester), _primary);
    expect(_render(tester).committedResolvedStyle.inheritedText.color, _white);
    await tester.pumpWidget(
      _host(ElTag(effect: .plain, type: .success, child: '标签')),
    );
    await tester.pumpAndSettle();
    expect(_bg(tester), const Color(0xffffffff));
    expect(_border(tester), _success.mix(_white, 80));
    await tester.pumpWidget(_host(ElTag(hit: true, round: true, child: '标签')));
    await tester.pumpAndSettle();
    expect(_border(tester), _primary);
    expect(
      _render(tester).style!.borderRadius,
      BorderRadius.all(Radius.circular(9999)),
    );
  });

  testWidgets('normal / compact 经局部变量传递，关闭图标保持独立尺寸', (tester) async {
    for (final (compact, height, icon) in [
      (true, 24.0, 14.0),
      (false, 26.0, 14.0),
    ]) {
      await tester.pumpWidget(
        _host(
          ElView(
            style: ElStyle(vars: {ElDesktopTheme.$compact: compact}),
            child: ElTag(closable: true, style: ElStyle(), child: '标签'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_render(tester).style!.height, height);
      expect(
        tester
            .renderObject<ElRenderView>(find.byType(ElButtonView))
            .style!
            .width,
        icon,
      );
    }
  });

  testWidgets('关闭动作不冒泡成标签点击或切换', (tester) async {
    for (final toggle in [false, true]) {
      var closed = 0;
      var clicked = 0;
      var changed = 0;
      final tag = toggle
          ? ElTag.toggle(
              closable: true,
              onClose: () => closed++,
              onChanged: (_) => changed++,
              event: ElEvent(onTap: (_) => clicked++),
              child: '标签',
            )
          : ElTag(
              closable: true,
              onClose: () => closed++,
              event: ElEvent(onTap: (_) => clicked++),
              child: '标签',
            );
      await tester.pumpWidget(_host(tag));
      await tester.tap(find.byType(ElButtonView), kind: .mouse);
      await tester.pump();
      expect(closed, 1);
      expect(clicked, 0);
      expect(changed, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(closed, 2);
      expect(changed, 0);
      expect(clicked, 0);
    }
  });

  testWidgets('关闭按钮有独立语义与焦点', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _host(
          ElTag(
            closable: true,
            closeSemanticLabel: '移除标签',
            onClose: () {},
            child: '标签',
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(ElButtonView)),
        matchesSemantics(
          label: '移除标签',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('toggle 默认关闭，点击自持并使用主题色', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      _host(ElTag.toggle(type: .success, onChanged: changes.add, child: '可选')),
    );
    expect(_bg(tester), _info.mix(_white, 90));
    await tester.tap(_body(), kind: .mouse);
    await tester.pumpAndSettle();
    expect(changes, [true]);
    expect(_bg(tester), _success.mix(_white, 90));
    await tester.tap(_body(), kind: .mouse);
    await tester.pumpAndSettle();
    expect(changes, [true, false]);
  });

  testWidgets('value 回灌不产生回调，modelValue 双向同步', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      _host(ElTag.toggle(value: false, onChanged: changes.add, child: '可选')),
    );
    await tester.pumpWidget(
      _host(ElTag.toggle(value: true, onChanged: changes.add, child: '可选')),
    );
    expect(changes, isEmpty);
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    await tester.pumpWidget(
      _host(ElTag.toggle(modelValue: model, child: '可选')),
    );
    await tester.tap(_body(), kind: .mouse);
    await tester.pumpAndSettle();
    expect(model.value, true);
    model.value = false;
    await tester.pumpAndSettle();
    expect(_bg(tester), _info.mix(_white, 90));
  });

  testWidgets('toggle 不读取或修改 FormItem 的值', (tester) async {
    final form = Obs<Map<String, dynamic>>({'hot': true});
    addTearDown(form.dispose);
    await tester.pumpWidget(
      _host(
        ElForm(
          modelValue: form,
          child: ElFormItem(
            prop: 'hot',
            child: ElTag.toggle(child: '可选'),
          ),
        ),
      ),
    );
    expect(_bg(tester), _info.mix(_white, 90));
    await tester.tap(_body(), kind: .mouse);
    await tester.pumpAndSettle();
    expect(form.value['hot'], true);
    await tester.tap(_body(), kind: .mouse);
    await tester.pumpAndSettle();
    expect(form.value['hot'], true);
  });

  testWidgets('禁用阻止切换，preventDefault 可接管点击', (tester) async {
    var changed = 0;
    await tester.pumpWidget(
      _host(
        ElTag.toggle(disabled: true, onChanged: (_) => changed++, child: '可选'),
      ),
    );
    await tester.tap(_body(), warnIfMissed: false);
    await tester.pump();
    expect(changed, 0);
    await tester.pumpWidget(
      _host(
        ElTag.toggle(
          onChanged: (_) => changed++,
          event: ElEvent(onTap: (e) => e.preventDefault()),
          child: '可选',
        ),
      ),
    );
    await tester.tap(_body());
    await tester.pump();
    expect(changed, 0);
  });

  testWidgets('替换外观 Builder 后保留指针和键盘切换', (tester) async {
    final model = ValueNotifier(false);
    addTearDown(model.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _host(
        ElComponentProvider(
          builders: ElComponents(
            tag: (_, tag) => ElView(child: tag.selected ? '开' : '关'),
          ),
          child: ElTag.toggle(modelValue: model, focusNode: focus),
        ),
      ),
    );
    await tester.tap(find.byType(ElTag));
    await tester.pump();
    expect(model.value, true);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    expect(model.value, true);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(model.value, false);
  });

  testWidgets('选中态有按压反馈和键盘焦点环，悬停不改色', (tester) async {
    await tester.pumpWidget(_host(ElTag.toggle(value: true, child: '可选')));
    final base = _bg(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_body()));
    await tester.pumpAndSettle();
    expect(_bg(tester), base);
    await mouse.down(tester.getCenter(_body()));
    await tester.pumpAndSettle();
    expect(_bg(tester), isNot(base));
    await mouse.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    // 从无主焦点进入键盘遍历，独立验证新的键盘聚焦会话。
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_render(tester).committedResolvedStyle.box.outline, isNotNull);
  });

  testWidgets('暗色主题保持可读的浅底与主题色', (tester) async {
    await tester.pumpWidget(_host(ElTag(child: '标签'), brightness: .dark));
    expect(_bg(tester), isNot(_primary.mix(_white, 90)));
    expect(
      _render(tester).committedResolvedStyle.inheritedText.color,
      _primary,
    );
    expect(_border(tester), isNot(_bg(tester)));
  });

  testWidgets('实心切换标签在明暗主题中按压均加深', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _host(
          ElTag.toggle(value: true, effect: .dark, child: '可选'),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: .mouse);
      await mouse.down(tester.getCenter(_body()));
      await tester.pumpAndSettle();
      expect(_bg(tester), _primary.mix(Color(0xff000000), 20));
      await mouse.cancel();
      await tester.pumpAndSettle();
    }
  });

  test('全局登记表支持复制、清空、合并与相等比较', () {
    Widget builder(BuildContext context, ElTag tag) => ElView(child: tag.child);
    final data = ElComponents(tag: builder);
    expect(data.copyWith(), data);
    expect(data.copyWith().hashCode, data.hashCode);
    expect(data.copyWith(tag: null).tag, isNull);
    expect(ElComponents().merge(data), data);
    expect(data.merge(ElComponents()), data);
    expect(const ElementPlusThemeData().tag, ElementPlusThemeData.tagBuilder);
  });
}
