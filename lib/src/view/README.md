# 命令式 View

从 `package:flutter_base/view.dart` 独立导入；与现有 Widget 版同名类型一起使用时添加别名。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_base/view.dart' as view;

final root = view.ElView(style: view.ElStyle(padding: .all(12)));
final rectangle = view.ElView(
  style: view.ElStyle(width: 120, height: 80, bgColor: Colors.blue, margin: .all(8)),
);
root.add(rectangle);

// 将这个 Widget 放入正常的 Flutter 布局，root 在 State 初始化时创建并持有。
view.ElRootView(root: root);

rectangle.bgColor = Colors.orange; // 只请求绘制。
rectangle.width = 180; // 请求布局。
root.remove(rectangle); // 摘下后可以重新 add。
```

`ElStyle` 是独立的五字段初始配置，构造 View 时直接映射到自身字段，不保留配置对象。之后通过
`bgColor`、`width`、`height`、`margin`、`padding` 的 setter 更新；相同值立即返回。

每棵树只有宿主的一个 Widget、Element 和 RenderBox。普通 View 不创建 RenderObject，没有
build、样式解析器、属性 Map 或通知器。布局结果与绘制矩形缓存于实例；背景绘制共用一个 Paint。
几何变化使自身和祖先失效，约束未变的干净子树复用尺寸；颜色变化直接通知根宿主重绘。

子 View 暂时只支持从上到下排列。宽高表示包含 padding、不包含 margin 的盒子尺寸，服从宿主
约束；自动宽度在有界时填满可用宽度，无界时随内容收缩；自动高度随内容收缩。margin 不折叠，
margin 和 padding 只接受有限的非负 EdgeInsets。固定尺寸容器中的内容允许溢出。

`ElRootView` 只在首次创建渲染宿主时读取 root；相同 key 下重新构建 Widget 会继续使用原实例，
要替换根实例需更换 key。卸载释放宿主绑定，普通 View 实例可由调用方保留后重新挂载。

当前范围为颜色矩形与垂直排列，不包含文本、图片、事件、变体、动画及其它布局。

示例目录的“命令式View → 颜色矩形”提供一万条记录，支持 ListView、ElScrollView 和 RecyclerView。
RecyclerView 换绑只修改已有 View 字段。

页面右上角的“官方组件”开关默认关闭；打开后，三个容器的子项都改用 Flutter 的 Container 和
Column 构建相同颜色、尺寸和间距的矩形行。容器选择与子项实现独立切换。
