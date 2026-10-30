import 'package:flutter_base/src/ui/desktop/internal.dart';
import 'package:flutter/material.dart';

/// 根据当前明暗环境从实际基色派生颜色。
extension ElColorContextExt on Color {
  /// light-1：离原色最近的一档。
  Color elLight1(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 1, reverse);

  /// 第二档浅色阶，按当前明暗环境派生。
  Color elLight2(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 2, reverse);

  /// light-3：常用于 hover 态的描边/文字色。
  Color elLight3(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 3, reverse);

  /// 第四档浅色阶，按当前明暗环境派生。
  Color elLight4(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 4, reverse);

  /// light-5：常用于禁用态文字色、聚焦环。
  Color elLight5(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 5, reverse);

  /// 第六档浅色阶，按当前明暗环境派生。
  Color elLight6(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 6, reverse);

  /// light-7：常用于 hover 态底色、浅描边。
  Color elLight7(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 7, reverse);

  /// light-8：常用于 tag/badge 的描边色。
  Color elLight8(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 8, reverse);

  /// light-9：最淡的一档，常用于 alert/tag 的填充底色。
  Color elLight9(BuildContext context, {bool reverse = false}) =>
      _elLight(context, 9, reverse);

  /// 按档位号取色阶，[level] 取值 1~9。
  ///
  /// 档位号来自运行时数据（如遍历、配置表）时用它，档位号写死在代码里时用
  /// [elLight3] 这类具名方法，读起来更直白。
  Color elLight(BuildContext context, int level, {bool reverse = false}) =>
      _elLight(context, level, reverse);

  /// 按**显式**明暗轴取色阶，不读 context。
  ///
  /// 给「要产出的主题轴 ≠ 当前 context 所处轴」的场景用——典型是
  /// `context.elMaterialTheme(.dark)` 在亮色页面里构建整份暗色 Material 主题。
  /// 普通组件用 [elLight]，跟随 context 才是对的。
  Color elLightOf(Brightness brightness, int level) {
    assert(level >= 1 && level <= 9, 'elLightOf 颜色级别范围必须是 1 - 9，但却得到: $level');
    return brightness == Brightness.dark ? _darken(level) : _brighten(level);
  }

  /// Element `--el-color-{type}-dark-2`：比原色更深的那一档。
  ///
  /// 官方公式是 `mix($black, $color, 20%)`，只有 dark-2 这一档，用于亮色模式下
  /// 按钮 active 态的加深。注意它**不跟随明暗态翻转**——暗色模式下 Element 官方
  /// 把 dark-2 定义成比原色更**亮**（`mix($white, $color, 20%)`），因为暗底上
  /// 「更强调」意味着更亮，这里用 [deepen] 的 reversal 语义表达同一件事。
  Color elDark2(BuildContext context) => context.isDark
      ? mix(const Color(0xffffffff), 20)
      : mix(const Color(0xff000000), 20);

  /// 按当前颜色明暗读取对应主题的常规文字色。
  Color elTextColor(BuildContext context) {
    return ElThemeData.of(context, brightness: isDark.brightness).textColorSm;
  }

  /// 按当前颜色明暗读取对应主题的常规文字色。
  Color elRegularTextColor(BuildContext context) {
    return ElThemeData.of(context, brightness: isDark.brightness).textColorSm;
  }

  /// 按当前颜色明暗读取对应主题的次要文字色。
  Color elSecondaryTextColor(BuildContext context) {
    return ElThemeData.of(context, brightness: isDark.brightness).textColorMd;
  }

  /// 按当前颜色明暗读取对应主题的占位文字色。
  Color elPlaceholderTextColor(BuildContext context) {
    return ElThemeData.of(context, brightness: isDark.brightness).textColorLg;
  }

  /// 按当前颜色明暗读取对应主题的次要图标色。
  Color elIconColor(BuildContext context) {
    return ElThemeData.of(context, brightness: isDark.brightness).textColorMd;
  }

  /// 根据颜色自身明暗与全局白色或黑色混合 50% 生成边框色。
  Color elBorderColor(BuildContext context) {
    return mix(
      (isDark
          ? ElThemeData.of(context, brightness: isDark.brightness).white
          : ElThemeData.of(context, brightness: isDark.brightness).black),
      50,
    );
  }

  /// 一次性取出 9 档色阶，下标 0 对应 light-1、下标 8 对应 light-9。
  ///
  /// 主要给色板展示这类要整条列出来的场景用；只取单档时别用它，会白算 8 次。
  List<Color> elLights(BuildContext context) {
    return [
      elLight1(context),
      elLight2(context),
      elLight3(context),
      elLight4(context),
      elLight5(context),
      elLight6(context),
      elLight7(context),
      elLight8(context),
      elLight9(context),
    ];
  }
}

extension _ColorExtension on Color {
  /// 暗色档位：与 `#222222` 混合，每档 9%。
  ///
  /// **本仓库自调值，不是 Element 官方暗表。** 官方 dark/css-vars.scss 的公式是
  /// `mix(#141414, $color, N*10%)`——混合对象是暗色页面底色 `--el-bg-color`
  /// (`#141414`)、每档 10%。两者以 primary (`#409eff`) 实测：
  ///
  /// | 档位 | 本实现 | Element 官方 | 最大通道差 |
  /// |------|--------|-------------|-----------|
  /// | 3    | #387dc3 | #3375b9     | 10/255    |
  /// | 5    | #33669c | #2a598a     | 18/255    |
  /// | 7    | #2d5074 | #213d5b     | 25/255    |
  /// | 8    | #2a4560 | #1d3043     | 29/255    |
  /// | 9    | #283a4c | #18222b     | 33/255    |
  ///
  /// 误差随档位单调放大，本实现整体**偏亮偏灰**；light-9 处 33/255 已是肉眼
  /// 可辨的差别。这是刻意保留的视觉选择（2026-07-28 用户裁决），改动前必须先跑
  /// 视觉回归。
  Color _darken(int level) => mix(const Color(0xff222222), level * 9);

  /// 亮色档位：与白色混合，每档 10%。
  ///
  /// 对齐 Element `mix($white, $color, percentage(N/10))`——Sass 的 `mix` 第一
  /// 参数是被混入色、第三参数是它的占比，故 light-N = N*10% 白 + 剩余原色。
  /// 以 primary 实测 light-3/5/7/8/9 五档与官方**逐字节相同**。
  Color _brighten(int level) => mix(const Color(0xffffffff), level * 10);

  /// 按当前明暗态生成 Element 色阶。
  ///
  /// 档位语义统一为「**离原色的距离**」：level 越大越远离原色、越贴近背景——
  /// 亮色模式下贴近白，暗色模式下贴近深灰。所以同一个 `elLight9` 在亮色下是极浅
  /// 底色、在暗色下是极深底色，两边都能当「最淡的那层底」用，调用方不必自己
  /// 分支判明暗。
  ///
  /// * [reverse] 反转明暗判定：用于**背景与页面主色调相反**的局部区域（如亮色页
  ///   面里的深色卡片），此时想要的色阶方向和页面整体相反。
  Color _elLight(BuildContext context, int level, bool reverse) {
    assert(level >= 1 && level <= 9, 'elLight 颜色级别范围必须是 1 - 9，但却得到: $level');
    if (!reverse) {
      return context.isDark ? _darken(level) : _brighten(level);
    } else {
      return context.isDark ? _brighten(level) : _darken(level);
    }
  }
}
