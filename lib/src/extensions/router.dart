part of flutter_base;

extension FlutterBaseRouterExtension on BuildContext {
  /// 跳转到新页面
  Future<T?> push<T>(
    Widget page, {
    RouteSettings? settings,
  }) async {
    var result = await Navigator.of(this).push<T>(CupertinoPageRoute(
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
  Future<T?> pushReplacement<T>(
    Widget page, {
    RouteSettings? settings,
  }) async {
    return await Navigator.of(this).pushReplacement(CupertinoPageRoute(
      builder: (context) => page,
      settings: settings,
    ));
  }

  /// 跳转新页面，同时删除之前所有的路由，直到指定的routePath。
  ///
  /// 例如：如果你想跳转一个新页面，同时希望这个新页面的上一级是首页，那么就设置routePath = '/'，
  /// 它会先跳转到新的页面，再删除从首页开始后的全部路由。
  void pushAndRemoveUntil(
    Widget page,
    String routePath, {
    RouteSettings? settings,
  }) async {
    Navigator.of(this).pushAndRemoveUntil(
      CupertinoPageRoute(
        builder: (context) => page,
        settings: settings,
      ),
      ModalRoute.withName(routePath),
    );
  }

  /// 退出到指定位置
  void popUntil(String routePath) async {
    Navigator.of(this).popUntil(
      ModalRoute.withName(routePath),
    );
  }

  /// 进入新的页面并删除之前所有路由
  void pushAndRemoveAllUntil(
    Widget page, {
    RouteSettings? settings,
  }) async {
    Navigator.of(this).pushAndRemoveUntil(
      CupertinoPageRoute(
        builder: (context) => page,
        settings: settings,
      ),
      (route) => false,
    );
  }
}
