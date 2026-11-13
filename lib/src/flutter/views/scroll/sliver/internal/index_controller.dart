/// 渲染器向控制器开放的定位与条目位移入口。
abstract interface class SliverIndexTarget {
  bool get attached;

  Future<bool> reveal(int index, double alignment);

  /// 记录 [index] 处的条目增删，[delta] 为负表示移除。
  void shift(int index, int delta);

  void cancelReveal();
}

/// 公开控制器与渲染器之间的内部通道，避免渲染器出现在公开 API 上。
class SliverIndexChannel {
  SliverIndexTarget? target;
}
