import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show
        MouseTrackerAnnotation,
        PointerEnterEventListener,
        PointerExitEventListener;
import 'package:flutter/widgets.dart';

import 'dispatcher.dart';
import 'event.dart';
import 'state.dart';

/// 为任意子组件提供独立的指针与手势事件，不改变子组件的布局和绘制。
class ElEventView extends StatefulWidget {
  /// 创建事件宿主，命中、光标和禁用行为统一由 [event] 声明。
  const ElEventView({super.key, required this.event, required this.child});

  /// 指针、点击、拖拽、缩放旋转及事件传播配置。
  final ElEvent event;

  /// 子组件可通过 Builder 的后代 context 读取当前宿主的交互状态。
  final Widget child;

  /// 读取并订阅最近祖先事件宿主的全部状态，没有宿主时返回 null。
  static ElEventState? maybeOf(BuildContext context) =>
      _EventScope.read(context);

  @override
  State<ElEventView> createState() => _EventViewState();
}

/// 订阅最近事件宿主的指定交互状态，没有宿主时返回 false。
extension ElEventContextExt on BuildContext {
  /// 是否处于按压反馈中，仅在按压状态变化时重建当前消费者。
  bool get hasTap => _EventScope.read(this, _EventAspect.tap)?.hasTap ?? false;

  /// 是否有鼠标悬停，仅在悬停状态变化时重建当前消费者。
  bool get hasHover =>
      _EventScope.read(this, _EventAspect.hover)?.hasHover ?? false;
}

enum _EventAspect { tap, hover }

class _EventScope extends InheritedModel<_EventAspect> {
  const _EventScope({required this.data, required super.child});

  final ElEventState data;

  static ElEventState? read(BuildContext context, [_EventAspect? aspect]) =>
      InheritedModel.inheritFrom<_EventScope>(context, aspect: aspect)?.data;

  @override
  bool updateShouldNotify(_EventScope oldWidget) => data != oldWidget.data;

  @override
  bool updateShouldNotifyDependent(
    _EventScope oldWidget,
    Set<_EventAspect> dependencies,
  ) => dependencies.any(
    (aspect) => switch (aspect) {
      _EventAspect.tap => data.hasTap != oldWidget.data.hasTap,
      _EventAspect.hover => data.hasHover != oldWidget.data.hasHover,
    },
  );
}

class _EventViewState extends State<ElEventView> {
  late final _InteractionSource _source = _InteractionSource(
    widget.event.disabled,
    _onChanged,
  );
  bool _publishScheduled = false;

  void _onChanged() {
    if (!mounted) return;
    // 配置更新或拆树可能在渲染期间结清手势，此时延后发布，避免反向标脏祖先。
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_publishScheduled) return;
      _publishScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _publishScheduled = false;
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant ElEventView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _source.updateDisabled(widget.event.disabled);
  }

  @override
  Widget build(BuildContext context) => _EventScope(
    data: _source.snapshot,
    child: _EventRenderWidget(
      event: widget.event,
      source: _source,
      child: widget.child,
    ),
  );

  @override
  void dispose() {
    _source.onChanged = null;
    super.dispose();
  }
}

/// 保存输入状态，不引用样式；禁用只遮蔽真实悬停，恢复时仍能反映静止鼠标。
class _InteractionSource {
  _InteractionSource(this._disabled, this.onChanged);

  VoidCallback? onChanged;
  bool _disabled;
  bool _tap = false;
  bool _hover = false;

  ElEventState get snapshot => ElEventState(
    hasTap: !_disabled && _tap,
    hasHover: !_disabled && _hover,
    disabled: _disabled,
  );

  void updateDisabled(bool value) {
    if (_disabled == value) return;
    _disabled = value;
    if (value) {
      _tap = false;
    }
  }

  void updateTap(bool value) {
    if (_tap == value) return;
    _tap = value;
    if (!_disabled) onChanged?.call();
  }

  void updateHover(bool value) {
    if (_hover == value) return;
    _hover = value;
    if (!_disabled) onChanged?.call();
  }
}

class _EventRenderWidget extends SingleChildRenderObjectWidget {
  const _EventRenderWidget({
    required this.event,
    required this.source,
    required super.child,
  });

  final ElEvent event;
  final _InteractionSource source;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _EventBox(event, source, MediaQuery.maybeGestureSettingsOf(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _EventBox)
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
      ..event = event;
  }
}

class _EventBox extends RenderProxyBoxWithHitTestBehavior
    implements MouseTrackerAnnotation {
  _EventBox(ElEvent event, this._source, DeviceGestureSettings? gestureSettings)
    : super(behavior: event.behavior) {
    _dispatcher = ElEventDispatcher(this)
      ..hitBoundsContainsGlobal = _containsGlobal
      ..gestureSettings = gestureSettings
      ..onTapChanged = _source.updateTap
      ..event = event;
  }

  final _InteractionSource _source;
  final Set<int> _hoverDevices = <int>{};
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

  void _handleEnter(PointerEnterEvent event) {
    _hoverDevices.add(event.device);
    _source.updateHover(true);
    _dispatcher.handlePointerEnter(event);
  }

  void _handleExit(PointerExitEvent event) {
    _hoverDevices.remove(event.device);
    _source.updateHover(_hoverDevices.isNotEmpty);
    _dispatcher.handlePointerExit(event);
  }

  @override
  PointerEnterEventListener get onEnter => _handleEnter;

  @override
  PointerExitEventListener get onExit => _handleExit;

  @override
  bool get validForMouseTracker => attached;

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
