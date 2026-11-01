import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/dart.dart';

import '../views/table/table.dart' show ElTableStyle;
import '../widgets/form/index.dart';
import 'button/index.dart';
import 'tag/index.dart';
import 'button_group/index.dart';
import 'switch/index.dart';
import 'input/index.dart';
import 'checkbox/index.dart';
import 'radio/index.dart';
import 'select/index.dart';
import 'autocomplete/index.dart';
import 'input_number/index.dart';
import 'mention/index.dart';
import 'input_tag/index.dart';
import 'input_otp/index.dart';
import 'text/index.dart';
import 'list_tile/index.dart';
import 'card/index.dart';
import 'loading_indicator/index.dart';
import 'icon/index.dart';
import 'anchor/index.dart';
import 'affix/index.dart';
import 'steps/index.dart';
import 'avatar/index.dart';
import 'calendar/index.dart';
import 'carousel/index.dart';
import 'collapse/index.dart';
import 'countdown/index.dart';
import 'descriptions/index.dart';
import 'empty/index.dart';
import 'pagination/index.dart';
import 'progress/index.dart';
import 'rate/index.dart';
import 'segmented/index.dart';
import 'slider/index.dart';
import 'skeleton/index.dart';
import 'statistic/index.dart';
import 'tabs/index.dart';
import 'timeline/index.dart';
import 'alert/index.dart';
import 'result/index.dart';
import 'backtop/index.dart';

export 'button/index.dart';
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
export 'text/index.dart';
export 'list_tile/index.dart';
export 'card/index.dart';
export 'loading_indicator/index.dart';
export 'icon/index.dart';
export 'anchor/index.dart';
export 'affix/index.dart';
export 'steps/index.dart';
export 'avatar/index.dart';
export 'calendar/index.dart';
export 'carousel/index.dart';
export 'collapse/index.dart';
export 'countdown/index.dart';
export 'descriptions/index.dart';
export 'empty/index.dart';
export 'pagination/index.dart';
export 'progress/index.dart';
export 'rate/index.dart';
export 'segmented/index.dart';
export 'slider/index.dart';
export 'skeleton/index.dart';
export 'statistic/index.dart';
export 'tabs/index.dart';
export 'timeline/index.dart';
export 'alert/index.dart';
export 'result/index.dart';
export 'backtop/index.dart';

part 'index.g.dart';

/// 通用组件实现登记表；新增声明的默认 Builder 为空，品牌实现另行安装。
///
/// copyWith、merge 与相等性由 `@ElModelGenerator.copy` 生成。
@ElModelGenerator.copy()
@immutable
class ElComponentBuilders with Equatable {
  /// 创建完整组件配置，不包含默认品牌实现。
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
    this.cardBuilder,
    this.loadingIndicatorBuilder,
    this.iconBuilder,
    this.listTileBuilder,
    this.listTileGroupBuilder,
    this.anchorBuilder,
    this.affixBuilder,
    this.stepsBuilder,
    this.stepBuilder,
    this.avatarBuilder,
    this.avatarGroupBuilder,
    this.calendarBuilder,
    this.carouselBuilder,
    this.collapseBuilder,
    this.collapseItemBuilder,
    this.countdownBuilder,
    this.descriptionsBuilder,
    this.emptyBuilder,
    this.paginationBuilder,
    this.progressBuilder,
    this.rateBuilder,
    this.segmentedBuilder,
    this.sliderBuilder,
    this.skeletonBuilder,
    this.skeletonItemBuilder,
    this.statisticBuilder,
    this.tabsBuilder,
    this.tabBarBuilder,
    this.timelineBuilder,
    this.timelineItemBuilder,
    this.alertBuilder,
    this.resultBuilder,
    this.backtopBuilder,
  });

  /// 根据 ElButton 声明构建品牌组件。
  final Widget Function(BuildContext context, ElButton component)? buttonBuilder;

  /// 根据 ElTag 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTag component)? tagBuilder;

  /// 根据 ElButtonGroup 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElButtonGroup<T> component)? buttonGroupBuilder;

  /// 根据 ElSwitch 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSwitch component)? switchBuilder;

  /// 根据 ElInput 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInput component)? inputBuilder;

  /// 根据 ElCheckbox 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCheckbox component, ElCheckboxState state)? checkboxBuilder;

  /// 根据 ElRadio 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElRadio<T> component, ElRadioState state)? radioBuilder;

  /// 根据 ElSelect 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElSelect<T> component)? selectBuilder;

  /// 根据 ElAutocomplete 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElAutocomplete<T> component)? autocompleteBuilder;

  /// 根据 ElInputNumber 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputNumber component)? inputNumberBuilder;

  /// 根据 ElMention 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElMention<T> component)? mentionBuilder;

  /// 根据 ElInputTag 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputTag component)? inputTagBuilder;

  /// 根据 ElInputOtp 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputOtp component)? inputOtpBuilder;

  /// 根据 ElFormItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElFormItem component)? formItemBuilder;

  /// 创建表格皮肤，表格行为继续由通用内核承担。
  final ElTableStyle Function(BuildContext context)? tableStyleBuilder;

  /// 根据 ElText 声明构建品牌组件。
  final Widget Function(BuildContext context, ElText component)? textBuilder;

  /// 根据 ElCard 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCard component)? cardBuilder;

  /// 根据 ElLoadingIndicator 声明构建品牌组件。
  final Widget Function(BuildContext context, ElLoadingIndicator component)? loadingIndicatorBuilder;

  /// 根据 ElIcon 声明构建品牌组件。
  final Widget Function(BuildContext context, ElIcon component)? iconBuilder;

  /// 根据 ElListTile 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElListTile<T> component)? listTileBuilder;

  /// 根据 ElListTileGroup 声明构建品牌组件。
  final Widget Function<D>(BuildContext context, ElListTileGroup<D> component)? listTileGroupBuilder;

  /// 根据 ElAnchor 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAnchor component)? anchorBuilder;

  /// 根据 ElAffix 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAffix component)? affixBuilder;

  /// 根据 ElSteps 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSteps component)? stepsBuilder;

  /// 根据 ElStep 声明构建品牌组件。
  final Widget Function(BuildContext context, ElStep component)? stepBuilder;

  /// 根据 ElAvatar 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAvatar component)? avatarBuilder;

  /// 根据 ElAvatarGroup 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAvatarGroup component)? avatarGroupBuilder;

  /// 根据 ElCalendar 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCalendar component)? calendarBuilder;

  /// 根据 ElCarousel 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCarousel component)? carouselBuilder;

  /// 根据 ElCollapse 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCollapse component)? collapseBuilder;

  /// 根据 ElCollapseItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCollapseItem component)? collapseItemBuilder;

  /// 根据 ElCountdown 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCountdown component)? countdownBuilder;

  /// 根据 ElDescriptions 声明构建品牌组件。
  final Widget Function(BuildContext context, ElDescriptions component)? descriptionsBuilder;

  /// 根据 ElEmpty 声明构建品牌组件。
  final Widget Function(BuildContext context, ElEmpty component)? emptyBuilder;

  /// 根据 ElPagination 声明构建品牌组件。
  final Widget Function(BuildContext context, ElPagination component)? paginationBuilder;

  /// 根据 ElProgress 声明构建品牌组件。
  final Widget Function(BuildContext context, ElProgress component)? progressBuilder;

  /// 根据 ElRate 声明构建品牌组件。
  final Widget Function(BuildContext context, ElRate component)? rateBuilder;

  /// 根据 ElSegmented 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSegmented component)? segmentedBuilder;

  /// 根据 ElSlider 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSlider component)? sliderBuilder;

  /// 根据 ElSkeleton 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSkeleton component)? skeletonBuilder;

  /// 根据 ElSkeletonItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSkeletonItem component)? skeletonItemBuilder;

  /// 根据 ElStatistic 声明构建品牌组件。
  final Widget Function(BuildContext context, ElStatistic component)? statisticBuilder;

  /// 根据 ElTabs 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTabs component)? tabsBuilder;

  /// 根据 ElTabBar 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTabBar component)? tabBarBuilder;

  /// 根据 ElTimeline 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTimeline component)? timelineBuilder;

  /// 根据 ElTimelineItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTimelineItem component)? timelineItemBuilder;

  /// 根据 ElAlert 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAlert component)? alertBuilder;

  /// 根据 ElResult 声明构建品牌组件。
  final Widget Function(BuildContext context, ElResult component)? resultBuilder;

  /// 根据 ElBacktop 声明构建品牌组件。
  final Widget Function(BuildContext context, ElBacktop component)? backtopBuilder;

  /// 相等性与 hashCode 依据全部注入点。
  @override
  List<Object?> get props => _props;
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
