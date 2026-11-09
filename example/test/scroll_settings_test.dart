import 'package:example/main.dart' as application;
import 'package:example/src/pages/settings.dart';
import 'package:example/src/router/index.dart' as app_router;
import 'package:example/src/state/index.dart';
import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _text(String text) => find.byWidgetPredicate(
  (widget) => (widget is Text && widget.data == text) || (widget is ElView && widget.child == text),
);

Finder _modeRow() => find.byKey(ValueKey('settings-doc-scroll-mode'));

Finder _semanticsRow() => find.byKey(ValueKey('settings-exclude-semantics'));

Finder _pressureRow() => find.byKey(ValueKey('settings-doc-repeat-count'));

Finder _resamplingRow() => find.byKey(ValueKey('settings-resampling-enabled'));

void _phoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _openSettings(WidgetTester tester) async {
  _phoneSize(tester);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(home: SettingPage()),
    ),
  );
  await tester.pumpAndSettle();
}

bool _hasSemanticsLabel(WidgetTester tester, RegExp pattern) {
  final root = tester.binding.renderViews.single.owner?.semanticsOwner?.rootSemanticsNode;
  if (root == null) return false;
  var found = false;
  void visit(SemanticsNode node) {
    if (pattern.hasMatch(node.getSemanticsData().label)) found = true;
    node.visitChildren((child) {
      if (!found) visit(child);
      return !found;
    });
  }

  visit(root);
  return found;
}

void main() {
  late DocScrollMode previousMode;
  late bool previousExcludeSemantics;
  late int previousRepeatCount;
  late bool previousResampling;
  late bool previousBindingResampling;
  setUp(() {
    previousMode = GlobalState.docScrollMode.value;
    previousExcludeSemantics = GlobalState.excludeSemantics.value;
    previousRepeatCount = GlobalState.docRepeatCount.value;
    previousBindingResampling = GestureBinding.instance.resamplingEnabled;
    previousResampling = GlobalState.resamplingEnabled.value;
    GlobalState.docScrollMode.value = DocScrollMode.elScrollView;
    GlobalState.excludeSemantics.value = false;
    GlobalState.docRepeatCount.value = 1;
    GlobalState.resamplingEnabled.value = false;
    GestureBinding.instance.resamplingEnabled = false;
  });
  tearDown(() {
    GlobalState.docScrollMode.value = previousMode;
    GlobalState.excludeSemantics.value = previousExcludeSemantics;
    GlobalState.docRepeatCount.value = previousRepeatCount;
    GlobalState.resamplingEnabled.value = previousResampling;
    GestureBinding.instance.resamplingEnabled = previousBindingResampling;
  });

  testWidgets('系统设置的文档滚动菜单提供四种模式并回写和展示当前值', (tester) async {
    await _openSettings(tester);
    expect(_modeRow(), findsOneWidget);
    expect(tester.widget<ElListTile<DocScrollMode>>(_modeRow()).title, '文档滚动');
    expect(find.descendant(of: _modeRow(), matching: _text('ElScrollView')), findsOneWidget);

    final options = <DocScrollMode, String>{
      DocScrollMode.official: '官方普通滚动',
      DocScrollMode.officialVirtual: '官方虚拟列表',
      DocScrollMode.sliverList: 'ElSliverList',
      DocScrollMode.elScrollView: 'ElScrollView',
    };
    for (final entry in options.entries) {
      await tester.tap(_modeRow());
      await tester.pumpAndSettle();
      for (final label in options.values) {
        expect(_text(label), findsWidgets);
      }
      await tester.tapAt(tester.getCenter(_text(entry.value).last));
      await tester.pumpAndSettle();

      expect(GlobalState.docScrollMode.value, entry.key);
      expect(tester.widget<ElListTile<DocScrollMode>>(_modeRow()).currentValue, entry.key);
      expect(find.descendant(of: _modeRow(), matching: _text(entry.value)), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('系统设置的语义开关通过整行点击回写全局值', (tester) async {
    await _openSettings(tester);
    expect(_semanticsRow(), findsOneWidget);
    expect(tester.widget<ElListTile<bool>>(_semanticsRow()).currentValue, isFalse);

    await tester.tap(_semanticsRow());
    await tester.pumpAndSettle();
    expect(GlobalState.excludeSemantics.value, isTrue);
    expect(tester.widget<ElListTile<bool>>(_semanticsRow()).currentValue, isTrue);

    await tester.tap(_semanticsRow());
    await tester.pumpAndSettle();
    expect(GlobalState.excludeSemantics.value, isFalse);
    expect(tester.widget<ElListTile<bool>>(_semanticsRow()).currentValue, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('性能压力菜单可选择全部倍率并显示当前值', (tester) async {
    await _openSettings(tester);
    expect(tester.widget<ElListTile<int>>(_pressureRow()).title, '性能压力');
    expect(find.descendant(of: _pressureRow(), matching: _text('1 倍')), findsOneWidget);
    for (final count in [2, 5, 10, 20, 1]) {
      await tester.tap(_pressureRow());
      await tester.pumpAndSettle();
      for (final option in [1, 2, 5, 10, 20]) {
        expect(_text('$option 倍'), findsWidgets);
      }
      await tester.tapAt(tester.getCenter(_text('$count 倍').last));
      await tester.pumpAndSettle();
      expect(GlobalState.docRepeatCount.value, count);
      expect(tester.widget<ElListTile<int>>(_pressureRow()).currentValue, count);
      expect(find.descendant(of: _pressureRow(), matching: _text('$count 倍')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('触摸重采样模型同步实际 GestureBinding 开关和设置行', (tester) async {
    await _openSettings(tester);
    expect(tester.widget<ElListTile<bool>>(_resamplingRow()).title, '触摸重采样');
    expect(tester.widget<ElListTile<bool>>(_resamplingRow()).currentValue, isFalse);
    expect(GestureBinding.instance.resamplingEnabled, isFalse);

    GlobalState.resamplingEnabled.value = true;
    await tester.pumpAndSettle();
    expect(GestureBinding.instance.resamplingEnabled, isTrue);
    expect(tester.widget<ElListTile<bool>>(_resamplingRow()).currentValue, isTrue);

    // 通过模型关闭后再继续其他交互，避免测试时钟进入触摸采样等待。
    GlobalState.resamplingEnabled.value = false;
    await tester.pumpAndSettle();
    expect(GestureBinding.instance.resamplingEnabled, isFalse);
    expect(tester.widget<ElListTile<bool>>(_resamplingRow()).currentValue, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('App 全局屏蔽语义会移除标签但保留触摸，关闭后恢复标签', (tester) async {
    _phoneSize(tester);
    final previousLocation = app_router.router.routeInformationProvider.value.uri;
    final previousMobile = app_router.routingConfig.isMobile;
    final semantics = tester.ensureSemantics();
    try {
      app_router.router.go('/settings');
      await tester.pumpWidget(application.App());
      await tester.pumpAndSettle();
      final label = RegExp('文档滚动');
      expect(_hasSemanticsLabel(tester, label), isTrue);
      expect(_semanticsRow().hitTestable(), findsOneWidget);

      GlobalState.excludeSemantics.value = true;
      await tester.pumpAndSettle();
      expect(_hasSemanticsLabel(tester, label), isFalse);
      expect(_semanticsRow().hitTestable(), findsOneWidget);

      await tester.tap(_semanticsRow());
      await tester.pumpAndSettle();
      expect(GlobalState.excludeSemantics.value, isFalse);
      expect(_hasSemanticsLabel(tester, label), isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(SizedBox());
      app_router.router.go(previousLocation.toString());
      app_router.routingConfig.isMobile = previousMobile;
      semantics.dispose();
    }
  });
}
