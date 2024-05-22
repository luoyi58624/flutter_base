part of '../../flutter_base.dart';

/// 顶级App组件，实现注入全局配置信息，构建[ThemeData]、[CupertinoThemeData]，构建[Overlay]遮罩层等功能
class AppWidget extends InheritedWidget {
  /// 注入[AppConfigData]全局配置数据
  AppWidget({
    super.key,
    required super.child,
    AppConfigData? data,
  }) {
    this.data = data ?? AppConfigData.config;
  }

  /// 全局配置数据
  late final AppConfigData data;

  /// 获取全局配置数据
  static AppConfigData of(BuildContext context) {
    final AppWidget? result = context.dependOnInheritedWidgetOfExactType<AppWidget>();
    assert(result != null, 'No App found in context');
    return result!.data;
  }

  /// 根据注入的[AppConfigData]，构建 Material 主题数据
  static ThemeData buildThemeData({
    AppConfigData? data,
    Brightness brightness = Brightness.light,
  }) {
    data ??= AppConfigData.config;
    return _buildThemeData(data, brightness);
  }

  /// 根据注入的[AppConfigData]，构建 Cupertino 主题数据
  static CupertinoThemeData buildCupertinoThemeData({
    AppConfigData? data,
    Brightness brightness = Brightness.light,
  }) {
    data ??= AppConfigData.config;
    return _buildCupertinoThemeData(data, brightness);
  }

  @override
  bool updateShouldNotify(AppWidget oldWidget) {
    return false;
  }
}
