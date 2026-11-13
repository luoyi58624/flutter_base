import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../../../../../flutter.dart';
import '../../../../flutter/widgets/popup/modal_layer.dart' show ModalLayer;
import '../../commons/icons.dart';
import '../../internal/common.dart';

const _curve = Cubic(.174, 0, .185, 1);

/// 移动对话框：居中为确认框，停靠顶部或底部为面板；面板可从内容或遮罩跟手拖动关闭。
Widget dialogBuilder(BuildContext context, ElDialog c) {
  final panel = c.placement == .center ? _dialog(context, c) : _sheet(context, c);
  return _modal(
    context,
    placement: c.placement,
    drawer: false,
    onClose: c.onClose,
    dismissible: c.dismissible,
    panel: panel,
  );
}

/// 移动抽屉保留业务子树和页脚，内容超长时独立滚动。
Widget drawerBuilder(BuildContext context, ElDrawer c) {
  final t = context.elTheme;
  // 直接嵌入页面时没有关闭入口，不显示无效的关闭按钮。
  final showClose = c.showClose && c.onClose != null;
  final panel = _surface(
    context,
    c.style,
    c.event,
    c.semanticLabel,
    const ElStyle(vars: {ElTokens.$popupListPadding: EdgeInsets.zero}),
    LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          if (c.title != null || showClose)
            ElView(
              style: ElStyle(
                minHeight: 73,
                padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 16, 15),
                border: ElBorder.only(borderBottom: ElBorderSide(borderColor: t.borderColor)),
              ),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: ElView(
                      style: ElStyle(fontSize: 20, lineHeight: 1.4, fontWeight: textWeight(t.fontWeightSubtitle)),
                      child: c.title,
                    ),
                  ),
                  if (showClose) _closeButton(context, 44, c.onClose),
                ],
              ),
            ),
          // 有限高度内让正文占满余量，短内容时页脚也贴着底边。
          Flexible(
            fit: constraints.hasBoundedHeight ? .tight : .loose,
            child: _scrollBody(c.child, padding: context.elTheme.drawerBodyPadding ?? const .all(24)),
          ),
          if (c.footer != null)
            ElView(
              style: ElStyle(
                padding: const .fromLTRB(24, 17, 24, 20),
                border: ElBorder.only(borderTop: ElBorderSide(borderColor: t.borderColor)),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
                child: buildContent(c.footer),
              ),
            ),
        ],
      ),
    ),
  );
  return _modal(
    context,
    placement: c.placement,
    drawer: true,
    size: c.size,
    onClose: c.onClose,
    dismissible: c.dismissible,
    panel: panel,
  );
}

// 直接嵌入页面时（没有 onClose）只绘制面板；经服务打开时加遮罩、进退场和拖动关闭。
Widget _modal(
  BuildContext context, {
  required ElPopupPlacement placement,
  required bool drawer,
  double? size,
  required VoidCallback? onClose,
  required bool dismissible,
  required Widget panel,
}) {
  if (onClose == null) return panel;
  final alignment = switch (placement) {
    .center => Alignment.center,
    .bottom => Alignment.bottomCenter,
    .top => Alignment.topCenter,
    .left => Alignment.centerLeft,
    .right => Alignment.centerRight,
  };
  final horizontal = alignment.x != 0;
  final sheet = !drawer && placement != .center;
  final margin = drawer ? 0.0 : 16.0;
  return ElOverlayTransition(
    duration: reducedMotion(context) ? Duration.zero : const Duration(milliseconds: 250),
    builder: (context, animation) => ModalLayer(
      animation: animation,
      alignment: alignment,
      curve: _curve,
      margin: margin,
      onDismiss: dismissible ? onClose : null,
      constraints: (available) => drawer && placement != .center
          ? BoxConstraints.tightFor(
              width: horizontal ? math.min(size ?? 360, available.maxWidth) : available.maxWidth,
              height: horizontal ? available.maxHeight : math.min(size ?? 420, available.maxHeight),
            )
          : BoxConstraints(
              maxWidth: sheet ? 400 : 420,
              maxHeight: sheet
                  ? math.min(available.maxHeight, MediaQuery.sizeOf(context).height * .85)
                  : available.maxHeight,
            ),
      // 遮罩颜色和模糊沿用调用处的主题变量，面板越淡遮罩越淡。
      barrier: (context, visible) {
        final color = context.elVarOr(ElTokens.$overlayColor, const Color(0x570c121c));
        final sigma = context.elVarOr<num>(ElTokens.$overlayBackdropBlur, 4).toDouble() * (sheet ? 1.75 : 1) * visible;
        return BackdropFilter(
          enabled: sigma > 0,
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: ColoredBox(color: color.withValues(alpha: color.a * visible)),
        );
      },
      // 居中淡入并轻微上移放大，停靠边缘的面板从对应边缘滑入。
      transition: (context, progress, child) {
        final remaining = 1 - progress;
        return Opacity(
          opacity: progress,
          child: placement == .center
              ? Transform.translate(
                  offset: Offset(0, remaining * 16),
                  child: Transform.scale(scale: 1 - remaining * .02, child: child),
                )
              : FractionalTranslation(
                  translation: Offset(alignment.x, alignment.y) * remaining,
                  child: Transform.translate(
                    offset: Offset(alignment.x * margin, alignment.y * margin) * remaining,
                    child: child,
                  ),
                ),
        );
      },
      child: panel,
    ),
  );
}

// 顶部或底部面板：居中标题，可选关闭按钮。
Widget _sheet(BuildContext context, ElDialog c) {
  final t = context.elTheme;
  // 直接嵌入页面时没有关闭入口，不显示无效的关闭按钮。
  final showClose = c.showClose && c.onClose != null;
  return _surface(
    context,
    c.style,
    c.event,
    c.semanticLabel,
    ElStyle(
      borderRadius: .circular(28),
      vars: {
        ElTokens.$popupListPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ElTokens.$dividerColor: Color.lerp(t.borderColor, t.cardColor, .5)!,
      },
    ),
    Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        if (c.title != null || showClose)
          Stack(
            alignment: .center,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(showClose ? 52 : 24, 28, showClose ? 52 : 24, 16),
                child: ElView(
                  style: ElStyle(
                    fontSize: 20,
                    lineHeight: 1.4,
                    fontWeight: textWeight(t.fontWeightSubtitle),
                    textAlign: .center,
                  ),
                  child: c.title,
                ),
              ),
              if (showClose) PositionedDirectional(end: 12, child: _closeButton(context, 40, c.onClose)),
            ],
          ),
        Flexible(child: _scrollBody(buildContent(c.child))),
        ?_footer(context, c),
      ],
    ),
  );
}

// 居中确认框：正文保留内边距，页脚通栏贴合底部圆角。
Widget _dialog(BuildContext context, ElDialog c) {
  final t = context.elTheme;
  // 直接嵌入页面时没有关闭入口，不显示无效的关闭按钮。
  final showClose = c.showClose && c.onClose != null;
  final footer = _footer(context, c);
  return _surface(
    context,
    c.style,
    c.event,
    c.semanticLabel,
    const ElStyle(
      maxWidth: 420,
      borderRadius: .all(.circular(28)),
      textAlign: .center,
      vars: {ElTokens.$popupListPadding: EdgeInsets.zero},
    ),
    Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        const SizedBox(height: 32),
        if (c.title != null || showClose)
          Padding(
            padding: const .fromLTRB(32, 0, 32, 10),
            child: Row(
              children: [
                if (showClose) const SizedBox(width: 40),
                Expanded(
                  child: ElView(
                    style: ElStyle(fontSize: 22, lineHeight: 1.45, fontWeight: textWeight(t.fontWeightSubtitle)),
                    child: c.title,
                  ),
                ),
                if (showClose) _closeButton(context, 40, c.onClose),
              ],
            ),
          ),
        Flexible(
          child: _scrollBody(
            ElView(
              style: ElStyle(fontSize: 15, lineHeight: 1.9, color: t.textSecondary),
              child: c.child,
            ),
            padding: EdgeInsets.fromLTRB(32, 0, 32, footer == null ? 32 : 24),
          ),
        ),
        ?footer,
      ],
    ),
  );
}

// 自定义页脚优先；提供 confirmText 时绘制通栏的取消、确认操作，确认、取消等页脚操作额外提供触感。
Widget? _footer(BuildContext context, ElDialog c) {
  if (c.footer != null) return TouchActionScope(child: buildContent(c.footer));
  final confirm = c.confirmText;
  if (confirm == null) return null;
  final t = context.elTheme;
  final cancel = c.cancelText;
  Widget action(Object label, bool accepted) => Expanded(
    child: ElButton(
      variant: .text,
      style: ElStyle(
        width: '100%',
        minHeight: 66,
        padding: const .fromLTRB(16, 18, 16, 24),
        borderRadius: .zero,
        fontSize: 16,
        lineHeight: 1.5,
        color: accepted && c.type == .error ? t.error : t.primary,
        transition: reducedMotion(context)
            ? const []
            : const [ElTransition.field(.backgroundColor, Duration(milliseconds: 140))],
        onTap: ElStyle(backgroundColor: t.press, transform: ElTransform.scale(1), transition: const []),
      ),
      onPressed: accepted ? c.onConfirm : c.onCancel,
      child: label,
    ),
  );
  return TouchActionScope(
    child: Stack(
      children: [
        Row(children: [if (cancel != null) action(cancel, false), action(confirm, true)]),
        if (cancel != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: .topCenter,
                child: Padding(
                  padding: const .only(top: 20),
                  child: ElView(style: ElStyle(width: 1, height: 20, backgroundColor: t.borderColor)),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _surface(
  BuildContext context,
  ElStyle? override,
  ElEvent? event,
  String? semanticLabel,
  ElStyle style,
  Widget child,
) {
  final theme = context.elTheme;
  return ElView(
    event: event,
    semantics: ElSemantics(container: true, label: semanticLabel),
    style: ElStyle(
      width: '100%',
      clipBehavior: .antiAlias,
      backgroundColor: theme.cardColor,
      color: theme.textColor,
    ).merge(style).withShadow(type: .floating, level: theme.shadowXl).merge(override),
    child: child,
  );
}

Widget _scrollBody(Widget child, {EdgeInsetsGeometry? padding}) =>
    SingleChildScrollView(primary: false, padding: padding, physics: const ClampingScrollPhysics(), child: child);

Widget _closeButton(BuildContext context, double size, VoidCallback? onClose) => ElButton(
  semanticLabel: '关闭弹层',
  variant: .text,
  style: ElStyle(
    width: size,
    height: size,
    padding: .zero,
    borderRadius: .circular(12),
    iconSize: 18,
    iconColor: context.elTheme.textSecondary,
    transition: reducedMotion(context)
        ? const []
        : const [ElTransition.field(.backgroundColor, Duration(milliseconds: 140))],
    onTap: ElStyle(backgroundColor: context.elTheme.press, transform: ElTransform.scale(1), transition: const []),
  ),
  onPressed: onClose,
  child: ElMobileIcons.x,
);

/// 轻提示为半透明黑底浅色文字，暗色模式换成浅底深色文字，淡入淡出。
Widget toastBuilder(BuildContext context, ElToast c) => ElOverlayTransition(
  duration: const Duration(milliseconds: 200),
  builder: (context, animation) => FadeTransition(
    opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
    child: ElView(style: _toastStyle.merge(c.style), child: buildContent(c.child)),
  ),
);

const _toastStyle = ElStyle(
  maxWidth: '80%',
  padding: .symmetric(horizontal: 16, vertical: 10),
  backgroundColor: Color.fromRGBO(0, 0, 0, .65),
  color: Color(0xffffffff),
  iconColor: Color(0xffffffff),
  fontSize: 13,
  lineHeight: 1.35,
  textAlign: .center,
  borderRadius: .all(.circular(8)),
  onDark: ElStyle(
    backgroundColor: Color.fromRGBO(229, 234, 243, .85),
    color: Color(0xff1d2129),
    iconColor: Color(0xff1d2129),
  ),
);
