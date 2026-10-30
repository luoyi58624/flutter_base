import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show Axis, AxisDirection, Size;

/// 可确认的滚动输入来源，未提供设备细分的信号不猜测硬件。
enum ElScrollInputSource {
  /// 触屏直接拖拽。
  touch,

  /// 手写笔直接拖拽，包含反向笔尖。
  stylus,

  /// 宿主明确允许的鼠标内容拖拽。
  mouseDrag,

  /// 触控板 pan-zoom 手势。
  trackpad,

  /// 平台滚动信号，可能来自滚轮或触控板。
  pointerSignal,

  /// 惯性采样；不表示重新产生硬件输入。
  ballistic,

  /// 当前入口无法可靠识别来源。
  unknown,
}

/// 以视口视觉起点为参照的滚动方向。
enum ElScrollTravelDirection {
  /// 本次快照没有产生可观测位移。
  idle,

  /// 向视觉起点移动。
  towardStart,

  /// 向视觉终点移动。
  towardEnd,
}

/// 当前滚动活动的统一分类。
enum ElScrollActivityType {
  /// 尚未绑定滚动宿主。
  detached,

  /// position 已绑定，但没有活动滚动。
  idle,

  /// 指针按下后暂时持有现有滚动活动。
  hold,

  /// 触摸、手写笔或被允许的鼠标内容拖拽。
  touchDrag,

  /// 触控板 pan-zoom 手势。
  trackpad,

  /// 鼠标滚轮或触控板 pointer signal。
  pointerScroll,

  /// 惯性 / 回弹 ballistic 活动。
  ballistic,

  /// animateTo 等程序性驱动活动。
  programmatic,

  /// 滚动条 thumb 拖拽。
  scrollbarDrag,

  /// 当前外部 position 未提供足以识别活动来源的信息。
  unknown,
}

/// 本次内容坐标变化的明确来源；无法确认时保留 unknown。
enum ElScrollUpdateCause {
  /// 当前接线无法确认来源。
  unknown,

  /// 设备或滚动条直接输入。
  userInput,

  /// 受控惯性采样。
  ballistic,

  /// 宿主导航操作。
  navigation,

  /// 布局和度量变化引起的修正。
  layoutCorrection,

  /// 状态恢复。
  restoration,

  /// 可观测的外部绝对位置命令。
  externalCommand,
}

/// 速度值的采样依据；unknown 对应空速度，禁止用回调执行耗时伪造。
enum ElScrollVelocitySource {
  /// 没有可靠速度样本。
  unknown,

  /// 内容已知静止，速度为零，不需要运动差分。
  stationary,

  /// 设备释放速度跟踪器。
  tracker,

  /// 受控运动 simulation。
  simulation,

  /// 同一帧时钟域内的有效运动样本估计。
  frameEstimate,
}

/// 一个滚动轴在同一时刻的不可变快照。
///
/// [contentOffset]、[motionDelta] 与 [velocity] 均以视口视觉起点为零点：正值表示向
/// [ElScrollTravelDirection.towardEnd] 移动；[rawPixels] 保留 Flutter
/// [ScrollPosition] 的原始像素坐标，便于需要底层物理口径的调用方使用。
@immutable
final class ElScrollSnapshot {
  /// 创建同一次提交中的不可变滚动观测值。
  const ElScrollSnapshot({
    required this.attached,
    required this.hasMetrics,
    required this.axis,
    required this.axisDirection,
    required this.bindingGeneration,
    required this.layoutRevision,
    required this.sampleId,
    this.sessionId,
    required this.timeStamp,
    required this.reverse,
    required this.contentOffset,
    required this.rawPixels,
    required this.motionDelta,
    required this.rawContentOffset,
    required this.correctionDelta,
    required this.coordinateReset,
    required this.cause,
    required this.velocitySource,
    required this.velocity,
    required this.direction,
    required this.activity,
    required this.viewportExtent,
    required this.minScrollExtent,
    required this.maxScrollExtent,
    required this.leadingOverscroll,
    required this.trailingOverscroll,
    required this.atStart,
    required this.atEnd,
  });

  /// 未绑定滚动宿主时的稳定快照。
  static const ElScrollSnapshot detached = ElScrollSnapshot(
    attached: false,
    hasMetrics: false,
    axis: null,
    axisDirection: null,
    bindingGeneration: 0,
    layoutRevision: 0,
    sampleId: 0,
    timeStamp: null,
    reverse: false,
    contentOffset: 0.0,
    rawPixels: 0.0,
    motionDelta: 0.0,
    rawContentOffset: 0.0,
    correctionDelta: 0.0,
    coordinateReset: true,
    cause: ElScrollUpdateCause.unknown,
    velocitySource: ElScrollVelocitySource.unknown,
    velocity: null,
    direction: ElScrollTravelDirection.idle,
    activity: ElScrollActivityType.detached,
    viewportExtent: 0.0,
    minScrollExtent: 0.0,
    maxScrollExtent: 0.0,
    leadingOverscroll: 0.0,
    trailingOverscroll: 0.0,
    atStart: false,
    atEnd: false,
  );

  /// 当前是否绑定真实滚动宿主。
  final bool attached;

  /// 该轴的完整位置和内容尺寸是否可用。
  final bool hasMetrics;

  /// 当前绑定轴；未绑定时为 null。
  final Axis? axis;

  /// 实际 position 的轴向，包含 reverse 与 RTL 的解析结果。
  final AxisDirection? axisDirection;

  /// 实际宿主 position 的绑定代次，换位或摘挂后旧任务不得回写。
  final int bindingGeneration;

  /// 当前指标所对应的已完成视口布局版本，纯观察不会增加版本。
  final int layoutRevision;

  /// 本宿主当前轴递增的观察样本序号，不随客户端取消订阅而重置。
  final int sampleId;

  /// 当前实际写入组所属的输入会话；无现役会话或入口不透明时为 null。
  final int? sessionId;

  /// 系统帧时钟域的观察时间；未绑定时为 null，不使用调整后的动画时钟。
  final Duration? timeStamp;

  /// 该轴的视觉方向是否与 Flutter pixels 增长方向相反。
  final bool reverse;

  /// 从视觉起点算起并钳制在合法滚动区间内的偏移。
  final double contentOffset;

  /// Flutter [ScrollPosition.pixels] 的原始值，可包含越界量。
  final double rawPixels;

  /// 已归因于真实运动的内容位移；坐标重基时为零。
  final double motionDelta;

  /// 未钳制的内容坐标，保留首尾越界位移。
  final double rawContentOffset;

  /// 本次布局修正造成的内容坐标变化，不能驱动方向效果。
  final double correctionDelta;

  /// 坐标基已变，当前快照不能与上一份作普通运动差分。
  final bool coordinateReset;

  /// 当前样本的明确变化来源。
  final ElScrollUpdateCause cause;

  /// 速度的采样依据。
  final ElScrollVelocitySource velocitySource;

  /// 内容坐标系速度；未知为 null，已知静止为零，正值朝视觉终点。
  final double? velocity;

  /// 仅由 motionDelta 推导的本次旅行方向。
  final ElScrollTravelDirection direction;

  /// 当前可确认的内容活动类型。
  final ElScrollActivityType activity;

  /// 正文视口在当前轴上的逻辑长度。
  final double viewportExtent;

  /// position 的最小数值边界。
  final double minScrollExtent;

  /// position 的最大数值边界。
  final double maxScrollExtent;

  /// 超出视觉起点边界的正数距离。
  final double leadingOverscroll;

  /// 超出视觉终点边界的正数距离。
  final double trailingOverscroll;

  /// 内容坐标是否位于视觉起边。
  final bool atStart;

  /// 内容坐标是否位于视觉尾边。
  final bool atEnd;

  @override
  bool operator ==(Object other) {
    return other is ElScrollSnapshot &&
        other.attached == attached &&
        other.hasMetrics == hasMetrics &&
        other.axis == axis &&
        other.axisDirection == axisDirection &&
        other.bindingGeneration == bindingGeneration &&
        other.layoutRevision == layoutRevision &&
        other.sampleId == sampleId &&
        other.sessionId == sessionId &&
        other.timeStamp == timeStamp &&
        other.reverse == reverse &&
        other.contentOffset == contentOffset &&
        other.rawPixels == rawPixels &&
        other.motionDelta == motionDelta &&
        other.rawContentOffset == rawContentOffset &&
        other.correctionDelta == correctionDelta &&
        other.coordinateReset == coordinateReset &&
        other.cause == cause &&
        other.velocitySource == velocitySource &&
        other.velocity == velocity &&
        other.direction == direction &&
        other.activity == activity &&
        other.viewportExtent == viewportExtent &&
        other.minScrollExtent == minScrollExtent &&
        other.maxScrollExtent == maxScrollExtent &&
        other.leadingOverscroll == leadingOverscroll &&
        other.trailingOverscroll == trailingOverscroll &&
        other.atStart == atStart &&
        other.atEnd == atEnd;
  }

  @override
  int get hashCode => Object.hashAll([
    attached,
    hasMetrics,
    axis,
    axisDirection,
    bindingGeneration,
    layoutRevision,
    sampleId,
    sessionId,
    timeStamp,
    reverse,
    contentOffset,
    rawPixels,
    motionDelta,
    rawContentOffset,
    correctionDelta,
    coordinateReset,
    cause,
    velocitySource,
    velocity,
    direction,
    activity,
    viewportExtent,
    minScrollExtent,
    maxScrollExtent,
    leadingOverscroll,
    trailingOverscroll,
    atStart,
    atEnd,
  ]);

  @override
  String toString() {
    return 'ElScrollSnapshot('
        'axis: $axis, contentOffset: $contentOffset, motionDelta: $motionDelta, velocity: $velocity, '
        'activity: $activity, hasMetrics: $hasMetrics)';
  }
}

/// 一个滚动成员在当前视口中的不可变几何快照。
///
/// 所有距离均使用主轴视觉首尾语义，已统一处理横向与 reverse。未处于
/// [ElScrollView] 的直接 item scope 时使用 [detached]。
@immutable
final class ElScrollItemSnapshot {
  const ElScrollItemSnapshot({
    required this.attached,
    required this.index,
    this.layoutSize,
    required this.itemExtent,
    required this.viewportExtent,
    required this.leadingOffset,
    required this.trailingOffset,
    required this.visibleExtent,
    required this.visibleFraction,
    required this.viewProgress,
    required this.isVisible,
    required this.isMounted,
    required this.isSticky,
    required this.isPinned,
  });

  /// 未绑定滚动成员时的稳定快照。
  static const ElScrollItemSnapshot detached = ElScrollItemSnapshot(
    attached: false,
    index: -1,
    itemExtent: 0.0,
    viewportExtent: 0.0,
    leadingOffset: 0.0,
    trailingOffset: 0.0,
    visibleExtent: 0.0,
    visibleFraction: 0.0,
    viewProgress: 0.0,
    isVisible: false,
    isMounted: false,
    isSticky: false,
    isPinned: false,
  );

  /// 当前 State 是否处于真实滚动 item scope 中。
  final bool attached;

  /// 当前成员在滚动容器扁平 item 空间中的 index。
  final int index;

  /// 当前成员所在行的主轴长度。
  final double itemExtent;

  /// 真实成员的已布局尺寸，不含行占位取整；未挂载或尚未布局时为 null。
  final Size? layoutSize;

  /// 当前滚动视口的主轴长度。
  final double viewportExtent;

  /// item 视觉首边相对 viewport 视觉首边的距离。
  final double leadingOffset;

  /// item 视觉尾边相对 viewport 视觉尾边的距离。
  final double trailingOffset;

  /// item 与 viewport 在主轴上的交叠长度。
  final double visibleExtent;

  /// [visibleExtent] / [itemExtent]，范围为 0 到 1。
  final double visibleFraction;

  /// CSS view-timeline 口径的穿越进度，范围为 0 到 1。
  final double viewProgress;

  /// 是否至少有一个逻辑像素位于视口内。
  final bool isVisible;

  /// 是否仍挂载在 viewport、cache、selection retention 或 sticky 保活集合中。
  final bool isMounted;

  /// 是否登记了 sticky 布局所有权。
  final bool isSticky;

  /// 当前 sticky 是否已钉住。
  final bool isPinned;

  @override
  bool operator ==(Object other) {
    return other is ElScrollItemSnapshot &&
        other.attached == attached &&
        other.index == index &&
        other.layoutSize == layoutSize &&
        other.itemExtent == itemExtent &&
        other.viewportExtent == viewportExtent &&
        other.leadingOffset == leadingOffset &&
        other.trailingOffset == trailingOffset &&
        other.visibleExtent == visibleExtent &&
        other.visibleFraction == visibleFraction &&
        other.viewProgress == viewProgress &&
        other.isVisible == isVisible &&
        other.isMounted == isMounted &&
        other.isSticky == isSticky &&
        other.isPinned == isPinned;
  }

  @override
  int get hashCode => Object.hash(
    attached,
    index,
    layoutSize,
    itemExtent,
    viewportExtent,
    leadingOffset,
    trailingOffset,
    visibleExtent,
    visibleFraction,
    viewProgress,
    isVisible,
    isMounted,
    isSticky,
    isPinned,
  );

  @override
  String toString() {
    return 'ElScrollItemSnapshot('
        'index: $index, leading: $leadingOffset, fraction: $visibleFraction, '
        'progress: $viewProgress${isPinned ? ', pinned' : ''})';
  }
}
