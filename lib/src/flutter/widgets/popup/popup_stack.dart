import 'package:flutter/foundation.dart';

/// 进程内浮层的 LIFO 注册表，以句柄身份区分浮层。
abstract final class ElPopupStack {
  static final List<Object> _handles = [];
  static final _changes = Map<Object, VoidCallback>.identity();
  static Object? _event;
  static Object? _eventHandle;

  /// 注册到栈顶；重复注册保持原顺序。
  static void register(Object handle, {VoidCallback? onChanged}) {
    if (_handles.any((item) => identical(item, handle))) return;
    _handles.add(handle);
    if (onChanged != null) _changes[handle] = onChanged;
    for (final callback in _changes.values.toList()) {
      callback();
    }
  }

  /// 移除句柄；未注册时不做处理。
  static void unregister(Object handle) {
    final count = _handles.length;
    _handles.removeWhere((item) => identical(item, handle));
    _changes.remove(handle);
    if (identical(_eventHandle, handle)) _eventHandle = null;
    if (count != _handles.length) {
      for (final callback in _changes.values.toList()) {
        callback();
      }
    }
  }

  /// 是否为当前栈顶。
  static bool isTopmost(Object handle) => _handles.isNotEmpty && identical(_handles.last, handle);

  /// 为同一次原始事件固定栈顶，避免同步关顶层后该事件继续关闭下一层。
  static bool isTopmostForEvent(Object handle, Object event) {
    if (!identical(_event, event)) {
      _event = event;
      _eventHandle = _handles.isEmpty ? null : _handles.last;
    }
    return identical(_eventHandle, handle);
  }
}
