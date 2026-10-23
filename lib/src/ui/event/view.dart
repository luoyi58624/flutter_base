import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'
    show
        MouseTrackerAnnotation,
        PointerEnterEventListener,
        PointerExitEventListener;
import 'package:flutter/widgets.dart';

import 'dispatcher.dart';
import 'event.dart';

/// 为任意子组件提供独立的指针与手势事件，不改变子组件的布局和绘制。
class ElEventView extends SingleChildRenderObjectWidget {
  /// 创建事件宿主，命中、光标和禁用行为统一由 [event] 声明。
  const ElEventView({super.key, required this.event, required Widget child})
    : super(child: child);

  /// 指针、点击、拖拽、缩放旋转及事件传播配置。
  final ElEvent event;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _EventBox(event, MediaQuery.maybeGestureSettingsOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _EventBox)
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
      ..event = event;
  }
}

class _EventBox extends RenderProxyBoxWithHitTestBehavior
    implements MouseTrackerAnnotation {
  _EventBox(ElEvent event, DeviceGestureSettings? gestureSettings)
    : super(behavior: event.behavior) {
    _dispatcher = ElEventDispatcher(this)
      ..hitBoundsContainsGlobal = _containsGlobal
      ..gestureSettings = gestureSettings
      ..event = event;
  }

  late final ElEventDispatcher _dispatcher;

  set gestureSettings(DeviceGestureSettings? value) =>
      _dispatcher.gestureSettings = value;

  set event(ElEvent value) {
    _dispatcher.event = value;
    behavior = _dispatcher.event?.behavior ?? value.behavior;
  }

  bool _containsGlobal(Offset position) {
    if (!attached || !hasSize) return false;
    final inverse = Matrix4.tryInvert(getTransformTo(null));
    return inverse != null &&
        size.contains(MatrixUtils.transformPoint(inverse, position));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_dispatcher.disabled) return super.hitTest(result, position: position);
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) =>
      _dispatcher.handleEvent(event, entry);

  @override
  MouseCursor get cursor => _dispatcher.cursor;

  @override
  PointerEnterEventListener? get onEnter =>
      _dispatcher.disabled || _dispatcher.event?.onPointerEnter == null
      ? null
      : _dispatcher.handlePointerEnter;

  @override
  PointerExitEventListener? get onExit =>
      _dispatcher.disabled || _dispatcher.event?.onPointerExit == null
      ? null
      : _dispatcher.handlePointerExit;

  @override
  bool get validForMouseTracker =>
      attached &&
      (_dispatcher.disabled ||
          cursor != MouseCursor.defer ||
          onEnter != null ||
          onExit != null);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _dispatcher.attach();
  }

  @override
  void detach() {
    _dispatcher.detach(preserveEvent: true);
    super.detach();
  }

  @override
  void dispose() {
    _dispatcher.dispose();
    super.dispose();
  }
}
