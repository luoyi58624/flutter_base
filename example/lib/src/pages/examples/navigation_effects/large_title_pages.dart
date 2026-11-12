import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'common.dart';

/// 旧「收藏」「提醒事项」「书库」三种 LargeTitle；复用同一个新 Sliver 组件。
enum LargeTitleEffectKind { scale, fade, search }

class LargeTitleEffectPage extends StatefulWidget {
  const LargeTitleEffectPage({super.key, required this.kind});

  final LargeTitleEffectKind kind;

  @override
  State<LargeTitleEffectPage> createState() => _LargeTitleEffectPageState();
}

class _LargeTitleEffectPageState extends State<LargeTitleEffectPage> {
  final query = TextEditingController();
  final saved = <String>{'山茶文具店'};
  final completed = <String>{};
  final favorites = [
    '稍后阅读',
    '心头好',
    '日常灵感',
    '想去的地方',
    '声音与音乐',
    '书页之间',
    '光影记录',
    '小小备忘',
    '清晨的窗',
    '晚风集市',
    '山与海之间',
    '路灯下',
    '旧车票',
    '手写笔记',
    '午后光影',
    '温热的茶',
    '未寄出的信',
  ];
  final reminders = <String, List<String>>{
    '今天': ['给阳台的植物浇水', '读完手边的那一章', '去河边散步'],
    '这周': ['整理旅行的照片', '给家里打个电话', '试一道新的菜', '换一束鲜花', '和朋友约一顿饭'],
    '慢慢来': ['找个晴天去爬山', '重读喜欢的那本书', '学会一首新的曲子', '写一封手写的信'],
    '以后再说': ['整理去年拍的照片', '学一道炖菜', '把旧书寄给需要的人', '修好那盏台灯', '写年度歌单', '去老电影院看场电影', '认真泡一次茶'],
  };
  final books = <String, List<(String, String, String)>>{
    '正在阅读': [('山茶文具店', '小川糸', '读到第 86 页'), ('瓦尔登湖', '亨利·戴维·梭罗', '读到第 42 页')],
    '下一本想读': [
      ('小王子', '圣埃克苏佩里', '关于爱与陪伴'),
      ('四季便当', '吉井忍', '把日子过成喜欢的样子'),
      ('目送', '龙应台', '那些渐行渐远的背影'),
      ('人间草木', '汪曾祺', '寻常日子里的诗意'),
    ],
    '读过的风景': [
      ('海边的卡夫卡', '村上春树', '穿过森林，走向海边'),
      ('浮生六记', '沈复', '布衣蔬食，可乐终身'),
      ('一个人的好天气', '青山七惠', '在平凡中慢慢长大'),
      ('长日将尽', '石黑一雄', '回望一段安静的人生'),
      ('看不见的城市', '伊塔洛·卡尔维诺', '在想象里远行'),
      ('冬牧场', '李娟', '大地辽阔，生活温暖'),
    ],
    '书友推荐': [
      ('夜航西飞', '柏瑞尔·马卡姆', '一个人的非洲飞行'),
      ('万物既伟大又渺小', '吉米·哈利', '乡村兽医的日常'),
      ('东京八平米', '吉井忍', '小空间里的大生活'),
      ('夏日走过山间', '约翰·缪尔', '跟着羊群翻山越岭'),
    ],
  };

  @override
  void initState() {
    super.initState();
    query.addListener(_onQuery);
  }

  void _onQuery() => setState(() {});

  @override
  void dispose() {
    query.removeListener(_onQuery);
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final title = switch (kind) {
      LargeTitleEffectKind.scale => '收藏',
      LargeTitleEffectKind.fade => '提醒事项',
      LargeTitleEffectKind.search => '书库',
    };
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: effectCanvas,
      body: ElScrollView.sliver(
        slivers: [
          ElSliverLargeTitle(
            title: title,
            fade: kind == LargeTitleEffectKind.fade,
            centerTitle: kind == LargeTitleEffectKind.fade,
            snap: kind != LargeTitleEffectKind.search,
            backgroundColor: colors.surface,
            leading: IconButton(
              tooltip: '返回',
              icon: Icon(CupertinoIcons.chevron_back),
              onPressed: () => Navigator.maybePop(context),
            ),
            actions: [
              if (kind == LargeTitleEffectKind.search)
                IconButton(tooltip: '关闭书库', icon: Icon(Icons.close), onPressed: () => Navigator.maybePop(context)),
            ],
            bottom: kind != LargeTitleEffectKind.search
                ? null
                : TextField(
                    key: ValueKey('effects-large-search'),
                    controller: query,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索书名或作者',
                      filled: true,
                      fillColor: Color(0xfff4f4f7),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
          ),
          ElSliverRefresh(onRefresh: effectRefresh),
          switch (kind) {
            LargeTitleEffectKind.scale => _favorites(),
            LargeTitleEffectKind.fade => _reminders(),
            LargeTitleEffectKind.search => _library(),
          },
          SliverToBoxAdapter(child: SizedBox(height: 36)),
        ],
      ),
    );
  }

  Widget _favorites() => effectSliverItems([
    effectSectionLabel('置顶'),
    effectGroup([
      for (final (index, label) in favorites.take(2).indexed)
        ListTile(
          leading: effectAvatar(index == 0 ? '书' : '♥', index == 0 ? Color(0xffd78b42) : Color(0xffda686d)),
          title: Text(label),
          subtitle: Text('给自己留一点慢慢读的时间'),
          trailing: Text(index == 0 ? '12' : '8'),
        ),
    ]),
    effectSectionLabel('我的收藏夹', trailing: '6 个收藏夹'),
    effectGroup([
      for (final (i, label) in favorites.skip(2).take(6).indexed)
        ListTile(
          leading: effectAvatar(label.characters.first, Colors.primaries[i % Colors.primaries.length]),
          title: Text(label),
          subtitle: Text('慢慢攒起来的念头'),
          trailing: Text('${(i + 2) * 3}'),
        ),
    ]),
    effectSectionLabel('最近收藏'),
    effectGroup([
      for (final title in ['把周末，还给自己', '窗边的一平方米', '沿着风的方向走']) ListTile(title: Text(title), subtitle: Text('慢读 · 今天')),
    ]),
    effectSectionLabel('更多收藏夹', trailing: '${favorites.length - 8} 个收藏夹'),
    effectGroup([
      for (final (i, label) in favorites.skip(8).indexed)
        ListTile(
          leading: effectAvatar(label.characters.first, Colors.primaries[i % Colors.primaries.length]),
          title: Text(label),
          subtitle: Text('值得反复回看的片刻'),
          trailing: Icon(Icons.chevron_right),
        ),
    ]),
  ]);

  Widget _reminders() => effectSliverItems([
    for (final group in reminders.entries) ...[
      effectSectionLabel(group.key, trailing: '${group.value.where((name) => !completed.contains(name)).length} 项待办'),
      effectGroup([
        for (final name in group.value)
          CheckboxListTile(
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              name,
              style: TextStyle(decoration: completed.contains(name) ? TextDecoration.lineThrough : null),
            ),
            subtitle: Text('早晨 · 让生活慢慢长出新叶'),
            value: completed.contains(name),
            onChanged: (value) => setState(() {
              if (value == true) {
                completed.add(name);
              } else {
                completed.remove(name);
              }
            }),
          ),
      ]),
    ],
  ]);

  Widget _library() {
    final keyword = query.text.trim().toLowerCase();
    final filtered = {
      for (final group in books.entries)
        group.key: group.value.where((item) => '${item.$1} ${item.$2}'.toLowerCase().contains(keyword)).toList(),
    };
    return effectSliverItems([
      if (filtered.values.every((items) => items.isEmpty))
        effectContent(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: Text('没有找到相关书籍\n试试书名或作者的名字', textAlign: TextAlign.center)),
          ),
        ),
      for (final group in filtered.entries)
        if (group.value.isNotEmpty) ...[
          effectSectionLabel(group.key, trailing: '${group.value.length} 本'),
          effectGroup([
            for (final book in group.value)
              ListTile(
                title: Text(book.$1),
                subtitle: Text('${book.$2} · ${book.$3}'),
                trailing: IconButton(
                  tooltip: saved.contains(book.$1) ? '取消收藏' : '收藏',
                  icon: Icon(saved.contains(book.$1) ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark),
                  onPressed: () => setState(() {
                    if (!saved.remove(book.$1)) saved.add(book.$1);
                  }),
                ),
              ),
          ]),
        ],
    ]);
  }
}
