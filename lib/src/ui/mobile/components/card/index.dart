/// 参照：D:/project/html/my-ui/packages/vue/components/Card.vue；packages/core/my-ui.js:1607-1681；my-ui.css:3657-3753。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import '../loading/index.dart';

/// 将通用卡片声明交给移动端布局，正文仍使用调用方的原实例。
Widget cardBuilder(BuildContext context, ElCard component) => Card(
  title: component.title,
  description: component.description,
  sample: component.sample,
  loading: component.loading,
  interactive: component.interactive,
  delayTouchDown: component.delayTouchDown,
  delayTouchUp: component.delayTouchUp,
  onActivate: component.onActivate,
  style: component.style,
  focusNode: component.focusNode,
  semanticLabel: component.semanticLabel,
  child: component.child == null ? null : buildContent(component.child),
);

/// 手机卡片，interactive 启用整卡操作且隐藏默认标题区。
class Card extends StatelessWidget {
  /// 局部卡片圆角。
  static const $radius = 'card.radius';

  /// 局部卡片内边距。
  static const $padding = 'card.padding';

  /// 标题区与正文间距。
  static const $headerGap = 'card.headerGap';

  /// 按压缩放比例。
  static const $pressScale = 'card.pressScale';

  /// 按压背景。
  static const $pressBackground = 'card.pressBackground';

  /// 内部按钮与输入独立操作，onActivate只接收整卡激活。
  const Card({
    super.key,
    this.title,
    this.description,
    this.sample,
    this.loading = false,
    this.interactive = false,
    this.delayTouchDown = Duration.zero,
    this.delayTouchUp = const Duration(milliseconds: 100),
    this.onActivate,
    this.child,
    this.style,
    this.focusNode,
    this.semanticLabel,
  });

  /// 标题，交互卡片中只作为辅助名称。
  final String? title;

  /// 标题下说明。
  final String? description;

  /// 右上示例编号。
  final String? sample;

  /// 加载期间保留正文实例并暂停其交互。
  final bool loading;

  /// 是否整卡可激活。
  final bool interactive;

  /// 触摸按下等待。
  final Duration delayTouchDown;

  /// 从触摸按下起算的最短反馈。
  final Duration delayTouchUp;

  /// 鼠标、触摸或键盘激活。
  final ElEventHandler? onActivate;

  /// 默认正文插槽。
  final Widget? child;

  /// 外观覆盖。
  final ElStyle? style;

  /// 整卡焦点节点。
  final FocusNode? focusNode;

  /// 卡片区域的辅助名称。
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final t = context.elTheme, width = viewport(context);
    final vars = ElView.maybeOf(context);
    final narrow = width <= 400;
    final padding = vars?.getVar<EdgeInsetsGeometry>($padding) ?? const EdgeInsets.fromLTRB(22, 24, 22, 25);
    final cardStyle = ElStyle(
      width: '100%',
      backgroundColor: t.cardColor,
      borderRadius: BorderRadius.circular(vars?.getVar<num>($radius)?.toDouble() ?? 26),
      border: ElBorder.all(borderWidth: 1, borderColor: t.borderColor.withValues(alpha: t.borderColor.a * .65)),
      boxShadow: t.shadowMd,
      padding: padding.add(const EdgeInsets.all(1)),
      userSelect: interactive ? ElUserSelect.none : null,
      transition: reducedMotion(context)
          ? const []
          : const [ElTransition.all(Duration(milliseconds: 150), Curves.easeOut)],
      onTap: interactive && !loading
          ? ElStyle(
              backgroundColor: vars?.getVar<Color>($pressBackground) ?? Color.lerp(t.cardColor, t.textColor, .085),
              transform: ElTransform.scale(vars?.getVar<num>($pressScale)?.toDouble() ?? .96),
            )
          : null,
    ).merge(style);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!interactive && title?.isNotEmpty == true)
          Padding(
            padding: EdgeInsets.only(bottom: vars?.getVar<num>($headerGap)?.toDouble() ?? 23),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: narrow ? 10 : 18,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElView(
                        style: textStyle(
                          context,
                          narrow ? 19 : 20,
                          t.fontWeightSubtitle,
                          height: 1.35,
                        ).merge(const ElStyle(letterSpacing: -.55, margin: EdgeInsets.only(bottom: 7))),
                        child: title,
                      ),
                      if (description?.isNotEmpty == true)
                        ElView(
                          style: textStyle(context, 13, t.fontWeight, color: t.textSecondary, height: 1.55),
                          child: description,
                        ),
                    ],
                  ),
                ),
                if (sample?.isNotEmpty == true)
                  ElView(
                    style: textStyle(context, narrow ? 9 : 10, t.fontWeight, color: t.textSecondary).merge(
                      ElStyle(padding: const EdgeInsets.only(top: 7), letterSpacing: narrow ? 0 : .5, softWrap: false),
                    ),
                    child: sample,
                  ),
              ],
            ),
          ),
        ?child,
      ],
    );
    final content = Stack(
      alignment: Alignment.center,
      children: [
        ExcludeFocus(
          excluding: loading,
          child: TickerMode(
            enabled: !loading,
            child: Offstage(offstage: loading, child: body),
          ),
        ),
        if (loading) const Loading(),
      ],
    );
    return interactive
        ? ActionView(
            style: cardStyle,
            label: semanticLabel ?? title,
            blocked: loading,
            excludeChildSemantics: false,
            ignoreDescendantAction: true,
            focusNode: focusNode,
            repeatEnter: false,
            delayTouchDown: delayTouchDown,
            delayTouchUp: delayTouchUp,
            onActivate: onActivate,
            child: content,
          )
        : ElView(
            style: cardStyle,
            semantics: semanticLabel == null ? null : ElSemantics(container: true, label: semanticLabel),
            child: content,
          );
  }
}
