import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 同一帧测量内容并构建外层结构，测量和显示复用同一个内容实例。
class ElChildSizeBuilder2 extends RenderObjectWidget {
  /// 创建尺寸构建器，builder 的 child 参数用于放置已测量的内容。
  const ElChildSizeBuilder2({
    super.key,
    required this.child,
    required this.builder,
    this.constraints,
  });

  /// 需要测量的内容，其 State 在测量和显示之间保留。
  final Widget child;

  /// 根据测得的尺寸构建结果，并通过第二个参数放置原内容。
  final Widget Function(Size size, Widget child) builder;

  /// 测量约束，默认使用父约束移除最小尺寸限制后的值。
  final BoxConstraints? constraints;

  /// 判断内容当前是否位于不显示的测量位置。
  static bool isTempLayout(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MeasurementScope>() != null;

  @override
  RenderObjectElement createElement() => _SizeBuilderElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeBuilder();
}

enum _Slot { probe, result }

class _SizeBuilderElement extends RenderObjectElement {
  _SizeBuilderElement(super.widget);

  @override
  ElChildSizeBuilder2 get widget => super.widget as ElChildSizeBuilder2;

  @override
  _RenderSizeBuilder get renderObject =>
      super.renderObject as _RenderSizeBuilder;

  @override
  BuildScope get buildScope => _buildScope;

  late final BuildScope _buildScope = BuildScope(
    scheduleRebuild: _scheduleBuild,
  );
  final _contentKey = GlobalKey();
  Element? _probe;
  Element? _result;
  _ContentSlotElement? _contentSlot;
  bool _measuring = false;
  bool _needsBuild = true;
  bool _needsMeasurement = true;
  bool _active = false;
  int? _frameCallbackId;
  bool _inLayout = false;
  Size? _measuredSize;
  BoxConstraints? _lastConstraints;
  FocusNode? _focusedContent;

  Widget get _content => _Content(
    key: _contentKey,
    onNeedsLayout: _invalidateMeasurement,
    child: widget.child,
  );

  Widget _probeWidget(Widget child) => TickerMode(
    enabled: false,
    child: ExcludeFocus(
      child: ExcludeSemantics(child: _MeasurementScope(child: child)),
    ),
  );

  void _invalidateMeasurement() {
    _needsMeasurement = true;
    // 内容可能处于自己的布局边界内，不能只等祖先自然收到布局失效。
    if (!_inLayout) _scheduleBuild();
  }

  void _scheduleBuild() {
    if (!_active) return;
    // 固定约束会截断渲染布局失效的传播，内容重建也必须使测量缓存失效。
    if (!_inLayout) _needsMeasurement = true;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase != SchedulerPhase.idle &&
        phase != SchedulerPhase.postFrameCallbacks) {
      renderObject.markNeedsLayout();
      return;
    }
    if (_frameCallbackId != null) return;
    _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameCallbackId = null;
      if (_active) renderObject.markNeedsLayout();
    });
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _active = true;
    renderObject._layout = _layout;
  }

  @override
  void update(ElChildSizeBuilder2 newWidget) {
    super.update(newWidget);
    _needsBuild = true;
    _scheduleBuild();
  }

  @override
  void markNeedsBuild() {
    _needsBuild = true;
    _scheduleBuild();
  }

  @override
  void performRebuild() {
    _needsBuild = true;
    _scheduleBuild();
    super.performRebuild();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
    _needsBuild = true;
    _scheduleBuild();
  }

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void unmount() {
    if (_frameCallbackId != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(_frameCallbackId!);
      _frameCallbackId = null;
    }
    renderObject._layout = null;
    _probe = null;
    _result = null;
    _contentSlot = null;
    _focusedContent = null;
    super.unmount();
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_probe != null) visitor(_probe!);
    if (_result != null) visitor(_result!);
  }

  @override
  void forgetChild(Element child) {
    if (child == _probe) _probe = null;
    if (child == _result) _result = null;
    super.forgetChild(child);
  }

  void _prepareMeasurement() {
    final focused = FocusManager.instance.primaryFocus;
    final root = _contentKey.currentContext;
    final context = focused?.context;
    if (root != null && context != null) {
      var inside = identical(root, context);
      context.visitAncestorElements((ancestor) {
        if (identical(ancestor, root)) inside = true;
        return !inside;
      });
      if (inside) _focusedContent = focused;
    }
    _measuring = true;
    _probe = updateChild(_probe, _probeWidget(_content), _Slot.probe);
    // 内容已移到测量位置，刷新旧插槽，清理它对 GlobalKey 的旧配置。
    _contentSlot?.rebuild(force: true);
  }

  void _buildResult() {
    _measuring = false;
    Widget result;
    try {
      result = widget.builder(_measuredSize!, _ContentSlot(this));
    } catch (error, stack) {
      final details = FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'flutter_base',
        context: ErrorDescription('构建 ElChildSizeBuilder2 内容时'),
      );
      FlutterError.reportError(details);
      result = ErrorWidget.builder(details);
    }
    _result = updateChild(_result, result, _Slot.result);
    // builder 可以复用旧 Widget，仍需将同一份内容恢复到它的插槽。
    _contentSlot?.rebuild(force: true);
    if (_contentSlot != null) {
      _probe = updateChild(
        _probe,
        _probeWidget(SizedBox.shrink()),
        _Slot.probe,
      );
      final focused = _focusedContent;
      if (focused?.context?.mounted == true && focused!.canRequestFocus) {
        focused.requestFocus();
      }
    }
    _focusedContent = null;
    _needsBuild = false;
  }

  void _layout(BoxConstraints constraints) {
    _inLayout = true;
    try {
      _layoutContent(constraints);
    } finally {
      _inLayout = false;
    }
  }

  void _layoutContent(BoxConstraints constraints) {
    // 先应用内容自身的 setState，渲染尺寸失效标记才能用于本帧的测量决策。
    owner!.buildScope(this);
    final needsMeasurement =
        _needsBuild ||
        _needsMeasurement ||
        _measuredSize == null ||
        _lastConstraints != constraints;
    if (needsMeasurement) {
      owner!.buildScope(this, _prepareMeasurement);
      renderObject.probe!.layout(
        widget.constraints ?? constraints.loosen(),
        parentUsesSize: true,
      );
      final measured = renderObject.probe!.size;
      final size = Size(measured.width, measured.height);
      final changed = size != _measuredSize;
      _measuredSize = size;
      _lastConstraints = constraints;
      // 每次迁移后都恢复插槽，尺寸相同也不重新创建内容 State。
      owner!.buildScope(this, _buildResult);
      if (changed) renderObject.markNeedsSemanticsUpdate();
    }
    renderObject.child?.layout(constraints.loosen(), parentUsesSize: true);
    _needsMeasurement = false;
  }

  @override
  void insertRenderObjectChild(RenderObject child, _Slot slot) {
    if (slot == _Slot.probe) {
      renderObject.probe = child as RenderBox;
    } else {
      renderObject.child = child as RenderBox;
    }
  }

  @override
  void removeRenderObjectChild(RenderObject child, _Slot slot) {
    if (slot == _Slot.probe) {
      renderObject.probe = null;
    } else {
      renderObject.child = null;
    }
  }

  @override
  void moveRenderObjectChild(RenderObject child, _Slot oldSlot, _Slot newSlot) {
    removeRenderObjectChild(child, oldSlot);
    insertRenderObjectChild(child, newSlot);
  }
}

class _ContentSlot extends Widget {
  const _ContentSlot(this.owner);
  final _SizeBuilderElement owner;
  @override
  Element createElement() => _ContentSlotElement(this);
}

class _ContentSlotElement extends ComponentElement {
  _ContentSlotElement(super.widget);
  _SizeBuilderElement get _owner => (widget as _ContentSlot).owner;
  @override
  Widget build() {
    _owner._contentSlot = this;
    return _owner._measuring ? SizedBox.shrink() : _owner._content;
  }

  @override
  void update(_ContentSlot newWidget) {
    super.update(newWidget);
    rebuild(force: true);
  }

  @override
  void deactivate() {
    if (identical(_owner._contentSlot, this)) _owner._contentSlot = null;
    super.deactivate();
  }
}

class _Content extends SingleChildRenderObjectWidget {
  const _Content({
    super.key,
    required this.onNeedsLayout,
    required super.child,
  });
  final VoidCallback onNeedsLayout;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderContent(onNeedsLayout);
}

class _RenderContent extends RenderProxyBox {
  _RenderContent(this._onNeedsLayout);
  final VoidCallback _onNeedsLayout;
  @override
  void markNeedsLayout() {
    _onNeedsLayout();
    super.markNeedsLayout();
  }
}

class _MeasurementScope extends InheritedWidget {
  const _MeasurementScope({required super.child});
  @override
  bool updateShouldNotify(_MeasurementScope oldWidget) => false;
}

class _RenderSizeBuilder extends RenderShiftedBox {
  _RenderSizeBuilder() : super(null);
  LayoutCallback<BoxConstraints>? _layout;
  RenderBox? _probe;
  RenderBox? get probe => _probe;
  set probe(RenderBox? value) {
    if (value == _probe) return;
    if (_probe != null) dropChild(_probe!);
    _probe = value;
    if (_probe != null) adoptChild(_probe!);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _probe?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _probe?.detach();
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    if (_probe != null) redepthChild(_probe!);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    if (_probe != null) visitor(_probe!);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (child != null) visitor(child!);
  }

  @override
  void performLayout() {
    if (_layout != null) invokeLayoutCallback(_layout!);
    size = child == null
        ? constraints.smallest
        : constraints.constrain(child!.size);
  }

  @override
  void dispose() {
    _layout = null;
    super.dispose();
  }
}
