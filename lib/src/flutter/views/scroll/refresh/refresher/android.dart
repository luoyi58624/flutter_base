// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/material.dart' show RefreshIndicatorStatus;
import 'package:flutter/widgets.dart';

import '../../../view/view.dart';
import '../../../view/style/style.dart';
import 'index.dart';

// ---- 官方 androidx SwipeRefreshLayout 常量 ----

/// DRAG_RATE：手指拉距 → 有效越界行程的阻尼系数。
const double _kDragRate = 0.5;

/// CIRCLE_DIAMETER：圆形卡片直径（dp）。
const double _kCircleDiameter = 40.0;

/// MAX_PROGRESS_ANGLE：拉出期弧长上限（圈数）。
const double _kMaxProgressAngle = 0.8;

/// Material 圆环中心半径。
const double _kMaterialCenterRadius = 7.5;

/// Material 圆环线宽。
const double _kMaterialStrokeWidth = 2.5;

/// Material 箭头宽度。
const double _kMaterialArrowWidth = 10.0;

/// Material 箭头高度。
const double _kMaterialArrowHeight = 5.0;

const Color _kAndroidSpinnerColor = Color(0xff409eff);

/// 构建直接进入旋转状态的 Android 指示器。
Widget buildAndroidRefreshSpinner() => const _RefreshMaterialSpinner(status: .refresh, color: _kAndroidSpinnerColor);

/// 安卓原生风格下拉刷新，逐式对齐官方 androidx SwipeRefreshLayout：
/// 圆形卡片从视口外滑入，手指行程经 DRAG_RATE=0.5 阻尼；到达触发距离前
/// 线性推进（箭头弧在 40% 行程后展开、整体 30% 透明度），达到后转全不
/// 透明并进入弹弓张力段（额外行程二次衰减，最多再前进一个触发距离）；
/// 松手达标 200ms 停靠（停靠 offset = 触发距离 − 卡片直径），刷新中为
/// CircularProgressDrawable 不定动画，完成后 150ms 原地缩小消失；
/// 未达标滑回视口外。
///
/// 手指下拉时内容钉在刷新边界，指示器独立浮出；惯性沿用容器物理。
class ElAndroidRefresher extends ElRefresher {
  /// 创建 Android 平台下拉刷新器。
  const ElAndroidRefresher({double? distanceToTrigger, this.color, this.bgColor})
    : _distanceToTrigger = distanceToTrigger,
      super(movesContent: false);

  /// 触发距离（**阻尼后**行程，官方 DEFAULT_CIRCLE_TARGET = 64dp）；
  /// 同时是弹弓张力段的 slingshotDist。
  double get distanceToTrigger => _distanceToTrigger ?? 64.0;
  final double? _distanceToTrigger;

  /// host 以原始拉距判定 armed；官方判定为 `拉距 × DRAG_RATE > 触发距离`。
  @override
  double get triggerExtent => distanceToTrigger / _kDragRate;

  /// 停靠位取 dragPercent 恰为 1 的原始拉距：位移公式在该点即官方停靠
  /// offset（spinnerOffsetEnd − circleDiameter，默认 24dp）。
  @override
  double get refreshingExtent => triggerExtent;

  /// 官方 ANIMATE_TO_TRIGGER_DURATION / ANIMATE_TO_START_DURATION = 200ms。
  @override
  Duration get settleDuration => const Duration(milliseconds: 200);

  /// 官方 SCALE_DOWN_DURATION = 150ms。
  @override
  Duration get finishDuration => const Duration(milliseconds: 150);

  /// 官方 DecelerateInterpolator(2) ≈ 1−(1−t)⁴。
  @override
  Curve get settleCurve => Curves.easeOutQuart;

  /// 官方 scale-down 动画的 AccelerateDecelerateInterpolator。
  @override
  Curve get finishCurve => Curves.easeInOutSine;

  /// 弧线颜色；null 用默认主色。
  final Color? color;

  /// 卡片背景色；null 用官方 CIRCLE_BG_LIGHT。
  final Color? bgColor;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    return _AndroidRefreshIndicator(
      details: details,
      distanceToTrigger: distanceToTrigger,
      color: color ?? _kAndroidSpinnerColor,
      bgColor: bgColor ?? const Color(0xfffafafa),
    );
  }
}

class _AndroidRefreshIndicator extends StatefulWidget {
  const _AndroidRefreshIndicator({
    required this.details,
    required this.distanceToTrigger,
    required this.color,
    required this.bgColor,
  });

  final ElRefreshDetails details;
  final double distanceToTrigger;
  final Color color;
  final Color bgColor;

  @override
  State<_AndroidRefreshIndicator> createState() => _AndroidRefreshIndicatorState();
}

class _AndroidRefreshIndicatorState extends State<_AndroidRefreshIndicator> {
  @override
  void initState() {
    super.initState();
    widget.details.snapshot.addListener(_handleSnapshotChanged);
  }

  @override
  void didUpdateWidget(covariant _AndroidRefreshIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.details.snapshot == widget.details.snapshot) return;
    oldWidget.details.snapshot.removeListener(_handleSnapshotChanged);
    widget.details.snapshot.addListener(_handleSnapshotChanged);
  }

  void _handleSnapshotChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.details.snapshot.removeListener(_handleSnapshotChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.details.snapshot.value;
    if (snapshot.status == null) {
      return const ElView(style: ElStyle(width: 0, height: 0));
    }

    // 官方 moveSpinner() 逐式复刻。
    final overscroll = snapshot.pulledExtent * _kDragRate;
    final slingshot = widget.distanceToTrigger;
    final dragPercent = math.min(1.0, overscroll / slingshot);
    final adjusted = math.max(dragPercent - 0.4, 0.0) * 5 / 3;
    final extraOs = math.max(0.0, overscroll - slingshot);
    final tensionSlingshotPercent = math.max(0.0, math.min(extraOs, slingshot * 2) / slingshot);
    final q = tensionSlingshotPercent / 4;
    final tensionPercent = (q - q * q) * 2.0;
    final extraMove = slingshot * tensionPercent * 2;
    var travel = -_kCircleDiameter + slingshot * dragPercent + extraMove;
    var scale = 1.0;
    if (snapshot.status == RefreshIndicatorStatus.done) {
      travel = slingshot - _kCircleDiameter;
      scale = math.max(snapshot.progress, 0.001);
    }
    final canceling = snapshot.status == RefreshIndicatorStatus.canceled;
    final endTrim = canceling ? 0.0 : math.min(_kMaxProgressAngle, adjusted * 0.8);
    final ringRotation = canceling ? 0.0 : (-0.25 + 0.4 * adjusted + tensionPercent * 2) * 0.5;
    final atStart = snapshot.anchoredAtViewportStart;

    return ElView(
      style: ElStyle(alignment: atStart ? Alignment.topCenter : Alignment.bottomCenter, pointerEvents: .none),
      child: ElView(
        style: ElStyle(
          width: _kCircleDiameter,
          height: _kCircleDiameter,
          backgroundColor: widget.bgColor,
          borderRadius: .all(Radius.circular(_kCircleDiameter / 2)),
          boxShadow: [BoxShadow(color: const Color(0x2e000000), blurRadius: 5, offset: const Offset(0, 2))],
          transform: .matrix(scale, 0, 0, scale, 0, atStart ? travel : -travel),
          alignment: .center,
        ),
        child: ElView(
          style: ElStyle(
            opacity: snapshot.status == RefreshIndicatorStatus.drag || canceling ? 0.3 : 1.0,
            transition: const [.all(Duration(milliseconds: 300))],
          ),
          child: _RefreshMaterialSpinner(
            status: snapshot.status,
            color: widget.color,
            endTrim: endTrim,
            rotation: ringRotation,
            arrowScale: canceling ? 0.0 : math.min(1.0, adjusted),
          ),
        ),
      ),
    );
  }
}

/// Material 圆形进度，对齐官方 CircularProgressDrawable：
/// 拉出期（dragging / armed）画静态箭头弧；**释放激活即起转**（用户裁决：
/// 官方等停靠动画结束才 start() 会让短刷新全程只见箭头、见不到加载器，
/// 不跟随）——起转先走 666ms 收拢段（拉出弧收成起始点、rotation 转正到
/// 整档，**箭头在收拢段前 1/4 快速淡出**，读感是"箭头变成加载器"），
/// 再进入 1332ms/圈的不定动画——弧长在 0.01↔0.8 圈间按 fastOutSlowIn
/// 涨缩、ring 每圈附加 0.19 圈旋转、外加 216°/圈的组旋转。
class _RefreshMaterialSpinner extends StatefulWidget {
  /// 创建 Material 刷新进度指示器。
  const _RefreshMaterialSpinner({
    required this.status,
    required this.color,
    this.endTrim = 0.0,
    this.rotation = 0.0,
    this.arrowScale = 0.0,
  }) : size = 40.0;

  /// 当前刷新阶段。
  final RefreshIndicatorStatus? status;

  /// 弧线与箭头颜色。
  final Color color;

  /// 拉出期弧终点 trim（圈数，0..0.8）。
  final double endTrim;

  /// 拉出期 ring 旋转（圈数，叠加进弧角）。
  final double rotation;

  /// 拉出期箭头缩放（0..1）。
  final double arrowScale;

  /// 指示器方形边长。
  final double size;

  /// 创建进度指示器状态。
  @override
  State<_RefreshMaterialSpinner> createState() => _RefreshMaterialSpinnerState();
}

class _RefreshMaterialSpinnerState extends State<_RefreshMaterialSpinner> with SingleTickerProviderStateMixin {
  // 官方 CircularProgressDrawable 常量。
  static const double _minArc = 0.01; // MIN_PROGRESS_ARC
  static const double _maxArc = 0.8; // MAX_PROGRESS_ARC
  static const double _ringRotationPerCycle = 0.19; // RING_ROTATION
  static const double _groupRotationPerCycle = 216.0 / 360.0; // GROUP_FULL_ROTATION
  static const Duration _cycleDuration = Duration(milliseconds: 1332); // ANIMATION_DURATION

  late final AnimationController _ticker = AnimationController(vsync: this, duration: _cycleDuration)
    ..addListener(_handleTick);

  /// 收拢段（官方 mFinishing）：从释放瞬间的箭头弧收成起始点。
  bool _intro = false;

  /// 释放帧冻结值（官方停靠滑动期 moveSpinner 不再被调，弧保持释放形态；
  /// 收拢段与主循环 originals 都从这里出发）。
  bool _frozenCaptured = false;
  double _frozenEndTrim = 0.0;
  double _frozenRotation = 0.0;
  double _frozenArrowScale = 0.0;

  /// 不定动画的 per-cycle originals（官方 storeOriginals 语义）。
  double _cycleStartTrim = 0.0;
  double _cycleRotation = 0.0;
  int _rotationCount = 0;
  double _lastValue = 0.0;

  /// 已进入旋转（收拢段或主循环）；对应官方 mProgress.start() 已调。
  bool _spinStarted = false;

  bool get _inRefreshPhase =>
      widget.status == RefreshIndicatorStatus.refresh || widget.status == RefreshIndicatorStatus.done;

  /// 起转时机 = 释放激活（进入 refreshing）即刻；finishing 期间旋转不停
  /// （scale-down 陪跑）。不等停靠动画结束——用户裁决，见类注释。
  bool get _shouldSpin => _inRefreshPhase;

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant _RefreshMaterialSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    if (!_inRefreshPhase) {
      _frozenCaptured = false;
      if (_spinStarted) {
        _spinStarted = false;
        _intro = false;
        _ticker.stop();
      }
      return;
    }
    // 进入刷新期首帧（armed 释放瞬间）：冻结当时的弧参数。
    if (!_frozenCaptured) {
      _frozenCaptured = true;
      _frozenEndTrim = widget.endTrim;
      _frozenRotation = widget.rotation;
      _frozenArrowScale = widget.arrowScale;
    }
    if (!_shouldSpin || _spinStarted) return;
    _spinStarted = true;
    _cycleStartTrim = 0.0;
    _cycleRotation = 0.0;
    _rotationCount = 0;
    _lastValue = 0.0;
    if (_frozenEndTrim > 0) {
      // 官方 start()：已有可见弧 → 先走半周期收拢段。
      _intro = true;
      _ticker.duration = _cycleDuration ~/ 2;
      _ticker.forward(from: 0.0).then((_) {
        if (!mounted || !_spinStarted) return;
        _intro = false;
        // 官方 onAnimationRepeat 的 storeOriginals + setStartTrim(endTrim)：
        // 主循环 originals 接在收拢段末端（弧位、旋转零跳变），而不是
        // 从 0 重开——否则弧瞬移一段圆周，肉眼即"断裂"。
        _cycleStartTrim = (_frozenEndTrim - _minArc) % 1.0;
        _cycleRotation = ((_frozenRotation / _maxArc).floorToDouble() + 1.0) % 1.0;
        _ticker.duration = _cycleDuration;
        _lastValue = 0.0;
        _ticker.repeat();
      });
    } else {
      _intro = false;
      _ticker.duration = _cycleDuration;
      _ticker.repeat();
    }
  }

  void _handleTick() {
    if (_intro) {
      _lastValue = _ticker.value;
    } else if (_ticker.value < _lastValue) {
      // 一圈结束（官方 onAnimationRepeat）：本圈末端值转正为下一圈 originals。
      _cycleStartTrim = (_cycleStartTrim + (_maxArc - _minArc)) % 1.0;
      _cycleRotation = (_cycleRotation + _ringRotationPerCycle) % 1.0;
      _rotationCount = (_rotationCount + 1) % 5;
    }
    _lastValue = _ticker.value;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double startTrim;
    double endTrim;
    double rotation;
    var groupRotation = 0.0;
    var arrowScale = 0.0;
    if (!_spinStarted) {
      startTrim = 0.0;
      if (_inRefreshPhase) {
        // 停靠滑动期（官方 moveSpinner 已停调）：弧冻结在释放帧。
        endTrim = _frozenEndTrim;
        rotation = _frozenRotation;
        arrowScale = _frozenArrowScale;
      } else {
        endTrim = widget.endTrim;
        rotation = widget.rotation;
        arrowScale = widget.arrowScale;
      }
    } else if (_intro) {
      // 官方 applyFinishTranslation：startTrim 追上 endTrim，rotation 对齐
      // 下一整档；箭头在收拢段前 1/4 快速缩小淡出。
      final t = _ticker.value;
      final target = (_frozenRotation / _maxArc).floorToDouble() + 1.0;
      startTrim = (_frozenEndTrim - _minArc) * t;
      endTrim = _frozenEndTrim;
      rotation = _frozenRotation + (target - _frozenRotation) * t;
      arrowScale = _frozenArrowScale * (1.0 - (t / 0.25).clamp(0.0, 1.0));
    } else {
      // 官方 applyTransformation 不定段：前半圈涨弧、后半圈缩弧。
      final t = _ticker.value;
      if (t < 0.5) {
        startTrim = _cycleStartTrim;
        endTrim = startTrim + _minArc + (_maxArc - _minArc) * Curves.fastOutSlowIn.transform(t / 0.5);
      } else {
        endTrim = _cycleStartTrim + _maxArc;
        startTrim = endTrim - (_minArc + (_maxArc - _minArc) * (1 - Curves.fastOutSlowIn.transform((t - 0.5) / 0.5)));
      }
      rotation = _cycleRotation + _ringRotationPerCycle * t;
      groupRotation = _groupRotationPerCycle * (t + _rotationCount);
    }
    return _MaterialRingPaint(
      diameter: widget.size,
      color: widget.color,
      startTrim: startTrim,
      endTrim: endTrim,
      rotation: rotation,
      groupRotation: groupRotation,
      arrowScale: arrowScale,
    );
  }
}

class _MaterialRingPaint extends LeafRenderObjectWidget {
  const _MaterialRingPaint({
    required this.diameter,
    required this.color,
    required this.startTrim,
    required this.endTrim,
    required this.rotation,
    required this.groupRotation,
    required this.arrowScale,
  });

  final double diameter;
  final Color color;
  final double startTrim;
  final double endTrim;
  final double rotation;
  final double groupRotation;
  final double arrowScale;

  @override
  _RenderMaterialRing createRenderObject(BuildContext context) {
    return _RenderMaterialRing(
      diameter: diameter,
      color: color,
      startTrim: startTrim,
      endTrim: endTrim,
      rotation: rotation,
      groupRotation: groupRotation,
      arrowScale: arrowScale,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderMaterialRing renderObject) {
    renderObject
      ..diameter = diameter
      ..color = color
      ..startTrim = startTrim
      ..endTrim = endTrim
      ..rotation = rotation
      ..groupRotation = groupRotation
      ..arrowScale = arrowScale;
  }
}

class _RenderMaterialRing extends RenderBox {
  _RenderMaterialRing({
    required double diameter,
    required Color color,
    required double startTrim,
    required double endTrim,
    required double rotation,
    required double groupRotation,
    required double arrowScale,
  }) : _diameter = diameter,
       _color = color,
       _startTrim = startTrim,
       _endTrim = endTrim,
       _rotation = rotation,
       _groupRotation = groupRotation,
       _arrowScale = arrowScale;

  double _diameter;

  double get diameter => _diameter;

  set diameter(double value) {
    if (_diameter == value) return;
    _diameter = value;
    markNeedsLayout();
  }

  Color _color;

  Color get color => _color;

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  double _startTrim;

  double get startTrim => _startTrim;

  set startTrim(double value) {
    if (_startTrim == value) return;
    _startTrim = value;
    markNeedsPaint();
  }

  double _endTrim;

  double get endTrim => _endTrim;

  set endTrim(double value) {
    if (_endTrim == value) return;
    _endTrim = value;
    markNeedsPaint();
  }

  double _rotation;

  double get rotation => _rotation;

  set rotation(double value) {
    if (_rotation == value) return;
    _rotation = value;
    markNeedsPaint();
  }

  double _groupRotation;

  double get groupRotation => _groupRotation;

  set groupRotation(double value) {
    if (_groupRotation == value) return;
    _groupRotation = value;
    markNeedsPaint();
  }

  double _arrowScale;

  double get arrowScale => _arrowScale;

  set arrowScale(double value) {
    if (_arrowScale == value) return;
    _arrowScale = value;
    markNeedsPaint();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size.square(diameter));

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintMaterialRing(context.canvas, offset, size, color, startTrim, endTrim, rotation, groupRotation, arrowScale);
  }
}

void _paintMaterialRing(
  Canvas canvas,
  Offset offset,
  Size size,
  Color color,
  double startTrim,
  double endTrim,
  double rotation,
  double groupRotation,
  double arrowScale,
) {
  final sweep = (endTrim - startTrim) * 2 * math.pi;
  if (sweep <= 0 && arrowScale <= 0) return;
  final center = size.center(offset);
  final arcRadius = _kMaterialCenterRadius + _kMaterialStrokeWidth / 2;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(groupRotation * 2 * math.pi);
  final startAngle = (startTrim + rotation) * 2 * math.pi;
  if (sweep > 0) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kMaterialStrokeWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: arcRadius), startAngle, sweep, false, paint);
  }
  if (arrowScale > 0) {
    canvas.rotate(startAngle + sweep);
    final w = _kMaterialArrowWidth * arrowScale;
    final h = _kMaterialArrowHeight * arrowScale;
    final path = Path()
      ..moveTo(arcRadius - w / 2, _kMaterialStrokeWidth / 2)
      ..lineTo(arcRadius + w / 2, _kMaterialStrokeWidth / 2)
      ..lineTo(arcRadius, _kMaterialStrokeWidth / 2 + h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
  canvas.restore();
}
