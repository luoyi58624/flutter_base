/// 独立的文本和图片文档选区。
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../common/selection_core.dart';
import '../../view/event/event.dart';
import '../../view/event/dispatcher.dart';
import '../../view/render/scroll_cursor_freeze.dart';
import '../../scroll/common/pointer/scroll_touch_gate.dart' show ScrollCatchPointers;
import '../../scroll/common/viewport/scroll_viewport.dart';
import '../../menu/context_menu.dart';
part 'selection_controller.dart';
part 'selection_model.dart';
part 'selection_render.dart';

/// 当前组件内的文本和图片选区，弹窗须自行包裹。
class ElSelectionView extends StatefulWidget {
  /// 创建选区容器。
  const ElSelectionView({super.key, required this.child, this.enabled = true, this.controller, this.onSelectionChanged})
    : _controls = null;

  const ElSelectionView._({
    super.key,
    required this.child,
    this.enabled = true,
    this.controller,
    this.onSelectionChanged,
    this._controls,
  });

  /// 被包裹的子树。
  final Widget child;

  /// 内部实例级附属层配置，业务入口使用平台默认实现。
  final SelectionControls? _controls;

  /// 是否启用选中能力（整棵子树级）。
  final bool enabled;

  /// 外部控制器。
  final ElSelectionController? controller;

  /// 选区变化回调。null 表示清空。
  final ValueChanged<String?>? onSelectionChanged;

  @override
  State<ElSelectionView> createState() => _SelectionViewState();
}

/// 内部引擎与测试调参视图，不进入公开入口。
class SelectionView extends ElSelectionView {
  /// 创建内部文档根。
  const SelectionView({
    super.key,
    required super.child,
    super.enabled = true,
    super.controller,
    super.onSelectionChanged,
    super.controls,
  }) : super._();
}

class _SelectionViewState extends State<ElSelectionView> {
  final GlobalKey _containerKey = GlobalKey();
  final SelectionDocument _document = SelectionDocument();

  RenderSelectionView? _render;
  bool _chromeVisible = false;

  /// 选区根焦点节点：指针落进选区内容（无更深可聚焦目标认领时）即隐式持焦，
  /// Ctrl+A/Ctrl+C/Esc 从此走焦点键盘冒泡链——根失焦后快捷键天然失效，
  /// 嵌套时内层节点更深、天然先消费（2026-08-03 裁决）。不进 Tab 遍历。
  final FocusNode _rootFocusNode = FocusNode(skipTraversal: true, debugLabel: 'ElSelectionView');

  @visibleForTesting
  int debugChromeSetStateCount = 0;

  SelectionControls _controls = const DesktopSelectionControls();
  bool _controlsResolved = false;

  /// 平台默认选区色对（root 兜底）：宿主未声明 `onSelection` 时的着色来源，
  /// 由 build 期按平台解析后推给 render（iOS/macOS 读 CupertinoTheme 需 context，
  /// 解析恒在 build、不在 paint 期）。
  Color _fallbackBgColor = const Color(0x553B82F6);
  Color? _fallbackTextColor;

  /// 按 [defaultTargetPlatform] 解析平台默认色对：Windows 实底系统蓝 + 白字；
  /// iOS / macOS 取 CupertinoTheme 主色 20% 罩；其余半透明蓝、不改字色。
  void _resolvePlatformFallback(BuildContext context) {
    final (bg, fg) = switch (defaultTargetPlatform) {
      TargetPlatform.windows => (const Color(0xFF0078D7), const Color(0xFFFFFFFF)),
      TargetPlatform.iOS ||
      TargetPlatform.macOS => (CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.2), null),
      _ => (const Color(0x553B82F6), null),
    };
    _fallbackBgColor = bg;
    _fallbackTextColor = fg;
  }

  /// 当前打开的右键菜单弹层（桌面 controls 专用；closed 后自动置 null）。
  ElContextMenuHandle? _menuEntry;

  @override
  void didUpdateWidget(covariant ElSelectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _menuEntry?.close();
  }

  @override
  void dispose() {
    _menuEntry?.close();
    _detachRender();
    _rootFocusNode.dispose();
    _document.dispose();
    super.dispose();
  }

  void _attachRender(RenderSelectionView render) {
    if (identical(_render, render)) {
      return;
    }
    _detachRender();
    _render = render;
    render.endpointsListenable.addListener(_handleEndpointsChanged);
    render.mobileChromeListenable.addListener(_handleEndpointsChanged);
    _handleEndpointsChanged();
  }

  void _detachRender() {
    _render?.endpointsListenable.removeListener(_handleEndpointsChanged);
    _render?.mobileChromeListenable.removeListener(_handleEndpointsChanged);
    _render = null;
  }

  void _handleEndpointsChanged() {
    final render = _render;
    final nextVisible = render != null && render.endpoints != null && render.selectionUsesMobileChrome;
    if (nextVisible == _chromeVisible) return;
    if (!mounted) {
      _chromeVisible = nextVisible;
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleEndpointsChanged();
      });
      return;
    }
    debugChromeSetStateCount++;
    setState(() => _chromeVisible = nextVisible);
  }

  /// 内部实例配置优先，其次读取内部作用域或平台默认实现。
  SelectionControls get _resolvedControls => widget._controls ?? SelectionControlsScope.of(context);

  Color get _handleColor => _fallbackBgColor.withAlpha(255);

  /// 桌面 controls 的右键菜单请求（render 仅在有选中内容时上报）。
  void _handleContextMenuRequested(Offset globalPosition) {
    final controls = _controls;
    if (controls is! DesktopSelectionControls || !mounted) return;
    _menuEntry?.close();
    final entry = controls.showContextMenu(
      context,
      position: globalPosition,
      actions: SelectionActions(copy: _menuCopy, selectAll: _selectAll),
    );
    _menuEntry = entry;
    if (entry == null) return;
    _render?.contextMenuOpen = true;
    entry.closed.then((_) {
      if (!identical(_menuEntry, entry)) return;
      _menuEntry = null;
      _render?.contextMenuOpen = false;
    });
  }

  /// 菜单「复制」：转发 controller 同款能力，保留选区（桌面惯例）。
  void _menuCopy() {
    final render = _render;
    if (render == null) return;
    unawaited(render.copySelection());
  }

  /// 工具条「复制」：复制后清空选区收起 Chrome（移动端原生行为）。
  void _toolbarCopy() {
    final render = _render;
    if (render == null) return;
    unawaited(render.copySelection());
    render.clearSelection();
  }

  /// 菜单 / 工具条「全选」。
  void _selectAll() => _render?.selectAllSelection();

  void _onHandleDragBegin(SelectionHandleSide side, Offset globalPosition, {int? pointer, PointerDeviceKind? kind}) {
    _render?.beginHandleDrag(side, globalPosition, pointer: pointer, kind: kind);
  }

  void _onHandleDragEnd() {
    _render?.endHandleDrag();
  }

  Offset _chromeGlobalToLocal(Offset global) {
    const pad = Offset(selectionChromeOverflowPad, selectionChromeOverflowPad);
    final transform = _render?.endpointsGlobalToLocalTransform;
    if (transform == null) return global + pad;
    return MatrixUtils.transformPoint(transform, global) + pad;
  }

  /// 只处理沿 Flutter 焦点链冒泡到本根、尚未被后代消费的选择快捷键。
  KeyEventResult _handleRootKeyEvent(FocusNode node, KeyEvent event) {
    final render = _render;
    if (render == null) return KeyEventResult.ignored;
    return render.handleRootKeyEvent(event);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !SelectionTextBoundary.blocks(context);
    final controls = _resolvedControls;
    if (_controlsResolved && !identical(controls, _controls)) {
      _menuEntry?.close();
      _menuEntry = null;
      _render?.contextMenuOpen = false;
    }
    _controls = controls;
    _controlsResolved = true;
    _resolvePlatformFallback(context);
    // 禁用/让位由 render 侧 selectionEnabled 决定是否认领；根节点仅在组件
    // 明确 disabled 时整体不可聚焦。
    _rootFocusNode.canRequestFocus = enabled;
    return SelectionChromeSlotHost(
      enabled: enabled,
      child: Builder(
        builder: (context) => SelectionChromePortal(
          visible: enabled && _chromeVisible && _render != null,
          fallbackGlobalToLocal: _chromeGlobalToLocal,
          content: Focus(
            focusNode: _rootFocusNode,
            includeSemantics: false,
            onKeyEvent: _handleRootKeyEvent,
            child: _wrapDocument(
              enabled: enabled,
              child: SelectionRenderWidget(
                document: _document,
                selectionControls: _controls,
                selectionColor: _fallbackBgColor,
                selectionTextColor: _fallbackTextColor,
                dragThreshold: _controls.resolveDragThreshold(context),
                longPressDelay: _controls.resolveLongPressDelay(context),
                longPressSelection: _controls.resolveLongPressSelection(context),
                longPressAutoScrollThreshold: _controls.resolveLongPressAutoScrollThreshold(context),
                clearOnTapOutside: _controls.resolveClearOnTapOutside(context),
                clearOnEsc: _controls.resolveClearOnEsc(context),
                longPressHaptics: _controls.resolveLongPressHaptics(context),
                handleHaptics: _controls.resolveHandleHaptics(context),
                touchAutoScroll: _controls.resolveTouchAutoScroll(context),
                mouseAutoScroll: _controls.resolveMouseAutoScroll(context),
                enabled: enabled,
                controller: widget.controller,
                onSelectionChanged: widget.onSelectionChanged,
                onContextMenuRequested: _handleContextMenuRequested,
                onRenderAttached: _attachRender,
                onRenderDetached: _detachRender,
                rootFocusNode: _rootFocusNode,
                child: DefaultSelectionStyle(selectionColor: _fallbackBgColor, child: widget.child),
              ),
            ),
          ),
          chromeBuilder: (context, globalToLocal) => _buildChrome(context, globalToLocal: globalToLocal),
        ),
      ),
    );
  }

  Widget _wrapDocument({required bool enabled, required Widget child}) {
    return SelectionContainer.disabled(
      // 保留注册容器的元素位置，启停时不重建渲染根和在用控制器。
      child: enabled
          ? SelectionContainer(key: _containerKey, delegate: _document, child: child)
          : SelectionContainer.disabled(key: _containerKey, child: child),
    );
  }

  Widget _buildChrome(BuildContext context, {Offset Function(Offset global)? globalToLocal}) {
    final render = _render;
    if (!widget.enabled || !_chromeVisible || render == null) {
      return const SizedBox.shrink();
    }
    return SelectionOverlayChrome(
      endpointsListenable: render.endpointsListenable,
      dragInfoListenable: render.dragInfoListenable,
      scrollActivityListenable: render.scrollActivityListenable,
      lineGeometryProvider: render.magnifierLineGeometryForDrag,
      globalToLocal: globalToLocal ?? _chromeGlobalToLocal,
      controls: _controls,
      handleColor: _handleColor,
      showHandles: !kIsWeb && _controls.resolveShowHandles(context),
      showMagnifier: !kIsWeb && _controls.resolveShowMagnifier(context),
      showToolbar: !kIsWeb && _controls.resolveShowToolbar(context),
      toolbarActions: SelectionActions(copy: _toolbarCopy, selectAll: _selectAll),
      onHandleDragBegin: _onHandleDragBegin,
      onHandleDragEnd: _onHandleDragEnd,
    );
  }
}

/// 文档视图到渲染内核的内部桥。
class SelectionRenderWidget extends SingleChildRenderObjectWidget {
  /// 创建内部渲染桥。
  const SelectionRenderWidget({
    super.key,
    required super.child,
    required this.selectionControls,
    required this.document,
    required this.selectionColor,
    required this.selectionTextColor,
    required this.dragThreshold,
    required this.longPressDelay,
    required this.longPressSelection,
    required this.longPressAutoScrollThreshold,
    required this.clearOnTapOutside,
    required this.clearOnEsc,
    required this.longPressHaptics,
    required this.handleHaptics,
    required this.touchAutoScroll,
    required this.mouseAutoScroll,
    required this.enabled,
    required this.controller,
    required this.onSelectionChanged,
    required this.onContextMenuRequested,
    required this.onRenderAttached,
    required this.onRenderDetached,
    required this.rootFocusNode,
  });

  /// 当前文档的官方成员和事件通道。
  final SelectionDocument document;

  /// 当前平台的内部交互控件。
  final SelectionControls selectionControls;

  /// 选中背景色。
  final Color selectionColor;

  /// 选中文字颜色。
  final Color? selectionTextColor;

  /// 鼠标拖选阈值。
  final double dragThreshold;

  /// 触摸长按等待时间。
  final Duration longPressDelay;

  /// 长按初始选择粒度。
  final LongPressSelection longPressSelection;

  /// 长按自动滚动的激活阈值。
  final double longPressAutoScrollThreshold;

  /// 空白点击是否清空选区。
  final bool clearOnTapOutside;

  /// Escape 是否清空选区。
  final bool clearOnEsc;

  /// 长按是否提供触觉反馈。
  final bool longPressHaptics;

  /// 端点移动是否提供触觉反馈。
  final bool handleHaptics;

  /// 触摸自动滚动配置。
  final SelectionAutoScrollConfig touchAutoScroll;

  /// 鼠标自动滚动配置。
  final SelectionAutoScrollConfig mouseAutoScroll;

  /// 是否启用当前选区根。
  final bool enabled;

  /// 绑定的文档选区控制器。
  final ElSelectionController? controller;

  /// 纯文本选区变化回调。
  final ValueChanged<String?>? onSelectionChanged;

  /// 已有选区时的右键菜单请求。
  final ValueChanged<Offset>? onContextMenuRequested;

  /// 渲染根挂载回调。
  final void Function(RenderSelectionView) onRenderAttached;

  /// 渲染根销毁回调。
  final VoidCallback onRenderDetached;

  /// 选区根焦点节点：down 认领隐式焦点、快捷键走焦点冒泡链的载体。
  final FocusNode? rootFocusNode;

  @override
  RenderSelectionView createRenderObject(BuildContext context) {
    return RenderSelectionView(
      document: document,
      selectionControls: selectionControls,
      selectionColor: selectionColor,
      selectionTextColor: selectionTextColor,
      dragThreshold: dragThreshold,
      longPressDelay: longPressDelay,
      longPressSelection: longPressSelection,
      longPressAutoScrollThreshold: longPressAutoScrollThreshold,
      clearOnTapOutside: clearOnTapOutside,
      clearOnEsc: clearOnEsc,
      longPressHaptics: longPressHaptics,
      handleHaptics: handleHaptics,
      touchAutoScroll: touchAutoScroll,
      mouseAutoScroll: mouseAutoScroll,
      enabled: enabled,
      controller: controller,
      onSelectionChanged: onSelectionChanged,
      onContextMenuRequested: onContextMenuRequested,
      rootFocusNode: rootFocusNode,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderSelectionView renderObject) {
    renderObject
      ..selectionControls = selectionControls
      ..selectionColor = selectionColor
      ..selectionTextColor = selectionTextColor
      ..dragThreshold = dragThreshold
      ..longPressDelay = longPressDelay
      ..longPressSelection = longPressSelection
      ..longPressAutoScrollThreshold = longPressAutoScrollThreshold
      ..clearOnTapOutside = clearOnTapOutside
      ..clearOnEsc = clearOnEsc
      ..longPressHaptics = longPressHaptics
      ..handleHaptics = handleHaptics
      ..touchAutoScroll = touchAutoScroll
      ..mouseAutoScroll = mouseAutoScroll
      ..enabled = enabled
      ..controller = controller
      ..onSelectionChanged = onSelectionChanged
      ..onContextMenuRequested = onContextMenuRequested
      ..rootFocusNode = rootFocusNode;
  }

  @override
  SingleChildRenderObjectElement createElement() => _SelectionRenderElement(this);
}

class _SelectionRenderElement extends SingleChildRenderObjectElement {
  _SelectionRenderElement(SelectionRenderWidget super.widget);

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    (widget as SelectionRenderWidget).onRenderAttached(renderObject as RenderSelectionView);
  }

  @override
  void update(SelectionRenderWidget newWidget) {
    super.update(newWidget);
    newWidget.onRenderAttached(renderObject as RenderSelectionView);
  }

  @override
  void unmount() {
    (widget as SelectionRenderWidget).onRenderDetached();
    super.unmount();
  }
}
