import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart' show ElTabController;

const _pink = Color(0xfffb7299);
const _ink = Color(0xff5d6269);
const _line = Color(0xffecedf0);
const _searchHeight = 58.0;
const _channelHeight = 43.0;
const _menuWidth = 42.0;
const _compactSearchWidth = 40.0;
const _fadeWidth = 19.0;
const _endInset = 4.0;
const _indicatorWidth = 22.0;

/// 仿 B 站首页的搜索栏、状态栏背景和频道栏。
class BibiHeader extends StatelessWidget {
  /// 页头位移由正文的滚动协调器提供。
  const BibiHeader({
    super.key,
    required this.offset,
    required this.statusInset,
    required this.pager,
    required this.channels,
    required this.onSelect,
    required this.onSearch,
    required this.onBack,
  });

  final ValueListenable<double> offset;
  final double statusInset;
  final ElTabController pager;
  final List<String> channels;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: offset,
    child: BibiSearchBar(onSearch: onSearch, onBack: onBack),
    builder: (context, value, search) {
      final collapse = value.clamp(0.0, _searchHeight);
      final progress = collapse / _searchHeight;
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: statusInset,
            child: ColoredBox(color: Colors.white),
          ),
          if (progress < 1)
            Positioned(
              key: ValueKey('bibi-search-position'),
              top: statusInset - collapse,
              left: 0,
              right: 0,
              height: _searchHeight,
              child: Material(
                key: ValueKey('bibi-search-row'),
                color: Colors.white,
                child: Opacity(opacity: (1 - progress) * (1 - .24 * progress), child: search),
              ),
            ),
          Positioned(
            key: ValueKey('bibi-channel-position'),
            top: statusInset + _searchHeight - collapse,
            left: 0,
            right: 0,
            height: _channelHeight,
            child: BibiChannelBar(
              progress: progress,
              pager: pager,
              channels: channels,
              onSelect: onSelect,
              onSearch: onSearch,
            ),
          ),
        ],
      );
    },
  );
}

/// Bibi 首页的搜索栏和两侧入口。
class BibiSearchBar extends StatelessWidget {
  /// 创建由页头布局控制位置的搜索栏。
  const BibiSearchBar({required this.onSearch, required this.onBack});

  final VoidCallback onSearch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: 18, end: 12),
    child: Row(
      children: [
        _HeaderAction(
          label: '返回示例',
          width: 42,
          height: 42,
          radius: 21,
          color: Color(0xffe9ebef),
          onTap: onBack,
          child: _GlyphIcon(_Glyph.tv, Color(0xff9ca3ad)),
        ),
        SizedBox(width: 14),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onSearch,
            child: Container(
              height: 38,
              padding: EdgeInsetsDirectional.only(start: 9, end: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Color(0xffa2a7ae)),
              ),
              child: Row(
                children: [
                  _GlyphIcon(_Glyph.search, _ink),
                  SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      '发现好看的视频',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: _ink, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        _HeaderAction(
          label: '我的',
          width: 38,
          height: 38,
          radius: 19,
          onTap: onBack,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xffffe2ed)),
                child: Text(
                  '哔',
                  style: TextStyle(fontSize: 16, color: Color(0xffe75886), fontWeight: FontWeight.bold),
                ),
              ),
              PositionedDirectional(
                top: 0,
                end: 0,
                width: 7,
                height: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xfffa526f)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 11),
        _HeaderAction(
          label: '消息',
          width: 32,
          height: 40,
          onTap: () => _showMessage(context, '暂无新消息'),
          child: _GlyphIcon(_Glyph.mail, _ink),
        ),
      ],
    ),
  );
}

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
                        icon: _GlyphIcon(_Glyph.menu, _ink),
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
                        child: _HeaderAction(
                          key: ValueKey('bibi-compact-search'),
                          label: '搜索',
                          width: _compactSearchWidth,
                          height: _channelHeight,
                          onTap: progress >= .5 ? widget.onSearch : null,
                          child: _GlyphIcon(_Glyph.search, _ink),
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

/// 首页固定在底部的五个入口。
class BibiBottomBar extends StatelessWidget {
  /// [bottomInset] 为系统手势导航区域预留空间。
  const BibiBottomBar({
    super.key,
    required this.bottomInset,
    required this.onHome,
    required this.onFollowing,
    required this.onBack,
  });

  final double bottomInset;
  final VoidCallback onHome;
  final VoidCallback onFollowing;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _BottomItem(icon: Icons.home, label: '首页', color: _pink, onTap: onHome),
            ),
            Expanded(
              child: _BottomItem(icon: Icons.chat_bubble_outline, label: '动态', onTap: onFollowing),
            ),
            Expanded(
              child: Center(
                child: _HeaderAction(
                  label: '发布',
                  width: 43,
                  height: 43,
                  radius: 13,
                  color: _pink,
                  onTap: () => _showMessage(context, '发布入口'),
                  child: _GlyphIcon(_Glyph.plus, Colors.white),
                ),
              ),
            ),
            Expanded(
              child: _BottomItem(icon: Icons.shopping_bag, label: '会员购', onTap: () => _showMessage(context, '会员购入口')),
            ),
            Expanded(
              child: _BottomItem(icon: Icons.person, label: '我的', onTap: onBack),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({required this.icon, required this.label, required this.onTap, this.color = _ink});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Icon(icon, size: 24, color: color),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    ),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    required this.onTap,
    required this.child,
    this.radius = 0,
    this.color,
  });

  final String label;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final Widget child;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Material(
      color: color ?? Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    ),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: Duration(seconds: 1)));
}

enum _Glyph { tv, search, mail, menu, plus }

class _GlyphIcon extends StatelessWidget {
  const _GlyphIcon(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(24), painter: _GlyphPainter(glyph, color));
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final _Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..strokeWidth = glyph == _Glyph.plus ? 2.7 : 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void line(double x, double y, double endX, double endY) => canvas.drawLine(Offset(x, y), Offset(endX, endY), pen);
    void box(double left, double top, double right, double bottom, double radius) => canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(left, top, right, bottom), Radius.circular(radius)),
      pen,
    );

    switch (glyph) {
      case _Glyph.tv:
        box(3, 7, 21, 21, 3);
        line(7, 2, 11, 7);
        line(17, 2, 13, 7);
        line(7, 13, 9, 12);
        line(15, 12, 17, 13);
        canvas.drawArc(Rect.fromLTRB(9, 13, 15, 17), math.pi / 6, math.pi * 2 / 3, false, pen);
      case _Glyph.search:
        canvas.drawCircle(Offset(10.5, 10.5), 6.8, pen);
        line(15.6, 15.6, 21, 21);
      case _Glyph.mail:
        box(2, 4.5, 22, 19.5, 2);
        line(3, 6, 12, 13);
        line(12, 13, 21, 6);
      case _Glyph.menu:
        for (var y = 6.0; y <= 18; y += 6) {
          line(5, y, 19, y);
        }
      case _Glyph.plus:
        line(5, 12, 19, 12);
        line(12, 5, 12, 19);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.glyph != glyph || oldDelegate.color != color;
}
