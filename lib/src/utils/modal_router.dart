part of flutter_base;

/// 模态路由工具类，对modal_bottom_sheet进行的封装
class ModalRouterUtil {
  ModalRouterUtil._();

  /// 进入包含Cupertino弹窗页面
  static Future<T?> toMaterialWithModalsPage<T>(BuildContext context, Widget page) async {
    return await Navigator.of(context).push<T>(
      modal_bottom_sheet.MaterialWithModalsPageRoute(
        builder: (context) => page,
      ),
    );
  }

  /// 进入包含cupertino弹窗页面(modal_bottom_sheet)，如果你希望进入的页面弹出cupertino风格的弹窗(弹出弹窗页面会进行缩小)，则必须使用此函数进入新页面
  static Future<T?> pushModalsPage<T>(BuildContext context, Widget page) async {
    return await Navigator.of(context).push<T>(
      CupertinoWithModalsPageRoute(builder: (context) => page),
    );
  }

  static Future<T?> redirectModalsPage<T>(BuildContext context, Widget page) async {
    return await Navigator.of(context).pushReplacement(
      CupertinoWithModalsPageRoute(builder: (context) => page),
    );
  }

  static void pushUntilModalsPage(BuildContext context, Widget page, String routePath) async {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoWithModalsPageRoute(
        builder: (context) => page,
      ),
      ModalRoute.withName(routePath),
    );
  }
}

/// 继承cupertino路由页面过渡动画，再此基础上加入页面缩放动画
class CupertinoWithModalsPageRoute<T> extends CupertinoPageRoute<T> {
  CupertinoWithModalsPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) : super(settings: settings, fullscreenDialog: fullscreenDialog, builder: builder, maintainState: maintainState);

  modal_bottom_sheet.ModalSheetRoute? _nextModalRoute;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    return (nextRoute is MaterialPageRoute && !nextRoute.fullscreenDialog) ||
        (nextRoute is CupertinoPageRoute && !nextRoute.fullscreenDialog) ||
        (nextRoute is CupertinoWithModalsPageRoute && !nextRoute.fullscreenDialog) ||
        (nextRoute is modal_bottom_sheet.ModalSheetRoute);
  }

  @override
  void didChangeNext(Route? nextRoute) {
    if (nextRoute is modal_bottom_sheet.ModalSheetRoute) {
      _nextModalRoute = nextRoute;
    }

    super.didChangeNext(nextRoute);
  }

  @override
  bool didPop(T? result) {
    _nextModalRoute = null;
    return super.didPop(result);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    PageTransitionsTheme theme = Theme.of(context).pageTransitionsTheme;
    final nextRoute = _nextModalRoute;
    if (nextRoute != null) {
      if (!secondaryAnimation.isDismissed) {
        final fakeSecondaryAnimation = Tween<double>(begin: 0, end: 0).animate(secondaryAnimation);
        final defaultTransition = theme.buildTransitions<T>(this, context, animation, fakeSecondaryAnimation, child);
        return nextRoute.getPreviousRouteTransition(context, secondaryAnimation, defaultTransition);
      } else {
        _nextModalRoute = null;
      }
    }

    return theme.buildTransitions<T>(this, context, animation, secondaryAnimation, child);
  }
}
