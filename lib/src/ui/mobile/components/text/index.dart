import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 原样传递通用文本参数，默认字体和颜色由 MyTheme 提供。
Widget myTextBuilder(BuildContext context, ElText component) => Text(
  component.data,
  style: component.style,
  strutStyle: component.strutStyle,
  textAlign: component.textAlign,
  textDirection: component.textDirection,
  locale: component.locale,
  softWrap: component.softWrap,
  overflow: component.overflow,
  textScaler: component.textScaler,
  maxLines: component.maxLines,
  textWidthBasis: component.textWidthBasis,
  textHeightBehavior: component.textHeightBehavior,
  selectionColor: component.selectionColor,
);
