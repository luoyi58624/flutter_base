import 'package:flutter/widgets.dart';

import 'render/index.dart';
import 'style/index.dart';

export 'style/index.dart'
    show ElStyle, ElStyleExt, ElTransition, ElTransitionField;

/// 由一个渲染对象实现盒模型；重建后的样式变化按 transitions 过渡。
class ElView extends SingleChildRenderObjectWidget {
  /// 创建视图，首次挂载直接显示目标样式。
  const ElView({super.key, this.style = const ElStyle(), super.child});

  /// 目标样式；盒模型属性不继承给后代。
  final ElStyle style;

  @override
  ElRenderView createRenderObject(BuildContext context) =>
      ElRenderView(style, Directionality.maybeOf(context) ?? TextDirection.ltr);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant ElRenderView renderObject,
  ) {
    renderObject.applyStyle(
      style,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }
}
