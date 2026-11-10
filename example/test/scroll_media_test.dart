import 'dart:io';
import 'dart:ui' as ui;

import 'package:example/src/pages/examples/index.dart';
import 'package:example/src/pages/examples/scroll_examples/media.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:example/src/widgets/panel.dart';

class _Files {
  _Files(this.directory);
  final Directory directory;
  final files = <File>[];
  Directory? nested;

  static Future<_Files> create(WidgetTester tester) async {
    final result = await tester.runAsync(() async {
      final fixture = _Files(await Directory.systemTemp.createTemp('flutter-media-grid-'));
      for (final data in [('竖图 中文', 32, 64), ('横图 空格', 64, 32), ('方图', 40, 40)]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, data.$2.toDouble(), data.$3.toDouble()), Paint()..color = Colors.blue);
        final picture = recorder.endRecording();
        final image = await picture.toImage(data.$2, data.$3);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(path.join(fixture.directory.path, '${data.$1}.png'));
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        fixture.files.add(file);
        image.dispose();
        picture.dispose();
      }
      for (final name in ['本机 视频.mp4', '忽略.txt']) {
        final file = File(path.join(fixture.directory.path, name));
        await file.writeAsBytes([0, 1, 2, 3]);
        fixture.files.add(file);
      }
      final nested = fixture.nested = await Directory(path.join(fixture.directory.path, '子目录')).create();
      final hidden = File(path.join(nested.path, '子目录影像.png'));
      await hidden.writeAsBytes(await fixture.files.first.readAsBytes());
      fixture.files.add(hidden);
      return fixture;
    });
    addTearDown(() async {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await tester.runAsync(() async {
        for (final file in result!.files) {
          if (await file.exists()) await file.delete();
        }
        await result.nested?.delete();
        await result.directory.delete();
      });
    });
    return result!;
  }
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: 10)));
    await tester.pump();
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('本机媒体读取未在有界等待内完成');
}

Future<void> _open(WidgetTester tester, Widget page, {double width = 390, double scale = 1, bool dark = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: dark ? .dark : .light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ElComponentProvider(components: el.mobileComponents, child: page),
    ),
  );
  await _wait(tester, () => find.byKey(ValueKey('media-card')).evaluate().isNotEmpty);
  expect(tester.takeException(), isNull);
}

Finder _photo(String title) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == '照片：$title');
Finder _video(String title) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == '视频：$title');

Future<void> _mode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(ValueKey('media-scroll-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('media-mode-$mode')));
  await tester.pumpAndSettle();
}

ScrollController _controller(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

void main() {
  test('视频 Grid、相册 Grid、瀑布流追加为三个独立入口', () {
    expect(scrollBusinessExamples.skip(6).take(3).map((entry) => entry.key), [
      'recycler-video-grid',
      'recycler-gallery-grid',
      'recycler-waterfall',
    ]);
  });

  testWidgets('目录一次提供全部媒体，超过 64 项仍可直接跳到末尾且不触发分页加载', (tester) async {
    final files = await _Files.create(tester);
    await tester.runAsync(() async {
      final bytes = await files.files.first.readAsBytes();
      for (var index = 0; index < 128; index++) {
        final file = File(path.join(files.nested!.path, '批量 ${index.toString().padLeft(4, '0')}.png'));
        await file.writeAsBytes(bytes);
        files.files.add(file);
      }
    });
    await _open(tester, RecyclerGalleryPage(directory: files.directory.path));
    final list = tester.widget<ElSliverRecyclerGrid>(find.byType(ElSliverRecyclerGrid));
    expect(list.itemCount, 133);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final maximum = _controller(tester).position.maxScrollExtent;
    _controller(tester).jumpTo(maximum);
    await tester.pumpAndSettle();
    expect(_controller(tester).offset, closeTo(_controller(tester).position.maxScrollExtent, .01));
    expect(_controller(tester).position.extentAfter, closeTo(0, .01));
    await _wait(tester, () => find.byType(RawImage).hitTestable().evaluate().isNotEmpty);
    _controller(tester).jumpTo(0);
    await tester.pumpAndSettle();
    expect(_controller(tester).offset, 0);
    expect(list.itemCount, 133);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('本机瀑布流直接按已解码缩略图比例排版，不预读全目录原图尺寸', (tester) async {
    final files = await _Files.create(tester);
    await _open(tester, RecyclerWaterfallPage(directory: files.directory.path));
    await _wait(tester, () {
      final images = tester.widgetList<RawImage>(find.byType(RawImage));
      return images.length >= 4 && images.every((image) => image.image != null);
    });
    Rect card(String title) =>
        tester.getRect(find.descendant(of: _photo(title), matching: find.byKey(ValueKey('media-card'))));
    final portrait = card('竖图 中文');
    final landscape = card('横图 空格');
    expect(portrait.width, closeTo(landscape.width, .01));
    expect(portrait.height, greaterThan(landscape.height + 100));
    final list = tester.widget<ElSliverRecyclerGrid>(find.byType(ElSliverRecyclerGrid));
    expect(list.itemCount, 4);
    expect(find.byKey(ValueKey('media-scroll-menu')), findsOneWidget);
    await tester.tap(_photo('横图 空格').hitTestable().first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(ValueKey('media-details')), findsOneWidget);
    expect(find.byType(ElCard), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ElSliverRecyclerGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('本机视频流递归读取子目录图片，跨列头图与双列卡片可 Hero 跳转', (tester) async {
    final files = await _Files.create(tester);
    await _open(tester, RecyclerVideoGridPage(directory: files.directory.path));
    final list = tester.widget<ElSliverRecyclerGrid>(find.byType(ElSliverRecyclerGrid));
    expect(list.itemCount, 4, reason: '网格只包含四张图片，整宽横幅独立于网格索引');
    expect(_photo('子目录影像'), findsWidgets);
    final header = tester.getRect(find.byKey(ValueKey('media-featured')));
    final card = tester.getRect(find.byKey(ValueKey('media-card')).first);
    expect(header.width, greaterThan(card.width * 1.9));
    expect(find.byType(Hero), findsWidgets);
    final photo = _photo('竖图 中文').hitTestable().first;
    await tester.tap(photo);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(ValueKey('media-details')), findsOneWidget);
    expect(find.byType(Hero), findsWidgets);
    expect(find.byWidgetPredicate((widget) => widget is ElView && widget.child == '从细节看见故事'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ElSliverRecyclerGrid), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('视频流的卡片来源与两种网格容器可以独立切换', (tester) async {
    final files = await _Files.create(tester);
    await _open(tester, RecyclerVideoGridPage(directory: files.directory.path));

    final context = tester.element(find.byType(RecyclerVideoGridPage));
    await tester.runAsync(() => precacheImage(AssetImage('assets/recycler_cards/bili_home.webp'), context));
    await tester.pumpAndSettle();
    await _mode(tester, 'official');
    expect(find.byKey(ValueKey('media-official-grid')), findsOneWidget);
    await _mode(tester, 'bibiCards');

    final firstTitle = '职业选手的极限反打，第一视角复盘';
    for (final (mode, key) in [('official', 'media-bibi-official'), ('recycler', 'media-bibi-recycler')]) {
      if (mode != 'official') await _mode(tester, mode);
      final host = find.byKey(ValueKey(key));
      final scroll = tester.widget(host);
      final controller = switch (scroll) {
        CustomScrollView(:final controller) => controller!,
        _ => throw StateError('未知网格容器 $key'),
      };
      final first = find.descendant(of: host, matching: find.text(firstTitle)).hitTestable();
      final second = find.descendant(of: host, matching: find.text('你是否也记得，夏天结束前的那场风')).hitTestable();
      expect(tester.getTopLeft(first).dy, closeTo(tester.getTopLeft(second).dy, .01));
      expect(tester.getTopLeft(second).dx, greaterThan(tester.getTopLeft(first).dx));
      expect(find.byKey(ValueKey('media-card')), findsNothing);
      final boundaries = find.descendant(
        of: host,
        matching: find.byElementPredicate(
          (element) => element is RenderObjectElement && element.renderObject is RenderRepaintBoundary,
        ),
      );
      final firstCard = find.ancestor(of: first, matching: find.byType(ExamplePanel));
      final secondCard = find.ancestor(of: second, matching: find.byType(ExamplePanel));
      final firstBoundary = find.ancestor(of: firstCard, matching: boundaries);
      final secondBoundary = find.ancestor(of: secondCard, matching: boundaries);
      expect(firstBoundary, findsOneWidget, reason: '$mode 每卡只需一层重绘边界');
      expect(secondBoundary, findsOneWidget);
      expect(tester.element(firstBoundary), isNot(same(tester.element(secondBoundary))));

      if (mode == 'official') {
        final cardRender = tester.renderObject<ElRenderView>(firstCard);
        final press = await tester.startGesture(tester.getCenter(first));
        await tester.pump();
        await tester.pump(Duration(milliseconds: 120));
        expect(cardRender.committedResolvedStyle.box.transform, ElTransform.scale(.98));
        expect(find.byType(AlertDialog), findsNothing);
        await press.up();
        await tester.pumpAndSettle();
        expect(cardRender.committedResolvedStyle.box.transform, isNull);
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(firstTitle)), findsOneWidget);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();

        await tester.tap(find.descendant(of: firstCard, matching: find.byType(ElButtonView)));
        await tester.pumpAndSettle();
        final details = find.byWidgetPredicate((widget) => widget is ElView && widget.child == '视频详情');
        expect(details, findsOneWidget);
        expect(find.byWidgetPredicate((widget) => widget is ElView && widget.child == '复制标题'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.tap(details);
        await tester.pumpAndSettle();
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(firstTitle)), findsOneWidget);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
      }

      final before = controller.offset;
      await tester.drag(host, Offset(0, -420));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(before + 250));
      if (scroll is ElScrollView) {
        expect(tester.widget(host), same(scroll), reason: '滚动中新挂载卡片不应触发重新测高和重建容器');
      }
      expect(first, findsNothing);
      controller.jumpTo(before);
      await tester.pumpAndSettle();
      expect(first, findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await _mode(tester, 'localCards');
    expect(find.byKey(ValueKey('media-card')), findsWidgets);
    expect(find.byKey(ValueKey('media-recycler-feed')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('相册显示图片和视频，分别进入缩放预览与正确的本地视频 URI', (tester) async {
    final files = await _Files.create(tester);
    Uri? played;
    await _open(
      tester,
      RecyclerGalleryPage(
        directory: files.directory.path,
        videoPlayerBuilder: (_, uri) {
          played = uri;
          return Center(child: Text('播放本地视频'));
        },
      ),
    );
    final list = tester.widget<ElSliverRecyclerGrid>(find.byType(ElSliverRecyclerGrid));
    expect(list.itemCount, 5);
    expect(list.crossAxisCount, 5);
    expect(_video('本机 视频'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(
      tester
          .widgetList<ElCard>(find.byKey(ValueKey('media-card')))
          .every((card) => card.style?.backgroundColor == null),
      isTrue,
    );
    await tester.tap(_photo('横图 空格'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('media-photo-preview')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final previewHero = find.descendant(of: find.byKey(ValueKey('media-photo-preview')), matching: find.byType(Hero));
    expect(tester.getSize(previewHero).width, 390);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(_video('本机 视频'));
    await _wait(tester, () => find.text('播放本地视频').evaluate().isNotEmpty);
    expect(find.byKey(ValueKey('media-video-preview')), findsOneWidget);
    expect(played!.scheme, 'file');
    expect(path.basename(path.fromUri(played!)), '本机 视频.mp4');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_photo('竖图 中文'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  for (final album in [false, true]) {
    testWidgets('${album ? '相册' : '视频流'}保留两种真实网格容器与相同内容', (tester) async {
      final files = await _Files.create(tester);
      await _open(
        tester,
        album
            ? RecyclerGalleryPage(directory: files.directory.path)
            : RecyclerVideoGridPage(directory: files.directory.path),
      );
      Future<void> checkAlbumCover() async {
        if (!album) return;
        final image = find.descendant(of: _photo('竖图 中文'), matching: find.byType(RawImage));
        await _wait(tester, () => tester.widgetList<RawImage>(image).any((raw) => raw.image?.width == 32));
      }

      await checkAlbumCover();
      await _mode(tester, 'official');
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(ElSliverRecyclerGrid), findsNothing);
      expect(_photo('竖图 中文'), findsWidgets);
      await checkAlbumCover();
      await _mode(tester, 'recycler');
      expect(find.byType(ElSliverRecyclerGrid), findsOneWidget);
      await checkAlbumCover();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(SizedBox());
    });
  }

  testWidgets('瀑布流万条数据按需挂载，远跳后回收复用且可以切换官方布局', (tester) async {
    await _open(tester, RecyclerWaterfallPage());
    final list = tester.widget<ElSliverRecyclerGrid>(find.byType(ElSliverRecyclerGrid));
    expect(list.itemCount, 10000);
    expect(find.byKey(ValueKey('media-scroll-menu')), findsOneWidget);
    expect(find.byKey(ValueKey('media-card')).evaluate().length, lessThan(40));
    final cards = tester.getRect(find.byKey(ValueKey('media-card')).first);
    final second = tester.getRect(find.byKey(ValueKey('media-card')).at(1));
    expect(cards.height, isNot(closeTo(second.height, 1)));
    _controller(tester).jumpTo(_controller(tester).position.maxScrollExtent * .8);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('media-card')).hitTestable(), findsWidgets);
    expect(find.byKey(ValueKey('media-card')).evaluate().length, lessThan(40));
    expect(find.byType(Hero).evaluate().length, lessThan(20));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });

  testWidgets('窄屏大字视频卡片与宽屏暗色相册都能正确布局', (tester) async {
    final files = await _Files.create(tester);
    await _open(tester, RecyclerVideoGridPage(directory: files.directory.path), width: 320, scale: 1.6);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
    await _open(tester, RecyclerGalleryPage(directory: files.directory.path), width: 1280, dark: true);
    final grid = tester.widget<ElSliverRecyclerGrid>(find.byType(ElSliverRecyclerGrid));
    expect(grid.crossAxisCount, greaterThan(5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
