part of 'index.dart';

/// 驱动 [ElSliverList.recycler] 按序号定位的控制器，可在挂载前创建、随列表更换。
///
/// 远处条目不需要预先构建：下一次布局先实测目标条目，再用官方偏移修正一次移动视口。
class ElSliverRecyclerController {
  final _channel = SliverIndexChannel();

  /// 是否已关联到正在显示的列表。
  bool get isAttached => _channel.target?.attached ?? false;

  /// 将 [index] 对齐到视口的 [alignment] 位置：0 顶端、0.5 居中、1 底端。
  ///
  /// 完成定位的那一帧布局结束后返回 true；未挂载、列表为空或期间列表被移除时返回 false。
  /// 内容不足以滚到目标位置时停在可滚动范围的边界。
  Future<bool> jumpToIndex(int index, {double alignment = 0}) {
    final target = _channel.target;
    if (target == null || !target.attached) return Future.value(false);
    return target.reveal(index, alignment);
  }

  /// 通知 [index] 处插入了 [count] 个条目。
  ///
  /// 下一次布局把视口内首个条目的序号随之后移，正文保持原位，不被插在上方的内容推走。
  void notifyItemsInserted(int index, int count) {
    if (count > 0) _channel.target?.shift(index, count);
  }

  /// 通知从 [index] 起移除了 [count] 个条目。
  ///
  /// 下一次布局把视口内首个条目的序号随之前移；它本身被移除时由紧随其后的条目接替原位置。
  void notifyItemsRemoved(int index, int count) {
    if (count > 0) _channel.target?.shift(index, -count);
  }

  /// 撤销尚未执行的定位，等待中的 [jumpToIndex] 返回 false。
  void cancel() => _channel.target?.cancelReveal();
}
