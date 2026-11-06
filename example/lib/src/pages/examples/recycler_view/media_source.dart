part of 'media.dart';

class _MediaEntry {
  _MediaEntry({
    required this.id,
    required this.key,
    required this.title,
    this.date,
    required this.source,
    required this.thumbnail,
    required this.original,
    this.isVideo = false,
    this.duration = 0,
    this.width = 0,
    this.height = 0,
    this.loadFile,
    this.description = '',
    this.coverRatio,
  });
  final int id;
  final String key;
  final String title;
  final DateTime? date;
  final String source;
  final ImageProvider thumbnail;
  final ImageProvider original;
  final bool isVideo;
  final int duration;
  final int width;
  final int height;
  final Future<File?> Function()? loadFile;
  final String description;
  final double? coverRatio;
  double get aspectRatio => coverRatio ?? (width > 0 && height > 0 ? width / height : 1.0).clamp(.6, 1.8).toDouble();

  factory _MediaEntry.demo(int index) {
    final image = AssetImage('assets/recycler_cards/${index.isEven ? 'owl.jpg' : 'owl-2.jpg'}');
    final titles = ['林间的片刻安静', '把日常留在光影里', '慢下来，看看身边的风景', '镜头里的自然观察', '遇见一束温柔的光', '记录旅途中的小发现'];
    final sentences = ['不用赶路，只想记住这一刻。', '换个角度，看见熟悉生活里的新鲜细节。', '光线穿过枝叶，给画面留下自然的层次。', '这些细碎的日常，值得被好好收藏。'];
    return _MediaEntry(
      id: -index - 1,
      key: 'offline-$index',
      title: '${titles[index % titles.length]} · ${index + 1}',
      date: DateTime(2026, 11, 6).subtract(Duration(hours: index)),
      source: '自然影像集',
      thumbnail: ResizeImage(image, width: 320, height: 320, policy: .fit),
      original: image,
      coverRatio: [.7, 1.25, .9, 1.6, .8][index % 5],
      description: [for (var i = 0; i <= index % 4; i++) sentences[(index + i) % sentences.length]].join(),
    );
  }
}

class _MediaLibrary extends ChangeNotifier {
  _MediaLibrary({required this.imagesOnly});
  final bool imagesOnly;
  final items = <_MediaEntry>[];
  final albums = <photos.AssetPathEntity>[];
  final _ids = <String, int>{};
  List<File> _files = [];
  photos.AssetPathEntity? _album;
  String? directory;
  String label = '最近项目';
  String? error;
  bool busy = false;
  bool denied = false;
  bool limited = false;
  bool needsDirectory = false;
  int total = 0;
  int _generation = 0;
  bool _alive = true;
  bool get systemAlbums => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool _current(int generation) => _alive && generation == _generation;
  int _id(String key) => _ids.putIfAbsent(key, () => _ids.length);

  Future<void> open({String? directory, photos.AssetPathEntity? album}) async {
    if (!_alive) return;
    final generation = ++_generation;
    this.directory = directory;
    busy = true;
    denied = limited = needsDirectory = false;
    error = null;
    items.clear();
    _files = [];
    total = 0;
    notifyListeners();
    try {
      if (kIsWeb) {
        error = '请在移动端或桌面端浏览本机媒体';
        return;
      }
      if (directory != null) {
        final root = Directory(path.normalize(Directory(directory).absolute.path));
        this.directory = root.path;
        label = path.basename(root.path);
        await _scanDirectory(root, generation);
        if (!_current(generation)) return;
        _files.sort((a, b) => a.path.compareTo(b.path));
        total = _files.length;
      } else if (systemAlbums) {
        final permission = await photos.PhotoManager.requestPermissionExtend(
          requestOption: photos.PermissionRequestOption(
            androidPermission: photos.AndroidPermission(
              type: imagesOnly ? photos.RequestType.image : photos.RequestType.common,
              mediaLocation: false,
            ),
          ),
        );
        if (!_current(generation)) return;
        limited = permission == photos.PermissionState.limited;
        if (permission != photos.PermissionState.authorized && !limited) {
          denied = true;
          return;
        }
        final paths = await photos.PhotoManager.getAssetPathList(
          type: imagesOnly ? photos.RequestType.image : photos.RequestType.common,
          filterOption: photos.FilterOptionGroup(
            imageOption: photos.FilterOption(needTitle: true),
            videoOption: photos.FilterOption(needTitle: true),
            orders: [photos.OrderOption(type: .createDate, asc: false)],
          ),
        );
        if (!_current(generation)) return;
        albums
          ..clear()
          ..addAll(paths);
        if (paths.isEmpty) return;
        _album = paths.firstWhere((value) => value.id == album?.id, orElse: () => paths.first);
        label = _album!.name;
        final count = await _album!.assetCountAsync;
        if (!_current(generation)) return;
        total = count;
      } else {
        needsDirectory = true;
        return;
      }
      final entries = await _readAll(generation);
      if (!_current(generation)) return;
      items.addAll(entries);
      total = items.length;
    } catch (_) {
      if (_current(generation)) error = '无法读取媒体，请检查访问权限后重试';
    } finally {
      if (_current(generation)) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _scanDirectory(Directory root, int generation) async {
    final pending = [root];
    while (pending.isNotEmpty && _current(generation)) {
      final directory = pending.removeLast();
      try {
        // 递归范围只来自所选目录，跳过链接，避免循环和越过用户选择的目录。
        await for (final entity in directory.list(followLinks: false)) {
          if (!_current(generation)) return;
          if (entity is Directory) {
            pending.add(entity);
          } else if (entity is File && _supported(entity.path, imagesOnly)) {
            _files.add(entity);
          }
        }
      } on FileSystemException {
        if (directory.path == root.path) rethrow;
        // 跳过无权访问的子目录，所选根目录不可读时才显示错误。
      }
    }
  }

  Future<List<_MediaEntry>> _readAll(int generation) async {
    if (total == 0) return [];
    if (directory == null) {
      final entities = await _album!.getAssetListRange(start: 0, end: total);
      if (!_current(generation)) return [];
      return [
        for (final entity in entities)
          _MediaEntry(
            id: _id(entity.id),
            key: entity.id,
            title: path.basenameWithoutExtension(entity.title ?? '本机影像 ${entity.id}'),
            date: entity.createDateTime,
            source: label,
            isVideo: entity.type == photos.AssetType.video,
            duration: entity.duration,
            width: entity.orientatedWidth,
            height: entity.orientatedHeight,
            thumbnail: AssetEntityImageProvider(
              entity,
              isOriginal: false,
              thumbnailSize: photos.ThumbnailSize.square(320),
            ),
            original: AssetEntityImageProvider(entity),
            loadFile: () => entity.file,
          ),
      ];
    }
    final result = <_MediaEntry>[];
    // 首次枚举只记录路径，不串行读取每张原图的头部和文件属性；滚动也不再分页。
    for (final file in _files) {
      if (!_current(generation)) return [];
      final isVideo = _videoExtensions.contains(path.extension(file.path).toLowerCase());
      final ImageProvider thumbnail = isVideo
          ? _VideoThumbnail(file.path, generation)
          : ResizeImage(FileImage(file), width: 320, height: 320, policy: .fit);
      result.add(
        _MediaEntry(
          id: _id(file.path),
          key: file.path,
          title: path.basenameWithoutExtension(file.path),
          source: label,
          isVideo: isVideo,
          thumbnail: thumbnail,
          original: isVideo ? thumbnail : FileImage(file),
          loadFile: () async => file,
        ),
      );
    }
    return result;
  }

  @override
  void dispose() {
    _alive = false;
    _generation++;
    super.dispose();
  }
}

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif', '.heic', '.heif'};
const _videoExtensions = {'.mp4', '.m4v', '.mov', '.mkv', '.webm', '.avi', '.wmv', '.mpeg', '.mpg', '.3gp'};
bool _supported(String value, bool imagesOnly) {
  final extension = path.extension(value).toLowerCase();
  return _imageExtensions.contains(extension) || !imagesOnly && _videoExtensions.contains(extension);
}

// Windows 视频缩略图仍走 Flutter ImageCache；串行生成避免快滚时并发启动大量解码任务。
Future<void> _thumbnailTail = Future.value();

class _VideoThumbnail extends ImageProvider<_VideoThumbnail> {
  // ignore: prefer_const_constructors_in_immutables
  _VideoThumbnail(this.file, this.revision);
  final String file;
  final int revision;
  @override
  Future<_VideoThumbnail> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_VideoThumbnail key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);
  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final request = _thumbnailTail.then(
      (_) => FcNativeVideoThumbnail().saveThumbnailToBytes(srcFile: file, width: 320, height: 320, quality: 80),
    );
    _thumbnailTail = request.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    final bytes = await request;
    if (bytes == null) throw StateError('视频没有可用缩略图');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is _VideoThumbnail && file == other.file && revision == other.revision;
  @override
  int get hashCode => Object.hash(file, revision);
}

String _mediaDate(DateTime date) => '${date.year}年${date.month}月${date.day}日';
String _duration(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
