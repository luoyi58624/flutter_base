# Card

内部 cardBuilder 直接承接公共 ElCard，复用 ElCardView 的区域语义和既有 ActionView 的点击、键盘及后代控件隔离。

默认使用 cardColor 背景、26 圆角和既有内边距。可点击时按压使用 cardPressColor，并缩放至 .96，沿用 150ms 过渡；style 最后合并，用户可自行覆写按压颜色、缩放、内边距等字段。详细事件通过 event 传递。

shadowLevel 对应主题的 xs / sm / md / lg / xl 阴影，默认无阴影，style.boxShadow 优先。loading 保留正文实例，显示加载指示并暂停内容与整卡激活。标题、说明、编号等布局由 child 组合，组件没有独立的标题属性或局部样式变量。
