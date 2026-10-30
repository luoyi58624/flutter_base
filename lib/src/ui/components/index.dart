import 'package:flutter/widgets.dart';

import '../../flutter/views/table/table.dart' show ElTableStyle;
import 'button.dart';
import 'tag.dart';
import 'button_group.dart';
import 'switch.dart';
import 'input.dart';
import 'checkbox/index.dart';
import 'radio/index.dart';
import 'select.dart';
import 'autocomplete.dart';
import 'input_number.dart';
import 'mention.dart';
import 'input_tag.dart';
import 'input_otp.dart';
import 'text.dart';
import '../widgets/form/index.dart';

export 'button.dart';
export 'tag.dart';
export 'button_group.dart';
export 'switch.dart';
export 'input.dart';
export 'checkbox/index.dart';
export 'radio/index.dart';
export 'select.dart';
export 'autocomplete.dart';
export 'input_number.dart';
export 'mention.dart';
export 'input_tag.dart';
export 'input_otp.dart';
export 'text.dart';

const _absent = Object();

/// 全局组件实现登记表，新增组件时直接在此声明 Builder 字段。
class ElComponentBuilders {
  /// 创建组件实现配置，空字段在 merge 时保留已有实现。
  const ElComponentBuilders({
    this.buttonBuilder,
    this.tagBuilder,
    this.buttonGroupBuilder,
    this.switchBuilder,
    this.inputBuilder,
    this.checkboxBuilder,
    this.radioBuilder,
    this.selectBuilder,
    this.autocompleteBuilder,
    this.inputNumberBuilder,
    this.mentionBuilder,
    this.inputTagBuilder,
    this.inputOtpBuilder,
    this.formItemBuilder,
    this.tableStyleBuilder,
    this.textBuilder,
  });

  /// 构建标签品牌外观，绑定与切换交互由公共宿主负责。
  final Widget Function(BuildContext context, ElTag component)? tagBuilder;

  /// 根据原始 Button 声明构建具体实现。
  final Widget Function(BuildContext context, ElButton component)? buttonBuilder;

  /// 根据原始 ButtonGroup 声明构建具体实现。
  final Widget Function<T>(BuildContext context, ElButtonGroup<T> component)? buttonGroupBuilder;

  /// 根据原始 Switch 声明构建具体实现。
  final Widget Function(BuildContext context, ElSwitch component)? switchBuilder;

  /// 根据原始 Input 声明构建具体实现。
  final Widget Function(BuildContext context, ElInput component)? inputBuilder;

  /// 根据原始 Select 声明构建具体实现。
  final Widget Function<T>(BuildContext context, ElSelect<T> component)? selectBuilder;

  /// 根据原始 Autocomplete 声明构建具体实现。
  final Widget Function<T>(BuildContext context, ElAutocomplete<T> component)? autocompleteBuilder;

  /// 根据原始 InputNumber 声明构建具体实现。
  final Widget Function(BuildContext context, ElInputNumber component)? inputNumberBuilder;

  /// 根据原始 Mention 声明构建具体实现。
  final Widget Function<T>(BuildContext context, ElMention<T> component)? mentionBuilder;

  /// 根据原始 InputTag 声明构建具体实现。
  final Widget Function(BuildContext context, ElInputTag component)? inputTagBuilder;

  /// 根据原始 InputOtp 声明构建具体实现。
  final Widget Function(BuildContext context, ElInputOtp component)? inputOtpBuilder;

  /// 根据原始 FormItem 声明构建具体实现。
  final Widget Function(BuildContext context, ElFormItem component)? formItemBuilder;

  /// 构建多选框外观，交互与有效状态由通用宿主提供。
  final Widget Function(BuildContext context, ElCheckbox component, ElCheckboxState state)? checkboxBuilder;

  /// 构建单选框外观，保留选项模型类型。
  final Widget Function<T>(BuildContext context, ElRadio<T> component, ElRadioState state)? radioBuilder;

  /// 表格外观工厂：只返回一个 [ElTableStyle] 样式对象，不接管任何表格实现。
  ///
  /// 表格渲染 / 布局 / 虚拟化 / 命中 / 排序 / 选择 / 展开全在 el_ui 内，
  /// 所以这里**不是** Widget builder —— 上层（品牌包）只登记一份皮肤预设。
  final ElTableStyle Function(BuildContext context)? tableStyleBuilder;

  /// 根据原始 Text 声明构建具体实现。
  final Widget Function(BuildContext context, ElText component)? textBuilder;

  /// 省略参数保留原值，显式 null 清空指定实现。
  ElComponentBuilders copyWith({
    Object? buttonBuilder = _absent,
    Object? tagBuilder = _absent,
    Object? buttonGroupBuilder = _absent,
    Object? switchBuilder = _absent,
    Object? inputBuilder = _absent,
    Object? checkboxBuilder = _absent,
    Object? radioBuilder = _absent,
    Object? selectBuilder = _absent,
    Object? autocompleteBuilder = _absent,
    Object? inputNumberBuilder = _absent,
    Object? mentionBuilder = _absent,
    Object? inputTagBuilder = _absent,
    Object? inputOtpBuilder = _absent,
    Object? formItemBuilder = _absent,
    Object? tableStyleBuilder = _absent,
    Object? textBuilder = _absent,
  }) => ElComponentBuilders(
    tagBuilder: identical(tagBuilder, _absent) ? this.tagBuilder : tagBuilder as Widget Function(BuildContext, ElTag)?,
    buttonBuilder: identical(buttonBuilder, _absent)
        ? this.buttonBuilder
        : buttonBuilder as Widget Function(BuildContext, ElButton)?,
    buttonGroupBuilder: identical(buttonGroupBuilder, _absent)
        ? this.buttonGroupBuilder
        : buttonGroupBuilder as Widget Function<T>(BuildContext, ElButtonGroup<T>)?,
    switchBuilder: identical(switchBuilder, _absent)
        ? this.switchBuilder
        : switchBuilder as Widget Function(BuildContext, ElSwitch)?,
    checkboxBuilder: identical(checkboxBuilder, _absent)
        ? this.checkboxBuilder
        : checkboxBuilder as Widget Function(BuildContext, ElCheckbox, ElCheckboxState)?,
    radioBuilder: identical(radioBuilder, _absent)
        ? this.radioBuilder
        : radioBuilder as Widget Function<T>(BuildContext, ElRadio<T>, ElRadioState)?,
    inputBuilder: identical(inputBuilder, _absent)
        ? this.inputBuilder
        : inputBuilder as Widget Function(BuildContext, ElInput)?,
    selectBuilder: identical(selectBuilder, _absent)
        ? this.selectBuilder
        : selectBuilder as Widget Function<T>(BuildContext, ElSelect<T>)?,
    autocompleteBuilder: identical(autocompleteBuilder, _absent)
        ? this.autocompleteBuilder
        : autocompleteBuilder as Widget Function<T>(BuildContext, ElAutocomplete<T>)?,
    inputNumberBuilder: identical(inputNumberBuilder, _absent)
        ? this.inputNumberBuilder
        : inputNumberBuilder as Widget Function(BuildContext, ElInputNumber)?,
    mentionBuilder: identical(mentionBuilder, _absent)
        ? this.mentionBuilder
        : mentionBuilder as Widget Function<T>(BuildContext, ElMention<T>)?,
    inputTagBuilder: identical(inputTagBuilder, _absent)
        ? this.inputTagBuilder
        : inputTagBuilder as Widget Function(BuildContext, ElInputTag)?,
    inputOtpBuilder: identical(inputOtpBuilder, _absent)
        ? this.inputOtpBuilder
        : inputOtpBuilder as Widget Function(BuildContext, ElInputOtp)?,
    formItemBuilder: identical(formItemBuilder, _absent)
        ? this.formItemBuilder
        : formItemBuilder as Widget Function(BuildContext, ElFormItem)?,
    tableStyleBuilder: identical(tableStyleBuilder, _absent) ? this.tableStyleBuilder : tableStyleBuilder as ElTableStyle Function(BuildContext)?,
    textBuilder: identical(textBuilder, _absent) ? this.textBuilder : textBuilder as Widget Function(BuildContext, ElText)?,
  );

  /// 合并非空实现，空配置不抹掉品牌默认值。
  ElComponentBuilders merge(ElComponentBuilders? other) => other == null
      ? this
      : ElComponentBuilders(
          buttonBuilder: other.buttonBuilder ?? buttonBuilder,
          tagBuilder: other.tagBuilder ?? tagBuilder,
          buttonGroupBuilder: other.buttonGroupBuilder ?? buttonGroupBuilder,
          switchBuilder: other.switchBuilder ?? switchBuilder,
          inputBuilder: other.inputBuilder ?? inputBuilder,
          checkboxBuilder: other.checkboxBuilder ?? checkboxBuilder,
          radioBuilder: other.radioBuilder ?? radioBuilder,
          selectBuilder: other.selectBuilder ?? selectBuilder,
          autocompleteBuilder: other.autocompleteBuilder ?? autocompleteBuilder,
          inputNumberBuilder: other.inputNumberBuilder ?? inputNumberBuilder,
          mentionBuilder: other.mentionBuilder ?? mentionBuilder,
          inputTagBuilder: other.inputTagBuilder ?? inputTagBuilder,
          inputOtpBuilder: other.inputOtpBuilder ?? inputOtpBuilder,
          formItemBuilder: other.formItemBuilder ?? formItemBuilder,
          tableStyleBuilder: other.tableStyleBuilder ?? tableStyleBuilder,
          textBuilder: other.textBuilder ?? textBuilder,
        );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElComponentBuilders &&
          buttonBuilder == other.buttonBuilder &&
          tagBuilder == other.tagBuilder &&
          buttonGroupBuilder == other.buttonGroupBuilder &&
          switchBuilder == other.switchBuilder &&
          inputBuilder == other.inputBuilder &&
          checkboxBuilder == other.checkboxBuilder &&
          radioBuilder == other.radioBuilder &&
          selectBuilder == other.selectBuilder &&
          autocompleteBuilder == other.autocompleteBuilder &&
          inputNumberBuilder == other.inputNumberBuilder &&
          mentionBuilder == other.mentionBuilder &&
          inputTagBuilder == other.inputTagBuilder &&
          inputOtpBuilder == other.inputOtpBuilder &&
          formItemBuilder == other.formItemBuilder &&
          tableStyleBuilder == other.tableStyleBuilder &&
          textBuilder == other.textBuilder;

  @override
  int get hashCode => Object.hash(
    tagBuilder,
    buttonBuilder,
    buttonGroupBuilder,
    switchBuilder,
    inputBuilder,
    checkboxBuilder,
    radioBuilder,
    selectBuilder,
    autocompleteBuilder,
    inputNumberBuilder,
    mentionBuilder,
    inputTagBuilder,
    inputOtpBuilder,
    formItemBuilder,
    tableStyleBuilder,
    textBuilder,
  );
}

/// 提供最近的完整组件实现配置，可随弹层捕获快照。
class ElComponentProvider extends InheritedTheme {
  /// 创建组件实现作用域；需要继承时在传入前显式合并。
  const ElComponentProvider({super.key, required this.builders, required super.child});

  /// 当前作用域的组件实现配置。
  final ElComponentBuilders builders;

  /// 读取最近的组件配置，必须存在祖先组件提供器。
  static ElComponentBuilders of(BuildContext context) {
    final builders = maybeOf(context);
    assert(builders != null, '当前上下文未找到 ElComponentProvider。');
    return builders!;
  }

  /// 读取可选的组件配置，独立通用 Widget 可在未登记品牌时使用自身默认布局。
  static ElComponentBuilders? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ElComponentProvider>()?.builders;

  @override
  bool updateShouldNotify(ElComponentProvider oldWidget) => builders != oldWidget.builders;

  @override
  Widget wrap(BuildContext context, Widget child) => ElComponentProvider(builders: builders, child: child);
}
