import 'package:flutter/widgets.dart';

import '../../views/view/event/event.dart';
import '../../views/view/style/style.dart';
import '../../widgets/popup/anchor.dart';
import '../../widgets/popup/context_menu.dart' show ElContextMenuItem;
import '../../widgets/popup/hover_intent.dart';
import '../../widgets/popup/popup.dart';
import '../index.dart';

/// 在任意目标周围弹出的菜单：点击或悬停展开下拉菜单，cover 时像安卓溢出菜单一样覆盖目标展开，
/// trigger 为 contextMenu 时在右键或长按位置展开；条目可带图标、勾选、快捷键与多级子菜单。
class ElPopupMenu extends StatelessWidget {
  /// 选择条目后整条菜单关闭再执行 onSelect；带子菜单的条目只展开子菜单。
  const ElPopupMenu({
    super.key,
    required this.child,
    required this.items,
    this.trigger = const {ElPopupTrigger.click},
    this.placement = .bottomStart,
    this.cover = false,
    this.hoverIntent = const ElHoverIntent(),
    this.disabled = false,
    this.controller,
    this.onOpenChanged,
    this.style,
    this.event,
  });

  /// 触发目标。
  final Widget child;

  /// 菜单条目，分隔线用 ElContextMenuItem.divider。
  final List<ElContextMenuItem> items;

  /// 触发方式。
  final Set<ElPopupTrigger> trigger;

  /// 菜单相对目标的首选方位，空间不足时自动翻转；右键菜单以指针位置为目标。
  final ElPlacement placement;

  /// 菜单覆盖目标自身，从目标所在位置展开。
  final bool cover;

  /// 悬停触发的打开、关闭延迟。
  final ElHoverIntent hoverIntent;

  /// 禁用全部触发，已打开时关闭。
  final bool disabled;

  /// 可选开闭控制器。
  final ElPopupController? controller;

  /// 开闭状态变化。
  final ValueChanged<bool>? onOpenChanged;

  /// 在品牌菜单面板样式后合并。
  final ElStyle? style;

  /// 目标的原生事件，preventDefault 可阻止打开或关闭。
  final ElEvent? event;

  @override
  Widget build(BuildContext context) => ElComponentProvider.builderOf(context, this, (b) => b.popupMenu)(context, this);
}
