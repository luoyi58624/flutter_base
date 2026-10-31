import 'package:flutter_base/flutter_base.dart';

/// Element Plus 输入族共用的默认字号。
///
/// 本文件不从组件 barrel 导出，只供表单复合组件复用同一套行盒度量，避免
/// Select、InputTag 等各自复制尺寸表后逐渐漂移。
double elInputDefaultFontSize(ElLevelType size) =>
    const <double>[12, 13, 14, 15, 16][size.index];

/// Element Plus 输入族共用的默认图标尺寸。
double elInputDefaultIconSize(ElLevelType size) =>
    const <double>[12, 13, 14, 15, 16][size.index];

/// 输入正文的 CSS line-height 倍数。
const double elInputLineHeightFactor = 1.5;

/// 根据实际字号计算输入正文行盒高度。
double elInputLineBoxHeight(double fontSize) =>
    fontSize * elInputLineHeightFactor;

/// 前后缀与动作按钮的稳定内联槽位边长。
double elInputInlineSlotExtent({
  required double fontSize,
  required double iconSize,
}) => elInputLineBoxHeight(fontSize) > iconSize
    ? elInputLineBoxHeight(fontSize)
    : iconSize;
