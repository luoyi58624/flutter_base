part of '../dispatcher.dart';

/// 拖拽分账管线：driver 接受拖拽时按祖先链快照形成一条 roster，driver 每帧
/// 的 delta 在三段（外→内 pre / driver 主段 / 内→外 overflow）内协作记账。
///
/// 挂在 driver 的 [_DragMachine._pipeline]（生命周期与机器一致，覆盖多指），
/// 每个 roster 成员反向持有 [ElEventDispatcher._passiveDragPipeline]。
/// [active] 为 false 时（driver reset / 解散）所有钝化 / 阶段调用直接失效。
final class _DragPipeline {
  _DragPipeline({
    required this.driver,
    required this.roster,
    required this.axis,
    required this.latchBreakMember,
  });

  /// 接受拖拽的成员（管线主段执行者）。
  final ElEventDispatcher driver;

  /// 参与 pre/overflow 的祖先成员，内→外（链索引升序）。
  final List<ElEventDispatcher> roster;

  /// driver 接受拖拽时的**胜出轴**（轴向组胜出为该轴，自由拖拽为 null）；
  /// roster 成员 proxy.axis 兼容以此为准。
  final Axis? axis;

  /// latch 截断成员：roster 收集时遇到的第一个"有 drag shape 但无兼容
  /// dragProxy"的链成员（竞争型拖拽消费者，如外层滚动）。null 表示收集
  /// 走到链尾未遇到竞争者（此时施加截断等于不截断）。
  ///
  /// 对涉事序列施加 primaryGestureCutoff 时按该成员在**目标序列链**中的
  /// 实际索引定位截断点——多指后续序列的链长可能与形成序列不同，按身份
  /// 定位而不是复用形成时的索引。
  final ElEventDispatcher? latchBreakMember;

  /// 管线是否活跃。driver 的 [_DragMachine.resetSilently] 末尾置 false，
  /// 之后任何钝化检查、阶段执行、pipeline 快照都视为解散。
  bool active = true;

  /// 投递豁免成员集合：roster 成员在 [_PointerSequence.blockedAt] 中对
  /// [_PointerSequence.primaryGestureCutoff] 截断放行（eager 坍缩不豁免）。
  /// 惰性构造，只用集合语义。
  late final Set<ElEventDispatcher> exemptMembers =
      HashSet<ElEventDispatcher>.identity()..addAll(roster);
}
