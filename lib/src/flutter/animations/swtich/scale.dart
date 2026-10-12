part of 'index.dart';

/// 从中心缩放内容，适合状态标记和小型反馈。
class ElScaleAnimation extends ElSwitcherAnimation {
  /// 使用内置的减速过渡，隐藏时缩小至零。
  const ElScaleAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 160);

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return ScaleTransition(scale: animation, child: child);
  }
}
