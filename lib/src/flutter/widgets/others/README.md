# Other Widgets

导入 `package:flutter/material.dart`、`package:flutter_base/flutter_base.dart`。控制器、notifier 在生命周期内持有并 dispose。

## 测量真实 child

```dart
ElChildSizeBuilder(
  constraints: BoxConstraints(maxWidth: 240),
  child: Text('测量真实内容'),
  builder: (size, child) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [Text('尺寸：$size'), child],
  ),
);
```

child 在测量与正式内容间复用同一份 State。constraints 覆写测量约束；builder 收到的 child 可省略或只放置一次，不可重复放入多处。一次构建仍可能产生测量与最终布局两次布局。必要时通过 ElChildSizeBuilder.isTempLayout(context) 判断是否处于临时测量子树，不要在测量布局中启动业务副作用。

## 选择性监听与稳定子树

```dart
final count = ValueNotifier(0);
ElListenableBuilder<ValueNotifier<int>, int>(
  listenable: count,
  select: (value) => value.value ~/ 10,
  child: Icon(Icons.numbers),
  builder: (_, child) => Row(children: [child!, Text('十位：${count.value ~/ 10}')]),
);
```

| 组件/API | 用途 |
| --- | --- |
| ElListenableBuilder.listenable | 监听 Listenable，null 时不订阅 |
| select | 从对象取目标值，默认按所选值比较，只在变化时重建 |
| shouldRebuild(newValue, oldValue) | 自定义所选值变化判定，例如集合比较 |
| child | 不依赖通知的稳定子树，通过 builder 第二参数取回 |
| ElRebuildWidget(child:, shouldRebuild:) | 比较新旧 Widget 后决定是否更新包装子树 |
| ElChildIndex(index:, start:, end:, length:) | 向后代传递索引，of/maybeOf 读取，isStart/isEnd 辅助首尾判断 |
| ElEmptyWidget.instance | 可渲染的空占位；ElNullWidget / ElNullElement 是内部哨兵，不用于界面 |

## 触底加载

```dart
final controller = ScrollController();
ElInfiniteScroll(
  controller: controller,
  distance: 100,
  delay: Duration(milliseconds: 200),
  disabled: false,
  onLoad: () async {
    // 请求下一页并更新业务数据。
  },
  child: SizedBox(height: 240, child: ElScroll(
    controller: controller,
    child: SizedBox(height: 800, child: Text('正文')),
  )),
);
```

controller 必须与内容宿主相同。distance 是距 max 边的触发距离；delay 为防抖；onLoad 返回 Future 时等待完成再接受下一次加载；无更多数据时设 disabled=true。immediate 默认 true，挂载时只检查一次内容不足一屏，不会自动循环补满视口。

## 加载动画与帧率

```dart
ElLoading(loading: true, duration: Duration(seconds: 1), child: Icon(Icons.sync));
ElFps(show: true, color: Colors.green);
```

ElLoading 对 child 应用旋转动画，loading 关闭时停止。ElFps 的位置由外层布局决定；它显示实时帧率，不等于界面流畅度或输入延迟。

程序采样可用 ElFpsRecorder.attach / detach / report / reset；ElFpsReport 含 frameCount、averageFps、secondRates、worstInterval 及估算丢帧/卡顿字段。采样结果反映 Flutter 帧时序，不能替代真实呈现节奏、长帧频率与输入延迟测量。
