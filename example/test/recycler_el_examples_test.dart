import 'package:example/src/pages/examples/recycler_view/cards.dart';
import 'package:example/src/pages/examples/recycler_view/selection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ElScrollView 复选列表按需挂载并支持首末、序号定位与已挂载行清空', (tester) async {
    await _open(tester, RecyclerSelectionPage());
    await _choose(tester, 'selection', 'mode-elScrollView');
    _expectElList(tester);
    expect(find.byType(ElCheckbox).evaluate().length, lessThan(30));
    await tester.tap(_checkbox(0));
    await tester.pumpAndSettle();
    await tester.tap(_checkbox(1));
    await tester.pumpAndSettle();
    expect(_checked(tester, 0), isTrue);
    expect(_checked(tester, 1), isTrue);
    expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, '2 / 10000');
    await _choose(tester, 'selection', 'clear');
    expect(_checked(tester, 0), isFalse);
    expect(_checked(tester, 1), isFalse);
    expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, '0 / 10000');

    await _choose(tester, 'selection', 'last');
    expect(find.text('条目 10000').hitTestable(), findsOneWidget);
    await tester.tap(_checkbox(9999));
    await tester.pumpAndSettle();
    expect(_checked(tester, 9999), isTrue);
    await _choose(tester, 'selection', 'locate-menu');
    await tester.enterText(find.byKey(ValueKey('selection-index-input')), '4321');
    await tester.tap(find.byKey(ValueKey('selection-locate')));
    await tester.pumpAndSettle();
    expect(find.text('条目 04321').hitTestable(), findsOneWidget);
    await _choose(tester, 'selection', 'first');
    expect(find.text('条目 00001').hitTestable(), findsOneWidget);
    await _choose(tester, 'selection', 'last');
    expect(_checked(tester, 9999), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ElScrollView 复杂卡片共享激活与统计模型，首末定位和可见刷新正常', (tester) async {
    await _open(tester, RecyclerCardsPage());
    await _choose(tester, 'cards', 'mode-elScrollView');
    _expectElList(tester);
    final first = _card('00001');
    expect(_selected(tester, first), isFalse);
    final visits = _cardText(tester, first, 'cards-visits');
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(_selected(tester, first), isTrue);
    await _choose(tester, 'cards', 'refresh-visible');
    expect(_cardText(tester, first, 'cards-visits'), isNot(visits));
    expect(_cardText(tester, first, 'cards-updated'), contains('已更新 1 次'));
    await _choose(tester, 'cards', 'last');
    expect(find.textContaining('观测 #10000').hitTestable(), findsOneWidget);
    await tester.tap(_card('10000'));
    await tester.pumpAndSettle();
    expect(_selected(tester, _card('10000')), isTrue);
    await _choose(tester, 'cards', 'first');
    expect(_selected(tester, first), isTrue);
    expect(_cardText(tester, first, 'cards-visits'), isNot(visits));
    await _choose(tester, 'cards', 'clear');
    expect(_selected(tester, first), isFalse);
    await _choose(tester, 'cards', 'last');
    expect(_selected(tester, _card('10000')), isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final cards in [false, true]) {
    final page = cards ? 'cards' : 'selection';
    testWidgets('$page 三种容器反复切换保留业务状态并重新从首项比较', (tester) async {
      await _open(tester, cards ? RecyclerCardsPage() : RecyclerSelectionPage());
      await tester.tap(cards ? _card('00001') : _checkbox(0));
      await tester.pumpAndSettle();
      final controllers = <ScrollController>{
        tester.widget<CupertinoScrollbar>(find.byType(CupertinoScrollbar)).controller!,
      };
      for (final mode in ['elScrollView', 'listView', 'elScrollView', 'recyclerView']) {
        await _choose(tester, page, 'mode-$mode');
        final ScrollController controller;
        if (mode == 'elScrollView') {
          _expectElList(tester);
          controller = tester.widget<ElScrollView>(find.byType(ElScrollView)).controller!;
        } else {
          expect(find.byType(ElScrollView), findsNothing);
          controller = tester.widget<CupertinoScrollbar>(find.byType(CupertinoScrollbar)).controller!;
          expect(find.byType(rv.RecyclerView), mode == 'recyclerView' ? findsOneWidget : findsNothing);
        }
        controllers.add(controller);
        expect(controller.positions, hasLength(1));
        for (final inactive in controllers.where((candidate) => candidate != controller)) {
          expect(inactive.hasClients, isFalse, reason: '已切走的引擎必须释放旧滚动位置');
        }
        expect(controller.offset, closeTo(0, .01));
        expect(cards ? _selected(tester, _card('00001')) : _checked(tester, 0), isTrue);
        expect(tester.takeException(), isNull);
      }
      expect(controllers, hasLength(2), reason: 'El 与官方宿主分别持有独立控制器，每个只附着当前位置');
    });

    testWidgets('安卓 $page 的 ElScrollView 原生 iOS 滑块可拖动跳过大量条目', (tester) async {
      await _open(tester, cards ? RecyclerCardsPage() : RecyclerSelectionPage());
      await _choose(tester, page, 'mode-elScrollView');
      final scroll = tester.widget<ElScrollView>(find.byType(ElScrollView));
      final controller = scroll.controller!;
      final before = controller.offset;
      final thumb = find.byKey(ValueKey('el-scrollbar-thumb-vertical'));
      expect(thumb, findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(thumb));
      await tester.pump(Duration(milliseconds: 130));
      await gesture.moveBy(Offset(0, 150));
      await tester.pump(Duration(milliseconds: 16));
      expect(controller.offset - before, greaterThan(10000));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        cards ? find.textContaining('观测 #00001').hitTestable() : find.text('条目 00001').hitTestable(),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ElScrollView 卡片在窄屏暗色和大字下仍可激活与刷新', (tester) async {
    await _open(tester, RecyclerCardsPage(), width: 320, textScale: 2, brightness: .dark);
    await _choose(tester, 'cards', 'mode-elScrollView');
    final first = _card('00001');
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(_selected(tester, first), isTrue);
    await _choose(tester, 'cards', 'refresh-visible');
    expect(_cardText(tester, first, 'cards-updated'), contains('已更新 1 次'));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(
  WidgetTester tester,
  Widget page, {
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        theme: ThemeData(platform: .android, brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String page, String action) async {
  await tester.tap(find.byKey(ValueKey('$page-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('$page-$action')));
  await tester.pumpAndSettle();
}

void _expectElList(WidgetTester tester) {
  expect(find.byType(ElScrollView), findsOneWidget);
  expect(find.byType(rv.RecyclerView), findsNothing);
  expect(find.byType(CupertinoScrollbar), findsNothing);
  final scroll = tester.widget<ElScrollView>(find.byType(ElScrollView));
  expect(scroll.scrollbar, isA<ElIosScrollBar>());
  final list = tester.widget<ElListView>(find.byType(ElListView));
  expect(list.itemCount, 10000);
  expect(list.keepAlive, isFalse);
  expect(list.fixedSize, isTrue);
  expect(scroll.controller!.positions, hasLength(1));
}

Finder _checkbox(int id) {
  final title = find.text('条目 ${(id + 1).toString().padLeft(5, '0')}').hitTestable();
  final row = find.ancestor(of: title, matching: find.byType(Row)).first;
  return find.descendant(of: row, matching: find.byType(ElCheckbox));
}

bool _checked(WidgetTester tester, int id) => tester.widget<ElCheckbox>(_checkbox(id)).modelValue!.value as bool;

Finder _card(String number) => find
    .ancestor(of: find.textContaining('观测 #$number'), matching: find.byKey(ValueKey('cards-activate')))
    .hitTestable();

bool _selected(WidgetTester tester, Finder card) => tester.widget<Semantics>(card).properties.selected!;

String _cardText(WidgetTester tester, Finder card, String key) =>
    tester.widget<Text>(find.descendant(of: card, matching: find.byKey(ValueKey(key)))).data!;
