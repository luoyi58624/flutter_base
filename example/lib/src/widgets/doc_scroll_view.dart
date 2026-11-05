import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../state/index.dart';

/// 将文档目录定位交给当前选择的滚动实现。
class DocScrollController {
  _DocViewportState? _state;

  /// 将指定文档条目移入视口，未挂载时不执行操作。
  Future<void> scrollToIndex(int index) => _state?._scrollToIndex(index) ?? Future<void>.value();
}

/// 根据系统设置为文档正文选择统一的滚动实现。
class DocScrollView extends StatelessWidget {
  /// 创建共用内容、间距和内边距的文档滚动区域。
  // 示例保持普通构造，遵循仓库示例不添加 const 的约定。
  // ignore: prefer_const_constructors_in_immutables
  DocScrollView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding = EdgeInsets.zero,
    this.gap = 0,
    this.headerCount = 0,
  }) : assert(itemCount >= 0),
       assert(headerCount >= 0 && headerCount <= itemCount),
       assert(gap >= 0 && gap.isFinite);

  /// 文档中包含标题在内的条目数量。
  final int itemCount;

  /// 四种实现共用的条目内容工厂。
  final IndexedWidgetBuilder itemBuilder;

  /// 可选的目录定位控制器。
  final DocScrollController? controller;

  /// 所有滚动实现共用的正文内边距。
  final EdgeInsets padding;

  /// 相邻条目之间的距离，末项不增加间隔。
  final double gap;

  /// 压力重复时只保留一份的页首条目数量。
  final int headerCount;

  @override
  Widget build(BuildContext context) => ObsBuilder(
    builder: (context) {
      final mode = GlobalState.docScrollMode.value;
      final repeat = GlobalState.docRepeatCount.value;
      return _DocViewport(
        key: ValueKey((mode, repeat)),
        mode: mode,
        itemCount: headerCount + (itemCount - headerCount) * repeat,
        templateCount: itemCount,
        headerCount: headerCount,
        itemBuilder: itemBuilder,
        controller: controller,
        padding: padding,
        gap: gap,
      );
    },
  );
}

class _DocViewport extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _DocViewport({
    required super.key,
    required this.mode,
    required this.itemCount,
    required this.templateCount,
    required this.headerCount,
    required this.itemBuilder,
    required this.controller,
    required this.padding,
    required this.gap,
  });

  final DocScrollMode mode;
  final int itemCount;
  final int templateCount;
  final int headerCount;
  final IndexedWidgetBuilder itemBuilder;
  final DocScrollController? controller;
  final EdgeInsets padding;
  final double gap;

  @override
  State<_DocViewport> createState() => _DocViewportState();
}

class _DocViewportState extends State<_DocViewport> {
  final _official = ScrollController();
  final _el = ElScrollController();
  rv.RecyclerView? _recycler;
  late List<GlobalKey> _keys;
  int _locateGeneration = 0;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.itemCount, (_) => GlobalKey());
    widget.controller?._state = this;
    if (widget.mode == DocScrollMode.recyclerView) {
      _recycler = rv.RecyclerView()..setLayoutManager(rv.LinearLayoutManager(context));
      _updateAdapter();
    }
  }

  @override
  void didUpdateWidget(_DocViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _locateGeneration++;
      if (identical(oldWidget.controller?._state, this)) oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
    if (widget.itemCount != oldWidget.itemCount) {
      _locateGeneration++;
      _keys = List.generate(widget.itemCount, (index) => index < _keys.length ? _keys[index] : GlobalKey());
    }
    if (widget.itemCount != oldWidget.itemCount ||
        widget.itemBuilder != oldWidget.itemBuilder ||
        widget.gap != oldWidget.gap) {
      _updateAdapter();
    }
  }

  void _updateAdapter() => _recycler?.setAdapter(
    _DocItemsAdapter(
      count: widget.itemCount,
      templateCount: widget.templateCount,
      headerCount: widget.headerCount,
      gap: widget.gap,
      itemBuilder: widget.itemBuilder,
    ),
  );

  Widget _item(BuildContext context, int index) {
    final sourceIndex = index < widget.headerCount
        ? index
        : widget.headerCount + (index - widget.headerCount) % (widget.templateCount - widget.headerCount);
    final child = KeyedSubtree(
      key: _keys[index],
      child: Padding(
        padding: .only(bottom: index == widget.itemCount - 1 ? 0 : widget.gap),
        child: widget.itemBuilder(context, sourceIndex),
      ),
    );
    // RecyclerView 由内核提供每项边界，其他实现统一在这里隔离重绘。
    return RepaintBoundary(child: child);
  }

  Future<void> _scrollToIndex(int index) async {
    if (index < 0 || index >= widget.itemCount) return;
    final generation = ++_locateGeneration;
    if (widget.mode == DocScrollMode.elScrollView) {
      _el.scrollToIndex(index);
      return;
    }
    if (widget.mode == DocScrollMode.recyclerView) {
      _recycler?.scrollToPosition(index);
      return;
    }
    // 官方虚拟列表没有未知高度的索引定位，目录点击时逐屏接近，挂载后再精确对齐。
    for (var attempt = 0; attempt < widget.itemCount * 4 + 4; attempt++) {
      if (!mounted || generation != _locateGeneration || !_official.hasClients) return;
      final target = _keys[index].currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(target, alignment: 0);
        return;
      }
      final mountedIndices = [
        for (var i = 0; i < _keys.length; i++)
          if (_keys[i].currentContext != null) i,
      ];
      final position = _official.position;
      final double next;
      if (attempt == 0 && widget.itemCount > 1) {
        next = position.maxScrollExtent * index / (widget.itemCount - 1);
      } else {
        final direction = mountedIndices.isNotEmpty && index < mountedIndices.first ? -1 : 1;
        next = position.pixels + position.viewportDimension * .8 * direction;
      }
      final clamped = next.clamp(0.0, position.maxScrollExtent);
      if (attempt > 0 && (clamped - position.pixels).abs() < .01) return;
      _official.jumpTo(clamped);
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) => switch (widget.mode) {
    .official => SingleChildScrollView(
      controller: _official,
      primary: false,
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [for (var i = 0; i < widget.itemCount; i++) _item(context, i)],
      ),
    ),
    .officialVirtual => NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 && notification.dragDetails != null) _locateGeneration++;
        return false;
      },
      child: ListView.builder(
        controller: _official,
        primary: false,
        padding: widget.padding,
        itemCount: widget.itemCount,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        itemBuilder: _item,
      ),
    ),
    .elScrollView => ElScrollView(
      controller: _el,
      padding: widget.padding,
      children: [ElListView.builder(keepAlive: false, itemCount: widget.itemCount, itemBuilder: _item)],
    ),
    .recyclerView =>
      _recycler!..setPadding(widget.padding.left, widget.padding.top, widget.padding.right, widget.padding.bottom),
  };

  @override
  void dispose() {
    _locateGeneration++;
    if (identical(widget.controller?._state, this)) widget.controller?._state = null;
    _official.dispose();
    _el.dispose();
    super.dispose();
  }
}

class _DocItemsAdapter extends rv.Adapter<_DocItemHolder> {
  _DocItemsAdapter({
    required this.count,
    required this.templateCount,
    required this.headerCount,
    required this.gap,
    required this.itemBuilder,
  });
  final int count;
  final int templateCount;
  final int headerCount;
  final double gap;
  final IndexedWidgetBuilder itemBuilder;

  @override
  int getItemCount() => count;

  @override
  int getItemViewType(int position) =>
      position < headerCount ? position : headerCount + (position - headerCount) % (templateCount - headerCount);

  @override
  _DocItemHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) =>
      _DocItemHolder(Builder(builder: (context) => itemBuilder(context, viewType)));

  @override
  void onBindViewHolder(_DocItemHolder holder, int position, [List<Object> payloads = const []]) {
    // 重复项共享结构类型，各 holder 保留独立子树，绑定只更新位置决定的间隔。
    holder.gap.value = position == count - 1 ? 0 : gap;
  }
}

class _DocItemHolder extends rv.ViewHolder {
  _DocItemHolder(Widget template) : this._(template, ValueNotifier<double>(0));

  _DocItemHolder._(Widget template, this.gap)
    : super(
        ValueListenableBuilder<double>(
          valueListenable: gap,
          child: template,
          builder: (context, value, child) => Padding(
            padding: .only(bottom: value),
            child: child,
          ),
        ),
      );

  final ValueNotifier<double> gap;
}
