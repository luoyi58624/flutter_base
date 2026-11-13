import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../flutter/widgets/popup/modal_layer.dart' show ModalLayer;
import '../../internal.dart';

const _duration = Duration(milliseconds: 300);

/// 桌面对话框沿用 Element 外观：标题、正文、右对齐页脚；提供 confirmText 时为 420 宽的确认框。
/// 进场淡入并从上方 20 像素落下（停靠底部时从下方升起），遮罩同步淡入。
Widget dialogBuilder(BuildContext context, ElDialog c) {
  final t = context.elTheme;
  // 直接嵌入页面时没有关闭入口，不显示无效的关闭按钮。
  final showClose = c.showClose && c.onClose != null;
  final Widget? footer = c.footer != null
      ? ElView(child: elContent(c.footer))
      : c.confirmText == null
      ? null
      : Row(
          mainAxisAlignment: .end,
          spacing: 12,
          children: [
            if (c.cancelText case final cancel?) ElButton(onPressed: c.onCancel, child: cancel),
            ElButton(type: c.type, onPressed: c.onConfirm, child: c.confirmText),
          ],
        );
  final panel = ElView(
    event: c.event,
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    style: ElStyle(
      width: '100%',
      padding: const .all(16),
      borderRadius: .circular(t.radiusMd),
      backgroundColor: t.cardColor,
      color: t.textRegular,
      fontSize: 14,
      lineHeight: 1.6,
    ).withShadow(type: .floating, level: t.shadowLg).merge(c.style),
    child: Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 16,
      children: [
        if (c.title != null || showClose)
          Row(
            crossAxisAlignment: .start,
            spacing: 12,
            children: [
              Expanded(
                child: ElView(
                  style: ElStyle(fontSize: 18, lineHeight: 1.35, color: t.textColor),
                  child: c.title,
                ),
              ),
              if (showClose) _close(context, c.onClose),
            ],
          ),
        Flexible(
          child: SingleChildScrollView(primary: false, child: ElView(child: elContent(c.child))),
        ),
        ?footer,
      ],
    ),
  );
  if (c.onClose == null) return panel;
  final alignment = _alignment(c.placement);
  return _modal(
    alignment: alignment,
    margin: 16,
    constraints: (available) =>
        BoxConstraints(maxWidth: c.confirmText == null ? 520 : 420, maxHeight: available.maxHeight),
    // 居中与顶部自上方落下，底部自下方升起，左右自对应侧移入。
    transition: (context, progress, child) => Opacity(
      opacity: progress,
      child: Transform.translate(
        offset:
            (alignment == Alignment.center ? const Offset(0, -1) : Offset(alignment.x, alignment.y)) *
            20 *
            (1 - progress),
        child: child,
      ),
    ),
    panel: panel,
  );
}

/// 桌面抽屉沿用 Element 外观：贴边铺满，标题与关闭按钮在顶部，页脚右对齐；默认占视口 30%，从对应边缘整体滑入。
Widget drawerBuilder(BuildContext context, ElDrawer c) {
  final t = context.elTheme;
  // 直接嵌入页面时没有关闭入口，不显示无效的关闭按钮。
  final showClose = c.showClose && c.onClose != null;
  final panel = ElView(
    event: c.event,
    semantics: ElSemantics(container: true, label: c.semanticLabel),
    style: ElStyle(
      width: '100%',
      height: '100%',
      backgroundColor: t.cardColor,
      color: t.textRegular,
      fontSize: 14,
      lineHeight: 1.6,
    ).withShadow(type: .floating, level: t.shadowLg).merge(c.style),
    child: Column(
      crossAxisAlignment: .stretch,
      children: [
        if (c.title != null || showClose)
          Padding(
            padding: const .fromLTRB(20, 20, 20, 0),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: ElView(
                    style: ElStyle(fontSize: 16, lineHeight: 1.5, color: t.textColor),
                    child: c.title,
                  ),
                ),
                if (showClose) _close(context, c.onClose),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(primary: false, padding: const .all(20), child: c.child),
        ),
        if (c.footer != null)
          Padding(
            padding: const .fromLTRB(20, 10, 20, 20),
            child: Align(
              alignment: .centerRight,
              child: ElView(child: elContent(c.footer)),
            ),
          ),
      ],
    ),
  );
  if (c.onClose == null) return panel;
  final alignment = _alignment(c.placement == .center ? .right : c.placement);
  final horizontal = alignment.x != 0;
  return _modal(
    alignment: alignment,
    margin: 0,
    constraints: (available) {
      final extent = horizontal ? available.maxWidth : available.maxHeight;
      final size = math.min(c.size ?? math.max(extent * .3, 280.0), extent);
      return horizontal
          ? BoxConstraints.tightFor(width: size, height: available.maxHeight)
          : BoxConstraints.tightFor(width: available.maxWidth, height: size);
    },
    transition: (context, progress, child) =>
        FractionalTranslation(translation: Offset(alignment.x, alignment.y) * (1 - progress), child: child),
    panel: panel,
  );
}

Alignment _alignment(ElPopupPlacement placement) => switch (placement) {
  .center => Alignment.center,
  .bottom => Alignment.bottomCenter,
  .top => Alignment.topCenter,
  .left => Alignment.centerLeft,
  .right => Alignment.centerRight,
};

Widget _modal({
  required Alignment alignment,
  required double margin,
  required BoxConstraints Function(BoxConstraints available) constraints,
  required Widget Function(BuildContext context, double progress, Widget panel) transition,
  required Widget panel,
}) => Builder(
  builder: (context) => ElOverlayTransition(
    duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? Duration.zero : _duration,
    builder: (context, animation) => ModalLayer(
      animation: animation,
      alignment: alignment,
      curve: Curves.ease,
      margin: margin,
      constraints: constraints,
      barrier: (context, visible) {
        final color = context.elVarOr(ElTokens.$overlayColorLighter, const Color(0x80000000));
        return ColoredBox(color: color.withValues(alpha: color.a * visible));
      },
      transition: transition,
      child: panel,
    ),
  ),
);

Widget _close(BuildContext context, VoidCallback? onClose) {
  final t = context.elTheme;
  return ElButtonView(
    onPressed: onClose,
    semanticLabel: '关闭',
    style: ElStyle(
      width: 24,
      height: 24,
      alignment: .center,
      borderRadius: .circular(t.radiusSm),
      iconSize: 16,
      iconColor: t.textSecondary,
      cursor: SystemMouseCursors.click,
      onHover: ElStyle(iconColor: t.primary),
      onFocusVisible: ElStyle(outline: .new(outlineWidth: 2, outlineColor: t.primary, outlineOffset: 1)),
      transition: const [ElTransition.all(Duration(milliseconds: 150))],
    ),
    child: const ElIcon(ElDesktopIcons.close),
  );
}
