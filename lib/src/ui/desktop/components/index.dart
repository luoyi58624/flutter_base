import 'package:flutter/widgets.dart';

import '../../../dart/commons/index.dart' show El;
import '../../../flutter/commons/models.dart' show ElLevelType;
import '../../../flutter/commons/theme/index.dart' show ElThemeContextExt, ElTokens;
import '../../../flutter/components/icon/index.dart' as common show ElIcon;
import '../../../flutter/components/index.dart' hide ElIcon;
import '../../../flutter/utils/obs/index.dart' show Obs;
import '../../../flutter/views/table/table.dart' show ElTableStyle;
import '../../../flutter/views/view/style/style.dart' show ElStyle;
import '../../../flutter/widgets/form/index.dart' show ElFormItem, ElFormItemView;
import 'autocomplete/index.dart';
import 'button/index.dart';
import 'button_group/index.dart';
import 'icon/index.dart';
import 'input/index.dart';
import 'input_number/index.dart';
import 'input_otp/index.dart';
import 'input_tag/index.dart';
import 'mention/index.dart';
import 'select/index.dart';
import 'switch/index.dart';
import 'table/index.dart';
import 'tag/index.dart';

part 'tokens.dart';
part 'shadow.dart';

/// 桌面品牌的组件和 token 预设。
extension ElDesktopExt on El {
  /// 桌面端默认组件及样式配置。
  ElementPlusThemeData get desktopComponents => const ElementPlusThemeData();
}

/// Element Plus 的全局组件实现预设。
///
/// 每个注入点都是本类的 `static` 成员，函数体直接构造实现类：构造 [ElComponents]
/// 时不传某项就吃这里的品牌默认，显式传 `null` 则清空该项（表格回退 el_ui 默认皮肤）。
class ElementPlusThemeData extends ElComponents {
  /// 桌面组件使用的紧凑密度变量。
  static const $compact = '--el-desktop-compact';

  @override
  ElStyle get token => _token;

  static final _token = ElStyle(
    vars: _lightVars,
    onDark: ElStyle(vars: _darkVars),
  );

  /// 字体图标沿用既有 ElView 图标实现，公共参数统一由 ElIcon 声明。
  static Widget iconBuilder(BuildContext context, common.ElIcon component) => ElIcon(
    component.child,
    size: component.size,
    color: component.color,
    style: component.style,
    semanticLabel: component.semanticLabel,
  );

  /// Element 按钮。
  static Widget buttonBuilder(BuildContext context, ElButton component, Obs<bool> model) => Button(component, model);

  /// Element 标签。
  static Widget tagBuilder(BuildContext context, ElTag component) => Tag(component);

  /// Element 按钮组；普通组没有模型值，不挂载值绑定和表单 Hook。
  static Widget buttonGroupBuilder<D>(BuildContext context, ElButtonGroup<D> component) => ButtonGroup<D>(component);

  /// Element 开关。
  static Widget switchButtonBuilder(BuildContext context, ElSwitch component, Obs<bool> model) =>
      Switch(component, model);

  /// Element 输入框；[style] 是组件外观的基线，组件自身 `style` 仍优先。
  static Widget inputBuilder(BuildContext context, ElInput component, {ElStyle? style}) => Input(component, style);

  /// Element 选择器。
  static Widget selectBuilder<T>(BuildContext context, ElSelect<T> component) => Select<T>(component);

  /// Element 自动补全。
  static Widget autocompleteBuilder<T>(BuildContext context, ElAutocomplete<T> component) => Autocomplete<T>(component);

  /// Element 数字输入框。
  static Widget inputNumberBuilder(BuildContext context, ElInputNumber component) => InputNumber(component);

  /// Element 提及输入框。
  static Widget mentionBuilder<T>(BuildContext context, ElMention<T> component) => Mention<T>(component);

  /// Element 标签输入框。
  static Widget inputTagBuilder(BuildContext context, ElInputTag component) => InputTag(component);

  /// Element 一次性验证码输入框。
  static Widget inputOtpBuilder(BuildContext context, ElInputOtp component) => InputOtp(component);

  /// Element 表单条目：只注入标签与校验提示外观，布局与校验由 el_ui 内核负责。
  static Widget formItemBuilder(BuildContext context, ElFormItem component) => ElFormItemView(
    component: component,
    labelStyle: ElStyle(color: context.elTheme.textRegular, iconColor: context.elTheme.textRegular),
    errorStyle: ElStyle(color: context.elTheme.error, iconColor: context.elTheme.error),
  );

  /// Element 表格皮肤（实现在表格目录的 [ElTableTheme.style]）。
  static ElTableStyle tableStyleBuilder(BuildContext context) => ElTableTheme.style(context);

  /// 默认使用已接入的品牌实现；Radio、Checkbox 默认留空，可显式注入自定义实现。
  const ElementPlusThemeData({
    super.button = buttonBuilder,
    super.buttonGroup = buttonGroupBuilder,
    super.switcher = switchButtonBuilder,
    super.input = inputBuilder,
    super.checkbox,
    super.radio,
    super.select = selectBuilder,
    super.autocomplete = autocompleteBuilder,
    super.inputNumber = inputNumberBuilder,
    super.mention = mentionBuilder,
    super.inputTag = inputTagBuilder,
    super.inputOtp = inputOtpBuilder,
    super.formItem = formItemBuilder,
    super.tag = tagBuilder,
    super.tableStyle = tableStyleBuilder,
    super.icon = iconBuilder,
  });
}
