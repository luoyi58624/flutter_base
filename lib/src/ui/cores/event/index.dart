import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/dart.dart';

import 'render.dart';
import 'event.dart';

export 'event.dart'
    show
        ElEvent,
        ElEventExt,
        ElDragProxy,
        ElDragProxyExt,
        ElEventConfig,
        ElEventConfigExt,
        ElEventHandler,
        ElEventPhase,
        ElEventCancelReason,
        ElEventCallback;

export 'recognizers/index.dart'
    show
        ElPressGestureRecognizer,
        ElTransformGestureRecognizer,
        ElGestureArenaTeam,
        ElGesturePhase,
        ElGestureCancelReason,
        ElGestureDetails,
        ElPressGestureDetails,
        ElTransformGestureDetails,
        ElPressGestureCallback,
        ElTransformGestureCallback;

extension ElEventContextExt on BuildContext {
  /// 是否处于按压反馈中，仅在按压状态变化时重建当前消费者。
  bool get hasTap => ElEventView.hasTap(this);

  /// 是否有鼠标悬停，仅在悬停状态变化时重建当前消费者。
  bool get hasHover => ElEventView.hasHover(this);
}

/// 为任意子组件提供独立的指针与手势事件，不改变子组件的布局和绘制。
class ElEventView extends StatefulWidget {
  /// 创建事件宿主，命中、光标和禁用行为统一由 [event] 声明。
  const ElEventView({super.key, this.event = const ElEvent(), required this.child});

  /// 指针、点击、拖拽、缩放旋转及事件传播配置。
  final ElEvent event;

  /// 子组件可通过 Builder 的后代 context 读取当前宿主的交互状态。
  final Widget child;

  static bool hasTap(BuildContext context) =>
      InheritedModel.inheritFrom<_EventScope>(context, aspect: _EventAspect.tap)?.data.hasTap ?? false;

  static bool hasHover(BuildContext context) =>
      InheritedModel.inheritFrom<_EventScope>(context, aspect: _EventAspect.hover)?.data.hasHover ?? false;

  @override
  State<ElEventView> createState() => _EventViewState();
}

class _EventViewState extends State<ElEventView> {
  late final _InteractionSource _source = _InteractionSource(widget.event.disabled, _onChanged);
  bool _publishScheduled = false;

  void _onChanged() {
    if (!mounted) return;
    // 配置更新或拆树可能在渲染期间结清手势，此时延后发布，避免反向标脏祖先。
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
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
    child: _EventRenderWidget(event: widget.event, source: _source, child: widget.child),
  );

  @override
  void dispose() {
    _source.onChanged = null;
    super.dispose();
  }
}

enum _EventAspect { tap, hover }

class _EventScope extends InheritedModel<_EventAspect> {
  const _EventScope({required this.data, required super.child});

  final ElEventState data;

  @override
  bool updateShouldNotify(_EventScope oldWidget) => data != oldWidget.data;

  @override
  bool updateShouldNotifyDependent(_EventScope oldWidget, Set<_EventAspect> dependencies) => dependencies.any(
    (aspect) => switch (aspect) {
      _EventAspect.tap => data.hasTap != oldWidget.data.hasTap,
      _EventAspect.hover => data.hasHover != oldWidget.data.hasHover,
    },
  );
}

/// 保存输入状态，不引用样式；禁用只遮蔽真实悬停，恢复时仍能反映静止鼠标。
class _InteractionSource {
  _InteractionSource(this._disabled, this.onChanged);

  VoidCallback? onChanged;
  bool _disabled;
  bool _tap = false;
  bool _hover = false;

  ElEventState get snapshot =>
      ElEventState(hasTap: !_disabled && _tap, hasHover: !_disabled && _hover, disabled: _disabled);

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
  const _EventRenderWidget({required this.event, required this.source, required super.child});

  final ElEvent event;
  final _InteractionSource source;

  @override
  RenderObject createRenderObject(BuildContext context) => ElRenderEvent(
    event: event,
    onTapChanged: source.updateTap,
    onHoverChanged: source.updateHover,
    gestureSettings: MediaQuery.maybeGestureSettingsOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as ElRenderEvent)
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
      ..event = event;
  }
}
