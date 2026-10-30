import 'package:flutter/widgets.dart';
import '../viewport/scroll_engine_position.dart';

/// 指针屏蔽窗口判据之一：**手指正在拖拽滚动**。
///
/// 官方 `ScrollPosition.goBallistic` 把拖拽期的 `shouldIgnorePointer` 原样
/// 传给 [BallisticScrollActivity]（构造参数，非按类型计算），且
/// `DrivenScrollActivity`（animateTo / smoothScroll）恒为 true，所以只看那个
/// 标志会把程序驱动动画也算进屏蔽窗口；两段触摸窗口拆成本判据 +
/// [touchFlingScrolling]，在命中现场按活动类型计算，程序动画天然豁免。
bool fingerDragScrolling(ScrollPosition position) {
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  return position.activity is DragScrollActivity;
}

/// 指针屏蔽窗口判据之二：**触摸起飞的 fling 仍在飞**（整段，不分快慢）。
///
/// 2026-08-02 用户裁决：惯性期一直屏蔽，直到滚动真正停下。此前的两档设计
/// （≥800px/s 快段屏蔽、慢速尾段恢复直接可点，Chrome TapSuppressionController
/// / AOSP RecyclerView SETTLING 同款速度门）在尾段仍偶发误触——浏览器样条
/// 低速区衰减慢、尾段窗口很长，落下即松手的轻触还是会落成卡片 onTap。惯性期
/// 触摸的语义统一为"停住/接管滚动"（按下依旧 `hold()`），内容交互等停稳。
///
/// [BallisticScrollActivity.shouldIgnorePointer] 是 `goBallistic` 从起飞时
/// 活动继承来的构造字段——触摸拖拽起飞为 true，trackpad 起飞与程序驱动
/// （hold/idle 期 goBallistic）为 false，桌面与程序动画天然豁免（保留
/// "滚动动画中点击"语义），不必查设备类型。
bool touchFlingScrolling(ScrollPosition position) {
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  final activity = position.activity;
  return activity != null &&
      activity.shouldIgnorePointer &&
      (activity is BallisticScrollActivity ||
          activity is ScrollCoordinatedActivity && (activity as ScrollCoordinatedActivity).activityType == .ballistic);
}

/// 触摸按下时落在**正在滚动**视口上的指针登记表（接住 fling / 程序驱动动画
/// / 他指拖拽的那一下）。
///
/// 触摸 fling 已整段屏蔽后代命中，但程序驱动动画（smoothScroll / animateTo）
/// 期间内容仍可直接命中，这类 down 会一路冒泡到选区根：不登记的话长按定时器
/// 被武装，按住 400ms 就在刚接住的内容上凭空选中（2026-07-19 用户报的误选）。
/// 登记必须发生在 `hold()` **之前**——hold 立刻把 `isScrolling` 转 false，
/// 事后无从判断这一下是不是"接住滚动"。
abstract final class ScrollCatchPointers {
  static final Map<int, bool> _pointers = <int, bool>{};

  /// 登记接住滚动的触点，并区分是否已有另一指拖拽。
  static void add(int pointer, {bool duringDrag = false}) =>
      _pointers[pointer] = duringDrag || _pointers[pointer] == true;

  /// 清除终结指针的滚动接住标记。
  static void remove(int pointer) => _pointers.remove(pointer);

  /// 此指针按下时是否已有滚动活动。
  static bool contains(int pointer) => _pointers.containsKey(pointer);

  /// 此触点是否落在另一指仍持有的滚动活动上。
  static bool isDuringDrag(int pointer) => _pointers[pointer] == true;
}
