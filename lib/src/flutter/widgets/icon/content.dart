import 'package:flutter/widgets.dart';

import '../../views/view/style/style.dart' show ElStyle;
import '../../views/view/view.dart' show ElView;
import 'index.dart' show ElIcon;

/// 图标槽将字体数据和普通 Icon 接入 ElStyle，自定义 Widget 保留原实例。
Widget buildIconContent(Object? content, {double? size}) {
  if (content is IconData) return ElIcon(content, size: size);
  if (content.runtimeType == Icon) {
    final icon = content as Icon;
    // 特殊混合绘制由调用方的 Widget 保持，避免转换时丢失自定义绘制语义。
    if (icon.blendMode != null) return icon;
    return ElIcon(
      icon.icon,
      key: icon.key,
      applyTextScaling: icon.applyTextScaling ?? false,
      size: icon.size ?? size,
      color: icon.color,
      fill: icon.fill,
      weight: icon.weight,
      grade: icon.grade,
      opticalSize: icon.opticalSize,
      fontWeight: icon.fontWeight,
      textDirection: icon.textDirection,
      semanticLabel: icon.semanticLabel,
      style: icon.shadows == null ? null : ElStyle(textShadow: icon.shadows),
    );
  }
  return content is Widget ? content : ElView(child: content);
}
