part of 'scroll_viewport_base.dart';

/// 将稳定的滚动语义边界与内部视口的动态子项变换分离。
class ScrollSemantics extends SingleChildRenderObjectWidget {
  /// 创建包内滚动语义宿主。
  const ScrollSemantics({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderScrollSemantics();
}

class _RenderScrollSemantics extends RenderProxyBox {
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (child case final RenderScrollViewportBase viewport) viewport._describeScrollSemantics(config);
  }
}
