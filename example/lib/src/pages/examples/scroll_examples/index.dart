import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../sliver_recycler/index.dart';
import '../sliver_takeaway/index.dart';
import 'cards.dart';
import 'chat.dart';
import 'media.dart';
import 'nest_scroll.dart';
import 'orders.dart';
import 'product_waterfall.dart';
import 'rich_document.dart';
import 'selection.dart';
import 'social_feed.dart';
import 'spike.dart';

/// Sliver 业务场景，两端共用相同目录与页面工厂。
final scrollBusinessExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    key: 'recycler-rectangles',
    title: '万条纯色矩形',
    icon: ElIcon(Icons.rectangle_outlined),
    data: (_) => ElSliverRecyclerExamplePage(),
  ),
  ElMenuModel(
    key: 'recycler-text',
    title: '万条纯文本列表',
    icon: ElIcon(Icons.text_fields),
    data: (_) => ElSliverRecyclerExamplePage(initialContent: .text),
  ),
  ElMenuModel(
    key: 'recycler-selection',
    title: '万条复选列表',
    icon: ElIcon(Icons.checklist_outlined),
    data: (_) => RecyclerSelectionPage(),
  ),
  ElMenuModel(
    key: 'recycler-chat',
    title: '聊天长列表',
    icon: ElIcon(Icons.chat_bubble_outline),
    data: (_) => RecyclerChatPage(),
  ),
  ElMenuModel(
    key: 'recycler-cards',
    title: '复杂卡片面板',
    icon: ElIcon(Icons.dashboard_outlined),
    data: (_) => RecyclerCardsPage(),
  ),
  ElMenuModel(
    key: 'recycler-takeaway',
    title: '外卖商家列表',
    icon: ElIcon(Icons.delivery_dining_outlined),
    data: (_) => TakeawaySliverPage(),
  ),
  ElMenuModel(
    key: 'recycler-video-grid',
    title: 'Grid 视频流卡片',
    icon: ElIcon(Icons.video_library_outlined),
    data: (_) => RecyclerVideoGridPage(),
  ),
  ElMenuModel(
    key: 'recycler-gallery-grid',
    title: 'Grid 本机相册',
    icon: ElIcon(Icons.photo_library_outlined),
    data: (_) => RecyclerGalleryPage(),
  ),
  ElMenuModel(
    key: 'recycler-waterfall',
    title: '瀑布流',
    icon: ElIcon(Icons.view_quilt_outlined),
    data: (_) => RecyclerWaterfallPage(),
  ),
  ElMenuModel(
    key: 'recycler-social-feed',
    title: '社交动态流',
    icon: ElIcon(Icons.dynamic_feed_outlined),
    data: (_) => RecyclerSocialFeedPage(),
  ),
  ElMenuModel(
    key: 'recycler-live-chat',
    title: '实时群聊',
    icon: ElIcon(Icons.forum_outlined),
    data: (_) => RecyclerLiveChatPage(),
  ),
  ElMenuModel(
    key: 'recycler-orders',
    title: '订单管理台',
    icon: ElIcon(Icons.receipt_long_outlined),
    data: (_) => RecyclerOrdersPage(),
  ),
  ElMenuModel(
    key: 'recycler-product-waterfall',
    title: '商品瀑布流',
    icon: ElIcon(Icons.storefront_outlined),
    data: (_) => RecyclerProductWaterfallPage(),
  ),
  ElMenuModel(
    key: 'recycler-rich-document',
    title: '富文本文档',
    icon: ElIcon(Icons.article_outlined),
    data: (_) => RecyclerRichDocumentPage(),
  ),
  ElMenuModel(key: 'nest-scroll', title: '嵌套滚动', icon: ElIcon(Icons.article_outlined), data: (_) => NestScrollPage()),
  ElMenuModel(
    key: 'recycler-spike',
    title: '单帧尖峰压力',
    icon: ElIcon(Icons.speed_outlined),
    data: (_) => RecyclerSpikePage(),
  ),
];
