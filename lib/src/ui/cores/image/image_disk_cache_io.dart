import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'image_source_utils.dart';

/// 网络图片的磁盘 HTTP 缓存（浏览器语义，dart:io 平台）。
///
/// 每个 URL 两个文件：`<hash>.bin`（响应体）+ `<hash>.meta`（JSON：ETag /
/// Last-Modified / max-age / fetchedAt）。读流程对齐浏览器：
///
/// 1. **新鲜期**（now − fetchedAt < max-age）→ 直读磁盘，零网络；
/// 2. **过期** → 条件请求（If-None-Match / If-Modified-Since）：
///    304 → 续期返回磁盘字节；200 → 覆写缓存返回新字节；
/// 3. **无缓存** → GET → 200 落盘（`Cache-Control: no-store` 不落盘）；
/// 4. **网络失败但有 stale 缓存** → 返回 stale（浏览器离线行为近似）。
///
/// **全部 IO 走异步 API**——MB 级响应体 writeAsBytesSync(flush) 在 UI isolate
/// 同步落盘是真机 30ms 帧尖峰实测根因（thumb cache 同款裁决）。
///
/// 缓存目录在 [Directory.systemTemp]（安卓即应用私有 cache 目录）；超过
/// [maxBytes] 时按修改时间惰性清最旧，会话内累计写入越过阈值会再次调度。
class ImageDiskCache {
  ImageDiskCache._();

  /// 全局单例。
  static final ImageDiskCache instance = ImageDiskCache._();

  /// 磁盘缓存上限。
  static const int maxBytes = 200 << 20;

  Directory? _dirCache;

  Directory get _dir {
    final cached = _dirCache;
    if (cached != null) return cached;
    final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}el_image_cache');
    dir.createSync(recursive: true);
    _dirCache = dir;
    _scheduleTrim();
    return dir;
  }

  static final HttpClient _client = HttpClient();

  /// 经缓存取回 [url] 的字节。
  Future<Uint8List> load(String url, {Map<String, String>? headers}) async {
    final payload = await loadPayload(url, headers: headers);
    final bytes = payload.bytes;
    if (bytes != null) return bytes;
    return File(payload.binPath!).readAsBytes();
  }

  /// 经缓存取回 [url] 的载荷：磁盘命中（新鲜/304/stale）给 [binPath]——调用方
  /// 走 `ImmutableBuffer.fromFilePath` native 直读，MB 级字节零 Dart heap 经手；
  /// 网络新取给 [bytes]（响应体已在 heap，直接用）。两者必有其一。
  Future<({String? binPath, Uint8List? bytes})> loadPayload(String url, {Map<String, String>? headers}) async {
    final hash = fnv1aHex(url);
    final binFile = File('${_dir.path}${Platform.pathSeparator}$hash.bin');
    final metaFile = File('${_dir.path}${Platform.pathSeparator}$hash.meta');

    _CacheMeta? meta;
    try {
      meta = _CacheMeta.fromJson(jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>);
      if (!await binFile.exists()) meta = null; // 孤儿 meta：当无缓存。
    } catch (_) {
      meta = null; // 缺失/损坏的 meta：当无缓存。
    }

    // 1. 新鲜期直读。
    if (meta != null && meta.isFresh(DateTime.now())) {
      return (binPath: binFile.path, bytes: null);
    }

    // 2/3. 条件请求或全新请求。
    try {
      final request = await _client.getUrl(Uri.parse(url));
      headers?.forEach(request.headers.add);
      if (meta != null) {
        final etag = meta.etag;
        final lastModified = meta.lastModified;
        if (etag != null) request.headers.add(HttpHeaders.ifNoneMatchHeader, etag);
        if (lastModified != null) request.headers.add(HttpHeaders.ifModifiedSinceHeader, lastModified);
      }
      final response = await request.close();

      if (response.statusCode == HttpStatus.notModified && meta != null) {
        // 304：续期（fetchedAt 刷新，max-age 可能随 304 头更新）。
        await response.drain<void>();
        await _writeMeta(metaFile, meta.renewed(DateTime.now(), _maxAgeOf(response)));
        return (binPath: binFile.path, bytes: null);
      }

      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();

      final cacheControl = response.headers.value(HttpHeaders.cacheControlHeader) ?? '';
      if (!cacheControl.contains('no-store')) {
        // 原子落盘：写临时文件后 rename（异步——同步 flush 写会占 UI 帧）。
        final tmp = File('${binFile.path}.tmp');
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(binFile.path);
        await _writeMeta(
          metaFile,
          _CacheMeta(
            etag: response.headers.value(HttpHeaders.etagHeader),
            lastModified: response.headers.value(HttpHeaders.lastModifiedHeader),
            fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
            maxAgeSeconds: _maxAgeOf(response),
          ),
        );
        _noteBytesWritten(bytes.length);
      }
      return (binPath: null, bytes: bytes);
    } catch (_) {
      // 4. 网络失败：有 stale 缓存则回退（浏览器离线行为）。
      if (meta != null && await binFile.exists()) return (binPath: binFile.path, bytes: null);
      rethrow;
    }
  }

  Future<void> _writeMeta(File metaFile, _CacheMeta meta) async {
    try {
      await metaFile.writeAsString(jsonEncode(meta.toJson()), flush: true);
    } catch (_) {
      // meta 写失败只损失缓存能力，不阻断图片返回。
    }
  }

  static int? _maxAgeOf(HttpClientResponse response) {
    final cacheControl = response.headers.value(HttpHeaders.cacheControlHeader);
    if (cacheControl == null) return null;
    final match = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  bool _trimScheduled = false;
  int _bytesWrittenSinceTrim = 0;

  /// 会话内累计写入越过该阈值就再调度一次清理——trim 不是每进程一次，长会话
  /// 磁盘占用有界（约 [maxBytes] + 阈值）。
  static const int _retrimThresholdBytes = 32 << 20;

  void _noteBytesWritten(int bytes) {
    _bytesWrittenSinceTrim += bytes;
    if (_bytesWrittenSinceTrim < _retrimThresholdBytes) return;
    _bytesWrittenSinceTrim = 0;
    _trimScheduled = false;
    _scheduleTrim();
  }

  /// 惰性清理：超上限按修改时间删最旧（后台，不阻塞加载）。预收集
  /// (file, mtime, size) 再排序——比较器里逐次 stat 是 O(n log n) 次系统调用。
  void _scheduleTrim() {
    if (_trimScheduled) return;
    _trimScheduled = true;
    Future<void>(() async {
      try {
        final dir = _dirCache;
        if (dir == null) return;
        final entries = <({File file, DateTime at, int size})>[];
        var total = 0;
        await for (final e in dir.list()) {
          if (e is! File) continue;
          final stat = await e.stat();
          entries.add((file: e, at: stat.modified, size: stat.size));
          total += stat.size;
        }
        if (total <= maxBytes) return;
        entries.sort((a, b) => a.at.compareTo(b.at));
        for (final e in entries) {
          if (total <= maxBytes) break;
          try {
            await e.file.delete();
            total -= e.size;
          } catch (_) {}
        }
      } catch (_) {}
    });
  }

  /// 测试钩子：定向/重置缓存目录。
  void debugReset({Directory? dir}) {
    _dirCache = dir;
    _trimScheduled = false;
    _bytesWrittenSinceTrim = 0;
  }
}

class _CacheMeta {
  _CacheMeta({required this.etag, required this.lastModified, required this.fetchedAtMs, required this.maxAgeSeconds});

  factory _CacheMeta.fromJson(Map<String, dynamic> json) {
    return _CacheMeta(
      etag: json['etag'] as String?,
      lastModified: json['lastModified'] as String?,
      fetchedAtMs: json['fetchedAtMs'] as int,
      maxAgeSeconds: json['maxAgeSeconds'] as int?,
    );
  }

  final String? etag;
  final String? lastModified;
  final int fetchedAtMs;
  final int? maxAgeSeconds;

  /// 浏览器新鲜度判定：max-age 内为新鲜；无 max-age 视为立即过期
  /// （走条件请求重验证，有验证器时几乎零成本）。
  bool isFresh(DateTime now) {
    final maxAge = maxAgeSeconds;
    if (maxAge == null) return false;
    return now.millisecondsSinceEpoch - fetchedAtMs < maxAge * 1000;
  }

  _CacheMeta renewed(DateTime now, int? newMaxAge) {
    return _CacheMeta(
      etag: etag,
      lastModified: lastModified,
      fetchedAtMs: now.millisecondsSinceEpoch,
      maxAgeSeconds: newMaxAge ?? maxAgeSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {'etag': etag, 'lastModified': lastModified, 'fetchedAtMs': fetchedAtMs, 'maxAgeSeconds': maxAgeSeconds};
  }
}
