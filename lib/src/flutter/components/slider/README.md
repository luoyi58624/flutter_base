# Slider

`ElSlider<D>` 以 Web Slider 为基线，D 是 double 或 `List<double>` 的完整模型类型；普通构造是单滑块，range 构造是范围，不把模型降为 Object? notifier。单值省略初值时从 min 开始，范围须提供初始列表或外部模型。

- 数值：min、max、step、buffer；step 为 null 时仅使用 marks 的值。
- 刻度：marks 接受 bool 或 `List<ElSliderMark>`，刻度只保存 value 和可选 label。
- 文案：label、unit、startLabel、endLabel，valueLabelDisplay 使用 auto / on / off；valueLabelFormat 和 semanticValueFormat 以端点索引区分范围文案。
- 行为与外观：disabled、style、focusNode、event，复用公共事件及焦点通道。

公共接口移除 Material 的 SliderInteraction、WidgetStateProperty、divisions 和专属颜色字段。吸附、交叉端点排序、触屏预览抬起提交和辅助技术操作由品牌实现，接口不修改传入集合或计算选择。移动端已有品牌实现，桌面端暂用官方 Slider / RangeSlider 承接基础行为；临时边界见 [Material 替代](../../../ui/material/README.md)。
