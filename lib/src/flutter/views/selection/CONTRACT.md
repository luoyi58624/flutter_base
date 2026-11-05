# 选区系统

选区的五个公开类型由 `lib/flutter.dart` 统一导出，内部参与者、端点、载荷、控件和变化通知留在实现中。

| 类型 | 用途 |
| --- | --- |
| `ElSelectionView` | 为当前子树建立独立的文本和图片文档选区 |
| `ElSelectionController` | 读取选中文本、全选、清空和复制 |
| `ElBoxSelectionView` | 实验性的桌面鼠标矩形框选区域 |
| `ElBoxSelectionController` | 管理选中的稳定对象值集合 |
| `ElBoxSelectable` | 将对象值及其显示矩形登记到最近的框选区域 |

## 文档选区

1. `ElSelectionView` 建立自己的官方 `SelectionRegistrar`，登记当前实际挂载的文本和图片。`ElView`、Flutter `Text`、接入 registrar 的 `RichText` 和 `ElImageView` 使用同一套选择事件。
2. 鼠标拖动、连击、触摸长按和句柄移动统一转换成官方选择事件。起止端点及各内容的选中范围由这些参与者持有，不再维护第二套跨节点范围。
3. 内容自行绘制高亮；句柄、放大镜和工具条由本组件的内部附属层承载。拖动期间隐藏句柄只改变绘制与命中，不卸载在途交互节点。
4. 控制器和 `onSelectionChanged` 只提供 `String?`。`null` 表示没有选区；图片参与范围与高亮，复制时优先使用替代文本，其次使用源地址，二者均为空时返回空字符串但仍有选区。
5. 每个显式根彼此独立。弹窗需要选中时，由调用方在弹窗内容中插入 `ElSelectionView`；组件不寻找或代管其他页面、弹层和文档根。

默认使用平台交互形制，选中外观由内容自身的 `ElStyle.onSelection` 声明。内部平台控件和编辑器桥不属于业务 API。

```dart
final controller = ElSelectionController();

ElSelectionView(
  controller: controller,
  onSelectionChanged: (text) => print(text),
  child: Column(children: [ElView(child: '可以跨文本块选中')]),
);

controller.selectAll();
print(controller.text);
await controller.copy();
controller.clear();
```

## 实验性对象框选

此实现只供试验和验证，不作为生产能力承诺。现有 `WinDesktop` 接入继续保留，并同样标记为实验性。

1. `ElBoxSelectable` 向最近的框选根登记唯一对象值和矩形，不创建文档参与者，也不提供文本复制载荷。
2. 鼠标按下并越过阈值后，固定起点与最新位置形成选框。命中计算使用拖动开始时的对象尺寸，避免选中样式改变布局后产生来回跳选。
3. 相交对象形成集合差集，只更新实际变化对象的样式；控制器保留稳定对象值，通知通过 Dart record 提供 `added`、`removed` 和 `selectedCount`，不增加公开变化类。
4. 支持普通选择、Ctrl/Meta 切换、Shift 加选、全选、清空及可选的边缘滚动。仅处理鼠标，不提供移动端句柄、放大镜或文档范围。
5. 全选仅处理当前实际挂载的对象，不构建离屏内容或推算虚拟对象。需要业务全量选择时，由业务提供稳定对象值。

```dart
final controller = ElBoxSelectionController();

ElBoxSelectionView(
  controller: controller,
  onSelectionChanged: (change) => print(change.selectedCount),
  child: ElBoxSelectable(
    value: 'item-1',
    selectedStyle: ElStyle(backgroundColor: Colors.blue),
    child: ElView(child: '对象'),
  ),
);

print(controller.selectedValues);
```

## 内部边界

- `docs/`：文档视图、纯文本控制器、官方文档模型和文档手势桥。
- `box/`：独立对象集合、矩形查询、对象样式和选框绘制。
- `common/`：可复用的边缘滚动、禁选边界，以及文档和编辑器共用的内容协议、句柄和附属层。

内部协议不添加 `El` 前缀，也不通过公开入口转导出。框选只依赖共享滚动和边界，不依赖文档内核或移动端附属层。
