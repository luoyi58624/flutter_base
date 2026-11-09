import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:file_selector/file_selector.dart' as selector;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show SliverGridDelegate, SliverGridLayout, SliverConstraints, SliverGridGeometry;
import 'package:flutter_base/flutter_base.dart';
import 'package:media_kit/media_kit.dart' as player;
import 'package:media_kit_video/media_kit_video.dart' as video;
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart' as photos;
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../../widgets/example_image.dart';
import '../../../widgets/example_scrollbar.dart';
import '../../example_page.dart';
import '../bibi/feed.dart' show bibiVideoCount, buildBibiVideoCard;
import 'album_thumbnails.dart';

part 'media_source.dart';
part 'media_cards.dart';
part 'media_preview.dart';
part 'media_grid.dart';

/// 用本机照片作为封面，展示网格卡片、Hero 转场和图文详情。
class RecyclerVideoGridPage extends StatelessWidget {
  /// 创建视频流卡片示例；directory 递归包含本地图片目录及其子目录。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerVideoGridPage({super.key, this.directory});

  /// 初始目录，未提供时移动端请求相册访问，桌面显示目录选择入口。
  final String? directory;

  @override
  Widget build(BuildContext context) => _MediaPage(kind: .feed, directory: directory);
}

/// 浏览本机照片与视频，点击后分别进入图片预览或视频播放页。
class RecyclerGalleryPage extends StatelessWidget {
  /// 创建相册示例；播放器构建器用于替换原生播放界面或进行无头测试。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerGalleryPage({super.key, this.directory, this.videoPlayerBuilder});

  /// 递归读取的初始目录，移动端未提供时读取系统相册。
  final String? directory;

  /// 自定义本地视频播放界面，默认使用 media_kit 并随页面退出释放播放器。
  final Widget Function(BuildContext context, Uri source)? videoPlayerBuilder;

  @override
  Widget build(BuildContext context) =>
      _MediaPage(kind: .album, directory: directory, videoPlayerBuilder: videoPlayerBuilder);
}

/// 对照官方网格与自然尺寸回收瀑布流。
class RecyclerWaterfallPage extends StatelessWidget {
  /// 创建万条离线瀑布流，也可指定目录改用本机照片。
  // ignore: prefer_const_constructors_in_immutables
  RecyclerWaterfallPage({super.key, this.directory});

  /// 指定本机图片目录；未提供时使用包内离线图片与变长文案。
  final String? directory;

  @override
  Widget build(BuildContext context) => _MediaPage(kind: .waterfall, directory: directory);
}

enum _MediaKind { feed, album, waterfall }

enum _MediaGridMode {
  official('SliverGrid'),
  recycler('ElSliverRecyclerGrid'),
  localCards('本机卡片'),
  bibiCards('Bibi 卡片');

  const _MediaGridMode(this.label);
  final String label;
}

class _MediaPage extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  _MediaPage({required this.kind, this.directory, this.videoPlayerBuilder});
  final _MediaKind kind;
  final String? directory;
  final Widget Function(BuildContext, Uri)? videoPlayerBuilder;

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  final _controller = ScrollController(keepScrollOffset: false);
  final _heroScope = Object();
  final _demoItems = <int, _MediaEntry>{};
  late final _library = _MediaLibrary(imagesOnly: widget.kind != .album);
  late bool _demo = widget.kind == .waterfall && widget.directory == null;
  _MediaGridMode _mode = .recycler;
  bool _bibiCards = false;
  late final _albumThumbnails = AlbumThumbnailQueue();
  int _albumColumns = 0;
  double _albumCellExtent = 0;
  double _albumPixels = 0;
  int _albumDirection = 1;
  (int, int, int)? _thumbnailWindow;
  bool _thumbnailUpdateScheduled = false;

  bool get _featured => widget.kind == .feed && _library.items.isNotEmpty;
  int get _itemCount => _demo ? 10000 : _library.items.length;
  String get _title => switch (widget.kind) {
    .feed => '视频流卡片',
    .album => '本机相册',
    .waterfall => '瀑布流',
  };

  @override
  void initState() {
    super.initState();
    if (widget.kind == .album) {
      _controller.addListener(_scheduleThumbnails);
    }
    _library.addListener(_changed);
    if (!_demo) unawaited(_library.open(directory: widget.directory));
  }

  void _changed() {
    if (!mounted) return;
    _thumbnailWindow = null;
    _scheduleThumbnails();
    if (!_bibiCards) setState(() {});
  }

  void _scheduleThumbnails() {
    if (widget.kind != .album || _thumbnailUpdateScheduled) return;
    _thumbnailUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _thumbnailUpdateScheduled = false;
      if (mounted) _updateThumbnails();
    });
  }

  void _updateThumbnails() {
    final controller = _controller;
    if (_itemCount == 0 || _albumCellExtent <= 0 || !controller.hasClients || !controller.position.haveDimensions) {
      _thumbnailWindow = null;
      _albumThumbnails.update([], []);
      return;
    }
    final position = controller.position;
    final pixels = position.pixels.clamp(0.0, position.maxScrollExtent);
    if (pixels != _albumPixels) _albumDirection = pixels > _albumPixels ? 1 : -1;
    _albumPixels = pixels;
    // 三种相册容器都是无间距的正方形网格，使用完成布局后的同一组坐标。
    final first = math.min(_itemCount, (pixels / _albumCellExtent).floor() * _albumColumns);
    final last = math.min(
      _itemCount,
      ((pixels + position.viewportDimension) / _albumCellExtent).ceil() * _albumColumns,
    );
    final window = (first, last, _albumDirection);
    if (window == _thumbnailWindow) return;
    _thumbnailWindow = window;
    final ahead = _albumDirection > 0
        ? [for (var index = last; index < math.min(_itemCount, last + _albumColumns * 2); index++) index]
        : [for (var index = first - 1; index >= math.max(0, first - _albumColumns * 2); index--) index];
    _albumThumbnails.update([
      for (var index = first; index < last; index++) _entryAt(index).albumThumbnail,
    ], ahead.map((index) => _entryAt(index).albumThumbnail));
  }

  _MediaEntry _entryAt(int index) =>
      _demo ? _demoItems.putIfAbsent(index, () => _MediaEntry.demo(index)) : _library.items[index];
  Object _tag(_MediaEntry entry, bool featured) => (_heroScope, entry.key, featured);

  void _open(_MediaEntry entry, bool featured) {
    final tag = _tag(entry, featured);
    final Widget page;
    if (widget.kind != .album) {
      page = _MediaDetailsPage(entry: entry, tag: tag);
    } else if (entry.isVideo) {
      page = _MediaVideoPage(entry: entry, playerBuilder: widget.videoPlayerBuilder);
    } else {
      page = _MediaPhotoPage(entry: entry, tag: tag);
    }
    final navigator = Navigator.of(context);
    // 独立示例的组件主题位于来源路由内，详情路由需要继承它。
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    navigator.push<void>(MaterialPageRoute(builder: (_) => themes.wrap(page)));
  }

  Future<void> _chooseSource() async {
    if (_library.systemAlbums) {
      _demo = false;
      await _library.open();
    } else {
      final directory = await selector.getDirectoryPath(
        initialDirectory: _library.directory,
        confirmButtonText: '使用此文件夹',
      );
      if (directory == null || !mounted) return;
      _demo = false;
      await _library.open(directory: directory);
    }
  }

  void _chooseMode(_MediaGridMode mode) {
    if (mode case .localCards || .bibiCards) {
      final bibiCards = mode == .bibiCards;
      if (_bibiCards != bibiCards) setState(() => _bibiCards = bibiCards);
      return;
    }
    if (_mode == mode) return;
    _thumbnailWindow = null;
    setState(() => _mode = mode);
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  Widget _officialTile(int index, {bool featured = false}) => _OwnedMediaTile(
    key: ValueKey((featured, _entryAt(index).key)),
    entry: _entryAt(index),
    kind: widget.kind,
    featured: featured,
    tag: _tag(_entryAt(index), featured),
    onOpen: (entry) => _open(entry, featured),
    fixedCover: true,
  );

  Widget _bibiGrid(BuildContext context, BoxConstraints constraints) {
    final padding = EdgeInsets.fromLTRB(8, 4, 8, 9);
    final columnGap = 8.0;
    final cardWidth = math.max(0.0, (constraints.maxWidth - padding.horizontal - columnGap) / 2);
    final pixelRatio = View.of(context).devicePixelRatio;
    // 用同一张卡片实测格高，让字号或主题变化时仍与 Bibi 首页对齐。
    return ElChildSizeBuilder(
      constraints: BoxConstraints.tightFor(width: cardWidth),
      child: buildBibiVideoCard(0, 0),
      builder: (size, _) {
        // 首页的虚拟列表把整行向上对齐到物理像素，差值加到间距以保留卡片原高。
        final rowExtent = ((size.height + 9) * pixelRatio - precisionErrorTolerance).ceilToDouble() / pixelRatio;
        final rowGap = rowExtent - size.height;
        return SizedBox.expand(
          // 给滚动子树独立的构建作用域，卡片更新不会反过来触发测高。
          child: LayoutBuilder(
            builder: (_, _) => _virtualGrid(
              columns: 2,
              padding: padding,
              extent: size.height,
              count: bibiVideoCount,
              columnGap: columnGap,
              rowGap: rowGap,
              itemBuilder: (_, index) => buildBibiVideoCard(index, 0),
            ),
          ),
        );
      },
    );
  }

  Widget _grid(BuildContext context, BoxConstraints constraints) {
    final album = widget.kind == .album;
    final columns = album
        ? math.max(3, (constraints.maxWidth / 76).floor())
        : constraints.maxWidth < 300
        ? 1
        : math.max(2, (constraints.maxWidth / 230).floor());
    if (album) {
      _albumColumns = columns;
      _albumCellExtent = constraints.maxWidth / columns;
      _scheduleThumbnails();
    }
    final padding = album ? EdgeInsets.zero : EdgeInsets.only(left: 6, top: 6);
    final width = (constraints.maxWidth - padding.horizontal) / columns;
    final extent = album ? width : _feedExtent(context, width);
    return _virtualGrid(
      columns: columns,
      padding: padding,
      extent: extent,
      masonry: widget.kind == .waterfall,
      count: _itemCount,
      featured: _featured ? _officialTile(0, featured: true) : null,
      itemBuilder: (_, index) => _officialTile(index),
    );
  }

  Widget _virtualGrid({
    required int columns,
    required EdgeInsets padding,
    required double extent,
    required int count,
    required IndexedWidgetBuilder itemBuilder,
    Widget? featured,
    double columnGap = 0,
    double rowGap = 0,
    bool masonry = false,
  }) {
    Widget recycled(BuildContext context, ValueListenable<int> index) {
      if (_bibiCards) {
        return ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (context, value, _) => buildBibiVideoCard(value, 0),
        );
      }
      return HookBuilder(
        builder: (context) {
          final model = useMemoized(() => ValueNotifier<_MediaEntry?>(_entryAt(index.value)));
          useEffect(() {
            void bind() => model.value = _entryAt(index.value);
            bind();
            index.addListener(bind);
            return () => index.removeListener(bind);
          }, [index]);
          return useMemoized(
            () => _MediaTile(
              model: model,
              kind: widget.kind,
              featured: false,
              tag: (entry) => _tag(entry, false),
              onOpen: (entry) => _open(entry, false),
            ),
            [model],
          );
        },
      );
    }

    final Widget content;
    if (_mode == .recycler) {
      content = masonry
          ? ElSliverRecyclerGrid.masonry(
              crossAxisCount: columns,
              mainAxisSpacing: rowGap,
              crossAxisSpacing: columnGap,
              itemCount: count,
              itemBuilder: recycled,
            )
          : ElSliverRecyclerGrid(
              crossAxisCount: columns,
              mainAxisSpacing: rowGap,
              crossAxisSpacing: columnGap,
              itemCount: count,
              itemBuilder: recycled,
            );
    } else {
      content = SliverGrid.builder(
        gridDelegate: masonry
            ? _MediaMasonryDelegate(
                columns,
                count,
                _waterfallFooterExtent(context),
                (index) => _entryAt(index).aspectRatio,
                Directionality.of(context) == .rtl,
              )
            : SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: columnGap,
                mainAxisSpacing: rowGap,
                mainAxisExtent: extent,
              ),
        itemCount: count,
        addAutomaticKeepAlives: false,
        itemBuilder: itemBuilder,
      );
    }
    final scroll = CustomScrollView(
      key: ValueKey(
        _bibiCards
            ? 'media-bibi-${_mode.name}'
            : _mode == .recycler
            ? 'media-recycler-${widget.kind.name}'
            : 'media-official-grid',
      ),
      controller: _controller,
      physics: _bibiCards ? ClampingScrollPhysics() : null,
      slivers: [
        if (featured != null)
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(child: featured),
          ),
        SliverPadding(
          padding: featured == null ? padding : EdgeInsets.only(left: padding.left),
          sliver: content,
        ),
      ],
    );
    return _bibiCards ? scroll : RecyclerExampleScrollbar(controller: _controller, child: scroll);
  }

  Widget _body() {
    if (!_demo && _itemCount == 0) {
      return Center(
        child: Padding(
          padding: .all(24),
          child: Column(
            mainAxisSize: .min,
            spacing: 12,
            children: [
              if (_library.busy)
                CircularProgressIndicator()
              else
                Icon(widget.kind == .album ? Icons.photo_library_outlined : Icons.video_library_outlined, size: 42),
              Text(
                _library.busy
                    ? '正在读取本机媒体…'
                    : _library.denied
                    ? '需要相册访问权限'
                    : _library.error ?? (_library.needsDirectory ? '选择一个照片或视频文件夹' : '这里还没有可显示的影像'),
                textAlign: .center,
              ),
              if (!_library.busy)
                FilledButton(
                  key: ValueKey('media-open-source'),
                  onPressed: _library.denied ? photos.PhotoManager.openSetting : _chooseSource,
                  child: Text(
                    _library.denied
                        ? '前往设置'
                        : _library.systemAlbums
                        ? '访问本机相册'
                        : '选择文件夹',
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        ElCard(
          style: ElStyle(padding: .symmetric(horizontal: 12, vertical: 7), borderRadius: BorderRadius.zero),
          child: Row(
            children: [
              Expanded(
                child: _library.albums.isEmpty || _demo
                    ? Text(
                        _demo ? '离线影像集' : _library.label,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: TextStyle(fontSize: 12),
                      )
                    : PopupMenuButton<photos.AssetPathEntity>(
                        key: ValueKey('media-albums'),
                        onSelected: (album) => _library.open(album: album),
                        itemBuilder: (_) => [
                          for (final album in _library.albums) PopupMenuItem(value: album, child: Text(album.name)),
                        ],
                        child: Row(
                          mainAxisSize: .min,
                          children: [
                            Flexible(
                              child: Text(
                                _library.label,
                                maxLines: 1,
                                overflow: .ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            Icon(Icons.expand_more, size: 16),
                          ],
                        ),
                      ),
              ),
              Text(
                '${_demo ? 10000 : _library.total} 项',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (_library.limited)
                TextButton(
                  onPressed: () async {
                    await photos.PhotoManager.presentLimited(
                      type: widget.kind == .album ? photos.RequestType.common : photos.RequestType.image,
                    );
                    if (mounted) await _library.open();
                  },
                  child: Text('管理可访问照片', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ),
        Expanded(child: LayoutBuilder(builder: _grid)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ExamplePage(
    title: _title,
    backgroundColor: _bibiCards ? Color(0xfff1f2f4) : null,
    actions: [
      if (!_bibiCards)
        IconButton(
          key: ValueKey('media-folder'),
          tooltip: '选择本机媒体',
          onPressed: _library.busy ? null : _chooseSource,
          icon: Icon(Icons.folder_open_outlined),
        ),
      if (!_bibiCards && !_demo)
        IconButton(
          tooltip: '刷新',
          onPressed: _library.busy ? null : () => _library.open(directory: _library.directory),
          icon: Icon(Icons.refresh),
        ),
      PopupMenuButton<_MediaGridMode>(
        key: ValueKey('media-scroll-menu'),
        tooltip: '网格容器',
        onSelected: _chooseMode,
        itemBuilder: (_) => [
          for (final mode in <_MediaGridMode>[.official, .recycler])
            CheckedPopupMenuItem(
              key: ValueKey('media-mode-${mode.name}'),
              value: mode,
              checked: _mode == mode,
              child: Text(mode.label),
            ),
          if (widget.kind == .feed) ...[
            PopupMenuDivider(),
            for (final source in <_MediaGridMode>[.localCards, .bibiCards])
              CheckedPopupMenuItem(
                key: ValueKey('media-mode-${source.name}'),
                value: source,
                checked: _bibiCards == (source == .bibiCards),
                child: Text(source.label),
              ),
          ],
        ],
      ),
    ],
    child: SafeArea(top: false, child: _bibiCards ? LayoutBuilder(builder: _bibiGrid) : _body()),
  );

  @override
  void dispose() {
    _library.removeListener(_changed);
    _library.dispose();
    if (widget.kind == .album) _albumThumbnails.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _OwnedMediaTile extends HookWidget {
  // ignore: prefer_const_constructors_in_immutables
  _OwnedMediaTile({
    super.key,
    required this.entry,
    required this.kind,
    required this.featured,
    required this.tag,
    required this.onOpen,
    this.fixedCover = false,
  });
  final _MediaEntry entry;
  final _MediaKind kind;
  final bool featured;
  final Object tag;
  final ValueChanged<_MediaEntry> onOpen;
  final bool fixedCover;
  @override
  Widget build(BuildContext context) {
    final model = useMemoized(() => ValueNotifier<_MediaEntry?>(entry));
    useEffect(() {
      model.value = entry;
      return null;
    }, [entry]);
    return _MediaTile(
      model: model,
      kind: kind,
      featured: featured,
      tag: (_) => tag,
      onOpen: onOpen,
      fixedCover: fixedCover,
    );
  }
}
