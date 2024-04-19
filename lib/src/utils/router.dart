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
  /// * hideTabbar 如果为true，则进入到此页面将隐藏底部tabbar，请在所有需要隐藏tabbar的页面添加此属性
  Page<dynamic> pageBuilder<T>(
    GoRouterState state,
    Widget page, {
    bool hideTabbar = false,
  }) =>
      _Page<void>(
        key: state.pageKey,
        name: state.name ?? state.path,
        arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
        restorationId: state.pageKey.value,
        child: page,
        hideTabbar: hideTabbar,
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
                  hideTabbar: false,
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
    required this.hideTabbar,
  });

  final bool hideTabbar;

  @override
  Route<T> createRoute(BuildContext context) {
    return _PageBasedPageRoute<T>(
      page: this,
      allowSnapshotting: allowSnapshotting,
      hideTabbar: hideTabbar,
    );
  }
}

/// 适用于[GoRouter]定义的声明式页面路由过渡动画，
class _PageBasedPageRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin, _CupertinoRouteTransitionMixin {
  _PageBasedPageRoute({
    required CupertinoPage<T> page,
    required this.hideTabbar,
    super.allowSnapshotting = true,
  }) : super(settings: page) {
    assert(opaque);
  }

  final bool hideTabbar;

  @override
  bool get _hideTabbar => hideTabbar;

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
  bool get _hideTabbar => hideTabbar;

  @override
  bool get maintainState => true;

  @override
  String? get title => null;

  @override
  Widget buildContent(BuildContext context) => builder(context);
}

class _RoutePageHistoryModel {
  _RoutePageHistoryModel(
    this.id,
    this.path,
    this.hideTabbar,
    this.isPop,
  );

  int id;
  String? path;
  final bool hideTabbar;
  bool isPop;

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'hideTabbar': hideTabbar,
      'isPop': isPop,
    };
  }
}

class _RoutePageState {
  _RoutePageState._();

  /// 当前路由地址
  static String? currentPath;

  /// 上一次的路由地址
  static String? previousPath;

  /// 当前顶级路由位置
  static int currentIndex = 0;

  /// 二维历史记录数组，它对应的是[GoRouter]的并行导航
  static final List<List<_RoutePageHistoryModel>> history = [];

  /// 当用户直接通过[go]跳转到某个分支的深层页面，或者用户在某个分支的深层页面刷新浏览器，[GoRouter]会从当前分支开始，依次
  /// 构建父级页面，直到最顶层，而此数组则是保存当前路由结构，到达最顶层后从最顶层开始依次添加到[urlHistory]
  static final List<_RoutePageHistoryModel> tempHistory = [];

  /// 设置当前顶级路由位置
  static void setCurrentIndex() {
    String rootPath = currentPath!.split('/')[1];
    for (int i = 0; i < history.length; i++) {
      if (history[i][0].path == '/$rootPath') {
        currentIndex = i;
        break;
      }
    }
  }

  /// 注册的路由path集合
  static List<String> get pathList {
    List<String> list = [];
    history.forEach((childList) {
      childList.forEach((e) {
        if (e.path != null) list.add(e.path!);
      });
    });
    return list;
  }

  /// 页面hashCode集合
  static List<int> get hashCodeList {
    List<int> list = [];
    history.forEach((childList) {
      childList.forEach((e) {
        list.add(e.id);
      });
    });
    return list;
  }

  /// 最后一级页面是否需要隐藏底部导航栏
  static bool get hideTabbar => history[currentIndex].last.hideTabbar;

  /// 当前页面上一级是否需要隐藏底部导航栏
  static bool get previousHideTabbar {
    final currentHistory = history[currentIndex];
    if (currentHistory.length <= 1) {
      return false;
    } else {
      return currentHistory[currentHistory.length - 2].hideTabbar == true;
    }
  }

  /// 只有当上一级不需要隐藏底部导航栏、以及当前页面需要隐藏底部导航栏时才允许执行更新动画
  static bool get allowUpdateTabbar => (!previousHideTabbar && hideTabbar) || (previousHideTabbar && !hideTabbar);

  /// 锁定当前页面的buildTransitions过渡转换
  static bool lockCurrentPage(int hashCode) {
    return history[currentIndex].last.id == hashCode;
  }

  /// 根据地址获取当前页面历史对象
  static _RoutePageHistoryModel? getHistoryModel(String url) {
    for (int i = 0; i < history.length; i++) {
      for (int j = 0; j < history[i].length; j++) {
        if (history[i][j].path == url) {
          return history[i][j];
        }
      }
    }
    return null;
  }

  static void pushPage(_RoutePageHistoryModel model) {
    if (model.path == null) {
      history[currentIndex].add(model);
    } else {
      // 处理动态路由
      if (model.path!.startsWith(':')) {
        final urlList = currentPath!.split('/');
        urlList[urlList.length - 1] = model.path!;
        model.path = urlList.join('/');
        history[currentIndex].add(model);
      } else {
        // 处理其他路由，我们先拿到符合条件的前缀路由集合，再根据/分割成数组进行长度匹配
        final targetUrl = matchUrl(currentPath!, true);
        assert(targetUrl != null, 'didPush匹配的路由不可能为空');
        model.path = '$targetUrl/${model.path}';
        history[currentIndex].add(model);
      }
    }
  }

  /// 标记退出的历史页面
  static void markPopPage() {
    history[currentIndex].last.isPop = true;
  }

  /// 移除退出的历史页面
  static void removePopPage(int hashCode) {
    // 当用户完全退出后根据条件是否显示、隐藏底部导航栏，如果用户在路由过渡期间又立即进行新的页面，那么就无需执行此逻辑
    if (history[currentIndex].last.isPop) {
      if (hideTabbar) {
        if (!previousHideTabbar) {
          // 如果当前页面需要隐藏，但上一页不需要隐藏，则显示底部导航栏
          TabScaffoldController.of._showBottomNav.value = true;
        }
      } else {
        if (previousHideTabbar) {
          // 如果当前页面不需要隐藏，但上一页需要隐藏，则隐藏底部导航栏
          TabScaffoldController.of._showBottomNav.value = false;
        }
      }
    }
    for (int i = 0; i < history.length; i++) {
      for (int j = 0; j < history[i].length; j++) {
        if (history[i][j].id == hashCode) {
          history[i].removeAt(j);
          break;
        }
      }
    }
  }

  /// 根据当前路由地址，匹配[urlHistory]中的地址
  static String? matchUrl(String url, [bool? matchParent]) {
    final urlList = url.split('/');
    final targetUrls = pathList.where((e) => e.startsWith('/${urlList[1]}'));
    final matchUrlList =
        targetUrls.where((e) => e.split('/').length + (matchParent == true ? 1 : 0) == urlList.length).toList();
    if (matchUrlList.isNotEmpty) {
      return matchUrlList[0];
    } else {
      return null;
    }
  }
}

/// 定制Cupertino路由切换动画，如果进入新页面设置了隐藏底部导航栏，将在路由转换时应用显示、隐藏底部导航栏动画
mixin _CupertinoRouteTransitionMixin<T> on CupertinoRouteTransitionMixin<T> {
  /// 当前路由是否隐藏tabbar
  bool get _hideTabbar => false;

  /// 禁用第一帧动画，buildTransitions第一帧的animation值是目标动画的最终值，这会导致底部导航栏隐藏过程中出现轻微抖动
  bool disabledFirstFrame = true;

  /// 判断路由页面名字是否为空，[settings.name]是[GoRouter]设置的路由地址
  bool get nameIsNotNull => settings.name != null && settings.name != '';

  /// 当立即显示新的路由时执行的方法，它不会和[didPush]同时执行，和[didPush]最大的不同在于，[didPush]会触发过渡动画，但[didAdd]不会。
  ///
  /// 触发此方法的时机有以下几点：
  /// * 每一条选项卡都存在独立的导航堆栈，当你切换到新的选项卡时，便会执行[didAdd]方法
  /// * 当你进入某个选项卡深度子页面时，目标路由页面会触发[didPush]，中间的子页面会触发[didAdd]
  /// * 当你已经处于某个选项卡深度子页面时，刷新浏览器或进入深度链接打开App，从当前页面开始，向上依次执行[didAdd]方法，直到根页面
  @override
  void didAdd() {
    // logger.i('didAdd', settings.name);
    assert(nameIsNotNull, '只有GoRouter创建的声明式路由才能触发didAdd方法，所以它必定存在路由名字，但却获得空，请检查相关代码逻辑！');
    if (isFirst) {
      // 创建新的历史记录
      List<_RoutePageHistoryModel> newHistory = [];
      newHistory.add(_RoutePageHistoryModel(hashCode, settings.name!, _hideTabbar, false));
      if (_RoutePageState.tempHistory.isNotEmpty) {
        for (int i = 0; i < _RoutePageState.tempHistory.length; i++) {
          _RoutePageState.tempHistory[i].path = '${settings.name!}/${_RoutePageState.tempHistory[i].path}';
        }
        newHistory.addAll(_RoutePageState.tempHistory);
        _RoutePageState.tempHistory.clear();
      }
      _RoutePageState.history.add(newHistory);
      if (_RoutePageState.hideTabbar) {
        TabScaffoldController.of._tabbarAnimationHeight.value = 0.0;
        TabScaffoldController.of._showBottomNav.value = false;
      }
    } else {
      if (_RoutePageState.tempHistory.isEmpty) {
        _RoutePageState.tempHistory.add(_RoutePageHistoryModel(hashCode, settings.name!, _hideTabbar, false));
      } else {
        for (int i = 0; i < _RoutePageState.tempHistory.length; i++) {
          _RoutePageState.tempHistory[i].path = '${settings.name!}/${_RoutePageState.tempHistory[i].path}';
        }
        _RoutePageState.tempHistory.insert(0, _RoutePageHistoryModel(hashCode, settings.name!, _hideTabbar, false));
      }
    }
    super.didAdd();
  }

  /// 如果你执行push方法，或者通过go进入选项卡内部子页面（必须是子页面），将会触发此方法
  @override
  scheduler.TickerFuture didPush() {
    // logger.i('didPush', settings.name);
    _RoutePageState.pushPage(_RoutePageHistoryModel(hashCode, settings.name, _hideTabbar, false));
    if (_RoutePageState.hideTabbar) {
      if (!_RoutePageState.previousHideTabbar) {
        TabScaffoldController.of._showBottomNav.value = false;
      }
    } else {
      if (_RoutePageState.previousHideTabbar) {
        TabScaffoldController.of._showBottomNav.value = true;
      }
    }
    return super.didPush();
  }

  @override
  bool didPop(result) {
    _RoutePageState.markPopPage();
    // logger.i('didPop', settings.name);
    return super.didPop(result);
  }

  @override
  void dispose() {
    super.dispose();
    // logger.i('dispose', settings.name);
    _RoutePageState.removePopPage(hashCode);
  }

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // 禁用第一帧 animation.value 防止抖动，因为它第一帧直接是1.0，然后从0-1转变
    if (disabledFirstFrame) {
      disabledFirstFrame = false;
    } else {
      // 锁定当前页面的过渡
      if (_RoutePageState.lockCurrentPage(hashCode)) {
        // logger.i(TabScaffoldController.of._tabbarAnimationHeight);
        final tween = _RoutePageState.hideTabbar
            ? Tween(begin: TabScaffoldController.of.bottomNavHeight, end: 0.0)
            : Tween(begin: 0.0, end: TabScaffoldController.of.bottomNavHeight);

        if (_RoutePageState.allowUpdateTabbar) {
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
      // 动画结束后重置 disabledFirstFrame 状态
      if (animation.value == 0.0 || animation.value == 1.0) {
        AsyncUtil.delayed(() {
          disabledFirstFrame = true;
        }, 16);
      }
    }

    return CupertinoRouteTransitionMixin.buildPageTransitions(this, context, animation, secondaryAnimation, child);
  }
}

mixin GoRouterUrlListenMixin<T extends StatefulWidget, D> on State<T> {
  @override
  void initState() {
    super.initState();
    _router.routerDelegate.addListener(routeListen);
  }

  @override
  void dispose() {
    super.dispose();
    _router.routerDelegate.removeListener(routeListen);
  }

  /// 监听[GoRouter]声明式跳转，即通过[go]函数路由跳转，如果是选项卡式导航直接的切换跳转，[PageRoute]是监听不到的，
  /// 所以需要在此处判断上一个路由和目标路由之间是否需要显示隐藏底部导航栏。
  ///
  /// 另外，[GoRouter]的路由地址变化监听与[PageRoute]的生命周期执行顺序为：
  ///
  /// routeListen -> didAdd、disPush -> didPop -> routeListen -> dispose
  void routeListen() {
    String url = _router.routerDelegate.currentConfiguration.uri.path;
    _RoutePageState.previousPath = _RoutePageState.currentPath;
    _RoutePageState.currentPath = url;
    _RoutePageState.setCurrentIndex();
    if (_RoutePageState.previousPath != null) {
      // 1.根据当前path获取历史中的目标path，因为存在动态路由，所以需要解析
      final previousPath = _RoutePageState.matchUrl(_RoutePageState.previousPath!);
      final currentPath = _RoutePageState.matchUrl(_RoutePageState.currentPath!);
      // 2.二者必须都不为空才进行下一步操作，因为这样才能确保当前跳转是选项卡中已存在的路由之间切换
      if (previousPath != null && currentPath != null) {
        final previousModel = _RoutePageState.getHistoryModel(previousPath);
        final currentModel = _RoutePageState.getHistoryModel(currentPath);
        // 3.当找到上一路由历史模型后，同时还要排除用户手动退出当前路由的情况，因为这部分逻辑是由RoutePage处理，
        // 我们需要做的是处理go函数在选项卡式之间的跳转，它不会退出当前路由。
        if (previousModel != null && !previousModel.isPop) {
          if (currentModel!.hideTabbar) {
            if (TabScaffoldController.of._showBottomNav.value) {
              TabScaffoldController.of._tabbarAnimationHeight.value = 0;
              TabScaffoldController.of._showBottomNav.value = false;
            }
          } else {
            if (TabScaffoldController.of._showBottomNav.value == false) {
              TabScaffoldController.of._tabbarAnimationHeight.value = TabScaffoldController.of.bottomNavHeight;
              TabScaffoldController.of._showBottomNav.value = true;
            }
          }
        }
      }
    }
  }
}
