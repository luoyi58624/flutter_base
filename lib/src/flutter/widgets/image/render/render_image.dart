// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../../views/selection/common/selection_core.dart';
import '../../../views/view/event/dispatcher.dart';
import '../../../views/view/event/event.dart';
import '../../../views/view/style/style.dart';
import '../sized_image.dart';

const double _imageSelectionOverlayMaxAlpha = 0.28;

/// 图片内存缓存的上限：约 12 屏像素，封顶 256MB；只调大，不覆盖应用已有更大的设置。
const int _maxCacheBytes = 256 << 20;

/// 图片加载相位（render → 外壳的状态通道）。
enum ImageLoadPhase { loading, ready, error }

/// 相位回调：外壳据此切占位/错误覆盖层。
typedef ImageLoadPhaseCallback = void Function(ImageLoadPhase phase, {int? width, int? height, Object? error});

/// Render object for ElImage。
///
/// 加载完全交给官方 [ImageProvider] 与 [ImageCache]：布局确定后按布局框换算物理像素，
/// 经 [SizedImage] 让引擎直接解码到够用的尺寸；布局变大才重新解析，变小或抖动不重复解码。
class ElRenderImage extends RenderImage implements SelectionParticipantHost {
  /// 创建。
  ElRenderImage({
    required ImageProvider imageProvider,
    required ImageConfiguration imageConfiguration,
    ImageLoadPhaseCallback? onLoadPhase,
    bool reportReady = false,
    bool reportError = false,
    String? src,
    String? alt,
    ElStyle? style,
    ElEvent? event,
    Object? node,
    super.width,
    super.height,
    super.scale,
    super.color,
    super.colorBlendMode,
    super.fit,
    super.alignment,
    super.repeat,
    super.centerSlice,
    super.matchTextDirection,
    super.textDirection,
    super.invertColors,
    super.isAntiAlias,
    super.filterQuality,
  }) : _imageProvider = imageProvider,
       _imageConfiguration = imageConfiguration,
       _onLoadPhase = onLoadPhase,
       _reportReady = reportReady,
       _reportError = reportError,
       _src = src,
       _alt = alt,
       _style = style,
       _event = event,
       _node = node,
       super(debugImageLabel: src);

  static bool _cacheTuned = false;

  static void _tuneImageCache() {
    if (_cacheTuned) return;
    _cacheTuned = true;
    final view = ui.PlatformDispatcher.instance.views.firstOrNull;
    if (view == null) return;
    final cache = PaintingBinding.instance.imageCache;
    final wanted = math.min((view.physicalSize.width * view.physicalSize.height * 4 * 12).toInt(), _maxCacheBytes);
    if (wanted > cache.maximumSizeBytes) cache.maximumSizeBytes = wanted;
  }

  ImageProvider _imageProvider;

  /// 当前图片 provider。
  ImageProvider get imageProvider => _imageProvider;

  set imageProvider(ImageProvider value) {
    if (_imageProvider == value) return;
    _imageProvider = value;
    _removeImageListener();
    _box = null;
    _reportedReady = false;
    image = null;
    if (attached) markNeedsLayout();
  }

  ImageConfiguration _imageConfiguration;

  /// 图片解析配置。
  ImageConfiguration get imageConfiguration => _imageConfiguration;

  set imageConfiguration(ImageConfiguration value) {
    if (_imageConfiguration == value) return;
    _imageConfiguration = value;
    _invalidateBox();
  }

  // fit / repeat / centerSlice 决定解码尺寸语义，变化时按新语义重新解析。
  @override
  set fit(BoxFit? value) {
    if (fit == value) return;
    super.fit = value;
    _invalidateBox();
  }

  @override
  set repeat(ImageRepeat value) {
    if (repeat == value) return;
    super.repeat = value;
    _invalidateBox();
  }

  @override
  set centerSlice(Rect? value) {
    if (centerSlice == value) return;
    super.centerSlice = value;
    _invalidateBox();
  }

  String? _src;

  /// 图片源地址。
  String? get src => _src;

  set src(String? value) {
    if (_src == value) return;
    _src = value;
    debugImageLabel = value;
    markNeedsSemanticsUpdate();
    _selectionParticipant.notifySelectionContentChanged();
  }

  String? _alt;

  /// 替代文本。
  String? get alt => _alt;

  set alt(String? value) {
    if (_alt == value) return;
    _alt = value;
    markNeedsSemanticsUpdate();
    _selectionParticipant.notifySelectionContentChanged();
  }

  ElStyle? _style;

  set style(ElStyle? value) {
    if (identical(_style, value)) return;
    final oldUserSelect = _style?.userSelect;
    _style = value;
    if (oldUserSelect != value?.userSelect) {
      reattachSelectionParticipantsInSubtree(this);
    }
  }

  ElEvent? _event;
  EventDispatcher? _eventDispatcher;

  /// 当前图片事件配置。
  ElEvent? get event => _event;

  /// 更新当前图片事件配置。
  set event(ElEvent? value) {
    if (identical(_event, value)) return;
    _event = value;
    if (value == null) {
      _eventDispatcher?.dispose();
      _eventDispatcher = null;
      return;
    }
    final dispatcher = _eventDispatcher ??= EventDispatcher(this);
    dispatcher.event = value;
    if (attached) dispatcher.attach();
  }

  Object? _node;

  set node(Object? value) {
    if (identical(_node, value)) return;
    _node = value;
  }

  ImageLoadPhaseCallback? _onLoadPhase;

  set onLoadPhase(ImageLoadPhaseCallback? value) => _onLoadPhase = value;

  bool _reportReady;

  /// 是否向 widget 外壳上报 ready；纯错误占位无需为成功图片额外调度一帧。
  set reportReady(bool value) {
    if (_reportReady == value) return;
    _reportReady = value;
    final current = image;
    if (value && current != null) _reportReadyIfPossible();
  }

  bool _reportError;

  /// 是否向 widget 外壳上报 error。
  set reportError(bool value) => _reportError = value;

  // --- 解码尺寸 ----------------------------------------------------------------

  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  BoxConstraints? _layoutConstraints;

  /// 当前（或最近一次发起的）解码框，物理像素；0 表示该轴不限，(0, 0) 即原尺寸。null = 尚未解析。
  ({int w, int h})? _box;

  /// 已发起解析但首帧未到：期间布局再变大只记录，首帧到达后再追赶，避免动画缩放时并发多次解码。
  bool _resolving = false;
  bool _syncScheduled = false;
  bool _reportedReady = false;

  /// 当前解码框，仅供测试断言。
  @visibleForTesting
  ({int w, int h})? get debugBox => _box;

  void _invalidateBox() {
    _box = null;
    if (attached) markNeedsLayout();
  }

  /// 布局框 → 物理像素框。只取确定的轴：紧约束的轴直接用；没有紧约束时才用有限的上限；
  /// 重复平铺与九宫格依赖原始像素，不缩小。
  ({int w, int h}) _wantedBox() {
    final constraints = _layoutConstraints;
    if (constraints == null || repeat != ImageRepeat.noRepeat || centerSlice != null) return (w: 0, h: 0);
    final c = BoxConstraints.tightFor(width: width, height: height).enforce(constraints);
    final tightW = c.hasTightWidth;
    final tightH = c.hasTightHeight;
    final dpr = _imageConfiguration.devicePixelRatio ?? 1.0;
    final w = tightW || (!tightH && c.hasBoundedWidth) ? c.maxWidth : double.infinity;
    final h = tightH || (!tightW && c.hasBoundedHeight) ? c.maxHeight : double.infinity;
    return (w: SizedImage.bucketOf(w, dpr), h: SizedImage.bucketOf(h, dpr));
  }

  /// 是否需要（重新）解析：只升不降。任一轴曾不限制则按不限制合并，宁可多解也不欠解。
  ({int w, int h})? _nextBox() {
    final wanted = _wantedBox();
    final current = _box;
    if (current == null) return wanted;
    int merge(int a, int b) => a == 0 || b == 0 ? 0 : math.max(a, b);
    final merged = (w: merge(current.w, wanted.w), h: merge(current.h, wanted.h));
    return merged == current ? null : merged;
  }

  void _scheduleSync() {
    if (_syncScheduled || !attached || _layoutConstraints == null || _resolving) return;
    if (_nextBox() == null) return;
    _syncScheduled = true;
    // 不在 layout 阶段内同步 resolve：缓存命中会同步回调并改动 image。
    scheduleMicrotask(() {
      _syncScheduled = false;
      if (!attached || _resolving) return;
      final next = _nextBox();
      if (next == null) return;
      _box = next;
      _resolve();
    });
  }

  void _resolve() {
    final box = _box;
    if (box == null) return;
    final provider = box.w == 0 && box.h == 0
        ? _imageProvider
        : SizedImage(_imageProvider, boxWidth: box.w, boxHeight: box.h, fit: fit ?? BoxFit.scaleDown);
    final stream = provider.resolve(_imageConfiguration);
    if (_imageStream?.key == stream.key) return;
    _removeImageListener();
    _resolving = true;
    _imageStream = stream;
    stream.addListener(_listener);
  }

  void _removeImageListener() {
    _imageStream?.removeListener(_listener);
    _imageStream = null;
    _resolving = false;
  }

  ImageStreamListener get _listener {
    return _imageStreamListener ??= ImageStreamListener(_handleImageFrame, onError: _handleImageError);
  }

  void _handleImageFrame(ImageInfo imageInfo, bool synchronousCall) {
    final completer = _imageStream?.completer;
    final natural = completer == null ? null : SizedImage.intrinsicOf(completer);
    final width = natural?.width.toInt() ?? imageInfo.image.width;
    final height = natural?.height.toInt() ?? imageInfo.image.height;
    image = imageInfo.image.clone();
    scale = imageInfo.scale;
    imageInfo.dispose();
    _resolving = false;
    _reportReadyIfPossible(width: width, height: height);
    // 解析期间布局若又变大，此处追赶最新尺寸。
    _scheduleSync();
  }

  void _handleImageError(Object exception, StackTrace? stackTrace) {
    _resolving = false;
    // 升级解码失败时保留已有位图；只有首次加载失败才进入错误态。
    if (image != null) return;
    _reportPhase(ImageLoadPhase.error, error: exception);
  }

  void _reportReadyIfPossible({int? width, int? height}) {
    if (!_reportReady || _reportedReady || image == null) return;
    _reportedReady = true;
    _reportPhase(ImageLoadPhase.ready, width: width ?? image!.width, height: height ?? image!.height);
  }

  /// 相位上报走 post-frame（解码回调可能落在任意时机，外壳要 setState）。
  void _reportPhase(ImageLoadPhase phase, {int? width, int? height, Object? error}) {
    if (phase == ImageLoadPhase.ready && !_reportReady) return;
    if (phase == ImageLoadPhase.error && !_reportError) return;
    final callback = _onLoadPhase;
    if (callback == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      callback(phase, width: width, height: height, error: error);
    });
    // 空闲期（无帧调度）回调不能悬着。
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_event != null) {
      final dispatcher = _eventDispatcher ??= EventDispatcher(this);
      dispatcher.event = _event;
      dispatcher.attach();
    }
    _selectionParticipant.reattachSelectionRoot();
    _tuneImageCache();
    // 重挂时沿用上次解码框，命中内存缓存会同步出图；首次挂载等待布局。
    if (_box != null) {
      _resolve();
    } else {
      _scheduleSync();
    }
  }

  @override
  void detach() {
    _eventDispatcher?.detach(preserveEvent: true);
    _selectionParticipant.detachFromSelectionRoot();
    // 停止监听（动图随之停播）；已显示的位图保留，重挂时再监听。
    _removeImageListener();
    super.detach();
  }

  @override
  void dispose() {
    _selectionParticipant.dispose();
    _eventDispatcher?.dispose();
    _eventDispatcher = null;
    _removeImageListener();
    image = null;
    super.dispose();
  }

  @override
  void performLayout() {
    _layoutConstraints = constraints;
    super.performLayout();
    _selectionParticipant.updateSelectionGeometry();
    _scheduleSync();
  }

  late final AtomicSelectionContent _selectionContent = AtomicSelectionContent(
    selectionContentKind: SelectionContentKind.image,
    sizeOf: () => size,
    plainTextOf: () => _selectionText,
    onPaint: (canvas, offset, range, color, s) {
      final paint = Paint()..color = color.withValues(alpha: math.min(color.a, _imageSelectionOverlayMaxAlpha));
      canvas.drawRect(offset & s, paint);
      final border = Paint()
        ..color = color.withValues(alpha: math.min(color.a + 0.25, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect((offset & s).deflate(1.0), border);
    },
  );

  /// onSelection 伪类提取 memo（图片无状态机 / 无 vars 表：只认顶层声明）。
  final OnSelectionPaintMemo _onSelectionPaintMemo = OnSelectionPaintMemo();

  late final BoundSelectionParticipant _selectionParticipant = BoundSelectionParticipant(
    box: this,
    contentOf: () => _selectionContent,
    styleOf: () => _style,
    nodeOf: () => _node,
    selectionPaintOf: () => _onSelectionPaintMemo.resolve(_style),
  );

  @override
  SelectionParticipant? get selectionParticipant => _selectionParticipant;

  TextRange? get currentSelectionRange => _selectionParticipant.currentSelectionRange;

  void paintSelectionRange(Canvas canvas, Offset offset, TextRange range, Color color) {
    _selectionParticipant.paintSelectionRange(canvas, offset, range, color);
  }

  String get _selectionText {
    final alt = _alt;
    if (alt != null && alt.isNotEmpty) return alt;
    final src = _src;
    if (src != null && src.isNotEmpty) return src;
    return '';
  }

  @override
  bool get alwaysNeedsCompositing => hasSize && _selectionParticipant.hasSelectionHandleLayers;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final range = _selectionParticipant.currentSelectionRange;
    if (range != null) {
      _selectionParticipant.paintSelectionRange(
        context.canvas,
        offset,
        range,
        _selectionParticipant.effectiveSelectionBgColor,
      );
    }
    _selectionParticipant.paintSelectionHandleLayers(context, offset);
  }

  @override
  bool hitTestSelf(Offset position) => _eventDispatcher?.hitTestSelf(position) ?? false;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    super.handleEvent(event, entry);
    _eventDispatcher?.handleEvent(event, entry);
  }
}
