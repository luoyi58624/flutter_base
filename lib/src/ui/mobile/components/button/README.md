# Button

用户通过 `ElButton` 调用移动端按钮。`ElButton.toggle` 的选中态由公共模型持有，切换时更新同一个模型。

`variant` 提供 `solid`、`outline`、`text` 和 `link`。常规按钮默认至少 40 高，圆角读取 `radiusMd`（6），实心与描边文字按钮最小宽度为 64。实心按钮的 `child` 为 `IconData` 时默认使用 40 × 40 图标盒。

按下缩放比例读取 `buttonPressScale`（0.9），按下与回弹共用 `pressDuration`（100ms）和 `pressCurve`（`easeOut`）。`style` 在默认样式之后合并，显式声明的按压变体和过渡可覆盖默认值。

`event.onTap` 先于默认动作，可通过 `preventDefault` 取消。`loading` 保留焦点并阻止激活。
