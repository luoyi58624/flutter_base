library flutter_base;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart' as scheduler;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flutter_base.dart';

export 'src/extendeds/index.dart';

export 'package:dart_base/dart_base.dart';

// flutter官方collection库，扩展集合函数
export 'package:collection/collection.dart';

// GetX的状态管理
export 'package:get/get.dart';

part 'src/theme.dart';

part 'src/config.dart';

part 'src/builders/hover.dart';

part 'src/builders/tap.dart';

part 'src/commons/model.dart';

part 'src/controllers/app.dart';

part 'src/extensions/color.dart';

part 'src/extensions/router.dart';

part 'src/extensions/theme.dart';

part 'src/mixins/theme.dart';

part 'src/pages/simple_page.dart';

part 'src/utils/animation.dart';

part 'src/utils/async.dart';

part 'src/utils/color.dart';

part 'src/utils/drawer.dart';

part 'src/utils/flutter.dart';

part 'src/utils/modal.dart';

part 'src/utils/no_ripper.dart';

part 'src/utils/platform.dart';

part 'src/utils/serializable.dart';

part 'src/widgets/animation.dart';

part 'src/widgets/badge.dart';

part 'src/widgets/flex_wrap.dart';

part 'src/widgets/flexible_title.dart';

part 'src/widgets/hide_keybord.dart';

part 'src/widgets/restart_app.dart';

part 'src/widgets/scroll_ripper.dart';

part 'src/widgets/simple_widgets.dart';

part 'src/widgets/sliver.dart';

part 'src/widgets/tag.dart';

part 'src/widgets/tap_animate.dart';

part 'src/widgets/form/form.dart';

part 'src/widgets/form/form_item.dart';

part 'src/widgets/form/form_text_field.dart';

part 'src/widgets/cupertino/list_group.dart';

part 'src/widgets/cupertino/list_tile.dart';

/// 根节点导航key
late final GlobalKey<NavigatorState> rootNavigatorKey;

/// 根节点context
BuildContext get rootContext => rootNavigatorKey.currentContext!;
