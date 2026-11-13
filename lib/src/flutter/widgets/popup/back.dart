import 'dart:async' show unawaited;
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/services.dart' show PredictiveBackEvent, SystemNavigator;
import 'package:flutter/widgets.dart';

import 'host.dart';
import 'scope.dart';

/// 应用根部的系统返回接线，按当前 FlutterView 获取对应宿主的 context。
///
/// 应在 WidgetsApp 或 Router 登记观察者前安装，回调返回当前窗口内的宿主子树上下文。
class ElPopupBackObserver with WidgetsBindingObserver {
  /// 应用提供各窗口的挂载上下文，窗口退出后返回 null。
  ElPopupBackObserver(this.contextForView);

  /// 按视图 ID 查询本应用内仍挂载的上下文。
  final BuildContext? Function(int viewId) contextForView;

  int? _focusedView;
  bool _hasViewFocusEvent = false;
  ({int viewId, Object owner})? _gesture;
  PopupHostState? _platformHost;
  final _navigationViews = <int>{};
  bool? _lastPlatformValue;

  /// 接收 WidgetsApp 的导航通知，并合并当前窗口的弹层返回能力。
  ///
  /// 由该窗口的 onNavigationNotification 传入同一窗口的宿主子树上下文。
  bool onNavigationNotification(BuildContext context, NavigationNotification notification) {
    final viewId = popupViewId(context);
    if (viewId == null) return false;
    if (notification.canHandlePop) {
      _navigationViews.add(viewId);
    } else {
      _navigationViews.remove(viewId);
    }
    updatePlatform(context);
    return true;
  }

  /// 根部挂载或替换导航树后，从该窗口上下文同步平台状态。
  void updatePlatform(BuildContext context, {bool resetNavigation = false}) {
    final viewId = popupViewId(context);
    if (viewId == null) return;
    if (resetNavigation) _navigationViews.remove(viewId);
    _syncPlatform();
  }

  void _syncPlatform() {
    final viewId = _activeView;
    final context = viewId == null ? null : _context(viewId);
    final host = context == null ? null : popupHostOf(context);
    if (!identical(host, _platformHost)) {
      _platformHost?.backChanges.removeListener(_publishPlatformState);
      _platformHost = host;
      _platformHost?.backChanges.addListener(_publishPlatformState);
    }
    _publishPlatformState();
  }

  void _publishPlatformState() {
    final value = _navigationViews.contains(_activeView) || _platformHost?.backTarget != null;
    if (value == _lastPlatformValue) return;
    _lastPlatformValue = value;
    unawaited(SystemNavigator.setFrameworkHandlesBack(value));
  }

  /// 窗口销毁时清除该窗口的导航和平台返回记录。
  void detachView(int viewId) {
    _navigationViews.remove(viewId);
    if (_focusedView == viewId) _focusedView = null;
    if (_gesture?.viewId == viewId) _gesture = null;
    if (_lastPlatformValue != null) _syncPlatform();
  }

  /// 注销观察者后释放平台状态的订阅。
  void dispose() {
    _platformHost?.backChanges.removeListener(_publishPlatformState);
    _platformHost = null;
    _gesture = null;
    _lastPlatformValue = null;
    _navigationViews.clear();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    _hasViewFocusEvent = true;
    if (event.state == ViewFocusState.focused) {
      _focusedView = event.viewId;
    } else if (_focusedView == event.viewId) {
      _focusedView = null;
    }
    if (_gesture?.viewId != _focusedView) _gesture = null;
    if (_lastPlatformValue != null) _syncPlatform();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _lastPlatformValue == null) return;
    _lastPlatformValue = null;
    _syncPlatform();
  }

  int? get _activeView {
    if (_hasViewFocusEvent) return _focusedView;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.length == 1 ? views.single.viewId : null;
  }

  BuildContext? _context(int viewId) {
    final context = contextForView(viewId);
    return context != null && popupViewId(context) == viewId ? context : null;
  }

  @override
  Future<bool> didPopRoute() async {
    final viewId = _activeView;
    final context = viewId == null ? null : _context(viewId);
    return context != null && ElPopupHost.handleBack(context);
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    _gesture = null;
    final viewId = _activeView;
    if (viewId == null) return false;
    final context = _context(viewId);
    final target = context == null ? null : popupBackTargetOf(context);
    if (target == null) return false;
    _gesture = (viewId: viewId, owner: target.owner);
    return true;
  }

  @override
  void handleCommitBackGesture() {
    final gesture = _gesture;
    _gesture = null;
    if (gesture == null || _activeView != gesture.viewId) return;
    final context = _context(gesture.viewId);
    if (context == null) return;
    final target = popupBackTargetOf(context);
    if (target != null && identical(target.owner, gesture.owner)) target.onBack(context);
  }

  @override
  void handleCancelBackGesture() {
    _gesture = null;
  }
}

/// 让所在页面在当前窗口有返回接收者时交出页面回退和预测手势。
class ElPopupBackScope extends StatefulWidget {
  /// 安装在实际参与页面返回的 Route 子树。
  const ElPopupBackScope({super.key, required this.child});

  /// 页面内容。
  final Widget child;

  @override
  State<ElPopupBackScope> createState() => _PopupBackScopeState();
}

class _PopupBackScopeState extends State<ElPopupBackScope> {
  final _entry = _PopupPopEntry();
  PopupHostState? _host;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = popupHostOf(context, listen: true);
    if (!identical(_host, host)) {
      _host?.backChanges.removeListener(_update);
      _host = host;
      _host?.backChanges.addListener(_update);
    }
    final route = ModalRoute.of(context);
    if (!identical(_route, route)) {
      _route?.unregisterPopEntry(_entry);
      _route = route;
      _route?.registerPopEntry(_entry);
    }
    _update();
  }

  void _update() {
    _entry.canPop.value = _host?.backTarget == null;
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    _host?.backChanges.removeListener(_update);
    _route?.unregisterPopEntry(_entry);
    _entry.canPop.dispose();
    super.dispose();
  }
}

class _PopupPopEntry extends PopEntry<Object?> {
  final canPop = ValueNotifier(true);

  @override
  ValueListenable<bool> get canPopNotifier => canPop;
}
