import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_base/flutter_base.dart';

import 'artwork.dart';
import 'common.dart';

/// 对应旧「慢读」：方向显隐、速度显隐、位置阈值和增量跟手。
class HideEffectPage extends StatefulWidget {
  const HideEffectPage({super.key, this.collapseVelocity, this.expandVelocity, this.collapseOffset});

  final double? collapseVelocity;
  final double? expandVelocity;
  final double? collapseOffset;

  @override
  State<HideEffectPage> createState() => _HideEffectPageState();
}

class _HideEffectPageState extends State<HideEffectPage> with SingleTickerProviderStateMixin {
  late final AnimationController header = AnimationController(vsync: this, duration: Duration(milliseconds: 200));
  final controller = ScrollController();
  var follow = false;
  double lastPixels = 0, travel = 0;
  Duration? lastStamp;

  static const stories = [
    ('生活方式', '把周末，还给自己', '不设闹钟，不赶行程。从一顿慢慢吃完的早餐开始。'),
    ('城市漫游', '在熟悉的街角，转一个弯', '一家没有招牌的小店，一棵刚刚开花的树。新鲜感不一定在远方。'),
    ('日常观察', '窗边的一平方米', '一束光、一把椅子和一盆绿植，足够安放一个安静的下午。'),
    ('声音笔记', '暮色有它自己的节奏', '等街灯一盏盏亮起来，再把耳机里的音量放低一些。'),
    ('慢读书单', '留一本书在手边', '不急着读完，也不急着理解。让文字陪你度过一段安静的时光。'),
    ('自然来信', '沿着风的方向走', '脚步放慢以后，树叶、潮水和远处的钟声，都变得清楚起来。'),
    ('周末日记', '在阳台种一棵柠檬', '事情本身很小，但做完之后，房间和心情都宽敞了一点。'),
    ('城市漫游', '骑车穿过整个城市', '不用等一个完美的时机，今天剩下的时间刚好够开始。'),
    ('日常观察', '给旧沙发换一个套', '慢吞吞地做一件事的时候，注意力终于回到了自己身上。'),
    ('城市漫游', '凌晨四点的面包房', '计划之外的相遇，往往比排好的行程更值得记住。'),
    ('自然来信', '在天台看一次日出', '留下来的未必有用，但每次看见都会想起那天的好天气。'),
    ('慢读书单', '学一首完整的歌', '计划外的午后也能拥有新的开始。'),
  ];

  @override
  void initState() {
    super.initState();
    controller.addListener(_observe);
  }

  void _observe() {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    final current = position.pixels;
    final delta = current - lastPixels;
    lastPixels = current;
    if (delta == 0) return;
    if (current <= position.minScrollExtent) {
      header.animateTo(0);
      return;
    }

    if (widget.collapseOffset != null) {
      if (follow) {
        header.value = ((current - widget.collapseOffset!) / 56).clamp(0.0, 1.0);
      } else {
        header.animateTo(current > widget.collapseOffset! ? 1 : 0);
      }
      return;
    }

    if (follow) {
      // 旧版跟手采用限速和反向容差，作用于导航行但不消费正文滚动距离。
      if (travel.sign != delta.sign) travel = 0;
      travel += delta;
      if (travel.abs() <= 10) return;
      header.value = (header.value + delta.clamp(-7.5, 7.5) / 56).clamp(0.0, 1.0);
      return;
    }

    if (widget.collapseVelocity != null || widget.expandVelocity != null) {
      final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
      final dt = lastStamp == null ? 1 / 60 : math.max((now - lastStamp!).inMicroseconds / 1e6, 1 / 120);
      lastStamp = now;
      final velocity = delta / dt;
      final collapseThreshold = widget.collapseVelocity ?? widget.expandVelocity ?? 800;
      final expandThreshold = widget.expandVelocity ?? widget.collapseVelocity ?? 600;
      if (velocity > collapseThreshold) header.animateTo(1);
      if (velocity < -expandThreshold) header.animateTo(0);
      return;
    }

    if (travel.sign != delta.sign) travel = 0;
    travel += delta;
    if (travel.abs() >= 8) {
      header.animateTo(delta > 0 ? 1 : 0);
      travel = 0;
    }
  }

  @override
  void dispose() {
    controller.removeListener(_observe);
    controller.dispose();
    header.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVelocity = widget.collapseVelocity != null || widget.expandVelocity != null;
    final mode = isVelocity
        ? '速度'
        : follow
        ? '跟手'
        : widget.collapseOffset != null
        ? '位置'
        : '方向';
    return Scaffold(
      backgroundColor: effectWhite,
      body: SafeArea(
        child: Stack(
          children: [
            ElScrollView.sliver(
              controller: controller,
              slivers: [
                ElSliverRefresh(onRefresh: effectRefresh),
                SliverToBoxAdapter(child: SizedBox(height: 56)),
                SliverToBoxAdapter(child: effectDescription('慢慢看，慢慢想。', '周日 · 给生活一点空白')),
                SliverList.builder(
                  itemCount: stories.length * 2,
                  itemBuilder: (context, i) {
                    final (category, title, summary) = stories[i % stories.length];
                    return effectContent(
                      Padding(
                        padding: EdgeInsets.only(bottom: 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            effectLandscape(i % 4, height: 200, radius: BorderRadius.circular(14)),
                            SizedBox(height: 16),
                            Text(
                              category,
                              style: TextStyle(color: Color(0xff567c70), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 6),
                            Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 23)),
                            SizedBox(height: 8),
                            Text(summary, style: TextStyle(color: effectMuted, height: 1.6)),
                            SizedBox(height: 14),
                            Text('林间编辑部 · 6 分钟', style: TextStyle(color: effectMuted, fontSize: 12)),
                            effectHairline(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            AnimatedBuilder(
              animation: header,
              child: Container(
                key: ValueKey('effects-hide-navigation'),
                height: 56,
                color: effectWhite,
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.maybePop(context), icon: Icon(Icons.chevron_left)),
                    Expanded(
                      child: Text('慢读', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                    Text(mode, style: TextStyle(fontSize: 12, color: effectMuted)),
                    if (!isVelocity)
                      Switch(
                        key: ValueKey('effects-hide-follow-switch'),
                        value: follow,
                        onChanged: (v) {
                          setState(() => follow = v);
                          travel = 0;
                        },
                      ),
                  ],
                ),
              ),
              builder: (context, child) => Transform.translate(offset: Offset(0, -56 * header.value), child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// 旧「午后慢调」：封面随 Sliver 正常离场，固定导航标题按封面离场进度淡入。
class FoldEffectPage extends StatefulWidget {
  const FoldEffectPage({super.key});

  @override
  State<FoldEffectPage> createState() => _FoldEffectPageState();
}

class _FoldEffectPageState extends State<FoldEffectPage> {
  final controller = ScrollController();
  final opacity = ValueNotifier<double>(0);
  final coverKey = GlobalKey();
  double coverExtent = 0;
  var saved = false;

  @override
  void initState() {
    super.initState();
    controller.addListener(_observe);
  }

  void _observe() {
    if (!controller.hasClients) return;
    final coverBox = coverKey.currentContext?.findRenderObject();
    if (coverBox is RenderBox && coverBox.hasSize) coverExtent = coverBox.size.height;
    if (coverExtent <= 0) return;
    final extent = (controller.position.pixels / coverExtent).clamp(0.0, 1.0);
    opacity.value = ((extent - .6) / .4).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    controller.removeListener(_observe);
    controller.dispose();
    opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Color(0xfffaf9f6),
    appBar: AppBar(
      backgroundColor: Color(0xfffaf9f6),
      title: ValueListenableBuilder<double>(
        valueListenable: opacity,
        builder: (context, value, child) => Opacity(opacity: value, child: child),
        child: Text('午后慢调'),
      ),
      actions: [
        IconButton(
          tooltip: saved ? '取消收藏歌单' : '收藏歌单',
          onPressed: () => setState(() => saved = !saved),
          icon: Icon(saved ? CupertinoIcons.heart_fill : CupertinoIcons.heart),
        ),
      ],
    ),
    body: ElScrollView.sliver(
      controller: controller,
      slivers: [
        ElSliverRefresh(onRefresh: effectRefresh),
        SliverToBoxAdapter(
          child: effectContent(
            Padding(
              key: coverKey,
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(width: 196, height: 196, child: LandscapeArtwork()),
                  ),
                  SizedBox(height: 22),
                  Text('午后慢调', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('林间编辑部精选', style: TextStyle(color: Color(0xff587666))),
                  SizedBox(height: 12),
                  Text('把时间调慢一点。\n钢琴、木吉他，与窗外的风。', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: effectSectionLabel('曲目', trailing: '64 首 · 约 4 小时')),
        SliverList.builder(
          itemCount: 64,
          itemBuilder: (context, i) {
            final names = [
              '晨光',
              '一杯温水',
              '风经过窗台',
              '慢慢醒来',
              '半页诗',
              '树影',
              '午后两点',
              '没有安排的一天',
              '走到河边',
              '云的形状',
              '玻璃上的雨',
              '日落之前',
            ];
            final artists = ['南山 · Piano Sketches', '白川 · 日常', '木和 · Room Sessions', '青木 · 清晨集', '陈默 · 未完成'];
            return effectContent(
              Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('${i + 1}', style: TextStyle(color: effectMuted)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(names[i % names.length], style: TextStyle(fontSize: 17)),
                          SizedBox(height: 4),
                          Text(artists[i % artists.length], style: TextStyle(color: effectMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                      '0${3 + i % 2}:${((i * 17 + 13) % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(color: effectMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
