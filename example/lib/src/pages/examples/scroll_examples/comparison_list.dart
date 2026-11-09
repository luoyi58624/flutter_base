import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../../../widgets/example_scrollbar.dart';
import 'scroll_mode.dart';

/// 共用官方视口，对照按需创建与自然尺寸回收的列表。
class SliverComparisonList extends StatelessWidget {
  /// 创建内容、方向和位置控制一致的 Sliver 对照。
  // ignore: prefer_const_constructors_in_immutables
  SliverComparisonList({
    super.key,
    required this.mode,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.recycledItemBuilder,
    this.itemType,
    this.reverse = false,
    this.findChildIndexCallback,
  });

  /// 当前内容布局。
  final SliverExampleMode mode;

  /// 两种布局使用的唯一位置控制器。
  final ScrollController controller;

  /// 业务记录数量。
  final int itemCount;

  /// 官方列表的内容工厂。
  final IndexedWidgetBuilder itemBuilder;

  /// 回收列表的固定结构工厂，事件执行时读取活索引。
  final Widget Function(BuildContext, ValueListenable<int>)? recycledItemBuilder;

  /// 允许互相复用的业务结构类型。
  final Object? Function(int)? itemType;

  /// 是否从末端反向排列。
  final bool reverse;

  /// 官方列表按业务 Key 保留重排后的内容身份。
  final int? Function(Key)? findChildIndexCallback;

  @override
  Widget build(BuildContext context) => RecyclerExampleScrollbar(
    controller: controller,
    child: CustomScrollView(
      key: ValueKey('comparison-${mode.name}-list'),
      controller: controller,
      reverse: reverse,
      semanticChildCount: itemCount,
      slivers: [
        if (mode == .recycler)
          ElSliverRecyclerList(
            itemCount: itemCount,
            itemType: itemType,
            itemBuilder:
                recycledItemBuilder ??
                (context, index) => ValueListenableBuilder<int>(
                  valueListenable: index,
                  builder: (context, value, _) => itemBuilder(context, value),
                ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              itemBuilder,
              childCount: itemCount,
              findChildIndexCallback: findChildIndexCallback,
              addAutomaticKeepAlives: false,
            ),
          ),
      ],
    ),
  );
}

/// 在导航栏中选择两种内容 Sliver。
class SliverComparisonModeMenu extends StatelessWidget {
  /// 创建内容布局菜单。
  // ignore: prefer_const_constructors_in_immutables
  SliverComparisonModeMenu({super.key, required this.mode, required this.onChanged});

  /// 当前布局。
  final SliverExampleMode mode;

  /// 切换内容布局。
  final ValueChanged<SliverExampleMode> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<SliverExampleMode>(
    key: ValueKey('comparison-mode-menu'),
    tooltip: '切换内容 Sliver',
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final option in SliverExampleMode.values)
        CheckedPopupMenuItem(
          key: ValueKey('comparison-mode-${option.name}'),
          checked: mode == option,
          value: option,
          child: Text(option.label),
        ),
    ],
  );
}
