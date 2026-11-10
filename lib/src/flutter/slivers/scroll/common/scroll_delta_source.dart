/// 滚动 delta 输入的来源：touchDrag 触摸拖拽、pointerScroll 滚轮 / 触控板信号、
/// fling 手势结束后的惯性帧。
enum ElScrollDeltaSource {
  /// 触摸拖拽（含 stylus / touch），每个 dragUpdate 事件一次进链。
  touchDrag,

  /// 滚轮 / 触控板：smooth 动画每帧真实应用到 position 的像素量。
  pointerScroll,

  /// 手势结束的惯性 ballistic，每帧到达 position 前先过链。
  fling,
}
