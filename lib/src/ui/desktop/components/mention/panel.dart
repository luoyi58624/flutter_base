part of 'index.dart';

Duration get _mentionPanelExitDuration => const Duration(milliseconds: 90);

double _mentionOptionHeight(bool compact) => elInputControlHeight(compact);

ElStyle _mentionPanelBaseStyle(BuildContext context) => ElStyle(
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

ElStyle _mentionOptionBaseStyle(BuildContext context, bool isSelected) =>
    ElStyle(
      width: '100%',
      padding: .symmetric(horizontal: 12),
      alignment: .centerLeft,
      cursor: SystemMouseCursors.click,
      userSelect: .none,
      onHover: (isSelected) ? null : (ElStyle(backgroundColor: context.elTheme.overlayColorLighter)),
    ).merge(
      (isSelected)
          ? (ElStyle(
              backgroundColor: context.elTheme.overlayColorLight,
              color: context.elTheme.primary,
              iconColor: context.elTheme.primary,
            ))
          : null,
    );

ElStyle _mentionDisabledOptionStyle(BuildContext context) => ElStyle(
  color: context.elTheme.textPlaceholder,
  cursor: SystemMouseCursors.basic,
  onHover: ElStyle(backgroundColor: Color(0x00000000)),
  iconColor: context.elTheme.textPlaceholder,
);

class _MentionPanel<T> extends StatelessWidget {
  const _MentionPanel({
    required this.suggestions,
    required this.loading,
    required this.activeIndex,
    required this.maxHeight,
    required this.width,
    required this.showArrow,
    required this.placement,
    required this.scrollController,
    required this.compact,
    required this.panelStyle,
    required this.optionStyle,
    required this.itemBuilder,
    required this.header,
    required this.footer,
    required this.loadingBuilder,
    required this.emptyBuilder,
    required this.onOptionPointerDown,
    required this.onOptionPointerEnd,
    required this.onSelected,
  });

  final List<_ResolvedMentionOption<T>> suggestions;
  final bool loading;
  final int? activeIndex;
  final double maxHeight;
  final double width;
  final bool showArrow;
  final ElMentionPlacement placement;
  final ScrollController scrollController;
  final bool compact;
  final ElStyle? panelStyle;
  final ElStyle? optionStyle;
  final Widget Function(BuildContext context, ElMentionOption<T> option, bool active)? itemBuilder;
  final Widget? header;
  final Widget? footer;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? emptyBuilder;
  final VoidCallback onOptionPointerDown;
  final VoidCallback onOptionPointerEnd;
  final ValueChanged<_ResolvedMentionOption<T>> onSelected;

  @override
  Widget build(BuildContext context) {
    final phase = ElPortal.phaseOf(context);
    final geometry = ElPortal.geometryOf(context);
    final exiting = phase == ElPortalPhase.exiting;
    var style = _mentionPanelBaseStyle(context).merge(
      ElStyle(width: width, maxHeight: maxHeight, opacity: exiting ? 0 : 1, transform: .translateY(exiting ? -4 : 0)),
    );
    if (panelStyle != null) style = style.merge(panelStyle);
    final optionHeight = _mentionOptionHeight(compact);

    final list = buildListScroll(controller: scrollController, children: _children(context, optionHeight));
    final content = header == null && footer == null
        ? list
        : Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              ?header,
              Flexible(child: list),
              ?footer,
            ],
          );
    final panel = ElView(
      key: const ValueKey<String>('el-mention-panel'),
      style: style,
      semantics: ElSemantics(container: true, explicitChildNodes: true),
      child: content,
    );
    if (!showArrow) return panel;

    final actualSide =
        geometry?.placement.side ?? (placement == ElMentionPlacement.top ? AxisDirection.up : AxisDirection.down);
    final arrowTarget = geometry?.arrowTarget ?? Offset(width / 2, actualSide == AxisDirection.up ? maxHeight : 0);
    final arrowLeft = (arrowTarget.dx - 4).clamp(0, math.max(0, width - 8)).toDouble();
    final arrowTop = actualSide == AxisDirection.up ? null : -4.0;
    final arrowBottom = actualSide == AxisDirection.up ? -4.0 : null;
    return ElStack(
      clipBehavior: Clip.none,
      children: [
        panel,
        ElPositioned(
          left: arrowLeft,
          top: arrowTop,
          bottom: arrowBottom,
          width: 8,
          height: 8,
          zIndex: 1,
          child: ElView(
            key: const ValueKey<String>('el-mention-arrow'),
            style: ElStyle(
              backgroundColor: context.elTheme.cardColor,
              border: ElBorder.all(borderColor: context.elTheme.borderColor),
              transform: ElTransform.rotate(0.7853981633974483),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _children(BuildContext context, double optionHeight) {
    if (loading) {
      return [_MentionMessage(height: optionHeight, child: loadingBuilder?.call(context) ?? '加载中…')];
    }
    if (suggestions.isEmpty) {
      return [_MentionMessage(height: optionHeight, child: emptyBuilder?.call(context) ?? '暂无匹配')];
    }
    return [
      for (var index = 0; index < suggestions.length; index++)
        _MentionOption<T>(
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

class _MentionMessage extends StatelessWidget {
  const _MentionMessage({required this.height, required this.child});

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

class _MentionOption<T> extends StatelessWidget {
  const _MentionOption({
    required this.suggestion,
    required this.active,
    required this.height,
    required this.style,
    required this.itemBuilder,
    required this.onPointerDown,
    required this.onPointerEnd,
    required this.onSelected,
  });

  final _ResolvedMentionOption<T> suggestion;
  final bool active;
  final double height;
  final ElStyle? style;
  final Widget Function(BuildContext context, ElMentionOption<T> option, bool active)? itemBuilder;
  final VoidCallback onPointerDown;
  final VoidCallback onPointerEnd;
  final ValueChanged<_ResolvedMentionOption<T>> onSelected;

  @override
  Widget build(BuildContext context) {
    final disabled = suggestion.source.disabled;
    var resolvedStyle = _mentionOptionBaseStyle(context, active).merge(ElStyle(height: height));
    if (disabled) {
      resolvedStyle = resolvedStyle.merge(_mentionDisabledOptionStyle(context));
    }
    if (style != null) resolvedStyle = resolvedStyle.merge(style);
    void select() {
      if (!disabled) onSelected(suggestion);
    }

    return ElView(
      key: ValueKey<(String, int)>(('el-mention-option', suggestion.index)),

      style: resolvedStyle,
      event: ElEvent(
        disabled: disabled,
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
        enabled: !disabled,
        selected: active,
        onTap: disabled ? null : select,
      ),
      child: itemBuilder?.call(context, suggestion.source, active) ?? suggestion.label,
    );
  }
}
