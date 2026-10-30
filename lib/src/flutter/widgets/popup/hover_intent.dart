import 'dart:async' show Timer;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// hover 触发弹层的开闭去抖配置（`ElPortal.hoverIntent`；tooltip / hover 菜单）。
@immutable
class ElHoverIntent {
  /// 创建配置。
  const ElHoverIntent({
    this.openDelay = const Duration(milliseconds: 150),
    this.closeDelay = const Duration(milliseconds: 100),
    this.safePolygon = true,
  });

  /// 悬停触发器多久后打开（快速掠过不弹）。
  final Duration openDelay;

  /// 指针离开（触发器与弹层都不在）多久后关闭。
  final Duration closeDelay;

  /// 安全多边形：关闭倒计时期间，指针落在「触发器矩形 ∪ 弹层矩形」的凸包内
  /// 视为仍在意图区，重置倒计时——沿对角线滑向弹层不误关。
  final bool safePolygon;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ElHoverIntent) return false;
    return openDelay == other.openDelay && closeDelay == other.closeDelay && safePolygon == other.safePolygon;
  }

  @override
  int get hashCode => Object.hash(openDelay, closeDelay, safePolygon);
}

/// hover intent 状态机（portal state 持有）。
///
/// 输入：触发器 / 弹层的 enter、exit；关闭倒计时窗口内经全局 hover 路由做
/// 安全多边形判定。输出：`requestOpen` / `requestClose` 回调。
class HoverIntentMachine {
  /// 创建。[rectsOf] 返回当前意图区矩形集（触发器 + 弹层内容，全局坐标；
  /// 空 = 无法判定，多边形失效按普通倒计时走）。
  HoverIntentMachine({
    required this.config,
    required this.requestOpen,
    required this.requestClose,
    required this.rectsOf,
  });

  /// 配置。
  final ElHoverIntent config;

  /// 开启请求（openDelay 计满）。
  final VoidCallback requestOpen;

  /// 关闭请求（closeDelay 计满且指针不在意图区）。
  final VoidCallback requestClose;

  /// 意图区矩形集提供者。
  final List<Rect> Function() rectsOf;

  Timer? _openTimer;
  Timer? _closeTimer;
  bool _watchingHover = false;
  bool _disposed = false;

  /// 指针进入触发器 / 弹层内容。
  void pointerEntered() {
    _cancelClose();
    if (_openTimer != null) return;
    _openTimer = Timer(config.openDelay, () {
      _openTimer = null;
      if (!_disposed) requestOpen();
    });
  }

  /// 指针离开触发器 / 弹层内容：启动关闭倒计时 + （可选）监听全局 hover 做
  /// 安全多边形续命。
  void pointerExited() {
    _openTimer?.cancel();
    _openTimer = null;
    _restartCloseTimer();
    if (config.safePolygon && !_watchingHover) {
      _watchingHover = true;
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
    }
  }

  void _restartCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = Timer(config.closeDelay, () {
      _closeTimer = null;
      _stopWatching();
      if (!_disposed) requestClose();
    });
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
    _stopWatching();
  }

  void _stopWatching() {
    if (!_watchingHover) return;
    _watchingHover = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
  }

  void _onGlobalPointer(PointerEvent event) {
    if (event is! PointerHoverEvent) return;
    if (_insideSafeHull(event.position)) _restartCloseTimer();
  }

  /// 落点是否在意图区凸包内（触发器 ∪ 弹层的 8 角点凸包）。
  bool _insideSafeHull(Offset p) {
    final rects = rectsOf();
    if (rects.isEmpty) return false;
    final points = <Offset>[
      for (final r in rects) ...[r.topLeft, r.topRight, r.bottomRight, r.bottomLeft],
    ];
    final hull = convexHull(points);
    return pointInConvexPolygon(p, hull);
  }

  /// 释放（portal dispose）。
  void dispose() {
    _disposed = true;
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _stopWatching();
  }

  /// Andrew 单调链凸包（输入 ≥1 点；共线点保留无碍包含判定）。
  @visibleForTesting
  static List<Offset> convexHull(List<Offset> points) {
    final pts = [...points]..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    if (pts.length <= 2) return pts;
    double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    List<Offset> half(Iterable<Offset> points) {
      final result = <Offset>[];
      for (final point in points) {
        while (result.length >= 2 && cross(result[result.length - 2], result.last, point) <= 0) {
          result.removeLast();
        }
        result.add(point);
      }
      return result..removeLast();
    }

    return [...half(pts), ...half(pts.reversed)];
  }

  /// 点在凸多边形内（含边界；顶点需逆时针或顺时针一致序——凸包产物满足）。
  @visibleForTesting
  static bool pointInConvexPolygon(Offset p, List<Offset> hull) {
    if (hull.length < 3) {
      // 退化（线段/点）：按外包矩形近似。
      if (hull.isEmpty) return false;
      final bounds = hull.fold<Rect>(
        Rect.fromPoints(hull.first, hull.first),
        (rect, point) => rect.expandToInclude(Rect.fromPoints(point, point)),
      );
      return p.dx >= bounds.left && p.dx <= bounds.right && p.dy >= bounds.top && p.dy <= bounds.bottom;
    }
    double? sign;
    for (var i = 0; i < hull.length; i++) {
      final a = hull[i];
      final b = hull[(i + 1) % hull.length];
      final c = (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
      if (c == 0) continue; // 边上
      if (sign == null) {
        sign = c.sign;
      } else if (c.sign != sign) {
        return false;
      }
    }
    return true;
  }
}
