part of flutter_base;

extension AppRouterExtension on BuildContext {
  /// 声明式跳转，通过此方法进行路由跳转会更改浏览器上面的url
  void go(String path) {
    GoRouter.of(this).go(path);
  }

  /// 命令式url跳转新页面，与[go]方法的区别在于，它不会更改浏览器上的url
  void pushUrl(String path) {
    GoRouter.of(this).push(path);
  }

  /// 跳转到新页面
  ///
  /// 提示：使用命令式导航如果需要隐藏底部tabbar，你可以使用[rootContext]进行跳转
  Future<T?> push<T>(
    Widget page, {
    RouteSettings? settings,
  }) async {
    var result = await Navigator.of(this).push<T>(_PageRouter(
      builder: (context) => page,
      settings: settings,
    ));
    return result;
  }

  /// 返回上一页
  void pop([dynamic data]) async {
    Navigator.of(this).pop(data);
  }

  /// 重定向页面，先跳转新页面，再删除之前的页面
  Future<T?> pushReplacement<T>(Widget page) async {
    return await Navigator.of(this).pushReplacement(_PageRouter(
      builder: (context) => page,
    ));
  }

  /// 跳转新页面，同时删除之前所有的路由，直到指定的routePath。
  ///
  /// 例如：如果你想跳转一个新页面，同时希望这个新页面的上一级是首页，那么就设置routePath = '/'，
  /// 它会先跳转到新的页面，再删除从首页开始后的全部路由。
  void pushAndRemoveUntil(Widget page, String routePath) async {
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
  void pushAndRemoveAllUntil(Widget page) async {
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
}
