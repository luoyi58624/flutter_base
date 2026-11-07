import 'dart:async';

import 'package:example/src/widgets/example_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _DeferredImage extends ImageProvider<_DeferredImage> {
  final frame = Completer<ImageInfo>();

  @override
  Future<_DeferredImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_DeferredImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(frame.future);
}

void main() {
  testWidgets('图片解码后原位淡入，回到已缓存图片时直接显示', (tester) async {
    final provider = _DeferredImage();
    addTearDown(provider.evict);

    Widget page() => MaterialApp(
      home: Center(
        child: Image(image: provider, width: 64, height: 48, frameBuilder: exampleImageFrame),
      ),
    );

    final image = find.byType(Image);
    final paintedImage = find.descendant(of: image, matching: find.byType(RawImage));
    final fade = find.descendant(of: image, matching: find.byType(Opacity));
    await tester.pumpWidget(page());
    expect(tester.getSize(image), Size(64, 48));
    expect(tester.widget<RawImage>(paintedImage).image, isNull);
    expect(fade, findsNothing);

    final pixels = await tester.runAsync(() => createTestImage(width: 8, height: 6, cache: false));
    provider.frame.complete(ImageInfo(image: pixels!));
    await tester.pump();
    expect(tester.widget<RawImage>(paintedImage).image, isNotNull);
    expect(tester.widget<Opacity>(fade).opacity, 0);
    await tester.pump(exampleImageFadeDuration * .5);
    expect(tester.widget<Opacity>(fade).opacity, allOf(greaterThan(0), lessThan(1)));
    expect(tester.getSize(image), Size(64, 48));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(fade).opacity, 1);

    await tester.pumpWidget(SizedBox.shrink());
    await tester.pumpWidget(page());
    expect(tester.widget<RawImage>(paintedImage).image, isNotNull);
    expect(fade, findsNothing);
  });
}
