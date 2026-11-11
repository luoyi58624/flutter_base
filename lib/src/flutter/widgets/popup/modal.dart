import 'dart:async';

import 'package:flutter/material.dart' show showModalBottomSheet;
import 'package:flutter/widgets.dart';

import '../../../../dart.dart' show El;
import '../../components/popup/index.dart';
import '../../views/view/style/style.dart';

/// 以必选 context 捕获调用位置的主题、品牌和导航器，返回关闭时的业务值。
extension ElFeedbackExt on El {
  /// 打开底部内容弹层，原生路由承担遮罩、返回键、拖动和焦点恢复。
  Future<T?> popup<T>(
    BuildContext context, {
    required Widget child,
    Object? title,
    Object? footer,
    bool dismissible = true,
    bool draggable = true,
    bool showClose = true,
    ElStyle? style,
  }) => _show<T>(
    context,
    ElPopup(title: title, footer: footer, showClose: showClose, style: style, child: child),
    .bottom,
    dismissible,
    draggable,
  );

  /// 打开确认对话框，footer 内通过 Navigator.pop(context, value) 返回选择结果。
  Future<T?> dialog<T>(
    BuildContext context, {
    required Widget child,
    Object? title,
    Object? footer,
    ElPopupPlacement placement = .center,
    bool dismissible = true,
    ElStyle? style,
  }) => _show<T>(
    context,
    ElDialog(title: title, footer: footer, style: style, child: child),
    placement,
    dismissible,
    false,
  );

  /// 从指定屏幕边缘打开抽屉。
  Future<T?> drawer<T>(
    BuildContext context, {
    required Widget child,
    Object? title,
    Object? footer,
    ElPopupPlacement placement = .right,
    bool dismissible = true,
    ElStyle? style,
  }) => _show<T>(
    context,
    ElDrawer(title: title, footer: footer, style: style, child: child),
    placement,
    dismissible,
    true,
  );

  /// 显示不阻断触摸的短提示，移除后完成 Future。
  Future<void> toast(
    BuildContext context,
    Object message, {
    Object? icon,
    Duration duration = const Duration(milliseconds: 2200),
    ElStyle? style,
  }) {
    final overlay = Overlay.of(context);
    final themes = InheritedTheme.capture(from: context, to: overlay.context);
    final complete = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: const Alignment(0, .65),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: themes.wrap(
                  Semantics(
                    liveRegion: true,
                    child: ElToast(child: message, icon: icon, style: style),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Timer(duration, () {
      entry.remove();
      entry.dispose();
      complete.complete();
    });
    return complete.future;
  }
}

Future<T?> _show<T>(BuildContext context, ElPopup content, ElPopupPlacement placement, bool dismissible, bool drag) {
  if (placement == .bottom && content is! ElDialog) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: drag,
      isDismissible: dismissible,
      backgroundColor: const Color(0x00000000),
      elevation: 0,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
          child: content,
        ),
      ),
    );
  }
  final navigator = Navigator.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final alignment = switch (placement) {
    .center => Alignment.center,
    .bottom => Alignment.bottomCenter,
    .top => Alignment.topCenter,
    .left => Alignment.centerLeft,
    .right => Alignment.centerRight,
  };
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: '关闭弹层',
    barrierColor: const Color(0x66000000),
    transitionDuration: Duration(milliseconds: reduced ? 0 : 240),
    pageBuilder: (context, animation, secondary) => themes.wrap(
      SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: content is ElDrawer ? 380 : 440,
                maxHeight: MediaQuery.sizeOf(context).height - 64 - MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: content,
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return placement == .center
          ? FadeTransition(opacity: curve, child: child)
          : SlideTransition(
              position: Tween<Offset>(begin: Offset(alignment.x, alignment.y), end: Offset.zero).animate(curve),
              child: child,
            );
    },
  );
}
