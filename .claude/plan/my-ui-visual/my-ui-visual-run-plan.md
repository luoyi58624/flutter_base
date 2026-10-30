# 首批8组件视觉验收执行范围

1. Web：只读启动 example（Vite8.3.4），真实 Vue 包组件；先采集 example 页面，再用相同插槽/状态的独立画布做直接对照。
2. Flutter：Flutter3.47.5 flutter_tester 无头真实栅格化，RepaintBoundary.toImage 输出；390/1440逻辑宽、DPR1、900高、明/暗主题。测试加载真实系统字体，避免 Ahem。
3. 基本矩阵：8×2×2×2=64张；另保留32张Web文档页面、状态补充图、样式/尺寸JSON和分析日志。
4. 不改实现、不改依赖、不运行Git。工具缓存与复现脚本集中在本目录run/，测试入口仅在test/my_ui/visual_render_test.dart。
5. 逐组件核对尺寸、圆角、颜色、字号/字体、间距、禁用/选中/加载状态，列需修项后给下一批准入结论。
