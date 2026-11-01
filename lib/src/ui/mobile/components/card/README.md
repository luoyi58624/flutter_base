# Card

ElCard 通过内部 `cardBuilder` 使用移动端卡片，保留标题、说明、示例编号、响应式内边距和可交互整卡行为。整卡激活跳过内部控件，默认正文实例不替换。

正文接受通用内容，loading 显示加载指示并阻止整卡激活，同时保留正文实例；semanticLabel 提供辅助名称。具体组件与内部变量键不从 mobile.dart 导出，外观通过公共 style 入口覆盖。实现见 [index.dart](index.dart)。
