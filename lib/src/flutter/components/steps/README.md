# Steps

ElSteps 继承 `ElModelValue<int>`，以零基索引绑定当前步骤，省略普通值时从 0 开始。共同参数是 children / status / vertical / interactive / disabled / style / semanticLabel，与 Web Steps 的职责一致。

status 只声明当前步骤的 process 或 error；前后步骤的等待、完成状态由品牌根据当前索引推导。ElStep 只提供 title、description、icon、disabled、style，不另外覆盖派生状态。

接口不进行索引归一化、状态推导或交互。两端暂用官方 Stepper / ListTile 承接基础步骤展示，见 [Material 替代](../../../ui/material/README.md)；品牌必须在 interactive 开启且未禁用时处理选择。
