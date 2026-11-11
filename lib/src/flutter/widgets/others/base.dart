import 'package:collection/collection.dart' show ListEquality;

import '../../commons/index.dart';

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
  const ElChildIndex({super.key, required super.child, required this.index, this.start, this.end, this.length});

  /// 当前索引
  final int index;

  /// 迭代元素起始索引，非必需，使用前请确认是否注入
  final int? start;

  /// 迭代元素结束索引，非必需，使用前请确认是否注入
  final int? end;

  /// 迭代元素总长度，非必需，使用前请确认是否注入
  final int? length;

  bool get isStart => index == start;

  bool get isEnd => index == end;

  static ElChildIndex? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ElChildIndex>();

  static ElChildIndex of(BuildContext context) {
    final ElChildIndex? result = maybeOf(context);
    assert(result != null, 'No ElChildIndex found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ElChildIndex oldWidget) =>
      index != oldWidget.index || start != oldWidget.start || end != oldWidget.end || length != oldWidget.length;
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

  /// 精确选择监听数据；默认比较会在通知时提前求值，须使用无副作用的读取并返回不可变结果。
  ///
  /// 选择值未变时跳过通知引起的重建；父配置或继承环境变化仍正常更新，例如：
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

  /// 在构建阶段比较最新选择值与上次观察值，自定义条件可允许等值重建，例如：
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

  /// 选择数据需要更新或父配置、继承环境变化时构建子树。
  final TransitionBuilder builder;

  /// 如果构建函数 [builder] 包含不依赖 [listenable] 的子树，那么在此处设置它可以跳过重建
  final Widget? child;

  @override
  Element createElement() => _ListenableElement<L, D>(this);
}

class _ListenableElement<L extends Listenable, D> extends ComponentElement {
  _ListenableElement(super.widget);

  @override
  ElListenableBuilder<L, D> get widget => super.widget as ElListenableBuilder<L, D>;

  /// 缓存旧的 Widget 实例，当 [_oldValue] 与新值一样时，将不会重新执行 builder 代码块
  Widget? _oldWidget;
  dynamic _oldValue;
  bool _selecting = false;
  bool _active = true;

  void _invalidateCache() {
    _oldWidget = null;
    _oldValue = null;
  }

  @override
  void reassemble() {
    _invalidateCache();
    super.reassemble();
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    widget.listenable?.addListener(_handleChange);
  }

  @override
  void update(ElListenableBuilder<L, D> newWidget) {
    final oldListenable = widget.listenable;
    final changed = oldListenable != newWidget.listenable;
    if (changed) oldListenable?.removeListener(_handleChange);
    super.update(newWidget);
    _invalidateCache();
    if (changed) newWidget.listenable?.addListener(_handleChange);
    rebuild(force: true);
  }

  @override
  void didChangeDependencies() {
    _invalidateCache();
    super.didChangeDependencies();
  }

  @override
  void deactivate() {
    _active = false;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _active = true;
    _invalidateCache();
    markNeedsBuild();
  }

  @override
  void unmount() {
    widget.listenable?.removeListener(_handleChange);
    _invalidateCache();
    super.unmount();
  }

  void _handleChange() {
    if (!mounted || !_active || dirty) return;
    final listenable = widget.listenable;
    final select = widget.select;
    // 自定义条件仍在 build 时比较，保留同帧合并及上次观察值的语义。
    if (_oldWidget != null && listenable != null && select != null && widget.shouldRebuild == null && !_selecting) {
      var unchanged = false;
      _selecting = true;
      try {
        unchanged = select(listenable) == _oldValue;
      } catch (_) {
        // 通知期间的临时读取失败退回构建阶段，由 Flutter 正常报告仍存在的错误。
      } finally {
        _selecting = false;
      }
      if (unchanged) return;
    }
    markNeedsBuild();
  }

  @override
  Widget build() {
    try {
      if (widget.listenable == null || widget.select == null) {
        return widget.builder(this, widget.child);
      }
      if (_oldWidget == null) {
        _oldWidget = widget.builder(this, widget.child);
        _oldValue = widget.select!(widget.listenable!);
        return _oldWidget!;
      }
      final newValue = widget.select!(widget.listenable!);
      final shouldRebuild = widget.shouldRebuild;
      final changed = shouldRebuild != null ? shouldRebuild(newValue, _oldValue) == true : newValue != _oldValue;
      _oldValue = newValue;
      if (changed) _oldWidget = widget.builder(this, widget.child);
      return _oldWidget!;
    } catch (_) {
      // 错误子树不属于有效缓存，下次合法通知即使同值也必须能够恢复。
      _invalidateCache();
      rethrow;
    }
  }
}
