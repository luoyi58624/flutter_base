part of flutter_base;

extension BuildContextExtension on BuildContext {
  /// 根据当前[ThemeMode]获取相应的主题配置
  FlutterThemeData get currentTheme => FlutterUtil.isDarkMode(this) ? FlutterController.of.darkTheme : FlutterController.of.theme;

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
