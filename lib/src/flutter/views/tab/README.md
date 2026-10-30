# Tab

水平分页视口，不负责标签栏外观。导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。

## 切页与标签栏联动

```dart
final controller = ElTabController(length: 2);
Column(children: [
  Row(children: [
    ElButtonView(onPressed: () => controller.animateTo(0), child: '首页'),
    ElButtonView(onPressed: () => controller.animateTo(1), child: '设置'),
  ]),
  SizedBox(
    height: 240,
    child: ElTabView(
      controller: controller,
      children: [Text('首页内容'), Text('设置内容')],
      onIndexChanged: (index) => debugPrint('落定页：$index'),
    ),
  ),
]);
```

控制器长期持有并 dispose；长度与页面数保持一致。无外部控制器时由 initialIndex 指定起始页。父级必须给出有限视口。

| 控制器 API | 用途 |
| --- | --- |
| index / previousIndex | 当前与上一落定页 |
| position / offset | 连续页位置与相对偏移，可驱动指示条 |
| isDragging / isAnimating | 拖动与动画状态 |
| jumpTo / animateTo | 立即切换或动画切换，可指定 duration / curve |
| next / previous | 相邻页切换 |
| addListener | 连续变化通知，解绑时移除 |

## 懒加载与缓存

```dart
SizedBox(
  height: 240,
  child: ElTabView(
    lazy: true,
    keepState: true,
    maxCacheCount: 3,
    viewportFraction: 0.9,
    children: [Text('一'), Text('二'), Text('三'), Text('四')],
  ),
);
```

| 参数 | 默认与行为 |
| --- | --- |
| lazy | false：初次全量构建；true：页面首次露出或成为动画目标时构建 |
| keepState | true；仅 lazy 时有效，false 则离开可视范围销毁 State |
| maxCacheCount | 默认不限；懒加载保活时按最近访问淘汰，可视页和当前页不淘汰 |
| viewportFraction | 默认 1，一页占视口宽度比例 |
| physics | 覆盖环境 ScrollConfiguration 的物理 |
| dragDevices | 默认跟随环境，不默认包含 mouse；桌面鼠标拖页需显式加入 |
| dragStartDistance | 覆写拖页起始阈值 |
| onDragStateChanged | 用户拖动开始、结束通知；onIndexChanged 只在落定页变化时触发 |

自定义标签栏读取控制器 position，不要依赖每帧 onIndexChanged。只是外观切换时无需使用控制器内部 attach / setPosition 等宿主维护方法。
