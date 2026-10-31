import 'package:flutter_base/flutter_base.dart' hide ElIcon;
import 'package:flutter/widgets.dart';

import '../components/basic/icon/index.dart';

/// 内容归一化（button / switch 设计体系的公共内容通道）。
///
/// - [IconData]：自动包成 [ElIcon]——尺寸取 [iconSize]（null 吃图标通道默认），
///   颜色吃外壳 `currentColor` 继承（组件根声明 `color` 即全局配色，无需逐处传色）；
/// - 其余类型（String / Widget / InlineSpan / Iterable）：原样交给 [ElView.child]
///   文本/子载荷通道，自动继承外壳的 fontSize / color 等文本样式。
///
/// 各组件内容参数统一声明为 `Object?` 并在此归一化，用户可直接传字符串、
/// 任意 Widget 或 IconData。
Object? elContent(Object? content, {double? iconSize}) {
  if (content is IconData) return ElIcon(content, size: iconSize);
  return content;
}
