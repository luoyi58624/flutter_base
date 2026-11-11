import 'dart:collection';
import 'dart:convert';

import 'package:example/src/pages/examples/scroll_examples/cards.dart';
import 'package:example/src/pages/examples/scroll_examples/chat.dart';
import 'package:example/src/pages/examples/scroll_examples/orders.dart';
import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:example/src/pages/examples/scroll_examples/social_feed.dart';
import 'package:example/src/pages/examples/sliver_recycler/index.dart';
import 'package:example/src/pages/examples/sliver_takeaway/index.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_test/flutter_test.dart';

const _timing = bool.fromEnvironment('BUSINESS_PERF');
const _samples = int.fromEnvironment('BUSINESS_PERF_SAMPLES', defaultValue: _timing ? 8 : 3);
const _passes = _timing ? 2 : 1;
const _warmupSteps = 6;
const _step = 192.0;
const _frame = Duration(milliseconds: 16);

enum _Mode { official, recycler }

enum _Scene {
  cards,
  orders,
  socialFeed,
  chat,
  liveChat,
  selection,
  rectangles,
  text,
  videoCards,
  complex,
  takeaway;

  Widget createPage() => switch (this) {
    .cards => RecyclerCardsPage(),
    .orders => RecyclerOrdersPage(),
    .socialFeed => RecyclerSocialFeedPage(),
    .chat => RecyclerChatPage(),
    .liveChat => RecyclerLiveChatPage(),
    .selection => RecyclerSelectionPage(),
    .rectangles => ElSliverRecyclerExamplePage(initialContent: .rectangles),
    .text => ElSliverRecyclerExamplePage(initialContent: .text),
    .videoCards => ElSliverRecyclerExamplePage(initialContent: .videoCards),
    .complex => ElSliverRecyclerExamplePage(initialContent: .complex),
    .takeaway => TakeawaySliverPage(networkPhotos: false),
  };

  String? get menuKey => switch (this) {
    .cards => 'cards-menu',
    .orders || .socialFeed => 'comparison-mode-menu',
    .chat || .liveChat => 'chat-menu',
    .selection => 'selection-menu',
    .takeaway => 'takeaway-sliver-menu',
    _ => null,
  };

  String? modeKey(_Mode mode) => switch (this) {
    .cards => 'cards-mode-${mode.name}',
    .orders || .socialFeed => 'comparison-mode-${mode.name}',
    .chat || .liveChat => 'chat-mode-${mode.name}',
    .selection => 'selection-mode-${mode.name}',
    .takeaway => 'takeaway-mode-${mode.name}',
    _ => null,
  };

  List<ImageProvider<Object>> get assets => switch (this) {
    .cards || .complex => [
      ResizeImage.resizeIfNeeded(960, null, AssetImage('assets/recycler_cards/owl.jpg')),
      ResizeImage.resizeIfNeeded(960, null, AssetImage('assets/recycler_cards/owl-2.jpg')),
    ],
    .socialFeed => [
      ResizeImage.resizeIfNeeded(360, null, AssetImage('assets/recycler_cards/owl.jpg')),
      ResizeImage.resizeIfNeeded(360, null, AssetImage('assets/recycler_cards/owl-2.jpg')),
    ],
    .videoCards => [AssetImage('assets/recycler_cards/bili_home.webp')],
    .takeaway => [AssetImage('assets/recycler_cards/takeaway-food.webp')],
    _ => [],
  };
}

void main() {
  for (final scene in _Scene.values) {
    testWidgets('业务页面基准 ${scene.name}', (tester) async {
      expect(_samples, greaterThan(0));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final work = _BuildWork()..observe();
      await _precache(tester, scene.assets);

      debugPrintSynchronously(
        'BUSINESS_PERF_CONFIG ${jsonEncode({
          'scene': scene.name,
          'timing': _timing,
          'viewport': [390, 800],
          'device_pixel_ratio': 1,
          'platform': 'android',
          'scope': 'real page; instrumented flutter_tester debug action+pump wall time; not device frame time',
          'identity_scope': 'main vertical scroll host including cached and pooled descendants',
          'snapshots_timed': false,
          'warmup_steps': _warmupSteps,
          'step_px': _step,
          'samples_per_direction': _samples,
          'passes': _passes,
          'simulated_pump_interval_us': _frame.inMicroseconds,
          'images': 'real local assets warmed before measurement; network photos disabled',
        })}',
      );

      for (var pass = 0; pass < _passes; pass++) {
        final modes = pass.isEven ? _Mode.values : _Mode.values.reversed;
        for (final mode in modes) {
          await tester.pumpWidget(SizedBox.shrink());
          await tester.pumpWidget(_app(scene.createPage()));
          await tester.pumpAndSettle();
          _menuAction(
            tester,
            menuKey: scene.menuKey,
            optionKey: scene.modeKey(mode),
            label: mode == .official ? 'SliverList' : 'ElSliverRecyclerList',
          )();
          await tester.pumpAndSettle();

          final root = tester.element(_mainScroll());
          final (controller, reverse, cache) = switch (root.widget) {
            CustomScrollView scroll => (scroll.controller!, scroll.reverse, scroll.scrollCacheExtent),
            ElScroll scroll => (scroll.controller!, scroll.reverse, scroll.scrollCacheExtent),
            _ => throw StateError('找不到页面滚动宿主。'),
          };
          final primarySliver = _primarySliver(root);
          expect(primarySliver, mode == .official ? isA<SliverList>() : isA<ElSliverRecyclerList>());
          final itemCount = switch (primarySliver) {
            SliverList list => list.delegate.estimatedChildCount,
            ElSliverRecyclerList list => list.itemCount,
            _ => null,
          };
          expect(itemCount, 10000, reason: '使用真实页面完整数据集，不用基准替身缩减负载。');
          expect(controller.position.viewportDimension, greaterThan(0));
          _assertOffline(_TreeSnapshot(root));

          for (var i = 1; i <= _warmupSteps; i++) {
            controller.jumpTo(i * _step);
            await tester.pump(_frame);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final metadata = {
            'item_count': itemCount,
            'viewport_dimension': controller.position.viewportDimension,
            'reverse': reverse,
            'cache': cache.toString(),
            'scroll_host': root.widget.runtimeType.toString(),
          };

          for (final forward in [true, false]) {
            final frames = <Map<String, Object?>>[];
            for (var i = 0; i < _samples; i++) {
              final target = (_warmupSteps + (forward ? i + 1 : _samples - i - 1)) * _step;
              expect(target, lessThan(controller.position.maxScrollExtent));
              frames.add(
                await _sample(
                  tester,
                  work,
                  root,
                  controller,
                  requestedOffset: target,
                  action: () => controller.jumpTo(target),
                ),
              );
            }
            _report(scene, mode, pass, forward ? 'forward' : 'backward', frames, metadata);
          }

          if (scene == .cards || scene == .orders) {
            final update = scene == .cards
                ? _menuAction(tester, menuKey: 'cards-menu', optionKey: 'cards-refresh-visible')
                : tester.widget<TextButton>(find.byKey(ValueKey('orders-update'))).onPressed!;
            update();
            await tester.pumpAndSettle();
            final frames = <Map<String, Object?>>[];
            for (var i = 0; i < _samples; i++) {
              final before = _updateFingerprint(scene, _TreeSnapshot(root));
              frames.add(await _sample(tester, work, root, controller, action: update));
              expect(_updateFingerprint(scene, _TreeSnapshot(root)), isNot(before), reason: '更新阶段必须实际改变页面数据。');
            }
            _report(scene, mode, pass, 'visibleUpdate', frames, {...metadata, 'update_warmup': 1});
          }
          await tester.pumpWidget(SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
      }
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }
}

Widget _app(Widget page) => ElComponentProvider(
  components: el.mobileComponents,
  child: MaterialApp(
    navigatorKey: el.navigatorKey,
    theme: ThemeData(platform: .android),
    home: page,
  ),
);

Finder _mainScroll() => find.byWidgetPredicate(
  (widget) =>
      widget is CustomScrollView && widget.scrollDirection == Axis.vertical ||
      widget is ElScroll && widget.axis == Axis.vertical,
);

Future<void> _precache(WidgetTester tester, List<ImageProvider<Object>> images) async {
  if (images.isEmpty) return;
  final key = GlobalKey();
  await tester.pumpWidget(_app(SizedBox(key: key)));
  final errors = <Object>[];
  await tester.runAsync(() async {
    await Future.wait([
      for (final image in images) precacheImage(image, key.currentContext!, onError: (error, _) => errors.add(error)),
    ]).timeout(Duration(seconds: 15));
  });
  expect(errors, isEmpty, reason: '真实素材加载失败时不能把空图片负载当成成功基准。');
  await tester.pumpAndSettle();
}

// 只读取页面已有公开 Widget 配置，不打开菜单，也不调用私有 State 方法。
VoidCallback _menuAction(WidgetTester tester, {String? menuKey, String? optionKey, String? label}) {
  final finder = menuKey == null
      ? find.byWidgetPredicate((widget) => widget is PopupMenuButton<Enum>)
      : find.byKey(ValueKey(menuKey));
  final element = tester.element(finder);
  // 菜单使用页面私有枚举；动态访问保留真实回调类型，避免协变读取 onSelected 时强转失败。
  final dynamic menu = element.widget;
  final List<PopupMenuEntry<dynamic>> entries = menu.itemBuilder(element);
  final options = entries.whereType<PopupMenuItem<dynamic>>();
  final selected = options.singleWhere(
    (item) =>
        optionKey != null ? item.key == ValueKey(optionKey) : item.child is Text && (item.child! as Text).data == label,
  );
  expect(selected.enabled, isTrue);
  expect(menu.onSelected, isNotNull);
  return () => menu.onSelected!(selected.value);
}

Widget _primarySliver(Element root) {
  Widget? found;
  void visit(Element element) {
    if (found != null) return;
    if (element.widget is SliverList || element.widget is ElSliverRecyclerList) {
      found = element.widget;
      return;
    }
    element.visitChildElements(visit);
  }

  visit(root);
  expect(found, isNotNull);
  return found!;
}

class _BuildWork {
  final counts = <String, int>{};
  final byType = <String, int>{};
  bool recording = false;

  void observe() {
    final previous = debugOnRebuildDirtyWidget;
    final seen = Expando<bool>();
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previous?.call(element, builtOnce);
      final alreadyBuilt = seen[element] == true;
      seen[element] = true;
      if (!recording) return;
      _increment(counts, alreadyBuilt ? 'global_rebuild' : 'global_first_build');
      final type = element.widget.runtimeType.toString();
      _increment(byType, type);
      if (type == '_TextEnvironment') _increment(counts, 'text_environment_build');
      if (element.widget is ElListenableBuilder) _increment(counts, 'selector_element_build');
      if (element.widget is ValueListenableBuilder) _increment(counts, 'value_element_build');
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
  }

  void reset() {
    counts.clear();
    byType.clear();
    BenchmarkProbe.reset();
  }
}

class _TreeSnapshot {
  _TreeSnapshot(Element root) {
    void visit(Element element) {
      elements[element] = element.widget;
      // ComponentElement.renderObject 会向下寻找同一个对象，不能据此重复计算渲染节点。
      if (element is RenderObjectElement) renders.add(element.renderObject);
      element.visitChildElements(visit);
    }

    visit(root);
  }

  final elements = HashMap<Element, Widget>.identity();
  final renders = HashSet<RenderObject>.identity();

  Map<String, Object> compare(_TreeSnapshot before) {
    final counts = <String, int>{
      'element_new': 0,
      'element_lost': 0,
      'element_widget_change': 0,
      'elview_new': 0,
      'elview_lost': 0,
      'elview_widget_change': 0,
      'text_environment_new': 0,
      'text_environment_lost': 0,
      'text_environment_widget_change': 0,
      'render_new': renders.where((render) => !before.renders.contains(render)).length,
      'render_lost': before.renders.where((render) => !renders.contains(render)).length,
    };
    final newTypes = <String, int>{};
    final lostTypes = <String, int>{};
    final changedTypes = <String, int>{};
    void count(String action, Widget widget, Map<String, int> types) {
      _increment(counts, action == 'widget_change' ? 'element_widget_change' : 'element_$action');
      _increment(types, widget.runtimeType.toString());
      if (widget is ElView) _increment(counts, 'elview_$action');
      if (widget.runtimeType.toString() == '_TextEnvironment') _increment(counts, 'text_environment_$action');
    }

    for (final entry in elements.entries) {
      final previous = before.elements[entry.key];
      if (previous == null) {
        count('new', entry.value, newTypes);
      } else if (!identical(entry.value, previous)) {
        count('widget_change', entry.value, changedTypes);
      }
    }
    for (final entry in before.elements.entries) {
      if (!elements.containsKey(entry.key)) count('lost', entry.value, lostTypes);
    }
    return {
      'identity': counts,
      'new_element_types': newTypes,
      'lost_element_types': lostTypes,
      'changed_widget_types': changedTypes,
      'elements_before': before.elements.length,
      'elements_after': elements.length,
      'renders_before': before.renders.length,
      'renders_after': renders.length,
    };
  }
}

void _increment(Map<String, int> target, String key, [int value = 1]) =>
    target.update(key, (previous) => previous + value, ifAbsent: () => value);

Future<Map<String, Object?>> _sample(
  WidgetTester tester,
  _BuildWork work,
  Element root,
  ScrollController controller, {
  required VoidCallback action,
  double? requestedOffset,
}) async {
  final before = _TreeSnapshot(root);
  final beforeOffset = controller.offset;
  work.reset();
  work.recording = true;
  final watch = Stopwatch()..start();
  try {
    action();
    await tester.pump(_frame);
  } finally {
    watch.stop();
    work.recording = false;
  }
  final counters = {
    ...work.counts,
    'elview_layout': BenchmarkProbe.performLayoutCount,
    'elview_cascade': BenchmarkProbe.cascadeTickCount,
    'elview_style_resolve': BenchmarkProbe.builderBuildCount,
    'text_engine_create': BenchmarkProbe.textLayerInstantiateCount,
  };
  final after = _TreeSnapshot(root);
  expect(tester.element(_mainScroll()), same(root));
  expect(controller.offset.isFinite, isTrue);
  if (requestedOffset != null) {
    expect(
      (controller.offset - beforeOffset) * (requestedOffset - beforeOffset),
      greaterThan(0),
      reason: '滚动样本必须实际沿目标方向移动，不能把未滚动当作零工作。',
    );
  }
  expect(tester.takeException(), isNull);
  _assertOffline(after);
  return {
    if (_timing) 'micros': watch.elapsedMicroseconds,
    'offset_before': beforeOffset,
    'offset_after': controller.offset,
    'requested_offset': ?requestedOffset,
    'work': counters,
    'build_types': Map<String, int>.of(work.byType),
    ...after.compare(before),
  };
}

void _assertOffline(_TreeSnapshot tree) {
  bool network(ImageProvider<Object> image) =>
      image is NetworkImage || image is ResizeImage && network(image.imageProvider);
  expect(
    tree.elements.values.whereType<Image>().any((widget) => network(widget.image)),
    isFalse,
    reason: '业务滚动基准只用真实本地资源，不发网络图片请求。',
  );
}

String _updateFingerprint(_Scene scene, _TreeSnapshot tree) {
  final values = switch (scene) {
    .cards =>
      tree.elements.values
          .whereType<Text>()
          .where((widget) => widget.key == ValueKey('cards-visits'))
          .map((widget) => widget.data ?? '')
          .toList(),
    .orders => tree.elements.values.whereType<LinearProgressIndicator>().map((widget) => '${widget.value}').toList(),
    _ => throw StateError('此页面没有定义更新观测点。'),
  };
  // 身份哈希表没有业务顺序，比较值集合，避免遍历顺序变化伪装成数据更新。
  values.sort();
  return values.join('|');
}

void _report(
  _Scene scene,
  _Mode mode,
  int pass,
  String phase,
  List<Map<String, Object?>> frames,
  Map<String, Object?> metadata,
) {
  final totals = <String, int>{};
  final types = <String, Map<String, int>>{};
  for (final frame in frames) {
    for (final category in ['work', 'identity']) {
      for (final entry in (frame[category]! as Map<String, int>).entries) {
        _increment(totals, entry.key, entry.value);
      }
    }
    for (final category in ['build_types', 'new_element_types', 'lost_element_types', 'changed_widget_types']) {
      final target = types.putIfAbsent(category, () => {});
      for (final entry in (frame[category]! as Map<String, int>).entries) {
        _increment(target, entry.key, entry.value);
      }
    }
  }
  final times = _timing ? (frames.map((frame) => frame['micros']! as int).toList()..sort()) : <int>[];
  debugPrintSynchronously(
    'BUSINESS_PERF_RESULT ${jsonEncode({'scene': scene.name, 'mode': mode.name, 'pass': pass, 'phase': phase, 'samples': frames.length, 'timing': _timing, ...metadata, if (_timing) 'median_us': times[(times.length - 1) ~/ 2], if (_timing) 'p95_us': times[(times.length * .95).ceil() - 1], 'totals': totals, 'types': types, 'frames': frames})}',
  );
}
