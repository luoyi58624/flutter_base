import 'package:flutter/rendering.dart';

/// 已完成样式插值与方向解析的原始矩阵和物理原点；几何执行器只补盒尺寸。
typedef TransformStyle = ({Matrix4 matrix, Alignment alignment});
