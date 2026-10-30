// Flutter authors 的 Android stretch 算法，来自 Flutter 3.47 overscroll_indicator.dart / stretch_effect.dart。
// Copyright 2014 The Flutter Authors. All rights reserved.
// 许可全文见 doc/flutter-scroll-license.txt；算法与 shader 常量保持原值，仅把绘制限定到正文连续段。
part of '../virtual/virtual_pipeline.dart';

final class _ScrollStretchNotification extends OverscrollIndicatorNotification {
  _ScrollStretchNotification({required super.leading});
  bool isAccepted = true;
  @override
  void disallowIndicator() {
    isAccepted = false;
    super.disallowIndicator();
  }
}

final class _ScrollStretch {
  _ScrollStretch(this.host);
  final ElScrollViewState host;
  late StretchingOverscrollIndicator configuration;
  AnimationController? _animation;
  double _value = 0;
  double _interrupted = 0;
  double _total = 0;
  bool _accepted = true;
  bool _disposed = false;
  ui.FragmentShader? _shader;
  bool _shaderRequested = false;

  Axis get axis => configuration.axis;
  bool get active => _value != 0;
  double get strength => axisDirectionIsReversed(configuration.axisDirection) ? _value : -_value;

  void _setValue(double value) {
    value = value.clamp(-1.0, 1.0);
    if (_disposed || _value == value) return;
    _value = value;
    final viewport = host._activeMixinViewportRenderObject();
    viewport?.markNeedsPaint();
    viewport?.markNeedsSemanticsUpdate();
  }

  void handle(ScrollNotification notification) {
    if (_disposed || !configuration.notificationPredicate(notification) || notification.metrics.axis != axis) return;
    if (notification is ScrollStartNotification) {
      _accepted = true;
      _total = 0;
    } else if (notification is OverscrollNotification) {
      // 与当前 SDK 一致，每次边界通知都允许祖先关闭装饰。
      final confirmation = _ScrollStretchNotification(leading: notification.overscroll < 0);
      confirmation.dispatch(host.context);
      _accepted = confirmation.isAccepted;
      if (!_accepted) return;
      _total += notification.overscroll;
      if (notification.velocity != 0) {
        _animate((notification.velocity / 3000).clamp(-1.25, 1.25));
      } else if (notification.dragDetails != null && notification.metrics.viewportDimension > 0) {
        if (_animation != null) {
          _interrupted = _animation!.value;
          _animation!.dispose();
          _animation = null;
        }
        final distance = (_total / notification.metrics.viewportDimension).clamp(-1.0, 1.0);
        final intensity = .016 * distance.abs() + .016 * (1 - math.exp(-distance.abs() * math.e / .33));
        _setValue(distance.sign * intensity + _interrupted);
      }
    } else if (notification is ScrollEndNotification) {
      var velocity = axis == .vertical
          ? notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0.0
          : notification.dragDetails?.velocity.pixelsPerSecond.dx ?? 0.0;
      if (axisDirectionIsReversed(configuration.axisDirection)) velocity = -velocity;
      _total = 0;
      if (_accepted) _end(velocity);
    } else if (notification is ScrollUpdateNotification) {
      _total = 0;
      _end(0);
    }
  }

  void _end(double velocity) {
    if ((velocity != 0 || _value != 0) && _animation == null) _animate((-velocity / 6000).clamp(-.5, .5));
  }

  void _animate(double velocity) {
    _animation?.dispose();
    final animation = _animation = AnimationController.unbounded(vsync: host);
    animation.addListener(() => _setValue(animation.value));
    animation
        .animateWith(
          SpringSimulation(
            SpringDescription.withDampingRatio(mass: 1, stiffness: 24.657 * 24.657 * .8 * .8, ratio: .98),
            _value,
            0,
            velocity * .8,
          ),
        )
        .whenComplete(() {
          if (_disposed || !identical(_animation, animation)) return;
          _setValue(0);
          _interrupted = 0;
          _animation = null;
          animation.dispose();
        });
  }

  Matrix4 matrix(Size size) {
    final scale = 1 + strength.abs();
    final shift = strength < 0 ? (axis == .vertical ? size.height : size.width) * (1 - scale) : 0.0;
    return axis == .vertical
        ? (Matrix4.diagonal3Values(1, scale, 1)..setTranslationRaw(0, shift, 0))
        : (Matrix4.diagonal3Values(scale, 1, 1)..setTranslationRaw(shift, 0, 0));
  }

  void paint(PaintingContext context, Offset offset, Size size, PaintingContextCallback paintBody) {
    if (!ui.ImageFilter.isShaderFilterSupported) {
      context.pushTransform(true, offset, matrix(size), paintBody);
      return;
    }
    if (!_shaderRequested) {
      _shaderRequested = true;
      ui.FragmentProgram.fromAsset('shaders/stretch_effect.frag').then((program) {
        if (_disposed) return;
        _shader = program.fragmentShader();
        host._activeMixinViewportRenderObject()?.markNeedsPaint();
      });
    }
    final shader = _shader;
    if (shader == null) {
      paintBody(context, offset);
      return;
    }
    shader
      ..setFloat(2, 1)
      ..setFloat(3, axis == .horizontal ? strength : 0)
      ..setFloat(4, axis == .vertical ? strength : 0)
      ..setFloat(5, .7);
    context.pushLayer(ImageFilterLayer(imageFilter: ui.ImageFilter.shader(shader), offset: offset), (inner, origin) {
      inner.pushClipRect(true, origin, Offset.zero & size, (clipped, point) {
        clipped.canvas.drawPoints(ui.PointMode.points, [
          point,
          point + Offset(size.width - 1, 0),
          point + Offset(0, size.height - 1),
          point + Offset(size.width - 1, size.height - 1),
        ], Paint()..color = const Color.fromARGB(1, 0, 0, 0));
        paintBody(clipped, point);
      });
    }, offset);
  }

  void dispose() {
    _disposed = true;
    _animation?.dispose();
    _shader?.dispose();
  }
}
