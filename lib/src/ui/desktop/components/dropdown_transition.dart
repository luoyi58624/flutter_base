import 'package:flutter/widgets.dart';

import '../../../flutter/widgets/popup/popup.dart' show ElPopup;
import '../../../flutter/widgets/popup/transition.dart' show ElOverlayTransition;

/// 桌面下拉面板的进退场：自目标一侧滑入 4 像素并淡入，关闭时反向退场后再移除；减少动效时直接显示。
Widget dropdownTransition(Widget panel) => Builder(
  builder: (context) => ElOverlayTransition(
    duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? Duration.zero : const Duration(milliseconds: 90),
    builder: (context, animation) {
      final progress = animation.drive(CurveTween(curve: Curves.easeOutCubic));
      // 面板翻到目标上方时自下而上滑入。
      final distance = ElPopup.geometryOf(context)?.placement.side == AxisDirection.up ? 4.0 : -4.0;
      return FadeTransition(
        opacity: progress,
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, child) =>
              Transform.translate(offset: Offset(0, distance * (1 - progress.value)), child: child),
          child: panel,
        ),
      );
    },
  ),
);
