import 'package:flutter/foundation.dart';

/// 最近事件宿主的只读交互状态，供后代根据状态构建外观。
@immutable
final class ElEventState {
  /// 创建交互状态快照，默认没有活动交互。
  const ElEventState({
    this.hasTap = false,
    this.hasHover = false,
    this.disabled = false,
  });

  /// 是否处于按压反馈中；触摸遵循 delayTouchDown 和 delayTouchUp。
  final bool hasTap;

  /// 是否有鼠标位于宿主内，与是否按下鼠标按键无关。
  final bool hasHover;

  /// 当前事件宿主是否禁用，禁用期间各交互状态均为 false。
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElEventState &&
          hasTap == other.hasTap &&
          hasHover == other.hasHover &&
          disabled == other.disabled;

  @override
  int get hashCode => Object.hash(hasTap, hasHover, disabled);
}
