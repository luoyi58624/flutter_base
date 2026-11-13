import 'package:flutter/foundation.dart' show Listenable, ValueNotifier, internal;
import 'package:flutter/widgets.dart';

import 'popup_stack.dart';
import 'scope.dart';
import 'session.dart';
import 'theme.dart';

/// 在应用内容外层建立弹层宿主，页面导航更换时保留已打开的面板。
class ElPopupHost extends StatefulWidget {
  /// 创建当前窗口的弹层宿主，可安装在应用的 builder 中。
  const ElPopupHost({super.key, required this.child});

  /// 导航器或无导航的页面内容。
  final Widget child;

  /// 在当前窗口尝试处理一次系统返回。
  static bool handleBack(BuildContext context) => popupBackTargetOf(context)?.onBack(context) ?? false;

  @override
  State<ElPopupHost> createState() => PopupHostState();
}

/// 通过实际挂载的上下文查找可见的弹层宿主。
@internal
PopupHostState? popupHostOf(BuildContext context, {bool listen = false}) {
  if (popupViewId(context) == null) return null;
  final scope = listen
      ? LookupBoundary.dependOnInheritedWidgetOfExactType<_HostScope>(context)
      : LookupBoundary.getInheritedWidgetOfExactType<_HostScope>(context);
  return scope?.host;
}

/// 只在同一窗口的有效宿主中获取当前返回目标。
@internal
PopupBackTarget? popupBackTargetOf(BuildContext context) => popupHostOf(context)?.backTarget;

/// 获取上下文所属的面板会话，页面底层返回 null。
@internal
PopupSession<Object?>? popupLayerOf(BuildContext context) =>
    LookupBoundary.getInheritedWidgetOfExactType<_LayerScope>(context)?.layer;

/// 返回接收者的身份与动作，手势提交时可校验是否仍由该层接收。
@internal
typedef PopupBackTarget = ({Object owner, bool Function(BuildContext context) onBack});

/// 视口弹层及返回接线访问的宿主状态。
@internal
final class PopupHostState extends State<ElPopupHost> {
  final _overlayKey = GlobalKey<OverlayState>();
  late final _content = OverlayEntry(
    maintainState: true,
    builder: (_) => _PopupLayer(host: this, layer: null, child: widget.child),
  );
  // 面板插在此锚点下方，提示按官方 Overlay 的栈顶插入。
  late final _notices = OverlayEntry(builder: (_) => const SizedBox.shrink());
  final _front = ValueNotifier<PopupSession<Object?>?>(null);
  final _back = ValueNotifier<PopupBackTarget?>(null);
  final _backOverlays = <OverlayState>{};
  final _panels = <PopupSession<Object?>>[];
  final _sessions = <PopupSession<Object?>>{};
  int? _viewId;
  bool _disposed = false;

  /// 当返回目标变化时通知。
  Listenable get backChanges => _back;

  /// 模态覆盖或解除时刷新所属锚定层的可交互状态。
  Listenable get layerChanges => _front;

  /// 锚定层以同一内容层的绘制顺序参与应用返回。
  void registerBack(OverlayState overlay, Object owner, bool Function(BuildContext)? onBack) {
    if (_disposed) return;
    final stack = PopupStack.forOverlay(overlay);
    final wasListening = _backOverlays.isNotEmpty;
    stack.setBack(owner, onBack);
    if (stack.backTarget == null) {
      _backOverlays.remove(overlay);
    } else {
      _backOverlays.add(overlay);
    }
    if (!wasListening && _backOverlays.isNotEmpty) {
      FocusManager.instance.addListener(_refreshBack);
    } else if (wasListening && _backOverlays.isEmpty) {
      FocusManager.instance.removeListener(_refreshBack);
    }
    _refreshBack();
  }

  /// 当前可交互的模态层，空值表示页面底层。
  PopupSession<Object?>? get frontPanel => _disposed ? null : _front.value;

  /// 当前可处理返回的层。
  PopupBackTarget? get backTarget => _disposed ? null : _back.value;

  void _refreshBack() {
    if (_disposed) return;
    PopupBackTarget? linked;
    if (_backOverlays.isNotEmpty) {
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      final focusedOverlay = focusedContext == null ? null : popupOverlayOf(focusedContext)?.overlay;
      final root = _overlayKey.currentState;
      final overlay = switch (focusedOverlay) {
        final OverlayState focused when _backOverlays.contains(focused) => focused,
        _ when _backOverlays.contains(root) => root,
        _ => _backOverlays.last,
      };
      if (overlay != null) linked = PopupStack.maybeOf(overlay)?.backTarget;
    }
    final panel = frontPanel;
    final owner = linked?.owner ?? panel;
    if (identical(_back.value?.owner, owner)) return;
    _back.value = linked ?? (panel == null ? null : (owner: panel, onBack: panel.close));
  }

  void _updateFront() {
    _front.value = _panels.reversed.where((panel) => panel.open.value).firstOrNull;
    _refreshBack();
  }

  OverlayState? _resolveOverlay(BuildContext source) {
    if (_disposed || !identical(popupHostOf(source), this)) return null;
    final overlay = _overlayKey.currentState;
    if (overlay == null || !overlay.mounted || popupViewId(source) != popupViewId(overlay.context)) return null;
    return overlay;
  }

  /// 将面板挂到当前窗口的独立 Overlay。
  PopupSession<T>? showPanel<T>(
    BuildContext source, {
    required Widget Function(BuildContext context, PopupSession<T> session) builder,
  }) {
    final overlay = _resolveOverlay(source);
    if (overlay == null) return null;
    final theme = PopupTheme.capture(source, to: overlay.context);
    late final PopupSession<T> session;
    session = PopupSession<T>(
      overlay,
      viewId: popupViewId(source)!,
      maintainState: true,
      builder: (context) => _PopupLayer(
        host: this,
        layer: session,
        child: _PopupPanel(
          session: session,
          child: theme.wrap(Builder(builder: (context) => builder(context, session))),
        ),
      ),
    );
    _track(session);
    session.insert(
      below: _notices,
      onInserted: () {
        _panels.add(session);
        session.open.addListener(_updateFront);
        session.removed.then((_) => _panels.remove(session));
        _updateFront();
      },
    );
    return session;
  }

  /// 提示与宿主使用同一 Overlay 时纳入宿主的卸载清理。
  void trackNotice(PopupSession<void> session) {
    if (identical(_overlayKey.currentState, session.overlay)) _track(session);
  }

  void _track(PopupSession<Object?> session) {
    _sessions.add(session);
    session.removed.then((_) => _sessions.remove(session));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewId = popupViewId(context);
    if (_viewId != null && _viewId != viewId) {
      // 在宿主重挂时移除旧窗口的会话，保持会话身份与实际视图一致。
      for (final session in _sessions.toList().reversed) {
        session.remove();
      }
    }
    _viewId = viewId;
  }

  @override
  void didUpdateWidget(ElPopupHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _content.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => _HostScope(
    host: this,
    child: TapRegionSurface(
      child: Listener(
        // 空白区域也需要参与命中，TapRegion 才能收到外点。
        behavior: HitTestBehavior.opaque,
        child: Overlay(key: _overlayKey, initialEntries: [_content, _notices]),
      ),
    ),
  );

  @override
  void dispose() {
    _disposed = true;
    if (_backOverlays.isNotEmpty) FocusManager.instance.removeListener(_refreshBack);
    _backOverlays.clear();
    for (final session in _sessions.toList().reversed) {
      session.open.removeListener(_updateFront);
      session.remove();
    }
    _content
      ..remove()
      ..dispose();
    _notices
      ..remove()
      ..dispose();
    _back.value = null;
    _front.dispose();
    _back.dispose();
    super.dispose();
  }
}

class _PopupPanel extends StatefulWidget {
  const _PopupPanel({required this.session, required this.child});

  final PopupSession<Object?> session;
  final Widget child;

  @override
  State<_PopupPanel> createState() => _PopupPanelState();
}

class _PopupPanelState extends State<_PopupPanel> {
  final _focus = FocusScopeNode(traversalEdgeBehavior: .closedLoop, directionalTraversalEdgeBehavior: .closedLoop);
  FocusNode? _previous;

  @override
  void initState() {
    super.initState();
    final previous = FocusManager.instance.primaryFocus;
    final previousContext = previous?.context;
    if (previousContext != null && popupViewId(previousContext) == widget.session.viewId) _previous = previous;
    widget.session.open.addListener(_restoreFocus);
  }

  void _restoreFocus() {
    final previous = _previous;
    if (!_focus.hasFocus || previous == null) return;
    final viewId = widget.session.viewId;
    final host = popupHostOf(context);
    final nextLayer = host?.frontPanel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final previousContext = previous.context;
      if (previousContext != null &&
          popupViewId(previousContext) == viewId &&
          identical(popupHostOf(previousContext), host) &&
          identical(host?.frontPanel, nextLayer) &&
          previous.canRequestFocus) {
        previous.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) => FocusScope(node: _focus, autofocus: true, child: widget.child);

  @override
  void dispose() {
    widget.session.open.removeListener(_restoreFocus);
    _focus.dispose();
    super.dispose();
  }
}

class _HostScope extends InheritedWidget {
  const _HostScope({required this.host, required super.child});

  final PopupHostState host;

  @override
  bool updateShouldNotify(_HostScope oldWidget) => !identical(host, oldWidget.host);
}

class _LayerScope extends InheritedWidget {
  const _LayerScope({required this.layer, required super.child});

  final PopupSession<Object?>? layer;

  @override
  bool updateShouldNotify(_LayerScope oldWidget) => !identical(layer, oldWidget.layer);
}

class _PopupLayer extends StatelessWidget {
  const _PopupLayer({required this.host, required this.layer, required this.child});

  final PopupHostState host;
  final PopupSession<Object?>? layer;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: host._front,
    child: _LayerScope(layer: layer, child: child),
    builder: (context, child) {
      final enabled = identical(host.frontPanel, layer);
      return ExcludeFocus(
        excluding: !enabled,
        child: ExcludeSemantics(
          excluding: !enabled,
          child: IgnorePointer(ignoring: !enabled, child: child),
        ),
      );
    },
  );
}
