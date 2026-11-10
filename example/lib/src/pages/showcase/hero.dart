import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import '../../widgets/panel.dart';

/// 综合展示首屏，宽屏并排介绍与场景卡片，窄屏自然堆叠。
class ShowcaseHero extends StatelessWidget {
  /// 创建首屏并提供按钮分区的定位动作。
  const ShowcaseHero({super.key, required this.onExplore});

  /// 定位到下方按钮展示。
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final theme = context.elTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final copy = Column(
          key: ValueKey('showcase-hero-copy'),
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: 20,
          children: [
            Text(
              'EL UI · 组件展示',
              style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: .w600, letterSpacing: 1),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '自然留白，\n'),
                  TextSpan(
                    text: '轻盈交互。',
                    style: TextStyle(color: theme.primary),
                  ),
                ],
              ),
              style: TextStyle(fontSize: wide ? 46 : 34, height: 1.18, fontWeight: .w700, color: theme.textColor),
            ),
            Text('从一组清晰的操作开始，体验组件的细节与反馈。', style: TextStyle(color: theme.textSecondary, height: 1.7)),
            ElButton(
              key: ValueKey('showcase-explore'),
              type: .primary,
              icon: Icons.arrow_forward_rounded,
              onPressed: onExplore,
              child: '体验按钮',
            ),
          ],
        );
        final art = ExcludeSemantics(child: _PreviewScene());
        return ExamplePanel(
          key: ValueKey('showcase-hero'),
          style: ElStyle(
            padding: .all(wide ? 36 : 24),
            borderRadius: .circular(28),
            border: .all(borderColor: theme.dividerColor),
            gradient: LinearGradient(
              begin: .topLeft,
              end: .bottomRight,
              colors: [theme.cardColor, Color.alphaBlend(theme.primary.withValues(alpha: .07), theme.cardColor)],
            ),
          ),
          child: wide
              ? Row(
                  children: [
                    Expanded(child: copy),
                    SizedBox(width: 32),
                    Expanded(child: art),
                  ],
                )
              : Column(crossAxisAlignment: .stretch, mainAxisSize: .min, spacing: 28, children: [copy, art]),
        );
      },
    );
  }
}

class _PreviewScene extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.elTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: ValueKey('showcase-hero-scene'),
        height: MediaQuery.textScalerOf(context).scale(240),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 16,
              top: 0,
              bottom: 28,
              child: ExamplePanel(
                style: ElStyle(
                  padding: .all(24),
                  borderRadius: .circular(24),
                  backgroundColor: theme.cardColor,
                  boxShadow: [
                    BoxShadow(color: theme.primary.withValues(alpha: .1), blurRadius: 32, offset: Offset(0, 12)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: .stretch,
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Icon(Icons.layers_outlined, color: theme.primary, size: 28),
                        Row(
                          spacing: 5,
                          children: [
                            for (final alpha in [.15, .3, .5])
                              ElView(
                                style: ElStyle(
                                  width: 6,
                                  height: 6,
                                  borderRadius: .circular(3),
                                  backgroundColor: theme.primary.withValues(alpha: alpha),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: .start,
                      mainAxisSize: .min,
                      spacing: 6,
                      children: [
                        Text(
                          '自在，从容。',
                          style: TextStyle(fontSize: 24, fontWeight: .w600, color: theme.textColor),
                        ),
                        Text('清晰而自然的视觉秩序', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                      ],
                    ),
                    ElView(
                      style: ElStyle(height: 6, backgroundColor: theme.fill, borderRadius: .circular(3)),
                      child: Align(
                        alignment: .centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: .72,
                          child: ElView(
                            style: ElStyle(height: 6, backgroundColor: theme.primary, borderRadius: .circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              width: math.min(224, constraints.maxWidth),
              child: ExamplePanel(
                style: ElStyle(
                  padding: .all(16),
                  backgroundColor: theme.cardColor,
                  border: .all(borderColor: theme.dividerColor),
                  borderRadius: .circular(18),
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    Icon(Icons.check_circle_rounded, color: theme.success, size: 30),
                    Expanded(
                      child: Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .start,
                        spacing: 3,
                        children: [
                          Text(
                            '准备就绪',
                            style: TextStyle(fontWeight: .w600, color: theme.textColor),
                          ),
                          Text('每一步都轻松', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
                        ],
                      ),
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
}
