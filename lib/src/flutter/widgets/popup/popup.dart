import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart' show RenderIgnorePointer;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../views/view/event/dispatcher.dart' show EventDispatcher;
import '../../views/view/event/event.dart';
import '../../views/view/view.dart' show ElView;
import 'anchor.dart';
import 'hover_intent.dart';
import 'transition.dart';

/// 锚定弹层的触发方式，可组合使用；为空时只由控制器开闭。
enum ElPopupTrigger {
  /// 点击目标切换开闭。
  click,

  /// 指针悬停目标或面板时打开、离开后关闭，延迟由 hoverIntent 决定；触摸设备没有悬停，点击目标切换开闭。
  hover,

  /// 目标内获得焦点时打开，焦点离开目标与面板后关闭。
  focus,

  /// 右键或长按时在指针位置打开，例如右键菜单。
  contextMenu,
}

/// 锚定弹层的开闭控制器。
class ElPopupController extends ChangeNotifier {
  _ElPopupState? _state;

  void _changed() => notifyListeners();

  /// 是否打开；退场期间已视为关闭。
  bool get isOpen => _state?._open ?? false;

  /// 打开弹层；position 为目标局部坐标时以该点为锚，例如在右键位置打开菜单。
  void open({Offset? position}) => _state?._show(position);

  /// 关闭弹层，品牌退场结束后移除。
  void close() => _state?._hide();

  /// 切换开闭。
  void toggle() => isOpen ? close() : open();
}

/// 包裹目标并在其周围显示面板。
///
/// 面板在布局阶段按目标的实时位置解算：滚动、窗口尺寸与键盘变化时跟随目标并重新选择最佳方位，
/// 目标滚出所在滚动区域时暂时隐藏。嵌套在面板内的 ElPopup 组成一条链：打开子层会关闭同级子层，
/// 关闭父层会关闭子层，链上任一面板与目标都不算外部点击，悬停在子层面板上时父层保持打开，Esc 从最内层逐级关闭。
class ElPopup extends StatefulWidget {
  /// 创建锚定弹层，builder 在打开时构建面板。
  const ElPopup({
    super.key,
    required this.child,
    required this.builder,
    this.controller,
    this.trigger = const {ElPopupTrigger.click},
    this.anchor = const ElOverlayAnchor(),
    this.hoverIntent = const ElHoverIntent(),
    this.disabled = false,
    this.rootOverlay = false,
    this.closeOnOutsideTap = true,
    this.consumeOutsideTap = false,
    this.closeOnScroll = false,
    this.closeOnEscape = true,
    this.onOpenChanged,
    this.event,
  });

  /// 锚定目标。
  final Widget child;

  /// 构建面板；进退场用 ElOverlayTransition 声明，关闭时等它退场完再移除。
  final WidgetBuilder builder;

  /// 可选开闭控制器，省略时内部创建。
  final ElPopupController? controller;

  /// 触发方式。
  final Set<ElPopupTrigger> trigger;

  /// 方位、间距、翻转、钳制、宽度跟随与覆盖目标。
  final ElOverlayAnchor anchor;

  /// 悬停触发的打开、关闭延迟与安全区域。
  final ElHoverIntent hoverIntent;

  /// 禁用全部触发，已打开时关闭。
  final bool disabled;

  /// 挂到根 Overlay，避免被局部 Overlay 裁剪或遮挡。
  final bool rootOverlay;

  /// 点击目标与面板以外的位置时关闭。
  final bool closeOnOutsideTap;

  /// 关闭弹层的外部点击不再传给下方组件。
  final bool consumeOutsideTap;

  /// 目标所在滚动区域开始滚动时关闭；默认跟随目标重新定位。
  final bool closeOnScroll;

  /// 焦点在目标或面板内时按 Esc 关闭。
  final bool closeOnEscape;

  /// 开闭状态变化。
  final ValueChanged<bool>? onOpenChanged;

  /// 目标的原生事件，先于触发动作执行，调用 preventDefault 可阻止打开或关闭。
  final ElEvent? event;

  /// 最近一层面板的控制器，面板内容可用它关闭自身。
  static ElPopupController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PopupScope>()?.state._controller;

  /// 最近一层面板的解算结果，供箭头与动画原点使用；布局完成前为空，方位变化后下一帧更新。
  static ElOverlayAnchorGeometry? geometryOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GeometryScope>()?.notifier?.value;

  @override
  State<ElPopup> createState() => _ElPopupState();
}

class _ElPopupState extends State<ElPopup> {
  final _portal = OverlayPortalController();
  final _transitions = OverlayTransitions();
  final _geometry = ValueNotifier<ElOverlayAnchorGeometry?>(null);
  final _panelKey = GlobalKey();
  final _ignoreKey = GlobalKey();
  final _panelFocus = FocusNode(debugLabel: 'ElPopup panel', canRequestFocus: false, skipTraversal: true);
  final _triggerFocus = FocusNode(debugLabel: 'ElPopup trigger', canRequestFocus: false, skipTraversal: true);
  ElPopupController? _ownController;
  _ElPopupState? _parent;
  _ElPopupState? _openChild;
  HoverIntentMachine? _hover;
  ScrollableState? _scrollable;
  ScrollPosition? _scrollWatch;
  FocusNode? _restore;
  Offset? _position;
  bool _open = false;
  int _generation = 0;

  ElPopupController get _controller => widget.controller ?? (_ownController ??= ElPopupController());

  Object get _group => _parent?._group ?? this;

  @override
  void initState() {
    super.initState();
    _controller._state = this;
    _syncHover();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _parent = context.getInheritedWidgetOfExactType<_PopupScope>()?.state;
    _scrollable = Scrollable.maybeOf(context);
    _syncScroll();
  }

  @override
  void didUpdateWidget(ElPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final old = oldWidget.controller ?? _ownController;
      if (old?._state == this) old!._state = null;
      _controller._state = this;
    }
    _syncHover();
    _syncScroll();
    if (widget.disabled) _hide();
  }

  @override
  void dispose() {
    if (_controller._state == this) _controller._state = null;
    _ownController?.dispose();
    if (_parent?._openChild == this) _parent!._openChild = null;
    _hover?.dispose();
    _scrollWatch?.isScrollingNotifier.removeListener(_handleScroll);
    _geometry.dispose();
    _panelFocus.dispose();
    _triggerFocus.dispose();
    super.dispose();
  }

  void _syncHover() {
    final config = widget.trigger.contains(ElPopupTrigger.hover) ? widget.hoverIntent : null;
    if (config == _hover?.config) return;
    _hover?.dispose();
    _hover = config == null
        ? null
        : HoverIntentMachine(config: config, requestOpen: _show, requestClose: _hide, rectsOf: _hoverRects);
  }

  void _syncScroll() {
    final position = widget.closeOnScroll ? _scrollable?.position : null;
    if (position == _scrollWatch) return;
    _scrollWatch?.isScrollingNotifier.removeListener(_handleScroll);
    _scrollWatch = position?..isScrollingNotifier.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (_scrollWatch?.isScrollingNotifier.value ?? false) _hide();
  }

  List<Rect> _hoverRects() => [
    for (final context in [this.context, _panelKey.currentContext])
      if (context?.findRenderObject() case final RenderBox box when box.attached && box.hasSize)
        box.localToGlobal(Offset.zero) & box.size,
  ];

  void _show([Offset? position]) {
    if (!mounted || widget.disabled) return;
    final moved = position != _position;
    _position = position;
    if (_open) {
      if (moved) setState(() {});
      return;
    }
    _generation++;
    _open = true;
    _parent?._childOpened(this);
    _restore = FocusManager.instance.primaryFocus;
    if (_portal.isShowing) {
      // 退场中途再次打开，从当前进度重新进场。
      _transitions.forward();
    } else {
      _portal.show();
    }
    setState(() {});
    _changed();
  }

  void _hide() {
    if (!_open) return;
    _open = false;
    final generation = ++_generation;
    _openChild?._hide();
    if (_parent?._openChild == this) _parent!._openChild = null;
    // 关闭当下就停止面板交互：结束面板内进行中的指针序列，不等下一帧重建再忽略指针。
    if (_panelKey.currentContext?.findRenderObject() case final RenderObject panel) {
      EventDispatcher.terminateActivePointerSequencesIn(panel);
    }
    if (_ignoreKey.currentContext?.findRenderObject() case final RenderIgnorePointer ignore) ignore.ignoring = true;
    // 焦点在面板内时交还给打开前的位置，避免随面板一起消失。
    if (_panelFocus.hasFocus && (_restore?.context?.mounted ?? false)) _restore!.requestFocus();
    _restore = null;
    _transitions.reverse().then((_) {
      if (mounted && generation == _generation) _portal.hide();
    });
    if (mounted) setState(() {});
    _changed();
  }

  void _toggle() => _open ? _hide() : _show();

  void _changed() {
    widget.onOpenChanged?.call(_open);
    _controller._changed();
  }

  void _childOpened(_ElPopupState child) {
    if (_openChild == child) return;
    _openChild?._hide();
    _openChild = child;
  }

  void _focusChanged(bool focused) {
    if (focused) return _show();
    // 焦点移进面板时保持打开，等焦点结算后再判断。
    scheduleMicrotask(() {
      if (mounted && !_triggerFocus.hasFocus && !_panelFocus.hasFocus) _hide();
    });
  }

  // 悬停在子层面板上也算悬停在父层上，父层不会在指针移进子层时关闭。
  void _panelHover(bool entered) {
    for (_ElPopupState? state = this; state != null; state = state._parent) {
      entered ? state._hover?.pointerEntered() : state._hover?.pointerExited();
    }
  }

  void _resolved(ElOverlayAnchorGeometry geometry) {
    if (geometry == _geometry.value) return;
    // 布局阶段不能标记重建，结果在帧末交给依赖它的箭头和动画原点。
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _geometry.value = geometry;
    });
  }

  // 目标所在滚动区域的可见范围，用于判断目标是否已滚出视野。
  bool _outOfView(Rect anchorRect, RenderBox overlay) {
    final box = _scrollable?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || !overlay.attached) return false;
    final visible = MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
    final anchor = MatrixUtils.transformRect(overlay.getTransformTo(null), anchorRect);
    return !visible.overlaps(anchor.inflate(.5));
  }

  // 快捷键只取最近一层 DismissIntent 动作，未启用也会截住 Esc；关闭时不登记，让 Esc 继续交给外层弹层或路由。
  Map<Type, Action<Intent>> get _dismiss =>
      _open && widget.closeOnEscape ? {DismissIntent: _DismissAction(this)} : const {};

  Widget _buildOverlay(BuildContext context, OverlayChildLayoutInfo info) {
    final transform = info.childPaintTransform;
    final anchorRect = MatrixUtils.transformRect(transform, Offset.zero & info.childSize);
    final target = switch (_position) {
      final position? => MatrixUtils.transformPoint(transform, position) & Size.zero,
      null => anchorRect,
    };
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final viewport = Rect.fromLTRB(
      padding.left,
      padding.top,
      info.overlaySize.width - padding.right,
      info.overlaySize.height - math.max(padding.bottom, keyboard),
    );
    final overlay = Overlay.maybeOf(context, rootOverlay: widget.rootOverlay)?.context.findRenderObject();
    final hidden = overlay is RenderBox && _outOfView(anchorRect, overlay);
    final hovering = _hover != null || _parent?._hover != null;
    return Visibility(
      visible: !hidden,
      maintainState: true,
      maintainAnimation: true,
      child: CustomSingleChildLayout(
        delegate: _PopupLayout(widget.anchor, target, viewport, _resolved),
        child: _PopupScope(
          state: this,
          child: Actions(
            actions: _dismiss,
            child: TapRegion(
              groupId: _group,
              consumeOutsideTaps: widget.consumeOutsideTap,
              onTapOutside: widget.closeOnOutsideTap ? (_) => _hide() : null,
              child: MouseRegion(
                key: _panelKey,
                onEnter: hovering ? (_) => _panelHover(true) : null,
                onExit: hovering ? (_) => _panelHover(false) : null,
                child: Focus(
                  focusNode: _panelFocus,
                  includeSemantics: false,
                  child: IgnorePointer(
                    key: _ignoreKey,
                    // 退场期间不再响应操作。
                    ignoring: !_open,
                    child: _transitions.wrap(
                      _GeometryScope(
                        notifier: _geometry,
                        child: Builder(builder: widget.builder),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final triggers = widget.trigger;
    final click = triggers.contains(ElPopupTrigger.click);
    final menu = triggers.contains(ElPopupTrigger.contextMenu);
    final hover = _hover != null;
    final user = widget.event ?? const ElEvent();
    ElEventHandler? chain(ElEventHandler? handler, bool enabled, void Function(ElEventDetails e) action) {
      if (!enabled) return handler;
      return (e) {
        handler?.call(e);
        if (!e.defaultPrevented && !widget.disabled) action(e);
      };
    }

    Widget trigger = ElView(
      event: user.copyWith(
        onTap: chain(user.onTap, click || hover, (e) {
          if (click || e.pointerEvent?.kind == PointerDeviceKind.touch) _toggle();
        }),
        onSecondaryTapUp: chain(user.onSecondaryTapUp, menu, (e) => _show(e.localPosition)),
        onLongPress: chain(user.onLongPress, menu, (e) => _show(e.localPosition)),
        onPointerEnter: chain(user.onPointerEnter, hover, (_) => _hover?.pointerEntered()),
        onPointerExit: chain(user.onPointerExit, hover, (_) => _hover?.pointerExited()),
      ),
      child: widget.child,
    );
    if (triggers.contains(ElPopupTrigger.focus)) {
      trigger = Focus(focusNode: _triggerFocus, includeSemantics: false, onFocusChange: _focusChanged, child: trigger);
    }
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayLocation: widget.rootOverlay ? .rootOverlay : .nearestOverlay,
      overlayChildBuilder: _buildOverlay,
      child: Actions(
        actions: _dismiss,
        child: TapRegion(groupId: _group, child: trigger),
      ),
    );
  }
}

class _DismissAction extends DismissAction {
  _DismissAction(this.state);

  final _ElPopupState state;

  @override
  bool isEnabled(DismissIntent intent) => state._open && state.widget.closeOnEscape;

  @override
  void invoke(DismissIntent intent) => state._hide();
}

class _PopupLayout extends SingleChildLayoutDelegate {
  _PopupLayout(this.anchor, this.target, this.viewport, this.onResolved);

  final ElOverlayAnchor anchor;
  final Rect target;
  final Rect viewport;
  final ValueChanged<ElOverlayAnchorGeometry> onResolved;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => anchor.constraints(target, viewport);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final geometry = anchor.resolve(target, childSize, viewport);
    onResolved(geometry);
    return geometry.overlayRect.topLeft;
  }

  @override
  bool shouldRelayout(_PopupLayout oldDelegate) =>
      anchor != oldDelegate.anchor || target != oldDelegate.target || viewport != oldDelegate.viewport;
}

class _PopupScope extends InheritedWidget {
  const _PopupScope({required this.state, required super.child});

  final _ElPopupState state;

  @override
  bool updateShouldNotify(_PopupScope oldWidget) => state != oldWidget.state;
}

class _GeometryScope extends InheritedNotifier<ValueNotifier<ElOverlayAnchorGeometry?>> {
  const _GeometryScope({required super.notifier, required super.child});
}
