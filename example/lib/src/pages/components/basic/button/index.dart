import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 按钮示例页：按设计稿的「左侧固定宽标题 + 右侧一排按钮」版式分组演示 [ElButton]。
///
/// 桌面与移动目录共用此页，按钮外观由外层主题注入；当前示例入口使用 ElMobileTheme。
/// 语义色由各端品牌 token 决定，移动端 info 使用次级文字色，其余使用对应语义色。
class ButtonPage extends HookWidget {
  /// 创建按钮示例页。
  const ButtonPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 点击次数：证明 onPressed 真的通了。
    final clicks = useState(0);
    // 受控 loading：loading 会拦掉自身的激活，所以用另一个按钮翻这个布尔值。
    final loading = useState(false);
    // 受控开关态，与 ElButton.toggle 的 value 双向绑定。
    final toggled = useState(false);

    return Scaffold(
      appBar: AppBar(
        title: Text('按钮'),
        actions: [
          IconButton(
            tooltip: '重置演示状态',
            icon: Icon(Icons.restart_alt),
            onPressed: () {
              clicks.value = 0;
              loading.value = false;
              toggled.value = false;
            },
          ),
        ],
      ),
      body: ElScrollView(
        padding: .all(16),
        children: [
          // 页面大标题，对应设计稿左上角的 Button。
          Padding(
            padding: .only(bottom: 24),
            child: Text(
              'Button',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24, fontWeight: .w700),
            ),
          ),
          _types(context),
          _variants(context),
          _shapes(context),
          _sizes(context),
          _states(context, loading, toggled),
          _feedback(context, clicks),
          _usage(context),
        ],
      ),
    );
  }

  /// 一行版式：左侧固定宽标题（标题下方一行 12 号次要色说明），右侧按钮横排并自动换行。
  Widget _section(BuildContext context, String title, String note, Widget stage) => Padding(
    padding: .only(bottom: 24),
    child: Row(
      crossAxisAlignment: .start,
      spacing: 16,
      children: [
        SizedBox(width: 96, child: _label(context, title, note)),
        Expanded(child: stage),
      ],
    ),
  );

  /// 行首标签：标题加一句短说明；宽度固定，说明换行也不会撑开整行。
  Widget _label(BuildContext context, String title, String note) => Column(
    crossAxisAlignment: .start,
    spacing: 4,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.elTheme.textColor)),
      Text(
        note,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, color: context.elTheme.textSecondary),
      ),
    ],
  );

  /// 一排按钮：间距宽松、宽度不够时自动换行，竖向居中。
  Widget _wrap(List<Widget> children) =>
      Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: .center, children: children);

  /// 单个示例：只出按钮本体，名称与用途收进 Tooltip，保持设计稿的纯净横排。
  Widget _item(String name, String note, Widget button) => Tooltip(message: '$name：$note', child: button);

  /// 行内小字，用于状态读数这类附属信息。
  Widget _caption(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.elTheme.textSecondary));

  /// 第一行：type 的五个语义档。
  Widget _types(BuildContext context) =>
      _section(context, '语义颜色', 'type 只声明语义，色值由主题映射', _wrap([for (final type in ElThemeType.types) _typeItem(type)]));

  Widget _typeItem(ElThemeType type) {
    final text = _typeText(type);
    return _item(type.name, text.note, ElButton(type: type, child: text.label));
  }

  /// 第二行：plain / text / bg / link / ghost 五个布尔变体。
  Widget _variants(BuildContext context) => _section(
    context,
    '按钮变体',
    'link、text 走扁平，ghost、plain 走描边',
    _wrap([
      _item('plain', '浅底加同色描边，次级操作的默认选择，按下反转为实心', ElButton(plain: true, child: '朴素按钮')),
      _item('text', '去底去边只留文字，仍占住按钮盒尺寸', ElButton(text: true, child: '文字按钮')),
      _item('text + bg', '文字按钮补一层底色，浅背景上更容易认出可点区域', ElButton(text: true, bg: true, child: '带底文字')),
      _item('link', '紧凑链接外观，只占内容尺寸，用于行内跳转', ElButton(link: true, child: '链接按钮')),
      _item('ghost', '透明底加描边，压在图片或彩色底上依然清楚', ElButton(ghost: true, child: '幽灵按钮')),
    ]),
  );

  /// 第三行：形状与图标槽，设计稿把它们排在同一行。
  Widget _shapes(BuildContext context) => _section(
    context,
    '按钮形状',
    'round 拉成胶囊，circle 锁死宽高',
    _wrap([
      _item('round', '胶囊圆角，主行动按钮的常见形态', ElButton(round: true, child: '胶囊按钮')),
      _item('circle', '正圆配纯图标，圆形按钮的标准写法', ElButton(circle: true, child: Icon(Icons.add))),
      _item('circle + 图标', '正圆塞图标槽，图标尺寸跟主题 iconSize 走', ElButton(circle: true, leftIcon: Icon(Icons.search))),
      ..._icons(),
    ]),
  );

  /// 图标槽的三个示例，并入「按钮形状」行。
  List<Widget> _icons() => [
    _item('leftIcon', '左图标点明动作含义，比如添加', ElButton(leftIcon: Icon(Icons.add), child: '添加')),
    _item('rightIcon', '右图标指向后续动作，比如进入下一屏', ElButton(rightIcon: Icon(Icons.chevron_right), child: '下一步')),
    _item('仅图标', '纯图标按钮靠 semanticLabel 提供无障碍名称', ElButton(semanticLabel: '收藏', child: Icon(Icons.favorite))),
  ];

  /// 第四行：小 / 默认 / 大三档同排，块级按钮换到下一行通栏。
  Widget _sizes(BuildContext context) => _section(
    context,
    '按钮尺寸',
    '没有尺寸枚举，差异直接覆盖 style',
    Column(
      crossAxisAlignment: .stretch,
      spacing: 16,
      children: [
        _wrap([
          _item(
            '小',
            '列表行内的次要动作，13 号字',
            ElButton(
              style: ElStyle(minHeight: 32, fontSize: 13, padding: .symmetric(horizontal: 12)),
              child: '小按钮',
            ),
          ),
          _item('默认', '不传 style，走主题给的高度与字号', ElButton(child: '默认按钮')),
          _item(
            '大',
            '落地页的主行动点，17 号字',
            ElButton(
              style: ElStyle(minHeight: 56, fontSize: 17, padding: .symmetric(horizontal: 24)),
              child: '大按钮',
            ),
          ),
        ]),
        // 块级按钮单独占一行，撑满右侧剩余宽度。
        _item('block', '占满父级可用宽度，用于表单底部的确认动作', ElButton(block: true, child: '通栏按钮')),
      ],
    ),
  );

  /// 第五行：禁用、加载、开关状态同排，对应设计稿的「禁用 / 加载中 / 已开启」。
  Widget _states(BuildContext context, ValueNotifier<bool> loading, ValueNotifier<bool> toggled) => _section(
    context,
    '按钮状态',
    'disabled、loading 拦住激活，toggle 受控',
    Column(
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        _wrap([
          _item('disabled', '不响应指针和键盘，也不请求焦点', ElButton(disabled: true, child: '禁用按钮')),
          _item('loading', '固定 loading，盒尺寸和焦点都保留', ElButton(loading: true, child: '加载中')),
          ..._toggles(toggled),
        ]),
        // 受控 loading 的开关，用来看 loading 状态真的从外面接管。
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: .center,
          children: [
            ElButton(onPressed: () => loading.value = !loading.value, child: loading.value ? '结束加载' : '开始加载'),
            _caption(context, 'loading：${loading.value}'),
            _caption(context, '当前布尔值：${toggled.value}'),
          ],
        ),
      ],
    ),
  );

  /// 开关态的三颗按钮：未选中 / 选中 / 受控，排在状态行的「加载中」之后。
  List<Widget> _toggles(ValueNotifier<bool> toggled) => [
    // 这两个只做外观对照，包 IgnorePointer 免得点一下就和旁边那个同款分不出来。
    _item('未选中', '沿用普通按钮外观', IgnorePointer(child: ElButton.toggle(value: false, child: '未选中'))),
    _item('选中', '叠加品牌色底与描边，状态一眼可辨', IgnorePointer(child: ElButton.toggle(value: true, child: '已开启'))),
    _item(
      '受控',
      'value 绑在页面 state 上，点一下下面的布尔值同步变化',
      ElButton.toggle(
        value: toggled.value,
        onChanged: (v) => toggled.value = v,
        child: toggled.value ? '开关：开' : '开关：关',
      ),
    ),
  ];

  /// 第六行：点击反馈，按钮旁边挂一枚真实计数的胶囊。
  Widget _feedback(BuildContext context, ValueNotifier<int> clicks) => _section(
    context,
    '点击反馈',
    'onPressed 通了，数字才往上跳',
    _wrap([
      _item('点我 +1', '指针点击与键盘 Enter / Space 都会走到 onPressed', ElButton(onPressed: () => clicks.value++, child: '点我 +1')),
      _item('清零', '把计数归零，方便反复验证', ElButton(onPressed: () => clicks.value = 0, child: '清零')),
      _counter(context, clicks.value),
    ]),
  );

  /// 计数胶囊：圆角底加次要色文字，对应设计稿里那枚小药丸。
  Widget _counter(BuildContext context, int count) => ElCardView(
    style: ElStyle(
      backgroundColor: context.elTheme.fill,
      borderRadius: .circular(999),
      padding: .symmetric(horizontal: 12, vertical: 6),
    ),
    child: Text(
      '点击次数 $count',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.elTheme.textSecondary),
    ),
  );

  /// 结尾的用法片段，跟范本一样留一块可复制的代码。
  Widget _usage(BuildContext context) => ElCardView(
    style: ElStyle(
      backgroundColor: context.elTheme.cardColor,
      borderRadius: .circular(16),
      padding: .all(16),
      margin: .only(bottom: 16),
    ),
    child: ExpansionTile(
      title: Text('用法'),
      childrenPadding: .symmetric(vertical: 12),
      expandedCrossAxisAlignment: .stretch,
      children: [
        SelectableText('''// 普通按钮：指针点击与键盘 Enter / Space 都走 onPressed。
ElButton(
  type: ElThemeType.primary,
  leftIcon: Icon(Icons.download),
  child: '下载',
  onPressed: () {},
);

// 尺寸不靠枚举，直接覆盖 style。
ElButton(
  style: ElStyle(minHeight: 32, fontSize: 13, padding: EdgeInsets.symmetric(horizontal: 12)),
  child: '小按钮',
);

// 开关态：value 受控，onChanged 回传当前值。
ElButton.toggle(
  value: opened,
  onChanged: (v) => opened = v,
  child: opened ? '开关：开' : '开关：关',
);'''),
      ],
    ),
  );
}

/// 类型分组的一句说明与按钮文案。
({String label, String note}) _typeText(ElThemeType type) => switch (type) {
  ElThemeType.primary => (label: '主要按钮', note: '页面最主要的那个动作'),
  ElThemeType.success => (label: '成功按钮', note: '确认、完成这类正向收尾'),
  ElThemeType.info => (label: '信息按钮', note: '辅助信息动作，移动端落到次级文字色'),
  ElThemeType.warning => (label: '警告按钮', note: '需要用户留意的操作'),
  ElThemeType.error => (label: '危险按钮', note: '删除、清空这类不可逆操作'),
};
