import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import 'collapse_pages.dart';
import 'content_pages.dart';
import 'large_title_pages.dart';
import 'layout_pages.dart';
import 'translucent_pages.dart';

/// 对照旧 element_docs/navigation_effects 的 15 个独立入口，保留原名称及功能区别。
final navigationEffectExamples = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    key: 'effect-bottom-navigation',
    title: '底部导航 · 三页位置保留',
    icon: ElIcon(Icons.navigation_outlined),
    data: (_) => BottomNavigationEffectPage(),
  ),
  ElMenuModel(
    key: 'effect-workspace',
    title: '工作空间 · 侧栏 / 抽屉',
    icon: ElIcon(Icons.menu_open),
    data: (_) => DrawerEffectPage(),
  ),
  ElMenuModel(
    key: 'effect-inbox',
    title: '收件箱 · 固定导航',
    icon: ElIcon(Icons.mail_outline),
    data: (_) => FixedEffectPage(),
  ),
  ElMenuModel(
    key: 'effect-contacts',
    title: '通讯录 · 分组吸顶',
    icon: ElIcon(Icons.contacts_outlined),
    data: (_) => StickyEffectPage(),
  ),
  ElMenuModel(
    key: 'effect-reading',
    title: '慢读 · 方向 / 跟手折叠',
    icon: ElIcon(Icons.auto_stories_outlined),
    data: (_) => HideEffectPage(),
  ),
  ElMenuModel(
    key: 'effect-reading-velocity',
    title: '慢读 · 速度显隐',
    icon: ElIcon(Icons.speed),
    data: (_) => HideEffectPage(collapseVelocity: 800, expandVelocity: 600),
  ),
  ElMenuModel(
    key: 'effect-reading-offset',
    title: '慢读 · 位置折叠',
    icon: ElIcon(Icons.swipe_vertical_outlined),
    data: (_) => HideEffectPage(collapseOffset: 100),
  ),
  ElMenuModel(
    key: 'effect-playlist',
    title: '午后慢调 · 封面标题交接',
    icon: ElIcon(Icons.album_outlined),
    data: (_) => FoldEffectPage(),
  ),
  ElMenuModel(
    key: 'effect-favorites',
    title: '收藏 · LargeTitle 缩小',
    icon: ElIcon(Icons.bookmark_outline),
    data: (_) => LargeTitleEffectPage(kind: LargeTitleEffectKind.scale),
  ),
  ElMenuModel(
    key: 'effect-reminders',
    title: '提醒事项 · LargeTitle 淡入淡出',
    icon: ElIcon(Icons.check_circle_outline),
    data: (_) => LargeTitleEffectPage(kind: LargeTitleEffectKind.fade),
  ),
  ElMenuModel(
    key: 'effect-library',
    title: '书库 · LargeTitle + 搜索',
    icon: ElIcon(Icons.search),
    data: (_) => LargeTitleEffectPage(kind: LargeTitleEffectKind.search),
  ),
  ElMenuModel(
    key: 'effect-landscape',
    title: '山海之间 · 渐显导航',
    icon: ElIcon(Icons.landscape_outlined),
    data: (_) => TranslucentEffectPage(officialSliver: false),
  ),
  ElMenuModel(
    key: 'effect-landscape-sliver',
    title: '山海之间 · 官方 Sliver / 毛玻璃',
    icon: ElIcon(Icons.blur_on),
    data: (_) => TranslucentEffectPage(officialSliver: true),
  ),
  ElMenuModel(
    key: 'effect-parallax',
    title: '原野 · 卡片渐显 / 视差',
    icon: ElIcon(Icons.photo_library_outlined),
    data: (_) => RevealParallaxEffectPage(),
  ),
  ElMenuModel(
    key: 'effect-progress',
    title: '把周末还给自己 · 阅读进度',
    icon: ElIcon(Icons.format_align_left),
    data: (_) => ReadingProgressEffectPage(),
  ),
];
