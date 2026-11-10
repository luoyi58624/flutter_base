import 'dart:math' as math;

// ignore_for_file: prefer_initializing_formals — 命名参数映射私有字段。

import 'package:flutter/material.dart' show RefreshIndicatorStatus;
import 'package:flutter/widgets.dart';

import '../../../views/view/view.dart';
import '../../../views/view/style/style.dart';
import 'refresher.dart';

// ---- 官方 CupertinoSliverRefreshControl / CupertinoActivityIndicator 常量 ----

/// 指示器在露出间隙中央时允许松手刷新。
const double _kIosTriggerPullDistance = 60.0;

/// _defaultRefreshIndicatorExtent。
const double _kIosIndicatorExtent = 60.0;

/// _kActivityIndicatorRadius（refresh control 用的加大号半径）。
const double _kIosSpinnerRadius = 14.0;

/// _kActivityIndicatorMargin：指示器距露出间隙顶部的固定边距。
const double _kIosIndicatorMargin = 16.0;

/// iOS 13.2 提取的 tick 亮度尾迹（相对 activeTick 的 alpha 序列）；
/// 长度即刻度数（官方 8 根，非 12）。
const List<int> _kIosTickAlphas = <int>[47, 47, 47, 47, 72, 97, 122, 147];

/// 拉出期部分点亮 tick 的统一 alpha（_partiallyRevealedAlpha）。
const int _kIosPartialAlpha = 147;

/// iOS 13.2 提取的 tick 亮色（暗色为 0xFFEBEBF5，经调用方传入）。
const Color _kIosTickColor = Color(0xFF3C3C44);

/// iOS 原生（Cupertino）风格下拉刷新，视觉逐项对齐官方
/// CupertinoSliverRefreshControl：内容跟手下移（bouncing），指示器钉在露出
/// 间隙顶部 16px 处；拉出期 8 根刻度逐根点亮（统一 alpha 147）且整体透明度按
/// `Interval(0, 0.35, easeInOut)` 淡入；达到阈值（armed）spinner 即起转；
/// 刷新中步进旋转带官方亮度尾迹、**内容停靠在指示器下方**（60px 间隙，
/// 停靠物理外扩边界）；完成后撤停靠交还 bouncing 弹簧把内容送回（官方撤
/// sliver 占位语义，速度连续无补间猛拽），spinner 随间隙塌缩从满尺寸连续
/// 缩小（官方 done 相位首帧 1.0→0.6 的半径突缩不跟随）。
///
/// **触发时机偏离官方**：官方 armed 相变即起跑 onRefresh + 震动（拉到距离
/// 直接刷新），不符合用户心智，不跟随——刷新恒在松手时触发（此刻才给
/// mediumImpact 确认触觉），armed 拉回阈值内再松手不触发。
///
/// 默认触发距离为 60 逻辑像素，指示器居中于露出间隙时即可松手刷新。
///
/// 手指下拉时内容让出刷新间隙；惯性沿用容器物理。
class ElIosRefresher extends ElRefresher {
  /// 创建 iOS 平台下拉刷新器。
  const ElIosRefresher({double? triggerExtent, this.color}) : _triggerExtent = triggerExtent;

  @override
  double get triggerExtent => _triggerExtent ?? _kIosTriggerPullDistance;
  final double? _triggerExtent;

  @override
  double get refreshingExtent => _kIosIndicatorExtent;

  /// 保留默认 250 逻辑像素的拉伸空间，避免降低触发距离时连带收紧上限。
  @override
  double get maxPullExtent => math.max(_triggerExtent == null ? 250.0 : 0.0, triggerExtent * 2.5);

  /// 松手激活刷新时 mediumImpact 确认触觉（armed 相变不震——用户裁决）。
  @override
  bool get hapticOnTrigger => true;

  /// spinner 刻度颜色；null 用 iOS 13 提取色（亮 #3C3C44）。
  final Color? color;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    return _IosRefreshIndicator(details: details, refreshingExtent: refreshingExtent, color: color ?? _kIosTickColor);
  }
}

class _IosRefreshIndicator extends StatefulWidget {
  const _IosRefreshIndicator({required this.details, required this.refreshingExtent, required this.color});

  final ElRefreshDetails details;
  final double refreshingExtent;
  final Color color;

  @override
  State<_IosRefreshIndicator> createState() => _IosRefreshIndicatorState();
}

class _IosRefreshIndicatorState extends State<_IosRefreshIndicator> {
  @override
  void initState() {
    super.initState();
    widget.details.snapshot.addListener(_handleSnapshotChanged);
  }

  @override
  void didUpdateWidget(covariant _IosRefreshIndicator oldWidget) {
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
    const opacityCurve = Interval(0.0, 0.35, curve: Curves.easeInOut);
    final dragPhase =
        snapshot.status == RefreshIndicatorStatus.drag || snapshot.status == RefreshIndicatorStatus.canceled;
    final opacity = dragPhase ? opacityCurve.transform(snapshot.progress) : 1.0;
    final scale = snapshot.status == RefreshIndicatorStatus.done
        ? (snapshot.pulledExtent / widget.refreshingExtent).clamp(0.0, 1.0).toDouble()
        : 1.0;
    const diameter = _kIosSpinnerRadius * 2;
    return ElView(
      style: ElStyle(
        alignment: snapshot.anchoredAtViewportStart ? Alignment.topCenter : Alignment.bottomCenter,
        pointerEvents: .none,
      ),
      child: ElView(
        style: ElStyle(
          width: diameter,
          height: diameter,
          opacity: opacity,
          // 指示器钉在间隙顶部固定边距，随间隙展开逐渐揭示。
          margin: snapshot.anchoredAtViewportStart
              ? const .only(top: _kIosIndicatorMargin)
              : const .only(bottom: _kIosIndicatorMargin),
          transform: scale == 1.0 ? null : .scale(scale, scale),
        ),
        child: ElRefreshCupertinoSpinner(snapshot: snapshot, color: widget.color),
      ),
    );
  }
}

/// iOS 放射状 spinner：官方 CupertinoActivityIndicator 复刻——8 根圆头刻度
/// （tick 径向跨 r/3..r、宽 0.2r），拉出期按进度逐根点亮（统一 alpha 147），
/// armed 起即步进旋转（1s/圈）、亮度尾迹用 iOS 13.2 提取的 alpha 序列。
class ElRefreshCupertinoSpinner extends StatefulWidget {
  /// 创建 Cupertino 刷新进度指示器。
  const ElRefreshCupertinoSpinner({super.key, required this.snapshot, required this.color});

  /// 当前刷新快照。
  final ElRefreshSnapshot snapshot;

  /// 刻度颜色。
  final Color color;

  /// 创建进度指示器状态。
  @override
  State<ElRefreshCupertinoSpinner> createState() => _RefreshCupertinoSpinnerState();
}

class _RefreshCupertinoSpinnerState extends State<ElRefreshCupertinoSpinner> with SingleTickerProviderStateMixin {
  /// 官方 CupertinoActivityIndicator 周期：1s / 圈。
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..addListener(_handleSpinTick);

  /// 官方起转时机 = armed（RefreshIndicatorMode.armed || refresh 都画
  /// 动画 spinner），不等松手；finishing（done）期间旋转不停。
  bool get _spinning => switch (widget.snapshot.status) {
    RefreshIndicatorStatus.armed || RefreshIndicatorStatus.refresh || RefreshIndicatorStatus.done => true,
    _ => false,
  };

  void _syncSpin() {
    if (_spinning && !_spin.isAnimating) _spin.repeat();
    if (!_spinning && _spin.isAnimating) _spin.stop();
  }

  void _handleSpinTick() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant ElRefreshCupertinoSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CupertinoSpinnerPaint(
      color: widget.color,
      progress: widget.snapshot.progress,
      spinning: _spinning,
      phase: _spin.value,
    );
  }
}

/// spinner 自绘节点。自持 RenderObject 而非 `CustomPaint`：一是包内零官方
/// widget 红线，二是 `CustomPaint` 无 child 时尺寸恒 `Size.zero`——宿主
/// `ElView` 向子传的是**松约束**，spinner 曾因此完全不可见（直径量得 0）。
class _CupertinoSpinnerPaint extends LeafRenderObjectWidget {
  const _CupertinoSpinnerPaint({
    required this.color,
    required this.progress,
    required this.spinning,
    required this.phase,
  });

  final Color color;
  final double progress;
  final bool spinning;
  final double phase;

  @override
  _RenderCupertinoSpinner createRenderObject(BuildContext context) {
    return _RenderCupertinoSpinner(color: color, progress: progress, spinning: spinning, phase: phase);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderCupertinoSpinner renderObject) {
    renderObject
      ..color = color
      ..progress = progress
      ..spinning = spinning
      ..phase = phase;
  }
}

class _RenderCupertinoSpinner extends RenderBox {
  _RenderCupertinoSpinner({
    required Color color,
    required double progress,
    required bool spinning,
    required double phase,
  }) : _color = color,
       _progress = progress,
       _spinning = spinning,
       _phase = phase;

  Color _color;
  Color get color => _color;
  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  double _progress;
  double get progress => _progress;
  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
  }

  bool _spinning;
  bool get spinning => _spinning;
  set spinning(bool value) {
    if (_spinning == value) return;
    _spinning = value;
    markNeedsPaint();
  }

  double _phase;
  double get phase => _phase;
  set phase(double value) {
    if (_phase == value) return;
    _phase = value;
    markNeedsPaint();
  }

  /// 官方 radius 14 → 固有直径 28。宿主给松约束时自撑该尺寸，
  /// 给紧约束（或更小的上界）时收敛到约束内。
  static const double _intrinsicDiameter = _kIosSpinnerRadius * 2;

  @override
  double computeMinIntrinsicWidth(double height) => _intrinsicDiameter;

  @override
  double computeMaxIntrinsicWidth(double height) => _intrinsicDiameter;

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicDiameter;

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicDiameter;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(const Size(_intrinsicDiameter, _intrinsicDiameter));
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintSpinner(context.canvas, offset, size, color, progress, spinning, phase);
  }
}

/// 官方 CupertinoActivityIndicator 的刻度绘制口径。
void _paintSpinner(Canvas canvas, Offset offset, Size size, Color color, double progress, bool spinning, double phase) {
  final radius = size.shortestSide / 2;
  final tickCount = _kIosTickAlphas.length;
  final paint = Paint()
    // 官方 tick 几何（RRect 全圆角端等价圆头线段）：径向跨 r/3..r、
    // 宽 2·r/10；圆头线段端点内缩半宽。
    ..strokeWidth = radius * 0.2
    ..strokeCap = StrokeCap.round;
  final inner = radius / 3 + radius * 0.1;
  final outer = radius - radius * 0.1;
  final center = size.center(offset);
  // 官方 activeTick 步进（每 1/8 圈跳一格）。
  final activeTick = spinning ? (phase * tickCount).floor() : 0;
  final revealed = spinning ? tickCount.toDouble() : progress * tickCount;
  for (var i = 0; i < revealed && i < tickCount; i++) {
    final alpha = spinning ? _kIosTickAlphas[(i - activeTick) % tickCount] : _kIosPartialAlpha;
    paint.color = color.withAlpha(alpha);
    // 官方从竖直向上的 tick 起、顺时针排布。
    final angle = (i / tickCount) * 2 * math.pi - math.pi / 2;
    final dir = Offset(math.cos(angle), math.sin(angle));
    canvas.drawLine(center + dir * inner, center + dir * outer, paint);
  }
}
