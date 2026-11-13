# Card

移动端 `ElCard` 复用 `ActionView` 的整卡点击和后代控件隔离。用户可通过焦点变体显式启用键盘交互。

默认使用 `cardColor` 背景、20 圆角和 16 内边距。可点击时同时过渡到 `cardPressColor` 和 `cardPressScale`（0.96），按下与回弹共用 `pressDuration`（100ms）和 `pressCurve`（`easeOut`）。`style` 最后合并，调用方可以覆盖按压颜色、缩放和内边距等字段。详细事件通过 `event` 传递。

shadowLevel 对应主题的 xs / sm / md / lg / xl 阴影，默认无阴影，style.boxShadow 优先。loading 保留正文实例，显示加载指示并暂停内容与整卡激活。标题、说明、编号等布局由 child 组合，组件没有独立的标题属性或局部样式变量。
