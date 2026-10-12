part of 'index.dart';

// 使用 Flutter Cupertino 对话框与 action sheet 的弹簧和停靠精度。
const _spatialMotion = SpringDescription(
  mass: 1,
  stiffness: 522.35,
  damping: 45.7099552,
);
const _spatialTolerance = Tolerance(distance: 0.001, velocity: 0.03);

// 小幅反馈使用 Material fast spatial 的刚度；临界阻尼保证布局与尺寸不越界。
final _feedbackMotion = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 1400,
);
const _feedbackTolerance = Tolerance(distance: 0.0015, velocity: 0.09375);

// 透明度使用 Material fast effects；停靠精度按 alpha 的可见变化设置。
final _effectsMotion = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 3800,
);
const _effectsTolerance = Tolerance(
  distance: 3 / 1024,
  velocity: 3 / 1024 * 62.5,
);

/// 保持同一响应和当前速度，不因反转或剩余距离而突然提高刚度。
void _driveMotion(
  AnimationController controller,
  bool value,
  SpringDescription motion,
  Tolerance tolerance,
) {
  final target = value ? 1.0 : 0.0;
  final velocity = controller.velocity;
  if (controller.value == target && velocity == 0) {
    controller.value = target;
    return;
  }
  final simulation = SpringSimulation(
    motion,
    controller.value,
    target,
    velocity,
    tolerance: tolerance,
    snapToEnd: true,
  );
  if (value) {
    controller.animateWith(simulation);
  } else {
    controller.animateBackWith(simulation);
  }
}
