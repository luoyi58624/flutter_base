import 'dart:io' show File, Platform;

import 'package:flutter/widgets.dart';

import 'image_byte_source.dart';
import 'image_byte_source_io.dart';
import 'image_source_utils.dart';

/// dart:io 平台的 src 三协议识别：http(s) / asset / file。
///
/// 识别规则（按序）：
/// 1. `http://` `https://` → [NetworkImage]；
/// 2. `asset://xxx` 或 `assets/` 前缀 → [AssetImage]（`asset://` 前缀剥掉后
///    即 pubspec 声明的资源路径）；
/// 3. `file://` URI → 按平台转文件路径；
/// 4. 其余一律当本地文件路径（含 Windows 盘符 `D:\...`——注意 Uri.tryParse
///    会把单字母盘符解析成 scheme，不能按 scheme 直判）。
ImageProvider imageProviderForSource(String source, {double scale = 1.0, Map<String, String>? headers}) {
  final uri = Uri.tryParse(source);
  final scheme = uri?.scheme ?? '';
  if (scheme == 'http' || scheme == 'https') {
    return NetworkImage(source, scale: scale, headers: headers);
  }
  final assetPath = assetPathForSource(source);
  if (assetPath != null) return AssetImage(assetPath);
  if (scheme == 'file' && uri != null) {
    return FileImage(File(uri.toFilePath(windows: Platform.isWindows)), scale: scale);
  }
  return FileImage(File(source), scale: scale);
}

/// io 平台的字节源解析：两段式解码管线（P3）的输入。与
/// [imageProviderForSource] 同一套识别规则。
ImageByteSource? byteSourceForSource(String source, {Map<String, String>? headers}) {
  final uri = Uri.tryParse(source);
  final scheme = uri?.scheme ?? '';
  if (scheme == 'http' || scheme == 'https') return NetworkByteSource(source, headers: headers);
  final assetPath = assetPathForSource(source);
  if (assetPath != null) return AssetByteSource(assetPath);
  if (scheme == 'file' && uri != null) {
    return FileByteSource(uri.toFilePath(windows: Platform.isWindows));
  }
  return FileByteSource(source);
}
