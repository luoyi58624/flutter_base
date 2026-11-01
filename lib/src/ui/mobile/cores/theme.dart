/// 参照：D:/project/html/my-ui/packages/core/my-ui.css:9-149；packages/vue/adapter.ts:68-106。
library;

import 'package:flutter/widgets.dart';
import 'package:android_system_font_weight/android_system_font_weight.dart';
import 'package:flutter_base/ui.dart';

import '../components/builders.dart';
import '../../../flutter/theme/style.dart';

part 'tokens.dart';

final Map<Object, Object> _lightVars = _buildVars(false);
final Map<Object, Object> _darkVars = _buildVars(true);

/// 系统字重采集入口，仅供无头测试替换原生调用，不从公共入口导出。
@visibleForTesting
double? Function() readSystemFontWeight = AndroidSystemFontWeight.getWght;

/// 注入移动端变量及 Android 系统字重，并同步 Flutter Text 与 ElView 的字体。
class ElMobileTheme extends StatelessWidget {
  /// 明暗默认表按当前状态级联，用户变量与实际样式通过 style 覆盖。
  const ElMobileTheme({super.key, required this.child, this.style, this.brightness, this.componentBuilders});

  /// 当前子树。
  final Widget child;

  /// 在品牌默认值之后合并的样式及变量。
  final ElStyle? style;

  /// 明确指定亮暗，省略时跟随系统。
  final Brightness? brightness;

  /// 在移动端默认实现上合并的通用组件覆写。
  final ElComponentBuilders? componentBuilders;

  /// 移动端默认浅色变量，调用方用新 Map 声明覆盖。
  static Map<Object, Object> get lightVars => _lightVars;

  /// 移动端默认暗色差异，其余变量继承浅色基础表。
  static Map<Object, Object> get darkVars => _darkVars;

  @override
  Widget build(BuildContext context) {
    final mode = brightness ?? MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    final systemWeight = readSystemFontWeight();
    final systemVariations =
        systemWeight != null && systemWeight.isFinite && systemWeight >= 100 && systemWeight <= 1000
        ? [FontVariation('wght', systemWeight)]
        : null;
    return ElView(
      themeMode: ElThemeMode(brightness: mode, duration: Duration.zero),
      style: ElStyle(
        vars: _lightVars,
        onDark: ElStyle(vars: _darkVars),
      ).merge(themeVarsOf(style)),
      child: ElComponentProvider(
        builders: defaultComponentBuilders.merge(componentBuilders),
        child: Builder(
          builder: (context) {
            final theme = context.elTheme;
            final fontWeight = textWeight(theme.fontWeight);
            final family = theme.fontFamily;
            final fallback = theme.fontFamilyFallback;
            return DefaultTextStyle.merge(
              style: TextStyle(
                fontFamily: family.isEmpty ? null : family,
                fontFamilyFallback: fallback.isEmpty ? null : fallback,
                color: theme.textColor,
                fontSize: 15,
                height: kTextHeightNone,
                fontWeight: fontWeight,
                fontVariations: style?.fontVariationSettings ?? systemVariations,
              ),
              child: ElView(
                style: ElStyle(
                  fontFamily: family.isEmpty ? null : family,
                  fontFamilyFallback: fallback.isEmpty ? null : fallback,
                  color: theme.textColor,
                  iconColor: theme.textColor,
                  fontSize: 15,
                  lineHeight: kTextHeightNone,
                  fontWeight: fontWeight,
                  // 系统轴由插件原样提供，保留各组件 fontWeight 档位，显式 style 仍优先。
                  fontVariationSettings: systemVariations,
                ).merge(style),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 以最近百位字重回退静态字体，数值轴由实际样式单独保留。
FontWeight textWeight(double value) => FontWeight.values[((value / 100).round() - 1).clamp(0, 8)];
