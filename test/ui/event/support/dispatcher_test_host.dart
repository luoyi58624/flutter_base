import 'package:flutter_base/src/ui/event/dispatcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

/// 用最小 RenderBox 链验证事件分发合同，隔离其他组件的行为。
final class DispatcherTestHost {
  DispatcherTestHost._(this._pipelineOwner, this.nodes, this.dispatchers);

  /// 创建一条根到叶的渲染链，索引零为根，末项为最深命中节点。
  factory DispatcherTestHost.chain({
    int depth = 1,
    Size size = const Size(200, 200),
  }) {
    assert(depth > 0);
    final pipelineOwner = PipelineOwner();
    final nodes = List<_DispatcherTestBox>.generate(
      depth,
      (_) => _DispatcherTestBox(),
    );
    for (var index = 0; index < nodes.length - 1; index++) {
      nodes[index].child = nodes[index + 1];
    }
    pipelineOwner.rootNode = nodes.first;
    nodes.first.layout(BoxConstraints.tight(size));
    final dispatchers = <ElEventDispatcher>[
      for (final node in nodes) ElEventDispatcher(node),
    ];
    return DispatcherTestHost._(pipelineOwner, nodes, dispatchers);
  }

  final PipelineOwner _pipelineOwner;

  /// 根到叶排列的渲染节点。
  final List<RenderBox> nodes;

  /// 与 [nodes] 同索引排列的事件分发器。
  final List<ElEventDispatcher> dispatchers;

  /// 根节点的事件分发器。
  ElEventDispatcher get rootDispatcher => dispatchers.first;

  /// 最深命中节点的事件分发器。
  ElEventDispatcher get leafDispatcher => dispatchers.last;

  /// 按真实命中顺序把事件投递到叶到根，并推进 Flutter 的全局指针路由与竞技场。
  void dispatch(PointerEvent event) {
    for (var index = nodes.length - 1; index >= 0; index--) {
      dispatchers[index].handleEvent(
        event,
        BoxHitTestEntry(nodes[index], event.position),
      );
    }
    GestureBinding.instance.pointerRouter.route(event);
    if (event is PointerDownEvent) {
      GestureBinding.instance.gestureArena.close(event.pointer);
    } else if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
      GestureBinding.instance.gestureArena.sweep(event.pointer);
    }
  }

  /// 仅向指定链索引直接投递事件，不触发 PointerRouter 或 gesture arena。
  void direct(int chainIndex, PointerEvent event) {
    RangeError.checkValidIndex(chainIndex, dispatchers, 'chainIndex');
    dispatchers[chainIndex].handleEvent(
      event,
      BoxHitTestEntry(nodes[chainIndex], event.position),
    );
  }

  /// 仅向根 dispatcher 直接投递事件，不推进 Flutter 的全局指针设施。
  void directRoot(PointerEvent event) => direct(0, event);

  /// 仅向最深命中 dispatcher 直接投递事件，不推进 Flutter 的全局指针设施。
  void directLeaf(PointerEvent event) => direct(dispatchers.length - 1, event);

  /// 投递一次完整主键点击，并允许测试显式控制连击窗口时间戳。
  void tap({
    required int pointer,
    required Duration downTime,
    required Duration upTime,
    Offset position = Offset.zero,
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) {
    dispatch(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: kind,
        timeStamp: downTime,
      ),
    );
    dispatch(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: kind,
        timeStamp: upTime,
      ),
    );
  }

  /// 释放 dispatcher 注册和渲染链挂载。
  void dispose() {
    for (final dispatcher in dispatchers.reversed) {
      dispatcher.dispose();
    }
    _pipelineOwner.rootNode = null;
  }
}

/// 测试专用的最小单子 RenderBox。
final class _DispatcherTestBox extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  @override
  void performLayout() {
    child?.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(const Size(200, 200));
  }
}
