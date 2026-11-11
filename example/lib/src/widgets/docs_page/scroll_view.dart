import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport, ScrollDirection;
import 'package:flutter/scheduler.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../state/index.dart';

/// 将文档目录定位交给当前选择的滚动实现。
class DocScrollController {
  _DocViewportState? _state;

  /// 与目录双向绑定的小节下标，从零开始，不包含页首。
  final activeSection = ValueNotifier<int?>(null);

  /// 将指定文档条目移入视口，未挂载时不执行操作。
  Future<void> scrollToIndex(int index) => _state?._scrollToIndex(index) ?? Future<void>.value();

  /// 释放文档目录使用的模型。
  void dispose() => activeSection.dispose();
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
    this.outline,
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

  /// 随正文共用同一视口的宽屏目录。
  final Widget? outline;

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
        outline: outline,
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
    required this.outline,
  });

  final DocScrollMode mode;
  final int itemCount;
  final int templateCount;
  final int headerCount;
  final IndexedWidgetBuilder itemBuilder;
  final DocScrollController? controller;
  final EdgeInsets padding;
  final double gap;
  final Widget? outline;

  @override
  State<_DocViewport> createState() => _DocViewportState();
}

class _DocViewportState extends State<_DocViewport> {
  final _official = ScrollController();
  late List<GlobalKey> _keys;
  int _locateGeneration = 0;
  bool _locating = false;
  bool _keepLocatedSection = false;
  bool _activeSyncScheduled = false;
  bool _reportingActiveSection = false;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.itemCount, (_) => GlobalKey());
    _attachController();
  }

  @override
  void didUpdateWidget(_DocViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = !identical(oldWidget.controller, widget.controller);
    if (controllerChanged ||
        widget.itemCount != oldWidget.itemCount ||
        widget.headerCount != oldWidget.headerCount ||
        widget.templateCount != oldWidget.templateCount) {
      _locateGeneration++;
      _locating = false;
      _keepLocatedSection = false;
    }
    if (controllerChanged) _detachController(oldWidget.controller);
    if (widget.itemCount != oldWidget.itemCount) {
      _keys = List.generate(widget.itemCount, (index) => index < _keys.length ? _keys[index] : GlobalKey());
    }
    if (controllerChanged) _attachController();
    _scheduleActiveSectionSync();
  }

  void _attachController() {
    final controller = widget.controller;
    if (controller == null) return;
    controller._state = this;
    controller.activeSection.addListener(_onActiveSectionChanged);
    _scheduleActiveSectionSync();
  }

  void _detachController(DocScrollController? controller) {
    if (controller == null) return;
    controller.activeSection.removeListener(_onActiveSectionChanged);
    if (identical(controller._state, this)) controller._state = null;
  }

  void _onActiveSectionChanged() {
    if (_reportingActiveSection) return;
    final section = widget.controller?.activeSection.value;
    if (section == null || section < 0 || section >= widget.templateCount - widget.headerCount) return;
    unawaited(_scrollToIndex(widget.headerCount + section, keepSelection: true));
  }

  void _scheduleActiveSectionSync() {
    if (widget.controller == null || _locating || _keepLocatedSection || _activeSyncScheduled) return;
    _activeSyncScheduled = true;
    final scheduler = SchedulerBinding.instance;
    scheduler.addPostFrameCallback((_) {
      _activeSyncScheduled = false;
      if (!mounted || _locating || _keepLocatedSection || !_official.hasClients) return;
      _syncActiveSection();
    });
    scheduler.ensureVisualUpdate();
  }

  double? _offsetOf(int index) {
    final target = _keys[index].currentContext?.findRenderObject();
    if (target == null || !target.attached) return null;
    return RenderAbstractViewport.maybeOf(target)?.getOffsetToReveal(target, 0).offset;
  }

  int _activeItem(ScrollPosition position) {
    final first = widget.headerCount;
    final last = widget.itemCount - 1;
    if (position.pixels <= position.minScrollExtent + 1) return first;
    if (position.pixels >= position.maxScrollExtent - 1 && _offsetOf(last) != null) return last;
    final edge = position.pixels + 1;
    if (widget.mode == .officialVirtual) {
      // 虚拟列表只读取已挂载的小节，未布局的条目没有可用坐标。
      var active = first;
      for (var index = first; index <= last; index++) {
        final offset = _offsetOf(index);
        if (offset == null) continue;
        if (offset > edge) return (index - 1).clamp(first, last);
        active = index;
      }
      return active;
    }
    // 常驻文档的小节偏移按下标递增，滚动时只查找顶部附近的条目。
    var low = first;
    var high = last + 1;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      final offset = _offsetOf(middle);
      if (offset != null && offset <= edge) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return (low - 1).clamp(first, last);
  }

  void _syncActiveSection() {
    final model = widget.controller?.activeSection;
    if (model == null || !_official.position.hasContentDimensions) return;
    final count = widget.templateCount - widget.headerCount;
    final section = count == 0 ? null : (_activeItem(_official.position) - widget.headerCount) % count;
    if (model.value == section) return;
    _reportingActiveSection = true;
    try {
      model.value = section;
    } finally {
      _reportingActiveSection = false;
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final userScroll =
        notification is ScrollStartNotification && notification.dragDetails != null ||
        notification is UserScrollNotification && notification.direction != ScrollDirection.idle;
    if (_locating && userScroll) {
      _locateGeneration++;
      _locating = false;
    }
    if (notification is ScrollUpdateNotification || userScroll) {
      if (!_locating) _keepLocatedSection = false;
      _scheduleActiveSectionSync();
    }
    return false;
  }

  Widget _item(BuildContext context, int index) {
    final sourceIndex = index < widget.headerCount
        ? index
        : widget.headerCount + (index - widget.headerCount) % (widget.templateCount - widget.headerCount);
    final content = Padding(
      padding: .only(bottom: index == widget.itemCount - 1 ? 0 : widget.gap),
      child: widget.itemBuilder(context, sourceIndex),
    );
    final child = KeyedSubtree(
      key: _keys[index],
      child: SizeChangedLayoutNotifier(child: content),
    );
    // 各个小节独立隔离重绘，状态与目录 Key 归逻辑小节持有。
    return RepaintBoundary(child: child);
  }

  Future<void> _scrollToIndex(int index, {bool keepSelection = false}) async {
    if (index < 0 || index >= widget.itemCount || !_official.hasClients) return;
    final generation = ++_locateGeneration;
    if (_locating) _official.jumpTo(_official.offset);
    _locating = true;
    var located = false;
    try {
      // 官方虚拟列表没有未知高度的索引定位，先逐屏接近，挂载后再对齐。
      for (var attempt = 0; attempt < widget.itemCount * 4 + 4; attempt++) {
        if (!mounted || generation != _locateGeneration || !_official.hasClients) return;
        final position = _official.position;
        final target = _keys[index].currentContext?.findRenderObject();
        if (target != null && target.attached) {
          // 只滚动本文档的视口，独立示例嵌在正文中时不会连带移动外层。
          await position.ensureVisible(target, duration: Duration(milliseconds: 220), curve: Curves.easeOutCubic);
          located = true;
          return;
        }
        final firstMounted = _keys.indexWhere((key) => key.currentContext != null);
        final direction = firstMounted >= 0 && index < firstMounted ? -1 : 1;
        final next = attempt == 0 && widget.itemCount > 1
            ? position.maxScrollExtent * index / (widget.itemCount - 1)
            : position.pixels + position.viewportDimension * .8 * direction;
        final clamped = next.clamp(position.minScrollExtent, position.maxScrollExtent);
        if (attempt > 0 && (clamped - position.pixels).abs() < .01) return;
        position.jumpTo(clamped);
        await SchedulerBinding.instance.endOfFrame;
      }
    } finally {
      if (mounted && generation == _locateGeneration) {
        _locating = false;
        // 页尾可能夹紧定位偏移，保留点击的条目，直到视口再次移动或正文重排。
        _keepLocatedSection = located && keepSelection;
        _scheduleActiveSectionSync();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewport = _pageScroll(context);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) _scheduleActiveSectionSync();
          return false;
        },
        child: NotificationListener<SizeChangedLayoutNotification>(
          onNotification: (_) {
            _keepLocatedSection = false;
            _scheduleActiveSectionSync();
            return false;
          },
          child: viewport,
        ),
      ),
    );
  }

  Widget _pageScroll(BuildContext context) {
    final body = SliverPadding(
      padding: widget.padding,
      sliver: switch (widget.mode) {
        .official => SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: .stretch,
            mainAxisSize: .min,
            children: [for (var i = 0; i < widget.itemCount; i++) _item(context, i)],
          ),
        ),
        .officialVirtual => SliverList.builder(
          itemCount: widget.itemCount,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          itemBuilder: _item,
        ),
        .elScroll || .sliverList => ElSliverList(
          stretch: widget.mode == .elScroll,
          children: [for (var i = 0; i < widget.itemCount; i++) _item(context, i)],
        ),
      },
    );
    final outline = widget.outline;
    return ElScroll.sliver(
      controller: _official,
      slivers: [
        if (outline == null)
          body
        else
          // 目录与正文共用视口，目录上的滚轮也走同一个 ElScroll。
          SliverCrossAxisGroup(
            slivers: [
              SliverCrossAxisExpanded(flex: 1, sliver: body),
              SliverConstrainedCrossAxis(maxExtent: 168, sliver: PinnedHeaderSliver(child: outline)),
            ],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _locateGeneration++;
    _detachController(widget.controller);
    _official.dispose();
    super.dispose();
  }
}
