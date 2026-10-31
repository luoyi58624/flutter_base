/// 参照：D:/project/html/my-ui/packages/core/my-ui.js:1118-1395、1607-1681；packages/vue/adapter.ts:51-66。
library;

import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart'
    show BoxHitTestResult, RenderSemanticsAnnotations;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_base/ui.dart';

import 'theme.dart';

/// 内部内容桥接，Widget 原样使用，其余交给 ElView 文本引擎。
Widget myContent(Object? child) =>
    child is Widget ? child : ElView(child: child);

/// 当前平台是否要求减少动态效果。
bool myReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// CSS px 的断点基于整个 viewport，而非组件局部可用宽度。
double myViewport(BuildContext context) =>
    MediaQuery.maybeSizeOf(context)?.width ?? double.infinity;

/// 保留数值字重，兼顾静态字体与可变字体。
ElStyle myTextStyle(
  BuildContext context,
  double size,
  double weight, {
  Color? color,
  double? height,
}) {
  return ElStyle(
    fontSize: size,
    fontWeight: myTextWeight(weight),
    fontVariationSettings: [FontVariation('wght', weight)],
    color: color,
    lineHeight: height,
  );
}

/// 将行内盒从父布局的横向拉伸中解除。
Widget myInline(Widget child) => UnconstrainedBox(
  constrainedAxis: Axis.vertical,
  alignment: Alignment.centerLeft,
  child: child,
);

/// 整卡按原命中路径跳过内部控件，禁用按钮仍保留语义但不会派发tap。
bool _hitsNestedControl(BuildContext context, ElEventDetails event) {
  if (event.originalEvent is! PointerEvent) return false;
  final render = context.findRenderObject();
  if (render is! RenderBox || !render.hasSize) return false;
  final result = BoxHitTestResult();
  render.hitTest(result, position: render.globalToLocal(event.globalPosition));
  for (final hit in result.path) {
    final target = hit.target;
    if (identical(target, render)) break;
    final properties = target is ElRenderView
        ? target.semantics?.properties
        : target is RenderSemanticsAnnotations
        ? target.properties
        : null;
    if (properties != null &&
        (properties.button == true ||
            properties.link == true ||
            properties.toggled != null ||
            properties.checked != null ||
            properties.textField == true)) {
      return true;
    }
  }
  return false;
}

final _activatedControl = Expando<bool>();

/// 内部统一操作宿主，计时由既有 ElEvent 内核负责，键盘只维护 Space 会话。
class MyAction extends HookWidget {
  /// blocked 保留焦点而禁止激活，用于 loading。
  const MyAction({
    super.key,
    required this.child,
    required this.style,
    this.onActivate,
    this.disabled = false,
    this.blocked = false,
    this.label,
    this.toggled,
    this.selected,
    this.button = true,
    this.focusNode,
    this.event,
    this.repeatEnter = true,
    this.quickTouchFeedback = false,
    this.activateOnEnter = true,
    this.keyboardBuilder,
    this.excludeChildSemantics = true,
    this.ignoreDescendantAction = false,
    this.delayTouchDown = Duration.zero,
    this.delayTouchUp = const Duration(milliseconds: 100),
  });

  /// 内容。
  final Widget child;

  /// 默认外观。
  final ElStyle style;

  /// 激活事件。
  final ElEventHandler? onActivate;

  /// 移出焦点与指针操作。
  final bool disabled;

  /// 保留焦点但禁止操作。
  final bool blocked;

  /// 可访问名称。
  final String? label;

  /// 可选开关状态。
  final bool? toggled;

  /// 普通按钮的选中语义，与布尔开关状态独立。
  final bool? selected;

  /// 是否声明按钮角色，switch 只使用 toggled。
  final bool button;

  /// 外部焦点。
  final FocusNode? focusNode;

  /// 用户事件。
  final ElEvent? event;

  /// Enter 长按是否重复。
  final bool repeatEnter;

  /// 按钮触屏落下立即变色，缩放60ms，其余输入沿用默认过渡。
  final bool quickTouchFeedback;

  /// 是否接管 Enter。
  final bool activateOnEnter;

  /// 可选键盘按压内容桥接。
  final Widget Function(bool pressed)? keyboardBuilder;

  /// 显式label是否替换全部子语义，整卡保留内部控件。
  final bool excludeChildSemantics;

  /// 整卡跳过已在子控件处理的激活，保留普通祖先的事件冒泡。
  final bool ignoreDescendantAction;

  /// 触摸按下等待。
  final Duration delayTouchDown;

  /// 触摸最短反馈。
  final Duration delayTouchUp;

  @override
  Widget build(BuildContext context) {
    final internalFocus = useFocusNode();
    final node = focusNode ?? internalFocus;
    final space = useState(false);
    final directInput = useState(false);
    final feedbackCancelled = useState(false);
    final downPosition = useRef<Offset?>(null);
    final downBounds = useRef<Rect?>(null);
    useEffect(() {
      if (disabled || blocked) space.value = false;
      return null;
    }, [disabled, blocked]);
    final base = event ?? const ElEvent();
    void activate(ElEventDetails e) {
      if (disabled ||
          blocked ||
          base.disabled ||
          (ignoreDescendantAction &&
              (_activatedControl[e.originalEvent ?? e] == true ||
                  _hitsNestedControl(context, e)))) {
        return;
      }
      base.onTap?.call(e);
      if (!e.defaultPrevented) onActivate?.call(e);
      _activatedControl[e.originalEvent ?? e] = true;
    }

    void keyDown(ElEventDetails e, {bool repeat = false}) {
      if (!node.hasPrimaryFocus || disabled || blocked) return;
      directInput.value = false;
      final key = e.logicalKey;
      if (activateOnEnter &&
          (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter)) {
        if (!repeat || repeatEnter) activate(e);
        e
          ..preventDefault()
          ..stopPropagation();
      } else if (key == LogicalKeyboardKey.space) {
        space.value = true;
        e
          ..preventDefault()
          ..stopPropagation();
      } else if (key == LogicalKeyboardKey.escape && space.value) {
        space.value = false;
        e
          ..preventDefault()
          ..stopPropagation();
      }
    }

    final ownsKeys = !base.hasKeyboardCallback;
    final configured = base.copyWith(
      disabled: disabled || base.disabled,
      config: (base.config ?? const ElEventConfig()).copyWith(
        delayTouchDown: delayTouchDown,
        delayTouchUp: delayTouchUp,
        // Web移动阈值只取消视觉，真正滚动/失权仍由既有手势竞技场取消点击。
        tapCancelByDistance: false,
      ),
      onPointerDown: (e) {
        final original = e.originalEvent;
        if (original is PointerEvent) {
          directInput.value =
              original.kind == PointerDeviceKind.touch ||
              original.kind == PointerDeviceKind.stylus;
          feedbackCancelled.value = false;
          downPosition.value = e.globalPosition;
          final render = context.findRenderObject();
          downBounds.value = render is RenderBox && render.hasSize
              ? render.localToGlobal(Offset.zero) & render.size
              : null;
        }
        base.onPointerDown?.call(e);
      },
      onPointerMove: (e) {
        final origin = downPosition.value;
        if (directInput.value &&
            origin != null &&
            ((e.globalPosition - origin).distance > 10 ||
                downBounds.value?.contains(e.globalPosition) == false)) {
          feedbackCancelled.value = true;
        }
        base.onPointerMove?.call(e);
      },
      onTap: activate,
      onKeyDown: ownsKeys ? (e) => keyDown(e) : base.onKeyDown,
      onKeyRepeat: ownsKeys
          ? (e) => keyDown(e, repeat: true)
          : base.onKeyRepeat,
      onKeyUp: ownsKeys
          ? (e) {
              if (e.logicalKey != LogicalKeyboardKey.space || !space.value) {
                return;
              }
              space.value = false;
              if (node.hasPrimaryFocus) activate(e);
              e
                ..preventDefault()
                ..stopPropagation();
            }
          : base.onKeyUp,
      onBlur: (e) {
        space.value = false;
        base.onBlur?.call(e);
      },
    );
    final reduced = myReducedMotion(context);
    final inputStyle = feedbackCancelled.value
        ? style.copyWith(onTap: const ElStyle())
        : style;
    final pointerStyle = quickTouchFeedback && directInput.value
        ? inputStyle.copyWith(
            onTap: inputStyle.onTap?.copyWith(
              transition: const [
                ElTransition.all(Duration.zero),
                ElTransition.field(
                  ElTransitionField.transform,
                  Duration(milliseconds: 60),
                  Cubic(.2, .7, .2, 1),
                ),
              ],
            ),
          )
        : inputStyle;
    var resolved = space.value && !disabled && !blocked
        ? pointerStyle.merge(pointerStyle.onTap)
        : pointerStyle;
    if (reduced) {
      resolved = resolved.copyWith(
        transition: const <ElTransition>[],
        onTap: resolved.onTap?.copyWith(transition: const <ElTransition>[]),
        onHover: resolved.onHover?.copyWith(
          transition: const <ElTransition>[],
        ),
      );
    }
    final body =
        keyboardBuilder?.call(space.value && !disabled && !blocked) ?? child;
    return ElView(
      focusNode: node,
      event: configured,
      style: resolved,
      semantics: ElSemantics(
        container: true,
        mergeDescendants: excludeChildSemantics,
        button: button ? true : null,
        enabled: !(disabled || blocked || base.disabled),
        toggled: toggled,
        selected: selected,
        label: label,
        onTap: disabled || blocked || base.disabled
            ? null
            : () => activate(
                ElEventDetails(
                  phase: ElEventPhase.tap,
                  globalPosition: Offset.zero,
                  localPosition: Offset.zero,
                ),
              ),
      ),
      child: label == null || !excludeChildSemantics
          ? body
          : ExcludeSemantics(child: body),
    );
  }
}

/// 共享单值桥接，用户操作更新本地/Notifier，外部输入同步时不反射回调。
class MyValueBuilder<T> extends StatefulWidget {
  /// notifier 的生命周期属于调用方。
  const MyValueBuilder({
    super.key,
    required this.value,
    this.notifier,
    this.onChanged,
    required this.builder,
  });

  /// 外部输入。
  final T value;

  /// 双向通知源。
  final ValueNotifier<T>? notifier;

  /// 用户变化。
  final ValueChanged<T>? onChanged;

  /// 构建当前值。
  final Widget Function(BuildContext context, T value, ValueChanged<T> change)
  builder;
  @override
  State<MyValueBuilder<T>> createState() => _ValueBuilderState<T>();
}

class _ValueBuilderState<T> extends State<MyValueBuilder<T>> {
  late T _value;
  @override
  void initState() {
    super.initState();
    _value = widget.notifier?.value ?? widget.value;
    widget.notifier?.addListener(_sync);
  }

  void _sync() {
    if (mounted) setState(() => _value = widget.notifier!.value);
  }

  @override
  void didUpdateWidget(MyValueBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notifier != widget.notifier) {
      oldWidget.notifier?.removeListener(_sync);
      widget.notifier?.addListener(_sync);
    }
    _value = widget.notifier?.value ?? widget.value;
  }

  void _change(T value) {
    if (_value == value) return;
    setState(() => _value = value);
    widget.notifier?.value = value;
    widget.onChanged?.call(value);
  }

  @override
  void dispose() {
    widget.notifier?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _value, _change);
}
