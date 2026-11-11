part of 'index.dart';

class _Preview extends StatefulWidget {
  const _Preview({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.origin,
    required this.imageSize,
    required this.desktop,
    required this.onClosed,
    required this.destination,
  });

  final List<ImageProvider> images;
  final int initialIndex;
  final Rect? origin;
  final Size? imageSize;
  final bool desktop;
  final VoidCallback onClosed;
  final Rect? Function(int index) destination;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> with TickerProviderStateMixin {
  late final _controller = ElPreviewController(initialIndex: widget.initialIndex);
  late final _flight = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  late final _return = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  final _focus = FocusScopeNode();
  final _dismiss = ValueNotifier(0.0);
  final _sizes = <int, Size>{};
  ImageStream? _stream;
  ImageStreamListener? _listener;
  FocusNode? _previousFocus;
  Size _size = Size.zero;
  Rect? _closeFrom;
  Rect? _closeTo;
  double _closeAngle = 0;
  double _returnFrom = 0;
  bool _closing = false;
  bool _entered = false;
  bool _chrome = true;

  @override
  void initState() {
    super.initState();
    if (widget.imageSize != null) _sizes[widget.initialIndex] = widget.imageSize!;
    _return.addListener(() => _dismiss.value = _returnFrom * (1 - Curves.easeOutCubic.transform(_return.value)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.desktop) {
        _previousFocus = FocusManager.instance.primaryFocus;
        _focus.requestFocus();
      }
      _flight.forward().then((_) {
        if (mounted && !_closing) setState(() => _entered = true);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observeImage();
  }

  void _observeImage() {
    _unsubscribe();
    final index = _controller.index;
    _stream = widget.images[index].resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, synchronousCall) {
        final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
        info.dispose();
        if (!mounted || _sizes[index] == size) return;
        setState(() => _sizes[index] = size);
      },
      onError: (Object error, StackTrace? stack) {
        // 图片自身显示失败占位，动画和关闭不依赖加载成功。
      },
    );
    _stream!.addListener(_listener!);
  }

  void _unsubscribe() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  Rect _imageRect(int index) {
    final natural = _sizes[index] ?? widget.origin?.size ?? _size;
    final fitted = applyBoxFit(BoxFit.contain, natural, _size).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & _size);
  }

  void close() {
    if (_closing) return;
    final base = _imageRect(_controller.index);
    final drag = _dismiss.value;
    final dragScale = 1 - (drag.abs() / 300).clamp(0.0, 1.0) * 0.25;
    final pageOffset = (_controller.index - _controller.page.value) * (_size.width + 16);
    final scale = _controller.scale * dragScale;
    _closeFrom = Rect.fromCenter(
      center: base.center + (_controller.translation + Offset(pageOffset, 0)) * dragScale + Offset(0, drag),
      width: base.width * scale,
      height: base.height * scale,
    );
    _closeAngle = _controller.rotation;
    _closeTo = widget.destination(_controller.index);
    if (!_entered) {
      _closeFrom = Rect.lerp(widget.origin ?? base, base, Curves.easeOutCubic.transform(_flight.value));
    }
    _return.stop();
    setState(() => _closing = true);
    _flight.forward(from: 0).then((_) {
      if (mounted) widget.onClosed();
    });
  }

  void _page(int delta) {
    if (_closing || !_entered) return;
    final target = _controller.index + delta;
    if (target >= 0 && target < widget.images.length) _controller.animateToPage(target);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      close();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _page(-1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _page(1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _unsubscribe();
    _flight.dispose();
    _return.dispose();
    _controller.dispose();
    _dismiss.dispose();
    _focus.dispose();
    final previous = _previousFocus;
    if (previous != null && previous.context?.mounted == true && previous.canRequestFocus) previous.requestFocus();
    super.dispose();
  }

  Widget _image(int index, {BoxFit fit = BoxFit.contain}) => Image(
    image: widget.images[index],
    fit: fit,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, synchronous) =>
        frame != null || synchronous ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
    errorBuilder: (context, error, stack) => const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white70, size: 40),
          SizedBox(height: 12),
          Text('图片加载失败', style: TextStyle(color: Colors.white70)),
        ],
      ),
    ),
  );

  Widget _button(String label, IconData icon, VoidCallback? action) => IconButton(
    tooltip: label,
    onPressed: action,
    color: Colors.white,
    disabledColor: Colors.white24,
    icon: Icon(icon),
  );

  Widget _controls() {
    final count = widget.images.length;
    final index = _controller.index;
    final counter = Text('${index + 1} / $count', style: const TextStyle(color: Colors.white, fontSize: 16));
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                if (!widget.desktop) _button('关闭', Icons.close, close),
                Expanded(child: Center(child: counter)),
                if (widget.desktop)
                  _button('关闭', Icons.close, close)
                else
                  _button('还原', Icons.fit_screen_outlined, _controller.resetTransform),
              ],
            ),
          ),
          if (widget.desktop) ...[
            if (count > 1) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _button('上一张', Icons.chevron_left, index > 0 ? () => _page(-1) : null),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _button('下一张', Icons.chevron_right, index + 1 < count ? () => _page(1) : null),
                ),
              ),
            ],
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: const Color(0xCC303030),
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _button('缩小', Icons.zoom_out, () => _controller.zoomTo(_controller.scale / 1.25)),
                        _button('放大', Icons.zoom_in, () => _controller.zoomTo(_controller.scale * 1.25)),
                        _button('向左旋转', Icons.rotate_left, () => _controller.rotateBy(-math.pi / 2)),
                        _button('向右旋转', Icons.rotate_right, _controller.rotateBy),
                        _button('还原', Icons.fit_screen_outlined, _controller.resetTransform),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      final preview = ElPreviewView(
        controller: _controller,
        itemCount: widget.images.length,
        itemBuilder: (context, index) => _image(index),
        onIndexChanged: (_) {
          _observeImage();
          setState(() {});
        },
        onTap: widget.desktop ? null : () => setState(() => _chrome = !_chrome),
        onVerticalDragStart: widget.desktop ? null : (_) => _return.stop(),
        onVerticalDragUpdate: widget.desktop ? null : (details) => _dismiss.value += details.primaryDelta ?? 0,
        onVerticalDragEnd: widget.desktop
            ? null
            : (details) {
                if (_dismiss.value.abs() > 120 || (details.primaryVelocity ?? 0).abs() > 800) {
                  close();
                } else {
                  _returnFrom = _dismiss.value;
                  _return.forward(from: 0);
                }
              },
      );
      return FocusScope(
        node: _focus,
        onKeyEvent: _key,
        child: BlockSemantics(
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: '图片预览',
            explicitChildNodes: true,
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedBuilder(
                animation: Listenable.merge([_flight, _dismiss]),
                child: preview,
                builder: (context, child) {
                  final k = Curves.easeOutCubic.transform(_flight.value);
                  final visibility = _closing ? 1 - k : k;
                  final progress = (_dismiss.value.abs() / 300).clamp(0.0, 1.0);
                  final flying = !_entered || _closing;
                  final base = _imageRect(_controller.index);
                  final rect = _closing
                      ? Rect.lerp(_closeFrom, _closeTo ?? _closeFrom, k)!
                      : Rect.lerp(widget.origin ?? base, base, k)!;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // 覆盖整屏并吞掉指针，透明动画阶段也不能点穿到底层页面。
                      ModalBarrier(
                        color: Colors.black.withValues(alpha: visibility * (1 - progress * 0.85)),
                        dismissible: false,
                      ),
                      IgnorePointer(
                        ignoring: flying,
                        child: Opacity(
                          opacity: flying ? 0 : 1,
                          child: Transform.translate(
                            offset: Offset(0, _dismiss.value),
                            child: Transform.scale(scale: 1 - progress * 0.25, child: child),
                          ),
                        ),
                      ),
                      if (flying)
                        Positioned.fromRect(
                          rect: rect,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: (_closing && _closeTo == null) || (!_closing && widget.origin == null)
                                  ? visibility
                                  : 1,
                              child: Transform.rotate(
                                angle: _closing ? _closeAngle * (1 - k) : 0,
                                child: ClipRect(child: _image(_controller.index, fit: BoxFit.cover)),
                              ),
                            ),
                          ),
                        ),
                      IgnorePointer(
                        ignoring: flying || !_chrome,
                        child: Opacity(
                          opacity: flying ? 0 : 1,
                          child: AnimatedOpacity(
                            opacity: _chrome ? 1 : 0,
                            duration: const Duration(milliseconds: 160),
                            child: _controls(),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
