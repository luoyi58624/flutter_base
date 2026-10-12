import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../dart.dart';

/// 调试小部件
class ElDebugWidget extends SingleChildRenderObjectWidget {
  const ElDebugWidget({
    super.key,
    this.debugLabel,
    this.checkElementMount = false,
    this.checkElementUpdate = false,
    this.checkElementUnmount = false,
    this.checkRenderLayout = false,
    this.checkRenderPaint = false,
    this.filterTime,
    required super.child,
  });

  /// 调试标签
  final String? debugLabel;

  /// 检查 Element 挂载
  final bool checkElementMount;

  /// 检查 Element 更新
  final bool checkElementUpdate;

  /// 检查 Element 卸载
  final bool checkElementUnmount;

  /// 检查重排
  final bool checkRenderLayout;

  /// 检查重绘
  final bool checkRenderPaint;

  /// 过滤时间打印最低阈值
  final Duration? filterTime;

  @override
  SingleChildRenderObjectElement createElement() {
    return _DebugElement(this);
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDebug(
      debugLabel,
      checkRenderLayout,
      checkRenderPaint,
      filterTime,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context,
      covariant RenderObject renderObject,
      ) {
    renderObject as _RenderDebug
      ..debugLabel = debugLabel
      ..checkRenderLayout = checkRenderLayout
      ..checkRenderPaint = checkRenderPaint
      ..filterTime = filterTime;
  }
}

class _DebugElement extends SingleChildRenderObjectElement {
  _DebugElement(super.widget);

  @override
  ElDebugWidget get widget => super.widget as ElDebugWidget;

  @override
  void mount(Element? parent, Object? newSlot) {
        () {
      super.mount(parent, newSlot);
    }.time(
      enabled: widget.checkElementMount,
      debugLabel: widget.debugLabel,
      logPrefix: 'Element mount: ',
      filterTime: widget.filterTime,
      log: ElLog.d,
    );
  }

  @override
  void update(ElDebugWidget newWidget) {
        () {
      super.update(newWidget);
    }.time(
      enabled: newWidget.checkElementUpdate,
      debugLabel: newWidget.debugLabel,
      logPrefix: 'Element update: ',
      filterTime: newWidget.filterTime,
      log: ElLog.i,
    );
  }

  @override
  void unmount() {
        () {
      super.unmount();
    }.time(
      enabled: widget.checkElementUnmount,
      debugLabel: widget.debugLabel,
      logPrefix: 'Element unmount: ',
      filterTime: widget.filterTime,
      log: ElLog.e,
    );
  }
}

class _RenderDebug extends RenderProxyBox {
  _RenderDebug(
      this._debugLabel,
      this._checkRenderLayout,
      this._checkRenderPaint,
      this._filterTime,
      );

  String? _debugLabel;

  set debugLabel(String? v) {
    if (_debugLabel == v) return;
    _debugLabel = v;
    markNeedsLayout();
  }

  bool _checkRenderLayout;

  set checkRenderLayout(bool v) {
    if (_checkRenderLayout == v) return;
    _checkRenderLayout = v;
    markNeedsLayout();
  }

  bool _checkRenderPaint;

  set checkRenderPaint(bool v) {
    if (_checkRenderPaint == v) return;
    _checkRenderPaint = v;
    markNeedsPaint();
  }

  Duration? _filterTime;

  set filterTime(Duration? v) {
    if (_filterTime == v) return;
    _filterTime = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
        () {
      super.performLayout();
    }.time(
      enabled: _checkRenderLayout,
      debugLabel: _debugLabel,
      logPrefix: 'RenderObject performLayout: ',
      filterTime: _filterTime,
      log: ElLog.e,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
        () {
      super.paint(context, offset);
    }.time(
      enabled: _checkRenderPaint,
      debugLabel: _debugLabel,
      logPrefix: 'RenderObject paint: ',
      filterTime: _filterTime,
      log: ElLog.w,
    );
  }
}
