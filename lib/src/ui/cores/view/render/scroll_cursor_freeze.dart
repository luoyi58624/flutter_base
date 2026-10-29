import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

const Duration elScrollCursorFreezeDuration = Duration(milliseconds: 160);

/// 滚动导致内容在静止鼠标下方移动时，暂时阻止子节点改写系统光标。
///
/// 住在 view/render 层而非 scroll 域：它是纯 RenderObject 级跨切面工具（不引用
/// 任何滚动类型），核心盒模型的 cursor/validForMouseTracker 与选区渲染都要读它，
/// 放在 scroll 深处会让 view 核心反向依赖滚动域。
final class ScrollCursorFreeze {
  ScrollCursorFreeze._();

  static RenderObject? _owner;
  static Timer? _timer;
  static int _debugMouseTrackerUpdateCount = 0;

  /// 现役 Timer 装填后是否又来过 claim（second-chance 续期标记）。
  static bool _claimedSinceArm = false;

  /// 当前是否存在滚动触发的光标冻结窗口。
  static bool get isActive => _owner?.attached ?? false;

  /// 测试探针：手动触发全局 MouseTracker 重新命中的次数。
  @visibleForTesting
  static int get debugMouseTrackerUpdateCount => _debugMouseTrackerUpdateCount;

  /// 声明 [owner] 所属滚动视口正在滚动，冻结窗口会被持续续期。
  ///
  /// 滚动/fling 期本方法逐帧到达，续期用 second-chance 复用现役 Timer
  /// （到期见标记则再装填一整段，不 cancel + new）——把每帧一次的 Timer
  /// 分配摊薄成每 [elScrollCursorFreezeDuration] 一次；代价是停滚后的
  /// 冻结窗口在 1~2 倍时长间浮动，鼠标真实移动的 [release] 路径不受影响。
  static void claim(RenderObject owner) {
    _owner = owner;
    if (_timer == null) {
      _claimedSinceArm = false;
      _timer = Timer(elScrollCursorFreezeDuration, _handleTimerExpired);
    } else {
      _claimedSinceArm = true;
    }
  }

  static void _handleTimerExpired() {
    _timer = null;
    if (_claimedSinceArm) {
      _claimedSinceArm = false;
      _timer = Timer(elScrollCursorFreezeDuration, _handleTimerExpired);
      return;
    }
    release();
  }

  /// 鼠标真实移动或视口销毁时恢复正常光标命中。
  static void release({bool updateMouseTracker = true}) {
    final releasedOwner = _owner;
    _timer?.cancel();
    _timer = null;
    _claimedSinceArm = false;
    _owner = null;
    if (updateMouseTracker && releasedOwner?.attached == true) {
      _debugMouseTrackerUpdateCount++;
      RendererBinding.instance.mouseTracker.updateAllDevices();
    }
  }

  /// [node] 是否位于当前冻结的滚动视口内部。
  static bool contains(RenderObject node) {
    final owner = _owner;
    if (owner == null || !owner.attached) return false;
    var current = node;
    while (true) {
      if (identical(current, owner)) return true;
      final parent = current.parent;
      if (parent is! RenderObject) return false;
      current = parent;
    }
  }

  /// 当前冻结是否由 [owner] 持有。
  static bool ownedBy(RenderObject owner) => identical(_owner, owner) && owner.attached;

  @visibleForTesting
  static void debugReset() {
    _timer?.cancel();
    _timer = null;
    _claimedSinceArm = false;
    _owner = null;
    _debugMouseTrackerUpdateCount = 0;
  }
}

/// 放在 hit-test path 最前方，只阻止 MouseTracker 改 cursor，不消费事件。
final HitTestTarget elScrollCursorFreezeBarrier = _ScrollCursorFreezeBarrier();

final class _ScrollCursorFreezeBarrier extends MouseTrackerAnnotation implements HitTestTarget {
  const _ScrollCursorFreezeBarrier() : super(cursor: MouseCursor.uncontrolled);

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {}
}
