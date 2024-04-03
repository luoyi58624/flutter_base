part of flutter_base;

class MyCupertinoListGroup extends StatelessWidget {
  const MyCupertinoListGroup({
    super.key,
    required this.children,
    this.insetGrouped = false,
    this.title,
  });

  final List<Widget> children;
  final bool insetGrouped;
  final String? title;

  /// 是否禁用下滑线的左边间距，如果你不需要item的默认图标，可以将其设置为true
  final bool disabledDividerMargin = false;

  @override
  Widget build(BuildContext context) {
    if (children.isNotEmpty) {
      Widget? headerWidget = title == null
          ? null
          : Text(
              title!,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            );
      double dividerMargin = disabledDividerMargin ? 0 : 14;
      double additionalDividerMargin = disabledDividerMargin ? 0 : 42;
      if (insetGrouped) {
        return CupertinoListSection.insetGrouped(
          dividerMargin: dividerMargin,
          additionalDividerMargin: additionalDividerMargin,
          header: headerWidget,
          children: children,
        );
      } else {
        return CupertinoListSection(
          dividerMargin: dividerMargin,
          additionalDividerMargin: additionalDividerMargin,
          header: headerWidget,
          children: children,
        );
      }
    } else {
      return const SizedBox();
    }
  }
}
