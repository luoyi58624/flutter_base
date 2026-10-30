part of 'selection_core.dart';

abstract interface class SelectionMagnifierHost {
  /// 把 side 端点设置到 [globalPosition] 命中的字符上，另一端不变。
  /// 返回是否真正更新了端点 offset（H5 haptic + H4 抖动过滤据此判断变化）。
  bool setSelectionHandleEndpoint(SelectionHandleSide side, Offset globalPosition);

  /// dragInfo 变化后通知 host 端点几何重算（触发 overlay 上 handle 位置更新）。
  void onDragInfoChanged();

  /// host 端 auto-scroll 拖动 viewport 同步（复用 body drag 的 viewport 列表）。
  void syncDragScrollViewportsForHandleDrag();

  /// 喂位置给 auto-scroll（handle 拖到 viewport 边缘外时触发反向自滚）。
  void updateAutoScrollForHandleDrag(Offset globalPosition);

  /// 停止 auto-scroll + 清 drag viewports（拖动结束时用）。
  void stopAutoScrollAndClearViewports();

  /// 让 host 冲掉 defer 的 selection info（发送最终 notification）。
  void flushDeferredSelectionInfo();

  /// 开始 / 停止 global pointer route（wheel scroll 转发用）。
  void startGlobalPointerRoute();
  void stopGlobalPointerRoute();

  /// **H1** — 当前 side 端点的 caret 底部、行高与 controls 解析的拖动偏移。
  /// 用于计算 touch-through 锚点：`_touchToAnchorOffset = globalPosition − globalBottom`。
  /// 端点不可用（无选区 / 未 mount）时返回 null，controller 走无锚点回退。
  ({Offset globalBottom, double lineHeight, double idealVerticalOffset, double touchOffsetY})? handleAnchorFor(
    SelectionHandleSide side,
  );

  /// **H3** — 获取当前 side 端点的 offset（用于词吸附方向判定）。
  int? handleEndpointOffsetFor(SelectionHandleSide side);

  /// **H5** — handle haptics 是否启用（controls 参数透传）。
  bool get handleHapticsEnabled;

  /// **H4** — 抬手抖动过滤回滚接口：把 side 端点直接设到指定 offset（当前
  /// participant 内）。用 offset 而非 globalPosition 可避开命中查询误差。
  void setHandleEndpointOffset(SelectionHandleSide side, int offset);
}

/// **H4** — 端点 offset 时空历史条目（wall-clock 微秒 + offset）。
class _HandleOffsetHistoryEntry {
  const _HandleOffsetHistoryEntry(this.micros, this.offset);

  final int micros;
  final int offset;
}

// ---- controller -------------------------------------------------------------

/// 移动端 handle 拖动 + magnifier 状态控制器。
///
/// 使用方式（对 host）：
///   - `begin(side, globalPosition, pointer: n)` — pointerDown
///   - `update(globalPosition)` — pointerMove
///   - `end()` — pointerUp/Cancel
///   - `onRoutedPointerRemoved(pointer)` — 全局 pointer removed 检测
///   - `detach()` — 宿主 render detach / dispose 时强制结束会话
class SelectionMagnifierHandleController {
  /// 创建。
  SelectionMagnifierHandleController(this._host);

  final SelectionMagnifierHost _host;

  /// 当前 handle 拖动的 pointer id（null 表示未 route）。
  int? activeHandlePointer;

  /// 当前拖动 info（kind + side + globalPosition）；null 表示无 drag。
  SelectionDragInfo? dragInfo;

  /// 是否正在拖动 handle。
  bool get isHandleDragInProgress => dragInfo?.kind == SelectionDragKind.handle && dragInfo?.side != null;

  /// **T1d** — 距上次同步处理 handle move 的时间戳（微秒）。
  ///
  /// [update] 内根据它判断"是否距上次极近的后续 move"：`> 4ms` → 立即同步处理；
  /// `<= 4ms` → 记 pending + schedule frame callback，让洪泛的 120Hz 采样合帧成一次。
  ///
  /// 语义正确性：pending 只是"洪泛时少算"——任何时刻消费 pending 都等价于把
  /// 选区端点提前拉到最新位置。[end] / 全局 pointer removed 等所有终态入口都
  /// 会同步 [_flushPendingUpdate]，保证抬手前一定应用最新位置。
  int? _lastUpdateSyncMicros;

  /// 待应用的最新 move 位置；null = 无 pending。
  Offset? _pendingUpdatePosition;

  /// 是否已 schedule 过 flush（避免多次 scheduleFrameCallback）。
  bool _flushScheduled = false;

  /// 4ms 窗口：120Hz = 8.3ms/frame，4ms 阈值可捕获同帧多次采样。
  static const int _coalesceWindowMicros = 4000;

  /// **H1** — down 时的"手指→端点 caret 底"偏移。null 表示未取到端点几何时回退
  /// 原行为（直接用手指位置命中）。
  Offset? _touchToAnchorOffset;
  double? _idealVerticalOffset;
  double? _touchOffsetY;

  // ---- H3 词吸附状态 --------------------------------------------------------
  //
  // 词界吸附逻辑移到 host `_handleWordSnappedEndpoint`（可直接访问 registry 与
  // 命中 participant 的 `selectionWordBoundaryAt`）；controller 内不再持吸附状态。

  // ---- H4 抬手抖动过滤 -----------------------------------------------------

  /// **H4** — 端点 offset 历史环 (timestampMicros, participantIndex, offset)。
  /// 抬手时若最后一次变化在 150ms 内 → 回滚到 350ms 之前最近的稳定条目。
  final List<_HandleOffsetHistoryEntry> _offsetHistory = <_HandleOffsetHistoryEntry>[];
  static const int _kOffsetHistoryLimit = 5;
  static const int _kShakeSuppressWindowMicros = 150 * 1000;
  static const int _kShakeStableWindowMicros = 350 * 1000;

  // ---- H5 haptic 帧内去重 --------------------------------------------------

  int? _lastHapticMicros;
  static const int _kHapticCoalesceWindowMicros = 8000;

  /// 手动写 dragInfo（供 host 内 gesture 逻辑写 longPress info 用）。
  ///
  /// 变化时会调 `_host.onDragInfoChanged()`（触发端点重算）。
  void setDragInfo(SelectionDragInfo? info) {
    if (dragInfo == info) return;
    dragInfo = info;
    _host.onDragInfoChanged();
  }

  /// 开始 handle 拖动（UI 层 pointerDown 时调）。
  ///
  /// **H1** — 记录 grab 偏移 `_touchToAnchorOffset = 手指 − 端点 caret 底`；
  /// 后续 move 用它做 touch-through 修正，避免手指按住手柄（行下 ~11px 处）
  /// 直接命中就窜行。端点几何暂不可用（端点 null）时留空，move 走原路径。
  void begin(SelectionHandleSide side, Offset globalPosition, {int? pointer}) {
    _clearActivePointerRoute();
    activeHandlePointer = pointer;
    if (pointer != null) {
      GestureBinding.instance.pointerRouter.addRoute(pointer, _handleRoutedPointerEvent);
    }
    // H1 grab 偏移。
    final anchor = _host.handleAnchorFor(side);
    _touchToAnchorOffset = anchor == null ? null : globalPosition - anchor.globalBottom;
    _idealVerticalOffset = anchor?.idealVerticalOffset;
    _touchOffsetY = anchor?.touchOffsetY;
    // H4 抖动历史复位（首条 = 起始 offset 快照）。
    _offsetHistory.clear();
    final startOffset = _host.handleEndpointOffsetFor(side);
    if (startOffset != null) {
      _offsetHistory.add(_HandleOffsetHistoryEntry(_nowMicros(), startOffset));
    }
    _lastHapticMicros = null;
    setDragInfo(SelectionDragInfo(kind: SelectionDragKind.handle, side: side, globalPosition: globalPosition));
    _host.startGlobalPointerRoute();
    // 复用拖选 viewport 同步：handle 拖到 viewport 边缘外侧时滚动反向回拉也能继续延伸。
    _host.syncDragScrollViewportsForHandleDrag();
    _host.updateAutoScrollForHandleDrag(globalPosition);
  }

  /// handle pointerMove。同时更新选区端点和 magnifier 位置。
  ///
  /// **T1d 合帧**：距上次同步处理 > 4ms → 立即同步（第一个/孤立 move 与旧行为
  /// bit-identical）；<= 4ms → 洪泛后续 move，只记 pending + schedule 一次帧回调
  /// 消费。`end` / `syncEndpointToLastDragPosition` / `_handleRoutedPointerEvent`
  /// 抬手前会同步 [_flushPendingUpdate] 保序。范围决策：**仅 handle 拖动做合帧**，
  /// body 拖动 (`_handlePointerMove`) 因 widget 测试面广（moveTo → assert 时序
  /// 敏感）保守不改；handle 拖动走 PointerRouter 且测试全部 pump 后断言，安全。
  void update(Offset globalPosition) {
    final current = dragInfo;
    if (current == null || current.kind != SelectionDragKind.handle || current.side == null) return;

    final nowMicros = _nowMicros();
    final last = _lastUpdateSyncMicros;
    if (last != null && nowMicros - last <= _coalesceWindowMicros) {
      // 合帧：只记 pending，schedule 一次消费；语义上任何时刻消费都等价于把端点
      // 提前拉到最新位置，正确性不依赖消费时机（`end` 前会同步 flush 保序）。
      _pendingUpdatePosition = globalPosition;
      if (!_flushScheduled) {
        _flushScheduled = true;
        SchedulerBinding.instance.scheduleFrameCallback((_) => _flushPendingUpdate());
      }
      return;
    }

    // 第一个/孤立 move：同步立即处理（与旧行为 bit-identical）。
    _lastUpdateSyncMicros = nowMicros;
    _pendingUpdatePosition = null;
    _applyUpdate(current, globalPosition);
  }

  /// 消费 pending（frame callback 或终态入口同步调）。
  void _flushPendingUpdate() {
    _flushScheduled = false;
    final pending = _pendingUpdatePosition;
    if (pending == null) return;
    _pendingUpdatePosition = null;
    final current = dragInfo;
    if (current == null || current.kind != SelectionDragKind.handle || current.side == null) return;
    _lastUpdateSyncMicros = _nowMicros();
    _applyUpdate(current, pending);
  }

  void _applyUpdate(SelectionDragInfo current, Offset globalPosition) {
    final queryPosition = _touchThroughQueryPosition(globalPosition);
    // H3 词吸附由 host `_handleWordSnappedEndpoint` 消费查询点（同 pattern）。
    final offsetBefore = _host.handleEndpointOffsetFor(current.side!);
    final changed = _host.setSelectionHandleEndpoint(current.side!, queryPosition);
    final offsetAfter = _host.handleEndpointOffsetFor(current.side!);
    // H4 offset 历史环记录（每次 offset 实际变化）。
    if (changed && offsetAfter != null && offsetAfter != offsetBefore) {
      _pushOffsetHistory(offsetAfter);
      // H5 handle drag haptic：offset 变化触发 selectionClick，帧内去重。
      _maybeFireHandleHaptic();
    }
    setDragInfo(SelectionDragInfo(kind: current.kind, side: current.side, globalPosition: globalPosition));
    _host.updateAutoScrollForHandleDrag(globalPosition);
  }

  /// **H1** — 把 raw 手指位置换算成 touch-through 端点查询点：手指 − grab 偏移 +
  /// Offset(0, touchOffsetY)，垂直分量单调向 idealVerticalOffset 收敛（AOSP
  /// HandleView 语义，不回弹）。无锚点（begin 时端点几何不可用）原样返回。
  Offset _touchThroughQueryPosition(Offset globalPosition) {
    final grab = _touchToAnchorOffset;
    final idealVerticalOffset = _idealVerticalOffset;
    final touchOffsetY = _touchOffsetY;
    if (grab == null || idealVerticalOffset == null || touchOffsetY == null) {
      return globalPosition;
    }
    final currentDeltaY = grab.dy;
    // 向 ideal 收敛：新 delta 更接近 ideal 才更新；远离时保持。
    // （ideal 是"手指→锚点"的期望正值距离，锚点=caret 底，即 handle 视觉顶。）
    final adjustedGrabY = (currentDeltaY - idealVerticalOffset).abs() < idealVerticalOffset.abs()
        ? currentDeltaY
        : (currentDeltaY > idealVerticalOffset ? idealVerticalOffset : currentDeltaY);
    _touchToAnchorOffset = Offset(grab.dx, adjustedGrabY);
    return Offset(globalPosition.dx - grab.dx, globalPosition.dy - adjustedGrabY + touchOffsetY);
  }

  void _pushOffsetHistory(int offset) {
    _offsetHistory.add(_HandleOffsetHistoryEntry(_nowMicros(), offset));
    while (_offsetHistory.length > _kOffsetHistoryLimit) {
      _offsetHistory.removeAt(0);
    }
  }

  void _maybeFireHandleHaptic() {
    if (!_host.handleHapticsEnabled) return;
    final now = _nowMicros();
    final last = _lastHapticMicros;
    if (last != null && now - last <= _kHapticCoalesceWindowMicros) return;
    _lastHapticMicros = now;
    unawaited(HapticFeedback.selectionClick());
  }

  static int _nowMicros() {
    // SchedulerBinding.currentSystemFrameTimeStamp 只在 draw frame 内有效；
    // 用 wall clock 微秒差判定 4ms 窗口，独立于 frame 调度状态。
    return DateTime.now().microsecondsSinceEpoch;
  }

  /// 结束 handle 拖动（pointerUp / Cancel）。
  ///
  /// **H4** — 抬手抖动过滤：最后一次 offset 变化在抬手前 150ms 内 → 回滚到
  /// 350ms 之前最近的稳定 offset。
  void end() {
    if (dragInfo?.kind != SelectionDragKind.handle) return;
    // T1d — 抬手前同步 flush 保序：pending 位置一定应用到端点，避免"最后一个
    // move 被合帧掉、抬手 end 直接清 dragInfo → 选区停在倒数第二个位置"。
    _flushPendingUpdate();
    _maybeRollbackShake();
    _clearActivePointerRoute();
    _host.flushDeferredSelectionInfo();
    setDragInfo(null);
    _host.stopGlobalPointerRoute();
    _host.stopAutoScrollAndClearViewports();
    _lastUpdateSyncMicros = null;
    _touchToAnchorOffset = null;
    _idealVerticalOffset = null;
    _touchOffsetY = null;
    _offsetHistory.clear();
    _lastHapticMicros = null;
  }

  void _maybeRollbackShake() {
    if (_offsetHistory.length < 2) return;
    final side = dragInfo?.side;
    if (side == null) return;
    final now = _nowMicros();
    final last = _offsetHistory.last;
    // 最后一次 offset 变化 > 150ms 前 → 稳态，无抖动。
    if (now - last.micros > _kShakeSuppressWindowMicros) return;
    // 找 350ms 之前最近的稳定 entry。
    _HandleOffsetHistoryEntry? stable;
    for (var i = _offsetHistory.length - 1; i >= 0; i--) {
      final entry = _offsetHistory[i];
      if (now - entry.micros >= _kShakeStableWindowMicros) {
        stable = entry;
        break;
      }
    }
    if (stable == null || stable.offset == last.offset) return;
    _host.setHandleEndpointOffset(side, stable.offset);
  }

  /// 全局路由报告的 pointer removed / cancel / up：对应 handle 直接 end。
  ///
  /// 返回是否命中当前 activeHandlePointer（供 host 决定是否吞事件）。
  bool onRoutedPointerRemoved(int pointer) {
    if (activeHandlePointer != pointer) return false;
    end();
    return true;
  }

  /// 把当前 handle sync 到最新 drag global position（滚动时 host 会调）。
  ///
  /// **H1** — 与 [_applyUpdate] 同口径做 touch-through 修正：auto-scroll tick /
  /// 滚动 offset 变化以手指静止的 raw 位置重解析端点时，若绕过修正，查询点会落
  /// 到手柄下方约一行处，端点在两行间逐帧跳变（窜行在滚动路径复发）。
  void syncEndpointToLastDragPosition(Offset? lastDragGlobalPosition) {
    // T1d — 滚动同步前先应用 pending：pending 的位置比 lastDragGlobalPosition
    // 更新（本 controller 内自持），先合并保序。
    _flushPendingUpdate();
    final side = dragInfo?.side;
    if (lastDragGlobalPosition == null || side == null) return;
    _host.setSelectionHandleEndpoint(side, _touchThroughQueryPosition(lastDragGlobalPosition));
  }

  void _handleRoutedPointerEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      update(event.position);
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent || event is PointerRemovedEvent) {
      end();
    }
  }

  void _clearActivePointerRoute() {
    final pointer = activeHandlePointer;
    activeHandlePointer = null;
    if (pointer == null) return;
    GestureBinding.instance.pointerRouter.removeRoute(pointer, _handleRoutedPointerEvent);
  }

  /// 宿主 render detach/dispose 时强制结束在途 handle 会话：摘 per-pointer
  /// route、清拖动瞬态并直写 dragInfo = null。**不回调 host**——detach 发生在
  /// build 中途（子树卸载），onDragInfoChanged 会触发监听方 markNeedsBuild
  /// during build，dispose 路径的 notifier 更是随后就 dispose；宿主自行在安全
  /// 时机同步 dragInfo notifier。也不走 [end] 的抖动回滚 / flush / auto-scroll
  /// 回调——宿主 detach 流程已各自收尾，这里再摸只会碰陈旧几何。
  /// why：route 只有 [end] 会摘，宿主拖拽中被卸载不摘时，抬手事件会经
  /// PointerRouter 回调已 dispose 的 render（use-after-dispose），route 闭包
  /// 还长期持有整棵已卸载 render 树。
  void detach() {
    _clearActivePointerRoute();
    _pendingUpdatePosition = null;
    _lastUpdateSyncMicros = null;
    _touchToAnchorOffset = null;
    _idealVerticalOffset = null;
    _touchOffsetY = null;
    _offsetHistory.clear();
    _lastHapticMicros = null;
    dragInfo = null;
  }
}
