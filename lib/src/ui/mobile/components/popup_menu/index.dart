import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../flutter.dart';
import '../../../../flutter/widgets/popup/arrow.dart' show popupOrigin;
import '../../commons/icons.dart';
import '../../internal/common.dart';

/// 移动菜单：大圆角浮起面板，条目按压变色，从目标一侧缩放淡入；带子菜单的条目点击在旁侧展开。
/// 条目不创建焦点，不参与键盘导航。
Widget popupMenuBuilder(BuildContext context, ElPopupMenu c) => ElPopup(
  controller: c.controller,
  trigger: c.trigger,
  hoverIntent: c.hoverIntent,
  anchor: ElOverlayAnchor(placement: c.placement, offset: c.cover ? 0 : 6, cover: c.cover),
  disabled: c.disabled,
  onOpenChanged: c.onOpenChanged,
  event: c.event,
  builder: (context) => _Menu(items: c.items, close: ElPopup.maybeOf(context)!.close, style: c.style),
  child: c.child,
);

class _Menu extends StatelessWidget {
  const _Menu({required this.items, required this.close, this.style});

  final List<ElContextMenuItem> items;

  /// 关闭整条菜单链。
  final VoidCallback close;
  final ElStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    final panel = ElView(
      style: ElStyle(
        minWidth: 160,
        maxWidth: 280,
        padding: const .all(6),
        borderRadius: .circular(18),
        border: .all(borderColor: t.borderColor),
        backgroundColor: t.cardColor,
        fontSize: 14,
      ).withShadow(level: ElLevelType.lg.shadow(context)).merge(style),
      child: SingleChildScrollView(
        primary: false,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              for (final item in items)
                if (item.isDivider)
                  ElView(
                    style: ElStyle(
                      height: 1,
                      margin: const .symmetric(horizontal: 10, vertical: 5),
                      backgroundColor: t.borderColor,
                    ),
                  )
                else if (item.hasChildren)
                  _Submenu(item: item, close: close)
                else
                  _row(
                    context,
                    item,
                    onTap: () {
                      close();
                      item.onSelect?.call();
                    },
                  ),
            ],
          ),
        ),
      ),
    );
    return ElOverlayTransition(
      duration: reducedMotion(context) ? .zero : const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 150),
      builder: (context, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: animation.drive(Tween(begin: .9, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic))),
          alignment: popupOrigin(context),
          child: panel,
        ),
      ),
    );
  }
}

class _Submenu extends HookWidget {
  const _Submenu({required this.item, required this.close});

  final ElContextMenuItem item;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(ElPopupController.new);
    useEffect(() => controller.dispose, const []);
    // 行自己的点击切换子菜单，弹层不再挂触发，避免一次点击切换两次。
    return ElPopup(
      controller: controller,
      trigger: const {},
      // 行在面板 6 像素内边距里，间距补上内边距才与父面板留出 4 像素空隙；交叉轴上移让首项与本行对齐。
      anchor: const ElOverlayAnchor(placement: .rightStart, offset: 10, crossOffset: -6),
      disabled: !item.enabled,
      builder: (context) => _Menu(items: item.children!, close: close),
      child: _row(context, item, onTap: controller.toggle, trailing: ElMobileIcons.chevronRight),
    );
  }
}

Widget _row(BuildContext context, ElContextMenuItem item, {required VoidCallback onTap, Widget? trailing}) {
  final t = context.elTheme;
  final enabled = item.enabled;
  return ElView(
    semantics: ElSemantics(
      mergeDescendants: true,
      button: true,
      enabled: enabled,
      toggled: item.checked,
      label: item.label,
      onTap: enabled ? onTap : null,
    ),
    event: enabled ? ElEvent(onTap: (_) => onTap()) : null,
    style: ElStyle(
      minHeight: 44,
      padding: const .symmetric(horizontal: 12, vertical: 10),
      borderRadius: .circular(11),
      userSelect: .none,
      color: enabled ? t.textColor : t.textDisabled,
      iconColor: enabled ? t.textSecondary : t.textDisabled,
      iconSize: 18,
      transition: enabled ? pressTransitions(t) : null,
      onTap: enabled ? ElStyle(backgroundColor: t.press) : null,
    ),
    child: Row(
      spacing: 10,
      children: [
        if (item.icon != null) ElView(child: buildContent(item.icon)),
        Expanded(child: ElView(child: item.label)),
        if (trailing != null)
          trailing
        else if (item.checked == true)
          ElMobileIcons.check
        else if (item.shortcut case final shortcut?)
          ElView(
            style: ElStyle(color: t.textPlaceholder, fontSize: 12),
            child: shortcut,
          ),
      ],
    ),
  );
}
