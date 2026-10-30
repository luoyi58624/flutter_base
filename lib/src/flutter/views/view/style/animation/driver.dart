import 'package:flutter/semantics.dart' show SemanticsBinding;

import '../dimension.dart';
import '../style.dart';
import 'field_animation.dart';
import 'frame_clock.dart';

/// auto 长度端点的真实布局快照；返回 null 时等待宿主在 layout 后补齐。
typedef LengthSnapshotResolver = double? Function(ElTransitionField field);

/// 系统是否要求禁用动画。
bool get elDisableAnimations => SemanticsBinding.instance.accessibilityFeatures.disableAnimations;

/// 单个节点的字段过渡，仅保存正在运行的动画。
class StyleAnimationDriver {
  /// 创建驱动器，动画实际开始后才创建帧时钟。
  StyleAnimationDriver({required this.onTick, this.lengthSnapshotResolver});

  /// 字段推进后通知宿主提交当前采样。
  final void Function() onTick;

  /// 仅 width/height 的 auto 端点使用真实 used-size 快照，min/max 保持离散切换。
  final LengthSnapshotResolver? lengthSnapshotResolver;
  final _activeAnimations = <ElTransitionField, FieldAnimation>{};
  List<ElTransitionField>? _fieldsSnapshot;
  ElAnimationClock? _clock;
  bool _disposed = false;

  /// 活跃字段的稳定快照，集合改变后才重建，旧快照不会被后续修改。
  Iterable<ElTransitionField> get activeFields {
    if (_activeAnimations.isEmpty) return const <ElTransitionField>[];
    return _fieldsSnapshot ??= (_activeAnimations.keys.toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index)));
  }

  /// 指定字段当前的过渡。
  FieldAnimation? animationOf(ElTransitionField field) => _activeAnimations[field];

  /// 是否正在播放字段过渡。
  bool get hasActiveAnimations => _activeAnimations.isNotEmpty;

  /// 补齐延迟测量的 auto 端点，完成态仍返回原始声明（含 null）。
  bool resolveDeferredLengthSnapshot(ElTransitionField field, double pixels) {
    final animation = animationOf(field);
    if (animation == null || (animation.from != null && animation.to != null)) return false;
    animation.replaceNullLerpEndpoint(ElDimension.pixels(pixels));
    return true;
  }

  /// 启动或替换同字段过渡，其他字段沿用原时间线。
  void startAnimation(FieldAnimation animation) {
    assert(!_disposed, 'startAnimation after dispose');
    final field = animation.field;
    if ((field == ElTransitionField.width || field == ElTransitionField.height) &&
        ((animation.from == null) != (animation.to == null))) {
      final pixels = lengthSnapshotResolver?.call(field);
      if (pixels != null) animation.replaceNullLerpEndpoint(ElDimension.pixels(pixels));
    }
    assert(!_disposed, 'startAnimation after dispose');
    if (!_activeAnimations.containsKey(field)) _fieldsSnapshot = null;
    _activeAnimations[field] = animation;
    (_clock ??= ElAnimationClock(_tick)).start();
  }

  /// 取消指定字段，最后一个字段结束时停止时钟。
  void cancelAnimation(ElTransitionField field) {
    if (_activeAnimations.remove(field) == null) return;
    _fieldsSnapshot = null;
    if (_activeAnimations.isEmpty) _clock?.stop();
  }

  /// 取消全部字段过渡。
  void cancelAll() {
    _activeAnimations.clear();
    _fieldsSnapshot = null;
    _clock?.stop();
  }

  void _tick(Duration delta) {
    List<FieldAnimation>? completed;
    for (final animation in _activeAnimations.values) {
      animation.advance(delta);
      if (animation.isComplete) (completed ??= []).add(animation);
    }
    onTick();
    if (completed != null) {
      for (final animation in completed) {
        // 提交采样可能触发新过渡，只清理本轮真正完成的旧实例。
        if (identical(_activeAnimations[animation.field], animation)) {
          _activeAnimations.remove(animation.field);
          _fieldsSnapshot = null;
        }
      }
    }
    if (_activeAnimations.isEmpty) _clock?.stop();
  }

  /// 释放时钟和字段引用。
  void dispose() {
    _disposed = true;
    _clock?.dispose();
    _clock = null;
    _activeAnimations.clear();
    _fieldsSnapshot = null;
  }
}
