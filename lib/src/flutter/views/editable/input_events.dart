import '../view/event/event.dart';

/// 上层可阻止基础默认动作，不改变 ElEvent 自身的冒泡和手势所有权。
ElEvent combineEditableEvents(ElEvent defaults, ElEvent? custom) {
  if (custom == null) return defaults;
  ElEventHandler? combine(ElEventHandler? supplied, ElEventHandler? fallback) {
    if (supplied == null) return fallback;
    return (event) {
      supplied(event);
      if (!event.defaultPrevented) fallback?.call(event);
    };
  }

  return defaults.copyWith(
    onPointerEnter: combine(custom.onPointerEnter, defaults.onPointerEnter),
    onPointerHover: combine(custom.onPointerHover, defaults.onPointerHover),
    onPointerExit: combine(custom.onPointerExit, defaults.onPointerExit),
    onPointerDown: combine(custom.onPointerDown, defaults.onPointerDown),
    onPointerMove: combine(custom.onPointerMove, defaults.onPointerMove),
    onPointerUp: combine(custom.onPointerUp, defaults.onPointerUp),
    onPointerCancel: combine(custom.onPointerCancel, defaults.onPointerCancel),
    onPointerPanZoomStart: combine(custom.onPointerPanZoomStart, defaults.onPointerPanZoomStart),
    onPointerPanZoomUpdate: combine(custom.onPointerPanZoomUpdate, defaults.onPointerPanZoomUpdate),
    onPointerPanZoomEnd: combine(custom.onPointerPanZoomEnd, defaults.onPointerPanZoomEnd),
    onPointerSignal: combine(custom.onPointerSignal, defaults.onPointerSignal),
    onTapDown: combine(custom.onTapDown, defaults.onTapDown),
    onTapUp: combine(custom.onTapUp, defaults.onTapUp),
    onTap: combine(custom.onTap, defaults.onTap),
    onDoubleTap: combine(custom.onDoubleTap, defaults.onDoubleTap),
    onDoubleTapDown: combine(custom.onDoubleTapDown, defaults.onDoubleTapDown),
    onTripleTap: combine(custom.onTripleTap, defaults.onTripleTap),
    onTripleTapDown: combine(custom.onTripleTapDown, defaults.onTripleTapDown),
    onSecondaryTapDown: combine(custom.onSecondaryTapDown, defaults.onSecondaryTapDown),
    onSecondaryTapUp: combine(custom.onSecondaryTapUp, defaults.onSecondaryTapUp),
    onSecondaryTap: combine(custom.onSecondaryTap, defaults.onSecondaryTap),
    onTertiaryTapDown: combine(custom.onTertiaryTapDown, defaults.onTertiaryTapDown),
    onTertiaryTapUp: combine(custom.onTertiaryTapUp, defaults.onTertiaryTapUp),
    onTertiaryTap: combine(custom.onTertiaryTap, defaults.onTertiaryTap),
    onForwardTapDown: combine(custom.onForwardTapDown, defaults.onForwardTapDown),
    onForwardTapUp: combine(custom.onForwardTapUp, defaults.onForwardTapUp),
    onForwardTap: combine(custom.onForwardTap, defaults.onForwardTap),
    onBackTapDown: combine(custom.onBackTapDown, defaults.onBackTapDown),
    onBackTapUp: combine(custom.onBackTapUp, defaults.onBackTapUp),
    onBackTap: combine(custom.onBackTap, defaults.onBackTap),
    onLongPress: combine(custom.onLongPress, defaults.onLongPress),
    onTapCancel: combine(custom.onTapCancel, defaults.onTapCancel),
    onDragDown: combine(custom.onDragDown, defaults.onDragDown),
    onDragStart: combine(custom.onDragStart, defaults.onDragStart),
    onDragUpdate: combine(custom.onDragUpdate, defaults.onDragUpdate),
    onDragEnd: combine(custom.onDragEnd, defaults.onDragEnd),
    onDragCancel: combine(custom.onDragCancel, defaults.onDragCancel),
    onVerticalDragStart: combine(custom.onVerticalDragStart, defaults.onVerticalDragStart),
    onVerticalDragUpdate: combine(custom.onVerticalDragUpdate, defaults.onVerticalDragUpdate),
    onVerticalDragEnd: combine(custom.onVerticalDragEnd, defaults.onVerticalDragEnd),
    onVerticalDragCancel: combine(custom.onVerticalDragCancel, defaults.onVerticalDragCancel),
    onHorizontalDragStart: combine(custom.onHorizontalDragStart, defaults.onHorizontalDragStart),
    onHorizontalDragUpdate: combine(custom.onHorizontalDragUpdate, defaults.onHorizontalDragUpdate),
    onHorizontalDragEnd: combine(custom.onHorizontalDragEnd, defaults.onHorizontalDragEnd),
    onHorizontalDragCancel: combine(custom.onHorizontalDragCancel, defaults.onHorizontalDragCancel),
    onScaleStart: combine(custom.onScaleStart, defaults.onScaleStart),
    onScaleUpdate: combine(custom.onScaleUpdate, defaults.onScaleUpdate),
    onScaleEnd: combine(custom.onScaleEnd, defaults.onScaleEnd),
    onScaleCancel: combine(custom.onScaleCancel, defaults.onScaleCancel),
    onRotationUpdate: combine(custom.onRotationUpdate, defaults.onRotationUpdate),
    onKeyDown: combine(custom.onKeyDown, defaults.onKeyDown),
    onKeyRepeat: combine(custom.onKeyRepeat, defaults.onKeyRepeat),
    onKeyUp: combine(custom.onKeyUp, defaults.onKeyUp),
    onFocus: combine(custom.onFocus, defaults.onFocus),
    onBlur: combine(custom.onBlur, defaults.onBlur),
  );
}
