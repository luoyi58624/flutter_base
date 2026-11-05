import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_byte_source.dart';
import 'image_disk_cache_io.dart';

/// 本地文件字节源（dart:io）。
class FileByteSource extends ImageByteSource {
  const FileByteSource(this.path);

  final String path;

  @override
  String get key => 'file:$path';

  @override
  String get localPath => path;

  @override
  Future<Uint8List> load() => File(path).readAsBytes();

  @override
  Future<ui.ImmutableBuffer> loadBuffer() => ui.ImmutableBuffer.fromFilePath(path);
}

/// 网络字节源：经 [ImageDiskCache] 走浏览器语义多级缓存
/// （内存位图缓存在解码管线，此处是磁盘 HTTP 层）。
class NetworkByteSource extends ImageByteSource {
  const NetworkByteSource(this.url, {this.headers});

  final String url;
  final Map<String, String>? headers;

  @override
  String get key => 'net:$url';

  @override
  Future<Uint8List> load() => ImageDiskCache.instance.load(url, headers: headers);

  @override
  Future<ui.ImmutableBuffer> loadBuffer() async {
    final payload = await ImageDiskCache.instance.loadPayload(url, headers: headers);
    final binPath = payload.binPath;
    // 磁盘命中（列表暖缓存的主流路径）：`.bin` 就是本地文件，native 直读——
    // MB 级原片字节零 Dart heap 经手，免掉 readAsBytes→fromUint8List 双拷贝。
    if (binPath != null) return ui.ImmutableBuffer.fromFilePath(binPath);
    return ui.ImmutableBuffer.fromUint8List(payload.bytes!);
  }
}
