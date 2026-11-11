part of 'index.dart';

class _FoodAtlas extends ChangeNotifier implements ValueListenable<ui.Image?> {
  _FoodAtlas(TickerProvider vsync)
    : _fade = AnimationController(vsync: vsync, duration: exampleImageFadeDuration, value: 1) {
    _fade.addListener(notifyListeners);
  }

  static const _asset = AssetImage('assets/recycler_cards/takeaway-food.webp');
  static const _columns = 4;
  static const _rows = 3;
  static const tileCount = _columns * _rows;
  final AnimationController _fade;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);
  ImageConfiguration? _configuration;
  ImageStream? _stream;
  ImageInfo? _imageInfo;
  List<Rect> _tiles = [];
  bool _reduceMotion = false;

  @override
  ui.Image? get value => _imageInfo?.image;

  double get opacity => Curves.easeOut.transform(_fade.value);

  Rect tileRect(int index) => _tiles[index];

  void resolve(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _fade.isAnimating) _fade.value = 1;
    final configuration = createLocalImageConfiguration(context);
    if (_configuration == configuration) return;
    _configuration = configuration;
    final stream = _asset.resolve(configuration);
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream;
    _replaceImage(null);
    stream.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronous) {
    if (_imageInfo == null) {
      // 整张图集共享一次淡入，滚动换绑只切换图块。
      if (synchronous || _reduceMotion) {
        _fade.value = 1;
      } else {
        _fade.forward(from: 0);
      }
    }
    _replaceImage(info);
  }

  void _onError(Object error, StackTrace? stack) => debugPrint('外卖图片图集加载失败：$error');

  void _replaceImage(ImageInfo? info) {
    if (identical(_imageInfo, info)) return;
    final previous = _imageInfo;
    _imageInfo = info;
    if (info == null) {
      _tiles = [];
    } else {
      final cellWidth = info.image.width / _columns;
      final cellHeight = info.image.height / _rows;
      // 两种卡片共用图块坐标，留半个纹素防止双线性采样混入相邻图块。
      _tiles = List.generate(
        tileCount,
        (index) => Rect.fromLTWH(
          index % _columns * cellWidth,
          index ~/ _columns * cellHeight,
          cellWidth,
          cellHeight,
        ).deflate(.5),
        growable: false,
      );
    }
    previous?.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _fade.dispose();
    _imageInfo?.dispose();
    super.dispose();
  }
}

class _AtlasPhoto extends LeafRenderObjectWidget {
  const _AtlasPhoto({super.key, required this.atlas, required this.store, required this.tile, required this.size});

  final _FoodAtlas atlas;
  final ValueListenable<_Store?> store;
  final int Function(_Store) tile;
  final double size;

  @override
  _RenderAtlasPhoto createRenderObject(BuildContext context) => _RenderAtlasPhoto(atlas, store, tile, size);

  @override
  void updateRenderObject(BuildContext context, _RenderAtlasPhoto renderObject) =>
      renderObject.bind(atlas, store, tile, size);
}

class _RenderAtlasPhoto extends RenderBox {
  _RenderAtlasPhoto(this._atlas, this._store, this._tile, this._extent);

  static final _imagePaint = Paint()..filterQuality = .low;

  _FoodAtlas _atlas;
  ValueListenable<_Store?> _store;
  int Function(_Store) _tile;
  double _extent;
  ui.Image? _image;
  int? _index;
  double _opacity = 1;

  void bind(_FoodAtlas atlas, ValueListenable<_Store?> store, int Function(_Store) tile, double extent) {
    if (!identical(_atlas, atlas)) {
      if (attached) _atlas.removeListener(_update);
      _atlas = atlas;
      if (attached) _atlas.addListener(_update);
    }
    if (!identical(_store, store)) {
      if (attached) _store.removeListener(_update);
      _store = store;
      if (attached) _store.addListener(_update);
    }
    _tile = tile;
    if (_extent != extent) {
      _extent = extent;
      markNeedsLayout();
    }
    _update();
  }

  void _update() {
    final record = _store.value;
    final index = record == null ? null : _tile(record);
    assert(index == null || (index >= 0 && index < _FoodAtlas.tileCount));
    final image = index == null ? null : _atlas.value;
    final opacity = _atlas.opacity;
    final changed = !identical(image, _image) || (image != null && (index != _index || opacity != _opacity));
    _image = image;
    _index = index;
    _opacity = opacity;
    if (changed) markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _atlas.addListener(_update);
    _store.addListener(_update);
    _update();
  }

  @override
  void detach() {
    _atlas.removeListener(_update);
    _store.removeListener(_update);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size.square(_extent));

  @override
  double computeMinIntrinsicWidth(double height) => _extent;

  @override
  double computeMaxIntrinsicWidth(double height) => _extent;

  @override
  double computeMinIntrinsicHeight(double width) => _extent;

  @override
  double computeMaxIntrinsicHeight(double width) => _extent;

  @override
  void paint(PaintingContext context, Offset offset) {
    final image = _image;
    final index = _index;
    if (image == null || index == null || _opacity == 0 || size.isEmpty) return;
    final bounds = offset & size;
    final rounded = RRect.fromRectAndRadius(bounds, const Radius.circular(8));
    final canvas = context.canvas;
    final cell = _atlas.tileRect(index);
    final fit = applyBoxFit(.cover, cell.size, size);
    final source = Alignment.center.inscribe(fit.source, cell);
    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawImageRect(image, source, bounds, _imagePaint..color = Color.fromRGBO(0, 0, 0, _opacity));
    canvas.restore();
  }
}
