# Selection

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。文本/图片文档选区与对象框选各用独立根、独立控制器。

## 文档选择、复制与监听

```dart
final controller = ElSelectionController();
ElSelectionView(
  controller: controller,
  onSelectionChanged: (text) => debugPrint(text ?? '选区清空'),
  child: Column(children: [ElView(child: '第一段'), Text('第二段')]),
);
ElButtonView(onPressed: controller.selectAll, child: '全选');
ElButtonView(onPressed: () => controller.copy(), child: '复制');
ElButtonView(onPressed: controller.clear, child: '清除');
```

| API | 说明 |
| --- | --- |
| ElSelectionView.enabled | 整个子树开关，默认 true |
| onSelectionChanged | 选中文本，null 表示清空 |
| controller.text / hasSelection | 当前文本与是否有选区；图片文本优先替代文本，再用源地址 |
| controller.selectAll / clear / copy | 全选当前已挂载内容、清除、复制纯文本 |
| controller.addListener | 选区文本变化通知，解绑时移除 |

ElView 文本、官方 Text/RichText 和支持的图片参与文档选择。一个 controller 只绑定一个根；外部创建则在生命周期内持有并 dispose。弹层内容要选中，须自己再包 ElSelectionView；嵌套根独立处理。虚拟列表未挂载项不属于全选范围。

## 对象框选（实验）

```dart
final controller = ElBoxSelectionController();
SizedBox(
  width: 320, height: 240,
  child: ElBoxSelectionView(
    controller: controller,
    onSelectionChanged: (change) => debugPrint('选中 ${change.selectedCount} 项'),
    child: Wrap(children: [
      for (final id in ['a', 'b', 'c'])
        ElBoxSelectable(
          value: id,
          style: ElStyle(padding: EdgeInsets.all(12)),
          selectedStyle: ElStyle(bgColor: Colors.lightBlue),
          child: Text(id),
        ),
    ]),
  ),
);
```

| API | 说明 |
| --- | --- |
| ElBoxSelectable.value | 同根内唯一稳定业务值；selectedStyle 叠加选中外观 |
| View.enabled / dragThreshold / autoScroll / selectionColor | 开关、起拖距离、边缘自动滚动、选框颜色 |
| onSelectionChanged | 差集 added / removed 与 selectedCount，不复制完整集合 |
| controller.selectedValues / selectedCount / isSelected | 读取集合、数量和单项状态 |
| select / deselect / clear / selectAll | 操作稳定对象值；全选当前根已登记对象 |

对象框选仅用于桌面鼠标实验，尚不适用于生产环境；不提供文本复制或移动端句柄。完整行为约定保留在 [CONTRACT.md](CONTRACT.md)。
