import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';

import '../commons/color.dart';

/// IOS页面混入
mixin CupertinoPageMixin {
  /// 构建通用的IOS页面脚手架
  Widget buildScaffold(
    BuildContext context, {
    required String title,
    required Widget child,
    String previousPageTitle = '', // 返回上一个页面的标题
    Widget? trailing, // 页面标题后缀组件
    String? heroTag,
    // 导航栏是否应用路由过渡动画，如果你使用showCupertinoModalBottomSheet以弹窗的形式加载一个IOS页面，
    // 那么你应当将其设置为false，否则两个IOS页面导航栏会触发hero动画，体验很差。
    bool transitionBetweenRoutes = true,
  }) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          title,
          style: TextStyle(color: MyColor.textColor(context)),
        ),
        previousPageTitle: previousPageTitle,
        backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
        trailing: trailing,
        transitionBetweenRoutes: transitionBetweenRoutes,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          height: double.infinity,
          child: child,
        ),
      ),
    );
  }

  /// 构建list分组容器
  Widget buildListGroup(
    context, {
    required List<Widget> children,
    bool insetGrouped = false,
    String? title,
    // 是否禁用下滑线的左边间距，如果你不需要item的默认图标，可以将其设置为true
    bool disabledDividerMargin = false,
  }) {
    if (children.isNotEmpty) {
      Widget? headerWidget = title == null
          ? null
          : Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: MyColor.textColor(context),
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

  /// 构建list分组列表项
  Widget buildListItem(
    BuildContext context,
    String title, {
    Function? onTap,
    Widget? page,
    bool disabledLeading = false, // 是否禁用默认前缀图标
    IconData? leadingIcon, // 自定义前缀图标
    Color? leadingIconColor,
    Widget? leadingWdiget, // 自定义前缀组件，优先级比leadingIcon高
    Widget? additionalInfo, // 末尾前的小部件
    Widget? trailing, // 尾缀小部件，如果为null则默认显示右箭头
    bool disabledTrailing = false, // 禁用尾缀箭头图标
  }) {
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
                : Icon(
                    leadingIcon,
                    color: leadingIconColor ?? MyColor.textColor(context),
                  ));
    return CupertinoListTile(
      onTap: onTap == null && page == null
          ? null
          : () {
              if (onTap != null) {
                onTap();
              } else {
                context.push(page!);
              }
            },
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          color: MyColor.textColor(context),
          fontWeight: FontWeight.w500,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      additionalInfo: additionalInfo,
      trailing: disabledTrailing ? null : trailing ?? const CupertinoListTileChevron(),
    );
  }
}
