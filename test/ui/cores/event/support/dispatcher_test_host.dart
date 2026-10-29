import 'package:flutter_base/src/ui/cores/view/event/dispatcher.dart' show EventDispatcher;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

/// 用裸 RenderBox 链承载 dispatcher 合同测试，避免把 ElView 的重构状态带入事件基线。
final class DispatcherTestHost {
  DispatcherTestHost._(this._pipelineOwner, this.nodes, this.dispatchers);

  /// 创建一条根到叶的渲染链，索引零为根，末项为最深命中节点。
  factory DispatcherTestHost.chain({int depth = 1, Size size = const Size(200, 200)}) {
    assert(depth > 0);
    final pipelineOwner = PipelineOwner();
    final nodes = List<_DispatcherTestBox>.generate(depth, (_) => _DispatcherTestBox());
    for (var index = 0; index < nodes.length - 1; index++) {
      nodes[index].child = nodes[index + 1];
    }
    pipelineOwner.rootNode = nodes.first;
    nodes.first.layout(BoxConstraints.tight(size));
    final dispatchers = <EventDispatcher>[for (final node in nodes) EventDispatcher(node)];
    return DispatcherTestHost._(pipelineOwner, nodes, dispatchers);
  }

  final PipelineOwner _pipelineOwner;

  /// 根到叶排列的渲染节点。
  final List<RenderBox> nodes;

  /// 与 [nodes] 同索引排列的事件分发器。
  final List<EventDispatcher> dispatchers;

  /// 根节点的事件分发器。
  EventDispatcher get rootDispatcher => dispatchers.first;

  /// 最深命中节点的事件分发器。
  EventDispatcher get leafDispatcher => dispatchers.last;

  /// 按真实命中顺序把事件投递到叶到根，并推进 Flutter 的全局指针路由与竞技场。
  void dispatch(PointerEvent event) {
    for (var index = nodes.length - 1; index >= 0; index--) {
      dispatchers[index].handleEvent(event, BoxHitTestEntry(nodes[index], event.position));
    }
    dispatchTestPointerInput(event);
  }

  /// 仅向指定链索引直接投递事件，不触发 PointerRouter 或 gesture arena。
  void direct(int chainIndex, PointerEvent event) {
    RangeError.checkValidIndex(chainIndex, dispatchers, 'chainIndex');
    dispatchers[chainIndex].handleEvent(event, BoxHitTestEntry(nodes[chainIndex], event.position));
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
    dispatch(PointerDownEvent(pointer: pointer, position: position, kind: kind, timeStamp: downTime));
    dispatch(PointerUpEvent(pointer: pointer, position: position, kind: kind, timeStamp: upTime));
  }

  /// 释放 dispatcher 注册和渲染链挂载。
  void dispose() {
    for (final dispatcher in dispatchers.reversed) {
      dispatcher.dispose();
    }
    _pipelineOwner.rootNode = null;
  }
}

/// 完成真实宿主投递后的官方输入路由与竞技场结算。
void dispatchTestPointerInput(PointerEvent event) {
  final binding = GestureBinding.instance;
  binding.pointerRouter.route(event);
  if (event is PointerDownEvent || event is PointerPanZoomStartEvent) {
    binding.gestureArena.close(event.pointer);
  } else if (event is PointerUpEvent || event is PointerPanZoomEndEvent) {
    binding.gestureArena.sweep(event.pointer);
  } else if (event is PointerSignalEvent) {
    binding.pointerSignalResolver.resolve(event);
  }
}

final _testDeliveries = Expando<({Set<EventDispatcher> forwarded, Set<EventDispatcher> callers})>();

/// 将旧的单入口测试接到真实命中父链，所有宿主先登记，再统一路由输入。
extension DispatcherTestTransport on EventDispatcher {
  /// 同一输入随后显式投递祖先时只登记一次，独立重复输入仍由最深入口重新投递。
  void dispatchTestPointer(PointerEvent event, BoxHitTestEntry entry, {bool includeAncestors = true}) {
    final canonical = event.original ?? event;
    final previous = _testDeliveries[canonical];
    if (previous != null && previous.forwarded.contains(this) && previous.callers.add(this)) return;
    final forwarded = <EventDispatcher>{};
    _testDeliveries[canonical] = (forwarded: forwarded, callers: {this});
    handleEvent(event, entry);
    forwarded.add(this);
    if (includeAncestors) {
      for (var node = entry.target.parent; node != null; node = node.parent) {
        if (node is! RenderBox) continue;
        final dispatcher = EventDispatcher.of(node);
        if (dispatcher == null || !forwarded.add(dispatcher)) continue;
        dispatcher.handleEvent(event, BoxHitTestEntry(node, node.globalToLocal(event.position)));
      }
    }
    dispatchTestPointerInput(event);
  }
}

/// 用真实触点平移建立 Scale 会话，供替换、取消和销毁合同复用。
final class DispatcherScaleGesture {
  DispatcherScaleGesture._(
    this.dispatcher,
    this.entry,
    this.pointer,
    this.position,
    this.kind,
    this.device,
    this.buttons,
  );

  /// 新触点平移到 [focalPoint] 起步，也可继续已经落下的 [existingDown]。
  factory DispatcherScaleGesture.start(
    EventDispatcher dispatcher,
    BoxHitTestEntry entry, {
    Offset focalPoint = const Offset(80, 80),
    PointerDownEvent? existingDown,
  }) {
    final down = existingDown ?? PointerDownEvent(pointer: _nextPointer++, position: focalPoint + const Offset(40, 0));
    final gesture = DispatcherScaleGesture._(
      dispatcher,
      entry,
      down.pointer,
      down.position,
      down.kind,
      down.device,
      down.buttons,
    );
    if (existingDown == null) dispatcher.dispatchTestPointer(down, entry);
    gesture.moveTo(existingDown == null ? focalPoint : down.position + const Offset(40, 0));
    return gesture;
  }

  static int _nextPointer = 15000;

  /// 当前承载识别器的真实宿主。
  final EventDispatcher dispatcher;

  /// 原命中路径对应的宿主入口。
  final BoxHitTestEntry entry;

  /// 本轮物理触点编号。
  final int pointer;

  /// 真实输入设备类型。
  final PointerDeviceKind kind;

  /// 真实输入设备编号。
  final int device;

  /// 接触期间保留按下时的鼠标按键。
  final int buttons;

  /// 本轮最后一次真实位置。
  Offset position;

  /// 投递实际移动；返回同一个输入实例供元数据身份断言使用。
  PointerMoveEvent moveTo(Offset next) {
    final event = PointerMoveEvent(
      pointer: pointer,
      device: device,
      kind: kind,
      buttons: buttons,
      position: next,
      delta: next - position,
    );
    position = next;
    dispatcher.dispatchTestPointer(event, entry);
    return event;
  }

  /// 抬起实际触点，通过官方路由结束会话。
  PointerUpEvent end() {
    final event = PointerUpEvent(pointer: pointer, device: device, kind: kind, position: position);
    dispatcher.dispatchTestPointer(event, entry);
    return event;
  }
}

/// 测试专用的最小单子 RenderBox。
final class _DispatcherTestBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {
  @override
  void performLayout() {
    child?.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(const Size(200, 200));
  }
}
