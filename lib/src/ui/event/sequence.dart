part of 'dispatcher.dart';

const int _observedFreeDragStart = 1 << 0;
const int _observedVerticalDragStart = 1 << 1;
const int _observedHorizontalDragStart = 1 << 2;
const int _dragStartFamilyMask =
    _observedFreeDragStart |
    _observedVerticalDragStart |
    _observedHorizontalDragStart;
const int _outstandingDragStartShift = 3;
const int _dragStartDirectionShift = 6;
const int _dragStartDirectionMask = 0x7 << _dragStartDirectionShift;
const int _dragStartAxisShift = 9;
const int _dragStartAxisMask = 0x3 << _dragStartAxisShift;

Axis? _dragAxisForStartFamily(int family) => switch (family) {
  _observedVerticalDragStart => Axis.vertical,
  _observedHorizontalDragStart => Axis.horizontal,
  _ => null,
};

/// PointerDown/PanZoomStart 到 terminal 的单一序列；最内层 owner 冻结
/// target→ancestor [chain]，统一投递 raw、推进成员状态机并路由语义事件。
/// eager winner、family cutoff 与每轮 phase 去重都只改变资格，不重排冻结链。
final class _PointerSequence {
  _PointerSequence({
    required this.pointer,
    required this.kind,
    required this.device,
    required this.owner,
    required this.chain,
  }) : assert(
         ElEventPhase.values.length <= 64,
         'owner phase 去重位图最多支持 64 个事件阶段',
       ),
       chainCutoff = chain.length,
       primaryGestureCutoff = chain.length,
       tapCutoff = chain.length,
       tapOnlyCutoff = chain.length,
       dragRouteCutoff = chain.length,
       scaleRouteCutoff = chain.length,
       panZoomRouteCutoff = chain.length;

  final int pointer;
  final PointerDeviceKind kind;

  /// 认领事件的 device id。add/remove 是设备级事件（framework 里 pointer 恒 0），
  /// PointerRemovedEvent 只能靠 device 关联回序列——Android 每根手指是独立
  /// device（MotionEvent pointer id），多指场景下第二指抬起后的 remove 绝不能
  /// 落到第一指的序列上。
  final int device;

  final ElEventDispatcher owner;

  /// claim 时收集的 dispatcher 链快照，`chain[0] == owner`，内→外。
  /// 跳过了宿主 disabled 的 dispatcher（禁用对冒泡链同样免疫）。
  final List<ElEventDispatcher> chain;

  /// 是否 trackpad pan-zoom 序列（claim 自 PointerPanZoomStart）。
  bool isPanZoom = false;

  /// 认领本序列的原始 down / panZoomStart 事件（canonical 实例）。
  ///
  /// Flutter 沿 hit-test path 子→根分发同一个事件对象；更外层 dispatcher 用
  /// 身份比对识别"本次 down 已被更内层认领"并直接返回。
  PointerEvent? canonicalDown;

  /// 已处理过终态事件（up / cancel / panZoomEnd）的成员。
  ///
  /// 每个成员在自己的 handleEvent 到达时处理终态；最外层成员处理完（或全部
  /// 成员都已见到终态）时同步释放序列，微任务兜底覆盖"外层不在 hit path"。
  Set<ElEventDispatcher>? _terminalSeen;
  Set<ElEventDispatcher> get terminalSeenMembers =>
      _terminalSeen ??= HashSet<ElEventDispatcher>.identity();

  /// 本序列是否见过侧键位（down 时打标）：up/cancel 的侧键 tracker 解析整段
  /// 门禁——常态主键序列零 putIfAbsent 闭包零链扫。
  bool sawSideButtons = false;

  /// 本序列是否真正建立过 Drag 跟踪；tap-only up 借此保持单遍链结算。
  bool hasTrackedDrag = false;

  /// 微任务释放兜底是否已排队。
  bool releaseScheduled = false;

  /// `stopPropagation@pointerDown` 建立的整条 pointer 序列边界。
  int chainCutoff;

  /// DragProxy 管线形成时对管线外主键手势建立的内部截断。
  int primaryGestureCutoff;

  /// `stopPropagation@tapDown/tapUp` 建立的 Tap 家族后续边界。
  int tapCutoff;

  /// `stopPropagation@tap` 建立的最终 Tap 边界。
  int tapOnlyCutoff;

  /// `stopPropagation@dragStart` 建立的 Drag 家族路由边界。
  int dragRouteCutoff;

  /// `stopPropagation@scaleStart` 建立的 Scale 家族路由边界。
  int scaleRouteCutoff;

  /// `stopPropagation@pointerPanZoomStart` 建立的 PanZoom 家族路由边界。
  int panZoomRouteCutoff;

  /// [ElEventCallback.eagerGesture] 认领者。非 null 后序列坍缩为该成员独占：
  /// 其余成员先结清取消终态再失权，后续 raw 与语义投递都只达 eager 成员。
  ElEventDispatcher? eagerMember;

  /// winner 是否已单向取消自身最终 tap 激活资格。
  ///
  /// pointerDown raw 回调早于 TapMachine.feedDown，因此必须由序列持久化，
  /// 让随后才建立的 Tap 候选继承同一裁决。
  bool eagerCancelsSelfTap = false;

  /// 当前 eager winner 明确允许接管它的 scale tracker；null 表示不可让渡。
  ElEventDispatcher? scaleUpgradeTarget;

  /// 多指 Scale 已经原子接管本序列，后续不得重建 Tap/Drag 候选。
  bool scaleWon = false;

  /// 内容命中被 Scroll winner 屏蔽时，第二指保留的唯一 Scale 宿主。
  ///
  /// 它不是本指针真实命中链成员，不参与 raw 投递或语义冒泡。
  ElEventDispatcher? scaleShadowTarget;

  /// [ElDragProxy] 管线形成时写入的豁免成员集合（roster 成员）。
  ///
  /// [blockedAt] 对豁免成员**仅放行 primaryGestureCutoff 截断**：这保证即使
  /// driver 或中间成员在 dragStart 链上 stopPropagation，或形成时的截断把
  /// roster 成员挤出 primaryGestureCutoff 之外，roster 成员的 dragStart /
  /// dragEnd / dragCancel 冒泡投递仍能到达（面板 snap 依赖 dragEnd.velocity）。
  /// eager 坍缩不豁免——它是 pointer 归属级压制。
  Set<ElEventDispatcher>? pipelineExemptMembers;

  /// 侧键（右/中/前进/后退）单 tracker：最内层订阅成员，nearest wins。懒建
  /// （sawSideButtons 门禁后仅侧键序列触碰）。
  Map<int, ElEventDispatcher?>? _sideTrackersLazy;
  Map<int, ElEventDispatcher?> get _sideTrackers =>
      _sideTrackersLazy ??= <int, ElEventDispatcher?>{};

  /// scale 单 tracker：最内层声明 scale 回调的成员。
  ElEventDispatcher? scaleTracker;
  bool scaleTrackerResolved = false;

  /// 每成员 DragStart 回调组的已观察位（低 3 bit）与待终态位（高 3 bit）。
  List<int>? _dragStartRouteStates;

  /// 本 pointer 已公开的轴向 Drag 轴；自由 Drag 不锁轴。
  Axis? _dragStartAxisLock;

  /// [axis] 是否与本 pointer 已公开的 Drag 轴冲突。
  bool dragStartAxisConflicts(Axis? axis) =>
      axis != null && _dragStartAxisLock != null && _dragStartAxisLock != axis;

  /// 标记 [member] 的 [axis] DragStart handler 已实际执行，避免同组重复 Start。
  void markDragStartRouteObserved(
    ElEventDispatcher member,
    Axis? axis,
    AxisDirection? direction, [
    int? knownIndex,
  ]) {
    final index = knownIndex ?? indexOf(member);
    if (index < 0 ||
        index >= chain.length ||
        !identical(chain[index], member)) {
      return;
    }
    final mask = _dragStartObservationMask(member, axis);
    if (mask == 0) return;
    if (axis != null && _dragStartAxisLock == null) {
      _dragStartAxisLock = axis;
    }
    final states = _dragStartRouteStates ??= List<int>.filled(chain.length, 0);
    if ((states[index] & _dragStartFamilyMask) == 0) {
      if (direction != null) {
        states[index] =
            (states[index] & ~_dragStartDirectionMask) |
            ((direction.index + 1) << _dragStartDirectionShift);
      }
      if (axis != null) {
        states[index] =
            (states[index] & ~_dragStartAxisMask) |
            ((axis.index + 1) << _dragStartAxisShift);
      }
    }
    states[index] |= mask | (mask << _outstandingDragStartShift);
  }

  /// [member] 是否已由任意回调组公开过本 pointer 的 DragStart。
  bool hasAnyObservedDragStartRoute(ElEventDispatcher member) =>
      observedDragStartFamily(member) != 0;

  /// [member] 首次公开的 DragStart 回调组；同一 pointer 后续不得换组。
  int observedDragStartFamily(ElEventDispatcher member) {
    final states = _dragStartRouteStates;
    if (states == null) return 0;
    final index = indexOf(member);
    if (index < 0 || index >= states.length) return 0;
    return states[index] & _dragStartFamilyMask;
  }

  /// [member] 首次公开 DragStart 时冻结的起手方向。
  AxisDirection? observedDragStartDirection(ElEventDispatcher member) {
    final states = _dragStartRouteStates;
    if (states == null) return null;
    final index = indexOf(member);
    if (index < 0 || index >= states.length) return null;
    final encoded =
        (states[index] & _dragStartDirectionMask) >> _dragStartDirectionShift;
    if (encoded == 0) return null;
    return AxisDirection.values[encoded - 1];
  }

  /// 指定链成员首次公开 DragStart 时冻结的起手方向。
  AxisDirection? observedDragStartDirectionAt(int index) {
    final states = _dragStartRouteStates;
    if (states == null || index < 0 || index >= states.length) return null;
    final encoded =
        (states[index] & _dragStartDirectionMask) >> _dragStartDirectionShift;
    return encoded == 0 ? null : AxisDirection.values[encoded - 1];
  }

  Axis? observedDragStartAxis(ElEventDispatcher member) =>
      observedDragStartAxisAt(indexOf(member));

  /// 指定成员首次公开 DragStart 时冻结的实际胜出轴。
  Axis? observedDragStartAxisAt(int index) {
    final states = _dragStartRouteStates;
    if (states == null || index < 0 || index >= states.length) return null;
    final encoded = (states[index] & _dragStartAxisMask) >> _dragStartAxisShift;
    return encoded == 0 ? null : Axis.values[encoded - 1];
  }

  /// [member] 在 [axis] 下实际解析到的 DragStart 回调组。
  int dragStartFamilyFor(ElEventDispatcher member, Axis? axis) =>
      _dragStartObservationMask(member, axis);

  /// [member] 的同组 DragStart 是否仍欠一个 End/Cancel。
  bool hasOutstandingDragStartRoute(ElEventDispatcher member, Axis? axis) {
    final states = _dragStartRouteStates;
    if (states == null) return false;
    final index = indexOf(member);
    if (index < 0 || index >= states.length) return false;
    final mask = _matchingStoredDragStartFamily(index, axis);
    return mask != 0 &&
        (states[index] & (mask << _outstandingDragStartShift)) != 0;
  }

  /// 结清 [member] 同组 DragStart 的唯一终态资格。
  bool takeOutstandingDragStartRoute(ElEventDispatcher member, Axis? axis) {
    final states = _dragStartRouteStates;
    if (states == null) return false;
    final index = indexOf(member);
    if (index < 0 || index >= states.length) return false;
    final mask = _matchingStoredDragStartFamily(index, axis);
    final outstanding = mask << _outstandingDragStartShift;
    if (mask == 0 || (states[index] & outstanding) == 0) return false;
    states[index] &= ~outstanding;
    return true;
  }

  /// 指定成员当前仍欠终态的回调组位图，不依赖其当前 event shape。
  int outstandingDragStartFamiliesAt(int index) {
    final states = _dragStartRouteStates;
    if (states == null || index < 0 || index >= states.length) return 0;
    return (states[index] >> _outstandingDragStartShift) & _dragStartFamilyMask;
  }

  /// 按终态轴解析指定成员已存的回调组。
  int outstandingDragStartFamilyForAxisAt(int index, Axis? axis) {
    final family = _matchingStoredDragStartFamily(index, axis);
    return (outstandingDragStartFamiliesAt(index) & family) != 0 ? family : 0;
  }

  /// 直接按已存回调组结清资格，供配置移除/失权等旧 handler 终态使用。
  bool takeOutstandingDragStartFamilyAt(int index, int family) {
    final states = _dragStartRouteStates;
    if (states == null ||
        index < 0 ||
        index >= states.length ||
        (family & _dragStartFamilyMask) == 0) {
      return false;
    }
    final outstanding = family << _outstandingDragStartShift;
    if ((states[index] & outstanding) == 0) return false;
    states[index] &= ~outstanding;
    return true;
  }

  /// 多指 Drag 仅迁移一个成员的公开 Start 台账到继续驱动的 pointer 序列。
  void transferOutstandingDragStartsForMemberTo(
    ElEventDispatcher member,
    int memberIndex,
    _PointerSequence target,
  ) {
    final states = _dragStartRouteStates;
    if (states == null || memberIndex < 0 || memberIndex >= states.length) {
      return;
    }
    final state = states[memberIndex];
    if (((state >> _outstandingDragStartShift) & _dragStartFamilyMask) == 0) {
      return;
    }
    final targetIndex = target.indexOf(member);
    if (targetIndex < 0) return;
    final targetStates = target._dragStartRouteStates ??= List<int>.filled(
      target.chain.length,
      0,
    );
    targetStates[targetIndex] |= state;
    if (_dragStartAxisLock != null && target._dragStartAxisLock == null) {
      target._dragStartAxisLock = _dragStartAxisLock;
    }
    states[memberIndex] &=
        ~(_dragStartFamilyMask << _outstandingDragStartShift);
  }

  /// 当前整条 route 仍欠终态的 DragStart 回调组位图。
  int get outstandingDragStartFamilies {
    final states = _dragStartRouteStates;
    if (states == null) return 0;
    var result = 0;
    for (final state in states) {
      result |= (state >> _outstandingDragStartShift) & _dragStartFamilyMask;
    }
    return result;
  }

  int _dragStartObservationMask(ElEventDispatcher member, Axis? axis) {
    final event = member._event;
    if (event == null) return 0;
    return switch (axis) {
      Axis.vertical =>
        event.onVerticalDragStart != null
            ? _observedVerticalDragStart
            : event.onDragStart != null
            ? _observedFreeDragStart
            : 0,
      Axis.horizontal =>
        event.onHorizontalDragStart != null
            ? _observedHorizontalDragStart
            : event.onDragStart != null
            ? _observedFreeDragStart
            : 0,
      null => event.onDragStart != null ? _observedFreeDragStart : 0,
    };
  }

  int _matchingStoredDragStartFamily(int index, Axis? axis) {
    final states = _dragStartRouteStates;
    if (states == null || index < 0 || index >= states.length) return 0;
    final observed = states[index] & _dragStartFamilyMask;
    return switch (axis) {
      Axis.vertical =>
        (observed & _observedVerticalDragStart) != 0
            ? _observedVerticalDragStart
            : observed & _observedFreeDragStart,
      Axis.horizontal =>
        (observed & _observedHorizontalDragStart) != 0
            ? _observedHorizontalDragStart
            : observed & _observedFreeDragStart,
      null => observed & _observedFreeDragStart,
    };
  }

  /// 重根或 owner 提升时按 dispatcher identity 迁移已执行的 Start 路由。
  void absorbObservedDragStartRoutesFrom(
    _PointerSequence old, {
    bool Function(ElEventDispatcher member)? keepMember,
  }) {
    final oldStates = old._dragStartRouteStates;
    if (oldStates == null) return;
    for (var i = 0; i < old.chain.length; i++) {
      final member = old.chain[i];
      if (!(keepMember?.call(member) ?? true)) continue;
      if (i < oldStates.length && oldStates[i] != 0) {
        final index = indexOf(member);
        if (index >= 0) {
          final states = _dragStartRouteStates ??= List<int>.filled(
            chain.length,
            0,
          );
          states[index] |= oldStates[i];
          if (old._dragStartAxisLock != null && _dragStartAxisLock == null) {
            _dragStartAxisLock = old._dragStartAxisLock;
          }
        }
      }
    }
  }

  // --- 每平台事件的投递去重与 stopPropagation 截断 ---------------------------

  /// 已 down 喂送过的成员（防止序列重根后同一 down 重复喂送）。
  /// owner（每个 down 必喂的对象）走 bool 零分配，非 owner 懒集合。
  bool _ownerDownFed = false;
  Set<ElEventDispatcher>? _downFed;

  /// down 喂送去重登记；返回是否首次。
  bool markDownFed(ElEventDispatcher member) {
    if (identical(member, owner)) {
      if (_ownerDownFed) return false;
      _ownerDownFed = true;
      return true;
    }
    return (_downFed ??= HashSet<ElEventDispatcher>.identity()).add(member);
  }

  /// 指定成员是否已经接入本序列的 down 状态机喂送。
  bool wasDownFed(ElEventDispatcher member) {
    if (identical(member, owner)) return _ownerDownFed;
    return _downFed?.contains(member) ?? false;
  }

  /// 吸收 [old] 的 down 喂送记录（重根/迁移；owner 身份可能变化）。
  void absorbDownFedFrom(
    _PointerSequence old, {
    bool Function(ElEventDispatcher member)? keepMember,
  }) {
    if (old._ownerDownFed && (keepMember?.call(old.owner) ?? true)) {
      markDownFed(old.owner);
    }
    final others = old._downFed;
    if (others != null) {
      for (final member in others) {
        if (keepMember?.call(member) ?? true) markDownFed(member);
      }
    }
  }

  /// 当前正在处理的平台事件（canonical 实例）。
  PointerEvent? _cycleEvent;

  /// 当前平台事件内已投递 (phase, member) 记录，防止"子机器 fire 冒泡到父 +
  /// 父机器自身 fire"重复调用父 handler（对齐旧 _suppressedByDescendant 语义）。
  ///
  /// **双轨**：owner（绝大多数投递的目标）走低/高双字 phase 位图零分配，
  /// 避免 Web 32 位 bitwise 让高位 phase 与低位碰撞；非 owner 成员走
  /// `phase → chain index 集合`（多成员链才触碰），集合跨 cycle 原位 clear
  /// 复用，也不会在深链上发生成员索引碰撞。
  int _deliveredOwnerLowMask = 0;
  int _deliveredOwnerHighMask = 0;
  Map<ElEventPhase, Set<int>>? _deliveredOthers;

  /// 当前平台事件内某 phase 被 stopPropagation 截断后的链上限（用于不冒泡的
  /// 高频 phase：dragUpdate / pointerMove 等，子级 stop 后父级本轮不再收到）。
  Map<ElEventPhase, int>? _phaseCutoffLazy;

  int? deferredTapRouteIndex;

  /// 以平台事件（canonical 实例）为界重置去重状态：同一事件的重复进入
  /// （序列重根等）保留记录，新事件清空。[canonicalEvent] 为 null（定时器 /
  /// 全局路由等非平台事件入口）时强制重置。
  void beginCycle([PointerEvent? canonicalEvent]) {
    if (canonicalEvent != null && identical(_cycleEvent, canonicalEvent)) {
      return;
    }
    _cycleEvent = canonicalEvent;
    _deliveredOwnerLowMask = 0;
    _deliveredOwnerHighMask = 0;
    final others = _deliveredOthers;
    if (others != null) {
      for (final delivered in others.values) {
        if (delivered.isNotEmpty) delivered.clear();
      }
    }
    final cutoffs = _phaseCutoffLazy;
    if (cutoffs != null && cutoffs.isNotEmpty) cutoffs.clear();
    deferredTapRouteIndex = null;
  }

  /// 当前 cycle 的 canonical 事件；跨指针聚合手势用它同步投递序列账本。
  bool markDelivered(
    ElEventPhase phase,
    ElEventDispatcher member, [
    int? knownIndex,
  ]) {
    if (identical(member, owner)) {
      final index = phase.index;
      final bit = 1 << (index & 31);
      if (index < 32) {
        if ((_deliveredOwnerLowMask & bit) != 0) return false;
        _deliveredOwnerLowMask |= bit;
      } else {
        if ((_deliveredOwnerHighMask & bit) != 0) return false;
        _deliveredOwnerHighMask |= bit;
      }
      return true;
    }
    final index = knownIndex ?? indexOf(member);
    if (index < 0 ||
        index >= chain.length ||
        !identical(chain[index], member)) {
      return false;
    }
    final delivered =
        (_deliveredOthers ??= <ElEventPhase, Set<int>>{})[phase] ??=
            HashSet<int>();
    return delivered.add(index);
  }

  bool wasDelivered(
    ElEventPhase phase,
    ElEventDispatcher member, [
    int? knownIndex,
  ]) {
    if (identical(member, owner)) {
      final index = phase.index;
      final bit = 1 << (index & 31);
      return index < 32
          ? (_deliveredOwnerLowMask & bit) != 0
          : (_deliveredOwnerHighMask & bit) != 0;
    }
    final index = knownIndex ?? indexOf(member);
    if (index < 0 ||
        index >= chain.length ||
        !identical(chain[index], member)) {
      return false;
    }
    return _deliveredOthers?[phase]?.contains(index) ?? false;
  }

  /// 把 [old] 的已投递记录吸收进本序列（重根/迁移；owner 身份可能变化，
  /// 位图逐位换算回通用记录）。[keepMember] 过滤仍在新链上的成员。
  void absorbDeliveredFrom(
    _PointerSequence old, {
    bool Function(ElEventDispatcher member)? keepMember,
  }) {
    if ((old._deliveredOwnerLowMask != 0 || old._deliveredOwnerHighMask != 0) &&
        (keepMember?.call(old.owner) ?? true)) {
      for (final phase in ElEventPhase.values) {
        if (old.wasDelivered(phase, old.owner)) markDelivered(phase, old.owner);
      }
    }
    final others = old._deliveredOthers;
    if (others != null) {
      for (final entry in others.entries) {
        for (final index in entry.value) {
          if (index < 0 || index >= old.chain.length) continue;
          final member = old.chain[index];
          if (keepMember?.call(member) ?? true) {
            markDelivered(entry.key, member);
          }
        }
      }
    }
  }

  int cyclePhaseCutoff(ElEventPhase phase) =>
      _phaseCutoffLazy?[phase] ?? chain.length;

  void truncateCyclePhase(ElEventPhase phase, int cutoff) {
    final map = _phaseCutoffLazy ??= <ElEventPhase, int>{};
    final current = map[phase];
    if (current == null || cutoff < current) map[phase] = cutoff;
  }

  int indexOf(ElEventDispatcher member) {
    for (var i = 0; i < chain.length; i++) {
      if (identical(chain[i], member)) return i;
    }
    return -1;
  }

  bool contains(ElEventDispatcher member) => indexOf(member) >= 0;

  /// 已知链索引时以 O(1) 判断成员是否仍持有本 pointer。
  bool memberActiveAt(int index) {
    if (index < 0 || index >= chainCutoff || index >= chain.length) {
      return false;
    }
    final eager = eagerMember;
    return eager == null || identical(eager, chain[index]);
  }

  /// 指定 phase 家族对成员 [index] 是否已被截断。
  bool blockedAt(ElEventPhase phase, int index) {
    if (index >= chainCutoff) return true;
    final eager = eagerMember;
    if (eager != null && !identical(chain[index], eager)) return true;
    if (eagerCancelsSelfTap &&
        identical(chain[index], eager) &&
        _isTapActivationPhase(phase)) {
      return true;
    }
    if (index >= primaryGestureCutoff && _isPrimaryGesturePhase(phase)) {
      // [ElDragProxy] roster 成员在 primaryGestureCutoff 截断上豁免——只有
      // 这一条豁免，eager 仍严格生效（上面的 return true 已优先执行）。
      if (pipelineExemptMembers?.contains(chain[index]) != true) return true;
    }
    if (index >= tapCutoff && _isTapUpSequencePhase(phase)) return true;
    if (index >= tapOnlyCutoff && phase == ElEventPhase.tap) return true;
    if (index >= dragRouteCutoff && _isDragPhase(phase)) return true;
    if (index >= scaleRouteCutoff && _isScalePhase(phase)) return true;
    if (index >= panZoomRouteCutoff && _isPanZoomPhase(phase)) return true;
    if (index >= cyclePhaseCutoff(phase)) return true;
    return false;
  }

  static bool _isPrimaryGesturePhase(ElEventPhase phase) {
    return switch (phase) {
      ElEventPhase.tapDown ||
      ElEventPhase.tapUp ||
      ElEventPhase.tap ||
      ElEventPhase.doubleTap ||
      ElEventPhase.doubleTapDown ||
      ElEventPhase.tripleTap ||
      ElEventPhase.tripleTapDown ||
      ElEventPhase.longPress ||
      ElEventPhase.dragDown ||
      ElEventPhase.dragStart ||
      ElEventPhase.dragUpdate ||
      ElEventPhase.dragEnd ||
      ElEventPhase.dragCancel => true,
      _ => false,
    };
  }

  static bool _isTapActivationPhase(ElEventPhase phase) {
    return switch (phase) {
      ElEventPhase.tap ||
      ElEventPhase.doubleTap ||
      ElEventPhase.doubleTapDown ||
      ElEventPhase.tripleTap ||
      ElEventPhase.tripleTapDown => true,
      _ => false,
    };
  }

  static bool _isDragPhase(ElEventPhase phase) {
    return switch (phase) {
      ElEventPhase.dragDown ||
      ElEventPhase.dragStart ||
      ElEventPhase.dragUpdate ||
      ElEventPhase.dragEnd ||
      ElEventPhase.dragCancel => true,
      _ => false,
    };
  }

  static bool _isTapUpSequencePhase(ElEventPhase phase) {
    return switch (phase) {
      ElEventPhase.tapUp ||
      ElEventPhase.tap ||
      ElEventPhase.doubleTap ||
      ElEventPhase.doubleTapDown ||
      ElEventPhase.tripleTap ||
      ElEventPhase.tripleTapDown ||
      ElEventPhase.longPress ||
      ElEventPhase.tapCancel => true,
      _ => false,
    };
  }

  static bool _isScalePhase(ElEventPhase phase) {
    return switch (phase) {
      ElEventPhase.scaleStart ||
      ElEventPhase.scaleUpdate ||
      ElEventPhase.scaleEnd ||
      ElEventPhase.scaleCancel => true,
      _ => false,
    };
  }

  static bool _isPanZoomPhase(ElEventPhase phase) {
    return switch (phase) {
      ElEventPhase.pointerPanZoomStart ||
      ElEventPhase.pointerPanZoomUpdate ||
      ElEventPhase.pointerPanZoomEnd => true,
      _ => false,
    };
  }

  /// 把源点 stop 转译为向后生效的序列/家族边界；其余 phase 只截断本轮。
  void applyStopPropagation(ElEventPhase phase, int stopperIndex) {
    final cutoff = stopperIndex + 1;
    // 无论家族规则如何，本轮 cycle 内更外层成员的同 phase 自发 fire 一律
    // 抑制（对齐旧实现"stopPropagation 后继续打标记"的每事件去重语义）。
    truncateCyclePhase(phase, cutoff);
    switch (phase) {
      case ElEventPhase.pointerDown:
        if (cutoff < chainCutoff) {
          chainCutoff = cutoff;
          for (var i = cutoff; i < chain.length; i++) {
            chain[i]._suppressSequenceSilently(this);
          }
        }
      case ElEventPhase.tapDown ||
          ElEventPhase.doubleTapDown ||
          ElEventPhase.tripleTapDown ||
          ElEventPhase.tapUp:
        if (cutoff < tapCutoff) {
          tapCutoff = cutoff;
          for (var i = cutoff; i < chain.length; i++) {
            chain[i]._suppressTapChain(this);
          }
        }
      case ElEventPhase.tap:
        if (cutoff < tapOnlyCutoff) tapOnlyCutoff = cutoff;
      case ElEventPhase.dragDown || ElEventPhase.dragStart:
        if (cutoff < dragRouteCutoff) {
          dragRouteCutoff = cutoff;
          for (var i = cutoff; i < chain.length; i++) {
            chain[i]._suppressDragSilently(this);
          }
        }
      case ElEventPhase.scaleStart:
        if (cutoff < scaleRouteCutoff) scaleRouteCutoff = cutoff;
      case ElEventPhase.pointerPanZoomStart:
        if (cutoff < panZoomRouteCutoff) panZoomRouteCutoff = cutoff;
      default:
        break;
    }
  }

  /// eagerGesture：序列坍缩为 [member] 独占。
  void claimEager(
    ElEventDispatcher member, {
    int? memberIndex,
    bool cancelSelfTap = false,
    bool allowScaleUpgrade = false,
    Object? originalEvent,
  }) {
    final current = eagerMember;
    if (current != null) {
      if (!identical(current, member)) return;
      if (!cancelSelfTap || eagerCancelsSelfTap) return;
      // 同 winner 的唯一可升级状态：取消 tap 资格只允许 false → true。
      eagerCancelsSelfTap = true;
      member._tapMachine?._suppressTapActivationForEager(
        this,
        reason: ElEventCancelReason.selfGestureAccepted,
        originalEvent: originalEvent,
      );
      return;
    }
    final index = memberIndex ?? indexOf(member);
    if (!memberActiveAt(index) || !identical(chain[index], member)) return;
    final passivePipeline = member._passiveDragPipeline;
    member._dragMachine?._dissolvePipeline();
    if (passivePipeline?.active == true) {
      passivePipeline!.driver._dragMachine?._dissolvePipeline();
    }
    // 先写 winner，确保 loser 终态回调重入时无法反抢。
    eagerMember = member;
    eagerCancelsSelfTap = cancelSelfTap;
    scaleWon = false;
    final upgradeTarget = allowScaleUpgrade ? resolveScaleTracker() : null;
    scaleUpgradeTarget = upgradeTarget;
    if (cancelSelfTap) {
      member._tapMachine?._suppressTapActivationForEager(
        this,
        reason: ElEventCancelReason.selfGestureAccepted,
        originalEvent: originalEvent,
      );
    }
    for (var otherIndex = 0; otherIndex < chain.length; otherIndex++) {
      final other = chain[otherIndex];
      if (identical(other, member)) continue;
      final previousImmediate = other._terminalFiresImmediate;
      other._terminalFiresImmediate = true;
      try {
        other._cancelSequenceForEagerLoss(
          this,
          memberIndex: otherIndex,
          originalEvent: originalEvent,
          preserveScale: identical(other, upgradeTarget),
        );
      } finally {
        other._terminalFiresImmediate = previousImmediate;
      }
    }
  }

  /// DragProxy 复合管线成立时只取消 Tap 激活，不坍缩管线成员的 Drag 生命周期。
  void cancelTapActivationsForDragPipeline(
    PointerEvent event,
    ElEventDispatcher driver,
  ) {
    for (final member in chain) {
      member._tapMachine?._suppressTapActivationForEager(
        this,
        reason: identical(member, driver)
            ? ElEventCancelReason.selfGestureAccepted
            : ElEventCancelReason.otherGestureAccepted,
        originalEvent: event,
      );
    }
  }

  /// 侧键家族 tracker：最内层有任一该按键回调的成员。
  ElEventDispatcher? sideTrackerFor(int buttonMask) {
    return _sideTrackers.putIfAbsent(buttonMask, () {
      for (final member in chain) {
        if (member._subscribesSideButton(buttonMask)) return member;
      }
      return null;
    });
  }

  ElEventDispatcher? resolveScaleTracker() {
    if (scaleTrackerResolved) return scaleTracker;
    scaleTrackerResolved = true;
    for (final member in chain) {
      if (member._needsScaleShape(member._event)) {
        scaleTracker = member;
        return member;
      }
    }
    return null;
  }
}

/// pointer → 序列 的全局注册表 + 唯一的 PointerRemoved 全局路由。
abstract final class _PointerSequenceRegistry {
  static final Map<int, _PointerSequence> _sequences =
      <int, _PointerSequence>{};
  static bool _globalRouteRegistered = false;

  static _PointerSequence? of(int pointer) => _sequences[pointer];

  static List<_PointerSequence> snapshotFor(ElEventDispatcher dispatcher) =>
      <_PointerSequence>[
        for (final sequence in _sequences.values)
          if (sequence.contains(dispatcher)) sequence,
      ];

  /// Scroll 等 winner 或活动分账管线截断后代时，把第二指接到首指保留的 Scale shadow。
  ///
  /// 仅多指 down 慢路径扫描：新序列必须仍命中同一个 eager winner 或管线
  /// driver/roster，落点仍在原 Scale 宿主几何内，且 raw down 没有产生另一
  /// eager winner。shadow 只恢复已不在新命中链的 target，绝不绕过 eager 归属。
  /// 这里只写 shadow 标量，不篡改冻结 chain，也不建立 cluster/router。
  static ElEventDispatcher? attachReservedScaleTarget(
    _PointerSequence seq,
    PointerDownEvent event,
  ) {
    if (_sequences.length <= 1) return null;
    for (final candidate in _sequences.values) {
      if (identical(candidate, seq)) continue;
      final target = candidate.scaleUpgradeTarget;
      final targetPipeline =
          target?._passiveDragPipeline ?? target?._dragMachine?._pipeline;
      final winner =
          candidate.eagerMember ??
          (targetPipeline?.active == true ? targetPipeline!.driver : null);
      if (target == null ||
          winner == null ||
          seq.eagerMember != null ||
          seq.contains(target)) {
        continue;
      }
      ElEventDispatcher? routedMember = seq.contains(winner) ? winner : null;
      if (routedMember == null && targetPipeline?.active == true) {
        for (final member in targetPipeline!.roster) {
          if (!seq.contains(member)) continue;
          routedMember = member;
          break;
        }
      }
      if (routedMember == null) continue;
      if (!target._owner.attached ||
          target.disabled ||
          !target._owner.hasSize) {
        continue;
      }
      if (!target._needsScaleShape(target._event)) continue;
      final localPosition = target._owner.globalToLocal(event.position);
      if (!(Offset.zero & target._owner.size).contains(localPosition)) continue;
      final routedIndex = seq.indexOf(routedMember);
      if (routedIndex < 0) continue;
      seq.scaleTracker = target;
      seq.scaleTrackerResolved = true;
      seq.scaleUpgradeTarget = target;
      seq.scaleShadowTarget = target;
      return target;
    }
    return null;
  }

  static int debugCountFor(ElEventDispatcher dispatcher) {
    var count = 0;
    for (final seq in _sequences.values) {
      if (seq.contains(dispatcher) ||
          identical(seq.scaleShadowTarget, dispatcher)) {
        count++;
      }
    }
    return count;
  }

  static _PointerSequence claim(
    ElEventDispatcher owner,
    PointerEvent event, {
    required bool isPanZoom,
  }) {
    final existing = _sequences[event.pointer];
    if (existing != null) {
      // pointer id 复用或 owner 死亡后残留：静默清掉旧序列再认领。
      release(existing, silently: true);
    }
    final chain = owner._collectChain();
    final seq = _PointerSequence(
      pointer: event.pointer,
      kind: event.kind,
      device: event.device,
      owner: owner,
      chain: chain,
    )..isPanZoom = isPanZoom;
    _sequences[event.pointer] = seq;
    for (final member in chain) {
      if (!isPanZoom) member._activeSequenceCount++;
    }
    _ensureGlobalRoute();
    return seq;
  }

  /// 序列重根：同一个 down 事件先到达了外层 dispatcher（人为分发顺序或部分
  /// 命中路径），更内层 dispatcher 随后到达时接管所有权。
  ///
  /// 普通祖先重根保留父链；透明命中的并列分支合并候选，共同祖先不重复投递。
  /// 截断位置按成员身份映射，避免把另一分支误当成更深的父链而丢弃旧候选。
  static _PointerSequence reroot(
    ElEventDispatcher newOwner,
    _PointerSequence old,
  ) {
    final nextChain = newOwner._collectChain();
    // 透明命中层和页面是并列分支，不能用后命中的页面覆盖先命中的手势候选。
    // 共同祖先仍只保留一次；普通祖先重根继续使用原来的线性父链。
    final chain = nextChain.contains(old.owner)
        ? nextChain
        : <ElEventDispatcher>[
            ...old.chain.where((member) => !nextChain.contains(member)),
            ...nextChain,
          ];
    final seq =
        _PointerSequence(
            pointer: old.pointer,
            kind: old.kind,
            device: old.device,
            owner: chain.first,
            chain: chain,
          )
          ..isPanZoom = old.isPanZoom
          ..canonicalDown = old.canonicalDown
          ..hasTrackedDrag = old.hasTrackedDrag
          ..eagerMember = old.eagerMember
          ..eagerCancelsSelfTap = old.eagerCancelsSelfTap
          ..scaleUpgradeTarget = old.scaleUpgradeTarget
          ..scaleWon = old.scaleWon
          ..scaleShadowTarget = old.scaleShadowTarget
          ..scaleTracker = old.scaleTracker
          ..scaleTrackerResolved = old.scaleTrackerResolved;
    int remap(int cutoff) => cutoff >= old.chain.length
        ? chain.length
        : chain.indexOf(old.chain[cutoff]);
    seq.chainCutoff = remap(old.chainCutoff);
    seq.primaryGestureCutoff = remap(old.primaryGestureCutoff);
    seq.tapCutoff = remap(old.tapCutoff);
    seq.tapOnlyCutoff = remap(old.tapOnlyCutoff);
    seq.dragRouteCutoff = remap(old.dragRouteCutoff);
    seq.scaleRouteCutoff = remap(old.scaleRouteCutoff);
    seq.panZoomRouteCutoff = remap(old.panZoomRouteCutoff);
    seq.absorbDownFedFrom(old);
    seq.absorbObservedDragStartRoutesFrom(old);
    seq.sawSideButtons = old.sawSideButtons;
    seq._cycleEvent = old._cycleEvent;
    seq.absorbDeliveredFrom(old);
    final oldCutoffs = old._phaseCutoffLazy;
    if (oldCutoffs != null && oldCutoffs.isNotEmpty) {
      final map = seq._phaseCutoffLazy ??= <ElEventPhase, int>{};
      oldCutoffs.forEach((phase, cutoff) {
        map[phase] = remap(cutoff);
      });
    }
    // 迁移管线豁免成员：reroot 通常发生在 down 阶段（尚无管线），空转是常态；
    // 但一旦上游流程改变，防御性拷贝更稳。
    final exempt = old.pipelineExemptMembers;
    if (exempt != null && exempt.isNotEmpty) {
      seq.pipelineExemptMembers = HashSet<ElEventDispatcher>.identity()
        ..addAll(exempt);
    }
    for (final member in old.chain) {
      if (!old.isPanZoom) member._activeSequenceCount--;
    }
    _sequences[old.pointer] = seq;
    for (final member in chain) {
      if (!old.isPanZoom) member._activeSequenceCount++;
    }
    return seq;
  }

  static void release(_PointerSequence seq, {bool silently = false}) {
    final current = _sequences[seq.pointer];
    if (!identical(current, seq)) return;
    assert(
      silently || seq.outstandingDragStartFamilies == 0,
      '公开 DragStart 必须在序列释放前结清终态。',
    );
    _sequences.remove(seq.pointer);
    for (final member in seq.chain) {
      if (!seq.isPanZoom) member._activeSequenceCount--;
      if (silently) member._suppressSequenceSilently(seq);
    }
    final shadow = seq.scaleShadowTarget;
    if (silently && shadow != null && !seq.contains(shadow)) {
      shadow._suppressSequenceSilently(seq);
    }
  }

  /// 成员处理完终态事件（up / cancel / panZoomEnd）后调用。
  ///
  /// 最外层成员处理完（或全部成员都已见过终态）→ 同步释放（单成员链 up 后
  /// 立即归零，宿主/latch 依赖这一同步性）；否则排一个微任务兜底，覆盖
  /// "更外层成员不在 hit-test path、终态永远不会到它"的情况。
  static void memberSawTerminal(
    _PointerSequence seq,
    ElEventDispatcher member,
  ) {
    // 最外层成员见终态 → 直接释放（单成员链的 up 常态零集合触碰）。
    if (identical(member, seq.chain.last)) {
      release(seq);
      return;
    }
    seq.terminalSeenMembers.add(member);
    if (seq.terminalSeenMembers.length >= seq.chain.length) {
      release(seq);
      return;
    }
    if (!seq.releaseScheduled) {
      seq.releaseScheduled = true;
      scheduleMicrotask(() => release(seq));
    }
  }

  /// dispatcher dispose / detach 时清理其参与的全部序列。
  ///
  /// owner 死亡时若链上仍有存活祖先，序列提升到最近祖先继续；否则整条
  /// 序列静默终结。普通成员死亡 → 仅该成员自身状态已由 dispose/detach 清理，
  /// 序列继续（投递时按 attached 状态跳过）。
  static void evict(ElEventDispatcher dispatcher) {
    if (_sequences.isEmpty) return;
    for (final seq in _sequences.values) {
      if (identical(seq.scaleTracker, dispatcher)) {
        seq.scaleTracker = null;
        seq.scaleTrackerResolved = true;
      }
      if (identical(seq.scaleUpgradeTarget, dispatcher)) {
        seq.scaleUpgradeTarget = null;
      }
      // eager winner 离场后保留其 identity 作为失效墓碑，直到 pointer terminal；
      // 清空 winner 会让已经淘汰的旧成员在同一序列中复活。
      if (identical(seq.eagerMember, dispatcher)) {
        seq.scaleUpgradeTarget = null;
        seq.scaleWon = false;
      }
      if (identical(seq.scaleShadowTarget, dispatcher)) {
        seq.scaleShadowTarget = null;
      }
    }
    final owned = <_PointerSequence>[
      for (final seq in _sequences.values)
        if (identical(seq.owner, dispatcher)) seq,
    ];
    for (final seq in owned) {
      if (!_promoteOwnedSequence(seq, dispatcher)) {
        release(seq, silently: true);
      }
    }
  }

  /// [evictedOwner] 死亡后，本序列是否仍有存活祖先能接手继续。
  ///
  /// 用于区分"宿主换手、指针还按着"与"链上真的没人了"：前者不得结算终态。
  static bool hasSurvivingAncestor(
    _PointerSequence seq,
    ElEventDispatcher evictedOwner,
  ) => _nextOwnerAfter(seq, evictedOwner) != null;

  static ElEventDispatcher? _nextOwnerAfter(
    _PointerSequence seq,
    ElEventDispatcher evictedOwner,
  ) {
    for (var i = 1; i < seq.chain.length; i++) {
      final candidate = seq.chain[i];
      if (identical(candidate, evictedOwner)) continue;
      if (!candidate._owner.attached || candidate.disabled) continue;
      return candidate;
    }
    return null;
  }

  static bool _promoteOwnedSequence(
    _PointerSequence old,
    ElEventDispatcher evictedOwner,
  ) {
    if (!identical(_sequences[old.pointer], old)) return true;
    final nextOwner = _nextOwnerAfter(old, evictedOwner);
    if (nextOwner == null) return false;

    final chain = nextOwner._collectChain();
    if (chain.isEmpty) return false;
    final next =
        _PointerSequence(
            pointer: old.pointer,
            kind: old.kind,
            device: old.device,
            owner: nextOwner,
            chain: chain,
          )
          ..isPanZoom = old.isPanZoom
          ..canonicalDown = old.canonicalDown
          ..hasTrackedDrag = old.hasTrackedDrag
          ..eagerCancelsSelfTap = old.eagerCancelsSelfTap
          ..scaleUpgradeTarget = old.scaleUpgradeTarget
          ..scaleWon = old.scaleWon
          ..chainCutoff = _remapCutoff(old, chain, old.chainCutoff)
          ..primaryGestureCutoff = _remapCutoff(
            old,
            chain,
            old.primaryGestureCutoff,
          )
          ..tapCutoff = _remapCutoff(old, chain, old.tapCutoff)
          ..tapOnlyCutoff = _remapCutoff(old, chain, old.tapOnlyCutoff)
          ..dragRouteCutoff = _remapCutoff(old, chain, old.dragRouteCutoff)
          ..scaleRouteCutoff = _remapCutoff(old, chain, old.scaleRouteCutoff)
          ..panZoomRouteCutoff = _remapCutoff(
            old,
            chain,
            old.panZoomRouteCutoff,
          )
          ..releaseScheduled = old.releaseScheduled
          .._cycleEvent = old._cycleEvent
          ..scaleShadowTarget = old.scaleShadowTarget;

    final shadow = next.scaleShadowTarget;
    // winner 不在提升后的链中时仍保留为墓碑；新 owner 只负责接住 terminal，
    // 不得让旧 loser 恢复 raw 或语义事件。
    next.eagerMember = old.eagerMember;
    if (next.eagerMember == null) {
      next.eagerCancelsSelfTap = false;
      next.scaleUpgradeTarget = null;
      next.scaleWon = false;
      shadow?._scaleMachine?.feedRemoved(old.pointer);
      next.scaleShadowTarget = null;
    } else if (!_containsDispatcher(chain, next.eagerMember) &&
        !identical(next.eagerMember, shadow)) {
      next.scaleUpgradeTarget = null;
      next.scaleWon = false;
    } else if (!_containsDispatcher(chain, next.scaleUpgradeTarget) &&
        !identical(next.scaleUpgradeTarget, shadow)) {
      next.scaleUpgradeTarget = null;
    }
    next.absorbDownFedFrom(
      old,
      keepMember: (member) => _containsDispatcher(chain, member),
    );
    next.absorbObservedDragStartRoutesFrom(
      old,
      keepMember: (member) => _containsDispatcher(chain, member),
    );
    final oldTerm = old._terminalSeen;
    if (oldTerm != null && oldTerm.isNotEmpty) {
      next.terminalSeenMembers.addAll(
        oldTerm.where((member) => _containsDispatcher(chain, member)),
      );
    }
    next.sawSideButtons = old.sawSideButtons;

    next.absorbDeliveredFrom(
      old,
      keepMember: (member) => _containsDispatcher(chain, member),
    );
    final oldCutoffsP = old._phaseCutoffLazy;
    if (oldCutoffsP != null && oldCutoffsP.isNotEmpty) {
      final map = next._phaseCutoffLazy ??= <ElEventPhase, int>{};
      oldCutoffsP.forEach((phase, cutoff) {
        map[phase] = _remapCutoff(old, chain, cutoff);
      });
    }

    final exempt = old.pipelineExemptMembers;
    if (exempt != null && exempt.isNotEmpty) {
      final kept = exempt
          .where((member) => _containsDispatcher(chain, member))
          .toList(growable: false);
      if (kept.isNotEmpty) {
        next.pipelineExemptMembers = HashSet<ElEventDispatcher>.identity()
          ..addAll(kept);
      }
    }

    final oldSideTrackers = old._sideTrackersLazy;
    if (oldSideTrackers != null && oldSideTrackers.isNotEmpty) {
      for (final entry in oldSideTrackers.entries) {
        final tracker = entry.value;
        next._sideTrackers[entry.key] = _containsDispatcher(chain, tracker)
            ? tracker
            : null;
      }
    }
    next.scaleTracker =
        _containsDispatcher(chain, old.scaleTracker) ||
            identical(old.scaleTracker, next.scaleShadowTarget)
        ? old.scaleTracker
        : null;
    next.scaleTrackerResolved =
        old.scaleTrackerResolved &&
        (old.scaleTracker == null || next.scaleTracker != null);

    for (final member in old.chain) {
      if (!old.isPanZoom) member._activeSequenceCount--;
    }
    _sequences[old.pointer] = next;
    for (final member in chain) {
      if (!old.isPanZoom) member._activeSequenceCount++;
    }
    return true;
  }

  static int _remapCutoff(
    _PointerSequence old,
    List<ElEventDispatcher> chain,
    int oldCutoff,
  ) {
    if (oldCutoff <= 0) return 0;
    for (var i = 0; i < chain.length; i++) {
      final oldIndex = old.indexOf(chain[i]);
      if (oldIndex < 0 || oldIndex >= oldCutoff) return i;
    }
    return chain.length;
  }

  static bool _containsDispatcher(
    List<ElEventDispatcher> chain,
    ElEventDispatcher? dispatcher,
  ) {
    if (dispatcher == null) return false;
    for (final member in chain) {
      if (identical(member, dispatcher)) return true;
    }
    return false;
  }

  static void debugReset() {
    for (final seq in _sequences.values.toList(growable: false)) {
      release(seq, silently: true);
    }
  }

  static void _ensureGlobalRoute() {
    if (_globalRouteRegistered) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(
      _handleGlobalPointerEvent,
    );
    _globalRouteRegistered = true;
  }

  /// PointerRemovedEvent 不走 hit-test path，只能经全局路由捕获。
  static void _handleGlobalPointerEvent(PointerEvent event) {
    if (event is! PointerRemovedEvent) return;
    final pointer = _resolveRemovedPointer(event);
    final seq = _sequences[pointer];
    if (seq == null) return;
    _DispatchCycle.run(() {
      seq.beginCycle();
      final resolved = _removedEventForPointer(event, pointer);
      for (final member in seq.chain) {
        member._feedRemoved(seq, resolved);
      }
      _DispatchCycle.flushNow();
      seq.owner._settleOutstandingDragTerminals(seq, resolved, canceled: true);
      final shadow = seq.scaleShadowTarget;
      if (shadow != null && !seq.contains(shadow)) {
        shadow._scaleMachine?.feedRemoved(pointer);
      }
      release(seq);
    });
  }

  /// 平台在触摸序列中途 detach 输入设备时（如 Android TalkBack 切换），
  /// PointerRemovedEvent 可能带 pointer 0 而非活跃指针 id；在恰好只有一条
  /// 采样器在场的单指 touch 拖拽序列时，把它映射到该序列。
  ///
  /// **device 必须匹配**（实机多指丢滚动根因，2026-07-06）：Android 每根手指
  /// 抬起后引擎都会补发设备级 remove（framework 里 pointer 恒 0，device 是该
  /// 手指的 MotionEvent pointer id）。一指拖拽中第二指点击 → 第二指的序列已随
  /// up 释放、拖拽机器也回到单指状态 → 第二指的 remove(pointer:0, device:1)
  /// 恰好满足"单条采样中单指 touch 拖拽序列"启发式 → 被误映射到**第一指**的
  /// 活跃序列并把它整条 release —— 第一指从此完全失联（"释放第二指后第一指
  /// 无法再触发"）。remove 只允许落到同 device 的序列上。
  static int _resolveRemovedPointer(PointerRemovedEvent event) {
    if (_sequences.containsKey(event.pointer)) return event.pointer;
    if (event.kind != PointerDeviceKind.touch || event.pointer != 0) {
      return event.pointer;
    }
    _PointerSequence? candidate;
    for (final seq in _sequences.values) {
      if (seq.kind != PointerDeviceKind.touch) continue;
      if (seq.device != event.device) continue;
      final hasResampledTouchDrag = seq.chain.any(
        (member) => member._dragMachine?._dragResampler != null,
      );
      if (!hasResampledTouchDrag) continue;
      if (candidate != null) return event.pointer; // 多个候选 → 放弃映射
      candidate = seq;
    }
    return candidate?.pointer ?? event.pointer;
  }

  static PointerRemovedEvent _removedEventForPointer(
    PointerRemovedEvent event,
    int pointer,
  ) {
    if (event.pointer == pointer) return event;
    return PointerRemovedEvent(
      viewId: event.viewId,
      timeStamp: event.timeStamp,
      pointer: pointer,
      kind: event.kind,
      device: event.device,
      position: event.position,
      obscured: event.obscured,
      pressureMin: event.pressureMin,
      pressureMax: event.pressureMax,
      distanceMax: event.distanceMax,
      radiusMin: event.radiusMin,
      radiusMax: event.radiusMax,
      embedderId: event.embedderId,
      original: event.original is PointerRemovedEvent
          ? event.original! as PointerRemovedEvent
          : event,
    );
  }
}

/// 一次事件处理周期：状态机先完成全部状态迁移并把语义事件入队，
/// 周期末尾统一 flush 执行用户回调。
///
/// 用户回调内的重入（set event / 再触发手势路径）会进入**同一**周期：
/// 状态机此刻不在迁移中途，重入天然安全 —— 旧实现散布 ~30 处的
/// `_eventUnchanged` revision 检查由此整体删除。
final class _DispatchCycle {
  _DispatchCycle._();

  static _DispatchCycle? _current;

  static bool get isActive => _current != null;

  /// 顶层 cycle 复用单例：_queue 经 clear 保留容量，稳态每平台事件零分配
  /// （旧实现每次 run 新建 cycle 对象 + 队列 List）。单线程 + 顶层唯一保证
  /// 无并用；异常路径在 finally 清队列防串。
  static final _DispatchCycle _rootCycle = _DispatchCycle._();

  final List<_QueuedDelivery> _queue = <_QueuedDelivery>[];
  List<void Function()> _afterCycle = <void Function()>[];
  bool _flushing = false;

  /// 入口包装：handleEvent / 定时器 / cancelAllPending / set event。
  static void run(void Function() body) {
    final existing = _current;
    if (existing != null) {
      body();
      return;
    }
    final cycle = _current = _rootCycle;
    List<void Function()> notifications = const <void Function()>[];
    try {
      body();
      cycle._flush();
      // 先转移通知并清空单例，再退出当前周期，通知中的重入可安全复用单例。
      if (cycle._afterCycle.isNotEmpty) {
        notifications = cycle._afterCycle;
        cycle._afterCycle = <void Function()>[];
      }
    } finally {
      _current = null;
      if (cycle._queue.isNotEmpty) cycle._queue.clear();
      cycle._afterCycle.clear();
      cycle._flushing = false;
    }
    for (final notify in notifications) {
      notify();
    }
  }

  /// 状态位同步更新，但副作用通知须等机器迁移及旧语义终态投递完毕。
  static void afterCurrentCycle(void Function() action) {
    final cycle = _current;
    if (cycle == null) {
      action();
      return;
    }
    cycle._afterCycle.add(action);
  }

  static void enqueue(_QueuedDelivery delivery) {
    final cycle = _current;
    assert(cycle != null, 'ElEvent fire outside of a _DispatchCycle');
    if (cycle == null) {
      // 理论不可达的兜底：直接同步执行。
      delivery.deliver();
      return;
    }
    cycle._queue.add(delivery);
    if (cycle._flushing) return; // flush 循环会继续消费新入队项
  }

  /// 立即排空当前队列。
  ///
  /// 逐成员喂送时使用：成员 i 的语义事件（含 eagerGesture / stopPropagation
  /// 效果）必须在成员 i+1 的 raw 投递与状态机喂送**之前**生效——对齐旧模型
  /// "子节点完整处理后祖先才收到原生分发"的跨成员次序。
  static void flushNow() {
    final cycle = _current;
    if (cycle == null || cycle._flushing) return;
    cycle._flush();
  }

  void _flush() {
    _flushing = true;
    var index = 0;
    while (index < _queue.length) {
      final d = _queue[index];
      d.deliver();
      index++;
    }
    _queue.clear();
    _flushing = false;
  }
}

/// 已入队的语义事件投递。
final class _QueuedDelivery {
  _QueuedDelivery({
    required this.firer,
    required this.phase,
    required this.callback,
    required this.seq,
    required this.firerIndex,
    required this.selfOnly,
    required this.handler,
    required this.generation,
    required this.config,
    this.pipeline,
    this.onDropped,
  });

  final ElEventDispatcher firer;
  final ElEventPhase phase;
  final ElEventCallback callback;
  final _PointerSequence? seq;

  /// 触发者在冻结序列链中的索引；无序列投递为 -1。
  final int firerIndex;

  /// 仅投递给触发者自身（侧键 / longPress / dragUpdate 等不冒泡 phase）。
  final bool selfOnly;

  /// enqueue 时刻捕获的触发者 handler（对齐旧实现"fire 即同步解析"的时序）。
  final ElEventHandler? handler;

  /// enqueue 时刻触发者的配置代际。flush 时若代际已变（结构替换 / 移除），
  /// 本次投递整体丢弃——对齐旧实现 revision 检查的"替换后不再 fire 到新旧
  /// 配置"语义。
  final int generation;

  /// enqueue 时刻触发者的配置实例。flush 时若实例已被 shape 相等的热替换
  /// 换掉，触发者 handler 改为实时解析（新闭包即刻生效）。
  final ElEvent? config;

  /// enqueue 时刻捕获的 [ElDragProxy] 分账管线快照。
  ///
  /// 仅 dragStart / dragUpdate 阶段可能非空；flush 时若管线仍 [active]，
  /// [_deliverQueued] 用三段包装（pre / main / overflow）执行，否则回退现状路径。
  final _DragPipeline? pipeline;

  /// 投递被代际检查丢弃时的通知（用于 dragStart 的 deferred-dispatch 语义）。
  final void Function()? onDropped;

  /// 投递时应使用的触发者 handler：配置实例未变用入队快照；被热替换则实时解析。
  ElEventHandler? get effectiveHandler =>
      identical(config, firer._event) ? handler : firer._handlerFor(phase);

  void deliver() {
    if (firer._configGeneration != generation) {
      onDropped?.call();
      return;
    }
    // enqueue 后 winner 可能已经收缩序列；执行用户回调前必须重新校验 firer
    // 是否仍持有该 pointer，不能依赖入队时快照。
    final sequence = seq;
    if (sequence != null) {
      if (!firer._memberActiveAt(sequence, firerIndex) ||
          !identical(sequence.chain[firerIndex], firer)) {
        onDropped?.call();
        return;
      }
    }
    firer._deliverQueued(this);
  }
}
