import 'dart:async' show Completer, scheduleMicrotask;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, VoidCallback, internal;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter/widgets.dart';

import 'scope.dart' show popupViewId;

/// 一次 OverlayEntry 挂载，分别结清逻辑关闭结果与实际摘除。
@internal
final class PopupSession<T> {
  /// 创建会话，安装前由调用方根据 context 确定目标 Overlay。
  PopupSession(this.overlay, {required this.viewId, required WidgetBuilder builder, bool maintainState = false})
    : _entry = OverlayEntry(builder: builder, maintainState: maintainState);

  final OverlayState overlay;
  final int viewId;
  final OverlayEntry _entry;
  final _open = ValueNotifier(true);
  final _result = Completer<T?>();
  final _removed = Completer<void>();
  bool _attached = false;
  bool _removing = false;

  /// 逻辑关闭同步生效，面板可据此启动退场。
  ValueListenable<bool> get open => _open;

  /// 首次接受关闭时结清。
  Future<T?> get result => _result.future;

  /// 面板从 Overlay 摘除后结清。
  Future<void> get removed => _removed.future;

  /// 将会话安装到已解析的 Overlay，首次挂载前也跟踪宿主卸载。
  void insert({OverlayEntry? below, VoidCallback? onInserted}) {
    if (_attached || _removing) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) => insert(below: below, onInserted: onInserted));
      return;
    }
    if (!overlay.mounted || popupViewId(overlay.context) != viewId) {
      remove();
      return;
    }
    _attached = true;
    _entry.addListener(_mountChanged);
    overlay.insert(_entry, below: below);
    scheduler.addPostFrameCallback((_) {
      if (!_attached || _removing || _entry.mounted) return;
      // Overlay 可能在首次绘制前被卸载，届时 entry 不会收到 unmount。
      if (!overlay.mounted) remove();
    });
    onInserted?.call();
  }

  /// 接受关闭并结清结果，由挂载方在退场完成后调用 remove。
  bool close(BuildContext context, [T? value]) {
    if (!_open.value || !overlay.mounted || popupViewId(context) != viewId) return false;
    final boundary = context.getElementForInheritedWidgetOfExactType<LookupBoundary>();
    var belongsToOverlay = false;
    context.visitAncestorElements((element) {
      if (identical(element, boundary)) return false;
      if (!identical(element, overlay.context)) return true;
      belongsToOverlay = true;
      return false;
    });
    if (!belongsToOverlay) return false;
    final accepted = _accept(value);
    if (!_entry.mounted) remove();
    return accepted;
  }

  bool _accept(T? value) {
    if (!_open.value) return false;
    _result.complete(value);
    _open.value = false;
    return true;
  }

  /// 摘除会话，重复调用无副作用。
  void remove() {
    if (_removing) return;
    _removing = true;
    _accept(null);
    if (_attached) _entry.remove();
    final stillMounted = _entry.mounted;
    if (!stillMounted) _entry.removeListener(_mountChanged);
    _entry.dispose();
    if (!stillMounted) _finish();
  }

  void _mountChanged() {
    if (_entry.mounted) return;
    // 离树通知在 OverlayEntry 自己的 ValueNotifier 派发中，延后释放 entry。
    if (_removing) {
      _finish();
    } else {
      scheduleMicrotask(remove);
    }
  }

  void _finish() {
    if (_removed.isCompleted) return;
    _removed.complete();
    // 关闭监听可能同步摘除零时长动画的 entry。
    scheduleMicrotask(_open.dispose);
  }
}
