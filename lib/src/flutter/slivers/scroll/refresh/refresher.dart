import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show RefreshIndicatorStatus;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// WebKit 原生橡皮筋回弹弹簧（Apple 开源实现的换算）：
/// `ScrollingEffectsController.mm` 的回弹是刚度 20/s 的临界阻尼指数衰减
/// `e^(-20t)·(x₀+v₀·t)`，换算成 SpringDescription = mass 0.5 / stiffness 200 /
/// 阻尼比 1.0（ω=√(200/0.5)=20，ζω=20/s，~250ms 收束）。对比 Flutter 官方
/// bouncing 弹簧（mass 0.5 / stiffness 100 / 1.1，慢根 9.1/s）收束快一倍多，
/// 是真机 iOS 回弹"利落"的来源。
SpringDescription get elWebKitRubberBandSpring =>
    SpringDescription.withDampingRatio(mass: 0.5, stiffness: 200.0, ratio: 1.0);

/// 下拉刷新挂载的滚动边缘。
///
/// [leading] = 滚动 min 边（普通列表的视觉顶部；`reverse: true` 时视觉底部）；
/// [trailing] = 滚动 max 边（聊天页 reverse 列表"顶部加载更早消息"用它）。
enum ElRefreshEdge { leading, trailing }

/// 每帧提供给指示器视觉树的不可变快照。
@immutable
class ElRefreshSnapshot {
  const ElRefreshSnapshot({
    required this.status,
    required this.pulledExtent,
    required this.triggerExtent,
    required this.edge,
    required this.axisDirection,
  });

  /// Flutter 官方刷新状态；null 表示未激活。
  ///
  /// 本实现不额外制造状态枚举：[RefreshIndicatorStatus.drag] / [RefreshIndicatorStatus.armed] /
  /// [RefreshIndicatorStatus.canceled] / [RefreshIndicatorStatus.refresh] /
  /// [RefreshIndicatorStatus.done] 分别对应拉出、待释放、取消、刷新中和收起。
  final RefreshIndicatorStatus? status;

  /// 当前拉出距离：内容让位时为真实间隙，悬浮时为指示器接收的手指行程。
  final double pulledExtent;

  /// 触发阈值（来自 [ElRefresher.triggerExtent]）。
  final double triggerExtent;

  final ElRefreshEdge edge;

  /// 宿主滚动视图的轴方向，指示器据此决定挂靠视口的哪一侧。
  final AxisDirection axisDirection;

  /// 0..1 触发进度。
  double get progress => triggerExtent <= 0 ? 0.0 : (pulledExtent / triggerExtent).clamp(0.0, 1.0).toDouble();

  /// 指示器是否挂靠在视口的视觉起始侧（垂直轴 = 顶部）。
  /// leading 边在正向列表位于视觉起始，reverse（up/left）时位于视觉末尾。
  bool get anchoredAtViewportStart => switch ((edge, axisDirection)) {
    (ElRefreshEdge.leading, AxisDirection.down || AxisDirection.right) => true,
    (ElRefreshEdge.trailing, AxisDirection.up || AxisDirection.left) => true,
    _ => false,
  };

  @override
  bool operator ==(Object other) {
    return other is ElRefreshSnapshot &&
        other.status == status &&
        other.pulledExtent == pulledExtent &&
        other.triggerExtent == triggerExtent &&
        other.edge == edge &&
        other.axisDirection == axisDirection;
  }

  @override
  int get hashCode => Object.hash(status, pulledExtent, triggerExtent, edge, axisDirection);
}

/// 传给 [ElRefresher.build] 的只读上下文（对齐 [ElScrollbarDetails] 形态）。
abstract class ElRefreshDetails {
  /// 当前刷新状态快照。
  ValueListenable<ElRefreshSnapshot> get snapshot;

  /// 指示器重绘信号；内容间隙变化但快照不变时也会通知。
  Listenable get repaint;

  /// 当前平台最终生效的滚动物理。
  ScrollPhysics get physics;

  /// 滚动内容真实让出的间隙；无法读取宿主指标时为 null。
  double? get contentGap;

  /// 固定头部下方的实际正文区域；null 保留整视口布局。
  Rect? get contentViewportRect => null;

  /// 正文可用区域即将重新布局的信号，与普通刷新重绘分开。
  Listenable? get contentLayoutChanges => null;

  /// 程序化触发一次完整刷新（指示器可用于"点击刷新"类交互）。
  /// 非 idle 状态下调用是 no-op。
  void requestRefresh();
}

/// 一份完整、不可变的下拉刷新配置（对齐 [ElScrollbar] 形态）。
///
/// 对象可复用（类似 ScrollPhysics）；每个挂载的刷新宿主自建可变 details
/// 与视觉子树。本类和 [ElScrollbar] 一样拥有完整构建边界：[build] 负责
/// 内容与刷新层的组合，平台子类只覆写 [buildIndicator] 与策略 getter。
abstract class ElRefresher {
  const ElRefresher({this.movesContent = true});

  /// 下拉时内容是否让出刷新间隙；false 表示指示器悬浮，独立于容器滚动物理。
  final bool movesContent;

  /// 松手触发刷新的拉出阈值。
  double get triggerExtent;

  /// refreshing 期间指示器保留的拉出距离（回弹停靠位）。
  double get refreshingExtent;

  /// 内容让位式拉出硬上限：刷新边越过真实边界的最大越界像素，越过后手指
  /// 加深方向的增量整笔吃掉（回收方向恒放行）。null = 官方橡皮筋无上限
  /// （渐近界是一整个视口高度，下拉刷新场景过于宽松——用户裁决 2026-07-20
  /// 默认收紧）。默认 2.5× 触发距离；覆写值必须 > [triggerExtent]，否则
  /// 永远拉不到 armed。只约束触摸拖拽，不约束惯性冲顶的瞬时深度。
  double? get maxPullExtent => triggerExtent * 2.5;

  /// 内容刷新回位的弹簧（松手停靠 / 未达阈值滑回 / 完成送回统一生效）；
  /// 默认 [elWebKitRubberBandSpring]（WebKit 原生临界阻尼，~250ms 收束）。
  /// null = 回退 Flutter 官方 bouncing 弹簧（过阻尼 1.1，收束慢一倍多）。
  /// 普通惯性与非刷新边的越界回弹不受影响。
  SpringDescription? get settleSpring => elWebKitRubberBandSpring;

  /// 指示器与滚动内容的层级：true = 画在内容**之下**（bouncing 风格：内容
  /// 位移让出间隙，指示器在间隙里被逐渐揭示，列表回位时从上方盖过它滑走
  /// ——原生 UIRefreshControl 的层级）；宿主同时把指示器绘制裁剪到间隙内，
  /// 既不会画到列表内容上，也不会透过透明行泄漏。false = 浮在内容**之上**
  /// （安卓圆盘悬浮于列表）。默认跟随 [movesContent]。
  ///
  /// 注意：内容之下的指示器不可交互（视口在其上层接管命中）；需要"点击
  /// 刷新"类交互的自定义刷新器可覆写本方法。
  bool behindContent(ElRefreshDetails details) => movesContent;

  /// 松手激活刷新的那一刻给一次 mediumImpact 触觉（确认"刷新已触发"）。
  /// **刷新恒在松手时触发**：官方 CupertinoSliverRefreshControl 的
  /// "armed 相变即起跑 onRefresh + 震动"语义不跟随（用户裁决 2026-07-18：
  /// 拉到距离就直接刷新/震动不符合用户心智——armed 只是承诺"松手会
  /// 刷新"，拉回阈值内再松手必须不触发，震动也只在真正激活时给）。
  bool get hapticOnTrigger => false;

  /// 停靠 / 收回动画时长（armed→refreshing 停靠与未达阈值收回共用；
  /// 安卓官方 ANIMATE_TO_TRIGGER_DURATION / ANIMATE_TO_START_DURATION = 200ms）。
  Duration get settleDuration => const Duration(milliseconds: 220);

  /// finishing 收起动画时长（安卓官方 SCALE_DOWN_DURATION = 150ms）；
  /// 默认与 [settleDuration] 相同。
  /// 只作用于 clamping 收起与"无露出间隙"的兜底补间——bouncing 停靠的
  /// finishing 由物理弹簧送回（官方 Cupertino 撤占位语义），不吃此时长。
  Duration get finishDuration => settleDuration;

  /// 完成态停留：onRefresh 完成后内容继续钉在停靠位展示"完成"视觉
  /// （文案/图标切到 finishing 态）多久，再启动弹簧送回。
  /// 默认 0 = 完成即送回（安卓/iOS 官方节奏）；文本式刷新器覆写非零值，
  /// 否则"刷新完成"随收起一闪而过。仅对 bouncing 停靠场景生效；停留期间
  /// 用户触摸拖拽视为打断，提前进入送回。
  Duration get finishDelay => Duration.zero;

  /// 停靠 / 收回动画曲线（安卓官方 DecelerateInterpolator(2) ≈ easeOutQuart）。
  Curve get settleCurve => Curves.easeOutCubic;

  /// finishing 收起动画曲线；默认跟随 [settleCurve]。安卓官方 scale-down
  /// 用 Animation 默认的 AccelerateDecelerateInterpolator（≈ easeInOutSine）
  /// ——缓起缓收，前段留在近满尺寸，缩小过程肉眼可见；直接套用前段陡降的
  /// easeOut 系曲线会让收起看起来像"突然消失"。
  Curve get finishCurve => settleCurve;

  /// 构建刷新指示器外观。
  ///
  /// 返回节点覆盖整个视口，无交互区域必须保持命中透明，避免挡住滚动手势。
  Widget buildIndicator(BuildContext context, ElRefreshDetails details);

  /// 构建滚动内容和刷新指示器的完整层级。
  ///
  /// bouncing 风格默认把指示器放在内容下方并裁剪到真实间隙；clamping
  /// 风格放在内容上方。自定义刷新器可覆写本方法接管完整组合。
  Widget build(BuildContext context, ElRefreshDetails details, Widget child) {
    final behind = behindContent(details);
    Widget indicator = buildIndicator(context, details);
    if (behind) {
      indicator = RefreshGapClip(
        snapshot: details.snapshot,
        repaint: details.repaint,
        contentGapOf: () => details.contentGap,
        child: indicator,
      );
    }
    return _RefreshComposition(details: details, behind: behind, children: [child, indicator]);
  }
}

class _RefreshComposition extends MultiChildRenderObjectWidget {
  const _RefreshComposition({required this.details, required this.behind, required super.children});
  final ElRefreshDetails details;
  final bool behind;
  @override
  _RenderRefreshComposition createRenderObject(BuildContext context) => _RenderRefreshComposition(details, behind);
  @override
  void updateRenderObject(BuildContext context, _RenderRefreshComposition renderObject) =>
      renderObject.update(details, behind);
}

class _RefreshParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderRefreshComposition extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RefreshParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RefreshParentData> {
  _RenderRefreshComposition(this._details, this._behind);
  ElRefreshDetails _details;
  bool _behind;
  Rect _region = Rect.zero;

  void update(ElRefreshDetails details, bool behind) {
    if (attached) _details.contentLayoutChanges?.removeListener(markNeedsLayout);
    _details = details;
    _behind = behind;
    if (attached) _details.contentLayoutChanges?.addListener(markNeedsLayout);
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RefreshParentData) child.parentData = _RefreshParentData();
  }

  @override
  void performLayout() {
    // 先布局真实正文，随后读取其最新头部边界；指示器没有一帧旧高度。
    firstChild!.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(firstChild!.size);
    _region = (_details.contentViewportRect ?? Offset.zero & size).intersect(Offset.zero & size);
    if (_region.isEmpty) _region = Rect.fromLTWH(0, size.height, 0, 0);
    lastChild!.layout(BoxConstraints.tight(_region.size), parentUsesSize: true);
    (lastChild!.parentData! as _RefreshParentData).offset = _region.topLeft;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void paintIndicator() {
      if (_region.isEmpty) return;
      if (_details.contentViewportRect == null) {
        context.paintChild(lastChild!, offset);
      } else {
        context.pushClipRect(
          needsCompositing,
          offset,
          _region,
          (inner, origin) => inner.paintChild(lastChild!, origin + _region.topLeft),
        );
      }
    }

    if (_behind) paintIndicator();
    context.paintChild(firstChild!, offset);
    if (!_behind) paintIndicator();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    bool indicator() =>
        _region.contains(position) &&
        result.addWithPaintOffset(
          offset: _region.topLeft,
          position: position,
          hitTest: (result, point) => lastChild!.hitTest(result, position: point),
        );
    return _behind
        ? firstChild!.hitTest(result, position: position) || indicator()
        : indicator() || firstChild!.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_behind ? lastChild! : firstChild!);
    visitor(_behind ? firstChild! : lastChild!);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      identical(child, lastChild) && _details.contentViewportRect != null ? _region : null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _details.contentLayoutChanges?.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _details.contentLayoutChanges?.removeListener(markNeedsLayout);
    super.detach();
  }
}

/// 显式关闭下拉刷新。
class ElNoRefresher extends ElRefresher {
  const ElNoRefresher();

  @override
  double get triggerExtent => 0.0;

  @override
  double get refreshingExtent => 0.0;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context, ElRefreshDetails details, Widget child) {
    return child;
  }
}

/// 闭包式自定义刷新：不想继承时用它拼装任意风格。
///
/// ```dart
/// ElCustomRefresher(
///   triggerExtent: 72,
///   movesContent: true,
///   builder: (context, details) => MyIndicator(snapshot: details.snapshot),
/// )
/// ```
final class ElCustomRefresher extends ElRefresher {
  const ElCustomRefresher({
    required this.triggerExtent,
    double? refreshingExtent,
    super.movesContent,
    required this.builder,
  }) : refreshingExtent = refreshingExtent ?? triggerExtent;

  @override
  final double triggerExtent;

  @override
  final double refreshingExtent;

  /// 构建自定义刷新指示器。
  final Widget Function(BuildContext context, ElRefreshDetails details) builder;

  @override
  Widget buildIndicator(BuildContext context, ElRefreshDetails details) => builder(context, details);
}

/// 把内容之下的刷新指示器裁剪到滚动内容真实让出的间隙。
///
/// 仅供刷新器核心和白盒测试使用，不属于 `package:flutter_base/ui.dart`
/// 的公开 API。
class RefreshGapClip extends SingleChildRenderObjectWidget {
  const RefreshGapClip({super.key, required this.snapshot, this.repaint, this.contentGapOf, super.child});

  final ValueListenable<ElRefreshSnapshot> snapshot;

  /// 快照之外的重绘信号（内容位移但快照不变的帧）。
  final Listenable? repaint;

  /// 内容位移让出的真实间隙；null 时退化为快照拉出距离。
  final double? Function()? contentGapOf;

  @override
  RenderRefreshGapClip createRenderObject(BuildContext context) {
    return RenderRefreshGapClip(snapshot, repaint: repaint, contentGapOf: contentGapOf);
  }

  @override
  void updateRenderObject(BuildContext context, RenderRefreshGapClip renderObject) {
    renderObject
      ..snapshot = snapshot
      ..repaint = repaint
      ..contentGapOf = contentGapOf;
  }
}

/// [RefreshGapClip] 的绘制裁剪实现。
///
/// 仅供刷新器核心和白盒测试使用，不属于公开 API。
class RenderRefreshGapClip extends RenderProxyBox {
  // ignore: prefer_initializing_formals
  RenderRefreshGapClip(this._snapshot, {Listenable? repaint, this.contentGapOf}) : _repaint = repaint;

  final LayerHandle<ClipRectLayer> _clipHandle = LayerHandle<ClipRectLayer>();

  double? Function()? contentGapOf;

  ValueListenable<ElRefreshSnapshot> _snapshot;
  set snapshot(ValueListenable<ElRefreshSnapshot> value) {
    if (identical(value, _snapshot)) return;
    if (attached) _snapshot.removeListener(markNeedsPaint);
    _snapshot = value;
    if (attached) _snapshot.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Listenable? _repaint;
  set repaint(Listenable? value) {
    if (identical(value, _repaint)) return;
    if (attached) _repaint?.removeListener(markNeedsPaint);
    _repaint = value;
    if (attached) _repaint?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _snapshot.addListener(markNeedsPaint);
    _repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _snapshot.removeListener(markNeedsPaint);
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipHandle.layer = null;
    super.dispose();
  }

  /// 当前露出间隙在本盒坐标系中的裁剪条带。
  Rect get clipRect {
    final snap = _snapshot.value;
    var gap = snap.pulledExtent;
    final content = contentGapOf?.call();
    if (content != null) gap = math.min(gap, content);
    gap = math.max(0.0, gap);
    return switch ((axisDirectionToAxis(snap.axisDirection), snap.anchoredAtViewportStart)) {
      (Axis.vertical, true) => Rect.fromLTWH(0, 0, size.width, gap),
      (Axis.vertical, false) => Rect.fromLTWH(0, size.height - gap, size.width, gap),
      (Axis.horizontal, true) => Rect.fromLTWH(0, 0, gap, size.height),
      (Axis.horizontal, false) => Rect.fromLTWH(size.width - gap, 0, gap, size.height),
    };
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final rect = clipRect;
    if (rect.isEmpty) {
      _clipHandle.layer = null;
      return;
    }
    _clipHandle.layer = context.pushClipRect(needsCompositing, offset, rect, super.paint, oldLayer: _clipHandle.layer);
  }
}
