import 'dart:math';

import 'package:faker/faker.dart' as fake;
import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

/// 按页追加网格卡片：固定格尺寸的 [ElSliverGrid.builder] 只构建缓存窗口内的卡片。
class GridScrollPage extends StatefulWidget {
  /// 创建网格滚动示例。
  const GridScrollPage({super.key});

  @override
  State<GridScrollPage> createState() => _GridScrollPageState();
}

class _GridScrollPageState extends State<GridScrollPage> {
  /// 每一页追加的格子数。
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
    return Scaffold(
      backgroundColor: dark ? Colors.grey.shade900 : Colors.grey.shade200,
      appBar: AppBar(title: Text('网格滚动')),
      body: ElScrollView.sliver(
        controller: _controller,
        slivers: [
          SliverPadding(
            padding: .all(6),
            sliver: ElSliverGrid.builder(
              itemCount: _items.length,
              itemWidth: 150,
              spacing: 6,
              // 格高为宽的 1.2 倍；aspectRatio 是宽/高。固定格尺寸让追加分页不需要测量已有卡片。
              aspectRatio: 1 / 1.2,
              itemBuilder: (context, index) => _Card(data: _items[index]),
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
