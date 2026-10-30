import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart'
    show DiagnosticsNode, ErrorDescription, ErrorHint, ErrorSummary, FlutterError, ValueListenable, immutable, internal;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'package:flutter_base/ui.dart';
import 'virtual/virtual_pipeline.dart';
import 'common/viewport/scroll_engine_position.dart';

/// 滚动视图，支持普通滚动、虚拟滚动，相当于 [SingleChildScrollView] + [CustomScrollView] 的结合体；
///
/// 普通滚动的性能比 [SingleChildScrollView] 要更好一些，它只绘制可视窗口内的元素，
/// 而且事件命中、语义遍历，均在可视范围内才激活；
///
/// 虚拟滚动应当用于构建大量、且轻量的子元素，它会频繁创建、销毁子项，如果子项耗时超过 8ms、16ms，
/// 滚动效果将很差，
///
/// 业务 RenderBox 直接属于视口。[ElPositioned] 和官方 `Positioned` 相对
/// 视口定位，任一定位字段存在便脱离滚动流；只写 zIndex 仍保留行占位。
/// State / Hook 根返回定位声明同样有效。滚动条直接参与同一层序，默认 zIndex 为 10。
/// 层级只控制视觉呈现与命中；文档选择按成员源序，明确的无障碍阅读顺序使用
/// [ElSemantics.properties] 的 sortKey。未声明时沿用 Flutter 的几何遍历规则。
///
/// 可变行保留自然尺寸，滚动占位向上对齐物理像素，行盒之间可能有不足
/// 1 个物理像素的空隙；统一尺寸列表与网格 继续使用固定尺寸约束。
/// List/Grid 条目只支持流内层级，脱流定位成员应放在 [children] 中。
///
/// 尺寸语义：默认按父级提供的最大尺寸布局；打开 [shrinkWrap] 后全部子元素
/// 都会挂载并参与布局，滚动容器宽高遵循完整子内容尺寸（含 padding），再由
/// 父级约束钳制；虚拟段声明保留，但虚拟挂窗失效，不再按可视范围挂卸 item。
///
/// 本类只是公开参数面；实现整体在 [ElScrollViewState]（物理链、平滑滚动、
/// 滚动条、刷新、拦截器、嵌套滚动、双轴等外围能力直接引用同目录既有模块）。
class ElScrollView extends StatefulWidget {
  /// 鼠标纵向滚轮转横向滚动的默认修饰键。
  static const List<LogicalKeyboardKey> defaultMouseWheelHorizontalModifiers = <LogicalKeyboardKey>[
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
  ];

  /// 返回离 [context] 最近、且支持 [axis] 的祖先滚动宿主；找不到返回 null。
  ///
  /// 查找只沿祖先链进行。若当前 State 自己创建了 [ElScrollView]，该 State
  /// 不会因此成为滚动后代；需要完整滚动能力的逻辑应拆进真正的 scroll child
  /// State。
  static ElScrollViewState? maybeOf(BuildContext context, {Axis? axis}) {
    return maybeFindScrollViewState(context, axis: axis);
  }

  /// 返回离 [context] 最近、且支持 [axis] 的祖先滚动宿主。
  ///
  /// 找不到时抛出包含目标轴、调用 context 与正确组件结构说明的错误。
  static ElScrollViewState of(BuildContext context, {Axis? axis}) {
    final state = maybeOf(context, axis: axis);
    if (state != null) return state;
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('ElScrollView.of() 的 context 下没有可匹配的祖先 ElScrollView。'),
      ErrorDescription(
        '从传入 context 向祖先查找时，没有找到${axis == null ? '' : '支持 $axis 的'} ElScrollView。\n'
        '传入的 context：\n  $context',
      ),
      ErrorHint(
        '持有滚动 Mixin 的 State 必须是 ElScrollView 的真实后代。若当前 State '
        '负责创建 ElScrollView，请把需要滚动能力的部分拆成 scroll child 的独立 State；'
        '不要从祖先 State 向下遍历查找滚动容器。',
      ),
    ]);
  }

  /// 创建统一滚动容器。参数面承袭旧双容器公共面，另含虚拟通道三参数
  /// （[cacheExtent] / [onVisibleRangeChanged] / [dragOptimize]——窗口是
  /// 容器级概念，仅虚拟段在场生效，无段静默）。
  const ElScrollView({
    super.key,
    required this.children,
    this.controller,
    this.horizontalController,
    this.physics,
    this.smoothScroll,
    this.mouseWheelHorizontalModifiers = defaultMouseWheelHorizontalModifiers,
    this.scrollbar,
    this.axis = Axis.vertical,
    this.reverse = false,
    this.shrinkWrap = false,
    this.pinToEnd = false,
    this.preserveAnchor = false,
    this.clipBehavior = Clip.hardEdge,
    this.padding = EdgeInsets.zero,
    this.gap = 0.0,
    this.crossAxisAlignment,
    this.minimumCrossAxisExtentListenable,
    this.itemExtentInvalidationListenable,
    this.excludeSemantics = false,
    this.semanticsRole,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.focusNode,
    this.keyboardScroll = true,
    this.dragStartDistance,
    this.cacheExtent = 250.0,
    this.onVisibleRangeChanged,
    this.dragOptimize,
    this.event,
    this.deltaInterceptor,
    this.inputOrder = const {},
    this.refresher,
    this.onRefresh,
    this.refreshEdge = ElRefreshEdge.leading,
  }) : assert(gap >= 0.0),
       assert(dragStartDistance == null || dragStartDistance >= 0.0),
       assert(cacheExtent >= 0.0 && cacheExtent < double.infinity),
       assert(axis != null || !reverse, '双轴滚动（axis: null）不支持 reverse——CSS overflow 没有对应语义。'),
       assert(
         axis == null || horizontalController == null,
         'horizontalController 仅在双轴滚动（axis: null）下生效；单轴请用 controller。',
       ),
       assert(
         crossAxisAlignment != CrossAxisAlignment.baseline,
         'crossAxisAlignment 不支持 baseline——滚动成员是主轴堆叠流，无共享文本基线。',
       ),
       assert(axis != null || crossAxisAlignment == null, '双轴滚动（axis: null）不支持 crossAxisAlignment——双轴成员按内容自然量宽，无对齐参照。');

  /// 滚动成员，普通 Widget 与全量 List/Grid 常驻，builder View 按窗口挂载。
  ///
  /// builder View 必须是本列表的直接成员；保留 View 自身 context、Key 和生命周期。
  /// 列表分隔项计入滚动索引，Grid 的索引按格子展开。
  final List<Widget> children;

  /// 各轴输入 slot 的显式消费顺序；单参与者可省略，多参与者必须列全。
  /// pre 按声明顺序、post 按反序，未挂载的 slot 跳过；不依据层级或挂载次序。
  final Map<Axis, List<Object>> inputOrder;

  /// 可选外部滚动 controller。双轴模式（[axis] 为 null）下绑定**垂直**轴。
  final ScrollController? controller;

  /// 双轴模式下水平轴的外部 controller，可选。
  ///
  /// 仅 [axis] 为 null 时生效；水平偏移不参与 PageStorage 恢复。
  final ScrollController? horizontalController;

  /// 当前滚动容器使用的滚动物理（个体覆写，优先级高于环境默认）。
  ///
  /// null 时读环境 `ScrollConfiguration.of(context).getScrollPhysics(context)`
  /// ——应用根挂 [ElScrollBehavior] 即 el 平台口径（Windows / Linux 弹跳），
  /// 想改在子树包一层 `ScrollConfiguration`。刷新器绑定物理恒最优先。
  final ScrollPhysics? physics;

  /// 当前滚动容器使用的滚轮平滑滚动算法（个体覆写，优先级高于最近
  /// [ElViewProvider] 的环境默认）。传 [ElNoSmoothScroll] 显式关闭。
  final ElSmoothScroll? smoothScroll;

  /// 鼠标纵向滚轮驱动横向滚动所需的修饰键。
  ///
  /// 仅单轴横向滚动生效。默认 Ctrl；传 null 表示不需要修饰键，普通鼠标滚轮
  /// 可直接横向滚动；传空集合表示禁用纵向滚轮转横向滚动。触控板与原生横向
  /// 滚轮分量不受影响。
  final Iterable<LogicalKeyboardKey>? mouseWheelHorizontalModifiers;

  /// 当前滚动容器使用的滚动条。
  ///
  /// null 时读取最近 [ElViewProvider] 的环境默认；祖先未配置时由 el_ui
  /// 按平台回落内置滚动条。传 [ElNoScrollBar] 显式关闭。
  final ElScrollbar? scrollbar;

  /// 滚动主轴；显式传 `null` 进入双轴滚动（CSS `overflow: auto` 语义）。
  final Axis? axis;

  /// 是否强制滚动容器按全部子元素布局，并让容器宽高遵循子内容尺寸。
  ///
  /// `false` 时容器默认取父级提供的最大尺寸；`true` 时全部 child 都会挂载
  /// 并实测，容器宽高取完整子内容尺寸与 padding 之和，再受父级约束钳制。
  /// 虚拟段声明原样保留，但虚拟滚动失效，item 不再按可视窗口挂卸。
  final bool shrinkWrap;

  /// 是否反转滚动方向。
  final bool reverse;

  /// 贴末端跟随（chat/feed 流式输出语义）：滚动位置贴住末端（max 边）时，
  /// 内容增长（追加成员、行自身长高）保持贴住，新内容始终可见。
  ///
  /// 默认 false = 与普通滚动容器一致（web/CSS 口径）：贴底追加内容保留当前
  /// 滚动位置，新内容出现在视口下方，可继续下滚；阅读位置保留需另开 [preserveAnchor]。
  /// 虚拟行首测/估计收敛的钉边是估算 artifact 补偿，不受本参数影响——
  /// `jumpTo(maxScrollExtent)` 类"回到底部"操作恒收敛到真实底部；视口
  /// resize 回钳与滚动条拖到边缘松手的钉边同样恒钉（交互意图）。
  /// 反向轴（[reverse]）的视觉底部是 min 边，天然跟随，与本参数无关。
  final bool pinToEnd;

  /// 内容增删、重排或尺寸变化时，是否调整滚动位置以保住原可见成员。
  ///
  /// 默认 false：保留当前像素位置，仅在新范围不再容纳该位置时回钳。
  /// 聊天列表加载历史消息时可开启；贴底接收新消息另用 [pinToEnd]。
  /// 虚拟列表首次实测的估高补偿与视口尺寸变化的修正不受此开关影响。
  final bool preserveAnchor;

  /// 视口裁剪行为。
  final Clip clipBehavior;

  /// 内容内边距。
  final EdgeInsets padding;

  /// 直接成员及布局段之间的主轴间距，段内间距由 List/Grid 自己声明。
  final double gap;

  /// 成员在交叉轴上的对齐（CSS `align-items` 语义）。
  ///
  /// **null（默认）= 沿轴向既有行为**：vertical 拉满宽（stretch）、horizontal
  /// 按成员固有高（start）——存量布局零破坏。显式传值则统一四值语义：
  /// `stretch` tight 拉满交叉轴，`start` / `center` / `end` 按成员固有尺寸摆位。
  ///
  /// 作用于普通直接成员；List 的内部对齐由自身声明，Grid 按格子几何定位。
  ///双轴（[axis] 为 null）成员按内容自然量宽，不适用（assert 只许
  /// 缺省）；`baseline` 无共享文本基线语义，assert 拒绝。
  final CrossAxisAlignment? crossAxisAlignment;

  /// 内部自然交叉轴下限通道；null 保持既有 mounted-only 尺寸语义。
  ///
  /// 供编辑器等拥有独立稀疏宽度索引的虚拟内容宿主使用，普通调用方不应传入。
  @internal
  final ValueListenable<double>? minimumCrossAxisExtentListenable;

  /// 内部虚拟行高度失效通道；null 时完全保持既有度量缓存语义。
  @internal
  final ValueListenable<ElScrollExtentInvalidation>? itemExtentInvalidationListenable;

  /// 是否把可见成员从语义树剔除。
  final bool excludeSemantics;

  /// 滚动语义节点的可选结构角色；null 保持默认滚动语义。
  final SemanticsRole? semanticsRole;

  /// 键盘收起行为，对齐官方滚动视图口径。
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// 滚动容器自身的焦点节点；默认不创建焦点节点，子控件仍正常参与导航。
  /// 声明后可通过 Tab、指针或传入的节点聚焦容器，键盘滚动只认自身主焦点。
  final FocusNode? focusNode;

  /// 自身持有主焦点时是否启用键盘滚动；子控件持焦时始终不自动接管。
  /// 默认按滚动轴处理方向键及 PageUp/PageDown/Home/End；其他按键、不可
  /// 滚动方向和到达边界后的按键继续交给祖先。不会关闭滚轮、拖动或用户事件。
  final bool keyboardScroll;

  /// render 层拖拽识别的起始 slop；null = 设备自适应。
  final double? dragStartDistance;

  /// 可视窗口外的预挂载距离（逻辑像素）；仅虚拟段在场生效。
  ///
  /// 预挂载行只 layout/测量，不进 paint / hit-test / semantics。
  final double cacheExtent;

  /// 可视窗口（first/last）或 mounted 窗口任一值变化时触发（post-frame
  /// 合并派发、值不变不重复）；仅虚拟段在场生效。
  final ValueChanged<ElVisibleRange>? onVisibleRangeChanged;

  /// 滚动条 thumb 拖拽快路径开关（默认开）；仅虚拟段在场生效。
  final bool? dragOptimize;

  /// 视口节点的 El 指针事件回调。
  final ElEvent? event;

  /// 滚动 delta 输入拦截器；null = 无拦截，热路径短路。
  ///
  /// 使用默认控制器或 [ElScrollController]；惯性与平滑滚轮只在实际帧中消费。
  final ElScrollDeltaInterceptor? deltaInterceptor;

  /// 当前滚动容器使用的下拉刷新器；仅 [onRefresh] 非 null 时挂载。
  final ElRefresher? refresher;

  /// 刷新回调；返回的 Future 完成后指示器收起。
  final Future<void> Function()? onRefresh;

  /// 刷新挂载的滚动边缘。
  final ElRefreshEdge refreshEdge;

  @override
  ElScrollViewState createState() => ElScrollViewState();
}

/// 虚拟滚动已实测行高度的内部失效请求。
@immutable
@internal
final class ElScrollExtentInvalidation {
  /// 创建按行或全量失效请求；[revision] 由生产者单调递增。
  ElScrollExtentInvalidation({required this.revision, Iterable<int> indices = const <int>[], this.resetAll = false})
    : indices = Set<int>.unmodifiable(indices);

  /// 生产者请求序号。
  final int revision;

  /// 新 item 坐标中的待失效行。
  final Set<int> indices;

  /// 是否丢弃全部已实测高度，供布局语义整体换代使用。
  final bool resetAll;
}

// ─────────────────────────── 滚动控制器 ───────────────────────────

/// 滚动容器的 index 定位控制器（改名自 ElVirtualScrollController，2026-08-04
/// 一次性硬切改名）。
///
/// 用户可选：换成官方 [ScrollController] 不影响 pixel 层滚动；只有需要 index
/// 级 API（[scrollToIndex]）时才必须挂本类。index = 扁平 item 空间：普通
/// child 计 1，List/Grid 布局段按其 itemCount 展开。
///
/// 挂载语义：单实例只能同时挂到一个滚动容器，attach/detach 生命周期由虚拟
/// 管线宿主 State 负责。未挂载（含挂到无虚拟段的容器）时调用 index API →
/// 抛 AssertionError（assert 关掉的 release 构建下静默返回）。
class ElScrollController extends ScrollController {
  ElScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
  });

  ScrollIndexBridge? _bridge;

  /// 单个控制器只能挂到一个真实位置，release 下也拒绝重复挂载。
  @override
  void attach(ScrollPosition position) {
    if (hasClients) throw FlutterError('ElScrollController 不可同时挂到多个滚动位置；每个宿主及轴应使用独立控制器。');
    super.attach(position);
  }

  /// 通过标准工厂创建唯一的可观测 position，保留初始偏移及恢复配置。
  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) =>
      ScrollEnginePosition(
        physics: physics,
        context: context,
        initialPixels: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        oldPosition: oldPosition,
        debugLabel: debugLabel,
      );

  /// 把外部区域收到的滚轮事件交给所属视口，沿用同一套平滑滚动与连击编排。
  bool dispatchPointerScroll(PointerScrollEvent event) {
    final bridge = _bridge;
    assert(bridge != null, 'ElScrollController 尚未挂到 ElScrollView，无法转发滚轮事件。');
    return bridge?.dispatchPointerScroll(event) ?? false;
  }

  /// 内部使用：由虚拟管线宿主 State 在 initState / didUpdateWidget 时绑定。
  /// 禁止用户代码直接调用。
  void attachIndexBridge(ScrollIndexBridge bridge) {
    if (_bridge != null && !identical(_bridge, bridge)) {
      throw FlutterError('ElScrollController 不可同时挂到多个滚动容器。');
    }
    _bridge = bridge;
  }

  /// 内部使用：由虚拟管线宿主 State 在 dispose / didUpdateWidget 时解绑。
  /// 禁止用户代码直接调用。
  void detachIndexBridge(ScrollIndexBridge bridge) {
    if (!identical(_bridge, bridge)) return;
    bridge.cancelScrollToIndex();
    _bridge = null;
  }

  /// 滚动到指定 index。
  ///
  /// * [alignment] 为 0/0.5/1 → item 顶/中/底 对齐视口顶/中/底（参考
  ///   scrollable_positioned_list 惯例）；
  /// * [duration] 为 null 或 `Duration.zero` → 走 jump 收敛路径（多帧修正 estimate
  ///   误差直至 <0.5px 或迭代上限）；否则先 animateTo(estimate offset) 再走 jump
  ///   收敛校正落点；
  /// * 越界 index 会 clamp 到 `[0, itemCount-1]` 并在 debug 断言提示；
  /// * 双轴模式（axis: null）仅作用于主轴（垂直），不影响水平位置；
  /// * 控制器未挂到 [ElScrollView] 时会抛 AssertionError。
  Future<void> scrollToIndex(int index, {double alignment = 0.0, Duration? duration, Curve curve = Curves.easeInOut}) {
    return scrollToIndexWithResult(index, alignment: alignment, duration: duration, curve: curve).then<void>((_) {});
  }

  /// 滚动到指定 index，并用布尔结果区分正常完成与取消。
  ///
  /// 返回 true 表示当前请求已经在 0.5px 容差内收敛；返回 false 表示被更新
  /// 请求、显式 [cancelScrollToIndex]、结构换代、控制器解绑取消，或达到有限
  /// 迭代上限仍未收敛。该门面供需要可靠生命周期的编辑器等组件使用；兼容调用
  /// 可继续使用返回 [Future<void>] 的 [scrollToIndex]。
  Future<bool> scrollToIndexWithResult(
    int index, {
    double alignment = 0.0,
    Duration? duration,
    Curve curve = Curves.easeInOut,
  }) {
    final bridge = _bridge;
    assert(bridge != null, 'ElScrollController 尚未挂到带虚拟段的滚动容器，无法执行 scrollToIndex。');
    if (bridge == null) return Future<bool>.value(false);
    if (duration == null || duration == Duration.zero) {
      return bridge.jumpToIndex(index, alignment: alignment);
    }
    return bridge.animateToIndex(index, alignment: alignment, duration: duration, curve: curve);
  }

  /// 取消当前仍在执行的 index 定位；没有活动请求时返回 false。
  ///
  /// 只终止由 [scrollToIndex] / [scrollToIndexWithResult] 发起的定位，不会打断
  /// 普通 pixel 动画或用户滚动。
  bool cancelScrollToIndex() => _bridge?.cancelScrollToIndex() ?? false;
}

/// Widget State 侧实现的 index 定位通道。
///
/// 抽出接口是为了让 [ElScrollController] 与 State 解耦——State 是私
/// 有类，controller 只依赖此协议。
abstract class ScrollIndexBridge {
  /// 把外部命中的滚轮事件转交给当前滚动视口。
  bool dispatchPointerScroll(PointerScrollEvent event);

  /// jump 路径：立即定位 + 多帧收敛，最终指针指向目标 index 的 [alignment] 位置。
  Future<bool> jumpToIndex(int index, {required double alignment});

  /// animate 路径：先 animateTo(estimate 目标)、落点后走 jump 收敛校正误差。
  ///
  /// v1 简化：动画过程中不做逐帧修正——仅在落点收敛（避免动画曲线被打断）。
  Future<bool> animateToIndex(int index, {required double alignment, required Duration duration, required Curve curve});

  /// 取消当前 index 定位；没有活动请求时返回 false。
  bool cancelScrollToIndex();
}

// ─────────────────────────── 滚动成员配置 ───────────────────────────

// ─────────────────────────── 可视性类型 ───────────────────────────

/// 可视范围快照，由 [ElScrollView.onVisibleRangeChanged] 派发。
///
/// 语义与官方 [ListView] 的 index-window 描述一致：first/last 半开区间——
/// `[first, last)` 表示当前完全或部分可见的 item 索引；mountedFirst/mountedLast
/// 是含 cache 的挂载窗口（同样半开）。
@immutable
class ElVisibleRange {
  const ElVisibleRange({
    required this.first,
    required this.last,
    required this.mountedFirst,
    required this.mountedLast,
  });

  /// 可见首 index（含）。空视口时 first == last == 0。
  final int first;

  /// 可见尾 index（半开，不含）。
  final int last;

  /// mounted 窗口首 index（含 cache）。
  final int mountedFirst;

  /// mounted 窗口尾 index（半开）。
  final int mountedLast;

  bool get isEmpty => first == last;

  @override
  bool operator ==(Object other) {
    return other is ElVisibleRange &&
        other.first == first &&
        other.last == last &&
        other.mountedFirst == mountedFirst &&
        other.mountedLast == mountedLast;
  }

  @override
  int get hashCode => Object.hash(first, last, mountedFirst, mountedLast);

  @override
  String toString() => 'ElVisibleRange(visible: [$first, $last), mounted: [$mountedFirst, $mountedLast))';
}

/// 虚拟成员可见性回调的入参。
@immutable
class ElVisibilityInfo {
  const ElVisibilityInfo({required this.index, required this.visible, required this.visibleFraction});

  /// 当前 item 的 index。
  final int index;

  /// 是否至少有一个像素落在视口内。
  final bool visible;

  /// 与视口在主轴的交叠比例，`[0.0, 1.0]`：
  /// - 完全在视口内 → 1.0；
  /// - 完全不在 → 0.0；
  /// - 部分在 → 交叠长度 / item 主轴 extent。
  ///
  /// 未开启连续比例跟踪时只在进出瞬间发一次事件。
  final double visibleFraction;

  @override
  bool operator ==(Object other) {
    return other is ElVisibilityInfo &&
        other.index == index &&
        other.visible == visible &&
        other.visibleFraction == visibleFraction;
  }

  @override
  int get hashCode => Object.hash(index, visible, visibleFraction);

  @override
  String toString() => 'ElVisibilityInfo(index: $index, visible: $visible, fraction: $visibleFraction)';
}
