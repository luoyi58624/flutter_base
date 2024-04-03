part of flutter_base;

/// Flutter路由对象，底层基于Flutter官方维护的[go_router]，它同时支持命令式、声明式导航。
///
/// * 如果你开发移动端应用，推荐以命令式路由为主，因为它非常简洁，除了嵌套导航，你无需[context]即可跳转。
///
/// 示例：
/// ``` dart
/// router.push(A());
/// router.pop();
/// ```
///
/// * 如果你开发桌面端、web应用，则推荐以声明式路由为主，它可以很好地支持嵌套导航、web_url导航。
///
/// 示例：
/// ``` dart
/// GoRoute(path: '/', builder: (context, state) => const HomePage()),
/// GoRoute(path: '/child', builder: (context, state) => const ChildPage()),
///
/// context.go('/');
/// context.go('/child');
/// ```
class FlutterRouter {
  /// 创建全局路由构造函数
  /// * routes 声明式路由集合，基于[go_router]
  /// * redirect 重定向，返回null表示放行，或者返回一个path重定向到指定页面
  /// * navigatorObservers 导航监听
  FlutterRouter({
    List<RouteBase> routes = const [],
    GoRouterRedirect? redirect,
    List<NavigatorObserver> navigatorObservers = const [],
  }) {
    _redirect = redirect ?? (context, state) => null;
    this.routes = routes;
    instance = GoRouter.routingConfig(
      routingConfig: _routingConfig,
      navigatorKey: globalNavigatorKey,
      observers: [
        // getx控制器自动释放监听
        GetXRouterObserver(),
        ...navigatorObservers,
      ],
    );
  }

  /// go_router实例对象
  late GoRouter instance;

  final ValueNotifier<RoutingConfig> _routingConfig = ValueNotifier<RoutingConfig>(const RoutingConfig(routes: []));

  late GoRouterRedirect _redirect;

  /// 声明的路由集合
  late List<RouteBase> _routes;

  /// 设置[_routes]，并动态更新[GoRouter]路由配置
  set routes(List<RouteBase> routes) {
    _routes = routes;
    _routingConfig.value = RoutingConfig(routes: _routes, redirect: _redirect);
  }

  /// 根节点导航key
  static GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

  /// 根节点全局context
  BuildContext get globalContext => globalNavigatorKey.currentContext!;

  static Page<dynamic> Function(BuildContext, GoRouterState) pageBuilder<T>(Widget child) =>
      (BuildContext context, GoRouterState state) => _pageBuilder<T>(context, state, child);

  static CustomTransitionPage _pageBuilder<T>(
    BuildContext context,
    GoRouterState state,
    Widget page,
  ) {
    return CustomTransitionPage<T>(
      child: page,
      // transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      //     FadeTransition(opacity: animation, child: child),
      transitionsBuilder: (context, animation, secondaryAnimation, child) => CupertinoPageRoute(
        builder: (context) => page,
      ).buildTransitions(context, animation, secondaryAnimation, page),
    );
  }

  /// 根据[RouterModel]集合生成[GoRoute]集合
  static List<GoRoute> buildChildrenRoute(List<RouterModel> pages) {
    return pages
        .map((e) => GoRoute(
            path: e.path,
            builder: (context, state) => e.page,
            // pageBuilder: pageBuilder(e.page),
            routes: DartUtil.safeList(e.children).isNotEmpty ? buildChildrenRoute(e.children!) : []))
        .toList();
  }

  /// 跳转到新页面
  /// * page 页面组件
  /// * context 如果你使用了嵌套导航，并且想使之生效，那么你需要传递当前context才能正确跳转，否则默认使用全局context
  Future<T?> push<T>(Widget page, [BuildContext? context, RouteSettings? settings]) async {
    return await Navigator.of(context ?? globalContext).push<T>(CupertinoPageRoute(
      builder: (context) => page,
      settings: settings,
    ));
  }

  /// 返回上一页
  /// * context 注意：如果[push]的页面携带了[context]，那么你返回上一页也必须传递当前[context]
  /// * data 返回的数据
  void pop<T>([BuildContext? context, T? data]) async {
    Navigator.of(context ?? globalContext).pop(data);
  }

  /// 重定向页面，先跳转新页面，再删除之前的页面
  Future<T?> pushReplacement<T>(Widget page, [BuildContext? context, RouteSettings? settings]) async {
    return await Navigator.of(
      context ?? globalContext,
    ).pushReplacement(CupertinoPageRoute(
      builder: (context) => page,
      settings: settings,
    ));
  }

  /// 跳转新页面，同时删除之前所有的路由，直到指定的routePath。
  /// 讲人话就是：如果你想跳转一个新页面，同时希望这个新页面的上一级是首页，那么就设置routePath = '/'，
  /// 它会先跳转到新的页面，再删除从首页开始后的全部路由。
  ///
  /// 当然，一般app有多个tabbar页面，它们都属于根页面，你若要指定tabbar页面还需要自己做处理，
  /// 你可以使用 "事件总线" 或者 "全局状态"。
  void pushAndRemoveUntil(Widget page, String routePath, [BuildContext? context, RouteSettings? settings]) async {
    Navigator.of(context ?? globalContext).pushAndRemoveUntil(
      CupertinoPageRoute(
        builder: (context) => page,
        settings: settings,
      ),
      ModalRoute.withName(routePath),
    );
  }

  /// 原理和pushUntil一样，只不过这是退出到指定位置
  void popUntil(String routePath, [BuildContext? context]) async {
    Navigator.of(context ?? globalContext).popUntil(
      ModalRoute.withName(routePath),
    );
  }

  /// 进入新的页面并删除之前所有路由
  void pushAndRemoveAllUntil(Widget page, [BuildContext? context]) async {
    Navigator.of(context ?? globalContext).pushAndRemoveUntil(
      CupertinoPageRoute(
        builder: (context) => page,
      ),
      (route) => false,
    );
  }
}

class CustomSlideTransition extends CustomTransitionPage<void> {
  CustomSlideTransition({super.key, required super.child})
      : super(
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, animation, __, child) {
            return SlideTransition(
              position: animation.drive(
                Tween(
                  begin: const Offset(1.0, 0),
                  end: Offset.zero,
                ).chain(
                  CurveTween(curve: Curves.easeOut),
                ),
              ),
              child: child,
            );
          },
        );
}

/// 监听路由变化，将路由添加到getx管理，实现离开页面自动销毁绑定的控制器。
/// 只有一点需要注意：Get.put在StatelessWidget中必须将放置build方法中，否则无法正确回收控制器。
///
/// 反例：
/// ```dart
/// class GetxDemoPage extends StatelessWidget {
///   GetxDemoPage({super.key});
///   final controller = Get.put(GetxDemoController());
///
///   @override
///   Widget build(BuildContext context) {
///     return Container();
///   }
/// }
/// ```
///
/// 正确做法：
/// ```dart
/// class GetxDemoPage extends StatelessWidget {
///   const GetxDemoPage({super.key});
///
///   @override
///   Widget build(BuildContext context) {
///     // Getx不会重复注入相同的控制器，所以不必担心此代码会影响程序的正常运行
///     final controller = Get.put(GetxDemoController());
///     return Container();
///   }
/// }
/// ```
class GetXRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RouterReportManager.instance.reportCurrentRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) async {
    RouterReportManager.instance.reportRouteDispose(route);
  }
}
