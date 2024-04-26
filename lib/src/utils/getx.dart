part of flutter_base;

class GetxUtil {
  /// Getx工具类
  GetxUtil._();

  /// 获取控制器，但是如果没有注入，则得到null
  static T? find<T>({String? tag}) {
    if (hasController<T>(tag: tag)) {
      return Get.find<T>(tag: tag);
    } else {
      return null;
    }
  }

  /// 检查是否存在控制器
  static bool hasController<T>({String? tag}) {
    try {
      Get.find<T>(tag: tag);
      return true;
    } catch (error) {
      return false;
    }
  }
}
