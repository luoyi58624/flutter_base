import 'package:flutter/widgets.dart';

import 'image_byte_source.dart';
import 'image_source_utils.dart';

/// 无 dart:io 平台（web）的 src 识别：http(s) / asset；file 路径在 web 上
/// 无文件系统可读，退化为按 URL 请求（相对路径由浏览器按站点根解析，
/// 与官方 web 图片处理一致——网络加载交给浏览器管线与其 HTTP 缓存）。
ImageProvider imageProviderForSource(String source, {double scale = 1.0, Map<String, String>? headers}) {
  final assetPath = assetPathForSource(source);
  if (assetPath != null) return AssetImage(assetPath);
  return NetworkImage(source, scale: scale, headers: headers);
}

/// web 的字节源恒为空，所有来源都回退官方 provider 管线。
///
/// asset 也必须走 [AssetImage]，避免 web 上经两段式字节解码后无法出图。
ImageByteSource? byteSourceForSource(String source, {Map<String, String>? headers}) {
  return null;
}
