import 'dart:convert';
import 'dart:typed_data';

const _codecVersionKey = '__el_storage_codec_version__';
const _codecVersion = 1;
const _codecPayloadKey = 'payload';

/// 存储快照编码器，默认不加密，子类可重写 [encode] / [decode] 接入加密算法。
class ElCodec {
  /// 创建存储快照编码器。
  const ElCodec();

  /// 将 JSON 快照字节编码为本地保存的字符串，默认直接按 UTF-8 转成明文。
  String encode(Uint8List bytes) => utf8.decode(bytes);

  /// 将本地保存的字符串还原为 JSON 快照字节，默认直接按 UTF-8 读取明文。
  Uint8List decode(String text) => Uint8List.fromList(utf8.encode(text));
}

/// 存储快照编码失败。
class ElCodecException implements Exception {
  /// 创建编码异常。
  const ElCodecException(this.message, [this.error]);

  /// 错误说明。
  final String message;

  /// 底层 codec 抛出的原始错误。
  final Object? error;

  @override
  String toString() => error == null ? 'ElCodecException: $message' : 'ElCodecException: $message ($error)';
}

bool _useCodec(ElCodec codec) => codec.runtimeType != ElCodec;

/// 将存储快照编码成本地文本。
String encodeStorageSnapshot(String key, Map<String, dynamic> snapshot, ElCodec codec) {
  final json = jsonEncode(snapshot);
  if (!_useCodec(codec)) return json;

  try {
    return jsonEncode({
      _codecVersionKey: _codecVersion,
      _codecPayloadKey: codec.encode(Uint8List.fromList(utf8.encode(json))),
    });
  } catch (error) {
    throw ElCodecException('ElStorage "$key" 编码快照失败', error);
  }
}

/// 将本地文本解码成存储快照。
dynamic decodeStorageSnapshot(String key, String text, ElCodec codec) {
  if (text.trim().isEmpty) return {};

  final json = jsonDecode(text);
  if (!_isCodecSnapshot(json)) return json;

  final source = (json as Map).cast<String, dynamic>();
  final payload = source[_codecPayloadKey];
  if (payload is! String) {
    throw ElCodecException('ElStorage "$key" 的编码快照格式无效');
  }

  try {
    return jsonDecode(utf8.decode(codec.decode(payload)));
  } catch (error) {
    throw ElCodecException('ElStorage "$key" 解码快照失败', error);
  }
}

bool _isCodecSnapshot(dynamic json) {
  return json is Map && json[_codecVersionKey] == _codecVersion && json.containsKey(_codecPayloadKey);
}
