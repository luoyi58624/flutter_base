import 'package:flutter/widgets.dart';

import '../../../utils/internal/benchmark_probe.dart';
import '../element/content_binding.dart';
import '../style/style_context.dart';
import 'text_engine.dart';

/// 文本启用时持有环境绑定与内联子树，退出时统一释放。
class TextElementBinding implements ContentElementBinding {
  /// 为当前文本引擎创建元素绑定。
  TextElementBinding(this._host, this._engine);

  final ContentElementHost _host;
  final TextEngine _engine;
  Element? _environment;
  List<Element> _children = const [];
  Set<Element>? _forgottenChildren;

  @override
  void update() {
    final previous = _environment?.widget as _TextEnvironment?;
    // 普通换字不改变继承环境；图标切换才需要重新选择缩放和无障碍参数。
    if (previous == null || previous.isIcon != _engine.isIcon) {
      _environment = _host.updateContentChild(_environment, _TextEnvironment(_engine, _host), null);
    }
    final spans = _engine.structure.spans;
    if (_children.isNotEmpty || spans.isNotEmpty) {
      _children = _host.updateContentChildren(_children, [
        for (final span in spans) _scope(span.child),
      ], _forgottenChildren);
    }
    _forgottenChildren?.clear();
  }

  Widget _scope(Widget child) {
    assert(() {
      if (child is! ParentDataWidget) return true;
      throw FlutterError(
        'ElView 的内联内容不接受 Flutter ParentDataWidget (${child.runtimeType})。\n'
        'Positioned、Expanded、Flexible、Spacer 等必须放在对应的 Flutter Stack 或 Flex 中。',
      );
    }());
    return StyleDependencyScope(
      key: child.key == null ? null : ValueKey(child.key),
      host: _host.renderView,
      child: child,
    );
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    final environment = _environment;
    if (environment != null) visitor(environment);
    final forgotten = _forgottenChildren;
    for (final child in _children) {
      if (forgotten == null || !forgotten.contains(child)) visitor(child);
    }
  }

  @override
  bool forgetChild(Element child) {
    if (!_children.contains(child)) return false;
    var forgotten = _forgottenChildren;
    if (forgotten == null) {
      assert(() {
        BenchmarkProbe.forgottenChildrenAllocCount++;
        return true;
      }());
      forgotten = _forgottenChildren = <Element>{};
    }
    forgotten.add(child);
    _children = List<Element>.of(_children)..remove(child);
    return true;
  }

  @override
  void dispose({bool unmounting = false}) {
    if (!unmounting) {
      if (_children.isNotEmpty) _host.updateContentChildren(_children, const [], _forgottenChildren);
      _host.updateContentChild(_environment, null, null);
    }
    _environment = null;
    _children = const [];
    _forgottenChildren = null;
  }
}

// 独立 Element 才能在退出文本时撤掉 Flutter 的继承依赖；不增加布局或绘制节点。
class _TextEnvironment extends Widget {
  _TextEnvironment(this.engine, this.host) : isIcon = engine.isIcon, super(key: ObjectKey(engine));

  final TextEngine engine;
  final ContentElementHost host;
  final bool isIcon;

  @override
  Element createElement() => _TextEnvironmentElement(this);
}

class _TextEnvironmentElement extends Element {
  _TextEnvironmentElement(_TextEnvironment super.widget);

  bool _debugBuilding = false;

  @override
  bool get debugDoingBuild => _debugBuilding;

  // 环境与文本共用宿主，仅为上下文和检查器提供观测入口，不承担渲染对象的挂卸。
  @override
  RenderObject? get renderObject => mounted ? (widget as _TextEnvironment).host.renderView : null;

  @override
  Element? get renderObjectAttachingChild => null;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    rebuild(force: true);
  }

  @override
  void update(covariant _TextEnvironment newWidget) {
    super.update(newWidget);
    rebuild(force: true);
  }

  @override
  void activate() {
    super.activate();
    markNeedsBuild();
  }

  @override
  void performRebuild() {
    assert(() {
      _debugBuilding = true;
      return true;
    }());
    try {
      _updateEnvironment();
    } finally {
      assert(() {
        _debugBuilding = false;
        return true;
      }());
      super.performRebuild();
    }
  }

  void _updateEnvironment() {
    final engine = (widget as _TextEnvironment).engine;
    engine.updateEnvironment(
      textScaler: engine.isIcon ? TextScaler.noScaling : MediaQuery.maybeTextScalerOf(this) ?? TextScaler.noScaling,
      accessibility: engine.isIcon
          ? defaultTextAccessibility
          : (
              bold: MediaQuery.boldTextOf(this),
              lineHeight: MediaQuery.maybeLineHeightScaleFactorOverrideOf(this),
              letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(this),
              wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(this),
            ),
      selectionRegistrar: SelectionContainer.maybeOf(this),
    );
  }
}
