part of flutter_base;

/// 按压缩放元素widget
class TapScaleWidget extends StatefulWidget {
  const TapScaleWidget({
    super.key,
    required this.child,
    this.scale,
    this.duration = 150,
    this.onTap,
    this.onLongPress,
    this.onLongPressDown,
    this.onLongPressUp,
    this.onLongPressCancel,
  });

  final Widget child;
  final double? scale;
  final int duration;

  final void Function()? onTap;
  final void Function()? onLongPress;
  final void Function(LongPressDownDetails)? onLongPressDown;
  final void Function()? onLongPressUp;
  final void Function()? onLongPressCancel;

  @override
  State<TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<TapScaleWidget> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (e) {
        if (widget.onTap != null) {
          setState(() {
            _tapped = true;
          });
        }
      },
      onTapUp: (e) {
        Future.delayed(
          Duration(milliseconds: widget.duration - 50),
          () {
            if (mounted) {
              setState(() {
                _tapped = false;
              });
            }
          },
        );
        Future.delayed(
          const Duration(milliseconds: 50),
          () {
            if (widget.onTap != null) {
              widget.onTap!();
            }
          },
        );
      },
      onTapCancel: () {
        if (mounted) {
          setState(() {
            _tapped = false;
          });
        }
      },
      onLongPressDown: widget.onLongPressDown,
      onLongPress: widget.onLongPress,
      onLongPressUp: widget.onLongPressUp,
      onLongPressCancel: widget.onLongPressCancel,
      child: AnimatedScale(
        duration: Duration(milliseconds: widget.duration),
        scale: _tapped ? widget.scale ?? 0.85 : 1,
        child: widget.child,
      ),
    );
  }
}

/// 按压修改元素颜色透明度widget
class TapOpacityWidget extends StatefulWidget {
  const TapOpacityWidget(
      {super.key, required this.child, this.onTap, required this.color, this.rightIcon, this.leftIcon, this.iconSize});

  final Widget child;
  final Color color;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final double? iconSize;

  final FutureOr<void> Function()? onTap;

  @override
  State<TapOpacityWidget> createState() => _TapOpacityWidgetState();
}

class _TapOpacityWidgetState extends State<TapOpacityWidget> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    Widget childWidget;
    Color color = _tapped ? widget.color.withAlpha(180) : widget.color;
    double iconSize = widget.iconSize ?? 16;
    if (widget.leftIcon == null && widget.rightIcon == null) {
      childWidget = widget.child;
    } else if (widget.leftIcon != null) {
      childWidget = Row(
        children: [
          Icon(
            widget.leftIcon!,
            size: iconSize,
            color: color,
          ),
          widget.child,
        ],
      );
    } else if (widget.rightIcon != null) {
      childWidget = Row(
        children: [
          widget.child,
          Icon(
            widget.rightIcon!,
            size: iconSize,
            color: color,
          ),
        ],
      );
    } else {
      childWidget = Row(
        children: [
          Icon(
            widget.leftIcon!,
            size: iconSize,
            color: color,
          ),
          widget.child,
          Icon(
            widget.rightIcon!,
            size: iconSize,
            color: color,
          ),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (e) {
        if (widget.onTap != null) {
          setState(() {
            _tapped = true;
          });
        }
      },
      onTapUp: (e) {
        Future.delayed(
          const Duration(milliseconds: 100),
          () {
            setState(() {
              _tapped = false;
            });
          },
        );
        Future.delayed(
          const Duration(milliseconds: 50),
          () {
            widget.onTap!();
          },
        );
      },
      onTapCancel: () {
        setState(() {
          _tapped = false;
        });
      },
      child: DefaultTextStyle(
        style: TextStyle(
          color: color,
        ),
        child: childWidget,
      ),
    );
  }
}

/// 按压修改元素颜色透明度widget
class TapBackgroundWidget extends StatefulWidget {
  const TapBackgroundWidget({
    super.key,
    required this.child,
    required this.color,
    required this.activeColor,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final Color activeColor;

  final FutureOr<void> Function()? onTap;

  @override
  State<TapBackgroundWidget> createState() => _TapBackgroundWidgetState();
}

class _TapBackgroundWidgetState extends State<TapBackgroundWidget> {
  bool _tapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (e) {
        if (mounted && widget.onTap != null) {
          setState(() {
            _tapped = true;
          });
        }
      },
      onTapUp: (e) {
        Future.delayed(
          const Duration(milliseconds: 100),
          () {
            if (mounted) {
              setState(() {
                _tapped = false;
              });
            }
          },
        );
        Future.delayed(
          const Duration(milliseconds: 50),
          () {
            if (mounted) {
              widget.onTap!();
            }
          },
        );
      },
      onTapCancel: () {
        if (mounted) {
          setState(() {
            _tapped = false;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: _tapped ? widget.activeColor : widget.color,
        child: widget.child,
      ),
    );
  }
}
