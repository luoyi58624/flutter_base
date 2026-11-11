# Sliver 回收列表、网格与瀑布流

公开入口为 `ElSliverRecyclerList` 和 `ElSliverRecyclerGrid`，可直接放进 `CustomScrollView.slivers`，与标题、固定导航、页脚等其他 Sliver 共用滚动。

```dart
Widget buildItem(BuildContext context, ValueListenable<int> index) {
  return ValueListenableBuilder<int>(
    valueListenable: index,
    builder: (context, value, child) => Text(records[value].title),
  );
}

ElSliverRecyclerList(
  itemCount: records.length,
  itemBuilder: buildItem,
);

ElSliverRecyclerGrid(
  crossAxisCount: 2,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  itemCount: records.length,
  itemBuilder: buildItem,
);

ElSliverRecyclerGrid.masonry(
  crossAxisCount: 2,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  itemCount: records.length,
  itemBuilder: buildItem,
);
```

示例中的 `records` 是业务数据。需要显式声明 ValueListenable 类型时，引入 `package:flutter/foundation.dart`；组件通过 `package:flutter_base/flutter_base.dart` 导入。

## 尺寸与布局

- 三种布局都自然测量条目，不要求固定高度或 itemExtent。方向、反向、滚动物理与缓存范围由外层 CustomScrollView 配置，内容边距使用 SliverPadding。
- 普通网格按行排列，每行的最大自然高度决定下一行起点；较短卡片保留自身高度。横向滚动时行列角色随主轴交换。
- 瀑布流将下一项放入当前最短列。已显示条目记录所在列，后续补测优先保持其列位置稳定，避免左右跳动。
- 父组件、路由或构建闭包更新会刷新业务绑定；数量、实际类型序列、轴向、交叉轴尺寸和网格配置未变时，保留实测尺寸与已显示条目的列分配。仅可视高度变化不会清空几何缓存。
- 未测尺寸使用类型估值；新类型估值只用于后续推算，已生成前缀等待实际测量后再修正。真实尺寸揭晓、宽度或列数变化时重新计算受影响的位置，并通过 Sliver 的偏移修正保持真实可见锚点。滚动条远跳后若旧条目已全部离屏，就保留输入像素，不拿估值条目补造锚点。总滚动长度在测量过程中仍可能变化。
- 瀑布流远距定位只推算几何元数据，不创建前面所有 Widget；未知位置仍需要顺序推算前置列状态，不承诺常数时间或未测尺寸下的绝对精确偏移。

## 复用与状态

`itemBuilder` 创建槽位的固定业务结构。滚动换绑通过同一个 ValueListenable<int> 通知新序号，固定 Widget、Element、State 和 RenderObject 保留。动态区域使用官方 ListenableBuilder / ValueListenableBuilder，固定内容放在监听范围外或通过 child 参数传入。ElView 可以继续接收标准 ValueListenable 文本来源并使用文本快路径。

上面的 Text 示例只重建一个动态叶子。复杂卡片应保留固定宿主，监听 index 后把当前记录写入卡片持有的 ValueNotifier，再由文字、图片等消费点订阅。不要把整张卡片放进 index 的 ValueListenableBuilder，也不要用随记录 ID 变化的 Key 标识可复用卡片：前者仍会重建并更新整棵业务树，后者会直接卸载旧子树，丢失 Element、State 和 RenderObject 的复用。实际接法见 example/lib/src/pages/examples/sliver_takeaway/index.dart。

索引通知也可能表示父配置刷新，此时 index.value 不一定改变，但该位置对应的记录可能已经变化。映射监听器收到通知就重新读取当前记录，不能只凭序号相等跳过；其订阅和自建数据通知器随槽位宿主释放。

监听对象由容器释放。事件回调应在触发时读取 index.value；输入内容、展开状态和异步任务应按业务记录保存或校验身份。父组件更换配置、条目数量或继承环境变化时，现有结构仍遵守正常配置更新规则。

`itemType` 区分不能交换业务结构的类型；记录类型改变后，失效的旧绑定会在刷新子树前移除，避免旧结构读取新类型数据。`maxRecycledItems` 限制所有类型合计的空闲槽位，不含当前缓存窗口。列表、网格和瀑布流共用同一套槽位生命周期。

槽位换绑的构建与布局共用内部 `ReuseAnimationScope`，跨序号时直接呈现新记录的开关、进度和入场状态；同一记录的正常更新及持续动画保留。消息等业务前插仍须由页面按业务 ID 恢复阅读锚点，列表起点保持零偏移。

## ElView 文本快路径

把稳定的 ValueListenable 直接作为 ElView.child，纯文本通知即可更新渲染层。例如下面直接显示槽位的当前序号：

```dart
ElSliverRecyclerList(
  itemCount: records.length,
  itemBuilder: (_, index) => ElView(
    style: ElStyle(fontSize: 16, padding: .all(12)),
    child: index,
  ),
);
```

业务标题同样可以传入 ValueListenable<String>：其当前值应反映 index.value 对应的记录，并在序号或业务数据变化时通知；映射来源的订阅随条目生命周期释放。不要在固定外壳的构建器里只取一次 index.value 再生成普通字符串，否则后续换绑不会更新这段文字。

文本快路径保留 ElView 的 Widget、Element 和 RenderObject，不经过整份视图配置更新；文字换行导致自然高度改变时，仍会触发布局并修正后续条目位置。三种布局的集成验证见 test/flutter/slivers/sliver_recycler_text_test.dart。

## 文件分工

| 文件 | 职责 |
| --- | --- |
| sliver_recycler.dart | 两个公开组件、固定槽位、单列布局、Sliver 绘制与命中 |
| extent_index.dart | 私有实测尺寸、类型估值、前缀和与偏移反查，不依赖旧 RecyclerView |
| grid_geometry.dart | 网格行高索引、瀑布流列分配与窗口查询 |
| grid_layout.dart | 自然测量、多列可见集合、间距及锚点修正 |

首页提供列表对照、网格和瀑布流三个 ListTile 入口。网格和瀑布流示例各展示 1,000 条自然高度记录，右上角可切换 2 / 3 / 4 列，并与宿主共用同一控制器接入常显、可拖拽的 iOS 风格滚动条。

上述示例仅在官方 SliverList / SliverGrid 与对应回收 Sliver 之间切换，统一使用 CustomScrollView。官方等高网格为这组有限文案预留高度；回收网格继续自然测量。迁出的业务示例见 example/lib/src/pages/examples/scroll_examples/README.md。

本轮验证使用无头 Widget 测试，不将测试运行时间解释为真机帧耗时。
