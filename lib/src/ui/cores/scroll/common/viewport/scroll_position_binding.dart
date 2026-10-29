// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'scroll_engine_position.dart';

final class _FallbackScrollController extends ScrollController {
  _FallbackScrollController({required super.keepScrollOffset});

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
}

typedef ScrollRenderFlagSetter = void Function(bool value);
typedef ScrollSemanticsActionsSetter = void Function(Set<SemanticsAction> actions);

/// Default devices that may drag-scroll viewport content.
///
/// Desktop mouse drags are reserved for text selection / marquee interactions;
/// desktop scrolling should use wheel, trackpad pan-zoom, or the scrollbar thumb.
const Set<PointerDeviceKind> kViewportDragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown,
};

class ScrollPositionBinding<T extends StatefulWidget> implements ScrollContext, ScrollPositionGeneration {
  ScrollPositionBinding({
    required State<T> owner,
    required TickerProvider vsync,
    required GlobalKey viewportKey,
    required GlobalKey notificationKey,
    required ScrollController? Function() controller,
    required ScrollPhysics Function() physics,
    required Axis Function() axis,
    required bool Function() reverse,
    required ScrollRenderFlagSetter onIgnorePointerChanged,
    required ScrollRenderFlagSetter onCanDragChanged,
    required ScrollSemanticsActionsSetter onSemanticsActionsChanged,
    VoidCallback? onPositionWillChange,
    bool persistOffset = true,
  }) : _owner = owner,
       _vsync = vsync,
       _viewportKey = viewportKey,
       _notificationKey = notificationKey,
       _controllerGetter = controller,
       _physicsGetter = physics,
       _axisGetter = axis,
       _reverseGetter = reverse,
       _onIgnorePointerChanged = onIgnorePointerChanged,
       _onCanDragChanged = onCanDragChanged,
       _onSemanticsActionsChanged = onSemanticsActionsChanged,
       _onPositionWillChange = onPositionWillChange,
       _persistOffset = persistOffset;

  final State<T> _owner;
  final TickerProvider _vsync;
  final GlobalKey _viewportKey;
  final GlobalKey _notificationKey;
  final ScrollController? Function() _controllerGetter;
  final ScrollPhysics Function() _physicsGetter;
  final Axis Function() _axisGetter;
  final bool Function() _reverseGetter;
  final ScrollRenderFlagSetter _onIgnorePointerChanged;
  final ScrollRenderFlagSetter _onCanDragChanged;
  final ScrollSemanticsActionsSetter _onSemanticsActionsChanged;
  final VoidCallback? _onPositionWillChange;

  /// 是否把滚动偏移持久化到 PageStorage。
  ///
  /// 同一 State 挂两份 binding（双轴滚动）时 storageContext 相同、bucket 会
  /// 互相覆盖——次轴传 false 关闭读写，只有主轴保留恢复语义。
  final bool _persistOffset;

  ScrollController? _fallbackController;

  /// attach 当前 [_position] 时实际使用的 controller。
  ///
  /// detach 必须用它而非 getter 现解：调用侧（如双轴切单轴）可能在 dispose
  /// 之前就改写了 getter 依赖的字段，现解会拿到 null（fallback 未建即空断言
  /// 崩溃）或一个从未 attach 过该 position 的新 controller。
  ScrollController? _attachedController;
  ScrollPosition? _position;
  static int _nextGeneration = 0;
  int _generation = 0;

  bool _suppressOffsetPersistence = false;
  bool _contextActive = true;

  /// 实际 position 绑定的全局递增代次，摘挂后旧任务即失效。
  @override
  int get generation => _generation;

  /// mounted 在 deactivate 期间仍为 true，必须单独记录活动树生命周期。
  @override
  bool get contextActive => _contextActive && _owner.mounted;

  /// 先封闭旧上下文，再取消活动，避免终态通知冒泡到已失活的 Material。
  void suspendContext() => _contextActive = false;

  /// 销毁期抑制偏移持久化：卸载路径取消活动会走 position 终态，此时宿主
  /// element 已 deactivate，PageStorage 祖先查找会断言，故先关掉写入。
  @override
  void suppressOffsetPersistence() => _suppressOffsetPersistence = true;

  /// 是否已进入销毁期抑制。
  @override
  bool get offsetPersistenceSuppressed => _suppressOffsetPersistence || !contextActive;

  late ScrollBehavior _configuration;
  late ScrollPhysics _physics;
  AxisDirection? _boundDirection;
  late double _devicePixelRatio;
  bool _ignorePointer = false;
  bool _canDrag = false;

  BuildContext get _context => _owner.context;

  /// 宿主仍在活动树中的构建上下文；失活或已销毁时返回 null。
  ///
  /// [axisDirection] 与 [notificationContext] 会被框架在 metrics 路径上回调，
  /// 指标通知还可能排在微任务里跨帧执行——那时宿主已经 unmount，
  /// `State.context` 会断言（release 下是空指针）。这两条路必须能表达
  /// 「拿不到上下文」，不能兜到 [_context] 上。
  BuildContext? get _liveContext => contextActive ? _owner.context : null;

  ScrollController get controller => _controllerGetter() ?? _fallbackController!;

  ScrollController controllerFor(ScrollController? explicitController) {
    return explicitController ?? _fallbackController!;
  }

  ScrollPosition get position => _position!;

  ScrollBehavior get configuration => _configuration;

  ScrollPhysics get physics => _physics;

  bool get ignorePointer => _ignorePointer;

  bool get canDrag => _canDrag;

  void initState() {
    if (_controllerGetter() == null) {
      _fallbackController = _FallbackScrollController(keepScrollOffset: _persistOffset);
    }
  }

  void didChangeDependencies() {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(_context) ?? View.of(_context).devicePixelRatio;
    final configuration = ScrollConfiguration.of(_context);
    final needsPosition =
        _position == null ||
        _configuration != configuration ||
        _physics != _physicsGetter() ||
        _boundDirection != axisDirection ||
        _devicePixelRatio != ratio;
    _devicePixelRatio = ratio;
    // 新增的 region/Scope 依赖只更新输入拓扑，不能无故换绑并取消还在进行的手势。
    if (needsPosition) _updatePosition();
  }

  void didUpdateWidget({
    required ScrollController? oldController,
    required ScrollPhysics oldPhysics,
    required Axis oldAxis,
    required bool oldReverse,
  }) {
    final controllerChanged = oldController != _controllerGetter();
    ScrollController? oldFallbackToDispose;
    ScrollController? detachController;

    if (controllerChanged) {
      detachController = oldController ?? _fallbackController;
      if (oldController == null && _controllerGetter() != null) {
        oldFallbackToDispose = _fallbackController;
        _fallbackController = null;
      } else if (oldController != null && _controllerGetter() == null) {
        _fallbackController = _FallbackScrollController(keepScrollOffset: _persistOffset);
      }
    }

    final needsNewPosition =
        controllerChanged ||
        _physicsGetter() != oldPhysics ||
        _axisGetter() != oldAxis ||
        _reverseGetter() != oldReverse;

    if (needsNewPosition) {
      _updatePosition(detachController: detachController);
      oldFallbackToDispose?.dispose();
    }
  }

  /// element 摘挂（结构换壳/重父化）时先把 position 从 controller 上摘下：
  /// 新宿主会在同一 build 相位 attach 同一个外部 controller，若等到 dispose
  /// 才 detach，layout 期读 `controller.position` 会撞 "ScrollController
  /// attached to multiple scroll views"（官方 Scrollable 的 deactivate 同款
  /// 语义）。position 本体保留，重父化存活由 [activate] 挂回。
  void deactivate() {
    suspendContext();
    final currentPosition = _position;
    final attached = _attachedController;
    if (currentPosition != null && attached != null) {
      _generation = ++_nextGeneration;
      if (currentPosition is ScrollEnginePosition) currentPosition.retireMotion();
      attached.detach(currentPosition);
      _attachedController = null;
    }
  }

  /// 重父化存活（GlobalKey 移树）后把 position 重新挂回 controller，与
  /// [deactivate] 成对。
  void activate() {
    _contextActive = true;
    final currentPosition = _position;
    if (currentPosition != null && _attachedController == null) {
      _generation = ++_nextGeneration;
      final activeController = controller;
      activeController.attach(currentPosition);
      _attachedController = activeController;
    }
  }

  /// 先摘下控制器，再等当前 widget 树更新完成后释放 position。
  ///
  /// `didUpdateWidget` 期间 RenderObject 仍可能因 GlobalKey 重父化短暂重挂；
  /// 同步 dispose 会让它在 `attach` 中监听一个已经释放的 position。
  void disposeAfterTreeUpdate() {
    deactivate();
    scheduleMicrotask(dispose);
  }

  void dispose() {
    final currentPosition = _position;
    if (currentPosition != null) {
      // deactivate 已摘挂时为 null——不重复 detach（controller 侧断言会拒绝
      // detach 未登记的 position）。
      _attachedController?.detach(currentPosition);
      currentPosition.dispose();
    }
    _fallbackController?.dispose();
  }

  void _resolvePhysics() {
    _configuration = ScrollConfiguration.of(_context);
    _physics = _physicsGetter();
  }

  void _updatePosition({ScrollController? detachController}) {
    _resolvePhysics();
    _boundDirection = axisDirection;
    // 在 controller 工厂接收旧 position 前失效旧代次，不能由观察者首次读取时补记。
    _generation = ++_nextGeneration;
    final oldPosition = _position;
    if (oldPosition != null) {
      _onPositionWillChange?.call();
      if (oldPosition is ScrollEnginePosition) oldPosition.retireMotion();
      (detachController ?? _attachedController ?? controller).detach(oldPosition);
    }

    final activeController = controller;
    _position = activeController.createScrollPosition(_physics, this, oldPosition);
    activeController.attach(position);
    _attachedController = activeController;
    if (oldPosition != null) {
      scheduleMicrotask(oldPosition.dispose);
    }
  }

  @override
  AxisDirection get axisDirection {
    final context = _liveContext;
    // 宿主销毁后沿用上次绑定的方向：metrics 路径仍会读 axis，
    // 此时已经取不到 context 了。
    if (context == null) return _boundDirection ?? AxisDirection.down;
    return getAxisDirectionFromAxisReverseAndDirectionality(context, _axisGetter(), _reverseGetter());
  }

  @override
  TickerProvider get vsync => _vsync;

  @override
  double get devicePixelRatio => _devicePixelRatio;

  @override
  BuildContext? get notificationContext =>
      contextActive ? _notificationKey.currentContext ?? _viewportKey.currentContext ?? _liveContext : null;

  @override
  BuildContext get storageContext => _context;

  /// 活动级屏蔽要求，原样转发官方语义（`goBallistic` 把拖拽期的值继承给
  /// [BallisticScrollActivity]，所以 fling 期这里恒为 true）。
  ///
  /// **它不是最终判据**：render 侧命中时再叠一道"当前活动是手指拖拽"
  /// （`fingerDragScrolling`），把本标志的窗口收敛到拖拽期，程序驱动动画
  /// 期间内容可直接命中；触摸 fling 由 `touchFlingScrolling` 另行整段屏蔽。
  /// 别在这里做收敛——drag→ballistic 交接时官方不会回调本方法（两者的
  /// shouldIgnorePointer 同为 true），推送型标志必然滞后。
  @override
  void setIgnorePointer(bool value) {
    if (_ignorePointer == value) return;
    _ignorePointer = value;
    _onIgnorePointerChanged(value);
  }

  @override
  void setCanDrag(bool value) {
    if (_canDrag == value) return;
    _canDrag = value;
    _onCanDragChanged(value);
  }

  @override
  void setSemanticsActions(Set<SemanticsAction> actions) {
    _onSemanticsActionsChanged(actions);
  }

  @override
  void saveOffset(double offset) {
    if (!_persistOffset || offsetPersistenceSuppressed) return;
    PageStorage.maybeOf(storageContext)?.writeState(storageContext, offset);
  }
}
