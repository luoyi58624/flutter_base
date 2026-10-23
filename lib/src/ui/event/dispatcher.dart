import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, internal, precisionErrorTolerance, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'callback.dart';
import 'drag/resampling/mounts.dart';
import 'drag/resampling/resampler.dart';
import 'event.dart';

part 'drag/drag_machine.dart';

part 'drag/drag_pipeline.dart';

part 'scale_machine.dart';

part 'sequence.dart';

part 'tap/side_button_machine.dart';

part 'tap/tap_machine.dart';

// 负值只在事件核心排队期间表示计数模式，业务回调前会解析为非负数。
const int _pointerCountCurrent = -1;
const int _pointerCountAfterTerminal = -2;

/// RenderBox 组合持有的事件分发器；宿主转发命中测试、指针与悬停入口。
/// 没有 [ElEvent] 时不要创建，以保留被动节点零开销路径。
///
/// 最内层 PointerDown 宿主创建 [_PointerSequence] 并冻结 target→ancestor 链；
/// 后续 raw 与语义回调、状态机推进都在执行前检查成员资格。[ElEventCallback.stopPropagation]
/// 只截当前 phase 或已建立的 Drag/Scale/PanZoom family route，
/// [ElEventCallback.eagerGesture] 才同步淘汰其余成员并结清必要终态。
///
/// [ElEvent] shape 相等的替换只热换闭包并保留手势；shape 变化仍保留活跃 pointer/Drag，
/// 通常清理连击窗口、延迟 Tap 与侧键等离散 pending。唯一例外是仅挂卸
/// Drag 回调：其他结构完全不变时，Tap / LongPress 状态不应被无关切换打断。
///
/// 主键 Tap 默认按元素边界判定：exit 取消按压、re-enter 重发 TapDown，盒内移动距离
/// 不影响最终 Tap；`tapCancelOnMove:true` 才采用不可恢复的距离取消。TapUp 表示释放，
/// 即使最终 Tap 被距离、LongPress 或 winner 自身 Drag 取消仍会执行。LongPress 成立后
/// 默认认领当前手势并取消 Tap；回调可用 [ElEventCallback.preventDefault] 拒绝这项
/// 默认动作。侧键由最内层订阅者独占且不冒泡。
class ElEventDispatcher {
  /// 创建事件分发器。
  ElEventDispatcher(this._owner, {bool register = true})
    : _registered = register {
    if (_registered) {
      _registry[_owner] = this;
      // 新节点插入链，命中/冒泡快照可能变化。
      _configCascadeEpoch++;
    }
  }

  /// 全局注册表：从任意 [RenderBox] 找到其 dispatcher（用于链收集）。
  static final Expando<ElEventDispatcher> _registry =
      Expando<ElEventDispatcher>('ElEventDispatcher');

  /// 从指定 [RenderBox] 找到绑定的 dispatcher，没有则返回 `null`。
  static ElEventDispatcher? of(RenderBox node) => _registry[node];

  /// 同步结清 [root] 子树拥有的活动 pointer；force 用于禁用后不允许祖先续接的边界。
  @internal
  static void terminateActivePointerSequencesIn(
    RenderObject root, {
    bool force = false,
  }) {
    if (_PointerSequenceRegistry._sequences.isEmpty && !force) return;
    void visit(RenderObject node) {
      node.visitChildren(visit);
      if (node is RenderBox) {
        final dispatcher = of(node);
        dispatcher?._terminateOwnedPointerSequences(force: force);
        // 已抬起的延迟 Tap 不在活动序列中，禁用时也必须撤销。
        if (force) dispatcher?.cancelAllPendingAtLastPosition();
      }
    }

    visit(root);
  }

  /// 在整条冻结链上开启同步终态保护，避免拆树期间任一成员反解失效坐标。
  static void _withImmediateTerminalChain(
    _PointerSequence seq,
    void Function() body,
  ) {
    final changed = <ElEventDispatcher>[];

    void enable(ElEventDispatcher member) {
      if (member._terminalFiresImmediate) return;
      member._terminalFiresImmediate = true;
      changed.add(member);
    }

    for (final member in seq.chain) {
      enable(member);
    }
    final shadow = seq.scaleShadowTarget;
    if (shadow != null && !seq.contains(shadow)) enable(shadow);
    try {
      body();
    } finally {
      for (final member in changed) {
        member._terminalFiresImmediate = false;
      }
    }
  }

  /// ElEvent 帧驱动拖拽重采样的全局调试总闸，默认开启；业务配置应使用
  /// [ElEventConfig.dragResampling]，其默认平台仅 Android，Windows 需显式加入。
  /// 重采样只接管 Drag accept 后的 update，raw slop/Tap/速度估计保持原始事件；
  /// Flutter 官方重采样开启时自动让位。修改开关只影响下一手势。
  static bool get enableDragResampling => DragResamplingPolicy.enabled;

  static set enableDragResampling(bool value) =>
      DragResamplingPolicy.enabled = value;

  /// 根据屏幕刷新率给拖拽重采样选择 offset。返回 null 表示不开启。
  ///
  /// 默认路径下该值是自适应尾随的**下限**(采样器按实测触控周期动态加深尾随,
  /// 见 [DragResampler.adaptive]),-5ms 对齐 AOSP `RESAMPLE_LATENCY`。
  /// 保留函数形态供按设备覆写。
  static Duration? Function(double fps) get dragSamplingBuilder =>
      DragResamplingPolicy.samplingBuilder;

  static set dragSamplingBuilder(Duration? Function(double fps) value) =>
      DragResamplingPolicy.samplingBuilder = value;

  /// 采样偏移全局覆写:非 null 时跳过 [dragSamplingBuilder]（也不再咨询屏幕
  /// 刷新率）并**关闭自适应尾随**、按该值固定采样——调试语义要求生效偏移
  /// 严格等于拨的值。null 走默认(builder 下限 + 自适应尾随)。
  /// 采样时刻 = 帧时间戳 + 偏移:越负越平滑越滞后(纯插值),越接近 0 越依赖
  /// ≤8ms 有界外推(折返微过冲后回收敛)。对进行中的手势不生效,下一手势生效。
  static Duration? get dragSamplingOffsetOverride =>
      DragResamplingPolicy.samplingOffsetOverride;

  static set dragSamplingOffsetOverride(Duration? value) =>
      DragResamplingPolicy.samplingOffsetOverride = value;

  /// 诊断:采样器累计挂载次数（每次 accepted touch 拖拽成功挂载 +1）。真机
  /// 上分不清"开关没生效"还是"门控被挡"时,看拖拽后它是否增长。
  static int get debugDragResamplingEngageCount =>
      DragResamplingPolicy.debugEngageCount;

  static set debugDragResamplingEngageCount(int value) =>
      DragResamplingPolicy.debugEngageCount = value;

  /// 测试用平台覆写：非 null 时采样门控按该平台判定（跳过 FLUTTER_TEST 测试环境门控）。
  @visibleForTesting
  static TargetPlatform? get debugDragResamplingPlatformOverride =>
      DragResamplingPolicy.debugPlatformOverride;

  @visibleForTesting
  static set debugDragResamplingPlatformOverride(TargetPlatform? value) =>
      DragResamplingPolicy.debugPlatformOverride = value;

  @visibleForTesting
  static double? get debugDragResamplingRefreshRateOverride =>
      DragResamplingPolicy.debugRefreshRateOverride;

  @visibleForTesting
  static set debugDragResamplingRefreshRateOverride(double? value) =>
      DragResamplingPolicy.debugRefreshRateOverride = value;

  /// 本 dispatcher 的拖拽采样器当前是否在场（accepted touch 拖拽期）。
  @visibleForTesting
  bool get debugDragResamplingActive => _dragMachine?._dragResampler != null;

  /// 重置全部 pointer 序列（含 eager 独占状态）。测试隔离用。
  @visibleForTesting
  static void debugResetEagerGestureOwners() {
    _PointerSequenceRegistry.debugReset();
  }

  @visibleForTesting
  double? debugDisplayRefreshRateForTest() => _displayRefreshRate();

  /// 当前仍路由到本 dispatcher 的普通 pointer 数，仅供同包复合组件协调生命周期。
  @internal
  int get activePointerCount => _PointerSequenceRegistry.debugCountFor(this);

  /// 本 dispatcher 当前参与（owner 或链成员）的活跃序列数。
  @visibleForTesting
  int get debugRoutedPointerCount => activePointerCount;

  final RenderBox _owner;
  final bool _registered;

  ElEvent? _event;
  bool _cachedHasAnyCallback = false;

  /// 本地配置代际：dispatcher 结构替换 / attach / detach 会递增，
  /// 令相关 resolved config 缓存失效。
  static int _configCascadeEpoch = 0;

  int _resolvedConfigEpoch = -1;
  ElEventConfig _resolvedConfig = const ElEventConfig();

  /// 生效的事件识别配置：节点声明了 config 就原样返回（未设置的字段由
  /// [ElEventConfig] 的各 getter 自行回落内部默认值），未声明时返回空配置。
  ///
  /// 配置不沿 render 树注入；组件需要特殊手感时应在自己的 [ElEvent.config]
  /// 声明。
  ElEventConfig get config {
    if (_resolvedConfigEpoch != _configCascadeEpoch) {
      _resolvedConfigEpoch = _configCascadeEpoch;
      _resolvedConfig = _event?.config ?? const ElEventConfig();
    }
    return _resolvedConfig;
  }

  /// 配置替换的静默沉降路径需要"按旧配置阈值判定"：取 [previous]（旧 ElEvent）
  /// 声明的配置。声明部分与现配置相同时直接复用缓存。
  ElEventConfig _configOf(ElEvent? previous) {
    if (identical(previous?.config, _event?.config)) return config;
    return previous?.config ?? const ElEventConfig();
  }

  /// 配置代际：结构替换（shape 变化）或移除时递增；shape 相等的热替换不变。
  ///
  /// 语义事件在 enqueue 时捕获代际，flush 时代际不符则整体丢弃；事件处理
  /// 中途（raw 投递 handler 内）发生的结构替换会让同一事件后续的状态机喂送
  /// 切换为静默沉降——对齐旧实现 revision 检查的可观察行为。
  int _configGeneration = 0;

  /// set event / cancelAllPending / dispose 的终态回调（dragCancel /
  /// scaleCancel / panZoomEnd / cancel）需要在旧配置下同步执行，而不是排队
  /// 到 flush（那时配置已换）。这些入口置起该标记让 fire 立即投递。
  bool _terminalFiresImmediate = false;

  /// 事件配置的禁用状态；禁用节点不认领序列，也不参与事件冒泡。
  bool get disabled => _event?.disabled ?? false;

  /// 事件宿主使用的鼠标光标。
  MouseCursor get cursor => disabled
      ? SystemMouseCursors.forbidden
      : (_event?.cursor ?? MouseCursor.defer);

  /// 参与中的普通指针序列计数（owner 或链成员，不含 PanZoom stream）。
  int _activeSequenceCount = 0;

  /// 当前事件配置。
  ElEvent? get event => _event;

  set event(ElEvent? value) {
    final current = _event;
    if (identical(current, value)) return;
    if (!disabled && value?.disabled == true) {
      terminateActivePointerSequencesIn(_owner, force: true);
      // Cancel 回调中的后一次配置替换优先，避免覆盖重入的声明。
      if (!identical(_event, current)) return;
    }
    if (current?.cursor != value?.cursor ||
        (current?.disabled ?? false) != (value?.disabled ?? false) ||
        (current?.behavior ?? HitTestBehavior.opaque) !=
            (value?.behavior ?? HitTestBehavior.opaque) ||
        (current?.onPointerEnter == null) != (value?.onPointerEnter == null) ||
        (current?.onPointerExit == null) != (value?.onPointerExit == null)) {
      // 仅请求帧后的鼠标重算，不要求指针移动，也不标记布局或绘制脏。
      _owner.owner?.requestVisualUpdate();
    }
    if (current != null &&
        value != null &&
        current.hasSameGestureShape(value)) {
      // 识别结构不变时，闭包和光标等声明只热替换，保留进行中的手势。
      _event = value;
      _cachedHasAnyCallback = value.hasAnyCallback;
      return;
    }
    final preservesPrimaryTapState =
        current != null && value != null && current.hasSameNonDragShape(value);
    final replacementDuringDispatch = _DispatchCycle.isActive;
    // fresh dispatcher 快路径：挂载首次 set event（状态机全 null、无 panZoom）
    // 时慢路径的全部清理判定语义收缩为纯赋值——
    // seedForActivePrimaryIfNeeded 因 _tapMachine == null 无 _downEvent 快照
    // 必早退不可能 fire；_DispatchCycle 包装与 _terminalFiresImmediate 快照
    // 均为空转，跳过。代际/纪元自增与慢路径一致保留。
    if (current == null &&
        value != null &&
        _tapMachine == null &&
        _dragMachine == null &&
        _scaleMachine == null &&
        !_panZoomStarted &&
        _secondaryMachine == null &&
        _tertiaryMachine == null &&
        _forwardMachine == null &&
        _backMachine == null) {
      _configGeneration++;
      _configCascadeEpoch++;
      _event = value;
      _cachedHasAnyCallback = value.hasAnyCallback;
      if (_hasDragShape(value)) {
        (_dragMachine ??= _DragMachine(this)).seedForActivePrimaryIfNeeded();
      }
      return;
    }
    _configGeneration++;
    // 结构替换可能带来新的 tapConfig / dragConfig 声明，已缓存的有效配置
    // 一并失效。
    _configCascadeEpoch++;
    final replaceGeneration = _configGeneration;
    // 终态回调（dragCancel / scaleCancel / panZoomEnd / cancel）在旧配置下
    // 同步执行；handler 内再次 set event 时（代际再次变化）中止剩余替换步骤
    // ——对齐旧实现的 revision 中止语义。
    _DispatchCycle.run(() {
      final previousImmediate = _terminalFiresImmediate;
      _terminalFiresImmediate = true;
      try {
        _cancelPassiveDragPipeline();
        if (_configGeneration != replaceGeneration) return;
        if (value == null ||
            !_hasDragShape(value) ||
            replacementDuringDispatch ||
            !_canPreserveOutstandingDragRoutes(value)) {
          _cancelDragRoutesForLifecycle(expectedGeneration: replaceGeneration);
          if (_configGeneration != replaceGeneration) return;
        }
        if (value != null) {
          // Tap 家族或识别参数变化时丢弃离散 pending；仅动态
          // 挂卸 Drag 等无关 shape 时保留长按计时与连击窗口。
          if (!preservesPrimaryTapState) {
            _tapMachine?.invalidateDiscretePending();
          }
          _clearSideMachines();
          if (!_hasDragShape(value)) {
            _dragMachine?.cancelActive();
            if (_configGeneration != replaceGeneration) return;
            _dragMachine = null;
          }
          if (!_needsScaleShape(value)) {
            _cancelActiveScale();
            if (_configGeneration != replaceGeneration) return;
            _scaleMachine = null;
          }
          if (!_needsPanZoomShape(value)) {
            _cancelActivePanZoom();
            if (_configGeneration != replaceGeneration) return;
          }
          _event = value;
          _cachedHasAnyCallback = value.hasAnyCallback;
          if (_hasDragShape(value)) {
            (_dragMachine ??= _DragMachine(
              this,
            )).seedForActivePrimaryIfNeeded();
          }
          return;
        }
        // event 移除：取消一切进行中的手势（终态回调用旧配置同步 fire），
        // 移除配置时一并释放事件状态机。
        _tapMachine?.cancelActive();
        if (_configGeneration != replaceGeneration) return;
        _tapMachine?.resetConsecutiveWindow();
        _dragMachine?.cancelActive();
        if (_configGeneration != replaceGeneration) return;
        _cancelActiveScale();
        if (_configGeneration != replaceGeneration) return;
        _cancelActivePanZoom();
        if (_configGeneration != replaceGeneration) return;
        _clearSideMachines();
        _event = null;
        _cachedHasAnyCallback = false;
        _scaleMachine = null;
        _dragMachine = null;
        _PointerSequenceRegistry.evict(this);
      } finally {
        _terminalFiresImmediate = previousImmediate;
      }
    });
  }

  /// 全局坐标是否落在宿主自身的命中范围内。
  ///
  /// 由事件 Widget 的渲染宿主注入，供 [ElEventConfig.tapCancelOnMove] 为
  /// false 时的边界口径 tap 判定使用（拖出熄灭、拖回复燃）。未注入时该口径
  /// 退化为"永远在范围内"，此时只有抬手位置越过 [ElEventConfig.tapCancelDistance]
  /// 的兜底判定生效。
  bool Function(Offset globalPosition)? hitBoundsContainsGlobal;

  /// 指针是否落在宿主命中范围内（未注入判定器时恒 true）。
  bool _withinHostBounds(Offset globalPosition) =>
      hitBoundsContainsGlobal?.call(globalPosition) ?? true;

  /// 宿主原点在全局空间的落位（**只算祖先链**，不含本节点自身的 paint
  /// transform）。取不到（未 attach / 矩阵退化）时返回 null。
  ///
  /// 排除自身 transform，避免控件响应按压时的局部动画误判为祖先搬走内容。
  Offset? _hostOriginInGlobal() {
    if (!_owner.attached) return null;
    final ancestorTransform = _owner.parent?.getTransformTo(null);
    if (ancestorTransform == null) return Offset.zero;
    // 退化矩阵（scale 0 等）：画不出来也无从比较，放弃判定而不是误取消。
    if (ancestorTransform.determinant() == 0.0) return null;
    return MatrixUtils.transformPoint(ancestorTransform, Offset.zero);
  }

  /// 宿主相对按下时刻漂移了多远——识别"内容在手指底下被搬走了"。
  ///
  /// 祖先滚动 / 翻页 / 路由动画都会让它增长。祖先是官方 Scrollable 时事件层
  /// 收不到任何拖拽信号（它在 gesture arena 里独立获胜，与 ElEvent 闭环无
  /// 交集），只能靠这个几何量反推手势归属已定。
  double? _hostDriftSince(Offset downOrigin) {
    final current = _hostOriginInGlobal();
    return current == null ? null : (current - downOrigin).distance;
  }

  /// 可参与 drag 的指针设备。null 表示不限制。
  Set<PointerDeviceKind>? dragDevices;

  /// 平台与设备提供的拖拽识别阈值。
  DeviceGestureSettings? gestureSettings;

  /// 多指拖拽时的位移合并策略。
  MultitouchDragStrategy multitouchDragStrategy =
      MultitouchDragStrategy.latestPointer;

  /// drag 结束速度追踪器构造器。
  GestureVelocityTrackerBuilder velocityTrackerBuilder = (PointerEvent event) =>
      VelocityTracker.withKind(event.kind);

  // ---------------------------------------------------------------------------
  // 手势状态机
  // ---------------------------------------------------------------------------

  _TapMachine? _tapMachine;
  _DragMachine? _dragMachine;
  _ScaleMachine? _scaleMachine;
  _SideButtonMachine? _secondaryMachine;
  _SideButtonMachine? _tertiaryMachine;
  _SideButtonMachine? _forwardMachine;
  _SideButtonMachine? _backMachine;

  /// 反向引用：本宿主被某活跃 [ElDragProxy] 管线钝化时指向该管线（driver 的
  /// [_DragMachine._pipeline]）。生命周期由 driver 端 resetSilently 统一维护，
  /// 本宿主对钝化状态只读——drag 机的 feedDown/feedMove/_settleMove/
  /// seedForActivePrimaryIfNeeded 在此非空且 active 时直接返回，防止自机复活。
  _DragPipeline? _passiveDragPipeline;

  _TapMachine get _ensureTapMachine => _tapMachine ??= _TapMachine(this);

  /// 是否需要实例化主指针 tap 机（[_feedDown] 惰性创建的门槛）。
  ///
  /// 仅当宿主声明 tap 家族回调（tap / 连击 / 长按 / tapCancel）时创建，
  /// 只挂 drag / raw 回调的宿主不为每次按下分配 tap 机。
  /// 代价（已接受，与官方"mid-press 新增 recognizer 不追溯"语义对齐）：down
  /// 时不满足条件的宿主在同一次按压中途经结构替换获得 tap / drag 回调时，
  /// 没有 tap 候选可判——tap 不触发；drag 的 seedForActivePrimaryIfNeeded
  /// 因无 _downEvent 快照而无法补种。下一次按下起恢复正常。
  bool get _needsTapMachine {
    final event = _event;
    if (event == null) return false;
    return event.onTapDown != null ||
        event.onTapUp != null ||
        event.onTap != null ||
        event.onDoubleTap != null ||
        event.onDoubleTapDown != null ||
        event.onTripleTap != null ||
        event.onTripleTapDown != null ||
        event.onLongPress != null ||
        event.onTapCancel != null;
  }

  _SideButtonMachine _sideMachineFor(int buttonMask) {
    return switch (buttonMask) {
      kSecondaryButton => _secondaryMachine ??= _SideButtonMachine(
        this,
        kSecondaryButton,
        ElEventPhase.secondaryTapDown,
        ElEventPhase.secondaryTapUp,
        ElEventPhase.secondaryTap,
        overrideButtons: kSecondaryButton,
      ),
      kTertiaryButton => _tertiaryMachine ??= _SideButtonMachine(
        this,
        kTertiaryButton,
        ElEventPhase.tertiaryTapDown,
        ElEventPhase.tertiaryTapUp,
        ElEventPhase.tertiaryTap,
        overrideButtons: kTertiaryButton,
      ),
      kForwardMouseButton => _forwardMachine ??= _SideButtonMachine(
        this,
        kForwardMouseButton,
        ElEventPhase.forwardTapDown,
        ElEventPhase.forwardTapUp,
        ElEventPhase.forwardTap,
      ),
      kBackMouseButton => _backMachine ??= _SideButtonMachine(
        this,
        kBackMouseButton,
        ElEventPhase.backTapDown,
        ElEventPhase.backTapUp,
        ElEventPhase.backTap,
      ),
      _ => throw ArgumentError.value(buttonMask, 'buttonMask'),
    };
  }

  static const List<_SideButtonMachine> _noSideMachines =
      <_SideButtonMachine>[];

  /// 去 sync*：无侧键机（常态）返回共享空表零分配——本 getter 在每次
  /// move/cancel 喂送里被调用，生成器机器是纯税。
  List<_SideButtonMachine> get _liveSideMachines {
    if (_secondaryMachine == null &&
        _tertiaryMachine == null &&
        _forwardMachine == null &&
        _backMachine == null) {
      return _noSideMachines;
    }
    return <_SideButtonMachine>[
      ?_secondaryMachine,
      ?_tertiaryMachine,
      ?_forwardMachine,
      ?_backMachine,
    ];
  }

  void _clearSideMachines() {
    for (final machine in _liveSideMachines) {
      machine.clear();
    }
  }

  static const List<int> _sideButtonMasks = <int>[
    kSecondaryButton,
    kTertiaryButton,
    kForwardMouseButton,
    kBackMouseButton,
  ];

  /// 全部侧键位的并集（feed 侧整段跳过门禁）。
  static const int _allSideButtonsMask =
      kSecondaryButton |
      kTertiaryButton |
      kForwardMouseButton |
      kBackMouseButton;

  // ---------------------------------------------------------------------------
  // 状态位
  // ---------------------------------------------------------------------------

  Offset _lastPointerPosition = Offset.zero;

  /// 当前是否仍有指针、拖拽、缩放或触控板手势进行中。
  ///
  /// 语义按**状态机活跃度**定义（tap 候选 / drag 指针 / scale / panZoom /
  /// 侧键按下），而非序列注册表成员数——序列条目只是路由基建，up 之后由
  /// 微任务移除；cancelAllPending 清空状态机后本值立即变 false（滚动 latch
  /// 依赖这一点判断可否立即重接线）。
  @internal
  bool get hasActivePointerSequence =>
      (_tapMachine?.tracking ?? false) ||
      (_dragMachine?.hasPointers ?? false) ||
      (_scaleMachine != null &&
          (_scaleMachine!.started || _scaleMachine!.hasPointers)) ||
      _panZoomStarted ||
      _secondaryMachine?.hasPointer == true ||
      _tertiaryMachine?.hasPointer == true ||
      _forwardMachine?.hasPointer == true ||
      _backMachine?.hasPointer == true;

  // ---------------------------------------------------------------------------
  // PanZoom 状态（trackpad）
  // ---------------------------------------------------------------------------

  bool _panZoomStarted = false;
  int? _panZoomPointerId;
  Offset? _lastPanZoomPosition;

  // ---------------------------------------------------------------------------
  // 配置 shape 判定
  // ---------------------------------------------------------------------------

  /// 是否声明了任意拖拽回调（自由 / 垂直 / 水平任一组）。
  bool _hasDragShape(ElEvent? event) {
    return _hasFreeDragShape(event) ||
        _hasVerticalDragShape(event) ||
        _hasHorizontalDragShape(event);
  }

  /// 自由拖拽组（onDrag*，官方 pan 语义）。
  static bool _hasFreeDragShape(ElEvent? event) {
    return event != null &&
        (event.onDragStart != null ||
            event.onDragUpdate != null ||
            event.onDragEnd != null ||
            event.onDragCancel != null);
  }

  /// 垂直拖拽组（onVerticalDrag*）。
  static bool _hasVerticalDragShape(ElEvent? event) {
    return event != null &&
        (event.onVerticalDragStart != null ||
            event.onVerticalDragUpdate != null ||
            event.onVerticalDragEnd != null ||
            event.onVerticalDragCancel != null);
  }

  /// 水平拖拽组（onHorizontalDrag*）。
  static bool _hasHorizontalDragShape(ElEvent? event) {
    return event != null &&
        (event.onHorizontalDragStart != null ||
            event.onHorizontalDragUpdate != null ||
            event.onHorizontalDragEnd != null ||
            event.onHorizontalDragCancel != null);
  }

  bool _needsScaleShape(ElEvent? event) {
    return event != null &&
        (event.onScaleStart != null ||
            event.onScaleUpdate != null ||
            event.onScaleEnd != null ||
            event.onScaleCancel != null ||
            event.onRotationUpdate != null);
  }

  bool _needsPanZoomShape(ElEvent? event) {
    return event != null &&
        (event.onPointerPanZoomStart != null ||
            event.onPointerPanZoomUpdate != null ||
            event.onPointerPanZoomEnd != null);
  }

  bool _subscribesSideButton(int buttonMask) {
    final event = _event;
    if (event == null) return false;
    return switch (buttonMask) {
      kSecondaryButton =>
        event.onSecondaryTapDown != null ||
            event.onSecondaryTapUp != null ||
            event.onSecondaryTap != null,
      kTertiaryButton =>
        event.onTertiaryTapDown != null ||
            event.onTertiaryTapUp != null ||
            event.onTertiaryTap != null,
      kForwardMouseButton =>
        event.onForwardTapDown != null ||
            event.onForwardTapUp != null ||
            event.onForwardTap != null,
      kBackMouseButton =>
        event.onBackTapDown != null ||
            event.onBackTapUp != null ||
            event.onBackTap != null,
      _ => false,
    };
  }

  // ===========================================================================
  // Hit-test & 事件入口
  // ===========================================================================

  /// 命中测试：节点声明任意事件回调时返回 `true`。
  bool hitTestSelf(Offset position) => _cachedHasAnyCallback;

  /// 处理 pointer 事件。由宿主 [RenderBox.handleEvent] 转发。
  ///
  /// 单一所有者模型：最内层认领，后续由 owner 沿冻结链统一喂送。
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (disabled) return;
    _lastPointerPosition = event.position;
    switch (event) {
      case PointerDownEvent():
        _handleDownEntry(event);
      case PointerMoveEvent() || PointerUpEvent() || PointerCancelEvent():
        final seq = _PointerSequenceRegistry.of(event.pointer);
        if (seq == null) return;
        if (!identical(seq.owner, this)) {
          if (!seq.contains(this)) return;
          if (event is PointerMoveEvent) {
            // move 不冒泡：成员的 raw move 投递与 tap/drag 手势机推进由成员
            // 自己的 hit-test 送达驱动（owner 只喂自己 + scale tracker）。
            _handleMemberMove(seq, event);
          } else {
            // up/cancel 的状态机喂送已由 owner 沿链完成，这里只做终态记账，
            // 最外层成员见到终态时同步释放序列。
            _PointerSequenceRegistry.memberSawTerminal(seq, this);
          }
          return;
        }
        _processSequenceEvent(seq, event);
      case PointerPanZoomStartEvent():
        _handlePanZoomStartEntry(event);
      case PointerPanZoomUpdateEvent() || PointerPanZoomEndEvent():
        final seq = _PointerSequenceRegistry.of(event.pointer);
        if (seq == null) return;
        if (!identical(seq.owner, this)) {
          if (event is PointerPanZoomEndEvent && seq.contains(this)) {
            _PointerSequenceRegistry.memberSawTerminal(seq, this);
          }
          return;
        }
        _processSequenceEvent(seq, event);
      case PointerRemovedEvent():
        break; // 由 _PointerSequenceRegistry 的全局路由处理
      case PointerHoverEvent() || PointerSignalEvent():
        _handleNonSequenceEvent(event);
      default:
        break;
    }
  }

  void _handleDownEntry(PointerDownEvent event) {
    final canonical = _canonicalPointerEvent(event);
    final existing = _PointerSequenceRegistry.of(event.pointer);
    if (existing != null && identical(existing.canonicalDown, canonical)) {
      // 同一个 down 已被认领。若本节点已在链上（正常子→根分发）直接返回；
      // 不在链上说明本节点比现 owner 更内层（分发顺序反转）——重根接管。
      if (existing.contains(this)) return;
      final rerooted = _PointerSequenceRegistry.reroot(this, existing);
      _processSequenceEvent(rerooted, event);
      return;
    }
    final seq = _PointerSequenceRegistry.claim(this, event, isPanZoom: false)
      ..canonicalDown = canonical;
    _processSequenceEvent(seq, event);
  }

  void _handlePanZoomStartEntry(PointerPanZoomStartEvent event) {
    final canonical = _canonicalPointerEvent(event);
    final existing = _PointerSequenceRegistry.of(event.pointer);
    if (existing != null && identical(existing.canonicalDown, canonical)) {
      if (existing.contains(this)) return;
      final rerooted = _PointerSequenceRegistry.reroot(this, existing);
      _processSequenceEvent(rerooted, event);
      return;
    }
    final seq = _PointerSequenceRegistry.claim(this, event, isPanZoom: true)
      ..canonicalDown = canonical;
    _processSequenceEvent(seq, event);
  }

  void _processSequenceEvent(_PointerSequence seq, PointerEvent event) {
    _DispatchCycle.run(() {
      seq.beginCycle(_canonicalPointerEvent(event));
      switch (event) {
        case PointerDownEvent():
          final replaced = _configReplacedProbe(seq);
          _deliverRaw(seq, ElEventPhase.pointerDown, event);
          _feedDown(seq, event, replaced);
        case PointerMoveEvent():
          // move 不做上前链投递：raw move 逐成员交错在状态机喂送里
          // （旧模型中 move 不冒泡，祖先靠自己的原生分发接收，天然排在
          // 子级完整处理之后——交错保持这一跨成员次序）。
          _feedMove(seq, event);
        case PointerUpEvent():
          final replaced = _configReplacedProbe(seq);
          _deliverRaw(seq, ElEventPhase.pointerUp, event);
          _feedUp(seq, event, replaced);
          _PointerSequenceRegistry.memberSawTerminal(seq, this);
        case PointerCancelEvent():
          final replaced = _configReplacedProbe(seq);
          _deliverRaw(seq, ElEventPhase.pointerCancel, event);
          _feedCancel(seq, event, replaced);
          _PointerSequenceRegistry.memberSawTerminal(seq, this);
        case PointerPanZoomStartEvent():
          for (var index = 0; index < seq.chain.length; index++) {
            if (!_memberActiveAt(seq, index)) continue;
            final member = seq.chain[index];
            member._panZoomStarted = true;
            member._panZoomPointerId = event.pointer;
            member._lastPanZoomPosition = event.position;
          }
          _deliverRaw(seq, ElEventPhase.pointerPanZoomStart, event);
        case PointerPanZoomUpdateEvent():
          final position = event.position + event.pan;
          for (var index = 0; index < seq.chain.length; index++) {
            if (!_memberActiveAt(seq, index)) continue;
            final member = seq.chain[index];
            if (member._panZoomStarted) member._lastPanZoomPosition = position;
          }
          _deliverRaw(
            seq,
            ElEventPhase.pointerPanZoomUpdate,
            event,
            globalPosition: position,
          );
        case PointerPanZoomEndEvent():
          final position = _lastPanZoomPosition ?? event.position;
          for (var index = 0; index < seq.chain.length; index++) {
            if (!_memberActiveAt(seq, index)) continue;
            final member = seq.chain[index];
            if (member._panZoomStarted) member._lastPanZoomPosition = position;
          }
          _deliverRaw(
            seq,
            ElEventPhase.pointerPanZoomEnd,
            event,
            globalPosition: position,
          );
          for (final member in seq.chain) {
            member._clearPanZoomState(event.pointer);
          }
          _PointerSequenceRegistry.memberSawTerminal(seq, this);
        default:
          break;
      }
    });
  }

  /// 捕获链上每个成员的配置快照，返回"槽位 i 的配置是否已被结构替换"判定器：
  /// raw 投递 handler 内的结构替换（shape 变化）会让该成员本事件的剩余状态机
  /// 喂送切换为静默沉降。
  ///
  /// 只在 down / up / cancel 分支调用——move / panZoom 是最高频入口，不付这份
  /// List + 闭包分配（move 只消费 self 槽位，见 [_feedMove]；panZoom 不消费）。
  static bool Function(int) _configReplacedProbe(_PointerSequence seq) {
    final configs = List<ElEvent?>.generate(
      seq.chain.length,
      (i) => seq.chain[i]._event,
      growable: false,
    );
    return (i) => !_sameShape(configs[i], seq.chain[i]._event);
  }

  void _clearPanZoomState(int pointer) {
    if (_panZoomPointerId != pointer) return;
    _panZoomStarted = false;
    _panZoomPointerId = null;
    _lastPanZoomPosition = null;
  }

  // ---------------------------------------------------------------------------
  // 状态机喂送（owner 驱动，尊重链截断）
  // ---------------------------------------------------------------------------

  /// 两份配置是否同构（shape 相等即视为同一配置；热替换不算替换）。
  static bool _sameShape(ElEvent? a, ElEvent? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a == b;
  }

  void _feedDown(
    _PointerSequence seq,
    PointerDownEvent event,
    bool Function(int index) replaced,
  ) {
    // 侧键：nearest tracker wins。down 不含任何侧键位（常态主键 tap/drag）时
    // 整段跳过——tracker 解析的 putIfAbsent 闭包 + 链扫是纯税；打标供
    // up/cancel 同样跳过（侧键机激活只发生在 down，判据同 mask 交集）。
    if ((event.buttons & _allSideButtonsMask) != 0) {
      seq.sawSideButtons = true;
      for (final mask in _sideButtonMasks) {
        if ((event.buttons & mask) == 0) continue;
        final tracker = seq.sideTrackerFor(mask);
        final trackerIndex = tracker == null ? -1 : seq.indexOf(tracker);
        if (tracker != null &&
            _memberActiveAt(seq, trackerIndex) &&
            !replaced(trackerIndex)) {
          tracker._sideMachineFor(mask).feedDown(seq, event);
        }
      }
    }
    // Scroll 已屏蔽内容命中时，首指预留的 Scale shadow 优先于
    // 当前链上无关的外层 Scale；普通 down 仍是 nearest tracker wins。
    final reservedScaleTracker =
        _PointerSequenceRegistry.attachReservedScaleTarget(seq, event);
    final scaleTracker = reservedScaleTracker ?? seq.resolveScaleTracker();
    final scaleIndex = scaleTracker == null ? -1 : seq.indexOf(scaleTracker);
    if (scaleTracker != null &&
        (reservedScaleTracker != null ||
            (_memberActiveAt(seq, scaleIndex) && !replaced(scaleIndex)))) {
      (scaleTracker._scaleMachine ??= _ScaleMachine(
        scaleTracker,
      )).feedDown(seq, event);
    }
    if (seq.scaleWon || reservedScaleTracker != null) return;
    // tap + drag：链上所有订阅成员并行跟踪（各自阈值），主键手势链截断生效。
    // downFedMembers 防止序列重根后同一 down 重复喂送已处理过的外层成员。
    for (var i = 0; i < seq.chain.length; i++) {
      if (!_memberActiveAt(seq, i)) continue;
      final member = seq.chain[i];
      if (i >= seq.primaryGestureCutoff) break;
      if (!seq.markDownFed(member)) continue;
      member._lastPointerPosition = event.position;
      if (replaced(i)) {
        // down 处理中途配置被结构替换：不建立 tap 候选 / 长按计时（对齐旧
        // 实现 revision 中止）；drag 按新配置 shape 直接开始跟踪（等价旧
        // seed 语义）。
        if (member._hasDragShape(member._event)) {
          (member._dragMachine ??= _DragMachine(member)).feedDown(seq, event);
        }
        continue;
      }
      if (i < seq.dragRouteCutoff &&
          (member._event?.onDragDown != null ||
              member._hasDragShape(member._event))) {
        (member._dragMachine ??= _DragMachine(member)).feedDown(seq, event);
      }
      if (i < seq.tapCutoff &&
          _memberActiveAt(seq, i) &&
          member._needsTapMachine) {
        member._ensureTapMachine.feedDown(seq, event);
      }
      _DispatchCycle.flushNow();
    }
  }

  /// move：owner 只投递/喂送自己（+ scale tracker 聚合）。
  ///
  /// raw move 不冒泡（scroll 热路径税）；非 owner 链成员的 raw 投递与 tap/drag
  /// 手势机推进由各自的 hit-test 送达（[_handleMemberMove]）驱动——对齐旧模型
  /// "成员手势在自己的原生分发到达时推进"。同一 canonical 事件下 owner（最内
  /// 层）先处理：其语义 fire 的冒泡标记抑制外层成员自机的同 phase 重复 fire，
  /// 其 stopPropagation 截断外层成员本事件的投递。
  void _feedMove(_PointerSequence seq, PointerMoveEvent event) {
    // 只捕获自己的配置引用，不建全链快照（move 是全系统最高频入口）。
    // scale tracker 喂送发生在本事件任何 handler 运行之前，其配置此刻必然
    // 未被本事件内的结构替换触碰，无需 replaced 判定。
    final selfConfig = _event;
    final scaleTracker = seq.scaleTracker;
    final scaleIndex = scaleTracker == null ? -1 : seq.indexOf(scaleTracker);
    if (scaleTracker != null &&
        _scaleTrackerActive(seq, scaleTracker, scaleIndex)) {
      scaleTracker._scaleMachine?.feedMove(seq, event);
      _DispatchCycle.flushNow();
    }
    if (!_memberActiveAt(seq, 0)) return;
    // 侧键 *Tap 的移动越界取消（对齐 onTap 语义）：owner 喂自己的侧键机，
    // 非 owner tracker 的喂送在 [_handleMemberMove]。
    for (final machine in _liveSideMachines) {
      machine.feedMove(event);
    }
    _deliverRawMoveToSelf(seq, 0, event);
    if (seq.scaleWon) return;
    if (seq.primaryGestureCutoff <= 0 || !_memberActiveAt(seq, 0)) return;
    if (!_sameShape(selfConfig, _event)) {
      _settleMoveAfterReplacement(seq, event, selfConfig);
      return;
    }
    _dragMachine?.feedMove(seq, event);
    _tapMachine?.feedMove(seq, event);
  }

  /// 非 owner 链成员在自己的 handleEvent 收到 move。
  ///
  /// canonical 事件保持同一 cycle：更内层成员（先到）已 fire 的语义 phase
  /// 冒泡标记在此仍然有效（本成员自机的同 phase 重复 fire 被抑制），其
  /// stopPropagation 的 cycle 级截断同样对本成员生效。
  void _handleMemberMove(_PointerSequence seq, PointerMoveEvent event) {
    _DispatchCycle.run(() {
      seq.beginCycle(_canonicalPointerEvent(event));
      final index = seq.indexOf(this);
      if (!_memberActiveAt(seq, index)) return;
      final config = _event;
      for (final machine in _liveSideMachines) {
        machine.feedMove(event);
      }
      _deliverRawMoveToSelf(seq, index, event);
      if (seq.scaleWon) return;
      if (index >= seq.primaryGestureCutoff || !_memberActiveAt(seq, index)) {
        return;
      }
      if (!_sameShape(config, _event)) {
        // raw 投递 handler 内发生结构替换：本事件剩余喂送静默沉降。
        _settleMoveAfterReplacement(seq, event, config);
        return;
      }
      _dragMachine?.feedMove(seq, event);
      _tapMachine?.feedMove(seq, event);
    });
  }

  void _deliverRawMoveToSelf(
    _PointerSequence seq,
    int selfIndex,
    PointerMoveEvent event,
  ) {
    if (!_memberActiveAt(seq, selfIndex) ||
        seq.blockedAt(ElEventPhase.pointerMove, selfIndex)) {
      return;
    }
    final handler = _handlerFor(ElEventPhase.pointerMove);
    if (handler == null || !_owner.attached) return;
    if (!seq.markDelivered(ElEventPhase.pointerMove, this, selfIndex)) return;
    final callback = ElEventCallback(
      phase: ElEventPhase.pointerMove,
      globalPosition: event.position,
      localPosition: Offset.zero,
      delta: event.delta,
      localDelta: Offset.zero,
      pointerCount: _activeSequenceCount,
      buttons: event.buttons,
      originalEvent: event,
    );
    _adoptLocalFromEvent(callback, event);
    _retargetResolversOnly(callback, this, seq, selfIndex);
    callback.markCallbackInvoked();
    handler(callback);
    if (callback.propagationStopped) {
      seq.applyStopPropagation(ElEventPhase.pointerMove, selfIndex);
    }
  }

  /// move 处理中途配置被结构替换：静默沉降（不 fire 任何回调），对齐旧
  /// `_settlePointerMoveAfterEventReplacement`。
  void _settleMoveAfterReplacement(
    _PointerSequence seq,
    PointerMoveEvent event,
    ElEvent? previousConfig,
  ) {
    final previous = previousConfig ?? const ElEvent();
    final dragAccepted =
        _dragMachine?._settleMoveAfterReplacement(seq, event, previous) ??
        false;
    _tapMachine?._settleMoveAfterReplacement(
      event,
      previous,
      dragAccepted: dragAccepted,
    );
  }

  void _feedUp(
    _PointerSequence seq,
    PointerUpEvent event,
    bool Function(int) replaced,
  ) {
    final scaleWon = seq.scaleWon;
    if (seq.sawSideButtons) {
      for (final mask in _sideButtonMasks) {
        final tracker = seq.sideTrackerFor(mask);
        if (tracker == null) continue;
        final trackerIndex = seq.indexOf(tracker);
        if (!_memberActiveAt(seq, trackerIndex)) continue;
        if (replaced(trackerIndex)) {
          tracker._sideMachineFor(mask).feedRemoved(event.pointer);
          continue;
        }
        tracker._sideMachineFor(mask).feedUp(seq, event);
      }
    }
    final scaleTracker = seq.scaleTracker;
    final scaleIndex = scaleTracker == null ? -1 : seq.indexOf(scaleTracker);
    if (scaleTracker != null &&
        _scaleTrackerActive(seq, scaleTracker, scaleIndex)) {
      if (scaleIndex >= 0 && replaced(scaleIndex)) {
        scaleTracker._scaleMachine?.feedRemoved(event.pointer);
      } else {
        scaleTracker._scaleMachine?.feedUp(seq, event);
      }
    }
    if (scaleWon || seq.scaleWon) return;
    if (seq.hasTrackedDrag) {
      for (var i = 0; i < seq.chain.length; i++) {
        if (!_memberActiveAt(seq, i)) continue;
        final member = seq.chain[i];
        member._lastPointerPosition = event.position;
        if (i >= seq.primaryGestureCutoff || replaced(i)) {
          member._dragMachine?.removePointerSilently(event.pointer);
          continue;
        }
        member._dragMachine?.feedUp(seq, event);
      }
    }
    _DispatchCycle.flushNow();
    _settleOutstandingDragTerminals(seq, event, canceled: false);
    // 先让整条链的 Drag 完成 up rescue 决胜，再结算任意 Tap；否则祖先在 up
    // 接受 micro-fling 时，较深节点可能已经提前发出 tapUp/tap。
    for (var i = 0; i < seq.chain.length; i++) {
      if (!_memberActiveAt(seq, i)) continue;
      final member = seq.chain[i];
      member._lastPointerPosition = event.position;
      if (i >= seq.primaryGestureCutoff || replaced(i)) {
        member._tapMachine?.feedRemoved(event.pointer);
        continue;
      }
      member._tapMachine?.feedUp(seq, event, memberIndex: i);
    }
  }

  /// [external] 标记本次取消由宿主发起（销毁 / 真离场结算），而非平台指针取消；
  /// 传给 tap 机决定报告给用户回调的取消原因。
  void _feedCancel(
    _PointerSequence seq,
    PointerCancelEvent event,
    bool Function(int) replaced, {
    bool external = false,
  }) {
    final scaleWon = seq.scaleWon;
    for (var index = 0; index < seq.chain.length; index++) {
      if (!_memberActiveAt(seq, index)) continue;
      final member = seq.chain[index];
      for (final machine in member._liveSideMachines) {
        machine.feedCancel(event);
      }
    }
    final scaleTracker = seq.scaleTracker;
    final scaleIndex = scaleTracker == null ? -1 : seq.indexOf(scaleTracker);
    if (scaleTracker != null &&
        _scaleTrackerActive(seq, scaleTracker, scaleIndex)) {
      if (scaleIndex >= 0 && replaced(scaleIndex)) {
        scaleTracker._scaleMachine?.feedRemoved(event.pointer);
      } else {
        scaleTracker._scaleMachine?.feedCancel(seq, event);
      }
    }
    if (scaleWon || seq.scaleWon) return;
    for (var i = 0; i < seq.chain.length; i++) {
      if (!_memberActiveAt(seq, i)) continue;
      final member = seq.chain[i];
      if (i >= seq.primaryGestureCutoff || replaced(i)) {
        member._tapMachine?.feedRemoved(event.pointer);
        member._dragMachine?.removePointerSilently(event.pointer);
        continue;
      }
      member._dragMachine?.feedCancel(seq, event);
      member._tapMachine?.feedCancel(seq, event, external: external);
    }
    _DispatchCycle.flushNow();
    _settleOutstandingDragTerminals(seq, event, canceled: true);
  }

  /// 按成员把多指 Drag 台账迁往各自仍在驱动的序列；旧链独有成员就地终结。
  void _settleOutstandingDragTerminals(
    _PointerSequence ending,
    PointerEvent event, {
    required bool canceled,
  }) {
    for (
      var memberIndex = 0;
      memberIndex < ending.chain.length;
      memberIndex++
    ) {
      if (ending.outstandingDragStartFamiliesAt(memberIndex) == 0) continue;
      final member = ending.chain[memberIndex];
      final pipeline = member._passiveDragPipeline;
      final drag = pipeline?.active == true
          ? pipeline!.driver._dragMachine
          : member._dragMachine;
      if (drag?._dragStarted != true || drag?.hasPointers != true) continue;
      final continuation = drag?._activeSequence;
      if (continuation == null || identical(continuation, ending)) continue;
      if (!identical(
        _PointerSequenceRegistry.of(continuation.pointer),
        continuation,
      )) {
        continue;
      }
      ending.transferOutstandingDragStartsForMemberTo(
        member,
        memberIndex,
        continuation,
      );
    }
    _flushOutstandingDragTerminals(ending, event, canceled: canceled);
  }

  /// 为只参与 Start proposal、未由任何 DragMachine 产生终态的成员补齐唯一终态。
  void _flushOutstandingDragTerminals(
    _PointerSequence seq,
    PointerEvent event, {
    required bool canceled,
  }) {
    var families = seq.outstandingDragStartFamilies;
    while (families != 0) {
      final family = families & -families;
      families &= ~family;
      final familyAxis = _dragAxisForStartFamily(family);
      ElEventDispatcher? firer;
      var firerIndex = -1;
      for (var i = 0; i < seq.chain.length; i++) {
        final member = seq.chain[i];
        if (seq.hasOutstandingDragStartRoute(member, familyAxis) &&
            _memberActiveAt(seq, i)) {
          firer = member;
          firerIndex = i;
          break;
        }
      }
      if (firer == null) {
        for (final member in seq.chain) {
          seq.takeOutstandingDragStartRoute(member, familyAxis);
        }
        continue;
      }
      final axis = seq.observedDragStartAxisAt(firerIndex) ?? familyAxis;
      if (canceled) {
        firer._fireWithDelta(
          seq,
          ElEventPhase.dragCancel,
          event.position,
          Offset.zero,
          Offset.zero,
          dragDirection: seq.observedDragStartDirectionAt(firerIndex),
          dragAxis: axis,
          pointerCount: _pointerCountAfterTerminal,
          originalEvent: event,
        );
      } else {
        firer._fireWithVelocity(
          seq,
          ElEventPhase.dragEnd,
          event.position,
          Velocity.zero,
          Offset.zero,
          dragDirection: seq.observedDragStartDirectionAt(firerIndex),
          dragAxis: axis,
          originalEvent: event,
        );
      }
      _DispatchCycle.flushNow();
      // terminal 的 stopPropagation 只阻止本次冒泡，不能吞掉已经公开 Start
      // 的外层生命周期；剩余义务逐成员直接结清且不再次冒泡。
      for (var i = 0; i < seq.chain.length; i++) {
        final member = seq.chain[i];
        if (!seq.takeOutstandingDragStartFamilyAt(i, family)) continue;
        if (!member._owner.attached) continue;
        final memberAxis = seq.observedDragStartAxisAt(i) ?? familyAxis;
        if (canceled) {
          member._fireWithDelta(
            null,
            ElEventPhase.dragCancel,
            event.position,
            Offset.zero,
            Offset.zero,
            dragDirection: seq.observedDragStartDirectionAt(i),
            dragAxis: memberAxis,
            pointerCount: _pointerCountAfterTerminal,
            originalEvent: event,
            selfOnly: true,
          );
        } else {
          member._fireWithVelocity(
            null,
            ElEventPhase.dragEnd,
            event.position,
            Velocity.zero,
            Offset.zero,
            dragDirection: seq.observedDragStartDirectionAt(i),
            dragAxis: memberAxis,
            originalEvent: event,
            selfOnly: true,
          );
        }
      }
      _DispatchCycle.flushNow();
    }
  }

  /// 当前成员失权或生命周期终止时同步结清 proposal-only DragStart。
  void _cancelOutstandingDragStartsForMember(
    _PointerSequence seq,
    int memberIndex,
    Offset position, {
    Object? originalEvent,
  }) {
    var families = seq.outstandingDragStartFamiliesAt(memberIndex);
    if (families == 0) return;
    final previousImmediate = _terminalFiresImmediate;
    _terminalFiresImmediate = true;
    try {
      while (families != 0) {
        final family = families & -families;
        families &= ~family;
        if (!seq.takeOutstandingDragStartFamilyAt(memberIndex, family)) {
          continue;
        }
        _fireWithDelta(
          null,
          ElEventPhase.dragCancel,
          position,
          Offset.zero,
          Offset.zero,
          dragDirection: seq.observedDragStartDirectionAt(memberIndex),
          dragAxis: seq.observedDragStartAxisAt(memberIndex),
          pointerCount: _pointerCountCurrent,
          originalEvent: originalEvent,
          selfOnly: true,
        );
      }
    } finally {
      _terminalFiresImmediate = previousImmediate;
    }
  }

  /// 当前成员从指定 pointer route 失权：先结清真实 Drag，再补 proposal-only Cancel。
  void _cancelDragForSequenceLoss(
    _PointerSequence seq,
    int memberIndex,
    Offset position, {
    Object? originalEvent,
  }) {
    final drag = _dragMachine;
    if (drag?.isTracking(seq.pointer) == true) {
      if (drag!.hasPointersOtherThan(seq.pointer)) {
        drag.removePointerSilently(seq.pointer);
        final continuation = drag._activeSequence;
        if (continuation != null && !identical(continuation, seq)) {
          seq.transferOutstandingDragStartsForMemberTo(
            this,
            memberIndex,
            continuation,
          );
        }
      } else {
        if (drag._dragStarted && drag._dragStartDispatched) {
          final family = seq.outstandingDragStartFamilyForAxisAt(
            memberIndex,
            drag._acceptedAxis,
          );
          if (family != 0) {
            seq.takeOutstandingDragStartFamilyAt(memberIndex, family);
          }
        }
        drag.cancelForScaleGesture(
          position,
          originalEvent: originalEvent,
          selfOnly: true,
        );
      }
    }
    _cancelOutstandingDragStartsForMember(
      seq,
      memberIndex,
      position,
      originalEvent: originalEvent,
    );
  }

  bool _canPreserveOutstandingDragRoutes(ElEvent event) {
    for (final sequence in _PointerSequenceRegistry.snapshotFor(this)) {
      final memberIndex = sequence.indexOf(this);
      if (memberIndex < 0 ||
          sequence.outstandingDragStartFamiliesAt(memberIndex) == 0) {
        continue;
      }
      final axis = sequence.observedDragStartAxisAt(memberIndex);
      if (!_hasCompleteDragTerminalShape(event, axis)) return false;
    }
    return true;
  }

  static bool _hasCompleteDragTerminalShape(
    ElEvent event,
    Axis? axis,
  ) => switch (axis) {
    Axis.vertical =>
      (event.onVerticalDragEnd != null || event.onDragEnd != null) &&
          (event.onVerticalDragCancel != null || event.onDragCancel != null),
    Axis.horizontal =>
      (event.onHorizontalDragEnd != null || event.onDragEnd != null) &&
          (event.onHorizontalDragCancel != null || event.onDragCancel != null),
    null => event.onDragEnd != null && event.onDragCancel != null,
  };

  void _cancelDragRoutesForLifecycle({
    PointerEvent? event,
    int? expectedGeneration,
  }) {
    final drag = _dragMachine;
    // pipeline 是否活跃必须在序列循环前取：循环里的 self-only 取消会把拖拽机
    // 重置，之后再问就永远是 false，roster 侧的同步通知会丢。
    final pipelineWasActive = drag?._pipeline?.active == true;
    // 先按序列派发（此时拖拽机仍在跟踪指针），再重置 pipeline。顺序反了的话
    // cancelActive 会把拖拽机清空，随后 self-only 判 isTracking 恒为 false，
    // 终态就再也发不出去。
    final sequences = _PointerSequenceRegistry.snapshotFor(this);
    for (final sequence in sequences) {
      // 代际被上面的终态回调顶掉时只停止后续序列，不能整个 return：下面的
      // pipeline 收尾必须照常执行，否则 roster 侧通知会被静默吞掉。
      if (expectedGeneration != null &&
          _configGeneration != expectedGeneration) {
        break;
      }
      if (!identical(_PointerSequenceRegistry.of(sequence.pointer), sequence)) {
        continue;
      }
      final memberIndex = sequence.indexOf(this);
      if (memberIndex < 0) continue;
      _cancelDragForSequenceLoss(
        sequence,
        memberIndex,
        event?.position ?? _lastPointerPosition,
        originalEvent: event,
      );
    }
    if (pipelineWasActive) {
      // DragProxy 是一条复合生命周期：driver 终止时必须沿冻结 route 同步通知
      // roster；普通成员失权仍走上方 self-only，不能误杀并行的祖先机器。
      drag!.cancelActive(event: event, pointerCount: _pointerCountCurrent);
    }
  }

  bool _memberActive(_PointerSequence seq, ElEventDispatcher member) {
    return _memberActiveAt(seq, seq.indexOf(member));
  }

  bool _memberActiveAt(_PointerSequence seq, int index) {
    if (!seq.memberActiveAt(index)) return false;
    return _memberHostLive(seq.chain[index]);
  }

  /// 成员宿主是否可接收本次投递。
  ///
  /// 正常路径要求宿主 attached；终态窗口（销毁 / 真离场结算）例外——那时整条链
  /// 的宿主都已 detach，但 driver 与 roster 必须收到终态，否则在途手势永远收不了
  /// 尾、下一手也接不上（正是"重挂/卸载不得中断拖拽"要求的下半句：真的没了要正确
  /// 取消而不是静默丢弃）。终态坐标会退化为全局值，见 [_terminalCoordinatesUnavailable]。
  static bool _memberHostLive(ElEventDispatcher member) =>
      (member._owner.attached || member._terminalFiresImmediate) &&
      !member.disabled;

  bool _scaleTrackerActive(
    _PointerSequence seq,
    ElEventDispatcher member, [
    int? memberIndex,
  ]) =>
      _memberHostLive(member) &&
      (_memberActiveAt(seq, memberIndex ?? seq.indexOf(member)) ||
          identical(seq.scaleShadowTarget, member) ||
          identical(seq.scaleUpgradeTarget, member));

  /// PointerRemoved（经全局路由）到达时结清本成员状态。
  void _feedRemoved(_PointerSequence seq, PointerRemovedEvent event) {
    _tapMachine?.feedRemoved(event.pointer);
    final memberIndex = seq.indexOf(this);
    if (memberIndex >= 0) {
      _cancelDragForSequenceLoss(
        seq,
        memberIndex,
        event.position,
        originalEvent: event,
      );
    }
    _scaleMachine?.feedRemoved(event.pointer);
    for (final machine in _liveSideMachines) {
      machine.feedRemoved(event.pointer);
    }
    _clearPanZoomState(event.pointer);
  }

  /// 同步结清 eager loser；`seq:null + selfOnly` 让必要终态绕过已失效的 membership，
  /// 普通 queued/raw/semantic 回调仍走门禁。
  void _cancelSequenceForEagerLoss(
    _PointerSequence seq, {
    required int memberIndex,
    Object? originalEvent,
    bool preserveScale = false,
  }) {
    final pointerEvent = originalEvent is PointerEvent ? originalEvent : null;
    final position = pointerEvent?.position ?? _lastPointerPosition;
    final tap = _tapMachine;
    final tapTracksPointer = tap?._pointer == seq.pointer;
    final tapAlreadyCancelled =
        tapTracksPointer && (tap!._canceled || tap._outsideBounds);
    final tapRouteBlocked =
        memberIndex >= seq.chainCutoff || memberIndex >= seq.tapCutoff;
    final participated =
        tapTracksPointer ||
        (_panZoomStarted && _panZoomPointerId == seq.pointer) ||
        seq.wasDownFed(this) ||
        seq.wasDelivered(ElEventPhase.pointerDown, this, memberIndex) ||
        seq.wasDelivered(ElEventPhase.pointerPanZoomStart, this, memberIndex);

    // eager 会终止 loser 的整个 raw pointer 资格，因此先同步补一个合成
    // PointerCancel；后续 Tap/Drag/Scale terminal 按从底层到语义层的顺序结清。
    if (participated &&
        !seq.wasDelivered(ElEventPhase.pointerCancel, this, memberIndex) &&
        _event?.onPointerCancel != null) {
      final cancelEvent = _syntheticPointerCancelEvent(
        seq,
        position,
        originalEvent,
      );
      _fire(
        null,
        ElEventPhase.pointerCancel,
        position,
        cancelReason: ElEventCancelReason.otherGestureAccepted,
        originalEvent: cancelEvent,
        pointerCount: _activeSequenceCount > 0 ? _activeSequenceCount - 1 : 0,
        selfOnly: true,
      );
    }

    // 只有真正建立过 Tap 候选的 loser 才补 TapCancel；raw-only 宿主已经由
    // 上面的 PointerCancel 收尾，不能制造没有 TapDown 的孤立 TapCancel。
    if (tapTracksPointer &&
        !tapRouteBlocked &&
        !tapAlreadyCancelled &&
        !seq.wasDelivered(ElEventPhase.tapCancel, this, memberIndex) &&
        _event?.onTapCancel != null) {
      _fire(
        null,
        ElEventPhase.tapCancel,
        position,
        cancelReason: ElEventCancelReason.otherGestureAccepted,
        originalEvent: originalEvent,
        selfOnly: true,
      );
    }
    if (participated) {
      tap?._clearDeferredTap();
      tap?.resetConsecutiveWindow();
    }
    if (tapTracksPointer) tap!.cancelSilently();
    _cancelDragForSequenceLoss(
      seq,
      memberIndex,
      position,
      originalEvent: originalEvent,
    );
    if (!preserveScale) {
      if (identical(seq.scaleUpgradeTarget, this)) {
        seq.scaleUpgradeTarget = null;
      }
      final scale = _scaleMachine;
      if (scale?._positions.containsKey(seq.pointer) == true) {
        if (scale!._positions.length == 1 && scale.started) {
          _cancelActiveScale(originalEvent: pointerEvent, selfOnly: true);
        } else {
          scale.feedRemoved(seq.pointer);
        }
      }
    }
    for (final machine in _liveSideMachines) {
      machine.feedRemoved(seq.pointer);
    }
    _clearPanZoomState(seq.pointer);
  }

  /// 为 eager loser 构造可被 `onPointerCancel` 安全识别的原始终态事件。
  static PointerCancelEvent _syntheticPointerCancelEvent(
    _PointerSequence seq,
    Offset position,
    Object? originalEvent,
  ) {
    final source = originalEvent is PointerEvent
        ? originalEvent
        : seq.canonicalDown;
    final kind = source?.kind ?? seq.kind;
    return PointerCancelEvent(
      viewId: source?.viewId ?? 0,
      timeStamp: source?.timeStamp ?? Duration.zero,
      pointer: seq.pointer,
      kind: kind == PointerDeviceKind.trackpad
          ? PointerDeviceKind.unknown
          : kind,
      device: source?.device ?? seq.device,
      position: position,
      buttons: source?.buttons ?? 0,
      obscured: source?.obscured ?? false,
    );
  }

  // ---------------------------------------------------------------------------
  // 序列级压制（stopPropagation 链截断 / eager 失权时由 _PointerSequence 调用）
  // ---------------------------------------------------------------------------

  void _suppressSequenceSilently(_PointerSequence seq) {
    final tap = _tapMachine;
    if (tap != null && tap._pointer == seq.pointer) tap.cancelSilently();
    _dragMachine?.removePointerSilently(seq.pointer);
    if (identical(seq.scaleUpgradeTarget, this)) seq.scaleUpgradeTarget = null;
    _scaleMachine?.feedRemoved(seq.pointer);
    for (final machine in _liveSideMachines) {
      machine.feedRemoved(seq.pointer);
    }
    _clearPanZoomState(seq.pointer);
  }

  void _suppressPrimaryGestureSilently(_PointerSequence seq) {
    final tap = _tapMachine;
    if (tap != null && tap._pointer == seq.pointer) tap.cancelSilently();
    _dragMachine?.removePointerSilently(seq.pointer);
  }

  void _suppressTapChain(_PointerSequence seq) {
    final tap = _tapMachine;
    if (tap != null && tap._pointer == seq.pointer && !tap._canceled) {
      tap._canceled = true;
      tap._clearDeferredTap();
    }
  }

  void _suppressDragSilently(_PointerSequence seq) =>
      _dragMachine?.removePointerSilently(seq.pointer);

  /// 收集链快照：self + 向上全部注册且未禁用的 dispatcher（内→外）。
  List<ElEventDispatcher> _collectChain() {
    final chain = <ElEventDispatcher>[this];
    RenderObject? current = _owner.parent;
    while (current != null) {
      if (current is RenderBox) {
        final dispatcher = ElEventDispatcher.of(current);
        if (dispatcher != null &&
            !dispatcher.disabled &&
            !identical(dispatcher, this)) {
          chain.add(dispatcher);
        }
      }
      current = current.parent;
    }
    return chain;
  }

  // ===========================================================================
  // 原始事件投递（同步——其 stopPropagation 决定后续状态机喂送范围）
  // ===========================================================================

  void _deliverRaw(
    _PointerSequence seq,
    ElEventPhase phase,
    PointerEvent event, {
    Offset? globalPosition,
  }) {
    // 无订阅者时零分配快速返回。
    var anySubscriber = false;
    for (var i = 0; i < seq.chain.length; i++) {
      final member = seq.chain[i];
      if (_memberActiveAt(seq, i) && member._handlerFor(phase) != null) {
        anySubscriber = true;
        break;
      }
    }
    if (!anySubscriber) return;

    final delta = switch (event) {
      PointerScrollEvent(:final scrollDelta) => scrollDelta,
      PointerPanZoomUpdateEvent(:final panDelta) => panDelta,
      _ => event.delta,
    };
    final (scale, rotation) = switch (event) {
      PointerPanZoomUpdateEvent(:final scale, :final rotation) => (
        scale,
        rotation,
      ),
      _ => (1.0, 0.0),
    };
    final callback = ElEventCallback(
      phase: phase,
      globalPosition: globalPosition ?? event.position,
      localPosition: Offset.zero,
      // 每成员投递前重写
      delta: delta,
      localDelta: Offset.zero,
      scale: scale,
      rotation: rotation,
      pointerCount: switch (phase) {
        ElEventPhase.pointerDown => _pointerCountCurrent,
        ElEventPhase.pointerUp ||
        ElEventPhase.pointerCancel => _pointerCountAfterTerminal,
        _ => 0,
      },
      buttons: event.buttons,
      originalEvent: event,
    );
    final eager = seq.eagerMember;
    final startIndex = eager == null ? 0 : seq.indexOf(eager);
    // winner 已离场时 eagerMember 作为墓碑保留，整条旧链都不得复活。
    if (startIndex < 0) return;
    _deliverAlongSequenceChain(
      seq,
      phase,
      callback,
      startIndex: startIndex,
      resolvedFirerHandler: null,
      liveResolve: true,
      // delta 取自 event.delta 的形态才可直采 localDelta（panZoomUpdate 的
      // panDelta / scroll 的 scrollDelta 与 event.localDelta 不对应）。
      localizedEvent:
          event is PointerPanZoomUpdateEvent || event is PointerScrollEvent
          ? null
          : event,
    );
  }

  // ===========================================================================
  // 语义事件 fire（enqueue，flush 时投递）
  // ===========================================================================

  void _enqueue(
    _PointerSequence? seq,
    ElEventPhase phase,
    ElEventCallback callback, {
    bool selfOnly = false,
    void Function()? onDropped,
  }) {
    // 仅 dragStart / dragUpdate 携带管线快照，dragEnd / dragCancel 走冒泡链
    // 直达 roster 成员的 onDragEnd / onDragCancel（生命周期信号）。
    final pipelineSnapshot =
        (phase == ElEventPhase.dragStart || phase == ElEventPhase.dragUpdate)
        ? _pipelineSnapshotForFire()
        : null;
    // dragStart / dragUpdate 快照祖先拖拽消费者存在性：滚动 driver 据此区分
    // "顶层"和"内嵌"，避免 defer 给空气造成顶层反向回拖不响应（缺陷 2 修复）。
    // 按胜出轴过滤：交叉轴祖先接不了本轴 delta，不算消费者。
    final firerIndex = seq?.indexOf(this) ?? -1;
    if (phase == ElEventPhase.dragStart || phase == ElEventPhase.dragUpdate) {
      callback.hasAncestorDragConsumer = _computeHasAncestorDragConsumer(
        seq,
        callback.dragAxis,
        firerIndex,
      );
    }
    final delivery = _QueuedDelivery(
      firer: this,
      phase: phase,
      callback: callback,
      seq: seq,
      firerIndex: firerIndex,
      selfOnly: selfOnly,
      handler: _handlerFor(phase, callback.dragAxis),
      generation: _configGeneration,
      config: _event,
      pipeline: pipelineSnapshot,
      onDropped: onDropped,
    );
    if (_terminalFiresImmediate) {
      delivery.deliver();
      return;
    }
    _DispatchCycle.enqueue(delivery);
  }

  /// 返回本 dispatcher 当前作为 driver 挂载的管线（若活跃）。
  _DragPipeline? _pipelineSnapshotForFire() {
    final pipeline = _dragMachine?._pipeline;
    return pipeline != null && pipeline.active ? pipeline : null;
  }

  /// 沿 [seq] 的链，从 firer（本 dispatcher）向外索引，判断是否存在能接手
  /// dragStart / dragUpdate 的祖先消费者。
  ///
  /// 判定：[_memberConsumesDragAxis]（**同轴**回调组或自由拖拽组）且
  /// `_memberActive(member)`，并同时位于 DragProxy 的内部协调边界与当前
  /// Drag route 内。
  ///
  /// 轴过滤防交叉轴误让渡（2026-08-09 缺陷修复）：横向滚动到边界不得 defer
  /// 给只会垂直滚的外层——垂直组接不了横向 delta，让渡即整手势失灵（连反向
  /// 回拖都死）且手势被外层垂直滚动捡走。边界代理只发生在同轴嵌套；外层无
  /// 同轴消费者时余量归自己（scroll drag controller 的顶层分支：吞余量 +
  /// overscroll 指示，下一帧继续尝试消费）。
  bool _computeHasAncestorDragConsumer(
    _PointerSequence? seq,
    Axis? dragAxis,
    int self,
  ) {
    if (seq == null) return false;
    if (self < 0) return false;
    var limit = seq.chain.length;
    if (seq.primaryGestureCutoff < limit) limit = seq.primaryGestureCutoff;
    if (seq.dragRouteCutoff < limit) limit = seq.dragRouteCutoff;
    for (var i = self + 1; i < limit; i++) {
      final member = seq.chain[i];
      if (!_memberActiveAt(seq, i)) continue;
      if (_memberConsumesDragAxis(member, dragAxis)) return true;
    }
    return false;
  }

  /// [member] 是否声明了能消费 [axis] 轴拖拽 delta 的回调组。
  ///
  /// 轴向手势（滚动 driver 锁轴后）只认**同轴**组与自由拖拽组（onDrag* 是
  /// 2D 语义、两轴都吃）；交叉轴组不算——垂直滚动接不了横向 delta。自由
  /// 拖拽手势（axis == null）任意组都算。
  static bool _memberConsumesDragAxis(ElEventDispatcher member, Axis? axis) {
    final event = member._event;
    return switch (axis) {
      Axis.vertical => _hasVerticalDragShape(event) || _hasFreeDragShape(event),
      Axis.horizontal =>
        _hasHorizontalDragShape(event) || _hasFreeDragShape(event),
      null => member._hasDragShape(event),
    };
  }

  ElEventCallback? _fire(
    _PointerSequence? seq,
    ElEventPhase phase,
    Offset globalPosition, {
    Offset? localPosition,
    Object? originalEvent,
    ElEventCancelReason? cancelReason,
    int pointerCount = 0,
    int? buttonsOverride,
    bool selfOnly = false,
  }) {
    if (!_owner.attached) return null;
    final buttons =
        buttonsOverride ??
        (originalEvent is PointerEvent ? originalEvent.buttons : 0);
    final coordinatesUnavailable = _terminalCoordinatesUnavailable(_owner);
    final callback = ElEventCallback(
      phase: phase,
      globalPosition: globalPosition,
      localPosition:
          localPosition ??
          (coordinatesUnavailable
              ? globalPosition
              : _localPositionFor(_owner, globalPosition)),
      tapCount: _tapCountFor(phase),
      pointerCount: pointerCount,
      buttons: buttons,
      cancelReason: cancelReason,
      originalEvent: originalEvent,
    );
    _enqueue(seq, phase, callback, selfOnly: selfOnly);
    return callback;
  }

  /// 按 phase 推导 [ElEventCallback.tapCount]，对齐 CSS `click.detail`。
  static int _tapCountFor(ElEventPhase phase) {
    return switch (phase) {
      ElEventPhase.tap ||
      ElEventPhase.secondaryTap ||
      ElEventPhase.tertiaryTap ||
      ElEventPhase.forwardTap ||
      ElEventPhase.backTap => 1,
      ElEventPhase.doubleTap || ElEventPhase.doubleTapDown => 2,
      ElEventPhase.tripleTap || ElEventPhase.tripleTapDown => 3,
      _ => 0,
    };
  }

  /// 在本成员接受 Drag 前，把 Start 提案同步送给命中链中更近的后代。
  ///
  /// 后代仅因声明 handler 不会保留或抢占 Drag；只有在回调中真实调用
  /// stopPropagation / eagerGesture 才能截断发起者。已执行过 Start 的成员
  /// 跨 cycle 跳过，保证同一 pointer 序列每个 handler 只收到一次 Start。
  bool _routeDragStartProposal(
    _PointerSequence seq,
    PointerEvent event,
    AxisDirection direction, {
    Axis? dragAxis,
    bool dragPipelineActive = false,
  }) {
    final initiatorIndex = seq.indexOf(this);
    if (initiatorIndex < 0 || !_memberActiveAt(seq, initiatorIndex)) {
      return false;
    }
    if (seq.blockedAt(ElEventPhase.dragStart, initiatorIndex)) return false;
    if (initiatorIndex == 0 || seq.hasAnyObservedDragStartRoute(this)) {
      return true;
    }

    final callback =
        ElEventCallback(
            phase: ElEventPhase.dragStart,
            globalPosition: event.position,
            localPosition: Offset.zero,
            delta: Offset.zero,
            localDelta: Offset.zero,
            remainingDelta: Offset.zero,
            remainingLocalDelta: Offset.zero,
            dragOffset: Offset.zero,
            dragDirection: direction,
            dragAxis: dragAxis,
            pointerCount: _pointerCountCurrent,
            buttons: event.buttons,
            originalEvent: event,
          )
          ..hasAncestorDragConsumer = _computeHasAncestorDragConsumer(
            seq,
            dragAxis,
            0,
          )
          ..dragPipelineActive = dragPipelineActive;
    _deliverAlongSequenceChain(
      seq,
      ElEventPhase.dragStart,
      callback,
      startIndex: 0,
      endIndexExclusive: initiatorIndex,
      resolvedFirerHandler: null,
      liveResolve: true,
    );
    return _memberActiveAt(seq, initiatorIndex) &&
        !seq.blockedAt(ElEventPhase.dragStart, initiatorIndex);
  }

  void _fireDragStart(
    _PointerSequence? seq,
    PointerEvent event,
    Offset delta,
    Offset dragOffset,
    AxisDirection direction, {
    Axis? dragAxis,
    bool dragPipelineActive = false,
    int? endIndexExclusive,
  }) {
    if (!_canFire) return;

    final localDelta = _localDeltaFor(_owner, event.position, delta);
    final remainingLocalDelta = _localDeltaFor(
      _owner,
      event.position,
      dragOffset,
    );
    final callback = ElEventCallback(
      phase: ElEventPhase.dragStart,
      globalPosition: event.position,
      localPosition: _localPositionFor(_owner, event.position),
      delta: delta,
      localDelta: localDelta,
      remainingDelta: dragOffset,
      remainingLocalDelta: remainingLocalDelta,
      dragOffset: dragOffset,
      dragDirection: direction,
      dragAxis: dragAxis,
      pointerCount: _pointerCountCurrent,
      buttons: event.buttons,
      originalEvent: event,
    )..dragPipelineActive = dragPipelineActive;
    // resolver 不在 fire 侧预置：所有投递路径在任何 handler 运行前都会
    // retarget 重设（updateLocalDeltaResolver 会 eager 重算 remainingLocalDelta，
    // 预置结果零消费者，白付 2 次 O(depth) globalToLocal + 闭包）。
    if (seq == null) {
      _enqueue(null, ElEventPhase.dragStart, callback);
      return;
    }
    final startIndex = seq.indexOf(this);
    if (startIndex < 0) return;
    callback.hasAncestorDragConsumer = _computeHasAncestorDragConsumer(
      seq,
      dragAxis,
      startIndex,
    );
    // Start 是路由裁决点：必须在返回前让 stop/eager 生效，后续才能安全决定
    // 是否组成 DragProxy。直接投递也能在分发队列重入期间保持同步语义。
    _deliverAlongSequenceChain(
      seq,
      ElEventPhase.dragStart,
      callback,
      startIndex: startIndex,
      endIndexExclusive: endIndexExclusive,
      resolvedFirerHandler: _handlerFor(ElEventPhase.dragStart, dragAxis),
      liveResolve: false,
      startMemberValidated: true,
    );
  }

  void _fireWithDelta(
    _PointerSequence? seq,
    ElEventPhase phase,
    Offset globalPosition,
    Offset delta,
    Offset dragOffset, {
    AxisDirection? dragDirection,
    Axis? dragAxis,
    int pointerCount = _pointerCountCurrent,
    Object? originalEvent,
    Duration? sampleTimeStamp,
    bool selfOnly = false,
  }) {
    if (!_canFire) return;
    final coordinatesUnavailable = _terminalCoordinatesUnavailable(_owner);
    final localDelta = coordinatesUnavailable
        ? delta
        : _localDeltaFor(_owner, globalPosition, delta);
    final callback = ElEventCallback(
      phase: phase,
      globalPosition: globalPosition,
      localPosition: coordinatesUnavailable
          ? globalPosition
          : _localPositionFor(_owner, globalPosition),
      delta: delta,
      localDelta: localDelta,
      dragOffset: dragOffset,
      dragDirection: dragDirection,
      dragAxis: dragAxis,
      pointerCount: pointerCount,
      buttons: _buttonsFromOriginalEvent(originalEvent),
      originalEvent: originalEvent,
      sampleTimeStamp: sampleTimeStamp,
    );
    // resolver 不在 fire 侧预置（同 _fireDragStart：投递侧必然重设，预置是白付）。
    // dragUpdate 是高频 self-only phase：不向祖先投递（嵌套滚动走 scroll-chain）。
    _enqueue(
      seq,
      phase,
      callback,
      selfOnly: selfOnly || phase == ElEventPhase.dragUpdate,
    );
  }

  void _fireWithVelocity(
    _PointerSequence? seq,
    ElEventPhase phase,
    Offset globalPosition,
    Velocity velocity,
    Offset dragOffset, {
    AxisDirection? dragDirection,
    Axis? dragAxis,
    double logScaleVelocity = 0.0,
    Object? originalEvent,
    bool selfOnly = false,
  }) {
    if (!_canFire) return;
    final coordinatesUnavailable = _terminalCoordinatesUnavailable(_owner);
    final primaryVelocity = phase == ElEventPhase.dragEnd
        ? _primaryDragVelocity(velocity, dragAxis)
        : null;
    final callback = ElEventCallback(
      phase: phase,
      globalPosition: globalPosition,
      localPosition: coordinatesUnavailable
          ? globalPosition
          : _localPositionFor(_owner, globalPosition),
      velocity: velocity,
      primaryVelocity: primaryVelocity,
      dragOffset: dragOffset,
      dragDirection: dragDirection,
      dragAxis: dragAxis,
      logScaleVelocity: logScaleVelocity,
      buttons: _buttonsFromOriginalEvent(originalEvent),
      originalEvent: originalEvent,
    );
    _enqueue(seq, phase, callback, selfOnly: selfOnly);
  }

  /// 拖拽结束主轴速度：按本次手势的**胜出轴**取分量，自由拖拽为 null。
  double? _primaryDragVelocity(Velocity velocity, Axis? dragAxis) {
    return switch (dragAxis) {
      Axis.vertical => velocity.pixelsPerSecond.dy,
      Axis.horizontal => velocity.pixelsPerSecond.dx,
      null => null,
    };
  }

  int _buttonsFromOriginalEvent(Object? originalEvent) {
    return originalEvent is PointerEvent ? originalEvent.buttons : 0;
  }

  void _fireDragCancel(
    _PointerSequence? seq,
    PointerCancelEvent event, {
    required Offset dragOffset,
    AxisDirection? dragDirection,
    Axis? dragAxis,
  }) {
    if (!_canFire) return;
    final coordinatesUnavailable = _terminalCoordinatesUnavailable(_owner);
    final callback = ElEventCallback(
      phase: ElEventPhase.dragCancel,
      globalPosition: event.position,
      localPosition: coordinatesUnavailable
          ? event.position
          : _localPositionFor(_owner, event.position),
      dragOffset: dragOffset,
      dragDirection: dragDirection,
      dragAxis: dragAxis,
      pointerCount: _pointerCountAfterTerminal,
      buttons: event.buttons,
      originalEvent: event,
    );
    _enqueue(seq, ElEventPhase.dragCancel, callback);
  }

  void _fireWithScale(
    _PointerSequence? seq,
    ElEventPhase phase,
    Offset globalPosition,
    double scale,
    double rotation, {
    Offset delta = Offset.zero,
    int pointerCount = 0,
    Object? originalEvent,
    bool selfOnly = false,
  }) {
    if (!_canFire) return;
    final coordinatesUnavailable = _terminalCoordinatesUnavailable(_owner);
    final localPosition = coordinatesUnavailable
        ? globalPosition
        : _localPositionFor(_owner, globalPosition);
    final localDelta = delta == Offset.zero
        ? Offset.zero
        : localPosition -
              (coordinatesUnavailable
                  ? globalPosition - delta
                  : _localPositionFor(_owner, globalPosition - delta));
    final callback = ElEventCallback(
      phase: phase,
      globalPosition: globalPosition,
      localPosition: localPosition,
      delta: delta,
      localDelta: localDelta,
      scale: scale,
      rotation: rotation,
      pointerCount: pointerCount,
      buttons: _buttonsFromOriginalEvent(originalEvent),
      originalEvent: originalEvent,
    );
    _enqueue(seq, phase, callback, selfOnly: selfOnly);
  }

  // ===========================================================================
  // 投递引擎
  // ===========================================================================

  /// flush 阶段执行入队的语义事件投递。
  void _deliverQueued(_QueuedDelivery q) {
    final seq = q.seq;
    final isDragTerminal =
        q.phase == ElEventPhase.dragEnd || q.phase == ElEventPhase.dragCancel;
    if (seq != null && isDragTerminal) {
      _deliverAlongSequenceChain(
        seq,
        q.phase,
        q.callback,
        startIndex: 0,
        terminalFirerIndex: q.firerIndex,
        resolvedFirerHandler: null,
        liveResolve: true,
      );
      return;
    }
    final pipeline = q.pipeline;
    if (pipeline != null && pipeline.active && seq != null) {
      _deliverWithPipeline(q, seq, pipeline);
      return;
    }
    if (seq == null) {
      _deliverAlongLiveChain(
        q.phase,
        q.callback,
        resolvedFirerHandler: q.effectiveHandler,
        selfOnly: q.selfOnly,
      );
      return;
    }
    final startIndex = q.firerIndex;
    if (startIndex < 0) return;
    _deliverAlongSequenceChain(
      seq,
      q.phase,
      q.callback,
      startIndex: startIndex,
      resolvedFirerHandler: q.effectiveHandler,
      liveResolve: false,
      selfOnly: q.selfOnly,
      startMemberValidated: true,
    );
  }

  /// 三段管线包装：pre（外→内）→ 主段 → overflow（内→外）。
  ///
  /// 余量按 driver 轴投影为 0 时短路的只有 pre / overflow **记账阶段**；
  /// 主段是语义投递而非记账阶段，**无条件执行**——dragStart / dragUpdate
  /// 对 driver 与冒泡链是手势生命周期与消费入口（滚动的 hold/drag 建立、
  /// roster 成员的 dragStart/dragEnd 配对都依赖它），即使 pre 已把余量扣到
  /// 0 也必须照常送达。
  ///
  /// 阶段内每成员：`_retargetCallback` 换算本地坐标/增量 → 装 no-op eager
  /// handler（防护）→ 调 proxy handler → 复位 propagationStopped。
  void _deliverWithPipeline(
    _QueuedDelivery q,
    _PointerSequence seq,
    _DragPipeline pipeline,
  ) {
    final callback = q.callback;
    final pointerCountMode = callback.pointerCount;
    final startIndex = q.firerIndex;
    if (startIndex < 0) return;
    callback.dragPipelineActive = true;
    try {
      _runPipelineStage(pipeline, seq, callback, pre: true);
      callback.pointerCount = pointerCountMode;
      _deliverAlongSequenceChain(
        seq,
        q.phase,
        callback,
        startIndex: startIndex,
        resolvedFirerHandler: q.effectiveHandler,
        liveResolve: false,
        selfOnly: q.selfOnly,
      );
      if (!_pipelineDeltaExhausted(callback, pipeline.axis)) {
        callback.pointerCount = pointerCountMode;
        _runPipelineStage(pipeline, seq, callback, pre: false);
      }
    } finally {
      if (pointerCountMode < 0) {
        callback.pointerCount = _resolvePointerCount(
          pointerCountMode,
          this,
          seq,
        );
      }
      callback.dragPipelineActive = false;
    }
  }

  void _runPipelineStage(
    _DragPipeline pipeline,
    _PointerSequence seq,
    ElEventCallback callback, {
    required bool pre,
  }) {
    final pointerCountMode = callback.pointerCount;
    // pre 阶段：外→内（roster 是内→外，反向）；overflow 阶段：内→外。
    final members = pre ? pipeline.roster.reversed : pipeline.roster;
    for (final member in members) {
      if (!pipeline.active) return;
      final memberIndex = seq.indexOf(member);
      if (!_memberActiveAt(seq, memberIndex)) continue;
      if (seq.blockedAt(callback.phase, memberIndex)) continue;
      if (!identical(member._passiveDragPipeline, pipeline)) continue;
      if (!member._owner.attached) continue;
      final proxy = member._event?.dragProxy;
      final handler = pre ? proxy?.onDragPreUpdate : proxy?.onDragOverflow;
      if (handler == null) continue;
      if (_pipelineDeltaExhausted(callback, pipeline.axis)) return;
      if (pointerCountMode < 0) {
        callback.pointerCount = _resolvePointerCount(
          pointerCountMode,
          member,
          seq,
        );
      }
      _retargetCallback(callback, member, seq, memberIndex);
      // 防护：proxy handler 内禁用 stopPropagation / eagerGesture——
      // eager 注入 no-op；调用后复位 propagationStopped（两者的副作用都
      // 清掉，防止误伤后续阶段与冒泡链）。
      callback.updateEagerGestureHandler(_noopEagerGesture);
      callback.markCallbackInvoked();
      handler(callback);
      callback.resetPropagation();
    }
  }

  static void _noopEagerGesture(
    ElEventCallback callback,
    bool cancelSelfTap,
    bool allowScaleUpgrade,
  ) {}

  bool _pipelineDeltaExhausted(ElEventCallback callback, Axis? axis) {
    if (axis == null) return callback.remainingDelta == Offset.zero;
    return callback.remainingPrimaryDelta(axis) == 0.0;
  }

  static int _resolvePointerCount(
    int mode,
    ElEventDispatcher member,
    _PointerSequence? seq,
  ) {
    var count = member._activeSequenceCount;
    final current = seq == null
        ? null
        : _PointerSequenceRegistry.of(seq.pointer);
    if (mode == _pointerCountAfterTerminal &&
        seq != null &&
        _continuesPointerSequence(current, seq) &&
        current!.contains(member)) {
      count--;
    }
    return count < 0 ? 0 : count;
  }

  static bool _continuesPointerSequence(
    _PointerSequence? current,
    _PointerSequence previous,
  ) =>
      current != null &&
      (identical(current, previous) ||
          (previous.canonicalDown != null &&
              identical(current.canonicalDown, previous.canonicalDown)));

  /// 沿序列链从 [startIndex] 向外投递。
  ///
  /// [liveResolve] 为 true 时所有成员的 handler 在投递时解析（原始事件投递）；
  /// 为 false 时触发成员使用 enqueue 时捕获的 [resolvedFirerHandler]（对齐旧
  /// 实现"fire 即同步解析"的时序），链上成员仍实时解析。
  void _deliverAlongSequenceChain(
    _PointerSequence seq,
    ElEventPhase phase,
    ElEventCallback callback, {
    required int startIndex,
    int? endIndexExclusive,
    int? terminalFirerIndex,
    required ElEventHandler? resolvedFirerHandler,
    required bool liveResolve,
    bool selfOnly = false,
    PointerEvent? localizedEvent,
    bool startMemberValidated = false,
  }) {
    final pointerCountMode = callback.pointerCount;
    final end = endIndexExclusive ?? seq.chain.length;
    final isDragTerminal =
        phase == ElEventPhase.dragEnd || phase == ElEventPhase.dragCancel;
    for (var i = startIndex; i < end; i++) {
      final member = seq.chain[i];
      if (isDragTerminal) {
        final observed = seq.hasAnyObservedDragStartRoute(member);
        final outstanding = seq.hasOutstandingDragStartRoute(
          member,
          callback.dragAxis,
        );
        if ((observed && !outstanding) ||
            (!observed && i < (terminalFirerIndex ?? startIndex))) {
          continue;
        }
      }
      if (!(startMemberValidated && i == startIndex) &&
          !_memberActiveAt(seq, i)) {
        if (seq.eagerMember != null) break;
        if (selfOnly) break;
        continue;
      }
      if (seq.blockedAt(phase, i)) {
        if (i == startIndex) return; // 触发者自身被家族截断
        break;
      }
      final isFirerSlot = i == startIndex && !liveResolve;
      if (isFirerSlot && seq.wasDelivered(phase, member, i)) {
        // 更内层成员本平台事件已 fire 过同 phase 并冒泡送达此处：本成员自机
        // 的重复 fire 整体抑制。去重是单向的——冒泡压制祖先自机，祖先先 fire
        // 不阻止其后代 fire 的冒泡再次送达（对齐旧 _suppressedByDescendant）。
        return;
      }
      if (!_memberHostLive(member)) {
        if (selfOnly) break;
        continue;
      }
      final handler = isFirerSlot
          ? resolvedFirerHandler
          : member._handlerFor(phase, callback.dragAxis);
      if (isDragTerminal) {
        seq.takeOutstandingDragStartRoute(member, callback.dragAxis);
      }
      if (handler != null) {
        if (phase == ElEventPhase.dragStart &&
            seq.hasAnyObservedDragStartRoute(member)) {
          if (selfOnly) break;
          continue;
        }
        if (!seq.markDelivered(phase, member, i)) {
          if (selfOnly) break;
          continue;
        }
        if (pointerCountMode < 0) {
          callback.pointerCount = _resolvePointerCount(
            pointerCountMode,
            member,
            seq,
          );
        }
        // 触发者自身的语义事件（!liveResolve）在 fire 时已算好 localPosition
        // （延迟 tap 等场景显式携带释放点坐标），不再重写；链上成员逐跳重写。
        if (liveResolve || i != startIndex) {
          // 本 dispatcher 即事件的 hit-test 变换目标：localPosition 直采。
          if (localizedEvent != null && identical(member, this)) {
            _adoptLocalFromEvent(callback, localizedEvent);
            _retargetResolversOnly(callback, member, seq, i);
          } else {
            _retargetCallback(callback, member, seq, i);
          }
        } else {
          _retargetResolversOnly(callback, member, seq, i);
        }
        callback.markCallbackInvoked();
        if (phase == ElEventPhase.dragStart) {
          seq.markDragStartRouteObserved(
            member,
            callback.dragAxis,
            callback.dragDirection,
            i,
          );
        }
        handler(callback);
        if (liveResolve &&
            (phase == ElEventPhase.pointerUp ||
                phase == ElEventPhase.pointerCancel)) {
          final current = _PointerSequenceRegistry.of(seq.pointer);
          if (!identical(current, seq) &&
              _continuesPointerSequence(current, seq)) {
            current!.markDelivered(phase, member);
          }
        }
        if (callback.propagationStopped) {
          if (phase == ElEventPhase.dragStart) {
            for (
              var outerIndex = i + 1;
              outerIndex < seq.chain.length;
              outerIndex++
            ) {
              final outer = seq.chain[outerIndex];
              outer._cancelDragForSequenceLoss(
                seq,
                outerIndex,
                callback.globalPosition,
                originalEvent: callback.originalEvent,
              );
            }
          }
          seq.applyStopPropagation(phase, i);
          break;
        }
      }
      if (selfOnly) break;
    }
  }

  /// 无序列上下文（延迟 tap/debug 注入）的投递：self + 实时父链游走。
  void _deliverAlongLiveChain(
    ElEventPhase phase,
    ElEventCallback callback, {
    required ElEventHandler? resolvedFirerHandler,
    bool selfOnly = false,
  }) {
    final pointerCountMode = callback.pointerCount;
    if (_owner.attached) {
      final handler = resolvedFirerHandler;
      if (handler != null) {
        if (pointerCountMode < 0) {
          callback.pointerCount = _resolvePointerCount(
            pointerCountMode,
            this,
            null,
          );
        }
        // 触发者的 localPosition 在 fire 时已算好（延迟 tap 携带
        // 各自语义的坐标），只刷新增量换算器与 eager 注入。
        _retargetResolversOnly(callback, this, null);
        callback.markCallbackInvoked();
        handler(callback);
      }
    }
    if (selfOnly ||
        callback.propagationStopped ||
        phase == ElEventPhase.longPress) {
      return;
    }
    RenderObject? current = _owner.parent;
    while (current != null) {
      if (current is RenderBox) {
        final member = ElEventDispatcher.of(current);
        if (member != null &&
            !member.disabled &&
            member._event != null &&
            member._owner.attached) {
          final handler = member._handlerFor(phase, callback.dragAxis);
          if (handler != null) {
            if (pointerCountMode < 0) {
              callback.pointerCount = _resolvePointerCount(
                pointerCountMode,
                member,
                null,
              );
            }
            _retargetCallback(callback, member, null);
            callback.markCallbackInvoked();
            handler(callback);
            if (callback.propagationStopped) return;
          }
        }
      }
      current = current.parent;
    }
  }

  void _retargetCallback(
    ElEventCallback callback,
    ElEventDispatcher member,
    _PointerSequence? seq, [
    int? memberIndex,
  ]) {
    final target = member._owner;
    if (!_terminalCoordinatesUnavailable(target)) {
      callback.localPosition = _localPositionFor(
        target,
        callback.globalPosition,
      );
      if (callback.delta != Offset.zero) {
        callback.localDelta = _localDeltaFor(
          target,
          callback.globalPosition,
          callback.delta,
        );
      }
    }
    _retargetResolversOnly(callback, member, seq, memberIndex);
  }

  void _retargetResolversOnly(
    ElEventCallback callback,
    ElEventDispatcher member,
    _PointerSequence? seq, [
    int? memberIndex,
  ]) {
    final target = member._owner;
    if (!_terminalCoordinatesUnavailable(target)) {
      callback.updateLocalDeltaResolver(
        (globalDelta) =>
            _localDeltaFor(target, callback.globalPosition, globalDelta),
      );
    }
    if (callback.phase == ElEventPhase.pointerCancel ||
        callback.phase == ElEventPhase.tapCancel ||
        callback.phase == ElEventPhase.dragCancel ||
        callback.phase == ElEventPhase.scaleCancel) {
      callback.updateEagerGestureHandler(_noopEagerGesture);
      return;
    }
    callback.updateEagerGestureHandler((
      eagerCallback,
      cancelSelfTap,
      allowScaleUpgrade,
    ) {
      // 只有当前投递明确携带活跃序列时才允许认领；hover/signal、
      // terminal cancel 与孤立 pointer 回调不能靠偶然复用的 pointer id 抢序列。
      if (seq == null) return;
      final index = memberIndex ?? seq.indexOf(member);
      if (!_memberActiveAt(seq, index)) return;
      // 同一 handler 先 stop 再 eager 时必须保持调用顺序：先落家族边界，
      // 再结算 eager loser，避免已被 TapDown/DragDown 截断的祖先收到 Cancel。
      if (eagerCallback.propagationStopped) {
        seq.applyStopPropagation(eagerCallback.phase, index);
      }
      seq.claimEager(
        member,
        memberIndex: index,
        cancelSelfTap: cancelSelfTap,
        allowScaleUpgrade: allowScaleUpgrade,
        originalEvent: eagerCallback.originalEvent,
      );
    });
  }

  ElEventHandler? _handlerFor(ElEventPhase phase, [Axis? dragAxis]) {
    final event = _event;
    if (event == null) return null;
    return switch (phase) {
      ElEventPhase.pointerEnter => event.onPointerEnter,
      ElEventPhase.pointerHover => event.onPointerHover,
      ElEventPhase.pointerExit => event.onPointerExit,
      ElEventPhase.pointerDown => event.onPointerDown,
      ElEventPhase.pointerMove => event.onPointerMove,
      ElEventPhase.pointerUp => event.onPointerUp,
      ElEventPhase.pointerCancel => event.onPointerCancel,
      ElEventPhase.pointerPanZoomStart => event.onPointerPanZoomStart,
      ElEventPhase.pointerPanZoomUpdate => event.onPointerPanZoomUpdate,
      ElEventPhase.pointerPanZoomEnd => event.onPointerPanZoomEnd,
      ElEventPhase.pointerSignal => event.onPointerSignal,
      ElEventPhase.tapDown => event.onTapDown,
      ElEventPhase.tapUp => event.onTapUp,
      ElEventPhase.tap => event.onTap,
      ElEventPhase.doubleTap => event.onDoubleTap,
      ElEventPhase.doubleTapDown => event.onDoubleTapDown,
      ElEventPhase.tripleTap => event.onTripleTap,
      ElEventPhase.tripleTapDown => event.onTripleTapDown,
      ElEventPhase.secondaryTapDown => event.onSecondaryTapDown,
      ElEventPhase.secondaryTapUp => event.onSecondaryTapUp,
      ElEventPhase.secondaryTap => event.onSecondaryTap,
      ElEventPhase.tertiaryTapDown => event.onTertiaryTapDown,
      ElEventPhase.tertiaryTapUp => event.onTertiaryTapUp,
      ElEventPhase.tertiaryTap => event.onTertiaryTap,
      ElEventPhase.forwardTapDown => event.onForwardTapDown,
      ElEventPhase.forwardTapUp => event.onForwardTapUp,
      ElEventPhase.forwardTap => event.onForwardTap,
      ElEventPhase.backTapDown => event.onBackTapDown,
      ElEventPhase.backTapUp => event.onBackTapUp,
      ElEventPhase.backTap => event.onBackTap,
      ElEventPhase.longPress => event.onLongPress,
      ElEventPhase.tapCancel => event.onTapCancel,
      ElEventPhase.dragDown => event.onDragDown,
      // drag 家族按胜出轴选组：轴向拖拽优先匹配对应轴组，未声明时回落到
      // 自由拖拽组（onDrag*）——保证外层只挂 onDrag* 的观察者与 dragProxy
      // roster 成员的生命周期信号（onDragEnd.velocity 等）继续可达。
      // 自由拖拽（dragAxis == null）不反向回落到轴向组。
      ElEventPhase.dragStart => switch (dragAxis) {
        Axis.vertical => event.onVerticalDragStart ?? event.onDragStart,
        Axis.horizontal => event.onHorizontalDragStart ?? event.onDragStart,
        null => event.onDragStart,
      },
      ElEventPhase.dragUpdate => switch (dragAxis) {
        Axis.vertical => event.onVerticalDragUpdate ?? event.onDragUpdate,
        Axis.horizontal => event.onHorizontalDragUpdate ?? event.onDragUpdate,
        null => event.onDragUpdate,
      },
      ElEventPhase.dragEnd => switch (dragAxis) {
        Axis.vertical => event.onVerticalDragEnd ?? event.onDragEnd,
        Axis.horizontal => event.onHorizontalDragEnd ?? event.onDragEnd,
        null => event.onDragEnd,
      },
      ElEventPhase.dragCancel => switch (dragAxis) {
        Axis.vertical => event.onVerticalDragCancel ?? event.onDragCancel,
        Axis.horizontal => event.onHorizontalDragCancel ?? event.onDragCancel,
        null => event.onDragCancel,
      },
      ElEventPhase.scaleStart => event.onScaleStart,
      ElEventPhase.scaleUpdate => event.onScaleUpdate,
      ElEventPhase.scaleEnd => event.onScaleEnd,
      ElEventPhase.scaleCancel => event.onScaleCancel,
      ElEventPhase.rotationUpdate => event.onRotationUpdate,
    };
  }

  static PointerEvent _canonicalPointerEvent(PointerEvent event) {
    var current = event;
    while (current.original != null) {
      current = current.original!;
    }
    return current;
  }

  /// 事件已是本节点坐标系的变换产物（framework 沿 hit-test entry 逐层
  /// `event.transformed` / MouseTracker 逐注解变换）时直接采纳其
  /// localPosition / localDelta——省去每事件 getTransformTo 全链矩阵求逆
  /// ×3（localPosition 一次 + localDelta 的 start/end 两次）。
  void _adoptLocalFromEvent(ElEventCallback callback, PointerEvent event) {
    callback.localPosition = event.localPosition;
    if (callback.delta != Offset.zero) callback.localDelta = event.localDelta;
  }

  Offset _localPositionFor(RenderBox target, Offset globalPosition) =>
      target.globalToLocal(globalPosition);

  /// 本 dispatcher 当前是否可以 fire。
  ///
  /// 正常事件路径要求宿主 attached。终态窗口（销毁 / 真离场结算）例外：此时宿主
  /// 已 detach，但 driver 与 roster 必须收到终态，否则在途手势永远收不了尾、下一
  /// 手也接不上。这类 fire 的坐标退化为全局值，见 [_terminalCoordinatesUnavailable]。
  bool get _canFire => _owner.attached || _terminalFiresImmediate;

  bool _terminalCoordinatesUnavailable(RenderBox target) {
    if (!_terminalFiresImmediate) return false;
    RenderObject root = target;
    while (root.parent != null) {
      root = root.parent!;
    }
    // detach 过程中 target 可能仍 attached，但物理父链已离开 RenderView；
    // 此时保留上一跳整套局部坐标，避免 position/delta 混用不同基准。
    return root is! RenderView;
  }

  Offset _localDeltaFor(
    RenderBox target,
    Offset globalPosition,
    Offset globalDelta,
  ) {
    if (globalDelta == Offset.zero) return Offset.zero;
    final start = _localPositionFor(target, globalPosition);
    final end = _localPositionFor(target, globalPosition + globalDelta);
    return end - start;
  }

  // ===========================================================================
  // 无序列 pointer 事件（hover / signal）
  // ===========================================================================

  /// 当前正在分发的无序列事件（同步分发内的最内层去重标记）。
  static PointerEvent? _activeNonSequenceEvent;

  void _handleNonSequenceEvent(PointerEvent event) {
    final canonical = _canonicalPointerEvent(event);
    if (identical(_activeNonSequenceEvent, canonical)) return; // 更内层已处理
    _activeNonSequenceEvent = canonical;
    final phase = event is PointerSignalEvent
        ? ElEventPhase.pointerSignal
        : ElEventPhase.pointerHover;
    _DispatchCycle.run(() {
      // 惰性构造 callback：链上无订阅者时零分配。
      ElEventCallback? callback;
      final delta = switch (event) {
        PointerScrollEvent(:final scrollDelta) => scrollDelta,
        _ => event.delta,
      };
      void deliverTo(ElEventDispatcher member) {
        final handler = member._handlerFor(phase);
        if (handler == null) return;
        callback ??= ElEventCallback(
          phase: phase,
          globalPosition: event.position,
          localPosition: Offset.zero,
          delta: delta,
          localDelta: Offset.zero,
          buttons: event.buttons,
          originalEvent: event,
        );
        final cb = callback!;
        if (cb.propagationStopped) return;
        if (identical(member, this) && event is! PointerSignalEvent) {
          _adoptLocalFromEvent(cb, event);
          _retargetResolversOnly(cb, member, null);
        } else {
          _retargetCallback(cb, member, null);
        }
        cb.markCallbackInvoked();
        handler(cb);
      }

      if (_owner.attached) deliverTo(this);
      if (callback?.propagationStopped ?? false) {
        _registerHandledPointerSignal(event, callback);
        return;
      }
      RenderObject? current = _owner.parent;
      while (current != null) {
        if (current is RenderBox) {
          final member = ElEventDispatcher.of(current);
          if (member != null && !member.disabled && member._owner.attached) {
            deliverTo(member);
            if (callback?.propagationStopped ?? false) {
              _registerHandledPointerSignal(event, callback);
              return;
            }
          }
        }
        current = current.parent;
      }
      _registerHandledPointerSignal(event, callback);
    });
  }

  static void _registerHandledPointerSignal(
    PointerEvent event,
    ElEventCallback? callback,
  ) {
    if (event is! PointerSignalEvent || callback == null) return;
    if (!callback.defaultPrevented &&
        callback.remainingDelta == callback.delta) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      _respondHandledPointerSignal,
    );
  }

  static void _respondHandledPointerSignal(PointerSignalEvent event) {
    event.respond(allowPlatformDefault: false);
  }

  // ===========================================================================
  // Scale 协调（tracker 宿主侧）
  // ===========================================================================

  bool _handleScaleStart(
    _PointerSequence? seq,
    Offset focalPoint, {
    Object? originalEvent,
    bool selfOnly = false,
  }) {
    final machine = _scaleMachine;
    if (machine == null) return false;
    final startGeneration = _configGeneration;
    final isMultiPointer = machine.pointerCount >= 2;
    if (isMultiPointer) {
      if (!_claimEagerForScalePointers()) return false;
      if (!_cancelPrimaryGesturesForScalePointers(
        focalPoint,
        startGeneration: startGeneration,
        originalEvent: originalEvent,
      )) {
        machine.resetSilently();
        return false;
      }
    } else {
      _tapMachine?.cancelForAcceptedScale(
        seq?.pointer,
        focalPoint,
        reason: ElEventCancelReason.selfGestureAccepted,
        originalEvent: originalEvent,
      );
      if (_configGeneration != startGeneration) {
        machine.resetSilently();
        return false;
      }
      _dragMachine?.cancelForScaleGesture(
        focalPoint,
        originalEvent: originalEvent,
      );
      if (_configGeneration != startGeneration) {
        machine.resetSilently();
        return false;
      }
    }
    if (!identical(_scaleMachine, machine) || !_needsScaleShape(_event)) {
      machine.resetSilently();
      return false;
    }
    machine.started = true;
    machine.lastFocalPoint = focalPoint;
    _fireWithScale(
      seq,
      ElEventPhase.scaleStart,
      focalPoint,
      1.0,
      0.0,
      pointerCount: machine.pointerCount,
      originalEvent: originalEvent,
      selfOnly: selfOnly,
    );
    return true;
  }

  /// 原子检查并接管 scale 机全部参与指针的序列。
  ///
  /// 官方 arena 里 ScaleGestureRecognizer accept 后独占所有参与指针；闭环
  /// 系统的等价物是先逐序列预检，再统一写入 eager owner；任一指针不兼容便
  /// 零提交。普通 eager 不可抢，只有明确把 [scaleUpgradeTarget] 指向本宿主
  /// 的 winner 可让渡。少于两指时不调用，单指消费权仍交给组件层。
  bool _claimEagerForScalePointers() {
    final machine = _scaleMachine;
    if (machine == null || machine.pointerCount < 2) return false;
    for (final pointer in machine._positions.keys) {
      final sequence = _PointerSequenceRegistry.of(pointer);
      if (sequence == null || !identical(sequence.scaleTracker, this)) {
        return false;
      }
      final index = sequence.indexOf(this);
      if (index < 0 && !identical(sequence.scaleShadowTarget, this)) {
        return false;
      }
      final eager = sequence.eagerMember;
      if (eager != null &&
          !identical(eager, this) &&
          !identical(sequence.scaleUpgradeTarget, this)) {
        return false;
      }
    }
    for (final pointer in machine._positions.keys) {
      final sequence = _PointerSequenceRegistry.of(pointer)!;
      sequence.eagerMember = this;
      sequence.scaleUpgradeTarget = null;
      sequence.scaleWon = true;
    }
    return true;
  }

  /// Scale 归属提交后按各序列原链直接终止 Tap/Drag，保证 cancel 先于 start。
  bool _cancelPrimaryGesturesForScalePointers(
    Offset focalPoint, {
    required int startGeneration,
    Object? originalEvent,
  }) {
    final machine = _scaleMachine;
    if (machine == null) return false;
    var generationUnchanged = true;
    final pointers = machine._positions.keys.toList(growable: false);
    for (final pointer in pointers) {
      final sequence = _PointerSequenceRegistry.of(pointer);
      if (sequence == null) continue;
      for (
        var memberIndex = 0;
        memberIndex < sequence.chain.length;
        memberIndex++
      ) {
        final member = sequence.chain[memberIndex];
        member._tapMachine?.cancelForAcceptedScale(
          pointer,
          focalPoint,
          reason: identical(member, this)
              ? ElEventCancelReason.selfGestureAccepted
              : ElEventCancelReason.otherGestureAccepted,
          originalEvent: originalEvent,
        );
        if (_configGeneration != startGeneration) generationUnchanged = false;
        member._cancelDragForSequenceLoss(
          sequence,
          memberIndex,
          focalPoint,
          originalEvent: originalEvent,
        );
        if (_configGeneration != startGeneration) generationUnchanged = false;
      }
    }
    return generationUnchanged;
  }

  void _fireScaleUpdate(
    _PointerSequence? seq,
    Offset focalPoint,
    double scale,
    double rotation, {
    Offset delta = Offset.zero,
    int pointerCount = 0,
    Object? originalEvent,
    bool selfOnly = false,
  }) {
    if (_event?.onScaleUpdate != null) {
      _fireWithScale(
        seq,
        ElEventPhase.scaleUpdate,
        focalPoint,
        scale,
        rotation,
        delta: delta,
        pointerCount: pointerCount,
        originalEvent: originalEvent,
        selfOnly: selfOnly,
      );
    }
    if (_event?.onRotationUpdate != null && rotation != 0.0) {
      _fireWithScale(
        seq,
        ElEventPhase.rotationUpdate,
        focalPoint,
        scale,
        rotation,
        delta: delta,
        pointerCount: pointerCount,
        originalEvent: originalEvent,
        selfOnly: selfOnly,
      );
    }
  }

  void _handleScaleEnd(
    _PointerSequence? seq,
    Velocity velocity, {
    double logScaleVelocity = 0.0,
    Offset? scaleVelocityFocalPoint,
    Object? originalEvent,
    bool selfOnly = false,
  }) {
    final machine = _scaleMachine;
    if (machine == null || !machine.started) return;
    final position =
        scaleVelocityFocalPoint ??
        machine.lastFocalPoint ??
        _lastPointerPosition;
    machine.started = false;
    machine.lastFocalPoint = null;
    _fireWithVelocity(
      seq,
      ElEventPhase.scaleEnd,
      position,
      velocity,
      Offset.zero,
      logScaleVelocity: logScaleVelocity,
      originalEvent: originalEvent,
      selfOnly: selfOnly,
    );
  }

  void _cancelActiveScale({
    _PointerSequence? deliverySequence,
    PointerEvent? originalEvent,
    bool selfOnly = false,
  }) {
    final machine = _scaleMachine;
    if (machine == null || !machine.started) {
      machine?.resetSilently();
      return;
    }
    final position =
        originalEvent?.position ??
        machine.lastFocalPoint ??
        _lastPointerPosition;
    machine.resetSilently();
    _fireWithScale(
      deliverySequence,
      ElEventPhase.scaleCancel,
      position,
      1.0,
      0.0,
      originalEvent: originalEvent,
      selfOnly: selfOnly,
    );
  }

  @visibleForTesting
  void debugHandleScaleStartForTest(
    Offset focalPoint, {
    Object? originalEvent,
  }) {
    _DispatchCycle.run(() {
      _scaleMachine ??= _ScaleMachine(this);
      _handleScaleStart(null, focalPoint, originalEvent: originalEvent);
    });
  }

  @visibleForTesting
  void debugFireScaleUpdateForTest(ScaleUpdateDetails details) {
    _DispatchCycle.run(() {
      final machine = _scaleMachine;
      final previousFocalPoint = machine?.lastFocalPoint ?? details.focalPoint;
      if (machine != null && machine.started) {
        machine.lastFocalPoint = details.focalPoint;
      }
      _fireScaleUpdate(
        null,
        details.focalPoint,
        details.scale,
        details.rotation,
        delta: details.focalPoint - previousFocalPoint,
        pointerCount: details.pointerCount,
        originalEvent: details,
      );
    });
  }

  @visibleForTesting
  void debugHandleScaleEndForTest({
    Velocity velocity = Velocity.zero,
    double logScaleVelocity = 0.0,
    Object? originalEvent,
  }) {
    _DispatchCycle.run(() {
      _handleScaleEnd(
        null,
        velocity,
        logScaleVelocity: logScaleVelocity,
        originalEvent: originalEvent,
      );
    });
  }

  void _cancelActivePanZoom({PointerEvent? originalEvent}) {
    if (!_panZoomStarted) return;
    final position =
        originalEvent?.position ?? _lastPanZoomPosition ?? _lastPointerPosition;
    _panZoomStarted = false;
    _panZoomPointerId = null;
    _lastPanZoomPosition = null;
    _fire(
      null,
      ElEventPhase.pointerPanZoomEnd,
      position,
      originalEvent: originalEvent,
      selfOnly: true,
    );
  }

  // ===========================================================================
  // MouseTracker 事件入口
  // ===========================================================================

  void handlePointerEnter(PointerEnterEvent event) {
    if (!_owner.attached || disabled) return;
    _lastPointerPosition = event.position;
    // handler 前置：无订阅（hover 扫掠常态）零 callback 构造零 globalToLocal。
    final handler = _handlerFor(ElEventPhase.pointerEnter);
    if (handler == null) return;
    _DispatchCycle.run(() {
      final callback = ElEventCallback(
        phase: ElEventPhase.pointerEnter,
        globalPosition: event.position,
        // MouseTracker 逐注解变换：enter/exit 事件的 localPosition 已是本节点系。
        localPosition: event.localPosition,
        buttons: event.buttons,
        originalEvent: event,
      );
      callback.markCallbackInvoked();
      handler(callback);
    });
  }

  void handlePointerExit(PointerExitEvent event) {
    if (!_owner.attached || disabled) return;
    _lastPointerPosition = event.position;
    final handler = _handlerFor(ElEventPhase.pointerExit);
    if (handler == null) return;
    _DispatchCycle.run(() {
      final callback = ElEventCallback(
        phase: ElEventPhase.pointerExit,
        globalPosition: event.position,
        localPosition: event.localPosition,
        buttons: event.buttons,
        originalEvent: event,
      );
      callback.markCallbackInvoked();
      handler(callback);
    });
  }

  // 取消 / 生命周期

  /// 结清本 dispatcher 拥有的活动指针序列。
  ///
  /// 默认只结算"链上再无存活祖先"的序列；force 用于必须取消整条序列的禁用边界。
  /// 宿主销毁往往是换手而不是交互结束——翻页、
  /// 重挂这类场景里祖先仍在消费同一指针，此时结算终态就是中断用户手势。这类序列
  /// 留给 [_PointerSequenceRegistry.evict] 提升给存活祖先继续。
  void _terminateOwnedPointerSequences({bool force = false}) {
    final owned = _PointerSequenceRegistry._sequences.values
        .where(
          (seq) =>
              identical(seq.owner, this) &&
              (force ||
                  !_PointerSequenceRegistry.hasSurvivingAncestor(seq, this)),
        )
        .toList(growable: false);
    _DispatchCycle.run(() {
      for (final seq in owned) {
        _withImmediateTerminalChain(seq, () {
          if (!identical(_PointerSequenceRegistry.of(seq.pointer), seq)) return;
          if (seq.isPanZoom) {
            final position = _lastPanZoomPosition ?? _lastPointerPosition;
            final end = PointerPanZoomEndEvent(
              pointer: seq.pointer,
              position: position,
              device: seq.device,
            );
            seq.beginCycle(end);
            _deliverRaw(
              seq,
              ElEventPhase.pointerPanZoomEnd,
              end,
              globalPosition: position,
            );
            for (final member in seq.chain) {
              member._clearPanZoomState(seq.pointer);
            }
          } else {
            final cancel = PointerCancelEvent(
              pointer: seq.pointer,
              position: _lastPointerPosition,
              kind: seq.kind,
              device: seq.device,
            );
            seq.beginCycle(cancel);
            // 禁用边界必须同时结清已公开的原始 Down，避免 raw 消费者残留按压状态。
            if (force) _deliverRaw(seq, ElEventPhase.pointerCancel, cancel);
            // 销毁 / 真离场结算：这里的 PointerCancelEvent 是宿主自造的，对用户是
            // 外部打断，按 external 报告而非平台 pointerCancel。
            _feedCancel(seq, cancel, (_) => false, external: true);
          }
          _PointerSequenceRegistry.release(seq);
        });
      }
    });
  }

  /// 外层选择器确认接管拖拽时，取消本 dispatcher 里等待中的 tap/drag。
  ///
  /// 终态回调在当前配置下同步执行；handler 内 set event（代际变化）会中止
  /// 剩余取消步骤，对齐旧实现的 revision 中止语义。
  void cancelAllPending(PointerEvent event) =>
      _cancelAllPending(event, _pointerCountCurrent);

  void _cancelAllPending(PointerEvent event, int pointerCount) {
    final cancelGeneration = _configGeneration;
    _DispatchCycle.run(() {
      final previousImmediate = _terminalFiresImmediate;
      _terminalFiresImmediate = true;
      try {
        final seq = _PointerSequenceRegistry.of(event.pointer);
        if (seq != null && identical(seq.eagerMember, this)) {
          seq.scaleUpgradeTarget = null;
          seq.scaleWon = false;
        }
        _tapMachine?.cancelActive(originalEvent: event);
        if (_configGeneration != cancelGeneration) return;
        _tapMachine?.resetConsecutiveWindow();
        _cancelDragRoutesForLifecycle(
          event: event,
          expectedGeneration: cancelGeneration,
        );
        if (_configGeneration != cancelGeneration) return;
        _dragMachine?.cancelActive(event: event, pointerCount: pointerCount);
        if (_configGeneration != cancelGeneration) return;
        _cancelActiveScale(originalEvent: event);
        if (_configGeneration != cancelGeneration) return;
        _cancelActivePanZoom(originalEvent: event);
        if (_configGeneration != cancelGeneration) return;
        _clearSideMachines();
      } finally {
        _terminalFiresImmediate = previousImmediate;
      }
    });
  }

  /// 宿主在没有新平台事件时按最后坐标取消当前输入序列。
  ///
  void cancelAllPendingAtLastPosition() =>
      _cancelAllPendingAtLastPosition(_pointerCountCurrent);

  void _cancelAllPendingAtLastPosition(int pointerCount) => _cancelAllPending(
    PointerCancelEvent(position: _lastPointerPosition),
    pointerCount,
  );

  void _cancelPassiveDragPipeline() =>
      _passiveDragPipeline?.driver.cancelAllPendingAtLastPosition();

  /// 释放资源。宿主 RenderBox 在 dispose / event = null 时调用。
  void dispose() {
    _terminateOwnedPointerSequences();
    _cancelPassiveDragPipeline();
    _DispatchCycle.run(() {
      final previousImmediate = _terminalFiresImmediate;
      _terminalFiresImmediate = true;
      try {
        _tapMachine?.cancelActive();
        _cancelDragRoutesForLifecycle(expectedGeneration: _configGeneration);
        _dragMachine?.cancelActive(pointerCount: 0);
        _cancelActiveScale();
        _cancelActivePanZoom();
      } finally {
        _terminalFiresImmediate = previousImmediate;
      }
    });
    _tapMachine?.dispose();
    _tapMachine = null;
    _dragMachine?.resetSilently();
    _dragMachine = null;
    _scaleMachine?.resetSilently();
    _scaleMachine = null;
    _secondaryMachine = null;
    _tertiaryMachine = null;
    _forwardMachine = null;
    _backMachine = null;
    _PointerSequenceRegistry.evict(this);

    _event = null;
    _cachedHasAnyCallback = false;
    if (_registered) {
      // 多次构造 / dispose 时序错乱时，新 dispatcher 可能已把同一 RenderBox
      // 接管为自己；这里只有当注册表仍指向自己时才解绑，否则会误清除新的。
      if (identical(_registry[_owner], this)) {
        _registry[_owner] = null;
        _configCascadeEpoch++;
      }
    }
  }

  /// 保留配置的宿主重挂后恢复注册，让在途手势继续沿用同一分发器。
  void attach() {
    if (_registered) {
      _registry[_owner] = this;
      _configCascadeEpoch++;
    }
  }

  /// 解除注册与计时器；普通等待态静默清理，已接管复合资源的拖拽先派发取消。
  ///
  /// GlobalKey 重挂等暂时离树场景传入 preserveEvent，保留配置与在途指针状态。
  void detach({bool preserveEvent = false}) {
    // 重挂：宿主只是暂时离树，同帧会 attach 回来，元素与手势账都还在。
    // 在途拖拽 / 按压 / 长按一律原样保留，这里什么都不结算。
    // 真正销毁时的取消统一由 dispose 派发终态。
    if (preserveEvent) return;
    _cancelPassiveDragPipeline();
    _DispatchCycle.run(() {
      final previousImmediate = _terminalFiresImmediate;
      _terminalFiresImmediate = true;
      try {
        _cancelDragRoutesForLifecycle(expectedGeneration: _configGeneration);
      } finally {
        _terminalFiresImmediate = previousImmediate;
      }
    });
    _tapMachine?.cancelSilently();
    _tapMachine?.resetConsecutiveWindow();
    _dragMachine?.resetSilently();
    _scaleMachine?.resetSilently();
    for (final machine in _liveSideMachines) {
      machine.clear();
    }
    _panZoomStarted = false;
    _panZoomPointerId = null;
    _lastPanZoomPosition = null;
    _PointerSequenceRegistry.evict(this);

    if (!preserveEvent) {
      _event = null;
      _cachedHasAnyCallback = false;
    }
    if (_registered && identical(_registry[_owner], this)) {
      _registry[_owner] = null;
      _configCascadeEpoch++;
    }
  }

  // ===========================================================================
  // 拖拽重采样（仅驱动已接受的 Drag 更新）
  // ===========================================================================

  double? _displayRefreshRate() {
    final debugRefreshRate = DragResamplingPolicy.debugRefreshRateOverride;
    if (debugRefreshRate != null) return debugRefreshRate;

    final renderView = _owner.owner?.rootNode;
    if (renderView is RenderView) {
      return renderView.flutterView.display.refreshRate;
    }
    final views = ui.PlatformDispatcher.instance.views;
    if (views.isEmpty) return null;
    return views.first.display.refreshRate;
  }
}

// --- 主指针共享谓词（tap / drag / 侧键状态机共用） ---------------------------

bool _isPrimaryButtonEvent(PointerEvent event) {
  if (event.kind == PointerDeviceKind.touch ||
      event.kind == PointerDeviceKind.stylus ||
      event.kind == PointerDeviceKind.invertedStylus ||
      event.kind == PointerDeviceKind.unknown) {
    return true;
  }
  return (event.buttons & kPrimaryButton) != 0;
}

bool _tracksStableButtons(PointerDeviceKind kind) {
  return kind == PointerDeviceKind.mouse ||
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;
}
