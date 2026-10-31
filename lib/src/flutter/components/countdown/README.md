# Countdown

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/countdown` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElCountdown | `countdownBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElCountdown | value | `DateTime` | 倒计时的目标时刻。 |
| ElCountdown | title | `Object?` | 倒计时标题。 |
| ElCountdown | format | `String` | 显示格式，支持 DD、HH、mm、ss、SSS 占位。 |
| ElCountdown | prefix | `Object?` | 读数前置内容。 |
| ElCountdown | suffix | `Object?` | 读数后置内容。 |
| ElCountdown | interval | `Duration` | 剩余时长刷新间隔。 |
| ElCountdown | onFinish | `VoidCallback?` | 到达目标时刻后的通知。 |
| ElCountdown | onChange | `ValueChanged<Duration>?` | 剩余时长更新通知。 |
| ElCountdown | style | `ElStyle?` | 组件根样式。 |
| ElCountdown | titleStyle | `ElStyle?` | 标题样式。 |
| ElCountdown | valueStyle | `ElStyle?` | 倒计时读数样式。 |
| ElCountdown | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

仅保留目标时刻和格式配置；不读取时钟、不启动计时器，不迁入源 debugNow 与 formatDuration 运行算法。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。
