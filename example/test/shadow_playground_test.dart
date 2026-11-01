import 'package:example/src/pages/components/start/shadow/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _host(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ElMobileTheme(
      brightness: Brightness.light,
      child: Builder(
        builder: (context) => MaterialApp(theme: context.elMaterialThemeData, home: ShadowPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ElStyle _preview(WidgetTester tester) =>
    tester.widget<ElCardView>(find.byKey(ValueKey('shadow-preview'), skipOffstage: false)).style!;

Finder _tag(String label) => find.byWidgetPredicate((widget) => widget is ElTag && widget.child == label);

bool _selected(WidgetTester tester, String label) => tester
    .widget<ElView>(
      find.descendant(
        of: _tag(label),
        matching: find.byWidgetPredicate((widget) => widget is ElView && widget.semantics?.properties.toggled != null),
      ),
    )
    .semantics!
    .properties
    .toggled!;

Future<void> _slide(WidgetTester tester, String key, double value) async {
  tester.widget<ElSlider<double>>(find.byKey(ValueKey(key))).currentValue = value;
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [Size(320, 700), Size(1280, 900), Size(800, 400)]) {
    testWidgets('游乐场布局 $size，同色预览与局部主题不改变应用默认值', (tester) async {
      final original = ElMobileTheme.lightVars[ElTokens.$shadowMd];
      await _host(tester, size);
      final originalShadows = _preview(tester).boxShadow;
      expect(
        find.byWidgetPredicate((widget) => widget is ElCardView && widget.style?.boxShadow != null),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is ElButton && ['浅色', '暗色', 'xs', 'sm', 'md', 'lg', 'xl'].contains(widget.child),
        ),
        findsNothing,
      );
      expect(_preview(tester).backgroundColor, Colors.white);
      expect(tester.widget<ColoredBox>(find.byKey(ValueKey('shadow-preview-stage'))).color, Colors.white);
      tester.widget<ElTag>(_tag('暗色')).onChanged!(true);
      await tester.pumpAndSettle();
      final stage = tester.widget<ColoredBox>(find.byKey(ValueKey('shadow-preview-stage')));
      expect(stage.color, _preview(tester).backgroundColor);
      expect(_preview(tester).boxShadow, isNot(originalShadows));
      expect(Theme.of(tester.element(find.byType(ShadowPage))).brightness, Brightness.light);
      expect(ElMobileTheme.lightVars[ElTokens.$shadowMd], same(original));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('几何和风格输入进入算法，复制用法可复现，重置恢复默认', (tester) async {
    String? copied;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await _host(tester, Size(400, 900));
    final before = _preview(tester).boxShadow;
    await _slide(tester, 'shadow-width', 240);
    await _slide(tester, 'shadow-radius', 50);
    await _slide(tester, 'shadow-strength', 1.5);
    await _slide(tester, 'shadow-softness', 1.2);
    expect(_preview(tester).boxShadow, isNot(before));
    expect(
      _preview(tester).boxShadow,
      ElShadow.resolve(
        level: ElLevelType.md,
        brightness: Brightness.light,
        surfaceColor: Colors.white,
        backgroundColor: Colors.white,
        size: Size(240, 120),
        borderRadius: BorderRadius.circular(50),
        strength: 1.5,
        softness: 1.2,
      ),
    );
    final copiedShadows = _preview(tester).boxShadow;
    await tester.tap(find.byKey(ValueKey('shadow-copy')));
    await tester.pumpAndSettle();
    expect(copied, contains('Size(240, 120)'));
    expect(copied, contains('BorderRadius.circular(50)'));
    expect(copied, contains('strength: 1.5'));
    expect(_preview(tester).boxShadow, same(copiedShadows));
    await tester.tap(find.byKey(ValueKey('shadow-copy')));
    await tester.pumpAndSettle();
    expect(_preview(tester).boxShadow, same(copiedShadows));
    await tester.tap(find.byKey(ValueKey('shadow-reset')));
    await tester.pumpAndSettle();
    expect(_preview(tester).boxShadow, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('主题与级别使用单选 Tag，重复选择不能取消，结果折叠时不构建代码', (tester) async {
    await _host(tester, Size(1280, 900));
    final original = _preview(tester).boxShadow;
    final code = find.byWidgetPredicate(
      (widget) =>
          widget is ElView &&
          widget.child is String &&
          (widget.child as String).startsWith('final shadows = ElShadow.resolve('),
    );
    expect(code, findsNothing);
    expect(_selected(tester, '浅色'), isTrue);
    await tester.tap(_tag('浅色'));
    await tester.pump(Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(_selected(tester, '浅色'), isTrue);
    expect(_preview(tester).boxShadow, same(original));
    await tester.tap(_tag('暗色'));
    await tester.pump(Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(_selected(tester, '暗色'), isTrue);
    expect(_selected(tester, '浅色'), isFalse);
    await tester.tap(_tag('xl'));
    await tester.pump(Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'xl'), isTrue);
    expect(_selected(tester, 'md'), isFalse);
    final shadows = _preview(tester).boxShadow;
    final fold = find
        .ancestor(
          of: find.byWidgetPredicate((widget) => widget is ElText && widget.data == '计算结果与 Dart 用法'),
          matching: find.byType(ElButton),
        )
        .first;
    await tester.tap(fold);
    await tester.pump(Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(code, findsOneWidget);
    expect(_preview(tester).boxShadow, same(shadows));
    expect(tester.takeException(), isNull);
  });

  testWidgets('颜色输入拒绝无效值，解除同色后可以独立设置背景', (tester) async {
    await _host(tester, Size(400, 900));
    tester.widget<ElEditableView>(find.byKey(ValueKey('shadow-surface'))).controller!.text = 'bad-input';
    await tester.pumpAndSettle();
    expect(_preview(tester).backgroundColor, Colors.white);
    expect(find.byWidgetPredicate((w) => w is ElText && w.data == '请输入有效的颜色'), findsOneWidget);
    tester.widget<ElEditableView>(find.byKey(ValueKey('shadow-surface'))).controller!.text = '#2454C6';
    await tester.pumpAndSettle();
    expect(_preview(tester).backgroundColor, Color(0xff2454c6));
    tester.widget<ElSwitch>(find.byKey(ValueKey('shadow-same-color'))).onChanged!(false);
    await tester.pumpAndSettle();
    tester.widget<ElEditableView>(find.byKey(ValueKey('shadow-background'))).controller!.text = '#FFFFFF';
    await tester.pumpAndSettle();
    expect(tester.widget<ColoredBox>(find.byKey(ValueKey('shadow-preview-stage'))).color, Colors.white);
    expect(_preview(tester).backgroundColor, Color(0xff2454c6));
    tester.widget<ElEditableView>(find.byKey(ValueKey('shadow-background'))).controller!.text = '#80FFFFFF';
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is ElText && w.data == '请输入有效且不透明的颜色'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机弹出键盘后保留颜色输入焦点，收起键盘后恢复预览', (tester) async {
    await _host(tester, Size(400, 900));
    final field = find.byKey(ValueKey('shadow-surface'));
    tester.widget<ElEditableView>(field).focusNode!.requestFocus();
    await tester.pumpAndSettle();
    final beforeKeyboard = _preview(tester).boxShadow;
    tester.view.viewInsets = FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(_preview(tester).boxShadow, same(beforeKeyboard));
    tester.testTextInput.enterText('#AABBCC');
    await tester.pumpAndSettle();
    expect(_preview(tester).backgroundColor, Color(0xffaabbcc));
    final editedShadows = _preview(tester).boxShadow;
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('shadow-preview')).hitTestable(), findsOneWidget);
    expect(_preview(tester).boxShadow, same(editedShadows));
    expect(tester.takeException(), isNull);
  });
}
