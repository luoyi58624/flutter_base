import 'dart:collection';

import 'package:flutter/foundation.dart' show internal, mapEquals;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Element;

import '../style_context.dart';
import 'build_dependency_phase.dart';

/// build 侧变量依赖的注册与派发，由 render 在首次读取时懒建。
@internal
class VarsBuildDependents implements BuildDependencySource {
  /// 以当前已提交变量表为初始派发基准创建。
  VarsBuildDependents(this._vars);

  /// Element →（登记的变量键集合，帧标）。
  final Map<Element, (Set<Object>, int)> _dependents = <Element, (Set<Object>, int)>{};

  /// 最近一次提交的变量表。
  Map<Object, Object> _vars;

  /// 各延期读者关心的变量键与已见值，用于合并一帧内的多次提交。
  Map<Element, Map<Object, Object?>>? _pending;

  bool _disposed = false;

  /// 登记变量键，同帧重复读取取并集，跨帧首读重置读取面。
  void register(Element reader, Object aspect) {
    if (_disposed) return;
    // 读者可能在延期期间重新读取部分键，只更新实际读取的键。
    _pending?[reader]?[aspect] = _vars[aspect];
    final frame = SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
    final existing = _dependents[reader];
    if (existing == null) StyleDependencyScope.dependOnBuildSource(reader, this);
    if (existing == null || existing.$2 != frame) {
      _dependents[reader] = (HashSet<Object>()..add(aspect), frame);
    } else {
      existing.$1.add(aspect);
    }
  }

  /// 读者离树时立即移除强引用，重挂后的首次读取会重新登记。
  @override
  void removeBuildDependent(Element dependent) {
    _dependents.remove(dependent);
    _pending?.remove(dependent);
  }

  /// 接收 render 提交的变量表，仅通知读取值发生变化的后代。
  void notifyCommit(Map<Object, Object> vars) {
    if (_disposed) return;
    final previous = _vars;
    if (identical(previous, vars) || mapEquals(previous, vars)) return;
    _vars = vars;

    List<Element>? dead;
    _dependents.forEach((element, entry) {
      if (!element.mounted) {
        (dead ??= <Element>[]).add(element);
        return;
      }
      final aspects = entry.$1;
      if (!_aspectsChanged(previous, vars, aspects)) return;
      if (canMarkBuildDependent(element)) {
        final pendingBaseline = _pending?.remove(element);
        if (pendingBaseline == null || _aspectsChanged(pendingBaseline, vars, aspects)) element.markNeedsBuild();
      } else {
        final pending = _pending ??= _scheduleFlush();
        pending.putIfAbsent(element, () => {for (final aspect in aspects) aspect: previous[aspect]});
      }
    });
    dead?.forEach(removeBuildDependent);
  }

  /// render 销毁时释放读者与待派发内容，之后所有入口不再生效。
  void dispose() {
    _disposed = true;
    _dependents.clear();
    _pending = null;
  }

  Map<Element, Map<Object, Object?>> _scheduleFlush() {
    scheduleBuildDependencyFlush((_) {
      final pending = _pending;
      _pending = null;
      if (pending == null) return;
      for (final MapEntry(key: element, value: baseline) in pending.entries) {
        final entry = _dependents[element];
        if (entry != null && element.mounted && _aspectsChanged(baseline, _vars, entry.$1)) element.markNeedsBuild();
      }
    });
    return {};
  }

  /// 直接按键比较新旧值，不解析键名或变量别名。
  static bool _aspectsChanged(Map<Object, Object?> old, Map<Object, Object> next, Set<Object> dependencies) {
    for (final key in dependencies) {
      if (old[key] != next[key]) return true;
    }
    return false;
  }
}
