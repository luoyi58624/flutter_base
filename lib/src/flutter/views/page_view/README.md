# PageView

`ElPageView` 与 `ElPageView.builder` 直接继承官方 `PageView`，控制器使用 `PageController`，手势、分页吸附、构建和状态保留沿用 Flutter。

同轴 `ElScroll` 在拖动途中到达边缘时，先消费本层剩余行程，再把余量交给最近的可滚动分页祖先的官方 `Drag`。接管之后直到松手都由分页响应，反向拖动也先回拖页面；松手或取消由官方分页物理收尾。该能力也适用于直接使用官方 `PageView` 的场景。

普通 `ElScroll` 相互嵌套仍维持起拖时选择接收层的规则。分页禁用用户滚动、位于不可继续翻页的边缘，或轴向不同时，不进行途中交接。

示例入口：组件 → View 视图 → PageView 分页视图（`/components/view-page-view`）。
