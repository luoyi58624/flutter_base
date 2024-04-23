part of flutter_base;

/// 扩展 go_router 的[GoRoute]对象，新增两个属性，用于支持隐藏底部导航栏。实现类似于跳转到根页面需求。
///
/// 提示：如果你声明的路由没有[hideTabbar]，那么将不会监听路由
class GoRoute extends go_router.GoRoute {
  /// 声明式路由配置
  GoRoute({
    required super.path,
    super.name,
    super.builder,
    super.pageBuilder,
    super.parentNavigatorKey,
    super.redirect,
    super.onExit,
    super.routes = const <RouteBase>[],
    this.hideTabbar = false,
    this.bodyPaddingAnimation = true,
  });

  /// 是否隐藏底部导航栏，如果父级路由设置为true，那么子级将强制为true。
  final bool hideTabbar;

  /// body底部padding是否应用动画，默认true，跳转隐藏底部导航栏的页面时，内容页面的底部padding值会同步跟随导航栏的高度，
  /// 导致body高度会不断发生变化，这会破坏[Hero]动画，如果你的页面应用了[Hero]动画，例如[CupertinoNavigationBar]，
  /// 请将该值设置为false，当页面跳转时会立即设置底部间距，而不是跟随底部导航栏高度的变化。
  final bool bodyPaddingAnimation;
}

/// [GoRoute]的配置模型，精简内部属性
class _GoRouteModel {
  final String path;
  final bool hideTabbar;
  final bool bodyPaddingAnimation;
  List<_GoRouteModel>? children;

  _GoRouteModel({
    required this.path,
    required this.hideTabbar,
    required this.bodyPaddingAnimation,
    this.children,
  });

  _GoRouteModel clone() {
    return _GoRouteModel(
      path: path,
      hideTabbar: hideTabbar,
      bodyPaddingAnimation: bodyPaddingAnimation,
      children: children,
    );
  }

  /// 将[StatefulShellRoute]转换成[_GoRouteModel]数组
  static List<_GoRouteModel> statefulShellRoute(GoRouter router) {
    List<_GoRouteModel> routePathList = [];
    router.configuration.routes.forEach((e) {
      if (e is StatefulShellRoute) {
        routePathList.addAll(_routeToModel(e.routes)!);
      }
    });
    return routePathList;
  }

  /// 将嵌套数组展开平铺
  static Map<String, _GoRouteModel> flatRoute(List<_GoRouteModel> routes, [Map<String, _GoRouteModel>? map]) {
    map ??= {};
    routes.forEach((e) {
      map![e.path] = e.clone();
      if (e.children != null) {
        flatRoute(e.children!, map);
        map[e.path]!.children = null;
      }
    });
    return map;
  }

  static List<_GoRouteModel>? _routeToModel(List<RouteBase> routes, [_GoRouteModel? parent]) {
    if (routes.isEmpty) return null;
    List<_GoRouteModel> list = [];
    routes.forEach((e) {
      if (e is GoRoute) {
        String path = e.path;
        bool hideTabbar = e.hideTabbar;
        if (parent != null) {
          path = '${parent.path}/$path';
          if (parent.hideTabbar) hideTabbar = true;
        }
        final model = _GoRouteModel(path: path, hideTabbar: hideTabbar, bodyPaddingAnimation: e.bodyPaddingAnimation);
        if (e.routes.isNotEmpty) model.children = _routeToModel(e.routes, model);
        list.add(model);
      }
    });
    return list;
  }

  @override
  String toString() {
    if (children != null) {
      return '_GoRouteModel{path: $path, hideTabbar: $hideTabbar, bodyPaddingAnimation: $bodyPaddingAnimation, children: $children}';
    } else {
      return '_GoRouteModel{path: $path, hideTabbar: $hideTabbar, bodyPaddingAnimation: $bodyPaddingAnimation}';
    }
  }
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
    return _GoRoutePage<T>(
      page: this,
      allowSnapshotting: allowSnapshotting,
    );
  }
}

/// 适用于[GoRouter]定义的声明式页面路由过渡动画，
class _GoRoutePage<T> extends PageRoute<T> with CupertinoRouteTransitionMixin, _CupertinoRouteTransitionMixin {
  _GoRoutePage({
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

/// 适用于命令式页面路由过渡动画，支持[hideTabbar]属性
class _PageRouter<T> extends PageRoute<T> with CupertinoRouteTransitionMixin, _CupertinoRouteTransitionMixin {
  _PageRouter({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  Widget buildContent(BuildContext context) => builder(context);
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

/// 保存用户声明的路由状态
class _RouteState {
  _RouteState._();

  static bool allowListen = false;

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

  static void init() {
    routeModels = _GoRouteModel.statefulShellRoute(_router);
    routeModelMap = _GoRouteModel.flatRoute(routeModels);
    routeModelKeys = routeModelMap.keys.toList();
    allowListen = DartUtil.listContains(routeModelMap.values.toList(), (e) => e.hideTabbar);
    if (allowListen) _router.routerDelegate.addListener(_routeListen);
  }

  static void setHideTabbarPath() {
    currentChainList.clear();
    setRouteChain(currentChainList);
    hideTabbarRootPath = currentChainList.firstWhereOrNull((e) => routeModelMap[e.path]?.hideTabbar == true)?.path;
    if (hideTabbarRootPath != null) isPopToHideTabbarRootPath = false;
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

  /// 监听[GoRouter]声明式跳转，即通过[go]函数路由跳转，如果是选项卡式导航直接的切换跳转，[PageRoute]是监听不到的，
  /// 所以需要在此处判断上一个路由和目标路由之间是否需要显示隐藏底部导航栏。
  ///
  /// 另外，[GoRouter]的路由地址变化监听与[PageRoute]的生命周期执行顺序为：
  ///
  /// routeListen -> didAdd、disPush -> didPop -> routeListen -> dispose
  static void _routeListen() {
    if (injectTabScaffoldController) {
      final currentRoute = getRouteModel(_router.routerDelegate.currentConfiguration.uri.path);
      if (currentRoute != null) {
        _RouteState.currentRoute = currentRoute;
        setIsPopToHideTabbarRootPath();
        previousRoute = getPreviousRouteModel();
        final newIndex = getCurrentIndex();
        if (newIndex != null && newIndex != currentIndex) {
          currentIndex = newIndex;
          setShowBottomNav(true);
        }
      }
    }
  }

  /// 解决从多级路由返回时显示、隐藏底部导航栏
  static void setIsPopToHideTabbarRootPath() {
    if (hideTabbarRootPath == null || previousRoute == null) {
      isPopToHideTabbarRootPath = false;
    } else {
      final urlList1 = hideTabbarRootPath!.split('/');
      final urlList2 = currentRoute!.path.split('/');
      final urlList3 = previousRoute!.path.split('/');
      // 1.上一页和当前页长度一致，表示只返回一级，此函数是处理返回多级，所以不符合条件
      // 2.当前页的url长度要小于hideTabbarRootPath长度，这才表示返回到隐藏前的页面
      isPopToHideTabbarRootPath = urlList2.length != urlList3.length && urlList2.length < urlList1.length;
    }
  }

  /// 解析路由地址，将其转换为[GoRouter]声明的地址
  static _GoRouteModel? getRouteModel(String url) {
    final urlList = url.split('/');
    final targetUrls = routeModelKeys.where((e) => e.startsWith('/${urlList[1]}'));
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
    return routeModelMap[matchUrlList];
  }

  /// 获取当前路由地址的上一页路由
  static _GoRouteModel? getPreviousRouteModel() {
    final urlList = currentRoute!.path.split('/');
    // 长度为2，表示此路由为根路由，根路由没有上一页
    if (urlList.length == 2) return null;
    final targetUrls = routeModelKeys.where((e) => e.startsWith('/${urlList[1]}'));
    final matchUrlList = targetUrls.firstWhereOrNull((e) => e.split('/').length + 1 == urlList.length);
    if (matchUrlList == null) return null;
    return routeModelMap[matchUrlList];
  }

  /// 根据[currentRouteUrl]获取当前所处的选项卡位置，但是，如果你是进入新的页面，拿到的却是空
  static int? getCurrentIndex() {
    if (currentRoute == null) return null;
    String rootPath = currentRoute!.path.split('/')[1];
    for (int i = 0; i < routeModels.length; i++) {
      if (routeModels[i].path == '/$rootPath') {
        return i;
      }
    }
    return null;
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
