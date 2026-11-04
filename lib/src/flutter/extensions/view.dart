part of 'index.dart';

/// 为视图样式添加按压反馈。
extension ElStyleTapExt on ElStyle {
  /// 将按压态的变换设为 [scale] 倍缩放，保留其他按压属性及已有过渡。
  ///
  /// 常态和已声明的按压过渡表各自补上缺少的 100ms `easeOut` 变换过渡。
  ElStyle withTapScale({double scale = 0.95}) {
    List<ElTransition> withScaleTransition(List<ElTransition>? transitions) {
      if (transitions != null && transitions.any((item) => item.covers(.transform))) return transitions;
      return [...?transitions, const ElTransition.field(.transform, Duration(milliseconds: 100), Curves.easeOut)];
    }

    final tapTransitions = onTap?.transition;
    return merge(
      ElStyle(
        transition: withScaleTransition(transition),
        onTap: ElStyle(
          transform: .scale(scale),
          transition: tapTransitions == null ? null : withScaleTransition(tapTransitions),
        ),
      ),
    );
  }
}
