import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 字体图标复用 ElView 字形渲染，尺寸和颜色沿 ElStyle 继承。
Widget iconBuilder(BuildContext context, ElIcon component) => ElView(
  style: ElStyle(
    alignment: .center,
    iconSize: component.size,
    iconColor: component.color,
    fontWeight: .normal,
    fontVariationSettings: const [],
  ).merge(component.style),
  semantics: component.semanticLabel == null ? null : ElSemantics(label: component.semanticLabel),
  child: component.child ?? const IconData(0x20),
);
