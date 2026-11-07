import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../custom_gestures.dart';
import '../view.dart';
import '../view/base.dart';
import 'imperative_view/rectangles.dart';
import 'press_feedback.dart';
import 'recycler_view/cards.dart';
import 'recycler_view/chat.dart';
import 'recycler_view/media.dart';
import 'recycler_view/orders.dart';
import 'recycler_view/product_waterfall.dart';
import 'recycler_view/rectangles.dart';
import 'recycler_view/rich_document.dart';
import 'recycler_view/selection.dart';
import 'recycler_view/social_feed.dart';
import 'recycler_view/spike.dart';
import 'recycler_view/takeaway.dart';
import 'recycler_view/text.dart';

/// 独立高级示例的统一目录，同时供目录点击与深度路由读取页面工厂。
final advancedExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(key: 'view', title: 'ElView 测试', icon: ElIcon(Icons.web_outlined), data: (_) => ElViewPage()),
  ElMenuModel(
    key: 'gestures',
    title: '自定义手势',
    icon: ElIcon(Icons.touch_app_outlined),
    data: (_) => CustomGesturesPage(),
  ),
  ElMenuModel(key: 'base', title: 'ElView 基础使用', icon: ElIcon(Icons.layers_outlined), data: (_) => ViewBasePage()),
  ElMenuModel(
    key: 'press-feedback',
    title: '按压反馈',
    icon: ElIcon(Icons.ads_click_outlined),
    data: (_) => PressFeedbackPage(),
  ),
];

/// 命令式 View 示例，两端共用相同分组和页面工厂。
final imperativeExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    key: 'imperative-rectangles',
    title: '颜色矩形',
    icon: ElIcon(Icons.rectangle_outlined),
    data: (_) => ImperativeRectanglesPage(),
  ),
];

/// RecyclerView 长列表示例，两端共用相同目录与页面工厂。
final recyclerExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    key: 'recycler-rectangles',
    title: '万条纯色矩形',
    icon: ElIcon(Icons.rectangle_outlined),
    data: (_) => ElRecyclerRectanglesPage(),
  ),
  ElMenuModel(key: 'recycler-text', title: '万条纯文本列表', icon: ElIcon(Icons.text_fields), data: (_) => RecyclerTextPage()),
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
    data: (_) => RecyclerTakeawayPage(),
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
  ElMenuModel(
    key: 'recycler-spike',
    title: '单帧尖峰压力',
    icon: ElIcon(Icons.speed_outlined),
    data: (_) => RecyclerSpikePage(),
  ),
];
