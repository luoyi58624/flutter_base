import 'package:flutter/services.dart';

import '../view/event/event.dart';
import '../view/event/press.dart' show EventDetailsAccess;
import '../view/semantics/semantics.dart';
import '../view/style/style.dart';
import '../view/view.dart';

/// 无任何外观样式、只统一指针、键盘与辅助技术的最小按钮基元
class ElButtonView extends ElView {
  /// 创建无外观按钮；selected 仅用于语义，disabled 合入事件，toggled 声明布尔开关状态。
  ElButtonView({
    super.key,
    VoidCallback? onPressed,
    String? semanticLabel,
    ElStyle? style,
    ElEvent? event,
    super.focusNode,
    bool disabled = false,
    bool selected = false,
    bool? toggled,
    super.child,
  }) : super(
         style: _mergeBaseStyle(style),
         event: buildEvent(onPressed, disabled, event),
         semantics: ElSemantics(
           mergeDescendants: true,
           button: true,
           enabled: !(disabled || event?.disabled == true),
           // 选中只用于语义播报，选中外观由调用方传入普通样式。
           // 非选中按钮传 null 而不是 false，否则每个普通按钮都白挂一个
           // hasSelectedState。
           selected: toggled == null && selected ? true : null,
           toggled: toggled,
           label: semanticLabel,
           onTap: buildSemanticsTap(onPressed, event, disabled),
         ),
       );

  static ElStyle _mergeBaseStyle(ElStyle? style) {
    const base = ElStyle(userSelect: .none);
    if (style == null) return base;
    return base.merge(style);
  }

  /// 组装按钮事件：`onTap` 组合 [onPressed] 与调用方 `event.onTap`，并注入
  /// web 按钮口径的键盘激活——Enter keydown 即触发且按住经 keyRepeat 连续
  /// 触发，Space keyup 触发。element_plus 的 switch / checkbox / radio / link 等类
  /// 按钮组件复用本函数获得一致的激活语义。
  ///
  /// 键盘激活按**组**让位：[event] 声明了 `onKeyDown` / `onKeyRepeat` /
  /// `onKeyUp` 任意一个，内建 Enter / Space 激活整组退出——只让位单个回调的话，
  /// 调用方覆盖了 keydown，按住 Enter 仍会经 keyRepeat 回退连续激活。
  /// [activateOnEnter] 为 false 时只保留 Space 会话，Enter 继续交给祖先默认动作。
  static ElEvent? buildEvent(VoidCallback? onPressed, bool disabled, ElEvent? event, {bool activateOnEnter = true}) {
    if (disabled || event?.disabled == true) return (event ?? ElEvent()).copyWith(disabled: true);
    final base = event ?? ElEvent();

    void onTap(ElEventDetails e) {
      base.onTap?.call(e);
      if (!e.defaultPrevented) onPressed?.call();
    }

    // 调用方接管任一键盘回调 → 内建键盘激活整组让位。
    if (base.onKeyDown != null || base.onKeyRepeat != null || base.onKeyUp != null) {
      return base.copyWith(onTap: onTap);
    }

    // 消费掉的按键显式 preventDefault：el 侧只在 defaultPrevented 时返回
    // handled，不阻止默认动作就等于把按键让给 Flutter 的遍历/滚动。
    void onKeyDown(ElEventDetails e) {
      final key = e.logicalKey;
      if (activateOnEnter && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter)) {
        onTap(e);
        e.preventDefault();
      } else if (key == LogicalKeyboardKey.space) {
        e.preventDefault();
      } else if (key == LogicalKeyboardKey.escape && e.keyboardTapMatched) {
        e.preventDefault();
      }
    }

    void onKeyUp(ElEventDetails e) {
      if (e.logicalKey == LogicalKeyboardKey.space && e.keyboardTapMatched) {
        onTap(e);
        e.preventDefault();
      }
    }

    // 不注入 onKeyRepeat：dispatcher 对 keyRepeat 回退到 onKeyDown，按住 Enter
    // 继续激活；空格是否有配对的按下由 ElView 的会话维护，重建不丢失。
    return base.copyWith(onTap: onTap, onKeyDown: onKeyDown, onKeyUp: onKeyUp);
  }

  /// 辅助技术 tap 激活：先执行调用方事件，未阻止默认行为时再执行 [onPressed]。
  ///
  /// 纯 [onPressed] 路径直传原回调不包装，保住 [ElSemantics] `==` 的 onTap
  /// 身份比较（调用方传方法 tearoff 时命中结构等值，挡住语义树无谓失效）。
  static VoidCallback? buildSemanticsTap(VoidCallback? onPressed, ElEvent? event, bool disabled) {
    if (disabled || event?.disabled == true) return null;
    final eventTap = event?.onTap;
    if (eventTap == null) return onPressed;
    return () {
      // 辅助技术激活没有指针坐标，合成零坐标 tap 事件。
      final callback = ElEventDetails(phase: .tap, globalPosition: Offset.zero, localPosition: Offset.zero);
      eventTap(callback);
      if (!callback.defaultPrevented) onPressed?.call();
    };
  }
}
