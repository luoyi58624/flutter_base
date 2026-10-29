import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 设备图片能力；其他平台或未注册插件时静默退化。
class ImagePlatformBridge {
  ImagePlatformBridge._();

  static const _channel = MethodChannel('com.el.ui/image');

  /// 查询应用内存等级与物理屏幕尺寸。
  static Future<ImageDeviceProfile?> deviceProfile() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('deviceProfile');
      if (raw == null) return null;
      return ImageDeviceProfile(
        memoryClassMb: raw['memoryClassMb'] as int,
        largeMemoryClassMb: raw['largeMemoryClassMb'] as int,
        lowRam: raw['lowRam'] as bool,
        screenWidthPx: raw['screenWidthPx'] as int,
        screenHeightPx: raw['screenHeightPx'] as int,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// 返回 Android MediaStore 中按修改时间倒序排列的真实图片路径。
  static Future<List<String>> listMediaImages({bool refresh = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return const [];
    try {
      final raw = await _channel.invokeListMethod<String>('listMediaImages', {'refresh': refresh});
      return raw == null ? const [] : List<String>.unmodifiable(raw);
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// 从 MediaStore 请求与当前布局物理尺寸匹配的系统缩略图。
  static Future<ImagePlatformThumbnail?> loadMediaThumbnail({
    required String path,
    required int width,
    required int height,
    required String fit,
    required String engine,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('loadMediaThumbnail', {
        'path': path,
        'width': width,
        'height': height,
        'fit': fit,
        'engine': engine,
      });
      final pixels = raw?['pixels'];
      if (raw == null || pixels is! Uint8List || pixels.isEmpty) return null;
      return ImagePlatformThumbnail(
        pixels: pixels,
        originalWidth: raw['originalWidth'] as int,
        originalHeight: raw['originalHeight'] as int,
        thumbnailWidth: raw['thumbnailWidth'] as int,
        thumbnailHeight: raw['thumbnailHeight'] as int,
        rowBytes: raw['rowBytes'] as int,
        modifiedSeconds: raw['modifiedSeconds'] as int,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Android 应用内存等级与屏幕画像。
@immutable
class ImageDeviceProfile {
  /// 创建设备画像。
  const ImageDeviceProfile({
    required this.memoryClassMb,
    required this.largeMemoryClassMb,
    required this.lowRam,
    required this.screenWidthPx,
    required this.screenHeightPx,
  });

  /// 常规应用 Java heap 等级（MB）。
  final int memoryClassMb;

  /// `largeHeap` 应用等级（MB），仅用于诊断，不据此越权分配。
  final int largeMemoryClassMb;

  /// 是否低内存设备。
  final bool lowRam;

  /// 物理屏幕宽。
  final int screenWidthPx;

  /// 物理屏幕高。
  final int screenHeightPx;
}

/// MediaStore 系统缩略图及其原图元数据。
@immutable
class ImagePlatformThumbnail {
  /// 创建平台缩略图结果。
  const ImagePlatformThumbnail({
    required this.pixels,
    required this.originalWidth,
    required this.originalHeight,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
    required this.rowBytes,
    required this.modifiedSeconds,
  });

  /// Android ARGB_8888 位图复制出的原始 RGBA 像素。
  final Uint8List pixels;

  /// 原图宽。
  final int originalWidth;

  /// 原图高。
  final int originalHeight;

  /// 平台缩略图宽。
  final int thumbnailWidth;

  /// 平台缩略图高。
  final int thumbnailHeight;

  /// 每行像素字节数，包含 Android Bitmap 的 stride。
  final int rowBytes;

  /// MediaStore 修改时间（秒）。
  final int modifiedSeconds;
}
