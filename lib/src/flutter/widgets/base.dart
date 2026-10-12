import 'package:collection/collection.dart' show ListEquality;

import '../../../dart.dart';

import 'package:flutter/rendering.dart';

import '../commons/index.dart';

import 'package:flutter/widgets.dart';

/// 空 Widget 实例，通常用于在 build 条件分之中返回不可到达代码
class ElNullWidget extends Widget {
  const ElNullWidget._();

  static const instance = ElNullWidget._();

  @override
  Element createElement() => throw UnimplementedError();
}

/// 空 Element 实例，通常用于初始化 Element 数组
class ElNullElement extends Element {
  ElNullElement._() : super(ElNullWidget.instance);

  static final instance = ElNullElement._();

  @override
  bool get debugDoingBuild => throw UnimplementedError();
}

/// 不渲染任何内容的小部件，它的作用仅充当占位符
class ElEmptyWidget extends LeafRenderObjectWidget {
  const ElEmptyWidget._();

  static const instance = ElEmptyWidget._();

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEmpty();
}

class _RenderEmpty extends RenderBox {
  @override
  void performLayout() {
    size = constraints.smallest;
  }
}

/// 一个功能小部件，让迭代的列表子元素确认自身所在的位置
class ElChildIndex extends InheritedWidget {
  const ElChildIndex({
    super.key,
    required super.child,
    required this.index,
    this.start,
    this.end,
    this.length,
  });

  /// 当前索引
  final int index;

  /// 迭代元素起始索引，非必需，使用前请确认是否注入
  final int? start;

  /// 迭代元素结束索引，非必需，使用前请确认是否注入
  final int? end;

  /// 迭代元素总长度，非必需，使用前请确认是否注入
  final int? length;

  static ElChildIndex? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ElChildIndex>();

  static ElChildIndex of(BuildContext context) {
    final ElChildIndex? result = maybeOf(context);
    assert(result != null, 'No ElChildIndex found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ElChildIndex oldWidget) =>
      index != oldWidget.index ||
      start != oldWidget.start ||
      end != oldWidget.end ||
      length != oldWidget.length;
}

/// 按指定条件复用或更新子组件实例。
class ElRebuildWidget<W extends Widget> extends Widget {
  /// 手动控制子组件重建，它会缓存旧的 Widget 实例，如果未触发重建条件，
  /// 则不会应用新的 Widget 实例，你可以将此效果理解为添加 const 修饰
  const ElRebuildWidget({super.key, this.shouldRebuild, required this.child});

  /// 指定触发重建条件，当返回 true 时将允许子组件重建，
  /// 此回调为 null 或者返回 false 则不会重建子组件，因为它会复用旧的 Widget 实例
  final ElUpdateCallback<W>? shouldRebuild;

  final W child;

  @override
  Element createElement() => _RebuildElement<W>(this);
}

class _RebuildElement<W extends Widget> extends ComponentElement {
  _RebuildElement(super.widget);

  @override
  ElRebuildWidget<W> get widget => super.widget as ElRebuildWidget<W>;

  W? _child;

  @override
  void reassemble() {
    _child = null; // 热刷新时清除缓存
    super.reassemble();
  }

  @override
  void update(covariant Widget newWidget) {
    super.update(newWidget);
    rebuild(force: true);
  }

  @override
  void unmount() {
    _child = null;
    super.unmount();
  }

  @override
  Widget build() {
    _child ??= widget.child;

    if (widget.shouldRebuild?.call(widget.child, _child!) == true) {
      _child = widget.child;
    }

    return _child!;
  }
}

/// 从 Listenable 选择目标数据并按变化重建子树。
class ElListenableBuilder<L extends Listenable, D> extends Widget {
  /// 类似于 ListenableBuilder 小部件，不过它支持精确更新
  const ElListenableBuilder({
    super.key,
    this.listenable,
    this.select,
    this.shouldRebuild,
    required this.builder,
    this.child,
  });

  /// 监听任何实现 [Listenable] 接口对象，例如：[ChangeNotifier]、[ValueNotifier]
  final L? listenable;

  /// 精确监听对象中的某个属性，只有当目标发生更新时才会重建 [builder] 代码块，例如：
  /// ```dart
  /// class MyController with ChangeNotifier {
  ///   int count = 0;
  ///   int count2 = 0;
  /// }
  ///
  /// ElListenableBuilder(
  ///   listenable: controller,
  ///   select: (MyController c) => c.count2, // 只监听 count2 的变化
  ///   builder: (context) {
  ///     return Text('count: ${controller.count2}');
  ///   },
  /// );
  /// ```
  final D Function(L listenable)? select;

  /// 自定义重建条件，此回调会传递 [select] 构建的最新值、上一次旧值，例如：
  /// ```dart
  /// select: (MyController c) => c.count2,
  /// shouldRebuild: (newValue, oldValue) => newValue < 10, // 超过 10 就不重建
  /// ```
  ///
  /// 你还可以监听多个属性变化，但判断 List 内容是否相同需要用 [ListEquality]：
  /// ```dart
  /// select: (MyController c) => [c.count, c.count2], // 当两个变量有一个发生变化就重建
  /// shouldRebuild: (newValue, oldValue) => newValue.neq(oldValue), // 判断 List 内容是否不同
  /// ```
  final ElUpdateCallback<D>? shouldRebuild;

  /// 当 [listenable] 发起通知时，会重建该代码块
  final TransitionBuilder builder;

  /// 如果构建函数 [builder] 包含不依赖 [listenable] 的子树，那么在此处设置它可以跳过重建
  final Widget? child;

  @override
  Element createElement() => _ListenableElement<L, D>(this);
}

class _ListenableElement<L extends Listenable, D> extends ComponentElement {
  _ListenableElement(super.widget);

  @override
  ElListenableBuilder<L, D> get widget =>
      super.widget as ElListenableBuilder<L, D>;

  /// 缓存旧的 Widget 实例，当 [_oldValue] 与新值一样时，将不会重新执行 builder 代码块
  Widget? _oldWidget;
  dynamic _oldValue;

  @override
  void reassemble() {
    _oldWidget = null; // 热刷新时清除缓存
    _oldValue = null;
    super.reassemble();
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    widget.listenable?.addListener(_handleChange);
  }

  @override
  void update(ElListenableBuilder<L, D> newWidget) {
    if (newWidget.listenable != widget.listenable) {
      widget.listenable?.removeListener(_handleChange);
      newWidget.listenable?.addListener(_handleChange);
    }

    super.update(newWidget);
    rebuild(force: true);
  }

  @override
  void unmount() {
    widget.listenable?.removeListener(_handleChange);
    _oldWidget = null;
    _oldValue = null;
    super.unmount();
  }

  void _handleChange() {
    if (mounted) markNeedsBuild();
  }

  @override
  Widget build() {
    if (widget.listenable == null || widget.select == null) {
      return widget.builder(this, widget.child);
    }

    if (_oldWidget == null && _oldValue == null) {
      _oldWidget = widget.builder(this, widget.child);
      _oldValue = widget.select!(widget.listenable!);
      return _oldWidget!;
    }

    final newValue = widget.select!(widget.listenable!);

    bool flag;
    if (widget.shouldRebuild != null) {
      flag = widget.shouldRebuild!(newValue, _oldValue) == true;
    } else {
      flag = newValue != _oldValue;
    }

    if (flag) {
      _oldValue = newValue;
      _oldWidget = widget.builder(this, widget.child);
      return _oldWidget!;
    } else {
      _oldValue = newValue;
      return _oldWidget!;
    }
  }
}

/// 调试小部件
class ElDebugWidget extends SingleChildRenderObjectWidget {
  const ElDebugWidget({
    super.key,
    this.debugLabel,
    this.checkElementMount = false,
    this.checkElementUpdate = false,
    this.checkElementUnmount = false,
    this.checkRenderLayout = false,
    this.checkRenderPaint = false,
    this.filterTime,
    required super.child,
  });

  /// 调试标签
  final String? debugLabel;

  /// 检查 Element 挂载
  final bool checkElementMount;

  /// 检查 Element 更新
  final bool checkElementUpdate;

  /// 检查 Element 卸载
  final bool checkElementUnmount;

  /// 检查重排
  final bool checkRenderLayout;

  /// 检查重绘
  final bool checkRenderPaint;

  /// 过滤时间打印最低阈值
  final Duration? filterTime;

  @override
  SingleChildRenderObjectElement createElement() {
    return _DebugElement(this);
  }

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDebug(
      debugLabel,
      checkRenderLayout,
      checkRenderPaint,
      filterTime,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    renderObject as _RenderDebug
      ..debugLabel = debugLabel
      ..checkRenderLayout = checkRenderLayout
      ..checkRenderPaint = checkRenderPaint
      ..filterTime = filterTime;
  }
}

class _DebugElement extends SingleChildRenderObjectElement {
  _DebugElement(super.widget);

  @override
  ElDebugWidget get widget => super.widget as ElDebugWidget;

  @override
  void mount(Element? parent, Object? newSlot) {
    () {
      super.mount(parent, newSlot);
    }.time(
      enabled: widget.checkElementMount,
      debugLabel: widget.debugLabel,
      logPrefix: 'Element mount: ',
      filterTime: widget.filterTime,
      log: ElLog.d,
    );
  }

  @override
  void update(ElDebugWidget newWidget) {
    () {
      super.update(newWidget);
    }.time(
      enabled: newWidget.checkElementUpdate,
      debugLabel: newWidget.debugLabel,
      logPrefix: 'Element update: ',
      filterTime: newWidget.filterTime,
      log: ElLog.i,
    );
  }

  @override
  void unmount() {
    () {
      super.unmount();
    }.time(
      enabled: widget.checkElementUnmount,
      debugLabel: widget.debugLabel,
      logPrefix: 'Element unmount: ',
      filterTime: widget.filterTime,
      log: ElLog.e,
    );
  }
}

class _RenderDebug extends RenderProxyBox {
  _RenderDebug(
    this._debugLabel,
    this._checkRenderLayout,
    this._checkRenderPaint,
    this._filterTime,
  );

  String? _debugLabel;

  set debugLabel(String? v) {
    if (_debugLabel == v) return;
    _debugLabel = v;
    markNeedsLayout();
  }

  bool _checkRenderLayout;

  set checkRenderLayout(bool v) {
    if (_checkRenderLayout == v) return;
    _checkRenderLayout = v;
    markNeedsLayout();
  }

  bool _checkRenderPaint;

  set checkRenderPaint(bool v) {
    if (_checkRenderPaint == v) return;
    _checkRenderPaint = v;
    markNeedsPaint();
  }

  Duration? _filterTime;

  set filterTime(Duration? v) {
    if (_filterTime == v) return;
    _filterTime = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    () {
      super.performLayout();
    }.time(
      enabled: _checkRenderLayout,
      debugLabel: _debugLabel,
      logPrefix: 'RenderObject performLayout: ',
      filterTime: _filterTime,
      log: ElLog.e,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    () {
      super.paint(context, offset);
    }.time(
      enabled: _checkRenderPaint,
      debugLabel: _debugLabel,
      logPrefix: 'RenderObject paint: ',
      filterTime: _filterTime,
      log: ElLog.w,
    );
  }
}

/// 为主子组件添加尺寸相同的前景与背景子项。
class ElSecondChildWidget extends RenderObjectWidget {
  /// 允许在 [child] 上方、下方构建第二个小部件，它们的约束尺寸强制跟随 [child] 大小
  const ElSecondChildWidget({
    super.key,
    this.sizedByParent,
    this.secondChild,
    this.foregroundSecondChild,
    required this.child,
  });

  /// 强制布局尺寸跟随父元素，默认情况下布局尺寸会跟随 [child]
  final bool? sizedByParent;

  /// 渲染在 child 上方的子组件
  final Widget? secondChild;

  /// 渲染在 child 下方的子组件
  final Widget? foregroundSecondChild;

  /// 代理子组件
  final Widget child;

  @override
  RenderObjectElement createElement() => ElSecondChildElement(this);

  @override
  ElRenderSecondChildBox createRenderObject(BuildContext context) =>
      ElRenderSecondChildBox(sizedByParent: sizedByParent);

  @override
  void updateRenderObject(
    BuildContext context,
    ElRenderSecondChildBox renderObject,
  ) {
    renderObject.updateSizedByParent(sizedByParent);
  }
}

/// 管理主子组件和两个附加子项的挂载。
class ElSecondChildElement extends RenderObjectElement {
  ElSecondChildElement(super.widget);

  Element? childElement;
  Element? secondChildElement;
  Element? foregroundSecondChildElement;

  @override
  ElSecondChildWidget get widget => super.widget as ElSecondChildWidget;

  @override
  ElRenderSecondChildBox get renderObject =>
      super.renderObject as ElRenderSecondChildBox;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (childElement != null) visitor(childElement!);
    if (secondChildElement != null) visitor(secondChildElement!);
    if (foregroundSecondChildElement != null) {
      visitor(foregroundSecondChildElement!);
    }
  }

  @override
  void forgetChild(Element child) {
    if (childElement == child) {
      childElement = null;
    } else if (secondChildElement == child) {
      secondChildElement = null;
    } else if (foregroundSecondChildElement == child) {
      foregroundSecondChildElement = null;
    }
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    childElement = updateChild(childElement, widget.child, #child);
    secondChildElement = updateChild(
      secondChildElement,
      widget.secondChild,
      #secondChild,
    );
    foregroundSecondChildElement = updateChild(
      foregroundSecondChildElement,
      widget.foregroundSecondChild,
      #foregroundSecondChild,
    );
  }

  @override
  void update(ElSecondChildWidget newWidget) {
    super.update(newWidget);
    childElement = updateChild(childElement, widget.child, #child);
    secondChildElement = updateChild(
      secondChildElement,
      widget.secondChild,
      #secondChild,
    );
    foregroundSecondChildElement = updateChild(
      foregroundSecondChildElement,
      widget.foregroundSecondChild,
      #foregroundSecondChild,
    );
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) {
    if (slot == #child) {
      renderObject.child = child;
    } else if (slot == #secondChild) {
      renderObject.secondChild = child;
    } else if (slot == #foregroundSecondChild) {
      renderObject.foregroundSecondChild = child;
    }
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object? slot) {
    if (slot == #child) {
      renderObject.child = null;
    } else if (slot == #secondChild) {
      renderObject.secondChild = null;
    } else if (slot == #foregroundSecondChild) {
      renderObject.foregroundSecondChild = child;
    }
  }

  @override
  void moveRenderObjectChild(
    covariant RenderObject child,
    covariant Object? oldSlot,
    covariant Object? newSlot,
  ) {}
}

/// 布局并绘制主子组件及其附加子项。
class ElRenderSecondChildBox extends RenderProxyBox {
  ElRenderSecondChildBox({bool? sizedByParent}) {
    _sizedByParent = sizedByParent;
  }

  bool? _sizedByParent;

  void updateSizedByParent(bool? v) {
    if (_sizedByParent != v) {
      _sizedByParent = v;
      markNeedsLayout();
    }
  }

  RenderBox? _secondChild;

  RenderBox? get secondChild => _secondChild;

  set secondChild(RenderBox? value) {
    if (_secondChild != null) {
      dropChild(_secondChild!);
    }
    _secondChild = value;
    if (_secondChild != null) {
      adoptChild(_secondChild!);
    }
  }

  RenderBox? _foregroundSecondChild;

  RenderBox? get foregroundSecondChild => _foregroundSecondChild;

  set foregroundSecondChild(RenderBox? value) {
    if (_foregroundSecondChild != null) {
      dropChild(_foregroundSecondChild!);
    }
    _foregroundSecondChild = value;
    if (_foregroundSecondChild != null) {
      adoptChild(_foregroundSecondChild!);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _secondChild?.attach(owner);
    _foregroundSecondChild?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _secondChild?.detach();
    _foregroundSecondChild?.detach();
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    if (_secondChild != null) redepthChild(_secondChild!);
    if (_foregroundSecondChild != null) redepthChild(_foregroundSecondChild!);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    if (_secondChild != null) visitor(_secondChild!);
    if (_foregroundSecondChild != null) visitor(_foregroundSecondChild!);
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  bool get sizedByParent => _sizedByParent ?? child == null;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    assert(
      constraints.biggest.isInfinite == false,
      'ElSecondChildWidget 没有指定 child 小部件，它的尺寸将跟随父元素，但是 parent 传递的约束为 infinity 无限大小: \n$constraints\n\n'
      '要修复此错误，请将 ElSecondChildWidget 包裹在有限尺寸的容器内，或者指定 child 小部件！',
    );
    return constraints.biggest;
  }

  @override
  void performLayout() {
    if (child != null) {
      if (sizedByParent) {
        child!.layout(constraints.loosen());
      } else {
        child!.layout(constraints.loosen(), parentUsesSize: true);
        size = constraints.constrain(child!.size);
      }
    }

    secondChild?.layout(BoxConstraints.tight(size));
    foregroundSecondChild?.layout(BoxConstraints.tight(size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (foregroundSecondChild != null) {
      context.paintChild(foregroundSecondChild!, offset);
    }
    context.paintChild(child!, offset);
    if (secondChild != null) context.paintChild(secondChild!, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (secondChild?.hitTest(result, position: position) == true) return true;
    if (child?.hitTest(result, position: position) == true) return true;
    if (foregroundSecondChild?.hitTest(result, position: position) == true) {
      return true;
    }
    return false;
  }
}

/// 布局、渲染多个子节点的小部件，该小部件是 [MultiChildRenderObjectWidget] 的简化版本，
/// 它只使用 [Key] 来放置 [children] 插槽，在 [ElRenderMultiBox] 中，允许用户使用 key
/// 来访问 [children] 实例化的 RenderObject 对象。
///
/// 注意：该小部件所创建的 [ElMultiElement]、[ElRenderMultiBox] 不会处理 children 的顺序，
/// 你不能将其用在动态 [children] 的场景中。
abstract class ElMultiWidget extends RenderObjectWidget {
  const ElMultiWidget({
    super.key,
    this.debugLabel = _debugLabel,
    this.sizedByParent,
    this.ignoreChildrenUpdate,
    required this.children,
    this.child,
  });

  static const _debugLabel = 'ElMultiWidget';

  /// 打印 assert 错误断言名称
  final String debugLabel;

  /// 强制布局尺寸跟随父元素
  final bool? sizedByParent;

  /// 是否忽略 [children] diff 更新
  final bool? ignoreChildrenUpdate;

  /// 子节点集合，注意：每个子节点必须设置 key 作为唯一标识，
  /// 因为 [ElMultiElement] 只使用 key 来作为元素 slot 插槽
  final Iterable<Widget> children;

  /// 代理子类，所有的子节点将绘制在目标小部件之上，如果为 null，布局大小将跟随父元素
  final Widget? child;

  @override
  ElMultiElement createElement() => ElMultiElement(this);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant ElRenderMultiBox renderObject,
  ) {
    renderObject.updateSizedByParent(sizedByParent);
  }
}

/// 按 Key 管理多子节点的挂载与更新。
class ElMultiElement extends RenderObjectElement {
  ElMultiElement(super.widget);

  Element? child;

  final Map<Key, Element?> children = {};

  @override
  ElMultiWidget get widget => super.widget as ElMultiWidget;

  @override
  ElRenderMultiBox get renderObject => super.renderObject as ElRenderMultiBox;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (child != null) visitor(child!);
    for (final child in children.values) {
      if (child != null) visitor(child);
    }
  }

  @override
  void forgetChild(Element child) {
    super.forgetChild(child);
    if (child.slot == null) {
      this.child = null;
    } else {
      children.remove(child.slot);
    }
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    child = updateChild(null, widget.child, null);
    for (final child in widget.children) {
      assert(
        child.key != null,
        '${widget.debugLabel} mount 出现错误，children 子元素必须全部设置 key：$child',
      );
      assert(
        children.containsKey(child.key) == false,
        '${widget.debugLabel} mount 出现错误，children 列表出现重复的 key 元素：${child.key}',
      );
      children[child.key!] = updateChild(null, child, child.key);
    }
  }

  @override
  void update(ElMultiWidget newWidget) {
    super.update(newWidget);
    child = updateChild(child, widget.child, null);

    if (newWidget.ignoreChildrenUpdate == true) return;

    updateMultiChildren(newWidget);
  }

  /// 默认的更新 children 元素方法
  @protected
  void updateMultiChildren(ElMultiWidget newWidget) {
    // 将 List -> Map 结构
    final newMap = {};
    for (final child in widget.children) {
      assert(
        child.key != null,
        '${widget.debugLabel} update 出现错误，children 子元素必须全部设置 key：$child',
      );
      newMap[child.key!] = child;
    }

    // 记录需要更新的节点 key、需要移除的节点 key
    final List<Key> updateKeys = [], removeKeys = [];

    // 对比新旧集合，提取出已存在、需要移除的元素节点
    for (final key in children.keys) {
      newMap.containsKey(key) ? updateKeys.add(key) : removeKeys.add(key);
    }

    // 移除被删除的元素节点
    for (final key in removeKeys) {
      updateChild(children[key], null, key);
      children.remove(key);
    }

    // 更新旧数据，并且从新的集合中移除它们，保留需要新增的元素节点
    for (final key in updateKeys) {
      children[key] = updateChild(children[key], newMap[key], key);
      newMap.remove(key);
    }

    // 将新增的元素节点挂载到 Element 树中
    for (final item in newMap.entries) {
      children[item.key!] = updateChild(null, item.value, item.key);
    }
  }

  @override
  void unmount() {
    super.unmount();
    child = null;
    children.clear();
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) {
    if (slot == null) {
      renderObject.child = child;
    } else {
      renderObject.insert(slot as Key, child);
    }
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object? slot) {
    if (slot == null) {
      renderObject.child = null;
    } else {
      renderObject.remove(slot as Key, child);
    }
  }

  @override
  void moveRenderObjectChild(child, oldSlot, newSlot) {
    assert(false, '${widget.debugLabel} 禁止动态增删子元素，因为这会导致显示可能和预期不符！');
  }
}

/// 多节点渲染对象，children 实例化的 RenderObject 对象会存放在 [renderBoxMap] 集合，
/// 你可以通过 [Key] 访问目标渲染对象，然后需要自行实现 [performLayout]、[paint]、[hitTestChildren] 方法
abstract class ElRenderMultiBox extends RenderProxyBox
    with ElMapRenderObjectMixin {
  ElRenderMultiBox({
    this.debugLabel = ElMultiWidget._debugLabel,
    this._sizedByParent,
  });

  String debugLabel;
  bool? _sizedByParent;

  void updateSizedByParent(bool? v) {
    if (_sizedByParent != v) {
      _sizedByParent = v;
      markNeedsLayout();
    }
  }

  @protected
  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  /// 若没有指定 child，那么大小将跟随父元素
  @override
  bool get sizedByParent => _sizedByParent ?? child == null;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    assert(
      constraints.biggest.isInfinite == false,
      '$debugLabel 没有指定 child 小部件，它的尺寸将跟随父元素，但是 parent 传递的约束为 infinity 无限大小: \n$constraints\n\n'
      '要修复此错误，请将 $debugLabel 包裹在有限尺寸的容器内，或者指定 child 小部件！',
    );
    return constraints.biggest;
  }

  @override
  void performLayout() {
    // 仅布局 child 代理小部件，你需要自行处理 children 布局逻辑
    if (child != null) {
      if (sizedByParent) {
        child!.layout(constraints);
      } else {
        child!.layout(constraints, parentUsesSize: true);
        size = constraints.constrain(child!.size);
      }
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData as BoxParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0.0, 1.0);
  }

  @override
  void dispose() {
    _sizedByParent = null;
    super.dispose();
  }
}

/// 使用 Map 集合保存 RenderObject 对象
mixin ElMapRenderObjectMixin on RenderObject {
  final Map<Key, RenderBox> renderBoxMap = {};

  void insert(Key key, RenderBox child) {
    adoptChild(child);
    renderBoxMap[key] = child;
  }

  void remove(Key key, RenderBox child) {
    dropChild(child);
    renderBoxMap.remove(key);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final child in renderBoxMap.values) {
      child.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    for (final child in renderBoxMap.values) {
      child.detach();
    }
  }

  @override
  void redepthChildren() {
    super.redepthChildren();
    for (final child in renderBoxMap.values) {
      redepthChild(child);
    }
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    super.visitChildren(visitor);
    for (final child in renderBoxMap.values) {
      visitor(child);
    }
  }

  @override
  void dispose() {
    renderBoxMap.clear();
    super.dispose();
  }
}

/// 切换多个子组件时会缓存旧的实例
class ElKeepAlive extends RenderObjectWidget {
  const ElKeepAlive({super.key, required this.child});

  /// 动态子组件，当每次更新子组件时，旧的组件依然会保留在 Element 树中（组件必须设置 key）
  final Widget child;

  @override
  RenderObjectElement createElement() => ElKeepAliveElement(this);

  @override
  ElRenderKeepAlive createRenderObject(BuildContext context) {
    assert(child.key != null, 'ElKeepAlive Error: child 需要设置 key');
    return ElRenderKeepAlive(key: child.key!);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant ElRenderKeepAlive renderObject,
  ) {
    assert(child.key != null, 'ElKeepAlive Error: child 需要设置 key');
    renderObject.key = child.key!;
  }
}

/// 按 Key 保留曾经挂载的子节点。
class ElKeepAliveElement extends RenderObjectElement {
  ElKeepAliveElement(super.widget);

  final Map<Key, Element?> children = {};

  @override
  ElKeepAlive get widget => super.widget as ElKeepAlive;

  @override
  ElRenderKeepAlive get renderObject => super.renderObject as ElRenderKeepAlive;

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final child in children.values) {
      if (child != null) visitor(child);
    }
  }

  @protected
  @override
  void forgetChild(Element child) {
    super.forgetChild(child);
    children.remove(child.slot);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    children[widget.child.key!] = updateChild(
      null,
      widget.child,
      widget.child.key,
    );
  }

  @override
  void update(ElKeepAlive newWidget) {
    super.update(newWidget);
    assert(
      newWidget.child.key != null,
      'ElKeepAliveElement update 出现错误，child 必须设置 key',
    );
    children[newWidget.child.key!] = updateChild(
      children[newWidget.child.key!],
      newWidget.child,
      newWidget.child.key,
    );
  }

  @override
  void unmount() {
    super.unmount();
    children.clear();
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) {
    renderObject.insert(slot as Key, child);
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object? slot) {
    renderObject.remove(slot as Key, child);
  }

  @override
  void moveRenderObjectChild(child, oldSlot, newSlot) {
    assert(false);
  }
}

/// 布局缓存子节点并仅绘制当前活动项。
class ElRenderKeepAlive extends RenderBox with ElMapRenderObjectMixin {
  ElRenderKeepAlive({required Key this._key});

  Key? _key;

  Key get key => _key!;

  set key(Key key) {
    if (_key == key) return;
    _key = key;
    markNeedsLayout();
  }

  RenderBox get child => renderBoxMap[key]!;

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = BoxParentData();
    }
  }

  @override
  void performLayout() {
    for (final child in renderBoxMap.values) {
      child.layout(constraints, parentUsesSize: true);
    }
    size = child.size;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.paintChild(child, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return child.hitTest(result, position: position);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData as BoxParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0.0, 1.0);
  }
}
