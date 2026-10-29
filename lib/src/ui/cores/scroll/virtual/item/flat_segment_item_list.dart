// 段计划的扁平 item 视图，保持现有 builder 物化与 memo 行为。
// ignore_for_file: prefer_initializing_formals

part of '../virtual_pipeline.dart';

/// 段解构产物的扁平 item 视图（`List<Widget>` facade）。
///
/// 整条管线（窗口 reconcile、测量、锚点、选区）消费统一的扁平 item 空间：
/// static/materialized 段直取零成本；builder 段惰性物化 + memo（稳定窗口的
/// 重复 reconcile 拿到相同实例，保住复用快路径）。
class FlatSegmentItemList extends ListBase<Widget> {
  /// 由段计划构建扁平视图。
  FlatSegmentItemList(this.plan);

  /// 仅约束变化时复用有界构建缓存与真实 View context。
  FlatSegmentItemList withPlan(SegmentPlan next) => FlatSegmentItemList(next)
    .._memo.addAll(_memo)
    .._segmentContexts.addAll(_segmentContexts)
    .._buildContext = _buildContext;

  /// 底层段计划。
  final SegmentPlan plan;

  final Map<int, Widget> _memo = <int, Widget>{};
  BuildContext? _buildContext;
  final Map<int, BuildContext> _segmentContexts = {};

  /// inherited 依赖更新只清本段的有界构建缓存。
  void invalidateSection(int section) {
    final start = plan.itemStartOf(section);
    final end = start + plan.segments[section].itemCount;
    _memo.removeWhere((index, _) => index >= start && index < end);
  }

  /// builder 使用所属 View 的 context，保留真实祖先及 inherited 依赖。
  void attachSegmentContext(int section, BuildContext context) => _segmentContexts[section] = context;

  /// 惰性物化前注入一个稳定 BuildContext（State 提供）。
  void attachBuildContext(BuildContext context) {
    _buildContext = context;
  }

  @override
  int get length => plan.totalItemCount;

  @override
  set length(int value) => throw UnsupportedError('Segment-backed children are fixed-length');

  @override
  Widget operator [](int index) {
    final s = plan.segmentOfItem(index);
    final segment = plan.segments[s];
    if (segment is StaticSegment) return segment.child;
    final local = index - plan.itemStartOf(s);
    // 物化来源直取（零分配零 memo）；builder 来源惰性建 + memo。
    final source = segment is LinearSegment ? segment.source : (segment as GridSegment).source;
    if (source is MaterializedItemSource) return source.children[local];
    final cached = _memo[index];
    if (cached != null) return cached;
    final context = _segmentContexts[s] ?? _buildContext;
    assert(context != null, 'FlatSegmentItemList 物化前必须 attachBuildContext。');
    final built = (source as BuilderItemSource).builder(context!, local);
    if (_memo.length >= _builderChildMemoLimit) _memo.remove(_memo.keys.first);
    return _memo[index] = built;
  }

  @override
  void operator []=(int index, Widget value) => throw UnsupportedError('Segment-backed children are read-only');

  /// 遍历已物化行（keyed remap 通道消费：memo 是有界的最近构建缓存）。
  void forEachMaterialized(void Function(int index, Widget widget) visit) {
    _memo.forEach(visit);
  }
}
