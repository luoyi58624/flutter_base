# Pagination

参照 `D:/project/my-project/el/ui/element_plus/lib/src/components/data/pagination` 的公共参数与模型。

当前仅定义接口：Widget 继承 StatelessWidget，build 只分派到 ElComponentProvider 对应 Builder；本次不新增品牌实现，渲染前须由后续品牌工作提供实现。

## 声明入口

| 类型 | 分派 |
| --- | --- |
| ElPagination | `paginationBuilder` |

## 参数

| 声明 | 参数 | 类型 | 用途 |
| --- | --- | --- | --- |
| ElPagination | value | `int?` | 普通值输入，具体同步由品牌实现处理。 |
| ElPagination | modelValue | `ValueNotifier<int>?` | 外部双向模型，生命周期由调用方管理。 |
| ElPagination | onChanged | `ValueChanged<int>?` | 模型变化通知。 |
| ElPagination | total | `int` | 数据总条数。 |
| ElPagination | pageSize | `int` | 每页数据条数。 |
| ElPagination | pageCount | `int?` | 显式总页数，优先于 total 与 pageSize 推导。 |
| ElPagination | pagerCount | `int` | 最多显示的页码数量，要求不小于五的奇数。 |
| ElPagination | background | `bool` | 为页码显示背景块。 |
| ElPagination | small | `bool` | 使用紧凑分页外观。 |
| ElPagination | disabled | `bool` | 禁止分页交互。 |
| ElPagination | hideOnSinglePage | `bool` | 只有一页时隐藏整个分页器。 |
| ElPagination | showTotal | `bool` | 显示数据总数说明。 |
| ElPagination | totalFormatter | `String Function(int total)?` | 自定义数据总数说明。 |
| ElPagination | style | `ElStyle?` | 组件根样式。 |
| ElPagination | itemStyle | `ElStyle?` | 单个页码的样式。 |
| ElPagination | semanticLabel | `String?` | 辅助技术读取的组件名称。 |

页模型使用 int，首项语义页码为一；small 是紧凑外观变体，不是全局品牌尺寸档。声明不生成页码或写回模型。

导入 `package:flutter_base/ui.dart` 或 `package:flutter_base/flutter_base.dart`。普通值、外部 notifier 与回调仅作为配置转交；外部 notifier、焦点节点和视口控制器的生命周期由调用方管理。
