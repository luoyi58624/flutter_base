part of 'media.dart';

// 转场沿用网格里的实际图片，详情页原图按自己的解码时机淡入。
Widget _mediaHeroFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to,
) => ((direction == .push ? from : to).widget as Hero).child;

class _FullMediaImage extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _FullMediaImage(this.entry, {this.fit = BoxFit.contain});
  final _MediaEntry entry;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(320, 4096);
    final height = (MediaQuery.sizeOf(context).height * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(320, 4096);
    return Image(
      image: ResizeImage(entry.original, width: width, height: height, policy: .fit, allowUpscaling: false),
      fit: fit,
      excludeFromSemantics: true,
      frameBuilder: exampleImageFrame,
      errorBuilder: exampleImageError,
    );
  }
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

class _MediaPhotoPage extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaPhotoPage({required this.entry, required this.tag});
  final _MediaEntry entry;
  final Object tag;
  @override
  Widget build(BuildContext context) => Scaffold(
    key: ValueKey('media-photo-preview'),
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(entry.title, maxLines: 1, overflow: .ellipsis),
      leading: CloseButton(),
    ),
    body: SizedBox.expand(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 6,
        child: SizedBox.expand(
          child: Hero(tag: tag, flightShuttleBuilder: _mediaHeroFlight, child: _FullMediaImage(entry)),
        ),
      ),
    ),
  );
}

class _MediaVideoPage extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaVideoPage({required this.entry, this.playerBuilder});
  final _MediaEntry entry;
  final Widget Function(BuildContext, Uri)? playerBuilder;
  @override
  State<_MediaVideoPage> createState() => _MediaVideoPageState();
}

class _MediaVideoPageState extends State<_MediaVideoPage> {
  late final _file = widget.entry.loadFile?.call() ?? Future<File?>.value();
  @override
  Widget build(BuildContext context) => Scaffold(
    key: ValueKey('media-video-preview'),
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(widget.entry.title, maxLines: 1, overflow: .ellipsis),
    ),
    body: FutureBuilder<File?>(
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
    ),
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
