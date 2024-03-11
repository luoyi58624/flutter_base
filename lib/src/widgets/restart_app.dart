part of flutter_base;

class RestartAppWidget extends StatefulWidget {
  /// 重新启动App组件，需要将其放置在runApp下。
  ///
  /// 注意：它仅仅是重新build我们的页面，目前flutter并未提供系统级别重启app的方法。
  ///
  ///
  /// ```dart
  /// runApp(
  ///   RestartAppWidget(
  ///     child: MyApp(),
  ///   ),
  /// );
  /// ```
  const RestartAppWidget({super.key, required this.child});

  final Widget child;

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartAppWidgetState>()!.restartApp();
  }

  @override
  State<RestartAppWidget> createState() => _RestartAppWidgetState();
}

class _RestartAppWidgetState extends State<RestartAppWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}
