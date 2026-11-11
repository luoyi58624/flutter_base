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
  _FullMediaImage(this.entry, {this.fit = BoxFit.contain});
  final _MediaEntry entry;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => Image(
    image: _previewImageProvider(context, entry),
    fit: fit,
    excludeFromSemantics: true,
    frameBuilder: exampleImageFrame,
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

class _MediaGalleryPageState extends State<_MediaGalleryPage> {
  late final _preview = ElPreviewController(initialIndex: widget.initialIndex);
  Animation<double>? _routeAnimation;
  bool _closing = false;

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

  Widget _item(BuildContext context, int index) {
    final entry = widget.entries[index];
    final active = index == _preview.index;
    final playing = entry.isVideo && active && !_closing && (_routeAnimation?.isCompleted ?? true);
    final image = entry.albumThumbnail.value?.image;
    final ratio = entry.width > 0 && entry.height > 0
        ? entry.width / entry.height
        : image != null
        ? image.width / image.height
        : null;
    final content = playing
        ? _MediaVideoContent(key: ValueKey(entry.key), entry: entry, playerBuilder: widget.playerBuilder)
        : _FullMediaImage(entry);
    final media = ratio == null ? SizedBox.expand(child: content) : AspectRatio(aspectRatio: ratio, child: content);
    return Center(
      child: active
          ? Hero(
              tag: widget.tag(entry),
              flightShuttleBuilder: (context, animation, direction, from, to) {
                // 远距离切换后格子已布局时，缩略图仍可能在等解码。
                final shuttle = entry.albumThumbnail.value == null
                    ? _FullMediaImage(entry, fit: .cover)
                    : _mediaHeroFlight(context, animation, direction, from, to);
                return KeyedSubtree(key: ValueKey(('media-gallery-flight', widget.tag(entry))), child: shuttle);
              },
              child: media,
            )
          : media,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = _preview.index;
    final entry = widget.entries[index];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        key: ValueKey('media-gallery-preview'),
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: CloseButton(onPressed: _close),
          title: Text(entry.title, maxLines: 1, overflow: .ellipsis),
          actions: [
            IconButton(
              tooltip: '上一项',
              onPressed: _closing || index == 0 ? null : () => _preview.animateToPage(index - 1),
              icon: Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: '下一项',
              onPressed: _closing || index == widget.entries.length - 1
                  ? null
                  : () => _preview.animateToPage(index + 1),
              icon: Icon(Icons.chevron_right),
            ),
          ],
        ),
        body: ElPreviewView(
          controller: _preview,
          itemCount: widget.entries.length,
          itemBuilder: _item,
          maxScale: entry.isVideo ? 1 : 4,
          enableRotation: !entry.isVideo,
          enableDoubleTap: !entry.isVideo,
          enableWheelZoom: !entry.isVideo,
          onIndexChanged: (index) {
            if (_closing) return;
            widget.reveal(index);
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onTransition);
    _preview.dispose();
    super.dispose();
  }
}

class _MediaVideoContent extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaVideoContent({super.key, required this.entry, this.playerBuilder});
  final _MediaEntry entry;
  final Widget Function(BuildContext, Uri)? playerBuilder;
  @override
  State<_MediaVideoContent> createState() => _MediaVideoContentState();
}

class _MediaVideoContentState extends State<_MediaVideoContent> {
  late final _file = widget.entry.loadFile?.call() ?? Future<File?>.value();
  @override
  Widget build(BuildContext context) => FutureBuilder<File?>(
    key: ValueKey('media-video-preview'),
    future: _file,
    builder: (context, snapshot) {
      if (snapshot.connectionState != .done) return Center(child: CircularProgressIndicator());
      final file = snapshot.data;
      if (file == null || snapshot.hasError) {
        return Center(
          child: Text('此视频暂不可用，请返回相册重试', style: TextStyle(color: Colors.white)),
        );
      }
      return widget.playerBuilder?.call(context, file.uri) ?? _NativeMediaVideo(source: file.uri);
    },
  );
}

class _NativeMediaVideo extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _NativeMediaVideo({required this.source});
  final Uri source;
  @override
  State<_NativeMediaVideo> createState() => _NativeMediaVideoState();
}

class _NativeMediaVideoState extends State<_NativeMediaVideo> with WidgetsBindingObserver {
  player.Player? _player;
  video.VideoController? _controller;
  StreamSubscription<String>? _errors;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      player.MediaKit.ensureInitialized();
      final instance = _player = player.Player();
      _controller = video.VideoController(instance);
      _errors = instance.stream.error.listen((_) {
        if (mounted) setState(() => _error = '视频无法播放，请检查文件是否完整或格式是否受支持');
      });
      await instance.open(player.Media(widget.source.toString()));
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法打开视频，请返回后重试');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != .resumed) unawaited(_player?.pause() ?? Future<void>.value());
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: .all(24),
          child: Text(
            _error!,
            textAlign: .center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) return Center(child: CircularProgressIndicator());
    return Center(
      child: video.Video(controller: controller, fit: .contain),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_errors?.cancel() ?? Future<void>.value());
    unawaited(_player?.dispose() ?? Future<void>.value());
    super.dispose();
  }
}
