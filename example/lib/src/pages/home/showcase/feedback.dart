import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';
import 'primitives.dart';

/// 反馈、弹层与菜单按卡片或可见行构建。
List<ShowcaseItem> feedbackShowcaseItems(bool mobile) => [
  ShowcaseItem(
    (context) => ShowcaseSection(
      id: 'feedback',
      number: '04',
      category: '状态反馈',
      title: '提示与弹层',
      description: '提示、确认对话框和移动端操作面板。',
      links: {
        'feedback-state': '共享状态',
        'feedback-prompts': '提示与确认',
        'feedback-progress': '进度与通知',
        'feedback-overlays': '抽屉与菜单',
      },
    ),
    anchor: 'feedback',
    gap: 0,
  ),
  ShowcaseItem((context) => _SharedState(), anchor: 'feedback-state'),
  ...ShowcaseItem.rows([
    ShowcaseItem((context) {
      final t = context.elTheme;
      return ShowcasePanel(
        title: '轻提示',
        description: '通过 el.toast 展示简短反馈，不中断当前操作。',
        child: demoColumn([
          ElToast(
            style: ElStyle(backgroundColor: t.fill, boxShadow: [], iconColor: t.success),
            child: demoColumn([
              Text(
                '保存成功',
                style: TextStyle(fontSize: 14, fontWeight: .w600, color: t.success),
              ),
              demoHint(context, '你的更改已经同步', size: 13),
            ], gap: 4),
          ),
          _promptAction(context, '体验轻提示', () => demoNotify(context, '你的更改已经同步')),
        ]),
      );
    }, anchor: 'feedback-prompts'),
    ShowcaseItem((context) {
      final t = context.elTheme;
      Widget preview(Widget child) => SizedBox(height: 116, child: Center(child: child));
      return ShowcasePanel(
        title: '确认弹窗',
        description: '等待 el.dialog 的返回值，确认后再执行后续操作。',
        child: demoColumn([
          preview(
            Column(
              mainAxisSize: .min,
              spacing: 14,
              children: [
                ElView(
                  style: ElStyle(
                    width: 66,
                    height: 66,
                    alignment: .center,
                    borderRadius: .circular(22),
                    backgroundColor: t.fill,
                    iconColor: t.textSecondary,
                    iconSize: 30,
                  ),
                  child: ElMobileIcons.shield,
                ),
                demoHint(context, '每个决定，都值得确认'),
              ],
            ),
          ),
          _promptAction(context, '打开确认弹窗', () async {
            if (await demoDialog(context) == true && context.mounted) demoNotify(context, '设置已保存');
          }),
        ]),
      );
    }),
    ShowcaseItem((context) {
      final t = context.elTheme;
      return ShowcasePanel(
        title: '底部操作面板',
        description: 'el.dialog.show 停靠底部即为面板，接收自定义内容，关闭后取得用户选择。',
        child: demoColumn([
          ElCard(
            style: ElStyle(
              padding: .fromLTRB(18, 14, 18, 19),
              borderRadius: .vertical(top: .circular(19), bottom: .circular(13)),
              backgroundColor: t.fill,
              border: .all(borderColor: t.borderColor),
              boxShadow: [],
            ),
            child: demoColumn([
              Center(
                child: ElView(
                  style: ElStyle(width: 32, height: 4, borderRadius: .circular(2), backgroundColor: t.gray),
                ),
              ),
              SizedBox(height: 14),
              ElView(
                style: ElStyle(height: 11, borderRadius: .circular(10), backgroundColor: t.borderColor),
              ),
              SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: .66,
                alignment: .centerLeft,
                child: ElView(
                  style: ElStyle(height: 11, borderRadius: .circular(10), backgroundColor: t.borderColor),
                ),
              ),
            ], gap: 0),
          ),
          _promptAction(context, '展开操作面板', () => demoShare(context)),
        ]),
      );
    }, anchor: 'feedback-share'),
  ], columns: mobile ? 1 : 3),
  ...primitiveShowcaseItems(mobile),
  ...ShowcaseItem.rows([
    ShowcaseItem((context) {
      final direction = useState('右侧');
      return ShowcasePanel(
        title: '抽屉',
        description: '从不同方向打开内容，输入和操作都保留在当前面板。',
        child: demoColumn([
          ElSegmented<String>(
            modelValue: direction,
            options: [
              for (final label in ['左侧', '右侧', '顶部', '底部']) ElSegmentedOption(value: label, label: label),
            ],
          ),
          ElButton(
            variant: .outline,
            child: '打开抽屉',
            onPressed: () async {
              final result = await el.drawer.show<String>(
                context,
                title: '编辑个人资料',
                placement: switch (direction.value) {
                  '左侧' => .left,
                  '顶部' => .top,
                  '底部' => .bottom,
                  _ => .right,
                },
                child: _DrawerProfile(),
              );
              if (result != null && context.mounted) demoNotify(context, '资料已保存：$result');
            },
          ),
        ]),
      );
    }, anchor: 'feedback-overlays'),
    ShowcaseItem((context) {
      final trailing = useState(true);
      final single = useState('锁屏与时钟桌面插件'), multi = useState(['同步文档', '同步图片']);
      Future<void> selections(bool multiple) async {
        final markLeading = !trailing.value;
        final selected = await el.dialog.show<String>(
          context,
          placement: .bottom,
          title: multiple ? '选择需要同步的内容' : '在以下位置显示双时钟',
          showClose: false,
          child: Builder(
            builder: (context) => multiple
                ? ElListGroup.multi(
                    modelValue: multi,
                    leading: markLeading,
                    children: [
                      for (final (name, subtitle) in [
                        ('同步文档', '多设备持续更新'),
                        ('同步图片', '保留珍贵的视觉记录'),
                        ('同步收藏', '随时找回喜欢的内容'),
                      ])
                        ElListTile(value: name, title: name, subtitle: subtitle),
                    ],
                  )
                : ElListGroup.single(
                    modelValue: single,
                    leading: markLeading,
                    children: [
                      for (final name in ['锁屏', '时钟桌面插件', '锁屏与时钟桌面插件'])
                        ElListTile(value: name, title: name, onTap: () => Navigator.of(context).pop(name)),
                    ],
                  ),
          ),
          footer: multiple ? demoPopupActions(confirm: '完成', onConfirm: () => '完成') : demoPopupActions(),
        );
        if (selected != null && context.mounted) {
          demoNotify(context, multiple ? '已选择 ${multi.value.length} 项同步内容' : '已选择：$selected');
        }
      }

      return ShowcasePanel(
        title: '选择面板',
        description: '单选与多选放入底部面板，保持清楚的选中反馈。',
        child: demoColumn([
          ElSegmented<bool>(
            modelValue: trailing,
            options: [
              ElSegmentedOption(value: false, label: '标记在前'),
              ElSegmentedOption(value: true, label: '标记在后'),
            ],
          ),
          demoActions([
            ElButton(variant: .outline, child: '打开单选面板', onPressed: () => selections(false)),
            ElButton(variant: .outline, child: '打开多选面板', onPressed: () => selections(true)),
          ]),
          demoHint(context, '双时钟：${single.value}\n同步内容：已选 ${multi.value.length} 项'),
        ]),
      );
    }, anchor: 'feedback-selection'),
    ShowcaseItem((context) {
      final center = useState(false);
      return ShowcasePanel(
        title: '确认与提醒',
        description: '单按钮提醒与危险操作确认，支持底部或居中展示。',
        child: demoColumn([
          ElSegmented<bool>(
            modelValue: center,
            options: [
              ElSegmentedOption(value: false, label: '底部'),
              ElSegmentedOption(value: true, label: '居中'),
            ],
          ),
          demoActions([
            ElButton(
              variant: .outline,
              child: '单按钮提醒',
              onPressed: () => demoDialog(
                context,
                title: '同步已完成',
                message: '你的文档和图片都已同步，可以安心继续浏览。',
                confirm: '知道了',
                single: true,
                placement: center.value ? .center : .bottom,
              ),
            ),
            ElButton(
              variant: .text,
              type: .error,
              child: '危险操作确认',
              onPressed: () async {
                if (await demoDialog(
                          context,
                          title: '移除本地缓存？',
                          message: '这是一项交互示例。确认后只展示操作结果，你的个人数据不会受影响。',
                          confirm: '移除',
                          danger: true,
                          placement: center.value ? .center : .bottom,
                        ) ==
                        true &&
                    context.mounted) {
                  demoNotify(context, '已确认移除（示例）');
                }
              },
            ),
          ]),
        ]),
      );
    }, anchor: 'feedback-confirm'),
  ], columns: mobile ? 1 : 3),
  ShowcaseItem((context) => _Touch()),
  ...ShowcaseItem.rows([
    ShowcaseItem(
      (context) =>
          ShowcasePanel(title: '基础菜单', description: '点击目标打开操作列表，在当前位置完成常用动作。', child: _menuTarget(context, '周末灵感.txt')),
    ),
    ShowcaseItem(
      (context) => ShowcasePanel(
        title: '上下文菜单',
        description: '右键或长按内容，显示与当前项目有关的操作。',
        child: demoColumn([
          _menuTarget(context, '设计灵感', contextOnly: true),
          _menuTarget(context, '旅行计划', contextOnly: true),
        ], gap: 12),
      ),
    ),
    ShowcaseItem((context) {
      final selected = useState('日常灵感'), sync = useState(['文档']);
      return ShowcasePanel(
        title: '选择菜单',
        description: '菜单中展示单选和多选状态，选择后更新当前内容。',
        child: demoColumn([
          ElListTile<String>.popup(
            title: '内容分类',
            modelValue: selected,
            options: [
              for (final label in ['日常灵感', '设计收藏', '旅行计划']) ElMenuOption(label, label),
            ],
          ),
          _menuTarget(
            context,
            '同步内容：${sync.value.join('、')}',
            options: [
              for (final label in ['文档', '图片', '收藏'])
                ElContextMenuItem(
                  label: label,
                  checked: sync.value.contains(label),
                  onSelect: () => sync.value = sync.value.contains(label)
                      ? sync.value.where((v) => v != label).toList()
                      : [...sync.value, label],
                ),
            ],
          ),
        ], gap: 12),
      );
    }),
    ShowcaseItem(
      (context) => ShowcasePanel(
        title: '级联菜单',
        description: '层级选项复用已有菜单机制，子选项保留业务值。',
        child: ElListTile<String?>.popup(
          title: '移动到收藏夹',
          value: null,
          options: [
            ElMenuOption('工作', 'work', children: [ElMenuOption('设计规范', 'design'), ElMenuOption('产品资料', 'product')]),
            ElMenuOption('生活', 'life', children: [ElMenuOption('旅行计划', 'travel'), ElMenuOption('日常灵感', 'daily')]),
            ElMenuOption('暂不可用', 'disabled', disabled: true),
          ],
          onChanged: (value) {
            if (value != null) demoNotify(context, '已移动到：$value');
          },
        ),
      ),
    ),
  ], columns: mobile ? 1 : 2),
];

Widget _promptAction(BuildContext context, String label, VoidCallback onPressed) => ElButton(
  variant: .link,
  style: ElStyle(margin: .only(top: 8), padding: .symmetric(horizontal: 14)),
  onPressed: onPressed,
  child: Row(
    mainAxisSize: .min,
    spacing: 6,
    children: [
      ElView(child: label),
      demoIcon(ElMobileIcons.arrowRight, size: 16),
    ],
  ),
);

Widget _menuTarget(BuildContext context, String text, {bool contextOnly = false, List<ElContextMenuItem>? options}) {
  void menu(ElEventDetails event, List<ElContextMenuItem> items) => el.showContextMenu(
    context,
    position: event.globalPosition,
    items: items,
    menu: ElMobileContextMenu(),
    triggerEvent: event,
  );
  List<ElContextMenuItem> commands() => [
    ElContextMenuItem(
      label: '复制链接',
      icon: ElMobileIcons.copy,
      onSelect: () {
        Clipboard.setData(ClipboardData(text: 'flutter-base://home'));
        demoNotify(context, '链接已复制');
      },
    ),
    ElContextMenuItem(label: '加入收藏', icon: ElMobileIcons.heart, onSelect: () => demoNotify(context, '已加入收藏')),
    ElContextMenuItem.divider(),
    ElContextMenuItem(label: '删除', icon: ElMobileIcons.trash, onSelect: () => demoNotify(context, '已删除示例项目')),
  ];
  return ElCard(
    event: ElEvent(
      onTap: contextOnly ? null : (event) => menu(event, options ?? commands()),
      onSecondaryTap: (event) => menu(event, options ?? commands()),
      onLongPress: (event) => menu(event, options ?? commands()),
    ),
    style: ElStyle(padding: .all(20), borderRadius: .circular(16), backgroundColor: context.elTheme.fill),
    child: Row(
      spacing: 12,
      children: [
        demoIcon(ElMobileIcons.file, color: context.elTheme.primary),
        Expanded(child: Text(text)),
        demoIcon(ElMobileIcons.grid, size: 18),
      ],
    ),
  );
}

class _SharedState extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final note = useState('记录一点今天的灵感'), count = useState(0);
    return _SharedPanel(note: note, count: count);
  }
}

class _SharedPanel extends StatelessWidget {
  const _SharedPanel({required this.note, required this.count, this.secondary = false});

  final ValueNotifier<String> note;
  final ValueNotifier<int> count;
  final bool secondary;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([note, count]),
    builder: (context, _) => ShowcasePanel(
      title: '跨页共享状态',
      description: '两页共用当前示例的备注和计数。',
      child: demoColumn([
        demoLabel(context, '共享备注'),
        ElInput(modelValue: note, clearable: true, semanticLabel: '共享备注'),
        demoActions([
          ElButton(variant: .outline, child: '共享计数 ${count.value}', onPressed: () => count.value++),
          if (!secondary)
            ElButton(
              child: '打开另一页',
              icon: ElMobileIcons.arrowRight,
              onPressed: () {
                final scope = ShowcaseScope.of(context);
                final child = InheritedTheme.captureAll(
                  context,
                  ShowcaseScope(
                    width: scope.width,
                    anchors: {},
                    onNavigate: (_) {},
                    child: Scaffold(
                      appBar: AppBar(title: Text('跨页共享状态')),
                      body: SingleChildScrollView(
                        padding: .all(16),
                        child: _SharedPanel(note: note, count: count, secondary: true),
                      ),
                    ),
                  ),
                );
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => child));
              },
            ),
          ElButton(
            variant: .text,
            child: '重置数据',
            onPressed: () {
              note.value = '记录一点今天的灵感';
              count.value = 0;
            },
          ),
        ], gap: 12),
        demoHint(context, '在当前窗口进入另一页；返回后保留原来的输入与滚动位置。', size: 13, height: 1.8),
      ], gap: 16),
    ),
  );
}

class _DrawerProfile extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final name = useState('小蓝同学');
    final notes = useState('让每个界面都简单一点。');
    final reminders = useState(true);
    return demoColumn([
      Padding(padding: .only(bottom: 8), child: demoHint(context, '在抽屉里编辑，返回时仍停留在当前页面。', size: 14, height: 1.7)),
      demoColumn([
        demoLabel(context, '显示名称'),
        ElInput(value: name.value, onChanged: (value) => name.value = value, clearable: true, semanticLabel: '显示名称'),
      ], gap: 8),
      demoColumn([
        demoLabel(context, '个人简介'),
        ElInput(
          value: notes.value,
          onChanged: (value) => notes.value = value,
          textarea: true,
          minLine: 4,
          maxLine: 4,
          maxLength: 120,
          semanticLabel: '个人简介',
        ),
      ], gap: 8),
      demoColumn([
        demoLabel(context, '消息提醒'),
        Row(
          spacing: 8,
          children: [
            ElSwitch(modelValue: reminders),
            Expanded(child: demoLabel(context, '接收消息提醒')),
          ],
        ),
      ], gap: 8),
      demoActions([
        ElButton(
          child: '保存资料',
          onPressed: () async {
            final accepted = await demoDialog(
              context,
              title: '保存这份资料？',
              message: '确认后关闭抽屉，并保留本次填写的显示名称。',
              confirm: '保存',
              placement: .center,
            );
            if (accepted == true && context.mounted) Navigator.of(context).pop(name.value);
          },
        ),
        ElButton(variant: .text, child: '取消编辑', onPressed: () => Navigator.of(context).pop()),
      ]),
    ]);
  }
}

class _Touch extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final page = useState('概览');
    final records = [
      ('概览', '把日常，整理得更轻松', '在内容区域左右滑动，下一页会跟随手指进入。', ElMobileIcons.grid, ['今天的灵感', '最近的收藏']),
      ('文件', '内容都在手边', '缓慢拖动再松手，试试切页与回弹的距离感。', ElMobileIcons.inbox, ['设计规范', '旅行计划']),
      ('动态', '每一步都有回应', '竖向仍可滚动页面，按钮也可以正常点击。', ElMobileIcons.clock, ['小蓝更新了文档', '团队完成了同步']),
    ];
    Widget panel() => Builder(
      builder: (context) => demoColumn([
        Padding(
          padding: .fromLTRB(24, 0, 24, 18),
          child: demoHint(context, '从标题区域拖动关闭。正文可以正常滚动，到达边缘后再向外拖动。', size: 14, height: 1.8),
        ),
        ElListGroup(
          children: [
            for (var i = 1; i <= 14; i++)
              ElListTile(
                title: '灵感记录 ${'$i'.padLeft(2, '0')}',
                subtitle: '保留值得回看的日常片段',
                onTap: () => Navigator.of(context).pop('灵感记录 $i'),
              ),
          ],
        ),
      ], gap: 0),
    );
    Future<void> open(bool bottom) async {
      final result = bottom
          ? await el.dialog.show<String>(
              context,
              placement: .bottom,
              title: '最近的灵感',
              showClose: false,
              child: panel(),
              footer: demoPopupActions(cancel: '关闭'),
            )
          : await el.drawer.show<String>(
              context,
              title: '我的工作空间',
              style: ElStyle(
                vars: {
                  ElTokens.$drawerBodyPadding: EdgeInsets.symmetric(vertical: 16),
                  ElTokens.$popupListPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                },
              ),
              child: panel(),
            );
      if (context.mounted && result != null) demoNotify(context, '已打开：$result');
    }

    return ShowcasePanel(
      title: '跟手滑动',
      description: '左右切页，拖动与回弹沿用已有交互视图。',
      child: demoColumn([
        ElTabs<String>(
          modelValue: page,
          panes: [
            for (final record in records)
              ElTabPane(
                value: record.$1,
                label: record.$1,
                child: Padding(
                  padding: .only(top: 16),
                  child: ElCard(
                    style: ElStyle(
                      padding: .all(22),
                      borderRadius: .circular(18),
                      backgroundColor: context.elTheme.bgColor,
                    ),
                    child: demoColumn([
                      Row(
                        spacing: 16,
                        children: [
                          demoIcon(record.$4, size: 30, color: context.elTheme.primary),
                          Expanded(
                            child: demoColumn([
                              Text(record.$2, style: TextStyle(fontSize: 16, fontWeight: .w600)),
                              demoHint(context, record.$3, size: 13),
                            ], gap: 7),
                          ),
                        ],
                      ),
                      for (final title in record.$5)
                        ElListTile(title: title, onTap: () => demoNotify(context, '已打开：$title')),
                    ], gap: 12),
                  ),
                ),
              ),
          ],
        ),
        demoActions([
          ElButton(variant: .outline, child: '滑动抽屉 →', onPressed: () => open(false)),
          ElButton(variant: .outline, child: '下拉面板', onPressed: () => open(true)),
          demoHint(context, '使用单指触摸体验'),
        ], gap: 12),
      ], gap: 22),
    );
  }
}
