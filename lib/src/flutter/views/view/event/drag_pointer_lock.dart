import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// 保留框架操作使用的全局输入锁，不参与普通手势识别。
@internal
final class DragPointerLock {
  DragPointerLock._();

  static RenderObject? _owner;

  /// 当前是否处于拖拽指针锁定期。
  static bool get isActive => _owner?.attached ?? false;

  /// [owner]（拖拽宿主 render）声明拖拽激活；后声明者接管且永不改变光标。
  static void claim(RenderObject owner) => _owner = owner;

  /// 拖拽结束/取消/宿主销毁时释放；仅当前 owner 的释放生效。
  static void release(RenderObject owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    if (owner.attached) {
      RendererBinding.instance.addPostFrameCallback((_) {
        if (!isActive) RendererBinding.instance.mouseTracker.updateAllDevices();
      });
      RendererBinding.instance.ensureVisualUpdate();
    }
  }

  @visibleForTesting
  static void debugReset() => _owner = null;
}

/// 锁激活期放在命中结果最前的屏障：吞事件但不下发任何光标换形命令。
final HitTestTarget dragPointerLockBarrier = const _DragPointerLockBarrier();

final class _DragPointerLockBarrier extends MouseTrackerAnnotation implements HitTestTarget {
  const _DragPointerLockBarrier();

  @override
  MouseCursor get cursor => MouseCursor.uncontrolled;

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {}
}
