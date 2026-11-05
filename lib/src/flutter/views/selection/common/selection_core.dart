// 文档选择与编辑器共用的内部内容、交互和附属层协议。

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../../dart.dart' show el;
import '../../../commons/global.dart' show ElViewExt;
import '../../../widgets/popup/context_menu.dart';
import '../../button/button_view.dart';
import '../../scroll/common/viewport/scroll_position_binding.dart';
import '../../scroll/common/viewport/scroll_viewport.dart';
import '../../view/event/event.dart';
import '../../view/render/hit_bounds.dart' show ElOverflowHitBounds;
import '../../view/render/render_view.dart';
import '../../view/style/cascade/style_spec.dart';
import '../../view/style/style.dart';
import '../../view/view.dart';
import 'selection_auto_scroll.dart';
import 'selection_boundary.dart';
import 'selection_chrome_host.dart';
export 'selection_chrome_host.dart';
export 'selection_auto_scroll.dart';
export 'selection_boundary.dart';
part 'selection_types.dart';
part 'selection_participant.dart';
part 'selection_controls.dart';
part 'selection_overlay.dart';
part 'selection_chrome.dart';
part 'selection_interaction.dart';
part 'selection_gestures.dart';
part 'selection_island.dart';

/// 内部控件覆写，仅供引擎、编辑器与白盒测试共享。
class SelectionControlsScope extends InheritedWidget {
  /// 创建内部控件作用域。
  const SelectionControlsScope({super.key, required this.controls, required super.child});

  /// 生效的内部控件实现。
  final SelectionControls controls;

  /// 获取最近覆写，缺失时采用平台默认实现。
  static SelectionControls of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SelectionControlsScope>();
    if (scope != null) return scope.controls;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.fuchsia => const AndroidSelectionControls(),
      TargetPlatform.iOS => const IosSelectionControls(),
      _ => const DesktopSelectionControls(),
    };
  }

  @override
  bool updateShouldNotify(SelectionControlsScope oldWidget) => !identical(controls, oldWidget.controls);
}
