part of flutter_base;

/// 路由工具类，封装命令式、声明式路由工具方法
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
  /// * context 由于需要支持[GoRouter]，你必须手动传递当前[context]用于支持嵌套路由、选项卡式导航
  /// * page 新页面组件
  /// * rootNavigator 如果为true，将隐藏底部tabbar
  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    bool rootNavigator = false,
  }) async {
    var result = await Navigator.of(context).push<T>(_PageRouter(
      builder: (context) => page,
      rootNavigator: rootNavigator,
    ));
    return result;
  }

  /// 返回上一页
  static void pop<T>(BuildContext context, [T? data]) async {
    Navigator.of(context).pop(data);
  }

  /// 重定向页面，先跳转新页面，再删除之前的页面
  static Future<T?> pushReplacement<T>(
    BuildContext context,
    Widget page, {
    bool rootNavigator = false,
  }) async {
    return await Navigator.of(context).pushReplacement(_PageRouter(
      builder: (context) => page,
      rootNavigator: rootNavigator,
    ));
  }

  /// 跳转新页面，同时删除之前所有的路由，直到指定的routePath。
  ///
  /// 例如：如果你想跳转一个新页面，同时希望这个新页面的上一级是首页，那么就设置routePath = '/'，
  /// 它会先跳转到新的页面，再删除从首页开始后的全部路由。
  static void pushAndRemoveUntil(
    BuildContext context,
    Widget page,
    String routePath, {
    bool rootNavigator = false,
  }) async {
    Navigator.of(context).pushAndRemoveUntil(
      _PageRouter(
        builder: (context) => page,
        rootNavigator: rootNavigator,
      ),
      ModalRoute.withName(routePath),
    );
  }

  /// 退出到指定位置
  static void popUntil(BuildContext context, String routePath) async {
    Navigator.of(context).popUntil(ModalRoute.withName(routePath));
  }

  /// 进入新的页面并删除之前所有路由
  static void pushAndRemoveAllUntil(
    BuildContext context,
    Widget page, {
    bool rootNavigator = false,
  }) async {
    Navigator.of(context).pushAndRemoveUntil(
      _PageRouter(
        builder: (context) => page,
        rootNavigator: rootNavigator,
      ),
      (route) => false,
    );
  }

  /// 构建[CupertinoPage]动画页面的[GoRoute]
  /// * rootNavigator 如果为true，将隐藏底部tabbar
  static Page<dynamic> pageBuilder<T>(
    BuildContext context,
    GoRouterState state,
    Widget page, {
    bool rootNavigator = false,
  }) =>
      _pageBuilder(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
        restorationId: state.pageKey.value,
        child: page,
        rootNavigator: rootNavigator,
      );

  /// 根据[RouterModel]集合生成[GoRoute]集合
  static List<GoRoute> routerModelToGoRouter(List<RouterModel> pages) {
    return pages
        .map((e) => GoRoute(
            path: e.path,
            pageBuilder: (context, state) => _pageBuilder(
                  key: state.pageKey,
                  name: state.name ?? state.path,
                  arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
                  restorationId: state.pageKey.value,
                  child: e.page,
                  rootNavigator: false,
                ),
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

CupertinoPage<void> _pageBuilder({
  required LocalKey key,
  required String? name,
  required Object? arguments,
  required String restorationId,
  required Widget child,
  required bool rootNavigator,
}) =>
    _Page<void>(
      name: name,
      arguments: arguments,
      key: key,
      restorationId: restorationId,
      child: child,
      rootNavigator: rootNavigator,
    );

/// 定义路由[CupertinoPage]
class _Page<T> extends CupertinoPage<T> {
  const _Page({
    required super.child,
    super.name,
    super.arguments,
    super.key,
    super.restorationId,
    required this.rootNavigator,
  });

  final bool rootNavigator;

  @override
  Route<T> createRoute(BuildContext context) {
    return _PageBasedPageRoute<T>(
      page: this,
      allowSnapshotting: allowSnapshotting,
      rootNavigator: rootNavigator,
    );
  }
}

/// 适用于[GoRouter]定义的声明式页面路由过渡动画，
class _PageBasedPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin, _CupertinoRouteTransitionMixin {
  _PageBasedPageRoute({
    required CupertinoPage<T> page,
    required this.rootNavigator,
    super.allowSnapshotting = true,
  }) : super(settings: page) {
    assert(opaque);
  }

  final bool rootNavigator;

  @override
  bool get showTabbar => rootNavigator;

  CupertinoPage<T> get _page => settings as CupertinoPage<T>;

  @override
  String? get title => _page.title;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  Widget buildContent(BuildContext context) => _page.child;
}

/// 适用于命令式页面路由过渡动画，支持[rootNavigator]属性，类似于：[MaterialPageRoute]、[CupertinoPageRoute]
class _PageRouter<T> extends PageRoute<T> with CupertinoRouteTransitionMixin, _CupertinoRouteTransitionMixin {
  _PageRouter({required this.builder, required this.rootNavigator});

  final WidgetBuilder builder;

  /// 若为true，则隐藏底部tabbar
  final bool rootNavigator;

  @override
  bool get showTabbar => rootNavigator;

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  Widget buildContent(BuildContext context) => builder(context);
}

// static Page<dynamic> Function(BuildContext, GoRouterState) pageBuilder<T>(Widget page) =>
//     (BuildContext context, GoRouterState state) => _pageBuilderForCupertinoApp(
//           key: state.pageKey,
//           name: state.name ?? state.path,
//           arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
//           restorationId: state.pageKey.value,
//           child: page,
//         );

// static CustomTransitionPage _pageBuilder<T>(
// BuildContext context,
// GoRouterState state,
// Widget page,
// ) {
// return CustomTransitionPage<T>(
// child: page,
// // transitionsBuilder: (context, animation, secondaryAnimation, child) =>
// //     FadeTransition(opacity: animation, child: child),
// transitionsBuilder: (context, animation, secondaryAnimation, child) => CupertinoPageRoute(
// builder: (context) => page,
// ).buildTransitions(context, animation, secondaryAnimation, page),
// );
// }

/// 定制Cupertino路由切换动画，如果进入新页面设置了隐藏底部导航栏，将在路由转换时应用显示、隐藏底部导航栏动画
mixin _CupertinoRouteTransitionMixin<T> on CupertinoRouteTransitionMixin<T> {
  bool get showTabbar => false;

  /// 当路由首次被安装时执行的生命周期函数
  @override
  void install() {
    if (showTabbar) TabScaffoldController.of.showTabbar = false;
    super.install();
  }

  /// 当进入新路由时执行的生命周期函数
  @override
  TickerFuture didPush() {
    if (showTabbar) TabScaffoldController.of.showTabbar = false;
    return super.didPush();
  }

  /// 当退出路由时执行的生命周期函数
  @override
  bool didPop(result) {
    if (showTabbar) {
      TabScaffoldController._showTabbarTimer = AsyncUtil.delayed(() {
        if (TabScaffoldController.of.showTabbar == false) {
          TabScaffoldController.of._showTabbar.value = true;
        }
      }, 400);
    }
    return super.didPop(result);
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (TabScaffoldController.of.showTabbar == false) {
      final tween = Tween(begin: TabScaffoldController.of.bottomNavHeight, end: 0.0);
      var heightAnimation = popGestureInProgress
          ? CurvedAnimation(
              parent: animation,
              curve: Curves.fastEaseInToSlowEaseOut.flipped,
            ).drive(tween)
          : CurvedAnimation(
              parent: animation,
              curve: Curves.fastEaseInToSlowEaseOut,
              reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
            ).drive(tween);
      TabScaffoldController.of.tabbarAnimationHeight.value = heightAnimation.value.toDouble();
    }
    return CupertinoRouteTransitionMixin.buildPageTransitions(this, context, animation, secondaryAnimation, child);
    // const begin = Offset(1.0, 0.0);
    // const end = Offset.zero;
    // final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.fastLinearToSlowEaseIn));
    // final offsetAnimation = animation.drive(tween);
    // return SlideTransition(
    //   position: offsetAnimation,
    //   child: child,
    // );
  }
}
