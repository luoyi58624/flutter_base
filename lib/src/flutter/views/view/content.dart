import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show Widget;

import '../../utils/internal/bit_mask.dart';
import 'element/content_binding.dart';
import 'render/render_view.dart';
import 'style/resolved/resolved_style.dart';
import 'style/style.dart';
import 'text/text_engine.dart';

/// 创建实际载荷需要的内容模块，普通 Widget 子树由 Element 管理。
ViewContent? createViewContent(ElRenderView host, Object? payload) => createTextEngine(host, payload);

/// 为需要独立语义坐标的复合载荷创建等价子视图。
Widget? contentSemanticsChild(Object payload, ElStyle? style) => textSemanticsChild(payload, style);

/// 按需内容模块与盒模型宿主之间的渲染、子树和生命周期边界。
abstract interface class ViewContent {
  /// 当前内容载荷。
  Object? get payload;

  /// 创建当前内容所需的 Element 子树绑定。
  ContentElementBinding createElementBinding(ContentElementHost host);

  /// 更新载荷并失效需要重算的内容。
  void setPayload(Object? value);

  /// 仅在子树结构不变时直接消费新载荷。
  bool tryUpdatePayload(Object? value);

  /// 安装内容专用的子项数据。
  void setupParentData(RenderObject child);

  /// 在盒内约束下排布或试算内容。
  Size layout(
    BoxConstraints constraints,
    Offset origin, {
    required ResolvedStyle style,
    bool fillWidth = false,
    bool dry = false,
  });

  /// 最终内容区确定后更新对齐及附属几何。
  void finishLayout(Size contentSize);

  /// 查询内容的固有宽度。
  double intrinsicWidth({required bool isMin});

  /// 查询内容的固有高度。
  double intrinsicHeight(double width, {required bool isMin});

  /// 查询当前真实内容的基线。
  double? actualBaseline(TextBaseline baseline);

  /// 在试算约束及最终内容区中查询基线。
  double? dryBaseline(
    BoxConstraints constraints,
    Size contentSize,
    Offset origin,
    TextBaseline baseline, {
    bool fillWidth = false,
  });

  /// 绘制内容及其附属层。
  void paint(PaintingContext context, Offset offset);

  /// 开始一轮宿主命中，清除上轮临时结果。
  void beginHitTest();

  /// 按内容自身几何执行命中。
  bool hitTest(BoxHitTestResult result, Offset position);

  /// 当前内容贡献的鼠标光标。
  MouseCursor get cursor;

  /// 内容是否需要合成层。
  bool get needsCompositing;

  /// 内容是否裁剪其溢出命中范围。
  bool get clipsHitBounds;

  /// 按实际内容坐标访问可命中的子项。
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor);

  /// 将内容子项的局部坐标接入宿主变换。
  void applyPaintTransform(RenderBox child, Matrix4 transform);

  /// 贡献内容自身的无障碍配置。
  void describeSemantics(SemanticsConfiguration config);

  /// 已提交样式变化后更新内容缓存。
  void styleCommit(ResolvedStyle previous, ResolvedStyle current, FieldMask changedMask);

  /// 本地声明变化后更新不参与级联的内容配置。
  void declarationChanged(ElStyle? previous, ElStyle? current);

  /// 真实渲染宿主加入树后重建内容协作关系。
  void attach();

  /// 真实渲染宿主离树后解除内容协作关系。
  void detach();

  /// 释放内容模块及其所有资源。
  void dispose();
}
