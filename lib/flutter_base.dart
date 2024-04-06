library flutter_base;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get_navigation/src/router_report.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:highlight_text/highlight_text.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:package_info_plus/package_info_plus.dart';

import 'flutter_base.dart';

export 'src/extendeds/index.dart';

export 'package:dart_base/dart_base.dart';

// dio网络请求库
export 'package:dio/dio.dart';

// flutter动画库
export 'package:flutter_animate/flutter_animate.dart';

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

// flutter常用的一组loading动画
export 'package:flutter_spinkit/flutter_spinkit.dart';

// 生成假数据
export 'package:faker/faker.dart';

// flutter展示html组件
export 'package:flutter_html/flutter_html.dart';

// 打开文件
export 'package:open_file_plus/open_file_plus.dart';

// 多平台查找文件系统上的常用位置
export 'package:path_provider/path_provider.dart';

// 闪光组件
export 'package:shimmer/shimmer.dart';

// ListView增强插件，解决不定高子项滚动条错位bug、拖动滚动条滚动性能低bug
export 'package:super_sliver_list/super_sliver_list.dart';

// 网络连接状态
export 'package:connectivity_plus/connectivity_plus.dart' show ConnectivityResult;

part 'src/app.dart';

part 'src/theme.dart';

part 'src/config.dart';

part 'src/commons/model.dart';

part 'src/controllers/network_controller.dart';

part 'src/mixins/theme.dart';

part 'src/pages/bottom_tabbar.dart';

part 'src/pages/root_page.dart';

part 'src/pages/simple_page.dart';

part 'src/utils/animation.dart';

part 'src/utils/async.dart';

part 'src/utils/color.dart';

part 'src/utils/crypto.dart';

part 'src/utils/device.dart';

part 'src/utils/flutter.dart';

part 'src/utils/html.dart';

part 'src/utils/http.dart';

part 'src/utils/loading.dart';

part 'src/utils/local_storage.dart';

part 'src/utils/uuid.dart';

part 'src/utils/modal.dart';

part 'src/utils/no_ripper.dart';

part 'src/utils/platform.dart';

part 'src/utils/router.dart';

part 'src/utils/toast.dart';

part 'src/utils/use_local_obs.dart';

part 'src/widgets/animation.dart';

part 'src/widgets/badge.dart';

part 'src/widgets/exit_intercept.dart';

part 'src/widgets/flex_wrap.dart';

part 'src/widgets/flexible_title.dart';

part 'src/widgets/hide_keybord.dart';

part 'src/widgets/restart_app.dart';

part 'src/widgets/scroll_ripper.dart';

part 'src/widgets/simple_widgets.dart';

part 'src/widgets/skeleton.dart';

part 'src/widgets/sliver.dart';

part 'src/widgets/tag.dart';

part 'src/widgets/tap_animate.dart';

part 'src/widgets/text_highlight.dart';

part 'src/widgets/form/form.dart';

part 'src/widgets/form/form_item.dart';

part 'src/widgets/form/form_text_field.dart';

part 'src/widgets/image/image_widget.dart';

part 'src/widgets/image/file_type_image_widget.dart';

part 'src/widgets/cupertino/list_group.dart';

part 'src/widgets/cupertino/list_tile.dart';

/// key-value本地存储对象
late LocalStorage localStorage;

/// 根节点导航key
GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// 根节点context
BuildContext get rootContext {
  assert(rootNavigatorKey.currentContext != null, '请配置rootNavigatorKey');
  return rootNavigatorKey.currentContext!;
}

/// 初始化Flutter通用配置，例如主题、本地存储
/// * router 全局路由对象
/// * themeModel 自定义主题
/// * enableGetxLog 控制台是否显示getx日志，默认false
Future<void> initFlutterApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.isLogEnable = false;
  await Hive.initFlutter();
  localStorage = await LocalStorage.init();
  _obsLocalStorage = await LocalStorage.init('local_obs');
}
