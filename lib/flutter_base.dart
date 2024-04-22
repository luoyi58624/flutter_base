library flutter_base;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart' as scheduler;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart' as modal_bottom_sheet;
import 'package:azlistview/azlistview.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:go_router/go_router.dart' as go_router hide GoRouterHelper;

import 'flutter_base.dart';

export 'src/extendeds/index.dart';

export 'package:dart_base/dart_base.dart';

// dio网络请求库
export 'package:dio/dio.dart';

// flutter动画库
export 'package:flutter_animate/flutter_animate.dart';

// flutter官方路由库
export 'package:go_router/go_router.dart' hide GoRouterHelper, GoRoute;

// flutter官方国际化库
export 'package:flutter_localizations/flutter_localizations.dart';

// flutter官方collection库，扩展集合函数
export 'package:collection/collection.dart';

// GetX的状态管理
export 'package:get/get.dart';

// flutter常用的一组loading动画
export 'package:flutter_spinkit/flutter_spinkit.dart';

// 生成假数据
export 'package:faker/faker.dart';

// flutter展示html组件
export 'package:flutter_html/flutter_html.dart';

// 多平台查找文件系统上的常用位置
export 'package:path_provider/path_provider.dart';

// 闪光组件
export 'package:shimmer/shimmer.dart';

// ListView增强插件，解决不定高子项滚动条错位bug、拖动滚动条滚动性能低bug
export 'package:super_sliver_list/super_sliver_list.dart';

/// 底部弹窗库
export 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

/// 扩展官方tabs，优化手感
export 'package:extended_tabs/extended_tabs.dart';

/// 轻松地在 Flex 小部件内添加间隙
export 'package:gap/gap.dart';

part 'src/app.dart';

part 'src/theme.dart';

part 'src/config.dart';

part 'src/commons/model.dart';

part 'src/controllers/flutter.dart';

part 'src/controllers/tab_scaffold.dart';

part 'src/extensions/color.dart';

part 'src/extensions/router.dart';

part 'src/extensions/theme.dart';

part 'src/mixins/theme.dart';

part 'src/pages/simple_page.dart';

part 'src/utils/animation.dart';

part 'src/utils/async.dart';

part 'src/utils/cascader.dart';

part 'src/utils/color.dart';

part 'src/utils/drawer.dart';

part 'src/utils/flutter.dart';

part 'src/utils/html.dart';

part 'src/utils/http.dart';

part 'src/utils/loading.dart';

part 'src/utils/local_storage.dart';

part 'src/utils/modal.dart';

part 'src/utils/modal_router.dart';

part 'src/utils/no_ripper.dart';

part 'src/utils/platform.dart';

part 'src/utils/router.dart';

part 'src/utils/serializable.dart';

part 'src/utils/toast.dart';

part 'src/utils/use_local_obs.dart';

part 'src/widgets/animation.dart';

part 'src/widgets/badge.dart';

part 'src/widgets/exit_intercept.dart';

part 'src/widgets/flex_wrap.dart';

part 'src/widgets/flexible_title.dart';

part 'src/widgets/hide_keybord.dart';

part 'src/widgets/index_list.dart';

part 'src/widgets/restart_app.dart';

part 'src/widgets/scroll_ripper.dart';

part 'src/widgets/simple_widgets.dart';

part 'src/widgets/skeleton.dart';

part 'src/widgets/sliver.dart';

part 'src/tab_scaffold.dart';

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

/// [GoRouter]路由对象
late final GoRouter router;

/// 根节点导航key
GlobalKey<NavigatorState> get rootNavigatorKey => router.configuration.navigatorKey;

/// 根节点context
BuildContext get rootContext => rootNavigatorKey.currentContext!;

/// 初始化App
/// * router 路由对象
/// * themeMode 主题模式
/// * theme 自定义亮色主题
/// * darkTheme 自定义暗色主题
/// * config 自定义全局配置
Future<void> initApp({
  required GoRouter router,
  ThemeMode? themeMode,
  AppThemeData? theme,
  AppThemeData? darkTheme,
  FlutterConfigData? config,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  localStorage = await LocalStorage.init();
  _obsLocalStorage = await LocalStorage.init('local_obs');
  _setRouter(router);
  Get.put(AppController(
    themeMode: themeMode ?? ThemeMode.system,
    theme: theme ?? AppThemeData(),
    darkTheme: darkTheme ?? AppThemeData.dark(),
    config: config ?? FlutterConfigData(),
  ));
}

void _setRouter(GoRouter _router) {
  router = _router;
  _RouteState.init();
}
