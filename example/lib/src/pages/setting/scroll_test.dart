import 'package:flutter/material.dart';
import 'package:flutter_base/desktop.dart';

import '../../widgets/example_image.dart';

/// 用一万条图文文章测试滚动和按压反馈。
class ScrollTestPage extends StatelessWidget {
  /// 创建文章列表滚动测试页。
  const ScrollTestPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.elTheme.fill,
    appBar: AppBar(title: Text('滚动测试')),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final coverWidth = (constraints.maxWidth * .24).clamp(0.0, 112.0).toDouble();
              return ElScrollView(
                padding: .symmetric(vertical: 8),
                children: [
                  ElListView.builder(
                    itemCount: 10000,
                    gap: 8,
                    itemBuilder: (_, index) => _ArticleCard(
                      index: index,
                      coverWidth: constraints.maxWidth >= 260 && index % 3 != 1 ? coverWidth : 0,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _ArticleCard extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _ArticleCard({required this.index, required this.coverWidth});

  final int index;
  final double coverWidth;

  @override
  Widget build(BuildContext context) {
    final article = _articles[index % _articles.length];
    final theme = context.elTheme;
    return ElCardView(
      style: ElStyle(
        padding: .fromLTRB(16, 15, 16, 13),
        backgroundColor: theme.cardColor,
        borderRadius: .circular(4),
      ).withTapScale(),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 10,
        children: [
          ElView(
            style: ElStyle(
              fontSize: 18,
              fontWeight: .w700,
              color: theme.textColor,
              lineHeight: 1.32,
              maxLines: 2,
              textOverflow: .ellipsis,
            ),
            child: article.title,
          ),
          Row(
            crossAxisAlignment: .start,
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .stretch,
                  spacing: 6,
                  children: [
                    Row(
                      spacing: 7,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.primary.withValues(alpha: .12),
                          foregroundColor: theme.primary,
                          child: Text(
                            article.author.characters.first,
                            style: TextStyle(fontSize: 10),
                            textScaler: TextScaler.noScaling,
                          ),
                        ),
                        Expanded(
                          child: ElView(
                            style: ElStyle(
                              fontSize: 14,
                              fontWeight: .w600,
                              color: theme.textRegular,
                              maxLines: 1,
                              textOverflow: .ellipsis,
                            ),
                            child: article.author,
                          ),
                        ),
                      ],
                    ),
                    ElView(
                      style: ElStyle(
                        fontSize: 15,
                        color: theme.textRegular,
                        lineHeight: 1.45,
                        maxLines: 2,
                        textOverflow: .ellipsis,
                      ),
                      child: article.summary,
                    ),
                  ],
                ),
              ),
              if (coverWidth > 0)
                SizedBox(
                  width: coverWidth,
                  height: coverWidth * .74,
                  child: ClipRRect(
                    borderRadius: .circular(4),
                    child: Image.network(
                      'https://picsum.photos/seed/scroll-article-$index/320/240',
                      fit: .cover,
                      cacheWidth: (coverWidth * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, 320),
                      excludeFromSemantics: true,
                      frameBuilder: exampleImageFrame,
                      errorBuilder: exampleImageError,
                    ),
                  ),
                ),
            ],
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _reaction(Icons.thumb_up_outlined, 24 + (index * 37) % 283, theme.textSecondary),
                    _reaction(Icons.chat_bubble_outline, 8 + (index * 19) % 87, theme.textSecondary),
                  ],
                ),
              ),
              ElView(
                style: ElStyle(
                  padding: .symmetric(horizontal: 7, vertical: 3),
                  backgroundColor: theme.fill,
                  borderRadius: .circular(3),
                  fontSize: 12,
                  color: theme.textSecondary,
                ),
                child: article.topic,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reaction(IconData icon, int count, Color color) => Row(
    mainAxisSize: .min,
    spacing: 5,
    children: [
      Icon(icon, size: 15, color: color),
      Text('$count', style: TextStyle(fontSize: 13, color: color)),
    ],
  );
}

final _articles = <({String title, String author, String summary, String topic})>[
  (
    title: '列表一滑就掉帧，我先查了这三个地方',
    author: '林间终端',
    summary: '同一组卡片，慢慢滑几乎看不出问题，一甩动就会卡在新图片进场的那一帧。我把图片解码、文字排版和条目换绑分开记录，才看清每次尖峰来自哪里。',
    topic: 'Flutter',
  ),
  (
    title: '为什么有的开源项目很好用，第一次提交代码却很难？',
    author: '代码旁白',
    summary: '上周我试着给一个常用工具修复拼写错误，改代码只用了几分钟，跑通测试却花了一个晚上。后来我把踩过的坑写成了贡献指南里的一段快速开始。',
    topic: '开源',
  ),
  (
    title: '把 AI 编程助手接进项目后，我改了代码审查流程',
    author: '晚一点发布',
    summary: '我挑了三个平时容易漏测的改动，让助手和同事分别给出验证步骤。最有帮助的一条建议出现在登录超时场景，原来我们一直只测了请求成功的分支。',
    topic: '人工智能',
  ),
  (
    title: '从一次半夜告警说起：重试到底该放在哪一层',
    author: '阿栈的备忘录',
    summary: '上游接口超时后，网关、业务服务和 SDK 同时开始重试，原本的一次请求在短时间内被放大了好几倍。这篇复盘记录我们怎么定位和收敛这条调用链。',
    topic: '后端',
  ),
  (
    title: '同一张图为什么在相册里快，在首页却慢？',
    author: '像素小记',
    summary: '相册只请求刚好能填满格子的缩略图，首页却一直在读取原图。把两个页面的请求尺寸和缓存键放在一起看之后，我找到了重复解码的那一步。',
    topic: '客户端',
  ),
  (
    title: '一个报表导出功能，为什么最后改成了后台任务',
    author: '南桥',
    summary: '数据范围一大，用户要等到文件生成完才能继续操作。我们拆开了筛选、生成和下载，把进度绑定到任务编号，还补上了失败后只重跑未完成部分的处理。',
    topic: '后端',
  ),
  (
    title: '桌面窗口缩到一半，页面布局开始露出真问题',
    author: '留白研究所',
    summary: '左右栏一起缩窄时，最长的工具栏按钮把正文挤出了窗口。我逐个排查固定宽度，把关键操作放到同一行，让其余操作在空间不足时进入菜单。',
    topic: '前端',
  ),
  (
    title: '写了一次“删不掉”的缓存，才真正搞懂过期策略',
    author: '一杯冷萃',
    summary: '商品已经下架，搜索结果仍然保留旧链接。追了半天发现写入、查询和索引各自保留了一份状态，统一失效时机比调小缓存时间更管用。',
    topic: '工程实践',
  ),
  (
    title: '在大字号下重新检查了一遍消息列表',
    author: '像素小记',
    summary: '把字号调到最大后，几个原本看起来宽裕的时间戳挤到了头像下方。我记录了哪些区域需要换行，哪些信息应该单独成行，再用真实的长昵称验证了一次。',
    topic: '无障碍',
  ),
  (
    title: '我们把线上问题整理成了一组能重跑的测试',
    author: '代码旁白',
    summary: '复现描述里的“快速点几下”很难每次都做对。我把事件顺序和请求结果固定下来，逐帧检查弹窗、返回和表单恢复，第二天就抓到了一个类似问题。',
    topic: '测试',
  ),
  (
    title: '写给第一次接手老项目的自己',
    author: '晚一点发布',
    summary: '接手第一天我没有急着拆目录，先跑通最常用的三个入口，把依赖的外部服务、测试账号和发布步骤画在一张图上。后来的排查大多能从这张图开始。',
    topic: '工程实践',
  ),
  (
    title: '滚动到底后再返回，为什么原来的阅读位置找不回来了',
    author: '林间终端',
    summary: '列表前面插入新文章后，保存下来的像素位置还在，原来那篇文章却已经移走了。我开始同时记录条目身份和它离屏幕顶部的距离，回来时先定位条目。',
    topic: 'Flutter',
  ),
];
