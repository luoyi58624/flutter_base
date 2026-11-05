import 'package:flutter/widgets.dart';

import '../../internal.dart';

/// 桌面预设使用的 Element 按钮实现。
class Button extends StatefulWidget {
  const Button(this.component, this.model, {super.key});

  final ElButton component;

  /// 切换按钮的选中模型；普通按钮不读取。
  final Obs<bool> model;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  late final _press = ElButtonViewPressController()..addListener(_pressedChanged);

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

  @override
  Widget build(BuildContext context) {
    final component = widget.component;
    final model = widget.model;
    final selected = component.isToggle && model.value;
    var style = component._styleBuilder(context, selected);
    if (_press.pressed && !component.loading) style = style.merge(style.onTap);
    style = style.merge(component.style);
    final button = ElButtonView(
      onPressed: component.isToggle
          ? () => model.value = !model.value
          : component.loading
          ? null
          : component.onPressed,
      semanticLabel: component.semanticLabel,
      style: style,
      event: component.event,
      focusNode: component.focusNode,
      pressController: _press,
      disabled: component.disabled,
      toggled: component.isToggle ? selected : null,
      child: component._buttonContent(context),
    );
    // 显式宽度（如 '100%'）需要父级约束，其余按内容宽度排布。
    return style.width != null ? button : UnconstrainedBox(child: button);
  }
}

extension on ElButton {
  /// 图标按钮：`child` 是 [IconData] 即图标按钮（与外观无关，忽略 left/right）。
  bool get _isIcon => child is IconData;

  bool get _link => variant == .link;
  bool get _text => variant == .text;
  bool get _plain => variant == .outline;

  /// 按 variant 选择 Element 外观：link、text、plain（outline）与实心主题色。
  ElStyle _styleBuilder(BuildContext context, bool selected) {
    // 紧凑密度优先读取组件自身声明，再继承祖先配置。
    final compact = context.elComponentCompact(style);
    var base = ElStyle(
      // 官方 .el-button line-height: 1（高度全由 padding 撑出）
      lineHeight: 1.0,
      fontSize: compact ? 13 : 14,
      fontWeight: .w500,
      iconSize: compact ? 13 : 15,
      cursor: SystemMouseCursors.click,
      userSelect: .none,
      alignment: .center,
      transition: const [.all(Duration(milliseconds: 100))],
    );
    // link 是纯文字形态，其他外观共享 normal / compact 盒尺寸；
    // circle 固定方盒（宽 = 高）
    final boxSize = compact ? 32.0 : 36.0;
    if (_link) {
      base = base.copyWith(padding: const EdgeInsets.all(2));
    } else {
      base = base.copyWith(
        // 图标按钮是无内边距的正方盒，正圆由用户 style 的圆角表达；
        // 普通按钮按 normal / compact 设置高度和水平内边距。
        minHeight: boxSize,
        width: _isIcon ? boxSize : null,
        height: _isIcon ? boxSize : null,
        padding: _isIcon ? EdgeInsets.zero : EdgeInsets.symmetric(vertical: 4, horizontal: compact ? 14 : 16),
        borderRadius: BorderRadius.circular(4),
      );
    }

    final typeColor = type?.color(context);
    base = base.copyWith(onFocusVisible: _focusRingStyle(context, typeColor));
    ElStyle result;
    if (_link) {
      result = _linkStyle(context, base, typeColor);
    } else if (_text) {
      result = _textStyle(context, base, typeColor);
    } else if (typeColor == null) {
      result = _defaultStyle(context, base);
    } else if (_plain) {
      result = _plainStyle(context, base, typeColor);
    } else {
      result = _themeStyle(context, base, typeColor);
    }

    if (isToggle && !_link) {
      // 实心主题色只在选中后出现；其他变体保持原来的未选中外观。
      if (typeColor != null && !_plain && !_text) {
        result = _defaultStyle(context, base);
      }
      if (typeColor != null || _plain || _text) {
        final color = typeColor ?? context.elTheme.primary;
        final theme = _themeStyle(context, const ElStyle(), color);
        // 文本按钮没有描边占位，填色时也不新增边框宽度，避免选中导致尺寸跳动。
        final selectedStyle = theme
            .copyWith(border: _text ? null : theme.border, onHover: null, onTap: null, onDisabled: null)
            .copyWith(
              onTap: _text ? theme.onTap?.copyWith(border: null) : theme.onTap,
              onDisabled: _text ? theme.onDisabled?.copyWith(border: null) : theme.onDisabled,
            );
        if (selected) {
          result = result.copyWith(onHover: null, onTap: null).merge(selectedStyle);
        }
      }
    }

    if (!loading) return result;
    // 官方 is-loading = pointer-events none + extra-light 蒙层盖住整钮（含文字）。
    // el_ui 无伪元素蒙层，用整体透明度等效；显式置空 onHover/onTap 静默交互
    // 反馈（copyWith 传非空是深合并，传 null 才是清空）。
    return result.copyWith(cursor: SystemMouseCursors.basic, opacity: 0.7, onHover: null, onTap: null);
  }

  /// 按背景明暗取通用对比文字色，背景暗用 textOnDark，背景亮用 textOnLight。
  /// 只按基础底判定一次，消费时兜底使跨风格局部使用无需 ElApp。
  /// 交互态（hover/tap 背景变浅变深）不参与——实心按钮文字色一经确定
  /// 不再变化。
  Color _textOnBackground(BuildContext context, Color background) {
    final dark = background.isDark.brightness == Brightness.dark;
    return dark ? context.elTheme.textOnDark : context.elTheme.textOnLight;
  }

  /// 无 type 的默认按钮；
  /// plain 时 hover 保持卡片底不染色（官方 is-plain 基础形态）
  ElStyle _defaultStyle(BuildContext context, ElStyle base) {
    final primary = context.elTheme.primary;
    final bgColor = context.elTheme.bgColor;
    final textColor = context.elTheme.textRegular;
    final borderColor = context.elTheme.borderColor;
    final plainAppearance = _plain;
    final hoverTextColor = primary;
    final hoverBgColor = plainAppearance ? bgColor : primary.elLight9(context);
    final hoverBorderColor = plainAppearance ? primary : primary.elLight7(context);
    final active = ElStyle(
      color: primary,
      backgroundColor: plainAppearance ? bgColor : primary.elLight9(context),
      border: _border(context, color: primary),
      iconColor: primary,
    );
    return base.copyWith(
      color: textColor,
      backgroundColor: bgColor,
      border: _border(context, color: borderColor),
      onHover: ElStyle(
        color: hoverTextColor,
        backgroundColor: hoverBgColor,
        border: _border(context, color: hoverBorderColor),
        iconColor: hoverTextColor,
      ),
      onTap: active,

      onDisabled: ElStyle(
        cursor: SystemMouseCursors.forbidden,
        color: context.elTheme.textPlaceholder,
        backgroundColor: bgColor,
        border: _border(context, color: borderColor),
        iconColor: context.elTheme.textPlaceholder,
      ),
      iconColor: textColor,
    );
  }

  /// 构建主题按钮样式
  ElStyle _themeStyle(BuildContext context, ElStyle base, Color typeColor) {
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
    return base.copyWith(
      color: textColor,
      backgroundColor: typeColor,
      border: _border(context, color: typeColor),
      onHover: ElStyle(
        color: textColor,
        backgroundColor: hoverBg,
        border: _border(context, color: hoverBg),
        iconColor: textColor,
      ),
      onTap: active,

      onDisabled: ElStyle(
        cursor: SystemMouseCursors.forbidden,
        color: const Color(0xffffffff),
        backgroundColor: typeColor.elLight5(context),
        border: _border(context, color: typeColor.elLight5(context)),
        iconColor: const Color(0xffffffff),
      ),
      iconColor: textColor,
    );
  }

  /// 构建朴素按钮（浅底描边，hover 反转为实心）
  ElStyle _plainStyle(BuildContext context, ElStyle base, Color typeColor) {
    final dark2 = typeColor.elLightOf(.dark, 2);
    // 转为实心后按基础主题色取对比文字，避免交互变色时文字明暗跳变。
    final textColor = _textOnBackground(context, typeColor);
    final active = ElStyle(
      color: textColor,
      backgroundColor: dark2,
      border: _border(context, color: dark2),
      iconColor: textColor,
    );
    return base.copyWith(
      color: typeColor,
      backgroundColor: typeColor.elLight9(context),
      border: _border(context, color: typeColor.elLight5(context)),
      onHover: ElStyle(
        color: textColor,
        backgroundColor: typeColor,
        border: _border(context, color: typeColor),
        iconColor: textColor,
      ),
      onTap: active,

      onDisabled: ElStyle(
        cursor: SystemMouseCursors.forbidden,
        color: typeColor.elLight5(context),
        backgroundColor: typeColor.elLight9(context),
        border: _border(context, color: typeColor.elLight8(context)),
        iconColor: typeColor.elLight5(context),
      ),
      iconColor: typeColor,
    );
  }

  /// 构建文本按钮样式，透明背景，悬停加深
  ElStyle _textStyle(BuildContext context, ElStyle base, Color? typeColor) {
    final textColor = typeColor ?? context.elTheme.textRegular;
    // 交互底从 $bgColor 加深派生：按背景明暗调整 elLight 反转值，恒走 _darken
    // 方向（亮底 reverse 混深灰、暗底走暗色分支混深灰）；hover 3 级、active 6 级
    final background = context.elTheme.bgColor;
    final activeColor = background.elLight1(context, reverse: true);
    final active = ElStyle(color: textColor, backgroundColor: activeColor, iconColor: textColor);
    return base.copyWith(
      color: textColor,
      backgroundColor: null,
      onHover: active,
      onTap: null,

      onDisabled: ElStyle(
        cursor: SystemMouseCursors.forbidden,
        color: typeColor?.elLight5(context) ?? context.elTheme.textPlaceholder,
        backgroundColor: const Color(0x00000000),
        iconColor: typeColor?.elLight5(context) ?? context.elTheme.textPlaceholder,
      ),
      iconColor: textColor,
    );
  }

  /// 构建链接按钮样式，纯文本
  ElStyle _linkStyle(BuildContext context, ElStyle base, Color? typeColor) {
    final textColor = typeColor ?? context.elTheme.textRegular;
    final active = ElStyle(
      color: typeColor != null ? typeColor.elLightOf(.dark, 2) : textColor,
      iconColor: typeColor != null ? typeColor.elLightOf(.dark, 2) : textColor,
    );
    return base.copyWith(
      color: textColor,
      onHover: ElStyle(
        color: typeColor?.elLightOf(.light, 5) ?? context.elTheme.textSecondary,
        iconColor: typeColor?.elLightOf(.light, 5) ?? context.elTheme.textSecondary,
      ),
      onTap: active,

      onDisabled: ElStyle(
        cursor: SystemMouseCursors.forbidden,
        color: typeColor?.elLight5(context) ?? context.elTheme.textPlaceholder,
        iconColor: typeColor?.elLight5(context) ?? context.elTheme.textPlaceholder,
      ),
      iconColor: textColor,
    );
  }

  /// 构建聚焦环样式
  ElStyle _focusRingStyle(BuildContext context, Color? typeColor) {
    final ringColor = typeColor ?? context.elTheme.primary;
    return ElStyle(outline: ElOutline(outlineWidth: 2, outlineColor: ringColor, outlineOffset: 1));
  }

  /// 构建 loading 小部件
  Widget _loadingWidget() => ElLoading(child: _iconWidget(ElDesktopIcons.loading));

  /// 构建图标小部件
  Widget _iconWidget(Object? icon) => icon is IconData ? ElIcon(icon) : _dynamicWidget(icon);

  /// 构建动态类型小部件
  Widget _dynamicWidget(Object? value) {
    final content = elContent(value);
    return content is Widget ? content : ElView(child: content);
  }

  /// 组装按钮内容
  Widget _buttonContent(BuildContext context) {
    if (_isIcon) {
      if (loading) return _loadingWidget();
      return _iconWidget(child);
    }
    if (!loading && icon == null) {
      return _dynamicWidget(child);
    }
    final leftWidget = loading
        ? _loadingWidget()
        : icon == null
        ? null
        : _iconWidget(icon);
    return Row(
      mainAxisSize: .min,
      mainAxisAlignment: .center,
      crossAxisAlignment: .center,
      children: [
        ?leftWidget,
        if (leftWidget != null && child != null) ElView(style: const ElStyle(width: 6)),
        if (child != null) _dynamicWidget(child),
      ],
    );
  }
}

ElBorder _border(BuildContext context, {required Color color}) =>
    .all(borderColor: color, borderWidth: context.elTheme.borderWidth);
