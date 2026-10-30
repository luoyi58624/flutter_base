# my-ui round 2 修复汇报

日期：2026-10-30。

结果：Loading / Progress 的glyph尺寸与居中缺陷已修复；Times New Roman字体契约已落地；**严格视觉验收仍有Card高度和Button基线残差，暂不放行下一批46组件。**

- MyGlyph增加目标size，保留默认24；Loading明确传16/24/32，Progress circle传size×0.28、line传18，更新尺寸触发真实布局。
- MyThemeData新增fontFamily（默认Times New Roman）、不可变fallback（Microsoft YaHei、SimSun）及copyWith；MyTheme同时设置Text / ElView，根行高使用字体normal，子级显式字体及组件行高优先。Windows同机Chrome实际使用Times New Roman + Microsoft YaHei；字体文件由宿主提供。
- 组件测试检查实际glyph尺寸、包装层和圆环中心，包含40/64/96/128及尺寸更新；主题测试覆盖默认字体、覆写、不可变回退列表和两条文字链的继承。

验证：

| 检查 | 结果 |
| --- | --- |
| flutter analyze lib/src/my_ui test/my_ui | 0 error / 0 warning / 0 info |
| flutter test test/my_ui | 62/62：原51 + 新增7 + 视觉4 |
| 新截图 | 190张PNG解码通过：基础72 + 状态48 + 对照60 + 总览8 + 前后证据2 |
| Loading实际glyph / 笔画 | 16/24/32；large笔画与Web同为28×28 |
| Progress circle ✓/✗ | 40/64/96/128分别11.2/17.92/26.88/35.84；实际glyph与圆环同心，line保持18 |
| 保护复核 | 471文件中仅允许的5个lib文件变化，其余一致 |

字体复验：390下Save 保存宽Web90.921875、Flutter90.907715；Cancel为69.656250、69.645508，均差小于0.015px。Skeleton loaded正文高已由22改为20，与Web20一致。

未达严格视觉一致的项：

1. Button最终基线：Save差−0.128418px；Cancel差+0.685303px，四个宽度/主题条件一致。
2. 默认Card高度：移动端Web174.78125、Flutter177；桌面Web183.140625、Flutter185。换字体后不能沿用首轮不足1px的结论，建议继续在首批范围定位标题/说明混排行盒与倍率行高。
3. 量化、抗锯齿、Divider栅格及首轮已记录的Switch UA外边距、Card阴影仍有差异；没有用像素平均分数宣称全面通过。

交付：

- [完整报告（追加第9节，原结论保留）](my-ui-visual-report.md)
- [最新离线图库](round2/index.html)
- [测量与残差](round2/measured-summary.json)
- [最终分析日志](run/round2-analyze-final-clean.log)
- [最终测试日志](run/round2-tests-verified.log)
- [重放脚本](run/round2-replay.ps1)

采用isolated SDK与PUB_CACHE=D:/data/pub-cache，未改依赖或全局SDK；只跑my_ui子集，未重跑全仓分析/测试。所有截图均为无头真实渲染、DPR1；没有执行git、commit、修改Web源或进入后续46组件。私有SDK/缓存保留在run目录供复现，专用Vite服务已关闭。

写入指定.codex/my-ui-fix-last.md被文件系统拒绝（EPERM）；本文件为同内容交付副本。
