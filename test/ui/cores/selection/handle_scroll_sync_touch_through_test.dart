// 回归：滚动同步路径（auto-scroll tick / 滚动 offset 变化）的 handle 端点重解析
// 必须走与 move 路径同口径的 H1 touch-through 修正——手指按在行下方手柄上，
// raw 位置直接命中会落到低约一行处，边缘自动滚动期间端点在两行间逐帧跳变。
import 'package:flutter_base/src/ui/cores/selection/common/selection_core.dart';

import 'package:flutter_test/flutter_test.dart';

/// 记录端点查询点的假 host；anchor 可配以驱动 H1 grab 偏移。
class _RecordingHost implements SelectionMagnifierHost {
  final List<Offset> endpointQueries = <Offset>[];

  ({Offset globalBottom, double lineHeight})? anchor;

  @override
  bool setSelectionHandleEndpoint(SelectionHandleSide side, Offset globalPosition) {
    endpointQueries.add(globalPosition);
    return false;
  }

  @override
  ({Offset globalBottom, double lineHeight, double idealVerticalOffset, double touchOffsetY})? handleAnchorFor(
    SelectionHandleSide side,
  ) {
    final value = anchor;
    if (value == null) return null;
    return (
      globalBottom: value.globalBottom,
      lineHeight: value.lineHeight,
      idealVerticalOffset: 15.4,
      touchOffsetY: -6.6,
    );
  }

  @override
  int? handleEndpointOffsetFor(SelectionHandleSide side) => 0;

  @override
  bool get handleHapticsEnabled => false;

  @override
  void onDragInfoChanged() {}

  @override
  void syncDragScrollViewportsForHandleDrag() {}

  @override
  void updateAutoScrollForHandleDrag(Offset globalPosition) {}

  @override
  void stopAutoScrollAndClearViewports() {}

  @override
  void flushDeferredSelectionInfo() {}

  @override
  void startGlobalPointerRoute() {}

  @override
  void stopGlobalPointerRoute() {}

  @override
  void setHandleEndpointOffset(SelectionHandleSide side, int offset) {}
}

void main() {
  test('滚动同步的端点查询点与 move 路径同口径（H1 修正），不用 raw 手指位置', () {
    final host = _RecordingHost();
    final controller = SelectionMagnifierHandleController(host);

    // 手指按在 caret 底下方 11px 的手柄区（AOSP 典型抓取姿态）。
    const caretBottom = Offset(100, 100);
    const finger = Offset(100, 111);
    host.anchor = (globalBottom: caretBottom, lineHeight: 16);

    controller.begin(.end, finger);
    expect(host.endpointQueries, isEmpty, reason: 'begin 不应触发端点重解析');

    // move 路径：首个 move 同步处理，产出 H1 修正后的查询点。
    controller.update(finger);
    expect(host.endpointQueries, hasLength(1));
    final moveQuery = host.endpointQueries.single;
    // grab = (0, 11)，|11 − 15.4| < 15.4 保持；query = 手指 − grab + (0, −6.6)。
    expect(moveQuery.dx, closeTo(100, 1e-9));
    expect(moveQuery.dy, closeTo(111 - 11 - 0.3 * 22.0, 1e-9));

    // 滚动同步路径（手指静止、内容滚动）：查询点必须与 move 口径一致，
    // 而不是 raw 手指位置（后者落在低约一行处 → 端点两行间跳变）。
    controller.syncEndpointToLastDragPosition(finger);
    expect(host.endpointQueries, hasLength(2));
    final syncQuery = host.endpointQueries.last;
    expect(syncQuery, moveQuery);
    expect(syncQuery, isNot(finger));
  });

  test('无 H1 锚点（begin 时端点几何不可用）滚动同步回退 raw 位置', () {
    final host = _RecordingHost()..anchor = null;
    final controller = SelectionMagnifierHandleController(host);

    const finger = Offset(50, 60);
    controller.begin(.start, finger);
    controller.syncEndpointToLastDragPosition(finger);

    expect(host.endpointQueries.single, finger);
  });
}
