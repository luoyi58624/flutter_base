import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:go_router/go_router.dart';

import '../../utils/router.dart';
import '../../layout/example_page.dart';
import 'advanced/infinite_scroll/index.dart';
import 'basic/button/index.dart';
import 'basic/button_group/index.dart';
import 'basic/icon/index.dart';
import 'basic/text/index.dart';
import 'basic/tag/index.dart';
import 'form/input/index.dart';
import 'form/input_number/index.dart';
import 'form/input_otp/index.dart';
import 'form/input_tag/index.dart';
import 'form/autocomplete/index.dart';
import 'form/mention/index.dart';
import 'form/select/index.dart';
import 'form/switch/index.dart';
import 'form/radio/index.dart';
import 'form/checkbox/index.dart';
import 'form/segmented/index.dart';
import 'form/slider/index.dart';
import 'form/calendar/index.dart';
import 'form/form/index.dart';
import 'layout/card/index.dart';
import 'layout/divider/index.dart';
import 'layout/collapse/index.dart';
import 'layout/tabs/index.dart';
import 'list/list_group/index.dart';
import 'data/avatar/index.dart';
import 'data/badge/index.dart';
import 'data/progress/index.dart';
import 'data/skeleton/index.dart';
import 'data/steps/index.dart';
import 'event/basic/index.dart';
import 'event/advanced/index.dart';
import 'event/drag/index.dart';
import 'event/propagation/index.dart';
import 'feedback/alert/index.dart';
import 'feedback/loading/index.dart';
import 'feedback/toast/index.dart';
import 'feedback/message/index.dart';
import 'feedback/dialog/index.dart';
import 'feedback/popover/index.dart';
import 'feedback/popup_menu/index.dart';
import 'feedback/tooltip/index.dart';
import 'feedback/drawer/index.dart';
import 'list/list_tile/index.dart';
import 'start/quick_start/index.dart';
import 'start/shadow/index.dart';
import 'desktop/anchor/index.dart';
import 'desktop/nav_menu/index.dart';
import 'mobile/bottom_tabbar/index.dart';
import 'view/selection/index.dart';
import 'view/page_view/index.dart';

/// 移动导航下的组件目录，共用组件与移动专属分组按顺序展示。
class ComponentPage extends StatelessWidget {
  /// 创建组件目录页。
  const ComponentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: '组件',
      child: ElScrollView(
        key: PageStorageKey('component-catalog'),
        padding: .fromLTRB(16, 8, 16, 24),
        children: [
          Column(
            spacing: 16,
            children: [
              for (final group in componentCatalogFor(mobile: true))
                ElListGroup(
                  title: group.title,
                  children: [
                    for (final item in group.children)
                      ElListTile(
                        key: ValueKey('component-${item.key}'),
                        title: item.title,
                        onTap: () => context.go('${RouterUtil.component}/${item.key}'),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 两端共用的组件目录，每个叶子都提供实际演示或空白示例页。
final componentCatalog = <ElMenuModel<WidgetBuilder>>[
  ElMenuModel(
    group: true,
    title: '开始使用',
    children: [
      _page('quick-start', '快速开始', builder: (_) => QuickStartPage()),
      _page('theme-design', '主题设计'),
      _page('shadow-design', '阴影设计', builder: (_) => ShadowPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '基础组件',
    children: [
      _page('button', 'Button 按钮', builder: (_) => ButtonPage()),
      _page('button-group', 'ButtonGroup 按钮组', builder: (_) => ButtonGroupPage()),
      _page('icon', 'Icon 图标', builder: (_) => IconPage()),
      _page('text', 'Text 文本', builder: (_) => TextPage()),
      _page('tag', 'Tag 标签', builder: (_) => TagPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '表单组件',
    children: [
      _page('input', 'Input 输入框', builder: (_) => InputPage()),
      _page('input-number', 'InputNumber 数字输入框', builder: (_) => InputNumberPage()),
      _page('input-otp', 'InputOtp 验证码输入', builder: (_) => InputOtpPage()),
      _page('input-tag', 'InputTag 标签输入', builder: (_) => InputTagPage()),
      _page('autocomplete', 'Autocomplete 自动补全', builder: (_) => AutocompletePage()),
      _page('mention', 'Mention 提及', builder: (_) => MentionPage()),
      _page('select', 'Select 选择器', builder: (_) => SelectPage()),
      _page('switch', 'Switch 开关', builder: (_) => SwitchPage()),
      _page('radio', 'Radio 单选框', builder: (_) => RadioPage()),
      _page('checkbox', 'Checkbox 多选框', builder: (_) => CheckboxPage()),
      _page('segmented', 'Segmented 分段选择', builder: (_) => SegmentedPage()),
      _page('slider', 'Slider 滑块', builder: (_) => SliderPage()),
      _page('calendar', 'Calendar 日历', builder: (_) => CalendarPage()),
      _page('form', 'Form 表单', builder: (_) => FormPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '布局与容器',
    children: [
      _page('card', 'Card 卡片', builder: (_) => CardPage()),
      _page('divider', 'Divider 分割线', builder: (_) => DividerPage()),
      _page('collapse', 'Collapse 折叠面板', builder: (_) => CollapsePage()),
      _page('tabs', 'Tabs 标签页', builder: (_) => TabsPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '列表组件',
    children: [
      _page('list-tile', 'ListTile 列表行', builder: (_) => ListTilePage()),
      _page('list-group', 'ListTileGroup 列表组', builder: (_) => ListGroupPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '数据展示',
    children: [
      _page('avatar', 'Avatar 头像', builder: (_) => AvatarPage()),
      _page('badge', 'Badge 徽标', builder: (_) => BadgePage()),
      _page('progress', 'Progress 进度', builder: (_) => ProgressPage()),
      _page('skeleton', 'Skeleton 骨架屏', builder: (_) => SkeletonPage()),
      _page('empty', 'Empty 空态'),
      _page('steps', 'Steps 步骤条', builder: (_) => StepsPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: '反馈组件',
    children: [
      _page('alert', 'Alert 提示', builder: (_) => AlertPage()),
      _page('loading', 'LoadingIndicator 加载指示', builder: (_) => LoadingPage()),
      _page('toast', 'Toast 轻提示', builder: (_) => ToastPage()),
      _page('message', 'Message 消息', builder: (_) => MessagePage()),
      _page('dialog', 'Dialog 对话框', builder: (_) => DialogPage()),
      _page('drawer', 'Drawer 抽屉', builder: (_) => DrawerPage()),
      _page('tooltip', 'Tooltip 文字提示', builder: (_) => TooltipPage()),
      _page('popover', 'Popover 弹出框', builder: (_) => PopoverPage()),
      _page('popup-menu', 'PopupMenu 弹出菜单', builder: (_) => PopupMenuPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: 'Advanced 高级组件',
    children: [_page('infinite-scroll', 'InfiniteScroll 无限滚动', builder: (_) => InfiniteScrollPage())],
  ),
  ElMenuModel(
    group: true,
    title: 'View 视图',
    children: [
      _page('view-selection', '文本选择', builder: (_) => ElSelectionPage()),
      _page('view-page-view', 'PageView 分页视图', builder: (_) => PageViewPage()),
    ],
  ),
  ElMenuModel(
    group: true,
    title: 'Event 事件',
    children: [
      _page('event-basic', '基础使用', builder: (_) => ElEventBasicPage()),
      _page('event-propagation', '阻止冒泡', builder: (_) => ElEventPropagationPage()),
      _page('event-drag', '拖拽交互', builder: (_) => ElEventDragPage()),
      _page('event-advanced', '高级示例', builder: (_) => ElEventAdvancedPage()),
    ],
  ),
];

/// 追加在桌面组件目录末尾的专属分组。
final desktopComponentGroup = ElMenuModel<WidgetBuilder>(
  group: true,
  title: 'Desktop 组件',
  children: [
    _page('anchor', 'Anchor 锚点', builder: (_) => AnchorPage()),
    _page('nav-menu', 'NavMenu 导航菜单', builder: (_) => NavMenuPage()),
  ],
);

/// 追加在移动组件目录末尾的专属分组。
final mobileComponentGroup = ElMenuModel<WidgetBuilder>(
  group: true,
  title: 'Mobile 组件',
  children: [_page('bottom-tabbar', 'BottomTabbar 底部导航栏', builder: (_) => BottomTabbarPage())],
);

/// 保持共用分组的顺序，并在末尾追加当前端的分组。
List<ElMenuModel<WidgetBuilder>> componentCatalogFor({required bool mobile}) => [
  ...componentCatalog,
  mobile ? mobileComponentGroup : desktopComponentGroup,
];

ElMenuModel<WidgetBuilder> _page(String key, String title, {WidgetBuilder? builder}) => ElMenuModel(
  key: key,
  title: title,
  data: builder ?? (_) => ExamplePage(title: title),
);
