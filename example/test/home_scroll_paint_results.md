# 首页滚动绘制回归（2026-11-13）

首页外层直接使用 `ElScrollView(children: …)`，五个章节作为普通子项，章节内部使用 Column / Wrap。全部内容常驻并按自然尺寸布局，外层按章节裁剪；章节进入视口时允许绘制整章，不再维护卡片行级 Sliver。

章节、展示分组和卡片保留 RepaintBoundary，稳态滚动复用静态绘制结果；无限进度与播放示例仍按真实视口切换 TickerMode。Wrap 跨断点换行不改变子项在元素树中的父级和顺序，因此无需 GlobalKey 搬迁卡片。

首页内嵌外卖默认使用 `ElSliverList.recycler`，保留模式切换、分类、搜索、排序和购物车；数据为 1000 家。独立 Sliver 对照页的默认模式仍为官方 SliverList。

## 采样方法

- 运行 `home_scroll_paint_test.dart`，使用 Flutter 官方 `debugOnProfilePaint` 统计经过 `PaintingContext.paintChild` 的绘制调用。
- 视口为 390 × 900、像素比为 1，使用测试默认字体。
- 跳转到小节后记录进入帧，等待 500 ms，再连续滚动 6 帧，每帧前进 12 像素并推进 16 ms，表中记录单帧最大绘制次数。
- “屏外”指 RenderBox 的全局 paintBounds 完全不与正文视口相交。它是绘制工作量诊断，并非对所有屏外绘制都作无效判定。

| 小节 | 进入帧绘制次数 | 稳态滚动单帧最大绘制次数 | 稳态单帧最大屏外绘制次数 |
| --- | ---: | ---: | ---: |
| 输入与选项 | 2404 | 4 | 0 |
| 日期与时间 | 4 | 4 | 0 |
| 卡片与阴影 | 878 | 4 | 0 |
| 提示反馈 | 1285 | 4 | 0 |
| 进度与通知 | 4 | 75 | 56 |

日期与时间、进度与通知在采样时所属章节已经绘制过，所以进入帧也能复用缓存。新测试检查完全离屏的章节不进入绘制，并保留稳态绘制次数上限；首次进入整章的绘制次数只记录，不再套用原来的行级裁剪上限。

这些数字来自无头 Widget 测试，表示绘制遍历量，不代表设备帧耗时或 FPS。真实 Profile 模式下的流畅度、GPU 和内存变化尚未复测。

## 复现

在 `example/` 下运行：

```powershell
$env:HOME_PAINT_REPORT = 'build/home-scroll-paint.json'
& ..\.fvm\flutter_sdk\bin\flutter.bat test --no-pub --concurrency=1 --timeout=60s test/home_scroll_paint_test.dart test/home_showcase_test.dart test/home_keyboard_rebuild_test.dart
```

共 5 项测试通过，覆盖章节裁剪、稳态绘制上限、跨断点保留输入实例、同章节离屏停止动画、四种布局、章节定位、收藏、资料校验、外卖交互和键盘变化。键盘高度变化每次记录 133 次构建、0 次 ElView 布局、0 次屏外 ElView 布局。
