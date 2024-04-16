part of flutter_base;

/// IconData序列化
class IconSerializable {
  IconSerializable._();

  static IconData? fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return null;
    } else {
      assert(json['codePoint'] != null,
          'IconData解析失败，传递的json对象没有包含codePoint，你确定是使用IconDataSerializable.toJson()获得的json对象？');
      return IconData(
        int.parse(json['codePoint']!),
        fontFamily: json['fontFamily'],
        fontPackage: json['fontPackage'],
        matchTextDirection: json['matchTextDirection'] == 'true',
      );
    }
  }

  static Map<String, dynamic> toJson(IconData? iconData) {
    if (iconData == null) {
      return {};
    } else {
      return {
        'codePoint': '${iconData.codePoint}',
        'fontFamily': iconData.fontFamily,
        'fontPackage': iconData.fontPackage,
        'matchTextDirection': '${iconData.matchTextDirection}',
      };
    }
  }
}
