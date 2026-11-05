// import 'package:flutter/material.dart';
// import 'package:flutter_base/flutter.dart';
//
// import 'button/index.dart';
// import 'button_group/index.dart';
// import 'tag/index.dart';
// import 'table/index.dart';
// import 'autocomplete/index.dart';
// import 'input/index.dart';
// import 'input_number/index.dart';
// import 'input_otp/index.dart';
// import 'input_tag/index.dart';
// import 'mention/index.dart';
// import 'select/index.dart';
// import 'switch/index.dart';
//
// class ElDesktopComponents extends ElComponents {
//   const ElDesktopComponents({
//     super.button = buttonBuilder,
//     super.buttonGroup = buttonGroupBuilder,
//     super.switcher = switchButtonBuilder,
//     super.input = inputBuilder,
//     super.checkbox,
//     super.radio,
//     super.select = selectBuilder,
//     super.autocomplete = autocompleteBuilder,
//     super.inputNumber = inputNumberBuilder,
//     super.mention = mentionBuilder,
//     super.inputTag = inputTagBuilder,
//     super.inputOtp = inputOtpBuilder,
//     super.tag = tagBuilder,
//   });
//
//   /// Element 按钮。
//   static Widget buttonBuilder(BuildContext context, ElButton component, Obs<bool> model) => Button(component, model);
//
//   /// Element 标签。
//   static Widget tagBuilder(BuildContext context, ElTag component) => Tag(component);
//
//   /// Element 按钮组；普通组没有模型值，不挂载值绑定和表单 Hook。
//   static Widget buttonGroupBuilder<D>(BuildContext context, ElButtonGroup<D> component) => ButtonGroup<D>(component);
//
//   /// Element 开关。
//   static Widget switchButtonBuilder(BuildContext context, ElSwitch component, Obs<bool> model) =>
//       Switch(component, model);
//
//   /// Element 输入框；[style] 是组件外观的基线，组件自身 `style` 仍优先。
//   static Widget inputBuilder(BuildContext context, ElInput component, {ElStyle? style}) => Input(component, style);
//
//   /// Element 选择器。
//   static Widget selectBuilder<T>(BuildContext context, ElSelect<T> component) => Select<T>(component);
//
//   /// Element 自动补全。
//   static Widget autocompleteBuilder<T>(BuildContext context, ElAutocomplete<T> component) => Autocomplete<T>(component);
//
//   /// Element 数字输入框。
//   static Widget inputNumberBuilder(BuildContext context, ElInputNumber component) => InputNumber(component);
//
//   /// Element 提及输入框。
//   static Widget mentionBuilder<T>(BuildContext context, ElMention<T> component) => Mention<T>(component);
//
//   /// Element 标签输入框。
//   static Widget inputTagBuilder(BuildContext context, ElInputTag component) => InputTag(component);
//
//   /// Element 一次性验证码输入框。
//   static Widget inputOtpBuilder(BuildContext context, ElInputOtp component) => InputOtp(component);
// }
