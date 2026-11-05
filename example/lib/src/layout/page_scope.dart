import 'package:flutter/widgets.dart';

/// 标记桌面壳已提供公共导航头，正文页面不再重复创建。
class DesktopPageScope extends InheritedWidget {
  /// 创建桌面导航头作用域。
  const DesktopPageScope({super.key, required super.child});

  /// 当前页面是否已经位于桌面公共壳内。
  static bool exists(BuildContext context) => context.dependOnInheritedWidgetOfExactType<DesktopPageScope>() != null;

  @override
  bool updateShouldNotify(DesktopPageScope oldWidget) => false;
}
