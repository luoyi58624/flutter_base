import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/ui/desktop/internal.dart';

import '../../button/index.dart';
import '../../button_group/index.dart';
import '../../tag/index.dart';
import '../../table/index.dart';
import '../../autocomplete/index.dart';
import '../../input/index.dart';
import '../../input_number/index.dart';
import '../../input_otp/index.dart';
import '../../input_tag/index.dart';
import '../../mention/index.dart';
import '../../select/index.dart';
import '../../switch/index.dart';

part 'theme.dart';
part 'palette.dart';
part 'shadow.dart';

/// 安装 Element Plus 桌面主题和已有通用接口的组件实现。
class ElDesktopTheme extends StatelessWidget {
  /// 创建主题宿主；未指定明暗模式时跟随平台。
  const ElDesktopTheme({
    super.key,
    this.style,
    this.themeMode,
    this.breakpoint,
    this.locale,
    this.componentBuilders,
    this.theme,
    this.darkTheme,
    this.size,
    required this.child,
  });

  /// 合并在默认根样式之后的用户样式。
  final ElStyle? style;

  /// 浅色品牌主题。
  final ElThemeData? theme;

  /// 暗色品牌主题。
  final ElThemeData? darkTheme;

  /// 覆盖品牌主题中的组件尺寸档位。
  final ElLevelType? size;

  /// 明暗模式及统一过渡参数。
  final ElThemeMode? themeMode;

  /// 继承给内容的响应式断点。
  final ElBreakpoint? breakpoint;

  /// 继承给内容的语言环境。
  final Locale? locale;

  /// 在本品牌默认实现上合并的组件实现。
  final ElComponentBuilders? componentBuilders;

  /// 使用桌面主题的内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final declared = themeMode;
    final mode = ElThemeMode(
      brightness:
          declared?.brightness ??
          MediaQuery.maybePlatformBrightnessOf(context) ??
          Brightness.light,
      duration: declared?.duration,
      curve: declared?.curve,
    );
    final light = (theme ?? ElThemeData()).copyWith(size: size);
    final dark = (darkTheme ?? ElThemeData.dark()).copyWith(size: size);
    ElStyle rootStyle(ElThemeData values) => ElStyle(
      backgroundColor: values.bgColor,
      color: values.textColorXs,
      fontSize: values.fontSizes[values.size.index],
      iconSize: values.iconSizes[values.size.index],
      iconColor: values.iconColor,
    );
    return _ElThemeScope(
      light: light,
      dark: dark,
      brightness: mode.brightness!,
      child: ElView(
        themeMode: mode,
        breakpoint: breakpoint,
        locale: locale,
        style: rootStyle(light).copyWith(onDark: rootStyle(dark)).merge(style),
        child: ElComponentProvider(
          builders: const ElementPlusThemeData().merge(componentBuilders),
          child: Directionality(
            textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
            // 保留输入候选层的官方 Overlay 环境，并按内容测量宿主。
            child: Overlay.wrap(
              clipBehavior: Clip.none,
              alwaysSizeToContent: true,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
