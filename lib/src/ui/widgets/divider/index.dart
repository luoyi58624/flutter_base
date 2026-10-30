import 'package:flutter/widgets.dart';

import '../../../flutter/views/view/style/style.dart';
import '../../../flutter/views/view/view.dart';

/// 无外观分割线，负责方向、内容插槽与线段布局。
class ElDivider extends ElView {
  /// 创建分割线；默认使用当前文字色，可直接指定方向、厚度与间距。
  ElDivider({
    super.key,
    bool vertical = false,
    Object? child,
    double size = 24,
    double thickness = 1,
    double indent = 0,
    double gap = 8,
    Color color = const Color(0xff808080),
    ElStyle? style,
  }) : super(
         style: ElStyle(
           width: vertical ? size : '100%',
           height: size,
           padding: vertical ? EdgeInsets.symmetric(vertical: indent) : EdgeInsets.symmetric(horizontal: indent),
           alignment: .center,
         ).merge(style),
         child: vertical
             ? _buildDividerColumn(child: child, thickness: thickness, gap: gap, color: color)
             : _buildDividerRow(child: child, thickness: thickness, gap: gap, color: color),
       );
}

Widget _buildDividerRow({required Object? child, required double thickness, required double gap, Color? color}) {
  return Row(
    crossAxisAlignment: .center,
    children: [
      Expanded(
        child: _dividerLine(thickness: thickness, color: color),
      ),
      if (child != null) ...[
        _dividerGap(width: gap),
        ElView(child: child),
        _dividerGap(width: gap),
        Expanded(
          child: _dividerLine(thickness: thickness, color: color),
        ),
      ],
    ],
  );
}

Widget _buildDividerColumn({required Object? child, required double thickness, required double gap, Color? color}) {
  return Column(
    mainAxisSize: .max,
    crossAxisAlignment: .center,
    children: [
      Expanded(
        child: _dividerLine(thickness: thickness, color: color, vertical: true),
      ),
      if (child != null) ...[
        _dividerGap(height: gap),
        ElView(child: child),
        _dividerGap(height: gap),
        Expanded(
          child: _dividerLine(thickness: thickness, color: color, vertical: true),
        ),
      ],
    ],
  );
}

Widget _dividerLine({required double thickness, Color? color, bool vertical = false}) => ElView(
  style: vertical ? ElStyle(width: thickness, bgColor: color) : ElStyle(height: thickness, bgColor: color),
);

Widget _dividerGap({double? width, double? height}) => ElView(
  style: ElStyle(width: width, height: height),
);
