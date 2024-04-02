part of flutter_base;

/// Flutter路由对象，底层基于Flutter官方维护的[go_router]，同时支持命令式、声明式导航。
///
/// * 如果你开发移动端应用，推荐以命令式路由为主，因为它非常简单。
///
/// 示例：
/// ``` dart
/// router.push(A());
/// router.pop();
/// ```
/// 优点：api简单，绝大多数页面无需[context]即可跳转(嵌套导航除外)
///
/// 缺点：不支持web_url，复杂页面实现困难(桌面端布局)
///
/// * 如果你开发桌面端、web应用，则推荐以声明式路由为主，它可以很好地支持嵌套导航、web_url导航。
///
/// 示例：
/// ``` dart
/// FlutterApp(
///   routes: [
///     GoRoute(path: '/', builder: (context, state) => const HomePage()),
///     GoRoute(path: '/child', builder: (context, state) => const ChildPage()),
///   ],
/// );
///
/// context.go('/');
/// context.go('/child');
/// ```
/// 优点：支持各种场景的导航，同时向下兼容命令式导航，反之，命令式导航的页面不可以进行声明式跳转
///
/// 缺点：api复杂，相比命令式使用起来稍微麻烦，虽然是官方推荐的路由器，但文档很简陋
class FlutterRouter {
  FlutterRouter({
    required this.routes,
    List<NavigatorObserver> navigatorObservers = const [],
  }) {
    instance = GoRouter(
      navigatorKey: globalNavigatorKey,
      routes: routes,
      observers: [
        _GetXRouterObserver(),
        ...navigatorObservers,
      ],
    );
  }

  /// go_router实例对象
  late GoRouter instance;

  /// 声明的路由集合
  final List<RouteBase> routes;

  /// 根节点导航key
  GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

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

  /// 返回上一页
  void pop<T>({
    BuildContext? context,
    T? data,
    int backNum = 1,
  }) async {
    for (int i = 0; i < backNum; i++) {
      Navigator.of(context ?? globalContext).pop(data);
    }
  }

  /// 重定向页面，先跳转新页面，再删除之前的页面
  Future<T?> redirect<T>(
    Widget page, {
    BuildContext? context,
    RouteSettings? settings,
  }) async {
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
  void pushUntil(
    Widget page,
    String routePath, {
    BuildContext? context,
    RouteSettings? settings,
  }) async {
    Navigator.of(context ?? globalContext).pushAndRemoveUntil(
      CupertinoPageRoute(
        builder: (context) => page,
        settings: settings,
      ),
      ModalRoute.withName(routePath),
    );
  }

  /// 原理和pushUntil一样，只不过这是退出到指定位置
  void popUntil(
    String routePath, {
    BuildContext? context,
  }) async {
    Navigator.of(context ?? globalContext).popUntil(
      ModalRoute.withName(routePath),
    );
  }

  /// 进入新的页面并删除之前所有路
  void pushAndPopAll(
    Widget page, {
    BuildContext? context,
  }) async {
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
class _GetXRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RouterReportManager.instance.reportCurrentRoute(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) async {
    RouterReportManager.instance.reportRouteDispose(route);
  }
}
