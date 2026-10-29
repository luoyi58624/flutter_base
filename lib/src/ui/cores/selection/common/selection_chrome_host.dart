import 'dart:async' show Completer;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../view/render/hit_bounds.dart' show ElOverflowHitBounds;

/// 选区 chrome 四周的溢出留白（handle / toolbar 可越出选区盒）。
const double selectionChromeOverflowPad = 48.0;

/// 选区 chrome 的挂载句柄。
///
/// 只服务选区：挂载/原位更新/幂等关闭；不承载通用层序、遮挡或指针仲裁。
abstract interface class SelectionChromeHandle {
  /// chrome 是否仍在宿主中展示。
  bool get isOpen;

  /// chrome 被摘除后完成。
  Future<void> get closed;

  /// 原位替换 chrome 内容。
  void update(WidgetBuilder builder);

  /// 摘除 chrome；重复调用 no-op。
  void close();
}

/// 选区 chrome 的宿主契约。
///
/// 宿主负责回答「挂到哪里、坐标怎么换算、所属容器是否仍有效」，
/// 不参与选区的几何与手势。
abstract interface class SelectionChromeMountHost {
  /// 当前是否允许挂载（如所属弹层已隐藏/关闭时返回 false）。
  bool get canMount;

  /// 宿主自身状态变化通知；无则为 null。
  Listenable? get stateListenable;

  /// 把 Flutter View 全局坐标换算到 chrome 坐标。
  Offset? globalToLocal(Offset global);

  /// 挂载一份 chrome，返回生命周期句柄。
  SelectionChromeHandle mount(BuildContext context, {required WidgetBuilder builder});
}

/// 选区 chrome 的树内 slot。
///
/// 页面/弹层内容根注入一个即可：选区 chrome 优先挂到这里，避免依赖
/// 跨树弹层层序。
class SelectionChromeSlot extends InheritedWidget {
  /// 创建 slot。
  const SelectionChromeSlot({super.key, required this.host, required super.child});

  /// 宿主实现。
  final SelectionChromeMountHost host;

  /// 向上查找最近的 slot。
  static SelectionChromeMountHost? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SelectionChromeSlot>()?.host;

  @override
  bool updateShouldNotify(SelectionChromeSlot oldWidget) => !identical(host, oldWidget.host);
}

/// 树内 slot 宿主：包裹内容，把选区 chrome 作为内容之上的兄弟层挂载。
///
/// 放在页面或弹层内容根、滚动容器之外，让句柄越过滚动裁剪。
/// 未提供宿主时，选区在自身内容旁挂载句柄。
class SelectionChromeSlotHost extends StatefulWidget {
  /// 创建独立选区宿主，放在页面或弹层内容根且位于滚动容器之外。
  const SelectionChromeSlotHost({super.key, this.enabled = true, required this.child});

  /// 是否允许显示选区附属层；内容退场或隐藏时关闭。
  final bool enabled;

  /// 页面或弹层内容。
  final Widget child;

  @override
  State<SelectionChromeSlotHost> createState() => _SelectionHostState();
}

class _SlotMount {
  _SlotMount(this.builder);

  final Object key = Object();
  WidgetBuilder builder;
}

class _SelectionHostState extends State<SelectionChromeSlotHost> implements SelectionChromeMountHost {
  final List<_SlotMount> _mounts = <_SlotMount>[];
  final Set<_SlotHandle> _handles = <_SlotHandle>{};
  late final ValueNotifier<bool> _changes = ValueNotifier(widget.enabled);
  SelectionChromeMountHost? _parentHost;
  bool _rebuildScheduled = false;

  @override
  bool get canMount => mounted && widget.enabled && (_parentHost?.canMount ?? true);

  @override
  Listenable get stateListenable => _changes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = SelectionChromeSlot.maybeOf(context);
    if (identical(parent, _parentHost)) return;
    _parentHost?.stateListenable?.removeListener(_handleParentChanged);
    _parentHost = parent;
    parent?.stateListenable?.addListener(_handleParentChanged);
    _changes.value = canMount;
  }

  void _handleParentChanged() {
    _changes.value = canMount;
    _rebuild();
  }

  @override
  void didUpdateWidget(covariant SelectionChromeSlotHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _changes.value = canMount;
  }

  @override
  void dispose() {
    _parentHost?.stateListenable?.removeListener(_handleParentChanged);
    for (final handle in _handles.toList()) {
      handle._finish();
    }
    _handles.clear();
    _mounts.clear();
    _changes.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (!mounted || _rebuildScheduled) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      _rebuildScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _rebuildScheduled = false;
        if (mounted) setState(() {});
      });
      SchedulerBinding.instance.ensureVisualUpdate();
      return;
    }
    setState(() {});
  }

  @override
  Offset? globalToLocal(Offset global) {
    final render = context.findRenderObject();
    if (render is RenderBox && render.attached && render.hasSize) return render.globalToLocal(global);
    return null;
  }

  @override
  SelectionChromeHandle mount(BuildContext context, {required WidgetBuilder builder}) {
    final mount = _SlotMount(builder);
    _mounts.add(mount);
    final handle = _SlotHandle(this, mount);
    _handles.add(handle);
    _rebuild();
    return handle;
  }

  void _update(_SlotMount mount, WidgetBuilder builder) {
    mount.builder = builder;
    _rebuild();
  }

  void _remove(_SlotMount mount) {
    if (!_mounts.remove(mount)) return;
    _rebuild();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionChromeSlot(
      host: this,
      child: SelectionChromeHost(
        content: widget.child,
        chromePadding: 0,
        chromes: [
          if (canMount)
            for (final mount in _mounts) Builder(key: ValueKey<Object>(mount.key), builder: mount.builder),
        ],
      ),
    );
  }
}

class _SlotHandle implements SelectionChromeHandle {
  _SlotHandle(this._host, this._mount);

  final _SelectionHostState _host;
  final _SlotMount _mount;
  final Completer<void> _closed = Completer<void>();
  bool _open = true;

  @override
  bool get isOpen => _open && _host.canMount;

  @override
  Future<void> get closed => _closed.future;

  @override
  void update(WidgetBuilder builder) {
    if (!_open) return;
    _host._update(_mount, builder);
  }

  @override
  void close() {
    if (!_open) return;
    _host._remove(_mount);
    _host._handles.remove(this);
    _finish();
  }

  void _finish() {
    _open = false;
    if (!_closed.isCompleted) _closed.complete();
  }
}

/// 将正文和选区附属层挂为兄弟节点的渲染桥。
class SelectionChromeHost extends MultiChildRenderObjectWidget {
  /// 创建渲染桥；原位附属层预留溢出，提升后的附属层自行处理留白。
  SelectionChromeHost({
    super.key,
    required Widget content,
    Widget? chrome,
    Iterable<Widget> chromes = const [],
    this.chromePadding = selectionChromeOverflowPad,
  }) : super(children: [content, ?chrome, ...chromes]);

  /// 附属层相对正文盒的四周留白。
  final double chromePadding;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSelectionChromeHost(chromePadding);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSelectionChromeHost).chromePadding = chromePadding;
  }
}

class _ChromeHostParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderSelectionChromeHost extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ChromeHostParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ChromeHostParentData>,
        ElOverflowHitBounds {
  _RenderSelectionChromeHost(this._chromePadding);

  double _chromePadding;

  set chromePadding(double value) {
    if (_chromePadding == value) return;
    _chromePadding = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ChromeHostParentData) {
      child.parentData = _ChromeHostParentData();
    }
  }

  RenderBox get _content => firstChild!;

  @override
  Rect get selfHitRect => Offset.zero & size;

  @override
  bool get clipsHitBounds => false;

  @override
  void visitHitBoundsChildren(void Function(RenderBox child, Offset offset) visitor) {
    var child = firstChild;
    while (child != null) {
      visitor(child, (child.parentData! as _ChromeHostParentData).offset);
      child = childAfter(child);
    }
  }

  @override
  void performLayout() {
    markHitBoundsDirty();
    final content = _content;
    content.layout(constraints, parentUsesSize: true);
    size = content.size;
    var chrome = childAfter(content);
    while (chrome != null) {
      (chrome.parentData! as _ChromeHostParentData).offset = Offset(-_chromePadding, -_chromePadding);
      chrome.layout(BoxConstraints.tight(Size(size.width + _chromePadding * 2, size.height + _chromePadding * 2)));
      chrome = childAfter(chrome);
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => _content.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) => _content.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => _content.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _content.getMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) => _content.getDryLayout(constraints);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position) && !hitBoundsContains(position)) return false;
    final hit = hitTestChildren(result, position: position);
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
