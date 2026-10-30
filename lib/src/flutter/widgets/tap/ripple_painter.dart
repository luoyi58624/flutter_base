// Copyright 2014 The Flutter Authors. All rights reserved.
// 源自 Flutter material/ink_ripple.dart 与 ink_well.dart，BSD 许可见 LICENSE.flutter。
// 移植传统 InkRipple 的动画与圆形绘制，Material 宿主改由 ElView 承担。

part of 'index.dart';

class _Ripple {
  _Ripple({
    required TickerProvider vsync,
    required this.position,
    required Size size,
    required VoidCallback repaint,
    required void Function(_Ripple) onRemoved,
  }) {
    final targetRadius = size.bottomRight(Offset.zero).distance / 2;
    _fadeIn = AnimationController(duration: const Duration(milliseconds: 75), vsync: vsync)
      ..addListener(repaint)
      ..forward();
    _radiusController = AnimationController(duration: const Duration(seconds: 1), vsync: vsync)
      ..addListener(repaint)
      ..forward();
    _radius = _radiusController.drive(
      Tween<double>(begin: targetRadius * 0.30, end: targetRadius + 5).chain(CurveTween(curve: Curves.ease)),
    );
    _fadeOut = AnimationController(duration: const Duration(milliseconds: 375), vsync: vsync)
      ..addListener(repaint)
      ..addStatusListener((status) {
        if (status.isCompleted) onRemoved(this);
      });
  }

  final Offset position;
  late final AnimationController _radiusController;
  late final Animation<double> _radius;
  late final AnimationController _fadeIn;
  late final AnimationController _fadeOut;

  /// 移回元素时恢复扩散完成的按压态，同时停止离开时的淡出。
  void showPressed() {
    _fadeOut.value = 0;
    _fadeIn.value = 1;
    _radiusController.value = 1;
  }

  void confirm() {
    _radiusController
      ..duration = const Duration(milliseconds: 225)
      ..forward();
    _fadeIn.forward();
    _fadeOut.animateTo(1, duration: const Duration(milliseconds: 375));
  }

  void cancel() {
    _fadeIn.stop();
    final fadeOutValue = 1 - _fadeIn.value;
    // 值为 1 时会同步触发移除，后面不能再访问已销毁的控制器。
    _fadeOut.value = fadeOutValue;
    if (fadeOutValue < 1) _fadeOut.animateTo(1, duration: const Duration(milliseconds: 75));
  }

  void paint(Canvas canvas, Color color, Size size) {
    final maxAlpha = (color.a * 255).round();
    // 官方退出时间轴：前 225ms 保持颜色，后 150ms 淡出。
    final fadeOut = const Interval(225 / 375, 1).transform(_fadeOut.value);
    final alpha = _fadeIn.isAnimating ? (maxAlpha * _fadeIn.value).round() : (maxAlpha - maxAlpha * fadeOut).round();
    final center = Offset.lerp(position, size.center(Offset.zero), Curves.ease.transform(_radiusController.value))!;
    canvas.drawCircle(center, _radius.value, Paint()..color = color.withAlpha(alpha));
  }

  void dispose() {
    _radiusController.dispose();
    _fadeIn.dispose();
    _fadeOut.dispose();
  }
}
