part of flutter_base;

/// Flutter应用全局控制器
class AppController extends GetxController {
  AppController({
    required ThemeMode themeMode,
    required AppThemeData theme,
    required AppThemeData darkTheme,
    required AppConfigData config,
  }) {
    _themeMode = themeMode.obs;
    _theme = theme.obs;
    _darkTheme = darkTheme.obs;
    _config = config.obs;
  }

  /// 通过静态变量直接获取控制器实例
  static AppController? get of => Get.findOrNull();

  static final AppThemeData _defaultTheme = AppThemeData();
  static final AppThemeData _defaultDarkTheme = AppThemeData.dark();
  static final AppConfigData _defaultConfig = AppConfigData();

  /// 当前主题模式
  late final Rx<ThemeMode> _themeMode;

  /// 亮色主题
  late final Rx<AppThemeData> _theme;

  /// 暗色主题
  late final Rx<AppThemeData> _darkTheme;

  /// 配置信息
  late final Rx<AppConfigData> _config;

  /// 应用全局过渡动画时长缩放，默认1倍速
  final timeDilation = 1.0.obs;

  ThemeMode get themeMode => _themeMode.value;

  set themeMode(ThemeMode value) {
    _themeMode.value = value;
  }

  AppThemeData get theme => _theme.value;

  set theme(AppThemeData value) {
    _theme.update((val) => value);
  }

  AppThemeData get darkTheme => _darkTheme.value;

  set darkTheme(AppThemeData value) {
    _darkTheme.update((val) => value);
  }

  AppConfigData get config => _config.value;

  set config(AppConfigData value) {
    _config.update((val) => value);
  }

  void _configUpdate(AppConfigData config) {
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
      scheduler.timeDilation = v;
    });
  }
}
