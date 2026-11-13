import 'package:flutter/widgets.dart';

import '../../internal.dart';

const _curve = Cubic(0, 0, .2, 1);

/// 桌面消息沿用 Element 浅色底：类型色图标与文字，可选关闭按钮。
/// 进场自上方 40 像素滑入并淡入；退场反向，同时收起高度让后续消息补位。
Widget messageBuilder(BuildContext context, ElMessage c) => ElOverlayTransition(
  duration: const Duration(milliseconds: 300),
  builder: (context, animation) => AnimatedBuilder(
    animation: animation,
    builder: (context, child) => Align(
      alignment: .topCenter,
      widthFactor: 1,
      heightFactor: animation.status == .reverse ? animation.value : 1,
      child: Opacity(
        opacity: animation.value,
        child: Transform.translate(offset: Offset(0, -40 * (1 - _curve.transform(animation.value))), child: child),
      ),
    ),
    // 间距放在收起范围内，补位时一并收回。
    child: Padding(padding: const .only(bottom: 8), child: _Message(c)),
  ),
);

/// 桌面消息自安全区顶部下方 20 像素起居中，按显示先后自上而下排列。
Widget messageStackBuilder(BuildContext context, List<Widget> children) => SafeArea(
  child: Padding(
    padding: const .only(top: 20),
    // 消息多到超出窗口时向下延伸到窗口外，不按溢出报错。
    child: OverflowBox(
      alignment: .topCenter,
      minWidth: 0,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Column(mainAxisSize: .min, children: children),
    ),
  ),
);

class _Message extends StatelessWidget {
  const _Message(this.c);

  final ElMessage c;

  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    final color = c.type.color(context);
    return ElView(
      style: ElStyle(
        minHeight: 40,
        maxWidth: 450,
        sm: const ElStyle(maxWidth: 320),
        xs: const ElStyle(maxWidth: 250),
        padding: const .symmetric(horizontal: 20, vertical: 10),
        backgroundColor: color.elLight9(context),
        border: .all(borderColor: color.elLight8(context)),
        borderRadius: .circular(t.radiusMd),
        color: color,
        iconColor: color,
        iconSize: 16,
        fontSize: 14,
        fontWeight: .w500,
        onDark: ElStyle(color: t.textColor),
      ).merge(c.style),
      child: Row(
        mainAxisSize: .min,
        spacing: 10,
        children: [
          ElIcon(switch (c.type) {
            .primary => ElDesktopIcons.platformEleme,
            .success => ElDesktopIcons.success,
            .warning => ElDesktopIcons.warning,
            .error => ElDesktopIcons.error,
            .info => ElDesktopIcons.info,
          }),
          Flexible(child: ElView(child: elContent(c.child))),
          if (c.onClose != null)
            ElButtonView(
              onPressed: c.onClose,
              semanticLabel: '关闭消息',
              style: ElStyle(
                width: 20,
                height: 20,
                borderRadius: .circular(9999),
                alignment: .center,
                iconSize: 16,
                iconColor: t.textColor.withAlpha(150),
                cursor: SystemMouseCursors.click,
                onHover: ElStyle(iconColor: color, backgroundColor: color.elLight7(context)),
                transition: const [ElTransition.all(Duration(milliseconds: 150))],
              ),
              child: const ElIcon(ElDesktopIcons.close),
            ),
        ],
      ),
    );
  }
}
