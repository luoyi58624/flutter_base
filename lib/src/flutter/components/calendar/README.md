# Calendar

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/form/calendar` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElCalendar | `calendarBuilder` |

辅助类型：`ElCalendarDayType`。

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElCalendar | value | `DateTime?` | 普通值输入，具体同步由品牌实现处理。 |
| ElCalendar | modelValue | `ValueNotifier<DateTime?>?` | 外部双向模型，生命周期由调用方管理。 |
| ElCalendar | onChanged | `ValueChanged<DateTime?>?` | 模型变化通知。 |
| ElCalendar | displayMonth | `DateTime?` | 当前展示月份，只使用年月部分。 |
| ElCalendar | onMonthChanged | `ValueChanged<DateTime>?` | 展示月份变化通知。 |
| ElCalendar | firstDayOfWeek | `int` | 每周首日，取 DateTime.monday 至 DateTime.sunday。 |
| ElCalendar | weekdayLabels | `List<String>` | 从周日开始排列的七个星期标题。 |
| ElCalendar | headerFormatter | `String Function(DateTime month)?` | 月份标题格式化函数。 |
| ElCalendar | dayBuilder | `Widget Function(
    BuildContext context,
    DateTime date,
    ElCalendarDayType type,
  )?
 ` | 自定义日期格子的内容。 |
| ElCalendar | showHeader | `bool` | 显示月份导航与标题。 |
| ElCalendar | style | `ElStyle?` | 组件根样式。 |
| ElCalendar | cellStyle | `ElStyle?` | 日期格子的样式。 |
| ElCalendar | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

选中日期使用 DateTime?，展示月份独立配置；声明不生成日期矩阵或访问表单。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。
