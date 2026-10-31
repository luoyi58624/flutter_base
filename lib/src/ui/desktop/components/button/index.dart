import 'package:flutter_base/src/ui/desktop/internal.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/widgets.dart';

List<double> get _buttonFonts => const [12.0, 13.0, 14.0, 15.0, 16.0];

List<double> get _buttonIcons => const [12.0, 13.0, 15.0, 16.0, 18.0];

List<double> get _buttonGaps => const [4.0, 6.0, 6.0, 8.0, 10.0];

List<EdgeInsetsGeometry> get _buttonPaddings => const [
  EdgeInsets.symmetric(vertical: 2, horizontal: 10),
  EdgeInsets.symmetric(vertical: 4, horizontal: 14),
  EdgeInsets.symmetric(vertical: 4, horizontal: 16),
  EdgeInsets.symmetric(vertical: 4, horizontal: 20),
  EdgeInsets.symmetric(vertical: 4, horizontal: 24),
];

/// Element 按钮主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class Button extends StatefulWidget {
  const Button(this.component, {super.key});
  final ElButton component;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  late final _press = ElButtonViewPressController()
    ..addListener(_pressedChanged);

  void _pressedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(Button oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.component.disabled || widget.component.loading) _press.cancel();
  }

  @override
  void dispose() {
    _press
      ..removeListener(_pressedChanged)
      ..dispose();
    super.dispose();
  }

  ElStyle _style(BuildContext context, ElButton component, bool pressed) {
    var base = component._styleBuilder(context);
    if (pressed && !component.loading) base = base.merge(base.onTap);
    final user = component.style;
    final merged = base.merge(user);
    return component.circle && !component.link
        ? merged.copyWith(width: merged.height)
        : merged;
  }

  @override
  Widget build(BuildContext context) {
    final component = widget.component;
    final button = ElButtonView(
      onPressed: component.loading ? null : component.onPressed,
      semanticLabel: component.semanticLabel,
      style: _style(context, component, _press.pressed),
      event: component.event,
      focusNode: component.focusNode,
      pressController: _press,
      disabled: component.disabled,
      selected: component.selected,
      toggled: component.isToggle ? component.selected : null,
      child: component._buttonContent(context),
    );
    return component.block ? button : UnconstrainedBox(child: button);
  }
}

extension _ButtonAppearance on ElButton {
  /// 图标按钮：`child` 是 [IconData] 即图标按钮（与外观无关，忽略 left/right）。
  bool get _isIcon => child is IconData;

  bool get _isDesktop {
    if (!ElPlatform.isFlutterTest) return ElPlatform.isDesktop;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  /// 移动端按下立即进入目标样式，松开后由基础态 transition 恢复。
  ElStyle _mobileTap(ElStyle style) =>
      style.copyWith(transition: const [ElTransition.all(Duration.zero)]);

  /// 主题色源：bgColor 显式覆盖 > type token（祖先主题色）。
  Color? _resolvedTypeColor(BuildContext context) {
    if (bgColor != null) return bgColor;
    return type?.color(context);
  }

  /// 图标按钮宽度：无 [circle] 固定 = 高度 × 1.2；[circle] 跟随高度（正方）。
  double? _iconButtonWidth(double boxSize) =>
      _isIcon ? (circle ? null : boxSize * 1.2) : null;

  /// 变体优先级同官方组件：link > text > ghost > plain。
  ElStyle _styleBuilder(BuildContext context) {
    final isDesktop = _isDesktop;
    // 尺寸档与控件高度统一读取祖先注入的通用主题变量。
    final resolvedSize = _size(context);
    var base = ElStyle(
      // 官方 .el-button line-height: 1（高度全由 padding 撑出）
      lineHeight: 1.0,
      fontSize: _buttonFonts[resolvedSize.index],
      fontWeight: .w500,
      iconSize: _buttonIcons[resolvedSize.index],
      cursor: SystemMouseCursors.click,
      userSelect: .none,
      alignment: .center,
      transition: [.all(Duration(milliseconds: isDesktop ? 100 : 200))],
    );
    // link 是纯文字形态（官方 padding 2 / height auto），其余变体共享同一套盒尺寸；
    // circle 固定方盒（宽 = 高）
    final boxSize = context.elTheme.controlHeights[resolvedSize.index];
    if (link) {
      base = base.copyWith(padding: const EdgeInsets.all(2));
    } else if (circle) {
      // 官方 is-circle：宽 = 高的正方盒 + 50% 圆角。内容区 = 整盒（无内边距），
      // 图标/文字居中即与按钮盒同心——加 padding 反而会在 xs 档压缩内容区
      // 导致 glyph 超盒绘制右偏下。
      base = base.copyWith(
        width: boxSize,
        height: boxSize,
        borderRadius: BorderRadius.all(Radius.circular(boxSize / 2)),
      );
    } else {
      base = base.copyWith(
        // 图标按钮：内边距归零 + 宽度固定 = 高度 × 1.2（不受 padding 撑宽）；
        // 其余官方默认档：height 32 / padding 8px 15px，移动端对齐 large 档
        minHeight: boxSize,
        width: _iconButtonWidth(boxSize),
        padding: _isIcon
            ? EdgeInsets.zero
            : _buttonPaddings[resolvedSize.index],
        // round 胶囊 = 半高全圆（官方 border-radius-round 的实际效果，padding 同直角档）
        borderRadius: BorderRadius.circular(
          round ? boxSize / 2 : (isDesktop ? 4 : 6),
        ),
      );
    }

    final typeColor = _resolvedTypeColor(context);
    base = base.copyWith(onFocusVisible: _focusRingStyle(context, typeColor));
    ElStyle result;
    if (link) {
      result = _linkStyle(context, base, typeColor);
    } else if (text) {
      result = _textStyle(context, base, typeColor);
    } else if (ghost) {
      result = _ghostStyle(context, base, typeColor);
    } else if (typeColor == null) {
      result = _defaultStyle(context, base);
    } else if (plain) {
      result = _plainStyle(context, base, typeColor);
    } else {
      result = _themeStyle(context, base, typeColor);
    }

    if (isToggle && !link) {
      // 实心主题色只在选中后出现；其他变体保持原来的未选中外观。
      if (typeColor != null && !plain && !ghost && !text) {
        result = _defaultStyle(context, base);
      }
      if (typeColor != null || plain || ghost || text) {
        final color = typeColor ?? context.elTheme.primary;
        final theme = _themeStyle(context, const ElStyle(), color);
        // 文本按钮没有描边占位，填色时也不新增边框宽度，避免选中导致尺寸跳动。
        final selected = theme
            .copyWith(
              border: text ? null : theme.border,
              onHover: null,
              onTap: null,
              onDisabled: null,
            )
            .copyWith(
              onTap: text ? theme.onTap?.copyWith(border: null) : theme.onTap,
              onDisabled: text
                  ? theme.onDisabled?.copyWith(border: null)
                  : theme.onDisabled,
            );
        if (this.selected) {
          result = result.copyWith(onHover: null, onTap: null).merge(selected);
        }
      }
    }

    if (!loading) return result;
    // 官方 is-loading = pointer-events none + extra-light 蒙层盖住整钮（含文字）。
    // el_ui 无伪元素蒙层，用整体透明度等效；显式置空 onHover/onTap 静默交互
    // 反馈（copyWith 传非空是深合并，传 null 才是清空）。
    return result.copyWith(
      cursor: SystemMouseCursors.basic,
      opacity: 0.7,
      onHover: null,
      onTap: null,
    );
  }

  /// 按背景明暗取通用对比文字色，背景暗用 textOnDark，背景亮用 textOnLight。
  /// 只按基础底判定一次，消费时兜底使跨风格局部使用无需 ElApp。
  /// 交互态（hover/tap 背景变浅变深）不参与——实心按钮文字色一经确定
  /// 不再变化。
  Color _textOnBackground(BuildContext context, Color background) {
    final dark = background.isDark.brightness == Brightness.dark;
    return dark
        ? context.elTheme.textOnDark
        : context.elTheme.textOnLight;
  }

  /// 无 type 的默认按钮；
  /// plain 时 hover 保持卡片底不染色（官方 is-plain 基础形态）
  ElStyle _defaultStyle(BuildContext context, ElStyle base) {
    final isDesktop = _isDesktop;
    final primary = context.elTheme.primary;
    final bgColor = context.elTheme.bgColor;
    final textColor = context.elTheme.textRegular;
    final borderColor = context.elTheme.borderColor;
    final plainAppearance = plain;
    final hoverTextColor = primary;
    final hoverBgColor = plainAppearance ? bgColor : primary.elLight9(context);
    final hoverBorderColor = plainAppearance
        ? primary
        : primary.elLight7(context);
    final active = ElStyle(
      color: primary,
      backgroundColor: plainAppearance ? bgColor : primary.elLight9(context),
      border: _border(context, color: primary),
      iconColor: primary,
    );
    return base
        .copyWith(
          color: textColor,
          backgroundColor: bgColor,
          border: _border(context, color: borderColor),
          onHover: (selected && !isToggle)
              ? null
              : (!isDesktop
                    ? null
                    : ElStyle(
                        color: hoverTextColor,
                        backgroundColor: hoverBgColor,
                        border: _border(context, color: hoverBorderColor),
                        iconColor: hoverTextColor,
                      )),
          onTap: (selected && !isToggle)
              ? null
              : (isDesktop ? active : _mobileTap(active)),

          onDisabled: ElStyle(
            cursor: SystemMouseCursors.forbidden,
            color: context.elTheme.textPlaceholder,
            backgroundColor: bgColor,
            border: _border(context, color: borderColor),
            iconColor: context.elTheme.textPlaceholder,
          ),
          iconColor: textColor,
        )
        .merge((selected && !isToggle) ? (active) : null);
  }

  /// 构建主题按钮样式
  ElStyle _themeStyle(BuildContext context, ElStyle base, Color typeColor) {
    final isDesktop = _isDesktop;
    // 文字色只按**基础底**明暗定一次（浅底深字 / 深底浅字）；
    // hover（light-3 变浅）/ active（dark-2 变深）交互态文字保持不变
    // （Element Plus 实心按钮交互只动背景，文字不反转）。
    final textColor = _textOnBackground(context, typeColor);
    // 实心基色不随主题明暗反转，交互固定悬停变浅、按压变深。
    final activeColor = typeColor.elLightOf(.dark, 2);

    final active = ElStyle(
      color: textColor,
      backgroundColor: activeColor,
      border: _border(context, color: activeColor),
      iconColor: textColor,
    );
    final hoverBg = typeColor.elLightOf(.light, 3);
    return base
        .copyWith(
          color: textColor,
          backgroundColor: typeColor,
          border: _border(context, color: typeColor),
          onHover: (selected && !isToggle)
              ? null
              : (!isDesktop
                    ? null
                    : ElStyle(
                        color: textColor,
                        backgroundColor: hoverBg,
                        border: _border(context, color: hoverBg),
                        iconColor: textColor,
                      )),
          onTap: (selected && !isToggle)
              ? null
              : (isDesktop ? active : _mobileTap(active)),

          onDisabled: ElStyle(
            cursor: SystemMouseCursors.forbidden,
            color: const Color(0xffffffff),
            backgroundColor: typeColor.elLight5(context),
            border: _border(context, color: typeColor.elLight5(context)),
            iconColor: const Color(0xffffffff),
          ),
          iconColor: textColor,
        )
        .merge((selected && !isToggle) ? (active) : null);
  }

  /// 构建朴素按钮（浅底描边，hover 反转为实心）
  ElStyle _plainStyle(BuildContext context, ElStyle base, Color typeColor) {
    final isDesktop = _isDesktop;
    final dark2 = typeColor.elLightOf(.dark, 2);
    // 转为实心后按基础主题色取对比文字，避免交互变色时文字明暗跳变。
    final textColor = _textOnBackground(context, typeColor);
    final active = ElStyle(
      color: textColor,
      backgroundColor: dark2,
      border: _border(context, color: dark2),
      iconColor: textColor,
    );
    final mobileActive = ElStyle(
      color: textColor,
      backgroundColor: typeColor,
      border: _border(context, color: typeColor),
      iconColor: textColor,
    );
    return base
        .copyWith(
          color: typeColor,
          backgroundColor: typeColor.elLight9(context),
          border: _border(context, color: typeColor.elLight5(context)),
          onHover: (selected && !isToggle)
              ? null
              : (!isDesktop
                    ? null
                    : ElStyle(
                        color: textColor,
                        backgroundColor: typeColor,
                        border: _border(context, color: typeColor),
                        iconColor: textColor,
                      )),
          onTap: (selected && !isToggle)
              ? null
              : (isDesktop ? active : _mobileTap(mobileActive)),

          onDisabled: ElStyle(
            cursor: SystemMouseCursors.forbidden,
            color: typeColor.elLight5(context),
            backgroundColor: typeColor.elLight9(context),
            border: _border(context, color: typeColor.elLight8(context)),
            iconColor: typeColor.elLight5(context),
          ),
          iconColor: typeColor,
        )
        .merge((selected && !isToggle) ? (active) : null);
  }

  /// 构建幽灵按钮样式，背景恒透明，鼠标悬停边框高亮
  ElStyle _ghostStyle(BuildContext context, ElStyle base, Color? typeColor) {
    final isDesktop = _isDesktop;
    final primary = typeColor ?? context.elTheme.primary;
    final textColor = primary;
    // 幽灵形态边框：默认级别与 plain 一致（light-5）
    final borderColor = primary.elLight5(context);
    final active = ElStyle(
      color: primary,
      backgroundColor: const Color(0x00000000),
      border: _border(context, color: primary),
      iconColor: primary,
    );
    return base
        .copyWith(
          color: textColor,
          backgroundColor: const Color(0x00000000),
          border: _border(context, color: borderColor),
          onHover: (selected && !isToggle)
              ? null
              : (!isDesktop
                    ? null
                    : ElStyle(
                        color: primary,
                        backgroundColor: const Color(0x00000000),
                        border: _border(context, color: primary),
                        iconColor: primary,
                      )),
          onTap: (selected && !isToggle)
              ? null
              : (isDesktop ? active : _mobileTap(active)),

          onDisabled: ElStyle(
            cursor: SystemMouseCursors.forbidden,
            color: context.elTheme.textPlaceholder,
            backgroundColor: const Color(0x00000000),
            border: _border(context, color: borderColor),
            iconColor: context.elTheme.textPlaceholder,
          ),
          iconColor: textColor,
        )
        .merge((selected && !isToggle) ? (active) : null);
  }

  /// 构建文本按钮样式，透明背景，悬停加深
  ElStyle _textStyle(BuildContext context, ElStyle base, Color? typeColor) {
    final isDesktop = _isDesktop;
    final textColor = typeColor ?? context.elTheme.textRegular;
    // 交互底从 $bgColor 加深派生：按背景明暗调整 elLight 反转值，恒走 _darken
    // 方向（亮底 reverse 混深灰、暗底走暗色分支混深灰）；hover 3 级、active 6 级
    final background = context.elTheme.bgColor;
    final activeColor = background.elLight1(context, reverse: true);
    final active = ElStyle(
      color: textColor,
      backgroundColor: activeColor,
      iconColor: textColor,
    );
    return base
        .copyWith(
          color: textColor,
          backgroundColor: bg ? background.deepen(5) : null,
          onHover: (selected && !isToggle)
              ? null
              : (!isDesktop ? null : active),
          onTap: (selected && !isToggle)
              ? null
              : (isDesktop ? null : _mobileTap(active)),

          onDisabled: ElStyle(
            cursor: SystemMouseCursors.forbidden,
            color:
                typeColor?.elLight5(context) ??
                context.elTheme.textPlaceholder,
            backgroundColor: bg ? background.deepen(5) : const Color(0x00000000),
            iconColor:
                typeColor?.elLight5(context) ??
                context.elTheme.textPlaceholder,
          ),
          iconColor: textColor,
        )
        .merge(
          (selected && !isToggle) ? (ElStyle(backgroundColor: activeColor)) : null,
        );
  }

  /// 构建链接按钮样式，纯文本
  ElStyle _linkStyle(BuildContext context, ElStyle base, Color? typeColor) {
    final isDesktop = _isDesktop;
    final textColor = typeColor ?? context.elTheme.textRegular;
    final active = ElStyle(
      color: typeColor != null ? typeColor.elLightOf(.dark, 2) : textColor,
      iconColor: typeColor != null ? typeColor.elLightOf(.dark, 2) : textColor,
    );
    final interactiveBase = isDesktop
        ? base
        : base.copyWith(
            transition: [
              ...?base.transition,
              const ElTransition.field(
                ElTransitionField.opacity,
                Duration(milliseconds: 250),
                Curves.easeInOutQuad,
              ),
            ],
          );
    return interactiveBase
        .copyWith(
          color: textColor,
          onHover: (selected && !isToggle)
              ? null
              : (!isDesktop
                    ? null
                    : ElStyle(
                        color:
                            typeColor?.elLightOf(.light, 5) ??
                            context.elTheme.textSecondary,
                        iconColor:
                            typeColor?.elLightOf(.light, 5) ??
                            context.elTheme.textSecondary,
                      )),
          onTap: (selected && !isToggle)
              ? null
              : (isDesktop
                    ? active
                    : const ElStyle(
                        opacity: 0.2,
                        transition: [
                          .field(ElTransitionField.opacity, Duration.zero),
                        ],
                      )),

          onDisabled: ElStyle(
            cursor: SystemMouseCursors.forbidden,
            color:
                typeColor?.elLight5(context) ??
                context.elTheme.textPlaceholder,
            iconColor:
                typeColor?.elLight5(context) ??
                context.elTheme.textPlaceholder,
          ),
          iconColor: textColor,
        )
        .merge((selected && !isToggle) ? (active) : null);
  }

  /// 构建聚焦环样式
  ElStyle _focusRingStyle(BuildContext context, Color? typeColor) {
    final ringColor = typeColor ?? context.elTheme.primary;
    return ElStyle(outline: ElOutline(outlineWidth: 2, outlineColor: ringColor, outlineOffset: 1));
  }

  /// 组件尺寸档：读取祖先主题变量中的 size。
  ElLevelType _size(BuildContext context) => context.elComponentSize(style);

  /// 构建 loading 小部件
  Widget _loadingWidget() => ElLoading(child: _iconWidget(ElIcons.loading));

  /// 构建图标小部件
  Widget _iconWidget(Object? icon) =>
      icon is IconData ? ElIcon(icon) : _dynamicWidget(icon);

  /// 构建动态类型小部件
  Widget _dynamicWidget(Object? value) {
    if (value is Widget) return value;
    return ElView(child: value);
  }

  /// 组装按钮内容
  Widget _buttonContent(BuildContext context) {
    if (_isIcon) {
      if (loading) return _loadingWidget();
      return _iconWidget(child);
    }
    if (!loading && leftIcon == null && rightIcon == null) {
      return _dynamicWidget(child);
    }
    final leftWidget = loading
        ? _loadingWidget()
        : leftIcon == null
        ? null
        : _iconWidget(leftIcon);
    return Row(
      mainAxisSize: .min,
      mainAxisAlignment: .center,
      crossAxisAlignment: .center,
      children: [
        ?leftWidget,
        if (leftWidget != null && child != null)
          ElView(style: (_gapStyle)(context)),
        if (child != null) _dynamicWidget(child),
        if (rightIcon != null && (leftWidget != null || child != null))
          ElView(style: (_gapStyle)(context)),
        if (rightIcon != null) _iconWidget(rightIcon),
      ],
    );
  }

  ElStyle _gapStyle(BuildContext context) =>
      ElStyle(width: _buttonGaps[_size(context).index]);
}

ElBorder _border(BuildContext context, {required Color color}) => .all(
  borderColor: color,
  borderWidth: context.elTheme.borderWidths[ElLevelType.md.index],
);
