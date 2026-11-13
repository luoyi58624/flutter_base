import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoApp, CupertinoIcons;
import 'package:flutter/material.dart' show MaterialApp, Icons;
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../../dart.dart' show $absent;
import '../../../../dart/gen/index.dart' show $absent;
import '../../../../flutter/commons/models.dart' show ElLabelModel, ElLevelType;
import '../../../../flutter/components/tokens.dart' show ElLevelTypeExt, ElThemeContextExt;
import '../../../../flutter/widgets/icon/index.dart' show ElIcon;
import '../../../../flutter/components/list_tile/index.dart' show ElListGroup, ElListTile, ElMenuOption;
import '../../../../flutter/utils/model_value/index.dart' show ElModelValueType;
import '../../../../flutter/utils/util.dart' show ElFlutterUtil;
import '../../../../flutter/views/button/button_view.dart' show ElButtonView;
import '../../../../flutter/views/view/event/event.dart' show ElEvent, ElEventDetails, ElEventExt;
import '../../../../flutter/views/view/semantics/semantics.dart' show ElSemantics;
import '../../../../flutter/views/view/style/style.dart'
    show ElBorder, ElShadowStyleExt, ElStyle, ElTransform, ElTransition, ElTransitionField;
import '../../../../flutter/views/view/style/cascade/style_spec.dart' show hasFocusableVariantOf;
import '../../../../flutter/views/view/view.dart' show ElView;
import '../../../../flutter/widgets/others/base.dart' show ElChildIndex;
import '../../../../flutter/widgets/popup/anchor.dart' show ElOverlayAnchor, ElOverlayAnchorGeometry;
import '../../../../flutter/widgets/popup/portal.dart' show ElPortal, ElPortalController;
import '../../commons/icons.dart' show ElMobileIcons;
import '../../internal/common.dart';
import '../loading/index.dart';

part 'group.dart';
part 'popup.dart';

VoidCallback? _activePopup;

/// 沿用原列表行的布局，由公共组件持有值绑定。
Widget listTileBuilder<T>(BuildContext context, ElListTile<T> component) => _ListTile<T>(component);

class _ListTile<T> extends HookWidget {
  const _ListTile(
    this.component, {
    this.selectionMode,
    this.selected = false,
    this.selectionLeading = true,
    this.onSelect,
    super.key,
  });

  final ElListTile<T> component;
  final ElModelValueType? selectionMode;
  final bool selected;
  final bool selectionLeading;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = context.elTheme;
    final popupPadding = theme.popupListPadding;
    final inset = popupPadding == EdgeInsets.zero ? null : popupPadding;
    final index = ElChildIndex.maybeOf(context);
    final focusEnabled = component.focusNode != null || hasFocusableVariantOf(component.style);
    final ownFocus = useMemoized(() => focusEnabled && component.focusNode == null ? FocusNode() : null, [
      focusEnabled,
      component.focusNode,
    ]);
    useEffect(() => ownFocus?.dispose, [ownFocus]);
    final focus = component.focusNode ?? ownFocus;
    final portal = useMemoized(ElPortalController.new);
    useEffect(() => portal.dispose, [portal]);
    final opening = useRef(false);
    final closePopup = useMemoized(
      () => () {
        opening.value = false;
        portal.close();
      },
      [portal],
    );
    final menuKey = useMemoized(GlobalKey<_PopupPanelState<T>>.new);
    final pointer = useRef<Offset?>(null);
    final anchorPosition = useState<Offset?>(null);
    useListenable(portal);
    useEffect(
      () => () {
        opening.value = false;
        if (_activePopup == closePopup) _activePopup = null;
      },
      [closePopup],
    );
    final choosing = selectionMode != null;
    final radio = selectionMode == .single;
    final switcher = !choosing && component.type == .switcher;
    final popup = !choosing && component.type == .popup;
    final disabled = component.disabled || component.event?.disabled == true || (!choosing && component.loading);
    final registry = radio ? RadioGroup.maybeOf<Object?>(context) : null;
    final radioClient = useMemoized(() => focus == null ? null : _ListRadioClient(focus, component.value, !disabled), [
      focus,
      component.value,
      disabled,
    ]);
    useEffect(() {
      if (radio) radioClient?.registry = registry;
      return () => radioClient?.registry = null;
    }, [radio, radioClient, registry]);
    useEffect(() {
      if (disabled) {
        opening.value = false;
        if (portal.isOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) portal.close();
          });
        }
      }
      return null;
    }, [disabled]);

    void activate() {
      if (disabled) return;
      if (choosing) {
        onSelect?.call();
        component.onTap?.call();
      } else if (switcher) {
        component.currentValue = (!(component.currentValue as bool)) as T;
      } else if (popup) {
        if (Overlay.maybeOf(context) == null) return;
        if (portal.isOpen || opening.value) {
          opening.value = false;
          portal.close();
        } else if (component.options.isNotEmpty) {
          _activePopup?.call();
          _activePopup = closePopup;
          opening.value = true;
          anchorPosition.value = component.popupAnchor == null ? pointer.value : null;
          WidgetsBinding.instance.scheduleFrame();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && opening.value && !disabled) {
              opening.value = false;
              portal.open();
            }
          });
        }
      } else {
        component.onTap?.call();
      }
    }

    Object? leading = component.leading;
    Object? trailing = component.trailing;
    final defaultTrailing = identical(trailing, $absent);
    if (choosing) {
      final mark = _selectionMark(context, selected, selectionMode!, inPopup: inset != null);
      if (selectionLeading) leading ??= mark;
      if (defaultTrailing) trailing = selectionLeading ? null : mark;
    } else if (switcher) {
      trailing = _switchVisual(context, component.currentValue as bool, component.loading, component.switchStyle);
    } else if (defaultTrailing) {
      trailing = ElView(
        style: ElStyle(iconSize: inset == null ? 20 : 18, iconColor: theme.textSecondary),
        child: inset != null
            ? (popup ? ElMobileIcons.chevronsUpDown : ElMobileIcons.chevronRight)
            : popup
            ? (_cupertino(context) ? CupertinoIcons.chevron_up_chevron_down : Icons.unfold_more)
            : (_cupertino(context) ? CupertinoIcons.chevron_forward : Icons.chevron_right),
      );
    }
    var trailingText = component.trailingText;
    if (popup && trailingText == null) {
      trailingText = _selectedLabel(component.options, component.currentValue);
    }

    final original = component.event ?? const ElEvent();
    final base = original.copyWith(
      onTap: (event) {
        original.onTap?.call(event);
        pointer.value = event.originalEvent is PointerEvent ? event.globalPosition : null;
      },
    );
    final event = focusEnabled
        ? ElButtonView.buildEvent(activate, disabled, base, activateOnEnter: !switcher)
        : base.copyWith(
            disabled: disabled,
            onTap: (event) {
              base.onTap?.call(event);
              if (!event.defaultPrevented) activate();
            },
          );
    final style = ElStyle(
      width: '100%',
      heightFactor: 1,
      padding:
          inset?.copyWith(
            top: inset.top + (index?.isStart == true ? 2 : 0),
            bottom: inset.bottom + (index?.isEnd == true ? 2 : 0),
          ) ??
          const EdgeInsets.symmetric(vertical: 16),
      fontSize: 15,
      fontWeight: inset == null ? .w500 : textWeight(theme.fontWeightAction),
      lineHeight: inset == null ? null : 22 / 15,
      color: selected ? theme.primary : theme.textColor,
      iconColor: selected ? theme.primary : theme.textColor,
      opacity: disabled ? (inset == null ? .5 : .6) : 1,
      userSelect: .none,
      onTap: disabled
          ? null
          : ElStyle(
              backgroundColor: inset == null ? theme.cardPressColor : theme.press,
              transition: inset == null ? null : const [],
            ),
      transition: reducedMotion(context)
          ? const []
          : inset == null
          ? const [ElTransition.field(ElTransitionField.backgroundColor, Duration(milliseconds: 150))]
          : const [
              ElTransition.field(
                ElTransitionField.backgroundColor,
                Duration(milliseconds: 160),
                Cubic(.215, .61, .355, 1),
              ),
            ],
    ).merge(component.style);
    final contents = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (inset == null)
            leading == null
                ? const SizedBox(width: 16)
                : SizedBox(width: 56, child: Center(child: _content(leading, 24)))
          else if (leading != null) ...[
            SizedBox(
              width: choosing ? 22 : 20,
              child: Center(child: _content(leading, 18, inheritIcon: true)),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                buildContent(component.title),
                if (component.subtitle != null)
                  ElView(
                    style: ElStyle(
                      fontSize: 14,
                      fontWeight: .w400,
                      lineHeight: inset == null ? null : 20 / 14,
                      color: theme.textSecondary,
                      padding: const .only(top: 4),
                    ),
                    child: component.subtitle,
                  ),
              ],
            ),
          ),
          if (trailingText != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * .4),
              child: ElView(
                style: ElStyle(
                  fontSize: 14,
                  fontWeight: .w400,
                  color: theme.textSecondary,
                  textAlign: .end,
                  padding: const .only(left: 12),
                ),
                child: trailingText,
              ),
            ),
          if (trailing != null)
            Padding(padding: const .only(left: 12), child: _content(trailing, inset == null ? 20 : 18)),
          if (inset == null) const SizedBox(width: 16),
        ],
      ),
    );
    Widget row = ElView(
      focusNode: focus,
      event: event,
      style: style,
      semantics: ElSemantics(
        mergeDescendants: true,
        properties: SemanticsProperties(
          label: component.semanticLabel,
          button: choosing || switcher ? null : true,
          checked: choosing ? selected : null,
          inMutuallyExclusiveGroup: radio ? true : null,
          toggled: switcher ? component.currentValue as bool : null,
          enabled: !disabled,
          expanded: popup ? portal.isOpen && !disabled : null,
          onTap: ElButtonView.buildSemanticsTap(activate, base, disabled),
        ),
      ),
      child: component.semanticLabel == null ? contents : ExcludeSemantics(child: contents),
    );
    if (index != null && (inset == null ? !index.isEnd : !index.isStart)) {
      row = Stack(
        children: [
          row,
          Positioned(
            left: inset?.left ?? (leading == null ? 16 : 56),
            right: inset?.right ?? 16,
            top: inset == null ? null : 0,
            bottom: inset == null ? 0 : null,
            child: IgnorePointer(
              child: ElView(
                style: ElStyle(height: inset == null ? .5 : 1, backgroundColor: theme.dividerColor),
              ),
            ),
          ),
        ],
      );
    }
    if (!popup || Overlay.maybeOf(context) == null) return row;
    return ElPortal(
      controller: portal,
      anchor: component.popupAnchor ?? const ElOverlayAnchor(placement: .bottomStart, offset: 4),
      anchorPosition: anchorPosition.value,
      captureFocus: _menuHasFocus(component),
      restoreFocus: _menuHasFocus(component),
      closeOnBack: true,
      onBack: () {
        final menu = menuKey.currentState;
        menu == null ? closePopup() : menu._back();
      },
      closeOnEscape: false,
      closeOnOutsidePointerDown: true,
      closeOnScroll: anchorPosition.value != null,
      closeWhenUnlinked: true,
      exitDuration: reducedMotion(context) ? Duration.zero : const Duration(milliseconds: 200),
      onDismiss: closePopup,
      panel: _PopupPanel<T>(
        key: menuKey,
        component: component,
        close: closePopup,
        onChoose: (option) {
          if (component.closeOnSelect) portal.close();
          // 先让既有 Portal 终止交互并归还焦点，通知可安全地再次打开菜单。
          scheduleMicrotask(() {
            if (context.mounted && !disabled) component.currentValue = option.value as T;
          });
        },
      ),
      child: row,
    );
  }
}

// 只接入 Flutter 原生单选导航，焦点和绘制仍由同一个 ElView 持有。
class _ListRadioClient with RadioClient<Object?> {
  _ListRadioClient(this.focusNode, this.radioValue, this.enabled);

  @override
  final FocusNode focusNode;
  @override
  final Object? radioValue;
  @override
  final bool enabled;
  @override
  bool get tristate => false;
}

Widget _content(Object? value, double size, {bool inheritIcon = false}) => IgnorePointer(
  child: ExcludeFocus(
    child: inheritIcon || value is IconData || value is Icon
        ? ElView(
            style: ElStyle(iconSize: size),
            child: buildContent(value),
          )
        : buildContent(value),
  ),
);

bool _cupertino(BuildContext context) {
  final cupertino = ElFlutterUtil.getAncestorElement<CupertinoApp>(context);
  final material = ElFlutterUtil.getAncestorElement<MaterialApp>(context);
  return cupertino != null && (material == null || cupertino.depth > material.depth);
}

Widget _selectionMark(BuildContext context, bool selected, ElModelValueType mode, {required bool inPopup}) {
  final theme = context.elTheme;
  final radio = mode == .single;
  return ExcludeSemantics(
    child: ElView(
      style: ElStyle(
        width: 22,
        height: 22,
        alignment: .center,
        borderRadius: BorderRadius.circular(radio ? 99 : 6),
        border: ElBorder.all(
          borderWidth: selected && radio ? 6 : 1.5,
          borderColor: selected ? theme.primary : theme.textSecondary,
        ),
        backgroundColor: selected && !radio ? theme.primary : null,
        iconSize: inPopup ? 16 : null,
        iconColor: inPopup ? theme.primaryText : null,
      ),
      child: selected && !radio
          ? (inPopup ? ElMobileIcons.check : ElIcon(CupertinoIcons.check_mark, size: 16, color: theme.primaryText))
          : null,
    ),
  );
}

Widget _switchVisual(BuildContext context, bool on, bool loading, ElStyle? style) {
  final theme = context.elTheme;
  final height = style?.height is num ? (style!.height as num).toDouble() : 28.0;
  final width = style?.width is num ? (style!.width as num).toDouble() : height * 47 / 28;
  final gap = height * 3 / 28;
  final thumb = height - 2 * gap;
  return ExcludeSemantics(
    child: ElView(
      style: ElStyle(
        width: width,
        height: height,
        padding: EdgeInsets.all(gap),
        alignment: .centerLeft,
        borderRadius: BorderRadius.circular(99),
        backgroundColor: on ? theme.primary : theme.gray,
      ).merge(style),
      child: ElView(
        style: ElStyle(
          width: thumb,
          height: thumb,
          alignment: .center,
          borderRadius: BorderRadius.circular(99),
          backgroundColor: theme.white,
          color: theme.primary,
          transform: ElTransform.translate(on ? width - height : 0, 0),
          boxShadow: const [BoxShadow(color: Color(0x1f000000), offset: Offset(0, 2), blurRadius: 5)],
          transition: reducedMotion(context)
              ? const []
              : const [ElTransition.field(ElTransitionField.transform, Duration(milliseconds: 230))],
        ),
        child: loading ? const Loading(size: LoadingSize.small) : null,
      ),
    ),
  );
}
