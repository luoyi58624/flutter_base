part of flutter_base;

class GetxUtil {
  /// Getx工具类
  GetxUtil._();

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
