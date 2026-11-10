// 旧视口的拦截器适配，通用嵌套协议由新版维护。
import 'package:flutter/foundation.dart' show precisionErrorTolerance;

import 'scroll_delta_interceptor.dart';
import '../../../../slivers/scroll/common/nested_scroll.dart';

export '../../../../slivers/scroll/common/nested_scroll.dart';

/// 链获取器:render / physics 经 getter 闭包动态读取(state 字段随 build
/// 刷新,identity 不参与 position 重建)。
typedef NestedScrollChainGetter = NestedScrollChain? Function();

/// 携带链引用的拦截器标记:drag controller 经既有 deltaInterceptor 引用
/// 拿到链做 touchDrag 的 post 段接力,免去 render 层新增穿线字段。
abstract interface class NestedScrollChainCarrier {
  NestedScrollChain? get nestedChain;
}

/// 滚动视图 State 持有的组合拦截器：既有拦截器（刷新链 / widget
/// 显式传参）优先，剩余量进嵌套滚动链，链只消费 leftovers。
///
/// 路由:
/// - touchDrag / pointerScroll → [NestedScrollChain.preScroll](进 position
///   前抽税);touchDrag 的 post 段由 drag controller 经
///   [NestedScrollChainCarrier] 直取链,在边界余量处接力;
/// - fling → [NestedScrollChain.postScroll]:fling 拦截物理只上报**越界
///   剩余量**,语义即安卓 dispatchNestedScroll 的 unconsumed;
/// - fling 速度交接 → [NestedScrollChain.preFling]。
final class NestedScrollInterceptorAdapter extends ElScrollDeltaInterceptor implements NestedScrollChainCarrier {
  NestedScrollInterceptorAdapter();

  @override
  NestedScrollChain? nestedChain;

  /// 既有拦截器(优先于链,保持存量优先级)。
  ElScrollDeltaInterceptor? next;

  @override
  double interceptScrollDelta(double delta, ElScrollDeltaSource source) {
    var remaining = delta;
    final n = next;
    if (n != null) {
      final consumed = n.interceptScrollDelta(remaining, source);
      // 同拦截器契约钳制:反号不消费、越量全消费。
      if (consumed != 0.0 && consumed.sign == remaining.sign) {
        remaining = consumed.abs() >= remaining.abs() ? 0.0 : remaining - consumed;
      }
    }
    final chain = nestedChain;
    if (chain != null && source == ElScrollDeltaSource.pointerScroll && remaining.abs() > precisionErrorTolerance) {
      // 仅保留尚未迁移的 wheel 桥；直接输入与惯性由真实宿主 slot 路线分派。
      remaining -= chain.preScroll(remaining, source);
    }
    return delta - remaining;
  }

  @override
  double interceptFlingVelocity(double velocity) {
    return next?.interceptFlingVelocity(velocity) ?? velocity;
  }
}

// 说明:El 滚动视图**之间**的越界接力(内层到边界→外层继续)由既有拖拽
// 管线(dispatcher 的 pre/overflow 阶段)承担,不在本协议内重复实现——本
// 协议专注**自定义 parent**(折叠头/视差/联动指示器)对 delta 的
// pre/post/fling 协商。
