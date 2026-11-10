import '../../../../scroll/nested/scroll_delta_source.dart';

export '../../../../scroll/nested/scroll_delta_source.dart';

/// 滚动输入拦截器：注册到 [ElScrollView] 后，
/// 用户手势 / 滚轮 / 惯性产生的主轴 delta 先经拦截器消费一层，
/// 剩余量才交给 [ScrollPosition]。语义对齐安卓 nested scrolling 的
/// `onNestedPreScroll`，可供折叠、吸收等输入效果复用。
///
/// **契约**：
/// - 只作用主轴（单轴 = 该轴，双轴 v1 只拦垂直主轴）；
/// - 返回值 `consumed` 必须与 `delta` 同号且 `|consumed| ≤ |delta|`，
///   拦截器返回 0 表示完全不吃，剩余全走 [ScrollPosition]；
/// - 越界、overscroll、fling 起飞等所有滚动边界语义保持不变——拦截器只
///   缩短进 position 的 delta，不改物理；
/// - 性能：无拦截器时零开销（null 短路，热路径无额外分派）。
abstract class ElScrollDeltaInterceptor {
  const ElScrollDeltaInterceptor();

  /// 每帧 delta 进 [ScrollPosition] 之前的拦截口。返回消费掉的量
  /// （0 ≤ |consumed| ≤ |delta|，与 [delta] 同号）。
  double interceptScrollDelta(double delta, ElScrollDeltaSource source);

  /// 手势结束的惯性起飞速度交接：返回拦截器消费后剩余速度。
  /// 不消费返回原值即可（默认实现）。
  double interceptFlingVelocity(double velocity) => velocity;
}

/// 可选的 post-scroll 余量协作面。
///
/// [ElScrollDeltaInterceptor] 仍只定义热路径 pre 阶段；需要接收 position 无法
/// 消费的越界余量时额外实现本接口。返回值是消费量，符号与范围契约与
/// [ElScrollDeltaInterceptor.interceptScrollDelta] 一致。
abstract interface class ElScrollPostDeltaInterceptor {
  double interceptPostScroll(double delta, ElScrollDeltaSource source);
}
