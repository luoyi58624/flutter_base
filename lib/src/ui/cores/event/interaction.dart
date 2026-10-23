part of 'render.dart';

/// 元素输入仅保存命中链、几何资格和反馈；不计算手势与竞技场归属。
final class _ElementInput {
  _ElementInput(this.path, this.down, this.tapVersion, this.transformVersion)
    : lastEvent = down;
  final List<RenderElEvent> path;
  final PointerEvent down;
  final int tapVersion;
  final int transformVersion;
  PointerEvent lastEvent;
  bool active = true;
  bool registered = false;
  bool pressRegistered = false;
  bool rawStarted = false;
  bool accepted = false;
  bool ended = false;
  bool scaleAllowed = false;
  bool claiming = false;
  bool tapVisible = false;
  bool tapObserved = false;
  bool tapEligible = true;
  bool inside = true;
  (ElEventCallback, bool, bool)? claim;
  GestureArenaEntry? entry;
}

/// 原始指针回调可显式申请官方席位，落败后不能重新报名。
final class _InputClaim extends GestureArenaMember {
  _InputClaim(this.element);
  final RenderElEvent element;
  @override
  void acceptGesture(int pointer) => element._accepted(pointer);
  @override
  void rejectGesture(int pointer) {
    element._inputs[pointer]?.entry = null;
  }
}

extension _TapHost on RenderElEvent {
  void _tapDown(_ElementInput input, PointerEvent event) {
    if (input.tapVisible || !input.active || !input.tapEligible) return;
    if (input.path.any(
      (member) =>
          !identical(member, this) &&
          member._inputs[event.pointer]?.claim != null,
    )) {
      return;
    }
    input.tapVisible = true;
    input.tapObserved = true;
    if (onTapChanged != null) _feedback.down(input, config);
    if (!input.pressRegistered) {
      final callback = _rawCallback(ElEventPhase.tapDown, event);
      _invoke(_handler(ElEventPhase.tapDown), callback);
      if (callback.propagationStopped) {
        // 纯 Down 观察者没有识别器，截断祖先候选时仍使用识别器的成员取消原语。
        for (final ancestor in input.path.skip(input.path.indexOf(this) + 1)) {
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

  void _tapUp(_ElementInput input, PointerEvent event) {
    if (!input.tapObserved) return;
    input.tapVisible = false;
    if (!input.pressRegistered) {
      _invoke(
        _handler(ElEventPhase.tapUp),
        _rawCallback(ElEventPhase.tapUp, event),
      );
      _feedback.up(input);
    }
  }

  void _cancelTap(
    _ElementInput input,
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

  void _updateBounds(_ElementInput input, PointerMoveEvent event) {
    if (!input.tapEligible) return;
    if (config.tapCancelOnMove == true) {
      if ((event.position - input.down.position).distance > _tapDistance) {
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
  _ElementInput? _input;
  Timer? _enter;
  Timer? _leave;
  bool value = false;

  void _set(bool next) {
    if (value == next) return;
    value = next;
    onChanged(next);
  }

  void down(_ElementInput input, ElEventConfig config) {
    final minimum = config.delayTouchUp ?? const Duration(milliseconds: 100);
    final enterDelay = config.delayTouchDown ?? Duration.zero;
    assert(minimum >= Duration.zero && enterDelay >= Duration.zero);
    _enter?.cancel();
    final firstDown = !identical(_input, input);
    if (firstDown) _leave?.cancel();
    _input = input;
    if (firstDown &&
        input.down.kind == PointerDeviceKind.touch &&
        minimum > Duration.zero) {
      _leave = Timer(minimum, () {
        _leave = null;
        if (identical(_input, input) && input.ended) cancel(input: input);
      });
    }
    final delay = input.down.kind == PointerDeviceKind.touch
        ? enterDelay
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

  void up(_ElementInput input) {
    if (!identical(_input, input)) return;
    _enter?.cancel();
    if (!value || input.down.kind != PointerDeviceKind.touch) {
      cancel(input: input);
      return;
    }
    if (!(_leave?.isActive ?? false)) cancel(input: input);
  }

  void cancel({_ElementInput? input, bool preserveDuration = false}) {
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
