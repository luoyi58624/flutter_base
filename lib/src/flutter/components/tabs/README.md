# Tabs

`ElTabs<T>` 以 Web Tabs 为基线，保留完整泛型值绑定、panes、disabled、swipeable、style 和 semanticLabel。`ElTabPane<T>` 使用明确的 value，保存标签、正文和单项禁用状态，不再包含关闭、新增页或左右侧栏外观协议。

模型由 ElModelValue 持有，品牌通过 currentValue 读写，不在接口层执行选项回退、键盘或滑动算法。非空 T 须提供初值或模型，业务值可用枚举、数字或值对象。

已有 ElTabController、ElTabView、ElTabBar、ElTabItem 和 ElTabIndicatorBuilder 继续承担 Flutter 的标签栏与正文组合。当前移动端尚未登记 Tabs / TabBar Builder，本目录只声明共同接口。
