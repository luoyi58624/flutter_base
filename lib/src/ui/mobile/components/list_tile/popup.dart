part of 'index.dart';

List<ElLabelModel<T>> _menuChildren<T>(ElLabelModel<T> option) =>
    option is ElMenuOption<T> ? option.children : const [];
bool _menuDisabled<T>(ElLabelModel<T> option) => option is ElMenuOption<T> && option.disabled;
Object? _menuDescription<T>(ElLabelModel<T> option) => option is ElMenuOption<T> ? option.description : null;
Object? _menuLeading<T>(ElLabelModel<T> option) => option is ElMenuOption<T> ? option.leading : null;
bool _menuSelected<T>(ElLabelModel<T> option, T value) =>
    option.value == value || _menuChildren(option).any((child) => _menuSelected(child, value));

String? _selectedLabel<T>(List<ElLabelModel<T>> options, T value) {
  for (final option in options) {
    final nested = _selectedLabel(_menuChildren(option), value);
    if (nested != null) return nested;
    if (option.value == value) return option.label;
  }
  return null;
}

class _MenuEntry<T> {
  _MenuEntry(this.option);
  ElLabelModel<T> option;
  final key = GlobalKey();
  final focus = FocusNode();
  void dispose() => focus.dispose();
}

// 每层只保留自己的滚动、焦点和几何，返回时不重建父列表。
class _MenuLevel<T> {
  _MenuLevel(List<ElLabelModel<T>> options, this.parent, TickerProvider ticker, this.sourceTop)
    : enter = AnimationController(vsync: ticker, duration: const Duration(milliseconds: 260)),
      cover = AnimationController(vsync: ticker, duration: const Duration(milliseconds: 220)),
      leave = AnimationController(vsync: ticker, duration: const Duration(milliseconds: 200)) {
    update(options);
  }
  ElLabelModel<T>? parent;
  final key = GlobalKey();
  final headerKey = GlobalKey();
  final scroll = ScrollController();
  final backFocus = FocusNode();
  final AnimationController enter;
  final AnimationController cover;
  final AnimationController leave;
  List<_MenuEntry<T>> entries = [];
  double sourceTop;
  double top = 0;
  double? height;
  double headerHeight = 54;
  bool retiring = false;

  void update(List<ElLabelModel<T>> options) {
    final previous = {for (final entry in entries) entry.option.value: entry};
    entries = [for (final option in options) (previous.remove(option.value) ?? _MenuEntry(option))..option = option];
    for (final entry in previous.values) {
      entry.dispose();
    }
  }

  void dispose() {
    scroll.dispose();
    backFocus.dispose();
    enter.dispose();
    cover.dispose();
    leave.dispose();
    for (final entry in entries) {
      entry.dispose();
    }
  }
}

class _PopupPanel<T> extends StatefulWidget {
  const _PopupPanel({super.key, required this.component, required this.close, required this.onChoose});
  final ElListTile<T> component;
  final VoidCallback close;
  final ValueChanged<ElLabelModel<T>> onChoose;
  @override
  State<_PopupPanel<T>> createState() => _PopupPanelState<T>();
}

class _PopupPanelState<T> extends State<_PopupPanel<T>> with TickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final _fallbackFocus = FocusNode();
  final List<_MenuLevel<T>> _levels = [];
  final List<_MenuLevel<T>> _retiring = [];
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _leave = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  Timer? _searchTimer;
  String _search = '';
  bool _started = false;
  bool _closing = false;
  bool _focusPending = true;
  double _frozenScale = 1;
  double _frozenOpacity = 1;
  Offset? _frozenOrigin;

  @override
  void initState() {
    super.initState();
    final root = _MenuLevel<T>(widget.component.options, null, this, 0);
    root.enter.value = 1;
    _levels.add(root);
  }

  @override
  void didUpdateWidget(_PopupPanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_closing) return;
    _levels.first.update(widget.component.options);
    for (var i = 1; i < _levels.length; i++) {
      final parent = _levels[i - 1], level = _levels[i];
      final matches = parent.entries.where((entry) => entry.option.value == level.parent?.value);
      if (matches.isEmpty || _menuDisabled(matches.first.option) || _menuChildren(matches.first.option).isEmpty) {
        for (final removed in _levels.sublist(i)) {
          removed.dispose();
        }
        _levels.removeRange(i, _levels.length);
        _levels.last.cover.value = 0;
        for (final retired in _retiring) {
          retired.dispose();
        }
        _retiring.clear();
        _focusPending = true;
        break;
      }
      level.parent = matches.first.option;
      level.update(_menuChildren(matches.first.option));
    }
    final current = FocusManager.instance.primaryFocus;
    if (!_levels.last.entries.any((entry) => entry.focus == current && !_menuDisabled(entry.option)) &&
        current != _levels.last.backFocus) {
      _focusPending = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = reducedMotion(context);
    if (!_started) {
      _started = true;
      if (reduced) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
    if (ElPortal.phaseOf(context) == .exiting && !_closing) {
      _closing = true;
      _enter.stop();
      _frozenScale = _curve(_enter.value);
      _frozenOpacity = Curves.ease.transform((_enter.value * 260 / 190).clamp(0, 1));
      _frozenOrigin = _originFor(ElPortal.geometryOf(context));
      for (final level in [..._levels, ..._retiring]) {
        level.enter.stop();
        level.cover.stop();
        level.leave.stop();
      }
      if (reduced) {
        _leave.value = 1;
      } else {
        _leave.forward();
      }
    }
  }

  double _curve(double value) => const Cubic(.18, .79, .22, 1).transform(value);

  Offset? _originFor(ElOverlayAnchorGeometry? geometry) {
    if (geometry == null) return null;
    if (geometry.anchorRect.size != Size.zero) return geometry.arrowTarget;
    final point = geometry.anchorRect.center - geometry.overlayRect.topLeft;
    return Offset(point.dx.clamp(0, geometry.overlayRect.width), point.dy.clamp(0, geometry.overlayRect.height));
  }

  void _focus(_MenuLevel<T> level, _MenuEntry<T> entry) {
    if (_closing || !_levels.contains(level) || !level.entries.contains(entry) || _menuDisabled(entry.option)) return;
    entry.focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = entry.key.currentContext;
      if (mounted && !_closing && _levels.contains(level) && level.entries.contains(entry) && target != null) {
        final scrollable = Scrollable.maybeOf(target);
        final viewport = scrollable?.context.findRenderObject();
        final row = target.findRenderObject();
        if (scrollable == null || viewport is! RenderBox || row is! RenderBox) return;
        final top = row.localToGlobal(Offset.zero, ancestor: viewport).dy;
        if (top >= 0 && top + row.size.height <= viewport.size.height) return;
        // 只滚当前菜单层，已完整可见的原行不移动，也不滚动触发行的祖先页面。
        scrollable.position.ensureVisible(
          row,
          alignmentPolicy: top < 0
              ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
              : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _focusInitial(_MenuLevel<T> level) {
    final available = level.entries.where((entry) => !_menuDisabled(entry.option));
    if (available.isEmpty) {
      (level.parent != null ? level.backFocus : _fallbackFocus).requestFocus();
      return;
    }
    final selected = available.where((entry) => _menuSelected(entry.option, widget.component.currentValue));
    _focus(level, selected.isEmpty ? available.first : selected.first);
  }

  void _open(_MenuLevel<T> parent, _MenuEntry<T> entry) {
    if (_closing || _menuDisabled(entry.option)) return;
    final options = _menuChildren(entry.option);
    if (options.isEmpty) {
      widget.onChoose(entry.option);
      return;
    }
    final index = _levels.indexOf(parent);
    if (index < 0) return;
    if (_levels.length > index + 1) _returnTo(index);
    var top = parent.top;
    final stack = _stackKey.currentContext?.findRenderObject(), row = entry.key.currentContext?.findRenderObject();
    if (stack is RenderBox && row is RenderBox && row.attached) {
      top = row.localToGlobal(Offset.zero, ancestor: stack).dy;
    }
    final level = _MenuLevel<T>(options, entry.option, this, top);
    final reduced = reducedMotion(context);
    if (reduced) level.enter.value = 1;
    reduced ? parent.cover.value = 1 : parent.cover.forward();
    setState(() {
      _levels.add(level);
      _focusPending = true;
    });
    if (!reduced) level.enter.forward();
  }

  void _returnTo(int index) {
    if (_closing || index < 0 || index >= _levels.length - 1) return;
    final returning = _levels[index + 1].parent?.value;
    final removed = _levels.sublist(index + 1);
    setState(() {
      _levels.removeRange(index + 1, _levels.length);
      for (final level in removed) {
        level.retiring = true;
        level.enter.stop();
        _retiring.add(level);
      }
    });
    for (final level in removed) {
      if (reducedMotion(context)) {
        _retiring.remove(level);
        level.dispose();
      } else {
        level.leave.forward().whenComplete(() {
          if (!mounted || _closing || !_retiring.remove(level)) return;
          setState(level.dispose);
        });
      }
    }
    final parent = _levels.last;
    reducedMotion(context) ? parent.cover.value = 0 : parent.cover.reverse();
    final entry = parent.entries.where((entry) => entry.option.value == returning && !_menuDisabled(entry.option));
    if (entry.isNotEmpty) {
      final original = entry.first;
      // 父层本帧仍在 ExcludeFocus 中，待恢复可交互后再归还原行焦点。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_closing) _focus(parent, original);
      });
    }
  }

  void _back() => _levels.length > 1 ? _returnTo(_levels.length - 2) : widget.close();

  void _key(ElEventDetails event, _MenuLevel<T> level, _MenuEntry<T>? entry) {
    if (_closing || level != _levels.last) return;
    final key = event.logicalKey, keyboard = HardwareKeyboard.instance;
    final available = level.entries.where((entry) => !_menuDisabled(entry.option)).toList();
    final current = available.indexWhere((item) => item.focus.hasPrimaryFocus);
    void handled() {
      event.preventDefault();
      event.stopPropagation();
    }

    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.arrowLeft) {
      handled();
      _back();
    } else if (key == LogicalKeyboardKey.tab) {
      handled();
      final nodes = [if (level.parent != null) level.backFocus, for (final item in available) item.focus];
      if (nodes.isEmpty) return;
      final focused = nodes.indexWhere((node) => node.hasPrimaryFocus);
      final next = nodes[(focused + (keyboard.isShiftPressed ? -1 : 1) + nodes.length) % nodes.length];
      final matching = available.where((item) => item.focus == next);
      if (matching.isEmpty) {
        next.requestFocus();
      } else {
        _focus(level, matching.first);
      }
    } else if ([
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
    ].contains(key)) {
      handled();
      if (available.isEmpty) return;
      final index = key == LogicalKeyboardKey.home
          ? 0
          : key == LogicalKeyboardKey.end
          ? available.length - 1
          : (current + (key == LogicalKeyboardKey.arrowDown ? 1 : -1) + available.length) % available.length;
      _focus(level, available[index]);
    } else if ([
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.arrowRight,
    ].contains(key)) {
      handled();
      if (event.originalEvent is KeyRepeatEvent) return;
      if (entry == null) {
        if (key != LogicalKeyboardKey.arrowRight) _back();
      } else if (key != LogicalKeyboardKey.arrowRight || _menuChildren(entry.option).isNotEmpty) {
        _open(level, entry);
      }
    } else if (!keyboard.isControlPressed && !keyboard.isAltPressed && !keyboard.isMetaPressed) {
      final original = event.originalEvent;
      final character = original is KeyEvent ? original.character : null;
      if (character == null || character.runes.length != 1) return;
      final lower = character.toLowerCase();
      _searchTimer?.cancel();
      _search = _search == lower ? lower : _search + lower;
      _searchTimer = Timer(const Duration(milliseconds: 500), () => _search = '');
      final ordered = [...available.skip(current + 1), ...available.take(current + 1)];
      final matching = ordered.where((entry) => (entry.option.label ?? '').toLowerCase().startsWith(_search));
      if (matching.isNotEmpty) {
        handled();
        _focus(level, matching.first);
      }
    }
  }

  Widget _row(_MenuLevel<T> level, _MenuEntry<T>? entry, {bool divider = false}) {
    final option = entry?.option ?? level.parent!;
    final disabled = _menuDisabled(option), children = _menuChildren(option);
    final selected = _menuSelected(option, widget.component.currentValue);
    final theme = context.elTheme, leading = _menuLeading(option), description = _menuDescription(option);
    final back = entry == null;
    final focus = entry?.focus ?? level.backFocus;
    void activate() {
      if (back) {
        _back();
      } else {
        _open(level, entry);
      }
    }

    Widget row = ElView(
      key: entry?.key ?? level.headerKey,
      focusNode: focus,
      event: ElButtonView.buildEvent(
        activate,
        disabled,
        ElEvent(onKeyDown: (event) => _key(event, level, entry), onKeyRepeat: (event) => _key(event, level, entry)),
      ),
      semantics: ElSemantics(
        mergeDescendants: true,
        properties: SemanticsProperties(
          label: back ? '返回：${option.label ?? ''}' : null,
          button: true,
          enabled: !disabled,
          selected: back ? null : selected,
          expanded: !back && children.isNotEmpty
              ? _levels.any((next) => next.parent != null && next.parent!.value == option.value)
              : null,
          onTap: disabled ? null : activate,
        ),
      ),
      style: ElStyle(
        width: '100%',
        heightFactor: 1,
        padding: const .symmetric(vertical: 16),
        color: selected ? theme.primary : theme.textColor,
        iconColor: selected ? theme.primary : theme.textColor,
        fontSize: 15,
        fontWeight: .w500,
        opacity: disabled ? .5 : 1,
        userSelect: .none,
        onTap: disabled ? null : ElStyle(backgroundColor: theme.press),
      ).merge(widget.component.optionStyle),
      child: Row(
        children: [
          if (leading == null)
            const SizedBox(width: 16)
          else
            SizedBox(width: 56, child: Center(child: _content(leading, 20))),
          Expanded(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                buildContent(option.label ?? ''),
                if (description != null)
                  ElView(
                    style: ElStyle(
                      fontSize: 14,
                      fontWeight: .w400,
                      color: theme.textSecondary,
                      padding: const .only(top: 4),
                    ),
                    child: description,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const .only(left: 12, right: 16),
            child: ExcludeSemantics(
              child: SizedBox(
                width: 17,
                height: 17,
                child: back
                    ? Icon(CupertinoIcons.chevron_back, size: 17, color: theme.primary)
                    : children.isNotEmpty
                    ? const Icon(CupertinoIcons.chevron_up_chevron_down, size: 17)
                    : Opacity(opacity: selected ? 1 : 0, child: const Icon(CupertinoIcons.check_mark, size: 17)),
              ),
            ),
          ),
        ],
      ),
    );
    if (!divider) return row;
    return Stack(
      children: [
        row,
        Positioned(
          left: leading == null ? 16 : 56,
          right: 16,
          bottom: 0,
          child: ColoredBox(color: theme.borderColor, child: const SizedBox(height: .5)),
        ),
      ],
    );
  }

  Widget _level(_MenuLevel<T> level, double maxHeight, bool active) {
    final theme = context.elTheme;
    final scrollHeader = level.parent != null && maxHeight < level.headerHeight;
    final body = ElView(
      key: level.key,
      style: ElStyle(
        width: '100%',
        heightFactor: 1,
        maxHeight: maxHeight,
        backgroundColor: theme.cardColor,
        borderRadius: .circular(17),
        clipBehavior: .hardEdge,
        boxShadow: theme.shadowLg,
      ).merge(widget.component.popupStyle),
      semantics: ElSemantics(container: true, label: level.parent?.label ?? widget.component.popupLabel),
      child: Column(
        mainAxisSize: .min,
        children: [
          if (level.parent != null && !scrollHeader)
            SizedBox(
              height: level.headerHeight.clamp(0.0, maxHeight),
              child: ClipRect(
                child: OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  alignment: .topLeft,
                  child: _row(level, null, divider: true),
                ),
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              controller: level.scroll,
              child: Column(
                mainAxisSize: .min,
                children: [
                  if (scrollHeader) _row(level, null, divider: true),
                  for (var i = 0; i < level.entries.length; i++)
                    Opacity(
                      opacity:
                          !active &&
                              _levels.any(
                                (child) => child.parent != null && child.parent!.value == level.entries[i].option.value,
                              )
                          ? 0
                          : 1,
                      child: _row(level, level.entries[i], divider: i < level.entries.length - 1),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (active && !level.retiring) return body;
    return ExcludeFocus(
      child: Stack(
        children: [
          ExcludeSemantics(child: IgnorePointer(child: body)),
          if (!level.retiring)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _returnTo(_levels.indexOf(level)),
                child: Semantics(label: '返回：${level.parent?.label ?? widget.component.popupLabel ?? ''}', button: true),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geometry = ElPortal.geometryOf(context);
    final origin = _closing ? _frozenOrigin : _originFor(geometry);
    if (_focusPending && !_closing) {
      _focusPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_closing) _focusInitial(_levels.last);
      });
    }
    return Focus(
      focusNode: _fallbackFocus,
      onKeyEvent: (node, event) {
        if (!node.hasPrimaryFocus || event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _back();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          _focusInitial(_levels.last);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wantedWidth = widget.component.popupStyle?.width;
          final width = (wantedWidth is num ? wantedWidth.toDouble() : 236.0).clamp(
            constraints.minWidth,
            constraints.maxWidth,
          );
          final maxHeight = (widget.component.popupMaxHeight ?? constraints.maxHeight).clamp(
            0.0,
            constraints.maxHeight,
          );
          // 深树优先给当前标题留空间，其余高度才作为各祖先的返回区域。
          final reserve = ((maxHeight - 84).clamp(0.0, maxHeight) / (_levels.length - 1).clamp(1, _levels.length))
              .clamp(0.0, 36.0);
          for (var i = 0; !_closing && i < _levels.length; i++) {
            final level = _levels[i];
            if (i == 0) {
              level.top = 0;
            } else {
              final minimum = _levels[i - 1].top + reserve;
              final estimated = level.height ?? (level.entries.length + 1) * 54.0;
              final maximum = (maxHeight - estimated).clamp(minimum, maxHeight);
              level.top = level.sourceTop.clamp(minimum, maximum);
            }
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _closing) return;
            var changed = false;
            for (final level in _levels) {
              final box = level.key.currentContext?.findRenderObject();
              final overflow = level.scroll.hasClients && level.scroll.position.hasContentDimensions
                  ? level.scroll.position.maxScrollExtent
                  : 0.0;
              // 被当前可用高度裁短的盒子不是真实内容高，须加回滚动范围再定位。
              if (box is RenderBox && level.height != box.size.height + overflow) {
                level.height = box.size.height + overflow;
                changed = true;
              }
              final header = level.headerKey.currentContext?.findRenderObject();
              if (header is RenderBox && level.headerHeight != header.size.height) {
                level.headerHeight = header.size.height;
                changed = true;
              }
            }
            if (changed) setState(() {});
          });
          return AnimatedBuilder(
            animation: Listenable.merge([
              _enter,
              _leave,
              for (final level in [..._levels, ..._retiring]) ...[level.enter, level.cover, level.leave],
            ]),
            builder: (context, _) {
              final scale = _closing ? _frozenScale : _curve(_enter.value);
              final opacity = _closing
                  ? _frozenOpacity * (1 - Curves.ease.transform(_leave.value))
                  : Curves.ease.transform((_enter.value * 260 / 190).clamp(0, 1));
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  alignment: .topLeft,
                  origin: origin,
                  child: SizedBox(
                    width: width,
                    child: Stack(
                      key: _stackKey,
                      children: [
                        for (final level in [..._levels, ..._retiring])
                          Padding(
                            padding: EdgeInsets.only(top: level.top),
                            child: Opacity(
                              opacity: 1 - level.leave.value,
                              child: Transform.translate(
                                offset: Offset(0, (level.sourceTop - level.top) * (1 - _curve(level.enter.value))),
                                child: Transform.scale(
                                  scale: _curve(level.enter.value),
                                  alignment: .topLeft,
                                  child: Transform.scale(
                                    scale: 1 - .06 * _curve(level.cover.value),
                                    alignment: .topCenter,
                                    child: IgnorePointer(
                                      ignoring: _closing || level.retiring,
                                      child: _level(
                                        level,
                                        (maxHeight - level.top).clamp(0.0, maxHeight),
                                        !level.retiring && level == _levels.last,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _fallbackFocus.dispose();
    _enter.dispose();
    _leave.dispose();
    for (final level in [..._levels, ..._retiring]) {
      level.dispose();
    }
    super.dispose();
  }
}
