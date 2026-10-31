/// 参照：D:/project/html/my-ui/packages/core/my-ui.css:9-149；packages/vue/adapter.ts:68-106。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import 'theme_data.dart';
import '../components/builders.dart';

final _light = MyThemeData();
final _dark = MyThemeData(brightness: Brightness.dark);

/// 为 my-ui 和 ElView 提供一致主题，省略 brightness 时跟随系统。
///
/// 默认 Times New Roman，中文依次回退 Microsoft YaHei、SimSun；宿主负责提供字体。
/// 根行高使用字体自身度量（对应 Web normal），避免继承 Material 宿主行高。
/// Flutter Text 与 ElView 字符串均继承主题字体，子级显式字体和组件行高优先，嵌套 MyTheme 重新建立契约。
class MyTheme extends StatelessWidget {
  /// data 可单独用于局部主题，darkData 用于系统暗色模式。
  const MyTheme({
    super.key,
    required this.child,
    this.data,
    this.darkData,
    this.brightness,
    this.componentBuilders,
  });

  /// 当前子树。
  final Widget child;

  /// 浅色或显式局部主题。
  final MyThemeData? data;

  /// 暗色主题，省略时使用 CSS 默认暗色。
  final MyThemeData? darkData;

  /// 明确指定亮暗，优先于系统设置。
  final Brightness? brightness;

  /// 在移动端默认实现上合并的通用组件覆写。
  final ElComponentBuilders? componentBuilders;

  /// 订阅最近主题，缺少宿主时使用默认浅色。
  static MyThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeScope>()?.data ?? _light;

  @override
  Widget build(BuildContext context) {
    final mode =
        brightness ??
        (darkData == null ? data?.brightness : null) ??
        MediaQuery.maybePlatformBrightnessOf(context) ??
        Brightness.light;
    final resolved = mode == Brightness.dark
        ? (darkData ?? (data?.brightness == mode ? data : null) ?? _dark)
        : (data ?? _light);
    return _ThemeScope(
      data: resolved,
      child: ElComponentProvider(
        builders: myComponentBuilders.merge(componentBuilders),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontFamily: resolved.fontFamily,
            fontFamilyFallback: resolved.fontFamilyFallback,
            color: resolved.text,
            fontSize: 15,
            height: kTextHeightNone,
            fontWeight: resolved.weight(resolved.fontWeight),
            fontVariations: [FontVariation('wght', resolved.fontWeight)],
          ),
          child: ElView(
            themeMode: ElThemeMode(brightness: mode, duration: Duration.zero),
            style: ElStyle(
              fontFamily: resolved.fontFamily,
              fontFamilyFallback: resolved.fontFamilyFallback,
              color: resolved.text,
              iconColor: resolved.text,
              fontSize: 15,
              lineHeight: kTextHeightNone,
              fontWeight: resolved.weight(resolved.fontWeight),
              fontVariationSettings: [FontVariation('wght', resolved.fontWeight)],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ThemeScope extends InheritedTheme {
  const _ThemeScope({required this.data, required super.child});
  final MyThemeData data;
  @override
  bool updateShouldNotify(_ThemeScope oldWidget) => data != oldWidget.data;
  @override
  Widget wrap(BuildContext context, Widget child) =>
      _ThemeScope(data: data, child: child);
}
