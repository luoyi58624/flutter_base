import 'dart:math';

import 'package:flutter_base/flutter_base.dart';
import 'package:flutter/material.dart';

/// ElView 示例卡片。
class ExampleViewCard extends StatefulWidget {
  /// 创建 ElView 示例卡片。
  const ExampleViewCard({super.key, this.item, this.onBuild});

  /// 固定卡片内容，供同负载滚动对照；省略时维持随机示例。
  final CardItem? item;

  /// 可选诊断回调，记录真实 State.build 次数而非列表工厂调用次数。
  final VoidCallback? onBuild;

  @override
  State<ExampleViewCard> createState() => _ViewCardState();
}

class _ViewCardState extends State<ExampleViewCard> {
  late final CardItem _card;
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    _card = widget.item ?? demoCards[Random().nextInt(demoCards.length)];
  }

  void _toggleSelected() {
    setState(() {
      _selected = !_selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final card = _card;
    return ElCard(
      style: ElStyle(
        width: '100%',
        margin: .only(bottom: 12, left: 12, right: 12),
        padding: .all(14),
        backgroundColor: _selected ? Color(0xFFEAF2FF) : Colors.white,
        border: .all(borderColor: _selected ? Color(0xFF2868D8) : Color(0xFFE2E8F0), borderWidth: _selected ? 1.5 : 1),
        borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
        boxShadow: _selected ? _selectedShadow : _cardShadow,
        color: _selected ? Color(0xFF1D4ED8) : Color(0xFF0F172A),
        onHover: ElStyle(backgroundColor: Color(0xFFF8FBFF), color: Color(0xFF1D4ED8), iconColor: Color(0xFF1D4ED8)),
        onTap: ElStyle(backgroundColor: Color(0xFFE8F1FF), transform: ElTransform.scale(0.99)),
        transition: [ElTransition.all(Duration(milliseconds: 120), Curves.easeOut)],
        iconColor: _selected ? Color(0xFF1D4ED8) : Color(0xFF0F172A),
      ),
      event: ElEvent(onTap: (_) => _toggleSelected()),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 14,
        children: [
          _StatusIcon(card: card, active: _selected),
          Expanded(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Row(
                  crossAxisAlignment: .center,
                  spacing: 8,
                  children: [
                    Expanded(
                      child: ElView(
                        style: ElStyle(fontSize: 15, fontWeight: .w700, maxLines: 1, textOverflow: .ellipsis),
                        child: card.title,
                      ),
                    ),
                    _PriorityPill(priority: card.priority),
                  ],
                ),
                SizedBox(height: 7),
                ElView(
                  style: ElStyle(
                    width: '100%',
                    color: Color(0xFF475569),
                    fontSize: 13,
                    lineHeight: 1.35,
                    maxLines: 2,
                    textOverflow: .ellipsis,
                    iconColor: Color(0xFF475569),
                  ),
                  child: card.summary,
                ),
                SizedBox(height: 12),
                Row(
                  crossAxisAlignment: .center,
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: .center,
                        spacing: 12,
                        children: [
                          Flexible(
                            child: _MetaText(icon: Icons.schedule_outlined, text: card.due),
                          ),
                          Flexible(
                            child: _MetaText(icon: Icons.person_outline, text: card.owner),
                          ),
                        ],
                      ),
                    ),
                    _CardSourceBadge(selected: _selected),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSourceBadge extends StatelessWidget {
  const _CardSourceBadge({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(height: 18, alignment: .center),
      child: Row(
        mainAxisSize: .min,
        crossAxisAlignment: .center,
        spacing: 8,
        children: [
          ElView(
            style: ElStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: .w600, iconColor: Color(0xFF64748B)),
            child: 'ElView',
          ),
          if (selected) Icon(Icons.check_circle, size: 18, color: Color(0xFF2868D8)),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.card, required this.active});

  final CardItem card;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(
        width: 42,
        height: 42,
        backgroundColor: active ? Color(0xFF2868D8) : card.tint,
        borderRadius: BorderRadius.all(Radius.elliptical(8, 8)),
        alignment: .center,
      ),
      child: Icon(card.icon, color: Colors.white, size: 22),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    return ElView(
      style: ElStyle(
        padding: .symmetric(horizontal: 9, vertical: 4),
        backgroundColor: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.all(Radius.elliptical(999, 999)),
        border: .all(borderColor: Color(0xFFE2E8F0)),
      ),
      child: ElView(
        style: ElStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: .w600, iconColor: Color(0xFF475569)),
        child: priority,
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      crossAxisAlignment: .center,
      spacing: 5,
      children: [
        Icon(icon, size: 15, color: Color(0xFF64748B)),
        Flexible(
          child: ElView(
            style: ElStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: .w500,
              maxLines: 1,
              textOverflow: .ellipsis,
              iconColor: Color(0xFF64748B),
            ),
            child: text,
          ),
        ),
      ],
    );
  }
}

/// 卡片数据模型。
class CardItem {
  /// 创建卡片数据。
  CardItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.owner,
    required this.due,
    required this.priority,
    required this.tint,
    required this.icon,
  });

  /// 编号。
  final int id;

  /// 标题。
  final String title;

  /// 摘要。
  final String summary;

  /// 负责人。
  final String owner;

  /// 截止时间。
  final String due;

  /// 优先级。
  final String priority;

  /// 图标底色。
  final Color tint;

  /// 图标。
  final IconData icon;
}

/// 示例卡片数据。
final List<CardItem> demoCards = List<CardItem>.generate(_cardCount, (index) {
  final template = _cardTemplates[index % _cardTemplates.length];
  final sprint = index ~/ _cardTemplates.length + 1;
  return CardItem(
    id: index,
    title: '${template.title} #${index + 1}',
    summary: template.summary,
    owner: template.owner,
    due: 'Sprint $sprint',
    priority: template.priority,
    tint: template.tint,
    icon: template.icon,
  );
}, growable: false);

List<BoxShadow> _cardShadow = [BoxShadow(color: Color(0x100F172A), blurRadius: 10, offset: Offset(0, 3))];

List<BoxShadow> _selectedShadow = [BoxShadow(color: Color(0x1A2868D8), blurRadius: 16, offset: Offset(0, 5))];

int _cardCount = 120;

List<CardItem> _cardTemplates = [
  CardItem(
    id: 0,
    title: '订单同步任务',
    summary: '核对渠道订单状态，处理重试队列，并保持列表滚动时的视觉稳定性。',
    owner: 'Ming',
    due: 'Sprint',
    priority: '高',
    tint: Color(0xFF2868D8),
    icon: Icons.sync_alt,
  ),
  CardItem(
    id: 1,
    title: '库存预警规则',
    summary: '将低库存、锁定库存和补货周期整理成统一的运营状态卡片。',
    owner: 'Yan',
    due: 'Sprint',
    priority: '中',
    tint: Color(0xFF0F9F6E),
    icon: Icons.inventory_2_outlined,
  ),
  CardItem(
    id: 2,
    title: '客户回访池',
    summary: '按最近互动、客户等级和响应时间排序，让高价值任务优先露出。',
    owner: 'Qiao',
    due: 'Sprint',
    priority: '中',
    tint: Color(0xFF7C3AED),
    icon: Icons.support_agent,
  ),
  CardItem(
    id: 3,
    title: '异常支付排查',
    summary: '展示支付通道、失败原因和人工处理状态，快速定位可恢复交易。',
    owner: 'Chen',
    due: 'Sprint',
    priority: '高',
    tint: Color(0xFFDC2626),
    icon: Icons.receipt_long_outlined,
  ),
  CardItem(
    id: 4,
    title: '内容审核流',
    summary: '汇总待审项目、处理人和超时风险，用紧凑卡片承载重复操作。',
    owner: 'Lin',
    due: 'Sprint',
    priority: '低',
    tint: Color(0xFF0891B2),
    icon: Icons.fact_check_outlined,
  ),
];
