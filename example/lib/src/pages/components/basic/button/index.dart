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
        actions: [IconButton(tooltip: '计数归零', icon: Icon(Icons.restart_alt), onPressed: () => clicks.value = 0)],
      ),
      body: ElScrollView(
        padding: .all(16),
        children: [
          // 页面大标题，对应设计稿左上角的 Button。
          Padding(
            padding: .only(bottom: 24),
            child: Text(
              'Button',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 32, fontWeight: .w700),
            ),
          ),
          _types(context),
          _variants(context),
          _shapes(context),
          _sizes(context),
          _states(context),
          _feedback(context, clicks),
        ],
      ),
    );
  }

  /// 左侧标题与首排按钮居中对齐，右侧保留独立的换行内容区。
  Widget _section(BuildContext context, String title, Widget stage) => Padding(
    padding: .only(bottom: 48),
    child: Row(
      crossAxisAlignment: .start,
      spacing: 16,
      children: [
        SizedBox(
          width: 96,
          height: 44,
          child: Align(alignment: .centerLeft, child: _label(context, title)),
        ),
        Expanded(child: stage),
      ],
    ),
  );

  Widget _label(BuildContext context, String title) => Text(
    title,
    style: Theme.of(context).textTheme.titleSmall
        ?.copyWith(fontSize: 15, fontWeight: .w600, color: context.elTheme.textColor),
  );

  // 主题的 plain 默认带品牌浅色，局部覆盖为设计稿的白底、浅边和深色内容。
  ElStyle _plainStyle(BuildContext context) => ElStyle(
    backgroundColor: context.elTheme.cardColor,
    border: ElBorder.all(borderWidth: 1, borderColor: context.elTheme.borderColorLight),
    borderRadius: .circular(6),
    color: context.elTheme.textColor,
    iconColor: context.elTheme.textColor,
    onTap: ElStyle(backgroundColor: context.elTheme.cardPressColor),
  );

  /// 一排按钮：间距宽松、宽度不够时自动换行，竖向居中。
  Widget _wrap(List<Widget> children) =>
      Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: .center, children: children);

  /// 单个示例：只出按钮本体，名称与用途收进 Tooltip，保持设计稿的纯净横排。
  Widget _item(String name, String note, Widget button) => Tooltip(message: '$name：$note', child: button);

  /// 第一行：type 的五个语义档。
  Widget _types(BuildContext context) =>
      _section(context, '语义颜色', _wrap([for (final type in ElThemeType.types) _typeItem(type)]));

  Widget _typeItem(ElThemeType type) {
    final text = _typeText(type);
    return _item(type.name, text.note, ElButton(type: type, round: true, child: text.label));
  }

  /// 第二行：plain / text / link / ghost 四个布尔变体。
  Widget _variants(BuildContext context) => _section(
    context,
    '按钮变体',
    _wrap([
      _item('plain', '白底加描边，次级操作的默认选择', ElButton(plain: true, style: _plainStyle(context), child: '朴素按钮')),
      _item(
        'text',
        '去底去边只留文字，仍占住按钮盒尺寸',
        ElButton(
          text: true,
          style: ElStyle(color: context.elTheme.textColor),
          child: '文字按钮',
        ),
      ),
      _item('link', '紧凑链接外观，只占内容尺寸，用于行内跳转', ElButton(link: true, child: '链接按钮')),
      _item(
        'ghost',
        '透明底加蓝描边，压在图片或彩色底上依然清楚',
        ElButton(
          ghost: true,
          style: ElStyle(borderRadius: .circular(6)),
          child: '幽灵按钮',
        ),
      ),
    ]),
  );

  /// 第三行：胶囊圆角、圆形图标按钮、带前置图标的按钮。
  Widget _shapes(BuildContext context) => _section(
    context,
    '按钮形状',
    _wrap([
      _item('round', '胶囊圆角，主行动按钮的常见形态', ElButton(round: true, child: '胶囊按钮')),
      _item('circle', '正圆配纯图标，圆形按钮的标准写法', ElButton(circle: true, semanticLabel: '新增', child: Icon(Icons.add))),
      _item(
        'leftIcon',
        '左图标点明动作含义，比如添加',
        ElButton(plain: true, leftIcon: Icon(Icons.add), style: _plainStyle(context), child: '添加'),
      ),
    ]),
  );

  /// 第四行：小 / 默认 / 大三档同排，块级按钮换到下一行通栏。
  Widget _sizes(BuildContext context) => _section(
    context,
    '按钮尺寸',
    Column(
      crossAxisAlignment: .stretch,
      spacing: 16,
      children: [
        _wrap([
          _item(
            '小',
            '列表行内的次要动作，13 号字',
            ElButton(
              plain: true,
              style: _plainStyle(context)
                  .merge(ElStyle(minHeight: 32, fontSize: 13, padding: .symmetric(horizontal: 12))),
              child: '小按钮',
            ),
          ),
          _item(
            '默认',
            '沿用主题的默认高度与字号',
            ElButton(
              style: ElStyle(borderRadius: .circular(6)),
              child: '默认按钮',
            ),
          ),
          _item(
            '大',
            '落地页的主行动点，17 号字',
            ElButton(
              style: ElStyle(
                minHeight: 56,
                fontSize: 17,
                padding: .symmetric(horizontal: 24),
                borderRadius: .circular(6),
              ),
              child: '大按钮',
            ),
          ),
        ]),
        // 块级按钮单独占一行，撑满右侧剩余宽度。
        _item(
          'block',
          '占满父级可用宽度，用于表单底部的确认动作',
          ElButton(
            block: true,
            style: ElStyle(borderRadius: .circular(6)),
            child: '块级按钮',
          ),
        ),
      ],
    ),
  );

  /// 第五行：禁用灰化、加载中（指示器 + 文字，且不可重复点击）、开关态已开启。
  Widget _states(BuildContext context) => _section(
    context,
    '按钮状态',
    _wrap([
      _item(
        'disabled',
        '不响应指针和键盘，也不请求焦点',
        ElButton(
          plain: true,
          disabled: true,
          style: _plainStyle(context).copyWith(
            color: context.elTheme.disabledTextColor,
            iconColor: context.elTheme.disabledTextColor,
            opacity: 1,
          ),
          child: '禁用按钮',
        ),
      ),
      _item(
        'loading',
        '旋转指示器与文字并存，加载期间点不动',
        ElButton(
          loading: true,
          style: ElStyle(borderRadius: .circular(6)),
          child: '加载中',
        ),
      ),
      // 只做外观对照，包 IgnorePointer 免得点一下就和别的按钮串味。
      _item(
        '已开启',
        '叠加品牌色底与描边，状态一眼可辨',
        IgnorePointer(
          child: ElButton.toggle(
            value: true,
            // 保留受控开关示例，覆盖主题选中态的加深色以贴合设计稿。
            style: ElStyle(backgroundColor: context.elTheme.primary),
            child: '已开启',
          ),
        ),
      ),
    ]),
  );

  /// 第六行：点击按钮累加次数，标题与数字用颜色区分层级。
  Widget _feedback(BuildContext context, ValueNotifier<int> clicks) => _section(
    context,
    '点击反馈',
    _wrap([
      ElButton(
        plain: true,
        onPressed: () => clicks.value++,
        style: _plainStyle(context),
        child: Row(
          mainAxisSize: .min,
          spacing: 12,
          children: [
            ElView(child: '点击次数'),
            ElView(
              style: ElStyle(color: context.elTheme.textSecondary),
              child: '${clicks.value}',
            ),
          ],
        ),
      ),
    ]),
  );
}

/// 类型分组的一句说明与按钮文案。
({String label, String note}) _typeText(ElThemeType type) => switch (type) {
  ElThemeType.primary => (label: '主要', note: '页面最主要的那个动作'),
  ElThemeType.success => (label: '成功', note: '确认、完成这类正向收尾'),
  ElThemeType.info => (label: '信息', note: '浅蓝底配蓝字，承载辅助信息动作'),
  ElThemeType.warning => (label: '警告', note: '需要用户留意的操作'),
  ElThemeType.error => (label: '危险', note: '删除、清空这类不可逆操作'),
};
