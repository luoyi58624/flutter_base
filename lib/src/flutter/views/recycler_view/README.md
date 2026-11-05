# Dart RecyclerView

按 AndroidX RecyclerView 的职责和调用方式实现的 Flutter 列表内核，代码位于 `lib/src/flutter/views/recycler_view/`，公共入口为：

```dart
import 'package:flutter_base/recycler_view.dart' as rv;
```

本模块的公开类型保留 `RecyclerView`、`Adapter`、`ViewHolder`、`LayoutManager`、`LinearLayoutManager` 和 `RecycledViewPool` 等官方名称，是本次对照移植对仓库 El 命名规范的特例。使用导入别名可以避免与 Flutter 的类型重名。

## 使用方式

容器沿用官方的先创建、再配置模式：

```dart
final recyclerView = rv.RecyclerView()
  ..setLayoutManager(rv.LinearLayoutManager(context))
  ..setAdapter(RowsAdapter());
```

在 `State` 中保存这个实例，再将它作为 Widget 放入有界的布局。不要在每次滚动通知中重新创建 RecyclerView、Adapter 或 LayoutManager；同一个 RecyclerView 实例也不能同时挂载在两个位置。

以下示例将结构创建与数据绑定分开：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

class RecyclerPage extends StatefulWidget {
  @override
  State<RecyclerPage> createState() => _RecyclerPageState();
}

class _RecyclerPageState extends State<RecyclerPage> {
  late final rv.RecyclerView recyclerView;

  @override
  void initState() {
    super.initState();
    recyclerView = rv.RecyclerView()
      ..setLayoutManager(rv.LinearLayoutManager(context))
      ..setAdapter(RowsAdapter());
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: recyclerView);
}

class RowHolder extends rv.ViewHolder {
  RowHolder(this.title)
    : super(
        SizedBox(
          height: 72,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: ValueListenableBuilder<String>(
              valueListenable: title,
              builder: (context, value, child) => Text(value),
            ),
          ),
        ),
      );

  final ValueNotifier<String> title;
}

class RowsAdapter extends rv.Adapter<RowHolder> {
  @override
  RowHolder onCreateViewHolder(rv.RecyclerView parent, int viewType) => RowHolder(ValueNotifier(''));

  @override
  void onBindViewHolder(RowHolder holder, int position, [List<Object> payloads = []]) {
    holder.title.value = '条目 $position';
  }

  @override
  int getItemCount() => 1000;
}
```

`onCreateViewHolder` 创建固定结构，`onBindViewHolder` 更新该结构实际消费的数据。示例使用 `ValueNotifier` 和 `ValueListenableBuilder`，业务也可以使用已有的可监听模型；容器没有额外发明一套数据绑定协议。绑定时应完整覆盖可能从上一条数据遗留的交互状态。点击回调需要位置时调用 `holder.getBindingAdapterPosition()`，并处理 `RecyclerView.NO_POSITION`，不要长期保存某次绑定传入的 position。

## 官方 API 对照

已经提供的接口保持官方的方法名、参数职责和调用方向：

| 官方职责 | Dart 接口 |
| --- | --- |
| 安装适配器和布局管理器 | `setAdapter`、`getAdapter`、`swapAdapter`、`setLayoutManager`、`getLayoutManager` |
| 创建与绑定条目 | `Adapter.onCreateViewHolder`、`onBindViewHolder`、`getItemCount`、`getItemViewType` |
| 稳定身份 | `setHasStableIds`、`hasStableIds`、`getItemId`、`findViewHolderForItemId` |
| 数据变更 | `notifyDataSetChanged`、`notifyItemChanged`、`notifyItemRangeChanged`、单项及范围插入/删除、`notifyItemMoved` |
| 数据观察 | `AdapterDataObserver`、`registerAdapterDataObserver`、`unregisterAdapterDataObserver`、`hasObservers` |
| 条目生命周期 | `onViewAttachedToWindow`、`onViewDetachedFromWindow`、`onViewRecycled`、`onFailedToRecycleView` |
| 适配器生命周期 | `onAttachedToRecyclerView`、`onDetachedFromRecyclerView` |
| 位置与回收保护 | `ViewHolder` 的绑定/绝对/布局/旧位置查询、`getBindingAdapter`、`setIsRecyclable`、`isRecyclable` |
| 同位置缓存与类型回收池 | `setItemViewCacheSize`、`setRecycledViewPool`、`getRecycledViewPool`、池的容量和存取接口 |
| 线性布局配置 | `setOrientation`、`setReverseLayout`、`setStackFromEnd` 及对应查询 |
| 可见条目查询 | `findFirstVisibleItemPosition` 等四种可见/完全可见位置查询 |
| 定位与滚动 | `scrollToPosition`、`scrollToPositionWithOffset`、`smoothScrollToPosition`、`scrollBy`、`smoothScrollBy`、`fling`、`stopScroll` |
| 滚动监听 | `OnScrollListener`、`addOnScrollListener`、`removeOnScrollListener`、`getScrollState` |
| 预取 | `setItemPrefetchEnabled`、`isItemPrefetchEnabled`、`setInitialPrefetchItemCount`、`getInitialPrefetchItemCount` |

先修改业务数据，再发送对应的 `notify*`。绑定位置会反映已经收到的结构变更，布局位置保留最近一次已提交布局的位置；两者在下一次布局前可能不同。`notifyDataSetChanged` 后，绑定位置在重新布局之前不可用。稳定 ID 必须在同一适配器内唯一，并在条目移动后保持不变；需要在适配器连接容器之前设置 `setHasStableIds(true)`。

`notifyItemChanged(position, payload)` 支持局部载荷；null 载荷要求完整绑定，并清除累积的局部载荷。`setIsRecyclable(false)` 与后续的 `setIsRecyclable(true)` 必须配对，允许嵌套。

`setHasFixedSize` 表示容器自身尺寸不依赖条目内容，不表示每个条目等高，也不承诺省略条目布局。

## 实际复用的内容

这套内核不使用 `ListView.builder` 承载条目，也不只缓存 Widget 描述。

- 可见条目离开布局后，可以先进入保留原数据身份的有限缓存。
- 条目进入类型回收池后，旧数据身份会清除，后续同类型数据可以重新绑定。
- 回收期间保留已经挂载的 Element、State 和 RenderObject；保留结构才有机会避开重复的首次挂载成本。
- 池中条目不参与绘制、命中测试和语义输出，Ticker 需要随可见性关闭。
- 清池、缩容、超出类型容量或宿主释放时，实际释放挂载结构。

同位置缓存和跨数据条目的结构回收是两种机制；这里的回收池不等同于将整个列表打开 keepAlive。回收池默认每种类型最多保留 5 个条目，可以通过 `setMaxRecycledViews` 调整。

共享 `RecycledViewPool` 的容器需要保证相同 viewType 对应兼容的 ViewHolder 和结构。共享池并不能自动消除不同业务适配器之间的类型冲突。

## Dart 与 Android 的差异

- Dart 没有 Java 的静态嵌套类型，因此 `RecyclerView.Adapter` 等类型平铺为 `rv.Adapter` 等公开类型。
- Dart 不支持同名方法重载，二参/三参 `onBindViewHolder` 合并成同名的可选 payloads 参数；重写方法时保留该可选参数。其他具有可选载荷的方法采用同样方式。
- `ViewHolder.itemView` 是不可变 Widget 描述，不提供 Android View 的 `setText` 等可变对象接口；绑定更新由条目持有的数据模型驱动。
- 滚动距离、偏移和速度采用 Flutter 逻辑像素，而不是 Android 物理像素整数。
- `LinearLayoutManager` 保留 context、orientation、reverseLayout 的参数顺序；context 用于保持官方调用形式，不承担 Android Context 的资源访问职责。
- `findViewByPosition` 返回 Widget 描述；它不是能够直接读写 Android View 坐标、布局参数或系统状态的对象。

## 当前支持范围

当前实现覆盖 Adapter/ViewHolder、同位置缓存、按类型的已挂载结构回收池、线性布局、适配器变更、位置查询和预算预取。线性布局支持横向/纵向、反向排列、从末端开始及条目定位。

没有实现 `GridLayoutManager`、`StaggeredGridLayoutManager`、`ItemAnimator`、`ItemDecoration`、`DiffUtil`、`ListAdapter`、`ConcatAdapter`、Android View 系统或全部 Android 辅助能力，也没有给这些能力放置不生效的同名空壳。已经暴露的接口对照官方使用模式，不表示整个 AndroidX RecyclerView 库的 API 和运行行为已经全部实现。

当前输入和惯性继续由 Flutter 的 `Scrollable` 与 `ClampingScrollPhysics` 驱动；这里实现的是视图回收和布局管线，没有把 Android `OverScroller`、HWUI、RenderThread 或 SurfaceFlinger 移植到 Dart，也没有修改 Flutter 引擎。

## 预取与性能验证

预取需要真正执行子树挂载、构建和布局，预算应包含这些成本，而不只是 `onCreateViewHolder` 返回 Widget 描述的耗时。准备任务根据方向、可见边界和历史成本安排；池中分别记录创建和绑定成本。

预算检查决定是否开始某项准备工作，不能中断已经执行到一半的同步 Dart 函数。未知成本的首次创建仍可能超时；复用后的绑定、条目内部变化和布局本身也仍有成本。如果主 isolate 被不可拆分的长任务阻塞，这套内核无法让新的 Dart 滚动更新同时执行。

当前统一入口为「设置 → 系统设置 → 文档滚动」，可选择：

- 官方普通滚动：`SingleChildScrollView + Column`，全量挂载文档条目。
- 官方虚拟滚动：`ListView.builder`，关闭自动 keepAlive。
- `ElScrollView`：文档列表的 keepAlive 关闭。
- `RecyclerView`：使用本目录的线性布局与视图回收内核。

通用组件文档与阴影文档共用该设置，同一倍率下四种模式使用相同的正文内容、间距、内边距和每项重绘边界。按钮页不再提供局部滚动开关，也不再通过深链的 `recycler`、`repeat` 查询参数选择管线或重复文档内容；普通组件页面链接继续用于打开页面。

同一系统设置中的「性能压力」弹出选项提供 1、2、5、10、20 倍。通用文档只显示一次页首，将正文小节按原顺序整体重复；阴影文档将完整的阴影演示内容作为一组重复。倍率全局共用，切换滚动方式不会改变所选倍率，不会为某一种实现单独增加或减少内容。

同一系统设置还提供「全局屏蔽语义」，控制应用内容是否向辅助技术输出语义。开启后，读屏无法读取被屏蔽的内容；这是一项全局对照设置，不会改变本内核的回收或惯性调度。比较四种滚动方式时应保持该开关一致。

「触摸重采样」开关按应用当前绑定的实际采样配置初始化。关闭时同时停用 El 绑定的自定义采样入口和 Flutter 官方采样标志，并结清在途输入；重新开启时恢复记录的采样配置，继续避免两套采样叠加。它控制输入采样路径，不改变列表内容或回收池。比较四种滚动方式时，也应保持此开关一致。

使用同一台设备、同一构建模式、相同内容和快速甩动方式对照。分别观察首次进入和已经复用后的表现，并同时检查条目创建/绑定次数、UI/raster 帧耗时、实际呈现间隔与输入延迟。回收次数增加或平均构建耗时降低，都不能单独证明用户感受到的抖动已经解决。

本实现用于验证 RecyclerView 的结构复用和准备机制能减少多少 Flutter 滚动开销，尚不承诺解决当前手机上的卡顿问题。

[首轮真机性能记录](PERFORMANCE.md)保存了旧版本重复按钮文档快速滑动的采样条件、结果和限制：当时 UI P95 与较长帧生产间隔减少，但 UI 最大值略变差、raster P95 没有改善；没有测得 SurfaceFlinger 的实际呈现间隔，不能据此宣称卡顿已根治。1101 项是已取消重复入口的历史采样场景，不是当前四模式页面的条目数量，也不是当前版本的重新实测结果。

## 官方参考

- [RecyclerView 源码](https://raw.githubusercontent.com/androidx/androidx/androidx-main/recyclerview/recyclerview/src/main/java/androidx/recyclerview/widget/RecyclerView.java)
- [LinearLayoutManager 源码](https://raw.githubusercontent.com/androidx/androidx/androidx-main/recyclerview/recyclerview/src/main/java/androidx/recyclerview/widget/LinearLayoutManager.java)
- [GapWorker 源码](https://raw.githubusercontent.com/androidx/androidx/androidx-main/recyclerview/recyclerview/src/main/java/androidx/recyclerview/widget/GapWorker.java)
- [Flutter scheduleTask 调度说明](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/scheduleTask.html)
