part of 'index.dart';

/// 全局轻提示入口。
extension ElToastExt on El {
  static final _service = ElToastService._();

  /// 轻提示，同一时间只显示一条。
  ElToastService get toast => _service;
}

/// 轻提示服务：show 显示新提示并让当前提示退场，close 关闭当前提示。
final class ElToastService {
  ElToastService._();

  _Toast? _current;

  /// 在根 Overlay 居中显示提示，退场移除后完成；duration 不大于零时保留到 close。
  ///
  /// 传入 context 时挂到它所在窗口的根 Overlay 并沿用该处的主题与品牌，省略时使用 el.navigatorKey 的 Overlay。
  Future<void> show(Object message, {BuildContext? context, Duration duration = const Duration(seconds: 2)}) {
    close();
    if (context != null && !context.mounted) return Future.value();
    final overlay = context == null
        ? el.navigatorKey.currentState?.overlay
        : Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return Future.value();
    Widget child = ElToast(child: message);
    if (context != null) child = InheritedTheme.capture(from: context, to: overlay.context).wrap(child);
    final toast = _current = _Toast(overlay, child);
    if (duration > Duration.zero) toast.timer = Timer(duration, toast.close);
    return toast.removed;
  }

  /// 关闭当前提示，退场移除后完成。
  Future<void> close() {
    final toast = _current;
    _current = null;
    return toast?.close() ?? Future.value();
  }
}

/// 一条已挂载的提示，退场完成后摘除 entry。
final class _Toast {
  _Toast(OverlayState overlay, Widget child) {
    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
              child: Center(child: Semantics(liveRegion: true, child: transitions.wrap(child))),
            ),
          ),
        ),
      ),
    );
    // Overlay 自身卸载时 entry 随之卸载，此时直接结清提示。
    entry.addListener(() {
      if (!entry.mounted) close();
    });
    overlay.insert(entry);
  }

  late final OverlayEntry entry;
  final transitions = OverlayTransitions();
  final _removed = Completer<void>();
  Timer? timer;
  Future<void>? _closing;

  Future<void> get removed => _removed.future;

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    timer?.cancel();
    await transitions.reverse();
    entry
      ..remove()
      ..dispose();
    _removed.complete();
  }
}
