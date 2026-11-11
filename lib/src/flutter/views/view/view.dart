import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../utils/internal/benchmark_probe.dart' show MountTrace, elMountTraceEnabled;
import '../../utils/internal/reuse_animation.dart';
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
    this.child,
  });

  /// 子内容。Widget 原样渲染；Iterable 默认走 rich inline；其他值渲染为文本。
  ///
  /// 传入 [ValueListenable] 时订阅其当前值；普通文本通知直接更新渲染层，
  /// 不重建本节点。Widget、富文本等结构型内容仍由 Element 协调子树；
  /// 独立图标与文字之间切换会重新同步缩放。只监听顶层来源，销毁由调用方负责。
  ///
  /// 不能把 Flutter [ParentDataWidget] 直接作为本节点的 child 或 Iterable
  /// 元素，例如 [Positioned]、[Expanded]、[Flexible]、[Spacer]。这些组件只
  /// 能由对应的 Flutter `Stack` / `Flex` 消费。开发模式会对此类错误抛出断言。
  final Object? child;

  /// 基础样式与状态变体，非常用文本配置通过 [ElStyle.textOptions] 声明。
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

  /// 响应式断点与尺寸基准声明；五档上界可空，沿 render 链继承合并；
  /// 整条链未声明时消费端 fallback 到 [ElBreakpoint.defaultXs] .. `defaultXl`
  /// （320/640/1024/1920/2560，对齐 `ElResponsiveData`）。
  final ElBreakpoint? breakpoint;

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

  @override
  ElRenderView createRenderObject(BuildContext context) {
    final element = context as ViewElement;
    final trace = elMountTraceEnabled ? (Stopwatch()..start()) : null;
    final render = ElRenderView(
      style: style,
      event: event,
      semantics: semantics,
      themeMode: themeMode,
      breakpoint: breakpoint,
    );
    render.bindTickerModeSource(() => TickerMode.getValuesNotifier(context));
    // 祖先失活时的按压反馈复位会回调这里，此时不可能处于换绑，直接返回 false。
    render.skipReuseTransitions = () => element.isActiveInTree && ReuseAnimationScope.skippingTransitionsOf(element);
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
        ..event = event
        ..semantics = semantics
        ..themeMode = themeMode
        ..breakpoint = breakpoint;
    });
  }
}
