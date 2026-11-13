import 'package:flutter/widgets.dart';

import 'child_source.dart';
import 'layout.dart';
import 'render.dart';

/// children 生命周期：全部子项常驻，构建留在框架的 build 阶段。
abstract class EagerSliver extends MultiChildRenderObjectWidget {
  const EagerSliver({
    super.key,
    required super.children,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  });

  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;

  SliverLayoutSpec get spec;

  int get itemCount => children.length;

  @override
  MultiChildRenderObjectElement createElement() => EagerElement(this);

  @override
  RenderNaturalSliver createRenderObject(BuildContext context) => RenderNaturalSliver(context as EagerElement, spec);

  @override
  void updateRenderObject(BuildContext context, RenderNaturalSliver renderObject) => renderObject.spec = spec;
}

// 保留公开 children 的原始实例，包装仅发生在挂载和配置更新时，不进入滚动布局路径。
class EagerElement extends MultiChildRenderObjectElement implements SliverChildSource {
  EagerElement(EagerSliver super.widget);

  bool _updatingChildren = false;
  late SliverChildListDelegate _delegate;
  // 按序号随机访问子盒；结构变化时失效，下次访问沿渲染器的子链表重建。
  List<RenderBox>? _boxes;

  void _configure() {
    final config = widget as EagerSliver;
    _delegate = SliverChildListDelegate(
      config.children,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: config.addRepaintBoundaries,
      addSemanticIndexes: config.addSemanticIndexes,
    );
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    _configure();
    super.mount(parent, newSlot);
  }

  @override
  Element inflateWidget(Widget newWidget, Object? newSlot) => super.inflateWidget(
    _updatingChildren ? newWidget : _delegate.build(this, (newSlot as IndexedSlot<Element?>).index)!,
    newSlot,
  );

  @override
  List<Element> updateChildren(
    List<Element> oldChildren,
    List<Widget> newWidgets, {
    Set<Element>? forgottenChildren,
    List<Object?>? slots,
  }) {
    _configure();
    _updatingChildren = true;
    try {
      return super.updateChildren(
        oldChildren,
        List.generate(newWidgets.length, (index) => _delegate.build(this, index)!),
        forgottenChildren: forgottenChildren,
        slots: slots,
      );
    } finally {
      _updatingChildren = false;
    }
  }

  @override
  void insertRenderObjectChild(RenderObject child, IndexedSlot<Element?> slot) {
    _boxes = null;
    super.insertRenderObjectChild(child, slot);
  }

  @override
  void moveRenderObjectChild(RenderObject child, IndexedSlot<Element?> oldSlot, IndexedSlot<Element?> newSlot) {
    _boxes = null;
    super.moveRenderObjectChild(child, oldSlot, newSlot);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    _boxes = null;
    super.removeRenderObjectChild(child, slot);
  }

  List<RenderBox> get _children {
    if (_boxes case final boxes?) return boxes;
    final render = renderObject as RenderNaturalSliver;
    final boxes = <RenderBox>[];
    for (var child = render.firstChild; child != null; child = render.childAfter(child)) {
      boxes.add(child);
    }
    return _boxes = boxes;
  }

  @override
  int get childCount => _children.length;

  @override
  bool get mountsAll => true;

  @override
  int get generation => 0;

  @override
  bool get hasTypes => false;

  @override
  Object? typeOf(int index) => null;

  @override
  bool beginLayout() => false;

  @override
  void prepareWindow(List<int> window) {}

  @override
  RenderBox layoutChild(int index, BoxConstraints constraints) =>
      _children[index]..layout(constraints, parentUsesSize: true);

  @override
  void endLayout(List<int> window) {}

  @override
  RenderBox? childAt(int index) => _children[index];

  @override
  Iterable<RenderBox> get parked => const [];
}
