import '../../../dart/commons/index.dart' show El;
import '../../../flutter/components/index.dart' show ElComponents;
import 'button/index.dart';
import 'card/index.dart';
import 'icon/index.dart';
import 'list_tile/index.dart';
import 'loading/index.dart';
import 'progress/index.dart';
import 'skeleton/index.dart';
import 'slider/index.dart';
import 'switch/index.dart';
import 'tag/index.dart';

extension ElMobileExt on El {
  /// 全局默认的移动端组件实现
  ElComponents get mobileComponents => _components;
}

const _components = ElComponents(
  button: buttonBuilder,
  card: cardBuilder,
  tag: tagBuilder,
  switcher: switchBuilder,
  icon: iconBuilder,
  listTile: listTileBuilder,
  listTileGroup: listTileGroupBuilder,
  loadingIndicator: loadingIndicatorBuilder,
  progress: progressBuilder,
  skeleton: skeletonBuilder,
  slider: sliderBuilder,
);
