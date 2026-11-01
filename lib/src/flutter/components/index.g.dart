// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'index.dart';

// **************************************************************************
// _ModelGenerator
// **************************************************************************

extension ElComponentBuildersExt on ElComponentBuilders {
  ElComponentBuilders copyWith({
    Object? buttonBuilder = $absent,
    Object? tagBuilder = $absent,
    Object? buttonGroupBuilder = $absent,
    Object? switchBuilder = $absent,
    Object? inputBuilder = $absent,
    Object? checkboxBuilder = $absent,
    Object? radioBuilder = $absent,
    Object? selectBuilder = $absent,
    Object? autocompleteBuilder = $absent,
    Object? inputNumberBuilder = $absent,
    Object? mentionBuilder = $absent,
    Object? inputTagBuilder = $absent,
    Object? inputOtpBuilder = $absent,
    Object? formItemBuilder = $absent,
    Object? tableStyleBuilder = $absent,
    Object? textBuilder = $absent,
    Object? cardBuilder = $absent,
    Object? loadingIndicatorBuilder = $absent,
    Object? iconBuilder = $absent,
    Object? listTileBuilder = $absent,
    Object? listTileGroupBuilder = $absent,
    Object? stepsBuilder = $absent,
    Object? stepBuilder = $absent,
    Object? avatarBuilder = $absent,
    Object? calendarBuilder = $absent,
    Object? collapseBuilder = $absent,
    Object? collapseItemBuilder = $absent,
    Object? emptyBuilder = $absent,
    Object? progressBuilder = $absent,
    Object? segmentedBuilder = $absent,
    Object? sliderBuilder = $absent,
    Object? skeletonBuilder = $absent,
    Object? tabsBuilder = $absent,
    Object? tabBarBuilder = $absent,
    Object? alertBuilder = $absent,
  }) {
    return ElComponentBuilders(
      buttonBuilder: identical(buttonBuilder, $absent)
          ? this.buttonBuilder
          : buttonBuilder as Widget Function(BuildContext, ElButton)?,
      tagBuilder: identical(tagBuilder, $absent)
          ? this.tagBuilder
          : tagBuilder as Widget Function(BuildContext, ElTag)?,
      buttonGroupBuilder: identical(buttonGroupBuilder, $absent)
          ? this.buttonGroupBuilder
          : buttonGroupBuilder as Widget Function<T>(BuildContext, ElButtonGroup<T>)?,
      switchBuilder: identical(switchBuilder, $absent)
          ? this.switchBuilder
          : switchBuilder as Widget Function(BuildContext, ElSwitch)?,
      inputBuilder: identical(inputBuilder, $absent)
          ? this.inputBuilder
          : inputBuilder as Widget Function(BuildContext, ElInput)?,
      checkboxBuilder: identical(checkboxBuilder, $absent)
          ? this.checkboxBuilder
          : checkboxBuilder as Widget Function(BuildContext, ElCheckbox, ElCheckboxState)?,
      radioBuilder: identical(radioBuilder, $absent)
          ? this.radioBuilder
          : radioBuilder as Widget Function<T>(BuildContext, ElRadio<T>, ElRadioState)?,
      selectBuilder: identical(selectBuilder, $absent)
          ? this.selectBuilder
          : selectBuilder as Widget Function<T>(BuildContext, ElSelect<T>)?,
      autocompleteBuilder: identical(autocompleteBuilder, $absent)
          ? this.autocompleteBuilder
          : autocompleteBuilder as Widget Function<T>(BuildContext, ElAutocomplete<T>)?,
      inputNumberBuilder: identical(inputNumberBuilder, $absent)
          ? this.inputNumberBuilder
          : inputNumberBuilder as Widget Function(BuildContext, ElInputNumber)?,
      mentionBuilder: identical(mentionBuilder, $absent)
          ? this.mentionBuilder
          : mentionBuilder as Widget Function<T>(BuildContext, ElMention<T>)?,
      inputTagBuilder: identical(inputTagBuilder, $absent)
          ? this.inputTagBuilder
          : inputTagBuilder as Widget Function(BuildContext, ElInputTag)?,
      inputOtpBuilder: identical(inputOtpBuilder, $absent)
          ? this.inputOtpBuilder
          : inputOtpBuilder as Widget Function(BuildContext, ElInputOtp)?,
      formItemBuilder: identical(formItemBuilder, $absent)
          ? this.formItemBuilder
          : formItemBuilder as Widget Function(BuildContext, ElFormItem)?,
      tableStyleBuilder: identical(tableStyleBuilder, $absent)
          ? this.tableStyleBuilder
          : tableStyleBuilder as ElTableStyle Function(BuildContext)?,
      textBuilder: identical(textBuilder, $absent)
          ? this.textBuilder
          : textBuilder as Widget Function(BuildContext, ElText)?,
      cardBuilder: identical(cardBuilder, $absent)
          ? this.cardBuilder
          : cardBuilder as Widget Function(BuildContext, ElCard)?,
      loadingIndicatorBuilder: identical(loadingIndicatorBuilder, $absent)
          ? this.loadingIndicatorBuilder
          : loadingIndicatorBuilder as Widget Function(BuildContext, ElLoadingIndicator)?,
      iconBuilder: identical(iconBuilder, $absent)
          ? this.iconBuilder
          : iconBuilder as Widget Function(BuildContext, ElIcon)?,
      listTileBuilder: identical(listTileBuilder, $absent)
          ? this.listTileBuilder
          : listTileBuilder as Widget Function<T>(BuildContext, ElListTile<T>)?,
      listTileGroupBuilder: identical(listTileGroupBuilder, $absent)
          ? this.listTileGroupBuilder
          : listTileGroupBuilder as Widget Function<D>(BuildContext, ElListGroup<D>)?,
      stepsBuilder: identical(stepsBuilder, $absent)
          ? this.stepsBuilder
          : stepsBuilder as Widget Function(BuildContext, ElSteps)?,
      stepBuilder: identical(stepBuilder, $absent)
          ? this.stepBuilder
          : stepBuilder as Widget Function(BuildContext, ElStep)?,
      avatarBuilder: identical(avatarBuilder, $absent)
          ? this.avatarBuilder
          : avatarBuilder as Widget Function(BuildContext, ElAvatar)?,
      calendarBuilder: identical(calendarBuilder, $absent)
          ? this.calendarBuilder
          : calendarBuilder as Widget Function<D>(BuildContext, ElCalendar<D>)?,
      collapseBuilder: identical(collapseBuilder, $absent)
          ? this.collapseBuilder
          : collapseBuilder as Widget Function<D>(BuildContext, ElCollapse<D>)?,
      collapseItemBuilder: identical(collapseItemBuilder, $absent)
          ? this.collapseItemBuilder
          : collapseItemBuilder as Widget Function<T>(BuildContext, ElCollapseItem<T>)?,
      emptyBuilder: identical(emptyBuilder, $absent)
          ? this.emptyBuilder
          : emptyBuilder as Widget Function(BuildContext, ElEmpty)?,
      progressBuilder: identical(progressBuilder, $absent)
          ? this.progressBuilder
          : progressBuilder as Widget Function(BuildContext, ElProgress)?,
      segmentedBuilder: identical(segmentedBuilder, $absent)
          ? this.segmentedBuilder
          : segmentedBuilder as Widget Function<D>(BuildContext, ElSegmented<D>)?,
      sliderBuilder: identical(sliderBuilder, $absent)
          ? this.sliderBuilder
          : sliderBuilder as Widget Function<D>(BuildContext, ElSlider<D>)?,
      skeletonBuilder: identical(skeletonBuilder, $absent)
          ? this.skeletonBuilder
          : skeletonBuilder as Widget Function(BuildContext, ElSkeleton)?,
      tabsBuilder: identical(tabsBuilder, $absent)
          ? this.tabsBuilder
          : tabsBuilder as Widget Function<D>(BuildContext, ElTabs<D>)?,
      tabBarBuilder: identical(tabBarBuilder, $absent)
          ? this.tabBarBuilder
          : tabBarBuilder as Widget Function(BuildContext, ElTabBar)?,
      alertBuilder: identical(alertBuilder, $absent)
          ? this.alertBuilder
          : alertBuilder as Widget Function(BuildContext, ElAlert)?,
    );
  }

  ElComponentBuilders merge([ElComponentBuilders? other]) {
    if (other == null) return this;
    return ElComponentBuilders(
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
      loadingIndicatorBuilder: other.loadingIndicatorBuilder ?? loadingIndicatorBuilder,
      iconBuilder: other.iconBuilder ?? iconBuilder,
      listTileBuilder: other.listTileBuilder ?? listTileBuilder,
      listTileGroupBuilder: other.listTileGroupBuilder ?? listTileGroupBuilder,
      stepsBuilder: other.stepsBuilder ?? stepsBuilder,
      stepBuilder: other.stepBuilder ?? stepBuilder,
      avatarBuilder: other.avatarBuilder ?? avatarBuilder,
      calendarBuilder: other.calendarBuilder ?? calendarBuilder,
      collapseBuilder: other.collapseBuilder ?? collapseBuilder,
      collapseItemBuilder: other.collapseItemBuilder ?? collapseItemBuilder,
      emptyBuilder: other.emptyBuilder ?? emptyBuilder,
      progressBuilder: other.progressBuilder ?? progressBuilder,
      segmentedBuilder: other.segmentedBuilder ?? segmentedBuilder,
      sliderBuilder: other.sliderBuilder ?? sliderBuilder,
      skeletonBuilder: other.skeletonBuilder ?? skeletonBuilder,
      tabsBuilder: other.tabsBuilder ?? tabsBuilder,
      tabBarBuilder: other.tabBarBuilder ?? tabBarBuilder,
      alertBuilder: other.alertBuilder ?? alertBuilder,
    );
  }

  List<Object?> get _props => [
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
    stepsBuilder,
    stepBuilder,
    avatarBuilder,
    calendarBuilder,
    collapseBuilder,
    collapseItemBuilder,
    emptyBuilder,
    progressBuilder,
    segmentedBuilder,
    sliderBuilder,
    skeletonBuilder,
    tabsBuilder,
    tabBarBuilder,
    alertBuilder,
  ];
}
