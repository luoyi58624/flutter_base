import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// 图片原始字节来源：两段式解码管线的输入抽象。
///
/// [key] 是缓存/去重的身份键——同 key 恒同字节（网络源含完整 URL，文件源含
/// 路径）。[load] 只负责取回压缩字节，不做任何解码。
abstract class ImageByteSource {
  const ImageByteSource();

  /// 缓存身份键。
  String get key;

  /// 本地文件路径；非文件源返回 null，供平台系统缩略图快速路径识别。
  String? get localPath => null;

  /// 取回原始压缩字节。
  Future<Uint8List> load();

  /// 取回 native 侧压缩字节缓冲。默认经 [load] 中转（Dart heap 拷贝一次）；
  /// **file/asset 源必须 override 为 native 直读**（fromFilePath/fromAsset），
  /// MB 级原片字节零 Dart heap 经手——真机滚动掉帧的头号来源就是每张图
  /// readAsBytes→fromUint8List 的双份拷贝 + 新生代 GC 风暴。
  Future<ui.ImmutableBuffer> loadBuffer() async => ui.ImmutableBuffer.fromUint8List(await load());
}

/// 内存字节源。
class MemoryByteSource extends ImageByteSource {
  MemoryByteSource(this.bytes) : key = 'memory:${identityHashCode(bytes)}:${bytes.length}';

  final Uint8List bytes;

  @override
  final String key;

  @override
  Future<Uint8List> load() async => bytes;
}

/// 包内资源字节源。
class AssetByteSource extends ImageByteSource {
  const AssetByteSource(this.assetPath);

  final String assetPath;

  @override
  String get key => 'asset:$assetPath';

  @override
  Future<Uint8List> load() async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer() => ui.ImmutableBuffer.fromAsset(assetPath);
}
