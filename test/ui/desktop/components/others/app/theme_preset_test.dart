import 'package:flutter_base/desktop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [ElementPlusThemeData] 的构造默认值契约：
/// 每个注入点是本类的 `static` 成员 —— 不传某项就吃 Element 预设，显式传 `null` 清空该注入点。
void main() {
  test('不传 = 吃 Element 预设的 static 成员', () {
    const preset = ElementPlusThemeData();
    expect(preset, isA<ElComponentBuilders>());
    expect(preset.buttonBuilder, ElementPlusThemeData.button);
    expect(preset.tagBuilder, ElementPlusThemeData.tag);
    expect(preset.buttonGroupBuilder, ElementPlusThemeData.buttonGroup);
    expect(preset.switchBuilder, ElementPlusThemeData.switchButton);
    expect(preset.inputBuilder, ElementPlusThemeData.input);
    expect(preset.checkboxBuilder, isNull);
    expect(preset.radioBuilder, isNull);
    expect(preset.selectBuilder, ElementPlusThemeData.select);
    expect(preset.autocompleteBuilder, ElementPlusThemeData.autocomplete);
    expect(preset.inputNumberBuilder, ElementPlusThemeData.inputNumber);
    expect(preset.mentionBuilder, ElementPlusThemeData.mention);
    expect(preset.inputTagBuilder, ElementPlusThemeData.inputTag);
    expect(preset.inputOtpBuilder, ElementPlusThemeData.inputOtp);
    expect(preset.formItemBuilder, ElementPlusThemeData.formItem);
    expect(preset.tableStyleBuilder, ElementPlusThemeData.tableStyle);
  });

  test('显式传 null = 清空该注入点；表格通道随之回退 el_ui 默认皮肤', () {
    const cleared = ElementPlusThemeData(
      buttonBuilder: null,
      tagBuilder: null,
      buttonGroupBuilder: null,
      switchBuilder: null,
      inputBuilder: null,
      checkboxBuilder: null,
      radioBuilder: null,
      selectBuilder: null,
      autocompleteBuilder: null,
      inputNumberBuilder: null,
      mentionBuilder: null,
      inputTagBuilder: null,
      inputOtpBuilder: null,
      formItemBuilder: null,
      tableStyleBuilder: null,
    );
    expect(cleared.buttonBuilder, isNull);
    expect(cleared.tagBuilder, isNull);
    expect(cleared.buttonGroupBuilder, isNull);
    expect(cleared.switchBuilder, isNull);
    expect(cleared.inputBuilder, isNull);
    expect(cleared.checkboxBuilder, isNull);
    expect(cleared.radioBuilder, isNull);
    expect(cleared.selectBuilder, isNull);
    expect(cleared.autocompleteBuilder, isNull);
    expect(cleared.inputNumberBuilder, isNull);
    expect(cleared.mentionBuilder, isNull);
    expect(cleared.inputTagBuilder, isNull);
    expect(cleared.inputOtpBuilder, isNull);
    expect(cleared.formItemBuilder, isNull);
    // 没有登记的工厂时，el_ui 的 `_resolveStyle`（table_view.dart:271）回落到
    // `const ElTableStyle()`：border / highlightCurrentRow 与 EP 预设正好相反。
    expect(cleared.tableStyleBuilder, isNull);
    expect(const ElTableStyle().border, isFalse);
    expect(const ElTableStyle().highlightCurrentRow, isTrue);
    expect(const ElementPlusThemeData().tableStyleBuilder, isNotNull);
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
            return ElDesktopTheme(
              style: ElStyle(vars: {ElTokens.$primary: primary}),
              child: child,
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
        child: ElDesktopTheme(
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
          child: ElDesktopTheme(
            themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
            style: ElStyle(
              vars: {ElTokens.$primary: lightPrimary},
              onDark: ElStyle(vars: {ElTokens.$primary: darkPrimary}),
            ),
            child: child,
          ),
        ),
      );
      expect(seenPrimary, brightness == Brightness.dark ? darkPrimary : lightPrimary);
    }
  });

  testWidgets('紧凑模式只缩小控件，页面正文与图标保持默认尺寸', (tester) async {
    final bodyKey = GlobalKey();
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        ElDesktopTheme(
          compact: compact,
          child: ElView(key: bodyKey, child: '正文'),
        ),
      );
      final body = tester.renderObject<ElRenderView>(find.byKey(bodyKey));
      expect(body.committedResolvedStyle.inheritedText.fontSize, 15);
      expect(body.committedResolvedStyle.inheritedBox.iconSize, 24);
    }
  });

  testWidgets('主题变体可级联覆盖 compact 并在明暗切换时恢复', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark, Brightness.light]) {
      await tester.pumpWidget(
        ElDesktopTheme(
          themeMode: ElThemeMode(brightness: brightness, duration: Duration.zero),
          style: ElStyle(onDark: ElStyle(vars: {ElDesktopTheme.$compact: true})),
          child: ElButton(child: '按钮'),
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
