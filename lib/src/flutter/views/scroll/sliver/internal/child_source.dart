import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 渲染器取子项的唯一入口，三种生命周期各实现一份。
abstract interface class SliverChildSource {
  int get childCount;

  /// children 模式：全部常驻，内容没有变脏时不逐项布局。
  bool get mountsAll;

  /// 配置版本，变化时渲染器重新读取类型序列并刷新语义。
  int get generation;

  bool get hasTypes;

  Object? typeOf(int index);

  /// 读取锚点前调用：builder 按 Key 重排槽位，recycler 丢弃越界或类型失效的槽位。
  /// 返回已有条目的序号是否被重排，重排后实测尺寸不再对应原序号。
  bool beginLayout();

  /// 预告本轮窗口：recycler 提前腾出窗口外的槽位，同一轮即可换绑。
  void prepareWindow(List<int> window);

  RenderBox layoutChild(int index, BoxConstraints constraints);

  /// builder 销毁或保活，recycler 入池并停放，children 不做处理。
  void endLayout(List<int> window);

  RenderBox? childAt(int index);

  /// 停放中仍挂载的盒子，由渲染器作为独立布局边界维护。
  Iterable<RenderBox> get parked;
}

/// 按需模式下一个已挂载的子树及其当前绑定的序号。
class Slot {
  Slot(this.type, this.index);

  final Object? type;
  int index;
  Element? child;
  RenderBox? box;
  int generation = -1;
  bool active = false;
}

class NaturalSliverParentData extends ContainerBoxParentData<RenderBox> with KeepAliveParentDataMixin {
  /// children 模式没有槽位，子项始终处于活跃状态。
  Slot? slot;
  double layoutOffset = 0;
  double crossAxisOffset = 0;
  double extent = 0;

  bool get active => slot?.active ?? true;

  @override
  bool get keptAlive => keepAlive && !active;
}

/// 需要知道自己是否落在视口内的条目边界，渲染器定位后通知。
abstract interface class ViewportVisibility {
  set visible(bool value);
}

/// 升序窗口的成员判断；连续区间直接比较边界，不分配集合。
bool Function(int index) windowMembership(List<int> window) {
  if (window.isEmpty) return (_) => false;
  final first = window.first;
  final last = window.last;
  if (last - first + 1 == window.length) return (index) => index >= first && index <= last;
  return window.toSet().contains;
}
