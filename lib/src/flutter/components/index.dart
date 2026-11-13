import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../../../dart.dart' show $absent, ElModelGenerator;
import '../utils/obs/index.dart' show Obs;
import '../views/table/table.dart' show ElTableStyle;
import '../views/view/style/style.dart' show ElStyle;
import '../views/view/view.dart' show ElView;
import '../widgets/form/index.dart';
import 'alert/index.dart';
import 'app_bar/index.dart';
import 'tooltip/index.dart';
import 'autocomplete/index.dart';
import 'avatar/index.dart';
import 'button/index.dart';
import 'button_group/index.dart';
import 'calendar/index.dart';
import 'card/index.dart';
import 'checkbox/index.dart';
import 'collapse/index.dart';
import 'empty/index.dart';
import 'input/index.dart';
import 'input_number/index.dart';
import 'input_otp/index.dart';
import 'input_tag/index.dart';
import 'list_tile/index.dart';
import 'loading_indicator/index.dart';
import 'mention/index.dart';
import 'picker/index.dart';
import 'popup/index.dart';
import 'upload/index.dart';
import 'progress/index.dart';
import 'radio/index.dart';
import 'segmented/index.dart';
import 'select/index.dart';
import 'skeleton/index.dart';
import 'slider/index.dart';
import 'steps/index.dart';
import 'switch/index.dart';
import 'tabs/index.dart';
import 'tag/index.dart';
import 'toast/index.dart';

export 'button/index.dart';
export 'toast/index.dart';
export 'tag/index.dart';
export 'button_group/index.dart';
export 'switch/index.dart';
export 'input/index.dart';
export 'checkbox/index.dart';
export 'radio/index.dart';
export 'select/index.dart';
export 'autocomplete/index.dart';
export 'input_number/index.dart';
export 'mention/index.dart';
export 'input_tag/index.dart';
export 'input_otp/index.dart';
export 'list_tile/index.dart';
export 'card/index.dart';
export 'loading_indicator/index.dart';
export 'progress/index.dart';
export 'slider/index.dart';
export 'skeleton/index.dart';
export 'steps/index.dart';
export 'avatar/index.dart';
export 'calendar/index.dart';
export 'collapse/index.dart';
export 'empty/index.dart';
export 'segmented/index.dart';
export 'tabs/index.dart';
export 'alert/index.dart';
export 'app_bar/index.dart';
export 'tooltip/index.dart';
export 'picker/index.dart';
export 'popup/index.dart';
export 'upload/index.dart';
export 'tokens.dart';

part 'index.g.dart';

/// 组件接口实现
@ElModelGenerator.copy()
@immutable
class ElComponents with Equatable {
  /// 创建完整预设或局部组件覆写。
  const ElComponents({
    this.style,
    this.button,
    this.tag,
    this.buttonGroup,
    this.switcher,
    this.input,
    this.checkbox,
    this.radio,
    this.select,
    this.autocomplete,
    this.inputNumber,
    this.mention,
    this.inputTag,
    this.inputOtp,
    this.formItem,
    this.tableStyle,
    this.card,
    this.loadingIndicator,
    this.listTile,
    this.listTileGroup,
    this.progress,
    this.slider,
    this.skeleton,
    this.steps,
    this.step,
    this.avatar,
    this.calendar,
    this.collapse,
    this.collapseItem,
    this.empty,
    this.segmented,
    this.tabs,
    this.tabBar,
    this.alert,
    this.picker,
    this.datePicker,
    this.timePicker,
    this.upload,
    this.popup,
    this.dialog,
    this.drawer,
    this.toast,
    this.appBar,
    this.tooltip,
  });

  /// 与组件预设绑定的样式和变量。
  final ElStyle? style;

  /// 根据 ElButton 声明与选中模型构建品牌组件；普通按钮的模型不参与绘制。
  final Widget Function(BuildContext context, ElButton component, Obs<bool> model)? button;

  /// 根据 ElTag 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTag component)? tag;

  /// 根据 ElButtonGroup 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElButtonGroup<T> component)? buttonGroup;

  /// 根据 ElSwitch 声明与开关模型构建品牌组件。
  final Widget Function(BuildContext context, ElSwitch component, Obs<bool> model)? switcher;

  /// 根据 ElInput 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInput component)? input;

  /// 根据 ElCheckbox 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCheckbox component, ElCheckboxState state)? checkbox;

  /// 根据 ElRadio 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElRadio<T> component, ElRadioState state)? radio;

  /// 根据 ElSelect 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElSelect<T> component)? select;

  /// 根据 ElAutocomplete 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElAutocomplete<T> component)? autocomplete;

  /// 根据 ElInputNumber 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputNumber component)? inputNumber;

  /// 根据 ElMention 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElMention<T> component)? mention;

  /// 根据 ElInputTag 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputTag component)? inputTag;

  /// 根据 ElInputOtp 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputOtp component)? inputOtp;

  /// 根据 ElFormItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElFormItem component)? formItem;

  /// 创建表格皮肤，表格行为继续由通用内核承担。
  final ElTableStyle Function(BuildContext context)? tableStyle;

  /// 根据 ElCard 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCard component)? card;

  /// 根据 ElLoadingIndicator 声明构建品牌组件。
  final Widget Function(BuildContext context, ElLoadingIndicator component)? loadingIndicator;

  /// 根据 ElListTile 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElListTile<T> component)? listTile;

  /// 根据 ElListGroup 声明构建品牌组件。
  final Widget Function<D>(BuildContext context, ElListGroup<D> component)? listTileGroup;

  /// 根据 ElProgress 声明构建品牌组件。
  final Widget Function(BuildContext context, ElProgress component)? progress;

  /// 根据 ElSlider 声明构建品牌组件。
  final Widget Function<D>(BuildContext context, ElSlider<D> component)? slider;

  /// 根据 ElSkeleton 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSkeleton component)? skeleton;

  /// 根据 ElSteps 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSteps component)? steps;

  /// 根据 ElStep 声明构建品牌组件。
  final Widget Function(BuildContext context, ElStep component)? step;

  /// 根据 ElAvatar 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAvatar component)? avatar;

  /// 根据 ElCalendar 声明构建品牌组件。
  final Widget Function<D>(BuildContext context, ElCalendar<D> component)? calendar;

  /// 根据 ElCollapse 声明构建品牌组件。
  final Widget Function<D>(BuildContext context, ElCollapse<D> component)? collapse;

  /// 根据 ElCollapseItem 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElCollapseItem<T> component)? collapseItem;

  /// 根据 ElEmpty 声明构建品牌组件。
  final Widget Function(BuildContext context, ElEmpty component)? empty;

  /// 根据 ElSegmented 声明构建品牌组件。
  final Widget Function<D>(BuildContext context, ElSegmented<D> component)? segmented;

  /// 根据 ElTabs 声明构建品牌组件。
  final Widget Function<D>(BuildContext context, ElTabs<D> component)? tabs;

  /// 根据 ElTabBar 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTabBar component)? tabBar;

  /// 根据 ElAlert 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAlert component)? alert;

  /// 根据 ElPicker 声明构建滚轮选择器。
  final Widget Function<T>(BuildContext context, ElPicker<T> component, Obs<List<T>> model)? picker;

  /// 根据 ElDatePicker 声明构建日期选择器。
  final Widget Function(BuildContext context, ElDatePicker component, Obs<DateTime> model)? datePicker;

  /// 根据 ElTimePicker 声明构建时间选择器。
  final Widget Function(BuildContext context, ElTimePicker component, Obs<Duration> model)? timePicker;

  /// 根据 ElUpload 声明构建文件列表和选择入口。
  final Widget Function(BuildContext context, ElUpload component)? upload;

  /// 根据 ElPopup 声明构建弹层内容。
  final Widget Function(BuildContext context, ElPopup component)? popup;

  /// 根据 ElDialog 声明构建对话框内容。
  final Widget Function(BuildContext context, ElDialog component)? dialog;

  /// 根据 ElDrawer 声明构建抽屉内容。
  final Widget Function(BuildContext context, ElDrawer component)? drawer;

  /// 根据 ElToast 声明构建短提示内容。
  final Widget Function(BuildContext context, ElToast component)? toast;

  /// 根据 ElAppBar 声明构建标题栏。
  final Widget Function(BuildContext context, ElAppBar component)? appBar;

  /// 根据 ElTooltip 声明构建锚定提示。
  final Widget Function(BuildContext context, ElTooltip component)? tooltip;

  /// 相等性与 hashCode 依据全部注入点。
  @override
  List<Object?> get props => _props;

  /// 合并局部覆写，安装完整品牌时采用该品牌的整套配置。
  ElComponents merge([ElComponents? other]) => other?.style != null ? other! : ElComponentsExt(this).merge(other);
}

/// 在同一视图作用域内安装组件实现和主题变量。
class ElComponentProvider extends ElView {
  /// 安装组件与预设样式，调用方样式优先，主题及其他视图配置沿用 ElView。
  ElComponentProvider({
    super.key,
    this.components,
    ElStyle? style,
    super.event,
    super.focusNode,
    super.semantics,
    super.themeMode,
    super.breakpoint,
    required Widget child,
  }) : super(
         style: components?.style?.merge(style) ?? style,
         child: Builder(
           builder: (context) {
             final parent = maybeOf(context);
             return _ComponentScope(components: parent?.merge(components) ?? components, child: child);
           },
         ),
       );

  /// 本层覆写的组件实现，省略时沿用祖先配置。
  final ElComponents? components;

  /// 读取合并后的组件配置，必须存在祖先组件提供器。
  static ElComponents of(BuildContext context) {
    final builders = maybeOf(context);
    assert(builders != null, '当前上下文未找到 ElComponentProvider。');
    return builders!;
  }

  /// 读取可选的组件配置，独立通用 Widget 可在未登记品牌时使用自身默认布局。
  static ElComponents? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ComponentScope>()?.components;

  /// 读取组件的实现，缺失时报出组件名，避免空断言难以定位。
  static F builderOf<F extends Function>(
    BuildContext context,
    Widget component,
    F? Function(ElComponents builders) select,
  ) {
    final builder = select(of(context));
    if (builder == null) throw FlutterError('${component.runtimeType} 未在 ElComponentProvider 中登记实现。');
    return builder;
  }
}

/// 保存合并结果；弹层捕获时直接复刻最终配置，不再与新位置的祖先合并。
class _ComponentScope extends InheritedTheme {
  const _ComponentScope({required this.components, required super.child});

  final ElComponents? components;

  @override
  bool updateShouldNotify(_ComponentScope oldWidget) => components != oldWidget.components;

  @override
  Widget wrap(BuildContext context, Widget child) => _ComponentScope(components: components, child: child);
}
