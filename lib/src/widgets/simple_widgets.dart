part of '../../flutter_base.dart';

const Widget arrowRightWidget = Icon(Icons.keyboard_arrow_right);

/// 构建滚动组件
Widget buildScrollWidget({
  required Widget child,
  ScrollController? controller,
  bool showScrollbar = true,
}) {
  Widget widget = SingleChildScrollView(
    controller: controller,
    child: child,
  );
  if (showScrollbar) {
    return widget = buildScrollbar(
      controller: controller,
      child: widget,
    );
  }
  return widget;
}

/// 构建通用分割线Widget
Widget buildDividerWidget(
  BuildContext context, {
  double height = 0,
  double thickness = 0.5,
  double indent = 0,
  Color? color,
}) {
  return Divider(
    height: height,
    thickness: thickness,
    indent: indent,
    color: color ?? (BrightnessWidget.isDark(context) ? Colors.grey.shade700 : Colors.grey.shade300),
  );
}

/// 构建通用的列表分割线widget
IndexedWidgetBuilder buildSeparatorWidget(
  BuildContext context, {
  double height = 0,
  double thickness = 0.5,
  double indent = 0,
  Color? color,
}) {
  return (ctx, index) => buildDividerWidget(
        context,
        height: height,
        thickness: thickness,
        indent: indent,
        color: color,
      );
}

Widget buildPopupMenuButton({
  Offset? offset,
}) {
  return PopupMenuButton(
    elevation: 2,
    offset: const Offset(0, 50),
    padding: const EdgeInsets.all(0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    ),
    itemBuilder: (BuildContext context) => <PopupMenuEntry>[
      const PopupMenuItem(
        child: Text('MaterialApp'),
      ),
      const PopupMenuItem(
        child: Text('CupertinoApp'),
      ),
      const PopupMenuItem(
        child: Text('重启App'),
      ),
    ],
  );
}

Widget buildCenterColumn(List<Widget> children) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    ),
  );
}

Widget buildBoxWidget({
  double width = 36,
  double height = 36,
  double radius = 4,
  Color color = Colors.grey,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: color,
    ),
  );
}

/// 构建滚动条，如果是桌面端(包括桌面端web)，直接返回子元素
Widget buildScrollbar({
  required Widget child,
  ScrollController? controller,
  bool thumbVisibility = false, // 是否一直显示滚动条
}) {
  if (GetPlatform.isDesktop) return child;
  return Scrollbar(
    controller: controller,
    thumbVisibility: thumbVisibility,
    child: child,
  );
}

/// 构建ios滚动条，如果是桌面端(包括桌面端web)，则不使用ios滚动条，因为会冲突
Widget buildCupertinoScrollbar({
  required Widget child,
  ScrollController? controller,
  bool thumbVisibility = false, // 是否一直显示滚动条
}) {
  if (GetPlatform.isDesktop) return child;
  return CupertinoScrollbar(
    controller: controller,
    thumbVisibility: thumbVisibility,
    child: child,
  );
}

/// 构建ios loading
Widget buildCupertinoLoading({
  double radius = 16,
  bool animating = true,
  Color? color,
}) =>
    CupertinoActivityIndicator(
      animating: animating,
      radius: radius,
      color: color,
    );

/// ios加载loading预设
class CupertinoLoadingPreset {
  CupertinoLoadingPreset._();

  static const Widget mini = CupertinoActivityIndicator(
    animating: true,
    radius: 8,
  );

  static const Widget small = CupertinoActivityIndicator(
    animating: true,
    radius: 12,
  );

  static const Widget medium = CupertinoActivityIndicator(
    animating: true,
    radius: 16,
  );

  static const Widget large = CupertinoActivityIndicator(
    animating: true,
    radius: 20,
  );
}
