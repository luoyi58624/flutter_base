part of 'media.dart';

// 转场沿用网格里的实际图片，详情页原图按自己的解码时机淡入。
Widget _mediaHeroFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to,
) => ((direction == .push ? from : to).widget as Hero).child;

ImageProvider _previewImageProvider(BuildContext context, _MediaEntry entry) {
  final size = MediaQuery.sizeOf(context);
  final ratio = MediaQuery.devicePixelRatioOf(context);
  final width = (size.width * ratio).ceil().clamp(320, 4096);
  final height = (size.height * ratio).ceil().clamp(320, 4096);
  return ResizeImage(entry.original, width: width, height: height, policy: .fit, allowUpscaling: false);
}

class _FullMediaImage extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _FullMediaImage(this.entry, {this.fit = BoxFit.contain, this.showThumbnail = false});
  final _MediaEntry entry;
  final BoxFit fit;
  final bool showThumbnail;
  @override
  Widget build(BuildContext context) => Image(
    image: _previewImageProvider(context, entry),
    fit: fit,
    excludeFromSemantics: true,
    frameBuilder: showThumbnail
        ? (_, child, frame, _) => frame == null
              ? Image(image: entry.thumbnail, fit: fit, excludeFromSemantics: true, errorBuilder: exampleImageError)
              : child
        : exampleImageFrame,
    errorBuilder: exampleImageError,
  );
}

class _MediaDetailsPage extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaDetailsPage({required this.entry, required this.tag});
  final _MediaEntry entry;
  final Object tag;
  @override
  Widget build(BuildContext context) => Scaffold(
    key: ValueKey('media-details'),
    appBar: AppBar(title: Text('影像详情')),
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Hero(
              tag: tag,
              flightShuttleBuilder: _mediaHeroFlight,
              child: _FullMediaImage(entry, fit: .cover),
            ),
          ),
          Padding(
            padding: .all(12),
            child: ElCard(
              style: ElStyle(padding: .all(14)),
              child: Column(
                crossAxisAlignment: .stretch,
                spacing: 12,
                children: [
                  _caption(entry.title, size: 18, bold: true, lines: 3),
                  _caption(
                    entry.date == null ? entry.source : '${_mediaDate(entry.date!)} · ${entry.source}',
                    size: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    lines: 2,
                  ),
                  if (entry.width > 0 && entry.height > 0) _caption('图片尺寸 ${entry.width} × ${entry.height}', size: 12),
                  _caption(
                    entry.description.isEmpty ? '这张照片来自本机影像。用一张图片留住当时的光线、色彩和心情，也给日常留下一份可以回看的记录。' : entry.description,
                    size: 13,
                    lines: 12,
                  ),
                  _caption('从细节看见故事', size: 15, bold: true),
                  _caption(
                    '有时候，值得记住的不是特别盛大的瞬间，而是一个熟悉的场景、一束刚好落下的光，或旅途中偶然发现的小风景。慢下来再看一次，画面里总能找到新的细节。',
                    size: 13,
                    lines: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MediaGalleryPage extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaGalleryPage({
    required this.entries,
    required this.initialIndex,
    required this.tag,
    required this.reveal,
    this.playerBuilder,
  });

  final List<_MediaEntry> entries;
  final int initialIndex;
  final Object Function(_MediaEntry) tag;
  final ValueChanged<int> reveal;
  final Widget Function(BuildContext, Uri)? playerBuilder;

  @override
  State<_MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends State<_MediaGalleryPage> with SingleTickerProviderStateMixin {
  static const _thumbnailExtent = 43.0;
  late final _preview = ElPreviewController(initialIndex: widget.initialIndex);
  late final _filmstrip = ScrollController(initialScrollOffset: widget.initialIndex * _thumbnailExtent);
  late final _pull = AnimationController.unbounded(vsync: this);
  late int _settledIndex = widget.initialIndex;
  Animation<double>? _routeAnimation;
  double? _stripWidth;
  bool _showChrome = true;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _preview.page.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    _syncFilmstrip();
    final index = _preview.index;
    if (_closing || _settledIndex == index || _preview.page.value != index) return;
    // 旧画面随翻页滑出，等新页面归位后才切换播放器。
    setState(() => _settledIndex = index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onTransition);
    _routeAnimation = animation;
    animation?.addStatusListener(_onTransition);
  }

  void _onTransition(AnimationStatus status) {
    if (status == .completed) setState(() {});
  }

  Future<void> _close() async {
    if (_closing) return;
    final index = _preview.index;
    if ((_preview.page.value - index).abs() > precisionErrorTolerance) _preview.jumpToPage(index);
    setState(() => _closing = true);
    widget.reveal(index);
    // 让网格先完成回收换绑，同时让视频切回封面，随后 Hero 才能读取正确的缩略图。
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  void _syncFilmstrip() {
    if (!_filmstrip.hasClients || !_filmstrip.position.hasContentDimensions) return;
    final position = _filmstrip.position;
    final center = (_preview.page.value + .5) * _thumbnailExtent;
    final target = (center - position.viewportDimension / 2).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() > .5) position.jumpTo(target);
  }

  void _select(int index) {
    if (!_closing && index >= 0 && index < widget.entries.length) unawaited(_preview.animateToPage(index));
  }

  void _endPull(DragEndDetails details) {
    if (_closing) return;
    if (_pull.value >= 110 || _pull.value >= 24 && (details.primaryVelocity ?? 0) >= 700) {
      unawaited(_close());
    } else {
      _pull.animateTo(0, duration: Duration(milliseconds: 180), curve: Curves.easeOutCubic);
    }
  }

  Widget _item(BuildContext context, int index) {
    final entry = widget.entries[index];
    final active = index == _preview.index;
    final playing = entry.isVideo && index == _settledIndex && !_closing && (_routeAnimation?.isCompleted ?? true);
    final image = entry.albumThumbnail.value?.image;
    final ratio = entry.width > 0 && entry.height > 0
        ? entry.width / entry.height
        : image != null
        ? image.width / image.height
        : null;
    final poster = entry.isVideo ? _AlbumVideoPoster(entry) : _FullMediaImage(entry, showThumbnail: true);
    final content = playing
        ? _MediaVideoContent(
            key: ValueKey(entry.key),
            entry: entry,
            poster: poster,
            showControls: _showChrome,
            playerBuilder: widget.playerBuilder,
          )
        : poster;
    final media = playing || ratio == null
        ? SizedBox.expand(child: content)
        : AspectRatio(aspectRatio: ratio, child: content);
    return Center(
      child: HeroMode(
        enabled: active,
        child: Hero(
          tag: widget.tag(entry),
          flightShuttleBuilder: (context, animation, direction, from, to) {
            // 远距离切换后格子已布局时，缩略图仍可能在等解码。
            final shuttle = entry.albumThumbnail.value == null
                ? entry.isVideo
                      ? _AlbumVideoPoster(entry, fit: .cover)
                      : _FullMediaImage(entry, fit: .cover)
                : _mediaHeroFlight(context, animation, direction, from, to);
            return KeyedSubtree(key: ValueKey(('media-gallery-flight', widget.tag(entry))), child: shuttle);
          },
          child: media,
        ),
      ),
    );
  }

  Widget _filmstripView(int selected) => SizedBox(
    height: 44,
    child: LayoutBuilder(
      builder: (_, constraints) {
        if (_stripWidth != constraints.maxWidth) {
          _stripWidth = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncFilmstrip();
          });
        }
        return ElScrollView.sliver(
          key: ValueKey('media-gallery-filmstrip'),
          axis: .horizontal,
          controller: _filmstrip,
          slivers: [
            SliverFixedExtentList.builder(
              itemExtent: _thumbnailExtent,
              itemCount: widget.entries.length,
              itemBuilder: (_, index) {
                final entry = widget.entries[index];
                final active = selected == index;
                return Padding(
                  padding: .symmetric(horizontal: 2, vertical: 2),
                  child: ElButtonView(
                    key: ValueKey(('media-gallery-thumb', index)),
                    semanticLabel: entry.title,
                    selected: active,
                    onPressed: () => _select(index),
                    child: DecoratedBox(
                      position: .foreground,
                      decoration: BoxDecoration(
                        border: active ? Border.all(color: Colors.white, width: 2) : null,
                        borderRadius: .circular(5),
                      ),
                      child: ClipRRect(
                        borderRadius: .circular(5),
                        child: Image(
                          image: entry.thumbnail,
                          width: double.infinity,
                          height: double.infinity,
                          fit: .cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: Color(0xff252525),
                            child: Icon(entry.isVideo ? Icons.videocam_outlined : Icons.image_outlined, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final index = _preview.index;
    final entry = widget.entries[index];
    final date = entry.date;
    final header = SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(tooltip: '关闭', onPressed: _close, icon: Icon(Icons.arrow_back)),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              mainAxisAlignment: .center,
              children: [
                Text(
                  date == null ? entry.title : '${date.month}月${date.day}日',
                  key: ValueKey('media-gallery-title'),
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: .w600),
                ),
                if (date != null)
                  Text(
                    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final footer = Column(
      mainAxisSize: .min,
      children: [
        _filmstripView(index),
        SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: .center,
            children: [
              IconButton(
                tooltip: '上一项',
                onPressed: _closing || index == 0 ? null : () => _select(index - 1),
                icon: Icon(Icons.chevron_left),
              ),
              Text('${index + 1} / ${widget.entries.length}', style: TextStyle(fontSize: 12, color: Colors.white70)),
              IconButton(
                tooltip: '下一项',
                onPressed: _closing || index == widget.entries.length - 1 ? null : () => _select(index + 1),
                icon: Icon(Icons.chevron_right),
              ),
              if (!entry.isVideo) ...[
                IconButton(tooltip: '旋转', onPressed: _preview.rotateBy, icon: Icon(Icons.rotate_right)),
                IconButton(tooltip: '还原', onPressed: _preview.resetTransform, icon: Icon(Icons.fit_screen_outlined)),
              ],
            ],
          ),
        ),
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        key: ValueKey('media-gallery-preview'),
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: _pull,
          child: ElPreviewView(
            controller: _preview,
            itemCount: widget.entries.length,
            itemBuilder: _item,
            pageSpacing: 18,
            maxScale: entry.isVideo ? 1 : 4,
            enableRotation: !entry.isVideo,
            enableDoubleTap: !entry.isVideo,
            enableWheelZoom: !entry.isVideo,
            onTap: () => setState(() => _showChrome = !_showChrome),
            onVerticalDragStart: (_) => _pull.stop(),
            onVerticalDragUpdate: (details) {
              if (!_closing) _pull.value = math.max(0, _pull.value + (details.primaryDelta ?? 0));
            },
            onVerticalDragEnd: _endPull,
            onIndexChanged: (index) {
              if (_closing) return;
              _onPageChanged();
              widget.reveal(index);
              setState(() {});
            },
          ),
          builder: (context, child) {
            final progress = (_pull.value / 300).clamp(0.0, 1.0);
            Widget chrome(Widget child) => IgnorePointer(
              ignoring: !_showChrome || _pull.value > 0,
              child: Opacity(opacity: _showChrome ? 1 - progress : 0, child: child),
            );
            return ColoredBox(
              color: Colors.black.withValues(alpha: 1 - progress * .85),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(foregroundColor: Colors.white, disabledForegroundColor: Colors.white38),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(color: Colors.white),
                  child: SafeArea(
                    child: Column(
                      children: [
                        chrome(header),
                        Expanded(
                          child: Transform.translate(
                            offset: Offset(0, _pull.value),
                            child: Transform.scale(scale: 1 - progress * .24, child: child),
                          ),
                        ),
                        chrome(footer),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onTransition);
    _preview.page.removeListener(_onPageChanged);
    _pull.dispose();
    _filmstrip.dispose();
    _preview.dispose();
    super.dispose();
  }
}
