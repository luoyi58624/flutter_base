part of 'index.dart';

Duration get _selectMenuExitDuration => const Duration(milliseconds: 90);

List<double> get _selectOptionHeights => const [28, 32, 36, 40, 44];

ElStyle _selectMenuBaseStyle(BuildContext context) => ElStyle(
  padding: .symmetric(vertical: 6),
  backgroundColor: context.elTheme.cardColor,
  color: context.elTheme.textRegular,
  border: .all(borderColor: null),
  borderRadius: .circular(context.elTheme.radiusSm),
  boxShadow: context.elTheme.shadowSm,
  opacity: 1,
  transform: .translateY(0),
  starting: ElStyle(opacity: 0, transform: .translateY(-4)),
  transition: [.all(Duration(milliseconds: 90), Curves.easeOutCubic)],
  iconColor: context.elTheme.textRegular,
);

ElStyle _selectOptionBaseStyle(BuildContext context, bool isSelected) =>
    ElStyle(
      width: '100%',
      padding: .symmetric(horizontal: 12),
      alignment: .centerLeft,
      cursor: SystemMouseCursors.click,
      userSelect: .none,
      onDisabled: ElStyle(
        color: context.elTheme.textPlaceholder,
        cursor: SystemMouseCursors.forbidden,
        iconColor: context.elTheme.textPlaceholder,
      ),
      onHover: (isSelected)
          ? null
          : (ElStyle(backgroundColor: context.elTheme.overlayColorLighter)),
    ).merge(
      (isSelected)
          ? (ElStyle(
              backgroundColor: context.elTheme.overlayColorLight,
              color: context.elTheme.primary,
              iconColor: context.elTheme.primary,
            ))
          : null,
    );

class _ElSelectPanel<T> extends StatelessWidget {
  const _ElSelectPanel({
    required this.semanticsIdentifier,
    required this.options,
    required this.activeIndex,
    required this.menuHeight,
    required this.scrollController,
    required this.size,
    required this.menuStyle,
    required this.optionStyle,
    required this.onOptionPointerDown,
    required this.onOptionPointerEnd,
    required this.onSelected,
  });

  final String semanticsIdentifier;
  final List<_ResolvedSelectOption<T>> options;
  final int? activeIndex;
  final double? menuHeight;
  final ScrollController scrollController;
  final ElLevelType size;
  final ElStyle? menuStyle;
  final ElStyle? optionStyle;
  final VoidCallback onOptionPointerDown;
  final VoidCallback onOptionPointerEnd;
  final ValueChanged<_ResolvedSelectOption<T>> onSelected;

  @override
  Widget build(BuildContext context) {
    final phase = ElPortal.phaseOf(context);
    final exiting = phase == ElPortalPhase.exiting;
    var style = _selectMenuBaseStyle(context).merge(
      ElStyle(
        maxHeight: menuHeight,
        opacity: exiting ? 0 : 1,
        transform: .translateY(exiting ? -4 : 0),
      ),
    );
    if (menuStyle != null) style = style.merge(menuStyle);
    final optionHeight = _selectOptionHeights[size.index];

    return ElView(
      key: const ValueKey<String>('el-select-panel'),
      style: style,
      // 禁用项和面板空白也属于候选层，点击时保留输入焦点以继续键盘导航。
      event: ElEvent(onPointerDown: (event) => event.preserveFocus()),
      semantics: ElSemantics(
        container: true,
        explicitChildNodes: true,
        properties: SemanticsProperties(identifier: semanticsIdentifier),
      ),
      child: ElScrollView(
        controller: scrollController,
        shrinkWrap: true,
        crossAxisAlignment: .stretch,
        semanticsRole: SemanticsRole.list,
        children: options.isEmpty
            ? [
                ElView(
                  style: ElStyle(
                    height: optionHeight,
                    padding: .symmetric(horizontal: 12),
                    alignment: .centerLeft,
                    color: context.elTheme.textPlaceholder,
                    userSelect: .none,
                    iconColor: context.elTheme.textPlaceholder,
                  ),
                  child: '暂无选项',
                ),
              ]
            : [
                for (final option in options)
                  _ElSelectOption(
                    option: option,
                    height: optionHeight,
                    active: option.index == activeIndex,
                    style: optionStyle,
                    onPointerDown: onOptionPointerDown,
                    onPointerEnd: onOptionPointerEnd,
                    onSelected: onSelected,
                  ),
              ],
      ),
    );
  }
}

class _ElSelectOption<T> extends StatelessWidget {
  const _ElSelectOption({
    required this.option,
    required this.height,
    required this.active,
    required this.style,
    required this.onPointerDown,
    required this.onPointerEnd,
    required this.onSelected,
  });

  final _ResolvedSelectOption<T> option;
  final double height;
  final bool active;
  final ElStyle? style;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerEnd;
  final ValueChanged<_ResolvedSelectOption<T>> onSelected;

  @override
  Widget build(BuildContext context) {
    var resolvedStyle = _selectOptionBaseStyle(
      context,
      active,
    ).merge(ElStyle(height: height));
    if (style != null) resolvedStyle = resolvedStyle.merge(style);
    void select() {
      if (!option.disabled) onSelected(option);
    }

    return ElView(
      key: ValueKey<(String, int)>(('el-select-option', option.index)),
      style: resolvedStyle,

      event: ElEvent(
        disabled: option.disabled,
        onTapDown: (_) => onPointerDown(),
        onPointerUp: (_) => onPointerEnd(),
        onPointerCancel: (_) => onPointerEnd(),
        onTap: (_) => select(),
      ),
      semantics: ElSemantics(
        label: option.label,
        role: SemanticsRole.listItem,
        enabled: !option.disabled,
        selected: active,
        onTap: option.disabled ? null : select,
      ),
      child: option.content,
    );
  }
}
