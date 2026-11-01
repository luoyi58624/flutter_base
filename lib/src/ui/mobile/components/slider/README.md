# 移动端 Slider

通过公共 `ElSlider<double>` / `ElSlider<List<double>>.range` 接入，模型由 ElModelValue 持有。

行为以 Web `packages/core/my-ui.js` 的 Slider、sliderScale 和 `tests/slider-value.test.mjs` 为基线：圆块与轨道填充使用连续指针位置，业务值按步长或显式刻度的中点取整，松开后圆块吸附。触屏拖动只更新预览，有效抬起提交一次；鼠标和键盘实时提交。纵向手势、取消、第二触点、失焦、禁用、外部值更新与卸载清理预览。

范围交叉切换端点职责，提交新的有序数组；`step: null` 仅选择 marks，常规 step 从 min 起算，不将不能整除的 max 当作合法值。密集刻度只抽稀绘制，不改变选值精度。

轨道高 6、圆块直径 20、触控区域高 44，支持缓冲、刻度及文字、自定义数值与语义文案、三种提示显示模式和外部 FocusNode。移动端默认只呈现按压光圈，不附加鼠标悬停外观。用户样式通过根 ElStyle 承接。
