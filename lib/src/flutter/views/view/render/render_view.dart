import 'dart:ui' as ui;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/foundation.dart' show ChangeNotifier, internal, visibleForTesting;
import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'
    show
        KeyEvent,
        MouseCursor,
        SystemMouseCursors,
        PointerEnterEventListener,
        PointerExitEventListener,
        MouseTrackerAnnotation;
import 'package:flutter/widgets.dart'
    show Brightness, Element, Widget, WidgetsBinding, WidgetsBindingObserver, InlineSpan, IconData;

import '../../../utils/internal/benchmark_probe.dart';
import '../../../utils/internal/bit_mask.dart';
import '../../../utils/internal/layout_reference.dart';
import '../../selection/common/selection_core.dart';
import '../event/dispatcher.dart';
import '../event/event.dart';
import '../semantics/render_semantics.dart';
import '../semantics/semantics.dart';
import '../semantics/semantics_frame.dart';
import '../style/animation/driver.dart';
import '../style/animation/field_animation.dart';
import '../style/animation/keyframe_runner.dart';
import '../style/cascade/resolver.dart';
import '../style/cascade/style_spec.dart';
import '../style/cascade/tick.dart';
import '../style/damage.dart';
import '../style/dimension.dart';
import '../style/inheritance/inheritable_node.dart';
import '../style/inheritance/subtree_walker.dart';
import '../style/internal/field_spec.dart';
import '../style/internal/responsive.dart';
import '../style/resolved/inherited_vars.dart';
import '../style/resolved/resolved_style.dart';
import '../style/state/vars_dependents.dart';
import '../style/state/view_state.dart';
import '../style/style.dart';
import '../text/text_engine.dart';
import '../view.dart';
import 'box_painter.dart';
import 'hit_bounds.dart';
import 'scroll_cursor_freeze.dart';

part 'box_insets.dart';
part '_intrinsics.dart';
part 'paint_controller.dart';

/// overlay 桥接与编辑器绘制继承共用的按需级联通知器。
@internal
class CascadeBridgeChanges extends ChangeNotifier {
  /// 发布源级联变化。
  @internal
  void publish() => notifyListeners();
}

class _ViewParentData extends ElTextParentData {}

/// ElView 的渲染对象 —— 盒模型 + 样式 cascade + 事件。
class ElRenderView extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ViewParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ViewParentData>,
        LayoutReferenceBox,
        ElOverflowHitBounds
    implements InheritableNode, MouseTrackerAnnotation, SelectionParticipantHost {
  /// 创建供**自定义 RenderObject 宿主**直接持有的节点（render 层正门）。
  ElRenderView({
    ElStyle? style,
    ElEvent? event,
    this._semantics,
    Object? child,
    TextContent? content,
    ElThemeMode? themeMode,
    ElBreakpoint? breakpoint,
    bool? inheritSize,
    TextScaler? textScaler,
    ui.Locale? locale,
  }) : _locale = locale,
       _localThemeMode = themeMode,
       _localBreakpoint = breakpoint,
       _selfSizeBasis = inheritSize == false,
       super() {
    _style = style;
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    _textScaler = textScaler ?? TextScaler.noScaling;
    _textScalerFallback = textScaler == null;
    _localeFallback = locale == null;
    // 禁用配置只来自事件；构造期写入样式状态位，首帧直接命中 onDisabled。
    _stateSet(ViewState.disabled, event?.disabled ?? false);
    _stateSet(ViewState.dark, themeMode?.brightness == Brightness.dark);
    if (event != null) {
      _ensureEventDispatcher().event = event;
      _ensureDispatcherIfNeededForVariants();
    } else if (_style != null) {
      final variantTrace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
      _ensureDispatcherIfNeededForVariants();
      if (variantTrace != null) MountTrace.ctorVariantScanUs += variantTrace.elapsedMicroseconds;
    }
    // 首次级联留到 attach：届时父级样式、暗色与断点已就绪，只需算一次。
    if (trace != null) MountTrace.ctorBodyUs += trace.elapsedMicroseconds;
    // Widget 门禁与富文本原子检查共用载荷入口；Element 会在挂载子内容前绑定宿主。
    if (child != null || content != null) setTextPayload(child, content: content);
  }

  // 级联快照与副作用由宿主持有，避免每个节点分配只作转发的 Engine/Host。
  // 动画、文本和绘制资源分别按需创建，不增加常规空盒的实例负担。

  ElStyle? _style;

  ResolvedStyle _committedResolved = ResolvedStyle.initial;

  ResolvedStyle _targetResolved = ResolvedStyle.initial;

  ResolvedStyle? _parentResolved;

  ElRenderView? _styleParent;
  Set<ElRenderView>? _styleChildren;

  // Portal 保留逻辑祖先，captureAll 保留主题；渲染继承直接沿这条父链传播，
  // 无需把已解析样式捕获成另一份声明，也不为普通节点创建订阅。
  InheritableNode? get _inheritedParent => _styleParent ?? _findAncestor<InheritableNode>();

  /// 绑定逻辑样式祖先；仅跨渲染树的节点登记额外继承关系。
  @internal
  void setStyleParent(ElRenderView? value) {
    if (identical(_styleParent, value)) return;
    _styleParent?._styleChildren?.remove(this);
    _styleParent = value;
    if (attached) _syncStyleParent();
  }

  void _syncStyleParent() {
    final source = _styleParent;
    if (source != null && !identical(source, _findAncestor<ElRenderView>())) {
      (source._styleChildren ??= {}).add(this);
    }
    _parentResolved = _inheritedParent?.committedResolvedStyle;
    _invalidateEffectiveThemeCascade();
    _invalidateEffectiveBreakpointCascade();
    _syncEffectiveDark(_localDark ?? _findAncestorEffectiveDark(), propagate: true);
    _syncResponsiveBits(_computeSelfResponsiveBits(), propagate: true);
    _reresolve();
  }

  /// 构造 + attach 期间 false（CSS：首次出现不过渡）；attach 末置 true，detach 置回 false。
  bool _transitionsEnabled = false;

  /// dark 切换进行中的强制过渡参数载体。
  ElThemeMode? _pendingDarkTransition;

  // 只保留当前输入，避免同一轮绘制与文本读取重复解析颜色。

  // --- 状态 -----------------------------------------------------------------

  /// 级联、事件与读取订阅共用的状态位，避免为每个节点另建包装对象。
  int _stateBits = 0;

  bool _stateHas(ViewState s) => (_stateBits & (1 << s.index)) != 0;

  void _stateSet(ViewState s, bool v) {
    final mask = 1 << s.index;
    _stateBits = v ? (_stateBits | mask) : (_stateBits & ~mask);
  }

  CustomClipper<Path>? _listenedClipper;
  Object? get _rawChild => _textPainterOrNull?.rawChild;

  TextScaler _textScaler = TextScaler.noScaling;
  ui.Locale? _locale;

  /// 尚未绑定 Element 时，由自定义 RenderObject 宿主直接持有。
  ///
  /// 只用于门禁：hosted 节点无 element，[setTextPayload] 收到 Widget 时 assert
  /// 报错而非静默丢弃。与环境兜底位独立——宿主显式传 textScaler 不该顺带关掉
  /// Widget 门禁，两件事不能共用一位。
  bool get _hosted => _ownerWidget == null;

  /// hosted（默认构造）未显式传 textScaler / locale 时为 true：对应 getter 从
  /// attach 所在 FlutterView 的 platformDispatcher 现取兜底（消费期读新值，
  /// 零依赖注册零挂载税）。
  /// 显式 setter 一经调用即永久关闭，转为宿主推送；element 路径恒 false。
  bool _textScalerFallback = false;
  bool _localeFallback = false;
  bool get _effectiveDark => _stateHas(ViewState.dark);

  ElThemeMode? _localThemeMode;
  ElThemeMode? _cachedEffectiveThemeMode;
  bool _effectiveThemeCacheDirty = true;

  ElBreakpoint? _localBreakpoint;
  ElBreakpoint? _cachedEffectiveBreakpoint;
  bool _effectiveBreakpointCacheDirty = true;

  /// 是否以自身宽度为响应式基准（`ElView(inheritSize: false)`）。true = 本节点
  /// 及后代按本节点 `_boxSize.width` 断档，直到更深的 selfSizeBasis 节点再次
  /// 接管；false = 继承祖先/窗口基准。
  late final bool _selfSizeBasis;

  /// `_selfSizeBasis` 节点 layout 尾钩 post-frame 单挂起守卫（防同帧重复挂）。
  bool _selfSizeBasisPostFrameScheduled = false;

  /// 级联变化通知器；只有 overlay 桥接或编辑器绘制消费者存在时才创建。
  CascadeBridgeChanges? _cascadeBridgeChanges;

  /// 订阅 committed 继承值、主题声明与断点声明变化。
  @internal
  CascadeBridgeChanges ensureCascadeBridgeChanges() => _cascadeBridgeChanges ??= CascadeBridgeChanges();

  /// 当前继承的文字色，供自绘子节点使用。
  Color? get currentColorForBuild => _committedResolved.inheritedText.color;

  /// ：首次 attach 标志。构造完成后初值 true；attach 里
  /// 首次触发时被置 false（无论是否走快路径都翻），确保 detach + re-attach
  /// （reparent）走祖先 resolved identity 的判定分支。
  bool _isFirstAttach = true;

  ViewStateSource? _stateSource;
  VarsBuildDependents? _varsBuildDeps;
  VarsBuildDependents? _themeBuildDeps;
  ElView? _ownerWidget;

  StyleAnimationDriver? _animDriver;

  /// `to:auto` 必须等新 child 与父约束进入真实 layout 后再测量；这里只记待测轴。
  FieldMask _pendingAutoLengthSnapshotMask = FieldMask.empty;

  /// driver 懒化 ensure：只在真正要启动过渡时才付这次分配。
  StyleAnimationDriver _ensureAnimDriver() {
    final existing = _animDriver;
    if (existing != null) return existing;
    assert(() {
      BenchmarkProbe.animDriverInstantiateCount++;
      return true;
    }());
    return _animDriver = StyleAnimationDriver(onTick: _onAnimTick, lengthSnapshotResolver: _resolveLengthSnapshot);
  }

  /// 只读查询空守卫：driver 未 alloc = 从未启动过动画 = 无活跃动画。
  bool get _hasActiveAnimations => _animDriver?.hasActiveAnimations ?? false;

  /// keyframe 动画运行时（CSS animations 通道，与 transition driver 并列）。
  /// 懒建：仅声明过 `ElStyle.animation` 的节点付这次分配。
  KeyframeRunner? _keyframeRunner;

  /// cascade 前对齐 keyframe 声明表，返回本轮的钉住掩码（0 = 无动画）。
  ///
  /// 门禁 [mayDeclareAnimationsOf] 让普通节点零成本；runner 已存在时即使
  /// 声明清空也要 sync（触发摘除回写）。
  FieldMask _syncKeyframeRunner() {
    var runner = _keyframeRunner;
    if (runner == null && !mayDeclareAnimationsOf(_style)) return FieldMask.empty;
    final anims = CascadeTick.effectiveAnimations(style: _style, state: _stateBits);
    if (runner == null) {
      if (anims.isEmpty) return FieldMask.empty;
      runner = _keyframeRunner = KeyframeRunner(onTick: _applyKeyframeSample);
    }
    runner.sync(anims);
    return runner.activeFieldsMask;
  }

  /// 采样当前关键帧覆盖值并 patch committed（runner 每帧回调；cascade 后也
  /// 同步调一次，避免「基值先落 committed、下一帧才被动画覆盖」的闪烁）。
  void _applyKeyframeSample() {
    final runner = _keyframeRunner;
    if (runner == null) return;
    if (!runner.hasClocks && runner.activeFieldsMask.isEmpty) return;
    final base = _targetResolved;
    final values = runner.sample(base);
    // CSS cascade：transition 层高于 animation 层——正在 transition 的字段
    // 让 driver 赢（keyframe 字段的 transition 已被 tick 钉住掩码抑制，此守卫
    // 只拦「动画声明出现前就在跑」的存量过渡）。
    if (_hasActiveAnimations) {
      values.removeWhere((field, _) => _animDriver!.animationOf(field) != null);
    }
    if (values.isEmpty) return;
    final (next, changedMask) = CascadeTick.writeFieldsFromAnimation(
      oldCommitted: _committedResolved,
      fieldValues: values,
    );
    if (changedMask.isEmpty) return;
    _commitResolved(next, changedMask);
  }

  // DamageRouter 为静态入口，无每节点实例。

  @override
  bool debugValidateChild(RenderObject child) => child is RenderBox;

  /// paint 编排协作体（backgroundImage 生命周期 + backdrop layer + paint 编排）。
  PaintController? _paintControllerOrNull;

  PaintController get _paintController => _paintControllerOrNull ??= PaintController(this);

  /// 自持文本协作体（engine / IFC / 选区 / overflow / inline 派发）。
  TextEngine? _textPainterOrNull;

  TextEngine get _textPainter => _textPainterOrNull!;

  TextEngine _ensureTextPainter() {
    final existing = _textPainterOrNull;
    if (existing != null) return existing;
    assert(() {
      BenchmarkProbe.textLayerInstantiateCount++;
      return true;
    }());
    return _textPainterOrNull = TextEngine()
      ..bindHost(
        host: this,
        nodeOf: () => _ownerWidget,
        lastHitCursorOf: () => _showsSelectableTextCursor && _lastHitIncludedTextContent,
      );
  }

  void _disposeTextPainter() {
    final painter = _textPainterOrNull;
    _textPainterOrNull = null;
    painter?.dispose();
  }

  bool? _systemBoldText;
  bool _effectiveBoldText = false;

  /// 设置继承根的系统粗体状态；null 表示继承最近的 ElRenderView。
  set systemBoldText(bool? value) {
    if (_systemBoldText == value) return;
    _systemBoldText = value;
    _inheritBoldText(_findAncestor<ElRenderView>()?._effectiveBoldText ?? false);
  }

  void _inheritBoldText(bool inherited) {
    final value = _systemBoldText ?? inherited;
    if (_effectiveBoldText == value) return;
    _effectiveBoldText = value;
    final painter = _textPainterOrNull;
    if (painter?.invalidateForBoldText() ?? false) {
      markNeedsLayout();
    }
    _visitNearestDescendants<ElRenderView>((child) => child._inheritBoldText(value));
  }

  /// 布局与绘制共用已提交样式；auto 终点探测可显式覆盖。
  TextPaintInput _textPaintInput({ResolvedStyle? resolvedOverride, Offset? contentOriginOverride}) {
    return (
      style: resolvedOverride ?? _committedResolved,
      // 经公开 getter：hosted 兜底（platformDispatcher 现取）在此生效
      textScaler: textScaler,
      locale: locale,
      boldText: _effectiveBoldText,
      contentOrigin: contentOriginOverride ?? _contentOrigin,
    );
  }

  // --- internal API（给 [PaintController] 等协作体反向访问 host 状态） -----

  /// 文本语言环境（字形选择用）。hosted 未显式传时从所挂 FlutterView 的
  /// platformDispatcher 现取兜底。
  ui.Locale? get locale {
    if (_localeFallback) {
      final view = _findAttachedFlutterView();
      if (view != null) return view.platformDispatcher.locale;
    }
    return _locale;
  }

  /// 语言环境推送通道（element / 宿主共用）：显式推送永久关闭 hosted 兜底，
  /// 变更失效文本字形并重排。
  set locale(ui.Locale? value) {
    // 同 textScaler：显式推送永久关闭兜底
    final fallbackWasOn = _localeFallback;
    _localeFallback = false;
    if (!fallbackWasOn && _locale == value) return;
    _locale = value;
    _textPainterOrNull?.invalidateLayout();
    markNeedsLayout();
  }

  /// 当前文本载荷原值（Widget 子在 element 层已归一为 null，恒非 Widget）。
  Object? get rawChild => _rawChild;

  /// 是否自持文本载荷（String / InlineSpan / 富文本）；false = 空盒或 widget 子。
  bool get hasTextPayload => _hasTextPayload;

  @override
  bool get effectiveDarkForInheritance => _effectiveDark;

  /// 本节点当前生效的响应式位（供后代继承）。
  @override
  int get responsiveBitsForInheritance => _stateBits & responsiveStateMask;

  /// 祖先响应式位下推：本节点若是自有基准直接截断，否则接收
  /// 并沿子树继续下推。
  @override
  bool inheritResponsiveFromAncestor(int bits) {
    if (_selfSizeBasis) return false;
    if (_localBreakpoint == null) {
      _syncResponsiveBits(bits, propagate: false);
      return true;
    }
    _syncResponsiveBits(_computeSelfResponsiveBits(), propagate: true);
    return false;
  }

  /// 内容区原点 = margin + padding 内缩，节点局部坐标（文本与单子摆位基准）。
  Offset get contentOrigin => _contentOrigin;

  RenderBox? get _singleWidgetChild => _hasWidgetPayload ? firstChild : null;

  /// margin 内侧真实视觉盒的起点。背景、边框、子内容命中都从这里开始。
  Offset get boxOrigin => _boxOrigin;

  /// margin 内侧真实视觉盒尺寸，不含 margin。
  Size get boxSize => _boxSize;

  bool get _hasTextPayload => _textPainterOrNull != null;

  /// widget 子存在判据：非文本载荷且有 render 子。不依赖 widget 实例 identity
  /// （`_rawChild` 只承载文本载荷，Widget 子在 element 层归一为 null——否则父级
  /// rebuild 的新实例会让 setTextPayload 误标 layout，见 T21 回退修复）。
  bool get _hasWidgetPayload => !_hasTextPayload && firstChild != null;

  /// dry 只查询几何；真实布局才写 child offset 和文本上下文。
  Size _layoutContent(
    BoxConstraints constraints,
    Offset contentOrigin, {
    ResolvedStyle? resolvedOverride,
    bool textWidthIsDefinite = false,
    bool dry = false,
  }) {
    final resolved = resolvedOverride ?? _committedResolved;
    if (_hasTextPayload) {
      final input = _textPaintInput(resolvedOverride: resolved, contentOriginOverride: contentOrigin);
      return dry
          ? _textPainter.computeDryMetrics(constraints, input, fillWidth: textWidthIsDefinite).size
          : _textPainter.layoutContent(constraints, input, fillWidth: textWidthIsDefinite);
    }
    final child = _singleWidgetChild;
    if (child == null) return Size.zero;
    final box = resolved.box;
    final alignment = box.alignment?.resolve(resolved.inheritedBox.direction ?? TextDirection.ltr);
    final childConstraints = alignment == null ? constraints : constraints.loosen();
    final Size childSize;
    if (dry) {
      childSize = child.getDryLayout(childConstraints);
    } else {
      child.layout(childConstraints, parentUsesSize: true);
      childSize = child.size;
    }
    var contentSize = childSize;
    if (alignment != null) {
      final widthFactor = box.width?.resolve(_availableWidthFor(constraints.maxWidth)) == null
          ? validStyleFactor(box.widthFactor)
          : null;
      final heightFactor = box.height?.resolve(_availableHeightFor(constraints.maxHeight)) == null
          ? validStyleFactor(box.heightFactor)
          : null;
      contentSize = Size(
        widthFactor == null && constraints.hasBoundedWidth ? constraints.maxWidth : childSize.width,
        heightFactor == null && constraints.hasBoundedHeight ? constraints.maxHeight : childSize.height,
      );
    }
    if (!dry) {
      final slack = Offset(contentSize.width - childSize.width, contentSize.height - childSize.height);
      (child.parentData! as BoxParentData).offset = contentOrigin + (alignment?.alongOffset(slack) ?? Offset.zero);
    }
    return alignment == null ? contentSize : constraints.constrain(contentSize);
  }

  /// 内容层绘制入口（paint 编排器调用）：文本自绘（含选区覆盖层）或子项直派。
  void paintContent(PaintingContext context, Offset offset) {
    if (_hasTextPayload) {
      final participant = _textPainter.selectionParticipant;
      final range = participant?.currentSelectionRange;
      _textPainter.paintContent(
        context,
        offset,
        _textPaintInput(),
        selection: range,
        selectionColor: range == null ? null : participant!.effectiveSelectionBgColor,
        selectionTextColor: range == null ? null : participant!.effectiveSelectionTextColor,
      );
      participant?.paintSelectionHandleLayers(context, offset);
      return;
    }
    defaultPaint(context, offset);
  }

  bool _hitTestContent(BoxHitTestResult result, Offset position) => _hasTextPayload
      ? _textPainter.hitTestContent(result, position)
      : defaultHitTestChildren(result, position: position);

  /// 事件分发器。仅当 [event] 非 null 或 [style] 含交互状态变体时 lazy 构造
  /// （零开销 fast path）。
  EventDispatcher? _eventDispatcher;
  Rect? _hoverEntryBounds;

  /// 最近一次 hitTest 是否命中文本字形（用于可选文本光标：padding/空白不显示 I-beam）。
  bool _lastHitIncludedTextContent = false;

  /// Element 层注入的点击聚焦入口。RenderObject 不持有 FocusNode。
  void Function(PointerDownEvent event, Offset localPosition)? requestFocusForEvent;

  bool _includeFocusSemantics = false;
  bool _focusableForSemantics = false;
  bool _focusedForSemantics = false;
  bool Function()? _focusedGetterForSemantics;
  ElSemantics? _semantics;

  int _debugLayoutCount = 0;

  // --- 公开 API ------------------------------------------------------------

  /// 当前样式。
  ElStyle? get style => _style;

  /// 样式推送通道（element updateRenderObject / 宿主共用）：identical 早退，
  /// 变更进 cascade diff，命中 transitions 的字段走补间。
  set style(ElStyle? value) {
    if (identical(_style, value)) return;
    _explicitInheritedMaskCache = null;
    if (_style == value) {
      _style = value;
      return;
    }
    final oldStyle = _style;
    _style = value;
    _ensureDispatcherIfNeededForVariants();
    // 失效变体清理：旧 style 有 onX 变体且 _state 持有对应 bit，新 style 没了
    // → 强清 bit。否则 cascade 用旧 state 值，新 style 一旦恢复变体会复用旧 hover
    // 残留。
    _clearStaleVariantStates(oldStyle, value);
    if (oldStyle?.userSelect != value?.userSelect) {
      _textPainterOrNull?.syncSelectionParticipation();
      reattachSelectionParticipantsInSubtree(this);
    }
    _reresolve();
    // onSelection 不进入 committed，声明更新也须通知直接消费样式的渲染宿主。
    _cascadeBridgeChanges?.publish();
  }

  /// 样式更新后清理已移除的悬停和按压变体状态，焦点状态由 Element 同步节点时维护。
  void _clearStaleVariantStates(ElStyle? oldStyle, ElStyle? newStyle) {
    // 焦点节点稍后由 Element 同步，保留旧焦点位才能在撤掉入口时送出失焦并清理键盘按压。
    final focusStates =
        (1 << ViewState.focus.index) | (1 << ViewState.focusVisible.index) | (1 << ViewState.focusWithin.index);
    final stale = variantStatesMaskOf(oldStyle) & ~variantStatesMaskOf(newStyle) & _interactionStateGate & ~focusStates;
    _stateBits &= ~stale;
  }

  /// 宿主文本是否发生截断/溢出：didExceedMaxLines（maxLines / ellipsis 截断）
  /// 或内容自然尺寸超出文本盒任一轴（单行不换行超宽等）。
  ///
  /// 对齐 DOM `scrollWidth > clientWidth` 的探测用途（`overflow: visible`
  /// 不裁剪也能测）；layout 末尾更新，post-layout 读取有效；无文本载荷恒
  /// false。「单元格截断才出 tooltip」类组件按此判定。
  bool get textOverflowing => _hasTextPayload && (_textPainterOrNull?.textOverflows ?? false);

  /// 文本引擎的无头测试诊断入口，读取本身不创建引擎。
  @visibleForTesting
  TextEngine? get textEngineForTest => _textPainterOrNull;

  /// 绘制控制器的无头测试诊断入口，读取本身不创建控制器。
  @visibleForTesting
  PaintController? get paintControllerForTest => _paintControllerOrNull;

  /// 当前 target style。
  ResolvedStyle get targetStyleForTest => _targetResolved;

  /// 是否有任何字段动画在跑（测试）。颜色过渡与其他字段同走 driver 通道
  /// （4b paint-lerp 已拆），本钩子对一切字段过渡有效。
  bool get hasActiveAnimationsForTest => _hasActiveAnimations;

  /// 测试观察：selected overlay 应该 paint 的 InlineSpan。
  @visibleForTesting
  InlineSpan? selectedTextOverlaySpanForTest() =>
      buildSelectionOverlaySpan(_textPainter.painterForTest.text!, textColor: selectionTextColor);

  /// Element 认领宿主，环境改由 Widget 持续推送。
  @internal
  void bindElementWidget(ElView widget) {
    _ownerWidget = widget;
    _textScalerFallback = false;
    _localeFallback = false;
  }

  /// 推送文本载荷并返回引擎，供 Element 复用结构编译产物。
  TextEngine? setTextPayload(Object? rawChild, {TextContent? content}) {
    assert(() {
      if (!_hosted) return true;
      if (rawChild is Widget) {
        throw FlutterError(
          'ElRenderView.setTextPayload 不接受 Widget（收到 ${rawChild.runtimeType}）。\n'
          'render 层无 element，Widget 无法充气成渲染物——传进来只会被静默丢弃。\n'
          '文本类载荷（String / num / InlineSpan / Iterable）直接传；要混排官方 '
          'widget 请把宿主改成 MultiChildRenderObjectWidget / Slotted，由 element 充气。',
        );
      }
      // 深检：只有 Iterable / InlineSpan 可能携带待充气原子。debug 期多 parse
      // 一次（产物即弃、无副作用），release 整段剥除。
      final produced =
          content ?? ((rawChild is InlineSpan || rawChild is Iterable) ? TextContent.parse(rawChild) : null);
      if (produced != null && produced.spans.isNotEmpty) {
        throw FlutterError(
          'render 宿主的富文本载荷里含 ${produced.spans.length} 个需要 element 充气的 '
          'widget 原子（Iterable 混排里的 widget 项 / InlineSpan 里的 WidgetSpan）。\n'
          'hosted 形态没有 element，这些原子洞位不会有 render 子，排版会在 TextPainter '
          '深处报洞数不匹配。\n'
          '纯文本 runs（String / 样式 TextSpan）可以照常混排；要内嵌 widget 请回 '
          'ElView(child: [...]) 由 element 充气。',
        );
      }
      return true;
    }());
    final normalizedRawChild = rawChild is Widget ? null : rawChild;
    final wasText = _hasTextPayload;
    final willBeText = normalizedRawChild != null;
    final rawChanged = !identical(_rawChild, normalizedRawChild);
    if (!rawChanged) return _textPainterOrNull;
    if (wasText && willBeText && sameViewTextPayload(_rawChild, normalizedRawChild)) {
      // 内容等价时只认领新引用，保留现有 span 和排版缓存。
      _textPainterOrNull?.setPayload(normalizedRawChild, content: content, contentEquivalent: true);
      return _textPainterOrNull;
    }
    if (wasText != willBeText) _disposeTextPainter();
    if (willBeText) _ensureTextPainter().setPayload(normalizedRawChild, content: content);
    // 首次载荷由 setPayload 同步选区，清空由 dispose 清理，避免重复查找祖先。
    markNeedsLayout();
    markNeedsSemanticsUpdate();
    return _textPainterOrNull;
  }

  /// 文本缩放。hosted 未显式传时从所挂 FlutterView 的 platformDispatcher
  /// 现取兜底；element 路径恒读字段。
  TextScaler get textScaler {
    if (_textScalerFallback) {
      if (_rawChild is IconData) return TextScaler.noScaling;
      final factor = _findAttachedFlutterView()?.platformDispatcher.textScaleFactor;
      if (factor != null) return factor == 1.0 ? TextScaler.noScaling : TextScaler.linear(factor);
    }
    return _textScaler;
  }

  /// 缩放推送通道：显式推送永久关闭 hosted 兜底（关闭即语义变化，不吃值相等早退）。
  set textScaler(TextScaler value) {
    // 显式推送永久关闭兜底；关闭本身即取值语义变化，不得被值相等早退跳过
    final fallbackWasOn = _textScalerFallback;
    _textScalerFallback = false;
    if (!fallbackWasOn && _textScaler == value) return;
    _textScaler = value;
    _textPainterOrNull?.invalidateLayout();
    markNeedsLayout();
  }

  ui.FlutterView? _findAttachedFlutterView() => _findAncestor<RenderView>()?.flutterView;

  /// 本节点显式明暗覆盖（themeMode.brightness）；null = 随祖先 effective。
  Brightness? get brightness => _localThemeMode?.brightness;

  /// 本节点声明的 ElThemeMode（未合并祖先）。
  ElThemeMode? get themeMode => _localThemeMode;

  /// 主题声明推送通道；brightness / duration / curve 沿子树逐项继承合并，
  /// dark 翻转按统一过渡切换。
  set themeMode(ElThemeMode? value) {
    final oldLocal = _localThemeMode;
    if (identical(oldLocal, value) || oldLocal == value) return;
    _localThemeMode = value;
    _cascadeBridgeChanges?.publish();
    // duration/curve 变化都可能改变后代的 effective 值 → 沿子树清 cache。
    // brightness 变化沿原通道下推 dark，时长与曲线仍逐项继承。
    _invalidateEffectiveThemeCascade();
    if (oldLocal?.brightness != value?.brightness) {
      _syncEffectiveDark(_localDark ?? _findAncestorEffectiveDark(), propagate: true);
    }
  }

  /// 惰性合并的 effective theme。
  ElThemeMode? get effectiveThemeMode {
    if (!_effectiveThemeCacheDirty) return _cachedEffectiveThemeMode;
    final ancestor = (_styleParent ?? _findAncestor<ElRenderView>())?.effectiveThemeMode;
    final local = _localThemeMode;
    _cachedEffectiveThemeMode = local != null && ancestor != null ? local.mergeAncestor(ancestor) : local ?? ancestor;
    _effectiveThemeCacheDirty = false;
    return _cachedEffectiveThemeMode;
  }

  void _notifyThemeBuildDependents() {
    _themeBuildDeps?.notifyCommit({ElThemeMode: resolvedThemeMode});
  }

  /// dark 统一过渡 effective duration（无声明兜底 200ms）。
  Duration get _effectiveThemeDuration => effectiveThemeMode?.duration ?? ElThemeMode.defaultDuration;

  /// dark 统一过渡 effective curve（无声明兜底 linear）。
  Curve get _effectiveThemeCurve => effectiveThemeMode?.curve ?? ElThemeMode.defaultCurve;

  /// 本节点声明的 [ElBreakpoint]（未合并祖先）。
  ElBreakpoint? get breakpoint => _localBreakpoint;

  /// 响应式断点覆盖推送；变更重算响应位并按需下推子树。
  set breakpoint(ElBreakpoint? value) {
    final oldLocal = _localBreakpoint;
    if (identical(oldLocal, value) || oldLocal == value) return;
    _localBreakpoint = value;
    _cascadeBridgeChanges?.publish();
    _invalidateEffectiveBreakpointCascade();
    if (!attached) return;
    // 声明变化 → 本节点若是基准持有者（暗根或 selfSizeBasis）按新断点重算位；
    // 子节点若命中同类也重算。简化口径：本节点重算 + propagate（透明子递归下推
    // 到下一个 InheritableNode，selfSizeBasis 后代自己收敛）。
    _syncResponsiveBits(_computeSelfResponsiveBits(), propagate: true);
  }

  /// 惰性合并的 effective breakpoint。
  ElBreakpoint? get effectiveBreakpoint {
    if (!_effectiveBreakpointCacheDirty) return _cachedEffectiveBreakpoint;
    final ancestor = (_styleParent ?? _findAncestor<ElRenderView>())?.effectiveBreakpoint;
    final local = _localBreakpoint;
    _cachedEffectiveBreakpoint = local != null && ancestor != null ? local.mergeAncestor(ancestor) : local ?? ancestor;
    _effectiveBreakpointCacheDirty = false;
    return _cachedEffectiveBreakpoint;
  }

  /// 清本节点及所有后代的 effective breakpoint 缓存。
  void _invalidateEffectiveBreakpointCascade() {
    if (_effectiveBreakpointCacheDirty) return;
    _effectiveBreakpointCacheDirty = true;
    _cachedEffectiveBreakpoint = null;
    SubtreeWalker.walk(this, (child) {
      if (child is ElRenderView) {
        if (child._effectiveBreakpointCacheDirty) return false;
        child._effectiveBreakpointCacheDirty = true;
        child._cachedEffectiveBreakpoint = null;
        child._cascadeBridgeChanges?.publish();
      }
      return true;
    });
  }

  /// 本节点当前应写入 `_state` 的响应式位。
  int _computeSelfResponsiveBits({InheritableNode? ancestorNode}) {
    if (_selfSizeBasis) {
      return computeResponsiveBits(_boxSize.width, effectiveBreakpoint);
    }
    if (_localBreakpoint != null) {
      final width = _WindowMetricsObserver.instance.windowWidth();
      return computeResponsiveBits(width, effectiveBreakpoint);
    }
    // attach 已爬过一次链时直接复用其结果，其余入口（窗口回调等）自爬。
    final ancestor = (ancestorNode ?? _inheritedParent)?.responsiveBitsForInheritance;
    if (ancestor != null) return ancestor;
    // 无祖先 → 暗根类节点，读窗口宽。
    final width = _WindowMetricsObserver.instance.windowWidth();
    return computeResponsiveBits(width, effectiveBreakpoint);
  }

  /// 查找最近的指定祖先，环境继承与依赖通知共用同一条父链遍历。
  T? _findAncestor<T>() {
    var p = parent;
    while (p != null) {
      if (p is T) return p as T;
      p = p.parent;
    }
    return null;
  }

  /// 穿过普通 Render 节点，找到最近的目标后代后停止下钻。
  void _visitNearestDescendants<T>(void Function(T) visitor) {
    void visit(RenderObject child) {
      if (child is ElRenderView && child._styleParent != null && !identical(child._styleParent, this)) return;
      if (child is T) {
        visitor(child as T);
      } else {
        child.visitChildren(visit);
      }
    }

    visitChildren(visit);
    for (final child in _styleChildren?.toList(growable: false) ?? const <ElRenderView>[]) {
      if (child.attached && child is T) visitor(child as T);
    }
  }

  /// 把新响应式位写入 `_state`，声明了响应式变体才 reresolve，
  /// 需要 propagate 时下推子树。
  void _syncResponsiveBits(int newBits, {required bool propagate}) {
    final responsive = newBits & responsiveStateMask;
    if ((_stateBits & responsiveStateMask) != responsive) {
      _stateBits = (_stateBits & ~responsiveStateMask) | responsive;
      _publishState();
      if ((variantStatesMaskOf(_style) & responsiveStateMask) != 0) _reresolve();
    }
    if (propagate) SubtreeWalker.walk(this, (child) => child.inheritResponsiveFromAncestor(responsive));
  }

  /// 清本节点及所有后代的 effective theme 缓存。
  void _invalidateEffectiveThemeCascade() {
    if (_effectiveThemeCacheDirty) return;
    _effectiveThemeCacheDirty = true;
    _cachedEffectiveThemeMode = null;
    _notifyThemeBuildDependents();
    // 沿子树推平 —— 复用 SubtreeWalker。
    SubtreeWalker.walk(this, (child) {
      if (child is ElRenderView) {
        if (child._effectiveThemeCacheDirty) return false; // 早退，止于已 dirty 节点。
        child._effectiveThemeCacheDirty = true;
        child._cachedEffectiveThemeMode = null;
        child._cascadeBridgeChanges?.publish();
        child._notifyThemeBuildDependents();
      }
      return true;
    });
  }

  /// 首次订阅时创建状态源并同步当前状态位；
  /// 构造函数期做的三件事）。挂 hook 必须在 add/removeListener 之前——hook 就
  /// 是 add/remove 到"从无到有 / 从有到无"临界点触发；不挂就漏 dispatcher 联动。
  ViewStateSource _ensureStateSource() {
    final existing = _stateSource;
    if (existing != null) return existing;
    assert(() {
      BenchmarkProbe.stateSourceInstantiateCount++;
      return true;
    }());
    final source = ViewStateSource();
    source.onListenerPresenceChanged = _ensureDispatcherIfNeededForVariants;
    source.updateNodeStateBits(_stateBits);
    _stateSource = source;
    return source;
  }

  /// layout 次数（测试用：锁定 paint-only 字段不触发 layout）。
  int get debugLayoutCount => _debugLayoutCount;

  // --- event 接入 ----------------------------------------------------------

  /// 当前事件配置。
  ElEvent? get event => _eventDispatcher?.event;

  /// 事件配置推送（element / 宿主共用）：非 null 懒建 dispatcher 并绑定；
  /// 置 null 后可经 [releaseEventDispatcherIfUnused] 回收。
  set event(ElEvent? value) {
    final current = _eventDispatcher?.event;
    if (identical(current, value)) return;
    if (value == null) {
      if (_needsDispatcherForVariants()) {
        _ensureEventDispatcher().event = null;
      } else if (_eventDispatcher != null) {
        _disposeEventDispatcher();
      }
      _syncDisabledState(false);
      return;
    }
    // 同构闭包换值零失效；光标和禁用变化由 dispatcher 调度鼠标刷新。
    // 事件配置不影响 layer 结构与合成需求（合成位由
    // backdropFilter/filter 单独承担），内联 ElEvent 每次 rebuild 新实例
    // 走到这里不该付脏位上溯。dispatcher 从无到有由 [_ensureEventDispatcher]
    // 统一补 paint 失效。
    _ensureEventDispatcher().event = value;
    _syncDisabledState(event?.disabled ?? false);
  }

  /// 当前语义配置。
  ElSemantics? get semantics => _semantics;

  /// 语义配置推送，变更标 semantics 脏。
  set semantics(ElSemantics? value) {
    if (_semantics == value) return;
    _semantics = value;
    markNeedsSemanticsUpdate();
  }

  /// lazy 构造 dispatcher 并把 pointer 状态桥到样式状态。
  EventDispatcher _ensureEventDispatcher() {
    final existing = _eventDispatcher;
    if (existing != null) return existing;
    final d = EventDispatcher(this);
    d.onTapChanged = setTap;
    d.localPositionResolver = _resolveEventLocalPosition;
    d.hitBoundsContainsGlobal = _tapBoundsContainsGlobal;
    _eventDispatcher = d;
    _markPaintForDispatcherPresenceChange();
    return d;
  }

  /// dispatcher 从无到有 / 从有到无的临界点重绘一帧：[validForMouseTracker] /
  /// [cursor] 判据随 dispatcher 存废翻转，MouseTracker 只在帧后重估指针状态，
  /// 需要一次 markNeedsPaint 调度（对齐 RenderMouseRegion 口径）。事件配置
  /// 本身不影响 layer 结构，不做合成位失效。
  void _markPaintForDispatcherPresenceChange() {
    markNeedsPaint();
  }

  /// 边界口径 tap 判定用：全局坐标是否落在本节点的视觉盒内。
  bool _tapBoundsContainsGlobal(Offset globalPosition) {
    if (!hasSize) return true;
    // globalToLocal 只走到**父寻址空间**（祖先链的 applyPaintTransform 不含本
    // 节点自身的 transform）。未变换口径直接用它比 _boxRect；变换后口径要补
    // 一次自身反变换，与 hitTest 里 addWithPaintTransform 的落点对齐。
    final parentSpace = globalToLocal(globalPosition);
    if (_tapBoundsContainsLocal(parentSpace)) return true;
    final transform = _effectivePaintTransform();
    if (transform == null) return false;
    final inverted = Matrix4.tryInvert(transform);
    // 矩阵退化（scale 0 等）：画不出来也无从判定，按"在范围内"放行，
    // 宁可不熄按压态也不误杀点击。
    if (inverted == null) return true;
    return _tapBoundsContainsLocal(MatrixUtils.transformPoint(inverted, parentSpace));
  }

  bool _tapBoundsContainsLocal(Offset local) {
    if (!_boxRect.contains(local)) return false;
    final clipper = _committedResolved.box.clipPath;
    if (clipper != null) return clipper.getClip(_boxSize).contains(local - _boxOrigin);
    return _containsClipRRectForHitTest(local);
  }

  Offset _resolveEventLocalPosition(RenderBox target, Offset globalPosition, ElEventDetails? callback) {
    if (target is ElRenderView) {
      if ((callback?.phase == ElEventPhase.focus || callback?.phase == ElEventPhase.blur) && callback != null) {
        return callback.localPosition + target._contentOrigin;
      }
      return target.eventLocalPositionFromGlobal(globalPosition);
    }
    return target.globalToLocal(globalPosition);
  }

  /// 从 Element 层转发聚焦节点收到的键盘事件。
  ElEventDetails? dispatchKeyEvent(KeyEvent event) => _ensureEventDispatcher().notifyKeyEvent(event);

  /// Element 层请求点击聚焦前写入本次 pointer 全局坐标。
  void rememberFocusEventPosition(Offset globalPosition, Offset localPosition) {
    _ensureEventDispatcher().rememberFocusPosition(globalPosition, localPosition);
  }

  Offset _focusLocalPositionForPointer() {
    final box = _committedResolved.box;
    final width = ElDimension.parse(box.width)?.resolve(_boxSize.width);
    final height = ElDimension.parse(box.height)?.resolve(_boxSize.height);
    if (width != null && height != null) {
      return Offset(width / 2, height / 2);
    }
    return _boxSize.center(Offset.zero);
  }

  /// ElEvent 使用内容盒坐标作为 localPosition，和样式声明的 width/height 对齐。
  Offset eventLocalPositionFromGlobal(Offset globalPosition) {
    return globalToLocal(globalPosition) - _contentOrigin;
  }

  /// 同步焦点语义配置。
  void setFocusSemantics({
    required bool includeSemantics,
    required bool focusable,
    bool focused = false,
    bool Function()? focusedGetter,
  }) {
    final focusedForSemantics = focusable && focused;
    final focusedGetterChanged = (_focusedGetterForSemantics == null) != (focusedGetter == null);
    if (_includeFocusSemantics == includeSemantics &&
        _focusableForSemantics == focusable &&
        _focusedForSemantics == focusedForSemantics &&
        !focusedGetterChanged) {
      return;
    }
    _includeFocusSemantics = includeSemantics;
    _focusableForSemantics = focusable;
    _focusedForSemantics = focusedForSemantics;
    _focusedGetterForSemantics = focusedGetter;
    markNeedsSemanticsUpdate();
  }

  /// 仅当 [style] 含需要分发器维护的状态变体时构造（即使无 event）。
  void _ensureDispatcherIfNeededForVariants() {
    if (!_needsDispatcherForVariants()) {
      if (_eventDispatcher?.event == null) {
        if (_eventDispatcher != null) _disposeEventDispatcher();
        return;
      }
    }
    final dispatcher = _ensureEventDispatcher();
    dispatcher.enableLongPressedState = false;
    dispatcher.enableDraggedState = false;
    dispatcher.syncRecognizersForStateVariants();
  }

  /// 需要 dispatcher 的状态：tap 来自按压反馈，focus 系列沿 dispatcher 父链通知。
  /// hover 由 MouseTracker 的进出回调直接维护，纯悬停节点不创建 dispatcher。
  static final int _dispatcherStateGate =
      (1 << ViewState.tap.index) |
      (1 << ViewState.focus.index) |
      (1 << ViewState.focusVisible.index) |
      (1 << ViewState.focusWithin.index);

  /// 由交互维护的状态；disabled 与 dark 分别由事件配置和主题维护。
  static final int _interactionStateGate = _dispatcherStateGate | (1 << ViewState.hover.index);

  /// 是否有状态变体或订阅需要 dispatcher 接收 pointer/focus 信号。
  bool _needsDispatcherForVariants() {
    if (_hasTapStateListener) return true;
    return (variantStatesMaskOf(_style) & _dispatcherStateGate) != 0;
  }

  /// event 与状态变体都不再需要 dispatcher 时释放之，回到零开销快路径。
  void releaseEventDispatcherIfUnused() {
    final dispatcher = _eventDispatcher;
    if (dispatcher == null || dispatcher.event != null || _needsDispatcherForVariants()) return;
    _disposeEventDispatcher();
  }

  void _disposeEventDispatcher() {
    _eventDispatcher!.dispose();
    _eventDispatcher = null;
    _markPaintForDispatcherPresenceChange();
  }

  bool get _hasHoverStateListener => _stateSource?.hasListenerFor(ViewState.hover) ?? false;

  bool get _hasTapStateListener => _stateSource?.hasListenerFor(ViewState.tap) ?? false;

  // --- 状态变体 setter -----------------------------------------------------

  /// 设置 hover 状态。
  void setHover(bool v) => _setVisualState(ViewState.hover, v);

  /// 设置 tap 按压状态。
  void setTap(bool v) => _setVisualState(ViewState.tap, v);

  void _setVisualState(ViewState state, bool value) {
    if (_stateHas(state) == value) return;
    // 在发布前保存入口，监听者同步命中查询也能避免 hover 位移抖动。
    if (state == ViewState.hover) _hoverEntryBounds = value ? _boxRect : null;
    _stateSet(state, value);
    _publishState();
    _reresolve();
  }

  /// 设置 dark 状态。
  void setDark(bool v) {
    _syncEffectiveDark(v, propagate: true);
  }

  void _syncEffectiveDark(bool value, {required bool propagate}) {
    if (_effectiveDark == value) return;
    if (_transitionsEnabled) _pendingDarkTransition = effectiveThemeMode;
    _stateSet(ViewState.dark, value);
    _publishState();
    _notifyThemeBuildDependents();
    if (propagate) _propagateDarkChange();
    // 顶层与嵌套声明使用同一份元数据，避免漏掉 onDisabled(onDark: ...) 等链。
    if ((variantStatesMaskOf(_style) & (1 << ViewState.dark.index)) != 0 || _hasActiveAnimations) {
      _reresolve();
    }
    if (_transitionsEnabled && !_pendingDarkClearScheduled) {
      _pendingDarkClearScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pendingDarkClearScheduled = false;
        _pendingDarkTransition = null;
      });
    }
  }

  /// 同帧 Widget 重建也使用主题过渡，绘制结束后再清理。
  bool _pendingDarkClearScheduled = false;

  /// 设置自身主焦点状态。由 Element 层 FocusNode listener 驱动。
  ///
  /// [focusVisible]：本次聚焦是否为"应显示焦点指示"的形态（CSS
  /// `:focus-visible`）——Element 按所属 View 的导航输入状态同步；输入方式
  /// 改变时可在同一持焦节点上更新，失焦随 focus 位一起清零。
  void setFocus(
    bool v, {
    ElFocusReason reason = ElFocusReason.programmatic,
    Offset? globalPosition,
    Offset? localPosition,
    bool focusVisible = false,
  }) {
    final visible = v && focusVisible;
    final stateChanged = _stateHas(ViewState.focus) != v;
    final visibleChanged = _stateHas(ViewState.focusVisible) != visible;
    final semanticsChanged = _focusedForSemantics != v;
    if (!stateChanged && !visibleChanged) {
      if (_includeFocusSemantics && semanticsChanged) {
        _focusedForSemantics = v;
        markNeedsSemanticsUpdate();
      }
      return;
    }
    if (stateChanged) _stateSet(ViewState.focus, v);
    if (visibleChanged) _stateSet(ViewState.focusVisible, visible);
    _publishState();
    _reresolve();
    if (stateChanged) {
      _eventDispatcher?.notifyFocusChanged(
        v,
        reason: reason,
        globalPosition: globalPosition,
        localPosition: localPosition,
      );
    }
    if (_includeFocusSemantics) {
      _focusedForSemantics = v;
      markNeedsSemanticsUpdate();
    }
  }

  /// 设置自身或后代拥有焦点状态。仅驱动视觉变体。
  void setFocusWithin(bool v) => _setVisualState(ViewState.focusWithin, v);

  // --- 事件禁用状态与样式级联同步 -------------------------------------------

  /// 是否禁用，直接读取 [ElEvent.disabled]。
  bool get disabled => event?.disabled ?? false;

  void _syncDisabledState(bool value) {
    if (_stateHas(ViewState.disabled) == value) return;
    _stateSet(ViewState.disabled, value);
    // 禁用同时结束按压与瞬时状态，解除后不能恢复旧 hover/tap。
    if (value) {
      _eventDispatcher?.cancelAllPendingAtLastPosition();
      // 进入禁用：丢弃 pointer 驱动的瞬时交互态，避免解除禁用后残留旧 hover/tap
      // （这些状态后续不会再被 onEnter/onExit/dispatcher 清除——已被门禁）。
      _stateSet(ViewState.hover, false);
      _stateSet(ViewState.tap, false);
    }
    _publishState();
    // disabled 翻转可能顺带清 hover/tap（上方门禁分支）；
    // XOR 取**实际**翻转位（过渡通道按位反推旧值，混入未翻转位会解错）。
    // 先于 _reresolve：pending flip 由它消费。
    _reresolve();
    // 即使没有视觉变体，禁用边界变化也要让静止鼠标在帧后重新命中。
    markNeedsPaint();
  }

  // --- Cascade tick --------------------------------------------------------

  bool _isDisposing = false;

  void _reresolve({FieldMask inheritedThemeAnimationMask = FieldMask.empty}) {
    if (_isDisposing) return;
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    // reduced-motion（系统禁用动画）：不再启动新过渡，存量动画立即收敛到
    // target（cancelAll 后 tick diff 直写新值）。
    final reducedMotion = elDisableAnimations;
    if (reducedMotion && _hasActiveAnimations) _animDriver!.cancelAll();
    // driver 只在「闸门已开 且（声明了 transitions / dark 强制过渡 / 已有活跃
    // 动画）」时 ensure —— 裸行与无过渡声明的节点永不分配。
    final driver =
        _transitionsEnabled &&
            !reducedMotion &&
            (mayDeclareTransitionsOf(_style) || _pendingDarkTransition != null || _hasActiveAnimations)
        ? _ensureAnimDriver()
        : null;
    // keyframe 声明对齐（cascade 前：钉住掩码要参与本轮 tick）。
    final keyframeMask = _syncKeyframeRunner();
    final result = CascadeTick.tick(
      style: _style,
      parent: _parentResolved,
      oldCommitted: _committedResolved,
      state: _stateBits,
      driver: driver,
      forceTransitionDuration: _pendingDarkTransition != null ? _effectiveThemeDuration : null,
      forceTransitionCurve: _pendingDarkTransition != null ? _effectiveThemeCurve : null,
      inheritedThemeAnimationMask: inheritedThemeAnimationMask,
      keyframeAnimationMask: keyframeMask,
      hostHasInheritanceConsumers: firstChild != null || _rawChild != null,
    );
    _targetResolved = result.newTarget;
    _commitResolved(result.newCommitted, result.changedMask, themeAnimationMask: inheritedThemeAnimationMask);
    // 同步施加当前关键帧采样：committed 不带着裸基值过帧（mount 即首帧生效）。
    if (keyframeMask.isNotEmpty) _applyKeyframeSample();
    if (trace != null) MountTrace.reresolveUs += trace.elapsedMicroseconds;
  }

  void _onAnimTick() {
    final driver = _animDriver!;
    final fieldValues = <ElTransitionField, Object?>{};
    var themeAnimationMask = FieldMask.empty;
    for (final field in driver.activeFields) {
      final anim = driver.animationOf(field);
      if (anim == null) continue;
      fieldValues[field] = anim.currentValue();
      if (anim.isThemeMode) {
        themeAnimationMask = maskSetBit(themeAnimationMask, field.index);
      }
    }
    if (fieldValues.isEmpty) return;
    final (next, changedMask) = CascadeTick.writeFieldsFromAnimation(
      oldCommitted: _committedResolved,
      fieldValues: fieldValues,
    );
    if (changedMask.isEmpty) return;
    _commitResolved(next, changedMask, themeAnimationMask: themeAnimationMask);
  }

  void _commitResolved(ResolvedStyle value, FieldMask changedMask, {FieldMask themeAnimationMask = FieldMask.empty}) {
    if (!identical(_committedResolved, value)) {
      final oldCommitted = _committedResolved;
      final oldInheritedText = oldCommitted.inheritedText;
      final oldInheritedBox = oldCommitted.inheritedBox;
      final oldVars = oldCommitted.inheritedVars;
      _committedResolved = value;
      _syncCompositedOpacity(oldCommitted, value);
      // cursor 只继承、不改变像素；静止鼠标仍需在下一帧读取新的样式光标。
      if (oldInheritedBox.cursor != value.inheritedBox.cursor) owner?.requestVisualUpdate();
      if (!identical(oldInheritedText, value.inheritedText) ||
          !identical(oldInheritedBox, value.inheritedBox) ||
          !identical(oldVars, value.inheritedVars)) {
        _cascadeBridgeChanges?.publish();
      }
      if (!identical(oldVars, value.inheritedVars)) {
        if (oldVars != value.inheritedVars) {
          visitInheritableChildren((child) => child.reresolveVarsFromInheritance(value));
        }
        _varsBuildDeps?.notifyCommit(value.inheritedVars.map);
      }
      if (!identical(oldInheritedText, value.inheritedText) && _hasTextPayload) {
        if (maskAnd(changedMask, textLayoutAffectingMask).isEmpty) {
          _textPainter.invalidatePaint();
        } else {
          _textPainter.invalidateLayout();
          markNeedsLayout();
        }
      }
      if (_hasTextPayload && oldInheritedBox.direction != value.inheritedBox.direction) {
        markNeedsSemanticsUpdate();
      }
      _listenToClipper(attached ? _committedResolved.box.clipPath : null);
    }
    _markCompositingBitsIfBackdropChanged(changedMask);
    DamageRouter.route(
      host: this,
      changedMask: changedMask,
      inheritableHost: this,
      themeAnimationMask: themeAnimationMask,
    );
  }

  void _listenToClipper(CustomClipper<Path>? next) {
    if (identical(_listenedClipper, next)) return;
    _listenedClipper?.removeListener(_handleClipperReclip);
    _listenedClipper = next;
    _listenedClipper?.addListener(_handleClipperReclip);
  }

  void _handleClipperReclip() {
    markNeedsPaint();
    _notifySelectionVisualGeometryChanged();
  }

  /// backdropFilter 会创建 `BackdropFilterLayer`、filter 会创建
  /// `ImageFilterLayer`，开关变化时需要刷新合成位。
  void _markCompositingBitsIfBackdropChanged(FieldMask changedMask) {
    if (maskHas(changedMask, ElTransitionField.transform.index) ||
        maskHas(changedMask, ElTransitionField.transformOrigin.index) ||
        maskHas(changedMask, ElTransitionField.clipPath.index) ||
        maskHas(changedMask, ElTransitionField.clipBehavior.index)) {
      _notifySelectionVisualGeometryChanged();
    }
    if (maskHas(changedMask, ElTransitionField.backdropFilter.index) ||
        maskHas(changedMask, ElTransitionField.filter.index)) {
      markNeedsCompositingBitsUpdate();
    }
  }

  void _notifySelectionVisualGeometryChanged() {
    _findAncestor<SelectionVisualGeometryDependency>()?.descendantSelectionVisualGeometryChanged(this);
    _visitNearestDescendants<SelectionVisualGeometryDependency>(
      (child) => child.descendantSelectionVisualGeometryChanged(this),
    );
  }

  // --- InheritableNode -----------------------------------------------------

  @override
  ResolvedStyle get committedResolvedStyle => _committedResolved;

  /// 样式声明变化时失效，传播全程只使用这一份显式字段位图。
  FieldMask? _explicitInheritedMaskCache;

  @override
  FieldMask get explicitlySetMask => _explicitInheritedMaskCache ??= StyleResolver.explicitInheritedMask(_style);

  @override
  void visitInheritableChildren(void Function(InheritableNode child) visitor) => _visitNearestDescendants(visitor);

  /// 沿用旧变量继承通道，从新父表重建并在有效值相等时截断传播。
  @override
  void reresolveVarsFromInheritance(ResolvedStyle? newParentResolved) {
    if (!attached) return;
    if (!identical(_parentResolved, newParentResolved)) {
      _parentResolved = newParentResolved;
    }
    if (hasVariantVarsOf(_style)) {
      _reresolve();
      return;
    }
    final parentVars = newParentResolved?.inheritedVars ?? InheritedVars.empty;
    final newVars = parentVars.merge(_style?.vars);
    final oldVars = _committedResolved.inheritedVars;
    if (identical(newVars, oldVars) || newVars == oldVars) return;
    final target = _targetResolved;
    final committed = _committedResolved;
    if (identical(target, committed)) {
      final next = committed.copyWith(inheritedVars: newVars);
      _targetResolved = next;
      _commitResolved(next, FieldMask.empty);
    } else {
      _targetResolved = target.copyWith(inheritedVars: newVars);
      _commitResolved(committed.copyWith(inheritedVars: newVars), FieldMask.empty);
    }
  }

  @override
  FieldMask reresolveFromInheritance(
    ResolvedStyle? newParentResolved,
    FieldMask changedMask, {
    FieldMask inheritedThemeAnimationMask = FieldMask.empty,
  }) {
    final continuedThemeAnimationMask = inheritedThemeAnimationMask.isEmpty
        ? FieldMask.empty
        : maskAndNot(inheritedThemeAnimationMask, activeVariantDeclaredMask(_style, _stateBits));
    if (!identical(_parentResolved, newParentResolved)) {
      _parentResolved = newParentResolved;
    }
    _reresolve(inheritedThemeAnimationMask: continuedThemeAnimationMask);
    return continuedThemeAnimationMask;
  }

  @override
  bool inheritDarkFromAncestor(bool dark) {
    if (_localThemeMode?.brightness != null) return false;
    _syncEffectiveDark(dark, propagate: false);
    return true;
  }

  // --- Single child --------------------------------------------------------

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _ViewParentData) {
      child.parentData = _ViewParentData();
    }
  }

  // --- Layout --------------------------------------------------------------

  // ===========================================================================
  // Intrinsic sizes —— RenderBox API 接到内容区 computeIntrinsicSizes
  // ===========================================================================
  //
  // Flutter `RenderBox` 默认实现返回 0；不 override 的话 `IntrinsicWidth` /
  // `IntrinsicHeight` widget 拿不到正确尺寸。这里把 4 个 API 接到 FC：
  //
  // - inline_fc / mixed_fc 委托 Skia ICU LineBreaker（TextPainter.min/maxIntrinsicWidth）
  //   —— 精度与 Chrome 一致，不是简化
  // - single_block FC 转发给唯一 child 取 max
  //
  // 显式 width/height 覆盖 intrinsic（CSS 标准：声明优先）。
  // intrinsic 对外暴露 RenderBox size，需包含 margin；width/height 动画的
  // used-size snapshot 仍只返回真实视觉盒尺寸，不包含 margin。

  @override
  double computeMinIntrinsicWidth(double height) => _measureIntrinsic(height, width: true, isMin: true);

  @override
  double computeMaxIntrinsicWidth(double height) => _measureIntrinsic(height, width: true, isMin: false);

  @override
  double computeMinIntrinsicHeight(double width) => _measureIntrinsic(width, width: false, isMin: true);

  @override
  double computeMaxIntrinsicHeight(double width) => _measureIntrinsic(width, width: false, isMin: false);

  /// 将 width / height 的 auto 端点冻结为真实 used-size，供 transition 连续插值。
  double? _resolveLengthSnapshot(ElTransitionField field) {
    if (!attached || !hasSize) return null;
    if (field != ElTransitionField.width && field != ElTransitionField.height) return null;
    final spec = fieldSpecOf(field);
    if (spec.read(_committedResolved) == null) {
      return field == ElTransitionField.width ? _boxSize.width : _boxSize.height;
    }
    // explicit → auto 的终点依赖更新后的 child、目标样式与父约束。style setter
    // 发生在 child update 之前，此处只登记；同帧真实 layout 会一次性测出终点。
    _pendingAutoLengthSnapshotMask = maskSetBit(_pendingAutoLengthSnapshotMask, field.index);
    markNeedsLayout();
    return null;
  }

  /// 在真实 layout 中用最终 target 样式和已更新 child 补齐 `to:auto` 快照。
  void _resolvePendingAutoLengthSnapshots(_BoxLayout committed) {
    final pending = _pendingAutoLengthSnapshotMask;
    if (pending.isEmpty) return;
    _pendingAutoLengthSnapshotMask = FieldMask.empty;

    final driver = _animDriver;
    if (driver == null) return;
    final widthAnimation = maskHas(pending, ElTransitionField.width.index)
        ? driver.animationOf(ElTransitionField.width)
        : null;
    final heightAnimation = maskHas(pending, ElTransitionField.height.index)
        ? driver.animationOf(ElTransitionField.height)
        : null;
    final needsWidth = widthAnimation != null && widthAnimation.to == null && _targetResolved.box.width == null;
    final needsHeight = heightAnimation != null && heightAnimation.to == null && _targetResolved.box.height == null;
    if (!needsWidth && !needsHeight) return;

    // 两轴同时 auto 只做一次真实子树测量；随后正式 layout 会按动画当前值再排
    // 一次，故目标测量产生的 child offset/size 不会泄漏到本帧输出。
    final autoSize = _layoutBoxSizeForResolved(_targetResolved, committed);
    if (needsWidth) {
      driver.resolveDeferredLengthSnapshot(ElTransitionField.width, autoSize.width);
    }
    if (needsHeight) {
      driver.resolveDeferredLengthSnapshot(ElTransitionField.height, autoSize.height);
    }
  }

  _BoxLayout _prepareLayout(ResolvedStyle resolved, BoxConstraints constraints) => _BoxLayout.resolve(
    resolved,
    constraints,
    availableWidth: _availableWidthFor,
    availableHeight: _availableHeightFor,
  );

  void _applyLayoutReference(double? width, double? height, {bool notify = true}) {
    if (setLayoutReference(width, height) && notify) markSubtreeNeedsLayoutForReference();
  }

  /// auto 终点必须测量真实子树；临时参照和富文本上下文在测量后恢复。
  Size _layoutBoxSizeForResolved(ResolvedStyle resolved, _BoxLayout committed) {
    final metrics = _prepareLayout(resolved, constraints);
    _applyLayoutReference(metrics.referenceWidth, metrics.referenceHeight);
    try {
      final content = _layoutContent(
        metrics.inner,
        metrics.contentOrigin,
        resolvedOverride: resolved,
        textWidthIsDefinite: metrics.used.hasTightWidth,
      );
      return metrics.resolveSize(content);
    } finally {
      _applyLayoutReference(committed.referenceWidth, committed.referenceHeight);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final metrics = _prepareLayout(_committedResolved, constraints);
    final content = _layoutContent(
      metrics.inner,
      metrics.contentOrigin,
      textWidthIsDefinite: metrics.used.hasTightWidth,
      dry: true,
    );
    return constraints.constrain(metrics.addMargin(metrics.resolveSize(content)));
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final metrics = _prepareLayout(_committedResolved, constraints);
    final content = _layoutContent(
      metrics.inner,
      metrics.contentOrigin,
      textWidthIsDefinite: metrics.used.hasTightWidth,
      dry: true,
    );
    final box = metrics.resolveSize(content);
    final contentSize = Size(
      (box.width - metrics.padding.horizontal).clamp(0.0, double.infinity),
      (box.height - metrics.padding.vertical).clamp(0.0, double.infinity),
    );
    if (_hasTextPayload) {
      final text = _textPainter.computeDryMetrics(
        metrics.inner,
        _textPaintInput(contentOriginOverride: metrics.contentOrigin),
        baseline: baseline,
        fillWidth: metrics.used.hasTightWidth,
      );
      final alignment = _committedResolved.box.alignment
          ?.resolve(_committedResolved.inheritedBox.direction ?? TextDirection.ltr)
          .alongOffset(Offset(contentSize.width - text.size.width, contentSize.height - text.size.height));
      return metrics.contentOrigin.dy + (alignment?.dy ?? 0) + text.baseline;
    }
    final child = _singleWidgetChild;
    if (child == null) return null;
    final alignment = _committedResolved.box.alignment?.resolve(
      _committedResolved.inheritedBox.direction ?? TextDirection.ltr,
    );
    final childConstraints = alignment == null ? metrics.inner : metrics.inner.loosen();
    final childBaseline = child.getDryBaseline(childConstraints, baseline);
    if (childBaseline == null) return null;
    final childSize = child.getDryLayout(childConstraints);
    final offset = alignment?.alongOffset(
      Offset(contentSize.width - childSize.width, contentSize.height - childSize.height),
    );
    return metrics.contentOrigin.dy + (offset?.dy ?? 0) + childBaseline;
  }

  @override
  void performLayout() {
    _debugLayoutCount++;
    assert(() {
      BenchmarkProbe.performLayoutCount++;
      return true;
    }());
    markHitBoundsDirty();
    final metrics = _prepareLayout(_committedResolved, constraints);
    if (_pendingAutoLengthSnapshotMask.isNotEmpty) _resolvePendingAutoLengthSnapshots(metrics);
    _boxOrigin = metrics.margin.topLeft;
    _contentOrigin = metrics.contentOrigin;
    _applyLayoutReference(metrics.referenceWidth, metrics.referenceHeight, notify: hasSize);
    final content = _layoutContent(metrics.inner, _contentOrigin, textWidthIsDefinite: metrics.used.hasTightWidth);
    _boxSize = metrics.resolveSize(content);
    final contentWidth = (_boxSize.width - metrics.padding.horizontal).clamp(0.0, double.infinity);
    final contentHeight = (_boxSize.height - metrics.padding.vertical).clamp(0.0, double.infinity);
    // min/max 和 factor 会改变最终内容区，必须按最终尺寸重新对齐。
    final alignment = _committedResolved.box.alignment;
    final child = _singleWidgetChild;
    if (alignment != null && child != null && child.hasSize) {
      final slack = Offset(contentWidth - child.size.width, contentHeight - child.size.height);
      (child.parentData! as BoxParentData).offset =
          _contentOrigin +
          alignment.resolve(_committedResolved.inheritedBox.direction ?? TextDirection.ltr).alongOffset(slack);
    }
    if (_hasTextPayload) {
      _textPainter.repositionAlignedText(_textPaintInput(), contentW: contentWidth, contentH: contentHeight);
    }
    size = constraints.constrain(metrics.addMargin(_boxSize));
    selectionParticipant?.updateSelectionGeometry();
    _maybeScheduleSelfSizeBasisRecompute();
    final frame = firstChild;
    if (frame is RenderViewSemanticsFrame) {
      final data = frame.parentData! as BoxParentData;
      frame.updateGeometry(_boxSize, data.offset - _boxOrigin);
      data.offset = _boxOrigin;
    }
  }

  /// layout 尾钩：`_selfSizeBasis` 节点 layout 之后按新 boxSize
  /// 重算响应式位；不等则延一帧同步（不得在 layout 中同步 reresolve，否则
  /// markNeedsLayout 会重入本 layout）。这是容器查询与布局环切割的标准取舍
  /// （CSS container queries 同款约束）。
  void _maybeScheduleSelfSizeBasisRecompute() {
    if (!_selfSizeBasis) return;
    if (_selfSizeBasisPostFrameScheduled) return;
    final targetBits = computeResponsiveBits(_boxSize.width, effectiveBreakpoint);
    if ((_stateBits & responsiveStateMask) == (targetBits & responsiveStateMask)) return;
    _selfSizeBasisPostFrameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _selfSizeBasisPostFrameScheduled = false;
      if (!attached) return;
      final now = computeResponsiveBits(_boxSize.width, effectiveBreakpoint);
      if ((_stateBits & responsiveStateMask) == (now & responsiveStateMask)) return;
      _syncResponsiveBits(now, propagate: true);
    });
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (_hasTextPayload) {
      return _textPainter.computeDistanceToActualBaseline(baseline);
    }
    final c = _singleWidgetChild;
    if (c == null || !c.hasSize) return null;
    final childBaseline = c.getDistanceToActualBaseline(baseline);
    if (childBaseline == null) return null;
    final pd = c.parentData;
    final childOffset = pd is BoxParentData ? pd.offset.dy : _contentOrigin.dy;
    return childOffset + childBaseline;
  }

  /// 无界 boxMaxW 时爬 [LayoutReferenceBox] 链取参照供百分比 resolve；有界
  /// 直接透传。返回 ∞ → resolve 折回 null → 上游按 auto 兜底，行为不变。
  ///
  /// 爬链只在该轴无界时发生（有界短路），单次 O(树深)、一帧至多两回
  /// （resolve + resolveNodeSize），不做缓存。
  double _availableWidthFor(double boxMaxW) =>
      boxMaxW.isFinite ? boxMaxW : (LayoutReferenceBox.ancestorReferenceWidth(this) ?? double.infinity);

  double _availableHeightFor(double boxMaxH) =>
      boxMaxH.isFinite ? boxMaxH : (LayoutReferenceBox.ancestorReferenceHeight(this) ?? double.infinity);

  /// 视觉盒相对包含 margin 的节点原点。
  Offset _boxOrigin = Offset.zero;

  /// 真实视觉盒尺寸，不含 margin。
  Size _boxSize = Size.zero;

  Rect get _boxRect => _boxOrigin & _boxSize;

  /// 内容区在节点 (0,0) 坐标系中的起点 = margin + padding（border 仅绘制不占位）。
  /// paint / hit-test 都要相对它偏移子内容。
  Offset _contentOrigin = Offset.zero;

  // --- selection（转发 TextEngine 内的 binder；本类不实例化）-------------

  @override
  SelectionParticipant? get selectionParticipant => _textPainterOrNull?.selectionParticipant;

  SelectionRegistrar? _selectionRegistrar;

  /// 文本参与者使用 Widget 作用域提供的官方注册中心。
  SelectionRegistrar? get selectionRegistrar => _selectionRegistrar;

  set selectionRegistrar(SelectionRegistrar? value) {
    if (identical(_selectionRegistrar, value)) return;
    _selectionRegistrar = value;
    selectionParticipant?.bindSelectionRegistrar(value);
  }

  /// onSelection 伪类提取的宿主侧 memo（惰性：仅接入选区 paint 的文本节点分配）。
  OnSelectionPaintMemo? _onSelectionPaintMemo;

  /// 文本宿主的 onSelection 伪类提取（memo 化）。
  ///
  /// 选区 paint 期经 participant 的 `selectionPaintOf` 回调读取：声明取自
  /// **declared** [_style]（onSelection 独立于普通级联，不进 committed），
  /// 激活链跟随 [_stateBits]，颜色直接来自样式声明。
  OnSelectionPaint _resolveOnSelectionPaint() {
    final memo = _onSelectionPaintMemo ??= OnSelectionPaintMemo();
    return memo.resolve(_style, stateBits: _stateBits);
  }

  /// 包内编辑器读取最近样式宿主的选区外观，不注册 Widget 依赖。
  @internal
  OnSelectionPaint get inheritedSelectionPaint => _resolveOnSelectionPaint();

  // 测试与少量调用点仍经 RenderView 读选区状态（转发 binder）。
  /// 选区委托：可选文本长度（无参与者恒 0）。
  int get selectionTextLength => selectionParticipant?.selectionTextLength ?? 0;

  /// 选区委托：高亮底色（onSelection 有效色；无参与者用内置兜底色）。
  Color get selectionColor => selectionParticipant?.effectiveSelectionBgColor ?? const Color(0x553B82F6);

  /// 选区委托：选中文字前景色（onSelection 有效色；null = 不改字色）。
  Color? get selectionTextColor => selectionParticipant?.effectiveSelectionTextColor;

  /// 选区委托：当前选中范围（无选区 null）。
  TextRange? get currentSelectionRange => selectionParticipant?.currentSelectionRange;

  /// 选区委托：是否处于启用选区的 root 之下。
  bool get hasEnabledSelectionRoot => selectionParticipant?.hasEnabledSelectionRoot ?? false;

  /// 选区委托：选区命中扩展范围（null = 按内容盒）。
  Rect? get selectionHitTestBounds => selectionParticipant?.selectionHitTestBounds;

  /// 选区委托：局部坐标是否落在当前选区内。
  bool selectionContainsLocalPosition(Offset localPosition) =>
      selectionParticipant?.selectionContainsLocalPosition(localPosition) ?? false;

  /// 选区委托：局部坐标映射到文本 offset。
  int selectionOffsetForLocalPosition(Offset localPosition) =>
      selectionParticipant?.selectionOffsetForLocalPosition(localPosition) ?? 0;

  /// 选区委托：offset 处的词边界（双击选词用）。
  TextRange selectionWordBoundaryAt(int offset) =>
      selectionParticipant?.selectionWordBoundaryAt(offset) ?? TextRange.collapsed(offset);

  /// 选区委托：offset 处 caret 几何。
  SelectionCaretGeometry? selectionCaretGeometryAt(int offset) =>
      selectionParticipant?.selectionCaretGeometryAt(offset);

  /// 选区委托：offset 所在行几何。
  SelectionLineGeometry? selectionLineGeometryAt(int offset) => selectionParticipant?.selectionLineGeometryAt(offset);

  // --- Paint ---------------------------------------------------------------

  /// 当前节点是否需要合成层。
  ///
  /// `backdropFilter` 必须进入 `BackdropFilterLayer`（默认裁剪也要以 clip
  /// layer 包住该合成层）、`filter` 必须进入 `ImageFilterLayer`；这里把合成
  /// 需求暴露给 Flutter pipeline，避免祖先裁剪或本节点裁剪在 layer / canvas
  /// 路径之间出现不一致。
  @override
  bool get alwaysNeedsCompositing =>
      (selectionParticipant?.hasSelectionHandleLayers ?? false) ||
      _usesCompositedOpacity ||
      _committedResolved.box.backdropFilter != null ||
      _committedResolved.box.filter != null;

  /// 普通半透明盒使用标准 OpacityLayer，避免 canvas saveLayer 继承祖先的大裁剪区。
  bool get _usesCompositedOpacity => _shouldCompositeOpacity(_committedResolved);

  bool _shouldCompositeOpacity(ResolvedStyle resolved) {
    final box = resolved.box;
    if (box.filter != null || box.backdropFilter != null) return false;
    final alpha = ViewBoxPainter.opacityAlpha(resolved.box.opacity);
    return alpha > 0 && alpha < 255;
  }

  void _syncCompositedOpacity(ResolvedStyle oldResolved, ResolvedStyle newResolved) {
    final oldComposited = _shouldCompositeOpacity(oldResolved);
    final newComposited = _shouldCompositeOpacity(newResolved);
    if (oldComposited != newComposited) {
      markNeedsCompositingBitsUpdate();
      return;
    }
    if (newComposited &&
        ViewBoxPainter.opacityAlpha(oldResolved.box.opacity) != ViewBoxPainter.opacityAlpha(newResolved.box.opacity)) {
      markNeedsCompositedLayerUpdate();
    }
  }

  @override
  bool get isRepaintBoundary => _usesCompositedOpacity;

  @override
  OffsetLayer updateCompositedLayer({required covariant OpacityLayer? oldLayer}) {
    final layer = oldLayer ?? OpacityLayer();
    // 复杂树里半透明 → 不透明的合成位回收可能比 paint 晚一拍；旧层必须
    // 原实例复用到框架摘除，过渡帧置 255 可避免重复透明且保持视觉等价。
    layer.alpha = _usesCompositedOpacity ? ViewBoxPainter.opacityAlpha(_committedResolved.box.opacity) : 255;
    return layer;
  }

  /// 测试观察：当前普通半透明盒持有的复合层；非该形态时为 null。
  @visibleForTesting
  OpacityLayer? get compositedOpacityLayerForTest => layer is OpacityLayer ? layer! as OpacityLayer : null;

  /// 当前盒是否依赖已绘制的下层内容作为 backdrop filter 采样来源。
  bool get usesBackdropFilter => _committedResolved.box.backdropFilter != null;

  /// 零绘制 op 直通缓存键：该 box 已判定为「无任何盒装饰 op」。
  ///
  /// 键 = 最终解析 box 的 identity（与 [PaintController] 内部 op 位缓存同一
  /// 不变量：identity 变 ⇔ 值变）。仅在控制器**尚未分配**时使用——虚拟滚动
  /// 的纯文本 / 裸容器行走此路径，整个生命周期不为 paint 编排付一次分配。
  Box? _zeroPaintOpsFor;

  @override
  void paint(PaintingContext context, Offset offset) {
    final pc = _paintControllerOrNull;
    if (pc != null) {
      pc.paint(context, offset);
      return;
    }
    // 控制器未分配：先零成本判定零 op（identical 命中即直通），只有真出现
    // 盒装饰 op 才落地 PaintController。资源正确性不受影响——backgroundImage /
    // backdrop layer 等跨 frame 资源只可能在控制器存在后产生。
    final box = committedResolvedStyle.box;
    if (identical(box, _zeroPaintOpsFor)) {
      paintContent(context, offset);
      return;
    }
    if (PaintController.classifyPaintOps(box) == 0) {
      _zeroPaintOpsFor = box;
      paintContent(context, offset);
      return;
    }
    _zeroPaintOpsFor = null;
    _paintController.paint(context, offset);
  }

  /// 当前节点自身的 paint transform。
  ///
  /// paint / hit-test / applyPaintTransform 必须共用同一套矩阵，避免视觉位置、
  /// 事件坐标和 global/local 坐标链出现分裂。
  Matrix4? _effectivePaintTransform() =>
      ViewBoxPainter.resolveEffectiveTransform(offset: _boxOrigin, size: _boxSize, resolved: _committedResolved);

  // --- Hit test ------------------------------------------------------------

  // --- 溢出命中边界协议（ElOverflowHitBounds，plan: hit-test-overflow-bounds） --

  @override
  Rect get selfHitRect => _boxRect;

  @override
  bool get clipsHitBounds {
    if (_hasTextPayload && _textPainter.overflowNeedsClipping) return true;
    final box = _committedResolved.box;
    if (box.clipPath != null) return true;
    final clip = box.clipBehavior;
    return clip != null && clip != Clip.none;
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    final box = _committedResolved.box;
    final clipper = box.clipPath;
    final outer = _boxOrigin & _boxSize;
    if (clipper != null) return clipper.getApproximateClipRect(_boxSize).shift(_boxOrigin);
    final clip = box.clipBehavior;
    if (clip == null || clip == Clip.none) return null;
    final radius = ViewBoxPainter.effectiveBorderRadius(
      box,
      textDirection: _committedResolved.inheritedBox.direction ?? TextDirection.ltr,
    );
    return ViewBoxPainter.resolveContentRRect(outer, radius).outerRect;
  }

  @override
  Matrix4? get hitBoundsTransform => _effectivePaintTransform();

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    final origin = _hasTextPayload ? _textPainter.textPaintOrigin : Offset.zero;
    visitChildren((child) {
      if (child is! RenderBox) return;
      final pd = child.parentData;
      if (pd is ElTextParentData && (!pd.visible || pd.scale == 0)) return;
      final local = pd is BoxParentData ? pd.offset : Offset.zero;
      visitor(child, origin + local);
    });
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // 拖拽指针锁：整树吞命中 + 锁光标（见 [DragPointerLock] 类注）；进行
    // 中的拖拽走 down 捕获路由投递，不经过本分支。
    if (DragPointerLock.blocksHitTesting) {
      result.add(HitTestEntry(dragPointerLockBarrier));
      return true;
    }
    final opacity = (_committedResolved.box.opacity as num?)?.toDouble();
    if (opacity != null && opacity <= 0) return false;

    return result.addWithPaintTransform(
      transform: _effectivePaintTransform(),
      position: position,
      hitTest: (result, transformed) {
        final inside = _containsForHitTest(transformed);
        if (inside) {
          // 裁剪判断先于子命中；clipper 优先于圆角。
          final clipper = _committedResolved.box.clipPath;
          if (clipper != null) {
            if (!clipper.getClip(_boxSize).contains(transformed - _boxOrigin)) return false;
          } else if (!_containsClipRRectForHitTest(transformed)) {
            return false;
          }
        } else if (!hitBoundsContains(transformed)) {
          return false;
        }
        final hitContent = _hitTestChildrenGated(result, transformed);
        if (_hasTextPayload) _lastHitIncludedTextContent = hitContent;
        // 半透明空白只加入路径，不阻断背后兄弟；盒外仍仅由溢出后代命中。
        final hitTarget = hitContent || (inside && hitTestSelf(transformed));
        final translucent = inside && !_pointerEventsNone && event?.behavior == HitTestBehavior.translucent;
        if (hitTarget || translucent) result.add(BoxHitTestEntry(this, transformed));
        return hitTarget;
      },
    );
  }

  /// 本节点解析后的 `pointer-events` 是否为 [ElPointerEvents.none]。
  ///
  /// 继承值经 cascade 落进 committed（未声明跟随最近 El 祖先），hitTest 期
  /// 实时读取——无需任何 damage 通道，变化帧结束后 MouseTracker 重命中即生效。
  bool get _pointerEventsNone => _committedResolved.inheritedBox.pointerEvents == ElPointerEvents.none;

  /// 本节点生效的 CSS pointer-events 是否为 none。框架内部消费点：overlay
  /// 弹层的面板命中面据此判断内容根是否声明指针透明（拖拽 ghost 等），
  /// 声明透明的面板不做命中不透明、照常穿透。
  bool get pointerEventsNone => _pointerEventsNone;

  /// 子树命中入口（禁用与 `pointer-events` 闸门）。
  bool _hitTestChildrenGated(BoxHitTestResult result, Offset position) {
    // 禁用表面不命中内容，避免文本 / 独立子控件抢光标或继续认领指针。
    if (disabled) return false;
    if (!_pointerEventsNone) return hitTestChildren(result, position: position);
    final probe = BoxHitTestResult();
    if (!hitTestChildren(probe, position: position)) return false;
    var reEnabled = false;
    for (final entry in probe.path) {
      final target = entry.target;
      if (target is ElRenderView && !target._pointerEventsNone) {
        reEnabled = true;
        break;
      }
    }
    if (!reEnabled) return false;
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) {
    // pointer-events: none —— 自身（背景 / 事件 / 焦点点击入口）对指针透明。
    if (_pointerEventsNone) return false;
    if (!_containsForHitTest(position)) return false;
    // 禁用按钮会移除事件配置，仍须保留整个表面的命中以免点击穿透。
    if (disabled) return true;
    // 显式命中行为优先；纯交互样式宿主仍按默认不透明行为参与命中。
    if (_eventDispatcher != null) return (event?.behavior ?? HitTestBehavior.opaque) == HitTestBehavior.opaque;
    // 纯悬停宿主不创建 dispatcher，命中口径与其他交互样式保持一致。
    if (_hasHoverVariant || _hasHoverStateListener) return true;
    // 有焦点入口时，即使没有事件或视觉内容，也应允许点击聚焦。
    if (requestFocusForEvent != null) return true;
    // 有视觉内容：bgColor 参与命中
    if (_committedResolved.box.backgroundColor != null) return true;
    return false;
  }

  bool _containsForHitTest(Offset position) {
    if (_boxRect.contains(position)) return true;
    // hover 入口区特判**与溢出命中边界协议并存，不可被其替代**：hover 位移
    // （onHover transform）后指针可能落在腾空的原盒区——那里已无视觉内容，
    // 协议按"画得出才点得到"不会覆盖；不保留原盒命中会形成
    // enter → 位移 → exit → 回位 → enter 的抖动环。
    final hoverEntryBounds = _hoverEntryBounds;
    return hoverEntryBounds != null &&
        _stateHas(ViewState.hover) &&
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.postFrameCallbacks &&
        hoverEntryBounds.contains(position);
  }

  bool _containsClipRRectForHitTest(Offset position) {
    final box = _committedResolved.box;
    final clip = box.clipBehavior;
    if (clip == null || clip == Clip.none) return true;
    final outer = _boxOrigin & _boxSize;
    final radius = ViewBoxPainter.effectiveBorderRadius(
      box,
      textDirection: _committedResolved.inheritedBox.direction ?? TextDirection.ltr,
    );
    if (radius == null || radius == BorderRadius.zero) return true;
    final contentRRect = ViewBoxPainter.resolveContentRRect(outer, radius);
    return contentRRect.contains(position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return _hitTestContent(result, position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final effectiveTransform = _effectivePaintTransform();
    if (effectiveTransform != null) {
      transform.multiply(effectiveTransform);
    }
    final data = child.parentData! as BoxParentData;
    var dx = data.offset.dx;
    var dy = data.offset.dy;
    if (_hasTextPayload) {
      dx += _textPainter.textPaintOrigin.dx;
      dy += _textPainter.textPaintOrigin.dy;
    }
    transform.translateByDouble(dx, dy, 0.0, 1.0);
    if (_hasTextPayload) {
      final scale = (data as ElTextParentData).scale;
      transform.scaleByDouble(scale, scale, 1, 1);
    }
  }

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    super.handleEvent(event, entry);
    if (disabled) return;
    if (event is PointerDownEvent) {
      _eventDispatcher?.rememberPointerPosition(event, entry);
      _eventDispatcher?.handleEvent(event, entry);
      requestFocusForEvent?.call(event, _focusLocalPositionForPointer());
      return;
    }
    _eventDispatcher?.handleEvent(event, entry);
  }

  // --- MouseTrackerAnnotation 接口 -----------------------------------------

  bool get _hasUserPointerEnter => _eventDispatcher?.event?.onPointerEnter != null;

  bool get _hasUserPointerExit => _eventDispatcher?.event?.onPointerExit != null;

  bool get _hasHoverVariant => (variantStatesMaskOf(_style) & (1 << ViewState.hover.index)) != 0;

  bool _needsPointerBoundary(bool entering) =>
      (entering ? _hasUserPointerEnter : _hasUserPointerExit) || _hasHoverVariant || _hasHoverStateListener;

  @override
  PointerEnterEventListener? get onEnter => _needsPointerBoundary(true) ? _handlePointerBoundary : null;

  @override
  PointerExitEventListener? get onExit => _needsPointerBoundary(false) ? _handlePointerBoundary : null;

  void _handlePointerBoundary(PointerEvent event) {
    if (disabled) return;
    if (event is PointerEnterEvent && _hasUserPointerEnter) {
      _eventDispatcher!.handlePointerEnter(event);
    } else if (event is PointerExitEvent && _hasUserPointerExit) {
      _eventDispatcher!.handlePointerExit(event);
    }
    if (_hasHoverVariant || _hasHoverStateListener) setHover(event is PointerEnterEvent);
  }

  @override
  MouseCursor get cursor {
    if (ScrollCursorFreeze.contains(this)) return MouseCursor.defer;
    if (disabled) return SystemMouseCursors.forbidden;
    // inline span 的 `mouseCursor` 由 `MouseTracker` 直接消费 —— 命中的
    // `TextSpan` 本身是 `MouseTrackerAnnotation` 且在命中路径里排在本 render
    // 之前（cursor first-in-path-wins），不需要本 getter 再转一手。
    final inheritedCursor = _committedResolved.inheritedBox.cursor;
    if (inheritedCursor != null) return inheritedCursor;
    final eventCursor = event?.cursor;
    if (eventCursor != null) return eventCursor;
    // 仅字形命中时出 I-beam；padding / bg 空白保持 defer（由下层决定 basic）。
    if (_showsSelectableTextCursor && _lastHitIncludedTextContent) {
      return SystemMouseCursors.text;
    }
    return MouseCursor.defer;
  }

  bool get _showsSelectableTextCursor =>
      hasEnabledSelectionRoot && _hasTextPayload && _style?.userSelect != ElUserSelect.none && selectionTextLength > 0;

  @override
  bool get validForMouseTracker =>
      attached &&
      (onEnter != null ||
          onExit != null ||
          ((disabled || event?.cursor != null) && !ScrollCursorFreeze.contains(this)));

  /// 容器捕获可见盒；外边距用于排布，不能扩大该区域的语义窗口。
  @override
  Rect get semanticBounds => _semantics?.container == true && hasSize ? _boxRect : super.semanticBounds;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (firstChild is RenderViewSemanticsFrame) return;
    describeContainerSemantics(config);
  }

  /// 内部容器坐标宿主复用本视图的语义、动作与焦点配置。
  @internal
  void describeContainerSemantics(SemanticsConfiguration config) {
    // exclude 时不贡献自身文本语义（与 children 一起整体排除）。
    final excluded = shouldExcludeViewSemanticsChildren(_semantics);
    final textLabel = excluded ? null : (_hasTextPayload ? _textPainter.semanticsTextLabel : null);
    applyViewSemanticsConfiguration(
      config,
      semantics: _semantics,
      textLabel: textLabel,
      textDirection: textLabel == null ? null : _committedResolved.inheritedBox.direction ?? TextDirection.ltr,
      includeFocusSemantics: _includeFocusSemantics,
      focusableForSemantics: _focusableForSemantics,
      focusedForSemantics: _focusedGetterForSemantics?.call() ?? _focusedForSemantics,
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (shouldExcludeViewSemanticsChildren(_semantics)) return;
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void markNeedsSemanticsUpdate() {
    super.markNeedsSemanticsUpdate();
    final frame = firstChild;
    if (frame is RenderViewSemanticsFrame) frame.markNeedsSemanticsUpdate();
  }

  @override
  SemanticsNode? get debugSemantics {
    final frame = firstChild;
    return frame is RenderViewSemanticsFrame ? frame.debugSemantics : super.debugSemantics;
  }

  // --- Lifecycle -----------------------------------------------------------

  @override
  void attach(PipelineOwner owner) {
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    final firstAttach = _isFirstAttach;
    super.attach(owner);
    _eventDispatcher?.attach();
    _invalidateEffectiveThemeCascade();
    final source = _styleParent;
    if (source != null && !identical(source, _findAncestor<ElRenderView>())) {
      (source._styleChildren ??= {}).add(this);
    }
    final ancestorNode = _inheritedParent;
    _inheritBoldText(
      (ancestorNode is ElRenderView ? ancestorNode : _findAncestor<ElRenderView>())?._effectiveBoldText ?? false,
    );
    final ancestorResolved = ancestorNode?.committedResolvedStyle;
    _parentResolved = ancestorResolved;
    _isFirstAttach = false;
    // 首挂时 Widget 子内容尚未插入。已有后代的自定义宿主保留原来的继承提交顺序。
    final resolveMountOnce = firstAttach && firstChild == null && (_styleChildren?.isEmpty ?? true);
    // 重挂时重建动画时钟并回落目标值，不能保留摘树前的过渡采样。
    if (!resolveMountOnce) _reresolve();
    final dark = _localDark ?? ancestorNode?.effectiveDarkForInheritance ?? false;
    if (!resolveMountOnce) _syncEffectiveDark(dark, propagate: true);
    _invalidateEffectiveBreakpointCascade();
    // 判定"响应式根"：本节点 `_selfSizeBasis` 或链上无 InheritableNode 祖先
    // （暗根类）——注册进窗口观察者。
    final isResponsiveRoot = _selfSizeBasis || ancestorNode == null;
    if (isResponsiveRoot) _WindowMetricsObserver.instance.register(this);
    final responsiveBits = _computeSelfResponsiveBits(ancestorNode: ancestorNode);
    if (resolveMountOnce) {
      final oldBits = _stateBits;
      final darkChanged = _effectiveDark != dark;
      _stateSet(ViewState.dark, dark);
      _stateBits = (_stateBits & ~responsiveStateMask) | (responsiveBits & responsiveStateMask);
      if (oldBits != _stateBits) _publishState();
      if (darkChanged) _notifyThemeBuildDependents();
      _reresolve();
    } else {
      _syncResponsiveBits(responsiveBits, propagate: false);
    }
    _listenToClipper(_committedResolved.box.clipPath);
    _textPainterOrNull?.syncSelectionParticipation();
    // attach 完成后才打开 transition 闸门
    _transitionsEnabled = true;
    // 路由返回和 GlobalKey 换父会重挂保留节点，入场只属于节点首次出现。
    if (firstAttach) _maybeStartEnterTransitions();
    if (trace != null) MountTrace.attachUs += trace.elapsedMicroseconds;
  }

  /// `ElStyle.starting`（CSS `@starting-style` 等价）：首次挂载帧以
  /// starting 声明值为起点、向 committed 基值启动 transition。
  ///
  /// 规则见 [ElStyle.starting] 文档：仅 effective transitions 覆盖的非离散
  /// 字段生效；reduced-motion 下整体跳过；保留节点重挂不重播。
  void _maybeStartEnterTransitions() {
    final starting = _style?.starting;
    if (starting == null || elDisableAnimations) return;
    final startingValues = specOf(starting).values;
    if (startingValues.isEmpty) return;

    final state = _stateBits;
    Map<ElTransitionField, Object?>? pinValues;
    for (final entry in startingValues.entries) {
      final field = entry.key;
      final spec = fieldSpecOf(field);
      if (spec.isDiscrete) continue;
      final transition = CascadeTick.firstCoveringTransition(style: _style, state: state, field: field);
      if (transition == null || (transition.duration == Duration.zero && transition.delay == Duration.zero)) {
        continue;
      }
      final startValue = entry.value;
      final targetValue = spec.read(_committedResolved);
      if (startValue == targetValue) continue;
      final animation = FieldAnimation(
        field: field,
        from: startValue,
        to: targetValue,
        duration: transition.duration,
        curve: transition.curve,
        delay: transition.delay,
      );
      _ensureAnimDriver().startAnimation(animation);
      (pinValues ??= <ElTransitionField, Object?>{})[field] = startValue;
    }
    if (pinValues == null) return;
    // 首帧钉在 starting 值（CSS：过渡进度 0 的视觉即起始样式）。
    final (next, changedMask) = CascadeTick.writeFieldsFromAnimation(
      oldCommitted: _committedResolved,
      fieldValues: pinValues,
    );
    if (changedMask.isEmpty) return;
    _commitResolved(next, changedMask);
  }

  /// 窗口尺寸变化回调（由 [_WindowMetricsObserver] 触发）。
  /// 只有本节点是响应式根（暗根 or `_selfSizeBasis`）时才会被调用；
  /// 位变化则同步 + propagate。
  void handleWindowMetricsChanged() {
    if (!attached) return;
    _syncResponsiveBits(_computeSelfResponsiveBits(), propagate: true);
  }

  @override
  void detach() {
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    _styleParent?._styleChildren?.remove(this);
    _eventDispatcher?.detach(preserveEvent: true);
    super.detach();
    // detach 后 sync：host.attached == false → 拆除选区 binder，保留 TextPainter。
    _textPainterOrNull?.syncSelectionParticipation();
    _animDriver?.cancelAll();
    _pendingAutoLengthSnapshotMask = FieldMask.empty;
    // keyframe 时钟清零（CSS 元素移出文档口径：重挂载后从头播）。
    _keyframeRunner?.reset();
    _transitionsEnabled = false;
    _listenToClipper(null);
    _WindowMetricsObserver.instance.unregister(this);
    if (trace != null) MountTrace.detachUs += trace.elapsedMicroseconds;
  }

  bool _findAncestorEffectiveDark() => _inheritedParent?.effectiveDarkForInheritance ?? false;

  void _propagateDarkChange() {
    SubtreeWalker.walk(this, (child) => child.inheritDarkFromAncestor(_effectiveDark));
  }

  bool? get _localDark {
    final declared = _localThemeMode?.brightness;
    return declared == null ? null : declared == Brightness.dark;
  }

  void _publishState() {
    _stateSource?.updateNodeStateBits(_stateBits);
  }

  @override
  void dispose() {
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    _isDisposing = true;
    _stateSource?.onListenerPresenceChanged = null;
    _stateSource = null;
    _varsBuildDeps?.dispose();
    _varsBuildDeps = null;
    _themeBuildDeps?.dispose();
    _themeBuildDeps = null;
    _animDriver?.dispose();
    _animDriver = null;
    _keyframeRunner?.dispose();
    _keyframeRunner = null;
    _eventDispatcher?.dispose();
    _eventDispatcher = null;
    requestFocusForEvent = null;
    _cascadeBridgeChanges?.dispose();
    _cascadeBridgeChanges = null;
    _listenToClipper(null);
    // 文本层 / paint 协作体：dispose 后置 null，销毁路径平坦、便于 GC。
    _textPainterOrNull?.dispose();
    _textPainterOrNull = null;
    _paintControllerOrNull?.dispose();
    _paintControllerOrNull = null;
    _zeroPaintOpsFor = null;
    super.dispose();
    if (trace != null) MountTrace.disposeUs += trace.elapsedMicroseconds;
  }
}

/// 窗口尺寸观察者单例。响应式**根节点**（暗根类：链上无
/// `InheritableNode` 祖先 —— 与 [ElRenderView._findAncestorEffectiveDark] 落
/// 兜底那类节点等价）attach 时向其注册；`didChangeMetrics` 时通知各注册根
/// recompute 位；位变化才 `_syncResponsiveBits(new, propagate: true)`。
class _WindowMetricsObserver with WidgetsBindingObserver {
  _WindowMetricsObserver._();

  static final _WindowMetricsObserver instance = _WindowMetricsObserver._();

  final Set<ElRenderView> _roots = <ElRenderView>{};

  void register(ElRenderView root) {
    if (_roots.add(root) && _roots.length == 1) WidgetsBinding.instance.addObserver(this);
  }

  void unregister(ElRenderView root) {
    if (_roots.remove(root) && _roots.isEmpty) WidgetsBinding.instance.removeObserver(this);
  }

  /// 取当前窗口逻辑尺寸的宽度。优先取任一 root 的 RenderView 侧 flutterView
  /// （物理像素除以 dpr）；拿不到再退回 platformDispatcher.implicitView，仍拿
  /// 不到兜底 0。
  double windowWidth() {
    for (final root in _roots) {
      final view = root._findAttachedFlutterView();
      if (view != null && view.devicePixelRatio > 0) return view.physicalSize.width / view.devicePixelRatio;
    }
    final implicit = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (implicit != null) {
      final dpr = implicit.devicePixelRatio;
      if (dpr > 0) return implicit.physicalSize.width / dpr;
    }
    return 0;
  }

  @override
  void didChangeMetrics() {
    for (final root in _roots) {
      if (!root.attached) continue;
      root.handleWindowMetricsChanged();
    }
  }
}

/// 引擎与组件渲染内部使用的状态接线，不从 el_ui 公共入口导出。
@internal
extension ViewStateRenderAccess on ElRenderView {
  /// 补齐默认值后的主题读面，供 Widget 与 MaterialApp 共用。
  ElThemeMode get resolvedThemeMode {
    final mode = effectiveThemeMode;
    return ElThemeMode(
      brightness: mode?.brightness ?? (_effectiveDark ? Brightness.dark : Brightness.light),
      duration: mode?.duration ?? ElThemeMode.defaultDuration,
      curve: mode?.curve ?? ElThemeMode.defaultCurve,
    );
  }

  /// 按需登记主题读者，复用变量依赖的派发与离树清理。
  VarsBuildDependents ensureThemeBuildDependents() =>
      _themeBuildDeps ??= VarsBuildDependents({ElThemeMode: resolvedThemeMode});

  /// 官方主题桥重放指定明暗轴时沿用实际级联父链，包含 Portal 的逻辑祖先。
  ElRenderView? get internalStyleParent => _styleParent ?? _findAncestor<ElRenderView>();

  /// 继承与当前激活变体合并后的变量表，读取本身不登记依赖。
  Map<Object, Object> get internalVars => _committedResolved.inheritedVars.map;

  /// 首次读取变量时才创建旧实现的按键依赖登记器。
  VarsBuildDependents ensureVarsBuildDependents() =>
      _varsBuildDeps ??= VarsBuildDependents(_committedResolved.inheritedVars.map);

  /// 离树清理状态订阅，不为仅变量读取者创建状态源。
  void removeStateBuildDependent(Element dependent) => _stateSource?.removeBuildDependent(dependent);

  /// 当前状态位，读取不创建订阅对象。
  int get internalStateBits => _stateBits;

  /// 读取指定状态，不登记 Widget 依赖。
  bool internalStateHas(ViewState state) => _stateHas(state);

  /// 首次订阅时才创建内部状态源。
  ViewStateSource get stateSource => _ensureStateSource();
}
