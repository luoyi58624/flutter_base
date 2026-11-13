import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart' show ElTabController;

import '../navigation_header/actions.dart';

const _pink = Color(0xfffb7299);
const _ink = Color(0xff5d6269);
const _line = Color(0xffecedf0);
const _channelHeight = 43.0;
const _menuWidth = 42.0;
const _compactSearchWidth = 40.0;
const _fadeWidth = 19.0;
const _endInset = 4.0;
const _indicatorWidth = 22.0;

/// Bibi 的频道标签、选中指示器和随折叠进度出现的搜索入口。
class BibiChannelBar extends StatefulWidget {
  /// 用 [progress] 驱动右侧搜索按钮，并跟随 [pager] 绘制选中状态。
  const BibiChannelBar({
    required this.progress,
    required this.pager,
    required this.channels,
    required this.onSelect,
    required this.onSearch,
  });

  final double progress;
  final ElTabController pager;
  final List<String> channels;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;

  @override
  State<BibiChannelBar> createState() => _ChannelRailState();
}

class _ChannelRailState extends State<BibiChannelBar> {
  final _scroll = ScrollController(keepScrollOffset: false);
  late int _selected;
  late double _page;
  ({double page, double offset})? _centerStart;
  double? _outerWidth;
  bool _centeringScheduled = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.pager.index;
    _page = _pagePosition;
    widget.pager.addListener(_handlePage);
  }

  @override
  void didUpdateWidget(covariant BibiChannelBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pager != widget.pager) {
      oldWidget.pager.removeListener(_handlePage);
      _selected = widget.pager.index;
      _page = _pagePosition;
      _centerStart = null;
      widget.pager.addListener(_handlePage);
      _scheduleCenter();
    }
  }

  @override
  void dispose() {
    widget.pager.removeListener(_handlePage);
    _scroll.dispose();
    super.dispose();
  }

  double _tabWidth(double outerWidth) =>
      widget.channels.isEmpty ? 50 : math.max(50, (outerWidth - _menuWidth - _endInset) / widget.channels.length);

  double get _pagePosition => widget.pager.position.clamp(0.0, math.max(0, widget.channels.length - 1)).toDouble();

  void _handlePage() {
    final pager = widget.pager;
    final page = _pagePosition;
    if (page != _page) {
      _followPage(page);
      _page = page;
    }
    if (pager.isDragging || pager.isAnimating || page != pager.index) return;
    _centerStart = null;
    if (_selected != pager.index) setState(() => _selected = pager.index);
  }

  double _centerOffset(ScrollPosition position, double page, double tabWidth) =>
      ((page + .5) * tabWidth - (position.viewportDimension - _fadeWidth) / 2)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

  void _followPage(double page) {
    final outerWidth = _outerWidth;
    if (!_scroll.hasClients || outerWidth == null) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final tabWidth = _tabWidth(outerWidth);
    final start = _centerStart ??= (page: _page, offset: position.pixels);
    // 频道栏手动滚过后，从当前画面接续，并在移动一页内回到居中位置。
    final correction = start.offset - _centerOffset(position, start.page, tabWidth);
    final target = (_centerOffset(position, page, tabWidth) + correction * math.max(0.0, 1 - (page - start.page).abs()))
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target != position.pixels) position.jumpTo(target);
  }

  void _select(int index) {
    if (index == _selected) _scheduleCenter();
    widget.onSelect(index);
  }

  void _scheduleCenter() {
    if (_centeringScheduled) return;
    _centeringScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centeringScheduled = false;
      final outerWidth = _outerWidth;
      if (!mounted || !_scroll.hasClients || outerWidth == null) return;
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      final target = _centerOffset(position, _page, _tabWidth(outerWidth));
      if ((target - position.pixels).abs() < .5) return;
      unawaited(position.animateTo(target, duration: Duration(milliseconds: 200), curve: Curves.easeOutCubic));
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (_outerWidth != constraints.maxWidth) {
        _outerWidth = constraints.maxWidth;
        _scheduleCenter();
      }
      final progress = widget.progress;
      final actionWidth = _menuWidth + _compactSearchWidth * progress;
      final tabWidth = _tabWidth(constraints.maxWidth);
      return Material(
        color: Colors.white,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // 视口边界跟随按钮轨道。展开时只约束越界位置，折叠不会主动滚动标签。
            PositionedDirectional(
              start: 0,
              end: math.min(actionWidth, constraints.maxWidth),
              top: 0,
              bottom: 0,
              child: SingleChildScrollView(
                key: ValueKey('bibi-tabs'),
                scrollDirection: Axis.horizontal,
                controller: _scroll,
                physics: ClampingScrollPhysics(),
                child: ListenableBuilder(
                  listenable: widget.pager,
                  builder: (context, _) {
                    final page = _page;
                    return Stack(
                      children: [
                        Row(
                          children: [
                            for (var index = 0; index < widget.channels.length; index++)
                              SizedBox(
                                key: ValueKey('bibi-channel-$index'),
                                width: tabWidth,
                                height: _channelHeight,
                                child: Semantics(
                                  button: true,
                                  selected: _selected == index,
                                  child: InkWell(
                                    onTap: () => _select(index),
                                    child: Center(
                                      child: Text(
                                        widget.channels[index],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color.lerp(_pink, _ink, (page - index).abs().clamp(0.0, 1.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(width: _endInset),
                          ],
                        ),
                        if (widget.channels.isNotEmpty)
                          PositionedDirectional(
                            start: (page + .5) * tabWidth - _indicatorWidth / 2,
                            bottom: 3,
                            width: _indicatorWidth,
                            height: 3,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                key: ValueKey('bibi-channel-indicator'),
                                decoration: BoxDecoration(color: _pink, borderRadius: BorderRadius.circular(2)),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            PositionedDirectional(
              end: actionWidth,
              width: _fadeWidth,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  key: ValueKey('bibi-channel-fade'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [Color(0x00ffffff), Colors.white],
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: -_compactSearchWidth * (1 - progress),
              width: _menuWidth + _compactSearchWidth,
              top: 0,
              bottom: 0,
              child: ColoredBox(
                color: Colors.white,
                child: Row(
                  children: [
                    SizedBox(
                      width: _menuWidth,
                      height: _channelHeight,
                      child: PopupMenuButton<int>(
                        key: ValueKey('bibi-menu'),
                        tooltip: '频道菜单',
                        padding: EdgeInsets.zero,
                        color: Colors.white,
                        icon: BibiGlyphIcon(BibiGlyph.menu, _ink),
                        onSelected: _select,
                        itemBuilder: (context) => [
                          for (var index = 0; index < widget.channels.length; index++)
                            PopupMenuItem(
                              value: index,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(widget.channels[index], style: TextStyle(color: _ink)),
                                  ),
                                  if (index == _selected) Icon(Icons.check, size: 18, color: _pink),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (progress > 0)
                      Opacity(
                        opacity: math.min(1.0, progress * 1.65),
                        child: BibiHeaderAction(
                          key: ValueKey('bibi-compact-search'),
                          label: '搜索',
                          width: _compactSearchWidth,
                          height: _channelHeight,
                          onTap: progress >= .5 ? widget.onSearch : null,
                          child: BibiGlyphIcon(BibiGlyph.search, _ink),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 1,
              child: IgnorePointer(child: ColoredBox(color: _line)),
            ),
          ],
        ),
      );
    },
  );
}
