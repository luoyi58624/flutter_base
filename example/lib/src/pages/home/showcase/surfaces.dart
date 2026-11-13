import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';

/// 卡片、头像图片、导航与列表展示。
class SurfacesShowcase extends StatelessWidget {
  /// 创建内容容器分区。
  const SurfacesShowcase({super.key});
  @override
  Widget build(BuildContext context) => ShowcaseSection(
    id: 'surfaces',
    number: '03',
    category: '内容容器',
    title: '卡片与导航',
    description: '柔和的层次和留白，突出内容本身。',
    links: {'surface-cards': '卡片与阴影', 'surface-images': '头像与图片', 'surface-navigation': '导航与列表'},
    child: showcaseColumn([
      demoAnchor(context, 'surface-cards', _Cards()),
      _Shadows(),
      demoAnchor(context, 'surface-images', _Identity()),
      _Images(),
      demoAnchor(context, 'surface-navigation', _AppBar()),
      _Navigation(),
      _Lists(),
    ], gap: 22),
  );
}

class _Cards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    Widget heading(String title, String description) => demoColumn([
      Text(
        title,
        style: TextStyle(fontSize: 20, height: 1.5, fontWeight: .w600, color: t.textColor),
      ),
      demoHint(context, description, size: 13),
    ], gap: 8);
    return showcaseColumn([
      heading('快捷卡片', 'onTap 开启整张卡片的按压反馈，统一处理触摸与显式启用的键盘激活。'),
      ShowcaseGrid(
        columns: 4,
        mobileColumns: 2,
        gap: 12,
        children: [
          for (final item in [
            ('清理存储', '36.8 GB / 128 GB', ElMobileIcons.inbox),
            ('安全检查', '设备状态良好', ElMobileIcons.shield),
            ('运行状态', '让日常使用更轻快', ElMobileIcons.spark),
            ('应用管理', '查看全部应用', ElMobileIcons.grid),
          ])
            ElCard(
              onTap: () => demoNotify(context, '${item.$1}（交互示例）'),
              style: ElStyle(
                minHeight: 138,
                padding: .symmetric(horizontal: 16, vertical: 17),
                borderRadius: .circular(22),
              ).withShadow(level: ElLevelType.md.shadow(context)),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  demoIcon(item.$3, size: 26, color: t.textColor),
                  SizedBox(height: 24),
                  Text(
                    item.$1,
                    style: TextStyle(fontSize: 17, height: 1.4, fontWeight: .w600, color: t.textColor),
                  ),
                  SizedBox(height: 5),
                  demoHint(context, item.$2, height: 1.5),
                ],
              ),
            ),
        ],
      ),
      SizedBox(height: 8),
      heading('图文内容卡片', '使用内容插槽组织图标、状态、图片与正文，以整张卡片作为操作入口。'),
      ElCard(
        onTap: () => demoNotify(context, '已打开云端同步示例'),
        style: ElStyle(
          minHeight: 270,
          padding: .all(24),
          borderRadius: .circular(24),
          backgroundColor: t.cardColor,
        ).withShadow(level: ElLevelType.md.shadow(context)),
        child: demoColumn([
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              ElView(
                style: ElStyle(
                  width: 44,
                  height: 44,
                  alignment: .center,
                  borderRadius: .circular(14),
                  backgroundColor: t.fill,
                ),
                child: demoIcon(ElMobileIcons.cloud, size: 24, color: t.primary),
              ),
              Row(
                mainAxisSize: .min,
                spacing: 6,
                children: [
                  ElView(
                    style: ElStyle(width: 6, height: 6, borderRadius: .circular(3), backgroundColor: t.success),
                  ),
                  Text('同步正常', style: TextStyle(color: t.success, fontSize: 12)),
                ],
              ),
            ],
          ),
          SizedBox(height: 4),
          demoHint(context, '随时随地，保持连接'),
          Text(
            '重要的内容，\n始终在你身边。',
            style: TextStyle(fontSize: 27, height: 1.35, fontWeight: .w600, color: t.textColor),
          ),
          demoHint(context, '照片、文档与收藏，在每一台设备上保持同步。', size: 13),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: demoHint(context, '最近同步于 2 分钟前')),
              demoIcon(ElMobileIcons.arrowRight, color: t.primary),
            ],
          ),
        ], gap: 12),
      ),
      ElCard(
        onTap: () => demoNotify(context, '已打开周末旅行示例'),
        style: ElStyle(
          padding: .zero,
          borderRadius: .circular(24),
          clipBehavior: .antiAlias,
        ).withShadow(level: ElLevelType.md.shadow(context)),
        child: Column(
          mainAxisSize: .min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: (constraints.maxWidth * 7 / 16).clamp(0, 300),
                width: double.infinity,
                child: ElImageView(showcaseLake, fit: .cover, alt: '平静的湖面与远山'),
              ),
            ),
            Padding(
              padding: .all(24),
              child: demoColumn([
                demoHint(context, '周末灵感'),
                Text(
                  '去湖边走走',
                  style: TextStyle(fontSize: 26, fontWeight: .w600, color: t.textColor),
                ),
                demoHint(context, '放慢一点，把时间留给风景。', size: 13),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: demoHint(context, '一份轻松出发的小计划')),
                    demoIcon(ElMobileIcons.arrowRight, color: t.primary),
                  ],
                ),
              ], gap: 10),
            ),
          ],
        ),
      ),
    ], gap: 18);
  }
}

class _Shadows extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.elTheme, scope = ShowcaseScope.of(context);
    final levels = <(String, String, int)>[
      ('无阴影', '内容自然融入', 0),
      ('轻阴影', '轻微抬起', ElLevelType.xs.shadow(context)),
      ('卡片阴影', '日常内容分组', ElLevelType.md.shadow(context)),
      ('浮层阴影', '菜单与下拉面板', ElLevelType.lg.shadow(context)),
      ('模态阴影', '重要的确认', ElLevelType.xl.shadow(context)),
    ];
    return ShowcasePanel(
      title: '阴影层级',
      description: '从安静的内容表面到浮起的操作面板，以阴影表达层级。',
      child: demoColumn([
        ShowcaseGrid(
          columns: scope.width <= 1000 ? 3 : 5,
          mobileColumns: scope.width <= 380 ? 1 : 2,
          gap: 16,
          children: [
            for (final item in levels)
              demoColumn([
                ElCard(
                  style: ElStyle(
                    height: 160,
                    alignment: .center,
                    padding: .all(18),
                    borderRadius: .circular(16),
                    backgroundColor: t.fill,
                  ),
                  child: ElCard(
                    style: ElStyle(
                      width: 94,
                      height: 76,
                      padding: .zero,
                      alignment: .center,
                      borderRadius: .circular(18),
                    ).withShadow(level: item.$3),
                    child: demoIcon(ElMobileIcons.layer, color: t.primary),
                  ),
                ),
                Text(
                  item.$1,
                  style: TextStyle(fontSize: 13, fontWeight: .w600, color: t.textColor),
                ),
                demoHint(context, item.$2),
              ], gap: 7),
          ],
        ),
        demoActions([
          ElButton(
            variant: .outline,
            child: '体验浮层',
            onPressed: () => el.popup(context, title: '浮起的内容', child: Text('柔和的阴影，让内容层次更清楚。')),
          ),
          ElButton(
            variant: .text,
            child: '体验模态',
            onPressed: () => demoDialog(
              context,
              title: '重要的确认',
              message: '适度强调，让注意力停留在此刻。',
              confirm: '知道了',
              single: true,
              placement: .center,
            ),
          ),
        ]),
      ], gap: 24),
    );
  }
}

class _Identity extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final unread = useState(12), quiet = useState(false), t = context.elTheme;
    Widget caption(Widget child, String text) =>
        Column(mainAxisSize: .min, spacing: 12, children: [child, demoHint(context, text)]);
    Widget badge(int value, Widget icon, String label, {bool dot = false, bool always = false}) => caption(
      ElBadge(
        value: value,
        isDot: dot,
        hidden: !always && quiet.value,
        bgColor: t.error,
        child: ElButton(
          variant: .text,
          semanticLabel: label,
          style: ElStyle(width: 44, height: 44, padding: .zero, iconSize: 24),
          child: icon,
          onPressed: () => unread.value = 0,
        ),
      ),
      label,
    );
    return showcaseColumn([
      ShowcasePanel(
        title: '头像与身份',
        description: '用头像、名称和状态快速建立身份感。',
        child: Row(
          spacing: 16,
          children: [
            ElBadge(
              isDot: true,
              bgColor: t.success,
              child: ElAvatar(src: showcaseAvatar, size: 56, alt: '小蓝'),
            ),
            Expanded(
              child: demoColumn([
                Text(
                  '小蓝同学',
                  style: TextStyle(fontSize: 16, fontWeight: .w600, color: t.textColor),
                ),
                demoHint(context, '记录灵感，也收集日常的好风景。', size: 13),
              ], gap: 7),
            ),
            if (!ShowcaseScope.of(context).mobile) ElTag(child: '创作者'),
          ],
        ),
      ),
      ShowcaseGrid(
        children: [
          ShowcasePanel(
            title: '不同头像',
            description: '图片、文字与默认图标都能表达身份。',
            child: demoActions([
              caption(ElAvatar(src: showcaseAvatar, size: 48, alt: '小蓝'), '图片头像'),
              caption(
                ElAvatar(
                  alt: '青',
                  size: 40,
                  style: ElStyle(backgroundColor: t.success.withValues(alpha: .12), color: t.success),
                ),
                '文字头像',
              ),
              caption(ElAvatar(alt: 'Alex Morgan', size: 40, shape: .square, child: 'AM'), '方形头像'),
              caption(ElAvatar(alt: '访', size: 32), '小尺寸'),
              caption(ElAvatar(size: 40), '默认头像'),
            ], gap: 18),
          ),
          ShowcasePanel(
            title: '徽标',
            description: '数字合并超出上限的值，圆点与零值保持清晰。',
            child: demoColumn([
              demoActions([
                badge(unread.value, ElMobileIcons.bell, '未读数字'),
                badge(128, ElMobileIcons.message, '超出上限'),
                badge(0, ElMobileIcons.heart, '圆点提醒', dot: true),
                badge(0, ElMobileIcons.inbox, '保留零值', always: true),
              ], gap: 18),
              demoActions([
                ElButton(
                  variant: .text,
                  child: unread.value > 0 ? '清空未读' : '恢复未读',
                  onPressed: () => unread.value = unread.value > 0 ? 0 : 12,
                ),
                ElButton(
                  variant: .text,
                  child: quiet.value ? '显示提醒' : '暂时隐藏',
                  onPressed: () => quiet.value = !quiet.value,
                ),
              ], gap: 8),
            ], gap: 24),
          ),
        ],
      ),
    ], gap: 22);
  }
}

class _Images extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final fit = useState('cover'), loaded = useState(false), recovered = useState(false);
    final t = context.elTheme;
    Widget stage(Widget child, double ratio) => ElCard(
      style: ElStyle(padding: .zero, borderRadius: .circular(14), clipBehavior: .antiAlias, backgroundColor: t.fill),
      child: AspectRatio(aspectRatio: ratio, child: child),
    );
    Widget placeholder(Widget icon, String text) => Center(
      child: Column(
        mainAxisSize: .min,
        spacing: 12,
        children: [
          demoIcon(icon, size: 28, color: t.gray),
          demoHint(context, text),
        ],
      ),
    );
    return ShowcaseGrid(
      children: [
        ShowcasePanel(
          title: '图片填充',
          description: 'cover、contain 与 fill 决定图片如何放入内容区域。',
          child: demoColumn([
            stage(
              ElImageView(
                showcaseLake,
                fit: switch (fit.value) {
                  'contain' => BoxFit.contain,
                  'fill' => BoxFit.fill,
                  _ => BoxFit.cover,
                },
                alt: '湖面与远山',
              ),
              16 / 9,
            ),
            ElSegmented<String>(
              modelValue: fit,
              options: [
                for (final value in ['cover', 'contain', 'fill']) ElSegmentedOption(value: value, label: value),
              ],
            ),
          ]),
        ),
        ShowcasePanel(
          title: '加载占位',
          description: '内容准备好之前，先提供安静的占位反馈。',
          child: demoColumn([
            stage(
              loaded.value
                  ? ElImageView(showcaseLake, fit: .cover, placeholder: placeholder(ElMobileIcons.image, '正在加载图片'))
                  : placeholder(ElMobileIcons.image, '等待加载图片'),
              3 / 2,
            ),
            ElButton(
              variant: .outline,
              child: loaded.value ? '重置占位' : '加载图片',
              onPressed: () => loaded.value = !loaded.value,
            ),
          ]),
        ),
        ShowcasePanel(
          title: '加载失败',
          description: '图片不可用时展示明确反馈，并提供重新加载入口。',
          child: demoColumn([
            stage(
              ElImageView(
                recovered.value ? showcaseLake : 'assets/showcase/missing.png',
                fit: .cover,
                error: placeholder(ElMobileIcons.alertCircle, '图片暂时无法显示'),
              ),
              3 / 2,
            ),
            ElButton(
              variant: .outline,
              child: recovered.value ? '模拟失败' : '恢复图片',
              onPressed: () => recovered.value = !recovered.value,
            ),
          ]),
        ),
      ],
    );
  }
}

class _AppBar extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final centered = useState(true), t = context.elTheme;
    Widget action(String label, Widget icon) => ElButton(
      variant: .text,
      semanticLabel: label,
      style: ElStyle(width: 36, height: 44, padding: .zero, iconSize: 19),
      child: icon,
      onPressed: () => demoNotify(context, label),
    );
    return ShowcasePanel(
      title: '标题与操作区',
      description: '组合标题、返回与右侧操作，切换居中设置观察标题的位置。',
      child: demoColumn([
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: ElCard(
              style: ElStyle(
                height: 300,
                padding: .zero,
                borderRadius: .circular(16),
                border: .all(borderColor: t.borderColor),
                backgroundColor: t.fill,
                clipBehavior: .antiAlias,
              ),
              child: Column(
                children: [
                  ElAppBar(
                    title: '我的收藏',
                    subtitle: '把喜欢的，留在这里',
                    back: true,
                    centerTitle: centered.value,
                    onBack: () => demoNotify(context, '已点击返回'),
                    actions: [action('搜索收藏', ElMobileIcons.search), action('收藏操作', ElMobileIcons.grid)],
                  ),
                  Expanded(
                    child: ElScrollView(
                      padding: .all(24),
                      spacing: 14,
                      children: [
                        Align(
                          alignment: .centerLeft,
                          child: demoIcon(ElMobileIcons.heart, size: 28, color: t.primary),
                        ),
                        Text(
                          '一点日常的好风景',
                          style: TextStyle(fontSize: 16, fontWeight: .w600, color: t.textColor),
                        ),
                        demoHint(context, '顶栏与页面内容各有自己的位置。滚动这块区域，顶栏会留在顶部。', size: 13),
                        for (final title in ['周末的散步', '随手记下的灵感', '旅途中的照片', '等待完成的计划'])
                          ElListTile(
                            title: title,
                            leading: ElMobileIcons.image,
                            trailing: null,
                            onTap: () => demoNotify(context, title),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        demoActions([
          demoHint(context, '左右操作区宽度不同，居中标题也保持对齐。'),
          ElButton(
            variant: .text,
            child: centered.value ? '标题靠左' : '标题居中',
            onPressed: () => centered.value = !centered.value,
          ),
        ]),
      ]),
    );
  }
}

class _Navigation extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final index = useState(0);
    final labels = ['首页', '发现', '消息', '我的'];
    return ShowcasePanel(
      title: '底部导航',
      description: '保持稳定的一级入口，让当前所在位置清楚可见。',
      child: demoColumn([
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: ElCard(
              style: ElStyle(
                padding: .zero,
                borderRadius: .circular(18),
                clipBehavior: .antiAlias,
                border: .all(borderColor: context.elTheme.borderColor),
              ),
              child: ElBottomTabbar(
                selectedIndex: index.value,
                onDestinationSelected: (value) => index.value = value,
                destinations: [
                  for (final item in [
                    (ElMobileIcons.home, '首页'),
                    (ElMobileIcons.grid, '发现'),
                    (ElMobileIcons.message, '消息'),
                    (ElMobileIcons.user, '我的'),
                  ])
                    NavigationDestination(icon: item.$1, label: item.$2),
                ],
              ),
            ),
          ),
        ),
        demoHint(context, '当前页面：${labels[index.value]}'),
      ]),
    );
  }
}

class _Lists extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final appearance = useState('跟随系统'), sync = useState(['文档', '图片']), auto = useState(true), sort = useState('最近更新');
    return ShowcaseGrid(
      children: [
        ShowcasePanel(
          title: '选择列表',
          description: '单选与多选使用同一列表结构，整行都可以轻松选择。',
          child: demoColumn([
            ElListGroup.single(
              modelValue: appearance,
              title: '外观模式',
              children: [
                ElListTile(value: '跟随系统', title: '跟随系统', subtitle: '与设备当前主题保持一致'),
                ElListTile(value: '浅色模式', title: '浅色模式', subtitle: '明亮、清晰的界面'),
                ElListTile(value: '深色模式', title: '深色模式', subtitle: '适合夜间和低光环境'),
              ],
            ),
            ElListGroup.multi(
              modelValue: sync,
              title: '同步内容',
              children: [
                for (final label in ['文档', '图片', '收藏']) ElListTile(value: label, title: label),
              ],
            ),
          ], gap: 24),
        ),
        ShowcasePanel(
          title: '设置列表',
          description: '把导航、说明、开关和选择集中在熟悉的列表中。',
          child: ElListGroup(
            title: '常用设置',
            children: [
              ElListTile(title: '个人资料', leading: ElMobileIcons.user, onTap: () => demoNotify(context, '已打开个人资料')),
              ElListTile(title: '隐私', leading: ElMobileIcons.shield, onTap: () => demoNotify(context, '已打开隐私设置')),
              ElListTile(
                title: '内存',
                subtitle: '显示应用的内存占用情况，帮助你了解当前设备的运行状态。',
                leading: ElMobileIcons.inbox,
                onTap: () => demoNotify(context, '内存使用正常'),
              ),
              ElListTile(
                title: 'WebView',
                trailingText: 'Android System WebView',
                leading: ElMobileIcons.layer,
                onTap: () => demoNotify(context, 'Android System WebView'),
              ),
              ElListTile<bool>.switcher(title: '自动更新', leading: ElMobileIcons.cloud, modelValue: auto),
              ElListTile<String>.popup(
                title: '排序方式',
                leading: ElMobileIcons.sliders,
                modelValue: sort,
                options: [
                  for (final label in ['最近更新', '名称顺序', '最早创建']) ElMenuOption(label, label),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
