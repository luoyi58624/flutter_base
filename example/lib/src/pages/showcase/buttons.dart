import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'panel.dart';

/// 首批按钮场景，按正文宽度独立排成一列或两列。
class ButtonShowcase extends StatelessWidget {
  /// 创建按钮展示分区。
  const ButtonShowcase({super.key});

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey('showcase-buttons'),
    mainAxisSize: .min,
    crossAxisAlignment: .stretch,
    spacing: 24,
    children: [
      Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: 10,
        children: [
          Text(
            '01 / 基础组件',
            style: TextStyle(fontSize: 12, fontWeight: .w600, color: context.elTheme.primary),
          ),
          Text(
            '从按钮开始',
            style: TextStyle(fontSize: 28, fontWeight: .w700, color: context.elTheme.textColor),
          ),
          Text('清晰的操作层级，自然的按压反馈。', style: TextStyle(color: context.elTheme.textSecondary)),
        ],
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 2 : 1;
          final width = (constraints.maxWidth - 20 * (columns - 1)) / columns;
          return Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              SizedBox(key: ValueKey('showcase-basic-panel'), width: width, child: _BasicButtons()),
              SizedBox(key: ValueKey('showcase-state-panel'), width: width, child: _StateButtons()),
            ],
          );
        },
      ),
    ],
  );
}

class _BasicButtons extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final feedback = useState('选择一个按钮，查看即时反馈。');
    return ShowcasePanel(
      title: '主次操作',
      description: '用实心、描边和文字按钮，让重要操作一目了然。',
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: 24,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              ElButton(
                key: ValueKey('showcase-primary'),
                type: .primary,
                onPressed: () => feedback.value = '主要操作已完成',
                child: '主要操作',
              ),
              ElButton(variant: .outline, onPressed: () => feedback.value = '已打开预览', child: '预览'),
              ElButton(variant: .text, onPressed: () => feedback.value = '操作已重置', child: '重置'),
            ],
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              feedback.value,
              key: ValueKey('showcase-basic-feedback'),
              style: TextStyle(fontSize: 12, color: context.elTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateButtons extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final favorite = useState(false);
    final added = useState(0);
    final loading = useState(false);
    final submitted = useState(false);
    return ShowcasePanel(
      title: '图标与状态',
      description: '体验收藏切换、提交反馈，以及明确的禁用状态。',
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: 20,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 12,
            crossAxisAlignment: .center,
            children: [
              ElButton.toggle(
                key: ValueKey('showcase-favorite'),
                modelValue: favorite,
                type: .primary,
                semanticLabel: favorite.value ? '取消收藏' : '收藏',
                child: favorite.value ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              ),
              ElButton(child: Icons.add_rounded, semanticLabel: '添加一项', onPressed: () => added.value++),
              ElButton(
                key: ValueKey('showcase-submit'),
                type: .primary,
                loading: loading.value,
                onPressed: () async {
                  if (loading.value) return;
                  loading.value = true;
                  await Future<void>.delayed(Duration(milliseconds: 900));
                  if (!context.mounted) return;
                  loading.value = false;
                  submitted.value = true;
                },
                child: submitted.value ? '已提交' : '提交',
              ),
              ElButton(disabled: true, child: '暂不可用'),
            ],
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              '${favorite.value ? '已收藏' : '未收藏'} · 已添加 ${added.value} 项',
              key: ValueKey('showcase-state-feedback'),
              style: TextStyle(fontSize: 12, color: context.elTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
