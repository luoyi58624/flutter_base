# 图片预览

`ElImagePreview` 包裹一个 `ElImageView`，点击后在根 Overlay 展示预览，不 push 路由。

```dart
ElImagePreview(child: ElImageView('assets/photo.jpg', width: 160, height: 100, fit: .cover));

ElImagePreview(
  images: ['assets/a.jpg', 'assets/b.jpg'],
  initialIndex: 1,
  child: ElImageView('assets/b.jpg', width: 160, height: 100, fit: .cover),
);
```

- 不传 `images` 或传空列表：预览子图片，也支持 `ElImageView.memory`。
- 传图片地址列表：按列表顺序翻页；省略 `initialIndex` 时匹配 `child.src`，没有匹配则从第一张开始。重复地址用 `initialIndex` 区分。
- 原有图片实例、样式和回调保留。图片的点击事件可通过 `preventDefault()` 阻止打开。
- 进退场自行插值缩略图与全屏图片的矩形，完成共享元素动画，不依赖 Navigator Hero。当前图片有同页同列表的缩略图时飞回对应入口；入口不存在时淡出。
- 系统返回由入口的 `PopScope` 消费，退场期间仍拦截返回。入口卸载时移除覆盖层。
- Android/iOS：双指缩放、旋转、横滑翻页，双击缩放，单击切换工具栏，未缩放时下拉关闭。
- Windows/macOS/Linux：上一张、下一张、左右旋转、缩放、还原按钮；滚轮缩放，放大后拖拽，方向键切换，Esc 关闭。

手势和图片变换由 `ElPreviewView` 负责。`ElPreviewController.zoomTo` 与 `rotateBy` 可供其他上层预览界面复用。
