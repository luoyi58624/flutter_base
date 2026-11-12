part of 'sliver.dart';

abstract class _EagerSliver extends MultiChildRenderObjectWidget {
  const _EagerSliver({
    super.key,
    required super.children,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  });

  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;

  @override
  MultiChildRenderObjectElement createElement() => _EagerElement(this);
}

// 保留公开 children 的原始实例，包装仅发生在挂载和配置更新时，不进入滚动布局路径。
class _EagerElement extends MultiChildRenderObjectElement {
  _EagerElement(_EagerSliver super.widget);
  bool _updatingChildren = false;
  late SliverChildListDelegate _delegate;

  void _configure() {
    final config = widget as _EagerSliver;
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
}
