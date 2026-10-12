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
    return SizeTransition(
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
  }
}
