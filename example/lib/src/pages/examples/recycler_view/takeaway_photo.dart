part of 'takeaway.dart';

class _FoodAtlas extends ChangeNotifier implements ValueListenable<ui.Image?> {
  static const _asset = AssetImage('assets/recycler_cards/takeaway-food.webp');
  late final _listener = ImageStreamListener(_onImage, onError: _onError);
  ImageConfiguration? _configuration;
  ImageStream? _stream;
  ImageInfo? _imageInfo;

  @override
  ui.Image? get value => _imageInfo?.image;

  void resolve(ImageConfiguration configuration) {
    if (_configuration == configuration) return;
    _configuration = configuration;
    final stream = _asset.resolve(configuration);
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream;
    _replaceImage(null);
    stream.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronous) => _replaceImage(info);

  void _onError(Object error, StackTrace? stack) => debugPrint('外卖图片图集加载失败：$error');

  void _replaceImage(ImageInfo? info) {
    if (identical(_imageInfo, info)) return;
    final previous = _imageInfo;
    _imageInfo = info;
    previous?.dispose();
    notifyListeners();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _imageInfo?.dispose();
    super.dispose();
  }
}

class _AtlasPhoto extends LeafRenderObjectWidget {
  const _AtlasPhoto({super.key, required this.atlas, required this.store, required this.tile, required this.size});

  final ValueListenable<ui.Image?> atlas;
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

  static const _columns = 4;
  static const _rows = 3;
  static final _imagePaint = Paint()..filterQuality = .low;
  static final _placeholderPaint = Paint()..color = _orange.withValues(alpha: .07);

  ValueListenable<ui.Image?> _atlas;
  ValueListenable<_Store?> _store;
  int Function(_Store) _tile;
  double _extent;
  ui.Image? _image;
  int? _index;

  void bind(
    ValueListenable<ui.Image?> atlas,
    ValueListenable<_Store?> store,
    int Function(_Store) tile,
    double extent,
  ) {
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
    assert(index == null || (index >= 0 && index < _columns * _rows));
    final image = index == null ? null : _atlas.value;
    final changed = !identical(image, _image) || (image != null && index != _index);
    _image = image;
    _index = index;
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
    if (size.isEmpty) return;
    final bounds = offset & size;
    final rounded = RRect.fromRectAndRadius(bounds, const Radius.circular(8));
    final image = _image;
    final index = _index;
    final canvas = context.canvas;
    if (image == null || index == null) {
      canvas.drawRRect(rounded, _placeholderPaint);
      return;
    }
    final width = image.width / _columns;
    final height = image.height / _rows;
    // 留半个纹素给双线性采样，避免相邻图块的颜色混进圆角边缘。
    final cell = Rect.fromLTWH(index % _columns * width, index ~/ _columns * height, width, height).deflate(.5);
    final fit = applyBoxFit(.cover, cell.size, size);
    final source = Alignment.center.inscribe(fit.source, cell);
    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawImageRect(image, source, bounds, _imagePaint);
    canvas.restore();
  }
}
