import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../custom_gestures.dart';
import '../view.dart';
import '../view/base.dart';
import 'press_feedback.dart';

/// 独立高级示例的统一目录，页面由 Navigator 推入，不登记深度路由。
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
