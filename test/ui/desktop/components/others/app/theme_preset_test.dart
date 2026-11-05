import 'package:flutter_base/desktop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [ElementPlusThemeData] 的构造默认值契约：
/// 每个注入点是本类的 `static` 成员 —— 不传某项就吃 Element 预设，显式传 `null` 清空该注入点。
void main() {
  test('不传 = 吃 Element 预设的 static 成员', () {
    const preset = ElementPlusThemeData();
    expect(preset, isA<ElComponents>());
    expect(preset.button, ElementPlusThemeData.buttonBuilder);
    expect(preset.tag, ElementPlusThemeData.tagBuilder);
    expect(preset.buttonGroup, ElementPlusThemeData.buttonGroupBuilder);
    expect(preset.switcher, ElementPlusThemeData.switchButtonBuilder);
    expect(preset.input, ElementPlusThemeData.inputBuilder);
    expect(preset.checkbox, isNull);
    expect(preset.radio, isNull);
    expect(preset.select, ElementPlusThemeData.selectBuilder);
    expect(preset.autocomplete, ElementPlusThemeData.autocompleteBuilder);
    expect(preset.inputNumber, ElementPlusThemeData.inputNumberBuilder);
    expect(preset.mention, ElementPlusThemeData.mentionBuilder);
    expect(preset.inputTag, ElementPlusThemeData.inputTagBuilder);
    expect(preset.inputOtp, ElementPlusThemeData.inputOtpBuilder);
    expect(preset.formItem, ElementPlusThemeData.formItemBuilder);
    expect(preset.tableStyle, ElementPlusThemeData.tableStyleBuilder);
  });

  test('显式传 null = 清空该注入点；表格通道随之回退 el_ui 默认皮肤', () {
    const cleared = ElementPlusThemeData(
      button: null,
      tag: null,
      buttonGroup: null,
      switcher: null,
      input: null,
      checkbox: null,
      radio: null,
      select: null,
      autocomplete: null,
      inputNumber: null,
      mention: null,
      inputTag: null,
      inputOtp: null,
      formItem: null,
      tableStyle: null,
    );
    expect(cleared.button, isNull);
    expect(cleared.tag, isNull);
    expect(cleared.buttonGroup, isNull);
    expect(cleared.switcher, isNull);
    expect(cleared.input, isNull);
    expect(cleared.checkbox, isNull);
    expect(cleared.radio, isNull);
    expect(cleared.select, isNull);
    expect(cleared.autocomplete, isNull);
    expect(cleared.inputNumber, isNull);
    expect(cleared.mention, isNull);
    expect(cleared.inputTag, isNull);
    expect(cleared.inputOtp, isNull);
    expect(cleared.formItem, isNull);
    // 没有登记的工厂时，el_ui 的 `_resolveStyle`（table_view.dart:271）回落到
    // `const ElTableStyle()`：border / highlightCurrentRow 与 EP 预设正好相反。
    expect(cleared.tableStyle, isNull);
    expect(const ElTableStyle().border, isFalse);
    expect(const ElTableStyle().highlightCurrentRow, isTrue);
    expect(const ElementPlusThemeData().tableStyle, isNotNull);
  });

  testWidgets('主题变量按读取键更新，同一子树中的其他颜色读者不重建', (tester) async {
    var primary = Color(0xff123456);
    var primaryBuilds = 0;
    var borderBuilds = 0;
    Color? seenPrimary;
    late StateSetter rebuild;
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (context) {
            primaryBuilds++;
            seenPrimary = context.elTheme.primary;
            return SizedBox();
          },
        ),
        Builder(
          builder: (context) {
            borderBuilds++;
            context.elTheme.borderColor;
            return SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ElComponentProvider(
              components: el.desktopComponents,
              child: ElView(
                style: ElStyle(vars: {ElTokens.$primary: primary}),
                child: child,
              ),
            );
          },
        ),
      ),
    );
    expect(seenPrimary, primary);
    expect((primaryBuilds, borderBuilds), (1, 1));

    rebuild(() => primary = Color(0xffabcdef));
    await tester.pump();
    expect(seenPrimary, primary);
    expect((primaryBuilds, borderBuilds), (2, 1));
  });

  testWidgets('普通 ElView 局部变量覆盖主题，未声明的颜色继续继承', (tester) async {
    final parentPrimary = Color(0xff123456);
    final localPrimary = Color(0xffabcdef);
    final border = Color(0xff654321);
    Color? seenPrimary;
    Color? seenBorder;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ElComponentProvider(
          components: el.desktopComponents,
          child: ElView(
            style: ElStyle(vars: {ElTokens.$primary: parentPrimary, ElTokens.$borderColor: border}),
            child: ElView(
              style: ElStyle(vars: {ElTokens.$primary: localPrimary}),
              child: Builder(
                builder: (context) {
                  seenPrimary = context.elTheme.primary;
                  seenBorder = context.elTheme.borderColor;
                  return SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(seenPrimary, localPrimary);
    expect(seenBorder, border);
  });

  testWidgets('暗色主题变量经 onDark 覆盖，恢复亮色时回到基础声明', (tester) async {
    final lightPrimary = Color(0xff123456);
    final darkPrimary = Color(0xffabcdef);
    Color? seenPrimary;
    final child = Builder(
      builder: (context) {
        seenPrimary = context.elTheme.primary;
        return SizedBox();
      },
    );
    for (final brightness in [Brightness.light, Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ElView(
            themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
            child: ElComponentProvider(
              components: el.desktopComponents,
              child: ElView(
                style: ElStyle(
                  vars: {ElTokens.$primary: lightPrimary},
                  onDark: ElStyle(vars: {ElTokens.$primary: darkPrimary}),
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
      expect(seenPrimary, brightness == Brightness.dark ? darkPrimary : lightPrimary);
    }
  });

  testWidgets('紧凑模式只缩小控件，正文与图标尺寸由应用设置', (tester) async {
    final bodyKey = GlobalKey();
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.desktopComponents,
          child: ElView(
            style: ElStyle(fontSize: 18, iconSize: 31, vars: {ElementPlusThemeData.$compact: compact}),
            child: ElView(key: bodyKey, child: '正文'),
          ),
        ),
      );
      final body = tester.renderObject<ElRenderView>(find.byKey(bodyKey));
      expect(body.committedResolvedStyle.inheritedText.fontSize, 18);
      expect(body.committedResolvedStyle.inheritedBox.iconSize, 31);
    }
  });

  testWidgets('主题变体可级联覆盖 compact 并在明暗切换时恢复', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        ElView(
          themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
          child: ElComponentProvider(
            components: el.desktopComponents,
            child: ElView(
              style: ElStyle(onDark: ElStyle(vars: {ElementPlusThemeData.$compact: true})),
              child: ElButton(child: '按钮'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.renderObject<ElRenderView>(
        find.descendant(of: find.byType(ElButton), matching: find.byType(ElButtonView)).first,
      );
      expect(button.size.height, brightness == Brightness.dark ? 32 : 36);
    }
  });
}
