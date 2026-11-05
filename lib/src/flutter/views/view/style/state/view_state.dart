import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Element;

import '../style_context.dart';
import '../../render/render_view.dart' show ViewStateRenderAccess;
import 'build_dependency_phase.dart';

/// 引擎内部的状态位序，不作为用户查询协议。
@internal
enum ViewState {
  /// 鼠标悬停。
  hover,

  /// 主键按下期间的 tap 状态。
  tap,

  /// 节点自身拥有焦点。
  focus,

  /// 节点自身或后代拥有焦点。
  focusWithin,

  /// 禁用。
  disabled,

  /// 暗色模式。
  dark,

  /// 响应式断点：当前是否处于极小布局（<=320）。
  xs,

  /// 响应式断点：当前是否处于移动端布局（<=640）。
  sm,

  /// 响应式断点：当前是否处于平板布局（<=1024）。
  md,

  /// 响应式断点：当前是否处于桌面布局（<=1920）。
  lg,

  /// 响应式断点：当前是否处于超大桌面布局（<=2560）。
  xl,

  /// 节点自身拥有焦点且所属 View 已通过导航键开启焦点指示。
  /// 指针按下收起；程序聚焦、窗口恢复和普通文字输入不自行开启。
  ///
  /// 优先级紧邻 [focus] 之上（各链插槽定义）；bit 位在尾部只为保位稳定。
  focusVisible,
}

typedef _StateListenerEntry = ({VoidCallback listener, int mask});

/// 引擎内部的按位订阅，仅保存状态位和失效通知，不创建快照或变更对象。
@internal
final class ViewStateSource {
  int _bits = 0;
  final List<_StateListenerEntry> _listeners = [];

  /// **读取即订阅** — build 依赖注册表：Element → (关心的位 mask, 登记帧标)。
  ///
  /// `ElView.of(context)` 的状态 getter 读取时经 [dependOnBits] 登记单 bit
  /// 依赖；对应位翻转时 phase-safe 地 markNeedsBuild（[_notifyBuildDependents]）。
  /// 帧标语义（MediaQuery.sizeOf 同款心智）：同帧重复读取 OR 合并 mask，
  /// 跨帧首读**重置** mask——build 不再读取的位自动退订。
  Map<Element, (int, int)>? _buildDependents;
  Set<Element>? _pendingBuildDependents;

  /// 历史上被 build 依赖读取过的位并集（sticky，不随帧标重置）。
  ///
  /// [dependOnBits] 用它判定"关心面是否扩张"：source 已有其他位的监听者时
  /// 新增状态依赖不会跨 0↔1 临界，必须靠本并集扩张触发
  /// [onListenerPresenceChanged]，render 才能按需打开高频跟踪（如 hover）。
  /// 每帧重复读取被并集挡住，不产生高频空转。
  int _everDependedMask = 0;

  /// 监听者集合变化回调。供 ElView render 层按需开启高频状态跟踪。
  @internal
  VoidCallback? onListenerPresenceChanged;

  /// 是否有任何监听者（含 build 依赖）。
  bool get hasListeners => _listeners.isNotEmpty || (_buildDependents?.isNotEmpty ?? false);

  /// 是否存在关心指定状态的监听者（含 build 依赖）。
  bool hasListenerFor(ViewState state) {
    final mask = 1 << state.index;
    return _hasListenerForMask(mask);
  }

  /// **读取即订阅** — 登记 [element] 对 [bitMask] 位的 build 依赖。
  ///
  /// 由 `ElView.of` 返回的 ElStyleContext 状态 getter 调用；render 层经
  /// [onListenerPresenceChanged] 感知 0↔1 临界，按需开启高频状态跟踪
  /// （hover/tap 等 dispatcher 门禁）。
  @internal
  void dependOnBits(Element element, int bitMask) {
    final map = _buildDependents ??= <Element, (int, int)>{};
    final hadListeners = hasListeners;
    // 关心面扩张：本 source 首次出现对这些位的依赖（不看帧标）。
    final expandsMask = (bitMask & ~_everDependedMask) != 0;
    _everDependedMask |= bitMask;
    // 帧标取 currentSystemFrameTimeStamp：帧内稳定、逐帧递增、帧外读取保持
    // 上一帧值（currentFrameTimeStamp 在帧外会断言）。
    final frame = SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    final existing = map[element];
    if (existing == null) {
      final scope = element.dependOnInheritedWidgetOfExactType<StyleDependencyScope>();
      assert(scope == null || identical(scope.host.stateSource, this), '状态依赖必须登记到最近视图自己的状态源。');
    }
    if (existing == null || existing.$2 != frame) {
      // 跨帧首读：重置 mask（旧订阅位随本帧真实读取面重建）。
      map[element] = (bitMask, frame);
    } else {
      map[element] = (existing.$1 | bitMask, frame);
    }
    // 0↔1 临界或关心面扩张都要通知 render：已有 hover 监听者时新加其它
    // 状态依赖不跨临界，仍须感知以便打开对应高频跟踪。
    if (!hadListeners || expandsMask) onListenerPresenceChanged?.call();
  }

  /// 读者离树时释放 build 订阅，并关闭无人消费的状态跟踪。
  @internal
  void removeBuildDependent(Element dependent) {
    if (_buildDependents?.remove(dependent) == null) return;
    _pendingBuildDependents?.remove(dependent);
    if (!hasListeners) onListenerPresenceChanged?.call();
  }

  /// 添加状态监听器。
  void addListener(VoidCallback listener, {Set<ViewState>? states}) {
    final hadListeners = hasListeners;
    _listeners.add((
      listener: listener,
      mask: states == null || states.isEmpty ? -1 : states.fold(0, (mask, state) => mask | (1 << state.index)),
    ));
    if (!hadListeners) onListenerPresenceChanged?.call();
  }

  /// 移除状态监听器。
  void removeListener(VoidCallback listener) {
    final hadListeners = hasListeners;
    // 实例方法每次取 tear-off 可产生新对象，按函数相等语义才能正确退订。
    _listeners.removeWhere((entry) => entry.listener == listener);
    if (hadListeners != hasListeners) onListenerPresenceChanged?.call();
  }

  /// 使用 render 层 [ViewState] bit 值同步状态。
  void updateNodeStateBits(int nextBits) {
    if (nextBits == _bits) return;

    final changedMask = _bits ^ nextBits;
    _bits = nextBits;
    _notifyBuildDependents(changedMask);
    if (!_hasImperativeListenerForMask(changedMask)) return;
    for (final entry in List<_StateListenerEntry>.of(_listeners)) {
      if ((entry.mask & changedMask) != 0) entry.listener();
    }
  }

  /// 命中的读者按构建边界同步标脏或延期，离树读者从登记表清除。
  void _notifyBuildDependents(int changedMask) {
    final map = _buildDependents;
    if (map == null || map.isEmpty) return;
    List<Element>? dead;
    map.forEach((element, entry) {
      if (!element.mounted) {
        (dead ??= <Element>[]).add(element);
        return;
      }
      if ((entry.$1 & changedMask) == 0) return;
      if (canMarkBuildDependent(element)) {
        _pendingBuildDependents?.remove(element);
        element.markNeedsBuild();
      } else {
        final pending = _pendingBuildDependents ??= _scheduleBuildDependentFlush();
        pending.add(element);
      }
    });
    dead?.forEach(removeBuildDependent);
  }

  Set<Element> _scheduleBuildDependentFlush() {
    final pending = <Element>{};
    scheduleBuildDependencyFlush((_) {
      _pendingBuildDependents = null;
      for (final element in pending) {
        if (element.mounted) element.markNeedsBuild();
      }
    });
    return pending;
  }

  bool _hasListenerForMask(int changedMask) {
    final map = _buildDependents;
    if (map != null) {
      for (final entry in map.values) {
        if ((entry.$1 & changedMask) != 0) return true;
      }
    }
    return _hasImperativeListenerForMask(changedMask);
  }

  bool _hasImperativeListenerForMask(int changedMask) => _listeners.any((entry) => (entry.mask & changedMask) != 0);
}
