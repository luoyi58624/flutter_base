import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, precisionErrorTolerance;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_base/src/ui/cores/view/event/event.dart';
import 'package:flutter_base/src/ui/cores/view/style/animation/driver.dart' show elDisableAnimations;
import 'package:flutter_base/src/ui/cores/view/view.dart';
import 'package:flutter_base/src/ui/cores/view/semantics/semantics.dart';
import 'package:flutter_base/src/ui/views/zoom/zoom_view.dart';

/// 为 builder 数据集提供稳定的页面逻辑身份。
typedef PreviewItemIdBuilder = Object Function(int index);

/// 控制一个 live [ElPreviewView] 的页索引与当前页变换。
final class ElPreviewController extends ChangeNotifier {
  /// 创建控制器；未挂载时 [initialIndex] 作为后续宿主的请求索引。
  ElPreviewController({int initialIndex = 0})
    : assert(initialIndex >= 0),
      _requestedIndex = initialIndex,
      _index = initialIndex;

  int _requestedIndex;
  int? _index;
  ElZoomTransform _transform = const ElZoomTransform();
  _PreviewViewState? _host;
  bool _disposed = false;

  /// 当前页索引；挂载到空数据集时为 null。
  int? get index => _index;

  /// 当前页的实际变换。
  ElZoomTransform get currentTransform => _transform;

  /// 当前分页是否完全归位，可供外层手势避免与切页过渡叠加。
  bool get isPageSettled => _host?._isPageSettled ?? true;

  /// 切到下一页。
  Future<void> next({bool animate = true}) {
    final host = _host;
    return host == null ? _goTo((_index ?? _requestedIndex) + 1, animate: animate) : host._goBy(1, animate: animate);
  }

  /// 切到上一页。
  Future<void> previous({bool animate = true}) {
    final host = _host;
    return host == null
        ? _goTo(math.max(0, (_index ?? _requestedIndex) - 1), animate: animate)
        : host._goBy(-1, animate: animate);
  }

  /// 动画切换到 [index]；未挂载时立即保存请求并完成。
  Future<void> animateToIndex(int index) => _goTo(index, animate: true);

  /// 立即切换到 [index]；宿主会按数据集范围钳制。
  void jumpToIndex(int index) {
    _requestedIndex = math.max(0, index);
    final host = _host;
    if (host == null) {
      _sync(_requestedIndex, _transform);
    } else {
      host._jumpToIndex(_requestedIndex);
    }
  }

  /// 动画设置当前页变换；未挂载时立即保存并完成。
  Future<void> animateTransform(ElZoomTransform transform) {
    _validateTransform(transform);
    final host = _host;
    if (host == null) {
      _sync(_index, transform);
      return Future<void>.value();
    }
    return host._animateCurrentTransform(transform);
  }

  /// 立即设置当前页变换。
  void jumpToTransform(ElZoomTransform transform) {
    _validateTransform(transform);
    final host = _host;
    if (host == null) {
      _sync(_index, transform);
    } else {
      host._jumpCurrentTransform(transform);
    }
  }

  /// 重置当前页变换。
  Future<void> resetCurrent({bool animate = true}) {
    if (animate) return animateTransform(const ElZoomTransform());
    jumpToTransform(const ElZoomTransform());
    return Future<void>.value();
  }

  Future<void> _goTo(int index, {required bool animate}) {
    _requestedIndex = math.max(0, index);
    final host = _host;
    if (host == null) {
      _sync(_requestedIndex, _transform);
      return Future<void>.value();
    }
    if (animate) return host._animateToIndex(_requestedIndex);
    host._jumpToIndex(_requestedIndex);
    return Future<void>.value();
  }

  void _attach(_PreviewViewState host) {
    if (_disposed) throw FlutterError('已 dispose 的 ElPreviewController 不能再次绑定。');
    final current = _host;
    if (current != null && !identical(current, host)) {
      throw FlutterError('一个 ElPreviewController 同一时刻只能绑定一个 live ElPreviewView。');
    }
    _host = host;
  }

  void _detach(_PreviewViewState host) {
    if (identical(_host, host)) _host = null;
  }

  void _sync(int? index, ElZoomTransform transform) {
    if (_disposed) return;
    final changed = _index != index || _transform != transform;
    _index = index;
    if (index != null) _requestedIndex = index;
    _transform = transform;
    if (changed) notifyListeners();
  }

  static void _validateTransform(ElZoomTransform value) {
    if (!value.scale.isFinite ||
        value.scale <= 0 ||
        !value.rotation.isFinite ||
        !value.offset.dx.isFinite ||
        !value.offset.dy.isFinite) {
      throw ArgumentError.value(value, 'transform', '全部分量必须 finite 且 scale > 0');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _host = null;
    super.dispose();
  }
}

/// 任意 Widget 的 headless 缩放分页预览容器。
///
/// 稳态只挂载 current ± [preloadCount]，非当前页只绘制且不参与
/// 命中、焦点与语义。页位移只更新 render paint transform，不逐帧
/// rebuild/layout 页面。
class ElPreviewView extends StatefulWidget {
  /// 用固定 children 创建预览器。
  const ElPreviewView({
    super.key,
    required this.children,
    this.initialIndex = 0,
    this.controller,
    this.minScale = 1,
    this.maxScale = 6,
    this.doubleTapScale = 2,
    this.scaleSensitivity = 1.25,
    this.enableRotation = true,
    this.panInertia = true,
    this.scaleInertia = false,
    this.mouseWheelZoom = true,
    this.mouseDragPan = true,
    this.strictPageDragIntent = false,
    this.wheelScaleSensitivity = 0.002,
    this.loop = false,
    this.preloadCount = 1,
    this.preserveItemTransform = false,
    this.transformCacheCapacity = 32,
    this.constrained = true,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.onIndexChanged,
  }) : _builderItemCount = null,
       itemBuilder = null,
       itemIdBuilder = null,
       assert(initialIndex >= 0),
       assert(preloadCount >= 0),
       assert(transformCacheCapacity >= 0),
       assert(minScale > 0 && minScale <= maxScale),
       assert(scaleSensitivity > 0 && scaleSensitivity < double.infinity),
       assert(wheelScaleSensitivity > 0 && wheelScaleSensitivity < double.infinity);

  /// 用惰性 builder 数据集创建预览器。
  const ElPreviewView.builder({
    super.key,
    required int itemCount,
    required this.itemBuilder,
    this.itemIdBuilder,
    this.initialIndex = 0,
    this.controller,
    this.minScale = 1,
    this.maxScale = 6,
    this.doubleTapScale = 2,
    this.scaleSensitivity = 1.25,
    this.enableRotation = true,
    this.panInertia = true,
    this.scaleInertia = false,
    this.mouseWheelZoom = true,
    this.mouseDragPan = true,
    this.strictPageDragIntent = false,
    this.wheelScaleSensitivity = 0.002,
    this.loop = false,
    this.preloadCount = 1,
    this.preserveItemTransform = false,
    this.transformCacheCapacity = 32,
    this.constrained = true,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.onIndexChanged,
  }) : children = null,
       _builderItemCount = itemCount,
       assert(itemCount >= 0),
       assert(initialIndex >= 0),
       assert(preloadCount >= 0),
       assert(transformCacheCapacity >= 0),
       assert(minScale > 0 && minScale <= maxScale),
       assert(scaleSensitivity > 0 && scaleSensitivity < double.infinity),
       assert(wheelScaleSensitivity > 0 && wheelScaleSensitivity < double.infinity);

  /// children 构造的页面列表；builder 构造时为 null。
  final List<Widget>? children;
  final int? _builderItemCount;

  /// builder 构造的页面数量。
  int get itemCount => children?.length ?? _builderItemCount!;

  /// builder 构造的页面生成器。
  final IndexedWidgetBuilder? itemBuilder;

  /// builder 数据集的稳定身份生成器；未提供时使用 index。
  final PreviewItemIdBuilder? itemIdBuilder;

  /// 未绑定 [controller] 时的首次页索引。
  final int initialIndex;

  /// 外部页索引与当前变换控制器。
  final ElPreviewController? controller;

  /// 每页最小缩放倍数。
  final double minScale;

  /// 每页最大缩放倍数。
  final double maxScale;

  /// 双击缩放目标倍数。
  final double doubleTapScale;

  /// 双指捏合的对数缩放增益；默认比原始指距比例更积极。
  final double scaleSensitivity;

  /// 是否允许触摸旋转；缩放意图会锁住旋转，旋转意图可同步缩放，松手后吸附最近直角。
  final bool enableRotation;

  /// 是否允许变换平移惯性。
  final bool panInertia;

  /// 是否允许双指近同时释放后的对数缩放惯性。
  final bool scaleInertia;

  /// 是否让物理鼠标滚轮围绕光标缩放。
  final bool mouseWheelZoom;

  /// 是否允许鼠标主键平移内容与翻页。
  final bool mouseDragPan;

  /// 是否让横向翻页先经过双轴方向裁决。
  ///
  /// 开启后，明显纵向的斜拖不会触发横向翻页，适合外层还有下滑关闭等
  /// 纵向手势的图片预览场景。
  final bool strictPageDragIntent;

  /// 鼠标滚轮每个逻辑像素对应的对数缩放量。
  final double wheelScaleSensitivity;

  /// 是否让两项及以上的数据集在手势、相邻命令和语义动作中首尾循环；绝对索引仍按范围钳制。
  final bool loop;

  /// 当前页两侧预挂载的页数。
  ///
  /// 预加载 child 保持 mounted，因此其自有 ticker/lifecycle 仍由 child 管理；
  /// Preview 只关闭自己的 Zoom 交互，并隔离命中、焦点与语义。严格按需挂载时设为 0。
  final int preloadCount;

  /// 离窗后是否保留页变换。
  final bool preserveItemTransform;

  /// 离窗变换的 LRU 容量，不计当前挂载页。
  final int transformCacheCapacity;

  /// true 时每页 child 紧约束到视口。
  final bool constrained;

  /// 小内容在视口中的基位。
  final Alignment alignment;

  /// 预览视口的裁剪方式。
  final Clip clipBehavior;

  /// 页面 commit 后的索引变化回调。
  final ValueChanged<int>? onIndexChanged;

  @override
  State<ElPreviewView> createState() => _PreviewViewState();
}

class _PreviewViewState extends State<ElPreviewView> with SingleTickerProviderStateMixin {
  static const double _snapThreshold = 0.35;
  static const double _minFlingVelocity = 400;
  static final SpringDescription _pageSpring = SpringDescription.withDampingRatio(mass: 0.5, stiffness: 120, ratio: 1);
  static const Tolerance _pageSpringTolerance = Tolerance(distance: 1, velocity: 30);
  static const Set<PointerDeviceKind> _nonMouseDragDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  late final AnimationController _pageAnimation;
  late List<Object> _ids;
  int _index = 0;
  Object? _currentId;
  double _pageOffset = 0;
  int? _pageTargetIndex;
  int _pageDirection = 0;
  bool _directPageDrag = false;
  bool _proxyPageDrag = false;
  bool _panZoomPageDrag = false;
  bool _handoffActive = false;
  bool _absorbingHandoff = false;
  ElZoomTransform _observedTransform = const ElZoomTransform();
  int _pointerCount = 0;

  double _animationTo = 0;
  Completer<void>? _pageCommandCompleter;
  bool _viewportResetScheduled = false;
  int? _deferredPreloadFirst;
  int? _deferredPreloadLast;
  bool _preloadRestoreScheduled = false;

  _RenderPreviewViewport? _render;
  final Map<Object, ElZoomController> _zoomControllers = <Object, ElZoomController>{};

  /// 非活动页的焦点阻断节点；每个页面一个（同一 FocusNode 不能挂到多个视图）。
  final Map<Object, FocusNode> _blockerNodes = <Object, FocusNode>{};
  final LinkedHashMap<Object, ElZoomTransform> _transformCache = LinkedHashMap<Object, ElZoomTransform>();

  @override
  void initState() {
    super.initState();
    _ids = _resolveIds();
    final requested = widget.controller?._requestedIndex ?? widget.initialIndex;
    _index = _normalizeIndex(requested) ?? 0;
    _currentId = _ids.isEmpty ? null : _ids[_index];
    if (_currentId != null && widget.controller != null) {
      _transformCache[_currentId!] = widget.controller!._transform;
    }
    _pageAnimation = AnimationController.unbounded(vsync: this)
      ..addListener(_handlePageAnimationTick)
      ..addStatusListener(_handlePageAnimationStatus);
    widget.controller?._attach(this);
    _syncExternalController();
  }

  @override
  void didUpdateWidget(covariant ElPreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = !identical(oldWidget.controller, widget.controller);
    final previousIds = _ids;
    final nextIds = _resolveIds();
    final datasetChanged = !listEquals(previousIds, nextIds);
    if (controllerChanged || datasetChanged || widget.loop != oldWidget.loop) {
      _stopCurrentZoomAnimation();
      _interruptPageAnimation();
      _setPageOffset(0);
      _pageTargetIndex = null;
      _pageDirection = 0;
      _handoffActive = false;
      _directPageDrag = false;
      _proxyPageDrag = false;
      _panZoomPageDrag = false;
    }
    if (controllerChanged) oldWidget.controller?._detach(this);
    final previousId = _currentId;
    final previousIndex = _index;
    _ids = nextIds;
    final followedIndex = previousId == null ? null : _ids.indexOf(previousId);
    final requested = widget.controller?._requestedIndex ?? widget.initialIndex;
    _index = (controllerChanged || previousIds.isEmpty) && requested >= 0
        ? (_normalizeIndex(requested) ?? 0)
        : followedIndex != null && followedIndex >= 0
        ? followedIndex
        : (_normalizeIndex(_index) ?? 0);
    _currentId = _ids.isEmpty ? null : _ids[_index];
    if (!widget.preserveItemTransform && previousId != null && previousId != _currentId) {
      _zoomControllers[previousId]?.jumpTo(const ElZoomTransform());
    }
    _removeDeletedTransforms();
    if (!widget.preserveItemTransform && oldWidget.preserveItemTransform) _transformCache.clear();
    _trimTransformCache();
    if (controllerChanged) {
      final controller = widget.controller;
      controller?._attach(this);
      final id = _currentId;
      if (controller != null && id != null) {
        final zoomController = _zoomControllers[id];
        if (zoomController == null) {
          _transformCache[id] = controller._transform;
        } else {
          zoomController.jumpTo(controller._transform);
        }
      }
    }
    _observedTransform = _currentTransform;
    if (previousIndex != _index) _scheduleIndexReport();
    _syncExternalController();
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _completePageCommand();
    _pageAnimation.dispose();
    for (final controller in _zoomControllers.values) {
      controller.dispose();
    }
    for (final node in _blockerNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  List<Object> _resolveIds() {
    final ids = <Object>[];
    final seen = <Object>{};
    for (var i = 0; i < widget.itemCount; i++) {
      final id = widget.itemIdBuilder?.call(i) ?? widget.children?[i].key ?? i;
      if (!seen.add(id)) throw FlutterError('ElPreviewView 的 itemId 必须唯一，重复值：$id');
      ids.add(id);
    }
    return ids;
  }

  int? _normalizeIndex(int value) => _ids.isEmpty ? null : math.min(math.max(0, value), _ids.length - 1);

  int? _adjacentIndex(int direction) {
    if (_ids.length < 2) return null;
    final target = _index + direction;
    if (target >= 0 && target < _ids.length) return target;
    if (!widget.loop) return null;
    return target < 0 ? _ids.length - 1 : 0;
  }

  Widget _itemAt(BuildContext context, int index) => widget.children?[index] ?? widget.itemBuilder!(context, index);

  List<int> _mountedIndices() {
    if (_ids.isEmpty) return const <int>[];
    if (widget.loop && _ids.length > 1) {
      if (_deferredPreloadFirst != null) return <int>[_index];
      final mountedCount = math.min(_ids.length, 1 + widget.preloadCount * 2);
      final first = (_index - widget.preloadCount) % _ids.length;
      final mounted = <int>[for (var offset = 0; offset < mountedCount; offset++) (first + offset) % _ids.length];
      final target = _pageTargetIndex;
      if (target != null && !mounted.contains(target)) mounted.add(target);
      return mounted;
    }
    final first = math.max(0, _index - widget.preloadCount);
    final last = math.min(_ids.length - 1, _index + widget.preloadCount);
    final retainedFirst = _deferredPreloadFirst;
    final retainedLast = _deferredPreloadLast;
    if (retainedFirst != null && retainedLast != null) {
      return <int>[
        for (var i = first; i <= last; i++)
          if (i == _index || (i >= retainedFirst && i <= retainedLast)) i,
      ];
    }
    final mounted = <int>[for (var i = first; i <= last; i++) i];
    final target = _pageTargetIndex;
    if (target != null && target < first) {
      mounted.insert(0, target);
    } else if (target != null && target > last) {
      mounted.add(target);
    }
    return mounted;
  }

  ElZoomController _zoomControllerFor(Object id) {
    return _zoomControllers.putIfAbsent(id, () {
      final initial = _transformCache.remove(id) ?? const ElZoomTransform();
      return ElZoomController(initialValue: initial);
    });
  }

  /// 非活动页的焦点阻断节点：挡住整棵后代的焦点、遍历与语义。
  FocusNode _blockerNodeFor(Object id) => _blockerNodes.putIfAbsent(
    id,
    () => FocusNode(
      debugLabel: 'ElPreviewInactivePage($id)',
      canRequestFocus: false,
      descendantsAreFocusable: false,
      descendantsAreTraversable: false,
    ),
  );

  void _retainOnly(Set<Object> mountedIds) {
    final removed = _zoomControllers.keys.where((id) => !mountedIds.contains(id)).toList(growable: false);
    for (final id in removed) {
      final controller = _zoomControllers.remove(id)!;
      if (widget.preserveItemTransform) _cacheTransform(id, controller.value);
      controller.dispose();
    }
    _blockerNodes.removeWhere((id, node) {
      if (mountedIds.contains(id)) return false;
      node.dispose();
      return true;
    });
  }

  void _cacheTransform(Object id, ElZoomTransform value) {
    if (!widget.preserveItemTransform || widget.transformCacheCapacity == 0) return;
    _transformCache.remove(id);
    _transformCache[id] = value;
    _trimTransformCache();
  }

  void _trimTransformCache() {
    while (_transformCache.length > widget.transformCacheCapacity) {
      _transformCache.remove(_transformCache.keys.first);
    }
  }

  void _removeDeletedTransforms() {
    final live = _ids.toSet();
    final removed = _zoomControllers.keys.where((id) => !live.contains(id)).toList(growable: false);
    for (final id in removed) {
      _zoomControllers.remove(id)?.dispose();
    }
    _transformCache.removeWhere((id, _) => !live.contains(id));
  }

  ElZoomTransform get _currentTransform {
    final id = _currentId;
    if (id == null) return const ElZoomTransform();
    return _zoomControllers[id]?.value ?? _transformCache[id] ?? const ElZoomTransform();
  }

  bool get _isPageSettled =>
      !_pageAnimation.isAnimating &&
      _pageOffset.abs() <= precisionErrorTolerance &&
      _pageTargetIndex == null &&
      !_handoffActive &&
      !_directPageDrag &&
      !_proxyPageDrag &&
      !_panZoomPageDrag;

  void _syncExternalController() => widget.controller?._sync(_ids.isEmpty ? null : _index, _currentTransform);

  void _scheduleIndexReport() {
    final expected = _index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _index == expected) widget.onIndexChanged?.call(expected);
    });
  }

  void _reportIndexChanged() {
    _syncExternalController();
    widget.onIndexChanged?.call(_index);
  }

  Future<void> _animateToIndex(int requested, {int? direction}) {
    final target = _normalizeIndex(requested);
    if (target == null || target == _index) {
      if (target != null) _jumpToIndex(target);
      return Future<void>.value();
    }
    _panZoomPageDrag = false;
    _stopCurrentZoomAnimation();
    _interruptPageAnimation();
    final pageDirection = direction ?? (target > _index ? 1 : -1);
    _setPageTarget(target, pageDirection);
    final extent = _render?.size.width ?? 0;
    if (extent <= precisionErrorTolerance || elDisableAnimations) {
      _commitPage(target);
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _pageCommandCompleter = completer;
    _startPageAnimation(-pageDirection * extent);
    return completer.future;
  }

  Future<void> _goBy(int direction, {required bool animate}) {
    final target = _adjacentIndex(direction);
    if (target == null) return Future<void>.value();
    if (animate) return _animateToIndex(target, direction: direction);
    _jumpToIndex(target, direction: direction);
    return Future<void>.value();
  }

  void _jumpToIndex(int requested, {int? direction}) {
    final target = _normalizeIndex(requested);
    _interruptPageAnimation();
    _pageDirection = direction ?? 0;
    _panZoomPageDrag = false;
    if (target == null) {
      _syncExternalController();
      return;
    }
    if (target == _index) {
      final needsRebuild =
          _pageOffset != 0 || _pageTargetIndex != null || _handoffActive || _directPageDrag || _proxyPageDrag;
      _stopCurrentZoomAnimation();
      _setPageOffset(0);
      _pageTargetIndex = null;
      _pageDirection = 0;
      _handoffActive = false;
      _directPageDrag = false;
      _proxyPageDrag = false;
      if (needsRebuild) setState(() {});
      _syncExternalController();
      return;
    }
    _commitPage(target);
  }

  Future<void> _animateCurrentTransform(ElZoomTransform transform) {
    _interruptPageAnimation();
    _setPageOffset(0);
    _clearPageTarget();
    _handoffActive = false;
    _directPageDrag = false;
    _proxyPageDrag = false;
    _panZoomPageDrag = false;
    final controller = _currentId == null ? null : _zoomControllerFor(_currentId!);
    if (controller == null) return Future<void>.value();
    if (elDisableAnimations) {
      controller.jumpTo(transform);
      return Future<void>.value();
    }
    return controller.animateTo(transform);
  }

  void _jumpCurrentTransform(ElZoomTransform transform) {
    _interruptPageAnimation();
    _setPageOffset(0);
    _clearPageTarget();
    _handoffActive = false;
    _directPageDrag = false;
    _proxyPageDrag = false;
    _panZoomPageDrag = false;
    final id = _currentId;
    if (id == null) {
      _syncExternalController();
      return;
    }
    _zoomControllerFor(id).jumpTo(transform);
  }

  void _stopCurrentZoomAnimation({bool settlePendingTransform = true}) {
    final id = _currentId;
    final controller = id == null ? null : _zoomControllers[id];
    controller?.stopAnimation(settlePendingTransform: settlePendingTransform);
  }

  void _handleItemTransform(Object id, ElZoomTransform value) {
    if (id != _currentId) return;
    if (_absorbingHandoff) {
      _observedTransform = value;
      return;
    }
    var actual = value;
    final scaleOrRotationChanged =
        value.scale != _observedTransform.scale || value.rotation != _observedTransform.rotation;
    if (_handoffActive && scaleOrRotationChanged && _pageOffset.abs() > precisionErrorTolerance) {
      _absorbingHandoff = true;
      final controller = _zoomControllers[id]!;
      final before = value.offset;
      controller.jumpTo(value.copyWith(offset: before + Offset(_pageOffset, 0)));
      actual = controller.value;
      final consumed = actual.offset.dx - before.dx;
      _absorbingHandoff = false;
      if (consumed.abs() > precisionErrorTolerance) {
        _setPageOffset(_pageOffset - consumed);
        if (_pageOffset.abs() <= precisionErrorTolerance) {
          _handoffActive = false;
          _clearPageTarget();
          setState(() {});
        }
      }
    }
    _observedTransform = actual;
    widget.controller?._sync(_index, actual);
  }

  void _handlePointerDown(ElEventDetails event) {
    _pointerCount = event.pointerCount;
    if (_pointerCount == 1) {
      _stopCurrentZoomAnimation(settlePendingTransform: false);
    } else if (_pageOffset.abs() > precisionErrorTolerance) {
      _beginHandoff();
    }
  }

  void _handleSinglePointerDown(ElEventDetails event) => _stopCurrentZoomAnimation(settlePendingTransform: false);

  void _handlePointerTerminal(ElEventDetails event) {
    _pointerCount = event.pointerCount;
    if (_pointerCount != 0 || _directPageDrag) return;
    if (_handoffActive) {
      scheduleMicrotask(_finishHandoff);
    }
  }

  void _handlePointerCancel(ElEventDetails event) {
    _pointerCount = event.pointerCount;
    if (_pointerCount != 0 || _directPageDrag) return;
    if (_handoffActive) {
      scheduleMicrotask(_finishHandoff);
    }
  }

  void _handleZoomPointerCountChanged(int pointerCount) {
    _pointerCount = pointerCount;
    if (_pointerCount != 0 || _directPageDrag) return;
    if (_handoffActive) scheduleMicrotask(_finishHandoff);
  }

  void _handlePageDragStart(ElEventDetails event) {
    _pointerCount = event.pointerCount;
    if (_ids.length < 2 || _pointerCount > 1) return;
    if (event.dragPipelineActive) return;
    event.eagerGesture(cancelSelfTap: true, allowScaleUpgrade: true);
    _takeOverPageAnimation();
    if (_handoffActive) return;
    _directPageDrag = true;
  }

  void _handlePageDragUpdate(ElEventDetails event) {
    _pointerCount = event.pointerCount;
    if (!_directPageDrag || _handoffActive) return;
    final consumed = _applyPageDelta(event.remainingLocalDelta.dx);
    if (consumed != 0) _consumeLocalHorizontal(event, consumed);
  }

  void _handlePageDragEnd(ElEventDetails event) {
    if (!_directPageDrag) {
      _handleProxyDragEnd(event.velocity);
      return;
    }
    _directPageDrag = false;
    _settlePage(event.velocity.pixelsPerSecond.dx);
  }

  void _handlePageDragCancel(ElEventDetails event) {
    _pointerCount = event.pointerCount;
    if (_handoffActive) {
      _directPageDrag = false;
      if (_pointerCount == 0) scheduleMicrotask(_finishHandoff);
      return;
    }
    if (!_directPageDrag) {
      _handleProxyDragCancel();
      return;
    }
    _directPageDrag = false;
    _animatePageBack();
  }

  void _handleCrossAxisDragStart(ElEventDetails event) {
    _pointerCount = event.pointerCount;
  }

  void _handleCrossAxisDragUpdate(ElEventDetails event) {
    _pointerCount = event.pointerCount;
  }

  void _handleCrossAxisDragEnd(ElEventDetails event) {
    _pointerCount = event.pointerCount;
  }

  void _handleCrossAxisDragCancel(ElEventDetails event) {
    _pointerCount = event.pointerCount;
  }

  void _handlePagePanZoomStart(ElEventDetails event) {
    _panZoomPageDrag = false;
  }

  void _handlePagePanZoomUpdate(ElEventDetails event) {
    if (_ids.length < 2) return;
    final delta = event.remainingLocalDelta.dx;
    if (delta == 0) return;
    _takeOverPageAnimation();
    if (_handoffActive) return;
    final consumed = _applyPageDelta(delta);
    if (consumed == 0) return;
    _panZoomPageDrag = true;
    _consumeLocalHorizontal(event, consumed);
  }

  void _handlePagePanZoomEnd(ElEventDetails event) {
    if (_handoffActive) {
      _finishHandoff();
      return;
    }
    if (!_panZoomPageDrag) return;
    _panZoomPageDrag = false;
    _settlePage(0);
  }

  void _handleProxyPreUpdate(ElEventDetails event) {
    _pointerCount = event.pointerCount;
    if (_takeOverPageAnimation()) _proxyPageDrag = true;
    if (_handoffActive || _pageOffset == 0) return;
    final delta = event.remainingLocalDelta.dx;
    if (delta == 0 || delta.sign == _pageOffset.sign) return;
    final consumed = delta.sign * math.min(delta.abs(), _pageOffset.abs());
    _setPageOffset(_pageOffset + consumed);
    if (_pageOffset.abs() <= precisionErrorTolerance) {
      _proxyPageDrag = false;
      _clearPageTarget();
    }
    _consumeLocalHorizontal(event, consumed);
  }

  void _handleProxyOverflow(ElEventDetails event) {
    _pointerCount = event.pointerCount;
    if (_ids.length < 2 || _pointerCount > 1) return;
    if (_takeOverPageAnimation()) _proxyPageDrag = true;
    if (_handoffActive) return;
    final consumed = _applyPageDelta(event.remainingLocalDelta.dx, allowRollover: false);
    if (consumed == 0) return;
    _proxyPageDrag = true;
    _consumeLocalHorizontal(event, consumed);
  }

  bool _handleProxyDragEnd(Velocity velocity) {
    if (!_proxyPageDrag) return false;
    _proxyPageDrag = false;
    _settlePage(velocity.pixelsPerSecond.dx);
    return false;
  }

  void _handleProxyDragCancel() {
    if (!_proxyPageDrag) return;
    _proxyPageDrag = false;
    _animatePageBack();
  }

  void _handleZoomPanCancel() {
    _handleProxyDragCancel();
    if (!_panZoomPageDrag) return;
    _panZoomPageDrag = false;
    _beginHandoff();
  }

  double _applyPageDelta(double delta, {bool allowRollover = true}) {
    final extent = _render?.size.width ?? 0;
    if (delta == 0 || extent <= precisionErrorTolerance) return 0;
    var remaining = delta;
    var consumed = 0.0;
    while (remaining.abs() > precisionErrorTolerance) {
      if (_pageOffset != 0 && remaining.sign != _pageOffset.sign) {
        if (remaining.abs() < _pageOffset.abs()) {
          _setPageOffset(_pageOffset + remaining);
          return consumed + remaining;
        }
        final closingDelta = -_pageOffset;
        consumed += closingDelta;
        remaining -= closingDelta;
        _setPageOffset(0);
        _clearPageTarget();
        continue;
      }

      final direction = remaining < 0 ? 1 : -1;
      final target = _adjacentIndex(direction);
      if (target == null) {
        final fraction = (_pageOffset.abs() / extent).clamp(0.0, 1.0).toDouble();
        final factor = 0.52 * math.pow(1 - fraction, 2).toDouble();
        final applied = remaining * factor;
        final before = _pageOffset;
        _setPageOffset((_pageOffset + applied).clamp(-extent * 0.5, extent * 0.5).toDouble());
        return consumed + _pageOffset - before;
      }

      _setPageTarget(target, direction);
      final boundary = -direction * extent;
      final boundaryDelta = boundary - _pageOffset;
      if (remaining.abs() < boundaryDelta.abs()) {
        _setPageOffset(_pageOffset + remaining);
        return consumed + remaining;
      }

      _setPageOffset(boundary);
      consumed += boundaryDelta;
      remaining -= boundaryDelta;
      // Zoom proxy 的 driver 绑定旧页，跨页时不能安全转移；直接翻页与 trackpad
      // 则在几何完全重合的端点提交，并把同帧余量继续交给下一张。
      if (!allowRollover) return consumed;
      _commitPage(target, preserveInteraction: true);
    }
    return consumed;
  }

  void _setPageTarget(int target, int direction) {
    if (_pageTargetIndex == target && _pageDirection == direction) return;
    final wasMounted = _mountedIndices().contains(target);
    _pageTargetIndex = target;
    _pageDirection = direction;
    if (!wasMounted) {
      setState(() {});
    } else {
      _render?.notePageOffsetChanged();
    }
  }

  void _clearPageTarget() {
    final target = _pageTargetIndex;
    if (target == null) return;
    _pageTargetIndex = null;
    _pageDirection = 0;
    if (!_mountedIndices().contains(target)) {
      setState(() {});
    } else {
      _render?.notePageOffsetChanged();
    }
  }

  void _consumeLocalHorizontal(ElEventDetails event, double localDelta) {
    final render = _render;
    if (render == null) {
      event.consumePrimaryDelta(Axis.horizontal, localDelta);
      return;
    }
    final start = render.localToGlobal(event.localPosition);
    final end = render.localToGlobal(event.localPosition + Offset(localDelta, 0));
    event.consumePrimaryDelta(Axis.horizontal, end.dx - start.dx);
  }

  void _beginHandoff() {
    if (_handoffActive) {
      if (_pageAnimation.isAnimating) _interruptPageAnimation();
      return;
    }
    if (_pageOffset.abs() <= precisionErrorTolerance) return;
    _interruptPageAnimation();
    _handoffActive = true;
    _directPageDrag = false;
    _proxyPageDrag = false;
    _panZoomPageDrag = false;
    _observedTransform = _currentTransform;
    final id = _currentId;
    if (id != null) _zoomControllers[id]?.setTransientTranslation(_pageOffset, 0);
    _render?.notePageOffsetChanged();
    setState(() {});
  }

  void _finishHandoff() {
    if (!mounted || !_handoffActive || _pointerCount != 0 || _pageAnimation.isAnimating) return;
    _stopCurrentZoomAnimation();
    if (_pageOffset.abs() <= precisionErrorTolerance || elDisableAnimations) {
      _setPageOffset(0);
      _handoffActive = false;
      _clearPageTarget();
      setState(() {});
      return;
    }
    _startPageAnimation(0);
  }

  void _settlePage(double velocity) {
    _stopCurrentZoomAnimation();
    if (_pageOffset.abs() <= precisionErrorTolerance) {
      _setPageOffset(0);
      _clearPageTarget();
      return;
    }
    final extent = _render?.size.width ?? 0;
    final target = _pageTargetIndex;
    final hasFling = velocity.abs() > _minFlingVelocity;
    final commitsByVelocity = target != null && hasFling && velocity.sign == _pageOffset.sign;
    final commitsByDistance = target != null && extent > 0 && _pageOffset.abs() / extent >= _snapThreshold;
    if (target != null && (commitsByVelocity || (!hasFling && commitsByDistance))) {
      if (elDisableAnimations) {
        _commitPage(target);
      } else {
        _startPageAnimation(-_pageDirection * extent, velocity: velocity);
      }
    } else {
      _animatePageBack(velocity);
    }
  }

  void _animatePageBack([double velocity = 0]) {
    _stopCurrentZoomAnimation();
    if (_pageOffset == 0) {
      _clearPageTarget();
    } else if (elDisableAnimations) {
      _setPageOffset(0);
      _clearPageTarget();
    } else {
      _startPageAnimation(0, velocity: velocity);
    }
  }

  void _startPageAnimation(double target, {double velocity = 0}) {
    _interruptPageAnimation(completeCommand: false);
    _animationTo = target;
    final displacement = _pageOffset - target;
    final crossingVelocity = -math.sqrt(_pageSpring.stiffness / _pageSpring.mass) * displacement;
    final springVelocity = displacement.abs() <= precisionErrorTolerance
        ? 0.0
        : displacement > 0
        ? math.max(velocity, crossingVelocity)
        : math.min(velocity, crossingVelocity);
    _pageAnimation.animateWith(
      SpringSimulation(
        _pageSpring,
        _pageOffset,
        target,
        springVelocity,
        snapToEnd: true,
        tolerance: _pageSpringTolerance,
      ),
    );
  }

  /// 在真实拖动成立时接管分页动画，并把 handoff 的内部平移无跳变地还原到页壳。
  bool _takeOverPageAnimation() {
    if (!_pageAnimation.isAnimating) return false;
    _interruptPageAnimation();
    if (_handoffActive) {
      final id = _currentId;
      if (id != null) _zoomControllers[id]?.setTransientTranslation(0, 0);
      _handoffActive = false;
      _render?.notePageOffsetChanged();
      setState(() {});
    }
    return true;
  }

  void _handlePageAnimationTick() => _setPageOffset(_pageAnimation.value);

  void _handlePageAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _setPageOffset(_animationTo);
    final target = _pageTargetIndex;
    if (_animationTo != 0 && target != null) {
      _commitPage(target);
    } else {
      _setPageOffset(0);
      _clearPageTarget();
      if (_handoffActive) {
        _handoffActive = false;
        setState(() {});
      }
    }
    _completePageCommand();
  }

  void _interruptPageAnimation({bool completeCommand = true}) {
    _pageAnimation.stop();
    if (completeCommand) _completePageCommand();
  }

  void _completePageCommand() {
    final completer = _pageCommandCompleter;
    _pageCommandCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _handleViewportWidthChanged() {
    if (_viewportResetScheduled ||
        (_pageOffset == 0 && _pageTargetIndex == null && !_handoffActive && !_pageAnimation.isAnimating)) {
      return;
    }
    _viewportResetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportResetScheduled = false;
      if (!mounted) return;
      _interruptPageAnimation();
      _setPageOffset(0);
      _pageTargetIndex = null;
      _pageDirection = 0;
      _handoffActive = false;
      _directPageDrag = false;
      _proxyPageDrag = false;
      _panZoomPageDrag = false;
      setState(() {});
    });
  }

  void _setPageOffset(double value) {
    if (_pageOffset == value) return;
    _pageOffset = value.abs() <= precisionErrorTolerance ? 0 : value;
    final id = _currentId;
    if (_handoffActive && id != null) _zoomControllers[id]?.setTransientTranslation(_pageOffset, 0);
    _render?.notePageOffsetChanged();
  }

  void _commitPage(int target, {bool preserveInteraction = false}) {
    final normalized = _normalizeIndex(target);
    if (normalized == null) return;
    _stopCurrentZoomAnimation();
    final oldIndex = _index;
    final adjacent =
        (normalized - oldIndex).abs() == 1 ||
        (widget.loop && _pageDirection != 0 && _adjacentIndex(_pageDirection) == normalized);
    if (!adjacent) {
      _deferredPreloadFirst = math.max(0, oldIndex - widget.preloadCount);
      _deferredPreloadLast = math.min(_ids.length - 1, oldIndex + widget.preloadCount);
    } else {
      _deferredPreloadFirst = null;
      _deferredPreloadLast = null;
    }
    final oldId = _currentId;
    if (oldId != null) _zoomControllers[oldId]?.setTransientTranslation(0, 0);
    _index = normalized;
    _currentId = _ids[_index];
    _observedTransform = _currentTransform;
    _setPageOffset(0);
    _pageTargetIndex = null;
    _pageDirection = 0;
    _handoffActive = false;
    if (!preserveInteraction) {
      _directPageDrag = false;
      _proxyPageDrag = false;
      _panZoomPageDrag = false;
    }
    if (!widget.preserveItemTransform && oldId != null && oldId != _currentId) {
      _zoomControllers[oldId]?.jumpTo(const ElZoomTransform());
    }
    setState(() {});
    if (oldIndex == _index) {
      _syncExternalController();
    } else {
      _reportIndexChanged();
    }
  }

  ElSemantics get _semantics {
    final next = _adjacentIndex(1);
    final previous = _adjacentIndex(-1);
    return ElSemantics(
      container: true,
      explicitChildNodes: true,
      properties: SemanticsProperties(
        value: _ids.isEmpty ? null : '${_index + 1} / ${_ids.length}',
        increasedValue: next == null ? null : '${next + 1} / ${_ids.length}',
        decreasedValue: previous == null ? null : '${previous + 1} / ${_ids.length}',
        onIncrease: next == null ? null : () => unawaited(_goBy(1, animate: true)),
        onDecrease: previous == null ? null : () => unawaited(_goBy(-1, animate: true)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final indices = _mountedIndices();
    if (_deferredPreloadFirst != null && !_preloadRestoreScheduled) {
      _preloadRestoreScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preloadRestoreScheduled = false;
        if (!mounted) return;
        _deferredPreloadFirst = null;
        _deferredPreloadLast = null;
        setState(() {});
      });
    }
    final mountedIds = <Object>{for (final index in indices) _ids[index]};
    _retainOnly(mountedIds);
    final pages = <Widget>[];
    for (final index in indices) {
      final id = _ids[index];
      final active = index == _index;
      final controller = _zoomControllerFor(id);
      pages.add(
        _PreviewPage(
          key: ValueKey<Object>(id),
          child: ElView(
            event: !active ? ElEvent(disabled: true) : null,
            focusNode: active ? null : _blockerNodeFor(id),
            semantics: active ? null : ElSemantics(exclude: true, blockUserActions: true),
            child: ElZoomView(
              controller: controller,
              minScale: widget.minScale,
              maxScale: widget.maxScale,
              doubleTapScale: widget.doubleTapScale,
              scaleSensitivity: widget.scaleSensitivity,
              enableRotation: widget.enableRotation,
              panInertia: widget.panInertia,
              scaleInertia: widget.scaleInertia,
              mouseWheelZoom: widget.mouseWheelZoom,
              mouseDragPan: widget.mouseDragPan,
              wheelScaleSensitivity: widget.wheelScaleSensitivity,
              elasticScaleBounds: true,
              lockScaleRotationIntent: true,
              constrained: widget.constrained,
              alignment: widget.alignment,
              clipBehavior: widget.clipBehavior,
              interactionEnabled: active,
              onPanEnd: active ? _handleProxyDragEnd : null,
              onPanCancel: active ? _handleZoomPanCancel : null,
              onPointerCountChanged: active ? _handleZoomPointerCountChanged : null,
              onTransformChanged: active && (widget.controller != null || _handoffActive)
                  ? (value) => _handleItemTransform(id, value)
                  : null,
              child: _itemAt(context, index),
            ),
          ),
        ),
      );
    }
    final previewEvent = switch (_ids.length) {
      0 => null,
      1 => ElEvent(onPointerDown: _handleSinglePointerDown),
      _ => ElEvent(
        config: widget.mouseDragPan ? null : const ElEventConfig(dragDevices: _nonMouseDragDevices),
        dragProxy: ElDragProxy(onDragPreUpdate: _handleProxyPreUpdate, onDragOverflow: _handleProxyOverflow),
        onPointerDown: _handlePointerDown,
        onPointerUp: _handlePointerTerminal,
        onPointerCancel: _handlePointerCancel,
        onHorizontalDragStart: _handlePageDragStart,
        onHorizontalDragUpdate: _handlePageDragUpdate,
        onHorizontalDragEnd: _handlePageDragEnd,
        onHorizontalDragCancel: _handlePageDragCancel,
        onVerticalDragStart: widget.strictPageDragIntent ? _handleCrossAxisDragStart : null,
        onVerticalDragUpdate: widget.strictPageDragIntent ? _handleCrossAxisDragUpdate : null,
        onVerticalDragEnd: widget.strictPageDragIntent ? _handleCrossAxisDragEnd : null,
        onVerticalDragCancel: widget.strictPageDragIntent ? _handleCrossAxisDragCancel : null,
        onPointerPanZoomStart: _handlePagePanZoomStart,
        onPointerPanZoomUpdate: _handlePagePanZoomUpdate,
        onPointerPanZoomEnd: _handlePagePanZoomEnd,
      ),
    };
    return ElView(
      event: previewEvent,
      semantics: _semantics,
      child: _PreviewViewport(state: this, indices: indices, clipBehavior: widget.clipBehavior, children: pages),
    );
  }
}

class _PreviewViewport extends MultiChildRenderObjectWidget {
  const _PreviewViewport({
    required this.state,
    required this.indices,
    required this.clipBehavior,
    required super.children,
  });

  final _PreviewViewState state;
  final List<int> indices;
  final Clip clipBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPreviewViewport(state, indices, clipBehavior);

  @override
  void updateRenderObject(BuildContext context, _RenderPreviewViewport renderObject) {
    renderObject
      ..indices = indices
      ..clipBehavior = clipBehavior;
  }
}

class _PreviewParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPreviewViewport extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PreviewParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PreviewParentData> {
  _RenderPreviewViewport(this._state, this._indices, this._clipBehavior) {
    _state._render = this;
  }

  final _PreviewViewState _state;
  List<int> _indices;
  Clip _clipBehavior;
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();
  late final PaintingContextCallback _paintPagesCallback = _paintPages;
  Rect _viewportRect = Rect.zero;

  set indices(List<int> value) {
    if (listEquals(_indices, value)) return;
    _indices = value;
    markNeedsLayout();
  }

  set clipBehavior(Clip value) {
    if (_clipBehavior == value) return;
    _clipBehavior = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get isRepaintBoundary => true;

  void notePageOffsetChanged() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PreviewParentData) child.parentData = _PreviewParentData();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError('ElPreviewView 的视口必须同时具有有限宽高。');
    }
    final previousWidth = hasSize ? size.width : 0.0;
    size = constraints.biggest;
    _viewportRect = Offset.zero & size;
    final childConstraints = BoxConstraints.tight(size);
    var child = firstChild;
    while (child != null) {
      child.layout(childConstraints);
      child = (child.parentData! as _PreviewParentData).nextSibling;
    }
    if (previousWidth > precisionErrorTolerance && previousWidth != size.width) {
      _state._handleViewportWidthChanged();
    }
  }

  double _originFor(int index) {
    if (index == _state._index) return _state._handoffActive ? 0 : _state._pageOffset;
    if (index == _state._pageTargetIndex) {
      return _state._pageDirection * size.width + _state._pageOffset;
    }
    var delta = index - _state._index;
    if (_state.widget.loop && _state._ids.length > 1) {
      final forward = delta % _state._ids.length;
      final backward = forward - _state._ids.length;
      delta = backward.abs() < forward.abs() ? backward : forward;
    }
    return delta * size.width + _state._pageOffset;
  }

  RenderBox? get _currentChild {
    var slot = 0;
    var child = firstChild;
    while (child != null) {
      if (_indices[slot] == _state._index) return child;
      child = (child.parentData! as _PreviewParentData).nextSibling;
      slot++;
    }
    return null;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = _currentChild;
    if (child == null) return false;
    final offset = Offset(_originFor(_state._index), 0);
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final child = _currentChild;
    if (child != null) visitor(child);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    var slot = 0;
    var current = firstChild;
    while (current != null && !identical(current, child)) {
      current = (current.parentData! as _PreviewParentData).nextSibling;
      slot++;
    }
    if (current != null) transform.translateByDouble(_originFor(_indices[slot]), 0, 0, 1);
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _clipBehavior == Clip.none ? null : _viewportRect;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (childCount == 0 || size.isEmpty) {
      _clipLayer.layer = null;
      return;
    }
    if (_clipBehavior == Clip.none) {
      _clipLayer.layer = null;
      _paintPages(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      _viewportRect,
      _paintPagesCallback,
      clipBehavior: _clipBehavior,
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintPages(PaintingContext context, Offset offset) {
    var slot = 0;
    var child = firstChild;
    while (child != null) {
      final index = _indices[slot++];
      final target = _state._pageTargetIndex;
      if ((!_state._handoffActive || index == _state._index || index == target) &&
          (target == null || index == _state._index || index == target)) {
        final dx = _originFor(index);
        if (dx < size.width && dx + size.width > 0) {
          context.paintChild(child, Offset(offset.dx + dx, offset.dy));
        }
      }
      child = (child.parentData! as _PreviewParentData).nextSibling;
    }
  }

  @override
  void dispose() {
    if (identical(_state._render, this)) _state._render = null;
    _clipLayer.layer = null;
    super.dispose();
  }
}

class _PreviewPage extends SingleChildRenderObjectWidget {
  const _PreviewPage({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPreviewPage();
}

class _RenderPreviewPage extends RenderProxyBox {
  @override
  bool get isRepaintBoundary => true;
}
