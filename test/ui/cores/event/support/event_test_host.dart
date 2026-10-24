import 'package:flutter_base/src/ui/cores/event/event.dart';
import 'package:flutter_base/src/ui/cores/view/render/index.dart';
import 'package:flutter_base/src/ui/cores/view/style/index.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

/// 用最小 RenderBox 链验证事件分发合同，隔离其他组件的行为。
final class EventTestHost {
  EventTestHost._(this._pipelineOwner, this._nodes);

  /// 创建一条根到叶的渲染链，索引零为根，末项为最深命中节点。
  factory EventTestHost.chain({
    int depth = 1,
    Size size = const Size(200, 200),
  }) {
    assert(depth > 0);
    final pipelineOwner = PipelineOwner();
    final nodes = List<ElRenderView>.generate(
      depth,
      (_) => ElRenderView(ElStyle(), TextDirection.ltr, event: ElEvent()),
    );
    for (var index = 0; index < nodes.length - 1; index++) {
      nodes[index].child = nodes[index + 1];
    }
    pipelineOwner.rootNode = nodes.first;
    nodes.first.layout(BoxConstraints.tight(size));
    return EventTestHost._(pipelineOwner, nodes);
  }

  final PipelineOwner _pipelineOwner;
  bool _disposed = false;

  final List<ElRenderView> _nodes;

  /// 根到叶排列的真实事件宿主。
  List<ElRenderView> get elements => _nodes;

  /// 根节点的事件元素。
  ElRenderView get rootElement => _nodes.first;

  /// 最深命中节点的事件元素。
  ElRenderView get leaf => _nodes.last;

  /// 按真实命中顺序把事件投递到叶到根，并推进 Flutter 的全局指针路由与竞技场。
  Future<void> dispatch(PointerEvent event) async {
    for (var index = _nodes.length - 1; index >= 0; index--) {
      _nodes[index].handleEvent(
        event,
        BoxHitTestEntry(_nodes[index], event.position),
      );
    }
    routeTestPointer(event);
  }

  /// 按指定命中顺序投递，最后到根时推进路由；await 等待官方竞技场微任务结算。
  void direct(int chainIndex, PointerEvent event) {
    RangeError.checkValidIndex(chainIndex, elements, 'chainIndex');
    _nodes[chainIndex].handleEvent(
      event,
      BoxHitTestEntry(_nodes[chainIndex], event.position),
    );
    if (chainIndex == 0) routeTestPointer(event);
  }

  /// 投递根节点并结算整条命中路径的官方路由。
  Future<void> directRoot(PointerEvent event) async => direct(0, event);

  /// 先投递最深节点，仍需投递根节点以结算完整路径。
  void directLeaf(PointerEvent event) => direct(elements.length - 1, event);

  /// 投递一次完整主键点击，并允许测试显式控制连击窗口时间戳。
  Future<void> tap({
    required int pointer,
    required Duration downTime,
    required Duration upTime,
    Offset position = Offset.zero,
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    await dispatch(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: kind,
        timeStamp: downTime,
      ),
    );
    await dispatch(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: kind,
        timeStamp: upTime,
      ),
    );
  }

  /// 释放真实事件元素与渲染链挂载。
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final node in _nodes.reversed) {
      node.dispose();
    }
    _pipelineOwner.rootNode = null;
  }
}

/// 推进真实的官方指针路由与竞技场，不能以直接调用宿主代替手势识别。
void routeTestPointer(PointerEvent event) {
  GestureBinding.instance.pointerRouter.route(event);
  if (event is PointerDownEvent || event is PointerPanZoomStartEvent) {
    GestureBinding.instance.gestureArena.close(event.pointer);
  } else if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
    GestureBinding.instance.gestureArena.sweep(event.pointer);
  }
}

/// 单节点宿主的真实输入入口，多节点命中应先投递整条链再统一路由。
extension EventInputTestExt on ElRenderView {
  Future<void> dispatchInput(PointerEvent event, BoxHitTestEntry entry) async {
    handleEvent(event, entry);
    routeTestPointer(event);
  }
}
