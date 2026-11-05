import 'package:flutter/painting.dart' show TextPosition, TextRange;

/// 编辑操作层依赖的布局查询协议。
///
/// 位置一律用 doc offset 表达（[TextPosition.offset] 为全文偏移，affinity 用于
/// wrap 折行点消歧）。实现方（渲染协调器）负责 doc↔行内坐标换算与跨逻辑行
/// 步进；操作层（[EditableOps]）不接触任何像素几何来源，保证可独立测试。
abstract interface class EditableLayoutQuery {
  /// 沿屏幕物理左右方向跨过一个视觉字素；到文档边界时返回 null。
  ///
  /// bidi run 内 doc offset 允许反向变化；soft-wrap 接缝必须先在同 offset 的
  /// upstream / downstream caret 间切换，再跨越下一字素。
  TextPosition? moveHorizontal(TextPosition position, {required bool left});

  /// 返回同一视觉行选区在屏幕物理左/右侧的端点。
  ///
  /// 跨逻辑行、跨 soft-wrap 行或尚无已挂载布局时返回 null，由操作层退回
  /// logical start/end，避免拿不同视觉行的局部 x 做伪比较。
  TextPosition? horizontalSelectionEdge(TextRange range, {required bool left});

  /// caret 的视觉 x（所在逻辑行的行内坐标），供垂直移动序列建立 xGoal 粘滞。
  double caretXFor(TextPosition position);

  /// 视觉行上/下移动。跨 wrap 行与跨逻辑行由实现处理；已到文档顶/底无处可去
  /// 时返回 null（调用方按惯例落到文档首/尾）。
  TextPosition? moveVertical(TextPosition position, {required bool down, required double xGoal});

  /// 翻页移动：按 [pageExtent]（视口主轴高度）跳过若干视觉行。
  TextPosition pageMove(TextPosition position, {required bool down, required double xGoal, required double pageExtent});

  /// wrap 感知的视觉行首/尾（Home / End 语义）。
  TextPosition visualLineEdge(TextPosition position, {required bool end});

  /// [position] 处的词边界（doc offset 区间，不跨逻辑行）。
  TextRange wordBoundary(TextPosition position);
}
