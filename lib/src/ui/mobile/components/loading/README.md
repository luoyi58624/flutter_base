# Loading

内部 `Loading` 保留 Web 的 16 / 24 / 32 三档圆弧，按钮和列表可直接复用。`loadingIndicator` 将公开 `ElLoadingIndicator` 的数值尺寸、根样式、辅助名称和可见说明交给同一皮肤。

图形尺寸同步作用于外框与实际 glyph；可见说明存在时由内容提供语义，不重复播报默认名称。旋转由 ElStyle 动画承担，减少动画设置会停转。具体类型与 Builder 不从 mobile.dart 导出。
