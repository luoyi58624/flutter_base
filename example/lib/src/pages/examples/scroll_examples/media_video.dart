part of 'media.dart';

class _AlbumVideoPoster extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _AlbumVideoPoster(this.entry, {this.fit = BoxFit.contain});

  final _MediaEntry entry;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final hasVideoSize = fit == .contain && entry.width > 0 && entry.height > 0;
    final cover = Image(
      image: entry.thumbnail,
      width: double.infinity,
      height: double.infinity,
      fit: hasVideoSize ? .cover : fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Center(child: Icon(Icons.videocam_outlined, color: Colors.white54)),
    );
    // 系统相册的封面可能被裁成方图，按视频尺寸固定它在画布中的范围。
    return hasVideoSize
        ? Center(
            child: AspectRatio(aspectRatio: entry.width / entry.height, child: cover),
          )
        : cover;
  }
}

class _MediaVideoContent extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaVideoContent({
    super.key,
    required this.entry,
    required this.poster,
    required this.showControls,
    this.playerBuilder,
  });

  final _MediaEntry entry;
  final Widget poster;
  final bool showControls;
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
      if (snapshot.connectionState != .done) return widget.poster;
      final file = snapshot.data;
      if (file == null || snapshot.hasError) {
        return Stack(fit: .expand, children: [widget.poster, _videoMessage('此视频暂不可用，请返回相册重试')]);
      }
      return widget.playerBuilder?.call(context, file.uri) ??
          _NativeMediaVideo(source: file.uri, poster: widget.poster, showControls: widget.showControls);
    },
  );
}

Widget _videoMessage(String message) => Align(
  alignment: .bottomCenter,
  child: Padding(
    padding: .all(12),
    child: DecoratedBox(
      decoration: BoxDecoration(color: Colors.black87, borderRadius: .circular(8)),
      child: Padding(
        padding: .all(12),
        child: Text(
          message,
          textAlign: .center,
          style: TextStyle(color: Colors.white),
        ),
      ),
    ),
  ),
);

class _NativeMediaVideo extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _NativeMediaVideo({required this.source, required this.poster, required this.showControls});

  final Uri source;
  final Widget poster;
  final bool showControls;

  @override
  State<_NativeMediaVideo> createState() => _NativeMediaVideoState();
}

class _NativeMediaVideoState extends State<_NativeMediaVideo> with WidgetsBindingObserver {
  player.Player? _player;
  video.VideoController? _controller;
  StreamSubscription<String>? _errors;
  bool _firstFrame = false;
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
      final controller = _controller = video.VideoController(instance);
      _errors = instance.stream.error.listen((_) {
        if (mounted) setState(() => _error = '视频无法播放，请检查文件是否完整或格式是否受支持');
      });
      await instance.open(player.Media(widget.source.toString()));
      if (!mounted) return;
      // open 完成时纹理可能还未显示，继续用封面盖住空帧。
      await controller.waitUntilFirstFrameRendered;
      if (mounted) setState(() => _firstFrame = true);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法打开视频，请返回后重试');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != .resumed) unawaited(_player?.pause());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final instance = _player;
    final error = _error;
    return Stack(
      fit: .expand,
      children: [
        if (controller != null)
          IgnorePointer(
            child: video.Video(
              controller: controller,
              fit: .contain,
              fill: Colors.transparent,
              controls: video.NoVideoControls,
            ),
          ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _firstFrame && error == null ? 0 : 1,
            duration: Duration(milliseconds: 120),
            child: ColoredBox(color: Colors.black, child: widget.poster),
          ),
        ),
        if (error != null)
          _videoMessage(error)
        else if (instance != null && widget.showControls)
          Align(alignment: .bottomCenter, child: _AlbumVideoControls(instance)),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_errors?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }
}

class _AlbumVideoControls extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _AlbumVideoControls(this.instance);

  final player.Player instance;

  @override
  Widget build(BuildContext context) {
    final playing = useStream(instance.stream.playing, initialData: instance.state.playing).data ?? false;
    final duration = useStream(instance.stream.duration, initialData: instance.state.duration).data ?? Duration.zero;
    final position = useStream(instance.stream.position, initialData: instance.state.position).data ?? Duration.zero;
    final muted = useStream(instance.stream.volume, initialData: instance.state.volume).data == 0;
    final seek = useState<double?>(null);
    final end = math.max(1, duration.inMilliseconds).toDouble();
    final current = (seek.value ?? position.inMilliseconds.toDouble()).clamp(0.0, end);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: .topCenter, end: .bottomCenter, colors: [Colors.transparent, Colors.black87]),
      ),
      child: Padding(
        padding: .symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: playing ? '暂停' : '播放',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () => unawaited(instance.playOrPause()),
            ),
            Text(_duration(current ~/ 1000), style: TextStyle(fontSize: 12)),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white38,
                  thumbColor: Colors.white,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 4),
                ),
                child: Slider(
                  value: current,
                  max: end,
                  semanticFormatterCallback: (value) => _duration(value ~/ 1000),
                  onChanged: duration > Duration.zero ? (value) => seek.value = value : null,
                  onChangeEnd: (value) async {
                    await instance.seek(Duration(milliseconds: value.round()));
                    if (context.mounted) seek.value = null;
                  },
                ),
              ),
            ),
            IconButton(
              tooltip: muted ? '取消静音' : '静音',
              icon: Icon(muted ? Icons.volume_off_outlined : Icons.volume_up_outlined, size: 20),
              onPressed: () => unawaited(instance.setVolume(muted ? 100 : 0)),
            ),
          ],
        ),
      ),
    );
  }
}
