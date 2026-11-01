import 'package:flutter_base/ui.dart';

import 'button/index.dart';
import 'card/index.dart';
import 'switch/index.dart';
import 'tag/index.dart';
import 'text/index.dart';
import 'list_tile/index.dart';
import 'loading/index.dart';
import 'progress/index.dart';
import 'skeleton/index.dart';

/// 已有移动端实现能够完整承接的通用组件配置。
const defaultComponentBuilders = ElComponentBuilders(
  buttonBuilder: buttonBuilder,
  cardBuilder: cardBuilder,
  tagBuilder: tagBuilder,
  switchBuilder: switchBuilder,
  textBuilder: textBuilder,
  listTileBuilder: listTileBuilder,
  listTileGroupBuilder: listTileGroupBuilder,
  loadingIndicatorBuilder: loadingIndicatorBuilder,
  progressBuilder: progressBuilder,
  skeletonBuilder: skeletonBuilder,
);
