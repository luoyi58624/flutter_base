import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart' show ElCardView, ElTabController, ElTabView;

/// 原生示例同款离线推荐流，每行两张卡片。
const int bibiVideoRowCount = 180;

/// 推荐流中的视频卡片总数。
const int bibiVideoCount = bibiVideoRowCount * 2;

const _ink = Color(0xff18191c);
const _muted = Color(0xff868b94);
const _pink = Color(0xfffb7299);
const _atlas = 'assets/recycler_cards/bili_home.webp';
const _bannerTitles = ['一人一剑，重走西域古道', '在山野里慢慢过一天', '她唱出了夏日夜晚的颜色'];
const _titles = [
  ['用了半年才敢说：这套桌搭到底值不值？', '桌面乱成一团？试试我的极简改造', '我把旧电脑改成了家里的媒体中心', '把工作台变舒服，只需要这几个细节'],
  ['最后十秒！这波团战是谁在指挥？', '职业选手的极限反打，第一视角复盘', '这套打法刚出来，我已经试了二十把', '逆风局队友一句话，全场突然安静了'],
  ['剪了三遍，还是舍不得删掉这段日落', '你是否也记得，夏天结束前的那场风', '这一帧出现时，终于明白主角在等谁', '画了一个月，把童年的夏天做成动画'],
  ['不赶路的一天，沿着海岸去看日出', '从小城出发，找到了这片安静的海', '沿海骑行二十公里，风声比音乐好听', '坐最慢的那班车，到海边吃午饭'],
  ['夜市收摊前，老板多炒了一勺锅气', '四块钱一份的街边小炒，真的能吃饱吗', '凌晨两点还亮着灯的小店，到底谁在排队', '跟着街坊去吃，三道菜全是下饭冠军'],
  ['电影里他回头的那一秒，线索就在背后', '从头再看一遍，才发现这五处伏笔', '结局只用了一个眼神，前面全都连起来了', '第一遍以为是悬疑片，第二遍才看懂'],
];
const _creators = ['像素工作室', '阿洛赛事手记', '未完待续动画社', '海岸散步计划', '大成去觅食', '放映室第七排'];
const _badges = ['必看', '精彩集锦', '人气投稿', '旅行记录', '烟火日常', '影视拆解'];

/// 构建首页轮播。刷新后由新一批推荐的首张封面开始。
Widget buildBibiBanner(BuildContext context, int generation) => Padding(
  key: ValueKey('bibi-banner'),
  padding: .fromLTRB(8, 4, 8, 6),
  child: _BibiBanner(key: ValueKey(generation), initialIndex: generation % _bannerTitles.length),
);

/// 按行构建两个视频卡片，频道共用相同的本地数据。
Widget buildBibiVideoRow(BuildContext context, int rowIndex, int generation) => Padding(
  key: ValueKey('bibi-row-$rowIndex'),
  padding: .fromLTRB(8, 4, 8, 5),
  child: Row(
    crossAxisAlignment: .start,
    spacing: 8,
    children: [
      Expanded(child: buildBibiVideoCard(rowIndex * 2, generation)),
      Expanded(child: buildBibiVideoCard(rowIndex * 2 + 1, generation)),
    ],
  ),
);

/// 构建首页与 Grid 对照共用的视频卡片。
Widget buildBibiVideoCard(int index, int generation) => _VideoCard(_videoAt(index, generation));

/// 从当前一批本地推荐按标题或 UP 主搜索。
Future<void> showBibiSearch(BuildContext context, int generation) async {
  var input = '';
  String? error;
  final query = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void submit() {
          final query = input.trim();
          if (query.isEmpty) {
            setState(() => error = '请输入关键词');
          } else {
            Navigator.pop(context, query.toLowerCase());
          }
        }

        return AlertDialog(
          title: Text('搜索视频'),
          content: TextField(
            autofocus: true,
            textInputAction: .search,
            decoration: InputDecoration(hintText: '视频标题或 UP 主', errorText: error),
            onChanged: (value) {
              input = value;
              if (error != null) setState(() => error = null);
            },
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('取消')),
            TextButton(onPressed: submit, child: Text('搜索')),
          ],
        );
      },
    ),
  );
  if (query == null || !context.mounted) return;

  final matches = <_Video>[];
  final seen = <String>{};
  for (var index = 0; index < bibiVideoCount && matches.length < 12; index++) {
    final video = _videoAt(index, generation);
    if ((video.title.toLowerCase().contains(query) || video.creator.toLowerCase().contains(query)) &&
        seen.add(video.title)) {
      matches.add(video);
    }
  }
  final selected = await showDialog<_Video>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('搜索结果'),
      scrollable: true,
      content: matches.isEmpty
          ? Text('当前推荐没有匹配的视频。')
          : Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                for (final video in matches)
                  ListTile(
                    contentPadding: .zero,
                    title: Text(video.title),
                    subtitle: Text(video.creator),
                    onTap: () => Navigator.pop(context, video),
                  ),
              ],
            ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭'))],
    ),
  );
  if (selected != null && context.mounted) await _showDetails(context, selected.title, selected.summary);
}

class _Video {
  _Video(this.tile, this.title, this.creator, this.plays, this.duration, this.badge);

  final int tile;
  final String title;
  final String creator;
  final String plays;
  final String duration;
  final String? badge;

  String get summary => '$creator · $plays次播放 · $duration';
}

_Video _videoAt(int index, int generation) {
  // 跟原生示例使用同一组序号与种子，刷新只轮换本地推荐。
  final source = (generation * 17 + index) % bibiVideoCount;
  final group = source ~/ _titles.length;
  final scene = (source + 1 + group) % _titles.length;
  final titles = _titles[scene];
  final seed = (source * 5393 + 2239) % 789360;
  final views = 1800 + (seed + generation * 8191) % 789360;
  final seconds = 68 + seed % 1257;
  final tenths = (views + 500) ~/ 1000;
  return _Video(
    scene + 3,
    titles[(group + 1) % titles.length],
    _creators[scene],
    views < 10000 ? '$views' : '${tenths ~/ 10}.${tenths % 10}万',
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
    source % 9 == 4 ? _badges[scene] : null,
  );
}

class _BibiBanner extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _BibiBanner({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<_BibiBanner> createState() => _BibiBannerState();
}

class _BibiBannerState extends State<_BibiBanner> {
  late final _controller = ElTabController(length: _bannerTitles.length, initialIndex: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      height: math.min(212.0, constraints.maxWidth * 9 / 16),
      child: ClipRRect(
        borderRadius: .circular(8),
        child: Stack(
          fit: .expand,
          children: [
            ElTabView(
              controller: _controller,
              physics: ClampingScrollPhysics(),
              children: [
                for (var index = 0; index < _bannerTitles.length; index++)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showDetails(context, _bannerTitles[index], '首页精选 · 热门推荐'),
                      child: Stack(
                        fit: .expand,
                        children: [
                          _AtlasCover(index),
                          Positioned(
                            left: 12,
                            right: 56,
                            bottom: 10,
                            child: Text(
                              _bannerTitles[index],
                              maxLines: 1,
                              overflow: .ellipsis,
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: .w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 14,
              child: IgnorePointer(
                child: CustomPaint(size: Size(28, 4), painter: _BannerDots(_controller)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BannerDots extends CustomPainter {
  _BannerDots(this.controller) : super(repaint: controller);

  final ElTabController controller;

  @override
  void paint(Canvas canvas, Size size) {
    var x = 0.0;
    final paint = Paint();
    for (var index = 0; index < _bannerTitles.length; index++) {
      final fraction = math.max(0.0, 1 - (index - controller.position).abs());
      final width = 4 + 6 * fraction;
      paint.color = Colors.white.withValues(alpha: .53 + .47 * fraction);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, width, size.height), Radius.circular(2)), paint);
      x += width + 5;
    }
  }

  @override
  bool shouldRepaint(covariant _BannerDots oldDelegate) => !identical(controller, oldDelegate.controller);
}

class _AtlasCover extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _AtlasCover(this.tile);

  final int tile;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // 一张图走同一个 ImageCache。按原生图集的边界裁切，缩放时避开相邻封面。
      const width = 1536.0;
      const height = 1024.0;
      final column = tile % 3;
      final row = tile ~/ 3;
      final sourceLeft = column * 512 + 1;
      final sourceTop = row * 1024 ~/ 3 + 1;
      final sourceHeight = (row + 1) * 1024 ~/ 3 - 1 - sourceTop;
      final scale = math.max(constraints.maxWidth / 510, constraints.maxHeight / sourceHeight);
      return Stack(
        fit: .expand,
        children: [
          ColoredBox(color: Color(0xff383845)),
          Positioned(
            left: (constraints.maxWidth - 510 * scale) / 2 - sourceLeft * scale,
            top: (constraints.maxHeight - sourceHeight * scale) / 2 - sourceTop * scale,
            width: width * scale,
            height: height * scale,
            child: Image.asset(_atlas, fit: .fill, excludeFromSemantics: true),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                stops: [.52, 1],
                colors: [Colors.transparent, Color(0xc4000000)],
              ),
            ),
          ),
        ],
      );
    },
  );
}

enum _VideoAction { details, copy }

class _VideoCard extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _VideoCard(this.video);

  final _Video video;

  Future<void> _onAction(BuildContext context, _VideoAction action) async {
    switch (action) {
      case .details:
        await _showDetails(context, video.title, video.summary);
      case .copy:
        await Clipboard.setData(ClipboardData(text: video.title));
        if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('已复制标题')));
    }
  }

  @override
  Widget build(BuildContext context) => ElCardView(
    child: Material(
      color: Colors.white,
      borderRadius: .circular(7),
      clipBehavior: .hardEdge,
      child: InkWell(
        onTap: () => _showDetails(context, video.title, video.summary),
        child: Column(
          crossAxisAlignment: .stretch,
          mainAxisSize: .min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: .expand,
                children: [
                  _AtlasCover(video.tile),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 5,
                    child: Row(
                      spacing: 3,
                      children: [
                        Icon(Icons.play_arrow_rounded, size: 13, color: Colors.white),
                        Expanded(child: _coverText(video.plays)),
                        _coverText(video.duration),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: .fromLTRB(7, 7, 6, 6),
              child: Column(
                crossAxisAlignment: .stretch,
                spacing: 4,
                children: [
                  SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(14) * 2.8,
                    child: Text(
                      video.title,
                      maxLines: 2,
                      overflow: .ellipsis,
                      style: TextStyle(color: _ink, fontSize: 14, height: 1.4, fontWeight: .w600),
                    ),
                  ),
                  Row(
                    spacing: 4,
                    children: [
                      Container(
                        width: 17,
                        height: 12,
                        alignment: .center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xffa9adb4)),
                          borderRadius: .circular(2),
                        ),
                        child: FittedBox(
                          child: Text(
                            'UP',
                            style: TextStyle(color: _muted, fontSize: 8, fontWeight: .w700),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          video.creator,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: TextStyle(color: _muted, fontSize: 11),
                        ),
                      ),
                      if (video.badge case final badge?)
                        Flexible(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Color(0xffffedf4), borderRadius: .circular(2)),
                            child: Padding(
                              padding: .symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                badge,
                                maxLines: 1,
                                overflow: .ellipsis,
                                style: TextStyle(color: _pink, fontSize: 9),
                              ),
                            ),
                          ),
                        ),
                      PopupMenuButton<_VideoAction>(
                        tooltip: '更多选项',
                        padding: .zero,
                        icon: Icon(Icons.more_vert, color: _muted, size: 16),
                        style: IconButton.styleFrom(minimumSize: Size(22, 22), tapTargetSize: .shrinkWrap),
                        onSelected: (action) => _onAction(context, action),
                        itemBuilder: (context) => [
                          PopupMenuItem(value: .details, child: Text('视频详情')),
                          PopupMenuItem(value: .copy, child: Text('复制标题')),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _coverText(String value) => Text(
    value,
    maxLines: 1,
    overflow: .ellipsis,
    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: .w600),
  );
}

Future<void> _showDetails(BuildContext context, String title, String summary) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(summary),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭'))],
    ),
  );
}
