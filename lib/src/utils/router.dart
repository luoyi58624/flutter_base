part of flutter_base;

late GoRouter _router;

/// 根节点导航key
GlobalKey<NavigatorState> get rootNavigatorKey => _router.configuration.navigatorKey;

/// 根节点context
BuildContext get rootContext => rootNavigatorKey.currentContext!;

/// 拓展[context]对象，支持通过[context]进行命令式、声明式导航
/// * 命令式路由
/// ``` dart
/// context.push(A());
/// context.pop();
/// ```
///
/// * 声明式路由
/// ``` dart
/// GoRoute(path: '/', builder: (context, state) => const HomePage()),
/// GoRoute(path: '/child', builder: (context, state) => const ChildPage()),
/// context.go('/child');
/// ```
extension FlutterRouterHelper on BuildContext {
  /// 声明式跳转，通过此方法进行路由跳转会更改浏览器上面的url
  void go(String path) {
    GoRouter.of(this).go(path);
  }

  /// 命令式url跳转新页面，与[go]方法的区别在于，它不会更改浏览器上的url
  void pushPath(String path) {
    GoRouter.of(this).push(path);
  }

  /// 跳转到新页面
  /// * context 由于需要支持[GoRouter]，你必须手动传递当前[context]用于支持嵌套路由、选项卡式导航
  /// * page 新页面组件
  /// * hideTabbar 如果为true，进入到此页面以及后续所有子级路由都将隐藏底部tabbar
  Future<T?> push<T>(
    Widget page, {
    bool hideTabbar = false,
  }) async {
    var result = await Navigator.of(this).push<T>(_PageRouter(
      builder: (context) => page,
      hideTabbar: hideTabbar,
    ));
    return result;
  }

  /// 返回上一页
  void pop([dynamic data]) async {
    Navigator.of(this).pop(data);
  }

  /// 重定向页面，先跳转新页面，再删除之前的页面
  Future<T?> pushReplacement<T>(
    Widget page, {
    bool hideTabbar = false,
  }) async {
    return await Navigator.of(this).pushReplacement(_PageRouter(
      builder: (context) => page,
      hideTabbar: hideTabbar,
    ));
  }

  /// 跳转新页面，同时删除之前所有的路由，直到指定的routePath。
  ///
  /// 例如：如果你想跳转一个新页面，同时希望这个新页面的上一级是首页，那么就设置routePath = '/'，
  /// 它会先跳转到新的页面，再删除从首页开始后的全部路由。
  void pushAndRemoveUntil(
    Widget page,
    String routePath, {
    bool hideTabbar = false,
  }) async {
    Navigator.of(this).pushAndRemoveUntil(
      _PageRouter(
        builder: (context) => page,
        hideTabbar: hideTabbar,
      ),
      ModalRoute.withName(routePath),
    );
  }

  /// 退出到指定位置
  void popUntil(String routePath) async {
    Navigator.of(this).popUntil(ModalRoute.withName(routePath));
  }

  /// 进入新的页面并删除之前所有路由
  void pushAndRemoveAllUntil(
    Widget page, {
    bool hideTabbar = false,
  }) async {
    Navigator.of(this).pushAndRemoveUntil(
      _PageRouter(
        builder: (context) => page,
        hideTabbar: hideTabbar,
      ),
      (route) => false,
    );
  }

  /// [GoRoute]页面构建，如果你需要实现[hideTabbar]，请一律使用此方法构建路由
  Page<dynamic> pageBuilder<T>(GoRouterState state, Widget page) => _Page<void>(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
        restorationId: state.pageKey.value,
        child: page,
      );

  /// 根据[RouterModel]集合生成[GoRoute]集合
  List<GoRoute> routerModelToGoRouter(List<RouterModel> pages) {
    return pages
        .map((e) => GoRoute(
            path: e.path,
            pageBuilder: (context, state) => _Page<void>(
                  key: state.pageKey,
                  name: state.name ?? state.path,
                  arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
                  restorationId: state.pageKey.value,
                  child: e.page,
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

/// 定义路由[CupertinoPage]
class _Page<T> extends CupertinoPage<T> {
  const _Page({
    required super.child,
    super.name,
    super.arguments,
    super.key,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return _PageBasedPageRoute<T>(
      page: this,
      allowSnapshotting: allowSnapshotting,
    );
  }
}

/// 适用于[GoRouter]定义的声明式页面路由过渡动画，
class _PageBasedPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin, _CupertinoRouteTransitionMixin {
  _PageBasedPageRoute({
    required CupertinoPage<T> page,
    super.allowSnapshotting = true,
  }) : super(settings: page) {
    assert(opaque);
  }

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

/// 适用于命令式页面路由过渡动画，支持[hideTabbar]属性，类似于：[MaterialPageRoute]、[CupertinoPageRoute]
class _PageRouter<T> extends PageRoute<T> with CupertinoRouteTransitionMixin, _CupertinoRouteTransitionMixin {
  _PageRouter({required this.builder, required this.hideTabbar});

  final WidgetBuilder builder;

  final bool hideTabbar;

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  Widget buildContent(BuildContext context) => builder(context);
}

class _State {
  _State._();

  /// 根路由列表
  static late final List<GoRouteModel> routeModels;

  /// 路由模型 Map 集合
  static late final Map<String, GoRouteModel> routeModelMap;

  /// [routeModelMap]keys集合
  static late final List<String> routeModelKeys;

  /// [currentRoute]所在的路由链
  static List<GoRouteModel> currentChainList = [];

  /// 当前路由历史对象
  static GoRouteModel? currentRoute;

  /// 上一次路由历史对象
  static GoRouteModel? previousRoute;

  static bool didPop = false;

  /// 当前顶级路由位置
  static int currentIndex = 0;

  /// 当前路由链中最顶层的隐藏底部导航栏路由
  static String? hideTabbarRootPath;

  /// 是否已经退出路由链中最顶层的隐藏底部导航栏路由
  static bool isPopToHideTabbarRootPath = false;

  static void setHideTabbarPath() {
    currentChainList.clear();
    setRouteChain(currentChainList);
    hideTabbarRootPath = currentChainList.firstWhereOrNull((e) => routeModelMap[e.path]?.hideTabbar == true)?.path;
    if (hideTabbarRootPath != null) isPopToHideTabbarRootPath = false;
    // i(currentChainList);
    // i(hideTabbarRootPath);
  }

  static void setRouteChain(List<GoRouteModel> chainList, [List<GoRouteModel>? $routeModels]) {
    $routeModels ??= routeModels;
    for (int i = 0; i < $routeModels.length; i++) {
      if (currentRoute!.path.startsWith($routeModels[i].path)) {
        if (currentRoute!.path == $routeModels[i].path) {
          chainList.add($routeModels[i]);
          break;
        } else {
          chainList.add($routeModels[i]);
          if ($routeModels[i].children != null) {
            setRouteChain(chainList, $routeModels[i].children!);
          }
        }
      }
    }
  }

  static void setShowBottomNav([bool? setHeight]) {
    if (currentRoute?.hideTabbar == true) {
      TabScaffoldController.of._showBottomNav.value = false;
      if (setHeight == true) TabScaffoldController.of._tabbarAnimationHeight.value = 0;
    } else {
      TabScaffoldController.of._showBottomNav.value = true;
      if (setHeight == true) TabScaffoldController.of._tabbarAnimationHeight.value = TabScaffoldController.of.bottomNavHeight;
    }
  }

  static void resetStatus() {
    currentChainList = [];
    currentRoute = null;
    previousRoute = null;
    didPop = false;
    currentIndex = 0;
    hideTabbarRootPath = null;
    isPopToHideTabbarRootPath = false;
  }
}

/// 定制Cupertino路由切换动画，如果进入新页面设置了隐藏底部导航栏，将在路由转换时应用显示、隐藏底部导航栏动画
mixin _CupertinoRouteTransitionMixin<T> on CupertinoRouteTransitionMixin<T> {
  String? _currentPath;

  /// 禁用第一帧动画，buildTransitions第一帧的animation值是目标动画的最终值，这会导致底部导航栏隐藏过程中出现轻微抖动
  bool _disabledFirstFrame = true;

  void _pushPage() {
    if (_State.currentRoute != null) {
      _State.setHideTabbarPath();
      _currentPath = _State.routeModelKeys
          .where((e) => _State.currentRoute!.path.startsWith(e))
          .firstWhereOrNull((e) => e.endsWith(settings.name ?? ''));
      if (_State.didPop) _State.didPop = false;
    }
  }

  @override
  void didAdd() {
    _pushPage();
    _State.setShowBottomNav(true);
    super.didAdd();
  }

  /// 如果你执行push方法，或者通过go进入选项卡内部子页面（必须是子页面），将会触发此方法
  @override
  scheduler.TickerFuture didPush() {
    _pushPage();
    _State.setShowBottomNav();
    return super.didPush();
  }

  @override
  bool didPop(result) {
    _State.didPop = true;
    return super.didPop(result);
  }

  @override
  void dispose() {
    super.dispose();
    if (_State.didPop) {
      _State.didPop = false;
      _State.setShowBottomNav();
    }
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_State.previousRoute?.hideTabbar != true &&
        _currentPath != null &&
        (_State.hideTabbarRootPath == _currentPath || _State.isPopToHideTabbarRootPath)) {
      // 禁用第一帧 animation.value 防止抖动，因为它第一帧直接是1.0，然后从0-1转变
      if (_disabledFirstFrame) {
        _disabledFirstFrame = false;
      } else {
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
      // 动画结束后重置 disabledFirstFrame 状态
      if (animation.value == 0.0 || animation.value == 1.0) _disabledFirstFrame = true;
    }

    return CupertinoRouteTransitionMixin.buildPageTransitions(this, context, animation, secondaryAnimation, child);
  }
}

mixin _GoRouterUrlListenMixin<T extends StatefulWidget, D> on State<T> {
  late bool _hasListen;

  @override
  void initState() {
    super.initState();
    _State.routeModels = GoRouteModel.statefulShellRoute(_router);
    _State.routeModelMap = GoRouteModel.flatRoute(_State.routeModels);
    _State.routeModelKeys = _State.routeModelMap.keys.toList();
    _hasListen = DartUtil.listContains(_State.routeModelMap.values.toList(), (e) => e.hideTabbar);
    if (_hasListen) _router.routerDelegate.addListener(routeListen);
  }

  @override
  void dispose() {
    super.dispose();
    if (_hasListen) _router.routerDelegate.removeListener(routeListen);
  }

  /// 监听[GoRouter]声明式跳转，即通过[go]函数路由跳转，如果是选项卡式导航直接的切换跳转，[PageRoute]是监听不到的，
  /// 所以需要在此处判断上一个路由和目标路由之间是否需要显示隐藏底部导航栏。
  ///
  /// 另外，[GoRouter]的路由地址变化监听与[PageRoute]的生命周期执行顺序为：
  ///
  /// routeListen -> didAdd、disPush -> didPop -> routeListen -> dispose
  void routeListen() {
    final currentRoute = getRouteModel(_router.routerDelegate.currentConfiguration.uri.path);
    if(currentRoute!=null){
      i(currentRoute);
      _State.currentRoute = currentRoute;
      setIsPopToHideTabbarRootPath();
      _State.previousRoute = getPreviousRouteModel();
      // i(_State.currentRoute?.path, 'routeListen');
      // i(_State.previousRoute?.path, 'previousRoute');
      final newIndex = getCurrentIndex();
      if (newIndex != null && newIndex != _State.currentIndex) {
        _State.currentIndex = newIndex;
        if(FlutterUtil.hasController<TabScaffoldController>()){
          _State.setShowBottomNav(true);
        }
      }
    }
  }

  /// 解决从多级路由返回时显示、隐藏底部导航栏
  void setIsPopToHideTabbarRootPath() {
    if (_State.hideTabbarRootPath == null || _State.previousRoute == null) {
      _State.isPopToHideTabbarRootPath = false;
    } else {
      final urlList1 = _State.hideTabbarRootPath!.split('/');
      final urlList2 = _State.currentRoute!.path.split('/');
      final urlList3 = _State.previousRoute!.path.split('/');
      // 1.上一页和当前页长度一致，表示只返回一级，此函数是处理返回多级，所以不符合条件
      // 2.当前页的url长度要小于hideTabbarRootPath长度，这才表示返回到隐藏前的页面
      _State.isPopToHideTabbarRootPath = urlList2.length != urlList3.length && urlList2.length < urlList1.length;
    }
  }

  /// 解析路由地址，将其转换为[GoRouter]声明的地址
  GoRouteModel? getRouteModel(String url) {
    final urlList = url.split('/');
    final targetUrls = _State.routeModelKeys.where((e) => e.startsWith('/${urlList[1]}'));
    final matchUrlList = targetUrls.firstWhereOrNull((e) {
      final urlList2 = e.split('/');
      if (urlList2.length == urlList.length) {
        if (urlList2[urlList2.length - 1].startsWith(":")) {
          return true;
        } else {
          return urlList2[urlList2.length - 1] == urlList[urlList.length - 1];
        }
      } else {
        return false;
      }
    });
    if (matchUrlList == null) return null;
    return _State.routeModelMap[matchUrlList];
  }

  /// 获取当前路由地址的上一页路由
  GoRouteModel? getPreviousRouteModel() {
    final urlList = _State.currentRoute!.path.split('/');
    // 长度为2，表示此路由为根路由，根路由没有上一页
    if (urlList.length == 2) return null;
    final targetUrls = _State.routeModelKeys.where((e) => e.startsWith('/${urlList[1]}'));
    final matchUrlList = targetUrls.firstWhereOrNull((e) => e.split('/').length + 1 == urlList.length);
    if (matchUrlList == null) return null;
    return _State.routeModelMap[matchUrlList];
  }

  /// 根据[currentRouteUrl]获取当前所处的选项卡位置，但是，如果你是进入新的页面，拿到的却是空
  int? getCurrentIndex() {
    if (_State.currentRoute == null) return null;
    String rootPath = _State.currentRoute!.path.split('/')[1];
    for (int i = 0; i < _State.routeModels.length; i++) {
      if (_State.routeModels[i].path == '/$rootPath') {
        return i;
      }
    }
    return null;
  }

  /// 判断进入的新页面是否是返回到之前的页面
  bool isPop(String url) {
    if (_State.currentRoute == null) return false;
    i(_State.currentRoute!);
    final currentPathList = _State.currentRoute!.path.split('/');
    final newPathList = url.split('/');
    return currentPathList[1] == newPathList[1] && newPathList.length < currentPathList.length;
  }
}
