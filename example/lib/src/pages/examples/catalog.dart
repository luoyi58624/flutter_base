import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../custom_gestures.dart';
import '../view.dart';
import '../view/base.dart';
import 'press_feedback.dart';
import 'recycler_view/cards.dart';
import 'recycler_view/chat.dart';
import 'recycler_view/selection.dart';
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

/// RecyclerView 长列表示例，两端共用相同目录与页面工厂。
final recyclerExamples = <ElMenuModel<WidgetBuilder>>[
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
];
