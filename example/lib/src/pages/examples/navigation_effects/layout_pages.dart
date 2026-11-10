import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'common.dart';

/// 旧「底部导航」：三个页面的 ScrollPosition 和可见内容分别保留。
class BottomNavigationEffectPage extends StatefulWidget {
  const BottomNavigationEffectPage({super.key});

  @override
  State<BottomNavigationEffectPage> createState() => _BottomNavigationEffectPageState();
}

class _BottomNavigationEffectPageState extends State<BottomNavigationEffectPage> {
  var selected = 0;
  final titles = ['发现', '收藏', '我的'];
  final icons = [CupertinoIcons.compass, CupertinoIcons.star, CupertinoIcons.person];
  final controllers = List.generate(3, (_) => ScrollController());

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: effectCanvas,
    appBar: AppBar(title: Text(titles[selected])),
    bottomNavigationBar: NavigationBar(
      key: ValueKey('effects-bottom-navigation'),
      selectedIndex: selected,
      onDestinationSelected: (index) => setState(() => selected = index),
      destinations: [for (var i = 0; i < 3; i++) NavigationDestination(icon: Icon(icons[i]), label: titles[i])],
    ),
    body: IndexedStack(
      index: selected,
      children: [
        for (var tab = 0; tab < 3; tab++)
          ElScroll.sliver(
            key: PageStorageKey('effects-bottom-tab-$tab'),
            controller: controllers[tab],
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverList.builder(
                  itemCount: 30,
                  itemBuilder: (context, i) => Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: Padding(padding: EdgeInsets.all(20), child: Text('${titles[tab]} · 第 ${i + 1} 项')),
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

/// 旧「工作空间」：相同侧栏内容在宽屏/移动抽屉间切换，选择与开关状态保留。
class DrawerEffectPage extends StatefulWidget {
  const DrawerEffectPage({super.key});

  @override
  State<DrawerEffectPage> createState() => _DrawerEffectPageState();
}

class _DrawerEffectPageState extends State<DrawerEffectPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final sections = ['工作概览', '进行中的项目', '收藏与灵感', '归档'];
  final icons = [
    CupertinoIcons.square_grid_2x2,
    CupertinoIcons.folder,
    CupertinoIcons.bookmark,
    CupertinoIcons.archivebox,
  ];
  var selected = 0;
  var forceDrawer = false;
  var fillHeight = true;
  var expandTop = false;
  var alignBottom = false;

  Widget _option(String label, bool value, ValueChanged<bool> change) =>
      SwitchListTile(title: Text(label), value: value, onChanged: change);

  Widget _menu(bool sidebar) => Material(
    color: Colors.white,
    elevation: sidebar ? 0 : 8,
    child: Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(22, 30, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('林间工作室', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('把每天的想法，慢慢变成作品', style: TextStyle(color: effectMuted, fontSize: 13)),
            ],
          ),
        ),
        for (var i = 0; i < sections.length; i++)
          ListTile(
            key: ValueKey('effects-drawer-section-$i'),
            leading: Icon(icons[i]),
            title: Text(sections[i]),
            selected: selected == i,
            selectedTileColor: Color(0xffeaf2fc),
            onTap: () {
              setState(() => selected = i);
              if (!sidebar) scaffoldKey.currentState?.closeDrawer();
            },
          ),
        if (fillHeight) Spacer(),
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('导航选择在两种形态间保持', style: TextStyle(fontSize: 12, color: effectMuted)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final sidebar = MediaQuery.sizeOf(context).width >= 768 && !forceDrawer;
    final body = ElScroll.sliver(
      slivers: [
        effectSliverItems([
          effectDescription(sections[selected], '桌面侧栏与移动抽屉共享同一份导航。\n用下面的开关试试不同布局。'),
          effectGroup([
            _option('桌面也使用抽屉', forceDrawer, (v) => setState(() => forceDrawer = v)),
            _option('侧栏撑满高度', fillHeight, (v) => setState(() => fillHeight = v)),
            _option('侧栏延伸到顶部，导航头让位', expandTop, (v) => setState(() => expandTop = v)),
            _option('自然高度侧栏贴底', alignBottom, (v) => setState(() => alignBottom = v)),
          ]),
          effectSectionLabel('最近的工作'),
          for (final title in ['秋日画册', '周末阅读清单', '新的想法', '下次出发'])
            effectContent(
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        SizedBox(height: 12),
                        Text('记录一点进展，让下一次开始变得更容易。', style: TextStyle(color: effectMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          for (var i = 0; i < 10; i++)
            effectContent(ListTile(title: Text('工作记录 ${i + 1}'), subtitle: Text('林间工作室 · 本周'))),
        ]),
      ],
    );
    return Stack(
      children: [
        Scaffold(
          key: scaffoldKey,
          backgroundColor: effectCanvas,
          appBar: AppBar(
            title: sidebar && expandTop
                ? Padding(padding: EdgeInsetsDirectional.only(start: 244), child: Text('工作空间'))
                : Text('工作空间'),
            actions: [
              if (!sidebar)
                IconButton(
                  tooltip: '打开导航菜单',
                  icon: Icon(Icons.menu),
                  onPressed: () => scaffoldKey.currentState?.openDrawer(),
                ),
              IconButton(
                tooltip: '工作提醒',
                icon: Icon(Icons.notifications_outlined),
                onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
          drawer: sidebar ? null : Drawer(child: _menu(false)),
          endDrawer: Drawer(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('工作提醒', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    SizedBox(height: 16),
                    Text('今天还有两份草稿等待整理。\n完成一件事，也记得给自己留一点空白。'),
                  ],
                ),
              ),
            ),
          ),
          body: Row(
            children: [
              if (sidebar)
                SizedBox(
                  width: 244,
                  child: expandTop
                      ? SizedBox.shrink()
                      : Align(
                          alignment: alignBottom ? Alignment.bottomCenter : Alignment.topCenter,
                          child: _menu(true),
                        ),
                ),
              Expanded(child: body),
            ],
          ),
        ),
        // 「延伸到顶部」是真的跨到导航区，并由导航标题让出水平空间。
        if (sidebar && expandTop)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 244,
            child: SafeArea(
              bottom: false,
              child: Align(alignment: alignBottom ? Alignment.bottomCenter : Alignment.topCenter, child: _menu(true)),
            ),
          ),
      ],
    );
  }
}

/// 旧「收件箱」：固定导航，只有正文参与滚动与刷新。
class FixedEffectPage extends StatelessWidget {
  const FixedEffectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final senders = ['林间来信', '陈一', '设计周刊', '远方书店', '许知远', '小满', '城市漫游', '青禾', '周末电台'];
    final subjects = [
      '周末，去山里走走',
      '给你留了一张靠窗的座位',
      '留白，是一种表达',
      '你预订的书到了',
      '一些关于旅行的照片',
      '今晚想吃什么？',
      '九月的散步地图',
      '关于那本没读完的书',
      '适合雨天的声音',
    ];
    return effectPage(
      context,
      title: '收件箱',
      slivers: [
        effectSliverItems([
          for (final group in ['今天', '昨天', '更早', for (var i = 1; i <= 8; i++) '第 $i 周']) ...[
            effectSectionLabel(group, trailing: group == '今天' ? '3 封未读' : null),
            effectGroup([
              for (var i = 0; i < (group == '今天' ? 3 : 8); i++)
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: effectAvatar(senders[i % senders.length].characters.first, Color(0xff638e9f)),
                  title: Text(senders[i % senders.length]),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subjects[i % subjects.length], maxLines: 1, style: TextStyle(fontWeight: FontWeight.w500)),
                      Text('路过邮局的时候想起你。挑了一张明信片，写完就寄出。', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  trailing: Text('09:41', style: TextStyle(color: effectMuted, fontSize: 11)),
                ),
            ]),
          ],
          SizedBox(height: 24),
        ]),
      ],
    );
  }
}

/// 旧「通讯录」：官方 PinnedHeaderSliver + SliverMainAxisGroup，每段独立吸顶。
class StickyEffectPage extends StatefulWidget {
  const StickyEffectPage({super.key});

  @override
  State<StickyEffectPage> createState() => _StickyEffectPageState();
}

class _StickyEffectPageState extends State<StickyEffectPage> {
  static final groups = _createGroups();

  // 与旧 ElContacts 示例使用相同的原始分组及 14 组扩展联系人。
  static Map<String, List<String>> _createGroups() {
    final groups = <String, List<String>>{
      'A': ['安然', '艾宁'],
      'C': ['陈一', '陈知夏', '程越', '崔宁'],
      'E': ['Ella', 'Ethan'],
      'I': ['Iris', 'Ivan'],
      'L': ['李青禾', '李书白', '梁沐', '林川', '陆遥'],
      'O': ['Oliver', 'Olivia'],
      'S': ['沈言', '沈知意', '宋嘉禾', '苏木', '孙小满'],
      'U': ['Uma', 'Una'],
      'V': ['Victor', 'Violet'],
      'W': ['王予安', '王知行', '温时', '吴悠', '伍月'],
      'X': ['夏宁', '向晚', '许澄', '许星然', '徐青'],
      'Z': ['张可', '赵一诺', '周嘉宁', '周屿', '朱南'],
    };
    const letters = 'BDFGHJKMNPQRTY';
    const surnames = ['白', '董', '冯', '高', '韩', '蒋', '孔', '孟', '倪', '潘', '秦', '任', '谭', '严'];
    const given = ['之远', '若曦', '望舒', '既明', '南乔', '清越', '亦安', '拾光', '泽川', '疏影', '沛然', '青临'];
    for (var i = 0; i < letters.length; i++) {
      groups[letters[i]] = [for (var j = 0; j < 6; j++) '${surnames[i]}${given[(i * 2 + j * 5) % given.length]}'];
    }
    final alphabet = groups.keys.toList()..sort();
    return {
      '☆': ['陈安', '林晚'],
      for (final letter in alphabet) letter: groups[letter]!,
      '#': ['123 服务热线', '_项目助手'],
    };
  }

  final keys = <String, GlobalKey>{for (final letter in groups.keys) letter: GlobalKey()};

  void _to(String letter) {
    final context = keys[letter]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(context, duration: Duration(milliseconds: 220), alignment: 0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('通讯录')),
    backgroundColor: Colors.white,
    body: Stack(
      children: [
        ElScroll.sliver(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  for (final (title, icon) in [
                    ('新的朋友', Icons.person_add_alt),
                    ('仅聊天的朋友', Icons.chat_bubble),
                    ('群聊', Icons.group),
                    ('标签', Icons.local_offer),
                    ('公众号', Icons.menu_book),
                    ('服务号', Icons.bolt),
                  ])
                    ListTile(
                      title: Text(title),
                      leading: Icon(icon, color: effectBlue),
                    ),
                ],
              ),
            ),
            for (final entry in groups.entries)
              SliverMainAxisGroup(
                slivers: [
                  PinnedHeaderSliver(
                    key: keys[entry.key],
                    child: Container(
                      color: effectCanvas,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        entry.key == '☆' ? '星标朋友' : entry.key,
                        style: TextStyle(color: effectMuted, fontSize: 14),
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: entry.value.length,
                    itemBuilder: (context, index) {
                      final name = entry.value[index];
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        leading: effectAvatar(name.characters.first, Color(0xff72859a), size: 36),
                        title: Text(name),
                      );
                    },
                  ),
                ],
              ),
            SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
        Positioned(
          top: 8,
          bottom: 8,
          right: 0,
          width: 22,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                final index = ((details.localPosition.dy / constraints.maxHeight) * groups.length).floor().clamp(
                  0,
                  groups.length - 1,
                );
                _to(groups.keys.elementAt(index));
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final letter in groups.keys)
                    Expanded(
                      child: InkWell(
                        onTap: () => _to(letter),
                        child: Center(
                          child: Text(
                            letter,
                            style: TextStyle(color: effectBlue, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
