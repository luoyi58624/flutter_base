# PageView

`ElPageView` 与 `ElPageView.builder` 直接继承官方 `PageView`，控制器使用 `PageController`，手势、分页吸附、构建和状态保留沿用 Flutter。

同轴 `ElScroll` 起手时已经贴边、拖动方向继续向外时，把官方 `Drag` 交给最近的可滚动分页祖先。接管之后直到松手都由分页响应，反向拖动也先回拖页面；松手或取消由官方分页物理收尾。该能力也适用于直接使用官方 `PageView` 的场景。

起手时内层还有行程，即使同一次拖动撞到边界，余量和后续输入也不交给分页；反拖仍滚内层，释放惯性也留在内层。必须松手后重新向边界外起手，才可以选择分页。普通嵌套和分页嵌套遵守同一规则。

示例入口：组件 → View 视图 → PageView 分页视图（`/components/view-page-view`）。
