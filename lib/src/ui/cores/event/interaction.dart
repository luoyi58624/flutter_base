part of 'dispatcher.dart';

/// 只冻结真实输入的命中成员，手势冒泡和竞技场不在这里实现。
final class _InputRoute {
  _InputRoute(this.pointer, this.chain) : active = chain.toSet();
  final int pointer;
  final List<ElEventDispatcher> chain;
  final Set<ElEventDispatcher> active;
  ElEventDispatcher? winner;
  ElEventDispatcher? driver;
  Object? dragIdentity;
  ElEventDispatcher? requester;
  bool accepted = false;
}

final class _HostInput {
  _HostInput(this.route, this.down, this.generation)
    : lastEvent = down,
      initialGeneration = generation;
  final _InputRoute route;
  final PointerEvent down;
  int generation;
  final int initialGeneration;
  PointerEvent lastEvent;
  bool active = true;
  bool registered = false;
  bool pressRegistered = false;
  int tapGeneration = 0;
  bool eager = false;
  bool eagerRegistered = false;
  bool accepted = false;
  bool cancelSelfTap = false;
  bool allowScale = false;
  bool scaleAllowed = false;
  bool claiming = false;
  ElEventCallback? claimCallback;
  bool ended = false;
  bool tapVisible = false;
  bool tapObserved = false;
  bool rawStarted = false;
  bool tapEligible = true;
  bool inside = true;
}

final class _GestureSnapshot {
  _GestureSnapshot(this.input, this.generation, this.press);
  final _HostInput input;
  final int generation;
  final bool press;
}

/// 显式独占请求直接使用官方团队席位，不另建输入识别状态机。
final class _EagerClaim extends GestureArenaMember {
  _EagerClaim(this.host);
  final ElEventDispatcher host;
  @override
  void acceptGesture(int pointer) => host._accepted(pointer);
  @override
  void rejectGesture(int pointer) {
    host._claims.remove(pointer);
  }
}

extension _TapHost on ElEventDispatcher {
  void _tapDown(_HostInput input, PointerEvent event) {
    if (input.tapVisible || !input.active || !input.tapEligible) return;
    input.tapVisible = true;
    input.tapObserved = true;
    if (onTapChanged != null) _feedback.down(input, config);
    if (!input.pressRegistered) {
      final callback = _rawCallback(ElEventPhase.tapDown, event);
      _invoke(_handler(ElEventPhase.tapDown), callback);
      if (callback.propagationStopped) {
        // 纯 Down 观察者没有识别器，截断祖先候选时仍使用识别器的成员取消原语。
        for (final ancestor in input.route.chain.skip(
          input.route.chain.indexOf(this) + 1,
        )) {
          final ancestorInput = ancestor._inputs[event.pointer];
          if (ancestorInput == null) continue;
          ancestorInput.tapEligible = false;
          ancestor._cancelTap(
            ancestorInput,
            event,
            ElEventCancelReason.external,
          );
          ancestor._press?.cancelMember(event.pointer);
        }
      }
    }
  }

  void _tapUp(_HostInput input, PointerEvent event) {
    if (!input.tapObserved) return;
    input.tapVisible = false;
    if (!input.pressRegistered) {
      _invoke(
        _handler(ElEventPhase.tapUp),
        _rawCallback(ElEventPhase.tapUp, event),
      );
      _feedback.up(input, config);
    }
  }

  void _cancelTap(
    _HostInput input,
    PointerEvent event,
    ElEventCancelReason reason, {
    bool preserveFeedbackDuration = false,
  }) {
    if (!input.tapVisible) return;
    input.tapVisible = false;
    _feedback.cancel(input: input, preserveDuration: preserveFeedbackDuration);
    _invoke(
      _handler(ElEventPhase.tapCancel),
      _rawCallback(ElEventPhase.tapCancel, event, reason: reason),
    );
  }

  void _updateBounds(_HostInput input, PointerMoveEvent event) {
    if (!input.tapEligible) return;
    if (config.tapCancelOnMove) {
      if ((event.position - input.down.position).distance >
          config.tapCancelDistance) {
        input.tapEligible = false;
        _cancelTap(input, event, ElEventCancelReason.tapRejected);
      }
      return;
    }
    final inside = _contains(event.position);
    if (inside == input.inside) return;
    input.inside = inside;
    if (!inside) {
      _cancelTap(
        input,
        event,
        ElEventCancelReason.tapRejected,
        preserveFeedbackDuration: true,
      );
    } else {
      _tapDown(input, event);
      if (_hasPress) {
        _invoke(
          _handler(ElEventPhase.tapDown),
          _rawCallback(ElEventPhase.tapDown, event),
        );
      }
    }
  }
}

/// 只管理按压反馈的进入和退出，不参与手势识别、冒泡或所有权判定。
final class _TapFeedback {
  _TapFeedback(this.onChanged);
  final ValueChanged<bool> onChanged;
  _HostInput? _input;
  Timer? _enter;
  Timer? _leave;
  bool value = false;

  void _set(bool next) {
    if (value == next) return;
    value = next;
    onChanged(next);
  }

  void down(_HostInput input, ElEventConfig config) {
    _enter?.cancel();
    final firstDown = !identical(_input, input);
    if (firstDown) _leave?.cancel();
    _input = input;
    if (firstDown &&
        input.down.kind == PointerDeviceKind.touch &&
        config.delayTouchUp > Duration.zero) {
      _leave = Timer(config.delayTouchUp, () {
        _leave = null;
        if (identical(_input, input) && input.ended) cancel(input: input);
      });
    }
    final delay = input.down.kind == PointerDeviceKind.touch
        ? config.delayTouchDown
        : Duration.zero;
    if (delay == Duration.zero) {
      _set(true);
    } else {
      _enter = Timer(delay, () {
        if (identical(_input, input) &&
            input.active &&
            !input.ended &&
            input.tapVisible) {
          _set(true);
        }
      });
    }
  }

  void up(_HostInput input, ElEventConfig config) {
    if (!identical(_input, input)) return;
    _enter?.cancel();
    if (!value || input.down.kind != PointerDeviceKind.touch) {
      cancel(input: input);
      return;
    }
    if (!(_leave?.isActive ?? false)) cancel(input: input);
  }

  void cancel({_HostInput? input, bool preserveDuration = false}) {
    if (input != null && !identical(input, _input)) return;
    _enter?.cancel();
    _enter = null;
    if (!preserveDuration) {
      _leave?.cancel();
      _leave = null;
      _input = null;
    }
    _set(false);
  }
}
