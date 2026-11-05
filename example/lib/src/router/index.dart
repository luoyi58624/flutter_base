import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/router.dart';
import 'desktop.dart';
import 'mobile.dart';

export 'desktop.dart' show desktopRoute;
export 'mobile.dart' show mobileRoute;

/// 随可用宽度切换的路由配置。
final routingConfig = RoutingConfigNotifier();

/// 两端共用的路由入口，切换布局时保留当前完整地址。
final router = GoRouter.routingConfig(
  navigatorKey: RouterUtil.rootNavigatorKey,
  routingConfig: routingConfig,
  initialLocation: RouterUtil.home,
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: Text('页面未找到')),
    body: Center(
      child: TextButton(onPressed: () => context.go(RouterUtil.home), child: Text('返回首页')),
    ),
  ),
);

/// 只在跨越断点时更新两端导航结构。
class RoutingConfigNotifier extends ChangeNotifier implements ValueListenable<RoutingConfig> {
  bool _isMobile = true;
  late RoutingConfig _config = mobileRoute;

  @override
  RoutingConfig get value => _config;

  /// 当前是否使用移动端导航结构。
  bool get isMobile => _isMobile;

  set isMobile(bool value) {
    if (_isMobile == value) return;
    _isMobile = value;
    _config = value ? mobileRoute : desktopRoute;
    notifyListeners();
  }
}
