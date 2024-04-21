part of flutter_base;

class GoRoute extends go_router.GoRoute {
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
    this.enabledPaddingAnimation = true,
  });

  /// 是否隐藏底部导航栏，如果父级路由设置为true，那么子级将强制为true
  final bool hideTabbar;

  /// 跳转需要隐藏底部导航栏的页面时，如果页面应用了[Hero]动画，例如[CupertinoNavigationBar]，
  /// 请将此选项设置为false，如果为false，页面改变时将会立即设置底部间距，而不是跟随底部导航栏高度的变化。
  final bool enabledPaddingAnimation;
}

class GoRouteModel extends Object {
  final String path;
  final bool hideTabbar;
  List<GoRouteModel>? children;

  GoRouteModel({
    required this.path,
    required this.hideTabbar,
    this.children,
  });

  GoRouteModel clone() {
    return GoRouteModel(
      path: path,
      hideTabbar: hideTabbar,
      children: children,
    );
  }

  /// 将[StatefulShellRoute]转换成[GoRouteModel]数组
  static List<GoRouteModel> statefulShellRoute(GoRouter router) {
    List<GoRouteModel> routePathList = [];
    router.configuration.routes.forEach((e) {
      if (e is StatefulShellRoute) {
        routePathList.addAll(_routeToModel(e.routes)!);
      }
    });
    return routePathList;
  }

  /// 将嵌套数组展开平铺
  static Map<String, GoRouteModel> flatRoute(List<GoRouteModel> routes, [Map<String, GoRouteModel>? map]) {
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

  static List<GoRouteModel>? _routeToModel(List<RouteBase> routes, [GoRouteModel? parent]) {
    if (routes.isEmpty) return null;
    List<GoRouteModel> list = [];
    routes.forEach((e) {
      if (e is GoRoute) {
        String path = e.path;
        bool hideTabbar = e.hideTabbar;
        if (parent != null) {
          path = '${parent.path}/$path';
          if (parent.hideTabbar) hideTabbar = true;
        }
        final model = GoRouteModel(path: path, hideTabbar: hideTabbar);
        if (e.routes.isNotEmpty) model.children = _routeToModel(e.routes, model);
        list.add(model);
      }
    });
    return list;
  }

  @override
  String toString() {
    if (children != null) {
      return 'GoRouteModel{path: $path, hideTabbar: $hideTabbar, children: $children}';
    } else {
      return 'GoRouteModel{path: $path, hideTabbar: $hideTabbar}';
    }
  }
}
