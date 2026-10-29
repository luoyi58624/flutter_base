import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../viewport/scroll_engine_position.dart';

/// 可选的滚轮信号入口，命中探测不运行业务输入回调。
@internal
abstract interface class ScrollPointerMotionInput {
  /// 当前绑定是否提供统一输入写入权。
  bool get supportsPointerMotion;

  /// 实际路线是否可能消费该方向的位移。
  bool canConsumePointerDelta(double delta);

  /// 建立可取消的真实滚轮输入会话。
  ScrollPointerMotionSession beginPointerMotion(PointerScrollEvent event, VoidCallback onCancelled);
}

/// 平滑算法只操作输入距离，每个实际样本由会话统一分账。
@internal
abstract interface class ScrollPointerMotionSession {
  /// 原输入组是否仍拥有实际 position。
  bool get isCurrent;

  /// 已消费的输入距离，不冒充正文位置。
  double get inputPosition;

  /// 当前实际 position 的写入令牌。
  ScrollMotionOwner get motionOwner;

  /// 连续滚轮更新原始事件，实际帧时刻另行传递。
  void updateEvent(PointerScrollEvent event);

  /// 在输入事务内安装唯一的动画活动。
  bool startActivity(ScrollActivity activity);

  /// 消费一笔实际帧或直滚输入，返回未处理的输入余量。
  double applyDelta(double delta, Duration timeStamp);

  /// 结束当前输入组，不影响后来接管的命令。
  void finish({required bool cancelled});
}
