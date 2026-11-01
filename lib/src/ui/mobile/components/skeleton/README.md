# Skeleton

内部 `Skeleton` 保留原 Web 皮肤的标题、正文行、头像和加载说明，`skeletonBuilder` 直接承接公共 `ElSkeleton`。

加载期间用 Offstage / ExcludeFocus / TickerMode 保留正文实例，同时屏蔽焦点、语义和动画；加载结束后恢复原正文。默认脉冲遵循系统减少动画设置，根样式最后合并。具体类型与 Builder 不从 mobile.dart 导出。
