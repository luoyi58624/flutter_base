# Collapse

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/collapse` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElCollapse | `collapseBuilder` |
| ElCollapseItem | `collapseItemBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElCollapse | value | `List<Object?>?` | 普通值输入，具体同步由品牌实现处理。 |
| ElCollapse | modelValue | `ValueNotifier<List<Object?>>?` | 外部双向模型，生命周期由调用方管理。 |
| ElCollapse | onChanged | `ValueChanged<List<Object?>>?` | 模型变化通知。 |
| ElCollapse | children | `List<Widget>` | 折叠面板成员列表。 |
| ElCollapse | accordion | `bool` | 手风琴模式下同时只展开一个成员。 |
| ElCollapse | style | `ElStyle?` | 组件根样式。 |
| ElCollapse | semanticLabel | `String?` | 辅助技术读取的组件名称。 |
| ElCollapseItem | name | `Object?` | 成员身份值，省略时由组使用下标。 |
| ElCollapseItem | title | `Object?` | 面板标题内容。 |
| ElCollapseItem | child | `Object?` | 面板正文内容。 |
| ElCollapseItem | disabled | `bool` | 禁止用户切换展开状态。 |
| ElCollapseItem | style | `ElStyle?` | 组件根样式。 |
| ElCollapseItem | headerStyle | `ElStyle?` | 标题区域的样式。 |
| ElCollapseItem | contentStyle | `ElStyle?` | 展开正文区域的样式。 |
| ElCollapseItem | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

组模型为 List<Object?> 展开身份集合；声明不维护成员上下文、展开集合或高度动画。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。
