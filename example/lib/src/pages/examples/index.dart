import 'package:example/src/pages/examples/scroll_examples/nest_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../custom_gestures.dart';
import '../view.dart';
import '../view/base.dart';
import 'bibi/bibi.dart';
import 'press_feedback.dart';
import 'new_scroll_nested.dart';
import 'new_scroll_refresh.dart';
import 'new_scroll_navigation.dart';
import 'new_bibi_collapse.dart';
export 'navigation_effects/routes.dart' show navigationEffectExamples;
import 'scroll_examples/cards.dart';
import 'scroll_examples/chat.dart';
import 'scroll_examples/media.dart';
import 'scroll_examples/orders.dart';
import 'scroll_examples/product_waterfall.dart';
import 'scroll_examples/rich_document.dart';
import 'scroll_examples/selection.dart';
import 'scroll_examples/social_feed.dart';
import 'scroll_examples/spike.dart';
import 'sliver_bibi/sliver_bibi.dart';
import 'sliver_list.dart';
import 'sliver_recycler.dart';
import 'sliver_recycler_grid.dart';
import 'sliver_takeaway/takeaway.dart';

/// 独立高级示例的统一目录，同时供目录点击与深度路由读取页面工厂。
final advancedExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(key: 'bibi-home', title: 'Bibi 首页', icon: ElIcon(Icons.video_library_outlined), data: (_) => BibiPage()),
  ElMenuModel(
    key: 'sliver-bibi',
    title: 'Bibi Sliver 对照',
    icon: ElIcon(Icons.view_day_outlined),
    data: (_) => SliverBibiPage(),
  ),
  ElMenuModel(
    key: 'bibi-plain',
    title: 'Bibi 非虚拟',
    icon: ElIcon(Icons.view_stream_outlined),
    data: (_) => BibiPlainPage(),
  ),
  ElMenuModel(
    key: 'sliver-recycler',
    title: 'SliverRecycler 性能对照',
    icon: ElIcon(Icons.view_list_outlined),
    data: (_) => ElSliverRecyclerExamplePage(),
  ),
  ElMenuModel(
    key: 'sliver-recycler-grid',
    title: 'Sliver 网格示例',
    icon: ElIcon(Icons.grid_view_outlined),
    data: (_) => ElSliverRecyclerGridExamplePage(),
  ),
  ElMenuModel(
    key: 'sliver-recycler-masonry',
    title: 'Sliver 瀑布流示例',
    icon: ElIcon(Icons.view_quilt_outlined),
    data: (_) => ElSliverRecyclerGridExamplePage.masonry(),
  ),
  ElMenuModel(
    key: 'sliver-list',
    title: '文档滚动（全量常驻）',
    icon: ElIcon(Icons.description_outlined),
    data: (_) => ElSliverListExamplePage(),
  ),
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

/// 新版滚动示例，两端共用相同分组和页面工厂。
final sliverScrollExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    key: 'new-bibi-collapse',
    title: 'Bibi · 新版折叠导航与真实视频流',
    icon: ElIcon(Icons.video_library_outlined),
    data: (_) => NewBibiCollapsePage(),
  ),
  ElMenuModel(
    key: 'new-scroll-navigation',
    title: '导航特效（LargeTitle / Collapse）',
    icon: ElIcon(Icons.auto_awesome_outlined),
    data: (_) => NewScrollNavigationPage(),
  ),
  ElMenuModel(
    key: 'new-scroll-nested',
    title: '嵌套滚动与 shrinkWrap',
    icon: ElIcon(Icons.swap_vert_outlined),
    data: (_) => NewScrollNestedPage(),
  ),
  ElMenuModel(
    key: 'new-scroll-refresh',
    title: '下拉刷新（Widget / Sliver）',
    icon: ElIcon(Icons.refresh_outlined),
    data: (_) => NewScrollRefreshPage(),
  ),
  ElMenuModel(
    key: 'sliver-takeaway',
    title: '外卖商家列表',
    icon: ElIcon(Icons.delivery_dining_outlined),
    data: (_) => TakeawaySliverPage(),
  ),
];

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
