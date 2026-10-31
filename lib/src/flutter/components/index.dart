import 'package:flutter/widgets.dart';

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

const _absent = Object();

/// 通用组件实现登记表；新增声明的默认 Builder 为空，品牌实现另行安装。
class ElComponentBuilders {
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
  final Widget Function(BuildContext context, ElButton component)?
  buttonBuilder;

  /// 根据 ElTag 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTag component)? tagBuilder;

  /// 根据 ElButtonGroup 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElButtonGroup<T> component)?
  buttonGroupBuilder;

  /// 根据 ElSwitch 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSwitch component)?
  switchBuilder;

  /// 根据 ElInput 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInput component)? inputBuilder;

  /// 根据 ElCheckbox 声明构建品牌组件。
  final Widget Function(
    BuildContext context,
    ElCheckbox component,
    ElCheckboxState state,
  )?
  checkboxBuilder;

  /// 根据 ElRadio 声明构建品牌组件。
  final Widget Function<T>(
    BuildContext context,
    ElRadio<T> component,
    ElRadioState state,
  )?
  radioBuilder;

  /// 根据 ElSelect 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElSelect<T> component)?
  selectBuilder;

  /// 根据 ElAutocomplete 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElAutocomplete<T> component)?
  autocompleteBuilder;

  /// 根据 ElInputNumber 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputNumber component)?
  inputNumberBuilder;

  /// 根据 ElMention 声明构建品牌组件。
  final Widget Function<T>(BuildContext context, ElMention<T> component)?
  mentionBuilder;

  /// 根据 ElInputTag 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputTag component)?
  inputTagBuilder;

  /// 根据 ElInputOtp 声明构建品牌组件。
  final Widget Function(BuildContext context, ElInputOtp component)?
  inputOtpBuilder;

  /// 根据 ElFormItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElFormItem component)?
  formItemBuilder;

  /// 创建表格皮肤，表格行为继续由通用内核承担。
  final ElTableStyle Function(BuildContext context)? tableStyleBuilder;

  /// 根据 ElText 声明构建品牌组件。
  final Widget Function(BuildContext context, ElText component)? textBuilder;

  /// 根据 ElCard 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCard component)? cardBuilder;

  /// 根据 ElLoadingIndicator 声明构建品牌组件。
  final Widget Function(BuildContext context, ElLoadingIndicator component)?
  loadingIndicatorBuilder;

  /// 根据 ElIcon 声明构建品牌组件。
  final Widget Function(BuildContext context, ElIcon component)? iconBuilder;

  /// 根据 ElListTile 声明构建品牌组件。
  final Widget Function(BuildContext context, ElListTile component)?
  listTileBuilder;

  /// 根据 ElListTileGroup 声明构建品牌组件。
  final Widget Function(BuildContext context, ElListTileGroup component)?
  listTileGroupBuilder;

  /// 根据 ElAnchor 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAnchor component)?
  anchorBuilder;

  /// 根据 ElAffix 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAffix component)? affixBuilder;

  /// 根据 ElSteps 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSteps component)? stepsBuilder;

  /// 根据 ElStep 声明构建品牌组件。
  final Widget Function(BuildContext context, ElStep component)? stepBuilder;

  /// 根据 ElAvatar 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAvatar component)?
  avatarBuilder;

  /// 根据 ElAvatarGroup 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAvatarGroup component)?
  avatarGroupBuilder;

  /// 根据 ElCalendar 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCalendar component)?
  calendarBuilder;

  /// 根据 ElCarousel 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCarousel component)?
  carouselBuilder;

  /// 根据 ElCollapse 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCollapse component)?
  collapseBuilder;

  /// 根据 ElCollapseItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCollapseItem component)?
  collapseItemBuilder;

  /// 根据 ElCountdown 声明构建品牌组件。
  final Widget Function(BuildContext context, ElCountdown component)?
  countdownBuilder;

  /// 根据 ElDescriptions 声明构建品牌组件。
  final Widget Function(BuildContext context, ElDescriptions component)?
  descriptionsBuilder;

  /// 根据 ElEmpty 声明构建品牌组件。
  final Widget Function(BuildContext context, ElEmpty component)? emptyBuilder;

  /// 根据 ElPagination 声明构建品牌组件。
  final Widget Function(BuildContext context, ElPagination component)?
  paginationBuilder;

  /// 根据 ElProgress 声明构建品牌组件。
  final Widget Function(BuildContext context, ElProgress component)?
  progressBuilder;

  /// 根据 ElRate 声明构建品牌组件。
  final Widget Function(BuildContext context, ElRate component)? rateBuilder;

  /// 根据 ElSegmented 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSegmented component)?
  segmentedBuilder;

  /// 根据 ElSlider 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSlider component)?
  sliderBuilder;

  /// 根据 ElSkeleton 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSkeleton component)?
  skeletonBuilder;

  /// 根据 ElSkeletonItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElSkeletonItem component)?
  skeletonItemBuilder;

  /// 根据 ElStatistic 声明构建品牌组件。
  final Widget Function(BuildContext context, ElStatistic component)?
  statisticBuilder;

  /// 根据 ElTabs 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTabs component)? tabsBuilder;

  /// 根据 ElTabBar 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTabBar component)?
  tabBarBuilder;

  /// 根据 ElTimeline 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTimeline component)?
  timelineBuilder;

  /// 根据 ElTimelineItem 声明构建品牌组件。
  final Widget Function(BuildContext context, ElTimelineItem component)?
  timelineItemBuilder;

  /// 根据 ElAlert 声明构建品牌组件。
  final Widget Function(BuildContext context, ElAlert component)? alertBuilder;

  /// 根据 ElResult 声明构建品牌组件。
  final Widget Function(BuildContext context, ElResult component)?
  resultBuilder;

  /// 根据 ElBacktop 声明构建品牌组件。
  final Widget Function(BuildContext context, ElBacktop component)?
  backtopBuilder;

  /// 省略参数保留原值，显式 null 清空对应实现。
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
    Object? cardBuilder = _absent,
    Object? loadingIndicatorBuilder = _absent,
    Object? iconBuilder = _absent,
    Object? listTileBuilder = _absent,
    Object? listTileGroupBuilder = _absent,
    Object? anchorBuilder = _absent,
    Object? affixBuilder = _absent,
    Object? stepsBuilder = _absent,
    Object? stepBuilder = _absent,
    Object? avatarBuilder = _absent,
    Object? avatarGroupBuilder = _absent,
    Object? calendarBuilder = _absent,
    Object? carouselBuilder = _absent,
    Object? collapseBuilder = _absent,
    Object? collapseItemBuilder = _absent,
    Object? countdownBuilder = _absent,
    Object? descriptionsBuilder = _absent,
    Object? emptyBuilder = _absent,
    Object? paginationBuilder = _absent,
    Object? progressBuilder = _absent,
    Object? rateBuilder = _absent,
    Object? segmentedBuilder = _absent,
    Object? sliderBuilder = _absent,
    Object? skeletonBuilder = _absent,
    Object? skeletonItemBuilder = _absent,
    Object? statisticBuilder = _absent,
    Object? tabsBuilder = _absent,
    Object? tabBarBuilder = _absent,
    Object? timelineBuilder = _absent,
    Object? timelineItemBuilder = _absent,
    Object? alertBuilder = _absent,
    Object? resultBuilder = _absent,
    Object? backtopBuilder = _absent,
  }) => ElComponentBuilders(
    buttonBuilder: identical(buttonBuilder, _absent)
        ? this.buttonBuilder
        : buttonBuilder
              as Widget Function(BuildContext context, ElButton component)?,
    tagBuilder: identical(tagBuilder, _absent)
        ? this.tagBuilder
        : tagBuilder as Widget Function(BuildContext context, ElTag component)?,
    buttonGroupBuilder: identical(buttonGroupBuilder, _absent)
        ? this.buttonGroupBuilder
        : buttonGroupBuilder
              as Widget Function<T>(
                BuildContext context,
                ElButtonGroup<T> component,
              )?,
    switchBuilder: identical(switchBuilder, _absent)
        ? this.switchBuilder
        : switchBuilder
              as Widget Function(BuildContext context, ElSwitch component)?,
    inputBuilder: identical(inputBuilder, _absent)
        ? this.inputBuilder
        : inputBuilder
              as Widget Function(BuildContext context, ElInput component)?,
    checkboxBuilder: identical(checkboxBuilder, _absent)
        ? this.checkboxBuilder
        : checkboxBuilder
              as Widget Function(
                BuildContext context,
                ElCheckbox component,
                ElCheckboxState state,
              )?,
    radioBuilder: identical(radioBuilder, _absent)
        ? this.radioBuilder
        : radioBuilder
              as Widget Function<T>(
                BuildContext context,
                ElRadio<T> component,
                ElRadioState state,
              )?,
    selectBuilder: identical(selectBuilder, _absent)
        ? this.selectBuilder
        : selectBuilder
              as Widget Function<T>(
                BuildContext context,
                ElSelect<T> component,
              )?,
    autocompleteBuilder: identical(autocompleteBuilder, _absent)
        ? this.autocompleteBuilder
        : autocompleteBuilder
              as Widget Function<T>(
                BuildContext context,
                ElAutocomplete<T> component,
              )?,
    inputNumberBuilder: identical(inputNumberBuilder, _absent)
        ? this.inputNumberBuilder
        : inputNumberBuilder
              as Widget Function(
                BuildContext context,
                ElInputNumber component,
              )?,
    mentionBuilder: identical(mentionBuilder, _absent)
        ? this.mentionBuilder
        : mentionBuilder
              as Widget Function<T>(
                BuildContext context,
                ElMention<T> component,
              )?,
    inputTagBuilder: identical(inputTagBuilder, _absent)
        ? this.inputTagBuilder
        : inputTagBuilder
              as Widget Function(BuildContext context, ElInputTag component)?,
    inputOtpBuilder: identical(inputOtpBuilder, _absent)
        ? this.inputOtpBuilder
        : inputOtpBuilder
              as Widget Function(BuildContext context, ElInputOtp component)?,
    formItemBuilder: identical(formItemBuilder, _absent)
        ? this.formItemBuilder
        : formItemBuilder
              as Widget Function(BuildContext context, ElFormItem component)?,
    tableStyleBuilder: identical(tableStyleBuilder, _absent)
        ? this.tableStyleBuilder
        : tableStyleBuilder as ElTableStyle Function(BuildContext context)?,
    textBuilder: identical(textBuilder, _absent)
        ? this.textBuilder
        : textBuilder
              as Widget Function(BuildContext context, ElText component)?,
    cardBuilder: identical(cardBuilder, _absent)
        ? this.cardBuilder
        : cardBuilder
              as Widget Function(BuildContext context, ElCard component)?,
    loadingIndicatorBuilder: identical(loadingIndicatorBuilder, _absent)
        ? this.loadingIndicatorBuilder
        : loadingIndicatorBuilder
              as Widget Function(
                BuildContext context,
                ElLoadingIndicator component,
              )?,
    iconBuilder: identical(iconBuilder, _absent)
        ? this.iconBuilder
        : iconBuilder
              as Widget Function(BuildContext context, ElIcon component)?,
    listTileBuilder: identical(listTileBuilder, _absent)
        ? this.listTileBuilder
        : listTileBuilder
              as Widget Function(BuildContext context, ElListTile component)?,
    listTileGroupBuilder: identical(listTileGroupBuilder, _absent)
        ? this.listTileGroupBuilder
        : listTileGroupBuilder
              as Widget Function(
                BuildContext context,
                ElListTileGroup component,
              )?,
    anchorBuilder: identical(anchorBuilder, _absent)
        ? this.anchorBuilder
        : anchorBuilder
              as Widget Function(BuildContext context, ElAnchor component)?,
    affixBuilder: identical(affixBuilder, _absent)
        ? this.affixBuilder
        : affixBuilder
              as Widget Function(BuildContext context, ElAffix component)?,
    stepsBuilder: identical(stepsBuilder, _absent)
        ? this.stepsBuilder
        : stepsBuilder
              as Widget Function(BuildContext context, ElSteps component)?,
    stepBuilder: identical(stepBuilder, _absent)
        ? this.stepBuilder
        : stepBuilder
              as Widget Function(BuildContext context, ElStep component)?,
    avatarBuilder: identical(avatarBuilder, _absent)
        ? this.avatarBuilder
        : avatarBuilder
              as Widget Function(BuildContext context, ElAvatar component)?,
    avatarGroupBuilder: identical(avatarGroupBuilder, _absent)
        ? this.avatarGroupBuilder
        : avatarGroupBuilder
              as Widget Function(
                BuildContext context,
                ElAvatarGroup component,
              )?,
    calendarBuilder: identical(calendarBuilder, _absent)
        ? this.calendarBuilder
        : calendarBuilder
              as Widget Function(BuildContext context, ElCalendar component)?,
    carouselBuilder: identical(carouselBuilder, _absent)
        ? this.carouselBuilder
        : carouselBuilder
              as Widget Function(BuildContext context, ElCarousel component)?,
    collapseBuilder: identical(collapseBuilder, _absent)
        ? this.collapseBuilder
        : collapseBuilder
              as Widget Function(BuildContext context, ElCollapse component)?,
    collapseItemBuilder: identical(collapseItemBuilder, _absent)
        ? this.collapseItemBuilder
        : collapseItemBuilder
              as Widget Function(
                BuildContext context,
                ElCollapseItem component,
              )?,
    countdownBuilder: identical(countdownBuilder, _absent)
        ? this.countdownBuilder
        : countdownBuilder
              as Widget Function(BuildContext context, ElCountdown component)?,
    descriptionsBuilder: identical(descriptionsBuilder, _absent)
        ? this.descriptionsBuilder
        : descriptionsBuilder
              as Widget Function(
                BuildContext context,
                ElDescriptions component,
              )?,
    emptyBuilder: identical(emptyBuilder, _absent)
        ? this.emptyBuilder
        : emptyBuilder
              as Widget Function(BuildContext context, ElEmpty component)?,
    paginationBuilder: identical(paginationBuilder, _absent)
        ? this.paginationBuilder
        : paginationBuilder
              as Widget Function(BuildContext context, ElPagination component)?,
    progressBuilder: identical(progressBuilder, _absent)
        ? this.progressBuilder
        : progressBuilder
              as Widget Function(BuildContext context, ElProgress component)?,
    rateBuilder: identical(rateBuilder, _absent)
        ? this.rateBuilder
        : rateBuilder
              as Widget Function(BuildContext context, ElRate component)?,
    segmentedBuilder: identical(segmentedBuilder, _absent)
        ? this.segmentedBuilder
        : segmentedBuilder
              as Widget Function(BuildContext context, ElSegmented component)?,
    sliderBuilder: identical(sliderBuilder, _absent)
        ? this.sliderBuilder
        : sliderBuilder
              as Widget Function(BuildContext context, ElSlider component)?,
    skeletonBuilder: identical(skeletonBuilder, _absent)
        ? this.skeletonBuilder
        : skeletonBuilder
              as Widget Function(BuildContext context, ElSkeleton component)?,
    skeletonItemBuilder: identical(skeletonItemBuilder, _absent)
        ? this.skeletonItemBuilder
        : skeletonItemBuilder
              as Widget Function(
                BuildContext context,
                ElSkeletonItem component,
              )?,
    statisticBuilder: identical(statisticBuilder, _absent)
        ? this.statisticBuilder
        : statisticBuilder
              as Widget Function(BuildContext context, ElStatistic component)?,
    tabsBuilder: identical(tabsBuilder, _absent)
        ? this.tabsBuilder
        : tabsBuilder
              as Widget Function(BuildContext context, ElTabs component)?,
    tabBarBuilder: identical(tabBarBuilder, _absent)
        ? this.tabBarBuilder
        : tabBarBuilder
              as Widget Function(BuildContext context, ElTabBar component)?,
    timelineBuilder: identical(timelineBuilder, _absent)
        ? this.timelineBuilder
        : timelineBuilder
              as Widget Function(BuildContext context, ElTimeline component)?,
    timelineItemBuilder: identical(timelineItemBuilder, _absent)
        ? this.timelineItemBuilder
        : timelineItemBuilder
              as Widget Function(
                BuildContext context,
                ElTimelineItem component,
              )?,
    alertBuilder: identical(alertBuilder, _absent)
        ? this.alertBuilder
        : alertBuilder
              as Widget Function(BuildContext context, ElAlert component)?,
    resultBuilder: identical(resultBuilder, _absent)
        ? this.resultBuilder
        : resultBuilder
              as Widget Function(BuildContext context, ElResult component)?,
    backtopBuilder: identical(backtopBuilder, _absent)
        ? this.backtopBuilder
        : backtopBuilder
              as Widget Function(BuildContext context, ElBacktop component)?,
  );

  /// 以非空项覆盖现有配置，空项保留原实现。
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
          cardBuilder: other.cardBuilder ?? cardBuilder,
          loadingIndicatorBuilder:
              other.loadingIndicatorBuilder ?? loadingIndicatorBuilder,
          iconBuilder: other.iconBuilder ?? iconBuilder,
          listTileBuilder: other.listTileBuilder ?? listTileBuilder,
          listTileGroupBuilder:
              other.listTileGroupBuilder ?? listTileGroupBuilder,
          anchorBuilder: other.anchorBuilder ?? anchorBuilder,
          affixBuilder: other.affixBuilder ?? affixBuilder,
          stepsBuilder: other.stepsBuilder ?? stepsBuilder,
          stepBuilder: other.stepBuilder ?? stepBuilder,
          avatarBuilder: other.avatarBuilder ?? avatarBuilder,
          avatarGroupBuilder: other.avatarGroupBuilder ?? avatarGroupBuilder,
          calendarBuilder: other.calendarBuilder ?? calendarBuilder,
          carouselBuilder: other.carouselBuilder ?? carouselBuilder,
          collapseBuilder: other.collapseBuilder ?? collapseBuilder,
          collapseItemBuilder: other.collapseItemBuilder ?? collapseItemBuilder,
          countdownBuilder: other.countdownBuilder ?? countdownBuilder,
          descriptionsBuilder: other.descriptionsBuilder ?? descriptionsBuilder,
          emptyBuilder: other.emptyBuilder ?? emptyBuilder,
          paginationBuilder: other.paginationBuilder ?? paginationBuilder,
          progressBuilder: other.progressBuilder ?? progressBuilder,
          rateBuilder: other.rateBuilder ?? rateBuilder,
          segmentedBuilder: other.segmentedBuilder ?? segmentedBuilder,
          sliderBuilder: other.sliderBuilder ?? sliderBuilder,
          skeletonBuilder: other.skeletonBuilder ?? skeletonBuilder,
          skeletonItemBuilder: other.skeletonItemBuilder ?? skeletonItemBuilder,
          statisticBuilder: other.statisticBuilder ?? statisticBuilder,
          tabsBuilder: other.tabsBuilder ?? tabsBuilder,
          tabBarBuilder: other.tabBarBuilder ?? tabBarBuilder,
          timelineBuilder: other.timelineBuilder ?? timelineBuilder,
          timelineItemBuilder: other.timelineItemBuilder ?? timelineItemBuilder,
          alertBuilder: other.alertBuilder ?? alertBuilder,
          resultBuilder: other.resultBuilder ?? resultBuilder,
          backtopBuilder: other.backtopBuilder ?? backtopBuilder,
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
          textBuilder == other.textBuilder &&
          cardBuilder == other.cardBuilder &&
          loadingIndicatorBuilder == other.loadingIndicatorBuilder &&
          iconBuilder == other.iconBuilder &&
          listTileBuilder == other.listTileBuilder &&
          listTileGroupBuilder == other.listTileGroupBuilder &&
          anchorBuilder == other.anchorBuilder &&
          affixBuilder == other.affixBuilder &&
          stepsBuilder == other.stepsBuilder &&
          stepBuilder == other.stepBuilder &&
          avatarBuilder == other.avatarBuilder &&
          avatarGroupBuilder == other.avatarGroupBuilder &&
          calendarBuilder == other.calendarBuilder &&
          carouselBuilder == other.carouselBuilder &&
          collapseBuilder == other.collapseBuilder &&
          collapseItemBuilder == other.collapseItemBuilder &&
          countdownBuilder == other.countdownBuilder &&
          descriptionsBuilder == other.descriptionsBuilder &&
          emptyBuilder == other.emptyBuilder &&
          paginationBuilder == other.paginationBuilder &&
          progressBuilder == other.progressBuilder &&
          rateBuilder == other.rateBuilder &&
          segmentedBuilder == other.segmentedBuilder &&
          sliderBuilder == other.sliderBuilder &&
          skeletonBuilder == other.skeletonBuilder &&
          skeletonItemBuilder == other.skeletonItemBuilder &&
          statisticBuilder == other.statisticBuilder &&
          tabsBuilder == other.tabsBuilder &&
          tabBarBuilder == other.tabBarBuilder &&
          timelineBuilder == other.timelineBuilder &&
          timelineItemBuilder == other.timelineItemBuilder &&
          alertBuilder == other.alertBuilder &&
          resultBuilder == other.resultBuilder &&
          backtopBuilder == other.backtopBuilder;

  @override
  int get hashCode => Object.hashAll([
    buttonBuilder,
    tagBuilder,
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
    cardBuilder,
    loadingIndicatorBuilder,
    iconBuilder,
    listTileBuilder,
    listTileGroupBuilder,
    anchorBuilder,
    affixBuilder,
    stepsBuilder,
    stepBuilder,
    avatarBuilder,
    avatarGroupBuilder,
    calendarBuilder,
    carouselBuilder,
    collapseBuilder,
    collapseItemBuilder,
    countdownBuilder,
    descriptionsBuilder,
    emptyBuilder,
    paginationBuilder,
    progressBuilder,
    rateBuilder,
    segmentedBuilder,
    sliderBuilder,
    skeletonBuilder,
    skeletonItemBuilder,
    statisticBuilder,
    tabsBuilder,
    tabBarBuilder,
    timelineBuilder,
    timelineItemBuilder,
    alertBuilder,
    resultBuilder,
    backtopBuilder,
  ]);
}

/// 提供最近的完整组件实现配置，可随弹层捕获快照。
class ElComponentProvider extends InheritedTheme {
  /// 创建组件实现作用域；需要继承时在传入前显式合并。
  const ElComponentProvider({
    super.key,
    required this.builders,
    required super.child,
  });

  /// 当前作用域的组件实现配置。
  final ElComponentBuilders builders;

  /// 读取最近的组件配置，必须存在祖先组件提供器。
  static ElComponentBuilders of(BuildContext context) {
    final builders = maybeOf(context);
    assert(builders != null, '当前上下文未找到 ElComponentProvider。');
    return builders!;
  }

  /// 读取可选的组件配置，独立通用 Widget 可在未登记品牌时使用自身默认布局。
  static ElComponentBuilders? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ElComponentProvider>()
      ?.builders;

  @override
  bool updateShouldNotify(ElComponentProvider oldWidget) =>
      builders != oldWidget.builders;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      ElComponentProvider(builders: builders, child: child);
}
