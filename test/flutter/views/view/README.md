# View 测试分类

按功能维护以下测试文件，具体场景用文件内的 `group` 组织。新增回归用例归入对应功能，不再按 bug、开发阶段或单个字段新建零散文件；无需为了控制行数拆文件。

| 文件 | 覆盖范围 |
| --- | --- |
| `core_test.dart` | 状态订阅、载荷复用、挂载分配、禁用与选中、指针事件行为 |
| `style_test.dart` | 样式字段和值类型、解析值、合并策略、强类型声明 |
| `cascade_test.dart` | 声明优先级、继承、状态变体、响应式断点、增量更新 |
| `layout_test.dart` | 盒模型几何、参考约束、尺寸、对齐、宽高比、固有尺寸 |
| `render_test.dart` | 绘制、装饰更新、失效路由、命中边界、Render 宿主 |
| `animation_test.dart` | 插值、动画驱动器、过渡、关键帧、主题动画与入场离场 |
| `text_test.dart` | 文本与富文本排版、内联事件、溢出、绘制失效、选区几何 |

归类时保留不同输入路径和边界条件。相同前提、相同结果的重复测试保留断言更完整的版本；相同宿主配置可在当前文件内共用辅助函数。

这里只保留功能测试，包括布局失效、缓存复用与实例生命周期的确定性计数断言。实际计时的挂载和动画基准统一放在 [examples/benchmark/test/view](../../../../../examples/benchmark/test/view)。

运行本模块测试：`flutter test --no-pub packages/el_ui/test/cores/view`。
