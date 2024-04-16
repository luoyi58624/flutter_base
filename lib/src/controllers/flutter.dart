part of flutter_base;

/// Flutter应用全局控制器
class FlutterController extends GetxController {
  FlutterController({
    required ThemeMode themeMode,
    required FlutterThemeData theme,
    required FlutterThemeData darkTheme,
    required FlutterConfigData config,
  }) {
    _themeMode = themeMode.obs;
    _theme = theme.obs;
    _darkTheme = darkTheme.obs;
    _config = config.obs;
    // primaryColor = useLocalObs(_?.primaryColor ?? _primaryColor, 'primaryColor');
  }

  /// 通过静态变量直接获取控制器实例
  static FlutterController get of => Get.find();

  /// 当前主题模式
  late final Rx<ThemeMode> _themeMode;

  /// 亮色主题
  late final Rx<FlutterThemeData> _theme;

  /// 暗色主题
  late final Rx<FlutterThemeData> _darkTheme;

  /// 配置信息
  late final Rx<FlutterConfigData> _config;

  /// 应用全局过渡动画时长缩放，默认1倍速
  final timeDilation = 1.0.obs;

  ThemeMode get themeMode => _themeMode.value;

  set themeMode(ThemeMode value) {
    _themeMode.value = value;
  }

  FlutterThemeData get theme => _theme.value;

  set theme(FlutterThemeData value) {
    _theme.update((val) => value);
  }

  FlutterThemeData get darkTheme => _darkTheme.value;

  set darkTheme(FlutterThemeData value) {
    _darkTheme.update((val) => value);
  }

  FlutterConfigData get config => _config.value;

  set config(FlutterConfigData value) {
    _config.update((val) => value);
  }

  /// 返回自适应主题色，必须传递当前页面的[context]
  FlutterThemeData getTheme(BuildContext context) {
    return FlutterUtil.isDarkMode(context) ? darkTheme : theme;
  }

  void _configUpdate(FlutterConfigData config) {
    if (config.translucenceStatusBar) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color.fromRGBO(0, 0, 0, 200)));
    } else {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color.fromRGBO(0, 0, 0, 0)));
    }
  }

  @override
  void onInit() {
    super.onInit();
    _configUpdate(config);
    ever(_config, (v) => _configUpdate(v));
    ever(timeDilation, (v) {
      logger.i('xx');
      scheduler.timeDilation = v;
    });
  }
}
