part of flutter_base;

class TapBuilder extends StatefulWidget {
  /// 按下事件构造器
  const TapBuilder({
    super.key,
    required this.builder,
    this.onTap,
    this.delay = 100,
    this.disabled = false,
  }) : assert(delay >= 0, 'delay延迟时间不能小于0');

  final Widget Function(bool isTap) builder;

  final GestureTapCallback? onTap;

  /// 延迟多少毫秒更新点击状态，如果为0将不会更新点击状态
  final int delay;

  /// 是否禁用，默认false
  final bool disabled;

  @override
  State<TapBuilder> createState() => _TapBuilderState();
}

class _TapBuilderState extends State<TapBuilder> {
  bool isTap = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.disabled ? null : widget.onTap,
      onTapDown: (widget.delay == 0 || widget.disabled)
          ? null
          : (e) {
              setState(() {
                isTap = true;
              });
            },
      onTapUp: (widget.delay == 0 || widget.disabled)
          ? null
          : (e) {
              AsyncUtil.delayed(() {
                setState(() {
                  isTap = false;
                });
              }, widget.delay);
            },
      onTapCancel: (widget.delay == 0 || widget.disabled)
          ? null
          : () {
              AsyncUtil.delayed(() {
                setState(() {
                  isTap = false;
                });
              }, widget.delay);
            },
      child: widget.builder(isTap),
    );
  }

  void update(bool enabled) {
    setState(() {
      isTap = enabled;
    });
  }
}
