import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform;
import 'package:flutter/widgets.dart' show TargetPlatform, BuildContext, Offset, VoidCallback;

import '../../../dart.dart' show El;
import '../utils/internal/haptics.dart';
import '../views/view/event/event.dart' show ElEventDetails;
import '../widgets/popup/context_menu.dart';

/// el_ui 仍保留的进程级门面配置。
///
/// 上下文菜单注册与移动控件触感开关。
extension ElViewExt on El {
  static Map<TargetPlatform, ElContextMenu> _contextMenus = const {};

  /// 移动按钮和菜单是否启用系统触感，默认开启。
  bool get hapticFeedbackEnabled => TouchHaptics.enabled;

  /// 统一开关移动控件触感，不覆盖设备的系统设置。
  set hapticFeedbackEnabled(bool value) => TouchHaptics.enabled = value;

  /// 全局上下文菜单默认配置。本包不带任何菜单形制：未配置的平台
  /// [showContextMenu] 不弹（debug 告警）；element_plus 的 ElApp 启动时注册平台默认，
  /// 全平台配成同一实现即统一外观。
  Map<TargetPlatform, ElContextMenu> get globalContextMenus => _contextMenus;

  set globalContextMenus(Map<TargetPlatform, ElContextMenu> v) => _contextMenus = v;

  /// 在 [position]（全局坐标）打开一个平台上下文菜单（命令式门面）。
  ///
  /// 生效实现（策略清单）：
  /// 1. [menu] 直参；
  /// 2. [globalContextMenus] 全局表按当前平台；
  /// 3. 均未配置 → debug 告警并返回 null（不弹）——本包只有抽象基座
  ///    [ElContextMenu]，形制由 element_plus 注册。
  ///
  /// [context] 是级联捕获点（菜单延续此处的 vars / 明暗 / 断点环境）。
  /// [rootOverlay] 决定主菜单与所有子菜单的弹层挂载点。
  /// [initialFocus] 决定主面板首次聚焦首项或末项；[restoreFocus] 控制整链
  /// 关闭后是否主动归还打开前焦点。[onNavigatePrevious] / [onNavigateNext]
  /// 是水平菜单栏在主面板边界切换相邻顶级菜单的可选接缝。
  /// [triggerEvent] 传入打开菜单的长按事件，以继续同一根手指的滑动选择。
  /// 返回菜单句柄；缺少 Flutter Overlay 时不弹。
  ElContextMenuHandle? showContextMenu(
    BuildContext context, {
    required Offset position,
    required List<ElContextMenuItem> items,
    ElContextMenu? menu,
    ElEventDetails? triggerEvent,
    bool rootOverlay = false,
    ContextMenuInitialFocus initialFocus = ContextMenuInitialFocus.first,
    bool restoreFocus = true,
    VoidCallback? onNavigatePrevious,
    VoidCallback? onNavigateNext,
  }) {
    final resolved = menu ?? _contextMenus[defaultTargetPlatform];
    if (resolved == null) {
      assert(() {
        debugPrint(
          'el_ui: el.showContextMenu 未注册任何菜单实现（el.globalContextMenus 为空且未传 menu 直参），本次不弹。皮肤在 element_plus：使用 ElApp 或手动注册。',
        );
        return true;
      }());
      return null;
    }
    final handle =
        initialFocus == ContextMenuInitialFocus.first &&
            restoreFocus &&
            onNavigatePrevious == null &&
            onNavigateNext == null
        ? resolved.open(context, position: position, items: items, rootOverlay: rootOverlay)
        : resolved.openWithOptions(
            context,
            position: position,
            items: items,
            rootOverlay: rootOverlay,
            initialFocus: initialFocus,
            restoreFocus: restoreFocus,
            onNavigatePrevious: onNavigatePrevious,
            onNavigateNext: onNavigateNext,
          );
    if (triggerEvent != null) handle?.trackTouch(triggerEvent);
    return handle;
  }
}
