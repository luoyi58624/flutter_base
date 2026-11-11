# Preview

任意内容的多指缩放、旋转、平移与横向翻页。放大后的内容移动到边缘，继续拖动即可进入相邻项；外层提供有限视口，计数栏、关闭按钮等外观由上层组合。

导入 `package:flutter/material.dart` 和 `package:flutter_base/flutter_base.dart`。

```dart
final controller = ElPreviewController(initialIndex: 0);
final items = ['第一项', '第二项'];

SizedBox(
  width: 320,
  height: 240,
  child: ElPreviewView(
    controller: controller,
    itemCount: items.length,
    itemBuilder: (_, index) => Center(child: Text(items[index])),
  ),
);

controller.animateToPage(1);
controller.resetTransform();
```

外部控制器在组件生命周期内持有并 `dispose`；省略控制器时由预览组件自行创建和释放。

| 参数 | 说明 |
| --- | --- |
| itemCount / itemBuilder | 项目数量与内容构建，内容按视口尺寸布局 |
| pageSpacing | 相邻项间距，默认 16 |
| maxScale / doubleTapScale | 最大缩放与双击目标，默认 4 / 2.5 |
| enableRotation | 是否允许双指旋转，默认 true |
| enableDoubleTap | 是否启用双击放大或还原，默认 true |
| enableWheelZoom / wheelZoomSensitivity | 鼠标滚轮缩放，默认启用，敏感度 0.002 |
| onTap | 单击回调；启用双击后等待双击判定窗口结束 |
| onIndexChanged | 当前项切换回调 |
| onVerticalDragStart / Update / End | 未缩放时的纵向拖动，可用于上层下拉关闭；未声明时留给祖先处理 |
| clipBehavior | 视口裁剪，默认 Clip.hardEdge |

两指先越过旋转阈值时允许旋转并缩放，先越过缩放阈值时锁定旋转；松手后旋转吸附到最近直角。

| ElPreviewController API | 用途 |
| --- | --- |
| index | 当前项索引，变化时通知控制器监听者 |
| page | 连续翻页位置的 ValueListenable，整数表示停在对应项 |
| scale / rotation / translation | 读取当前项的缩放、旋转和中心偏移 |
| jumpToPage / animateToPage | 立即或动画切换项目 |
| resetTransform | 还原当前项变换，可传 animate: false |
