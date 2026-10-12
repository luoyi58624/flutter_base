part of 'index.dart';

/// 从右侧滑入的面板过渡，滑出部分裁剪在原有布局内。
class ElSlideAnimation extends ElSwitcherAnimation {
  /// 使用内置的连续位移和停靠节奏。
  const ElSlideAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 180);

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return ClipRect(
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
