import 'package:example/src/pages/examples/scroll_examples/orders.dart';
import 'package:example/src/pages/examples/scroll_examples/scroll_mode.dart';
import 'package:example/src/pages/examples/scroll_examples/social_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Future<void> _open(WidgetTester tester, Widget page, {double width = 390, double textScale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ElComponentProvider(
      components: el.mobileComponents,
      child: MaterialApp(
        home: page,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ScrollController _controller(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 250, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> _mode(WidgetTester tester, SliverExampleMode mode) async {
  await _tap(tester, _key('comparison-mode-menu'));
  await _tap(tester, _key('comparison-mode-${mode.name}'));
}

Finder _socialCard(int id) => find
    .ancestor(
      of: find.byWidgetPredicate((widget) => widget is Text && widget.data?.endsWith(' · 动态 #${id + 1}') == true),
      matching: _key('social-post-card'),
    )
    .hitTestable();

Finder _orderCard(int id) => find.ancestor(of: find.text('订单 #$id'), matching: _key('orders-card')).hitTestable();

Finder _within(Finder card, Finder child) => find.descendant(of: card, matching: child);

String _summary(WidgetTester tester) => tester.widget<Text>(_key('orders-summary')).data!;

Finder _element(Element element) => find.byElementPredicate((candidate) => identical(candidate, element));

int _recordId(WidgetTester tester, Finder card, {bool social = false}) {
  final pattern = social ? RegExp(r' · 动态 #(\d+)$') : RegExp(r'^订单 #(\d+)$');
  for (final text in tester.widgetList<Text>(_within(card, find.byType(Text)))) {
    final match = pattern.firstMatch(text.data ?? '');
    if (match != null) return int.parse(match[1]!) - (social ? 1 : 0);
  }
  throw StateError('未找到卡片的业务记录');
}

ValueNotifier<T> _sourceOf<T>(WidgetTester tester, Finder leaf) {
  ValueNotifier<T>? source;
  // 页面外层也可能监听同一类型，业务来源只取离交互叶子最近的一层。
  tester.element(leaf).visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is ValueListenableBuilder<T>) {
      source = widget.valueListenable as ValueNotifier<T>;
      return false;
    }
    return true;
  });
  return source ?? (throw StateError('未找到交互叶子的业务通知来源'));
}

Future<int> _rebindCard(WidgetTester tester, Element element, int previous, {bool social = false}) async {
  final controller = _controller(tester);
  for (var step = 0; step < 12; step++) {
    controller.jumpTo(controller.offset + 1000);
    await tester.pumpAndSettle();
    expect(element.mounted, isTrue, reason: '回收换绑应保留卡片 Element');
    final card = _element(element);
    final current = _recordId(tester, card, social: social);
    if (current != previous) return current;
  }
  throw StateError('滚动后卡片未换绑到新记录');
}

void main() {
  testWidgets('订单跨记录保留卡片结构，旧回调读取当前订单并切换状态来源', (tester) async {
    await _open(tester, RecyclerOrdersPage());
    final original = _orderCard(10000);
    final element = tester.element(original);
    final panel = element.widget;
    final checkbox = _within(original, _key('orders-select'));
    final oldSelect = tester.widget<Checkbox>(checkbox).onChanged!;
    final oldSelected = _sourceOf<bool>(tester, checkbox);
    final oldProgress = _sourceOf<int>(tester, _within(original, find.byType(LinearProgressIndicator)));
    final originalProgress = oldProgress.value;

    final currentId = await _rebindCard(tester, element, 10000);
    final current = _element(element);
    expect(element.widget, same(panel));
    final currentProgress = _within(current, find.byType(LinearProgressIndicator));
    final currentSelected = _sourceOf<bool>(tester, _within(current, _key('orders-select')));
    final currentProgressSource = _sourceOf<int>(tester, currentProgress);
    expect(currentSelected, isNot(same(oldSelected)));
    expect(currentProgressSource, isNot(same(oldProgress)));
    expect(tester.widget<LinearProgressIndicator>(currentProgress).value, (currentId * 7 % 101) / 100);

    oldSelect(true);
    await tester.pumpAndSettle();
    expect(currentSelected.value, isTrue);
    expect(oldSelected.value, isFalse);
    expect(_summary(tester), '共 10000 单 · 已选 1 单 · 已更新 0 批');

    final currentCheckboxWidget = tester.widget<Checkbox>(_within(current, _key('orders-select')));
    final currentProgressWidget = tester.widget<LinearProgressIndicator>(currentProgress);
    oldSelected.value = true;
    oldProgress.value = (originalProgress + 19) % 101;
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(_within(current, _key('orders-select'))), same(currentCheckboxWidget));
    expect(tester.widget<LinearProgressIndicator>(currentProgress), same(currentProgressWidget));
    oldSelected.value = false;
    oldProgress.value = originalProgress;

    _controller(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(_within(_orderCard(10000), _key('orders-select'))).value, isFalse);
    _controller(tester).jumpTo((10000 - currentId) * 128.0);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(_within(_orderCard(currentId), _key('orders-select'))).value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('长文复用保留固定结构，展开和点赞回调及通知来源随当前记录切换', (tester) async {
    await _open(tester, RecyclerSocialFeedPage());
    final original = _socialCard(0);
    final element = tester.element(original);
    final panel = element.widget;
    final expand = _within(original, _key('social-expand'));
    final like = _within(original, _key('social-like'));
    final oldExpand = tester.widget<TextButton>(expand).onPressed!;
    final oldLike = tester.widget<TextButton>(like).onPressed!;
    final oldExpanded = _sourceOf<bool>(tester, expand);
    final oldLiked = _sourceOf<bool>(tester, like);
    final title = tester.widget<Text>(_within(original, find.text('写在天亮之前')));

    final currentId = await _rebindCard(tester, element, 0, social: true);
    final current = _element(element);
    expect(currentId % 4, 0);
    expect(element.widget, same(panel));
    expect(tester.widget<Text>(_within(current, find.text('写在天亮之前'))), same(title));
    oldExpand();
    oldLike();
    await tester.pumpAndSettle();
    expect(_within(current, find.text('收起长文')), findsOneWidget);
    expect(_within(current, find.byIcon(Icons.favorite_rounded)), findsOneWidget);
    expect(oldExpanded.value, isFalse);
    expect(oldLiked.value, isFalse);

    final currentExpand = tester.widget<TextButton>(_within(current, _key('social-expand')));
    final currentLike = tester.widget<TextButton>(_within(current, _key('social-like')));
    oldExpanded.value = true;
    oldLiked.value = true;
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(_within(current, _key('social-expand'))), same(currentExpand));
    expect(tester.widget<TextButton>(_within(current, _key('social-like'))), same(currentLike));
    oldExpanded.value = false;
    oldLiked.value = false;

    _controller(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(_within(_socialCard(0), find.text('展开长文')), findsOneWidget);
    expect(_within(_socialCard(0), find.byIcon(Icons.favorite_border_rounded)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同类型九宫格换绑保留九张图片，投票旧回调只写入当前动态', (tester) async {
    await _open(tester, RecyclerSocialFeedPage());
    await _reveal(tester, _socialCard(1));
    final galleryElement = tester.element(_socialCard(1));
    final galleryPanel = galleryElement.widget;
    final images = tester.widgetList<Image>(_within(_element(galleryElement), find.byType(Image))).toList();
    expect(images, hasLength(9));
    final galleryId = await _rebindCard(tester, galleryElement, 1, social: true);
    expect(galleryId % 4, 1);
    expect(galleryElement.widget, same(galleryPanel));
    final reboundImages = tester.widgetList<Image>(_within(_element(galleryElement), find.byType(Image))).toList();
    for (var index = 0; index < images.length; index++) {
      expect(reboundImages[index], same(images[index]));
    }

    _controller(tester).jumpTo(0);
    await tester.pumpAndSettle();
    await _reveal(tester, _key('social-vote-0'));
    final poll = _socialCard(3);
    final pollElement = tester.element(poll);
    final pollPanel = pollElement.widget;
    final oldVote = tester.widget<OutlinedButton>(_within(poll, _key('social-vote-0'))).onPressed!;
    final oldVotes = _sourceOf<int?>(tester, _within(poll, _key('social-vote-0')));
    final pollId = await _rebindCard(tester, pollElement, 3, social: true);
    expect(pollId % 4, 3);
    expect(pollElement.widget, same(pollPanel));
    final current = _element(pollElement);
    oldVote();
    await tester.pumpAndSettle();
    expect(_within(current, find.text('河边慢走 · 39 票')), findsOneWidget);
    expect(oldVotes.value, isNull);
    final currentButton = tester.widget<OutlinedButton>(_within(current, _key('social-vote-0')));
    oldVotes.value = 1;
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(_within(current, _key('social-vote-0'))), same(currentButton));
    oldVotes.value = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('动态流在真实变高、九宫格和投票之间复用，两种模式共享记录状态', (tester) async {
    await _open(tester, RecyclerSocialFeedPage());
    final controller = _controller(tester);
    expect(tester.widget<ElSliverRecyclerList>(find.byType(ElSliverRecyclerList)).itemCount, 10000);
    final article = _socialCard(0);
    final height = tester.getSize(article).height;
    await _tap(tester, _within(article, _key('social-expand')));
    expect(tester.getSize(article).height, greaterThan(height));
    await _tap(tester, _within(article, _key('social-like')));

    await _reveal(tester, _key('social-post-card').at(1));
    expect(_within(_socialCard(1), find.byType(Image)), findsNWidgets(9));
    await _reveal(tester, _key('social-vote-0'));
    await _tap(tester, _within(_socialCard(3), _key('social-vote-0')));
    expect(_within(_socialCard(3), find.text('河边慢走 · 39 票')), findsOneWidget);
    controller.jumpTo(400000);
    await tester.pumpAndSettle();
    expect(_key('social-post-card').evaluate().length, lessThan(60));
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    await _reveal(tester, _key('social-vote-0'));
    expect(_within(_socialCard(3), find.text('河边慢走 · 39 票')), findsOneWidget);

    for (final mode in [SliverExampleMode.official]) {
      await _mode(tester, mode);
      expect(find.byType(ElSliverRecyclerList), findsNothing);
      expect(_key('comparison-official-list'), findsOneWidget);
      expect(_within(article, find.text('收起长文')), findsOneWidget);
      expect(_within(article, find.byIcon(Icons.favorite_rounded)), findsOneWidget);
    }
    await _mode(tester, .recycler);
    expect(_within(article, find.text('收起长文')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('万条订单的定向更新保留卡片，三种真实容器头部增删后保留阅读行', (tester) async {
    await _open(tester, RecyclerOrdersPage());
    final first = _orderCard(10000);
    final firstElement = tester.element(first);
    final progress = _within(first, find.byType(LinearProgressIndicator));
    final initialProgress = tester.widget<LinearProgressIndicator>(progress).value!;
    await _tap(tester, _within(first, _key('orders-select')));
    await _tap(tester, _key('orders-update'));
    expect(_summary(tester), '共 10000 单 · 已选 1 单 · 已更新 1 批');
    expect(tester.widget<LinearProgressIndicator>(progress).value, closeTo(initialProgress + .11, .001));
    expect(tester.element(first), same(firstElement));

    var current = SliverExampleMode.recycler;
    for (final mode in SliverExampleMode.values.reversed) {
      if (mode != current) {
        await _mode(tester, mode);
        current = mode;
      }
      expect(tester.widget<Checkbox>(_within(first, _key('orders-select'))).value, isTrue);
      expect(tester.widget<LinearProgressIndicator>(progress).value, closeTo(initialProgress + .11, .001));
      final controller = _controller(tester);
      controller.jumpTo(64 * 128 + 24.0);
      await tester.pumpAndSettle();
      final anchor = _orderCard(9936);
      final top = tester.getTopLeft(anchor).dy;
      await _tap(tester, _key('orders-insert'));
      expect(_summary(tester), '共 10024 单 · 已选 1 单 · 已更新 1 批');
      expect(tester.getTopLeft(anchor).dy, closeTo(top, .5));
      await _tap(tester, _key('orders-remove'));
      expect(_summary(tester), '共 10000 单 · 已选 1 单 · 已更新 1 批');
      expect(tester.getTopLeft(anchor).dy, closeTo(top, .5));
    }

    await _mode(tester, .recycler);
    await _tap(tester, _key('orders-remove'));
    expect(_summary(tester), '共 9976 单 · 已选 0 单 · 已更新 1 批');
    expect(tester.takeException(), isNull);
  });

  testWidgets('订单压力跑固定 32 批并随滚动窗口推进，结束后不再继续', (tester) async {
    await _open(tester, RecyclerOrdersPage());
    final list = _controller(tester);
    list.jumpTo(400 * 128);
    await tester.pumpAndSettle();
    final row = _orderCard(9600);
    final progress = _within(row, find.byType(LinearProgressIndicator));
    final previous = tester.widget<LinearProgressIndicator>(progress).value!;
    await tester.tap(_key('orders-live'));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 250));
    expect(tester.widget<LinearProgressIndicator>(progress).value, isNot(previous));
    expect(_summary(tester), '共 10000 单 · 已选 0 单 · 已更新 1 批');
    await tester.pump(Duration(milliseconds: 7750));
    await tester.pumpAndSettle();
    expect(find.text('实时更新 8 秒'), findsOneWidget);
    expect(_summary(tester), '共 10000 单 · 已选 0 单 · 已更新 32 批');
    await tester.pump(Duration(seconds: 1));
    expect(_summary(tester), '共 10000 单 · 已选 0 单 · 已更新 32 批');
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏动态流与窄屏大字订单保留可操作的内容区域', (tester) async {
    await _open(tester, RecyclerSocialFeedPage(), width: 1100);
    expect(tester.getSize(find.byType(CustomScrollView)).width, 760);
    expect(_within(_socialCard(0), _key('social-expand')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _open(tester, RecyclerOrdersPage(), width: 320, textScale: 1.6);
    expect(_within(_orderCard(10000), _key('orders-select')).hitTestable(), findsOneWidget);
    await _tap(tester, _key('orders-update'));
    expect(_summary(tester), '共 10000 单 · 已选 0 单 · 已更新 1 批');
    expect(tester.takeException(), isNull);
  });
}
