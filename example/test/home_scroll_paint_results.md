# 首页滚动绘制回归（2026-11-12）

旧首页把五个大章节作为 ElScroll 的直接子项，裁剪只能跳过整个章节；章节进入视口后，内部 Column / Wrap 会遍历并绘制大量屏外内容。

现在使用 ElScroll.sliver 和已有 ElSliverList 按卡片行排版，行级 RepaintBoundary 复用静态内容；无限进度与播放示例按真实视口切换 TickerMode。所有卡片仍保持挂载，章节定位、表单状态和跨断点卡片实例得以保留。

## 采样方法

- 运行 `home_scroll_paint_test.dart`，使用 Flutter 官方 `debugOnProfilePaint` 统计经过 `PaintingContext.paintChild` 的绘制调用。
- 视口为 390 × 900、像素比为 1，使用测试默认字体；基线与修改后使用相同场景和采样顺序。
- 跳转到小节后记录进入帧，等待 500 ms，再连续滚动 6 帧，每帧前进 12 像素并推进 16 ms，表中记录单帧最大绘制次数。
- “屏外”指 RenderBox 的全局 paintBounds 完全不与正文视口相交。它是绘制工作量诊断，并非对所有屏外绘制都作无效判定。

| 小节 | 进入帧：修改前 → 后 | 滚动帧：修改前 → 后 | 屏外绘制：修改前 → 后 |
| --- | ---: | ---: | ---: |
| 输入与选项 | 2350 → 351 | 1794 → 11 | 1677 → 0 |
| 日期与时间 | 1794 → 222 | 1794 → 9 | 1659 → 0 |
| 卡片与阴影 | 1065 → 166 | 572 → 30 | 484 → 10 |
| 提示反馈 | 1241 → 145 | 1173 → 10 | 1077 → 0 |
| 进度与通知 | 1173 → 266 | 1173 → 117 | 1001 → 94 |

这些数字来自无头 Widget 测试，表示绘制遍历量，不代表设备帧耗时或 FPS。真实 Profile 模式下的流畅度、GPU 和内存变化尚未复测。

## 复现

在 `example/` 下运行：

```powershell
$env:HOME_PAINT_REPORT = 'build/home-scroll-paint.json'
flutter test --no-pub --concurrency=1 --timeout=60s test/home_scroll_paint_test.dart test/home_showcase_test.dart
```

共 4 项测试通过，覆盖绘制数量上限、跨断点保留输入实例、同章节离屏停止动画、四种布局、章节定位、收藏、资料校验和外卖交互。跨断点测试同时发现并修复了导航头留白过渡造成的瞬间溢出。
