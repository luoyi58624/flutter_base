import 'package:flutter_base/ui.dart';

import 'button/index.dart';
import 'switch/index.dart';
import 'tag/index.dart';
import 'text/index.dart';

/// 已有移动端实现能够完整承接的通用组件配置。
const myComponentBuilders = ElComponentBuilders(
  buttonBuilder: myButtonBuilder,
  tagBuilder: myTagBuilder,
  switchBuilder: mySwitchBuilder,
  textBuilder: myTextBuilder,
);
