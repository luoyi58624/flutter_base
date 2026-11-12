import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerDownEvent;
import 'package:flutter/widgets.dart' show Offset, TickerModeData, Widget;

/// 渲染宿主回读所属 Element 的唯一入口。
///
/// 声明、时钟环境、换绑状态和焦点都由 Element 持有，渲染层只在用到时经这里读取，
/// 不为每个视图各存一份回调；脱离 Element 独立使用的渲染对象没有宿主。
abstract interface class RenderElementHost {
  /// 当前声明，供内容和选区关联来源节点。
  Widget get widget;

  /// 所在子树的时钟环境；只有动画节点才读取并订阅。
  ValueListenable<TickerModeData> get tickerModeNotifier;

  /// 所在条目是否正在局部换绑：换绑只跳过状态过渡，持续关键帧照常运行。
  bool get skipsReuseTransitions;

  /// 是否接受指针聚焦；接受时即使没有事件或视觉内容也参与命中。
  bool get acceptsPointerFocus;

  /// 指针按下时请求聚焦，[localPosition] 是焦点事件使用的本地落点。
  void requestPointerFocus(PointerDownEvent event, Offset localPosition);

  /// 当前是否持有主焦点；没有焦点集成时为 null，语义沿用最近一次同步的值。
  bool? get hasPrimaryFocus;
}
