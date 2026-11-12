import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:example/src/pages/examples/scroll_examples/cards.dart';
import 'package:example/src/pages/examples/scroll_examples/chat.dart';
import 'package:example/src/pages/examples/scroll_examples/media.dart';
import 'package:example/src/pages/examples/scroll_examples/orders.dart';
import 'package:example/src/pages/examples/scroll_examples/product_waterfall.dart';
import 'package:example/src/pages/examples/scroll_examples/selection.dart';
import 'package:example/src/pages/examples/scroll_examples/social_feed.dart';
import 'package:example/src/pages/examples/sliver_recycler/index.dart';
import 'package:example/src/pages/examples/sliver_recycler_grid/index.dart';
import 'package:example/src/pages/examples/sliver_takeaway/index.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/flutter/utils/internal/benchmark_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

const _timing = bool.fromEnvironment('BUSINESS_PERF');
const _onlyMode = String.fromEnvironment('BUSINESS_PERF_MODE');
const _samples = int.fromEnvironment('BUSINESS_PERF_SAMPLES', defaultValue: _timing ? 8 : 3);
const _passes = _timing ? 2 : 1;
const _warmupSteps = 6;
const _step = 192.0;
const _frame = Duration(milliseconds: 16);
const _mediaFileCount = 96;

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
  grid,
  masonry,
  mediaVideo,
  mediaAlbum,
  mediaWaterfall,
  mediaLocalWaterfall,
  productWaterfall,
  takeaway;

  bool get isGrid => switch (this) {
    .grid ||
    .masonry ||
    .mediaVideo ||
    .mediaAlbum ||
    .mediaWaterfall ||
    .mediaLocalWaterfall ||
    .productWaterfall => true,
    _ => false,
  };

  bool get hasMediaFiles => this == .mediaVideo || this == .mediaAlbum || this == .mediaLocalWaterfall;

  bool get isMedia => hasMediaFiles || this == .mediaWaterfall;

  // 相册的 5 列小格用较短步长，96 张真实图片仍能覆盖完整的双向采样。
  double get step => this == .mediaAlbum ? 48 : _step;

  int get expectedItemCount => switch (this) {
    .grid || .masonry || .productWaterfall => 1000,
    .mediaVideo || .mediaAlbum || .mediaLocalWaterfall => _mediaFileCount,
    _ => 10000,
  };

  Widget createPage({String? directory}) => switch (this) {
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
    .grid => ElSliverRecyclerGridExamplePage(),
    .masonry => ElSliverRecyclerGridExamplePage.masonry(),
    .mediaVideo => RecyclerVideoGridPage(directory: directory!),
    .mediaAlbum => RecyclerGalleryPage(directory: directory!),
    .mediaWaterfall => RecyclerWaterfallPage(),
    .mediaLocalWaterfall => RecyclerWaterfallPage(directory: directory!),
    .productWaterfall => RecyclerProductWaterfallPage(),
    .takeaway => TakeawaySliverPage(networkPhotos: false),
  };

  String? get menuKey => switch (this) {
    .cards => 'cards-menu',
    .orders || .socialFeed => 'comparison-mode-menu',
    .chat || .liveChat => 'chat-menu',
    .selection => 'selection-menu',
    .grid || .masonry => 'grid-mode-menu',
    .mediaVideo || .mediaAlbum || .mediaWaterfall || .mediaLocalWaterfall => 'media-scroll-menu',
    .productWaterfall => 'product-waterfall-mode',
    .takeaway => 'takeaway-sliver-menu',
    _ => null,
  };

  String? modeKey(_Mode mode) => switch (this) {
    .cards => 'cards-mode-${mode.name}',
    .orders || .socialFeed => 'comparison-mode-${mode.name}',
    .chat || .liveChat => 'chat-mode-${mode.name}',
    .selection => 'selection-mode-${mode.name}',
    .mediaVideo || .mediaAlbum || .mediaWaterfall || .mediaLocalWaterfall => 'media-mode-${mode.name}',
    .productWaterfall => 'product-waterfall-mode-${mode == .official ? 'sliverGrid' : 'recycler'}',
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
    .mediaWaterfall => [
      ResizeImage(AssetImage('assets/recycler_cards/owl.jpg'), width: 320, height: 320, policy: .fit),
      ResizeImage(AssetImage('assets/recycler_cards/owl-2.jpg'), width: 320, height: 320, policy: .fit),
    ],
    .productWaterfall => [
      ResizeImage.resizeIfNeeded(195, null, AssetImage('assets/recycler_cards/owl.jpg')),
      ResizeImage.resizeIfNeeded(195, null, AssetImage('assets/recycler_cards/owl-2.jpg')),
    ],
    _ => [],
  };

  Map<String, Object?> geometryMetadata(_Mode mode) {
    final official = mode == .official;
    return switch (this) {
      .grid || .masonry => {
        'geometry': official
            ? 'fixed-height grid'
            : this == .masonry
            ? 'natural-height masonry'
            : 'natural-height rows',
        'geometry_note': 'official reserved uniform extent differs from recycler natural card heights',
      },
      .mediaVideo => {
        'geometry': official ? 'fixed-height 2-column SliverGrid' : 'natural-height 2-column recycler rows',
        'geometry_note': 'both retain the real page 4:3 covers, caption slots and full-width featured header',
      },
      .mediaAlbum => {
        'geometry': official ? 'fixed square 5-column SliverGrid' : 'natural square 5-column recycler rows',
        'geometry_note': 'both use 78px square cells at the 390px viewport; 48px scroll step',
        'thumbnail_queue':
            'real page queue active; providers predecoded; normal per-frame notifications and fades retained',
      },
      .mediaWaterfall => {
        'geometry': official ? 'business-precomputed masonry SliverGrid' : 'natural-height recycler masonry',
        'geometry_note': 'both use the complete 10000 records, explicit demo cover ratios and shared caption slots',
      },
      .mediaLocalWaterfall => {
        'geometry': official
            ? 'business-precomputed square-cover masonry SliverGrid'
            : 'decoded-image natural-height recycler masonry',
        'geometry_note': 'local file metadata has no dimensions: official uses ratio 1 and a fixed footer slot; recycler uses decoded ratios clamped to 0.6..1.8 and natural caption height; geometry differs',
      },
      .productWaterfall => {
        'geometry': official ? 'business-precomputed masonry SliverGrid' : 'natural-height recycler masonry',
        'geometry_note': 'both use the same initial per-product image metadata and caption slots',
        'cache_equivalent': false,
        'cache_note': 'real page retains official cache=0px and recycler default cache',
        'size_reveal': 'not requested; 450ms reveal timer never started; revealed count asserted zero throughout',
      },
      _ => {},
    };
  }
}

void main() {
  for (final scene in _Scene.values) {
    testWidgets('业务页面基准 ${scene.name}', (tester) async {
      expect(_samples, greaterThan(0));
      expect(_onlyMode.isEmpty || _Mode.values.any((mode) => mode.name == _onlyMode), isTrue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final work = _BuildWork()..observe();
      try {
        final mediaFiles = scene.hasMediaFiles ? await _MediaFiles.create(tester) : null;
        await _precache(tester, [...scene.assets, ...?mediaFiles?.providers]);
        if (scene == .takeaway) {
          await tester.runAsync(() async {
            // ElImageView 按布局尺寸解码，分别预热店标和商品使用的完整图集尺寸。
            for (final size in [Size(288, 216), Size(384, 288)]) {
              await ElImageView.preload(
                'assets/recycler_cards/takeaway-food.webp',
                size: size,
                devicePixelRatio: 1,
                fit: .fill,
              ).timeout(Duration(seconds: 15));
            }
          });
        }

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
            'step_px': scene.step,
            'samples_per_direction': _samples,
            'passes': _passes,
            'modes': [for (final mode in _Mode.values)
              if (_onlyMode.isEmpty || mode.name == _onlyMode) mode.name],
            'simulated_pump_interval_us': _frame.inMicroseconds,
            'images': mediaFiles == null ? 'real local assets warmed before measurement; network photos disabled' : '96 real local PNG files from 3 small generated images; all thumbnail providers predecoded before measurement',
            if (mediaFiles != null) 'fixture': mediaFiles.metadata,
          })}',
        );

        for (var pass = 0; pass < _passes; pass++) {
          final modes = pass.isEven ? _Mode.values : _Mode.values.reversed;
          for (final mode in modes) {
            if (_onlyMode.isNotEmpty && mode.name != _onlyMode) continue;
            await tester.pumpWidget(SizedBox.shrink());
            await tester.pumpWidget(_app(scene.createPage(directory: mediaFiles?.directory.path)));
            // 先放行真实目录 IO，再等待动画结束；加载中的转圈不会自行 settle。
            if (mediaFiles != null) await _waitForMediaFiles(tester, mediaFiles.files.length);
            await tester.pumpAndSettle();
            _menuAction(
              tester,
              menuKey: scene.menuKey,
              optionKey: scene.modeKey(mode),
              label: scene.isGrid
                  ? (mode == .official ? 'SliverGrid' : 'ElSliverGrid')
                  : (mode == .official ? 'SliverList' : 'ElSliverList'),
            )();
            await tester.pumpAndSettle();

            final root = tester.element(_mainScroll());
            final (controller, reverse, cache) = switch (root.widget) {
              CustomScrollView scroll => (scroll.controller!, scroll.reverse, scroll.scrollCacheExtent),
              ElScrollView scroll => (scroll.controller!, scroll.reverse, scroll.scrollCacheExtent),
              _ => throw StateError('找不到页面滚动宿主。'),
            };
            final primarySliver = _primarySliver(root);
            expect(
              primarySliver,
              scene.isGrid
                  ? (mode == .official ? isA<SliverGrid>() : isA<ElSliverGrid>())
                  : (mode == .official ? isA<SliverList>() : isA<ElSliverList>()),
            );
            final itemCount = switch (primarySliver) {
              SliverList list => list.delegate.estimatedChildCount,
              ElSliverList list => list.itemCount,
              SliverGrid grid => grid.delegate.estimatedChildCount,
              ElSliverGrid grid => grid.itemCount,
              _ => null,
            };
            expect(
              itemCount,
              mediaFiles?.files.length ?? scene.expectedItemCount,
              reason: '使用真实页面完整数据集；本地媒体完整读取明确注入的测试目录。',
            );
            expect(controller.position.viewportDimension, greaterThan(0));
            _assertOffline(_TreeSnapshot(root));

            for (var i = 1; i <= _warmupSteps; i++) {
              controller.jumpTo(i * scene.step);
              await tester.pump(_frame);
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (scene.isMedia) _assertVisibleMediaImages(tester);
            if (scene == .takeaway) {
              final images = _TreeSnapshot(root).renders.whereType<RenderImage>().toList();
              expect(images, isNotEmpty);
              expect(images.every((image) => image.image != null), isTrue, reason: '外卖 ElImageView 必须已显示真实图集。');
            }
            if (scene == .productWaterfall) _assertUnrevealedProducts(tester);
            final metadata = {
              'item_count': itemCount,
              'viewport_dimension': controller.position.viewportDimension,
              'reverse': reverse,
              'cache': cache.toString(),
              'scroll_host': root.widget.runtimeType.toString(),
              'content_sliver': primarySliver.runtimeType.toString(),
              'step_px': scene.step,
              ...scene.geometryMetadata(mode),
              if (mediaFiles != null) 'fixture': mediaFiles.metadata,
            };

            for (final forward in [true, false]) {
              final frames = <Map<String, Object?>>[];
              for (var i = 0; i < _samples; i++) {
                final target = (_warmupSteps + (forward ? i + 1 : _samples - i - 1)) * scene.step;
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
                if (scene == .productWaterfall) _assertUnrevealedProducts(tester);
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
            if (scene == .selection) {
              final frames = <Map<String, Object?>>[];
              for (var i = 0; i < _samples; i++) {
                final before = tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data;
                frames.add(
                  await _sample(
                    tester,
                    work,
                    root,
                    controller,
                    action: () {
                      final checkbox = tester.widget<ElCheckbox>(find.byType(ElCheckbox).hitTestable().first);
                      final value = checkbox.modelValue!;
                      // 与页面行点击相同的模型入口，包含实际 onChanged 及计数更新。
                      value.value = value.value != true;
                    },
                  ),
                );
                expect(tester.widget<Text>(find.byKey(ValueKey('selection-count'))).data, isNot(before));
              }
              _report(scene, mode, pass, 'selectionToggle', frames, metadata);
            }
            if (scene == .liveChat) {
              void step() => tester.widget<TextButton>(find.byKey(ValueKey('chat-live-step'))).onPressed!();
              String streamText() => tester
                  .widgetList<Text>(find.byType(Text))
                  .map((text) => text.data ?? '')
                  .singleWhere((text) => text.startsWith('小林的滚动记录正在整理。'));
              final frames = <Map<String, Object?>>[];
              for (var i = 0; i < _samples; i++) {
                // 结构步骤在计时外执行，只测 1、3、6、7 四个纯正文增长步骤。
                if (i % 4 == 0) {
                  tester.widget<TextButton>(find.byKey(ValueKey('chat-live-reset'))).onPressed!();
                  await tester.pumpAndSettle();
                }
                final preparationSteps = switch (i % 4) {
                  0 || 1 => 1,
                  2 => 2,
                  _ => 0,
                };
                for (var j = 0; j < preparationSteps; j++) {
                  step();
                  await tester.pumpAndSettle();
                }
                final count = tester.widget<Text>(find.byKey(ValueKey('chat-count'))).data;
                final before = streamText();
                frames.add(await _sample(tester, work, root, controller, action: step));
                expect(tester.widget<Text>(find.byKey(ValueKey('chat-count'))).data, count);
                expect(streamText().length, greaterThan(before.length), reason: '纯内容样本必须显示新增正文。');
              }
              _report(scene, mode, pass, 'streamContent', frames, {
                ...metadata,
                'script_steps': [1, 3, 6, 7],
              });
            }
            await tester.pumpWidget(SizedBox.shrink());
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        }
      } finally {
        // 失败也必须释放页面、Ticker、焦点与全局导航键，再进入下一项测试。
        work.recording = false;
        await tester.pumpWidget(SizedBox.shrink());
        await tester.pump();
      }
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }
}

class _MediaFiles {
  _MediaFiles(this.directory);

  final Directory directory;
  final files = <File>[];

  List<ImageProvider<Object>> get providers => [
    for (final file in files) ResizeImage(FileImage(file), width: 320, height: 320, policy: .fit),
  ];

  Map<String, Object> get metadata => {
    'file_count': files.length,
    'unique_png_contents': 3,
    'dimensions': [
      [32, 64],
      [64, 32],
      [40, 40],
    ],
    'directory_scope': 'one explicitly created temporary directory; no children, user files, plugins or network',
    'decode':
        'all ResizeImage(FileImage, width=320, height=320, fit) providers warmed before mounting the measured page',
  };

  static Future<_MediaFiles> create(WidgetTester tester) async {
    final directory = await tester.runAsync(() => Directory.systemTemp.createTemp('flutter-business-media-'));
    final fixture = _MediaFiles(directory!);
    addTearDown(() async {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await tester.runAsync(() async {
        // 只清理本次明确创建的文件和空目录，不枚举目录，也不递归删除。
        for (final file in fixture.files) {
          if (path.dirname(file.absolute.path) != fixture.directory.absolute.path) {
            throw StateError('拒绝清理测试临时目录外的图片：${file.path}');
          }
          if (await file.exists()) await file.delete();
        }
        if (await fixture.directory.exists()) await fixture.directory.delete();
      });
    });
    await tester.runAsync(() async {
      final images = <List<int>>[];
      for (final (width, height, color) in [
        (32, 64, Colors.indigo),
        (64, 32, Colors.teal),
        (40, 40, Colors.deepOrange),
      ]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
        canvas.drawCircle(Offset(width / 3, height / 3), 7, Paint()..color = Colors.white);
        final picture = recorder.endRecording();
        final image = await picture.toImage(width, height);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          images.add(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
          picture.dispose();
        }
      }
      for (var index = 0; index < _mediaFileCount; index++) {
        final file = File(path.join(fixture.directory.path, '影像 ${index.toString().padLeft(3, '0')}.png'));
        fixture.files.add(file);
        await file.writeAsBytes(images[index % images.length]);
      }
    });
    return fixture;
  }
}

Future<void> _waitForMediaFiles(WidgetTester tester, int itemCount) async {
  // 页面仍经公开 directory 参数加载完整目录，等待和解码都在计时段外。
  for (var attempt = 0; attempt < 100; attempt++) {
    final grids = tester.widgetList<ElSliverGrid>(
      find.byWidgetPredicate((widget) => widget is ElSliverGrid || widget is ElSliverMasonry),
    );
    if (grids.length == 1 && grids.single.itemCount == itemCount) {
      return;
    }
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: 10)));
    await tester.pump();
  }
  fail('本地测试图片未在有界等待内完整加载。');
}

void _assertVisibleMediaImages(WidgetTester tester) {
  final cards = find.byKey(ValueKey('media-card')).hitTestable();
  expect(cards, findsWidgets);
  for (final card in cards.evaluate()) {
    final images = tester.widgetList<RawImage>(
      find.descendant(
        of: find.byElementPredicate((element) => identical(element, card)),
        matching: find.byType(RawImage),
      ),
    );
    expect(images, isNotEmpty, reason: '媒体样本开始前，可见卡片必须已显示真实解码图片。');
    expect(images.every((image) => image.image != null), isTrue);
  }
}

void _assertUnrevealedProducts(WidgetTester tester) {
  expect(tester.widget<Text>(find.byKey(ValueKey('product-waterfall-revealed'))).data, '已揭晓 0 张');
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
      widget is ElScrollView && widget.scrollDirection == Axis.vertical,
);

Future<void> _precache(WidgetTester tester, List<ImageProvider<Object>> images) async {
  if (images.isEmpty) return;
  final key = GlobalKey();
  try {
    // 图片预热无需业务全局 Navigator，独立宿主避免复用失败页面的导航状态。
    await tester.pumpWidget(MaterialApp(home: SizedBox(key: key)));
    final context = key.currentContext;
    if (context == null) throw StateError('图片预热宿主未能挂载。');
    final errors = <Object>[];
    await tester.runAsync(() async {
      await Future.wait([
        for (final image in images) precacheImage(image, context, onError: (error, _) => errors.add(error)),
      ]).timeout(Duration(seconds: 15));
    });
    expect(errors, isEmpty, reason: '真实素材加载失败时不能把空图片负载当成成功基准。');
    await tester.pumpAndSettle();
  } finally {
    await tester.pumpWidget(SizedBox.shrink());
    await tester.pump();
  }
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
    if (element.widget is SliverList ||
        element.widget is ElSliverList ||
        element.widget is SliverGrid ||
        element.widget is ElSliverGrid) {
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
  expect(
    tree.elements.values.whereType<ElImageView>().any((widget) {
      final uri = Uri.tryParse(widget.src ?? '');
      return uri?.scheme == 'http' || uri?.scheme == 'https';
    }),
    isFalse,
    reason: 'ElImageView 同样只能使用本地图片，不能遗漏新的图片入口。',
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
