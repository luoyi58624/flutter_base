part of '../dispatcher.dart';

/// 鼠标侧键状态机（右键 / 中键 / 前进 / 后退），nearest-target-wins、不冒泡。
///
/// ## 取消语义（对齐主键 onTap / onTapUp）
///
/// - `*Tap`：与 [ElEvent.onTap] 相同——按下后移动越过
///   [ElEventConfig.tapCancelDistance] 即**永久**取消（移回原位也不恢复）；
/// - `*TapUp`：与 [ElEvent.onTapUp] 的抬起语义相同——不受移动影响，
///   同一指针抬起即 fire（对齐 DOM mouseup 恒触发）。
final class _SideButtonMachine {
  _SideButtonMachine(
    this.host,
    this.buttonMask,
    this.downPhase,
    this.upPhase,
    this.tapPhase, {
    this.overrideButtons,
  });

  final ElEventDispatcher host;
  final int buttonMask;
  final ElEventPhase downPhase;
  final ElEventPhase upPhase;
  final ElEventPhase tapPhase;

  /// secondary/tertiary 语义链 fire 时覆盖 buttons（对齐旧实现）；
  /// forward/back 使用原始事件 buttons。
  final int? overrideButtons;

  int? _pointer;
  Offset? _downPosition;

  /// 移动越界后置位：`*Tap` 永久取消，`*TapUp` 不受影响。
  bool _tapCanceled = false;

  bool get hasPointer => _pointer != null;

  double get _cancelDistance => host.config.tapCancelDistance;

  void feedDown(_PointerSequence seq, PointerDownEvent event) {
    if ((event.buttons & buttonMask) == 0) return;
    _pointer = event.pointer;
    _downPosition = event.position;
    _tapCanceled = false;
    host._fire(
      seq,
      downPhase,
      event.position,
      originalEvent: event,
      buttonsOverride: overrideButtons,
      selfOnly: true,
    );
  }

  void feedMove(PointerMoveEvent event) {
    if (_tapCanceled || _pointer != event.pointer) return;
    final down = _downPosition;
    if (down == null) return;
    if ((event.position - down).distance > _cancelDistance) _tapCanceled = true;
  }

  void feedUp(_PointerSequence seq, PointerUpEvent event) {
    final down = _downPosition;
    if (down == null || _pointer != event.pointer) return;
    final tapCanceled = _tapCanceled;
    _pointer = null;
    _downPosition = null;
    _tapCanceled = false;
    host._fire(
      seq,
      upPhase,
      event.position,
      originalEvent: event,
      buttonsOverride: overrideButtons,
      selfOnly: true,
    );
    // 终点距离兜底与越界置位并存：平台可能在没有 move 事件的情况下让 up
    // 位置跳变（合成位置），仅靠 move 置位挡不住这种情形。
    if (!tapCanceled && (event.position - down).distance <= _cancelDistance) {
      host._fire(
        seq,
        tapPhase,
        event.position,
        originalEvent: event,
        buttonsOverride: overrideButtons,
        selfOnly: true,
      );
    }
  }

  void feedCancel(PointerEvent event) {
    if (_pointer != event.pointer) return;
    clear();
  }

  void feedRemoved(int pointer) {
    if (_pointer != pointer) return;
    clear();
  }

  void clear() {
    _pointer = null;
    _downPosition = null;
    _tapCanceled = false;
  }
}
