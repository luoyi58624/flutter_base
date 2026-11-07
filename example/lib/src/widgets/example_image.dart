import 'package:flutter/widgets.dart';

/// 示例图片首帧的淡入时长。
final exampleImageFadeDuration = Duration(milliseconds: 160);

/// 让异步解码的首帧淡入，命中缓存时直接显示。
Widget exampleImageFrame(BuildContext context, Widget child, int? frame, bool synchronous) {
  if (frame == null || synchronous || MediaQuery.disableAnimationsOf(context)) return child;
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: exampleImageFadeDuration,
    curve: Curves.easeOut,
    child: child,
    builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
  );
}

/// 在已有尺寸约束的图片区域内留白。
Widget exampleImageError(BuildContext context, Object error, StackTrace? stack) => SizedBox.shrink();
