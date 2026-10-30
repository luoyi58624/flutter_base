// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// ElModelCodeGenerator
// **************************************************************************

extension ElEventConfigExt on ElEventConfig {
  /// 复制声明；省略保留原值，可空字段显式传 null 时清空。
  ElEventConfig copyWith({
    Object? doubleTapInterval = $absent,
    Object? tripleTapInterval = $absent,
    Object? longPressDelay = $absent,
    Object? longPressCancelDistance = $absent,
    Object? tapCancelDistance = $absent,
    Object? tapCancelByDistance = $absent,
    Object? delayTouchDown = $absent,
    Object? delayTouchUp = $absent,
    Object? deferTap = $absent,
    Object? dragStartDistance = $absent,
    Object? dragDevices = $absent,
    Object? dragHorizontalAngle = $absent,
    Object? dragMinFlingDistance = $absent,
    Object? dragMinFlingVelocity = $absent,
    Object? dragMaxFlingVelocity = $absent,
  }) {
    return ElEventConfig(
      doubleTapInterval: identical(doubleTapInterval, $absent) ? _doubleTapInterval : doubleTapInterval as Duration?,
      tripleTapInterval: identical(tripleTapInterval, $absent) ? _tripleTapInterval : tripleTapInterval as Duration?,
      longPressDelay: identical(longPressDelay, $absent) ? _longPressDelay : longPressDelay as Duration?,
      longPressCancelDistance: identical(longPressCancelDistance, $absent)
          ? this.longPressCancelDistance
          : (longPressCancelDistance as num?)?.toDouble(),
      tapCancelDistance: identical(tapCancelDistance, $absent)
          ? _tapCancelDistance
          : (tapCancelDistance as num?)?.toDouble(),
      tapCancelByDistance: identical(tapCancelByDistance, $absent)
          ? _tapCancelByDistance
          : tapCancelByDistance as bool?,
      delayTouchDown: identical(delayTouchDown, $absent) ? _delayTouchDown : delayTouchDown as Duration?,
      delayTouchUp: identical(delayTouchUp, $absent) ? _delayTouchUp : delayTouchUp as Duration?,
      deferTap: identical(deferTap, $absent) ? _deferTap : deferTap as bool?,
      dragStartDistance: identical(dragStartDistance, $absent)
          ? this.dragStartDistance
          : (dragStartDistance as num?)?.toDouble(),
      dragDevices: identical(dragDevices, $absent) ? this.dragDevices : dragDevices as Set<PointerDeviceKind>?,
      dragHorizontalAngle: identical(dragHorizontalAngle, $absent)
          ? _dragHorizontalAngle
          : (dragHorizontalAngle as num?)?.toDouble(),
      dragMinFlingDistance: identical(dragMinFlingDistance, $absent)
          ? this.dragMinFlingDistance
          : (dragMinFlingDistance as num?)?.toDouble(),
      dragMinFlingVelocity: identical(dragMinFlingVelocity, $absent)
          ? _dragMinFlingVelocity
          : (dragMinFlingVelocity as num?)?.toDouble(),
      dragMaxFlingVelocity: identical(dragMaxFlingVelocity, $absent)
          ? _dragMaxFlingVelocity
          : (dragMaxFlingVelocity as num?)?.toDouble(),
    );
  }

  /// 合并声明；对方的可空字段为 null 时保留当前值。
  ElEventConfig merge([ElEventConfig? other]) {
    if (other == null) return this;
    return ElEventConfig(
      doubleTapInterval: other._doubleTapInterval ?? _doubleTapInterval,
      tripleTapInterval: other._tripleTapInterval ?? _tripleTapInterval,
      longPressDelay: other._longPressDelay ?? _longPressDelay,
      longPressCancelDistance: other.longPressCancelDistance ?? longPressCancelDistance,
      tapCancelDistance: other._tapCancelDistance ?? _tapCancelDistance,
      tapCancelByDistance: other._tapCancelByDistance ?? _tapCancelByDistance,
      delayTouchDown: other._delayTouchDown ?? _delayTouchDown,
      delayTouchUp: other._delayTouchUp ?? _delayTouchUp,
      deferTap: other._deferTap ?? _deferTap,
      dragStartDistance: other.dragStartDistance ?? dragStartDistance,
      dragDevices: other.dragDevices ?? dragDevices,
      dragHorizontalAngle: other._dragHorizontalAngle ?? _dragHorizontalAngle,
      dragMinFlingDistance: other.dragMinFlingDistance ?? dragMinFlingDistance,
      dragMinFlingVelocity: other._dragMinFlingVelocity ?? _dragMinFlingVelocity,
      dragMaxFlingVelocity: other._dragMaxFlingVelocity ?? _dragMaxFlingVelocity,
    );
  }

  List<Object?> get _props => [
    _doubleTapInterval,
    _tripleTapInterval,
    _longPressDelay,
    longPressCancelDistance,
    _tapCancelDistance,
    _tapCancelByDistance,
    _delayTouchDown,
    _delayTouchUp,
    _deferTap,
    dragStartDistance,
    dragDevices,
    _dragHorizontalAngle,
    dragMinFlingDistance,
    _dragMinFlingVelocity,
    _dragMaxFlingVelocity,
  ];
}

extension ElDragProxyExt on ElDragProxy {
  /// 复制声明；省略保留原值，可空字段显式传 null 时清空。
  ElDragProxy copyWith({
    Object? axis = $absent,
    Object? onDragPreUpdate = $absent,
    Object? onDragOverflow = $absent,
    Object? boundaryHandoff,
  }) {
    return ElDragProxy(
      axis: identical(axis, $absent) ? this.axis : axis as Axis?,
      onDragPreUpdate: identical(onDragPreUpdate, $absent)
          ? this.onDragPreUpdate
          : onDragPreUpdate as void Function(ElEventDetails)?,
      onDragOverflow: identical(onDragOverflow, $absent)
          ? this.onDragOverflow
          : onDragOverflow as void Function(ElEventDetails)?,
      boundaryHandoff: boundaryHandoff == null ? this.boundaryHandoff : boundaryHandoff as Set<AxisDirection>,
    );
  }

  /// 合并声明；对方的可空字段为 null 时保留当前值。
  ElDragProxy merge([ElDragProxy? other]) {
    if (other == null) return this;
    return ElDragProxy(
      axis: other.axis ?? axis,
      onDragPreUpdate: other.onDragPreUpdate ?? onDragPreUpdate,
      onDragOverflow: other.onDragOverflow ?? onDragOverflow,
      boundaryHandoff: other.boundaryHandoff,
    );
  }
}

extension ElEventExt on ElEvent {
  /// 复制声明；省略保留原值，可空字段显式传 null 时清空。
  ElEvent copyWith({
    Object? config = $absent,
    Object? dragProxy = $absent,
    Object? behavior,
    Object? cursor = $absent,
    Object? disabled,
    Object? rotationStartEnabled,
    Object? onPointerEnter = $absent,
    Object? onPointerHover = $absent,
    Object? onPointerExit = $absent,
    Object? onPointerDown = $absent,
    Object? onPointerMove = $absent,
    Object? onPointerUp = $absent,
    Object? onPointerCancel = $absent,
    Object? onPointerPanZoomStart = $absent,
    Object? onPointerPanZoomUpdate = $absent,
    Object? onPointerPanZoomEnd = $absent,
    Object? onPointerSignal = $absent,
    Object? onTapDown = $absent,
    Object? onTapUp = $absent,
    Object? onTap = $absent,
    Object? onDoubleTap = $absent,
    Object? onDoubleTapDown = $absent,
    Object? onTripleTap = $absent,
    Object? onTripleTapDown = $absent,
    Object? onSecondaryTapDown = $absent,
    Object? onSecondaryTapUp = $absent,
    Object? onSecondaryTap = $absent,
    Object? onTertiaryTapDown = $absent,
    Object? onTertiaryTapUp = $absent,
    Object? onTertiaryTap = $absent,
    Object? onForwardTapDown = $absent,
    Object? onForwardTapUp = $absent,
    Object? onForwardTap = $absent,
    Object? onBackTapDown = $absent,
    Object? onBackTapUp = $absent,
    Object? onBackTap = $absent,
    Object? onLongPress = $absent,
    Object? onTapCancel = $absent,
    Object? onDragDown = $absent,
    Object? onDragStart = $absent,
    Object? onDragUpdate = $absent,
    Object? onDragEnd = $absent,
    Object? onDragCancel = $absent,
    Object? onVerticalDragStart = $absent,
    Object? onVerticalDragUpdate = $absent,
    Object? onVerticalDragEnd = $absent,
    Object? onVerticalDragCancel = $absent,
    Object? onHorizontalDragStart = $absent,
    Object? onHorizontalDragUpdate = $absent,
    Object? onHorizontalDragEnd = $absent,
    Object? onHorizontalDragCancel = $absent,
    Object? onScaleStart = $absent,
    Object? onScaleUpdate = $absent,
    Object? onScaleEnd = $absent,
    Object? onScaleCancel = $absent,
    Object? onRotationUpdate = $absent,
    Object? onKeyDown = $absent,
    Object? onKeyRepeat = $absent,
    Object? onKeyUp = $absent,
    Object? onFocus = $absent,
    Object? onBlur = $absent,
  }) {
    return ElEvent(
      config: identical(config, $absent)
          ? this.config
          : (config == null
                ? null
                : (this.config == null ? config as ElEventConfig : this.config!.merge(config as ElEventConfig))),
      dragProxy: identical(dragProxy, $absent)
          ? this.dragProxy
          : (dragProxy == null
                ? null
                : (this.dragProxy == null
                      ? dragProxy as ElDragProxy
                      : this.dragProxy!.merge(dragProxy as ElDragProxy))),
      behavior: behavior == null ? this.behavior : behavior as HitTestBehavior,
      cursor: identical(cursor, $absent) ? this.cursor : cursor as MouseCursor?,
      disabled: disabled == null ? this.disabled : disabled as bool,
      rotationStartEnabled: rotationStartEnabled == null ? this.rotationStartEnabled : rotationStartEnabled as bool,
      onPointerEnter: identical(onPointerEnter, $absent)
          ? this.onPointerEnter
          : onPointerEnter as void Function(ElEventDetails)?,
      onPointerHover: identical(onPointerHover, $absent)
          ? this.onPointerHover
          : onPointerHover as void Function(ElEventDetails)?,
      onPointerExit: identical(onPointerExit, $absent)
          ? this.onPointerExit
          : onPointerExit as void Function(ElEventDetails)?,
      onPointerDown: identical(onPointerDown, $absent)
          ? this.onPointerDown
          : onPointerDown as void Function(ElEventDetails)?,
      onPointerMove: identical(onPointerMove, $absent)
          ? this.onPointerMove
          : onPointerMove as void Function(ElEventDetails)?,
      onPointerUp: identical(onPointerUp, $absent) ? this.onPointerUp : onPointerUp as void Function(ElEventDetails)?,
      onPointerCancel: identical(onPointerCancel, $absent)
          ? this.onPointerCancel
          : onPointerCancel as void Function(ElEventDetails)?,
      onPointerPanZoomStart: identical(onPointerPanZoomStart, $absent)
          ? this.onPointerPanZoomStart
          : onPointerPanZoomStart as void Function(ElEventDetails)?,
      onPointerPanZoomUpdate: identical(onPointerPanZoomUpdate, $absent)
          ? this.onPointerPanZoomUpdate
          : onPointerPanZoomUpdate as void Function(ElEventDetails)?,
      onPointerPanZoomEnd: identical(onPointerPanZoomEnd, $absent)
          ? this.onPointerPanZoomEnd
          : onPointerPanZoomEnd as void Function(ElEventDetails)?,
      onPointerSignal: identical(onPointerSignal, $absent)
          ? this.onPointerSignal
          : onPointerSignal as void Function(ElEventDetails)?,
      onTapDown: identical(onTapDown, $absent) ? this.onTapDown : onTapDown as void Function(ElEventDetails)?,
      onTapUp: identical(onTapUp, $absent) ? this.onTapUp : onTapUp as void Function(ElEventDetails)?,
      onTap: identical(onTap, $absent) ? this.onTap : onTap as void Function(ElEventDetails)?,
      onDoubleTap: identical(onDoubleTap, $absent) ? this.onDoubleTap : onDoubleTap as void Function(ElEventDetails)?,
      onDoubleTapDown: identical(onDoubleTapDown, $absent)
          ? this.onDoubleTapDown
          : onDoubleTapDown as void Function(ElEventDetails)?,
      onTripleTap: identical(onTripleTap, $absent) ? this.onTripleTap : onTripleTap as void Function(ElEventDetails)?,
      onTripleTapDown: identical(onTripleTapDown, $absent)
          ? this.onTripleTapDown
          : onTripleTapDown as void Function(ElEventDetails)?,
      onSecondaryTapDown: identical(onSecondaryTapDown, $absent)
          ? this.onSecondaryTapDown
          : onSecondaryTapDown as void Function(ElEventDetails)?,
      onSecondaryTapUp: identical(onSecondaryTapUp, $absent)
          ? this.onSecondaryTapUp
          : onSecondaryTapUp as void Function(ElEventDetails)?,
      onSecondaryTap: identical(onSecondaryTap, $absent)
          ? this.onSecondaryTap
          : onSecondaryTap as void Function(ElEventDetails)?,
      onTertiaryTapDown: identical(onTertiaryTapDown, $absent)
          ? this.onTertiaryTapDown
          : onTertiaryTapDown as void Function(ElEventDetails)?,
      onTertiaryTapUp: identical(onTertiaryTapUp, $absent)
          ? this.onTertiaryTapUp
          : onTertiaryTapUp as void Function(ElEventDetails)?,
      onTertiaryTap: identical(onTertiaryTap, $absent)
          ? this.onTertiaryTap
          : onTertiaryTap as void Function(ElEventDetails)?,
      onForwardTapDown: identical(onForwardTapDown, $absent)
          ? this.onForwardTapDown
          : onForwardTapDown as void Function(ElEventDetails)?,
      onForwardTapUp: identical(onForwardTapUp, $absent)
          ? this.onForwardTapUp
          : onForwardTapUp as void Function(ElEventDetails)?,
      onForwardTap: identical(onForwardTap, $absent)
          ? this.onForwardTap
          : onForwardTap as void Function(ElEventDetails)?,
      onBackTapDown: identical(onBackTapDown, $absent)
          ? this.onBackTapDown
          : onBackTapDown as void Function(ElEventDetails)?,
      onBackTapUp: identical(onBackTapUp, $absent) ? this.onBackTapUp : onBackTapUp as void Function(ElEventDetails)?,
      onBackTap: identical(onBackTap, $absent) ? this.onBackTap : onBackTap as void Function(ElEventDetails)?,
      onLongPress: identical(onLongPress, $absent) ? this.onLongPress : onLongPress as void Function(ElEventDetails)?,
      onTapCancel: identical(onTapCancel, $absent) ? this.onTapCancel : onTapCancel as void Function(ElEventDetails)?,
      onDragDown: identical(onDragDown, $absent) ? this.onDragDown : onDragDown as void Function(ElEventDetails)?,
      onDragStart: identical(onDragStart, $absent) ? this.onDragStart : onDragStart as void Function(ElEventDetails)?,
      onDragUpdate: identical(onDragUpdate, $absent)
          ? this.onDragUpdate
          : onDragUpdate as void Function(ElEventDetails)?,
      onDragEnd: identical(onDragEnd, $absent) ? this.onDragEnd : onDragEnd as void Function(ElEventDetails)?,
      onDragCancel: identical(onDragCancel, $absent)
          ? this.onDragCancel
          : onDragCancel as void Function(ElEventDetails)?,
      onVerticalDragStart: identical(onVerticalDragStart, $absent)
          ? this.onVerticalDragStart
          : onVerticalDragStart as void Function(ElEventDetails)?,
      onVerticalDragUpdate: identical(onVerticalDragUpdate, $absent)
          ? this.onVerticalDragUpdate
          : onVerticalDragUpdate as void Function(ElEventDetails)?,
      onVerticalDragEnd: identical(onVerticalDragEnd, $absent)
          ? this.onVerticalDragEnd
          : onVerticalDragEnd as void Function(ElEventDetails)?,
      onVerticalDragCancel: identical(onVerticalDragCancel, $absent)
          ? this.onVerticalDragCancel
          : onVerticalDragCancel as void Function(ElEventDetails)?,
      onHorizontalDragStart: identical(onHorizontalDragStart, $absent)
          ? this.onHorizontalDragStart
          : onHorizontalDragStart as void Function(ElEventDetails)?,
      onHorizontalDragUpdate: identical(onHorizontalDragUpdate, $absent)
          ? this.onHorizontalDragUpdate
          : onHorizontalDragUpdate as void Function(ElEventDetails)?,
      onHorizontalDragEnd: identical(onHorizontalDragEnd, $absent)
          ? this.onHorizontalDragEnd
          : onHorizontalDragEnd as void Function(ElEventDetails)?,
      onHorizontalDragCancel: identical(onHorizontalDragCancel, $absent)
          ? this.onHorizontalDragCancel
          : onHorizontalDragCancel as void Function(ElEventDetails)?,
      onScaleStart: identical(onScaleStart, $absent)
          ? this.onScaleStart
          : onScaleStart as void Function(ElEventDetails)?,
      onScaleUpdate: identical(onScaleUpdate, $absent)
          ? this.onScaleUpdate
          : onScaleUpdate as void Function(ElEventDetails)?,
      onScaleEnd: identical(onScaleEnd, $absent) ? this.onScaleEnd : onScaleEnd as void Function(ElEventDetails)?,
      onScaleCancel: identical(onScaleCancel, $absent)
          ? this.onScaleCancel
          : onScaleCancel as void Function(ElEventDetails)?,
      onRotationUpdate: identical(onRotationUpdate, $absent)
          ? this.onRotationUpdate
          : onRotationUpdate as void Function(ElEventDetails)?,
      onKeyDown: identical(onKeyDown, $absent) ? this.onKeyDown : onKeyDown as void Function(ElEventDetails)?,
      onKeyRepeat: identical(onKeyRepeat, $absent) ? this.onKeyRepeat : onKeyRepeat as void Function(ElEventDetails)?,
      onKeyUp: identical(onKeyUp, $absent) ? this.onKeyUp : onKeyUp as void Function(ElEventDetails)?,
      onFocus: identical(onFocus, $absent) ? this.onFocus : onFocus as void Function(ElEventDetails)?,
      onBlur: identical(onBlur, $absent) ? this.onBlur : onBlur as void Function(ElEventDetails)?,
    );
  }

  /// 合并声明；对方的可空字段为 null 时保留当前值。
  ElEvent merge([ElEvent? other]) {
    if (other == null) return this;
    return ElEvent(
      config: config == null ? other.config : config!.merge(other.config),
      dragProxy: dragProxy == null ? other.dragProxy : dragProxy!.merge(other.dragProxy),
      behavior: other.behavior,
      cursor: other.cursor ?? cursor,
      disabled: other.disabled,
      rotationStartEnabled: other.rotationStartEnabled,
      onPointerEnter: other.onPointerEnter ?? onPointerEnter,
      onPointerHover: other.onPointerHover ?? onPointerHover,
      onPointerExit: other.onPointerExit ?? onPointerExit,
      onPointerDown: other.onPointerDown ?? onPointerDown,
      onPointerMove: other.onPointerMove ?? onPointerMove,
      onPointerUp: other.onPointerUp ?? onPointerUp,
      onPointerCancel: other.onPointerCancel ?? onPointerCancel,
      onPointerPanZoomStart: other.onPointerPanZoomStart ?? onPointerPanZoomStart,
      onPointerPanZoomUpdate: other.onPointerPanZoomUpdate ?? onPointerPanZoomUpdate,
      onPointerPanZoomEnd: other.onPointerPanZoomEnd ?? onPointerPanZoomEnd,
      onPointerSignal: other.onPointerSignal ?? onPointerSignal,
      onTapDown: other.onTapDown ?? onTapDown,
      onTapUp: other.onTapUp ?? onTapUp,
      onTap: other.onTap ?? onTap,
      onDoubleTap: other.onDoubleTap ?? onDoubleTap,
      onDoubleTapDown: other.onDoubleTapDown ?? onDoubleTapDown,
      onTripleTap: other.onTripleTap ?? onTripleTap,
      onTripleTapDown: other.onTripleTapDown ?? onTripleTapDown,
      onSecondaryTapDown: other.onSecondaryTapDown ?? onSecondaryTapDown,
      onSecondaryTapUp: other.onSecondaryTapUp ?? onSecondaryTapUp,
      onSecondaryTap: other.onSecondaryTap ?? onSecondaryTap,
      onTertiaryTapDown: other.onTertiaryTapDown ?? onTertiaryTapDown,
      onTertiaryTapUp: other.onTertiaryTapUp ?? onTertiaryTapUp,
      onTertiaryTap: other.onTertiaryTap ?? onTertiaryTap,
      onForwardTapDown: other.onForwardTapDown ?? onForwardTapDown,
      onForwardTapUp: other.onForwardTapUp ?? onForwardTapUp,
      onForwardTap: other.onForwardTap ?? onForwardTap,
      onBackTapDown: other.onBackTapDown ?? onBackTapDown,
      onBackTapUp: other.onBackTapUp ?? onBackTapUp,
      onBackTap: other.onBackTap ?? onBackTap,
      onLongPress: other.onLongPress ?? onLongPress,
      onTapCancel: other.onTapCancel ?? onTapCancel,
      onDragDown: other.onDragDown ?? onDragDown,
      onDragStart: other.onDragStart ?? onDragStart,
      onDragUpdate: other.onDragUpdate ?? onDragUpdate,
      onDragEnd: other.onDragEnd ?? onDragEnd,
      onDragCancel: other.onDragCancel ?? onDragCancel,
      onVerticalDragStart: other.onVerticalDragStart ?? onVerticalDragStart,
      onVerticalDragUpdate: other.onVerticalDragUpdate ?? onVerticalDragUpdate,
      onVerticalDragEnd: other.onVerticalDragEnd ?? onVerticalDragEnd,
      onVerticalDragCancel: other.onVerticalDragCancel ?? onVerticalDragCancel,
      onHorizontalDragStart: other.onHorizontalDragStart ?? onHorizontalDragStart,
      onHorizontalDragUpdate: other.onHorizontalDragUpdate ?? onHorizontalDragUpdate,
      onHorizontalDragEnd: other.onHorizontalDragEnd ?? onHorizontalDragEnd,
      onHorizontalDragCancel: other.onHorizontalDragCancel ?? onHorizontalDragCancel,
      onScaleStart: other.onScaleStart ?? onScaleStart,
      onScaleUpdate: other.onScaleUpdate ?? onScaleUpdate,
      onScaleEnd: other.onScaleEnd ?? onScaleEnd,
      onScaleCancel: other.onScaleCancel ?? onScaleCancel,
      onRotationUpdate: other.onRotationUpdate ?? onRotationUpdate,
      onKeyDown: other.onKeyDown ?? onKeyDown,
      onKeyRepeat: other.onKeyRepeat ?? onKeyRepeat,
      onKeyUp: other.onKeyUp ?? onKeyUp,
      onFocus: other.onFocus ?? onFocus,
      onBlur: other.onBlur ?? onBlur,
    );
  }
}
