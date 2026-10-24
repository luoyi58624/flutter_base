// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// _ModelGenerator
// **************************************************************************

extension ElDragProxyExt on ElDragProxy {
  ElDragProxy copyWith({
    Object? axis = $absent,
    Object? onDragPreUpdate = $absent,
    Object? onDragOverflow = $absent,
  }) {
    return ElDragProxy(
      axis: identical(axis, $absent) ? this.axis : axis as Axis?,
      onDragPreUpdate: identical(onDragPreUpdate, $absent)
          ? this.onDragPreUpdate
          : onDragPreUpdate as void Function(ElEventCallback)?,
      onDragOverflow: identical(onDragOverflow, $absent)
          ? this.onDragOverflow
          : onDragOverflow as void Function(ElEventCallback)?,
    );
  }
}

extension ElEventExt on ElEvent {
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
  }) {
    return ElEvent(
      config: identical(config, $absent)
          ? this.config
          : config as ElEventConfig?,
      dragProxy: identical(dragProxy, $absent)
          ? this.dragProxy
          : dragProxy as ElDragProxy?,
      behavior: behavior == null ? this.behavior : behavior as HitTestBehavior,
      cursor: identical(cursor, $absent) ? this.cursor : cursor as MouseCursor?,
      disabled: disabled == null ? this.disabled : disabled as bool,
      rotationStartEnabled: rotationStartEnabled == null
          ? this.rotationStartEnabled
          : rotationStartEnabled as bool,
      onPointerEnter: identical(onPointerEnter, $absent)
          ? this.onPointerEnter
          : onPointerEnter as void Function(ElEventCallback)?,
      onPointerHover: identical(onPointerHover, $absent)
          ? this.onPointerHover
          : onPointerHover as void Function(ElEventCallback)?,
      onPointerExit: identical(onPointerExit, $absent)
          ? this.onPointerExit
          : onPointerExit as void Function(ElEventCallback)?,
      onPointerDown: identical(onPointerDown, $absent)
          ? this.onPointerDown
          : onPointerDown as void Function(ElEventCallback)?,
      onPointerMove: identical(onPointerMove, $absent)
          ? this.onPointerMove
          : onPointerMove as void Function(ElEventCallback)?,
      onPointerUp: identical(onPointerUp, $absent)
          ? this.onPointerUp
          : onPointerUp as void Function(ElEventCallback)?,
      onPointerCancel: identical(onPointerCancel, $absent)
          ? this.onPointerCancel
          : onPointerCancel as void Function(ElEventCallback)?,
      onPointerPanZoomStart: identical(onPointerPanZoomStart, $absent)
          ? this.onPointerPanZoomStart
          : onPointerPanZoomStart as void Function(ElEventCallback)?,
      onPointerPanZoomUpdate: identical(onPointerPanZoomUpdate, $absent)
          ? this.onPointerPanZoomUpdate
          : onPointerPanZoomUpdate as void Function(ElEventCallback)?,
      onPointerPanZoomEnd: identical(onPointerPanZoomEnd, $absent)
          ? this.onPointerPanZoomEnd
          : onPointerPanZoomEnd as void Function(ElEventCallback)?,
      onPointerSignal: identical(onPointerSignal, $absent)
          ? this.onPointerSignal
          : onPointerSignal as void Function(ElEventCallback)?,
      onTapDown: identical(onTapDown, $absent)
          ? this.onTapDown
          : onTapDown as void Function(ElEventCallback)?,
      onTapUp: identical(onTapUp, $absent)
          ? this.onTapUp
          : onTapUp as void Function(ElEventCallback)?,
      onTap: identical(onTap, $absent)
          ? this.onTap
          : onTap as void Function(ElEventCallback)?,
      onDoubleTap: identical(onDoubleTap, $absent)
          ? this.onDoubleTap
          : onDoubleTap as void Function(ElEventCallback)?,
      onDoubleTapDown: identical(onDoubleTapDown, $absent)
          ? this.onDoubleTapDown
          : onDoubleTapDown as void Function(ElEventCallback)?,
      onTripleTap: identical(onTripleTap, $absent)
          ? this.onTripleTap
          : onTripleTap as void Function(ElEventCallback)?,
      onTripleTapDown: identical(onTripleTapDown, $absent)
          ? this.onTripleTapDown
          : onTripleTapDown as void Function(ElEventCallback)?,
      onSecondaryTapDown: identical(onSecondaryTapDown, $absent)
          ? this.onSecondaryTapDown
          : onSecondaryTapDown as void Function(ElEventCallback)?,
      onSecondaryTapUp: identical(onSecondaryTapUp, $absent)
          ? this.onSecondaryTapUp
          : onSecondaryTapUp as void Function(ElEventCallback)?,
      onSecondaryTap: identical(onSecondaryTap, $absent)
          ? this.onSecondaryTap
          : onSecondaryTap as void Function(ElEventCallback)?,
      onTertiaryTapDown: identical(onTertiaryTapDown, $absent)
          ? this.onTertiaryTapDown
          : onTertiaryTapDown as void Function(ElEventCallback)?,
      onTertiaryTapUp: identical(onTertiaryTapUp, $absent)
          ? this.onTertiaryTapUp
          : onTertiaryTapUp as void Function(ElEventCallback)?,
      onTertiaryTap: identical(onTertiaryTap, $absent)
          ? this.onTertiaryTap
          : onTertiaryTap as void Function(ElEventCallback)?,
      onForwardTapDown: identical(onForwardTapDown, $absent)
          ? this.onForwardTapDown
          : onForwardTapDown as void Function(ElEventCallback)?,
      onForwardTapUp: identical(onForwardTapUp, $absent)
          ? this.onForwardTapUp
          : onForwardTapUp as void Function(ElEventCallback)?,
      onForwardTap: identical(onForwardTap, $absent)
          ? this.onForwardTap
          : onForwardTap as void Function(ElEventCallback)?,
      onBackTapDown: identical(onBackTapDown, $absent)
          ? this.onBackTapDown
          : onBackTapDown as void Function(ElEventCallback)?,
      onBackTapUp: identical(onBackTapUp, $absent)
          ? this.onBackTapUp
          : onBackTapUp as void Function(ElEventCallback)?,
      onBackTap: identical(onBackTap, $absent)
          ? this.onBackTap
          : onBackTap as void Function(ElEventCallback)?,
      onLongPress: identical(onLongPress, $absent)
          ? this.onLongPress
          : onLongPress as void Function(ElEventCallback)?,
      onTapCancel: identical(onTapCancel, $absent)
          ? this.onTapCancel
          : onTapCancel as void Function(ElEventCallback)?,
      onDragDown: identical(onDragDown, $absent)
          ? this.onDragDown
          : onDragDown as void Function(ElEventCallback)?,
      onDragStart: identical(onDragStart, $absent)
          ? this.onDragStart
          : onDragStart as void Function(ElEventCallback)?,
      onDragUpdate: identical(onDragUpdate, $absent)
          ? this.onDragUpdate
          : onDragUpdate as void Function(ElEventCallback)?,
      onDragEnd: identical(onDragEnd, $absent)
          ? this.onDragEnd
          : onDragEnd as void Function(ElEventCallback)?,
      onDragCancel: identical(onDragCancel, $absent)
          ? this.onDragCancel
          : onDragCancel as void Function(ElEventCallback)?,
      onVerticalDragStart: identical(onVerticalDragStart, $absent)
          ? this.onVerticalDragStart
          : onVerticalDragStart as void Function(ElEventCallback)?,
      onVerticalDragUpdate: identical(onVerticalDragUpdate, $absent)
          ? this.onVerticalDragUpdate
          : onVerticalDragUpdate as void Function(ElEventCallback)?,
      onVerticalDragEnd: identical(onVerticalDragEnd, $absent)
          ? this.onVerticalDragEnd
          : onVerticalDragEnd as void Function(ElEventCallback)?,
      onVerticalDragCancel: identical(onVerticalDragCancel, $absent)
          ? this.onVerticalDragCancel
          : onVerticalDragCancel as void Function(ElEventCallback)?,
      onHorizontalDragStart: identical(onHorizontalDragStart, $absent)
          ? this.onHorizontalDragStart
          : onHorizontalDragStart as void Function(ElEventCallback)?,
      onHorizontalDragUpdate: identical(onHorizontalDragUpdate, $absent)
          ? this.onHorizontalDragUpdate
          : onHorizontalDragUpdate as void Function(ElEventCallback)?,
      onHorizontalDragEnd: identical(onHorizontalDragEnd, $absent)
          ? this.onHorizontalDragEnd
          : onHorizontalDragEnd as void Function(ElEventCallback)?,
      onHorizontalDragCancel: identical(onHorizontalDragCancel, $absent)
          ? this.onHorizontalDragCancel
          : onHorizontalDragCancel as void Function(ElEventCallback)?,
      onScaleStart: identical(onScaleStart, $absent)
          ? this.onScaleStart
          : onScaleStart as void Function(ElEventCallback)?,
      onScaleUpdate: identical(onScaleUpdate, $absent)
          ? this.onScaleUpdate
          : onScaleUpdate as void Function(ElEventCallback)?,
      onScaleEnd: identical(onScaleEnd, $absent)
          ? this.onScaleEnd
          : onScaleEnd as void Function(ElEventCallback)?,
      onScaleCancel: identical(onScaleCancel, $absent)
          ? this.onScaleCancel
          : onScaleCancel as void Function(ElEventCallback)?,
      onRotationUpdate: identical(onRotationUpdate, $absent)
          ? this.onRotationUpdate
          : onRotationUpdate as void Function(ElEventCallback)?,
    );
  }
}

extension ElEventConfigExt on ElEventConfig {
  ElEventConfig copyWith({
    Object? doubleTapInterval = $absent,
    Object? tripleTapInterval = $absent,
    Object? longPressDelay = $absent,
    Object? longPressCancelDistance = $absent,
    Object? tapCancelDistance = $absent,
    Object? tapCancelOnMove = $absent,
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
      doubleTapInterval: identical(doubleTapInterval, $absent)
          ? this.doubleTapInterval
          : doubleTapInterval as Duration?,
      tripleTapInterval: identical(tripleTapInterval, $absent)
          ? this.tripleTapInterval
          : tripleTapInterval as Duration?,
      longPressDelay: identical(longPressDelay, $absent)
          ? this.longPressDelay
          : longPressDelay as Duration?,
      longPressCancelDistance: identical(longPressCancelDistance, $absent)
          ? this.longPressCancelDistance
          : (longPressCancelDistance as num?)?.toDouble(),
      tapCancelDistance: identical(tapCancelDistance, $absent)
          ? this.tapCancelDistance
          : (tapCancelDistance as num?)?.toDouble(),
      tapCancelOnMove: identical(tapCancelOnMove, $absent)
          ? this.tapCancelOnMove
          : tapCancelOnMove as bool?,
      delayTouchDown: identical(delayTouchDown, $absent)
          ? this.delayTouchDown
          : delayTouchDown as Duration?,
      delayTouchUp: identical(delayTouchUp, $absent)
          ? this.delayTouchUp
          : delayTouchUp as Duration?,
      deferTap: identical(deferTap, $absent)
          ? this.deferTap
          : deferTap as bool?,
      dragStartDistance: identical(dragStartDistance, $absent)
          ? this.dragStartDistance
          : (dragStartDistance as num?)?.toDouble(),
      dragDevices: identical(dragDevices, $absent)
          ? this.dragDevices
          : dragDevices as Set<PointerDeviceKind>?,
      dragHorizontalAngle: identical(dragHorizontalAngle, $absent)
          ? this.dragHorizontalAngle
          : (dragHorizontalAngle as num?)?.toDouble(),
      dragMinFlingDistance: identical(dragMinFlingDistance, $absent)
          ? this.dragMinFlingDistance
          : (dragMinFlingDistance as num?)?.toDouble(),
      dragMinFlingVelocity: identical(dragMinFlingVelocity, $absent)
          ? this.dragMinFlingVelocity
          : (dragMinFlingVelocity as num?)?.toDouble(),
      dragMaxFlingVelocity: identical(dragMaxFlingVelocity, $absent)
          ? this.dragMaxFlingVelocity
          : (dragMaxFlingVelocity as num?)?.toDouble(),
    );
  }

  ElEventConfig merge([ElEventConfig? other]) {
    if (other == null) return this;
    return ElEventConfig(
      doubleTapInterval: other.doubleTapInterval ?? doubleTapInterval,
      tripleTapInterval: other.tripleTapInterval ?? tripleTapInterval,
      longPressDelay: other.longPressDelay ?? longPressDelay,
      longPressCancelDistance:
          other.longPressCancelDistance ?? longPressCancelDistance,
      tapCancelDistance: other.tapCancelDistance ?? tapCancelDistance,
      tapCancelOnMove: other.tapCancelOnMove ?? tapCancelOnMove,
      delayTouchDown: other.delayTouchDown ?? delayTouchDown,
      delayTouchUp: other.delayTouchUp ?? delayTouchUp,
      deferTap: other.deferTap ?? deferTap,
      dragStartDistance: other.dragStartDistance ?? dragStartDistance,
      dragDevices: other.dragDevices ?? dragDevices,
      dragHorizontalAngle: other.dragHorizontalAngle ?? dragHorizontalAngle,
      dragMinFlingDistance: other.dragMinFlingDistance ?? dragMinFlingDistance,
      dragMinFlingVelocity: other.dragMinFlingVelocity ?? dragMinFlingVelocity,
      dragMaxFlingVelocity: other.dragMaxFlingVelocity ?? dragMaxFlingVelocity,
    );
  }

  List<Object?> get _props => [
    doubleTapInterval,
    tripleTapInterval,
    longPressDelay,
    longPressCancelDistance,
    tapCancelDistance,
    tapCancelOnMove,
    delayTouchDown,
    delayTouchUp,
    deferTap,
    dragStartDistance,
    dragDevices,
    dragHorizontalAngle,
    dragMinFlingDistance,
    dragMinFlingVelocity,
    dragMaxFlingVelocity,
  ];
}
