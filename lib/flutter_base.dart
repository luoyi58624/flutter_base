library flutter_base;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'flutter_base.dart';

export 'package:dart_base/dart_base.dart';

// flutter官方国际化库
export 'package:flutter_localizations/flutter_localizations.dart';

// flutter官方collection库，扩展集合函数
export 'package:collection/collection.dart';

// 仅导出GetX的状态管理以及部分实用工具函数，但排除路由功能、http网络请求等与状态管理无关的代码，
export 'package:get/get_core/get_core.dart';
export 'package:get/get_instance/get_instance.dart';
export 'package:get/get_state_manager/get_state_manager.dart' hide VoidCallback;
export 'package:get/get_rx/get_rx.dart';
export 'package:get/get_utils/src/extensions/export.dart';
export 'package:get/get_utils/src/get_utils/get_utils.dart';
export 'package:get/get_utils/src/platform/platform.dart';
export 'package:get/get_utils/src/queue/get_queue.dart';

part 'src/commons/model.dart';

part 'src/utils/animation.dart';

part 'src/utils/async.dart';

part 'src/utils/color.dart';

part 'src/utils/flutter.dart';

part 'src/utils/local_storage.dart';

part 'src/utils/platform.dart';

part 'src/utils/use_local_obs.dart';

part 'src/widgets/animation.dart';

part 'src/widgets/badge.dart';

part 'src/widgets/flex_wrap.dart';

part 'src/widgets/restart_app.dart';

part 'src/widgets/simple_widgets.dart';

part 'src/widgets/sliver.dart';

/// key-value本地存储对象
late LocalStorage localStorage;

/// 初始化Flutter通用配置，例如主题、本地存储
/// * themeModel 自定义主题
/// * enableGetxLog 控制台是否显示getx日志
Future<void> initFlutter({
  bool enableGetxLog = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!enableGetxLog) Get.isLogEnable = false;
  await Hive.initFlutter();
  localStorage = await LocalStorage.init();
  _obsLocalStorage = await LocalStorage.init('local_obs');
}
