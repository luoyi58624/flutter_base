import 'dart:async';
import 'dart:ui' as ui;

import 'package:example/src/pages/examples/scroll_examples/album_thumbnails.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class _ImageRequests {
  final started = <int>[];
  final _pending = <int, Completer<ImageInfo>>{};

  AlbumThumbnail thumbnail(int id) => AlbumThumbnail(_ImageProvider(id, this));

  Future<ImageInfo> start(int id) {
    started.add(id);
    final result = Completer<ImageInfo>();
    _pending[id] = result;
    return result.future;
  }

  void finish(int id) {
    final recorder = ui.PictureRecorder();
    final width = id + 1;
    ui.Canvas(recorder).drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), 1), ui.Paint());
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, 1);
    picture.dispose();
    _pending.remove(id)!.complete(ImageInfo(image: image));
  }

  void fail(int id) => _pending.remove(id)!.completeError(StateError('缩略图读取失败'));

  void finishPending() {
    for (final id in _pending.keys.toList()) {
      finish(id);
    }
  }
}

class _ImageProvider extends ImageProvider<(Object, int)> {
  // ignore: prefer_const_constructors_in_immutables
  _ImageProvider(this.id, this.requests);

  final int id;
  final _ImageRequests requests;

  @override
  Future<(Object, int)> obtainKey(ImageConfiguration configuration) => SynchronousFuture((requests, id));

  @override
  ImageStreamCompleter loadImage((Object, int) key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(requests.start(id));
}

void main() {
  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('跳转后释放出的名额交给新视口，旧视口排队项与过期结果都被丢弃', (tester) async {
    final requests = _ImageRequests();
    final queue = AlbumThumbnailQueue();
    final old = List.generate(8, requests.thumbnail);
    final next = List.generate(4, (index) => requests.thumbnail(40 + index));

    queue.update(old, [requests.thumbnail(8)]);
    await tester.pump();
    expect(requests.started, [0, 1, 2, 3]);

    queue.update(next, [requests.thumbnail(44)]);
    await tester.pump();
    expect(requests.started, [0, 1, 2, 3]);
    requests.finish(0);
    await tester.pump();
    expect(requests.started, [0, 1, 2, 3, 40]);
    expect(old.first.value, isNull);
    expect(next.first.value, isNull);

    requests.finish(40);
    await tester.pump();
    expect(requests.started, [0, 1, 2, 3, 40, 41]);
    expect(next.first.value?.image.width, 41);
    expect(old.skip(4).every((thumbnail) => thumbnail.value == null), isTrue);

    queue.dispose();
    requests.finishPending();
    await tester.pump();
    expect(next[1].value, isNull);
    expect(requests.started, [0, 1, 2, 3, 40, 41]);
  });

  testWidgets('仅一个预取可同时执行，重复项合并且新可见项先于下一个预取', (tester) async {
    final requests = _ImageRequests();
    final queue = AlbumThumbnailQueue();
    final first = requests.thumbnail(10);
    final second = requests.thumbnail(11);
    final ahead = requests.thumbnail(12);
    final later = requests.thumbnail(13);
    final next = requests.thumbnail(14);
    final last = requests.thumbnail(15);

    queue.update([first, second], [first, ahead, ahead, later]);
    await tester.pump();
    expect(requests.started, [10, 11, 12]);

    queue.update([first, second, next, last], [ahead, later]);
    await tester.pump();
    expect(requests.started, [10, 11, 12, 14]);
    requests.finish(12);
    await tester.pump();
    expect(requests.started, [10, 11, 12, 14, 15]);
    expect(ahead.value?.image.width, 13);

    requests.finish(14);
    await tester.pump();
    expect(requests.started, [10, 11, 12, 14, 15, 13]);
    queue.dispose();
    requests.finishPending();
    await tester.pump();
  });

  testWidgets('读图失败归还名额，重访成功项直接复用 Flutter 图片缓存', (tester) async {
    final requests = _ImageRequests();
    final queue = AlbumThumbnailQueue();
    final visible = List.generate(5, (index) => requests.thumbnail(20 + index));
    queue.update(visible, []);
    await tester.pump();
    expect(requests.started, [20, 21, 22, 23]);

    requests.fail(20);
    await tester.pump();
    expect(requests.started, [20, 21, 22, 23, 24]);
    expect(visible.first.value, isNull);
    expect(tester.takeException(), isNull);

    requests.finish(21);
    await tester.pump();
    expect(visible[1].value?.image.width, 22);
    queue.update([], []);
    await tester.pump();
    expect(visible[1].value, isNull);

    final revisit = requests.thumbnail(21);
    queue.update([revisit], []);
    await tester.pump();
    expect(revisit.value?.image.width, 22);
    expect(requests.started, [20, 21, 22, 23, 24]);

    queue.dispose();
    requests.finishPending();
    await tester.pump();
  });
}
