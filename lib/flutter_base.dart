library flutter_base;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_navigation/src/router_report.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:page_transition/page_transition.dart';

import 'flutter_base.dart';

export 'package:dart_base/dart_base.dart';

// flutter官方路由库
export 'package:go_router/go_router.dart';

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

part 'src/app.dart';

part 'src/router.dart';

part 'src/theme.dart';

part 'src/commons/model.dart';

part 'src/pages/root/material.dart';

part 'src/pages/root_page.dart';

part 'src/pages/simple_page.dart';

part 'src/utils/animation.dart';

part 'src/utils/async.dart';

part 'src/utils/color.dart';

part 'src/utils/flutter.dart';

part 'src/utils/loading.dart';

part 'src/utils/local_storage.dart';

part 'src/utils/modal.dart';

part 'src/utils/no_ripper.dart';

part 'src/utils/platform.dart';

part 'src/utils/toast.dart';

part 'src/utils/use_local_obs.dart';

part 'src/widgets/animation.dart';

part 'src/widgets/badge.dart';

part 'src/widgets/exit_intercept.dart';

part 'src/widgets/flex_wrap.dart';

part 'src/widgets/flexible_title.dart';

part 'src/widgets/restart_app.dart';

part 'src/widgets/simple_widgets.dart';

part 'src/widgets/sliver.dart';

/// key-value本地存储对象
late LocalStorage localStorage;

/// flutter路由
late FlutterRouter _router;

/// 初始化Flutter通用配置，例如主题、本地存储
/// * router 路由对象
/// * themeModel 自定义主题
/// * enableGetxLog 控制台是否显示getx日志
Future<void> initFlutterApp({
  required FlutterRouter router,
  AppThemeModel? appThemeModel,
  bool enableGetxLog = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _router = router;
  if (!enableGetxLog) Get.isLogEnable = false;
  appTheme = AppTheme(appThemeModel);
  if (appTheme.translucenceStatusBar) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color.fromRGBO(0, 0, 0, 200)));
  } else {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Color.fromRGBO(0, 0, 0, 0)));
  }
  await Hive.initFlutter();
  localStorage = await LocalStorage.init();
  _obsLocalStorage = await LocalStorage.init('local_obs');
}
