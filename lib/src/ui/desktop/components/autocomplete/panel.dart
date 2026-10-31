part of 'index.dart';

Duration get _autocompletePanelExitDuration => const Duration(milliseconds: 90);

List<double> get _autocompleteOptionHeights => const [28, 32, 36, 40, 44];

ElStyle _autocompletePanelBaseStyle(BuildContext context) => ElStyle(
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

ElStyle _autocompleteOptionBaseStyle(BuildContext context, bool isSelected) =>
    ElStyle(
      width: '100%',
      padding: .symmetric(horizontal: 12),
      alignment: .centerLeft,
      cursor: SystemMouseCursors.click,
      userSelect: .none,
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

class _AutocompletePanel<T> extends StatelessWidget {
  const _AutocompletePanel({
    required this.semanticsIdentifier,
    required this.suggestions,
    required this.loading,
    required this.error,
    required this.activeIndex,
    required this.maxHeight,
    required this.scrollController,
    required this.size,
    required this.panelStyle,
    required this.optionStyle,
    required this.itemBuilder,
    required this.header,
    required this.footer,
    required this.loadingBuilder,
    required this.emptyBuilder,
    required this.errorBuilder,
    required this.onOptionPointerDown,
    required this.onOptionPointerEnd,
    required this.onSelected,
  });

  final String semanticsIdentifier;
  final List<_ResolvedSuggestion<T>> suggestions;
  final bool loading;
  final Object? error;
  final int? activeIndex;
  final double maxHeight;
  final ScrollController scrollController;
  final ElLevelType size;
  final ElStyle? panelStyle;
  final ElStyle? optionStyle;
  final Widget Function(
    BuildContext context,
    ElLabelModel<T> suggestion,
    bool active,
  )?
  itemBuilder;
  final Widget? header;
  final Widget? footer;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final VoidCallback onOptionPointerDown;
  final VoidCallback onOptionPointerEnd;
  final ValueChanged<_ResolvedSuggestion<T>> onSelected;

  @override
  Widget build(BuildContext context) {
    final phase = ElPortal.phaseOf(context);
    final exiting = phase == ElPortalPhase.exiting;
    var style = _autocompletePanelBaseStyle(context).merge(
      ElStyle(
        maxHeight: maxHeight,
        opacity: exiting ? 0 : 1,
        transform: .translateY(exiting ? -4 : 0),
      ),
    );
    if (panelStyle != null) style = style.merge(panelStyle);
    final optionHeight = _autocompleteOptionHeights[size.index];

    final list = ElScrollView(
      controller: scrollController,
      shrinkWrap: true,
      crossAxisAlignment: .stretch,
      semanticsRole: SemanticsRole.list,
      children: _children(context, optionHeight),
    );
    return ElView(
      key: const ValueKey<String>('el-autocomplete-panel'),
      style: style,
      semantics: ElSemantics(
        container: true,
        explicitChildNodes: true,
        properties: SemanticsProperties(identifier: semanticsIdentifier),
      ),
      child: header == null && footer == null
          ? list
          : Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                ?header,
                Flexible(child: list),
                ?footer,
              ],
            ),
    );
  }

  List<Widget> _children(BuildContext context, double optionHeight) {
    if (loading) {
      return [
        _AutocompleteMessage(
          height: optionHeight,
          child: loadingBuilder?.call(context) ?? '加载中…',
        ),
      ];
    }
    if (error != null) {
      return [
        _AutocompleteMessage(
          height: optionHeight,
          child: errorBuilder?.call(context, error!) ?? '加载失败',
        ),
      ];
    }
    if (suggestions.isEmpty) {
      return [
        _AutocompleteMessage(
          height: optionHeight,
          child: emptyBuilder?.call(context) ?? '暂无匹配',
        ),
      ];
    }
    return [
      for (var index = 0; index < suggestions.length; index++)
        _AutocompleteOption<T>(
          suggestion: suggestions[index],
          active: index == activeIndex,
          height: optionHeight,
          style: optionStyle,
          itemBuilder: itemBuilder,
          onPointerDown: onOptionPointerDown,
          onPointerEnd: onOptionPointerEnd,
          onSelected: onSelected,
        ),
    ];
  }
}

class _AutocompleteMessage extends StatelessWidget {
  const _AutocompleteMessage({required this.height, required this.child});

  final double height;
  final Object child;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(
        height: height,
        padding: .symmetric(horizontal: 12),
        alignment: .centerLeft,
        color: context.elTheme.textPlaceholder,
        userSelect: .none,
        iconColor: context.elTheme.textPlaceholder,
      ),
      child: child,
    );
  }
}

class _AutocompleteOption<T> extends StatelessWidget {
  const _AutocompleteOption({
    required this.suggestion,
    required this.active,
    required this.height,
    required this.style,
    required this.itemBuilder,
    required this.onPointerDown,
    required this.onPointerEnd,
    required this.onSelected,
  });

  final _ResolvedSuggestion<T> suggestion;
  final bool active;
  final double height;
  final ElStyle? style;
  final Widget Function(
    BuildContext context,
    ElLabelModel<T> suggestion,
    bool active,
  )?
  itemBuilder;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerEnd;
  final ValueChanged<_ResolvedSuggestion<T>> onSelected;

  @override
  Widget build(BuildContext context) {
    var resolvedStyle = _autocompleteOptionBaseStyle(
      context,
      active,
    ).merge(ElStyle(height: height));
    if (style != null) resolvedStyle = resolvedStyle.merge(style);
    void select() => onSelected(suggestion);
    return ElView(
      key: ValueKey<(String, int)>((
        'el-autocomplete-option',
        suggestion.index,
      )),
      style: resolvedStyle,

      event: ElEvent(
        onPointerDown: (event) {
          event.preserveFocus();
          onPointerDown();
        },
        onPointerUp: (_) => onPointerEnd(),
        onPointerCancel: (_) => onPointerEnd(),
        onTap: (_) => select(),
      ),
      semantics: ElSemantics(
        label: suggestion.label,
        role: SemanticsRole.listItem,
        enabled: true,
        selected: active,
        onTap: select,
      ),
      child:
          itemBuilder?.call(context, suggestion.source, active) ??
          suggestion.label,
    );
  }
}
