# Calendar

`ElCalendar<D>` 保留 Web Calendar 的单日和范围职责：普通构造使用 `DateTime?`，range 构造使用完整 `List<DateTime>`，值通道由 ElModelValue 持有。范围依次允许空列表、一个起点、完整的两个端点，不在接口层排序、补全或截断日期。

共同配置为 month、min、max、disabledDate、firstDayOfWeek、disabled、style、semanticLabel。日期使用 Flutter DateTime；firstDayOfWeek 使用 DateTime.monday 至 DateTime.sunday，默认周一。min/max 包含当天，范围不得跨过 disabledDate 返回 true 的日期。

onChanged 是模型变化，onSelect 由品牌在完成单日选择或两个范围端点后发出，onMonthChanged 由用户月份导航发出；接口不会把每次值写入都当成选择完成。

移除桌面专属格子模板、标题格式和独立日期归属枚举。两端暂用官方日历与范围选择对话框承接，首日取官方本地化设置；完整品牌能力仍待实现，见 [Material 替代](../../../ui/material/README.md)。
