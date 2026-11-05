part of 'index.dart';

/// Element Plus 的全局组件实现预设。
///
/// 每个注入点都是本类的 `static` 成员，函数体直接构造实现类：构造 [ElComponentBuilders]
/// 时不传某项就吃这里的品牌默认，显式传 `null` 则清空该项（表格回退 el_ui 默认皮肤）。
class ElementPlusThemeData extends ElComponentBuilders {
  /// 字体图标沿用既有 ElView 图标实现，公共参数统一由 ElIcon 声明。
  static Widget icon(BuildContext context, common.ElIcon component) => ElIcon(
    component.child,
    size: component.size,
    color: component.color,
    style: component.style,
    semanticLabel: component.semanticLabel,
  );

  /// Element 按钮。
  static Widget button(BuildContext context, ElButton component) => Button(component);

  /// Element 切换按钮，选中态读写公共模型。
  static Widget toggleButton(BuildContext context, ElToggleButton component, Obs<bool> model) =>
      Button.toggle(component, model);

  /// Element 标签。
  static Widget tag(BuildContext context, ElTag component) => Tag(component);

  /// Element 按钮组；普通组没有模型值，不挂载值绑定和表单 Hook。
  static Widget buttonGroup<D>(BuildContext context, ElButtonGroup<D> component) => ButtonGroup<D>(component);

  /// Element 开关。
  static Widget switchButton(BuildContext context, ElSwitch component, Obs<bool> model) => Switch(component, model);

  /// Element 输入框；[style] 是组件外观的基线，组件自身 `style` 仍优先。
  static Widget input(BuildContext context, ElInput component, {ElStyle? style}) => Input(component, style);

  /// Element 选择器。
  static Widget select<T>(BuildContext context, ElSelect<T> component) => Select<T>(component);

  /// Element 自动补全。
  static Widget autocomplete<T>(BuildContext context, ElAutocomplete<T> component) => Autocomplete<T>(component);

  /// Element 数字输入框。
  static Widget inputNumber(BuildContext context, ElInputNumber component) => InputNumber(component);

  /// Element 提及输入框。
  static Widget mention<T>(BuildContext context, ElMention<T> component) => Mention<T>(component);

  /// Element 标签输入框。
  static Widget inputTag(BuildContext context, ElInputTag component) => InputTag(component);

  /// Element 一次性验证码输入框。
  static Widget inputOtp(BuildContext context, ElInputOtp component) => InputOtp(component);

  /// Element 表单条目：只注入标签与校验提示外观，布局与校验由 el_ui 内核负责。
  static Widget formItem(BuildContext context, ElFormItem component) => ElFormItemView(
    component: component,
    labelStyle: ElStyle(color: context.elTheme.textRegular, iconColor: context.elTheme.textRegular),
    errorStyle: ElStyle(color: context.elTheme.error, iconColor: context.elTheme.error),
  );

  /// Element 表格皮肤（实现在表格目录的 [ElTableTheme.style]）。
  static ElTableStyle tableStyle(BuildContext context) => ElTableTheme.style(context);

  /// Element 文本：透传 Flutter [Text]，品牌不干预默认排版。
  static Widget text(BuildContext context, ElText component) => Text(
    component.data,
    style: component.style,
    strutStyle: component.strutStyle,
    textAlign: component.textAlign,
    textDirection: component.textDirection,
    locale: component.locale,
    softWrap: component.softWrap,
    overflow: component.overflow,
    textScaler: component.textScaler,
    maxLines: component.maxLines,
    textWidthBasis: component.textWidthBasis,
    textHeightBehavior: component.textHeightBehavior,
    selectionColor: component.selectionColor,
  );

  /// 默认使用已接入的品牌实现；Radio、Checkbox 默认留空，可显式注入自定义实现。
  const ElementPlusThemeData({
    super.buttonBuilder = button,
    super.toggleButtonBuilder = toggleButton,
    super.buttonGroupBuilder = buttonGroup,
    super.switchBuilder = switchButton,
    super.inputBuilder = input,
    super.checkboxBuilder,
    super.radioBuilder,
    super.selectBuilder = select,
    super.autocompleteBuilder = autocomplete,
    super.inputNumberBuilder = inputNumber,
    super.mentionBuilder = mention,
    super.inputTagBuilder = inputTag,
    super.inputOtpBuilder = inputOtp,
    super.formItemBuilder = formItem,
    super.tagBuilder = tag,
    super.tableStyleBuilder = tableStyle,
    super.textBuilder = text,
    super.iconBuilder = icon,
  });
}
