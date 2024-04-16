part of flutter_base;

/// Flutter应用全局控制器
class FlutterController extends GetxController {
  static FlutterController get of => Get.find();

  /// 应用全局过渡动画时长缩放，默认1倍速
  final timeDilation = 1.0.obs;

  final useMaterial3 = useLocalObs(false, 'useMaterial3');

  @override
  void onInit() {
    super.onInit();
    ever(timeDilation, (value) {
      scheduler.timeDilation = value;
    });
  }
}
