import 'package:flutter/cupertino.dart' show CupertinoApp, CupertinoIcons;
import 'package:flutter/material.dart' show MaterialApp, Icons;
import 'package:flutter/semantics.dart' show SemanticsProperties;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_base/ui.dart';

import '../../cores/common.dart';
import '../loading/index.dart';

part 'group.dart';
part 'popup.dart';

/// 沿用原列表行的布局，由公共组件持有值绑定。
Widget myListTileBuilder<T>(BuildContext context, ElListTile<T> component) => _ListTile<T>(component);

class _ListTile<T> extends HookWidget {
  const _ListTile(
    this.component, {
    this.selectionMode,
    this.selected = false,
    this.selectionLeading = true,
    this.onSelect,
    this.autofocus = false,
    super.key,
  });

  final ElListTile<T> component;
  final ElModelValueType? selectionMode;
  final bool selected;
  final bool selectionLeading;
  final VoidCallback? onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = context.elTheme;
    final ownFocus = useFocusNode();
    final focus = component.focusNode ?? ownFocus;
    final open = useState(false);
    final press = useMemoized(ElButtonViewPressController.new);
    useEffect(() => press.dispose, [press]);
    useListenable(press);
    final choosing = selectionMode != null;
    final radio = selectionMode == .single;
    final switcher = !choosing && component.type == .switcher;
    final popup = !choosing && component.type == .popup;
    final disabled = component.disabled || component.event?.disabled == true || (!choosing && component.loading);
    final registry = radio ? RadioGroup.maybeOf<Object?>(context) : null;
    final radioClient = useMemoized(() => _ListRadioClient(focus, component.value, !disabled), [
      focus,
      component.value,
      disabled,
    ]);
    useEffect(() {
      if (radio) radioClient.registry = registry;
      return () => radioClient.registry = null;
    }, [radio, radioClient, registry]);
    useEffect(() {
      if (autofocus && !disabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) focus.requestFocus();
        });
      }
      return null;
    }, [autofocus, focus, disabled]);
    useEffect(() {
      if (disabled && open.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) open.value = false;
        });
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
        if (Overlay.maybeOf(context) != null) open.value = !open.value;
      } else {
        component.onTap?.call();
      }
    }

    Object? leading = component.leading;
    Object? trailing = component.trailing;
    final defaultTrailing = identical(trailing, ElEmptyWidget.instance);
    if (choosing) {
      final mark = _selectionMark(context, selected, selectionMode!);
      if (selectionLeading) leading ??= mark;
      if (defaultTrailing) trailing = selectionLeading ? null : mark;
    } else if (switcher) {
      trailing = _switchVisual(context, component.currentValue as bool, component.loading, component.switchStyle);
    } else if (defaultTrailing) {
      trailing = Icon(
        popup
            ? (_cupertino(context) ? CupertinoIcons.chevron_up_chevron_down : Icons.unfold_more)
            : (_cupertino(context) ? CupertinoIcons.chevron_forward : Icons.chevron_right),
        size: 20,
        color: theme.textSecondary,
      );
    }
    var trailingText = component.trailingText;
    if (popup && trailingText == null) {
      for (final option in component.options) {
        if (option.value == component.currentValue) {
          trailingText = option.label;
          break;
        }
      }
    }

    final base = component.event ?? const ElEvent();
    final event = ElButtonView.buildEvent(activate, disabled, base, pressController: press, activateOnEnter: !switcher);
    var style = ElStyle(
      width: '100%',
      heightFactor: 1,
      padding: const EdgeInsets.symmetric(vertical: 16),
      fontSize: 15,
      fontWeight: .w500,
      color: selected ? theme.primary : theme.textColor,
      iconColor: selected ? theme.primary : theme.textColor,
      opacity: disabled ? .5 : 1,
      userSelect: .none,
      onTap: disabled ? null : ElStyle(backgroundColor: theme.press),
      transition: myReducedMotion(context)
          ? const []
          : const [ElTransition.field(ElTransitionField.backgroundColor, Duration(milliseconds: 150))],
    ).merge(component.style);
    if (press.pressed && !disabled) style = style.merge(style.onTap);
    final contents = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (leading == null)
            const SizedBox(width: 16)
          else
            SizedBox(width: 56, child: Center(child: _content(leading, 24))),
          Expanded(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                myContent(component.title),
                if (component.subtitle != null)
                  ElView(
                    style: ElStyle(
                      fontSize: 14,
                      fontWeight: .w400,
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
          if (trailing != null) Padding(padding: const .only(left: 12), child: _content(trailing, 20)),
          const SizedBox(width: 16),
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
          expanded: popup ? open.value && !disabled : null,
          onTap: ElButtonView.buildSemanticsTap(activate, base, disabled),
        ),
      ),
      child: component.semanticLabel == null ? contents : ExcludeSemantics(child: contents),
    );
    final index = ElChildIndex.maybeOf(context);
    if (index != null && !index.isEnd) {
      row = Stack(
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
    if (!popup || Overlay.maybeOf(context) == null) return row;
    return ElPortal(
      anchor: component.popupAnchor!,
      captureFocus: true,
      restoreFocus: true,
      closeOnBack: true,
      closeWhenUnlinked: true,
      onDismiss: () => open.value = false,
      panel: open.value && !disabled ? _popupPanel(context, component, () => open.value = false) : null,
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

Widget _content(Object? value, double size) => IgnorePointer(
  child: ExcludeFocus(
    child: value is IconData
        ? ElView(
            style: ElStyle(iconSize: size),
            child: value,
          )
        : myContent(value),
  ),
);

bool _cupertino(BuildContext context) {
  final cupertino = ElFlutterUtil.getAncestorElement<CupertinoApp>(context);
  final material = ElFlutterUtil.getAncestorElement<MaterialApp>(context);
  return cupertino != null && (material == null || cupertino.depth > material.depth);
}

Widget _selectionMark(BuildContext context, bool selected, ElModelValueType mode) {
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
      ),
      child: selected && !radio ? Icon(CupertinoIcons.check_mark, size: 16, color: theme.primaryText) : null,
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
          transition: myReducedMotion(context)
              ? const []
              : const [ElTransition.field(ElTransitionField.transform, Duration(milliseconds: 230))],
        ),
        child: loading ? const MyLoading(size: MyLoadingSize.small) : null,
      ),
    ),
  );
}
