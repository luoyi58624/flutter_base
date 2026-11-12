import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';
import 'pickers.dart';
import 'upload.dart';

/// 输入、选择、日期与上传的完整分区。
class ControlsShowcase extends StatelessWidget {
  /// 创建控制类组件展示。
  const ControlsShowcase({super.key});
  @override
  Widget build(BuildContext context) => ShowcaseSection(
    id: 'controls',
    number: '02',
    category: '交互控制',
    title: '输入与选择',
    description: '为手指设计的控件尺寸，状态变化一目了然。',
    links: {'control-fields': '输入与选项', 'control-pickers': '搜索与选择', 'control-dates': '日期与时间', 'control-upload': '文件上传'},
    child: ShowcaseSlivers([
      demoAnchor(context, 'control-fields', _Fields()),
      _Selections(),
      _MoreSelections(),
      showcaseSliver(_Collapses()),
      demoAnchor(context, 'control-pickers', _Comboboxes()),
      PickerShowcase(),
      demoAnchor(context, 'control-dates', DateTimeShowcase()),
      demoAnchor(context, 'control-upload', UploadShowcase()),
    ], gap: 22),
  );
}

class _Fields extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final search = useState(''), nickname = useState('小蓝同学'), category = useState('视觉灵感');
    final notification = useState(true), silent = useState(false), privacy = useState(true);
    return ShowcaseGrid.sliver(
      children: [
        ShowcasePanel(
          title: '搜索输入',
          description: '通过 prefix 添加前置图标，clearable 提供一键清空。',
          child: demoColumn([
            demoLabel(context, '搜索'),
            ElInput(
              modelValue: search,
              prefix: ElMobileIcons.search,
              placeholder: '寻找你感兴趣的内容…',
              clearable: true,
              semanticLabel: '搜索内容',
            ),
          ], gap: 8),
        ),
        ShowcasePanel(
          title: '辅助信息',
          description: '搭配文字补充输入提示，maxLength 限制最大长度。',
          child: demoColumn([
            demoLabel(context, '昵称'),
            ElInput(modelValue: nickname, maxLength: 24, semanticLabel: '昵称'),
          ], gap: 8),
        ),
        ShowcasePanel(
          title: '下拉选择',
          description: 'ElSelect 通过 children 提供选项，modelValue 同步当前值。',
          child: demoColumn([
            demoLabel(context, '内容分类'),
            ElSelect<String>(
              modelValue: category,
              children: [
                for (final label in ['视觉灵感', '效率优先', '轻度探索']) ElSelectOption(label, label),
              ],
              semanticLabel: '内容偏好',
            ),
            Wrap(
              alignment: .spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [demoHint(context, '已选择：${category.value}'), demoHint(context, '下拉展开简洁柔和')],
            ),
          ], gap: 8),
        ),
        ShowcasePanel(
          title: '列表开关',
          description: '把开关放入列表，说明和当前状态保持在一起。',
          child: demoColumn([
            ElListTile<bool>.switcher(
              title: '消息提醒',
              subtitle: '不错过重要的更新',
              leading: ElMobileIcons.bell,
              modelValue: notification,
            ),
            ElListTile<bool>.switcher(
              title: '静音模式',
              subtitle: '暂时放下通知，专注当下',
              leading: ElMobileIcons.moon,
              modelValue: silent,
            ),
            ElListTile<bool>.switcher(
              title: '隐私保护',
              subtitle: '妥善保护你的个人信息',
              leading: ElMobileIcons.shield,
              modelValue: privacy,
            ),
            demoHint(context, '已开启 ${[notification.value, silent.value, privacy.value].where((v) => v).length} 项设置'),
          ], gap: 0),
        ),
      ],
    );
  }
}

class _Selections extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final mode = useState('舒适'), strength = useState(68.0), custom = useState(36.0);
    final plan = useState<String?>('标准体验'), features = useState(['云端同步']);
    final number = useState<num?>(1);
    return ShowcaseGrid.sliver(
      children: [
        demoColumn([
          ShowcasePanel(
            title: '分段选择',
            description: '在少量同级选项之间快速切换。',
            child: demoColumn([
              ElSegmented<String>(
                modelValue: mode,
                options: [
                  for (final name in ['舒适', '均衡', '专注']) ElSegmentedOption(value: name, label: name),
                ],
              ),
              Row(
                spacing: 10,
                children: [
                  demoIcon(ElMobileIcons.sun, color: context.elTheme.primary),
                  Expanded(
                    child: demoHint(context, switch (mode.value) {
                      '舒适' => '轻松一点，让内容自然呈现。',
                      '均衡' => '恰到好处，兼顾信息与留白。',
                      _ => '减少干扰，把注意力留给重要的事。',
                    }),
                  ),
                ],
              ),
            ]),
          ),
          ShowcasePanel(
            title: '基础滑块',
            description: '拖动调节数值，反馈跟随指尖变化。',
            child: ElSlider<double>(modelValue: strength, label: '显示强度'),
          ),
          ShowcasePanel(
            title: '自定义滑块',
            description: '通过 style 调整轨道与滑块外观。',
            child: ElSlider<double>(
              modelValue: custom,
              label: '柔和程度',
              style: ElStyle(vars: {ElTokens.$primary: Color(0xff8979c7)}),
            ),
          ),
        ], gap: 22),
        demoColumn([
          ShowcasePanel(
            title: '单选选项',
            description: '一次选择一项，当前选择清楚可见。',
            child: demoColumn([
              ElRadioGroup<String>(
                modelValue: plan,
                child: demoColumn([
                  for (final label in ['标准体验', '进阶体验', '专业体验']) ElRadio<String>(value: label, label: label),
                ], gap: 8),
              ),
              demoHint(context, '当前方案：${plan.value}'),
            ]),
          ),
          ShowcasePanel(
            title: '复选选项',
            description: '独立选择需要的功能，支持多个选项同时开启。',
            child: demoColumn([
              ElCheckboxGroup<String>(
                modelValue: features,
                child: demoColumn([
                  for (final label in ['云端同步', '自动更新', '消息提醒']) ElCheckbox(value: label, label: label),
                ], gap: 8),
              ),
              demoHint(context, '已选 ${features.value.length} 项功能'),
            ]),
          ),
          ShowcasePanel(
            title: '数字步进器',
            description: '用加减按钮调整数量，也可以直接输入。',
            child: demoColumn([
              Row(
                children: [
                  Expanded(child: demoLabel(context, '添加到我的收藏')),
                  ElInputNumber(modelValue: number, min: 1, max: 99),
                ],
              ),
              demoHint(context, '当前数量：${number.value ?? 0}'),
            ]),
          ),
        ], gap: 22),
      ],
    );
  }
}

class _MoreSelections extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final delivery = useState<String?>('送货上门'), autosave = useState(true), notify = useState(false);
    final density = useState<String?>('舒适'), files = useState(['文档', '图片']);
    Widget toggle(String title, ValueNotifier<bool> model, {String? subtitle}) => ElListTile(
      title: title,
      subtitle: subtitle,
      leading: ElCheckbox.toggle(modelValue: model),
      trailing: null,
      onTap: () => model.value = !model.value,
    );
    return ShowcaseGrid.sliver(
      children: [
        ShowcasePanel(
          title: '独立单选框',
          description: 'Radio 与已有分组模型组合，保留简单的值绑定。',
          child: demoColumn([
            ElRadioGroup<String>(
              modelValue: delivery,
              child: demoActions([
                ElRadio(value: '送货上门', label: '送货上门'),
                ElRadio(value: '到店自取', label: '到店自取'),
                ElRadio(value: '极速配送', label: '极速配送', disabled: true),
              ], gap: 12),
            ),
            demoHint(context, '配送方式：${delivery.value}'),
          ]),
        ),
        ShowcasePanel(
          title: '独立复选框',
          description: '单独使用时绑定布尔值，适合独立设置。',
          child: demoColumn([
            toggle('自动保存', autosave, subtitle: '编辑时自动保存当前内容'),
            toggle('接收提醒', notify),
            ElListTile(title: '暂不可用', leading: ElCheckbox.toggle(disabled: true), trailing: null, disabled: true),
          ], gap: 4),
        ),
        ShowcasePanel(
          title: '单选组',
          description: '按业务值管理一组选项，布局由内容决定。',
          child: demoColumn([
            ElRadioGroup<String>(
              modelValue: density,
              child: demoActions([
                for (final label in ['紧凑', '舒适', '宽松']) ElRadio(value: label, label: label),
              ], gap: 12),
            ),
            demoHint(context, '当前密度：${density.value}'),
          ]),
        ),
        ShowcasePanel(
          title: '复选组与半选',
          description: '全选与部分选中共同表达一组选项的状态。',
          child: demoColumn([
            ElListTile(
              title: '全部内容',
              trailing: null,
              leading: ElCheckbox.toggle(
                value: files.value.length == 3,
                indeterminate: files.value.isNotEmpty && files.value.length < 3,
                onChanged: (checked) => files.value = checked ? ['文档', '图片', '收藏'] : [],
              ),
              onTap: () => files.value = files.value.length == 3 ? [] : ['文档', '图片', '收藏'],
            ),
            ElCheckboxGroup<String>(
              modelValue: files,
              child: demoActions([
                for (final label in ['文档', '图片', '收藏', '归档'])
                  ElCheckbox(value: label, label: label, disabled: label == '归档'),
              ], gap: 12),
            ),
            demoHint(context, '已选：${files.value.isEmpty ? '暂无' : files.value.join('、')}'),
          ]),
        ),
      ],
    );
  }
}

class _Collapses extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final expanded = useState(['collection']),
        single = useState<String?>('privacy'),
        note = useState('周末整理灵感'),
        sync = useState(true);
    return ShowcasePanel(
      title: '折叠面板',
      description: '多项展开与手风琴模式，按需要组织更多内容。',
      child: demoColumn([
        ShowcaseGrid(
          gap: 28,
          children: [
            demoColumn([
              demoHint(context, '多项展开 · 保留内容状态', size: 13),
              ElCollapse.multi(
                modelValue: expanded,
                children: [
                  ElCollapseItem(
                    value: 'collection',
                    title: '收藏与整理',
                    child: demoColumn([
                      demoHint(context, '把感兴趣的内容收集起来，再慢慢整理。'),
                      demoLabel(context, '收集备注'),
                      ElInput(modelValue: note, placeholder: '写下下一步计划'),
                    ], gap: 8),
                  ),
                  ElCollapseItem(
                    value: 'sync',
                    title: '同步偏好',
                    child: ElListTile(
                      title: '允许后台同步',
                      subtitle: '离开当前页面前，请确认内容已经保存',
                      leading: ElCheckbox.toggle(modelValue: sync),
                      trailing: null,
                      onTap: () => sync.value = !sync.value,
                    ),
                  ),
                  ElCollapseItem(value: 'archive', title: '归档策略 · 暂未开放', disabled: true, child: Text('稍后开放更多归档方式。')),
                ],
              ),
            ], gap: 12),
            demoColumn([
              demoHint(context, '手风琴 · 一次展开一项', size: 13),
              ElCollapse.single(
                modelValue: single,
                children: [
                  ElCollapseItem(
                    value: 'privacy',
                    title: '隐私与内容安全',
                    child: Text('示例数据只在当前页面内保存。你可以自由尝试各项控件，重载后恢复初始内容。'),
                  ),
                  ElCollapseItem(value: 'keyboard', title: '展开与收起', child: Text('点击标题展开对应内容，再次点击即可收起；内部输入和选择状态会保留。')),
                  ElCollapseItem(
                    value: 'custom',
                    title: Row(
                      children: [
                        Expanded(child: Text('查看面板状态')),
                        demoHint(context, single.value == 'custom' ? '已展开' : '已收起'),
                      ],
                    ),
                    child: Text('标题可以补充状态，面板布局保持统一。'),
                  ),
                ],
              ),
            ], gap: 12),
          ],
        ),
        demoActions([
          demoHint(context, '收起保留内部状态，支持连续切换。'),
          ElButton(
            variant: .text,
            child: '重置折叠示例',
            onPressed: () {
              expanded.value = ['collection'];
              single.value = 'privacy';
              note.value = '周末整理灵感';
              sync.value = true;
            },
          ),
        ]),
      ], gap: 20),
    );
  }
}

class _Comboboxes extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final city = useState('杭州'), member = useState('小蓝'), project = useState('');
    final cities = ['杭州', '上海', '成都', '深圳', '厦门', '北京'];
    final members = ['小蓝', '小青', '云间'];
    return ShowcaseGrid.sliver(
      children: [
        ShowcasePanel(
          title: '本地搜索',
          description: '输入关键词过滤候选，选中后回填当前文本。',
          child: demoColumn([
            demoLabel(context, '目的地'),
            ElAutocomplete<String>(
              modelValue: city,
              clearable: true,
              fetchSuggestions: (query) => [
                for (final name in cities.where((name) => name.contains(query))) ElLabelModel(name, name),
              ],
              semanticLabel: '目的地',
            ),
            demoHint(context, '试试搜索杭州、上海或成都'),
            ElAutocomplete<String>(value: '暂不可选', disabled: true, fetchSuggestions: (_) => []),
            ElButton(variant: .text, child: '清空选择', onPressed: () => city.value = ''),
          ], gap: 12),
        ),
        ShowcasePanel(
          title: '自定义选项',
          description: '为协作成员加入头像与状态，候选信息更完整。',
          child: demoColumn([
            demoLabel(context, '协作成员'),
            ElAutocomplete<String>(
              modelValue: member,
              clearable: true,
              fetchSuggestions: (query) => [
                for (final name in members.where((name) => name.contains(query))) ElLabelModel(name, name),
              ],
              itemBuilder: (context, option, active) => Row(
                spacing: 10,
                children: [
                  ElAvatar(src: option.value == '小蓝' ? showcaseAvatar : null, alt: option.label ?? '', size: 32),
                  Expanded(child: Text(option.label ?? '')),
                  demoHint(context, option.value == '云间' ? '离开' : '在线'),
                ],
              ),
            ),
            demoHint(context, '当前协作成员：${member.value}'),
          ], gap: 12),
        ),
        ShowcasePanel(
          title: '异步搜索',
          description: '输入后查询项目，等待、空结果和新请求保持同步。',
          child: demoColumn([
            demoLabel(context, '搜索项目'),
            ElAutocomplete<String>(
              modelValue: project,
              clearable: true,
              placeholder: '输入项目关键词',
              debounce: Duration(milliseconds: 300),
              fetchSuggestions: (query) async {
                await Future<void>.delayed(Duration(milliseconds: 550));
                return [
                  for (final item in ['设计灵感', '灵感笔记', '旅行计划'].where((v) => v.contains(query))) ElLabelModel(item, item),
                ];
              },
            ),
            demoHint(context, '试试「设计」「笔记」或「旅行」，请求延迟约 550ms。'),
            ElButton(variant: .text, child: '重置异步搜索', onPressed: () => project.value = ''),
          ], gap: 12),
        ),
      ],
    );
  }
}
