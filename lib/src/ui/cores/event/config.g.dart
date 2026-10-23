// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// ElModelGenerator
// **************************************************************************

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
