part of 'index.dart';

extension ElObjectExt<T extends Object> on T {
  /// 批量生成重复的对象
  List<T> operator *(int other) => List.generate(other, (index) => this);
}

extension ElIntExt on int {
  /// 应用系统全局文本缩放
  double applyTextScale(
    TextScaler textScaler, {
    double? minValue,
    double? maxValue,
  }) {
    if (textScaler == TextScaler.noScaling) return toDouble();

    double result = textScaler.scale(toDouble());

    if (minValue != null) result = max(result, minValue);
    if (maxValue != null) result = min(result, maxValue);
    return result;
  }

  /// int 转 [FontWeight]
  FontWeight toFontWeight([FontWeight? defaultFontWeight]) {
    switch (this) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
      default:
        return defaultFontWeight ?? FontWeight.normal;
    }
  }
}

extension ElDoubleExt on double {
  /// 应用系统全局文本缩放
  double applyTextScale(
    TextScaler textScaler, {
    double? minValue,
    double? maxValue,
  }) {
    if (textScaler == TextScaler.noScaling) return this;

    double result = textScaler.scale(this);

    if (minValue != null) result = max(result, minValue);
    if (maxValue != null) result = min(result, maxValue);
    return result;
  }

  Offset get toOffset => Offset(this, this);

  Size get toSize => Size(this, this);
}

extension ElListIntExt on List<int> {
  EdgeInsets? get toEdgeInsets =>
      map((e) => e.toDouble()).toList().toEdgeInsets;
}

extension ElListDoubleExt on List<double> {
  /// 将数组转为内边距对象，其数组结构与 CSS 一致：
  /// * [10] - 所有
  /// * [10, 20] - 上下 | 左右
  /// * [10, 20, 10] - 上 | 左右 | 下
  /// * [10, 20, 10, 20] - 上 | 右 | 下 | 左
  EdgeInsets? get toEdgeInsets {
    if (isEmpty) return null;

    if (length == 1) {
      return .all(first);
    } else if (length == 2) {
      return .symmetric(vertical: first, horizontal: last);
    } else {
      if (length == 3) {
        return .only(
          top: this[0],
          left: this[1],
          right: this[1],
          bottom: this[2],
        );
      } else {
        return .only(
          top: this[0],
          right: this[1],
          bottom: this[2],
          left: this[3],
        );
      }
    }
  }
}

extension ElBoolExt on bool {
  Brightness get brightness =>
      this == true ? Brightness.dark : Brightness.light;
}

extension ElStringExt on String {
  /// 将16进制字符串颜色转成Color对象
  Color toColor() {
    final buffer = StringBuffer();
    if (length == 6 || length == 7) buffer.write('ff');
    buffer.write(replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

extension ElPointerDownEventExt on PointerDownEvent {
  TapDownDetails get toTapDownDetails => TapDownDetails(
    globalPosition: position,
    localPosition: localPosition,
    kind: kind,
  );

  DragDownDetails get toDragDownDetails =>
      DragDownDetails(globalPosition: position, localPosition: localPosition);

  DragStartDetails get toDragStartDetails => DragStartDetails(
    sourceTimeStamp: timeStamp,
    globalPosition: position,
    localPosition: localPosition,
    kind: kind,
  );
}

extension ElPointerUpEventExt on PointerUpEvent {
  TapUpDetails get toTapUpDetails => TapUpDetails(
    globalPosition: position,
    localPosition: localPosition,
    kind: kind,
  );
}

extension ElPointerMoveEventExt on PointerMoveEvent {
  DragUpdateDetails get toDragUpdateDetails => DragUpdateDetails(
    sourceTimeStamp: timeStamp,
    delta: delta,
    globalPosition: position,
    localPosition: localPosition,
  );
}

extension ElAxisExt on Axis {
  bool get isHorizontal => this == Axis.horizontal;

  bool get isVertical => this == Axis.vertical;
}

extension ElAxisDirectionExt on AxisDirection {
  bool get isHorizontal =>
      this == AxisDirection.left || this == AxisDirection.right;

  bool get isVertical => this == AxisDirection.up || this == AxisDirection.down;

  /// 判断拖拽的滚动方向是否为前进
  bool get isForwardScroll =>
      this == AxisDirection.up || this == AxisDirection.left;

  /// 将方向转成 Alignment 对象
  Alignment get toAlignment {
    switch (this) {
      case AxisDirection.up:
        return Alignment.topCenter;
      case AxisDirection.down:
        return Alignment.bottomCenter;
      case AxisDirection.left:
        return Alignment.centerLeft;
      case AxisDirection.right:
        return Alignment.centerRight;
    }
  }

  /// 反转方向
  AxisDirection get flipped {
    switch (this) {
      case AxisDirection.up:
        return AxisDirection.down;
      case AxisDirection.down:
        return AxisDirection.up;
      case AxisDirection.left:
        return AxisDirection.right;
      case AxisDirection.right:
        return AxisDirection.left;
    }
  }

  /// 根据文本方向返回新的方向
  AxisDirection applyTextDirection(TextDirection textDirection) {
    if (isVertical) return this;
    return textDirection == TextDirection.ltr ? this : flipped;
  }
}

extension ElEdgeInsetsExt on EdgeInsets {
  EdgeInsets applyTextScale(TextScaler textScaler) {
    if (textScaler == TextScaler.noScaling) return this;
    return copyWith(
      left: textScaler.scale(left),
      right: textScaler.scale(right),
      top: textScaler.scale(top),
      bottom: textScaler.scale(bottom),
    );
  }

  EdgeInsets merge(EdgeInsets? v) {
    if (v == null) return this;
    return copyWith(
      left: v.left == 0.0 ? null : v.left,
      right: v.right == 0.0 ? null : v.right,
      top: v.top == 0.0 ? null : v.top,
      bottom: v.bottom == 0.0 ? null : v.bottom,
    );
  }
}

extension ElBorderRadiusExt on BorderRadius {
  BorderRadius applyTextScale(TextScaler textScaler) {
    if (textScaler == TextScaler.noScaling) return this;
    return copyWith(
      topLeft: Radius.elliptical(
        textScaler.scale(topLeft.x),
        textScaler.scale(topLeft.y),
      ),
      topRight: Radius.elliptical(
        textScaler.scale(topRight.x),
        textScaler.scale(topRight.y),
      ),
      bottomLeft: Radius.elliptical(
        textScaler.scale(bottomLeft.x),
        textScaler.scale(bottomLeft.y),
      ),
      bottomRight: Radius.elliptical(
        textScaler.scale(bottomRight.x),
        textScaler.scale(bottomRight.y),
      ),
    );
  }
}

extension ElBorderExt on Border {
  /// 获取 Border 最大的宽度
  double get maxWidth {
    final list = [top.width, right.width, bottom.width, left.width];
    list.sort();
    return list.last;
  }

  /// 判断是否为完整边框，边框的 4 条边均不为 null
  bool get isFull =>
      top != BorderSide.none &&
      right != BorderSide.none &&
      bottom != BorderSide.none &&
      left != BorderSide.none;

  /// 将自定义属性应用到当前边框对象中，添加 el 前缀防止冲突，虽然目前 Border 没有这个方法
  Border copyWith({
    double? width,
    Color? color,
    BorderStyle? style,
    double? strokeAlign,
  }) => Border(
    top: top.copyWith(
      width: width,
      color: color,
      style: style,
      strokeAlign: strokeAlign,
    ),
    right: right.copyWith(
      width: width,
      color: color,
      style: style,
      strokeAlign: strokeAlign,
    ),
    bottom: bottom.copyWith(
      width: width,
      color: color,
      style: style,
      strokeAlign: strokeAlign,
    ),
    left: left.copyWith(
      width: width,
      color: color,
      style: style,
      strokeAlign: strokeAlign,
    ),
  );
}

extension ElBoxDecorationExt on BoxDecoration {
  BoxDecoration merge(BoxDecoration? other) {
    if (other == null) return this;
    return copyWith(
      color: other.color,
      image: other.image,
      border: other.border,
      borderRadius: other.borderRadius,
      boxShadow: other.boxShadow,
      gradient: other.gradient,
      backgroundBlendMode: other.backgroundBlendMode,
      shape: other.shape,
    );
  }
}

extension ElBrightnessExt on Brightness {
  bool get isDark => this == Brightness.dark;

  Brightness get reverse =>
      this == Brightness.dark ? Brightness.light : Brightness.dark;
}

extension ElAnimationControllerExt on AnimationController {
  /// 继续运行动画，默认情况下会根据当前状态继续朝相同方向运行动画，将参数设置为 true 则朝反方向运行动画
  void start([bool? $reverse]) {
    if (status == AnimationStatus.dismissed ||
        status == AnimationStatus.forward) {
      $reverse == true ? reverse() : forward();
    } else {
      $reverse == true ? forward() : reverse();
    }
  }
}

extension ElSizeExt on Size {
  /// 将 Size 转成 Offset 对象
  Offset get toOffset => Offset(width, height);
}

extension ElOffsetExt on Offset {
  /// 将 Offset 转成 Size 对象
  Size get toSize => Size(dx, dy);

  /// 将 offset 限制在 [BoxConstraints] 约束中，返回新的 Offset 对象
  Offset clampConstraints(BoxConstraints constraints) {
    double x = 0.0;
    double y = 0.0;
    if (dx < 0) {
      x = 0;
    } else if (dx > constraints.maxWidth) {
      x = constraints.maxWidth;
    } else {
      x = dx;
    }
    if (dy < 0) {
      y = 0;
    } else if (dy > constraints.maxHeight) {
      y = constraints.maxHeight;
    } else {
      y = dy;
    }
    return Offset(x, y);
  }

  /// 根据 [Axis] 轴计算拖拽方向
  AxisDirection fromAxis(Axis axis) => switch (axis) {
    Axis.vertical => dy < 0 ? AxisDirection.up : AxisDirection.down,
    Axis.horizontal => dx < 0 ? AxisDirection.left : AxisDirection.right,
  };

  /// 根据水平角度计算拖拽方向
  AxisDirection toAxisDirection(double horizontalAngle) {
    final direction = this.direction;
    if ((-horizontalAngle <= direction && direction <= horizontalAngle) ||
        (direction <= -pi + horizontalAngle ||
            direction >= pi - horizontalAngle)) {
      return dx < 0 ? AxisDirection.left : AxisDirection.right;
    } else {
      return dy < 0 ? AxisDirection.up : AxisDirection.down;
    }
  }
}

extension ElImageProviderExt on ImageProvider {
  /// 获取图片信息
  Future<ImageInfo?> getImageInfo({ImageStream? imageStream}) async {
    imageStream ??= resolve(ImageConfiguration.empty);
    final completer = Completer<ImageInfo?>();

    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(imageInfo);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          imageStream!.removeListener(listener);
        });
      },
      onError: (exception, stackTrace) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        imageStream!.removeListener(listener);
      },
    );
    imageStream.addListener(listener);
    return completer.future;
  }
}

extension ElWidgetExt on Widget {
  /// 不使用祖先提供的默认滚动条，当使用自定义滚动条时请设置此扩展，可以防止与祖先提供的默认滚动条重叠
  Widget noScrollbarBehavior(
    BuildContext context, {
    Key? key,
    bool? overscroll,
    Set<PointerDeviceKind>? dragDevices,
    MultitouchDragStrategy? multitouchDragStrategy,
    Set<LogicalKeyboardKey>? pointerAxisModifiers,
    ScrollPhysics? physics,
    TargetPlatform? platform,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
    bool enabled = true,
  }) => enabled
      ? ScrollConfiguration(
          key: key,
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            overscroll: overscroll,
            dragDevices: dragDevices,
            multitouchDragStrategy: multitouchDragStrategy,
            pointerAxisModifiers: pointerAxisModifiers,
            physics: physics,
            platform: platform,
            keyboardDismissBehavior: keyboardDismissBehavior,
          ),
          child: this,
        )
      : this;

  /// 监听鼠标水平滚动（仅限桌面端生效），其后代滚动小部件必须在 widget 层指定 ScrollController
  Widget get elHorizontalScroll {
    if (ElPlatform.isMobile) return this;
    return _HorizontalScroll(child: this);
  }
}

class _HorizontalScroll extends HookWidget {
  const _HorizontalScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = useRef<ScrollController?>(null);
    useEffect(() {
      nextTick(() {
        final scroll = ElFlutterUtil.findDescendantStateOfType<ScrollableState>(
          context,
        );
        assert(scroll != null, 'ElHorizontalScroll Error: 后代不存在可滚动小部件！');
        assert(
          scroll?.widget.controller != null,
          'ElHorizontalScroll Error: 后代滚动小部件必须手动设置 ScrollController！',
        );
        controller.value = scroll!.widget.controller!;
      });

      return () => controller.value = null;
    }, []);

    return ElPlatform.isDesktop
        ? Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(e, (
                  event,
                ) {
                  controller.value?.position.pointerScroll(e.scrollDelta.dy);
                });
              }
            },
            child: child,
          )
        : child;
  }
}
