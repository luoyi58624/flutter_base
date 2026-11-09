/// 示例共用官方滚动宿主，只切换内容 Sliver。
enum SliverExampleMode {
  /// 使用官方按需挂载的列表。
  official('SliverList'),

  /// 使用按类型复用结构的回收列表。
  recycler('ElSliverRecyclerList');

  const SliverExampleMode(this.label);

  /// 下拉菜单中显示的容器名称。
  final String label;
}
