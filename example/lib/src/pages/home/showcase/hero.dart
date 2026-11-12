import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';

import 'panel.dart';

/// 完整展示页首屏，手机隐藏装饰，宽屏保留原稿浮动卡片。
class ShowcaseHero extends StatelessWidget {
  /// 创建两个章节定位入口。
  const ShowcaseHero({super.key, required this.onExplore, required this.onTakeaway});

  /// 定位基础组件。
  final VoidCallback onExplore;

  /// 定位外卖示例。
  final VoidCallback onTakeaway;
  @override
  Widget build(BuildContext context) {
    final scope = ShowcaseScope.of(context), t = context.elTheme;
    final mobile = scope.mobile;
    final size = mobile ? (scope.width * .077).clamp(28.0, 39.0) : (scope.width * .04).clamp(36.0, 54.0);
    final copy = Padding(
      key: ValueKey('showcase-hero-copy'),
      padding: .symmetric(vertical: mobile ? 0 : 12),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              ElView(
                style: ElStyle(width: 19, height: 2, backgroundColor: t.primary, borderRadius: .circular(2)),
              ),
              SizedBox(width: 9),
              Text(
                'MY-UI · 组件展示',
                style: TextStyle(color: t.primary, fontSize: 11, fontWeight: .w700, letterSpacing: 1),
              ),
            ],
          ),
          SizedBox(height: 13),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '自然留白，\n'),
                TextSpan(
                  text: '轻盈交互。',
                  style: TextStyle(color: t.primary),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: size,
              height: 1.15,
              letterSpacing: -size * .045,
              fontWeight: .w700,
              color: t.textColor,
            ),
          ),
          SizedBox(height: 12),
          demoHint(context, '体验按钮、表单、弹层与完整交互场景。', size: mobile ? 14 : 15, height: 1.7),
          SizedBox(height: mobile ? 16 : 20),
          demoActions([
            ElButton(
              key: ValueKey('showcase-explore'),
              onPressed: onExplore,
              style: ElStyle(height: 44, padding: .symmetric(horizontal: 18), borderRadius: .circular(12)),
              child: Row(
                mainAxisSize: .min,
                spacing: 10,
                children: [
                  ElView(child: '探索组件'),
                  demoIcon(ElMobileIcons.arrowRight, size: 16),
                ],
              ),
            ),
            ElButton(
              variant: .outline,
              onPressed: onTakeaway,
              style: ElStyle(
                height: 44,
                padding: .symmetric(horizontal: 18),
                borderRadius: .circular(12),
                backgroundColor: t.cardColor,
                border: .all(borderColor: t.borderColor),
              ),
              child: '外卖示例',
            ),
          ]),
        ],
      ),
    );
    return ElCard(
      key: ValueKey('showcase-hero'),
      style: ElStyle(
        padding: mobile ? .all(22) : .symmetric(vertical: 24, horizontal: (scope.width * .04).clamp(28, 58)),
        borderRadius: .circular(mobile ? 22 : 30),
        border: .all(borderColor: t.borderColor),
        boxShadow: [],
        clipBehavior: .antiAlias,
        gradient: LinearGradient(
          begin: .centerLeft,
          end: .bottomRight,
          colors: [t.cardColor, Color.alphaBlend(t.primary.withValues(alpha: .08), t.cardColor)],
          stops: [.48, 1],
        ),
      ),
      child: mobile
          ? copy
          : Row(
              children: [
                Expanded(flex: 100, child: copy),
                Expanded(flex: 95, child: ExcludeSemantics(child: _Scene())),
              ],
            ),
    );
  }
}

class _Scene extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.elTheme;
    Widget chip(String title, String note, bool success) => ElView(
      style: ElStyle(borderRadius: .circular(17), boxShadow: t.shadowLg),
      child: ElCard(
        style: ElStyle(
          width: success ? 140 : 146,
          padding: .symmetric(horizontal: 16, vertical: 13),
          borderRadius: .circular(17),
          boxShadow: [],
          backgroundColor: t.cardColor.withValues(alpha: .94),
          border: .all(borderColor: t.cardColor.withValues(alpha: .94)),
          backdropFilter: ElFilter(blur: 12),
        ),
        child: Row(
          mainAxisSize: .min,
          spacing: 10,
          children: [
            ElView(
              style: ElStyle(
                width: 31,
                height: 31,
                alignment: .center,
                borderRadius: .circular(11),
                backgroundColor: success ? t.success.withValues(alpha: .1) : t.fill,
                iconColor: success ? t.success : t.primary,
                iconSize: 17,
              ),
              child: success ? ElMobileIcons.check : ElMobileIcons.spark,
            ),
            Column(
              crossAxisAlignment: .start,
              mainAxisSize: .min,
              spacing: 3,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: .w600, color: t.textColor),
                ),
                demoHint(context, note, size: 10),
              ],
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      key: ValueKey('showcase-hero-scene'),
      height: 304,
      child: FittedBox(
        fit: .scaleDown,
        alignment: .centerRight,
        child: SizedBox(
          width: 440,
          height: 304,
          child: Stack(
            clipBehavior: .none,
            children: [
              Positioned(
                left: 64,
                top: 4,
                child: ElView(
                  style: ElStyle(
                    width: 300,
                    height: 300,
                    padding: .all(24),
                    border: .all(borderColor: t.primary.withValues(alpha: .23)),
                    borderRadius: .circular(150),
                  ),
                  child: SizedBox.expand(
                    child: ElView(
                      style: ElStyle(
                        border: .all(borderColor: t.primary.withValues(alpha: .22), borderStyle: .dashed),
                        borderRadius: .circular(150),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 47,
                top: 43,
                child: Transform.rotate(
                  angle: -5 * math.pi / 180,
                  child: ElView(
                    style: ElStyle(borderRadius: .circular(30), boxShadow: t.shadowMd),
                    child: ElCard(
                      style: ElStyle(
                        width: 320,
                        height: 240,
                        padding: .all(26),
                        borderRadius: .circular(30),
                        backgroundColor: t.cardColor.withValues(alpha: .75),
                        border: .all(borderColor: t.cardColor.withValues(alpha: .9)),
                        backdropFilter: ElFilter(blur: 10),
                        boxShadow: [],
                      ),
                      child: Column(
                        crossAxisAlignment: .stretch,
                        children: [
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              ElView(
                                style: ElStyle(
                                  width: 47,
                                  height: 47,
                                  alignment: .center,
                                  borderRadius: .circular(15),
                                  backgroundColor: t.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: t.primary.withValues(alpha: .15),
                                      offset: Offset(0, 5),
                                      blurRadius: 12,
                                    ),
                                  ],
                                  iconColor: t.primaryText,
                                  iconSize: 24,
                                ),
                                child: ElMobileIcons.spark,
                              ),
                              Row(
                                spacing: 5,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    ElView(
                                      style: ElStyle(
                                        width: 5,
                                        height: 5,
                                        borderRadius: .circular(3),
                                        backgroundColor: t.gray,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 22),
                          Text(
                            '自在，从容。',
                            style: TextStyle(fontSize: 16, fontWeight: .w700, color: t.textColor),
                          ),
                          SizedBox(height: 7),
                          demoHint(context, '清晰而自然的视觉秩序'),
                          SizedBox(height: 21),
                          ElView(
                            style: ElStyle(
                              height: 7,
                              backgroundColor: t.borderColor,
                              borderRadius: .circular(7),
                              clipBehavior: .antiAlias,
                            ),
                            child: FractionallySizedBox(
                              widthFactor: .68,
                              heightFactor: 1,
                              alignment: .centerLeft,
                              child: ElView(
                                style: ElStyle(backgroundColor: t.primary, borderRadius: .circular(7)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 10,
                child: Transform.rotate(angle: 7 * math.pi / 180, child: chip('已完成', '每一步都轻松', true)),
              ),
              Positioned(
                left: -17,
                bottom: 10,
                child: Transform.rotate(angle: 4 * math.pi / 180, child: chip('专注细节', '简洁，却不简单', false)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
