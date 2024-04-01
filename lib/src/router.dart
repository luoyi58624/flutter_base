part of flutter_base;

/// flutter路由对象，基于flutter官方路由库[go_router]实现，同时支持flutter命令式、声明式api
late FlutterRouter router;

class FlutterRouter {
  FlutterRouter({required this.routes}) {
    _router = GoRouter(
      navigatorKey: globalNavigatorKey,
      routes: routes,
    );
  }

  final List<RouteBase> routes;

  /// go_router实例
  late GoRouter _router;

  /// 根节点导航key
  GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

  /// 根节点context，此属性用于
  BuildContext get globalContext => globalNavigatorKey.currentContext!;

  static CustomTransitionPage pageBuilder<T>(
    BuildContext context,
    GoRouterState state,
    Widget page,
  ) {
    return CustomTransitionPage<T>(
      child: page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      // transitionsBuilder: (context, animation, secondaryAnimation, child) => MaterialPageRoute(
      //   builder: (context) => page,
      // ).buildTransitions(context, animation, secondaryAnimation, page),
    );
  }

  /// 以声明式的方式跳转路由，相比[push]方法，最大的不同点是它会改变url地址。
  ///
  /// 注意：不要在执行了[push]方法的页面内执行[go]跳转，否则路由会发生错乱：
  /// ``` dart
  /// router.push(A());
  /// // 不要在A页面执行go跳转，
  /// router.go(context, '/b');
  /// ```
  ///
  /// 示例：
  /// * /a -> /b : 如果a、b页面同级，那么a页面的状态会丢失，路由跳转相当于replace
  /// ``` dart
  /// GoRoute(path: '/a', builder: (context, state) => const A()),
  /// GoRoute(path: '/b', builder: (context, state) => const B()),
  /// context.go('/b');
  /// ```
  /// * /a -> /b : 如果b页面为a页面子级，那么a页面的状态则不会丢失，路由跳转相当于push
  /// ``` dart
  /// GoRoute(path: '/a', builder: (context, state) => const A(), routes: [
  ///   GoRoute(path: 'b', builder: (context, state) => const B()),
  /// ]),
  /// context.go('/b');
  /// ```
  void go(BuildContext context, String url) {
    context.go(url);
  }

  /// 跳转到新页面
  Future<T?> push<T>(
    Widget page, {
    // 如果你使用了嵌套导航，那么必须传递当前context
    BuildContext? context,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) async {
    return await Navigator.of(context ?? globalContext).push<T>(CupertinoPageRoute(
      builder: (context) => page,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
    ));
  }
}
