import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../flutter/widgets/popup/arrow.dart' show popupOrigin;
import '../../internal.dart';

/// 桌面菜单沿用 Element 下拉菜单外观：白底浅边框，条目悬停与键盘聚焦时浅主色高亮。
///
/// 点击或右键打开的菜单接管键盘：上下键循环切换条目，右键或回车展开子菜单并聚焦第一项，左键收起子菜单，
/// Esc 逐级关闭并交还焦点；悬停打开的菜单不抢焦点。子菜单悬停 150 毫秒展开，斜向移入子菜单途中不收起。
Widget popupMenuBuilder(BuildContext context, ElPopupMenu c) => ElPopup(
  controller: c.controller,
  trigger: c.trigger,
  hoverIntent: c.hoverIntent,
  anchor: ElOverlayAnchor(placement: c.placement, offset: c.cover ? 0 : 4, cover: c.cover),
  disabled: c.disabled,
  onOpenChanged: c.onOpenChanged,
  event: c.event,
  builder: (context) => _Menu(
    items: c.items,
    close: ElPopup.maybeOf(context)!.close,
    style: c.style,
    autofocus: !c.trigger.contains(ElPopupTrigger.hover),
  ),
  child: c.child,
);

class _Menu extends HookWidget {
  const _Menu({required this.items, required this.close, this.style, this.autofocus = false, this.scope});

  final List<ElContextMenuItem> items;

  /// 关闭整条菜单链。
  final VoidCallback close;
  final ElStyle? style;
  final bool autofocus;

  /// 子菜单的焦点作用域由父条目持有，键盘展开时父条目把焦点送进第一项。
  final FocusScopeNode? scope;

  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    final own = useFocusScopeNode(debugLabel: 'ElPopupMenu');
    final node = scope ?? own;
    useEffect(() {
      // 聚焦作用域而不是条目：不出现焦点环，按下方向键时从第一项或最后一项开始。
      if (autofocus) WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
      return null;
    }, const []);
    final checkable = items.any((item) => item.checked != null);
    final panel = FocusScope(
      node: node,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => FocusManager.instance.primaryFocus?.nextFocus(),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => FocusManager.instance.primaryFocus?.previousFocus(),
          if (scope != null)
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () => ElPopup.maybeOf(context)?.close(),
        },
        child: ElView(
          style: ElStyle(
            minWidth: 120,
            padding: const .symmetric(vertical: 5),
            borderRadius: .circular(t.radiusSm),
            border: .all(borderColor: t.borderColorLight),
            backgroundColor: t.cardColor,
            color: t.textRegular,
            iconColor: t.textRegular,
            fontSize: 14,
          ).withShadow(level: ElLevelType.sm.shadow(context)).merge(style),
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
                          margin: const .symmetric(vertical: 6),
                          backgroundColor: t.borderColorLight,
                        ),
                      )
                    else if (item.hasChildren)
                      _Submenu(item: item, close: close, checkable: checkable)
                    else
                      _row(
                        context,
                        item,
                        checkable: checkable,
                        onPressed: () {
                          close();
                          item.onSelect?.call();
                        },
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return ElOverlayTransition(
      duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? .zero : const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
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
  const _Submenu({required this.item, required this.close, required this.checkable});

  final ElContextMenuItem item;
  final VoidCallback close;
  final bool checkable;

  @override
  Widget build(BuildContext context) {
    final controller = useMemoized(ElPopupController.new);
    useEffect(() => controller.dispose, const []);
    final scope = useFocusScopeNode(debugLabel: 'ElPopupMenu submenu');
    void enter() {
      controller.open();
      // 子菜单面板下一帧才挂载，挂载后把焦点送进第一项。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scope.context != null) scope.nextFocus();
      });
    }

    return ElPopup(
      controller: controller,
      // 悬停展开；点击不切换，避免悬停展开后再点击行反而收起。触摸没有悬停，点击切换。
      trigger: const {.hover},
      hoverIntent: const ElHoverIntent(closeDelay: Duration(milliseconds: 150)),
      anchor: const ElOverlayAnchor(placement: .rightStart, offset: 2, crossOffset: -6),
      disabled: !item.enabled,
      builder: (context) => _Menu(items: item.children!, close: close, scope: scope),
      child: _row(
        context,
        item,
        checkable: checkable,
        trailing: elContent(ElDesktopIcons.arrowRight, iconSize: 12),
        event: ElEvent(
          onKeyDown: (e) {
            final key = e.logicalKey;
            if (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter ||
                key == LogicalKeyboardKey.space) {
              enter();
              e.preventDefault();
            }
          },
        ),
      ),
    );
  }
}

Widget _row(
  BuildContext context,
  ElContextMenuItem item, {
  required bool checkable,
  VoidCallback? onPressed,
  ElEvent? event,
  Object? trailing,
}) {
  final t = context.elTheme;
  final active = ElStyle(backgroundColor: t.primary.elLight9(context), color: t.primary, iconColor: t.primary);
  return ElButtonView(
    onPressed: onPressed,
    disabled: !item.enabled,
    toggled: item.checked,
    semanticLabel: item.label,
    event: event,
    style: ElStyle(
      padding: const .symmetric(horizontal: 16, vertical: 5),
      lineHeight: 22 / 14,
      cursor: SystemMouseCursors.click,
      onHover: active,
      onFocusVisible: active,
      onDisabled: ElStyle(
        backgroundColor: const Color(0x00000000),
        color: t.textPlaceholder,
        iconColor: t.textPlaceholder,
        cursor: SystemMouseCursors.forbidden,
      ),
    ),
    child: Row(
      spacing: 8,
      children: [
        if (checkable)
          SizedBox(
            width: 14,
            child: item.checked == true ? ElView(child: elContent(ElDesktopIcons.check, iconSize: 14)) : null,
          ),
        if (item.icon != null) ElView(child: elContent(item.icon, iconSize: 14)),
        Expanded(child: ElView(child: item.label)),
        if (trailing != null)
          ElView(child: trailing)
        else if (item.shortcut case final shortcut?)
          ElView(
            style: ElStyle(margin: const .only(left: 16), color: t.textPlaceholder, fontSize: 12),
            child: shortcut,
          ),
      ],
    ),
  );
}
