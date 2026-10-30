import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

/// Defers structural scroll viewport event rewiring while a pointer sequence is held.
///
/// The dispatcher itself preserves live pointer state across non-null event
/// configuration updates. This latch is for scroll-only structure changes such
/// as axis, physics, gesture settings, or drag thresholds: those should not
/// change the interpretation of an already held pointer or pan-zoom sequence.
final class ScrollTouchEventSyncLatch {
  final Set<int> _pointers = <int>{};
  final Set<int> _panZoomPointers = <int>{};
  final List<VoidCallback> _deferredCallbacks = <VoidCallback>[];
  int? _pendingFlushPointer;
  int? _pendingPanZoomFlushPointer;
  bool _deferred = false;

  bool get active => _pointers.isNotEmpty || _panZoomPointers.isNotEmpty;
  bool get hasDeferredSync => _deferred;

  bool deferIfActive() {
    if (!active) return false;
    markDeferred();
    return true;
  }

  bool deferCallbackIfActive(VoidCallback callback) {
    if (!active) return false;
    deferCallback(callback);
    return true;
  }

  void deferCallback(VoidCallback callback) {
    markDeferred();
    _deferredCallbacks.add(callback);
  }

  void markDeferred() {
    _deferred = true;
  }

  bool beforeDispatch(PointerEvent event) {
    if (event is PointerPanZoomStartEvent) {
      _panZoomPointers.add(event.pointer);
      return false;
    }
    if (event is PointerPanZoomEndEvent) {
      if (!_panZoomPointers.contains(event.pointer)) return false;
      _pendingPanZoomFlushPointer = event.pointer;
      return true;
    }
    if (event is PointerRemovedEvent && _panZoomPointers.contains(event.pointer)) {
      _pendingPanZoomFlushPointer = event.pointer;
      return true;
    }
    if (event is PointerDownEvent) {
      _pointers.add(event.pointer);
      return false;
    }
    if (!_pointers.contains(event.pointer)) return false;
    if (event is! PointerUpEvent && event is! PointerCancelEvent && event is! PointerRemovedEvent) return false;
    _pendingFlushPointer = event.pointer;
    return true;
  }

  void flushAfterDispatch(VoidCallback sync) {
    final panZoomPointer = _pendingPanZoomFlushPointer;
    _pendingPanZoomFlushPointer = null;
    if (panZoomPointer != null) {
      _panZoomPointers.remove(panZoomPointer);
      flushIfIdle(sync);
      return;
    }
    final pointer = _pendingFlushPointer;
    _pendingFlushPointer = null;
    if (pointer == null) return;
    _pointers.remove(pointer);
    flushIfIdle(sync);
  }

  void handleRoutedPointerRemoved(PointerRemovedEvent event, VoidCallback sync, {bool externalActive = false}) {
    final removedPointer = _pointers.remove(event.pointer);
    final removedPanZoom = _panZoomPointers.remove(event.pointer);
    if (!removedPointer && !removedPanZoom) return;
    if (_pendingFlushPointer == event.pointer) {
      _pendingFlushPointer = null;
    }
    if (_pendingPanZoomFlushPointer == event.pointer) {
      _pendingPanZoomFlushPointer = null;
    }
    flushIfIdle(sync, externalActive: externalActive);
  }

  void flushIfIdle(VoidCallback sync, {bool externalActive = false}) {
    if (externalActive) return;
    if (active) return;
    if (!_deferred) return;
    _deferred = false;
    final callbacks = List<VoidCallback>.of(_deferredCallbacks);
    _deferredCallbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
    sync();
  }

  /// 中止对指针序列的等待（render detach / dispose 时调用）。
  ///
  /// 未执行的 deferred 回调**不能**无声丢弃：宿主 State 清 deferred flag 的
  /// 唯一路径挂在回调里，丢弃即永久卡死后续 controller/physics/axis 结构
  /// 更新（GlobalKey 保 element 的 reparent / 路由转场 re-attach 场景）。
  /// 迁移到 post-frame 执行——回调自带 mounted 守卫，宿主已销毁时安全空转。
  void reset() {
    _pointers.clear();
    _panZoomPointers.clear();
    _pendingFlushPointer = null;
    _pendingPanZoomFlushPointer = null;
    _deferred = false;
    if (_deferredCallbacks.isEmpty) return;
    final callbacks = List<VoidCallback>.of(_deferredCallbacks);
    _deferredCallbacks.clear();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final callback in callbacks) {
        callback();
      }
    });
    // detach 可能发生在帧外（微任务里的树变更），催一帧保证回调落地。
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}
