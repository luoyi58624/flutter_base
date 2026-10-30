import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/widgets.dart';

import '../render/render_view.dart' show ElRenderView, ViewStateRenderAccess;
import 'state/view_state.dart';

/// 由 `ElView.of(context)` 获取的只读状态；读取哪个属性就订阅哪个属性。
final class ElStyleContext {
  ElStyleContext._(this._context);

  final BuildContext _context;

  /// 当前样式上下文的明暗轴。
  Brightness get brightness => isDark ? Brightness.dark : Brightness.light;

  /// [brightness] == [Brightness.dark] 的语法糖（`ElStyle.onDark` 的读值面）。
  bool get isDark => _has(ViewState.dark);

  /// 鼠标悬停（`ElStyle.onHover` 读值面）。
  bool get hasHover => _has(ViewState.hover);

  /// 主键按下（`ElStyle.onTap` 读值面）。
  bool get hasTap => _has(ViewState.tap);

  /// 自身拥有焦点（`ElStyle.onFocus` 读值面）。
  bool get hasFocus => _has(ViewState.focus);

  /// 自身或后代拥有焦点（`ElStyle.onFocusWithin` 读值面）。
  bool get hasFocusWithin => _has(ViewState.focusWithin);

  /// 键盘形态聚焦（`ElStyle.onFocusVisible` 读值面）。
  bool get hasFocusVisible => _has(ViewState.focusVisible);

  /// 禁用（`ElStyle.onDisabled` 读值面）。
  bool get isDisabled => _has(ViewState.disabled);

  // ---- 响应式断点（对齐 ElStyle.xs..xl 变体命名，max-width 语义，同 ElResponsiveExt）----

  /// 当前是否处于极小布局（<=320）。
  bool get xs => _has(ViewState.xs);

  /// 当前是否处于移动端布局（<=640）。
  bool get sm => _has(ViewState.sm);

  /// 当前是否处于平板布局（<=1024）。
  bool get md => _has(ViewState.md);

  /// 当前是否处于桌面布局（<=1920）。
  bool get lg => _has(ViewState.lg);

  /// 当前是否处于超大桌面布局（<=2560）。
  bool get xl => _has(ViewState.xl);

  bool _has(ViewState state) {
    final access = StyleDependencyScope.maybeHostOf(_context);
    if (access == null) return false;
    final mask = 1 << state.index;
    access.stateSource.dependOnBits(_context as Element, mask);
    return (access.internalStateBits & mask) != 0;
  }
}

/// 创建只订阅读过的状态位的上下文。
@internal
ElStyleContext readStyleContextFromContext(BuildContext context) => ElStyleContext._(context);

/// 检查最近视图是否存在，不登记依赖。
@internal
bool hasViewStateAccess(BuildContext context) => StyleDependencyScope.maybeHostOf(context) != null;

/// 借框架生命周期清理样式订阅，不参与文本排版或渲染。
@internal
class StyleDependencyScope extends InheritedTheme {
  const StyleDependencyScope({super.key, required this.host, required super.child});

  /// 当前子树所属的视图状态宿主。
  final ElRenderView host;

  /// 借继承表找到最近宿主，不登记状态依赖。
  static ElRenderView? maybeHostOf(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<StyleDependencyScope>()?.widget as StyleDependencyScope?)?.host;

  @override
  Widget wrap(BuildContext context, Widget child) => StyleDependencyScope(host: host, child: child);

  @override
  InheritedElement createElement() => _DependencyElement(this);

  @override
  bool updateShouldNotify(StyleDependencyScope oldWidget) => host != oldWidget.host;
}

class _DependencyElement extends InheritedElement {
  _DependencyElement(StyleDependencyScope super.widget);

  @override
  void removeDependent(Element dependent) {
    super.removeDependent(dependent);
    (widget as StyleDependencyScope).host.stateSource.removeBuildDependent(dependent);
  }
}
