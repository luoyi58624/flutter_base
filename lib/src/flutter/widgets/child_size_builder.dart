import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 通过临时布局探测子组件尺寸，再构建实际内容。
class ElChildSizeBuilder extends RenderObjectWidget {
  /// 在 build 过程中直接访问 child 尺寸的小部件，无需帧后回调，
  /// 其核心原理便是在进行实际布局前探测 [tempChild] 的尺寸，
  /// 然后将 size 传递给 [builder] 方法。
  ///
  /// 提示：使用该小部件需要注意性能问题，因为布局成本可能翻倍，创建该小部件的灵感来自此评论：
  /// https://github.com/flutter/flutter/issues/14488#issuecomment-675837800
  const ElChildSizeBuilder({
    super.key,
    this.constraints,
    required this.tempChild,
    required this.builder,
  });

  /// 对 [tempChild] 添加尺寸约束，默认情况下 [tempChild] 使用的是 [ElChildSizeBuilder] 父级的尺寸约束，
  /// 但如果你实际构建的组件间接引用了新的约束，那么你应当将此约束应用给 [tempChild]
  final BoxConstraints? constraints;

  /// 需要计算尺寸的临时小部件，它参与布局但不进行渲染，布局完成后会拿到 size 并传递给 [builder] 回调
  final Widget tempChild;

  /// 实际构建的小部件，其回调参数便是 [tempChild] 的尺寸
  final Widget Function(Size size) builder;

  /// 判断组件是否处于临时布局中
  static bool isTempLayout(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ChildSizeInheritedWidget>() !=
      null;

  @override
  RenderObjectElement createElement() => _ChildSizeElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderChildSizeBox(constraints);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderChildSizeBox).builderConstraints = constraints;
  }
}

class _ChildSizeElement extends RenderObjectElement {
  _ChildSizeElement(super.widget);

  @override
  ElChildSizeBuilder get widget => super.widget as ElChildSizeBuilder;

  @override
  _RenderChildSizeBox get renderObject =>
      super.renderObject as _RenderChildSizeBox;

  bool _needsBuild = true;
  Element? _tempChild;
  Element? _child;

  /// 探测尺寸的临时小部件需要排除焦点、语义，尤其是焦点，如果不排除将会破坏正常布局的聚焦，
  /// 你还可以通过 [ElChildSizeBuilder.isTempLayout] 方法判断组件是否处于临时布局中
  Widget get tempChildWidget => ExcludeSemantics(
    child: ExcludeFocus(
      child: _ChildSizeInheritedWidget(child: widget.tempChild),
    ),
  );

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) visitor(_child!);
    if (_tempChild != null) visitor(_tempChild!);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _tempChild = updateChild(_tempChild, tempChildWidget, #tempChild);
    renderObject._rebuild = _rebuild;
  }

  @override
  void update(covariant RenderObjectWidget newWidget) {
    super.update(newWidget);
    _tempChild = updateChild(_tempChild, tempChildWidget, #tempChild);
    renderObject.markNeedsLayout();
    _needsBuild = true;
  }

  @override
  void markNeedsBuild() {
    renderObject.markNeedsLayout();
    _needsBuild = true;
  }

  @override
  void performRebuild() {
    renderObject.markNeedsLayout();
    _needsBuild = true;
    super.performRebuild();
  }

  @override
  void insertRenderObjectChild(
    covariant RenderObject child,
    covariant Object? slot,
  ) {
    if (slot == #tempChild) {
      renderObject.tempChild = child as RenderBox;
    } else if (slot == #child) {
      renderObject.child = child as RenderBox;
    }
  }

  @override
  void removeRenderObjectChild(
    covariant RenderObject child,
    covariant Object? slot,
  ) {
    if (slot == #tempChild) {
      renderObject.tempChild = null;
    } else if (slot == #child) {
      renderObject.child = null;
    }
  }

  @override
  void moveRenderObjectChild(
    covariant RenderObject child,
    covariant Object? oldSlot,
    covariant Object? newSlot,
  ) {
    assert(false);
  }

  /// 当 [_tempChild] 的尺寸发生变化时，需要重新构建 builder 代码块
  Size? _oldTempChildSize;

  void _rebuild(Constraints constraints) {
    void updateChildCallback() {
      Widget result = widget.builder(renderObject.tempChildSize);
      _child = updateChild(_child, result, #child);
      _needsBuild = false;
      _oldTempChildSize = renderObject.tempChildSize;
    }

    owner!.buildScope(
      this,
      _needsBuild || _oldTempChildSize != renderObject.tempChildSize
          ? updateChildCallback
          : null,
    );
  }
}

class _RenderChildSizeBox extends RenderShiftedBox {
  _RenderChildSizeBox(this._builderConstraints) : super(null);

  LayoutCallback? _rebuild;

  Size get tempChildSize => _tempChildSize!;
  Size? _tempChildSize;

  RenderBox? _tempChild;

  set tempChild(RenderBox? v) {
    if (_tempChild == v) return;
    if (_tempChild != null) {
      dropChild(_tempChild!);
    }
    _tempChild = v;
    if (_tempChild != null) {
      adoptChild(_tempChild!);
    }
  }

  BoxConstraints? _builderConstraints;

  set builderConstraints(BoxConstraints? v) {
    if (_builderConstraints != v) {
      _builderConstraints = v;
      markNeedsLayout();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _tempChild?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _tempChild?.detach();
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    if (_tempChild != null) visitor(_tempChild!);
  }

  @override
  void performLayout() {
    // 对临时子组件进行布局，它的作用只用于探测尺寸，不做渲染
    _tempChild!.layout(
      _builderConstraints ?? constraints.loosen(),
      parentUsesSize: true,
    );

    _tempChildSize = _tempChild!.size;

    // 调用 builder 代码块，将返回的 Widget 插入到 Element 树中
    if (_rebuild != null) invokeLayoutCallback(_rebuild!);

    if (child != null) {
      child!.layout(constraints.loosen(), parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      size = constraints.smallest;
    }
  }

  @override
  void dispose() {
    _tempChildSize = null;
    _rebuild = null;
    super.dispose();
  }
}

/// 子组件可以通过 [ElChildSizeBuilder.isTempLayout] 判断当前构建是否处于临时布局中，
/// 这样可以规避一些错误，例如：排除 [Focus] 焦点
class _ChildSizeInheritedWidget extends InheritedWidget {
  const _ChildSizeInheritedWidget({required super.child});

  @override
  bool updateShouldNotify(_ChildSizeInheritedWidget oldWidget) => false;
}
