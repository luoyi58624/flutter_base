import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/flutter_base.dart';

import 'artwork.dart';
import 'common.dart';

/// 「山海之间」两版共享同一组封面与正文。区别仅在固定导航与官方 Sliver 的实现方式。
class TranslucentEffectPage extends StatefulWidget {
  const TranslucentEffectPage({super.key, required this.officialSliver});

  final bool officialSliver;

  @override
  State<TranslucentEffectPage> createState() => _TranslucentEffectPageState();
}

class _TranslucentEffectPageState extends State<TranslucentEffectPage> {
  final scrollController = ScrollController();
  final position = ValueNotifier<double>(0);
  var blurEnabled = true;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_sync);
  }

  void _sync() {
    if (scrollController.hasClients) position.value = scrollController.offset;
  }

  @override
  void dispose() {
    scrollController.removeListener(_sync);
    scrollController.dispose();
    position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final cover = _LandscapeCover(safeTop: safe.top);
    final content = _landscapeContent();
    final barExtent = safe.top + 56.0;
    Widget nav(double offset, {required bool blur}) {
      final progress = Curves.easeInOut.transform(((offset - 24) / 160).clamp(0.0, 1.0));
      return _TranslucentBar(
        progress: progress,
        safeTop: safe.top,
        blurEnabled: blur,
        showBlurToggle: widget.officialSliver,
        onToggleBlur: () => setState(() => blurEnabled = !blurEnabled),
      );
    }

    final slivers = widget.officialSliver
        ? <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _TranslucentHeader(
                safeTop: safe.top,
                cover: cover,
                blurEnabled: blurEnabled,
                toggleBlur: () => setState(() => blurEnabled = !blurEnabled),
              ),
            ),
            ...content.map((widget) => SliverToBoxAdapter(child: widget)),
          ]
        : <Widget>[SliverToBoxAdapter(child: cover), ...content.map((widget) => SliverToBoxAdapter(child: widget))];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: effectWhite,
      ),
      child: Scaffold(
        backgroundColor: effectWhite,
        body: Stack(
          children: [
            widget.officialSliver
                ? ElScrollView.sliver(
                    key: PageStorageKey('effects-landscape-official'),
                    controller: scrollController,
                    slivers: [
                      ...slivers,
                      SliverToBoxAdapter(child: SizedBox(height: safe.bottom + 24)),
                    ],
                  )
                : ElScrollView.sliver(
                    key: PageStorageKey('effects-landscape-original'),
                    controller: scrollController,
                    slivers: [
                      ElSliverRefresh(onRefresh: effectRefresh),
                      ...slivers,
                      SliverToBoxAdapter(child: SizedBox(height: safe.bottom + 24)),
                    ],
                  ),
            if (!widget.officialSliver)
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                height: barExtent,
                child: ValueListenableBuilder<double>(
                  valueListenable: position,
                  builder: (context, offset, _) => nav(offset, blur: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LandscapeCover extends StatelessWidget {
  const _LandscapeCover({required this.safeTop});
  final double safeTop;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      height: safeTop + 410,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LandscapeArtwork(variant: 1),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x500b2832), Color(0x050b2832), Color(0xc00b2832)],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('原野画册 / VOL. 01', style: TextStyle(fontSize: 12, letterSpacing: 3, color: Color(0xffe2e9e6))),
                SizedBox(height: 12),
                Text(
                  '山海之间',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text('把目光放远一点，\n把脚步放轻一点。', style: TextStyle(fontSize: 15, height: 1.6, color: Color(0xffe2e9e6))),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 这部分是两版的同一份画册；不以改变虚拟化方式掩盖导航差异。
List<Widget> _landscapeContent() {
  const chapters = [
    ('湖面的风', '风把湖面吹出细纹，光在上面碎成很多片，看久了觉得时间也慢了下来。'),
    ('入秋的通知', '叶子先知道季节的消息，然后是清晨的温度，最后才是我们的衣柜。'),
    ('山径分岔处', '两条路看起来差不多，选哪条都好，反正走的都是同一个下午。'),
    ('夜行的火车', '车窗外的灯一盏接一盏退后，像有人在替你翻一本很厚的书。'),
    ('屋顶看云', '云的形状每次抬头都不一样，看云的人不需要记住任何一朵。'),
    ('候鸟过境', '它们每年都走同一条路，却从不觉得旅途重复。'),
    ('潮间带', '潮水退下去的地方，藏着贝壳、小螃蟹和一个下午的好奇心。'),
    ('炉火与猫', '炉火的声音让房间变小，猫觉得这里就是世界的中心。'),
    ('初雪之前', '雪来之前，空气里有一种安静的期待，连脚步都不自觉放轻。'),
  ];
  final cards = <(int, String, String)>[
    (0, '01 / 等一场日出', '山还没有完全醒来，太阳已经替它描好了轮廓。先别急着出发，让温暖的颜色在眼前多停一会儿。'),
    (3, '02 / 走进山林', '路在树影里弯了几次，身后的声音就渐渐小了。绿色有许多层，远看和走近，是两种不同的答案。'),
    (2, '03 / 留住暮色', '天色暗下来的时候，山的线条反而更清楚。最后一点暖色消失之前，把这份安静带回去。'),
    for (var i = 0; i < chapters.length; i++) (i % 4, '0${i + 4} / ${chapters[i].$1}', chapters[i].$2),
  ];
  return [
    effectContent(
      Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('林间编辑部 · 四幅风景，四种心情', style: TextStyle(color: effectMuted, fontSize: 12)),
            SizedBox(height: 18),
            Text('去一个能看见地平线的地方', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 23, height: 1.4)),
            SizedBox(height: 16),
            effectParagraph('日常把目光留在很近的地方：屏幕、桌面、下一站。偶尔也想走远一些，看看山怎样接住云，海怎样把颜色交给天空。'),
            effectParagraph('这组画从清晨出发，经过海岸与山林，最后停在暮色里。没有需要赶到的终点，只有可以多停留一会儿的风景。'),
          ],
        ),
      ),
    ),
    for (final (variant, title, description) in cards)
      effectContent(
        Padding(
          padding: EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              effectLandscape(variant),
              SizedBox(height: 18),
              Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
              SizedBox(height: 12),
              effectParagraph(description),
            ],
          ),
        ),
      ),
  ];
}

/// 旧版淡入导航与官方 Sliver 保留相同的 24～184 px 进度/颜色/状态栏切换。
class _TranslucentBar extends StatelessWidget {
  const _TranslucentBar({
    required this.progress,
    required this.safeTop,
    required this.blurEnabled,
    this.showBlurToggle = true,
    required this.onToggleBlur,
  });

  final double progress;
  final double safeTop;
  final bool blurEnabled;
  final bool showBlurToggle;
  final VoidCallback onToggleBlur;

  @override
  Widget build(BuildContext context) {
    final foreground = Color.lerp(Colors.white, effectInk, progress)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: ValueKey('effects-translucent-bar'),
      value: progress < .5 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: ClipRect(
        child: BackdropFilter(
          enabled: blurEnabled && progress > 0,
          filter: ui.ImageFilter.blur(sigmaX: 18 * progress, sigmaY: 18 * progress),
          child: DecoratedBox(
            key: ValueKey('effects-translucent-background'),
            decoration: BoxDecoration(
              color: effectWhite.withValues(alpha: .96 * progress),
              border: Border(
                bottom: BorderSide(color: Color(0xffdedee3).withValues(alpha: progress), width: .5),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: safeTop, left: 4, right: 4),
              child: NavigationToolbar(
                centerMiddle: false,
                middleSpacing: 12,
                leading: SizedBox(
                  width: 56,
                  child: IconButton(
                    tooltip: '返回',
                    color: foreground,
                    icon: Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? CupertinoIcons.chevron_forward
                          : CupertinoIcons.chevron_back,
                    ),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                middle: Opacity(
                  key: ValueKey('effects-translucent-title'),
                  opacity: progress,
                  child: Text(
                    '山海之间',
                    style: TextStyle(color: foreground, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                trailing: SizedBox(
                  width: 56,
                  child: showBlurToggle
                      ? IconButton(
                          key: ValueKey('effects-translucent-blur-toggle'),
                          tooltip: blurEnabled ? '关闭模糊（对照）' : '开启模糊（原效果）',
                          color: foreground,
                          icon: Icon(blurEnabled ? Icons.blur_on : Icons.blur_off),
                          onPressed: onToggleBlur,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TranslucentHeader extends SliverPersistentHeaderDelegate {
  _TranslucentHeader({required this.safeTop, required this.cover, required this.blurEnabled, required this.toggleBlur});

  final double safeTop;
  final Widget cover;
  final bool blurEnabled;
  final VoidCallback toggleBlur;

  @override
  double get minExtent => safeTop + 56;

  @override
  double get maxExtent => safeTop + 410;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = Curves.easeInOut.transform(((shrinkOffset - 24) / 160).clamp(0.0, 1.0));
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(top: -shrinkOffset, left: 0, right: 0, height: maxExtent, child: cover),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: minExtent,
          child: _TranslucentBar(
            progress: progress,
            safeTop: safeTop,
            blurEnabled: blurEnabled,
            onToggleBlur: toggleBlur,
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _TranslucentHeader old) =>
      safeTop != old.safeTop || cover != old.cover || blurEnabled != old.blurEnabled || toggleBlur != old.toggleBlur;
}
