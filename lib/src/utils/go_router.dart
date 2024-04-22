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
    this.hideTab = false,
    this.bodyPaddingAnimation = true,
  });

  /// 是否隐藏底部导航栏，如果父级路由设置为true，那么子级将强制为true
  final bool hideTab;

  /// body底部padding是否应用动画，默认true，跳转隐藏底部导航栏的页面时，内容页面的底部padding值会同步跟随导航栏的高度，
  /// 导致body高度会不断发生变化，这会破坏[Hero]动画，如果你的页面应用了[Hero]动画，例如[CupertinoNavigationBar]，
  /// 请将该值设置为false，当页面跳转时会立即设置底部间距，而不是跟随底部导航栏高度的变化。
  final bool bodyPaddingAnimation;
}

class _GoRouteModel extends Object {
  final String path;
  final bool hideTab;
  final bool bodyPaddingAnimation;
  List<_GoRouteModel>? children;

  _GoRouteModel({
    required this.path,
    required this.hideTab,
    required this.bodyPaddingAnimation,
    this.children,
  });

  _GoRouteModel clone() {
    return _GoRouteModel(
      path: path,
      hideTab: hideTab,
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
        bool hideTab = e.hideTab;
        if (parent != null) {
          path = '${parent.path}/$path';
          if (parent.hideTab) hideTab = true;
        }
        final model = _GoRouteModel(path: path, hideTab: hideTab, bodyPaddingAnimation: e.bodyPaddingAnimation);
        if (e.routes.isNotEmpty) model.children = _routeToModel(e.routes, model);
        list.add(model);
      }
    });
    return list;
  }

  @override
  String toString() {
    if (children != null) {
      return '_GoRouteModel{path: $path, hideTab: $hideTab, bodyPaddingAnimation: $bodyPaddingAnimation, children: $children}';
    } else {
      return '_GoRouteModel{path: $path, hideTab: $hideTab, bodyPaddingAnimation: $bodyPaddingAnimation}';
    }
  }
}
