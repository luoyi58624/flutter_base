part of 'index.dart';

/// 为视图样式添加按压反馈。
extension ElStyleTapExt on ElStyle {
  /// 将按压透明度设为 [opacity]，默认立即淡化并用 250ms 恢复。
  ///
  /// 保留其他按压属性与显式过渡；触摸反馈保持时间仍由事件配置决定。
  ElStyle withTapFade([double opacity = 0.2]) {
    const enter = ElTransition.field(.opacity, Duration.zero);
    const leave = ElTransition.field(.opacity, Duration(milliseconds: 250), Curves.easeInOutQuad);

    List<ElTransition> withOpacityTransition(List<ElTransition>? transitions, ElTransition fallback) {
      if (transitions != null && transitions.any((item) => item.covers(.opacity))) return transitions;
      return [...?transitions, fallback];
    }

    final tapTransitions = onTap?.transition;
    return merge(
      ElStyle(
        transition: withOpacityTransition(transition, leave),
        onTap: ElStyle(
          opacity: opacity,
          // 按压表整体替换常态表，继承其他字段过渡以便与缩放等效果组合。
          transition: tapTransitions == null ? [...?transition, enter] : withOpacityTransition(tapTransitions, enter),
        ),
      ),
    );
  }

  /// 将按压态的变换设为 [scale] 倍缩放，保留其他按压属性及已有过渡。
  ///
  /// 常态和已声明的按压过渡表各自补上缺少的 100ms `easeOut` 变换过渡。
  ElStyle withTapScale([double scale = 0.95]) {
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
