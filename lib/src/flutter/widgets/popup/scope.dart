import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

/// 获取仍挂载的上下文所属窗口。
@internal
int? popupViewId(BuildContext context) {
  if (!context.mounted) return null;
  var active = true;
  assert(() {
    if (context is Element) active = context.debugIsActive;
    return true;
  }());
  return active ? View.maybeOf(context)?.viewId : null;
}

/// 解析当前窗口及目标 Overlay，遵守 Flutter 的查找边界。
@internal
({int viewId, OverlayState overlay})? popupOverlayOf(BuildContext context, {bool rootOverlay = false}) {
  final viewId = popupViewId(context);
  if (viewId == null) return null;
  final overlay = Overlay.maybeOf(context, rootOverlay: rootOverlay);
  if (overlay == null || !overlay.mounted || popupViewId(overlay.context) != viewId) return null;
  return (viewId: viewId, overlay: overlay);
}
