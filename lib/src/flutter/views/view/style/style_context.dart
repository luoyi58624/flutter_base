import 'package:flutter/foundation.dart' show debugPrint, internal;
import 'package:flutter/widgets.dart';

import '../render/render_view.dart' show ElRenderView, ViewStateRenderAccess;
import 'state/view_state.dart';

/// 由 `ElView.of(context)` 获取的只读样式上下文，按读取的状态与变量订阅变化。
final class ElStyleContext {
  ElStyleContext._(this._context);

  final BuildContext _context;

  /// 读取祖先样式合并变体后的变量并订阅该键，未定义或类型不符时返回 null。
  T? getVar<T extends Object>(Object key) {
    final access = StyleDependencyScope.maybeHostOf(_context);
    if (access == null) return null;
    access.ensureVarsBuildDependents().register(_context as Element, key);
    final value = access.internalVars[key];
    assert(() {
      if (value != null && value is! T) {
        debugPrint('ElView.of(context).getVar("$key") 解析为 ${value.runtimeType}，期望 $T——按"未声明"处理');
      }
      return true;
    }());
    return value is T ? value : null;
  }

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

/// 创建按需订阅状态位与变量的上下文。
@internal
ElStyleContext readStyleContextFromContext(BuildContext context) => ElStyleContext._(context);

/// 检查最近视图是否存在，不登记依赖。
@internal
bool hasViewStateAccess(BuildContext context) => StyleDependencyScope.maybeHostOf(context) != null;

/// build 依赖源在读者离树时释放对应登记。
@internal
abstract interface class BuildDependencySource {
  /// 移除读者，不要求源值再次变化。
  void removeBuildDependent(Element dependent);
}

/// 借框架生命周期清理样式订阅，不参与文本排版或渲染。
@internal
class StyleDependencyScope extends InheritedTheme {
  const StyleDependencyScope({super.key, required this.host, required super.child});

  /// 当前子树所属的视图状态宿主。
  final ElRenderView host;

  /// 借继承表找到最近宿主，不登记状态依赖。
  static ElRenderView? maybeHostOf(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<StyleDependencyScope>()?.widget as StyleDependencyScope?)?.host;

  /// 登记退订关系，值变化仍由原来的样式源通知。
  static void dependOnBuildSource(Element dependent, BuildDependencySource source) {
    final scope = dependent.getElementForInheritedWidgetOfExactType<StyleDependencyScope>();
    if (scope != null) dependent.dependOnInheritedElement(scope, aspect: source);
  }

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
  void updateDependencies(Element dependent, Object? aspect) {
    if (aspect is! BuildDependencySource) {
      // 状态读取沿用空 aspect，同时保留该读者已经登记的变量源。
      if (getDependencies(dependent) == null) super.updateDependencies(dependent, aspect);
      return;
    }
    final sources = getDependencies(dependent) as Set<BuildDependencySource>? ?? <BuildDependencySource>{};
    sources.add(aspect);
    setDependencies(dependent, sources);
  }

  @override
  void removeDependent(Element dependent) {
    final sources = getDependencies(dependent) as Set<BuildDependencySource>?;
    super.removeDependent(dependent);
    (widget as StyleDependencyScope).host.removeStateBuildDependent(dependent);
    if (sources == null) return;
    for (final source in sources) {
      source.removeBuildDependent(dependent);
    }
  }
}
