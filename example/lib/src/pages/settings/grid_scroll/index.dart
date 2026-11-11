import 'dart:math';

import 'package:faker/faker.dart' as fake;
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

/// 按页追加网格卡片。旧页用 [ElRebuildWidget] 冻住，滚动只绘制视口内的页。
class GridScrollPage extends StatefulWidget {
  /// 创建网格滚动示例。
  const GridScrollPage({super.key});

  @override
  State<GridScrollPage> createState() => _GridScrollPageState();
}

class _GridScrollPageState extends State<GridScrollPage> {
  /// 每一页的格子数。追加时只构建这一页。
  static const _pageSize = 100;

  final ScrollController _controller = ScrollController();
  final List<Map<String, String>> _items = [];
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    if (_controller.position.pixels >= _controller.position.maxScrollExtent) {
      _load();
    }
  }

  /// 滚到底再要一页。请求结束后多停 100ms，避免同一帧末尾再次触发。
  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    await 200.ms.delay();
    if (!mounted) return;
    setState(() {
      _items.addAll(
        List.generate(_pageSize, (index) {
          return {
            'id': ElDartUtil.uuidStr,
            'name': fake.faker.person.name(),
            'image': fake.faker.image.loremPicsum(width: 300, height: 300, random: Random().nextInt(100)),
          };
        }),
      );
    });
    await 100.ms.delay();
    _loading = false;
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.elTheme.brightness == Brightness.dark;
    final pages = _items.length ~/ _pageSize;
    return Scaffold(
      backgroundColor: dark ? Colors.grey.shade900 : Colors.grey.shade200,
      appBar: AppBar(title: Text('网格滚动')),
      body: ElScroll(
        controller: _controller,
        padding: .all(6),
        children: [
          for (var page = 0; page < pages; page++)
            ElRebuildWidget(
              child: ObsBuilder(
                builder: (context) {
                  return RepaintBoundary(
                    child: ElGrid(
                      itemWidth: 150,
                      rowGap: 6,
                      columnGap: 6,
                      // 旧 ElGrid 用宽乘 1.2 得到高度；这里的 aspectRatio 是宽/高。
                      aspectRatio: 1 / 1.2,
                      children: List.generate(_pageSize, (index) => _Card(data: _items[page * _pageSize + index])),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.data});

  final Map<String, String> data;

  @override
  Widget build(BuildContext context) {
    final dark = context.elTheme.brightness == Brightness.dark;
    final secondary = context.elTheme.textSecondary;
    return ElView(
      style: ElStyle(
        backgroundColor: dark ? Colors.grey.shade800 : Colors.white,
        borderRadius: .circular(6),
        clipBehavior: Clip.antiAlias,
        boxShadow: [BoxShadow(color: Color(0xff000000).withValues(alpha: 0.08), blurRadius: 0.2)],
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ElImageView(
                  data['image']!,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          Padding(
            padding: .symmetric(vertical: 8, horizontal: 6),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                ElView(
                  style: ElStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    maxLines: 1,
                    textOverflow: TextOverflow.ellipsis,
                  ),
                  child: data['name'],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    ElIcon(Icons.account_circle_rounded, size: 16, color: secondary),
                    SizedBox(width: 2),
                    Expanded(
                      child: ElView(
                        style: ElStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: secondary,
                          maxLines: 1,
                          textOverflow: TextOverflow.ellipsis,
                        ),
                        child: '酱油神小子',
                      ),
                    ),
                    ElView(
                      event: ElEvent(onTap: (event) => event.stopPropagation()),
                      style: ElStyle(padding: .fromLTRB(24, 2, 0, 2), onTap: ElStyle(opacity: 0.6)),
                      child: ElIcon(Icons.more_vert, size: 16, color: secondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
