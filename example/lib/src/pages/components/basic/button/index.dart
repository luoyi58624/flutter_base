import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

/// 按钮示例页：按设计稿的「左侧固定宽标题 + 右侧一排按钮」版式分组演示 [ElButton]。
///
/// 桌面与移动目录共用此页，按钮外观由外层主题注入；当前示例入口使用 ElMobileTheme，
/// 所以看到的是移动端品牌外观：语义色取设计稿的亮色，info 是浅蓝底配蓝字。
class ButtonPage extends HookWidget {
  /// 创建按钮示例页。
  const ButtonPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 点击次数：证明 onPressed 真的通了，数字由页面状态驱动。
    final clicks = useState(0);

    return Scaffold(
      appBar: AppBar(
        title: Text('按钮'),
        actions: [
          IconButton(
            tooltip: '计数归零',
            icon: Icon(Icons.restart_alt),
            onPressed: () => clicks.value = 0,
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
          _states(context),
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

  /// 第一行：type 的五个语义档。
  Widget _types(BuildContext context) => _section(
    context,
    '语义颜色',
    'type 只声明语义，色值由主题映射',
    _wrap([for (final type in ElThemeType.types) _typeItem(type)]),
  );

  Widget _typeItem(ElThemeType type) {
    final text = _typeText(type);
    return _item(type.name, text.note, ElButton(type: type, child: text.label));
  }

  /// 第二行：plain / text / link / ghost 四个布尔变体。
  Widget _variants(BuildContext context) => _section(
    context,
    '按钮变体',
    'link、text 走扁平，ghost、plain 走描边',
    _wrap([
      _item('plain', '白底加描边，次级操作的默认选择', ElButton(plain: true, child: '朴素按钮')),
      _item('text', '去底去边只留文字，仍占住按钮盒尺寸', ElButton(text: true, child: '文字按钮')),
      _item('link', '紧凑链接外观，只占内容尺寸，用于行内跳转', ElButton(link: true, child: '链接按钮')),
      _item('ghost', '透明底加蓝描边，压在图片或彩色底上依然清楚', ElButton(ghost: true, child: '幽灵按钮')),
    ]),
  );

  /// 第三行：胶囊圆角、圆形图标按钮、带前置图标的按钮。
  Widget _shapes(BuildContext context) => _section(
    context,
    '按钮形状',
    'round 拉成胶囊，circle 锁死宽高',
    _wrap([
      _item('round', '胶囊圆角，主行动按钮的常见形态', ElButton(round: true, child: '胶囊按钮')),
      _item('circle', '正圆配纯图标，圆形按钮的标准写法', ElButton(circle: true, semanticLabel: '新增', child: Icon(Icons.add))),
      _item('leftIcon', '左图标点明动作含义，比如添加', ElButton(leftIcon: Icon(Icons.add), child: '添加')),
    ]),
  );

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
        _item('block', '占满父级可用宽度，用于表单底部的确认动作', ElButton(block: true, child: '块级按钮')),
      ],
    ),
  );

  /// 第五行：禁用灰化、加载中（指示器 + 文字，且不可重复点击）、开关态已开启。
  Widget _states(BuildContext context) => _section(
    context,
    '按钮状态',
    'disabled、loading 拦住激活，toggle 受控',
    _wrap([
      _item('disabled', '不响应指针和键盘，也不请求焦点', ElButton(disabled: true, child: '禁用按钮')),
      _item('loading', '旋转指示器与文字并存，加载期间点不动', ElButton(loading: true, child: '加载中')),
      // 只做外观对照，包 IgnorePointer 免得点一下就和别的按钮串味。
      _item(
        '已开启',
        '叠加品牌色底与描边，状态一眼可辨',
        IgnorePointer(child: ElButton.toggle(value: true, child: '已开启')),
      ),
    ]),
  );

  /// 第六行：点击反馈——胶囊自己就是按钮，点一下计数往上跳。
  Widget _feedback(BuildContext context, ValueNotifier<int> clicks) => _section(
    context,
    '点击反馈',
    'onPressed 通了，数字才往上跳',
    _wrap([
      ElButton(
        onPressed: () => clicks.value++,
        child: '点击次数 ${clicks.value}',
        // 只读胶囊观感：白底、浅描边、次要色文字，但仍是能被点到的按钮。
        style: ElStyle(
          minHeight: 32,
          fontSize: 13,
          padding: .symmetric(horizontal: 12),
          backgroundColor: context.elTheme.cardColor,
          border: ElBorder.all(borderWidth: 1, borderColor: context.elTheme.borderColor),
          color: context.elTheme.textSecondary,
          iconColor: context.elTheme.textSecondary,
        ),
      ),
    ]),
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
ElButton(type: ElThemeType.primary, child: '确定', onPressed: () {});

// 语义只声明意图：info 落成浅蓝底蓝字，warning、error 各自取主题色。
ElButton(type: ElThemeType.info, child: '信息按钮');

// 尺寸不靠枚举，直接覆盖 style。
ElButton(
  style: ElStyle(minHeight: 32, fontSize: 13, padding: EdgeInsets.symmetric(horizontal: 12)),
  child: '小按钮',
);

// 加载中保留盒尺寸并拦住重复点击，指示器与文字同时出现。
ElButton(loading: true, child: '加载中');

// 开关态：value 受控，onChanged 回传当前值。
ElButton.toggle(value: opened, onChanged: (v) => opened = v, child: '已开启');'''),
      ],
    ),
  );
}

/// 类型分组的一句说明与按钮文案。
({String label, String note}) _typeText(ElThemeType type) => switch (type) {
  ElThemeType.primary => (label: '主要按钮', note: '页面最主要的那个动作'),
  ElThemeType.success => (label: '成功按钮', note: '确认、完成这类正向收尾'),
  ElThemeType.info => (label: '信息按钮', note: '浅蓝底配蓝字，承载辅助信息动作'),
  ElThemeType.warning => (label: '警告按钮', note: '需要用户留意的操作'),
  ElThemeType.error => (label: '危险按钮', note: '删除、清空这类不可逆操作'),
};
