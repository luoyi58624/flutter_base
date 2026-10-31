# Tabs

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/tabs` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElTabPane | 只保存配置的数据类 |
| ElTabs | `tabsBuilder` |
| ElTabItem | 只保存配置的数据类 |
| ElTabBar | `tabBarBuilder` |

辅助类型：`ElTabsType`、`ElTabsPosition`、`ElTabIndicatorBuilder`。

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElTabPane | label | `Object?` | 标签显示内容，接受文字或 Widget。 |
| ElTabPane | child | `Widget?` | 该页的正文内容。 |
| ElTabPane | name | `Object?` | 页身份值，省略时由品牌实现采用下标。 |
| ElTabPane | disabled | `bool` | 禁止用户选择该页。 |
| ElTabPane | closable | `bool` | 显示关闭操作，实际移除由调用方决定。 |
| ElTabs | value | `Object?` | 当前页身份值。 |
| ElTabs | modelValue | `ValueNotifier<Object?>?` | 外部页身份模型，生命周期由调用方管理。 |
| ElTabs | onChanged | `ValueChanged<Object?>?` | 当前页身份变化通知。 |
| ElTabs | panes | `List<ElTabPane>` | 标签页配置列表。 |
| ElTabs | type | `ElTabsType` | 标签页外观类型。 |
| ElTabs | tabPosition | `ElTabsPosition` | 标签栏相对内容的位置。 |
| ElTabs | stretch | `bool` | 将标签等分整条标签栏。 |
| ElTabs | addable | `bool` | 显示新增操作入口。 |
| ElTabs | onAdd | `VoidCallback?` | 新增操作通知。 |
| ElTabs | onRemove | `void Function(Object? name)?` | 请求移除指定身份的页，真正移除由调用方处理。 |
| ElTabs | style | `ElStyle?` | 标签页根样式。 |
| ElTabs | headerStyle | `ElStyle?` | 标签栏样式。 |
| ElTabs | semanticLabel | `String?` | 辅助技术读取的标签页名称。 |
| ElTabItem | label | `String?` | 标签文字。 |
| ElTabItem | icon | `Widget?` | 标签前置图标。 |
| ElTabItem | badge | `Widget?` | 标签徽标内容。 |
| ElTabItem | child | `Widget?` | 完整接管标签内容的自定义组件。 |
| ElTabItem | disabled | `bool` | 禁止选择该标签。 |
| ElTabItem | key | `Key?` | 标签内容的稳定身份。 |
| ElTabBar | tabs | `List<ElTabItem>` | 标签项列表。 |
| ElTabBar | controller | `ElTabController` | 与正文视口共享的现有通用控制器。 |
| ElTabBar | scrollable | `bool` | 允许标签栏横向滚动。 |
| ElTabBar | height | `double` | 标签栏的显式逻辑高度。 |
| ElTabBar | onTap | `ValueChanged<int>?` | 用户选择标签时的附加通知。 |
| ElTabBar | indicator | `ElTabIndicatorBuilder?` | 自定义活动指示器。 |
| ElTabBar | selectedTextStyle | `ElStyle?` | 选中标签的文字样式。 |
| ElTabBar | textStyle | `ElStyle?` | 未选中标签的文字样式。 |
| ElTabBar | selectedColor | `Color?` | 选中标签颜色，null 时由品牌决定。 |
| ElTabBar | color | `Color?` | 未选中标签颜色，null 时由品牌决定。 |
| ElTabBar | disabledColor | `Color?` | 禁用标签颜色，null 时由品牌决定。 |
| ElTabBar | indicatorColor | `Color?` | 默认指示器颜色，null 时由品牌决定。 |
| ElTabBar | indicatorWidth | `double` | 默认指示器的显式宽度。 |
| ElTabBar | indicatorHeight | `double` | 默认指示器的显式高度。 |

组合页使用 Object? 身份模型；ElTabBar 复用现有 ElTabController，不重复定义 ElTabView 或控制器。源硬编码默认配色改为可空覆盖值，由品牌决定默认外观。声明不监听控制器、测量标签或切换页面。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。
