# ElAppBar

页面标题、可选副标题、返回入口和末端操作使用同一声明。移动品牌采用对称操作槽，标题居中时不会被单侧操作数量推偏。

```dart
Scaffold(
  appBar: ElAppBar(
    title: '我的收藏',
    subtitle: '把喜欢的，留在这里',
    back: true,
    actions: [ElButton(variant: .text, child: '编辑', onPressed: edit)],
  ),
  body: content,
)
```

`back` 默认关闭；开启后，`onBack` 为空时执行最近 Navigator 的 `maybePop`。`leading` 优先于默认返回按钮。`centerTitle` 控制标题布局，`style` 覆盖品牌样式，`event` 合并到标题栏根节点。放进 Scaffold 时由 Scaffold 处理顶部安全区；直接嵌入内容时按布局需要包裹 SafeArea。
