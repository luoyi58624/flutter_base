import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';

/// 按钮与标签的各张示例卡独立挂载。
List<ShowcaseItem> buttonShowcaseItems(double width) => [
  ShowcaseItem(
    (context) =>
        ShowcaseSection(id: 'actions', number: '01', category: '基础组件', title: '按钮与标签', description: '清晰的操作层级，自然的按压反馈。'),
    anchor: 'actions',
    gap: 0,
  ),
  ShowcaseItem(
    (context) => Text(
      '按钮',
      style: TextStyle(fontSize: 17, fontWeight: .w600, color: context.elTheme.textColor),
    ),
    gap: 12,
  ),
  ...ShowcaseItem.rows(
    [
      ShowcaseItem(
        (context) => ShowcasePanel(
          key: ValueKey('showcase-basic-panel'),
          title: '基础用法',
          description: '通过 variant 区分主要、描边和文本操作，按操作优先级选择。',
          child: demoActions([
            ElButton(child: '主要按钮', onPressed: () => demoNotify(context, '主要操作已执行')),
            ElButton(variant: .outline, child: '镂空按钮', onPressed: () => demoNotify(context, '镂空按钮已点击')),
            ElButton(
              variant: .text,
              child: Row(
                mainAxisSize: .min,
                spacing: 6,
                children: [
                  ElView(child: '文本按钮'),
                  demoIcon(ElMobileIcons.chevronRight, size: 16),
                ],
              ),
              onPressed: () => demoNotify(context, '已打开详情'),
            ),
          ], gap: 9),
        ),
        gap: 20,
      ),
      ShowcaseItem(
        (context) {
          final liked = useState(false);
          final t = context.elTheme;
          Future<void> share() async {
            final action = await demoShare(context);
            if (!context.mounted) return;
            if (action == 'favorite') liked.value = true;
          }

          Widget iconButton(
            String label,
            Widget icon,
            VoidCallback onTap, {
            bool selected = false,
            bool bare = false,
          }) => ElButton(
            key: label == '收藏' ? ValueKey('showcase-favorite') : null,
            semanticLabel: label,
            variant: .text,
            onPressed: onTap,
            style: ElStyle(
              width: 44,
              height: 44,
              padding: .zero,
              borderRadius: .circular(22),
              backgroundColor: bare ? Colors.transparent : t.fill,
              iconColor: selected
                  ? t.error
                  : bare
                  ? t.textSecondary
                  : t.textColor,
              iconSize: 20,
            ),
            child: icon,
          );
          return ShowcasePanel(
            title: '图标按钮',
            description: '独立图标使用 semanticLabel 描述操作，切换状态通过模型绑定。',
            child: demoActions([
              iconButton('收藏', ElMobileIcons.heart, () {
                liked.value = !liked.value;
                demoNotify(context, liked.value ? '已加入收藏' : '已取消收藏');
              }, selected: liked.value),
              iconButton('分享', ElMobileIcons.share, share),
              iconButton('添加', ElMobileIcons.add, () => demoNotify(context, '已添加新项目（原型示例）')),
              ElButton(
                semanticLabel: '更多',
                variant: .text,
                style: ElStyle(width: 44, height: 44, padding: .zero, iconColor: t.textSecondary),
                event: ElEvent(
                  onTap: (event) => el.showContextMenu(
                    context,
                    position: event.globalPosition,
                    menu: ElMobileContextMenu(),
                    items: [
                      ElContextMenuItem(
                        label: '收藏',
                        icon: ElMobileIcons.heart,
                        onSelect: () {
                          liked.value = true;
                          demoNotify(context, '已收藏');
                        },
                      ),
                      ElContextMenuItem(
                        label: '稍后查看',
                        icon: ElMobileIcons.clock,
                        onSelect: () {
                          demoNotify(context, '已加入稍后查看');
                        },
                      ),
                      ElContextMenuItem(label: '分享', icon: ElMobileIcons.share, onSelect: share),
                    ],
                  ),
                ),
                child: ElMobileIcons.grid,
              ),
            ]),
          );
        },
        anchor: 'actions-buttons',
        gap: 20,
      ),
      ShowcaseItem(
        (context) => ShowcasePanel(
          key: ValueKey('showcase-state-panel'),
          title: '图标与禁用状态',
          description: 'icon 为按钮添加前置图标，disabled 阻止点击与激活。',
          child: demoActions([
            ElButton(icon: ElMobileIcons.check, child: '带图标按钮', onPressed: () => demoNotify(context, '已保存')),
            ElButton(disabled: true, child: '禁用按钮'),
          ]),
        ),
        gap: 20,
      ),
    ],
    columns: width <= 760
        ? 1
        : width >= 1060
        ? 3
        : 2,
    gap: width <= 760 ? 20 : 24,
  ),
  ShowcaseItem((context) => SizedBox(height: (width * .04).clamp(28, 44) - 24), gap: 0),
  ShowcaseItem(
    (context) => Text(
      '标签',
      style: TextStyle(fontSize: 17, fontWeight: .w600, color: context.elTheme.textColor),
    ),
    gap: 12,
  ),
  ...ShowcaseItem.rows([
    ShowcaseItem(
      (context) => ShowcasePanel(
        title: '状态标签',
        description: '用简短状态与语义色，补充内容信息。',
        child: demoActions([
          for (final item in [
            ('推荐', ElThemeType.primary),
            ('已完成', ElThemeType.success),
            ('处理中', ElThemeType.info),
            ('需留意', ElThemeType.warning),
            ('草稿', ElThemeType.info),
          ])
            ElTag(type: item.$2, child: item.$1),
        ], gap: 8),
      ),
    ),
    ShowcaseItem((context) {
      final tag = useState('灵感');
      return ShowcasePanel(
        title: '单选标签组',
        description: '选择一个偏好，选中状态与当前值保持一致。',
        child: demoColumn([
          demoActions([
            for (final label in ['灵感', '云端', '发现', '音乐'])
              ElTag.toggle(value: tag.value == label, onChanged: (_) => tag.value = label, child: label),
          ], gap: 8),
          demoHint(context, '当前偏好：${tag.value}'),
        ]),
      );
    }),
    ShowcaseItem((context) {
      final tags = useState(['灵感']);
      return ShowcasePanel(
        title: '多选标签组',
        description: '多个标签可以同时选择，禁用选项保留状态提示。',
        child: demoColumn([
          demoActions([
            for (final label in ['灵感', '云端', '发现', '音乐', '未开放'])
              ElTag.toggle(
                value: tags.value.contains(label),
                disabled: label == '未开放',
                onChanged: (selected) =>
                    tags.value = selected ? [...tags.value, label] : tags.value.where((v) => v != label).toList(),
                child: label,
              ),
          ], gap: 8),
          demoHint(context, '已选：${tags.value.isEmpty ? '暂无' : tags.value.join('、')}'),
        ]),
      );
    }),
    ShowcaseItem((context) {
      final later = useState(false);
      return ShowcasePanel(
        title: '独立选择标签',
        description: '轻量布尔状态，适合收藏、稍后阅读等独立操作。',
        child: demoColumn([
          demoActions([
            ElTag.toggle(modelValue: later, child: '稍后阅读'),
            ElTag.toggle(disabled: true, child: '暂不可选'),
          ], gap: 8),
          demoHint(context, later.value ? '已加入稍后阅读' : '尚未加入稍后阅读'),
        ]),
      );
    }),
  ], columns: width <= 760 ? 1 : 2),
];
