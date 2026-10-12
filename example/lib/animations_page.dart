import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

part 'scenes.dart';

/// 用实际界面展示各组件内置的进出场效果。
class ElAnimationExamplesPage extends StatefulWidget {
  /// 创建动画展示页。
  const ElAnimationExamplesPage({super.key});

  @override
  State<ElAnimationExamplesPage> createState() => _AnimationExamplesPageState();
}

class _AnimationExamplesPageState extends State<ElAnimationExamplesPage> {
  final _visible = List<bool>.filled(_Demo.values.length, true);

  @override
  Widget build(BuildContext context) {
    final allVisible = _visible.every((value) => value);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FLUTTER BASE',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '开关动画',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '提示、弹窗、侧栏与折叠面板。每种效果都有内置的进出场节奏。',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        key: ValueKey('toggle-all'),
                        onPressed: () => setState(() {
                          _visible.fillRange(0, _visible.length, !allVisible);
                        }),
                        icon: Icon(
                          allVisible
                              ? Icons.visibility_off_outlined
                              : Icons.play_arrow_rounded,
                          size: 18,
                        ),
                        label: Text(allVisible ? '全部隐藏' : '全部播放'),
                      ),
                      Text(
                        '9 个场景 · 点击卡片开关可反向切换',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.maxWidth / 320)
                          .floor()
                          .clamp(1, 3);
                      final width =
                          (constraints.maxWidth - (columns - 1) * 16) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final demo in _Demo.values)
                            SizedBox(width: width, child: _card(demo)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(_Demo demo) {
    final value = _visible[demo.index];
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Color(0xffe4e7ef)),
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    demo.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: TextButton(
                    key: ValueKey('toggle-${demo.name}'),
                    onPressed: () =>
                        setState(() => _visible[demo.index] = !value),
                    style: TextButton.styleFrom(
                      minimumSize: Size(56, 32),
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(value ? '关闭' : '播放'),
                  ),
                ),
              ],
            ),
            Text(
              demo.component,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 192,
                width: double.infinity,
                child: CustomPaint(
                  painter: _StagePainter(),
                  child: _DemoScene(
                    demo: demo,
                    value: value,
                    animate: (child) => _animation(demo, value, child),
                  ),
                ),
              ),
            ),
            SizedBox(height: 14),
            Text(
              demo.description,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animation(_Demo demo, bool value, Widget child) => switch (demo) {
    _Demo.fade => ElFadeAnimation(value, child: child),
    _Demo.slide => ElSlideAnimation(value, child: child),
    _Demo.scale => ElScaleAnimation(value, child: child),
    _Demo.fadeSlide => ElFadeSlideAnimation(value, child: child),
    _Demo.fadeScale => ElFadeScaleAnimation(value, child: child),
    _Demo.reveal => ElRevealAnimation(value, child: child),
    _Demo.flip => ElFlipAnimation(value, child: child),
    _Demo.collapseVertical || _Demo.collapseHorizontal => ElCollapseAnimation(
      value,
      axis: demo == _Demo.collapseHorizontal ? Axis.horizontal : Axis.vertical,
      child: child,
    ),
  };
}

enum _Demo {
  fade('轻量提示', 'ElFadeAnimation', '轻柔显隐，没有多余位移。'),
  slide('侧边面板', 'ElSlideAnimation', '从边缘进入，减速停靠。'),
  scale('状态反馈', 'ElScaleAnimation', '从中心缩放，平稳停下。'),
  fadeSlide('消息通知', 'ElFadeSlideAnimation', '轻移与淡入同步完成。'),
  fadeScale('确认弹窗', 'ElFadeScaleAnimation', '轻微缩放，柔和显隐。'),
  reveal('内容揭示', 'ElRevealAnimation', '沿阅读方向展开，内容保持原位。'),
  flip('卡片翻转', 'ElFlipAnimation', '透视转入，卡片尽早恢复清晰。'),
  collapseVertical('折叠面板', 'ElCollapseAnimation', '向下展开，推动后续内容。'),
  collapseHorizontal('搜索工具栏', 'ElCollapseAnimation', '收缩宽度，为相邻操作让出空间。');

  final String title;
  final String component;
  final String description;

  const _Demo(this.title, this.component, this.description);
}
