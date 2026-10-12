part of 'index.dart';

/// 折叠内容并让出布局空间，内容固定在展开起点。
class ElCollapseAnimation extends ElSwitcherAnimation {
  /// 配置折叠方向及关闭后是否保留内容状态。
  const ElCollapseAnimation(
    super.value, {
    super.key,
    required super.child,
    this.axis = Axis.vertical,
    this.keepState = true,
  });

  /// 折叠方向，默认收缩高度。
  final Axis axis;

  /// 是否保留内容状态，为 false 时在退场完成后销毁内容。
  final bool keepState;

  @override
  Duration get $duration => const Duration(milliseconds: 180);

  @override
  Widget builder(BuildContext context, Animation<double> animation) {
    final content = SizeTransition(
      axis: axis,
      alignment: AlignmentDirectional.topStart,
      sizeFactor: animation,
      child: keepState
          ? child
          : AnimatedBuilder(
              animation: animation,
              // 退场结束再销毁，途中重新展开仍复用原有子组件。
              builder: (context, _) => !value && animation.value == 0
                  ? ElEmptyWidget.instance
                  : child,
            ),
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      // 只柔化正在移动的裁剪边缘，避免字形和图标被生硬切成半截。
      shaderCallback: (bounds) {
        final length = axis == Axis.vertical ? bounds.height : bounds.width;
        final progress = animation.value.clamp(0.0, 1.0);
        final fade =
            math.min(14.0, length * 0.35) *
            (1 - ((progress - 0.82) / 0.18).clamp(0.0, 1.0));
        final stop = length > 0 ? (1 - fade / length).clamp(0.0, 1.0) : 1.0;
        return LinearGradient(
          begin: axis == Axis.vertical
              ? Alignment.topCenter
              : AlignmentDirectional.centerStart,
          end: axis == Axis.vertical
              ? Alignment.bottomCenter
              : AlignmentDirectional.centerEnd,
          colors: const [
            Color(0xffffffff),
            Color(0xffffffff),
            Color(0x00ffffff),
          ],
          stops: [0, stop, 1],
        ).createShader(
          bounds,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        );
      },
      child: content,
    );
  }
}
