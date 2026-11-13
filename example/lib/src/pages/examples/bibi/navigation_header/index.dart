import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'actions.dart';

const _pink = Color(0xfffb7299);
const _ink = Color(0xff5d6269);
const _line = Color(0xffecedf0);
const _searchHeight = 58.0;
const _channelHeight = 43.0;

/// 仿 B 站首页的搜索栏、状态栏背景和频道栏。
class BibiHeader extends StatelessWidget {
  /// 页头位移由正文的滚动协调器提供。
  const BibiHeader({
    super.key,
    required this.offset,
    required this.statusInset,
    required this.channelBarBuilder,
    required this.onSearch,
    required this.onBack,
  });

  final ValueListenable<double> offset;
  final double statusInset;

  /// 用当前折叠进度构建频道栏。
  final Widget Function(double progress) channelBarBuilder;
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
            child: channelBarBuilder(progress),
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
        BibiHeaderAction(
          label: '返回示例',
          width: 42,
          height: 42,
          radius: 21,
          color: Color(0xffe9ebef),
          onTap: onBack,
          child: BibiGlyphIcon(BibiGlyph.tv, Color(0xff9ca3ad)),
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
                  BibiGlyphIcon(BibiGlyph.search, _ink),
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
        BibiHeaderAction(
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
        BibiHeaderAction(
          label: '消息',
          width: 32,
          height: 40,
          onTap: () => _showMessage(context, '暂无新消息'),
          child: BibiGlyphIcon(BibiGlyph.mail, _ink),
        ),
      ],
    ),
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
                child: BibiHeaderAction(
                  label: '发布',
                  width: 43,
                  height: 43,
                  radius: 13,
                  color: _pink,
                  onTap: () => _showMessage(context, '发布入口'),
                  child: BibiGlyphIcon(BibiGlyph.plus, Colors.white),
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

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: Duration(seconds: 1)));
}
