import 'package:flutter/physics.dart' show FrictionSimulation, Simulation;
import 'package:flutter/widgets.dart';

/// iOS bouncing 物理的动量修正版：修复官方 [BouncingScrollPhysics] 的
/// "越界期反向甩动不触发滚动"缺陷。
///
/// **官方缺陷**：[BouncingScrollSimulation] 只要起步位置越界（rubber-band
/// 拉伸中、回弹尚未完成），就无条件把整段速度喂给"回弹到边界"的 spring——
/// 朝界内方向的甩动速度被弹簧全部吸收，内容微微探入界内又被拉回边界，
/// 用户感知为"过度滚动回弹前反向滚动完全不生效"。iOS 原生 UIScrollView
/// 此时会把动量无缝带回内容区继续减速滚动。
///
/// **修正**：越界起步且速度指向界内时，先用与官方同参的摩擦轨迹
/// （UIScrollView decelerationRate 0.998 → drag 0.135）预判终点；能穿回界内
/// 就把"越界侧 extent 扩到当前位置"再构造 [BouncingScrollSimulation]——
/// 构造器落入界内摩擦分支，越界段并入同一条摩擦曲线，位置与速度双连续；
/// 甩得极猛穿透对侧边界时，构造器自带的对侧 spring 衔接照常成立。
/// 摩擦轨迹到不了边界（速度太小）时回退官方 spring 回弹，绝不会停在界外。
///
/// **越界外甩限速**（2026-07-19 用户报告：频繁单次用力下拉幅度过大）：官方
/// [BouncingScrollPhysics.carriedMomentum]（0.000816·v^1.967，封顶 40000）在
/// ≈1560px/s 以上超线性放大，且叠加发生在手势识别器 [maxFlingVelocity] 截断
/// **之后**（ScrollDragController._end: velocity += carriedVelocity）——连续同向
/// 快甩的有效入弹速度可达 48000px/s，越界峰值随速度线性放大到近两个视口
/// （探针实测 291→458→555px 发散，见 bouncing_overscroll_amplitude_probe_test）。
/// iOS 的动量叠加只作用于界内滚动，橡皮筋拉伸不吃叠加速度。修正：贴边/越界
/// 起步且速度指向界外时，入弹速度按 [maxFlingVelocity] 封顶——单次手势能甩出
/// 多深，连续快甩也只能到多深；界内滚动的动量叠加（iOS 真实行为）不受影响。
///
/// 界内起步、越界外甩（未超速）、静止回弹等其余路径全部委托官方实现，逐帧等值。
class ElBouncingScrollPhysics extends BouncingScrollPhysics {
  /// 创建一份动量修正的 bouncing 物理；参数语义与官方完全一致。
  const ElBouncingScrollPhysics({super.decelerationRate, super.parent});

  /// 把 physics 链头部的**官方精确类型** [BouncingScrollPhysics] 替换为
  /// [ElBouncingScrollPhysics]（保留 decelerationRate 与 parent 链）。
  ///
  /// 用在 ElScroll 的 physics 合成收口处：平台
  /// 默认（iOS/macOS ScrollBehavior）与调用方显式传入的官方 bouncing 都被
  /// 升级；[BouncingScrollPhysics] 的自定义子类视为调用方有意定制，不动。
  static ScrollPhysics upgrade(ScrollPhysics physics) {
    if (physics.runtimeType == BouncingScrollPhysics) {
      final bouncing = physics as BouncingScrollPhysics;
      return ElBouncingScrollPhysics(decelerationRate: bouncing.decelerationRate, parent: bouncing.parent);
    }
    return physics;
  }

  @override
  ElBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ElBouncingScrollPhysics(decelerationRate: decelerationRate, parent: buildParent(ancestor));
  }

  double get _constantDeceleration => switch (decelerationRate) {
    ScrollDecelerationRate.fast => 1400.0,
    ScrollDecelerationRate.normal => 0.0,
  };

  /// 越界起步且速度指向界内时，同参摩擦轨迹能否实际穿回界内——即动量
  /// 修正路径会生效的判定。供刷新停靠物理（接管刷新边回弹弹簧时）复用，
  /// 给"越界反甩穿回列表"让路，判定与 [createBallisticSimulation] 单源。
  bool carriesInwardMomentum(ScrollMetrics position, double velocity) {
    if (!position.outOfRange) return false;
    final overAtTrailing = position.pixels > position.maxScrollExtent;
    final inward = overAtTrailing ? velocity < 0.0 : velocity > 0.0;
    final tolerance = toleranceFor(position);
    if (!inward || velocity.abs() < tolerance.velocity) return false;
    final friction = FrictionSimulation(0.135, position.pixels, velocity, constantDeceleration: _constantDeceleration);
    // 摩擦终点须实际穿回界内（留 tolerance.distance 余量）；到不了边界
    // 的低速甩回退官方 spring，避免摩擦中途停在界外无人纠偏。
    return overAtTrailing
        ? friction.finalX < position.maxScrollExtent - tolerance.distance
        : friction.finalX > position.minScrollExtent + tolerance.distance;
  }

  /// 贴边/越界起步且速度指向界外时，把 carriedMomentum 叠加穿透手势上限的
  /// 入弹速度收回 [maxFlingVelocity]；其余情况原样返回。橡皮筋深度由此恒有
  /// 单次手势上限对应的峰值封顶，连续快甩不再发散。
  double _clampOutwardEdgeVelocity(ScrollMetrics position, double velocity) {
    final outwardAtLeading = position.pixels <= position.minScrollExtent && velocity < 0.0;
    final outwardAtTrailing = position.pixels >= position.maxScrollExtent && velocity > 0.0;
    if (!outwardAtLeading && !outwardAtTrailing) return velocity;
    return velocity.clamp(-maxFlingVelocity, maxFlingVelocity);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    velocity = _clampOutwardEdgeVelocity(position, velocity);
    if (carriesInwardMomentum(position, velocity)) {
      final overAtTrailing = position.pixels > position.maxScrollExtent;
      return BouncingScrollSimulation(
        spring: spring,
        position: position.pixels,
        velocity: velocity,
        leadingExtent: overAtTrailing ? position.minScrollExtent : position.pixels,
        trailingExtent: overAtTrailing ? position.pixels : position.maxScrollExtent,
        tolerance: toleranceFor(position),
        constantDeceleration: _constantDeceleration,
      );
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
