# Progress

接口以 Web Progress 的共同职责为准：条形、圆环、完成量、缓冲量、总量、状态和读数，不保留仪表盘、另一套 percentage 输入或桌面专属色标配置。

```dart
ElProgress(value: 30, buffer: 60, max: 100);
ElProgress.circle(value: 80, status: ElProgressStatus.success);
```

- `value` 省略或非有限数值时进入不确定状态；合法值限制在 0 至 `max`，非法 `max` 回退为 100。
- `buffer` 与 `value` 使用相同单位，确定状态下限制在当前完成量与总量之间。
- `status` 为 normal / success / warning / error，`showText` 默认 true；`textBuilder` 接收归一化的 `ElProgressValue`，隐藏读数时仍保留其实例。
- `semanticLabel` 默认“进度”；`style` 覆盖根样式，数值圆环宽高参与内部图形与读数尺寸计算。

移动端已复用原进度皮肤。减少动画设置会停止不确定动画并直接更新完成量。用户通过 `ElComponentProvider` 安装 `el.mobileComponents`，具体绘制和 Builder 不公开导出。
