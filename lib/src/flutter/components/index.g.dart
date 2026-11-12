// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'index.dart';

// **************************************************************************
// _ModelGenerator
// **************************************************************************

extension ElComponentsExt on ElComponents {
  ElComponents copyWith({
    Object? style = $absent,
    Object? button = $absent,
    Object? tag = $absent,
    Object? buttonGroup = $absent,
    Object? switcher = $absent,
    Object? input = $absent,
    Object? checkbox = $absent,
    Object? radio = $absent,
    Object? select = $absent,
    Object? autocomplete = $absent,
    Object? inputNumber = $absent,
    Object? mention = $absent,
    Object? inputTag = $absent,
    Object? inputOtp = $absent,
    Object? formItem = $absent,
    Object? tableStyle = $absent,
    Object? card = $absent,
    Object? loadingIndicator = $absent,
    Object? listTile = $absent,
    Object? listTileGroup = $absent,
    Object? progress = $absent,
    Object? slider = $absent,
    Object? skeleton = $absent,
    Object? steps = $absent,
    Object? step = $absent,
    Object? avatar = $absent,
    Object? calendar = $absent,
    Object? collapse = $absent,
    Object? collapseItem = $absent,
    Object? empty = $absent,
    Object? segmented = $absent,
    Object? tabs = $absent,
    Object? tabBar = $absent,
    Object? alert = $absent,
    Object? picker = $absent,
    Object? datePicker = $absent,
    Object? timePicker = $absent,
    Object? upload = $absent,
    Object? popup = $absent,
    Object? dialog = $absent,
    Object? drawer = $absent,
    Object? toast = $absent,
    Object? appBar = $absent,
    Object? tooltip = $absent,
  }) {
    return ElComponents(
      style: identical(style, $absent)
          ? this.style
          : (style == null
                ? null
                : (this.style == null
                      ? style as ElStyle
                      : this.style!.merge(style as ElStyle))),
      button: identical(button, $absent)
          ? this.button
          : button as Widget Function(BuildContext, ElButton, Obs<bool>)?,
      tag: identical(tag, $absent)
          ? this.tag
          : tag as Widget Function(BuildContext, ElTag)?,
      buttonGroup: identical(buttonGroup, $absent)
          ? this.buttonGroup
          : buttonGroup as Widget Function<T>(BuildContext, ElButtonGroup<T>)?,
      switcher: identical(switcher, $absent)
          ? this.switcher
          : switcher as Widget Function(BuildContext, ElSwitch, Obs<bool>)?,
      input: identical(input, $absent)
          ? this.input
          : input as Widget Function(BuildContext, ElInput)?,
      checkbox: identical(checkbox, $absent)
          ? this.checkbox
          : checkbox
                as Widget Function(BuildContext, ElCheckbox, ElCheckboxState)?,
      radio: identical(radio, $absent)
          ? this.radio
          : radio
                as Widget Function<T>(BuildContext, ElRadio<T>, ElRadioState)?,
      select: identical(select, $absent)
          ? this.select
          : select as Widget Function<T>(BuildContext, ElSelect<T>)?,
      autocomplete: identical(autocomplete, $absent)
          ? this.autocomplete
          : autocomplete
                as Widget Function<T>(BuildContext, ElAutocomplete<T>)?,
      inputNumber: identical(inputNumber, $absent)
          ? this.inputNumber
          : inputNumber as Widget Function(BuildContext, ElInputNumber)?,
      mention: identical(mention, $absent)
          ? this.mention
          : mention as Widget Function<T>(BuildContext, ElMention<T>)?,
      inputTag: identical(inputTag, $absent)
          ? this.inputTag
          : inputTag as Widget Function(BuildContext, ElInputTag)?,
      inputOtp: identical(inputOtp, $absent)
          ? this.inputOtp
          : inputOtp as Widget Function(BuildContext, ElInputOtp)?,
      formItem: identical(formItem, $absent)
          ? this.formItem
          : formItem as Widget Function(BuildContext, ElFormItem)?,
      tableStyle: identical(tableStyle, $absent)
          ? this.tableStyle
          : tableStyle as ElTableStyle Function(BuildContext)?,
      card: identical(card, $absent)
          ? this.card
          : card as Widget Function(BuildContext, ElCard)?,
      loadingIndicator: identical(loadingIndicator, $absent)
          ? this.loadingIndicator
          : loadingIndicator
                as Widget Function(BuildContext, ElLoadingIndicator)?,
      listTile: identical(listTile, $absent)
          ? this.listTile
          : listTile as Widget Function<T>(BuildContext, ElListTile<T>)?,
      listTileGroup: identical(listTileGroup, $absent)
          ? this.listTileGroup
          : listTileGroup as Widget Function<D>(BuildContext, ElListGroup<D>)?,
      progress: identical(progress, $absent)
          ? this.progress
          : progress as Widget Function(BuildContext, ElProgress)?,
      slider: identical(slider, $absent)
          ? this.slider
          : slider as Widget Function<D>(BuildContext, ElSlider<D>)?,
      skeleton: identical(skeleton, $absent)
          ? this.skeleton
          : skeleton as Widget Function(BuildContext, ElSkeleton)?,
      steps: identical(steps, $absent)
          ? this.steps
          : steps as Widget Function(BuildContext, ElSteps)?,
      step: identical(step, $absent)
          ? this.step
          : step as Widget Function(BuildContext, ElStep)?,
      avatar: identical(avatar, $absent)
          ? this.avatar
          : avatar as Widget Function(BuildContext, ElAvatar)?,
      calendar: identical(calendar, $absent)
          ? this.calendar
          : calendar as Widget Function<D>(BuildContext, ElCalendar<D>)?,
      collapse: identical(collapse, $absent)
          ? this.collapse
          : collapse as Widget Function<D>(BuildContext, ElCollapse<D>)?,
      collapseItem: identical(collapseItem, $absent)
          ? this.collapseItem
          : collapseItem
                as Widget Function<T>(BuildContext, ElCollapseItem<T>)?,
      empty: identical(empty, $absent)
          ? this.empty
          : empty as Widget Function(BuildContext, ElEmpty)?,
      segmented: identical(segmented, $absent)
          ? this.segmented
          : segmented as Widget Function<D>(BuildContext, ElSegmented<D>)?,
      tabs: identical(tabs, $absent)
          ? this.tabs
          : tabs as Widget Function<D>(BuildContext, ElTabs<D>)?,
      tabBar: identical(tabBar, $absent)
          ? this.tabBar
          : tabBar as Widget Function(BuildContext, ElTabBar)?,
      alert: identical(alert, $absent)
          ? this.alert
          : alert as Widget Function(BuildContext, ElAlert)?,
      picker: identical(picker, $absent)
          ? this.picker
          : picker
                as Widget Function<T>(BuildContext, ElPicker<T>, Obs<List<T>>)?,
      datePicker: identical(datePicker, $absent)
          ? this.datePicker
          : datePicker
                as Widget Function(BuildContext, ElDatePicker, Obs<DateTime>)?,
      timePicker: identical(timePicker, $absent)
          ? this.timePicker
          : timePicker
                as Widget Function(BuildContext, ElTimePicker, Obs<Duration>)?,
      upload: identical(upload, $absent)
          ? this.upload
          : upload as Widget Function(BuildContext, ElUpload)?,
      popup: identical(popup, $absent)
          ? this.popup
          : popup as Widget Function(BuildContext, ElPopup)?,
      dialog: identical(dialog, $absent)
          ? this.dialog
          : dialog as Widget Function(BuildContext, ElDialog)?,
      drawer: identical(drawer, $absent)
          ? this.drawer
          : drawer as Widget Function(BuildContext, ElDrawer)?,
      toast: identical(toast, $absent)
          ? this.toast
          : toast as Widget Function(BuildContext, ElToast)?,
      appBar: identical(appBar, $absent)
          ? this.appBar
          : appBar as Widget Function(BuildContext, ElAppBar)?,
      tooltip: identical(tooltip, $absent)
          ? this.tooltip
          : tooltip as Widget Function(BuildContext, ElTooltip)?,
    );
  }

  ElComponents merge([ElComponents? other]) {
    if (other == null) return this;
    return ElComponents(
      style: style == null ? other.style : style!.merge(other.style),
      button: other.button ?? button,
      tag: other.tag ?? tag,
      buttonGroup: other.buttonGroup ?? buttonGroup,
      switcher: other.switcher ?? switcher,
      input: other.input ?? input,
      checkbox: other.checkbox ?? checkbox,
      radio: other.radio ?? radio,
      select: other.select ?? select,
      autocomplete: other.autocomplete ?? autocomplete,
      inputNumber: other.inputNumber ?? inputNumber,
      mention: other.mention ?? mention,
      inputTag: other.inputTag ?? inputTag,
      inputOtp: other.inputOtp ?? inputOtp,
      formItem: other.formItem ?? formItem,
      tableStyle: other.tableStyle ?? tableStyle,
      card: other.card ?? card,
      loadingIndicator: other.loadingIndicator ?? loadingIndicator,
      listTile: other.listTile ?? listTile,
      listTileGroup: other.listTileGroup ?? listTileGroup,
      progress: other.progress ?? progress,
      slider: other.slider ?? slider,
      skeleton: other.skeleton ?? skeleton,
      steps: other.steps ?? steps,
      step: other.step ?? step,
      avatar: other.avatar ?? avatar,
      calendar: other.calendar ?? calendar,
      collapse: other.collapse ?? collapse,
      collapseItem: other.collapseItem ?? collapseItem,
      empty: other.empty ?? empty,
      segmented: other.segmented ?? segmented,
      tabs: other.tabs ?? tabs,
      tabBar: other.tabBar ?? tabBar,
      alert: other.alert ?? alert,
      picker: other.picker ?? picker,
      datePicker: other.datePicker ?? datePicker,
      timePicker: other.timePicker ?? timePicker,
      upload: other.upload ?? upload,
      popup: other.popup ?? popup,
      dialog: other.dialog ?? dialog,
      drawer: other.drawer ?? drawer,
      toast: other.toast ?? toast,
      appBar: other.appBar ?? appBar,
      tooltip: other.tooltip ?? tooltip,
    );
  }

  List<Object?> get _props => [
    style,
    button,
    tag,
    buttonGroup,
    switcher,
    input,
    checkbox,
    radio,
    select,
    autocomplete,
    inputNumber,
    mention,
    inputTag,
    inputOtp,
    formItem,
    tableStyle,
    card,
    loadingIndicator,
    listTile,
    listTileGroup,
    progress,
    slider,
    skeleton,
    steps,
    step,
    avatar,
    calendar,
    collapse,
    collapseItem,
    empty,
    segmented,
    tabs,
    tabBar,
    alert,
    picker,
    datePicker,
    timePicker,
    upload,
    popup,
    dialog,
    drawer,
    toast,
    appBar,
    tooltip,
  ];
}
