part of flutter_base;

class CryptoUtil {
  CryptoUtil._();

  static final Codec<String, String> _base64Codec = utf8.fuse(base64);

  /// 使用md5加密字符串
  static String md5(String str) {
    return crypto.md5.convert(utf8.encode(str)).toString();
  }

  /// 字符串转base64
  static String toBase64(String str) {
    return _base64Codec.encode(str);
  }

  /// base64转字符串
  static String formBase64(String base64Str) {
    return _base64Codec.decode(base64Str);
  }

  /// 将字符串编码压缩
  static String encodeString(String str) {
    List<int> stringBytes = utf8.encode(str);
    List<int> gzipBytes = GZipEncoder().encode(stringBytes)!;
    return base64UrlEncode(gzipBytes);
  }

  /// 将字符串编码压缩
  static String decodeString(String str) {
    List<int> stringBytes = base64Url.decode(str);
    List<int> gzipBytes = GZipDecoder().decodeBytes(stringBytes);
    return utf8.decode(gzipBytes);
  }
}
