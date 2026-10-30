# Scroll 测试分类

按功能维护以下测试文件，具体场景用文件内的 `group` 组织。新增回归用例归入对应功能，不再按单个 bug、开发阶段或设备组合新建零散文件；无需为了控制行数拆文件。

| 文件 | 覆盖范围 |
| --- | --- |
| `core_test.dart` | 基础行为、环境配置（ScrollConfiguration 通道）、作用域、Mixin 登记、快照与会话生命周期 |
| `controller_test.dart` | 索引定位、取消与运动所有权、末端跟随 |
| `layout_test.dart` | 尺寸约束、shrinkWrap、对齐、间距、尺寸变化与布局失效 |
| `render_test.dart` | 重绘边界、定位与层序、溢出命中、视口隔离、亚像素位移 |
| `input_test.dart` | 鼠标、触摸、触控板、键盘焦点、拖动代理、默认动作取消 |
| `nested_test.dart` | 输入路线与成员、消费顺序、同轴交接、交叉轴隔离、协同惯性 |
| `physics_test.dart` | 物理模拟、平滑滚动、速度、越界回弹、按住停止与拉伸 |
| `virtual_test.dart` | 列表与网格构建、窗口、尺寸索引、布局段、可见范围与成员生命周期 |
| `scrollbar_test.dart` | 平台滚动条、拖柄、短视口、投影及 Windows inset 首帧占位 |
| `refresh_test.dart` | 下拉刷新、输入协同、停靠、回落、弹簧限制与层序 |
| `effects_test.dart` | 成员效果、折叠与收尾、大标题导航、底部搜索槽及预设组合 |
| `selection_test.dart` | 滚动与文本选区交互、选区保活、重排与自动滚动 |

同一断言的重复用例保留更完整的版本；输入设备、轴向、reverse、边界交接及生命周期不同的用例继续保留。共享辅助声明先核对其依赖，不能只因类名相同就合并不同的测试 State。

`support/` 仅保留功能测试复用的虚拟列表宿主。耗时基准、实验探针、手工录帧与历史报告统一放在 [examples/benchmark](../../../../../examples/benchmark/test/scroll/README.md)，不进入库内测试。

运行本模块测试：`flutter test --no-pub packages/el_ui/test/cores/scroll`。
