import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

import 'transition.dart';

/// 在根导航器打开模态内容，返回值随关闭交给 Future。
///
/// 系统返回、Esc、焦点圈定、语义与遮罩点击沿用官方路由；进退场交给内容里的 ElOverlayTransition。
/// 出栈沿用官方语义：立即交付结果并让出栈顶，路由等品牌退场结束后才移除。
@internal
Future<T?> showModal<T>(
  BuildContext context, {
  required bool dismissible,
  String? label,
  required Widget Function(void Function([T? result]) close) builder,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final route = _ModalRoute<T>(dismissible: dismissible, label: label);
  route.content = themes.wrap(builder(route.close));
  return navigator.push(route);
}

class _ModalRoute<T> extends PopupRoute<T> {
  _ModalRoute({required this.dismissible, this.label});

  final bool dismissible;
  final String? label;
  late final Widget content;
  final _transitions = OverlayTransitions();

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => '关闭弹层';

  @override
  Duration get transitionDuration => Duration.zero;

  // 不可关闭时系统返回、Esc 与 maybePop 都不生效，内容里的按钮仍可调用 close。
  @override
  RoutePopDisposition get popDisposition => dismissible ? super.popDisposition : .doNotPop;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final page = _transitions.wrap(content);
    return label == null ? page : Semantics(namesRoute: true, label: label, child: page);
  }

  /// 关闭这一层：位于栈顶时按官方出栈，被上层盖住时直接移除。
  void close([T? result]) {
    if (isCurrent) {
      navigator!.pop(result);
    } else if (isActive) {
      navigator!.removeRoute(this, result);
    }
  }

  // 路由自身的退场时长对齐品牌剩余的退场，两者同帧结束；退场期间官方 ModalRoute 已忽略指针与焦点。
  @override
  bool didPop(T? result) {
    controller!.reverseDuration = _transitions.remaining;
    _transitions.reverse();
    return super.didPop(result);
  }
}
