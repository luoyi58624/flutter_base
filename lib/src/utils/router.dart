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
  /// * rootNavigator 如果为true，进入到此页面以及后续所有子级路由都将隐藏底部tabbar
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
  /// * rootNavigator 如果为true，进入到此页面以及此页面下的所有子级路由都将隐藏底部tabbar
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
  bool get hideTabbar => rootNavigator;

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
  bool get hideTabbar => rootNavigator;

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  Widget buildContent(BuildContext context) => builder(context);
}

class _RoutePageState {
  _RoutePageState._();

  /// 此变量用于解决用户退出隐藏底部导航栏后又快速重新进入所引发的一些问题，因为我们需要在页面完全退出的情况下重新设置状态(dispose生命周期)，
  /// 但是退出有一个几百毫秒的过渡动画，在此期间用户再次进入我们必须抛弃dispose 当前设置了隐藏底部导航栏的路由是否已经弹出，但退出动画还未结束
  static bool isPop = false;

  /// 保存最上层隐藏底部tabbar的路由页面HashCode
  static int? rootHashCode;

  /// 当前激活的路由页面HashCode
  static int? currentHashCode;

  /// 弹出的路由上一个页面的hashCode
  static int? popNextHashCode;
}

/// 定制Cupertino路由切换动画，如果进入新页面设置了隐藏底部导航栏，将在路由转换时应用显示、隐藏底部导航栏动画
mixin _CupertinoRouteTransitionMixin<T> on CupertinoRouteTransitionMixin<T> {
  /// 当前路由是否隐藏tabbar
  bool get hideTabbar => false;

  /// 禁用第一帧动画，buildTransitions第一帧的animation值是目标动画的最终值，这会导致底部导航栏隐藏过程中出现轻微抖动
  bool disabledFirstFrame = true;

  /// 是否允许更新底部导航栏，只有当第一个设置了[rootNavigator]页面允许进入、退出页面时更新底部导航栏
  bool get _allowUpdateBottomNav {
    return hideTabbar && _RoutePageState.rootHashCode == _RoutePageState.currentHashCode;
  }

  /// 安装路由，如果你已经进入深层链接路由页面，那么它会从最底层开始依次安装父级路由
  @override
  void install() {
    // 设置当前页面的hashCode
    _RoutePageState.currentHashCode = hashCode;
    // 如果用户进入的路由页面需要隐藏底部tabbar
    if (hideTabbar) {
      // 当用户退出隐藏底部导航栏页面又快速重新进入，那么此时上次退出的页面dispose还未执行，那么我们在此处重置dispose的状态
      if (_RoutePageState.isPop) {
        _RoutePageState.isPop = false;
        _RoutePageState.popNextHashCode = null;
        _RoutePageState.rootHashCode = hashCode;
      } else {
        _RoutePageState.rootHashCode ??= hashCode;
      }
    }
    if (_allowUpdateBottomNav) TabScaffoldController.of._showBottomNav.value = false;
    super.install();
  }

  @override
  bool didPop(result) {
    _RoutePageState.isPop = true;
    return super.didPop(result);
  }

  @override
  void didPopNext(Route nextRoute) {
    super.didPopNext(nextRoute);
    // 当上一个页面退出后将拿到当前页面的 hashCode，在上一个页面执行 dispose 后再设置 currentHashCode，这段逻辑非常绕，
    // 因为 buildTransitions 会在两个页面间同步执行，如果在 didPopNext 方法中直接设置 currentHashCode，同时上一个页面刚好是 rootHashCode,
    // 那么 rootHashCode 页面和子页面之间的转换将导致 buildTransitions 触发显示、隐藏底部导航栏，所以我们必须创建 popNextHashCode 中间变量，
    // 当子页面完全销毁后（dispose），再设置 currentHashCode。
    _RoutePageState.popNextHashCode = hashCode;
  }

  @override
  void dispose() {
    super.dispose();
    // 在路由销毁时并过渡动画结束后取消隐藏底部tabbar，并重置_RoutePageState中的状态
    if (_allowUpdateBottomNav) {
      if (_RoutePageState.isPop) {
        _RoutePageState.isPop = false;
        _RoutePageState.rootHashCode = null;
        _RoutePageState.currentHashCode = null;
        _RoutePageState.popNextHashCode = null;
        TabScaffoldController.of._showBottomNav.value = true;
      }
    } else {
      // 若弹出的是子级页面，等待路由动画结束再设置 currentHashCode
      _RoutePageState.currentHashCode = _RoutePageState.popNextHashCode;
    }
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (disabledFirstFrame) {
      disabledFirstFrame = false;
    } else {
      if (_allowUpdateBottomNav) {
        final tween = Tween(begin: TabScaffoldController.of.bottomNavHeight, end: 0.0);
        var heightAnimation = popGestureInProgress
            ? CurvedAnimation(
                parent: animation,
                curve: Curves.linear,
              ).drive(tween)
            : CurvedAnimation(
                parent: animation,
                curve: Curves.fastEaseInToSlowEaseOut,
                reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
              ).drive(tween);
        TabScaffoldController.of._tabbarAnimationHeight.value = heightAnimation.value;
      }
    }
    return CupertinoRouteTransitionMixin.buildPageTransitions(this, context, animation, secondaryAnimation, child);
  }
}
