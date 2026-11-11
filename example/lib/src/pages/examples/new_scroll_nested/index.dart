import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

/// 对照新版 ElScroll 在纵横轴嵌套、尺寸约束与 shrinkWrap 下的行为。
class NewScrollNestedPage extends StatelessWidget {
  /// 创建嵌套滚动审核页面。
  const NewScrollNestedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('新版滚动 · 嵌套与尺寸')),
      body: ElScroll(
        padding: EdgeInsets.all(16),
        gap: 16,
        children: [
          _info(colors),
          for (final outer in [Axis.vertical, Axis.horizontal])
            for (final inner in [Axis.vertical, Axis.horizontal]) _case(colors, outer: outer, inner: inner),
          _shrinkWrapCase(colors),
          Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Text(
              '这里使用的是官方一维 Sliver：同轴拖动按边界接力，异轴分别滚动。'
              '双轴滚动不属于当前 ElScroll 的支持范围。',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(ColorScheme colors) => Card(
    color: colors.surfaceContainerLow,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('纵横轴嵌套矩阵', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('拖动蓝色内层与灰色外层，观察同轴接力、异轴独立滚动；下方单独展示 shrinkWrap 的自然高度。'),
        ],
      ),
    ),
  );

  Widget _case(ColorScheme colors, {required Axis outer, required Axis inner}) {
    final vertical = outer == Axis.vertical;
    final title = '外层${vertical ? '纵向' : '横向'} / 内层${inner == Axis.vertical ? '纵向' : '横向'}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('外层固定 220 高；内层 172 高，均可独立拖拽。', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
            SizedBox(height: 10),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.hardEdge,
              child: ElScroll(
                axis: outer,
                padding: EdgeInsets.all(10),
                gap: 10,
                children: [
                  _outerBlock(colors, vertical: vertical, label: '外层开始'),
                  _inner(colors, axis: inner),
                  _outerBlock(colors, vertical: vertical, label: '外层结束'),
                  _outerBlock(colors, vertical: vertical, label: '继续滚动'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outerBlock(ColorScheme colors, {required bool vertical, required String label}) => Container(
    width: vertical ? double.infinity : 150,
    height: vertical ? 88 : 190,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
    child: Text(label),
  );

  Widget _inner(ColorScheme colors, {required Axis axis}) => SizedBox(
    width: 240,
    height: 172,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: ElScroll(
          axis: axis,
          shrinkWrap: true,
          gap: 6,
          children: [
            for (var i = 0; i < 12; i++)
              Container(
                width: axis == Axis.horizontal ? 116 : double.infinity,
                height: axis == Axis.vertical ? 40 : 136,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(6)),
                child: Text('内层 ${i + 1}', style: TextStyle(color: colors.onPrimaryContainer)),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _shrinkWrapCase(ColorScheme colors) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('shrinkWrap · 高度跟随内容', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('不给内层固定高度，只限制最大高度为 180。两个子项时按内容收缩。'),
          SizedBox(height: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 180),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElScroll(
                shrinkWrap: true,
                gap: 6,
                padding: EdgeInsets.all(8),
                children: [
                  for (var i = 0; i < 2; i++)
                    Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('自然高度子项 ${i + 1}'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
