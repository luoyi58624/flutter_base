import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';

/// 通讯录分组，索引文字须非空且在同一通讯录内唯一。
class ElContactGroup<T> {
  /// 创建分组，顺序与成员排序均由调用方决定。
  /// 创建组件参数声明。
  const ElContactGroup({required this.index, required this.items, this.title});

  /// 右侧索引显示的文字，例如 A、☆ 或 #；↑ 保留给回到顶部。
  final String index;

  /// 分组中的业务数据，空分组仍展示标题并支持定位。
  final List<T> items;

  /// 分组标题与辅助技术名称，省略时使用 index。
  final String? title;
}

/// 带吸顶分组、字母索引和拖动预览的综合通讯录组件。
///
/// 放在有界高度中（例如 Expanded 或 ElScaffold.viewport）；导航和安全区由外层负责。
/// 不自动推断拼音或重排数据，更新时传入新的 groups 和 items 列表。
class ElContacts<T> extends StatelessWidget {
  /// 创建通讯录，默认行展示姓名首字头像与姓名。
  /// 创建组件参数声明。
  const ElContacts({
    super.key,
    required this.groups,
    required this.nameBuilder,
    this.itemBuilder,
    this.groupHeaderBuilder,
    this.onContactTap,
    this.header = const [],
    this.footer,
    this.empty,
    this.controller,
    this.onRefresh,
    this.refresher,
    this.padding = const .only(bottom: 24),
    this.indexPadding,
    this.style,
    this.itemStyle,
    this.groupHeaderStyle,
    this.showCount = true,
    this.showIndex = true,
    this.indexSemanticLabel = '通讯录字母索引',
  });

  /// 按展示顺序传入的分组。
  final List<ElContactGroup<T>> groups;

  /// 提取姓名，用于默认行、头像和联系人的可访问名称。
  final String Function(T contact) nameBuilder;

  /// 自定义联系人内容；点击和键盘激活仍由 onContactTap 统一处理。
  final Widget Function(BuildContext context, T contact)? itemBuilder;

  /// 自定义分组标题内容，组件继续负责吸顶和索引定位。
  final Widget Function(BuildContext context, ElContactGroup<T> group)?
  groupHeaderBuilder;

  /// 激活联系人时回传原始业务数据；省略时行仅展示内容。
  final ValueChanged<T>? onContactTap;

  /// 列表顶部的快捷入口或名片，每个成员独立参与滚动。
  final List<Widget> header;

  /// 列表底部内容，指定后替换默认人数统计。
  final Widget? footer;

  /// 联系人数为零时显示的内容。
  final Widget? empty;

  /// 外借滚动控制器，由调用方释放；省略时组件自建并释放。
  final ElScrollController? controller;

  /// 下拉刷新回调，省略时不启用刷新。
  final Future<void> Function()? onRefresh;

  /// 刷新外观，省略时沿用平台配置。
  final ElRefresher? refresher;

  /// 滚动内容留白，可在底部加入页面安全区。
  final EdgeInsets padding;

  /// 索引与组件边缘的距离，默认上下 12，右侧 Windows 为 14、其他平台为 2。
  final EdgeInsets? indexPadding;

  /// 通讯录容器样式，颜色与索引强调色可通过 ElApp 变量定制。
  final ElStyle? style;

  /// 联系人行样式，覆盖默认留白、分隔线与交互外观。
  final ElStyle? itemStyle;

  /// 分组标题样式，覆盖默认背景、留白与文字外观。
  final ElStyle? groupHeaderStyle;

  /// 未指定 footer 时是否显示联系人总数。
  final bool showCount;

  /// 是否显示右侧索引。
  final bool showIndex;

  /// 索引操作区域的辅助技术名称。
  final String indexSemanticLabel;

  @override
  Widget build(BuildContext context) =>
      ElComponentProvider.of(context).contactsBuilder!<T>(context, this);
}
