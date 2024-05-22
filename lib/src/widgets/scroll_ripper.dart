part of '../../flutter_base.dart';

/// 滚动触顶波纹（安卓平台）
class ScrollerRipperWidget extends StatelessWidget {
  const ScrollerRipperWidget({super.key, required this.child, this.color, this.disabledRipper});

  final Widget child;

  /// 禁用水波纹
  final bool? disabledRipper;

  /// 水波纹颜色，默认灰色
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _RipperScrollBehavior(
        disabledRipper ?? false,
        color ?? const Color(0xFF9E9E9E),
      ),
      child: child,
    );
  }
}

/// 设置安卓平台滚动水波纹行为
class _RipperScrollBehavior extends ScrollBehavior {
  final bool disabledRipper;
  final Color color;

  const _RipperScrollBehavior(this.disabledRipper, this.color);

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    var target = getPlatform(context);
    if (target == TargetPlatform.android || target == TargetPlatform.fuchsia) {
      return GlowingOverscrollIndicator(
        // 去除滚动到顶部的水波纹
        showLeading: disabledRipper == true ? false : true,
        // 去除滚动到底部的水波纹
        showTrailing: disabledRipper == true ? false : true,
        axisDirection: details.direction,
        color: color,
        child: child,
      );
    } else {
      return child;
    }
  }
}
