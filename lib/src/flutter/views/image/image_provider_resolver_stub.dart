import 'package:flutter/widgets.dart';

import 'image_source_utils.dart';

/// 无 dart:io 平台（web）的 src 识别：http(s) / asset；file 路径在 web 上无文件系统可读，
/// 退化为按 URL 请求（相对路径由浏览器按站点根解析，网络缓存交给浏览器自己的 HTTP 缓存）。
ImageProvider imageProviderForSource(String source, {double scale = 1.0, Map<String, String>? headers}) {
  final assetPath = assetPathForSource(source);
  if (assetPath != null) return AssetImage(assetPath);
  return NetworkImage(source, scale: scale, headers: headers);
}

/// web 没有应用层磁盘缓存。
Future<void> clearDiskCache() async {}
