# LoadingIndicator

`ElLoadingIndicator` 复用 Web Loading 的加载图形、可见说明与辅助名称。`size` 是数值逻辑尺寸，默认使用品牌尺寸；`child` 提供可见说明，省略时播报 `semanticLabel`。

`style` 在品牌根样式之后合并。移动端已通过内部 `loadingIndicatorBuilder` 接入现有圆弧皮肤，减少动画设置会关闭旋转。用户导入 `package:flutter_base/mobile.dart`，在 `ElMobileTheme` 内使用公共接口。

已有 `ElLoading` 是旋转任意 Widget 的工具，与加载指示组件职责独立。
