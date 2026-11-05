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
  ),
);
