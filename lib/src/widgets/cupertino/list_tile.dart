part of flutter_base;

class MyCupertinoListTile extends StatelessWidget {
  const MyCupertinoListTile({
    super.key,
    required this.title,
    this.onTap,
    this.page,
    this.disabledLeading = false,
    this.leadingIcon,
    this.leadingIconColor,
    this.leadingWdiget,
    this.additionalInfo,
    this.trailing,
    this.disabledTrailing = false,
  });

  final String title;
  final Function? onTap;
  final Widget? page;

  /// 是否禁用默认前缀图标
  final bool disabledLeading;

  /// 自定义前缀图标
  final IconData? leadingIcon;
  final Color? leadingIconColor;

  /// 自定义前缀组件，优先级比leadingIcon高
  final Widget? leadingWdiget;

  /// 末尾前的小部件
  final Widget? additionalInfo;

  /// 尾缀小部件，如果为null则默认显示右箭头
  final Widget? trailing;

  /// 禁用尾缀箭头图标
  final bool disabledTrailing;

  @override
  Widget build(BuildContext context) {
    Widget? leading = disabledLeading
        ? null
        : leadingWdiget ??
            (leadingIcon == null
                ? Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.resolveFrom(context),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Icon(leadingIcon, color: leadingIconColor));
    return CupertinoListTile(
      onTap: onTap == null && page == null
          ? null
          : () {
              if (onTap != null) {
                onTap!();
              } else {
                context.push(page!);
              }
            },
      leading: leading,
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: AppController.of.config.defaultFontWeight),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      additionalInfo: additionalInfo,
      trailing: disabledTrailing ? null : trailing ?? const CupertinoListTileChevron(),
    );
  }
}
