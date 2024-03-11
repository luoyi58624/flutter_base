part of flutter_base;

class AnimationUtil {
  AnimationUtil._();

  static AnimationController? _numAnimationController;
  static Animation<double>? _numAnimation;

  /// 创建两个数字区间动画
  static void createNumTween({
    required TickerProvider vsync,
    required double begin,
    required double end,
    required void Function(double value) callback,
    int milliseconds = 250,
    Curve curve = Curves.linear,
  }) {
    if (begin == end) return;

    void disposeAnimation() {
      if (_numAnimationController != null) {
        _numAnimationController!.dispose();
        _numAnimationController = null;
      }
    }

    disposeAnimation();
    _numAnimationController = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: milliseconds),
    );
    final Animation<double> curveAnimation = CurvedAnimation(parent: _numAnimationController!, curve: curve);
    _numAnimation = Tween(begin: begin, end: end).animate(curveAnimation)
      ..addListener(() {
        callback(_numAnimation!.value);
        if (_numAnimationController!.status == AnimationStatus.completed) {
          disposeAnimation();
        }
      });
    _numAnimationController!.forward();
  }
}
