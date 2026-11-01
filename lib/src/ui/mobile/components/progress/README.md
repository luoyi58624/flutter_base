# Progress

内部 `Progress` 保留原 Web 皮肤的条形 / 圆环、缓冲值、状态、读数和不确定进度。`progressBuilder` 使用同一绘制和动画机制承接公共 `ElProgress`，读数快照转换为 `ElProgressValue`。

完成量、总量与缓冲量在消费点统一归一化。根样式最后合并，数值圆环宽高同步参与图形与读数尺寸计算；减少动画设置停止不确定运动并直接更新进度。隐藏读数仍保留其 Widget 实例。

类型、局部变量键和 Builder 只供内部组合与回归，不从 mobile.dart 导出；业务代码使用 ElProgress / ElProgress.circle。
