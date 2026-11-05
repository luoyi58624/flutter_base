import 'package:flutter/widgets.dart';

import '../../views/view/render/render_view.dart' show ElRenderView;
import '../../views/view/semantics/semantics.dart' show ElSemantics;
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
    return _IconView(
      key: icon.key,
      applyTextScaling: icon.applyTextScaling ?? false,
      style: ElStyle(
        alignment: .center,
        iconSize: icon.size ?? size,
        iconColor: icon.color,
        direction: icon.textDirection,
        fontWeight: icon.fontWeight ?? .normal,
        textShadow: icon.shadows,
        fontVariationSettings: [
          if (icon.fill != null) FontVariation('FILL', icon.fill!),
          if (icon.weight != null) FontVariation('wght', icon.weight!),
          if (icon.grade != null) FontVariation('GRAD', icon.grade!),
          if (icon.opticalSize != null) FontVariation('opsz', icon.opticalSize!),
        ],
      ),
      semantics: icon.semanticLabel == null
          ? null
          : ElSemantics(label: icon.semanticLabel, textDirection: icon.textDirection),
      child: icon.icon ?? const IconData(0x20),
    );
  }
  return content is Widget ? content : ElView(child: content);
}

class _IconView extends ElView {
  const _IconView({super.key, required this.applyTextScaling, super.style, super.semantics, required super.child});

  final bool applyTextScaling;

  TextScaler _scaler(BuildContext context) =>
      applyTextScaling ? (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling) : TextScaler.noScaling;

  @override
  ElRenderView createRenderObject(BuildContext context) =>
      super.createRenderObject(context)..textScaler = _scaler(context);

  @override
  void updateRenderObject(BuildContext context, ElRenderView renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject.textScaler = _scaler(context);
  }
}
