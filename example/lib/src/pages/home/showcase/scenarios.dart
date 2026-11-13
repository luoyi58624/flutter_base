import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';
import '../../examples/sliver_takeaway/index.dart';

/// 表单、内容加载、标签页、输入状态和外卖的组合场景。
class ScenariosShowcase extends StatelessWidget {
  /// 创建完整场景分区。
  const ScenariosShowcase({super.key});
  @override
  Widget build(BuildContext context) => ShowcaseSection(
    id: 'scenarios',
    number: '05',
    category: '完整示例',
    title: '组件如何配合',
    description: '从资料编辑到内容加载，体验多个组件一起工作。',
    links: {
      'scenario-form': '资料编辑',
      'scenario-feed': '内容加载',
      'scenario-tabs': '标签页',
      'scenario-inputs': '输入状态',
      'takeaway': '外卖虚拟列表',
    },
    child: showcaseColumn([
      _Profile(),
      ShowcaseGrid(children: [_Feed(), _Tabs()]),
      _Inputs(),
      ShowcasePanel(
        anchor: 'takeaway',
        title: '外卖虚拟列表',
        description: '一千家模拟商家，支持分类、搜索、排序和购物车。',
        child: TakeawayShowcase(),
      ),
    ], gap: 22),
  );
}

Map<String, dynamic> _initialProfile() => {
  'name': '小蓝同学',
  'email': '',
  'bio': '',
  'notifications': true,
  'plan': '标准体验',
  'features': ['云端同步'],
};

class _Profile extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final layout = useState('垂直布局'),
        data = useState(_initialProfile()),
        saving = useState(false),
        message = useState('');
    final count = useRef(0), timer = useRef<Timer?>(null);
    final keys = useMemoized(
      () => {
        for (final name in ['name', 'email', 'features']) name: GlobalKey(),
      },
    );
    final nameFocus = useFocusNode(), emailFocus = useFocusNode();
    useEffect(
      () =>
          () => timer.value?.cancel(),
      [],
    );
    return ShowcasePanel(
      anchor: 'scenario-form',
      title: '资料编辑与校验',
      description: '切换表单布局，体验校验、错误定位、异步提交与重置。',
      child: demoColumn([
        Wrap(
          spacing: 22,
          runSpacing: 12,
          crossAxisAlignment: .center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 350),
              child: ElSegmented<String>(
                modelValue: layout,
                options: [
                  for (final label in ['垂直布局', '水平布局', '行内布局']) ElSegmentedOption(value: label, label: label),
                ],
              ),
            ),
            demoHint(context, switch (layout.value) {
              '垂直布局' => '标签在上，逐项填写',
              '水平布局' => '标签在左，控件整齐对齐',
              _ => '多个表单项同行排列，空间不足时换行',
            }, size: 13),
          ],
        ),
        ElForm(
          modelValue: data,
          labelPosition: layout.value == '垂直布局' ? .top : .left,
          labelWidth: layout.value == '垂直布局'
              ? null
              : ShowcaseScope.of(context).mobile
              ? 72
              : 92,
          rules: {
            'name': [
              ElRequiredFormRule(message: '请输入显示名称'),
              ElRangeFormRule(min: 2, max: 24, message: '名称需要 2 到 24 个字符', trigger: .blur),
            ],
            'email': [
              ElRequiredFormRule(message: '请输入联系邮箱'),
              ElFormRule(
                message: '请输入有效的邮箱地址',
                trigger: .blur,
                validator: (_, value) => value is String && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value),
              ),
            ],
            'features': [ElRequiredFormRule(message: '请至少选择一项内容偏好')],
          },
          child: Builder(
            builder: (context) {
              final form = ElForm.of(context);
              final fields = [
                ElFormItem(
                  key: keys['name'],
                  label: '显示名称',
                  prop: 'name',
                  child: ElInput(
                    focusNode: nameFocus,
                    semanticLabel: '显示名称',
                    maxLength: 24,
                    clearable: true,
                    readOnly: saving.value,
                    placeholder: '至少 2 个字符',
                  ),
                ),
                ElFormItem(
                  key: keys['email'],
                  label: '联系邮箱',
                  prop: 'email',
                  child: ElInput(
                    focusNode: emailFocus,
                    semanticLabel: '联系邮箱',
                    keyboardType: .emailAddress,
                    clearable: true,
                    readOnly: saving.value,
                    placeholder: 'name@example.com',
                  ),
                ),
                ElFormItem(
                  label: '接收更新',
                  prop: 'notifications',
                  child: Row(
                    spacing: 12,
                    children: [
                      ElSwitch(disabled: saving.value),
                      demoHint(context, data.value['notifications'] == true ? '已开启' : '已关闭'),
                    ],
                  ),
                ),
                ElFormItem(
                  label: '体验方案',
                  prop: 'plan',
                  child: ElRadioGroup<String>(
                    child: demoActions([
                      for (final label in ['标准体验', '进阶体验', '专业体验'])
                        ElRadio(value: label, label: label, disabled: saving.value),
                    ], gap: 12),
                  ),
                ),
                ElFormItem(
                  key: keys['features'],
                  label: '内容偏好',
                  prop: 'features',
                  child: ElCheckboxGroup<String>(
                    child: demoActions([
                      for (final label in ['云端同步', '灵感笔记', '图片收藏'])
                        ElCheckbox(value: label, label: label, disabled: saving.value),
                    ], gap: 12),
                  ),
                ),
                ElFormItem(
                  label: '个人简介',
                  prop: 'bio',
                  child: ElInput(
                    textarea: true,
                    maxLength: 120,
                    readOnly: saving.value,
                    placeholder: '介绍一下你的兴趣与日常…',
                    semanticLabel: '个人简介',
                  ),
                ),
              ];
              return demoColumn([
                layout.value == '行内布局'
                    ? LayoutBuilder(
                        builder: (_, constraints) => Wrap(
                          spacing: 24,
                          runSpacing: 20,
                          children: [
                            for (var i = 0; i < fields.length; i++)
                              SizedBox(
                                width: i == fields.length - 1
                                    ? constraints.maxWidth
                                    : constraints.maxWidth < 650
                                    ? constraints.maxWidth
                                    : (constraints.maxWidth - 24) / 2,
                                child: fields[i],
                              ),
                          ],
                        ),
                      )
                    : demoColumn(fields, gap: 20),
                demoActions([
                  ElButton(
                    key: ValueKey('profile-save'),
                    loading: saving.value,
                    child: '保存资料',
                    onPressed: () {
                      if (saving.value) return;
                      message.value = '';
                      if (!form.validate()) {
                        final first = form.errorMessages.keys.first;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final target = keys[first]?.currentContext;
                          if (target != null && target.mounted) {
                            Scrollable.ensureVisible(target, duration: Duration(milliseconds: 240), alignment: .2);
                          }
                          if (context.mounted) {
                            (first == 'name'
                                    ? nameFocus
                                    : first == 'email'
                                    ? emailFocus
                                    : null)
                                ?.requestFocus();
                          }
                        });
                        return;
                      }
                      saving.value = true;
                      final name = (data.value['name'] as String).trim();
                      timer.value?.cancel();
                      timer.value = Timer(Duration(milliseconds: 900), () {
                        if (!context.mounted) return;
                        saving.value = false;
                        count.value++;
                        message.value = '$name，资料与偏好已在本页保存 · 第 ${count.value} 次';
                        demoNotify(context, '资料与偏好已在本页保存');
                      });
                    },
                  ),
                  ElButton(
                    variant: .outline,
                    child: '重置表单',
                    onPressed: () {
                      timer.value?.cancel();
                      saving.value = false;
                      count.value = 0;
                      form.reset();
                      message.value = '已恢复初始值';
                    },
                  ),
                  demoHint(context, '仅在本页保存'),
                ], gap: 12),
                Text(message.value, style: TextStyle(fontSize: 13, height: 1.55, color: context.elTheme.success)),
              ], gap: 20);
            },
          ),
        ),
      ], gap: 28),
    );
  }
}

List<ElListTile> _records(BuildContext context, {int count = 3}) => [
  for (final record in [
    ('午后灵感', '给日常留一点新鲜感', '3 条笔记', ElMobileIcons.spark),
    ('城市散步', '收集沿途的好风景', '12 张图片', ElMobileIcons.image),
    ('旅行计划', '把下一次出发安排好', '待整理', ElMobileIcons.briefcase),
  ].take(count))
    ElListTile(
      title: record.$1,
      subtitle: record.$2,
      trailingText: record.$3,
      leading: record.$4,
      onTap: () => demoNotify(context, '已打开：${record.$1}'),
    ),
];

class _Feed extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final loading = useState(false), failed = useState(false), count = useState(0), timer = useRef<Timer?>(null);
    useEffect(
      () =>
          () => timer.value?.cancel(),
      [],
    );
    void reload() {
      if (loading.value) return;
      loading.value = true;
      failed.value = false;
      timer.value?.cancel();
      timer.value = Timer(Duration(milliseconds: 850), () {
        if (!context.mounted) return;
        loading.value = false;
        count.value++;
      });
    }

    return ShowcasePanel(
      anchor: 'scenario-feed',
      title: '内容加载与失败重试',
      description: '组合 Loading、Skeleton 与 Empty，覆盖加载、正常内容与失败状态。',
      child: demoColumn([
        demoActions([
          ElButton(variant: .outline, loading: loading.value, child: '重新加载', onPressed: reload),
          ElButton(variant: .text, disabled: loading.value, child: '查看失败状态', onPressed: () => failed.value = true),
        ]),
        if (loading.value) ElLoadingIndicator(child: '正在加载最近的内容'),
        ElSkeleton(
          loading: loading.value,
          rows: 4,
          avatar: true,
          child: failed.value
              ? ElEmpty(
                  state: .error,
                  description: '再试一次，继续查看最近的内容',
                  child: ElButton(child: '重试加载', onPressed: reload),
                )
              : ElListGroup(title: '最近更新', children: _records(context)),
        ),
        demoHint(
          context,
          loading.value
              ? '请稍等，内容马上回来'
              : failed.value
              ? '重试后可以恢复内容'
              : count.value > 0
              ? '内容已更新 · 第 ${count.value} 次'
              : '有内容，也为等待和失败留好位置',
        ),
      ], gap: 20),
    );
  }
}

class _Tabs extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final tab = useState('最近'), favorite = useState(false), updates = useState(true), compact = useState(false);
    return ShowcasePanel(
      anchor: 'scenario-tabs',
      title: '标签页与内容分组',
      description: '使用 Tabs 切换内容，ListGroup 组织列表与设置项。',
      child: ElTabs<String>(
        modelValue: tab,
        panes: [
          ElTabPane(
            value: '最近',
            label: '最近',
            child: Padding(
              padding: .only(top: 18),
              child: ElListGroup(title: '最近浏览', children: _records(context, count: 2)),
            ),
          ),
          ElTabPane(
            value: '收藏',
            label: '收藏',
            child: Padding(
              padding: .only(top: 18),
              child: favorite.value
                  ? demoColumn([
                      ElListTile(title: '周末的好风景', subtitle: '已加入你的收藏', leading: ElMobileIcons.heart),
                      ElButton(variant: .text, child: '清空收藏', onPressed: () => favorite.value = false),
                    ])
                  : ElEmpty(
                      title: '还没有收藏',
                      description: '留下一条喜欢的内容，下次更容易找到。',
                      icon: ElMobileIcons.heart,
                      child: ElButton(child: '收藏一条内容', onPressed: () => favorite.value = true),
                    ),
            ),
          ),
          ElTabPane(value: '归档', label: '归档', disabled: true),
          ElTabPane(
            value: '偏好',
            label: '偏好',
            child: Padding(
              padding: .only(top: 18),
              child: ElListGroup(
                title: '内容偏好',
                children: [
                  ElListTile<bool>.switcher(title: '接收内容更新', modelValue: updates),
                  ElListTile<bool>.switcher(title: '紧凑显示', modelValue: compact),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Inputs extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ShowcasePanel(
    anchor: 'scenario-inputs',
    title: '更多输入状态',
    description: '只读、密码、禁用与自定义外观，覆盖真实表单里的常见状态。',
    child: ShowcaseGrid(
      gap: 22,
      children: [
        demoColumn([
          demoLabel(context, '只读编号'),
          ElInput(value: 'CL-001024', readOnly: true),
          demoHint(context, '只读内容可以查看，不进入编辑。'),
        ], gap: 8),
        demoColumn([
          demoLabel(context, '密码与显示切换'),
          ElInput(value: 'blue-demo-2026', showPassword: true),
          demoHint(context, '点击眼睛切换密码可见性。'),
        ], gap: 8),
        demoColumn([
          demoLabel(context, '隐藏密码'),
          ElInput(
            value: 'hidden-demo',
            showPassword: true,
            actionStyle: ElStyle(opacity: 0, pointerEvents: .none),
          ),
          demoHint(context, '隐藏明文切换入口。'),
        ], gap: 8),
        demoColumn([demoLabel(context, '禁用输入'), ElInput(value: '由管理员管理', disabled: true)], gap: 8),
        demoColumn([
          demoLabel(context, '描边输入'),
          ElInput(
            value: '清晰的边界',
            style: ElStyle(backgroundColor: context.elTheme.cardColor),
          ),
        ], gap: 8),
        demoColumn([
          demoLabel(context, '无边框输入'),
          ElInput(
            value: '自由的外观',
            style: ElStyle(border: .only(), backgroundColor: Colors.transparent, boxShadow: []),
          ),
        ], gap: 8),
        demoColumn([
          demoLabel(context, '带单位输入'),
          ElInput(value: '120', prefix: '¥', suffix: '元', keyboardType: .number),
        ], gap: 8),
      ],
    ),
  );
}
