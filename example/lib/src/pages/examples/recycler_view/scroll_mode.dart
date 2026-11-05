/// 两个长列表示例共用的本地滚动容器选项。
enum RecyclerExampleScrollMode {
  /// 使用 Flutter 按需创建条目的列表。
  listView('ListView'),

  /// 使用按类型复用结构的回收列表。
  recyclerView('RecyclerView');

  const RecyclerExampleScrollMode(this.label);

  /// 下拉菜单中显示的容器名称。
  final String label;
}
