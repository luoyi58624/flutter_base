import 'package:flutter/gestures.dart' show Drag;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 基于官方 [Scrollable] 与 [Viewport] 的 Sliver 滚动容器，同轴嵌套时自动接力。
///
/// 一次拖动只属于一层：起手时本层在拖动方向已经贴边，就交给最近的可滚动同轴祖先；
/// 本层一旦开始消费，途中撞到边界也不换层，释放后的惯性同样留在本层。
/// 整条链都贴边时由最外层按自身物理处理。接力在本组件创建的滚动位置内完成，
/// 调用方不需要额外代码，祖先可以是任意官方滚动视图。
class ElScroll extends HookWidget {
  /// 创建承载 [slivers] 的滚动容器。
  const ElScroll({
    super.key,
    required this.slivers,
    this.controller,
    this.physics,
    this.axis = .vertical,
    this.reverse = false,
    this.clipBehavior = .hardEdge,
  });

  /// 按滚动顺序排列的 Sliver。
  final List<Widget> slivers;

  /// 观察与驱动滚动位置的控制器。
  ///
  /// 位置由本组件创建，才能承担嵌套接力；控制器自定义的 createScrollPosition 不会被调用，
  /// 初始偏移与偏移保存配置仍然生效。
  final ScrollController? controller;

  /// 滚动物理，默认读取环境 [ScrollConfiguration]。
  final ScrollPhysics? physics;

  /// 滚动主轴。
  final Axis axis;

  /// 是否反转滚动方向。
  final bool reverse;

  /// 视口裁剪行为。
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final host = useMemoized(_HostController.new);
    useEffect(() => host.dispose, const []);
    useEffect(() {
      host.bind(controller);
      return () => host.bind(null);
    }, [controller]);

    final direction = getAxisDirectionFromAxisReverseAndDirectionality(context, axis, reverse);
    return Scrollable(
      controller: host,
      physics: physics,
      axisDirection: direction,
      clipBehavior: clipBehavior,
      viewportBuilder: (context, offset) =>
          Viewport(axisDirection: direction, offset: offset, clipBehavior: clipBehavior, slivers: slivers),
    );
  }
}

/// 始终交给 [Scrollable] 的内部控制器，保证位置类型不受调用方控制器影响。
final class _HostController extends ScrollController {
  ScrollController? _user;

  /// 把已创建的位置同步挂到调用方控制器，更换控制器不重建位置。
  void bind(ScrollController? next) {
    final previous = _user;
    if (identical(previous, next)) return;
    _user = next;
    for (final position in positions) {
      previous?.detach(position);
      next?.attach(position);
    }
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    final user = _user;
    return _RelayPosition(
      physics: physics,
      context: context,
      initialPixels: user?.initialScrollOffset ?? 0,
      keepScrollOffset: user?.keepScrollOffset ?? true,
      oldPosition: oldPosition,
      debugLabel: user?.debugLabel,
    );
  }

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    _user?.attach(position);
  }

  @override
  void detach(ScrollPosition position) {
    _user?.detach(position);
    super.detach(position);
  }
}

/// 在官方拖动入口决定本次手势归属的滚动位置。
final class _RelayPosition extends ScrollPositionWithSingleContext {
  _RelayPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  bool _disposed = false;

  // 官方 drag 入口没有方向信息，先返回代理，等第一段位移再决定由谁真正开始拖动。
  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) => _RelayDrag(this, details, dragCancelCallback);

  Drag _startDrag(DragUpdateDetails first, DragStartDetails start, VoidCallback onCancelled) {
    final delta = first.primaryDelta ?? 0;
    final forward = axisDirectionIsReversed(axisDirection) ? delta > 0 : delta < 0;
    if (!_canScroll(forward)) {
      final ancestor = _ancestor();
      if (ancestor != null) {
        _releaseHold();
        // 祖先若也是本类型，会用同一段位移继续向外判定。
        return ancestor.drag(start, onCancelled);
      }
    }
    return super.drag(start, onCancelled);
  }

  bool _canScroll(bool forward) {
    // 越界回弹中的位置仍由自己接住，避免把回弹过程交给祖先。
    if (!hasPixels || !hasContentDimensions || outOfRange) return true;
    // 距边界不足一个物理像素视为贴边，否则惯性停在边界前的残余会锁住整段手势。
    final slack = physics.toleranceFor(this).distance;
    return forward ? pixels < maxScrollExtent - slack : pixels > minScrollExtent + slack;
  }

  ScrollPosition? _ancestor() {
    final host = context;
    if (host is! ScrollableState || !host.mounted) return null;
    var state = host.context.findAncestorStateOfType<ScrollableState>();
    while (state != null) {
      final position = state.position;
      if (position.axis == axis && position.hasContentDimensions && position.physics.shouldAcceptUserOffset(position)) {
        return position;
      }
      state = state.context.findAncestorStateOfType<ScrollableState>();
    }
    return null;
  }

  /// 结束按下时留下的 hold；本层不参与本次拖动时回到静止或回弹。
  void _releaseHold() {
    if (!_disposed && hasPixels && activity is HoldScrollActivity) goBallistic(0);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// 交给 [Scrollable] 的拖动代理，首段位移确定归属后原样转发。
final class _RelayDrag implements Drag {
  _RelayDrag(this._origin, this._start, this._onCancelled);

  final _RelayPosition _origin;
  final DragStartDetails _start;
  final VoidCallback _onCancelled;
  Drag? _target;
  bool _closed = false;

  // Scrollable 要求 end / cancel 返回前已收到取消回调，这里保证只通知一次。
  void _close() {
    _target = null;
    if (_closed) return;
    _closed = true;
    _onCancelled();
  }

  @override
  void update(DragUpdateDetails details) {
    if (_closed) return;
    var target = _target;
    if (target == null) {
      if (_origin._disposed) {
        _close();
        return;
      }
      if ((details.primaryDelta ?? 0) == 0) return;
      target = _target = _origin._startDrag(details, _start, _close);
    }
    target.update(details);
  }

  @override
  void end(DragEndDetails details) {
    final target = _target;
    if (target == null) {
      _origin._releaseHold();
    } else {
      target.end(details);
    }
    _close();
  }

  @override
  void cancel() {
    final target = _target;
    if (target == null) {
      _origin._releaseHold();
    } else {
      target.cancel();
    }
    _close();
  }
}
