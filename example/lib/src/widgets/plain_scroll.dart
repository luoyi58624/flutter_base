import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

final _plainDistance = 200.0;
final _plainDelay = Duration(milliseconds: 100);

/// 让普通滚动在目录定位前把目标条目挂上。
class ExamplePlainHandle {
  _ExamplePlainScrollState? _state;

  /// 挂到包含 [index] 的那一批，并把它滚进视口。
  Future<void> ensure(int index) => _state?.reveal(index) ?? Future<void>.value();
}

/// 普通滚动：每批固定条数留在树上，接近末端再追加下一批。
class ExamplePlainScroll extends StatefulWidget {
  /// [itemBuilder] 按绝对下标取条目，[maxCount] 是这批数据的上限。
  // ignore: prefer_const_constructors_in_immutables
  ExamplePlainScroll({
    super.key,
    required this.itemBuilder,
    required this.maxCount,
    this.controller,
    this.reverse = false,
    this.pageSize = 100,
    this.physics,
    this.padding = EdgeInsets.zero,
    this.leading = const [],
    this.revision,
    this.handle,
  });

  /// 按绝对下标创建一条。
  final IndexedWidgetBuilder itemBuilder;

  /// 可追加的最大条数，到顶后不再加载。
  final int maxCount;

  /// 外部滚动控制器；不传时内部自建。
  final ScrollController? controller;

  /// 为真时窗口贴着数据末尾，向前追加更早的条目。
  final bool reverse;

  /// 每一批挂上的条数。
  final int pageSize;

  /// 滚动物理效果。
  final ScrollPhysics? physics;

  /// 列表内边距。
  final EdgeInsets padding;

  /// 放在分批内容之前的固定头部。
  final List<Widget> leading;

  /// 数据身份变化时丢弃已缓存的批次。
  final Object? revision;

  /// 外部用来把某一条滚进视口。
  final ExamplePlainHandle? handle;

  @override
  State<ExamplePlainScroll> createState() => _ExamplePlainScrollState();
}

class _ExamplePlainScrollState extends State<ExamplePlainScroll> {
  ScrollController? _owned;
  int _loaded = 0;
  int _ticket = 0;
  bool _loading = false;
  Object? _appliedRevision;

  ScrollController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _owned = ScrollController();
    _loaded = math.min(widget.pageSize, math.max(0, widget.maxCount));
    _controller.addListener(_maybeLoad);
    widget.handle?._state = this;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoad();
    });
  }

  @override
  void didUpdateWidget(ExamplePlainScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_maybeLoad);
      if (widget.controller == null) {
        _owned ??= ScrollController();
      } else {
        _owned?.dispose();
        _owned = null;
      }
      _controller.addListener(_maybeLoad);
    }
    if (oldWidget.handle != widget.handle) {
      if (oldWidget.handle?._state == this) oldWidget.handle?._state = null;
      widget.handle?._state = this;
    }
    if (widget.maxCount < _loaded) {
      _loaded = math.max(0, widget.maxCount);
    } else if (_loaded == 0 && widget.maxCount > 0) {
      _loaded = math.min(widget.pageSize, widget.maxCount);
    }
  }

  @override
  void dispose() {
    _ticket++;
    if (widget.handle?._state == this) widget.handle?._state = null;
    _controller.removeListener(_maybeLoad);
    _owned?.dispose();
    super.dispose();
  }

  /// 距末端不足 200px 时，等 100ms 再挂上下一批。
  void _maybeLoad() {
    if (_loading || _loaded >= widget.maxCount) return;
    final controller = _controller;
    if (!controller.hasClients || !controller.position.hasContentDimensions) return;
    final position = controller.position;
    if (position.maxScrollExtent - position.pixels > _plainDistance) return;
    _loading = true;
    final ticket = ++_ticket;
    Future<void>.delayed(_plainDelay, () {
      if (!mounted || ticket != _ticket) return;
      setState(() => _loaded = math.min(widget.maxCount, _loaded + widget.pageSize));
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeLoad();
      });
    });
  }

  /// 把 [index] 所在的批次挂上，再滚到带有相同下标键的条目。
  Future<void> reveal(int index) async {
    if (widget.maxCount <= 0) return;
    final target = index.clamp(0, widget.maxCount - 1);
    final need = widget.reverse
        ? math.min(
            widget.maxCount,
            ((widget.maxCount - target + widget.pageSize - 1) ~/ widget.pageSize) * widget.pageSize,
          )
        : math.min(widget.maxCount, (target ~/ widget.pageSize + 1) * widget.pageSize);
    if (_loaded < need) {
      setState(() => _loaded = need);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final key = ValueKey<int>(target);
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget.key == key) {
        found = element;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    final element = found;
    final box = element?.renderObject;
    final viewport = _controller.position.context.notificationContext?.findRenderObject();
    if (box is! RenderBox || viewport is! RenderBox || !box.hasSize || !box.attached || !viewport.attached) return;
    final delta = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final position = _controller.position;
    _controller.jumpTo((position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent));
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  Widget build(BuildContext context) {
    final refresh = _appliedRevision != widget.revision;
    _appliedRevision = widget.revision;
    final start = widget.reverse ? widget.maxCount - _loaded : 0;
    final chunks = <Widget>[];
    var offset = 0;
    while (offset < _loaded) {
      final count = math.min(widget.pageSize, _loaded - offset);
      final chunkStart = start + offset;
      chunks.add(
        ElRebuildWidget(
          key: ValueKey('plain-$chunkStart'),
          shouldRebuild: refresh ? (_, _) => true : null,
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [for (var index = 0; index < count; index++) widget.itemBuilder(context, chunkStart + index)],
            ),
          ),
        ),
      );
      offset += count;
    }
    return ElScroll(
      controller: _controller,
      reverse: widget.reverse,
      physics: widget.physics,
      padding: widget.padding,
      children: [...widget.leading, ...chunks],
    );
  }
}
