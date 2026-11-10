import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'artwork.dart';
import 'common.dart';

/// 旧「原野」：24 张自然进入视口的渐显卡片，画框中的图像与正文以不同速率移动。
class RevealParallaxEffectPage extends StatefulWidget {
  const RevealParallaxEffectPage({super.key});

  @override
  State<RevealParallaxEffectPage> createState() => _RevealParallaxEffectPageState();
}

class _RevealParallaxEffectPageState extends State<RevealParallaxEffectPage> {
  final controller = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: effectWhite,
    appBar: AppBar(title: Text('原野'), backgroundColor: effectWhite),
    body: ElRefresh(
      onRefresh: effectRefresh,
      child: ElScroll.sliver(
        controller: controller,
        slivers: [
          SliverToBoxAdapter(child: effectDescription('风景，正在发生', '把日常的片刻，收进一幅画里。')),
          SliverList.builder(
            itemCount: 24,
            itemBuilder: (context, index) => _MotionCard(index: index, scroll: controller),
          ),
          SliverToBoxAdapter(
            child: effectContent(
              Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '愿你也有一片自己的原野。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: effectMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MotionCard extends StatefulWidget {
  const _MotionCard({required this.index, required this.scroll});
  final int index;
  final ScrollController scroll;

  @override
  State<_MotionCard> createState() => _MotionCardState();
}

class _MotionCardState extends State<_MotionCard> {
  final cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final captions = [
      ('晨光未央', '清晨 / 暖色山丘'),
      ('海风经过', '午后 / 蓝色海岸'),
      ('暮色来信', '傍晚 / 紫色远山'),
      ('林间小路', '清晨 / 绿色山谷'),
      ('太阳慢慢升起', '日出 / 山的另一边'),
      ('潮水的声音', '午后 / 风停下的地方'),
      ('晚安，群山', '日落 / 最后一束光'),
      ('走进绿色里', '雨后 / 安静的原野'),
    ];
    final (title, caption) = captions[widget.index % captions.length];
    return effectContent(
      Padding(
        key: cardKey,
        padding: EdgeInsets.only(bottom: 32),
        child: AnimatedBuilder(
          animation: widget.scroll,
          builder: (context, child) {
            final box = cardKey.currentContext?.findRenderObject();
            final height = MediaQuery.sizeOf(context).height;
            final top = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero).dy : height * .5;
            // 只观察卡片相对屏幕的位置；不拦截输入也不修改滚动位置。
            final reveal = ((height - top) / (height * .38)).clamp(0.0, 1.0).toDouble();
            final opacity = Curves.easeOut.transform(reveal);
            final parallax = ((top - height / 2) / (height / 2)).clamp(-1.0, 1.0) * 24;
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - reveal)),
                child: _LandscapeCard(title: title, caption: caption, index: widget.index, parallax: parallax),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LandscapeCard extends StatelessWidget {
  const _LandscapeCard({required this.title, required this.caption, required this.index, required this.parallax});
  final String title;
  final String caption;
  final int index;
  final double parallax;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 250,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: -24 + parallax,
                bottom: -24 - parallax,
                left: 0,
                right: 0,
                child: LandscapeArtwork(variant: index),
              ),
            ],
          ),
        ),
      ),
      SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text(caption, style: TextStyle(fontSize: 12, color: effectMuted)),
              ],
            ),
          ),
          Text('${(index + 1).toString().padLeft(2, '0')} / 24', style: TextStyle(fontSize: 12, color: effectMuted)),
        ],
      ),
    ],
  );
}

/// 旧「把周末，还给自己」：导航下方独立的 2px 阅读进度条，正文 Sliver 不参与进度组件构建。
class ReadingProgressEffectPage extends StatefulWidget {
  const ReadingProgressEffectPage({super.key});

  @override
  State<ReadingProgressEffectPage> createState() => _ReadingProgressEffectPageState();
}

class _ReadingProgressEffectPageState extends State<ReadingProgressEffectPage> {
  final scroll = ScrollController();
  final progress = ValueNotifier<double>(0);
  var saved = false;

  static const sections = <(String, List<String>)>[
    (
      '从一顿早餐开始',
      [
        '平时的早餐，总是在赶时间。面包拿在手里，咖啡还烫着，目光已经越过餐桌，落在一天的安排上。周末可以换一种方式：坐下来，把手机放远一点，等一杯茶慢慢凉到合适的温度。',
        '窗外也许没有特别的风景，但光线每一分钟都不一样。楼下有人遛狗，有人提着刚买的菜回家。你不必加入任何一场匆忙，只需要好好吃完眼前的早餐。',
      ],
    ),
    (
      '散步不需要目的地',
      [
        '出门之前，不必先打开地图。沿着熟悉的路走，到平时总是忽略的路口，选一个没有走过的方向。城市里总有一些细节，要等脚步慢下来才肯出现。',
        '你可能会找到一棵很大的树、一家很小的书店，或一面被爬山虎覆盖的墙。它们并不是景点，也不需要拍照证明来过。看见过，就已经很好。',
        '走累了，就找个地方坐一会儿。听旁边的人聊天，看一辆公交车停下又开走。偶尔什么也不做，反而能感觉到自己正身处生活之中。',
      ],
    ),
    (
      '给注意力留一点空白',
      [
        '我们习惯了把每一段空闲填满。等水烧开的几分钟、坐车的半小时、睡前的一点时间，都可以再看一些消息。信息没有结束的时候，注意力却会疲惫。',
        '试着把某一段时间留空。不是为了更有效率，也不是为了之后更努力，只是让脑子不用一直回应什么。听完一首歌，望一会儿窗外，或者安静地把衣服叠好。',
      ],
    ),
    (
      '做一件没有考核的小事',
      [
        '画一张不打算发出去的画，煮一道不需要严格照着菜谱的菜，给花盆换一点土。事情可以做得不太好，也可以做到一半停下来。',
        '兴趣一旦变成必须完成的任务，就容易失去原来的轻松。给自己一次不计成果的尝试：不用记录进度，不必分享，也不急着定义这件事有什么用。',
        '有时，快乐来自非常具体的触感。纸的纹理、揉面时掌心的温度、阳光晒过的衣服。它们不够宏大，却足够真实。',
      ],
    ),
    (
      '留一点时间给别人',
      [
        '给很久没见的朋友发一句问候，或者约家人一起吃顿饭。无需准备一个完美的话题。聊聊最近吃到的东西、路上遇见的小事，甚至只是一起坐着。',
        '关系不总是靠重要时刻维系。更多时候，是有人记得你的口味，愿意听你把一句话说完，也允许你今天不那么精神。',
      ],
    ),
    (
      '让这一天慢慢结束',
      [
        '傍晚回家时，开一盏暖灯。把鞋放好，给自己倒一杯水。如果还有一点力气，就整理一下桌面；如果没有，留到明天也没关系。',
        '不必在睡前核对这一天完成了多少事。休息不是另一张待办清单。你有权度过一个没有产出、没有计划，也没有值得讲述的大事的周末。',
        '明天会带来明天的安排。现在，把今天留给自己。',
      ],
    ),
    (
      '慢一点也没关系',
      [
        '走错路的时候，不必急着折返。多走的每一段路都算数：你看见了一家没见过的店，闻到了别人院子里的桂花，听到一段不成调的琴声。这些都不在计划里，所以格外像礼物。',
        '吃饭也是一样。认真咀嚼一碗米饭的时间，和刷完一集剧的时间一样长，但前者会让你记住米香。快不是错误，只是别让快成为唯一的速度。',
      ],
    ),
    (
      '记录，但不打分',
      [
        '可以试着写下今天的三件小事：一只趴在窗台上的猫、一句突然想起来的歌词、一场下得很轻的雨。不评价好坏，只负责记下。日子久了回头看，会发现生活比印象中丰富得多。',
        '记录的意义不在于坚持多少天。断了也没关系，想起来再写就好。它更像在路上捡石头，捡到哪颗算哪颗，装进口袋里，走路的时候叮当作响。',
      ],
    ),
    (
      '把周末过成自己的样子',
      [
        '有人喜欢把周末排得满满当当，也有人喜欢什么都不安排。两种都可以很好，前提是那是你自己选的，而不是模仿别人的样子。',
        '周末不必有意义。你可以花一下午看云从这栋楼慢慢挪到那栋楼，也可以把一首歌听到会哼为止。时间花在让自己踏实的事情上，就不算浪费。',
        '愿你度过一个普通、具体、让人安心的周末。',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scroll.hasClients) return;
    final metrics = scroll.position;
    if (!metrics.hasContentDimensions || metrics.maxScrollExtent <= metrics.minScrollExtent) return;
    progress.value = ((metrics.pixels - metrics.minScrollExtent) / (metrics.maxScrollExtent - metrics.minScrollExtent))
        .clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    scroll.removeListener(_onScroll);
    scroll.dispose();
    progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('慢读'),
      backgroundColor: effectWhite,
      actions: [
        IconButton(
          tooltip: saved ? '取消收藏文章' : '收藏文章',
          onPressed: () => setState(() => saved = !saved),
          icon: Icon(saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark),
        ),
      ],
    ),
    backgroundColor: effectWhite,
    body: Stack(
      children: [
        ElRefresh(
          onRefresh: effectRefresh,
          child: ElScroll.sliver(
            controller: scroll,
            slivers: [
              SliverToBoxAdapter(
                child: effectContent(
                  Padding(
                    padding: EdgeInsets.only(top: 32, bottom: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('生活方式 / 慢读', style: TextStyle(fontSize: 12, letterSpacing: 2, color: Color(0xff6f8778))),
                        SizedBox(height: 14),
                        Text('把周末，\n还给自己', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, height: 1.25)),
                        SizedBox(height: 18),
                        Text('不把休息变成另一张待办清单。\n从一件小事开始，重新感受生活。', style: TextStyle(color: effectMuted, height: 1.6)),
                        SizedBox(height: 24),
                        Row(
                          children: [
                            effectAvatar('林', Color(0xff587666), size: 30),
                            SizedBox(width: 10),
                            Text('林间编辑部  ·  约 6 分钟', style: TextStyle(color: effectMuted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: effectContent(effectLandscape(0, height: 210))),
              SliverToBoxAdapter(
                child: effectContent(
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('插画 / 给日常留一点温柔的颜色', style: TextStyle(fontSize: 11, color: effectMuted)),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final (title, paragraphs) = sections[index];
                  return effectContent(
                    Padding(
                      padding: EdgeInsets.only(top: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 18),
                            child: Text(title, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600)),
                          ),
                          for (final paragraph in paragraphs) effectParagraph(paragraph),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: effectContent(
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      '全文完 · 愿你有一个属于自己的周末',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: effectMuted),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 2,
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                key: ValueKey('effects-reading-progress'),
                widthFactor: value,
                child: ColoredBox(color: Color(0xff587666)),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
