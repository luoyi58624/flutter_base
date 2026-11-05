import 'package:flutter/widgets.dart';

import '../../../flutter/views/view/view.dart' show ElView;
import '../../../flutter/widgets/icon/content.dart';
import '../../../flutter/widgets/icon/index.dart' show ElIcon;

/// 内容归一化（button / switch 设计体系的公共内容通道）。
///
/// - [IconData]：自动包成 [ElIcon]——尺寸取 [iconSize]（null 吃图标通道默认），
///   颜色沿外壳 ElStyle.iconColor 继承；普通 Flutter Icon 同样转换到字形通道；
/// - 其余类型（String / Widget / InlineSpan / Iterable）：原样交给 [ElView.child]
///   文本/子载荷通道，自动继承外壳的 fontSize / color 等文本样式。
///
/// 各组件内容参数统一声明为 `Object?` 并在此归一化，用户可直接传字符串、
/// 任意 Widget 或 IconData。
Object? elContent(Object? content, {double? iconSize}) {
  if (content is IconData) return ElIcon(content, size: iconSize);
  if (content is Icon) return buildIconContent(content, size: iconSize);
  return content;
}
