import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_base/src/dart/gen/index.dart';

part 'config.g.dart';

/// 当前元素的事件参数声明，空值交由识别器或 Render 采用默认行为。
@ElModelGenerator.copy()
final class ElEventConfig with Equatable {
  /// 创建局部配置，不继承祖先配置，也不在此解析默认值。
  const ElEventConfig({
    this.doubleTapInterval,
    this.tripleTapInterval,
    this.longPressDelay,
    this.longPressCancelDistance,
    this.tapCancelDistance,
    this.tapCancelOnMove,
    this.delayTouchDown,
    this.delayTouchUp,
    this.deferTap,
    this.dragStartDistance,
    this.dragDevices,
    this.dragHorizontalAngle,
    this.dragMinFlingDistance,
    this.dragMinFlingVelocity,
    this.dragMaxFlingVelocity,
  });

  /// 第二击与前一击的最长间隔，默认由 Press 采用官方双击时限。
  final Duration? doubleTapInterval;

  /// 第三击与前一击的最长间隔，默认由 Press 采用官方双击时限。
  final Duration? tripleTapInterval;

  /// 长按等待时间，默认由 Press 采用官方长按时限。
  final Duration? longPressDelay;

  /// 长按允许的移动距离，空值采用官方设备容差。
  final double? longPressCancelDistance;

  /// 移动取消、侧键点击与连续点击的位置容差，默认由 Press 管理。
  final double? tapCancelDistance;

  /// 为 true 时按距离永久取消主键点击，否则由 Render 判断元素边界。
  ///
  /// 边界模式允许移回后重新按下；释放通知并不表示最终点击成立。
  final bool? tapCancelOnMove;

  /// 触摸按下反馈的延迟，Render 默认立即激活，不延迟鼠标与笔。
  final Duration? delayTouchDown;

  /// 触摸反馈从物理按下起算的最短时间，Render 默认采用 100ms，不延迟业务点击。
  final Duration? delayTouchUp;

  /// 同时监听单击和双击时，是否等待双击窗口再通知单击。
  final bool? deferTap;

  /// 拖拽开始的距离，空值由 Transform 按设备与轴向采用官方容差。
  final double? dragStartDistance;

  /// 可参与变换识别的设备，空值表示不限制。
  final Set<PointerDeviceKind>? dragDevices;

  /// 水平捕获锥的半角，Transform 默认采用 π/4。
  final double? dragHorizontalAngle;

  /// 产生释放速度的最小距离，空值采用官方设备容差。
  final double? dragMinFlingDistance;

  /// 产生甩动的最小速度，Transform 默认采用官方阈值。
  final double? dragMinFlingVelocity;

  /// 释放速度的最大值，Transform 默认采用官方上限。
  final double? dragMaxFlingVelocity;

  /// 点击识别参数是否相同，反馈时间变化不打断正在进行的手势。
  @internal
  bool hasSameTapConfiguration(ElEventConfig? other) =>
      doubleTapInterval == other?.doubleTapInterval &&
      tripleTapInterval == other?.tripleTapInterval &&
      longPressDelay == other?.longPressDelay &&
      longPressCancelDistance == other?.longPressCancelDistance &&
      tapCancelDistance == other?.tapCancelDistance &&
      tapCancelOnMove == other?.tapCancelOnMove &&
      deferTap == other?.deferTap;

  /// 用当前已设置的字段覆盖底层配置。
  ElEventConfig withFallback(ElEventConfig base) => base.merge(this);

  @override
  List<Object?> get props => _props;
}
