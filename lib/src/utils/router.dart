part of flutter_base;

/// 路由工具类
/// * 命令式路由
/// ``` dart
/// RouterUtil.push(context, A());
/// RouterUtil.pop(context);
/// ```
///
/// * 声明式路由
/// ``` dart
/// GoRoute(path: '/', builder: (context, state) => const HomePage()),
/// GoRoute(path: '/child', builder: (context, state) => const ChildPage()),
/// context.go('/child');
/// ```
class RouterUtil {
  RouterUtil._();

  /// 根节点导航key
  static GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  /// 根节点context
  static BuildContext get rootContext {
    assert(rootNavigatorKey.currentContext != null, '请配置rootNavigatorKey');
    return rootNavigatorKey.currentContext!;
  }

  /// 跳转到新页面
  static Future<T?> push<T>(BuildContext context, Widget page) async {
    return await Navigator.of(context).push<T>(CupertinoPageRoute(builder: (context) => page));
  }

  /// 返回上一页
  static void pop<T>(BuildContext context, [T? data]) async {
    Navigator.of(context).pop(data);
  }

  /// 重定向页面，先跳转新页面，再删除之前的页面
  static Future<T?> pushReplacement<T>(BuildContext context, Widget page) async {
    return await Navigator.of(context).pushReplacement(CupertinoPageRoute(builder: (context) => page));
  }

  /// 跳转新页面，同时删除之前所有的路由，直到指定的routePath。
  ///
  /// 例如：如果你想跳转一个新页面，同时希望这个新页面的上一级是首页，那么就设置routePath = '/'，
  /// 它会先跳转到新的页面，再删除从首页开始后的全部路由。
  static void pushAndRemoveUntil(BuildContext context, Widget page, String routePath) async {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (context) => page),
      ModalRoute.withName(routePath),
    );
  }

  /// 退出到指定位置
  static void popUntil(BuildContext context, String routePath) async {
    Navigator.of(context).popUntil(ModalRoute.withName(routePath));
  }

  /// 进入新的页面并删除之前所有路由
  static void pushAndRemoveAllUntil(BuildContext context, Widget page) async {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (context) => page),
      (route) => false,
    );
  }

  static Page<dynamic> Function(BuildContext, GoRouterState) pageBuilder<T>(Widget page) =>
      (BuildContext context, GoRouterState state) => _pageBuilderForCupertinoApp(
            key: state.pageKey,
            name: state.name ?? state.path,
            arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
            restorationId: state.pageKey.value,
            child: page,
          );

  static Page<dynamic> builder<T>(BuildContext context, GoRouterState state, Widget page) => _pageBuilderForCupertinoApp(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
        restorationId: state.pageKey.value,
        child: page,
      );

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
  static List<GoRoute> routerModelToGoRouter(List<RouterModel> pages) {
    return pages
        .map((e) => GoRoute(
            path: e.path,
            pageBuilder: (context, state) => _pageBuilderForCupertinoApp(
                  key: state.pageKey,
                  name: state.name ?? state.path,
                  arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
                  restorationId: state.pageKey.value,
                  child: e.page,
                ),
            // pageBuilder: pageBuilder(e.page),
            routes: DartUtil.safeList(e.children).isNotEmpty ? routerModelToGoRouter(e.children!) : []))
        .toList();
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

/// Builds a Cupertino page.
CupertinoPage<void> _pageBuilderForCupertinoApp({
  required LocalKey key,
  required String? name,
  required Object? arguments,
  required String restorationId,
  required Widget child,
}) =>
    CupertinoPage<void>(
      name: name,
      arguments: arguments,
      key: key,
      restorationId: restorationId,
      child: child,
    );

/// Getx控制器自动销毁监听器，将此实例添加到路由监听器中，实现离开页面自动销毁绑定的控制器。
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
