import 'package:flutter/foundation.dart';

/// 最近事件宿主的只读交互状态，供后代根据状态构建外观。
@immutable
final class ElEventState {
  /// 创建交互状态快照，默认没有活动交互。
  const ElEventState({
    this.hasTap = false,
    this.hasHover = false,
    this.hasLongPress = false,
    this.hasDrag = false,
    this.disabled = false,
  });

  /// 是否处于按压反馈中；触摸遵循 delayTouchDown 和 delayTouchUp。
  final bool hasTap;

  /// 是否有鼠标位于宿主内，与是否按下鼠标按键无关。
  final bool hasHover;

  /// 已配置的长按手势是否成立且尚未释放。
  final bool hasLongPress;

  /// 已配置的拖拽手势是否开始且尚未结束或取消。
  final bool hasDrag;

  /// 当前事件宿主是否禁用，禁用期间各交互状态均为 false。
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElEventState &&
          hasTap == other.hasTap &&
          hasHover == other.hasHover &&
          hasLongPress == other.hasLongPress &&
          hasDrag == other.hasDrag &&
          disabled == other.disabled;

  @override
  int get hashCode =>
      Object.hash(hasTap, hasHover, hasLongPress, hasDrag, disabled);
}
