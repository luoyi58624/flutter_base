import 'package:flutter/material.dart';

import '../../../dart.dart' show El, el;
import '../../flutter/extensions/index.dart' show ElNavigatorExt;

/// 为全局 [El] 实例提供根路由服务。
extension ElRouterServiceExt on El {
  /// 根路由服务实例，可替换以统一配置页面过渡。
  static ElRouterService instance = const ElRouterService();

  /// 操作挂载了 [ElNavigatorExt.navigatorKey] 的根导航器。
  ElRouterService get router => instance;
}

/// 为组件上下文提供就近导航。
extension ElRouterContextExt on BuildContext {
  /// 操作最近的导航器，复用根路由服务的过渡配置。
  ElRouterService get elRouter => ElRouterService._(ElRouterServiceExt.instance.pageTransitionsBuilder, this);
}

/// 封装 Flutter Navigator 的命令式路由和页面操作。
class ElRouterService {
  /// 创建根路由服务，默认使用应用主题的页面过渡。
  const ElRouterService({this.pageTransitionsBuilder}) : _context = null;

  const ElRouterService._(this.pageTransitionsBuilder, this._context);

  /// 页面便捷方法使用的过渡构建器，留空时使用应用主题配置。
  final PageTransitionsBuilder? pageTransitionsBuilder;
  final BuildContext? _context;

  NavigatorState get _navigator => _context == null ? el.navigatorState : Navigator.of(_context);

  /// 推入一个路由，返回它弹出时的结果。
  Future<T?> push<T>(Route<T> route) => _navigator.push(route);

  /// 导航栈可弹出时返回上一页，并将结果交给调用方。
  void pop<T>([T? result]) {
    final navigator = _navigator;
    if (navigator.canPop()) navigator.pop(result);
  }

  /// 弹出首个路由之上的所有路由。
  void popAll() => popUntil((route) => route.isFirst);

  /// 查询当前导航栈能否弹出。
  bool canPop() => _navigator.canPop();

  /// 按当前路由的返回规则尝试弹出。
  Future<bool> maybePop<T>([T? result]) => _navigator.maybePop(result);

  /// 连续弹出，直到遇到符合条件的路由。
  void popUntil(RoutePredicate predicate) => _navigator.popUntil(predicate);

  /// 用新路由替换栈顶，向被替换路由交付可选结果。
  Future<T?> pushReplacement<T, TO>(Route<T> newRoute, {TO? result}) =>
      _navigator.pushReplacement<T, TO>(newRoute, result: result);

  /// 推入新路由，移除其下直到遇到符合条件的路由。
  Future<T?> pushAndRemoveUntil<T>(Route<T> newRoute, RoutePredicate predicate) =>
      _navigator.pushAndRemoveUntil(newRoute, predicate);

  /// 移除栈中的指定路由。
  void removeRoute(Route<dynamic> route) => _navigator.removeRoute(route);

  /// 替换导航栈中的指定路由。
  void replace<T>({required Route<dynamic> oldRoute, required Route<T> newRoute}) =>
      _navigator.replace(oldRoute: oldRoute, newRoute: newRoute);

  /// 推入页面，使用服务配置的页面过渡。
  Future<T?> pushPage<T>(
    Widget page, {
    String? title,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
    bool allowSnapshotting = true,
    bool barrierDismissible = false,
  }) => push(
    _pageRoute<T>(
      page,
      title: title,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
      allowSnapshotting: allowSnapshotting,
      barrierDismissible: barrierDismissible,
    ),
  );

  /// 用页面替换栈顶，向被替换路由交付可选结果。
  Future<T?> pushReplacementPage<T, TO>(
    Widget page, {
    String? title,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
    bool allowSnapshotting = true,
    bool barrierDismissible = false,
    TO? result,
  }) => pushReplacement<T, TO>(
    _pageRoute<T>(
      page,
      title: title,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
      allowSnapshotting: allowSnapshotting,
      barrierDismissible: barrierDismissible,
    ),
    result: result,
  );

  /// 推入页面，移除其下直到遇到符合条件的路由。
  Future<T?> pushPageAndRemoveUntil<T>(
    Widget page,
    RoutePredicate predicate, {
    String? title,
    RouteSettings? settings,
    bool maintainState = true,
    bool fullscreenDialog = false,
    bool allowSnapshotting = true,
    bool barrierDismissible = false,
  }) => pushAndRemoveUntil(
    _pageRoute<T>(
      page,
      title: title,
      settings: settings,
      maintainState: maintainState,
      fullscreenDialog: fullscreenDialog,
      allowSnapshotting: allowSnapshotting,
      barrierDismissible: barrierDismissible,
    ),
    predicate,
  );

  PageRoute<T> _pageRoute<T>(
    Widget page, {
    required String? title,
    required RouteSettings? settings,
    required bool maintainState,
    required bool fullscreenDialog,
    required bool allowSnapshotting,
    required bool barrierDismissible,
  }) => _ElPageRoute<T>(
    builder: (_) => page,
    title: title,
    transitions: pageTransitionsBuilder,
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
    allowSnapshotting: allowSnapshotting,
    barrierDismissible: barrierDismissible,
  );
}

class _ElPageRoute<T> extends MaterialPageRoute<T> {
  _ElPageRoute({
    required super.builder,
    required this.title,
    required this.transitions,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    super.barrierDismissible,
  });

  final String? title;
  final PageTransitionsBuilder? transitions;

  @override
  String get debugLabel => settings.name == null && title != null ? '${super.debugLabel}($title)' : super.debugLabel;

  @override
  Duration get transitionDuration => transitions?.transitionDuration ?? super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => transitions?.reverseTransitionDuration ?? super.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      transitions == null ? super.delegatedTransition : transitions?.delegatedTransition;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      transitions?.buildTransitions<T>(this, context, animation, secondaryAnimation, child) ??
      super.buildTransitions(context, animation, secondaryAnimation, child);
}
