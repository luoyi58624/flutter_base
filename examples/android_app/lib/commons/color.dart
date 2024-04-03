import 'package:android_app/global.dart';
import 'package:flutter/material.dart';

List<int> _lightLevel = [100, 200, 300, 400];
List<int> _darkLevel = [900, 800, 700, 600];

List<Color> _lightGrey = List.generate(4, (index) => Colors.grey[_lightLevel[index]]!);

List<Color> _darkGrey = List.generate(4, (index) => Colors.grey[_darkLevel[index]]!);

class MyColor {
  static Color baseColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.white,
      Colors.black,
      context,
      mode: mode,
    );
  }

  /// 头部背景颜色
  static Color headerColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.white,
      Theme.of(context).colorScheme.surface,
      context,
      mode: mode,
    );
  }

  /// 底部导航背景颜色
  static Color bottomBarbackgroundColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.white,
      Colors.grey.shade900,
      context,
      mode: mode,
    );
  }

  /// 背景颜色
  static Color backgroundColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      const Color(0xFFf1f1f1),
      const Color(0xFF222222),
      context,
      mode: mode,
    );
  }

  /// input输入框填充背景色
  static Color inputFileColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.grey.shade100,
      Colors.grey.shade800,
      context,
      mode: mode,
    );
  }

  /// input输入框提示颜色
  static Color inputHintColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.grey.shade500,
      Colors.grey.shade300,
      context,
      mode: mode,
    );
  }

  /// 文本颜色
  static Color textColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.grey.shade900,
      Colors.grey.shade50,
      context,
      mode: mode,
    );
  }

  /// 二级文本颜色
  static Color secondTextColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.grey.shade800,
      Colors.grey.shade100,
      context,
      mode: mode,
    );
  }

  /// 分割线颜色
  static Color separatorColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      const Color.fromARGB(73, 60, 60, 67),
      const Color.fromARGB(153, 84, 84, 88),
      context,
      mode: mode,
    );
  }

  /// 骨架屏颜色
  static Color skeletonColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.grey.shade300,
      Theme.of(context).colorScheme.surface,
      context,
      mode: mode,
    );
  }

  /// 骨架屏高亮颜色
  static Color skeletonHighlightColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.grey.shade100,
      Theme.of(context).colorScheme.surface.withAlpha(200),
      context,
      mode: mode,
    );
  }

  /// IOS ListTile颜色
  static Color cupertinoListTileColor(BuildContext context, {ColorMode? mode}) {
    return dynamicColor(
      Colors.white,
      CupertinoColors.systemFill,
      context,
      mode: mode,
    );
  }

  static Color dynamicGrey(BuildContext context, {int level = 1, bool reversal = false}) {
    assert(level >= 1 && level <= 4, 'level颜色级别超出范围: 1-4');
    if (reversal) {
      return dynamicColor(
        _darkGrey[level - 1],
        _lightGrey[level - 1],
        context,
      );
    } else {
      return dynamicColor(
        _lightGrey[level - 1],
        _darkGrey[level - 1],
        context,
      );
    }
  }

  /// 返回一个动态颜色
  static Color dynamicColor(
    lightColor,
    darkColor,
    BuildContext context, {
    ColorMode? mode,
  }) {
    return ColorUtil.dynamicColor(lightColor, darkColor, context, mode: mode);
  }
}
