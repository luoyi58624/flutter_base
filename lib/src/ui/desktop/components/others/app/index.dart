import 'package:flutter/widgets.dart';
import 'package:flutter_base/src/flutter/components/icon/index.dart' as common show ElIcon;
import 'package:flutter_base/src/ui/desktop/internal.dart';

import '../../../../../flutter/commons/theme/style.dart';

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
part 'tokens.dart';
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
    this.compact = false,
    required this.child,
  });

  /// 合并在默认根样式之后的用户样式。
  final ElStyle? style;

  /// 使用紧凑控件密度，默认保留普通桌面尺寸。
  final bool compact;

  /// 明暗模式及统一过渡参数。
  final ElThemeMode? themeMode;

  /// 继承给内容的响应式断点。
  final ElBreakpoint? breakpoint;

  /// 继承给内容的语言环境。
  final Locale? locale;

  /// 在本品牌默认实现上合并的组件实现。
  final ElComponents? componentBuilders;

  /// 使用桌面主题的内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final declared = themeMode;
    final mode = ElThemeMode(
      brightness: declared?.brightness ?? MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
      duration: declared?.duration,
      curve: declared?.curve,
    );
    return ElView(
      themeMode: mode,
      breakpoint: breakpoint,
      locale: locale,
      style: ElStyle(
        vars: {...lightVars, $compact: compact},
        onDark: ElStyle(vars: darkVars),
      ).merge(themeVarsOf(style)),
      // 沿用旧主题的两层根：先注入变量，再由后代读取生成实际继承样式。
      child: Builder(
        builder: (context) {
          final values = context.elTheme;
          final rootStyle = ElStyle(
            backgroundColor: values.bgColor,
            color: values.textColor,
            fontSize: 15,
            iconSize: 24,
            iconColor: values.textSecondary,
          ).merge(style);
          return ElView(
            style: rootStyle,
            child: ElComponentProvider(
              builders: const ElementPlusThemeData().merge(componentBuilders),
              child: Directionality(
                textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
                // 保留输入候选层的官方 Overlay 环境，并按内容测量宿主。
                child: Overlay.wrap(clipBehavior: Clip.none, alwaysSizeToContent: true, child: child),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 桌面端的通用主题浅色默认表。
  static Map<Object, Object> get lightVars => _lightVars;

  /// 桌面控件密度变量，普通 ElView 可局部覆盖，移动端组件不消费它。
  static const $compact = '--el-desktop-compact';

  /// 桌面端的暗色增量，按普通 onDark 变体覆盖。
  static Map<Object, Object> get darkVars => _darkVars;
}
