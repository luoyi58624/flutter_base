part of 'index.dart';

/// 从中心放大内容，适合状态标记和小型反馈。
class ElScaleAnimation extends ElSwitcherAnimation {
  /// 使用内置的连续缩放，隐藏时缩小至零。
  const ElScaleAnimation(super.value, {super.key, required super.child});

  @override
  SpringDescription get $motion => _feedbackMotion;

  @override
  Tolerance get $motionTolerance => _feedbackTolerance;

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return ScaleTransition(scale: animation, child: child);
  }
}
