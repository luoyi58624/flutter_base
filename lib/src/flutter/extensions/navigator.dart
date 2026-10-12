part of 'index.dart';

/// 不依赖组件库的全局根导航入口。
extension ElNavigatorExt on El {
  static final _navigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'el_root_navigator',
  );

  /// 挂到应用根 Navigator 的稳定 key，MaterialApp、WidgetsApp 或路由器均可使用。
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// 已挂载根导航器的 context，仅用于导航或全局服务定位，不替代局部主题依赖。
  BuildContext get context => navigatorState.context;

  /// 当前根导航器；未挂载时提示接入 navigatorKey。
  NavigatorState get navigatorState {
    final state = _navigatorKey.currentState;
    if (state != null && state.mounted) return state;
    throw FlutterError(
      '请先在应用根 Navigator、MaterialApp、WidgetsApp 或路由器上设置 navigatorKey: el.navigatorKey。',
    );
  }
}
