part of flutter_base;

/// 全局抽屉工具类
class DrawerUtil {
  DrawerUtil._();

  static OverlayEntry? _overlayEntry;
  static AnimationController? _controller;
  static Animation<double>? _positionAnimation;
  static Animation<double>? _opacityAnimation;

  /// 当前屏幕是否已经存在抽屉
  static bool hasDrawer() {
    return _controller != null;
  }

  /// 在当前屏幕上显示一个抽屉，如果之前打开过一个抽屉，那么会先关闭它再重新打开一个新的抽屉
  /// * child 抽屉子元素
  /// * width 抽屉宽度
  /// * position 抽屉位置: left、top、bottom、right
  static Future<void> show({
    required Widget child,
    double width = 300,
    String position = 'left',
  }) async {
    if (hasDrawer()) await close();
    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return _DrawerWidget(
          width: width,
          child: child,
        );
      },
    );
    if (rootContext.mounted) Overlay.of(rootContext).insert(_overlayEntry!);
  }

  /// 关闭当前屏幕上的抽屉
  static Future<void> close() async {
    if (_controller != null) {
      await _controller!.reverse();
      _controller!.dispose();
      _controller = null;
      _positionAnimation = null;
      _opacityAnimation = null;
      _overlayEntry!.remove();
      _overlayEntry = null;
      await 0.05.delay();
    }
  }
}

class _DrawerWidget extends StatefulWidget {
  const _DrawerWidget({required this.child, required this.width});

  final Widget child;
  final double width;

  @override
  State<_DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<_DrawerWidget> with SingleTickerProviderStateMixin {
  late double position = -widget.width;
  double opacity = 0;

  @override
  void initState() {
    super.initState();
    DrawerUtil._controller = AnimationController(duration: const Duration(milliseconds: 225), vsync: this);
    DrawerUtil._positionAnimation = Tween<double>(begin: position, end: 0)
        .animate(CurvedAnimation(parent: DrawerUtil._controller!, curve: const Cubic(0, 0, 0.2, 1)));
    DrawerUtil._opacityAnimation = Tween<double>(begin: opacity, end: 0.54)
        .animate(CurvedAnimation(parent: DrawerUtil._controller!, curve: const Cubic(0.4, 0, 0.2, 1)));
    DrawerUtil._controller!.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0.0,
      bottom: 0.0,
      left: 0.0,
      right: 0.0,
      child: AnimatedBuilder(
        animation: DrawerUtil._controller!,
        builder: (context, child) => Stack(
          children: [
            GestureDetector(
              onTap: () {
                DrawerUtil.close();
              },
              child: Container(
                color: Color.fromRGBO(0, 0, 0, DrawerUtil._opacityAnimation!.value),
                alignment: Alignment.topLeft,
              ),
            ),
            Positioned(
              top: 0.0,
              bottom: 0.0,
              left: DrawerUtil._positionAnimation!.value,
              child: Material(
                child: Container(width: widget.width, color: Colors.white, child: widget.child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
