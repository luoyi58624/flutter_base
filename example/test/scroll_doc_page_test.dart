import 'dart:async';

import 'package:example/src/pages/components/basic/button/index.dart';
import 'package:example/src/pages/components/data/steps/index.dart';
import 'package:example/src/pages/components/doc_page.dart';
import 'package:example/src/pages/components/list/list_tile/index.dart';
import 'package:example/src/pages/components/start/shadow/index.dart';
import 'package:example/src/state/index.dart';
import 'package:example/src/widgets/code_preview/index.dart';
import 'package:example/src/widgets/doc_scroll_view.dart';
import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:example/src/widgets/panel.dart';

Future<GoRouter> _openButtonRoute(WidgetTester tester, String location, {double width = 390}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/components/button', builder: (context, state) => ButtonPage()),
      GoRoute(path: '/components/steps', builder: (context, state) => StepsPage()),
      GoRoute(path: '/components/list-tile', builder: (context, state) => ListTilePage()),
      GoRoute(path: '/components/shadow-design', builder: (context, state) => ShadowPage()),
      GoRoute(
        path: '/empty',
        builder: (context, state) => Scaffold(body: Text('空页面')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _predictiveBack(WidgetTester tester, String method, [double progress = 0]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    StandardMethodCodec().encodeMethodCall(
      MethodCall(method, {
        'touchOffset': [388.0 - progress * 140, 400.0 + progress * 9],
        'progress': progress,
        'swipeEdge': 1,
      }),
    ),
    (_) {},
  );
  await tester.pump(Duration(milliseconds: 16));
}

Future<void> _showDocItem(WidgetTester tester, int index) async {
  final list = tester.widget<ElSliverList>(find.byType(ElSliverList));
  await Scrollable.ensureVisible(tester.element(find.byWidget(list.children[index])));
}

void _expectRealExample(WidgetTester tester, ElSliverList list, int position, {String phase = ''}) {
  final item = find.byWidget(list.children[position]);
  expect(item, findsOneWidget);
  expect(find.descendant(of: item, matching: find.byType(ElCodeExample)), findsOneWidget);
  final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
  expect(
    find.descendant(of: item, matching: find.byWidget(page.sections[(position - 1) % page.sections.length].example)),
    findsOneWidget,
  );
  final viewport = tester.getRect(find.byType(DocScrollView));
  expect(tester.getRect(item).overlaps(viewport), isTrue, reason: phase);
}

void _expectDocMode(WidgetTester tester, DocScrollMode mode, {int? sections}) {
  final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
  if (sections != null) expect(page.sections, hasLength(sections));
  final repeat = GlobalState.docRepeatCount.value;
  final itemCount = page.sections.length * repeat + 1;
  expect(find.text(page.title), findsOneWidget);
  switch (mode) {
    case DocScrollMode.official:
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(ElScrollView), findsNothing);
      expect(find.byType(ElSliverList), findsNothing);
      expect(find.byType(ElCodeExample), findsNWidgets(page.sections.length * repeat));
    case DocScrollMode.officialVirtual:
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ElScrollView), findsNothing);
      expect(find.byType(ElSliverList), findsNothing);
      final list = tester.widget<ListView>(find.byType(ListView));
      final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.estimatedChildCount, itemCount);
      expect(delegate.addAutomaticKeepAlives, isFalse);
      expect(find.byType(ElCodeExample), findsWidgets);
    case DocScrollMode.elScrollView:
      expect(find.byType(ElScrollView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(ElSliverList), findsNothing);
      final list = tester.widget<ElListView>(find.byType(ElListView).first);
      expect(list.itemCount, itemCount);
      expect(list.keepAlive, isFalse);
      expect(find.byType(ElCodeExample), findsWidgets);
    case DocScrollMode.sliverList:
      expect(find.byType(ElSliverList), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(ElScrollView), findsNothing);
      final list = tester.widget<ElSliverList>(find.byType(ElSliverList));
      expect(list.children.length, itemCount);
      expect(find.byType(ElCodeExample), findsNWidgets(page.sections.length * repeat));
  }

  final itemBoundaries = <Element>{};
  final repaintBoundary = find.byWidgetPredicate((widget) => widget is RepaintBoundary);
  final headingBoundary = find.ancestor(of: find.text(page.title), matching: repaintBoundary).evaluate().first;
  itemBoundaries.add(headingBoundary);
  for (final example in find.byType(ElCodeExample).evaluate()) {
    final item = find.byElementPredicate((element) => identical(element, example));
    final boundaries = find.ancestor(of: item, matching: repaintBoundary).evaluate().toList();
    expect(boundaries, isNotEmpty);
    expect(itemBoundaries.add(boundaries.first), isTrue, reason: '标题和每个已挂载文档条目应有独立的重绘边界');
  }
  expect(find.byKey(ValueKey('button-scroll-recycler-switch')), findsNothing);
  expect(tester.takeException(), isNull);
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

  for (final mode in DocScrollMode.values) {
    testWidgets('全局 ${mode.name} 使用对应真实管线展示相同的 Button 文档', (tester) async {
      GlobalState.docScrollMode.value = mode;
      await _openButtonRoute(tester, '/components/button');
      expect(find.byType(ButtonPage), findsOneWidget);
      _expectDocMode(tester, mode, sections: 11);
      final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
      expect(page.sections.first.title, '基础使用');
      expect(page.sections.last.title, '通用点击');
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('ElSliverList 能定位真实按钮模板并回滑', (tester) async {
    GlobalState.docScrollMode.value = DocScrollMode.sliverList;
    await _openButtonRoute(tester, '/components/button');
    final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
    final recyclerView = tester.widget<ElSliverList>(find.byType(ElSliverList));
    expect(recyclerView.children.length, page.sections.length + 1);

    for (final (attempt, position) in [page.sections.length, 1, 5, page.sections.length, 1].indexed) {
      await _showDocItem(tester, position);
      await tester.pumpAndSettle();
      _expectRealExample(tester, recyclerView, position, phase: '第 ${attempt + 1} 次定位');
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('ElSliverList 文档反复离开和重新进入没有遗留异常', (tester) async {
    GlobalState.docScrollMode.value = DocScrollMode.sliverList;
    final router = await _openButtonRoute(tester, '/components/button');
    for (var attempt = 0; attempt < 2; attempt++) {
      final previous = tester.widget<ElSliverList>(find.byType(ElSliverList));
      router.go('/empty');
      await tester.pumpAndSettle();
      expect(find.byType(ElSliverList), findsNothing);
      expect(tester.takeException(), isNull);

      router.go('/components/button');
      await tester.pumpAndSettle();
      final current = tester.widget<ElSliverList>(find.byType(ElSliverList));
      expect(identical(current, previous), isFalse);
      await _showDocItem(tester, 1);
      await tester.pumpAndSettle();
      _expectRealExample(tester, current, 1);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('Steps 文档预测性返回期间保留 ElSliverList 的阅读位置', (tester) async {
    GlobalState.docScrollMode.value = DocScrollMode.sliverList;
    GlobalState.docRepeatCount.value = 20;
    final router = await _openButtonRoute(tester, '/empty');
    unawaited(router.push<void>('/components/steps'));
    await tester.pumpAndSettle();
    final list = tester.widget<ElSliverList>(find.byType(ElSliverList));
    final viewport = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final controller = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
    controller.jumpTo(4000);
    await tester.pumpAndSettle();
    final pixels = controller.position.pixels;
    final anchorElement = tester.element(find.byWidget(list.children[5]));
    final anchor = find.byElementPredicate((element) => identical(element, anchorElement));

    await _predictiveBack(tester, 'startBackGesture');
    final route = ModalRoute.of(tester.element(find.byType(StepsPage)))!;
    expect(route.popGestureInProgress, isTrue);
    for (final progress in [.12, .45, .38, .66, .20]) {
      await _predictiveBack(tester, 'updateBackGestureProgress', progress);
      expect(controller.position.pixels, closeTo(pixels, .01), reason: '返回进度 $progress');
      expect(anchor, findsOneWidget);
      expect(tester.state<ScrollableState>(find.byType(Scrollable).first), same(viewport));
      expect(tester.takeException(), isNull);
    }
    await _predictiveBack(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(controller.position.pixels, closeTo(pixels, .01));
    expect(anchor, findsOneWidget);

    await _predictiveBack(tester, 'startBackGesture');
    await _predictiveBack(tester, 'updateBackGestureProgress', .6);
    await _predictiveBack(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('空页面'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('文档构建闭包更新已挂载条目并保留滚动位置宿主', (tester) async {
    GlobalState.docScrollMode.value = DocScrollMode.sliverList;
    final label = ValueNotifier('旧内容');
    addTearDown(label.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: label,
            builder: (context, value, child) => DocScrollView(
              itemCount: 3,
              itemBuilder: (context, index) => SizedBox(height: 60, child: Text('$value $index')),
            ),
          ),
        ),
      ),
    );
    final viewport = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(find.text('旧内容 0'), findsOneWidget);
    label.value = '新内容';
    await tester.pumpAndSettle();
    expect(find.text('新内容 0'), findsOneWidget);
    expect(find.text('旧内容 0'), findsNothing);
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first), same(viewport));
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('修改全局模式会立即切换当前文档且不改变地址', (tester) async {
    final router = await _openButtonRoute(tester, '/components/button');
    final originalUri = router.routeInformationProvider.value.uri;
    for (final mode in [
      DocScrollMode.officialVirtual,
      DocScrollMode.official,
      DocScrollMode.sliverList,
      DocScrollMode.elScrollView,
    ]) {
      GlobalState.docScrollMode.value = mode;
      await tester.pumpAndSettle();
      _expectDocMode(tester, mode, sections: 11);
      expect(router.routeInformationProvider.value.uri, originalUri);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('全局滚动模式在 Button 和 ListTile 真实文档之间沿用', (tester) async {
    GlobalState.docScrollMode.value = DocScrollMode.sliverList;
    final router = await _openButtonRoute(tester, '/components/button');
    _expectDocMode(tester, DocScrollMode.sliverList, sections: 11);

    router.go('/components/list-tile');
    await tester.pumpAndSettle();
    expect(find.byType(ListTilePage), findsOneWidget);
    _expectDocMode(tester, DocScrollMode.sliverList, sections: 8);

    GlobalState.docScrollMode.value = DocScrollMode.officialVirtual;
    await tester.pumpAndSettle();
    _expectDocMode(tester, DocScrollMode.officialVirtual, sections: 8);
    router.go('/components/button');
    await tester.pumpAndSettle();
    _expectDocMode(tester, DocScrollMode.officialVirtual, sections: 11);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('旧 recycler 和 repeat 查询参数不覆盖全局模式或复制文档', (tester) async {
    GlobalState.docScrollMode.value = DocScrollMode.officialVirtual;
    final router = await _openButtonRoute(tester, '/components/button?recycler=true&repeat=100#compare');
    _expectDocMode(tester, DocScrollMode.officialVirtual, sections: 11);
    expect(GlobalState.docScrollMode.value, DocScrollMode.officialVirtual);

    GlobalState.docScrollMode.value = DocScrollMode.sliverList;
    router.go('/components/button?recycler=false&repeat=3');
    await tester.pumpAndSettle();
    _expectDocMode(tester, DocScrollMode.sliverList, sections: 11);
    expect(GlobalState.docScrollMode.value, DocScrollMode.sliverList);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('宽屏目录在四种滚动模式都能定位最后一个真实小节', (tester) async {
    await _openButtonRoute(tester, '/components/list-tile', width: 1200);
    final page = tester.widget<ComponentDocPage>(find.byType(ComponentDocPage));
    final lastTitle = page.sections.last.title;
    expect(page.sections, hasLength(8));
    for (final mode in DocScrollMode.values) {
      GlobalState.docScrollMode.value = mode;
      await tester.pumpAndSettle();
      final directoryEntry = find.widgetWithText(TextButton, lastTitle);
      expect(directoryEntry.hitTestable(), findsOneWidget);
      await tester.tap(directoryEntry);
      await tester.pumpAndSettle();

      final body = find.byType(DocScrollView);
      final heading = find.descendant(of: body, matching: find.text(lastTitle)).hitTestable();
      expect(heading, findsOneWidget, reason: '${mode.label} 的目录应使最后小节标题进入视口');
      final viewport = tester.getRect(body);
      final center = tester.getCenter(heading);
      expect(center.dx, inInclusiveRange(viewport.left, viewport.right));
      expect(center.dy, inInclusiveRange(viewport.top, viewport.bottom));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('阴影页沿用四种滚动模式且保留五级卡片和风格选择', (tester) async {
    await _openButtonRoute(tester, '/components/shadow-design', width: 1200);
    final choices = [
      (ElShadowType.uniform, '四周均匀'),
      (ElShadowType.floating, '轻盈悬浮'),
      (ElShadowType.glow, '彩色光晕'),
      (ElShadowType.inset, '内凹阴影'),
    ];
    for (final (index, mode) in DocScrollMode.values.indexed) {
      GlobalState.docScrollMode.value = mode;
      await tester.pumpAndSettle();
      final body = find.byType(DocScrollView);
      expect(body, findsOneWidget);
      for (final level in ElLevelType.values) {
        expect(find.byKey(ValueKey('shadow-${level.name}')).hitTestable(), findsOneWidget);
      }

      final dropdown = find.byKey(ValueKey('shadow-type'));
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      final (type, label) = choices[index];
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<ElShadowType>>(dropdown).value, type);
      for (final level in ElLevelType.values) {
        final card = tester.widget<ExamplePanel>(find.byKey(ValueKey('shadow-${level.name}')));
        expect(card.style!.boxShadow, isNotEmpty);
        if (type == ElShadowType.uniform) {
          expect(card.style!.boxShadow!.every((shadow) => shadow.offset == Offset.zero), isTrue);
        }
        if (type == ElShadowType.inset) {
          expect(card.style!.boxShadow!.every((shadow) => (shadow as ElBoxShadow).inset), isTrue);
        }
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('两倍压力在四种模式重复相同正文且页首标题只保留一次', (tester) async {
    GlobalState.docRepeatCount.value = 2;
    await _openButtonRoute(tester, '/components/button');
    for (final mode in DocScrollMode.values) {
      GlobalState.docScrollMode.value = mode;
      await tester.pumpAndSettle();
      _expectDocMode(tester, mode, sections: 11);
      if (mode == DocScrollMode.sliverList) {
        final list = tester.widget<ElSliverList>(find.byType(ElSliverList));
        expect(list.children.length, 23);
        await _showDocItem(tester, 12);
        await tester.pumpAndSettle();
        _expectRealExample(tester, list, 12);
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('二十倍虚拟压力保留完整计数并只挂载视口附近正文', (tester) async {
    GlobalState.docRepeatCount.value = 20;
    GlobalState.docScrollMode.value = DocScrollMode.officialVirtual;
    await _openButtonRoute(tester, '/components/button');
    for (final mode in [DocScrollMode.officialVirtual, DocScrollMode.elScrollView]) {
      GlobalState.docScrollMode.value = mode;
      await tester.pumpAndSettle();
      _expectDocMode(tester, mode, sections: 11);
      expect(find.byType(ElCodeExample, skipOffstage: false).evaluate().length, lessThan(22));
    }
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('当前压力变化立即更新数量并在其他文档沿用', (tester) async {
    GlobalState.docScrollMode.value = DocScrollMode.officialVirtual;
    final router = await _openButtonRoute(tester, '/components/button');
    GlobalState.docRepeatCount.value = 2;
    await tester.pumpAndSettle();
    _expectDocMode(tester, DocScrollMode.officialVirtual, sections: 11);
    GlobalState.docRepeatCount.value = 5;
    await tester.pumpAndSettle();
    _expectDocMode(tester, DocScrollMode.officialVirtual, sections: 11);

    router.go('/components/list-tile');
    await tester.pumpAndSettle();
    _expectDocMode(tester, DocScrollMode.officialVirtual, sections: 8);
    expect(GlobalState.docRepeatCount.value, 5);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('阴影页在四种模式按两倍压力重复完整五级卡片', (tester) async {
    GlobalState.docRepeatCount.value = 2;
    await _openButtonRoute(tester, '/components/shadow-design', width: 1200);
    for (final mode in DocScrollMode.values) {
      GlobalState.docScrollMode.value = mode;
      await tester.pumpAndSettle();
      for (final level in ElLevelType.values) {
        expect(find.byKey(ValueKey('shadow-${level.name}')), findsNWidgets(2));
      }
      expect(find.byKey(ValueKey('shadow-type')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(SizedBox());
  });
}
