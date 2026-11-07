import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_base/recycler_view.dart' as rv;

import '../../../widgets/example_scrollbar.dart';
import 'scroll_mode.dart';

/// 在同一视口和内容工厂下切换三种线性滚动容器。
class RecyclerComparisonList extends StatelessWidget {
  /// 传入已安装适配器的回收列表，其他模式共用按需构建的行。
  const RecyclerComparisonList({
    super.key,
    required this.mode,
    required this.controller,
    required this.elController,
    required this.recyclerView,
    required this.itemCount,
    required this.itemBuilder,
    this.reverse = false,
    this.itemExtent,
    this.findChildIndexCallback,
  });

  /// 当前实际使用的滚动容器。
  final RecyclerExampleScrollMode mode;

  /// 连接官方列表和 RecyclerView 的滚动控制器。
  final ScrollController controller;

  /// ElScrollView 的独立控制器，避免切换时短暂挂载两处。
  final ScrollController elController;

  /// 已配置布局管理器和适配器的回收列表。
  final rv.RecyclerView recyclerView;

  /// 当前数据项的总数量。
  final int itemCount;

  /// 官方和 ElScrollView 共用的行构建函数。
  final IndexedWidgetBuilder itemBuilder;

  /// 是否让列表从底部反向开始。
  final bool reverse;

  /// 各行确实等高时，允许容器按已知尺寸定位。
  final double? itemExtent;

  /// 按需构建的列表在数据重排后根据行 Key 找到新的位置。
  final int? Function(Key)? findChildIndexCallback;

  Widget _item(BuildContext context, int index) {
    final item = itemBuilder(context, index);
    return RepaintBoundary(key: item.key is LocalKey ? item.key : null, child: item);
  }

  @override
  Widget build(BuildContext context) {
    if (mode == .elScrollView) {
      return ElScrollView(
        key: ValueKey('comparison-el-list'),
        controller: elController,
        reverse: reverse,
        scrollbar: RecyclerExampleIosScrollbar(),
        children: [
          ElListView.builder(
            fixedSize: itemExtent != null,
            keepAlive: false,
            itemCount: itemCount,
            findChildIndexCallback: findChildIndexCallback,
            itemBuilder: _item,
          ),
        ],
      );
    }
    return RecyclerExampleScrollbar(
      controller: controller,
      child: mode == .recyclerView
          ? recyclerView
          : ListView.builder(
              key: ValueKey('comparison-official-list'),
              controller: controller,
              reverse: reverse,
              itemCount: itemCount,
              itemExtent: itemExtent,
              findChildIndexCallback: findChildIndexCallback,
              addAutomaticKeepAlives: false,
              itemBuilder: itemBuilder,
            ),
    );
  }
}

/// 把滚动容器选项放在示例导航栏的一个图标菜单里。
class RecyclerComparisonModeMenu extends StatelessWidget {
  /// 创建保留选中状态的滚动容器菜单。
  const RecyclerComparisonModeMenu({super.key, required this.mode, required this.onChanged});

  /// 菜单中当前选中的模式。
  final RecyclerExampleScrollMode mode;

  /// 用户选择另一种滚动容器时调用。
  final ValueChanged<RecyclerExampleScrollMode> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<RecyclerExampleScrollMode>(
    key: ValueKey('comparison-mode-menu'),
    tooltip: '切换滚动容器',
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final option in RecyclerExampleScrollMode.values)
        CheckedPopupMenuItem(
          key: ValueKey('comparison-mode-${option.name}'),
          checked: mode == option,
          value: option,
          child: Text(option.label),
        ),
    ],
  );
}
