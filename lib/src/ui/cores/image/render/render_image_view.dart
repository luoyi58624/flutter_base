// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter_base/src/ui/cores/view/event/dispatcher.dart';
import 'package:flutter_base/src/ui/cores/view/event/event.dart';
import 'package:flutter_base/src/ui/cores/selection/common/selection_core.dart';

import 'package:flutter_base/src/ui/cores/view/style/style.dart';
import 'package:flutter_base/src/ui/cores/image/image_byte_source.dart';
import 'package:flutter_base/src/ui/cores/image/image_decode_pipeline.dart';

const double _imageSelectionOverlayMaxAlpha = 0.28;

/// 图片加载相位（render → 外壳的状态通道）。
enum ImageLoadPhase { loading, ready, error }

/// 相位回调：外壳据此切占位/错误覆盖层。
typedef ImageLoadPhaseCallback = void Function(ImageLoadPhase phase, {int? width, int? height, Object? error});

/// Render object for ElImageView.
class RenderImageView extends RenderImage implements SelectionParticipantHost {
  /// 创建。
  RenderImageView({
    required ImageProvider imageProvider,
    required ImageConfiguration imageConfiguration,
    ImageByteSource? byteSource,
    bool Function()? decodeVisible,
    int Function()? decodePriority,
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
       _byteSource = byteSource,
       _decodeVisible = decodeVisible,
       _decodePriority = decodePriority,
       _onLoadPhase = onLoadPhase,
       _reportReady = reportReady,
       _reportError = reportError,
       _src = src,
       _alt = alt,
       _style = style,
       _event = event,
       _node = node,
       super(debugImageLabel: src);

  ImageProvider _imageProvider;

  /// 当前图片 provider。
  ImageProvider get imageProvider => _imageProvider;

  set imageProvider(ImageProvider value) {
    if (_imageProvider == value) return;
    _imageProvider = value;
    // 换源后新图首帧要重新上报 ready（外壳 didUpdateWidget 已把相位回
    // loading，占位层等这次上报揭开）。
    _reportedReady = false;
    if (attached && !_pipelineEligible) _resolveImage();
  }

  ImageConfiguration _imageConfiguration;

  /// 图片解析配置。
  ImageConfiguration get imageConfiguration => _imageConfiguration;

  set imageConfiguration(ImageConfiguration value) {
    if (_imageConfiguration == value) return;
    _imageConfiguration = value;
    if (_pipelineEligible) {
      _isCurrentlyVisible = false;
      markNeedsLayout();
    } else {
      _resolveImage();
    }
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

  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  // --- 两段式解码管线（P3，io 平台） -----------------------------------------

  ImageByteSource? _byteSource;

  /// 字节源；非 null 且语义允许时走自管两段式管线，否则走官方 provider 管线。
  set byteSource(ImageByteSource? value) {
    if (identical(_byteSource, value) || _byteSource?.key == value?.key) {
      _byteSource = value;
      return;
    }
    _byteSource = value;
    _pipelineFellBack = false;
    _descriptorInfo = null;
    _decodedBucket = 0;
    _pendingDecodeBucket = 0;
    _retryDecodeBucket = 0;
    _mediaDecodePending = false;
    _mediaUnavailable = false;
    _usingMediaThumbnail = false;
    _generation++;
    // 新源首帧重新走 ready 上报：不复位则第二张及以后的图占位层永不揭开、
    // onLoad 永不回调。
    _reportedReady = false;
    _removeImageListener();
    image = null;
    if (attached) _startLoad();
    markNeedsLayout();
  }

  ImageLoadPhaseCallback? _onLoadPhase;

  set onLoadPhase(ImageLoadPhaseCallback? value) => _onLoadPhase = value;

  bool _reportReady;

  /// 是否向 widget 外壳上报 ready；纯错误占位无需为成功图片额外调度一帧。
  set reportReady(bool value) {
    if (_reportReady == value) return;
    _reportReady = value;
    final current = image;
    if (value && current != null) {
      _reportReadyIfPossible(imageWidth: current.width, imageHeight: current.height);
    }
  }

  bool _reportError;

  /// 是否向 widget 外壳上报 error。
  set reportError(bool value) => _reportError = value;

  /// 动图 / repeat / centerSlice 语义下管线让路（降采样位图会改变平铺与
  /// 九宫格语义；动图只有首帧）。
  bool get _pipelineEligible =>
      _byteSource != null && !_pipelineFellBack && repeat == ImageRepeat.noRepeat && centerSlice == null;

  bool _pipelineFellBack = false;
  int Function()? _decodePriority;
  ImageDescriptorInfo? _descriptorInfo;

  // 只记录当前真正交给 RenderImage 绘制的位图所满足的目标桶。请求发出时
  // 提前抬高这个水位会把排队/失败误判成升级完成，窗口放大后便永久拉伸旧图。
  int _decodedBucket = 0;
  int _pendingDecodeBucket = 0;
  int _retryDecodeBucket = 0;
  bool _mediaDecodePending = false;
  bool _mediaUnavailable = false;
  bool _usingMediaThumbnail = false;

  /// 当前绘制位图已经完成的解码目标桶，仅供尺寸策略回归测试。
  @visibleForTesting
  int get debugDecodedBucket => _decodedBucket;

  int _generation = 0;
  bool _reportedReady = false;

  bool _isCurrentlyVisible = false;
  bool Function()? _decodeVisible;

  /// 当前节点是否被解码调度视为可见，仅供优先级回归测试。
  @visibleForTesting
  bool get debugDecodeIsVisible => _decodeIsVisible();

  /// 更新虚拟窗口提供的实时可见性查询。
  set decodeVisible(bool Function()? value) => _decodeVisible = value;

  /// 更新虚拟窗口提供的方向解码优先级查询。
  set decodePriority(int Function()? value) => _decodePriority = value;

  /// 当前虚拟项的动态解码优先级，仅供滚动方向回归测试。
  @visibleForTesting
  int? get debugDecodePriority => _decodePriority?.call();

  void _markCurrentlyVisible() {
    // paint 过的 cell 保持高优先级直到 detach；cacheExtent 外节点不会 paint，
    // 而每帧清零会让异步槽位释放恰好落在缝隙时退化成几百项 FIFO。
    _isCurrentlyVisible = true;
  }

  bool _decodeIsVisible() => _decodeVisible?.call() ?? _isCurrentlyVisible;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (_event != null) {
      final dispatcher = _eventDispatcher ??= EventDispatcher(this);
      dispatcher.event = _event;
      dispatcher.attach();
    }
    _isCurrentlyVisible = false;
    _selectionParticipant.reattachSelectionRoot();
    _startLoad();
  }

  @override
  void detach() {
    _eventDispatcher?.detach(preserveEvent: true);
    _selectionParticipant.detachFromSelectionRoot();
    _generation++;
    // 桶水位清零：残留旧值会让重挂后的 decode 请求被 `bucket <= _decodedBucket`
    // 短路，滚回的 cell 永不重试（白屏卡死）。重挂后解码直接命中管线缓存。
    _decodedBucket = 0;
    _pendingDecodeBucket = 0;
    _retryDecodeBucket = 0;
    _mediaDecodePending = false;
    _isCurrentlyVisible = false;
    _removeImageListener();
    super.detach();
  }

  @override
  void dispose() {
    _generation++;
    _selectionParticipant.dispose();
    _eventDispatcher?.dispose();
    _eventDispatcher = null;
    _removeImageListener();
    image = null;
    super.dispose();
  }

  void _startLoad() {
    unawaited(ImageDecodePipeline.instance.ensurePlatformTuning());
    if (_pipelineEligible) {
      if (_shouldUseMediaThumbnail) {
        _restoreCachedBitmap();
        return;
      }
      _restoreCachedOrLoad();
    } else {
      _resolveImage();
    }
  }

  /// 重挂先同步复用内存位图；冷图才进入描述符与尺寸解码管线。
  void _restoreCachedOrLoad() {
    if (_restoreCachedBitmap()) return;
    final source = _byteSource!;
    final pipeline = ImageDecodePipeline.instance;
    final descriptor = pipeline.findDescriptor(source);
    if (descriptor == null) return _requestDescriptor();
    _descriptorInfo = descriptor;
    markNeedsLayout();
  }

  bool _restoreCachedBitmap() {
    final hit = ImageDecodePipeline.instance.findCached(_byteSource!);
    if (hit == null) return false;
    _descriptorInfo = ImageDescriptorInfo(width: hit.originalWidth, height: hit.originalHeight);
    _decodedBucket = hit.bucketWidth;
    image = hit.image.clone();
    if (_shouldUseMediaThumbnail) _usingMediaThumbnail = true;
    _reportReadyIfPossible();
    return true;
  }

  bool get _shouldUseMediaThumbnail =>
      ImageDecodePipeline.mediaStoreThumbnailEnabled &&
      !_mediaUnavailable &&
      _byteSource?.localPath != null &&
      width != null &&
      height != null;

  /// 段一：描述符（原始尺寸）就绪 → intrinsic 布局可用。
  void _requestDescriptor() {
    final source = _byteSource!;
    if (_descriptorInfo != null) return;
    final generation = _generation;
    ImageDecodePipeline.instance
        .descriptorFor(
          source,
          isCanceled: () => generation != _generation || !attached,
          isVisible: _decodeIsVisible,
          priority: _decodePriority,
        )
        .then((info) {
          if (generation != _generation || !attached) return;
          _descriptorInfo = info;
          _reportReadyIfPossible();
          // 显式尺寸场景首轮 layout 已经拿到真实约束，描述符返回后可直接解码，
          // 不必白等下一帧 layout；intrinsic 场景仍由下方重排收敛尺寸。
          if (!size.isEmpty) _requestDecodeForLayout();
          markNeedsLayout();
        })
        .catchError((Object error) {
          if (error is ImageDecodeCanceled) {
            // 滚出屏撤销非错误；存活节点被共享请求的取消波及（竞态兜底）
            // 则重新发起，不能停在无 descriptor 的 0 尺寸态。
            if (generation == _generation && attached) _requestDescriptor();
            return;
          }
          if (generation != _generation) return;
          _reportPhase(ImageLoadPhase.error, error: error);
        });
  }

  /// 段二：布局尾声算出正确采样宽并请求解码；同桶幂等，布局放大才升级。
  void _requestDecodeForLayout() {
    final info = _descriptorInfo;
    final source = _byteSource;
    if (source == null || size.isEmpty) return;
    final dpr = _imageConfiguration.devicePixelRatio ?? 1.0;
    if (_shouldUseMediaThumbnail && (info == null || _usingMediaThumbnail)) {
      _requestMediaThumbnail(source, size, dpr);
      return;
    }
    if (info == null) return;
    final bucket = _bucketForLayout(info, size, dpr);
    if (bucket <= _decodedBucket) return;
    // 连续窗口缩放/布局动画只允许单节点保留一个解码任务。在途期间的尺寸
    // 变化由完成回调按最新 layout 追赶，禁止每跨一个 32px 桶就并发解码。
    if (_pendingDecodeBucket != 0) return;
    _pendingDecodeBucket = bucket;
    final generation = _generation;
    ImageDecodePipeline.instance
        .decode(
          source,
          bucket,
          isCanceled: () => generation != _generation || !attached,
          isVisible: _decodeIsVisible,
          priority: _decodePriority,
        )
        .then((decoded) {
          if (generation != _generation || !attached) return;
          if (decoded == null) {
            if (_pendingDecodeBucket == bucket) _pendingDecodeBucket = 0;
            // 动图必须交回官方 provider，保留完整逐帧语义。
            _pipelineFellBack = true;
            _descriptorInfo = null;
            _resolveImage();
            return;
          }
          // 同一节点连续放大时可能同时存在多个桶请求。旧请求晚回只能作为
          // 无图首帧兜底，绝不能把已经展示的更高清位图重新降级。
          if (bucket >= _decodedBucket) {
            image = decoded.clone();
            _decodedBucket = bucket;
          }
          if (bucket >= _retryDecodeBucket) _retryDecodeBucket = 0;
          if (_pendingDecodeBucket == bucket) _pendingDecodeBucket = 0;
          _reportReadyIfPossible();
          // 解码期间布局还可能继续变化；成功回调立刻追赶最新尺寸，不等待
          // 下一次外部 rebuild。
          scheduleMicrotask(_requestDecodeForLayout);
        })
        .catchError((Object error) {
          if (generation != _generation) return;
          if (_pendingDecodeBucket == bucket) _pendingDecodeBucket = 0;
          if (error is ImageDecodeCanceled) {
            if (attached) markNeedsLayout();
            return;
          }
          // 升级失败时保留仍可绘制的旧位图；只有首次解码失败才进入错误态。
          // 同一目标自动重试一次，既兜住瞬时 codec 失败，也不会让损坏图片
          // 形成无休止的解码循环。
          if (image != null && _retryDecodeBucket != bucket) {
            _retryDecodeBucket = bucket;
            if (attached) markNeedsLayout();
          } else if (image == null) {
            _reportPhase(ImageLoadPhase.error, error: error);
          }
        });
  }

  void _requestMediaThumbnail(ImageByteSource source, Size layoutSize, double dpr) {
    if (_mediaDecodePending) return;
    final info = _descriptorInfo;
    if (info != null) {
      final needed = _bucketForLayout(info, layoutSize, dpr);
      if (needed <= _decodedBucket) return;
    }
    _mediaDecodePending = true;
    final generation = _generation;
    ImageDecodePipeline.instance
        .decodeMediaThumbnail(
          source,
          layoutSize,
          dpr,
          fit ?? BoxFit.scaleDown,
          isCanceled: () => generation != _generation || !attached,
          isVisible: _decodeIsVisible,
          priority: _decodePriority,
        )
        .then((decoded) {
          if (generation != _generation || !attached) return;
          _mediaDecodePending = false;
          if (decoded == null) {
            _mediaUnavailable = true;
            _usingMediaThumbnail = false;
            _restoreCachedOrLoad();
            return;
          }
          _usingMediaThumbnail = true;
          _descriptorInfo = ImageDescriptorInfo(width: decoded.originalWidth, height: decoded.originalHeight);
          _decodedBucket = decoded.bucketWidth;
          image = decoded.image.clone();
          _reportReadyIfPossible();
          if (size != layoutSize) markNeedsLayout();
        })
        .catchError((Object error) {
          if (generation == _generation) _mediaDecodePending = false;
          if (error is ImageDecodeCanceled) {
            if (generation == _generation && attached) markNeedsLayout();
            return;
          }
          if (generation != _generation) return;
          _mediaUnavailable = true;
          _usingMediaThumbnail = false;
          _restoreCachedOrLoad();
        });
  }

  int _bucketForLayout(ImageDescriptorInfo info, Size layoutSize, double dpr) {
    return ImageDecodePipeline.bucketForLayout(info, layoutSize, dpr, fit ?? BoxFit.scaleDown);
  }

  void _reportReadyIfPossible({int? imageWidth, int? imageHeight}) {
    if (!_reportReady || _reportedReady || image == null) return;
    final info = _descriptorInfo;
    if (info == null && (_pipelineEligible || imageWidth == null || imageHeight == null)) return;
    _reportedReady = true;
    _reportPhase(ImageLoadPhase.ready, width: info?.width ?? imageWidth, height: info?.height ?? imageHeight);
  }

  /// 相位上报走 post-frame（解码回调可能落在任意时机，外壳要 setState）。
  void _reportPhase(ImageLoadPhase phase, {int? width, int? height, Object? error}) {
    if (phase == ImageLoadPhase.ready && !_reportReady) return;
    if (phase == ImageLoadPhase.error && !_reportError) return;
    if (phase == ImageLoadPhase.loading && !_reportReady) return;
    final callback = _onLoadPhase;
    if (callback == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      callback(phase, width: width, height: height, error: error);
    });
    // 空闲期（无帧调度）回调不能悬着。
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// 管线模式的 sizing：image 未就绪时用描述符原始尺寸做 intrinsic
  /// （RenderImage 同款公式），避免"先 0 尺寸后跳变"。
  Size _sizeForDescriptor(BoxConstraints constraints) {
    final info = _descriptorInfo;
    constraints = BoxConstraints.tightFor(width: width, height: height).enforce(constraints);
    if (info == null) return constraints.smallest;
    return constraints.constrainSizeAndAttemptToPreserveAspectRatio(
      Size(info.width.toDouble() / scale, info.height.toDouble() / scale),
    );
  }

  @override
  void performLayout() {
    final previousSize = hasSize ? size : null;
    if (_pipelineEligible && image == null) {
      size = _sizeForDescriptor(constraints);
    } else {
      super.performLayout();
    }
    _selectionParticipant.updateSelectionGeometry();
    if (_pipelineEligible) {
      // 窗口/网格 resize 会让整段 cacheExtent 节点一起重排；清掉旧 paint
      // 留下的可见标记，随后只有本帧真正 paint 的节点恢复高优先级。
      if (previousSize != null && previousSize != size) _isCurrentlyVisible = false;
      scheduleMicrotask(_requestDecodeForLayout);
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_pipelineEligible && image == null) return _sizeForDescriptor(constraints);
    return super.computeDryLayout(constraints);
  }

  // --- 官方 provider 管线（web / 动图 / repeat / centerSlice 回退路径） -------

  void _resolveImage() {
    if (!attached) return;
    final stream = _imageProvider.resolve(_imageConfiguration);
    if (_imageStream?.key == stream.key) return;
    _removeImageListener();
    _imageStream = stream;
    stream.addListener(_listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    if (stream == null) return;
    stream.removeListener(_listener);
    _imageStream = null;
  }

  ImageStreamListener get _listener {
    return _imageStreamListener ??= ImageStreamListener(_handleImageFrame, onError: _handleImageError);
  }

  void _handleImageFrame(ImageInfo imageInfo, bool synchronousCall) {
    image = imageInfo.image.clone();
    scale = imageInfo.scale;
    _reportReadyIfPossible(imageWidth: imageInfo.image.width, imageHeight: imageInfo.image.height);
    imageInfo.dispose();
  }

  void _handleImageError(Object exception, StackTrace? stackTrace) {
    image = null;
    _reportPhase(ImageLoadPhase.error, error: exception);
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
    _markCurrentlyVisible();
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
