/// 长列表示例共用的本地滚动容器选项。
enum RecyclerExampleScrollMode {
  /// 使用 Flutter 按需创建条目的列表。
  listView('ListView'),

  /// 使用 ElScrollView 与按需创建的虚拟列表。
  elScrollView('ElScrollView'),

  /// 使用按类型复用结构的回收列表。
  recyclerView('RecyclerView'),

  /// 使用构建器换绑、按子项实测高度回收的列表。
  recyclerView2('RecyclerView2');

  const RecyclerExampleScrollMode(this.label);

  /// 下拉菜单中显示的容器名称。
  final String label;
}
