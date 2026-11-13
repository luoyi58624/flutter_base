import 'dart:async' show Timer;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

import 'host.dart';
import 'scope.dart';
import 'session.dart';
import 'theme.dart';

/// 在调用窗口的根 Overlay 展示透传提示，摘除后结清。
@internal
Future<void> showPopupNotice(BuildContext context, {required Duration duration, required Widget child}) async {
  final target = popupOverlayOf(context, rootOverlay: true);
  if (target == null) return;
  final overlay = target.overlay;
  final theme = PopupTheme.capture(context, to: overlay.context);
  Timer? timer;
  late final PopupSession<void> session;
  Widget buildNotice(BuildContext context) {
    timer ??= Timer(duration, session.remove);
    return Positioned.fill(child: IgnorePointer(child: theme.wrap(child)));
  }

  session = PopupSession<void>(overlay, viewId: target.viewId, builder: buildNotice, maintainState: true);
  popupHostOf(context)?.trackNotice(session);
  session.insert();
  await session.removed;
  timer?.cancel();
}
