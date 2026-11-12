import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// 移动控件共用的系统触感入口，事件去重且滑选限频。
class TouchHaptics {
  /// 是否启用组件触感；系统设置仍由原生反馈接口处理。
  static bool enabled = true;

  static final _activated = Expando<bool>();
  Duration? _lastSelection;

  /// 只为手指与触控笔提供触感。
  static bool accepts(Object? event) =>
      event is PointerEvent && (event.kind == PointerDeviceKind.touch || event.kind == PointerDeviceKind.stylus);

  /// 一次有效激活最多发送一次轻触感，避免嵌套控件重复反馈。
  static void activate(Object? event) {
    if (!enabled || !accepts(event)) return;
    final original = (event as PointerEvent).original ?? event;
    if (_activated[original] == true) return;
    _activated[original] = true;
    _send(HapticFeedback.lightImpact);
  }

  /// 滑入新的有效项时发送选择触感，连续滑选最多每 50ms 一次。
  void selection() {
    if (!enabled) return;
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    if (_lastSelection != null && now - _lastSelection! < const Duration(milliseconds: 50)) return;
    _lastSelection = now;
    _send(HapticFeedback.selectionClick);
  }

  /// 新手势不继承上次滑选的限频时间。
  void reset() => _lastSelection = null;

  static Future<void> _send(Future<void> Function() feedback) async {
    try {
      await feedback();
    } on MissingPluginException {
      // 未提供触感的平台保持正常交互。
    } on PlatformException {
      // 设备不可用时不让可选反馈中断操作。
    }
  }
}
