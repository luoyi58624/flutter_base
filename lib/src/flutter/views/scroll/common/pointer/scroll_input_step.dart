import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 单次正文输入接受量与实际像素位移的分账，供私有设备边界适配使用。
@internal
final class ScrollInputStep {
  const ScrollInputStep._(this.acceptedInput, this.appliedDisplacement, this.remainingInput, this.overscroll);

  /// 正文接受的物理轴输入，阻尼缩短位移不会退回已经接受的输入。
  final double acceptedInput;

  /// position 的原始像素位移，与输入使用不同单位口径。
  final double appliedDisplacement;

  /// 仍可交给后续参与者的输入预算。
  final double remainingInput;

  /// 原始像素域的边界反馈，不能作为后续参与者的输入预算。
  final double overscroll;

  /// 对有限、同向且单调的拖拽物理求解边界截断所接受的输入。
  /// [stopAtBoundary] 将越界回拖截在真实边界，供效果前置分账保留正文回位预算。
  static ScrollInputStep resolve(
    ScrollMetrics metrics,
    ScrollPhysics physics,
    double primaryDelta, {
    bool clampToRange = false,
    bool stopAtBoundary = false,
  }) {
    if (primaryDelta == 0) return const ScrollInputStep._(0, 0, 0, 0);
    if (!primaryDelta.isFinite) throw FlutterError('滚动输入必须有限。');
    if (!metrics.hasPixels || !metrics.hasContentDimensions) return ScrollInputStep._(0, 0, primaryDelta, 0);
    final axisScale = axisDirectionIsReversed(metrics.axisDirection) ? -1.0 : 1.0;
    final userOffset = primaryDelta * axisScale;
    final adjusted = physics.applyPhysicsToUserOffset(metrics, userOffset);
    if (!adjusted.isFinite || (adjusted != 0 && adjusted.sign != userOffset.sign)) {
      throw FlutterError('滚动阻尼必须返回有限且同向的位移。');
    }
    if (adjusted == 0) return ScrollInputStep._(primaryDelta, 0, 0, 0);
    final targetPixels = metrics.pixels - adjusted;
    final attemptedDisplacement = targetPixels - metrics.pixels;
    if (attemptedDisplacement == 0) return ScrollInputStep._(primaryDelta, 0, 0, 0);
    final overscroll =
        stopAtBoundary &&
            (metrics.pixels < metrics.minScrollExtent && targetPixels > metrics.minScrollExtent ||
                metrics.pixels > metrics.maxScrollExtent && targetPixels < metrics.maxScrollExtent)
        ? targetPixels - metrics.pixels.clamp(metrics.minScrollExtent, metrics.maxScrollExtent)
        : clampToRange && !metrics.outOfRange
        ? targetPixels - targetPixels.clamp(metrics.minScrollExtent, metrics.maxScrollExtent)
        : physics.applyBoundaryConditions(metrics, targetPixels);
    if (overscroll == 0) return ScrollInputStep._(primaryDelta, attemptedDisplacement, 0, 0);
    if (!overscroll.isFinite ||
        overscroll.sign != attemptedDisplacement.sign ||
        overscroll.abs() > attemptedDisplacement.abs()) {
      throw FlutterError('滚动边界必须保留同向且不放大的位移。');
    }
    // 以真实候选坐标计算落点，贴边的小数输入不会因两种减法顺序产生反号尾差。
    final acceptedOffset = metrics.pixels - (targetPixels - overscroll);
    double accepted;
    if (acceptedOffset == 0) {
      accepted = 0;
    } else if (acceptedOffset.abs() >= adjusted.abs()) {
      accepted = userOffset;
    } else if (adjusted == userOffset) {
      accepted = acceptedOffset;
    } else {
      // 仅部分撞界且有阻尼时反算，不能把像素 overscroll 从输入预算直接相减。
      var lower = 0.0;
      var upper = userOffset.abs();
      final target = acceptedOffset.abs();
      for (var iteration = 0; iteration < 48; iteration++) {
        final middle = (lower + upper) / 2;
        final applied = physics.applyPhysicsToUserOffset(metrics, middle * userOffset.sign);
        if (!applied.isFinite || (applied != 0 && applied.sign != userOffset.sign)) {
          throw FlutterError('滚动阻尼必须返回有限且同向的位移。');
        }
        if (applied.abs() <= target) {
          lower = middle;
        } else {
          upper = middle;
        }
      }
      // 回位取内侧近似，避免浮点尾差把已到边界的下一帧仍判成越界阻尼。
      accepted = (stopAtBoundary ? upper : lower) * userOffset.sign;
    }
    return ScrollInputStep._(accepted * axisScale, -acceptedOffset, (userOffset - accepted) * axisScale, overscroll);
  }
}
