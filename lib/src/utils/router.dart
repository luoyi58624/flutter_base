part of flutter_base;

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
  _PageRouter({required this.builder});

  final WidgetBuilder builder;

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  Widget buildContent(BuildContext context) => builder(context);
}

class _RouteState {
  _RouteState._();

  /// 当前是否已经注入了底部导航栏脚手架，如果没有注入，那么监听逻辑将不会触发
  static bool injectTabScaffoldController = false;

  /// 根路由列表
  static late final List<_GoRouteModel> routeModels;

  /// 路由模型 Map 集合
  static late final Map<String, _GoRouteModel> routeModelMap;

  /// [routeModelMap]keys集合
  static late final List<String> routeModelKeys;

  /// [currentRoute]所在的路由链
  static List<_GoRouteModel> currentChainList = [];

  /// 当前路由历史对象
  static _GoRouteModel? currentRoute;

  /// 上一次路由历史对象
  static _GoRouteModel? previousRoute;

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

  static void setRouteChain(List<_GoRouteModel> chainList, [List<_GoRouteModel>? $routeModels]) {
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
    if (injectTabScaffoldController) {
      if (currentRoute?.hideTabbar == true) {
        TabScaffoldController.of._showBottomNav.value = false;
        if (setHeight == true) TabScaffoldController.of._tabbarAnimationHeight.value = 0;
      } else {
        TabScaffoldController.of._showBottomNav.value = true;
        if (setHeight == true) {
          TabScaffoldController.of._tabbarAnimationHeight.value = TabScaffoldController.of.bottomNavHeight;
        }
      }
    }
  }
}

/// 定制Cupertino路由切换动画，如果进入新页面设置了隐藏底部导航栏，将在路由转换时应用显示、隐藏底部导航栏动画
mixin _CupertinoRouteTransitionMixin<T> on CupertinoRouteTransitionMixin<T> {
  String? _currentPath;

  /// 禁用第一帧动画，buildTransitions第一帧的animation值是目标动画的最终值，这会导致底部导航栏隐藏过程中出现轻微抖动
  bool _disabledFirstFrame = true;

  void _pushPage() {
    if (_RouteState.injectTabScaffoldController && _RouteState.currentRoute != null) {
      _RouteState.setHideTabbarPath();
      _currentPath = _RouteState.routeModelKeys
          .where((e) => _RouteState.currentRoute!.path.startsWith(e))
          .firstWhereOrNull((e) => e.endsWith(settings.name ?? ''));
      if (_RouteState.didPop) _RouteState.didPop = false;
    }
  }

  @override
  void didAdd() {
    _pushPage();
    _RouteState.setShowBottomNav(true);
    super.didAdd();
  }

  /// 如果你执行push方法，或者通过go进入选项卡内部子页面（必须是子页面），将会触发此方法
  @override
  scheduler.TickerFuture didPush() {
    _pushPage();
    _RouteState.setShowBottomNav();
    return super.didPush();
  }

  @override
  bool didPop(result) {
    if (_RouteState.injectTabScaffoldController) _RouteState.didPop = true;
    return super.didPop(result);
  }

  @override
  void dispose() {
    super.dispose();
    if (_RouteState.injectTabScaffoldController && _RouteState.didPop) {
      _RouteState.didPop = false;
      _RouteState.setShowBottomNav();
    }
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_RouteState.injectTabScaffoldController) {
      if (_RouteState.previousRoute?.hideTabbar != true &&
          _currentPath != null &&
          (_RouteState.hideTabbarRootPath == _currentPath || _RouteState.isPopToHideTabbarRootPath)) {
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
    }
    return CupertinoRouteTransitionMixin.buildPageTransitions(this, context, animation, secondaryAnimation, child);
  }
}

mixin _GoRouterUrlListenMixin<T extends StatefulWidget, D> on State<T> {
  late bool _hasListen;

  @override
  void initState() {
    super.initState();
    _RouteState.routeModels = _GoRouteModel.statefulShellRoute(router);
    _RouteState.routeModelMap = _GoRouteModel.flatRoute(_RouteState.routeModels);
    _RouteState.routeModelKeys = _RouteState.routeModelMap.keys.toList();
    _RouteState.injectTabScaffoldController = FlutterUtil.hasController<TabScaffoldController>();
    _hasListen = DartUtil.listContains(_RouteState.routeModelMap.values.toList(), (e) => e.hideTabbar);
    if (_hasListen) {
      router.routerDelegate.addListener(routeListen);
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (_hasListen) router.routerDelegate.removeListener(routeListen);
  }

  /// 监听[GoRouter]声明式跳转，即通过[go]函数路由跳转，如果是选项卡式导航直接的切换跳转，[PageRoute]是监听不到的，
  /// 所以需要在此处判断上一个路由和目标路由之间是否需要显示隐藏底部导航栏。
  ///
  /// 另外，[GoRouter]的路由地址变化监听与[PageRoute]的生命周期执行顺序为：
  ///
  /// routeListen -> didAdd、disPush -> didPop -> routeListen -> dispose
  void routeListen() {
    if (_RouteState.injectTabScaffoldController) {
      final currentRoute = getRouteModel(router.routerDelegate.currentConfiguration.uri.path);
      if (currentRoute != null) {
        _RouteState.currentRoute = currentRoute;
        setIsPopToHideTabbarRootPath();
        _RouteState.previousRoute = getPreviousRouteModel();
        // i(_RouteState.currentRoute?.path, 'routeListen');
        // i(_RouteState.previousRoute?.path, 'previousRoute');
        final newIndex = getCurrentIndex();
        if (newIndex != null && newIndex != _RouteState.currentIndex) {
          _RouteState.currentIndex = newIndex;
          _RouteState.setShowBottomNav(true);
        }
      }
    }
  }

  /// 解决从多级路由返回时显示、隐藏底部导航栏
  void setIsPopToHideTabbarRootPath() {
    if (_RouteState.hideTabbarRootPath == null || _RouteState.previousRoute == null) {
      _RouteState.isPopToHideTabbarRootPath = false;
    } else {
      final urlList1 = _RouteState.hideTabbarRootPath!.split('/');
      final urlList2 = _RouteState.currentRoute!.path.split('/');
      final urlList3 = _RouteState.previousRoute!.path.split('/');
      // 1.上一页和当前页长度一致，表示只返回一级，此函数是处理返回多级，所以不符合条件
      // 2.当前页的url长度要小于hideTabbarRootPath长度，这才表示返回到隐藏前的页面
      _RouteState.isPopToHideTabbarRootPath = urlList2.length != urlList3.length && urlList2.length < urlList1.length;
    }
  }

  /// 解析路由地址，将其转换为[GoRouter]声明的地址
  _GoRouteModel? getRouteModel(String url) {
    final urlList = url.split('/');
    final targetUrls = _RouteState.routeModelKeys.where((e) => e.startsWith('/${urlList[1]}'));
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
    return _RouteState.routeModelMap[matchUrlList];
  }

  /// 获取当前路由地址的上一页路由
  _GoRouteModel? getPreviousRouteModel() {
    final urlList = _RouteState.currentRoute!.path.split('/');
    // 长度为2，表示此路由为根路由，根路由没有上一页
    if (urlList.length == 2) return null;
    final targetUrls = _RouteState.routeModelKeys.where((e) => e.startsWith('/${urlList[1]}'));
    final matchUrlList = targetUrls.firstWhereOrNull((e) => e.split('/').length + 1 == urlList.length);
    if (matchUrlList == null) return null;
    return _RouteState.routeModelMap[matchUrlList];
  }

  /// 根据[currentRouteUrl]获取当前所处的选项卡位置，但是，如果你是进入新的页面，拿到的却是空
  int? getCurrentIndex() {
    if (_RouteState.currentRoute == null) return null;
    String rootPath = _RouteState.currentRoute!.path.split('/')[1];
    for (int i = 0; i < _RouteState.routeModels.length; i++) {
      if (_RouteState.routeModels[i].path == '/$rootPath') {
        return i;
      }
    }
    return null;
  }

  /// 判断进入的新页面是否是返回到之前的页面
  bool isPop(String url) {
    if (_RouteState.currentRoute == null) return false;
    i(_RouteState.currentRoute!);
    final currentPathList = _RouteState.currentRoute!.path.split('/');
    final newPathList = url.split('/');
    return currentPathList[1] == newPathList[1] && newPathList.length < currentPathList.length;
  }
}
