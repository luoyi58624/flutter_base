import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../common/viewport/scroll_engine_position.dart';
import 'scrollbar_base.dart';

typedef _AxisState = ({
  AxisDirection direction,
  double min,
  double max,
  double pixels,
  double viewport,
  bool scrolling,
});

typedef _DetailsState = ({_AxisState? vertical, _AxisState? horizontal});

/// 滚动宿主持有的双轴滚动条状态，不创建 Widget 或 RenderObject。
final class ScrollbarController extends ChangeNotifier implements ElScrollbarDetails {
  /// 将真实 position 与滚动条交互连接。
  ScrollbarController({
    required ScrollPosition? verticalPosition,
    required ScrollPosition? horizontalPosition,
    ScrollbarThumbDragDelegate? verticalThumbDragDelegate,
    ScrollbarThumbDragDelegate? horizontalThumbDragDelegate,
    required bool Function(PointerSignalEvent event) dispatchPointerSignal,
  }) : _vertical = verticalPosition == null
           ? null
           : _ScrollbarAxisDetails(
               axis: Axis.vertical,
               position: verticalPosition,
               thumbDragDelegate: verticalThumbDragDelegate,
             ),
       _horizontal = horizontalPosition == null
           ? null
           : _ScrollbarAxisDetails(
               axis: Axis.horizontal,
               position: horizontalPosition,
               thumbDragDelegate: horizontalThumbDragDelegate,
             ),
       // ignore: prefer_initializing_formals - 命名参数映射到私有回调字段。
       _dispatchPointerSignal = dispatchPointerSignal {
    _vertical?.addListener(_sync);
    _horizontal?.addListener(_sync);
    _state = _captureState();
  }

  _ScrollbarAxisDetails? _vertical;
  _ScrollbarAxisDetails? _horizontal;
  final bool Function(PointerSignalEvent event) _dispatchPointerSignal;
  late _DetailsState _state;

  @override
  ElScrollbarAxisDetails? operator [](Axis axis) {
    return axis == Axis.vertical ? _vertical : _horizontal;
  }

  @override
  bool dispatchPointerSignal(PointerSignalEvent event) => _dispatchPointerSignal(event);

  /// 宿主结构更新时换绑真实 position。
  void updatePositions({required ScrollPosition? verticalPosition, required ScrollPosition? horizontalPosition}) {
    _vertical = _updateAxis(_vertical, Axis.vertical, verticalPosition);
    _horizontal = _updateAxis(_horizontal, Axis.horizontal, horizontalPosition);
    _sync();
  }

  _ScrollbarAxisDetails? _updateAxis(_ScrollbarAxisDetails? current, Axis axis, ScrollPosition? position) {
    if (position == null) {
      current?.removeListener(_sync);
      current?.dispose();
      return null;
    }
    if (current == null) {
      return _ScrollbarAxisDetails(axis: axis, position: position)..addListener(_sync);
    }
    if (!identical(current.position, position)) {
      current
        ..removeListener(_sync)
        ..updatePosition(position)
        ..addListener(_sync);
    }
    return current;
  }

  /// 更新虚拟内容的 thumb 分数映射。
  void updateThumbDragDelegates({ScrollbarThumbDragDelegate? vertical, ScrollbarThumbDragDelegate? horizontal}) {
    _vertical?.thumbDragDelegate = vertical;
    _horizontal?.thumbDragDelegate = horizontal;
  }

  void _sync() {
    final next = _captureState();
    if (_state == next) return;
    // position 的 metrics 通知可能来自 render performLayout 内
    // (applyContentDimensions),此时驱动 ChangeNotifier 会触发
    // build-during-frame 断言;persistentCallbacks 阶段延到帧尾合并派发。
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_postFrameSyncScheduled) return;
      _postFrameSyncScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _postFrameSyncScheduled = false;
        if (_disposed) return;
        _sync();
      });
      return;
    }
    _state = next;
    notifyListeners();
  }

  bool _postFrameSyncScheduled = false;
  bool _disposed = false;

  _DetailsState _captureState() {
    return (vertical: _captureAxis(_vertical), horizontal: _captureAxis(_horizontal));
  }

  _AxisState? _captureAxis(_ScrollbarAxisDetails? axis) {
    if (axis == null) return null;
    return (
      direction: axis.axisDirection,
      min: axis.minScrollExtent,
      max: axis.maxScrollExtent,
      pixels: axis.pixels,
      viewport: axis.viewportExtent,
      scrolling: axis.isScrolling,
    );
  }

  /// 布局尺寸更新后刷新快照，布局期通知自动合并到帧尾。
  void refresh() => _sync();

  @override
  void dispose() {
    _disposed = true;
    _vertical
      ?..removeListener(_sync)
      ..dispose();
    _horizontal
      ?..removeListener(_sync)
      ..dispose();
    super.dispose();
  }
}

final class _ScrollbarAxisDetails extends ChangeNotifier implements ElScrollbarAxisDetails {
  _ScrollbarAxisDetails({required this.axis, required ScrollPosition position, this.thumbDragDelegate})
    // ignore: prefer_initializing_formals — 命名参数 position 映射私有字段。
    : _position = position {
    _position.addListener(notifyListeners);
    _position.isScrollingNotifier.addListener(notifyListeners);
  }

  @override
  final Axis axis;
  ScrollPosition _position;
  ScrollHoldController? _hold;
  bool _thumbDragActive = false;

  /// 虚拟滚动 thumb 拖拽映射覆盖;null 走线性 fraction→pixels。
  ScrollbarThumbDragDelegate? thumbDragDelegate;

  ScrollPosition get position => _position;

  bool get _hasMetrics => _position.hasPixels && _position.hasContentDimensions;

  void updatePosition(ScrollPosition value) {
    if (identical(_position, value)) return;
    _position
      ..removeListener(notifyListeners)
      ..isScrollingNotifier.removeListener(notifyListeners);
    _position = value
      ..addListener(notifyListeners)
      ..isScrollingNotifier.addListener(notifyListeners);
    notifyListeners();
  }

  @override
  AxisDirection get axisDirection => _position.axisDirection;

  @override
  double get minScrollExtent => _hasMetrics ? _position.minScrollExtent : 0.0;

  @override
  double get maxScrollExtent => _hasMetrics ? _position.maxScrollExtent : 0.0;

  @override
  double get pixels => _hasMetrics ? _position.pixels : 0.0;

  @override
  double get viewportExtent => _hasMetrics ? _position.viewportDimension : 0.0;

  @override
  bool get isScrolling => _position.isScrollingNotifier.value;

  @override
  bool get isScrollable => maxScrollExtent > minScrollExtent;

  @override
  bool get isReversed {
    return axisDirection == AxisDirection.up || axisDirection == AxisDirection.left;
  }

  @override
  double get fraction => fractionForPixels(pixels);

  @override
  double get visualFraction => isReversed ? 1.0 - fraction : fraction;

  @override
  bool get canScrollLeading {
    return isReversed ? pixels < maxScrollExtent : pixels > minScrollExtent;
  }

  @override
  bool get canScrollTrailing {
    return isReversed ? pixels > minScrollExtent : pixels < maxScrollExtent;
  }

  @override
  double fractionForPixels(double pixels) {
    final extent = maxScrollExtent - minScrollExtent;
    if (extent <= 0.0) return 0.0;
    return ((pixels - minScrollExtent) / extent).clamp(0.0, 1.0).toDouble();
  }

  @override
  double pixelsForFraction(double fraction) {
    return _pixelsInRange(minScrollExtent, maxScrollExtent, fraction, isReversed);
  }

  /// 视觉分数 → position 像素:反转轴(reverse)分数 0 对应像素 max。
  static double _pixelsInRange(double min, double max, double visualFraction, bool reversed) {
    final f = visualFraction.clamp(0.0, 1.0);
    return reversed ? max - (max - min) * f : min + (max - min) * f;
  }

  @override
  void scrollByLine({required bool forward}) {
    // forward 语义是"视觉 trailing 方向";反转轴的像素方向相反。
    final direction = (forward ? 1.0 : -1.0) * (isReversed ? -1.0 : 1.0);
    scrollByPixels((viewportExtent * 0.1).clamp(16.0, 48.0) * direction);
  }

  @override
  void scrollByPage({required bool forward}) {
    final direction = (forward ? 1.0 : -1.0) * (isReversed ? -1.0 : 1.0);
    scrollByPixels(viewportExtent * 0.8 * direction);
  }

  @override
  void scrollByPixels(double delta) {
    if (!isScrollable) return;
    jumpToPixels(_position.pixels + delta);
  }

  @override
  void jumpToPixels(double pixels) {
    if (!isScrollable) return;
    final target = pixels.clamp(minScrollExtent, maxScrollExtent).toDouble();
    if ((target - _position.pixels).abs() <= precisionErrorTolerance) return;
    if (_position case final ScrollEnginePosition position) {
      position.jumpToFromInput(target);
    } else {
      _position.jumpTo(target);
    }
  }

  @override
  Future<void> animateToPixels(double pixels, {required Duration duration, Curve curve = Curves.easeOut}) {
    if (!isScrollable) return Future<void>.value();
    final target = pixels.clamp(minScrollExtent, maxScrollExtent).toDouble();
    if ((target - _position.pixels).abs() <= precisionErrorTolerance) return Future<void>.value();
    return _position is ScrollEnginePosition
        ? (_position as ScrollEnginePosition).animateToFromInput(target, duration: duration, curve: curve)
        : _position.animateTo(target, duration: duration, curve: curve);
  }

  @override
  void jumpToFraction(double fraction) => jumpToPixels(pixelsForFraction(fraction));

  @override
  void beginThumbDrag() {
    if (!isScrollable || _thumbDragActive) return;
    _thumbDragActive = true;
    // 冻结拖拽会话的滚动范围:按住期间内容尺寸变化不得重映射手上的
    // thumb 位置(沿旧集成条的 drag session 语义);delegate 路径自带模型映射。
    _dragSessionMin = _position.minScrollExtent;
    _dragSessionMax = _position.maxScrollExtent;
    _hold = _position.hold(_handleHoldCancelled);
    thumbDragDelegate?.beginThumbDrag();
  }

  double? _dragSessionMin;
  double? _dragSessionMax;

  void _handleHoldCancelled() => _hold = null;

  @override
  void updateThumbDrag(double fraction) {
    final delegated = _thumbDragActive ? thumbDragDelegate?.pixelsForThumbFraction(fraction) : null;
    if (delegated != null) {
      jumpToPixels(delegated);
      return;
    }
    final min = _dragSessionMin;
    final max = _dragSessionMax;
    final target = _thumbDragActive && min != null && max != null
        ? _pixelsInRange(min, max, fraction, isReversed)
        : pixelsForFraction(fraction);
    jumpToPixels(target);
  }

  @override
  void endThumbDrag() {
    _hold?.cancel();
    _hold = null;
    _dragSessionMin = null;
    _dragSessionMax = null;
    if (_thumbDragActive) {
      _thumbDragActive = false;
      thumbDragDelegate?.endThumbDrag();
    }
  }

  @override
  void cancelInteraction() => endThumbDrag();

  @override
  void dispose() {
    _position
      ..removeListener(notifyListeners)
      ..isScrollingNotifier.removeListener(notifyListeners);
    _hold?.cancel();
    _hold = null;
    super.dispose();
  }
}
