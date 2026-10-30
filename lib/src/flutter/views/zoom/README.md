# Zoom

单内容的缩放、平移和可选旋转；多页预览使用 [Preview](../preview/README.md)。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

## 手势缩放

```dart
final controller = ElZoomController();
SizedBox(
  width: 320, height: 240,
  child: ElZoomView(
    controller: controller,
    maxScale: 6,
    enableRotation: true,
    mouseWheelZoom: true,
    child: FlutterLogo(size: 120),
    onTransformChanged: (value) => debugPrint('${value.scale}'),
  ),
);
ElButtonView(onPressed: () => controller.reset(), child: '还原');
```

控制器在 State / Hook 生命周期内持有并 dispose，同一实例只能绑定一个 live ZoomView。child 可为图片、画布、图表或任意 Widget，父级提供有限视口。

## 尺寸与交互选项

| 参数 | 默认值与用途 |
| --- | --- |
| minScale / maxScale / doubleTapScale | 1 / 4 / 2；双击在最小倍数和目标倍数之间切换 |
| enableDoubleTapZoom / enablePan / enableRotation | true / true / false；双击、缩放后单指平移、旋转 |
| panInertia / scaleInertia | true / false；平移与缩放惯性 |
| mouseWheelZoom / mouseDragPan | false / true；物理鼠标滚轮缩放、主键拖动 |
| scaleSensitivity / wheelScaleSensitivity | 捏合、滚轮的缩放增益，默认 1 / 0.002 |
| constrained | true 时将 child 紧约束到视口；false 按内容实际尺寸，child 必须自行提供有限尺寸 |
| alignment / clipBehavior | 内容基位与裁剪，默认 center / hardEdge |
| onZoomChanged / onTransformChanged | 逐帧缩放值或完整变换通知，只按需监听 |

未缩放时单指拖动让给祖先滚动；缩放后优先平移内容，捏合接管手势。滚轮缩放默认关闭，避免抢占祖先滚动。

## 程序控制变换

```dart
final controller = ElZoomController(
  initialValue: ElZoomTransform(scale: 1.5),
);
ElButtonView(
  onPressed: () => controller.animateTo(
    ElZoomTransform(scale: 2, rotation: 0.25, offset: Offset(20, 0)),
    duration: Duration(milliseconds: 250),
    curve: Curves.easeOutCubic,
  ),
  child: '缩放并平移',
);
```

| API | 行为 |
| --- | --- |
| value / value= | 读取快照或立即设置；修改部分值可用 value.copyWith |
| jumpTo(transform) | 立即设置完整变换 |
| animateTo(transform, duration:, curve:) | 动画到指定变换，返回 Future |
| reset(animate: true) | 恢复单位变换，仍受当前 min/max 和边界约束 |

ElZoomTransform 的 scale 为有限正数，rotation 单位是**弧度**，offset 是视口逻辑坐标中的平移。挂载后控制器值会被宿主边界钳制并回写实际值；未挂载时保存请求值，animateTo 立即完成。监听 controller 可读持续变化，卸载前清理自己的监听。
