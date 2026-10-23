import 'package:flutter/painting.dart';

/// 供轮廓绘制器消费的纯色贡献、渐变及其权重，几何值均已完成求值。
typedef OutlineStyle = ({
  double width,
  double offset,
  Color color,
  Gradient? gradient,
  double gradientOpacity,
  TextDirection direction,
});
