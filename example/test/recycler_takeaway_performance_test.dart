import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:example/src/pages/examples/recycler_view/takeaway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

Set<Element> _elements(Finder root) {
  final result = <Element>{};
  void visit(Element element) {
    result.add(element);
    element.visitChildren(visit);
  }

  visit(root.evaluate().single);
  return result;
}

bool _framework(Element element) => switch (element.widget) {
  ElCard() || Row() || Column() || Wrap() || ListView() || Scrollable() || IconButton() => true,
  _ => false,
};

Map<String, Object> _timings(List<int> samples) {
  final ordered = samples.skip(2).toList()..sort();
  double p(double value) => ordered[(ordered.length * value).ceil() - 1] / 1000;
  return {'p50_ms': p(.5), 'p95_ms': p(.95), 'max_ms': p(1)};
}

class _LayoutWork {
  int microseconds = 0;
}

class _MeasureLayout extends SingleChildRenderObjectWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MeasureLayout({required this.work, required super.child});
  final _LayoutWork work;

  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureLayoutBox(work);
}

class _MeasureLayoutBox extends RenderProxyBox {
  _MeasureLayoutBox(this.work);
  final _LayoutWork work;

  @override
  void performLayout() {
    final clock = Stopwatch()..start();
    super.performLayout();
    work.microseconds += clock.elapsedMicroseconds;
  }
}

// 在真正的 Image.network / ResizeImage 路径返回固定 PNG，排除公网波动。
class _ImageClient extends Fake implements HttpClient {
  _ImageClient(this.bytes);
  final List<int> bytes;
  var requests = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests++;
    return _ImageRequest(bytes);
  }
}

class _ImageRequest extends Fake implements HttpClientRequest {
  _ImageRequest(this.bytes);
  final List<int> bytes;

  @override
  Future<HttpClientResponse> close() async => _ImageResponse(bytes);
}

class _ImageResponse extends Fake implements HttpClientResponse {
  _ImageResponse(this.bytes);
  final List<int> bytes;

  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

Future<_ImageClient> _cachePhotos(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var y = 0; y < 16; y++) {
      for (var x = 0; x < 16; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * 16, y * 16, 16, 16),
          Paint()..color = Color.fromARGB(255, x * 15, y * 15, 120),
        );
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 256);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data!.buffer.asUint8List();
  });
  final client = _ImageClient(bytes!);
  debugNetworkImageHttpClientProvider = () => client;
  addTearDown(() {
    debugNetworkImageHttpClientProvider = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  await tester.runAsync(() async {
    for (var step = 0; step <= 12; step++) {
      for (var slot = -1; slot < 10; slot++) {
        final seed = slot < 0 ? 'shop-${step * 24}' : 'dish-${step * 24}-$slot';
        final sourceSize = slot < 0 ? 160 : 360;
        final source = NetworkImage('https://picsum.photos/seed/takeaway-$seed/$sourceSize/$sourceSize');
        final stream = ResizeImage(source, width: slot < 0 ? 52 : 94).resolve(ImageConfiguration.empty);
        final ready = Completer<void>();
        final listener = ImageStreamListener((image, synchronous) {
          image.dispose();
          ready.complete();
        }, onError: (Object error, StackTrace? stack) => ready.completeError(error, stack));
        stream.addListener(listener);
        await ready.future;
        stream.removeListener(listener);
      }
    }
  });
  return client;
}

void main() {
  for (final cachedImages in [false, true]) {
    testWidgets('真实外卖卡片换绑不重挂菜单与静态框架：${cachedImages ? '图片已解码' : '断网占位'}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final content = ValueNotifier<Widget>(SizedBox());
      final layout = _LayoutWork();
      addTearDown(content.dispose);
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Offstage(child: TickerMode(enabled: false, child: RecyclerTakeawayPage())),
                  ValueListenableBuilder<Widget>(
                    valueListenable: content,
                    builder: (context, child, _) => SingleChildScrollView(
                      child: _MeasureLayout(
                        work: layout,
                        child: SizedBox(width: 390, child: child),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView, skipOffstage: false));
      final adapter = list.getAdapter()!;
      final holder = adapter.createViewHolder(list, 0);
      adapter.bindViewHolder(holder, 0);
      content.value = holder.itemView;
      await tester.pumpAndSettle();
      final images = cachedImages ? await _cachePhotos(tester) : null;
      if (cachedImages) {
        adapter.bindViewHolder(holder, 24);
        await tester.pumpAndSettle();
        adapter.bindViewHolder(holder, 0);
        await tester.pumpAndSettle();
      }
      final requests = images?.requests;
      final root = find.byWidget(holder.itemView);
      final initial = _elements(root);
      var previous = initial;
      var frame = {for (final element in previous.where(_framework)) element: element.widget};
      final samples = <int>[];
      final binds = <int>[];
      final layouts = <int>[];
      var added = 0;
      var removed = 0;
      var frameAdded = 0;
      var frameRemoved = 0;
      var frameUpdates = 0;
      var retainedMenus = 0;
      Object menuState() => tester.state(find.descendant(of: root, matching: find.byType(Scrollable)));
      var menu = menuState();
      final titleFinder = find.descendant(of: root, matching: find.byKey(ValueKey('takeaway-title')));
      final title = tester.renderObject<RenderParagraph>(titleFinder);
      for (var step = 1; step <= 12; step++) {
        layout.microseconds = 0;
        final clock = Stopwatch()..start();
        // 真实不同商家，同菜系且餐品数一致，排除业务结构变化的必要增删。
        adapter.bindViewHolder(holder, step * 24);
        binds.add(clock.elapsedMicroseconds);
        await tester.pump(Duration(milliseconds: 16));
        clock.stop();
        samples.add(clock.elapsedMicroseconds);
        layouts.add(layout.microseconds);
        final next = _elements(root);
        final nextFrame = next.where(_framework).toSet();
        added += next.difference(previous).length;
        removed += previous.difference(next).length;
        frameAdded += nextFrame.difference(frame.keys.toSet()).length;
        frameRemoved += frame.keys.toSet().difference(nextFrame).length;
        frameUpdates += nextFrame
            .where((element) => frame.containsKey(element) && !identical(frame[element], element.widget))
            .length;
        final nextMenu = menuState();
        if (identical(menu, nextMenu)) retainedMenus++;
        menu = nextMenu;
        previous = next;
        frame = {for (final element in nextFrame) element: element.widget};
        expect(holder.getItemId(), step * 24);
        expect(tester.renderObject(titleFinder), same(title));
        expect(title.text.toPlainText(), contains('${step * 24 + 1}店'));
        for (final image in tester.widgetList<Image>(find.descendant(of: root, matching: find.byType(Image)))) {
          final source = (image.image as ResizeImage).imageProvider as NetworkImage;
          expect(
            source.url.contains('takeaway-shop-${step * 24}/') || source.url.contains('takeaway-dish-${step * 24}-'),
            isTrue,
            reason: '性能改善必须真的换文字和图片，不能只更新 holder 的 ID',
          );
        }
        expect(tester.takeException(), isNull);
      }
      final result = {
        'label': const String.fromEnvironment('TAKEAWAY_LABEL', defaultValue: 'current'),
        'environment': 'flutter_test/debug; host pump wall time, not Profile FrameTiming',
        'images': cachedImages ? 'decoded 256x256 PNG, distinct URL/ResizeImage cache keys' : 'HTTP 400 placeholders',
        'binds': 12,
        'warmup_samples_dropped': 2,
        'initial_elements': initial.length,
        'final_elements': previous.length,
        'added_elements': added,
        'removed_elements': removed,
        'added_framework_elements': frameAdded,
        'removed_framework_elements': frameRemoved,
        'updated_framework_widgets': frameUpdates,
        'retained_menu_states': retainedMenus,
        'pump_wall': _timings(samples),
        'bind_wall': _timings(binds),
        'layout_wall': _timings(layouts),
      };
      debugPrint('TAKEAWAY_BIND_WORK ${jsonEncode(result)}');
      if (cachedImages) {
        expect(images!.requests, requests, reason: '计时窗口必须命中已解码缓存');
        final rendered = tester.widgetList<RawImage>(find.descendant(of: root, matching: find.byType(RawImage)));
        expect(
          rendered.where((image) => image.image != null).length,
          find.descendant(of: root, matching: find.byType(Image)).evaluate().length,
        );
      }
      debugNetworkImageHttpClientProvider = null;
      await tester.pumpWidget(SizedBox());
      if (!const bool.fromEnvironment('TAKEAWAY_BASELINE')) {
        expect(added, 0, reason: '相同业务结构换绑不能重新挂载文本、图片或控件');
        expect(removed, 0);
        expect(frameAdded, 0, reason: '文本和图片换绑不能重新挂载卡片、按钮或横向滚动框架');
        expect(frameRemoved, 0);
        expect(frameUpdates, 0, reason: '同尺寸同餐品数量的换绑只需更新数据叶子');
        expect(retainedMenus, 12, reason: '横向菜单必须复用滚动容器，同时正确恢复商家自己的位置');
      }
    });
  }

  testWidgets('实际外卖页面快速纵向滚动工作量', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: RecyclerTakeawayPage()),
      ),
    );
    await tester.pumpAndSettle();
    final root = find.byType(rv.RecyclerView);
    final list = tester.widget<rv.RecyclerView>(root);
    var previous = _elements(root);
    final samples = <int>[];
    var added = 0;
    var removed = 0;
    for (var step = 1; step <= 12; step++) {
      final clock = Stopwatch()..start();
      list.controller!.jumpTo(step * 480.0);
      await tester.pump(Duration(milliseconds: 16));
      clock.stop();
      samples.add(clock.elapsedMicroseconds);
      final next = _elements(root);
      added += next.difference(previous).length;
      removed += previous.difference(next).length;
      previous = next;
      expect(tester.takeException(), isNull);
    }
    debugPrint(
      'TAKEAWAY_FAST_SCROLL ${jsonEncode({'label': const String.fromEnvironment('TAKEAWAY_LABEL', defaultValue: 'current'), 'environment': 'flutter_test/debug; HTTP 400 placeholders; host pump wall time', 'frames': 12, 'pixels_per_frame': 480, 'added_elements': added, 'removed_elements': removed, 'mounted_elements': previous.length, 'mounted_images': find.byType(Image).evaluate().length, 'pump_wall': _timings(samples)})}',
    );
    final smallSamples = <int>[];
    final start = list.controller!.offset;
    var smallAdded = 0;
    var smallRemoved = 0;
    for (var step = 1; step <= 12; step++) {
      final clock = Stopwatch()..start();
      list.controller!.jumpTo(start + step);
      await tester.pump(Duration(milliseconds: 16));
      clock.stop();
      smallSamples.add(clock.elapsedMicroseconds);
      final next = _elements(root);
      smallAdded += next.difference(previous).length;
      smallRemoved += previous.difference(next).length;
      previous = next;
      expect(tester.takeException(), isNull);
    }
    debugPrint(
      'TAKEAWAY_SMALL_SCROLL ${jsonEncode({'label': const String.fromEnvironment('TAKEAWAY_LABEL', defaultValue: 'current'), 'environment': 'flutter_test/debug; host pump wall time', 'frames': 12, 'pixels_per_frame': 1, 'added_elements': smallAdded, 'removed_elements': smallRemoved, 'pump_wall': _timings(smallSamples)})}',
    );
    await tester.pumpWidget(SizedBox());
  });
}
