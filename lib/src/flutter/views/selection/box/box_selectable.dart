part of 'box_selection_view.dart';

class _BoxScope extends InheritedWidget {
  const _BoxScope({required this.owner, required this.controller, required super.child});
  final _BoxSelectionState owner;
  final ElBoxSelectionController controller;
  @override
  bool updateShouldNotify(_BoxScope oldWidget) => owner != oldWidget.owner || controller != oldWidget.controller;
}

/// 实验性框选对象项，自行选择普通样式，不创建文档 participant。
///
/// 仅用于试验验证，不适用于生产环境。
class ElBoxSelectable extends StatelessWidget {
  /// 创建只订阅所属根、不订阅全体选中变化的对象项。
  const ElBoxSelectable({super.key, required this.value, this.style, this.selectedStyle, this.child});

  /// 在同一个框选根内唯一的稳定值。
  final Object value;

  /// 普通样式。
  final ElStyle? style;

  /// 选中时叠加的样式。
  final ElStyle? selectedStyle;

  /// 对象显示内容。
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_BoxScope>();
    if (scope == null) throw StateError('ElBoxSelectable 必须位于 ElBoxSelectionView 内。');
    return _BoxItemWidget(
      owner: scope.owner,
      value: value,
      child: _BoxItemView(
        controller: scope.controller,
        value: value,
        normalStyle: style,
        selectedStyle: selectedStyle,
        child: child,
      ),
    );
  }
}

class _BoxItemView extends ElView {
  const _BoxItemView({
    required this.controller,
    required this.value,
    this.normalStyle,
    this.selectedStyle,
    super.child,
  });
  final ElBoxSelectionController controller;
  final Object value;
  final ElStyle? normalStyle;
  final ElStyle? selectedStyle;
  @override
  ElStyle? get style =>
      controller.isSelected(value) ? (normalStyle ?? const ElStyle()).merge(selectedStyle) : normalStyle;

  @override
  ElRenderView createRenderObject(BuildContext context) {
    final render = super.createRenderObject(context);
    // 框选只更新命中的对象项；沿用其 Element 样式求值，保持 builder 依赖和布局收敛。
    context.findAncestorRenderObjectOfType<_BoxItemRender>()!.resolveStyle = () => style;
    return render;
  }
}

class _BoxItemWidget extends SingleChildRenderObjectWidget {
  const _BoxItemWidget({required this.owner, required this.value, required super.child});
  final _BoxSelectionState owner;
  final Object value;
  @override
  RenderObject createRenderObject(BuildContext context) => _BoxItemRender(owner, value);
  @override
  void updateRenderObject(BuildContext context, _BoxItemRender renderObject) => renderObject.rebind(owner, value);
}

class _BoxItemRender extends RenderProxyBox {
  _BoxItemRender(this.regionOwner, this.value);
  _BoxSelectionState regionOwner;
  Object value;
  ElStyle? Function()? resolveStyle;
  bool? _selected;
  @override
  bool get isRepaintBoundary => true;
  void syncSelected() {
    final selected = regionOwner._controller.isSelected(value);
    if (_selected == selected) return;
    _selected = selected;
    if (child case final ElRenderView view) view.style = resolveStyle?.call();
  }

  void rebind(_BoxSelectionState next, Object nextValue) {
    if (next == regionOwner && nextValue == value) return;
    _unregister();
    regionOwner = next;
    value = nextValue;
    _selected = null;
    if (attached) _register();
    syncSelected();
    markNeedsLayout();
  }

  void _unregister() {
    if (identical(regionOwner._items[value], this)) regionOwner._items.remove(value);
  }

  void _register() {
    final previous = regionOwner._items[value];
    regionOwner._items[value] = this;
    assert(() {
      if (previous != null && previous != this) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          assert(
            !attached || !previous.attached || previous.value != value || previous.regionOwner != regionOwner,
            'ElBoxSelectable 的 value 在同一个框选根内必须唯一。',
          );
        });
      }
      return true;
    }());
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _register();
  }

  @override
  void detach() {
    _unregister();
    super.detach();
  }
}
