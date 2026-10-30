# Preview

多页内容预览，每页包含缩放、平移和旋转。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

## 固定页面与翻页

```dart
final controller = ElPreviewController(initialIndex: 0);
SizedBox(
  width: 320, height: 240,
  child: ElPreviewView(
    controller: controller,
    loop: true,
    children: [FlutterLogo(size: 100), Text('第二页')],
    onIndexChanged: (index) => debugPrint('当前页：$index'),
  ),
);
ElButtonView(onPressed: () => controller.next(), child: '下一页');
ElButtonView(onPressed: () => controller.resetCurrent(), child: '还原当前页');
```

外部 controller 在生命周期内持有并 dispose；省略时用 initialIndex 初始化内部状态。外层提供有限视口。

## 大数据、预加载与页面状态

```dart
final ids = ['image-a', 'image-b', 'image-c'];
SizedBox(
  width: 320, height: 240,
  child: ElPreviewView.builder(
    itemCount: ids.length,
    itemIdBuilder: (index) => ids[index],
    itemBuilder: (_, index) => Text(ids[index]),
    preloadCount: 1,
    preserveItemTransform: true,
    transformCacheCapacity: 32,
  ),
);
```

| 参数 | 说明 |
| --- | --- |
| itemIdBuilder | 重排、插入或删除时提供唯一稳定身份，避免按旧索引套用缩放状态 |
| preloadCount | 当前页两侧预挂载页数，默认 1 |
| preserveItemTransform | 默认 false；开启后切页保留各页变换 |
| transformCacheCapacity | 卸载页变换缓存数量上限，默认 32 |
| loop | 默认 false；开启首尾循环 |
| constrained / alignment / clipBehavior | 内容尺寸、基位与裁剪，语义同 Zoom |
| strictPageDragIntent | 收紧分页拖动意图判定，用于减少误翻页 |

## 缩放与控制器

minScale / maxScale / doubleTapScale 默认 1 / 6 / 2，enableRotation 默认 true，mouseWheelZoom 默认 true；scaleSensitivity、wheelScaleSensitivity 调整增益，panInertia / scaleInertia、mouseDragPan 控制惯性及鼠标拖动。与单内容 [Zoom](../zoom/README.md) 的部分默认值不同。

| ElPreviewController API | 用途 |
| --- | --- |
| index / currentTransform / isPageSettled | 当前页、当前变换、分页是否落定；空数据时 index 可为 null |
| next / previous | 翻页，可传 animate: false |
| animateToIndex / jumpToIndex | 动画或立即定位 |
| animateTransform / jumpToTransform | 控制当前页 ElZoomTransform |
| resetCurrent | 还原当前页，可关闭动画 |
| addListener | 监听页码或变换变化，解绑时移除监听 |

未缩放时单指横向拖动翻页；缩放后优先平移内容，边界余量再交给分页宿主。自定义内容不限于图片。
