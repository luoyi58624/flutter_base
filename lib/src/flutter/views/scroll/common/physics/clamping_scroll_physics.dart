import 'package:flutter/physics.dart' show FrictionSimulation, Simulation, Tolerance;
import 'package:flutter/widgets.dart';

/// 安卓/桌面滚动物理：官方 [ClampingScrollPhysics] 的边界语义（硬停、不越界）
/// + **iOS 式指数摩擦惯性**，速度绝对值低于 [stopVelocity] 时停止。
///
/// **为什么不用官方样条**：官方 [ClampingScrollSimulation] 是 Android
/// OverScroller 样条，`isDone` 按时长判定、尾段被时长截断；本类改为
/// 指数衰减，并统一惯性启动、续接与模拟结束的速度阈值。
///
/// **本类**改喂 [FrictionSimulation]（drag 0.135 = iOS UIScrollView
/// decelerationRate 0.998 的逐帧口径，`constantDeceleration: 0` 无附加减速）：
/// - 指数衰减无时长截断，速度持续降低到停止阈值；
/// - 传入 [toleranceFor] 的速度阈值，默认 10 逻辑像素/秒，不随设备像素比变化；
/// - 惯性撞界仍由 [ClampingScrollPhysics.applyBoundaryConditions] 拦住，
///   `BallisticScrollActivity` 收到非零 overscroll 即 goIdle → 边界照旧硬停 +
///   上报 [OverscrollNotification] 喂 M3 拉伸指示器。
class ElClampingScrollPhysics extends ClampingScrollPhysics {
  /// 创建一份指数摩擦惯性的 clamping 物理，可配置停止速度。
  const ElClampingScrollPhysics({this.stopVelocity = 10, super.parent})
    : assert(stopVelocity > 0 && stopVelocity < double.infinity);

  /// 惯性停止速度（逻辑像素/秒），默认 10；必须是有限正数。
  final double stopVelocity;

  /// 把 physics 链头部的**官方精确类型** [ClampingScrollPhysics] 替换为本类
  /// （保留 parent 链）；自定义子类视为调用方有意定制，不动。
  /// 口径同 ElBouncingScrollPhysics.upgrade。
  static ScrollPhysics upgrade(ScrollPhysics physics) {
    return physics.runtimeType == ClampingScrollPhysics ? ElClampingScrollPhysics(parent: physics.parent) : physics;
  }

  @override
  ElClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ElClampingScrollPhysics(stopVelocity: stopVelocity, parent: buildParent(ancestor));
  }

  /// 使用配置的惯性停止速度，保留父级距离与时间容差。
  @override
  Tolerance toleranceFor(ScrollMetrics metrics) {
    final tolerance = super.toleranceFor(metrics);
    return Tolerance(distance: tolerance.distance, time: tolerance.time, velocity: stopVelocity);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // 越界走官方 spring 回弹（视口放大把 pixels 留在新 max 之外、resize 到底
    // 部露空白的场景）：FrictionSimulation 是纯惯性衰减，v=0 时就是钉在越界
    // 位的常量模拟，永远回不到范围内。
    if (position.outOfRange) return super.createBallisticSimulation(position, velocity);
    final tolerance = toleranceFor(position);
    if (velocity.abs() >= tolerance.velocity) {
      return FrictionSimulation(0.135, position.pixels, velocity, constantDeceleration: 0, tolerance: tolerance);
    }
    return null;
  }
}
