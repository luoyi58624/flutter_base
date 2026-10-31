part of 'selection_core.dart';

/// 白盒测试识别内置 selection handle 的稳定 key。
@visibleForTesting
Key get selectionHandleVisualKey => const ValueKey<String>('selection-handle-visual');

/// selection toolbar 外壳（含自定义 buildToolbar 产物）的稳定 key：Chrome 层
/// 挂在工具条外，白盒测试按它定位。
Key get selectionToolbarKey => const ValueKey<String>('selection-toolbar');

/// 选中动作集：菜单 / 工具条只转发宿主已经具备的剪贴板与全选能力。
class SelectionActions {
  /// 创建动作集。
  const SelectionActions({
    required this.copy,
    required this.selectAll,
    this.cut,
    this.paste,
    this.canCopy = true,
    bool? canCut,
    bool? canPaste,
    this.canSelectAll = true,
  }) : canCut = canCut ?? cut != null,
       canPaste = canPaste ?? paste != null;

  /// 剪切当前选区；null 表示宿主不提供剪切能力。
  final VoidCallback? cut;

  /// 复制当前选区。
  final VoidCallback copy;

  /// 粘贴到当前选区；null 表示宿主不提供粘贴能力。
  final VoidCallback? paste;

  /// 选中当前选区根内所有可选内容。
  final VoidCallback selectAll;

  /// 当前是否可以复制。
  final bool canCopy;

  /// 当前是否可以剪切。
  final bool canCut;

  /// 当前是否可以粘贴。
  final bool canPaste;

  /// 当前是否可以全选。
  final bool canSelectAll;
}

/// 移动端浮动工具条的构建入参（[SelectionControls.buildToolbar]）。
class SelectionToolbarDetails {
  /// 创建入参。
  const SelectionToolbarDetails({required this.actions, required this.isAbove});

  /// 动作集。
  final SelectionActions actions;

  /// 工具条是否位于选区上方（iOS 形据此决定箭头朝向）。
  final bool isAbove;
}

/// 移动端长按进入选中模式时的初始选中粒度。
enum LongPressSelection {
  /// 命中词。
  word,

  /// 命中参与者的整段内容。
  paragraph,
}

/// 文本选中 Chrome 的平台构建器（句柄、放大镜、工具条、右键菜单）。
///
/// 不负责选区颜色（由宿主 `ElStyle.onSelection` 与平台默认决定）也不决定
/// Chrome 显隐——显隐由选区引擎按「移动档 / 桌面档」在运行时决定。
/// 本包内建 Android/iOS 移动形与纯机制桌面形；实例直参或最近
/// 内部 SelectionControlsScope 可覆写平台默认。
abstract class SelectionControls {
  /// 创建 controls。
  const SelectionControls({
    this.dragThreshold,
    this.longPressDelay,
    this.longPressSelection,
    this.longPressAutoScrollThreshold,
    this.clearOnTapOutside,
    this.clearOnEsc,
    this.showHandles,
    this.showMagnifier,
    this.showToolbar,
    this.longPressHaptics,
    this.handleHaptics,
    this.touchAutoScroll,
    this.mouseAutoScroll,
    this.hideHandlesWhileScrolling,
    this.hideDraggedHandle,
    this.hideHandleBehindMagnifier,
  });

  /// 鼠标拖选确认阈值。
  final double? dragThreshold;

  /// 触摸长按进入选中模式的延时。
  final Duration? longPressDelay;

  /// 长按进入选中时的初始粒度。
  final LongPressSelection? longPressSelection;

  /// 长按激活后开启边缘自动滚动所需的累计移动距离。
  final double? longPressAutoScrollThreshold;

  /// 点击空白是否清空选区。
  final bool? clearOnTapOutside;

  /// Esc 是否清空选区。
  final bool? clearOnEsc;

  /// 是否构建 selection handles。null 视为构建；Chrome 何时可见由选区引擎
  /// 按移动档/桌面档在运行时决定，本开关只做整体关停（Web 恒不构建）。
  final bool? showHandles;

  /// 是否构建 magnifier。null 视为构建；显隐口径同 [showHandles]。
  final bool? showMagnifier;

  /// 是否构建移动端浮动工具条。null 落 [resolveShowToolbar] 的形态默认
  /// （移动形态构建、桌面形态不构建、Web 恒不构建）。
  final bool? showToolbar;

  /// 长按建立选区时是否触发触觉反馈。
  final bool? longPressHaptics;

  /// handle 或长按拖动中端点变化时是否触发触觉反馈。
  final bool? handleHaptics;

  /// 触摸拖选的边缘自动滚动配置。
  final SelectionAutoScrollConfig? touchAutoScroll;

  /// 鼠标拖选的边缘自动滚动配置。
  final SelectionAutoScrollConfig? mouseAutoScroll;

  /// 滚动期间是否隐藏 handles。
  final bool? hideHandlesWhileScrolling;

  /// handle 拖动期间是否隐藏被拖动的 handle。
  final bool? hideDraggedHandle;

  /// magnifier 与 handle 相交时是否隐藏 handle。
  final bool? hideHandleBehindMagnifier;

  /// 解析鼠标拖选确认阈值。
  double resolveDragThreshold(BuildContext context) => dragThreshold ?? 4.0;

  /// 解析触摸长按延时。
  Duration resolveLongPressDelay(BuildContext context) => longPressDelay ?? const Duration(milliseconds: 400);

  /// 解析长按初始粒度。
  LongPressSelection resolveLongPressSelection(BuildContext context) => longPressSelection ?? LongPressSelection.word;

  /// 解析长按自动滚动门槛。
  double resolveLongPressAutoScrollThreshold(BuildContext context) => longPressAutoScrollThreshold ?? 100.0;

  /// 解析点击空白清空策略。
  bool resolveClearOnTapOutside(BuildContext context) => clearOnTapOutside ?? true;

  /// 解析 Esc 清空策略。
  bool resolveClearOnEsc(BuildContext context) => clearOnEsc ?? true;

  /// 解析长按建立选区时的触觉反馈策略。
  bool resolveLongPressHaptics(BuildContext context) => longPressHaptics ?? false;

  /// 解析拖动端点变化时的触觉反馈策略。
  bool resolveHandleHaptics(BuildContext context) => handleHaptics ?? false;

  /// 解析触摸边缘自动滚动配置。
  SelectionAutoScrollConfig resolveTouchAutoScroll(BuildContext context) =>
      touchAutoScroll ?? SelectionAutoScrollConfig.touch;

  /// 解析鼠标边缘自动滚动配置。
  SelectionAutoScrollConfig resolveMouseAutoScroll(BuildContext context) =>
      mouseAutoScroll ?? SelectionAutoScrollConfig.mouse;

  /// 解析滚动期间隐藏 handles 的策略。
  bool resolveHideHandlesWhileScrolling(BuildContext context) => hideHandlesWhileScrolling ?? false;

  /// 解析拖动期间隐藏目标 handle 的策略。
  bool resolveHideDraggedHandle(BuildContext context) => hideDraggedHandle ?? false;

  /// 解析 magnifier 遮挡 handle 时的隐藏策略。
  bool resolveHideHandleBehindMagnifier(BuildContext context) => hideHandleBehindMagnifier ?? false;

  /// 解析 handles 构建开关（Web 恒不构建在消费端另行判定；桌面形态默认 false）。
  bool resolveShowHandles(BuildContext context) => showHandles ?? true;

  /// 解析 magnifier 构建开关，口径同 [resolveShowHandles]。
  bool resolveShowMagnifier(BuildContext context) => showMagnifier ?? true;

  /// 解析移动端浮动工具条构建开关，口径同 [resolveShowHandles]。
  bool resolveShowToolbar(BuildContext context) => showToolbar ?? true;

  /// 构建长按选中后的浮动工具条。
  ///
  /// 返回 null 表示该形态不出工具条（基座默认）；Android / iOS 各自覆写平台
  /// 形态，自定义 controls 覆写本钩子换整体外观。定位（选区上/下方、水平
  /// 居中与越界钳制）由选区 Chrome 层负责，实现只需构建视觉本体。
  Widget? buildToolbar(BuildContext context, SelectionToolbarDetails details) => null;

  /// 当前指针种类是否可以拖动 handle。
  ///
  /// handles 只在移动档选区出现，任何能到达它的 pointer 都应能拖（Chrome
  /// DevTools / AOSP 外接鼠标同款）。默认全收；曾经的"排除 mouse"是
  /// mouse 恒桌面档的旧世界残留——dragDevices 注入 mouse 后 Windows 上
  /// 句柄完全拖不动（2026-07-29 实测报障）。
  bool acceptsHandlePointer(PointerDeviceKind kind) => true;

  /// 返回 handle 的视觉尺寸。
  Size resolveHandleSize(BuildContext context, TextSelectionHandleType type, double lineHeight) =>
      Size(12.0, math.max(12.0, lineHeight));

  /// 返回 handle 相对 caret 底部锚点的位置。
  Offset resolveHandleAnchor(BuildContext context, TextSelectionHandleType type, double lineHeight) {
    final size = resolveHandleSize(context, type, lineHeight);
    return Offset(size.width / 2, size.height / 2);
  }

  /// 返回 handle 的命中矩形。
  ///
  /// [visualRect] 使用全局坐标，返回值也必须使用全局坐标。
  Rect resolveHandleHitRect(BuildContext context, TextSelectionHandleType type, double lineHeight, Rect visualRect) =>
      visualRect;

  /// 返回手指相对 caret 锚点的理想垂直距离。
  double resolveHandleIdealVerticalOffset(TextSelectionHandleType type, double lineHeight) => 15.4;

  /// 返回拖动命中点相对 caret 锚点的垂直补偿。
  double resolveHandleTouchOffsetY(TextSelectionHandleType type, double lineHeight) => -6.6;

  /// 构建 handle 视觉。
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double lineHeight, Color color) {
    return _SelectionHandleVisual(
      key: selectionHandleVisualKey,
      color: color,
      type: type,
      size: resolveHandleSize(context, type, lineHeight),
    );
  }

  /// 返回 magnifier 的视觉尺寸。
  Size resolveMagnifierSize(BuildContext context) => const Size(100.0, 48.0);

  /// 返回 magnifier 位置跟随动画时长。
  Duration resolveMagnifierPositionDuration(BuildContext context) => Duration.zero;

  /// 返回 magnifier 出场动画时长。
  Duration resolveMagnifierEnterDuration(BuildContext context) => Duration.zero;

  /// 返回 magnifier 退场动画时长。
  Duration resolveMagnifierExitDuration(BuildContext context) => Duration.zero;

  /// 是否对 magnifier 的横向位置应用跟随动画。
  bool resolveAnimateMagnifierX(BuildContext context) => false;

  /// 是否对 magnifier 的纵向位置应用跟随动画。
  bool resolveAnimateMagnifierY(BuildContext context) => false;

  /// 返回 magnifier 位置动画曲线。
  Curve resolveMagnifierPositionCurve(BuildContext context) => Curves.linear;

  /// 返回 magnifier 出入场动画曲线。
  Curve resolveMagnifierVisibilityCurve(BuildContext context) => Curves.easeOut;

  /// 当前输入是否允许显示 magnifier。
  bool shouldShowMagnifier(BuildContext context, MagnifierInfo info) => true;

  /// 返回 magnifier 目标中心点，坐标使用全局坐标。
  Offset resolveMagnifierCenter(BuildContext context, MagnifierInfo info) {
    return Offset(info.globalGesturePosition.dx, info.currentLineBoundaries.center.dy - 42.0);
  }

  /// 返回 magnifier 应采样的全局焦点。
  Offset resolveMagnifierFocalPoint(BuildContext context, MagnifierInfo info, Rect magnifierRect) {
    return info.caretRect.center;
  }

  /// 将 magnifier 矩形限制到可见区域。
  Rect constrainMagnifierRect(BuildContext context, Rect rect, Size screenSize, EdgeInsets safePadding) {
    final leftMin = safePadding.left;
    final leftMax = math.max(leftMin, screenSize.width - safePadding.right - rect.width);
    final topMin = safePadding.top;
    final topMax = math.max(topMin, screenSize.height - safePadding.bottom - rect.height);
    return Rect.fromLTWH(
      rect.left.clamp(leftMin, leftMax).toDouble(),
      rect.top.clamp(topMin, topMax).toDouble(),
      rect.width,
      rect.height,
    );
  }

  /// 构建 magnifier 视觉。
  ///
  /// [animationValue] 从 0 到 1，供平台实现出入场效果。
  Widget buildMagnifier(
    BuildContext context,
    MagnifierInfo info, {
    required Size size,
    required Offset focalPointOffset,
    required double animationValue,
  }) {
    return RawMagnifier(
      size: size,
      magnificationScale: 1.0,
      focalPointOffset: focalPointOffset,
      decoration: MagnifierDecoration(opacity: animationValue, shape: const StadiumBorder()),
    );
  }

  /// 长按选择正式开始时调用。
  void onLongPressStart(PointerDeviceKind kind) {}

  /// handle 拖动开始时调用。
  void onHandleDragStart(TextSelectionHandleType type, PointerDeviceKind kind) {}

  /// 被拖端点发生变化时调用。
  void onHandleSelectionChanged(TextSelectionHandleType type) {}

  /// handle 拖动结束或异常中断时调用。
  void onHandleDragEnd(TextSelectionHandleType type) {}
}

/// 桌面文本选中 controls：右键上下文菜单形态（Windows / Linux / macOS 内置默认）。
///
/// 桌面形态不出句柄 / 放大镜 / 工具条（show* 解析默认 false）；选中内容上的
/// secondary tap（右键）触发 [showContextMenu]，动作集由宿主按读写状态提供。
/// 菜单外观归通用菜单体系：走 `el.showContextMenu`
/// 的「直参 > `el.globalContextMenus` > 平台默认」解析链，或经 [contextMenu]
/// 直接指定实现；增删动作项覆写 [buildMenuItems]。
class DesktopSelectionControls extends SelectionControls {
  /// 创建桌面 controls。
  const DesktopSelectionControls({
    this.contextMenu,
    super.dragThreshold,
    super.longPressDelay,
    super.longPressSelection,
    super.longPressAutoScrollThreshold,
    super.clearOnTapOutside,
    super.clearOnEsc,
    super.showHandles,
    super.showMagnifier,
    super.showToolbar,
    super.longPressHaptics,
    super.handleHaptics,
    super.touchAutoScroll,
    super.mouseAutoScroll,
    super.hideHandlesWhileScrolling,
    super.hideDraggedHandle,
    super.hideHandleBehindMagnifier,
  });

  /// 菜单实现覆写口。null 时由 `el.showContextMenu` 按
  /// 「`el.globalContextMenus` > 平台默认」继续解析。
  final ElContextMenu? contextMenu;

  @override
  bool resolveShowHandles(BuildContext context) => showHandles ?? false;

  @override
  bool resolveShowMagnifier(BuildContext context) => showMagnifier ?? false;

  @override
  bool resolveShowToolbar(BuildContext context) => showToolbar ?? false;

  /// 组装右键菜单条目（open 钩子）。
  ///
  /// 只提供复制 / 全选的旧宿主保持原来的两项顺序；可编辑宿主提供 cut / paste
  /// 后扩展为「剪切、复制、粘贴、分隔线、全选」，不可用动作保留但禁用。
  List<ElContextMenuItem> buildMenuItems(BuildContext context, SelectionActions actions) {
    final cut = actions.cut;
    final paste = actions.paste;
    if (cut == null && paste == null) {
      return [
        ElContextMenuItem(label: '复制', onSelect: actions.copy, enabled: actions.canCopy),
        ElContextMenuItem(label: '全选', onSelect: actions.selectAll, enabled: actions.canSelectAll),
      ];
    }
    return [
      if (cut != null) ElContextMenuItem(label: '剪切', onSelect: cut, enabled: actions.canCut),
      ElContextMenuItem(label: '复制', onSelect: actions.copy, enabled: actions.canCopy),
      if (paste != null) ElContextMenuItem(label: '粘贴', onSelect: paste, enabled: actions.canPaste),
      const ElContextMenuItem.divider(),
      ElContextMenuItem(label: '全选', onSelect: actions.selectAll, enabled: actions.canSelectAll),
    ];
  }

  /// 在 [position]（全局坐标）弹出右键菜单。返回菜单句柄；无 Flutter Overlay 时
  /// debug 告警并返回 null（选区其他功能不受影响）。
  ElContextMenuHandle? showContextMenu(
    BuildContext context, {
    required Offset position,
    required SelectionActions actions,
  }) {
    return el.showContextMenu(context, position: position, items: buildMenuItems(context, actions), menu: contextMenu);
  }
}

class _SelectionHandleVisual extends LeafRenderObjectWidget {
  const _SelectionHandleVisual({super.key, required this.color, required this.type, required this.size});

  final Color color;
  final TextSelectionHandleType type;
  final Size size;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSelectionHandleVisual(color, type, size);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderSelectionHandleVisual renderObject) {
    renderObject
      ..color = color
      ..type = type
      ..visualSize = size;
  }
}

class _RenderSelectionHandleVisual extends RenderBox {
  _RenderSelectionHandleVisual(this._color, this._type, this._visualSize);

  Color _color;
  TextSelectionHandleType _type;
  Size _visualSize;

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  set type(TextSelectionHandleType value) {
    if (_type == value) return;
    _type = value;
    markNeedsPaint();
  }

  set visualSize(Size value) {
    if (_visualSize == value) return;
    _visualSize = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(_visualSize);

  @override
  void performLayout() {
    size = constraints.constrain(_visualSize);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final paint = Paint()
      ..color = _color
      ..isAntiAlias = true;
    if (_type == TextSelectionHandleType.collapsed) return;
    final radius = math.min(size.width, size.height) / 2;
    final center = offset + Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, radius, paint);
    final rect = _type == TextSelectionHandleType.left
        ? Rect.fromLTRB(center.dx, center.dy - radius, center.dx + radius, center.dy)
        : Rect.fromLTRB(center.dx - radius, center.dy - radius, center.dx, center.dy);
    canvas.drawRect(rect, paint);
  }
}

// Android / iOS 平台文本选中形制由 ElSelectionView 按平台直接回落，
// 引擎与测试通过内部作用域覆写，业务入口不暴露控件协议。

/// 白盒测试识别内置 selection handle 的稳定 key（与 el_ui 基座句柄同一
/// key 值，finder 按 ValueKey 字符串定位）。
const _handleVisualKey = ValueKey<String>('selection-handle-visual');

/// 白盒测试识别内置 selection toolbar 主体（Android 横条 / iOS 气泡条）的稳定 key。
const _toolbarVisualKey = ValueKey<String>('selection-toolbar-visual');

/// Android 文本选中 controls。
///
/// 句柄视觉沿用基座通用泪滴形（圆 + 象限角），本类只覆写尺寸 / 锚点 /
/// 命中膨胀与 Material 工具条 / 放大镜形制。
class AndroidSelectionControls extends SelectionControls {
  /// 创建 Android controls。
  const AndroidSelectionControls({
    super.dragThreshold,
    super.longPressDelay,
    super.longPressSelection,
    super.longPressAutoScrollThreshold,
    super.clearOnTapOutside,
    super.clearOnEsc,
    super.showHandles,
    super.showMagnifier,
    super.showToolbar,
    super.longPressHaptics,
    super.handleHaptics,
    super.touchAutoScroll,
    super.mouseAutoScroll,
    super.hideHandlesWhileScrolling,
    super.hideDraggedHandle,
    super.hideHandleBehindMagnifier,
  });

  @override
  bool resolveLongPressHaptics(BuildContext context) => longPressHaptics ?? true;

  @override
  bool resolveHideHandlesWhileScrolling(BuildContext context) => hideHandlesWhileScrolling ?? true;

  @override
  bool resolveHideDraggedHandle(BuildContext context) => hideDraggedHandle ?? true;

  @override
  bool resolveHideHandleBehindMagnifier(BuildContext context) => hideHandleBehindMagnifier ?? true;

  @override
  Size resolveHandleSize(BuildContext context, TextSelectionHandleType type, double lineHeight) =>
      const Size.square(22.0);

  @override
  Offset resolveHandleAnchor(BuildContext context, TextSelectionHandleType type, double lineHeight) {
    return switch (type) {
      TextSelectionHandleType.left => const Offset(22.0, 0.0),
      TextSelectionHandleType.right => Offset.zero,
      TextSelectionHandleType.collapsed => const Offset(11.0, 0.0),
    };
  }

  @override
  Rect resolveHandleHitRect(BuildContext context, TextSelectionHandleType type, double lineHeight, Rect visualRect) =>
      visualRect.inflate(8.0);

  @override
  Size resolveMagnifierSize(BuildContext context) => const Size(100.0, 48.0);

  @override
  Duration resolveMagnifierPositionDuration(BuildContext context) => const Duration(milliseconds: 100);

  @override
  bool resolveAnimateMagnifierY(BuildContext context) => true;

  @override
  Curve resolveMagnifierPositionCurve(BuildContext context) => Curves.easeOut;

  @override
  Offset resolveMagnifierCenter(BuildContext context, MagnifierInfo info) {
    return Offset(info.globalGesturePosition.dx, info.currentLineBoundaries.center.dy - 42.0);
  }

  @override
  Offset resolveMagnifierFocalPoint(BuildContext context, MagnifierInfo info, Rect magnifierRect) {
    final x = info.globalGesturePosition.dx
        .clamp(info.currentLineBoundaries.left, info.currentLineBoundaries.right)
        .toDouble();
    return Offset(x, magnifierRect.center.dy + 42.0);
  }

  @override
  Widget buildMagnifier(
    BuildContext context,
    MagnifierInfo info, {
    required Size size,
    required Offset focalPointOffset,
    required double animationValue,
  }) {
    return RawMagnifier(
      size: size,
      magnificationScale: 1.25,
      focalPointOffset: focalPointOffset,
      clipBehavior: Clip.hardEdge,
      decoration: const MagnifierDecoration(
        shape: StadiumBorder(),
        shadows: <BoxShadow>[
          BoxShadow(color: Color(0x33000000), blurRadius: 4.0, offset: Offset(0.0, 2.0)),
          BoxShadow(color: Color(0x1F000000), blurRadius: 1.0, offset: Offset(0.0, 1.0)),
        ],
      ),
      child: const ElView(style: ElStyle(backgroundColor: Color(0x0EFFFFFF))),
    );
  }

  @override
  Widget? buildToolbar(BuildContext context, SelectionToolbarDetails details) {
    final actions = _toolbarActions(details.actions);
    if (actions.isEmpty) return null;
    return ElView(
      key: _toolbarVisualKey,
      style: const ElStyle(
        height: 40,
        backgroundColor: Color(0xFFFFFFFF),
        borderRadius: .all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(color: Color(0x2E000000), blurRadius: 14, offset: Offset(0, 4), spreadRadius: -3),
          BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
        onDark: ElStyle(backgroundColor: Color(0xFF2E2E2E)),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [for (final action in actions) _androidToolbarAction(action.label, action.callback)],
      ),
    );
  }

  /// Material 风格工具条文字按钮。
  Widget _androidToolbarAction(String label, VoidCallback onPressed) {
    return _SelectionToolbarAction(
      label: label,
      onPressed: onPressed,
      style: const ElStyle(
        height: 40,
        padding: .symmetric(horizontal: 14),
        alignment: .center,
        borderRadius: .all(Radius.circular(10)),
        fontSize: 14,
        fontWeight: .w500,
        color: Color(0xFF1F1F1F),
        onHover: ElStyle(backgroundColor: Color(0x0F000000)),
        onTap: ElStyle(backgroundColor: Color(0x1A000000)),
        onDark: ElStyle(
          color: Color(0xFFE8EAED),
          onHover: ElStyle(backgroundColor: Color(0x14FFFFFF)),
          onTap: ElStyle(backgroundColor: Color(0x24FFFFFF)),
        ),
      ),
    );
  }
}

/// iOS 文本选中 controls。
class IosSelectionControls extends SelectionControls {
  /// 创建 iOS controls。
  const IosSelectionControls({
    super.dragThreshold,
    super.longPressDelay,
    super.longPressSelection,
    super.longPressAutoScrollThreshold,
    super.clearOnTapOutside,
    super.clearOnEsc,
    super.showHandles,
    super.showMagnifier,
    super.showToolbar,
    super.longPressHaptics,
    super.handleHaptics,
    super.touchAutoScroll,
    super.mouseAutoScroll,
    super.hideHandlesWhileScrolling,
    super.hideDraggedHandle,
    super.hideHandleBehindMagnifier,
  });

  @override
  Duration resolveLongPressDelay(BuildContext context) => longPressDelay ?? const Duration(milliseconds: 500);

  @override
  bool resolveLongPressHaptics(BuildContext context) => longPressHaptics ?? true;

  @override
  bool resolveHideDraggedHandle(BuildContext context) => hideDraggedHandle ?? true;

  @override
  Size resolveHandleSize(BuildContext context, TextSelectionHandleType type, double lineHeight) =>
      Size(12.0, lineHeight + 10.5);

  @override
  Offset resolveHandleAnchor(BuildContext context, TextSelectionHandleType type, double lineHeight) {
    final size = resolveHandleSize(context, type, lineHeight);
    return switch (type) {
      TextSelectionHandleType.left => Offset(size.width / 2, size.height),
      TextSelectionHandleType.right => Offset(size.width / 2, lineHeight),
      TextSelectionHandleType.collapsed => Offset(size.width / 2, lineHeight + 5.25),
    };
  }

  @override
  Rect resolveHandleHitRect(BuildContext context, TextSelectionHandleType type, double lineHeight, Rect visualRect) {
    final width = math.max(44.0, visualRect.width);
    final height = math.max(44.0, visualRect.height);
    return Rect.fromCenter(center: visualRect.center, width: width, height: height);
  }

  @override
  double resolveHandleIdealVerticalOffset(TextSelectionHandleType type, double lineHeight) => 0.7 * (lineHeight + 10.5);

  @override
  double resolveHandleTouchOffsetY(TextSelectionHandleType type, double lineHeight) => -0.3 * (lineHeight + 10.5);

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double lineHeight, Color color) {
    return _IosSelectionHandleVisual(
      key: _handleVisualKey,
      color: color,
      type: type,
      size: resolveHandleSize(context, type, lineHeight),
    );
  }

  @override
  Size resolveMagnifierSize(BuildContext context) => const Size(80.0, 47.5);

  @override
  Duration resolveMagnifierPositionDuration(BuildContext context) => const Duration(milliseconds: 45);

  @override
  Duration resolveMagnifierEnterDuration(BuildContext context) => const Duration(milliseconds: 150);

  @override
  Duration resolveMagnifierExitDuration(BuildContext context) => const Duration(milliseconds: 150);

  @override
  bool resolveAnimateMagnifierX(BuildContext context) => true;

  @override
  bool resolveAnimateMagnifierY(BuildContext context) => true;

  @override
  bool shouldShowMagnifier(BuildContext context, MagnifierInfo info) {
    return info.caretRect.center.dy - info.globalGesturePosition.dy >= -48.0;
  }

  @override
  Offset resolveMagnifierCenter(BuildContext context, MagnifierInfo info) {
    final lineCenter = info.caretRect.center.dy;
    final verticalPosition = math.max(lineCenter, lineCenter - (lineCenter - info.globalGesturePosition.dy) / 10.0);
    return Offset(info.globalGesturePosition.dx, verticalPosition - 49.75);
  }

  @override
  Rect constrainMagnifierRect(BuildContext context, Rect rect, Size screenSize, EdgeInsets safePadding) {
    final minLeft = 10.0;
    final maxLeft = math.max(minLeft, screenSize.width - 10.0 - rect.width);
    return Rect.fromLTWH(rect.left.clamp(minLeft, maxLeft).toDouble(), rect.top, rect.width, rect.height);
  }

  @override
  Offset resolveMagnifierFocalPoint(BuildContext context, MagnifierInfo info, Rect magnifierRect) {
    return Offset(magnifierRect.center.dx, info.caretRect.center.dy);
  }

  @override
  Widget buildMagnifier(
    BuildContext context,
    MagnifierInfo info, {
    required Size size,
    required Offset focalPointOffset,
    required double animationValue,
  }) {
    final theme = CupertinoTheme.of(context);
    return ElView(
      style: ElStyle(transform: .translate(0.0, 26.0 * (1.0 - animationValue))),
      child: RawMagnifier(
        size: size,
        magnificationScale: 1.0,
        focalPointOffset: focalPointOffset,
        decoration: MagnifierDecoration(
          opacity: animationValue,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.elliptical(60.0, 50.0)),
            side: BorderSide(color: theme.primaryColor, width: 2.0),
          ),
          shadows: const <BoxShadow>[
            BoxShadow(
              color: Color.fromARGB(25, 0, 0, 0),
              blurRadius: 11.0,
              spreadRadius: 0.2,
              blurStyle: BlurStyle.outer,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget? buildToolbar(BuildContext context, SelectionToolbarDetails details) {
    const bubbleColor = Color(0xF2202020);
    final actions = _toolbarActions(details.actions);
    if (actions.isEmpty) return null;
    final children = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      if (i > 0) {
        children.add(const ElView(style: ElStyle(width: 1, height: 36, backgroundColor: Color(0x33FFFFFF))));
      }
      final action = actions[i];
      children.add(_iosToolbarAction(action.label, action.callback));
    }
    final bar = ElView(
      key: _toolbarVisualKey,
      style: const ElStyle(
        height: 36,
        backgroundColor: bubbleColor,
        borderRadius: .all(Radius.circular(9)),
        clipBehavior: Clip.antiAlias,
      ),
      child: Row(mainAxisSize: .min, children: children),
    );
    // 黑底气泡 + 指向选区的小箭头：上方形态箭头朝下，下方形态箭头朝上。
    final arrow = ElView(
      style: ElStyle(
        width: 16,
        height: 7,
        backgroundColor: bubbleColor,
        clipPath: ElClipper.triangle(pointTo: details.isAbove ? AxisDirection.down : AxisDirection.up),
      ),
    );
    return Column(mainAxisSize: .min, children: details.isAbove ? [bar, arrow] : [arrow, bar]);
  }

  /// iOS 气泡工具条文字按钮。
  Widget _iosToolbarAction(String label, VoidCallback onPressed) {
    return _SelectionToolbarAction(
      label: label,
      onPressed: onPressed,
      style: const ElStyle(
        height: 36,
        padding: .symmetric(horizontal: 14),
        alignment: .center,
        fontSize: 14,
        color: Color(0xFFFFFFFF),
        onHover: ElStyle(backgroundColor: Color(0x1FFFFFFF)),
        onTap: ElStyle(backgroundColor: Color(0x33FFFFFF)),
      ),
    );
  }
}

/// 移动端选区工具条按钮。
///
/// 浮动工具条不参与 Tab 遍历、不认领指针焦点，也不额外暴露焦点语义；节点
/// 由本组件持有，随工具条构建 / 销毁。
class _SelectionToolbarAction extends StatefulWidget {
  const _SelectionToolbarAction({required this.label, required this.onPressed, required this.style});

  final String label;
  final VoidCallback onPressed;
  final ElStyle style;

  @override
  State<_SelectionToolbarAction> createState() => _SelectionToolbarActionState();
}

class _SelectionToolbarActionState extends State<_SelectionToolbarAction> {
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'SelectionToolbar(${widget.label})',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ElButtonView(
    onPressed: widget.onPressed,
    semanticLabel: widget.label,
    focusNode: _focusNode,
    style: widget.style,
    child: widget.label,
  );
}

List<({String label, VoidCallback callback})> _toolbarActions(SelectionActions actions) {
  return [
    if (actions.cut != null && actions.canCut) (label: '剪切', callback: actions.cut!),
    if (actions.canCopy) (label: '复制', callback: actions.copy),
    if (actions.paste != null && actions.canPaste) (label: '粘贴', callback: actions.paste!),
    if (actions.canSelectAll) (label: '全选', callback: actions.selectAll),
  ];
}

/// iOS 棒棒糖句柄视觉（圆头 + 细杆；left 圆头在上、right 圆头在下）。
class _IosSelectionHandleVisual extends LeafRenderObjectWidget {
  const _IosSelectionHandleVisual({super.key, required this.color, required this.type, required this.size});

  final Color color;
  final TextSelectionHandleType type;
  final Size size;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderIosSelectionHandleVisual(color, type, size);
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderIosSelectionHandleVisual renderObject) {
    renderObject
      ..color = color
      ..type = type
      ..visualSize = size;
  }
}

class _RenderIosSelectionHandleVisual extends RenderBox {
  _RenderIosSelectionHandleVisual(this._color, this._type, this._visualSize);

  Color _color;
  TextSelectionHandleType _type;
  Size _visualSize;

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  set type(TextSelectionHandleType value) {
    if (_type == value) return;
    _type = value;
    markNeedsPaint();
  }

  set visualSize(Size value) {
    if (_visualSize == value) return;
    _visualSize = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(_visualSize);

  @override
  void performLayout() {
    size = constraints.constrain(_visualSize);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_type == TextSelectionHandleType.collapsed) return;
    final canvas = context.canvas;
    final paint = Paint()
      ..color = _color
      ..isAntiAlias = true;
    const radius = 6.0;
    const overlap = 1.5;
    final left = offset.dx + (size.width - radius * 2) / 2;
    if (_type == TextSelectionHandleType.left) {
      canvas.drawCircle(Offset(left + radius, offset.dy + radius), radius, paint);
      canvas.drawRect(
        Rect.fromLTRB(
          left + radius - 1.0,
          offset.dy + radius * 2 - overlap,
          left + radius + 1.0,
          offset.dy + size.height,
        ),
        paint,
      );
    } else {
      canvas.drawCircle(Offset(left + radius, offset.dy + size.height - radius), radius, paint);
      canvas.drawRect(
        Rect.fromLTRB(
          left + radius - 1.0,
          offset.dy,
          left + radius + 1.0,
          offset.dy + size.height - radius * 2 + overlap,
        ),
        paint,
      );
    }
  }
}
