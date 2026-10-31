import 'dart:collection';

import 'package:flutter/foundation.dart' show internal, mapEquals;
import 'package:flutter/rendering.dart' show PipelineOwner;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show Element;

import '../style_context.dart';

/// build 侧变量依赖的注册与派发，由 render 在首次读取时懒建。
@internal
class VarsBuildDependents implements BuildDependencySource {
  /// 以当前已提交变量表为初始派发基准创建。
  VarsBuildDependents(Map<Object, Object> vars) : _lastNotified = vars;

  /// Element →（登记的变量键集合，帧标）。
  final Map<Element, (Set<Object>, int)> _dependents = <Element, (Set<Object>, int)>{};

  /// 上次已派发基准，延期期间多次提交仍以它判定变化。
  Map<Object, Object> _lastNotified;

  /// 延期中待派发的最新值，null 表示没有待派发内容。
  Map<Object, Object>? _pending;

  bool _flushScheduled = false;
  bool _disposed = false;

  /// 登记变量键，同帧重复读取取并集，跨帧首读重置读取面。
  void register(Element reader, Object aspect) {
    if (_disposed) return;
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
  void removeBuildDependent(Element dependent) => _dependents.remove(dependent);

  /// 接收 render 提交的变量表，仅通知读取值发生变化的后代。
  void notifyCommit(Map<Object, Object> vars, {PipelineOwner? pipelineOwner}) {
    if (_disposed) return;
    final base = _lastNotified;
    final next = vars;
    if (_pending == null && _snapshotEquals(base, next)) return;
    if (_dependents.isEmpty) {
      _lastNotified = next;
      _pending = null;
      return;
    }
    // 构建时同步标脏后代以保证同帧生效；布局、绘制时按旧实现延至帧末。
    var canMarkNow = true;
    assert(() {
      canMarkNow = !(pipelineOwner?.debugDoingLayout ?? false) && !(pipelineOwner?.debugDoingPaint ?? false);
      return true;
    }());
    if (canMarkNow) {
      _pending = null;
      if (!_snapshotEquals(base, next)) {
        _markChanged(base, next);
        _lastNotified = next;
      }
      return;
    }
    _pending = next;
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (_disposed) return;
      final p = _pending;
      if (p == null) return;
      _pending = null;
      final b0 = _lastNotified;
      if (!_snapshotEquals(b0, p)) {
        _markChanged(b0, p);
        _lastNotified = p;
      }
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  /// render 销毁时释放读者与待派发内容，之后所有入口不再生效。
  void dispose() {
    _disposed = true;
    _dependents.clear();
    _pending = null;
  }

  void _markChanged(Map<Object, Object> old, Map<Object, Object> next) {
    List<Element>? dead;
    _dependents.forEach((element, entry) {
      if (!element.mounted) {
        (dead ??= <Element>[]).add(element);
        return;
      }
      if (_aspectsChanged(old, next, entry.$1)) element.markNeedsBuild();
    });
    dead?.forEach(_dependents.remove);
  }

  static bool _snapshotEquals(Map<Object, Object> a, Map<Object, Object> b) => identical(a, b) || mapEquals(a, b);

  /// 直接按键比较新旧值，不解析键名或变量别名。
  static bool _aspectsChanged(Map<Object, Object> old, Map<Object, Object> next, Set<Object> dependencies) {
    for (final key in dependencies) {
      if (old[key] != next[key]) return true;
    }
    return false;
  }
}
