# 新版导航特效 · 旧示例迁移

旧仓库：`D:\project\my-project\el\examples\element_docs\lib\src\pages\advance\navigation_effects\pages`

新入口：示例 → **导航特效 · 旧版 15 个示例迁移**；独立 Bibi 新版对照入口在「新版滚动」。

本目录不是新增第三种导航组件。通用导航只使用 `ElSliverLargeTitle`、`ElSliverCollapse`；固定、吸顶、渐显、阅读进度和视差等效果基于官方 Sliver / ScrollPosition / Widget 组合。

| 旧入口 | 新 ID | 核心验收 |
| --- | --- | --- |
| 底部导航 | effect-bottom-navigation | 三个 Tab 独立滚动位置，切换保留 |
| 工作空间 | effect-workspace | 宽屏侧栏、移动抽屉、四项布局开关与选择态 |
| 收件箱 | effect-inbox | 固定导航与正文独立滚动、刷新 |
| 通讯录 | effect-contacts | 分组 Header 依次吸顶，字母索引点击/拖动定位 |
| 慢读 | effect-reading | 方向显隐与跟手折叠可切换 |
| 慢读 · 速度显隐 | effect-reading-velocity | 双向速度阈值，低速不切换 |
| 慢读 · 位置折叠 | effect-reading-offset | 100px 阈值，位置跟手可切换 |
| 午后慢调 | effect-playlist | 封面正常离场，导航标题从透明变为实色 |
| 收藏 | effect-favorites | LargeTitle 连续缩小进入紧凑导航 |
| 提醒事项 | effect-reminders | LargeTitle 大小标题交叉淡入淡出 |
| 书库 | effect-library | LargeTitle 搜索槽提前淡出，真实搜索/收藏状态 |
| 山海之间 | effect-landscape | 独立透明导航，24～184px 渐显，无模糊 |
| 山海之间 · 官方 Sliver | effect-landscape-sliver | 官方 pinned PersistentHeader、封面衔接、毛玻璃开关 |
| 原野 | effect-parallax | 24 张卡片渐显、固定画框内视差 |
| 把周末，还给自己 | effect-progress | 顶部细线读取正文滚动进度 |

两版「山海之间」复用相同 13 幅离线风景画与正文；与旧版一致使用 24px 起始 / 160px 渐显距离。联系人保留旧分组生成规则和索引。

**Bibi 新版真实业务对照**：`NewBibiCollapsePage` 使用已有视频轮播、双列视频流和底栏，导航用 `ElSliverCollapse.bibi`，刷新用 `ElSliverRefresh`。旧 `SliverBibiPage` 不删除，可以直接比较手感。

验收：

```shell
cd example
flutter test --no-pub --concurrency=1 test/navigation_effects_migration_test.dart test/new_scroll_examples_test.dart
dart analyze lib/src/pages/examples/navigation_effects lib/src/pages/examples/new_bibi_collapse.dart

cd ..
flutter test --no-pub --concurrency=1 test/flutter/slivers/navigation_effects_test.dart
```

注意：这轮保持旧示例的交互语义、核心文案、页面结构与艺术素材，控件本身使用当前 Flutter / flutter_base API 重建，并非将旧版 ElementPlus 控件的全部像素样式照搬。真机上的 GPU 模糊成本、触控板手感和不同屏幕密度的视觉对比，需要在现有示例中人工审核；无头测试不能代替这些检查。
