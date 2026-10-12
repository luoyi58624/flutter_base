part of 'index.dart';

/// 轻量淡入淡出，适合提示和辅助内容。
class ElFadeAnimation extends ElSwitcherAnimation {
  /// 使用内置的柔和显隐节奏。
  const ElFadeAnimation(super.value, {super.key, required super.child});

  @override
  Duration get $duration => const Duration(milliseconds: 140);

  @override
  bool get $opacityOnly => true;

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    return FadeTransition(opacity: animation, child: child);
  }
}
