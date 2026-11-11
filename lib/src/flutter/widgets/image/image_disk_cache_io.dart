import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'image_source_utils.dart';

/// 网络图片的磁盘缓存（dart:io 平台）：每个 URL 一个文件，按修改时间判断是否过期。
///
/// 命中直接 native 读文件，字节不经过 Dart 堆；同 URL 的并发请求共用一次下载；
/// 过期后重新下载，下载失败时回退到过期文件。位图缓存由官方 [ImageCache] 负责，这里只管字节。
class ImageDiskCache {
  ImageDiskCache._();

  /// 全局单例。
  static final ImageDiskCache instance = ImageDiskCache._();

  /// 磁盘缓存上限，超出后按修改时间清理最旧文件。
  static const int maxBytes = 200 << 20;

  /// 缓存有效期。
  static const Duration ttl = Duration(days: 7);

  static final HttpClient _client = HttpClient();

  Directory? _dirCache;
  int _writtenSinceTrim = 0;
  final Map<String, Future<Uint8List>> _inFlight = {};

  Directory get _dir {
    return _dirCache ??= Directory('${Directory.systemTemp.path}${Platform.pathSeparator}el_image_cache')
      ..createSync(recursive: true);
  }

  /// 取回 [url] 的压缩字节缓冲。
  Future<ui.ImmutableBuffer> load(String url, {Map<String, String>? headers}) async {
    final file = File('${_dir.path}${Platform.pathSeparator}${fnv1aHex(url)}.bin');
    DateTime? modified;
    try {
      modified = await file.lastModified();
    } on FileSystemException {
      modified = null;
    }
    if (modified != null && DateTime.now().difference(modified) < ttl) {
      return ui.ImmutableBuffer.fromFilePath(file.path);
    }
    try {
      final bytes = await (_inFlight[url] ??= _download(url, headers, file).whenComplete(() {
        // 块体：表达式体会把被移除的 future 自己返回，whenComplete 就会等待自身而死锁。
        _inFlight.remove(url);
      }));
      return await ui.ImmutableBuffer.fromUint8List(bytes);
    } catch (_) {
      if (modified != null) return ui.ImmutableBuffer.fromFilePath(file.path);
      rethrow;
    }
  }

  Future<Uint8List> _download(String url, Map<String, String>? headers, File file) async {
    final request = await _client.getUrl(Uri.parse(url));
    headers?.forEach(request.headers.add);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    if (!(response.headers.value(HttpHeaders.cacheControlHeader) ?? '').contains('no-store')) {
      _write(file, bytes);
    }
    return bytes;
  }

  /// 异步原子落盘（先写临时文件再 rename）；写失败只损失缓存，不影响图片显示。
  Future<void> _write(File file, Uint8List bytes) async {
    try {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes);
      await tmp.rename(file.path);
      _writtenSinceTrim += bytes.length;
      if (_writtenSinceTrim >= maxBytes ~/ 4) {
        _writtenSinceTrim = 0;
        await _trim();
      }
    } catch (_) {}
  }

  /// 超出 [maxBytes] 时按修改时间删除最旧文件。
  Future<void> _trim() async {
    final entries = <({File file, DateTime at, int size})>[];
    var total = 0;
    await for (final entity in _dir.list()) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      entries.add((file: entity, at: stat.modified, size: stat.size));
      total += stat.size;
    }
    entries.sort((a, b) => a.at.compareTo(b.at));
    for (final e in entries) {
      if (total <= maxBytes) break;
      try {
        await e.file.delete();
        total -= e.size;
      } catch (_) {}
    }
  }

  /// 清空磁盘缓存。
  Future<void> clear() async {
    try {
      await for (final entity in _dir.list()) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {}
  }

  /// 测试钩子：改用指定缓存目录。
  @visibleForTesting
  void debugReset({Directory? dir}) {
    _dirCache = dir;
    _writtenSinceTrim = 0;
    _inFlight.clear();
  }
}
