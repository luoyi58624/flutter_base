// ignore_for_file: prefer_initializing_formals — 命名参数映射私有字段。

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart' show Axis;

import 'scroll_delta_interceptor.dart';

/// 嵌套滚动协议 —— 安卓 `NestedScrollingParent3` 语义的 El 化。
///
/// 与视图正交的**双段协商**:手势始终归最内层滚动视图,delta 逐帧过链:
/// - **pre 段**(外→内):内层消费前,链上父级先抽税——折叠头收起方向
///   先吃 delta 的场景(AppBarLayout.onNestedPreScroll 语义);
/// - **post 段**(内→外):内层滚到边界后剩余量上交——嵌套滚动视图的
///   中途接力、折叠头展开方向"列表先到顶再展开"的场景
///   (onNestedScroll unconsumed 语义)。
///
/// 触摸、触控板、实际滚轮帧与惯性统一经过宿主路线；业务回调不进入物理轨迹查询。
/// 本底层接口返回消费量，公开 Mixin 的 remaining 协议在声明入口适配。
///
/// 消费契约(与 [ElScrollDeltaInterceptor] 相同):返回值与 delta 同号且
/// |consumed| ≤ |delta|;越界返回视为全消费(clamp),反号视为不消费。
abstract class ElNestedScrollParent {
  /// 创建底层嵌套滚动协商参与者。
  const ElNestedScrollParent();

  /// 兴趣轴；null 表示两轴都参与，节点声明可覆盖此值。
  Axis? get nestedScrollAxis => null;

  /// 一次触摸滚动会话开始(dragStart,内层判定可滚时)。
  void onNestedScrollStart(Axis axis, ElScrollDeltaSource source) {}

  /// pre 段:内层消费**之前**先抽税。返回消费量(0 = 不吃)。
  ///
  /// delta 空间与 [ElScrollDeltaInterceptor.interceptScrollDelta] 一致:
  /// touchDrag / fling 在用户空间(正 = 下拉/展开方向),pointerScroll 在
  /// pixels 空间(正 = 内容前进)。
  double onNestedPreScroll(double delta, ElScrollDeltaSource source) => 0.0;

  /// post 段:内层滚到边界后,没消费掉的剩余量上交。返回消费量;
  /// 本级没吃完的部分继续交给更外层,全链吃不完才回落为内层 overscroll。
  double onNestedPostScroll(double unconsumed, ElScrollDeltaSource source) => 0.0;

  /// fling 起飞速度交接(dragEnd)。返回剩余速度;**零速也回调**——
  /// 慢拖松手同样是手势收尾信号(snap 动画启动等依赖它)。
  double onNestedPreFling(double velocity) => velocity;

  /// 手势被取消时提前结清已拉出的状态，不能将取消误判为正常松手。
  void onNestedScrollCancel() {}

  /// 触摸滚动会话结束(dragEnd / dragCancel)。
  void onNestedScrollEnd() {}
}

/// 真实滚动宿主持有的链节点，由私有 region scope 下发。
final class NestedScrollNode {
  /// 创建参与者及其真实祖先链关系。
  NestedScrollNode({required this.parent, this.axis, this.outer});

  /// 当前节点调用的协商参与者。
  ElNestedScrollParent parent;

  /// 参与协商的轴;null = 两轴。
  Axis? axis;

  /// 更外层区域的节点。
  NestedScrollNode? outer;

  /// 宿主已卸载:链快照跨 build 持有时跳过,防调用已死实例。
  bool detached = false;
}

/// 解析后的协商链(某个滚动视图视角,按驱动轴过滤)。
///
/// 迭代顺序对齐安卓有效语义(每层父级先上报再消费的展开形):
/// - [preScroll]:**外→内**——最外层折叠头先吃;
/// - [postScroll] / [preFling]:**内→外**——剩余量逐层上交。
final class NestedScrollChain {
  NestedScrollChain._(this._nodes);

  /// 最近优先(内→外)。
  final List<NestedScrollNode> _nodes;

  /// 从最近的 outer 节点向外组链;无参与者返回 null(热路径零开销短路)。
  ///
  /// [outermost] 追加在链的最外侧:pre 段最先、post 段最后轮到,供刷新这类
  /// 「别人都走不动了才接手、回收时最先让出」的越界消费者使用。
  static NestedScrollChain? fromNode(
    NestedScrollNode? node, {
    required Axis axis,
    Iterable<NestedScrollNode> outermost = const [],
  }) {
    final nodes = <NestedScrollNode>[];
    void add(NestedScrollNode n) {
      final interestedAxis = n.axis ?? n.parent.nestedScrollAxis;
      if (!n.detached && (interestedAxis == null || interestedAxis == axis)) nodes.add(n);
    }

    for (var n = node; n != null; n = n.outer) {
      add(n);
    }
    outermost.forEach(add);
    return nodes.isEmpty ? null : NestedScrollChain._(nodes);
  }

  /// 消费契约钳制:反号 = 不消费,越量 = 全消费(与拦截器语义一致)。
  static double _clampConsumed(double consumed, double delta) {
    if (consumed == 0.0) return 0.0;
    if (consumed.sign != delta.sign) return 0.0;
    if (consumed.abs() > delta.abs()) return delta;
    return consumed;
  }

  /// 通知链中仍存活的参与者开始会话。
  void start(Axis axis, ElScrollDeltaSource source) {
    for (final n in _nodes) {
      if (!n.detached) n.parent.onNestedScrollStart(axis, source);
    }
  }

  /// 先通知真实取消，再由活动切换统一触发 end。
  void cancel() {
    for (final n in _nodes) {
      if (!n.detached) n.parent.onNestedScrollCancel();
    }
  }

  /// 通知链中仍存活的参与者结束会话。
  void end() {
    for (final n in _nodes) {
      if (!n.detached) n.parent.onNestedScrollEnd();
    }
  }

  /// pre 段(外→内),返回全链消费总量。
  double preScroll(double delta, ElScrollDeltaSource source) {
    var remaining = delta;
    for (var i = _nodes.length - 1; i >= 0; i--) {
      if (remaining.abs() <= precisionErrorTolerance) break;
      final n = _nodes[i];
      if (n.detached) continue;
      remaining -= _clampConsumed(n.parent.onNestedPreScroll(remaining, source), remaining);
    }
    return delta - remaining;
  }

  /// post 段(内→外),返回全链消费总量。
  double postScroll(double unconsumed, ElScrollDeltaSource source) {
    var remaining = unconsumed;
    for (final n in _nodes) {
      if (remaining.abs() <= precisionErrorTolerance) break;
      if (n.detached) continue;
      remaining -= _clampConsumed(n.parent.onNestedPostScroll(remaining, source), remaining);
    }
    return unconsumed - remaining;
  }

  /// fling 速度交接(内→外),返回剩余速度。零速也**逐个**回调不短路——
  /// 这是手势收尾信号(snap 启动等),每个参与者都必须收到。
  double preFling(double velocity) {
    var remaining = velocity;
    for (final n in _nodes) {
      if (n.detached) continue;
      final residual = n.parent.onNestedPreFling(remaining);
      // 同拦截器契约:0 或同号且不放大才接受,否则视为不消费。
      if (residual == 0.0 ||
          (remaining != 0.0 && residual.sign == remaining.sign && residual.abs() <= remaining.abs())) {
        remaining = residual;
      }
    }
    return remaining;
  }
}

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
