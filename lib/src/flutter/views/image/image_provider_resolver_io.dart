import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'image_disk_cache_io.dart';
import 'image_source_utils.dart';

/// dart:io 平台的 src 三协议识别：http(s) / asset / file。
///
/// 识别规则（按序）：
/// 1. `http://` `https://` → 带磁盘缓存的网络图；
/// 2. `asset://xxx` 或 `assets/` 前缀 → [AssetImage]（`asset://` 前缀剥掉后即 pubspec 声明的资源路径）；
/// 3. `file://` URI → 按平台转文件路径；
/// 4. 其余一律当本地文件路径（含 Windows 盘符 `D:\...`——`Uri.tryParse` 会把单字母盘符解析成 scheme，不能按 scheme 直判）。
ImageProvider imageProviderForSource(String source, {double scale = 1.0, Map<String, String>? headers}) {
  final uri = Uri.tryParse(source);
  final scheme = uri?.scheme ?? '';
  if (scheme == 'http' || scheme == 'https') return _CachedNetworkImage(source, scale: scale, headers: headers);
  final assetPath = assetPathForSource(source);
  if (assetPath != null) return AssetImage(assetPath);
  if (scheme == 'file' && uri != null) {
    return FileImage(File(uri.toFilePath(windows: Platform.isWindows)), scale: scale);
  }
  return FileImage(File(source), scale: scale);
}

/// 清空网络图片磁盘缓存。
Future<void> clearDiskCache() => ImageDiskCache.instance.clear();

/// 与官方 [NetworkImage] 同构，只是字节来自 [ImageDiskCache]；身份只由 url 与 scale 决定。
@immutable
class _CachedNetworkImage extends ImageProvider<_CachedNetworkImage> {
  const _CachedNetworkImage(this.url, {this.scale = 1.0, this.headers});

  final String url;
  final double scale;
  final Map<String, String>? headers;

  @override
  Future<_CachedNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_CachedNetworkImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => [DiagnosticsProperty<ImageProvider>('Image provider', this)],
    );
  }

  Future<ui.Codec> _load(_CachedNetworkImage key, ImageDecoderCallback decode) async {
    try {
      return await decode(await ImageDiskCache.instance.load(key.url, headers: key.headers));
    } catch (_) {
      // 失败的 key 不留在内存缓存里，下次重新请求。
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) => other is _CachedNetworkImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);
}
