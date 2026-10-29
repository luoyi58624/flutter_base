part of 'selection_core.dart';

/// 编辑器内部的起手边界，不建立注册表或代管外部文档。
class SelectionIsland extends SingleChildRenderObjectWidget {
  /// 包裹自行处理文本手势的编辑区域。
  const SelectionIsland({super.key, this.enabled = true, super.child});

  /// 是否让编辑区域自行处理选择手势。
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSelectionIsland(enabled: enabled);

  @override
  void updateRenderObject(BuildContext context, RenderSelectionIsland renderObject) {
    renderObject.enabled = enabled;
  }
}

/// 只标记当前编辑区域，不查找或订阅外部选区根。
class RenderSelectionIsland extends RenderProxyBox {
  /// 创建内部编辑边界。
  RenderSelectionIsland({this.enabled = true});

  /// 是否启用内部手势边界。
  bool enabled;
}
