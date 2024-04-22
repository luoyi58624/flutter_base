part of flutter_base;

/// tap事件延迟触发混入
mixin DelayTapMixin<T extends StatefulWidget, D> on State<T> {
  bool tap = false;

  /// 持续多少毫秒响应目标事件
  int get milliseconds => 150;

  /// 自定义点击事件
  void onTap();

  Widget buidlDelayTapWidget({required Widget child}) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      onTapDown: (e) {
        setState(() {
          tap = true;
        });
      },
      onTapUp: (e) {
        AsyncUtil.delayed(() {
          setState(() {
            tap = false;
          });
        }, milliseconds);
      },
      onTapCancel: () {
        AsyncUtil.delayed(() {
          setState(() {
            tap = false;
          });
        }, milliseconds);
      },
      child: child,
    );
  }
}
