import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show Color, BoxShadow, Offset;

import '../../../../flutter.dart';
import '../../../dart/commons/index.dart' show El;
import '../../material/index.dart' show materialComponents;
import 'button/index.dart';
import 'button_group/index.dart';
import 'card/index.dart';
import 'checkbox/index.dart';
import 'list_tile/index.dart';
import 'loading/index.dart';
import 'progress/index.dart';
import 'radio/index.dart';
import 'skeleton/index.dart';
import 'slider/index.dart';
import 'switch/index.dart';
import 'tag/index.dart';
import 'input/index.dart';
import 'select/index.dart';
import 'autocomplete/index.dart';
import 'input_number/index.dart';
import 'segmented/index.dart';
import 'avatar/index.dart';
import 'calendar/index.dart';
import 'collapse/index.dart';
import 'empty/index.dart';
import 'steps/index.dart';
import 'tabs/index.dart';
import 'alert/index.dart';
import 'picker/index.dart';
import 'upload/index.dart';
import 'popup/index.dart';
import 'message/index.dart';
import 'app_bar/index.dart';
import 'tooltip/index.dart';
import 'popover/index.dart';
import 'popup_menu/index.dart';

part 'tokens.dart';

/// 移动品牌的组件和 token 预设。
extension ElMobileExt on El {
  /// 移动端默认组件及样式配置。
  ElComponents get mobileComponents => _components;
}

final _components = ElComponentsExt(materialComponents(mobile: true)).merge(
  ElComponents(
    style: ElStyle(
      vars: _lightVars,
      onDark: ElStyle(vars: _darkVars),
    ),
    button: buttonBuilder,
    checkbox: checkboxBuilder,
    radio: radioBuilder,
    buttonGroup: buttonGroupBuilder,
    card: cardBuilder,
    tag: tagBuilder,
    switcher: switchBuilder,
    listTile: listTileBuilder,
    listTileGroup: listTileGroupBuilder,
    loadingIndicator: loadingIndicatorBuilder,
    progress: progressBuilder,
    skeleton: skeletonBuilder,
    slider: sliderBuilder,
    input: inputBuilder,
    select: selectBuilder,
    autocomplete: autocompleteBuilder,
    inputNumber: inputNumberBuilder,
    formItem: formItemBuilder,
    segmented: segmentedBuilder,
    avatar: avatarBuilder,
    calendar: calendarBuilder,
    collapse: collapseBuilder,
    collapseItem: collapseItemBuilder,
    empty: emptyBuilder,
    steps: stepsBuilder,
    step: stepBuilder,
    tabs: tabsBuilder,
    tabBar: tabBarBuilder,
    alert: alertBuilder,
    picker: pickerBuilder,
    datePicker: datePickerBuilder,
    timePicker: timePickerBuilder,
    upload: uploadBuilder,
    dialog: dialogBuilder,
    drawer: drawerBuilder,
    toast: toastBuilder,
    message: messageBuilder,
    messageStack: messageStackBuilder,
    appBar: appBarBuilder,
    tooltip: tooltipBuilder,
    popover: popoverBuilder,
    popupMenu: popupMenuBuilder,
  ),
);
