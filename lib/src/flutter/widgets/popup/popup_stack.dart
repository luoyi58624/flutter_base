import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext, OverlayState;

/// 同一 Overlay 的锚定浮层注册表，以句柄身份区分浮层。
@internal
final class PopupStack {
  static final _stacks = Expando<PopupStack>();

  /// 用实际目标 Overlay 隔离局部弹层和不同窗口。
  static PopupStack forOverlay(OverlayState overlay) => _stacks[overlay] ??= PopupStack();

  /// 读取指定 Overlay 已存在的栈。
  static PopupStack? maybeOf(OverlayState overlay) => _stacks[overlay];

  final List<Object> _handles = [];
  final _changes = Map<Object, VoidCallback>.identity();
  Object? _event;
  Object? _eventHandle;
  final _backs = Map<Object, bool Function(BuildContext)>.identity();

  /// 返回最靠上的已登记接收者。
  ({Object owner, bool Function(BuildContext) onBack})? get backTarget {
    for (final handle in _handles.reversed) {
      if (_backs[handle] case final onBack?) return (owner: handle, onBack: onBack);
    }
    return null;
  }

  /// 注册到栈顶；重复注册保持原顺序。
  void register(Object handle, {VoidCallback? onChanged}) {
    if (_handles.any((item) => identical(item, handle))) return;
    _handles.add(handle);
    if (onChanged != null) _changes[handle] = onChanged;
    for (final callback in _changes.values.toList()) {
      callback();
    }
  }

  /// 移除句柄；未注册时不做处理。
  void unregister(Object handle) {
    final count = _handles.length;
    _handles.removeWhere((item) => identical(item, handle));
    _changes.remove(handle);
    _backs.remove(handle);
    if (identical(_eventHandle, handle)) _eventHandle = null;
    if (count != _handles.length) {
      for (final callback in _changes.values.toList()) {
        callback();
      }
    }
  }

  /// 更新同一层的返回动作，保持原绘制顺序。
  void setBack(Object handle, bool Function(BuildContext)? onBack) {
    if (onBack == null || !_handles.any((item) => identical(item, handle))) {
      _backs.remove(handle);
    } else {
      _backs[handle] = onBack;
    }
  }

  /// 是否为当前栈顶。
  bool isTopmost(Object handle) => _handles.isNotEmpty && identical(_handles.last, handle);

  /// 为同一次原始事件固定栈顶，避免同步关顶层后该事件继续关闭下一层。
  bool isTopmostForEvent(Object handle, Object event) {
    if (!identical(_event, event)) {
      _event = event;
      _eventHandle = _handles.isEmpty ? null : _handles.last;
    }
    return identical(_eventHandle, handle);
  }
}
