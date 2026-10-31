/// 参照：D:/project/html/my-ui/packages/vue/components/Card.vue；packages/core/my-ui.js:1607-1681；my-ui.css:3657-3753。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import '../../cores/theme.dart';

/// 原版响应式卡片，interactive启用整卡操作且隐藏默认标题区。
class MyCard extends StatelessWidget {
  /// 内部按钮与输入独立操作，onActivate只接收整卡激活。
  const MyCard({
    super.key,
    this.title,
    this.description,
    this.sample,
    this.interactive = false,
    this.delayTouchDown = Duration.zero,
    this.delayTouchUp = const Duration(milliseconds: 100),
    this.onActivate,
    this.child,
    this.style,
    this.focusNode,
  });

  /// 标题，交互卡片中只作为辅助名称。
  final String? title;

  /// 标题下说明。
  final String? description;

  /// 右上示例编号。
  final String? sample;

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
  @override
  Widget build(BuildContext context) {
    final t = MyTheme.of(context), width = myViewport(context);
    final mobile = width <= 760, narrow = width <= 400;
    final padding =
        t.cardPadding ??
        (mobile
            ? const EdgeInsets.fromLTRB(22, 24, 22, 25)
            : width <= 1100
            ? const EdgeInsets.fromLTRB(28, 29, 28, 30)
            : const EdgeInsets.fromLTRB(29, 28, 29, 29));
    final cardStyle = ElStyle(
      width: '100%',
      backgroundColor: t.cardBackground,
      borderRadius: BorderRadius.circular(t.cardRadius ?? (mobile ? 26 : 30)),
      border: ElBorder.all(
        borderWidth: 1,
        borderColor: t.border.withValues(alpha: t.border.a * .65),
      ),
      boxShadow: t.shadow,
      padding: padding.add(const EdgeInsets.all(1)),
      userSelect: interactive ? ElUserSelect.none : null,
      transition: myReducedMotion(context)
          ? const []
          : const [
              ElTransition.all(Duration(milliseconds: 150), Curves.easeOut),
            ],
      onHover: interactive
          ? ElStyle(
              backgroundColor:
                  t.cardHoverBackground ??
                  Color.lerp(t.cardBackground, t.text, .03),
            )
          : null,
      onTap: interactive
          ? ElStyle(
              backgroundColor:
                  t.cardPressBackground ??
                  Color.lerp(t.cardBackground, t.text, .085),
              transform: ElTransform.scale(t.cardPressScale ?? .96),
            )
          : null,
      onFocusVisible: interactive ? myFocusStyle(context) : null,
    ).merge(style);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!interactive && title?.isNotEmpty == true)
          Padding(
            padding: EdgeInsets.only(
              bottom: t.cardHeaderGap ?? (mobile ? 23 : 22),
            ),
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
                        style:
                            myTextStyle(
                              context,
                              narrow ? 19 : 20,
                              t.fontWeightSubtitle,
                              height: 1.35,
                            ).merge(
                              const ElStyle(
                                letterSpacing: -.55,
                                margin: EdgeInsets.only(bottom: 7),
                              ),
                            ),
                        child: title,
                      ),
                      if (description?.isNotEmpty == true)
                        ElView(
                          style: myTextStyle(
                            context,
                            13,
                            t.fontWeight,
                            color: t.textSecondary,
                            height: 1.55,
                          ),
                          child: description,
                        ),
                    ],
                  ),
                ),
                if (sample?.isNotEmpty == true)
                  ElView(
                    style:
                        myTextStyle(
                          context,
                          narrow ? 9 : 10,
                          t.fontWeight,
                          color: t.textSecondary,
                        ).merge(
                          ElStyle(
                            padding: EdgeInsets.only(top: mobile ? 7 : 6),
                            letterSpacing: narrow ? 0 : .5,
                            softWrap: false,
                          ),
                        ),
                    child: sample,
                  ),
              ],
            ),
          ),
        ?child,
      ],
    );
    return interactive
        ? MyAction(
            style: cardStyle,
            label: title,
            excludeChildSemantics: false,
            ignoreDescendantAction: true,
            focusNode: focusNode,
            repeatEnter: false,
            delayTouchDown: delayTouchDown,
            delayTouchUp: delayTouchUp,
            onActivate: onActivate,
            child: body,
          )
        : ElView(style: cardStyle, child: body);
  }
}
