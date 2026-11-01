# Skeleton

`ElSkeleton` 以 Web Skeleton 为基线，保留 `loading / rows / avatar / child / style / semanticLabel`。不增加独立骨架块、模板协议或额外动画开关。

`rows` 遵守 Web 的取整与限制规则：0 和 NaN 回退为 3，其余限制在 1 至 10 行；`avatar` 添加头像占位。加载说明默认“内容加载中”，动画遵循系统减少动画设置。

移动端已接入现有骨架皮肤。加载中保留正文实例与 State，同时移出正文的焦点、语义和动画；加载结束后恢复同一正文。`style` 合并到根外观，业务代码只使用公共接口。
