import 'package:flutter/widgets.dart';

import '../../../dart/commons/index.dart' show El;
import '../../material/index.dart' show materialComponents;
import '../../../flutter/components/tokens.dart' show ElThemeContextExt, ElTokens;
import '../../../flutter/components/index.dart' show ElComponents, ElComponentsExt;
import '../../../flutter/views/view/style/style.dart' show ElStyle;
import '../../../flutter/widgets/form/index.dart' show ElFormItemView;
import 'autocomplete/index.dart';
import 'button/index.dart';
import 'button_group/index.dart';
import 'card/index.dart';
import 'checkbox/index.dart';
import 'dialog/index.dart';
import 'input/index.dart';
import 'input_number/index.dart';
import 'input_otp/index.dart';
import 'input_tag/index.dart';
import 'mention/index.dart';
import 'message/index.dart';
import 'radio/index.dart';
import 'select/index.dart';
import 'switch/index.dart';
import 'table/index.dart';
import 'tag/index.dart';

part 'tokens.dart';

/// 桌面品牌的组件和 token 预设。
extension ElDesktopExt on El {
  /// 桌面组件使用的紧凑密度变量。
  static const $compact = '--el-desktop-compact';

  /// 桌面端默认组件及样式配置。
  ElComponents get desktopComponents => _components;
}

final _components = ElComponentsExt(materialComponents()).merge(
  ElComponents(
    style: ElStyle(
      vars: _lightVars,
      onDark: ElStyle(vars: _darkVars),
    ),
    button: (context, component, model) => Button(component, model),
    card: cardBuilder,
    checkbox: checkboxBuilder,
    radio: radioBuilder,
    tag: (context, component) => Tag(component),
    buttonGroup: <T>(context, component) => ButtonGroup<T>(component),
    switcher: (context, component, model) => Switch(component, model),
    input: (context, component) => Input(component, null),
    select: <T>(context, component) => Select<T>(component),
    autocomplete: <T>(context, component) => Autocomplete<T>(component),
    inputNumber: (context, component) => InputNumber(component),
    mention: <T>(context, component) => Mention<T>(component),
    inputTag: (context, component) => InputTag(component),
    inputOtp: (context, component) => InputOtp(component),
    message: messageBuilder,
    dialog: dialogBuilder,
    drawer: drawerBuilder,
    messageStack: messageStackBuilder,
    formItem: (context, component) => ElFormItemView(
      component: component,
      labelStyle: ElStyle(color: context.elTheme.textRegular, iconColor: context.elTheme.textRegular),
      errorStyle: ElStyle(color: context.elTheme.error, iconColor: context.elTheme.error),
    ),
    tableStyle: ElTableTheme.style,
  ),
);
