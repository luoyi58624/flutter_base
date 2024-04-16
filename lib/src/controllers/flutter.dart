part of flutter_base;

/// Flutter应用全局控制器
class FlutterController extends GetxController {
  FlutterController({
    required FlutterConfigData config,
  }) {
    useMaterial3 = useLocalObs(config.useMaterial3, 'useMaterial3');
    // primaryColor = useLocalObs(_?.primaryColor ?? _primaryColor, 'primaryColor');
  }

  /// 通过静态变量直接获取控制器实例
  static FlutterController get of => Get.find();

  /// 应用全局过渡动画时长缩放，默认1倍速
  final timeDilation = useLocalObs(1.0, 'timeDilation');

  /// 是否启用material3
  late final Rx<bool> useMaterial3;

  /// 当前主题模式
  // final themeMode = useLocalObs(ThemeMode.system, 'themeMode');

  // late final Rx<Color> primaryColor;

  @override
  void onInit() {
    super.onInit();
    ever(timeDilation, (value) {
      scheduler.timeDilation = value;
    });
  }
}
