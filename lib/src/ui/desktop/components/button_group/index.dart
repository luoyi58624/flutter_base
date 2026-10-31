// 渲染协作／测试使用引擎内部状态，不扩展业务 API。
// ignore: implementation_imports, invalid_use_of_internal_member
import 'package:flutter_base/src/flutter/views/view/render/render_view.dart';

import 'dart:math' as math;

import 'package:flutter_base/src/ui/desktop/internal.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'render.dart';

List<double> get _buttonFonts => const [12.0, 13.0, 14.0, 15.0, 16.0];

List<double> get _buttonIcons => const [12.0, 13.0, 15.0, 16.0, 18.0];

List<EdgeInsetsGeometry> get _buttonPaddings => const [
  EdgeInsets.symmetric(vertical: 2, horizontal: 10),
  EdgeInsets.symmetric(vertical: 4, horizontal: 14),
  EdgeInsets.symmetric(vertical: 4, horizontal: 16),
  EdgeInsets.symmetric(vertical: 4, horizontal: 20),
  EdgeInsets.symmetric(vertical: 4, horizontal: 24),
];

/// Element 按钮组主题实现：只服务 [ElementPlusThemeData]，由 barrel 挡住、不经 `element_plus.dart` 导出。
class ButtonGroup<D> extends ElFormModelValue<D> {
  ButtonGroup(this.component, {super.key})
    : super(
        value: component.value,
        modelValue: component.modelValue,
        onChanged: component.onChanged,
      );

  final ElButtonGroup<D> component;

  Object? _valueOf(int index) => component.children[index].value ?? index;

  bool _isSelected(int index) {
    final value = _valueOf(index);
    return switch (component.mode) {
      null => false,
      ElButtonGroupMode.single => $obs.value == value,
      ElButtonGroupMode.multi =>
        ($obs.value as Iterable?)?.contains(value) ?? false,
    };
  }

  void _toggle(int index) {
    final value = _valueOf(index);
    switch (component.mode) {
      case null:
        return;
      case ElButtonGroupMode.single:
        // 重复点击选中项 = 清空选择，但**只在 D 可空时**才清——绑定
        // `Obs<int>` 这类非空泛型时写 null 会当场类型崩溃，此时退化为
        // mandatory（静默保持选中）比崩溃合理。想要可清就用 `Obs<int?>`。
        final clearing =
            $obs.value == value && !component.mandatory && null is D;
        // Obs setter 自带相等短路：component.mandatory 下重复点击写入同值 → 静默
        $obs.value = clearing ? (null as D) : (value as D);
      case ElButtonGroupMode.multi:
        final current = $obs.value;
        assert(
          current is List || current is Set,
          'ElButtonGroup.multi 的选中值必须为 List / Set 集合',
        );
        final has = (current as Iterable).contains(value);
        // 必选模式下不允许清掉最后一个选中项
        if (has && current.length == 1 && component.mandatory) return;
        // toList / toSet 保留调用方元素类型，绑定窄类型时回写不触发协变检查错误
        final dynamic next = current is Set
            ? current.toSet()
            : (current as List).toList();
        has ? next.remove(value) : next.add(value);
        $obs.value = next as D;
    }
  }

  bool get _isDesktop {
    if (!ElPlatform.isFlutterTest) return ElPlatform.isDesktop;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  /// 移动端立即进入按压配色，松开沿基础过渡恢复，与普通按钮一致。
  ElStyle _mobileTap(ElStyle style) =>
      style.copyWith(transition: const [ElTransition.all(Duration.zero)]);

  Color? _resolvedColor(BuildContext context) {
    final bg = component.bgColor;
    if (bg != null) return bg;
    return component.type?.color(context);
  }

  /// 按背景明暗取通用对比文字色，背景暗用 textOnDark，背景亮用 textOnLight。
  Color _textOnBackground(BuildContext context, Color background) {
    final dark = background.isDark.brightness == Brightness.dark;
    return dark
        ? context.elTheme.textOnDark
        : context.elTheme.textOnLight;
  }

  /// 组件尺寸档：读取祖先主题变量中的 size。
  ElLevelType _resolvedSize(BuildContext context) =>
      context.elComponentSize(component.style);

  @override
  Widget obsBuilder(BuildContext context) {
    return ElView(
      semantics: ElSemantics(container: true, label: component.semanticLabel),
      style: component.style,
      child: _ButtonGroupLayout(
        axis: component.axis,
        block: component.block,
        flexes: [for (final item in component.children) item.flex ?? 1],
        children: [
          for (var i = 0; i < component.children.length; i++)
            _buildItem(
              context,
              index: i,
              isFirst: i == 0,
              isLast: i == component.children.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required int index,
    required bool isFirst,
    required bool isLast,
  }) {
    final item = component.children[index];
    return ElButtonView(
      onPressed: component.disabled || item.disabled
          ? null
          : () {
              _toggle(index);
              item.onPressed?.call();
            },
      semanticLabel: item.semanticLabel,
      disabled: component.disabled || item.disabled,
      selected: _isSelected(index),
      style: _itemStyle(
        context,
        isFirst: isFirst,
        selected: _isSelected(index),
        isLast: isLast,
        single: component.children.length == 1,
        horizontal: component.axis == Axis.horizontal,
        typeColor: _resolvedColor(context),
      ),
      child: _buildContent(context, item.child),
    );
  }

  /// 项内容：IconData 升格为图标（尺寸跟档位、颜色跟 currentColor），
  /// Widget 原样托管，其余按文本渲染。
  Widget _buildContent(BuildContext context, Object? child) {
    if (child is Widget) return child;
    if (child is IconData) {
      return ElIcon(child);
    }
    return ElView(child: child);
  }

  /// 组内按钮的完整外观（自绘，不经过 ElButton）：
  ///
  /// - 普通实心组的背景与边框同步变色，hover 变浅，按压变深。
  /// - 选择组未选中时统一默认外观，选中背景、边框与对比文字按主题色生成。
  /// - **默认主题**：白底灰边（内侧缝边不画、归组在 render 层画），
  ///   hover 文字/边框染 primary、底色 light-9，按压/选中边框实色。
  ///
  /// 两种形态共用同一套盒尺寸（高度/字号/内边距/圆角档位），与 [ElButton]
  /// 一致；默认值由按钮组自身持有，所有条目使用组级配色。
  ElStyle _itemStyle(
    BuildContext context, {
    required bool isFirst,
    required bool selected,
    required bool isLast,
    required bool single,
    required bool horizontal,
    required Color? typeColor,
  }) {
    final isDesktop = _isDesktop;
    final size = _resolvedSize(context);
    final radius = Radius.circular(context.elTheme.radiusSm);
    final base = ElStyle(
      alignment: .center,
      lineHeight: 1.0,
      fontSize: _buttonFonts[size.index],
      iconSize: _buttonIcons[size.index],
      fontWeight: .w500,
      cursor: SystemMouseCursors.click,
      minHeight: context.elTheme.controlHeights[size.index],
      padding: _buttonPaddings[size.index],
      borderRadius: _positionRadius(
        isFirst: isFirst,
        isLast: isLast,
        single: single,
        horizontal: horizontal,
        r: radius,
      ),
      transition: [.all(Duration(milliseconds: isDesktop ? 100 : 200))],
    );
    ElBorder border(Color color, {bool contrast = false}) {
      // 只有实心背景启用对比接缝，浅底交互已有底色差异，无需再加亮边。
      // HSP 按基础主题色判断，避免 hover 变浅时突然翻转亮暗边。
      final seamColor = typeColor == null
          ? const Color(0x00000000)
          : (typeColor.isDark
                    ? context.elLightBorderColor(color)
                    : context.elDarkBorderColor(color))
                .withValues(alpha: contrast ? 1 : 0);
      return _positionBorder(
        context,
        isFirst: isFirst,
        isLast: isLast,
        single: single,
        horizontal: horizontal,
        color: color,
        seamColor: seamColor,
      );
    }

    if (typeColor != null && component.mode == null) {
      final textColor = _textOnBackground(context, typeColor);
      // 与普通主题按钮一致，固定悬停变浅、按压变深，不随页面明暗反转。
      final activeBg = typeColor.elLightOf(.dark, 2);
      final hoverBg = typeColor.elLightOf(.light, 3);
      final disabledBg = typeColor.elLight5(context);
      final active = ElStyle(
        backgroundColor: activeBg,
        border: border(activeBg, contrast: true),
      );
      return base
          .copyWith(
            color: textColor,
            iconColor: textColor,
            backgroundColor: typeColor,
            border: border(typeColor, contrast: true),
            onHover: (selected)
                ? null
                : (isDesktop && !selected
                      ? ElStyle(
                          backgroundColor: hoverBg,
                          border: border(hoverBg, contrast: true),
                        )
                      : null),
            onTap: (selected)
                ? null
                : (isDesktop ? active : _mobileTap(active)),

            onDisabled: ElStyle(
              cursor: SystemMouseCursors.forbidden,
              color: const Color(0xffffffff),
              backgroundColor: disabledBg,
              border: border(disabledBg, contrast: true),
              iconColor: const Color(0xffffffff),
            ),
            onFocusVisible: active,
          )
          .merge((selected) ? (active) : null);
    }

    final primary = context.elTheme.primary;
    final bgColor = context.elTheme.bgColor;
    final textColor = context.elTheme.textRegular;
    final borderColor = context.elTheme.borderColor;
    final active = ElStyle(
      color: primary,
      backgroundColor: primary.elLight9(context),
      border: border(primary),
      iconColor: primary,
    );
    final disabled = ElStyle(
      cursor: SystemMouseCursors.forbidden,
      color: context.elTheme.textPlaceholder,
      backgroundColor: bgColor,
      border: border(borderColor),
      iconColor: context.elTheme.textPlaceholder,
    );
    final selectedText = typeColor == null
        ? primary
        : _textOnBackground(context, typeColor);
    ElStyle selectedColor(Color color) => ElStyle(
      color: selectedText,
      backgroundColor: color,
      border: border(
        typeColor == null ? primary : color,
        contrast: typeColor != null,
      ),
      iconColor: selectedText,
    );
    final selectedBase = selectedColor(typeColor ?? primary.elLight9(context));
    final selectedActive = selectedColor(
      typeColor?.elLightOf(.dark, 2) ?? primary.elLight7(context),
    );
    return base
        .copyWith(
          color: textColor,
          iconColor: textColor,
          backgroundColor: bgColor,
          border: border(borderColor),
          onHover: (selected)
              ? null
              : (!isDesktop || selected
                    ? null
                    : ElStyle(
                        color: primary,
                        backgroundColor: primary.elLight9(context),
                        border: border(primary.elLight7(context)),
                        iconColor: primary,
                      )),
          onTap: (selected) ? null : (isDesktop ? active : _mobileTap(active)),
          // 选中态仅承接按压和键盘焦点反馈，悬停保持选中底色。

          onDisabled: disabled,
          onFocusVisible: active,
        )
        .merge(
          (selected)
              ? (selectedBase.copyWith(
                  onTap: isDesktop
                      ? selectedActive
                      : _mobileTap(selectedActive),
                  onFocusVisible: selectedActive,
                  onDisabled: disabled,
                ))
              : null,
        );
  }

  /// 组内项的圆角：单项全圆角；横向首项保左侧两角、末项保右侧两角；
  /// 纵向首项保上侧两角、末项保下侧两角；中间直角。
  BorderRadiusGeometry _positionRadius({
    required bool isFirst,
    required bool isLast,
    required bool single,
    required bool horizontal,
    required Radius r,
  }) {
    if (single) return BorderRadius.all(r);
    return BorderRadius.only(
      topLeft: isFirst ? r : Radius.zero,
      topRight: horizontal
          ? (isLast ? r : Radius.zero)
          : (isFirst ? r : Radius.zero),
      bottomLeft: horizontal
          ? (isFirst ? r : Radius.zero)
          : (isLast ? r : Radius.zero),
      bottomRight: isLast ? r : Radius.zero,
    );
  }

  /// 组内项的边框：**内侧缝边不画**（归组在 render 层画），
  /// 只保留外侧——横向首项 left/top/bottom、末项 right/top/bottom、
  /// 中间 top/bottom；纵向首项 top/left/right、末项 bottom/left/right。
  ElBorder _positionBorder(
    BuildContext context, {
    required bool isFirst,
    required bool isLast,
    required bool single,
    required bool horizontal,
    required Color color,
    required Color seamColor,
  }) {
    if (single) return ElBorder.all(borderColor: color);
    final side = ElBorderSide(borderColor: color, borderWidth: context.elBorderWidth);
    // 内侧保存对比边及其透明度，由组取两侧共同可见度，随边框一起过渡。
    final seam = ElBorderSide(borderColor: seamColor, borderWidth: 0, borderStyle: .none);
    return ElBorder.only(
      borderLeft: horizontal ? (isFirst ? side : seam) : side,
      borderRight: horizontal ? (isLast ? side : seam) : side,
      borderTop: horizontal ? side : (isFirst ? side : seam),
      borderBottom: horizontal ? side : (isLast ? side : seam),
    );
  }
}
