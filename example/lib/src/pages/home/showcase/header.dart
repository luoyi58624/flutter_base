import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import '../../../state/index.dart';
import 'panel.dart';

/// 保留原稿居中目录、窄屏章节菜单与主题切换的首页导航头。
class ShowcaseHeader extends HookWidget implements PreferredSizeWidget {
  /// 章节只定位当前长页，应用路由仍由外层管理。
  const ShowcaseHeader({
    super.key,
    required this.width,
    required this.inset,
    required this.chapters,
    required this.current,
    required this.onNavigate,
  });

  /// 页面可用宽度。
  final double width;

  /// 与正文对齐的水平留白。
  final double inset;

  /// 分区身份与显示名称。
  final Map<String, String> chapters;

  /// 当前滚动分区。
  final ValueNotifier<String> current;

  /// 定位章节或回到顶部。
  final ValueChanged<String> onNavigate;
  @override
  Size get preferredSize => Size.fromHeight(width <= 760 ? 57 : 65);
  @override
  Widget build(BuildContext context) {
    final portal = useMemoized(ElPortalController.new);
    useEffect(() => portal.dispose, []);
    final selected = useValueListenable(current), t = context.elTheme;
    final brand = Align(
      alignment: .centerLeft,
      child: FittedBox(
        fit: .scaleDown,
        child: ElButton(
          variant: .text,
          style: ElStyle(padding: .zero, color: t.textColor),
          onPressed: () => onNavigate('top'),
          child: Row(
            mainAxisSize: .min,
            spacing: 9,
            children: [
              ElImageView('assets/showcase/logo.png', width: 28, height: 28),
              Text(
                'my-ui',
                style: TextStyle(fontSize: 17, fontWeight: .w700, letterSpacing: -.7, color: t.textColor),
              ),
              if (width > 1060) demoHint(context, '交互示例', size: 12),
            ],
          ),
        ),
      ),
    );
    final theme = ObsBuilder(
      builder: (context) => ElButton(
        key: ValueKey('navbar-menu'),
        variant: .outline,
        semanticLabel: GlobalState.isDark.value ? '切换到浅色模式' : '切换到暗黑模式',
        style: ElStyle(
          width: 44,
          height: 44,
          padding: .zero,
          borderRadius: .circular(13),
          backgroundColor: t.cardColor,
          border: .all(borderColor: t.borderColor),
          color: t.textSecondary,
          iconColor: t.textSecondary,
        ),
        onPressed: () => GlobalState.isDark.value = !GlobalState.isDark.value,
        child: demoIcon(GlobalState.isDark.value ? ElMobileIcons.sun : ElMobileIcons.moon, size: 18),
      ),
    );
    final menu = ElPortal(
      controller: portal,
      anchor: ElOverlayAnchor(placement: .bottomEnd, offset: 8),
      closeOnScroll: true,
      overlayBuilder: (context) => ElCard(
        style: ElStyle(
          width: 180,
          padding: .all(8),
          borderRadius: .circular(16),
          border: .all(borderColor: t.borderColor),
          boxShadow: t.shadowLg,
        ),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            for (final chapter in chapters.entries)
              ElButton(
                variant: .text,
                child: chapter.value,
                onPressed: () {
                  portal.close();
                  onNavigate(chapter.key);
                },
              ),
          ],
        ),
      ),
      child: ElButton(
        key: ValueKey('showcase-chapters'),
        variant: .text,
        style: ElStyle(
          fontSize: 13,
          padding: .symmetric(horizontal: 12),
          backgroundColor: t.fill,
          borderRadius: .circular(10),
          color: t.textColor,
        ),
        onPressed: portal.toggle,
        child: Row(
          mainAxisSize: .min,
          spacing: 9,
          children: [
            Text(chapters[selected] ?? '章节目录', style: TextStyle(fontSize: 13, color: t.textColor)),
            Transform.rotate(angle: 1.5708, child: demoIcon(ElMobileIcons.chevronRight, size: 12, color: t.textColor)),
          ],
        ),
      ),
    );
    return SafeArea(
      bottom: false,
      child: ElCard(
        style: ElStyle(
          height: preferredSize.height,
          padding: .symmetric(horizontal: inset),
          borderRadius: .zero,
          backgroundColor: t.cardColor,
          // 断点切换时结构和留白必须同步，避免旧宽屏内边距挤压手机导航。
          transition: MediaQuery.disableAnimationsOf(context)
              ? []
              : [
                  ElTransition.fields(
                    {ElTransitionField.backgroundColor, ElTransitionField.border, ElTransitionField.boxShadow},
                    Duration(milliseconds: 150),
                    Curves.easeOut,
                  ),
                ],
          boxShadow: selected.isEmpty
              ? []
              : [BoxShadow(color: Colors.black.withValues(alpha: .06), offset: Offset(0, 8), blurRadius: 20)],
          border: ElBorder.only(borderBottom: ElBorderSide(borderColor: t.borderColor)),
        ),
        child: width > 1060
            ? Stack(
                alignment: .center,
                children: [
                  Row(children: [brand, Spacer(), theme]),
                  ElView(
                    style: ElStyle(padding: .all(4), borderRadius: .circular(13), backgroundColor: t.fill),
                    child: Row(
                      mainAxisSize: .min,
                      spacing: 6,
                      children: [
                        for (final chapter in chapters.entries)
                          ElButton(
                            variant: .text,
                            style: ElStyle(
                              minHeight: 36,
                              fontSize: 13,
                              padding: .symmetric(horizontal: 10),
                              borderRadius: .circular(10),
                              color: selected == chapter.key ? t.primary : t.textSecondary,
                              backgroundColor: selected == chapter.key ? t.cardColor : Colors.transparent,
                            ),
                            child: chapter.value,
                            onPressed: () => onNavigate(chapter.key),
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                spacing: 8,
                children: [
                  Expanded(child: brand),
                  menu,
                  theme,
                ],
              ),
      ),
    );
  }
}
