import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_base/src/ui/cores/view/event/event.dart';
import 'package:flutter_base/src/ui/cores/view/view.dart';
import 'package:flutter_base/src/ui/cores/view/style/style.dart';
import 'package:flutter_base/src/ui/cores/view/semantics/semantics.dart';

/// 保存按钮键盘按压会话，供上层皮肤同步绘制 Space 按住状态。
///
/// 控制器不拥有按钮焦点和激活行为；[ElButtonView] 只在 Space 按下、释放、取消或
/// 失焦时更新 [pressed]。调用方创建时也负责销毁。
class ElButtonViewPressController extends ChangeNotifier {
  bool _pressed = false;

  /// Space 是否处于已按下、等待 keyup 激活的会话。
  bool get pressed => _pressed;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    _pressed = value;
    notifyListeners();
  }

  /// 取消当前键盘按压会话，不触发按钮激活。
  void cancel() => _setPressed(false);
}

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
    this.pressController,
    bool disabled = false,
    bool selected = false,
    bool? toggled,
    super.child,
  }) : super(
         style: _mergeBaseStyle(style),
         event: buildEvent(onPressed, disabled, event, pressController: pressController),
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

  /// 可选键盘按压会话；用于让外观层读取 Space 按住期间的物理按压状态。
  final ElButtonViewPressController? pressController;

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
  static ElEvent? buildEvent(
    VoidCallback? onPressed,
    bool disabled,
    ElEvent? event, {
    ElButtonViewPressController? pressController,
    bool activateOnEnter = true,
  }) {
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

    // 粘滞空格防护（web 口径）：keyup 激活要求 keydown 发生在本按钮聚焦期间
    // ——空格按住途中焦点才移进来的 keyup 不激活；按住期间 Esc 取消本次激活。
    // 状态存在闭包里，widget 重建会复位——失败方向是"不激活"，安全。
    var spaceArmed = false;

    bool spaceIsArmed() => pressController?.pressed ?? spaceArmed;

    void setSpaceArmed(bool value) {
      spaceArmed = value;
      pressController?._setPressed(value);
    }

    // 消费掉的按键显式 preventDefault：el 侧只在 defaultPrevented 时返回
    // handled，不阻止默认动作就等于把按键让给 Flutter 的遍历/滚动。
    void onKeyDown(ElEventDetails e) {
      final key = e.logicalKey;
      if (activateOnEnter && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter)) {
        onTap(e);
        e.preventDefault();
      } else if (key == LogicalKeyboardKey.space) {
        setSpaceArmed(true);
        e.preventDefault();
      } else if (key == LogicalKeyboardKey.escape) {
        final armed = spaceIsArmed();
        setSpaceArmed(false);
        if (armed) e.preventDefault();
      }
    }

    void onKeyUp(ElEventDetails e) {
      if (e.logicalKey == LogicalKeyboardKey.space && spaceIsArmed()) {
        setSpaceArmed(false);
        onTap(e);
        e.preventDefault();
      }
    }

    void onBlur(ElEventDetails e) {
      base.onBlur?.call(e);
      setSpaceArmed(false);
    }

    // 不注入 onKeyRepeat：dispatcher 对 keyRepeat 回退到 onKeyDown，按住 Enter
    // 自然连续激活，空格 repeat 只是反复置位 spaceArmed，无副作用。
    return base.copyWith(onTap: onTap, onKeyDown: onKeyDown, onKeyUp: onKeyUp, onBlur: onBlur);
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
