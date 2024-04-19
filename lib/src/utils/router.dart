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
  );

  int id;
  String? path;
  final bool hideTabbar;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'hideTabbar': hideTabbar,
    };
  }

  @override
  String toString() {
    return '_RoutePageHistoryModel{id: $id, path: $path, hideTabbar: $hideTabbar}';
  }
}

class _RoutePageState {
  _RoutePageState._();

  /// 当前路由地址，与[currentPath]不同点在于：
  /// * currentRouteUrl -> /user/2
  /// * currentPath -> /user/:id
  static late String currentRouteUrl;

  /// 当前路由编码设定的地址
  static String? currentPath;

  /// 上一次的路由地址
  static String? previousPath;

  /// 当前路由历史对象
  static _RoutePageHistoryModel? currentModel;

  /// 上一次路由历史对象
  static _RoutePageHistoryModel? previousModel;

  /// 当前退出的页面
  static _RoutePageHistoryModel? isPopModel;

  /// [routeListen]退出监听是否已经处理，此变量只为了防止[routeListen]在短时间内多次重复处理退出逻辑，
  /// 如果用户正常退出页面清理资源交由[popPage]处理，但若用户退出页面又快速进入，此时[popPage]将不会执行，
  /// 而是在[pushPage]中去异步清理，这样才能确保退出、进入的过渡动画的连贯性，但由于[routeListen]在[pushPage]
  /// 之前执行，所以创建此变量用于限制[routeListen]
  static bool popListenFlag = false;

  /// 当前顶级路由位置
  static int currentIndex = 0;

  /// 二维历史记录数组，它对应的是[GoRouter]的并行导航
  static final List<List<_RoutePageHistoryModel>> history = [];

  /// 当用户直接通过[go]跳转到某个分支的深层页面，或者用户在某个分支的深层页面刷新浏览器，[GoRouter]会从当前分支开始，依次
  /// 构建父级页面，直到最顶层，而此数组则是保存当前路由结构，到达最顶层后从最顶层开始依次添加到[urlHistory]
  static final List<_RoutePageHistoryModel> tempHistory = [];

  /// 待销毁的hashCode集合，创建这个集合是为了解决[GoRouter]从深层子路由直接返回顶部的问题，
  /// 此时只有最深层子路由会执行didPop，中间的子路由只会触发dispose
  static Set<int> disposeHashCodeList = {};

  /// 用户当进入新页面时(无论是push、还是go，都算进入新页面)，统一更新所有状态
  static void goUpdate(_RoutePageHistoryModel model) {
    previousPath = currentPath;
    currentPath = model.path;
    currentModel = getHistoryModel(currentPath);
    previousModel = getHistoryModel(previousPath);
    setCurrentIndex();
  }

  /// 设置当前顶级路由位置
  static void setCurrentIndex() {
    final index = getCurrentIndex();
    if (index != null) currentIndex = index;
  }

  /// 根据[currentRouteUrl]获取当前所处的选项卡位置，但是，如果你是进入新的页面，拿到的却是空
  static int? getCurrentIndex() {
    String rootPath = currentRouteUrl.split('/')[1];
    for (int i = 0; i < history.length; i++) {
      if (history[i][0].path == '/$rootPath') {
        return i;
      }
    }
    return null;
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

  /// 最后一级页面是否需要隐藏底部导航栏
  static bool get hideTabbar => currentModel != null && currentModel!.hideTabbar;

  /// 当前页面上一级是否需要隐藏底部导航栏
  static bool get previousHideTabbar => previousModel != null && previousModel!.hideTabbar;

  /// 只有当上一级不需要隐藏底部导航栏、以及当前页面需要隐藏底部导航栏时才允许执行更新动画
  static bool get allowUpdateTabbar => (!previousHideTabbar && hideTabbar) || (previousHideTabbar && !hideTabbar);

  /// 锁定当前页面的buildTransitions过渡转换
  static bool lockCurrentPage(int hashCode) => currentModel != null && currentModel!.id == hashCode;

  /// 根据path获取当前页面历史对象
  static _RoutePageHistoryModel? getHistoryModel(String? path) {
    _RoutePageHistoryModel? model;
    if (path == null) return null;
    for (int i = 0; i < history.length; i++) {
      for (int j = 0; j < history[i].length; j++) {
        if (history[i][j].path == path) {
          model = history[i][j];
        }
      }
    }
    return model;
  }

  /// push新页面
  static void pushPage(_RoutePageHistoryModel model) {
    if (isPopModel != null) {
      isPopModel = null;
      _RoutePageState.popListenFlag = false;
      // 异步删除旧页面，因为必须等待dispose全部执行完毕
      AsyncUtil.delayed(() {
        disposeHashCodeList.forEach((e) {
          for (int i = 0; i < history.length; i++) {
            for (int j = 0; j < history[i].length; j++) {
              if (history[i][j].id == e) {
                history[i].removeAt(j);
                break;
              }
            }
          }
        });
        disposeHashCodeList.clear();
      }, 500);
    }
    // 使用命令式跳转的页面，它没有path
    if (model.path == null) {
      history[currentIndex].add(model);
    } else {
      // 我们先拿到符合条件的前缀路由集合，再根据/分割成数组进行长度匹配
      final targetUrl = matchUrl(currentRouteUrl, true);
      // 如果没有匹配到，那么只有一种情况，那就是通过go直接访问深层页面，上级路由将通过didAdd加载，但它们在didPush后面执行，
      // 我们将其放入到临时路由页面中，等didAdd加载完成后再添加到历史记录中
      if (targetUrl == null) {
        tempHistory.add(model);
      } else {
        model.path = '$targetUrl/${model.path}';
        history[currentIndex].add(model);
        goUpdate(model);
      }
    }
  }

  /// 移除退出的历史页面
  static void popPage(int hashCode) {
    disposeHashCodeList.add(hashCode);
    // 一定要判断当前hashCode是否与isPopModel的id是否相同，如果你通过go返回层级 >=2 之前的页面，
    // GoRouter会从之前的页面开始依次调用dispose，注意：之前的页面不会调用didPop，这样以下逻辑便可以
    // 统一销毁掉所有dispose的路由。
    if (isPopModel != null && hashCode == isPopModel!.id) {
      isPopModel = null;
      _RoutePageState.popListenFlag = false;
      currentModel = getHistoryModel(currentPath);
      previousModel = getHistoryModel(previousPath);
      // 如果退出后的当前也需要隐藏底部导航栏，但上一页不隐藏，则隐藏底部导航栏
      if (hideTabbar) {
        if (!previousHideTabbar) {
          TabScaffoldController.of._showBottomNav.value = false;
        }
      } else {
        // 如果退出后当前页面不需要隐藏底部导航栏，但上一页需要隐藏，则显示底部导航栏
        if (previousHideTabbar) {
          TabScaffoldController.of._showBottomNav.value = true;
        }
      }
      disposeHashCodeList.forEach((e) {
        for (int i = 0; i < history.length; i++) {
          for (int j = 0; j < history[i].length; j++) {
            if (history[i][j].id == e) {
              history[i].removeAt(j);
              break;
            }
          }
        }
      });
      disposeHashCodeList.clear();
    }
  }

  /// 根据当前路由地址，匹配[urlHistory]中的地址
  static String? matchUrl([String? url, bool? matchParent]) {
    if (url == null) return null;
    final urlList = url.split('/');
    final targetUrls = pathList.where((e) => e.startsWith('/${urlList[1]}'));
    final matchUrlList =
        targetUrls.where((e) => (e.split('/').length + (matchParent == true ? 1 : 0)) == urlList.length).toList();
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
    assert(nameIsNotNull, '只有GoRouter创建的声明式路由才能触发didAdd方法，所以它必定存在路由名字，但却获得空，请检查相关代码逻辑！');
    if (isFirst) {
      // 创建新的历史记录
      List<_RoutePageHistoryModel> newHistory = [];
      newHistory.add(_RoutePageHistoryModel(hashCode, settings.name!, _hideTabbar));
      if (_RoutePageState.tempHistory.isNotEmpty) {
        for (int i = 0; i < _RoutePageState.tempHistory.length; i++) {
          _RoutePageState.tempHistory[i].path = '${settings.name!}/${_RoutePageState.tempHistory[i].path}';
        }
        newHistory.addAll(_RoutePageState.tempHistory);
        _RoutePageState.tempHistory.clear();
      }
      // 如果追加的新路由属于根路由，则直接在历史记录中添加，否则添加到已存在的根路由
      if (newHistory.first.path!.startsWith('/')) {
        _RoutePageState.history.add(newHistory);
      } else {
        final index = _RoutePageState.getCurrentIndex();
        assert(index != null, '追加的新路由不属于根路由，那么历史记录中必定存在根路由索引');
        _RoutePageState.history[index!].addAll(newHistory);
        i(newHistory);
      }
      _RoutePageState.goUpdate(newHistory.last);
      if (_RoutePageState.hideTabbar) {
        TabScaffoldController.of._tabbarAnimationHeight.value = 0.0;
        TabScaffoldController.of._showBottomNav.value = false;
      }
    } else {
      if (_RoutePageState.tempHistory.isEmpty) {
        _RoutePageState.tempHistory.add(_RoutePageHistoryModel(hashCode, settings.name!, _hideTabbar));
      } else {
        for (int i = 0; i < _RoutePageState.tempHistory.length; i++) {
          _RoutePageState.tempHistory[i].path = '${settings.name!}/${_RoutePageState.tempHistory[i].path}';
        }
        _RoutePageState.tempHistory.insert(0, _RoutePageHistoryModel(hashCode, settings.name!, _hideTabbar));
      }
    }
    super.didAdd();
  }

  /// 如果你执行push方法，或者通过go进入选项卡内部子页面（必须是子页面），将会触发此方法
  @override
  scheduler.TickerFuture didPush() {
    _RoutePageState.pushPage(_RoutePageHistoryModel(hashCode, settings.name, _hideTabbar));
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
    // i('didPop', settings.name);
    _RoutePageState.isPopModel = _RoutePageState.currentModel;
    return super.didPop(result);
  }

  @override
  void dispose() {
    super.dispose();
    _RoutePageState.popPage(hashCode);
    // i(_RoutePageState.history, 'dispose');
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
      if (animation.value == 0.0 || animation.value == 1.0) disabledFirstFrame = true;
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
    _RoutePageState.currentRouteUrl = _router.routerDelegate.currentConfiguration.uri.path;
    final currentPath = _RoutePageState.matchUrl(_RoutePageState.currentRouteUrl);
    // 1.如果进入的目标路由为空，则表示此路由属于新页面，将交由PageRoute去实现
    if (currentPath == null) return;
    // 2.限制快速退出、进入页面
    if (_RoutePageState.popListenFlag == true) return;
    // 3.如果监听到的路由是退出页面，那么在这里只需要设置好当前路由和上一路由即可
    if (_RoutePageState.isPopModel != null) {
      _RoutePageState.popListenFlag = true;
      _RoutePageState.currentPath = currentPath;
      _RoutePageState.previousPath = _RoutePageState.isPopModel!.path;
      _RoutePageState.setCurrentIndex();
      return;
    }
    // 3.处理go函数在选项卡式之间的跳转
    _RoutePageState.previousPath = _RoutePageState.currentPath;
    _RoutePageState.currentPath = currentPath;
    _RoutePageState.previousModel = _RoutePageState.currentModel;
    _RoutePageState.currentModel = _RoutePageState.getHistoryModel(currentPath);
    _RoutePageState.setCurrentIndex();
    if (_RoutePageState.currentModel!.hideTabbar) {
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
