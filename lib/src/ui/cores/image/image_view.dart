import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:flutter_base/src/flutter/views/view/event/event.dart';
import 'package:flutter_base/src/flutter/views/scroll/virtual/virtual_pipeline.dart' show ElScrollMixin;
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'image_byte_source.dart';
import 'image_decode_pipeline.dart';
import 'image_platform_bridge.dart';
import 'image_provider_resolver_stub.dart'
    if (dart.library.io) 'image_provider_resolver_io.dart'
    as image_provider_resolver;
import 'render/render_image_view.dart';

/// 图片加载完成信息（[ElImageView.onLoad] 入参）。
@immutable
class ImageLoadInfo {
  const ImageLoadInfo({required this.width, required this.height});

  /// 图片原始像素宽。
  final double width;

  /// 图片原始像素高。
  final double height;

  @override
  String toString() => 'ImageLoadInfo($width x $height)';
}

/// 核心图片标签，语义对应 HTML `img`，只负责加载、绘制、事件与选区能力。
///
/// 图片预览等组合行为由上层组件库封装，不属于本标签职责。
///
/// [src] 三协议自动识别（无需选构造）：
/// - `http://` / `https://` → 网络图；
/// - `asset://xxx` 或 `assets/` 前缀 → 包内资源；
/// - `file://` URI 或裸文件路径（含 Windows 盘符）→ 本地文件。
///
/// 内存字节用 [ElImageView.memory]。
///
/// 占位与错误：[placeholder] 在加载完成前显示，[error] 在加载失败后显示；
/// 两者与 [onLoad] / [onError] 均未配置时组件走零开销直挂路径（不额外监听
/// 图片流，行为与配置前完全一致）。
class ElImageView extends StatefulWidget {
  /// 创建图片组件；[src] 按上述规则自动识别来源。
  ElImageView(
    String this.src, {
    super.key,
    this.alt,
    this.width,
    this.height,
    double scale = 1.0,
    Map<String, String>? headers,
    this.color,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.invertColors = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.medium,
    this.style,
    this.event,
    this.placeholder,
    this.error,
    this.onLoad,
    this.onError,
  }) : image = image_provider_resolver.imageProviderForSource(src, scale: scale, headers: headers),
       byteSource = image_provider_resolver.byteSourceForSource(src, headers: headers),
       scale = scale;

  /// 内存图片。
  ElImageView.memory(
    Uint8List bytes, {
    super.key,
    this.src,
    this.alt,
    this.width,
    this.height,
    double scale = 1.0,
    this.color,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.invertColors = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.medium,
    this.style,
    this.event,
    this.placeholder,
    this.error,
    this.onLoad,
    this.onError,
  }) : image = MemoryImage(bytes, scale: scale),
       byteSource = MemoryByteSource(bytes),
       scale = scale;

  /// 返回 Android 系统相册中按修改时间倒序排列的图片路径；其他平台返回空列表。
  static Future<List<String>> systemImagePaths({bool refresh = false}) =>
      ImagePlatformBridge.listMediaImages(refresh: refresh);

  /// 预解即将进入视口的图片；只写入 ElImageView 自身缓存，不创建独立缩略图缓存。
  static Future<void> preload(
    String src, {
    required Size size,
    required double devicePixelRatio,
    BoxFit fit = BoxFit.cover,
    Map<String, String>? headers,
  }) async {
    final source = image_provider_resolver.byteSourceForSource(src, headers: headers);
    if (source == null || size.isEmpty) return;
    final pipeline = ImageDecodePipeline.instance;
    await pipeline.ensurePlatformTuning();
    final cached = pipeline.findCached(source);
    if (cached != null) {
      final info = ImageDescriptorInfo(width: cached.originalWidth, height: cached.originalHeight);
      final needed = ImageDecodePipeline.bucketForLayout(info, size, devicePixelRatio, fit);
      if (cached.bucketWidth >= needed) return;
    }
    final media = await pipeline.decodeMediaThumbnail(source, size, devicePixelRatio, fit);
    if (media != null) return;
    final info = await pipeline.descriptorFor(source);
    final bucket = ImageDecodePipeline.bucketForLayout(info, size, devicePixelRatio, fit);
    await pipeline.decode(source, bucket);
  }

  /// 图片源（[src] 解析产物 / memory provider）。用于图片加载回退管线。
  final ImageProvider image;

  /// 两段式解码管线的字节源；null = 平台/来源不支持，走官方 provider 管线。
  final ImageByteSource? byteSource;

  /// 图片 URL / 资源标识。
  final String? src;

  /// 替代文本。复制选区时优先使用。
  final String? alt;

  /// 显式宽度。
  final double? width;

  /// 显式高度。
  final double? height;

  /// 图片 scale。
  final double scale;

  /// 颜色混合。
  final Color? color;

  /// 颜色混合模式。
  final BlendMode? colorBlendMode;

  /// 图片填充方式。
  final BoxFit? fit;

  /// 对齐。
  final AlignmentGeometry alignment;

  /// 重复方式。
  final ImageRepeat repeat;

  /// 九宫格切片。
  final Rect? centerSlice;

  /// 是否按文本方向镜像。
  final bool matchTextDirection;

  /// 是否反色。
  final bool invertColors;

  /// 是否抗锯齿。
  final bool isAntiAlias;

  /// 过滤质量。
  final FilterQuality filterQuality;

  /// 用于 userSelect 继承判断。
  final ElStyle? style;

  /// 图片自身的指针与点击事件；未配置时不创建事件分发器。
  final ElEvent? event;

  /// 加载完成前的占位内容。有显式 [width]/[height] 时占位随图片尺寸。
  final Widget? placeholder;

  /// 加载失败后的内容。有显式 [width]/[height] 时同样随图片尺寸。
  final Widget? error;

  /// 加载完成回调（首帧解码完成，带原始像素尺寸）。
  final void Function(ImageLoadInfo info)? onLoad;

  /// 加载失败回调。
  final void Function(Object error)? onError;

  @override
  State<ElImageView> createState() => _ImageViewState();
}

enum _ImagePhase { loading, ready, error }

class _ImageViewState extends State<ElImageView> with ElScrollMixin<ElImageView> {
  _ImagePhase _phase = _ImagePhase.loading;

  bool get _tracksReady => widget.placeholder != null || widget.onLoad != null;

  bool get _tracksError => widget.error != null || widget.onError != null;

  /// 占位/错误/回调任一配置时才需要相位驱动 rebuild。
  bool get _tracksPhase => _tracksReady || _tracksError;

  @override
  bool get observesScrollUpdates => false;

  @override
  bool get observesScrollMetrics => false;

  @override
  void didUpdateWidget(ElImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _phase = _ImagePhase.loading;
  }

  /// render 的相位通道（post-frame 派发，可安全 setState）。
  void _handlePhase(ImageLoadPhase phase, {int? width, int? height, Object? error}) {
    if (!mounted) return;
    switch (phase) {
      case ImageLoadPhase.ready:
        if (_phase != _ImagePhase.ready) {
          widget.onLoad?.call(ImageLoadInfo(width: (width ?? 0).toDouble(), height: (height ?? 0).toDouble()));
          setState(() => _phase = _ImagePhase.ready);
        }
      case ImageLoadPhase.error:
        if (_phase != _ImagePhase.error) {
          if (error != null) widget.onError?.call(error);
          setState(() => _phase = _ImagePhase.error);
        }
      case ImageLoadPhase.loading:
        if (_phase != _ImagePhase.loading) setState(() => _phase = _ImagePhase.loading);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = _RawImageView(
      view: widget,
      decodeVisible: hasScrollItem ? () => scrollItemDecodeVisible : null,
      decodePriority: hasScrollItem ? () => scrollItemDecodePriority : null,
      onLoadPhase: _tracksPhase ? _handlePhase : null,
      reportReady: _tracksReady,
      reportError: _tracksError,
    );
    if (!_tracksPhase) return raw;
    // 恒挂 render（加载由它驱动），占位/错误作为覆盖层盖在其上；
    // 完成后覆盖层移除、图片已在底层就位（无重挂闪烁）。
    final Widget? overlay = switch (_phase) {
      _ImagePhase.loading => widget.placeholder,
      _ImagePhase.error => widget.error,
      _ImagePhase.ready => null,
    };
    if (overlay == null) return raw;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          raw,
          Positioned.fill(child: overlay),
        ],
      ),
    );
  }
}

/// 裸图片 render 挂载层：承接 ElImageView 的全部绘制参数。
class _RawImageView extends LeafRenderObjectWidget {
  const _RawImageView({
    required this.view,
    required this.decodeVisible,
    required this.decodePriority,
    required this.reportReady,
    required this.reportError,
    this.onLoadPhase,
  });

  final ElImageView view;
  final bool Function()? decodeVisible;
  final int Function()? decodePriority;
  final ImageLoadPhaseCallback? onLoadPhase;
  final bool reportReady;
  final bool reportError;

  @override
  RenderImageView createRenderObject(BuildContext context) {
    final render = RenderImageView(
      imageProvider: view.image,
      imageConfiguration: createLocalImageConfiguration(context),
      byteSource: view.byteSource,
      decodeVisible: decodeVisible,
      decodePriority: decodePriority,
      onLoadPhase: onLoadPhase,
      reportReady: reportReady,
      reportError: reportError,
      src: view.src,
      alt: view.alt,
      style: view.style,
      event: view.event,
      node: view,
      width: view.width,
      height: view.height,
      scale: view.scale,
      color: view.color,
      colorBlendMode: view.colorBlendMode,
      fit: view.fit,
      alignment: view.alignment,
      repeat: view.repeat,
      centerSlice: view.centerSlice,
      matchTextDirection: view.matchTextDirection,
      textDirection: view.matchTextDirection || view.alignment is! Alignment ? Directionality.maybeOf(context) : null,
      invertColors: view.invertColors,
      isAntiAlias: view.isAntiAlias,
      filterQuality: view.filterQuality,
    );
    render.selectionParticipant?.bindSelectionRegistrar(SelectionContainer.maybeOf(context));
    return render;
  }

  @override
  void updateRenderObject(BuildContext context, RenderImageView renderObject) {
    renderObject
      ..imageProvider = view.image
      ..imageConfiguration = createLocalImageConfiguration(context)
      ..byteSource = view.byteSource
      ..decodeVisible = decodeVisible
      ..decodePriority = decodePriority
      ..onLoadPhase = onLoadPhase
      ..reportReady = reportReady
      ..reportError = reportError
      ..src = view.src
      ..alt = view.alt
      ..style = view.style
      ..event = view.event
      ..node = view
      ..width = view.width
      ..height = view.height
      ..scale = view.scale
      ..color = view.color
      ..colorBlendMode = view.colorBlendMode
      ..fit = view.fit
      ..alignment = view.alignment
      ..repeat = view.repeat
      ..centerSlice = view.centerSlice
      ..matchTextDirection = view.matchTextDirection
      ..textDirection = view.matchTextDirection || view.alignment is! Alignment ? Directionality.maybeOf(context) : null
      ..invertColors = view.invertColors
      ..isAntiAlias = view.isAntiAlias
      ..filterQuality = view.filterQuality;
    renderObject.selectionParticipant?.bindSelectionRegistrar(SelectionContainer.maybeOf(context));
  }

  @override
  void didUnmountRenderObject(RenderImageView renderObject) {
    renderObject.image = null;
  }
}
