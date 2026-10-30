import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 截断外层文档的渲染边界，内部文档仍可显式建立自己的选区。
abstract interface class SelectionBoundary {}

/// 不允许嵌套文档根或显式 userSelect 重开的文字禁选标记。
abstract interface class SelectionTextBlockBoundary {}

/// 选中内部使用的真实条目过滤，排除虚拟测量样本和缓存窗口。
abstract interface class SelectionItemVisibility {
  bool isSelectionItemAvailable(RenderObject descendant, {required bool visibleOnly});
}

/// 布局结束后同步新挂载对象；返回是否应用了需要重新布局的选中样式。
abstract interface class SelectionGeometryObserver {
  bool selectionLayoutChanged();
}

/// 向文档根和编辑器传递不可被后代 userSelect 重开的文字禁选边界。
final class SelectionTextBoundary extends InheritedWidget {
  /// 边界恒生效，框选 enabled 只控制对象交互。
  const SelectionTextBoundary({super.key, required super.child});

  /// 订阅最近硬边界；用于同步编辑器事件、快捷键与平台交互配置。
  static bool blocks(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SelectionTextBoundary>() != null;

  @override
  bool updateShouldNotify(SelectionTextBoundary oldWidget) => false;
}

/// 渲染侧硬边界，阻止外层文档跨入对象框选区域。
final class SelectionTextBlock extends SingleChildRenderObjectWidget {
  /// 包裹框选正文。
  const SelectionTextBlock({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _TextBlockRender();
}

final class _TextBlockRender extends RenderProxyBox implements SelectionBoundary, SelectionTextBlockBoundary {}
