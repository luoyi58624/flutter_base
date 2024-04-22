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

/// 适用于命令式页面路由过渡动画，支持[hideTab]属性，类似于：[MaterialPageRoute]、[CupertinoPageRoute]
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

class _State {
  _State._();

  /// 当前是否已经注入了底部导航栏脚手架，如果没有注入，那么切换路由将不会应用过渡
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
    hideTabbarRootPath = currentChainList.firstWhereOrNull((e) => routeModelMap[e.path]?.hideTab == true)?.path;
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
      if (currentRoute?.hideTab == true) {
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
    if (_State.injectTabScaffoldController && _State.currentRoute != null) {
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
    if (_State.injectTabScaffoldController) _State.didPop = true;
    return super.didPop(result);
  }

  @override
  void dispose() {
    super.dispose();
    if (_State.injectTabScaffoldController && _State.didPop) {
      _State.didPop = false;
      _State.setShowBottomNav();
    }
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (_State.injectTabScaffoldController) {
      if (_State.previousRoute?.hideTab != true &&
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
    }
    return CupertinoRouteTransitionMixin.buildPageTransitions(this, context, animation, secondaryAnimation, child);
  }
}

mixin _GoRouterUrlListenMixin<T extends StatefulWidget, D> on State<T> {
  late bool _hasListen;

  @override
  void initState() {
    super.initState();
    _State.routeModels = _GoRouteModel.statefulShellRoute(router);
    _State.routeModelMap = _GoRouteModel.flatRoute(_State.routeModels);
    _State.routeModelKeys = _State.routeModelMap.keys.toList();
    _hasListen = DartUtil.listContains(_State.routeModelMap.values.toList(), (e) => e.hideTab);
    if (_hasListen) router.routerDelegate.addListener(routeListen);
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
    if (_State.injectTabScaffoldController) {
      final currentRoute = getRouteModel(router.routerDelegate.currentConfiguration.uri.path);
      if (currentRoute != null) {
        _State.currentRoute = currentRoute;
        setIsPopToHideTabbarRootPath();
        _State.previousRoute = getPreviousRouteModel();
        // i(_State.currentRoute?.path, 'routeListen');
        // i(_State.previousRoute?.path, 'previousRoute');
        final newIndex = getCurrentIndex();
        if (newIndex != null && newIndex != _State.currentIndex) {
          _State.currentIndex = newIndex;
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
  _GoRouteModel? getRouteModel(String url) {
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
  _GoRouteModel? getPreviousRouteModel() {
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
