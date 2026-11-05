import 'package:collection/collection.dart' show IdentityEquality, IterableEquality;
import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

import '../../utils/internal/benchmark_probe.dart' show MountTrace, elMountTraceEnabled;
import 'element/view_element.dart';
import 'event/event.dart';
import 'render/render_view.dart';
import 'semantics/semantics.dart';
import 'style/state/build_dependency_phase.dart';
import 'style/style.dart';
import 'style/style_context.dart';

/// ElView：盒模型 + 样式 + 事件节点。
class ElView extends RenderObjectWidget {
  /// 创建单子视图，禁用与基础光标由 [event] 配置。
  const ElView({
    super.key,
    this.style,
    this.event,
    this.focusNode,
    this.semantics,
    this.themeMode,
    this.breakpoint,
    this.inheritSize,
    this.locale,
    this.child,
  });

  /// 子内容。Widget 原样渲染；Iterable 默认走 rich inline；其他值渲染为文本。
  ///
  /// 不能把 Flutter [ParentDataWidget] 直接作为本节点的 child 或 Iterable
  /// 元素，例如 [Positioned]、[Expanded]、[Flexible]、[Spacer]。这些组件只
  /// 能由对应的 Flutter `Stack` / `Flex` 消费。开发模式会对此类错误抛出断言。
  final Object? child;

  final ElStyle? style;

  /// 事件配置（pointer / tap / longPress / drag / scale / keyboard / focus）。
  ///
  /// 仅当 [event] 非 null 或 [style] 含状态变体时，[ElRenderView] 才 lazy 构造
  /// `EventDispatcher`（零开销 fast path）。
  final ElEvent? event;

  /// 焦点节点。传 null 时按 [style] 是否启用焦点变体（onFocus /
  /// onFocusVisible / onFocusWithin）或是否声明键盘回调自动创建并持有内部节点。
  final FocusNode? focusNode;

  /// 语义配置。用于向读屏等辅助技术暴露 label / role / state / action。
  final ElSemantics? semantics;

  /// 定义主题，它会驱动 onDark 变体，如果 brightness 为 null 将自动跟随祖先，默认兜底 light，
  /// 更新主题时，会根据配置的 duration / curve 统一后代的动画时长、曲线，从 Render 底层解决过渡不一致问题。
  final ElThemeMode? themeMode;

  /// 响应式断点声明。五字段全部可空，沿 render 链继承合并；
  /// 整条链未声明时消费端 fallback 到 [ElBreakpoint.defaultXs] .. `defaultXl`
  /// （320/640/1024/1920/2560，对齐 `ElResponsiveData`）。
  final ElBreakpoint? breakpoint;

  /// 定义后代的响应式基准尺寸。
  final bool? inheritSize;

  /// 文本语言环境提示。默认 null，让平台/引擎按字体 fallback 规则处理；
  /// 需要精确语言字形时显式传入（如 `Locale('ja', 'JP')`）。
  final Locale? locale;

  /// 最近 ElView 的只读样式上下文，读取状态或变量时自动订阅对应变化。
  static ElStyleContext of(BuildContext context) {
    assert(hasViewStateAccess(context), 'No ElView found in context.');
    return readStyleContextFromContext(context);
  }

  /// [of] 的可空版本：context 之上无ElView 时返回 null。
  static ElStyleContext? maybeOf(BuildContext context) {
    if (!hasViewStateAccess(context)) return null;
    return readStyleContextFromContext(context);
  }

  @override
  RenderObjectElement createElement() => ViewElement(this);

  /// textScaler 只有文本链消费（[ElRenderView.textScaler] → 文本子失效 +
  /// TextView 排版 `owner?.textScaler`）：child 为 null / 纯 Widget 的节点
  /// （布局容器的大多数）没有消费者——不读 MediaQuery、不建 aspect 依赖，
  /// 挂载突发少一次 InheritedModel 注册。inline Widget 混排即使路由 TextView，
  /// payload 里也只有 atomic widget、无可缩放文本；其内部文本由自己的 ElView
  /// 宿主提供 scaler。String / InlineSpan / Iterable（可能混文本）保守读取。
  // 独立 IconData 默认不缩放；ElIcon 的可选缩放由组件推送到既有 render 接口。
  bool get _needsTextScaler => child != null && child is! Widget && child is! IconData;

  TextScaler _resolveTextScaler(BuildContext context) =>
      _needsTextScaler ? (MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling) : TextScaler.noScaling;

  @override
  ElRenderView createRenderObject(BuildContext context) {
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    // Element 挂载文本前认领宿主，环境参数由 Widget 持续推送。
    final render = ElRenderView(
      style: style,
      event: event,
      semantics: semantics,
      themeMode: themeMode,
      breakpoint: breakpoint,
      inheritSize: inheritSize,
      textScaler: _resolveTextScaler(context),
      locale: locale,
    );
    render.systemBoldText = (context as ViewElement).resolveSystemBoldText();
    render.setStyleParent(StyleDependencyScope.maybeHostOf(context));
    if (trace != null) MountTrace.createRenderObjectUs += trace.elapsedMicroseconds;
    return render;
  }

  @override
  void updateRenderObject(BuildContext context, ElRenderView renderObject) {
    final element = context as ViewElement;
    withBuildDependencyOrigin(element, () {
      renderObject.setStyleParent(StyleDependencyScope.maybeHostOf(element));
      renderObject
        ..style = style
        ..systemBoldText = element.resolveSystemBoldText()
        ..event = event
        ..semantics = semantics
        ..themeMode = themeMode
        ..breakpoint = breakpoint
        ..textScaler = _resolveTextScaler(element)
        ..locale = locale;
    });
  }
}

/// 比较文本载荷；富文本按节点身份比较，普通文本按值比较。
@internal
bool sameViewTextPayload(Object? first, Object? second) {
  if (identical(first, second)) return true;
  if (first is Iterable && second is Iterable) {
    return const IterableEquality<Object?>(IdentityEquality()).equals(first, second);
  }
  return first is! InlineSpan && second is! InlineSpan && first == second;
}
