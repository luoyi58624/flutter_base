import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 按布局框自适应解码尺寸的 provider 包装，等价于官方 [ResizeImage] 的 cacheWidth/cacheHeight，
/// 但目标尺寸在拿到原图宽高后才按 [BoxFit] 推导，因此 cover 能正确保证覆盖而不被降采样压糊。
///
/// 只改变解码目标，缓存、重试与多帧都交给被包装的官方 provider 和 [ImageCache]。
@immutable
class SizedImage extends ImageProvider<SizedImageKey> {
  /// [boxWidth]/[boxHeight] 为物理像素上限，0 表示该轴不限制。
  const SizedImage(this.base, {required this.boxWidth, required this.boxHeight, required this.fit});

  /// 被包装的官方 provider。
  final ImageProvider base;

  /// 物理像素宽上限，0 = 不限。
  final int boxWidth;

  /// 物理像素高上限，0 = 不限。
  final int boxHeight;

  /// 决定缩放基准的填充方式。
  final BoxFit fit;

  /// 解码尺寸分桶粒度（物理像素）。布局微调落在同一桶内时复用同一份缓存位图。
  static const int bucket = 32;

  static final Expando<Size> _intrinsicSizes = Expando<Size>('SizedImage.intrinsic');

  /// 取该 completer 对应图片的原始像素尺寸；不是经 [SizedImage] 解码的（原尺寸路径）返回 null。
  static Size? intrinsicOf(ImageStreamCompleter completer) => _intrinsicSizes[completer];

  /// 把逻辑尺寸换算成分桶后的物理像素；无限或非正数返回 0。
  static int bucketOf(double logical, double devicePixelRatio) {
    if (!logical.isFinite || logical <= 0) return 0;
    return (logical * devicePixelRatio / bucket).ceil() * bucket;
  }

  /// 按 [fit] 与布局框推导解码目标；不需要缩小时返回原尺寸。
  @visibleForTesting
  ui.TargetImageSize targetFor(int intrinsicWidth, int intrinsicHeight) {
    final w = boxWidth > 0 ? boxWidth : null;
    final h = boxHeight > 0 ? boxHeight : null;
    if (w == null && h == null || fit == BoxFit.none) return const ui.TargetImageSize();
    final sx = w == null ? null : w / intrinsicWidth;
    final sy = h == null ? null : h / intrinsicHeight;
    if (fit == BoxFit.fill && sx != null && sy != null) {
      return ui.TargetImageSize(width: w! < intrinsicWidth ? w : null, height: h! < intrinsicHeight ? h : null);
    }
    // 单轴受限时只由该轴决定；双轴受限时 cover 取大比例（保证铺满），其余取小比例（保证放得下）。
    final scale = switch ((sx, sy)) {
      (final double x, null) => x,
      (null, final double y) => y,
      (final double x, final double y) => switch (fit) {
        BoxFit.cover => x > y ? x : y,
        BoxFit.fitWidth => x,
        BoxFit.fitHeight => y,
        _ => x < y ? x : y,
      },
      _ => 1.0,
    };
    if (scale >= 1) return const ui.TargetImageSize();
    final targetWidth = (intrinsicWidth * scale).round();
    final targetHeight = (intrinsicHeight * scale).round();
    return ui.TargetImageSize(width: targetWidth < 1 ? 1 : targetWidth, height: targetHeight < 1 ? 1 : targetHeight);
  }

  @override
  Future<SizedImageKey> obtainKey(ImageConfiguration configuration) {
    Completer<SizedImageKey>? completer;
    SynchronousFuture<SizedImageKey>? sync;
    base.obtainKey(configuration).then((Object baseKey) {
      final key = SizedImageKey(baseKey, boxWidth, boxHeight, fit);
      if (completer == null) {
        sync = SynchronousFuture(key);
      } else {
        completer.complete(key);
      }
    });
    if (sync != null) return sync!;
    return (completer = Completer<SizedImageKey>()).future;
  }

  @override
  ImageStreamCompleter loadImage(SizedImageKey key, ImageDecoderCallback decode) {
    late final ImageStreamCompleter completer;
    completer = base.loadImage(
      key.base,
      (buffer, {ui.TargetImageSizeCallback? getTargetSize}) => decode(
        buffer,
        getTargetSize: (intrinsicWidth, intrinsicHeight) {
          // 解码后位图已被缩小，原图尺寸在这里记下，供 onLoad 上报。
          _intrinsicSizes[completer] = Size(intrinsicWidth.toDouble(), intrinsicHeight.toDouble());
          return targetFor(intrinsicWidth, intrinsicHeight);
        },
      ),
    );
    // 与官方 ResizeImage 一致：失败的 key 不能留在缓存里，否则同尺寸永远拿到错误。
    completer.addEphemeralErrorListener((_, _) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }
}

/// [SizedImage] 的缓存身份：被包装 provider 的 key 加上解码框与 fit。
@immutable
class SizedImageKey {
  const SizedImageKey(this.base, this.width, this.height, this.fit);

  final Object base;
  final int width;
  final int height;
  final BoxFit fit;

  @override
  bool operator ==(Object other) =>
      other is SizedImageKey &&
      other.base == base &&
      other.width == width &&
      other.height == height &&
      other.fit == fit;

  @override
  int get hashCode => Object.hash(base, width, height, fit);
}
