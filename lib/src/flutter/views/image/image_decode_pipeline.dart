import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show BoxFit, applyBoxFit;

import 'image_byte_source.dart';
import 'image_platform_bridge.dart';

/// 内存位图命中结果：携带解码桶与原图尺寸，供重挂节点同步恢复布局和绘制。
class ImageDecodeCacheHit {
  /// 创建内存位图命中结果。
  const ImageDecodeCacheHit({
    required this.image,
    required this.bucketWidth,
    required this.originalWidth,
    required this.originalHeight,
  });

  /// 缓存持有的位图；渲染节点接管前必须 clone。
  final ui.Image image;

  /// 当前位图对应的解码宽度桶。
  final int bucketWidth;

  /// 原图像素宽。
  final int originalWidth;

  /// 原图像素高。
  final int originalHeight;
}

/// 解码请求已取消（滚出屏的 cell 撤销排队中的请求，不占解码槽位）。
/// render 侧收到后回退桶水位，重新可见时自然重试。
class ImageDecodeCanceled implements Exception {
  /// 创建已取消标记。
  const ImageDecodeCanceled();
}

/// 两级优先信号量：可见请求优先放行，同级请求按滚动方向的动态优先级推进。
class _PrioritySemaphore {
  _PrioritySemaphore(this.maxSlots);

  final int maxSlots;
  int _active = 0;
  int _sequence = 0;
  bool _drainScheduled = false;
  bool _waitersDirty = false;
  final List<_SlotWaiter> _waiters = [];

  Future<void> acquire({bool Function()? isVisible, int Function()? priority}) {
    // 无优先级的后台工作保留零延迟直通。虚拟图片请求则合并到当前微任务
    // 批次后统一排序：同一帧挂载的整行 cell 必须先全部入队，反向滚动时才
    // 能真正从大 index 开始，而不是被最先调用 acquire 的左列抢走空槽。
    if (priority == null && _waiters.isEmpty && _active < maxSlots) {
      _active++;
      return Future<void>.value();
    }
    final waiter = _SlotWaiter(isVisible, priority, _sequence++);
    _waiters.add(waiter);
    _waitersDirty = true;
    if (priority == null) {
      _drain();
    } else {
      _scheduleDrain();
    }
    return waiter.completer.future;
  }

  void release() {
    assert(_active > 0);
    _active--;
    _drain();
  }

  void _scheduleDrain() {
    if (_drainScheduled) return;
    _drainScheduled = true;
    scheduleMicrotask(() {
      _drainScheduled = false;
      _drain();
    });
  }

  void _drain() {
    _sortWaitersIfNeeded();
    while (_active < maxSlots && _waiters.isNotEmpty) {
      final waiter = _waiters.removeLast();
      _active++;
      waiter.completer.complete();
    }
  }

  void _sortWaitersIfNeeded() {
    if (_waiters.length < 2) {
      if (_waiters.isNotEmpty) _waiters.first.resolve();
      _waitersDirty = false;
      return;
    }
    // 旧队列积压期间仍可能滚动反向，cacheExtent 内的等待项也可能刚进入
    // 可见区。每次槽位释放只做一次轻量状态扫描；值没变便不重排，避免旧版
    // 每取一个槽都重新做完整优先级选择与 removeAt 的双重 O(n²) 成本。
    if (!_waitersDirty) {
      var changed = false;
      for (final waiter in _waiters) {
        if (waiter.hasDynamicValueChanged) {
          changed = true;
          break;
        }
      }
      if (!changed) return;
    }
    for (final waiter in _waiters) {
      waiter.resolve();
    }
    // 最优项放末尾，release 后 removeLast 是 O(1)。
    _waiters.sort(_compareWorstFirst);
    _waitersDirty = false;
  }

  int _compareWorstFirst(_SlotWaiter left, _SlotWaiter right) {
    if (left.resolvedVisible != right.resolvedVisible) return left.resolvedVisible ? 1 : -1;
    final leftPriority = left.resolvedPriority;
    final rightPriority = right.resolvedPriority;
    if (leftPriority != null && rightPriority != null && leftPriority != rightPriority) {
      return rightPriority.compareTo(leftPriority);
    }
    if (leftPriority != null && rightPriority == null) return 1;
    if (leftPriority == null && rightPriority != null) return -1;
    return right.sequence.compareTo(left.sequence);
  }
}

class _SlotWaiter {
  _SlotWaiter(this.isVisible, this.priority, this.sequence);

  final Completer<void> completer = Completer<void>();
  final bool Function()? isVisible;
  final int Function()? priority;
  final int sequence;
  bool resolvedVisible = false;
  int? resolvedPriority;

  bool get hasDynamicValueChanged =>
      resolvedVisible != (isVisible?.call() ?? false) || resolvedPriority != priority?.call();

  void resolve() {
    resolvedVisible = isVisible?.call() ?? false;
    resolvedPriority = priority?.call();
  }
}

/// 两段式解码管线（自管，不依赖官方 ImageCache）：
///
/// - **段一（描述符）**：字节 → [ui.ImageDescriptor]，只解图片头拿原始宽高
///   （KB 级/微秒），供布局 intrinsic；
/// - **段二（像素）**：布局定出展示尺寸后按 32px 桶 `instantiateCodec(
///   targetWidth:)` 定尺寸解码——永远只解展示所需的像素量（Glide into()
///   语义的 el 化）。
///
/// 三个不变量：
/// 1. **去重独立于缓存**：in-flight 表按 key 合并并发请求，缓存清空/关闭不
///    影响去重（ImageCache 置 0 事故的教训内化为设计约束）；
/// 2. **桶单调复用**：已有 ≥ 目标桶的位图直接复用（缩小绘制无画质损失），
///    只有变大才重解；
/// 3. **动图让路**：codec 帧数 > 1 时管线不接（返回 null），调用方回退官方
///    provider 管线保留动画。
class ImageDecodePipeline {
  ImageDecodePipeline._();

  /// 全局单例。
  static final ImageDecodePipeline instance = ImageDecodePipeline._();

  /// 是否启用按设备内存等级计算的位图预算；基准可用 dart-define 关闭做 A/B。
  static const bool adaptiveCacheEnabled = bool.fromEnvironment('EL_IMAGE_ADAPTIVE_CACHE', defaultValue: true);

  /// 是否启用 Android MediaStore 系统缩略图；基准可用 dart-define 关闭做 A/B。
  static const bool mediaStoreThumbnailEnabled = bool.fromEnvironment(
    'EL_IMAGE_MEDIASTORE_THUMBNAILS',
    defaultValue: true,
  );

  /// Android 缩略图后端；默认 Glide，多级缓存 A/B 可切回 `mediaStore`。
  static const String androidThumbnailEngine = String.fromEnvironment(
    'EL_IMAGE_ANDROID_THUMBNAIL_ENGINE',
    defaultValue: 'glide',
  );

  /// 同源节点重挂时同步复用当前最大解码桶，不经过 Future、文件 IO 或额外帧。
  ImageDecodeCacheHit? findCached(ImageByteSource source) {
    final srcKey = source.key;
    final original = _originalSizeBySrc[srcKey];
    if (original == null) return null;
    final entries = _bitmapsBySrc[srcKey];
    _BitmapEntry? best;
    if (entries != null) {
      for (final entry in entries) {
        if (best == null || entry.bucketWidth > best.bucketWidth) best = entry;
      }
    }
    if (best == null) return null;
    // LRU touch。
    _bitmaps.remove(best.cacheKey);
    _bitmaps[best.cacheKey] = best;
    return ImageDecodeCacheHit(
      image: best.image,
      bucketWidth: best.bucketWidth,
      originalWidth: original.width,
      originalHeight: original.height,
    );
  }

  /// 同源描述符已加载时同步返回原图尺寸，避免重挂节点再等待一轮 Future。
  ImageDescriptorInfo? findDescriptor(ImageByteSource source) {
    final entry = _descriptors.remove(source.key);
    if (entry == null) return null;
    _descriptors[source.key] = entry;
    return entry.info;
  }

  // --- 段一：描述符 ---------------------------------------------------------

  final Map<String, Future<_DescriptorEntry>> _descriptorInFlight = {};
  final LinkedHashMap<String, _DescriptorEntry> _descriptors = LinkedHashMap();
  int _descriptorBytes = 0;

  /// 描述符缓存上限（持有压缩字节）。
  static const int _maxDescriptorBytes = 64 << 20;

  // --- 段二：位图 -----------------------------------------------------------

  final Map<String, Future<ui.Image?>> _decodeInFlight = {};
  final Map<String, Future<ImageDecodeCacheHit?>> _mediaDecodeInFlight = {};
  final LinkedHashMap<String, _BitmapEntry> _bitmaps = LinkedHashMap();
  int _mediaThumbnailHits = 0;
  int _mediaThumbnailMisses = 0;

  /// per-src 位图索引：srcKey → 该源的全部缓存条目。查询/复用不再 O(全表)
  /// startsWith 扫描（照片墙数百条目 × 滚动中高频 decode 调用的热路径）。
  final Map<String, List<_BitmapEntry>> _bitmapsBySrc = {};
  int _bitmapBytes = 0;

  /// srcKey → 原图尺寸轻量表（两个 int，随位图缓存同生共死）。
  final Map<String, ImageDescriptorInfo> _originalSizeBySrc = {};

  /// 同源解码串行链：同一 descriptor 上并发 instantiateCodec 是 engine 侧
  /// 竞态嫌疑（真机 io.worker SIGSEGV 的候选根因之二；测试里表现为偶发
  /// "Codec failed"）。同 src 的不同桶解码依次执行——串行还白赚复用：前一个
  /// 若是全尺寸/更大桶，后一个直接命中位图缓存不再解码。
  final Map<String, Future<void>> _perSourceDecodeChain = {};

  /// 全局解码并发闸门（两级优先：可见插队，预挂载 FIFO）。快速滚动每秒
  /// 涌入几十个解码请求，无上限并发会打满 worker、瞬时内存峰值叠加。
  final _PrioritySemaphore _decodeSlots = _PrioritySemaphore(4);

  /// 文件 IO 闸门（段一读原片）：冷图要读取完整压缩文件（MB 级），真机
  /// UFS 上快滚的 IO 洪峰同样要限流 + 可见优先；与解码槽分开，避免 IO 等待
  /// 饿死解码（或反之）。
  final _PrioritySemaphore _ioSlots = _PrioritySemaphore(6);

  /// 位图缓存保底上限。
  static const int _defaultBitmapBytes = 128 << 20;
  int _maxBitmapBytes = _defaultBitmapBytes;
  Future<void>? _platformTuning;

  /// 读取平台内存等级并设置位图预算；同进程只执行一次。
  Future<void> ensurePlatformTuning() => _platformTuning ??= _loadPlatformTuning();

  Future<void> _loadPlatformTuning() async {
    if (!adaptiveCacheEnabled) return;
    final profile = await ImagePlatformBridge.deviceProfile();
    if (profile == null) return;
    _maxBitmapBytes = cacheBudgetForProfile(profile);
    _evictBitmaps();
  }

  /// 按设备画像计算位图预算；保底 128MB，并受常规应用内存等级与 12 屏像素量双重约束。
  @visibleForTesting
  static int cacheBudgetForProfile(ImageDeviceProfile profile) {
    final memoryBytes = profile.memoryClassMb << 20;
    final memoryCap = (memoryBytes * (profile.lowRam ? 0.35 : 0.60)).floor();
    final screenBytes = profile.screenWidthPx * profile.screenHeightPx * 4;
    final screenTarget = screenBytes * 12;
    return math.max(_defaultBitmapBytes, math.min(memoryCap, screenTarget));
  }

  /// 测试探针：返回一批虚拟图片实际取得槽位的顺序。
  @visibleForTesting
  static Future<List<int>> debugScheduleDecodePriorities(
    List<int> indices, {
    required bool forward,
    int maxSlots = 1,
    Set<int>? visibleIndices,
    int? reverseAfterStarts,
    void Function(int startedCount)? onStarted,
  }) async {
    final slots = _PrioritySemaphore(maxSlots);
    final started = <int>[];
    var currentForward = forward;
    await Future.wait([
      for (final index in indices)
        slots
            .acquire(
              isVisible: () => visibleIndices?.contains(index) ?? true,
              priority: () => currentForward ? index : -index,
            )
            .then((_) {
              started.add(index);
              onStarted?.call(started.length);
              if (started.length == reverseAfterStarts) currentForward = !currentForward;
              slots.release();
            }),
    ]);
    return started;
  }

  /// 测试探针：只测一批请求入队并取得首批槽位，不把后续异步解码耗时混入帧预算。
  @visibleForTesting
  static Future<List<int>> debugScheduleDecodePriorityBatch(
    List<int> indices, {
    required bool forward,
    int maxSlots = 4,
  }) {
    final slots = _PrioritySemaphore(maxSlots);
    final started = <int>[];
    final ready = Completer<List<int>>();
    final expected = math.min(indices.length, maxSlots);
    if (expected == 0) return Future<List<int>>.value(started);
    for (final index in indices) {
      unawaited(
        slots.acquire(isVisible: () => true, priority: () => forward ? index : -index).then((_) {
          started.add(index);
          if (started.length == expected) ready.complete(started);
        }),
      );
    }
    return ready.future;
  }

  /// 取（或加载）图片描述符：原始宽高 + 后续按桶解码的入口。
  Future<ImageDescriptorInfo> descriptorFor(
    ImageByteSource source, {
    bool Function()? isCanceled,
    bool Function()? isVisible,
    int Function()? priority,
  }) async {
    return (await _entryFor(source, isCanceled: isCanceled, isVisible: isVisible, priority: priority)).info;
  }

  /// 内部：取 entry 本体。解码调用方用 [retain] 在返回前锁定 native 描述符；
  /// LRU 驱逐只做标记，最后一个解码调用方释放后才真正 dispose，避免
  /// `io.worker` use-after-free，也避免把近 GB 资源拖给 GC finalizer。
  Future<_DescriptorEntry> _entryFor(
    ImageByteSource source, {
    bool Function()? isCanceled,
    bool Function()? isVisible,
    int Function()? priority,
    bool retain = false,
  }) async {
    final key = source.key;
    final cached = _descriptors.remove(key);
    if (cached != null) {
      _descriptors[key] = cached; // LRU touch
      if (retain) cached.retain();
      return cached;
    }
    final inFlight = _descriptorInFlight[key];
    if (inFlight != null) {
      final entry = await _joinInFlight(
        inFlight,
        () => _entryFor(source, isCanceled: isCanceled, isVisible: isVisible, priority: priority),
        isCanceled,
      );
      if (retain) entry.retain();
      return entry;
    }
    final future = _loadAndCacheDescriptor(source, isCanceled, isVisible, priority);
    _descriptorInFlight[key] = future;
    try {
      final entry = await future;
      if (retain) entry.retain();
      return entry;
    } finally {
      _descriptorInFlight.remove(key);
    }
  }

  Future<_DescriptorEntry> _loadAndCacheDescriptor(
    ImageByteSource source,
    bool Function()? isCanceled,
    bool Function()? isVisible,
    int Function()? priority,
  ) async {
    final entry = await _loadDescriptor(source, isCanceled, isVisible, priority);
    _descriptors[source.key] = entry;
    _descriptorBytes += entry.byteLength;
    _evictDescriptors();
    return entry;
  }

  Future<_DescriptorEntry> _loadDescriptor(
    ImageByteSource source,
    bool Function()? isCanceled,
    bool Function()? isVisible,
    int Function()? priority,
  ) async {
    await _ioSlots.acquire(isVisible: isVisible, priority: priority);
    try {
      // 滚出屏的 cell 在 IO 排队期被撤销：整个原片文件读取一分不付。
      if (isCanceled?.call() ?? false) throw const ImageDecodeCanceled();
      return await _loadDescriptorBody(source);
    } finally {
      _ioSlots.release();
    }
  }

  Future<_DescriptorEntry> _loadDescriptorBody(ImageByteSource source) async {
    // native 直读缓冲（file→fromFilePath / asset→fromAsset）：MB 级原片字节
    // 零 Dart heap 经手——readAsBytes→fromUint8List 双拷贝 + GC 风暴是真机
    // 网格滚动断崖掉帧的头号结构性成本。
    final buffer = await source.loadBuffer();
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    return _DescriptorEntry(
      descriptor: descriptor,
      byteLength: buffer.length,
      info: ImageDescriptorInfo(width: descriptor.width, height: descriptor.height),
    );
  }

  /// 按尺寸桶解码位图。[bucketWidth] 应来自 [bucketForTargetWidth]。
  ///
  /// 返回 null = 动图（多帧），调用方回退官方管线。[isCanceled] 在排队/开工
  /// 前查询：已取消的请求抛 [ImageDecodeCanceled]，不占解码槽位——滚出屏
  /// 的 cell 由此撤销排队（白屏修复：可见请求不再被废请求垫底）。
  Future<ui.Image?> decode(
    ImageByteSource source,
    int bucketWidth, {
    bool Function()? isCanceled,
    bool Function()? isVisible,
    int Function()? priority,
  }) async {
    final srcKey = source.key;
    // 桶单调复用：现存 ≥ 目标桶的最小位图直接用。
    final reuse = _smallestBitmapAtLeast(srcKey, bucketWidth);
    if (reuse != null) return reuse;
    final key = '$srcKey@$bucketWidth';
    final inFlight = _decodeInFlight[key];
    if (inFlight != null) {
      return _joinInFlight(
        inFlight,
        () => decode(source, bucketWidth, isCanceled: isCanceled, isVisible: isVisible, priority: priority),
        isCanceled,
      );
    }
    final future = _decode(source, srcKey, bucketWidth, key, isCanceled, isVisible, priority);
    _decodeInFlight[key] = future;
    return future;
  }

  /// 用 Android MediaStore 系统缩略图完成与布局尺寸一致的解码；不可用时返回 null。
  Future<ImageDecodeCacheHit?> decodeMediaThumbnail(
    ImageByteSource source,
    ui.Size layoutSize,
    double devicePixelRatio,
    BoxFit fit, {
    bool Function()? isCanceled,
    bool Function()? isVisible,
    int Function()? priority,
  }) async {
    final path = source.localPath;
    if (!mediaStoreThumbnailEnabled || path == null || !_supportsMediaThumbnail(path) || layoutSize.isEmpty) {
      return null;
    }
    await ensurePlatformTuning();
    final cached = findCached(source);
    if (cached != null) {
      final info = ImageDescriptorInfo(width: cached.originalWidth, height: cached.originalHeight);
      final needed = bucketForLayout(info, layoutSize, devicePixelRatio, fit);
      if (cached.bucketWidth >= needed) return cached;
    }
    final width = math.max(1, (layoutSize.width * devicePixelRatio).ceil());
    final height = math.max(1, (layoutSize.height * devicePixelRatio).ceil());
    final requestKey = '${source.key}@media:$androidThumbnailEngine:${fit.name}:$width×$height';
    final inFlight = _mediaDecodeInFlight[requestKey];
    if (inFlight != null) {
      return _joinInFlight(
        inFlight,
        () => decodeMediaThumbnail(
          source,
          layoutSize,
          devicePixelRatio,
          fit,
          isCanceled: isCanceled,
          isVisible: isVisible,
          priority: priority,
        ),
        isCanceled,
      );
    }
    final future = _decodeMediaThumbnail(
      source,
      path,
      width,
      height,
      layoutSize,
      devicePixelRatio,
      fit,
      isCanceled,
      isVisible,
      priority,
      requestKey,
    );
    _mediaDecodeInFlight[requestKey] = future;
    return future;
  }

  Future<ImageDecodeCacheHit?> _decodeMediaThumbnail(
    ImageByteSource source,
    String path,
    int width,
    int height,
    ui.Size layoutSize,
    double devicePixelRatio,
    BoxFit fit,
    bool Function()? isCanceled,
    bool Function()? isVisible,
    int Function()? priority,
    String requestKey,
  ) async {
    await _decodeSlots.acquire(isVisible: isVisible, priority: priority);
    try {
      if (isCanceled?.call() ?? false) throw const ImageDecodeCanceled();
      final thumbnail = await ImagePlatformBridge.loadMediaThumbnail(
        path: path,
        width: width,
        height: height,
        fit: fit.name,
        engine: androidThumbnailEngine,
      );
      if (thumbnail == null) {
        _mediaThumbnailMisses++;
        return null;
      }
      _mediaThumbnailHits++;
      final original = ImageDescriptorInfo(width: thumbnail.originalWidth, height: thumbnail.originalHeight);
      final bucketWidth = bucketForLayout(original, layoutSize, devicePixelRatio, fit);
      final reuse = _smallestBitmapAtLeast(source.key, bucketWidth);
      if (reuse != null) {
        return ImageDecodeCacheHit(
          image: reuse,
          bucketWidth: bucketWidth,
          originalWidth: original.width,
          originalHeight: original.height,
        );
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(thumbnail.pixels);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: thumbnail.thumbnailWidth,
        height: thumbnail.thumbnailHeight,
        rowBytes: thumbnail.rowBytes,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      try {
        final codec = await descriptor.instantiateCodec();
        late final ui.Image image;
        try {
          final frame = await codec.getNextFrame();
          image = frame.image;
        } finally {
          codec.dispose();
        }
        _cacheBitmap(source.key, image, bucketWidth: bucketWidth, isFullResolution: false, original: original);
        return ImageDecodeCacheHit(
          image: image,
          bucketWidth: bucketWidth,
          originalWidth: original.width,
          originalHeight: original.height,
        );
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
    } finally {
      _decodeSlots.release();
      _mediaDecodeInFlight.remove(requestKey);
    }
  }

  bool _supportsMediaThumbnail(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.avif');
  }

  /// 加入共享 in-flight future：其取消信号只绑定首个发起方——首个滚出屏引发
  /// 的 [ImageDecodeCanceled] 不得传染给仍存活的本调用方（否则滚回的可见
  /// cell 会一直白屏）。捕获共享取消后以自己的取消回调重新发起；此时
  /// in-flight 槽已在原请求的 finally 里清空，重试即全新请求。
  Future<T> _joinInFlight<T>(Future<T> inFlight, Future<T> Function() retry, bool Function()? isCanceled) {
    return inFlight.catchError((Object error) {
      if (isCanceled?.call() ?? false) throw const ImageDecodeCanceled();
      return retry();
    }, test: (error) => error is ImageDecodeCanceled);
  }

  Future<ui.Image?> _decode(
    ImageByteSource source,
    String srcKey,
    int bucketWidth,
    String key,
    bool Function()? isCanceled,
    bool Function()? isVisible,
    int Function()? priority,
  ) async {
    // 串行闸门：排在同 src 前序解码之后（见 _perSourceDecodeChain 注释）。
    final prior = _perSourceDecodeChain[srcKey] ?? Future<void>.value();
    final gate = Completer<void>();
    _perSourceDecodeChain[srcKey] = gate.future;
    await prior;
    await _decodeSlots.acquire(isVisible: isVisible, priority: priority);
    try {
      // 取消检查在取槽后统一做（清理走 finally 一条路）：已取消的请求立刻
      // 让出槽位，真正的解码成本一分不付。
      if (isCanceled?.call() ?? false) throw const ImageDecodeCanceled();
      // 前序解码可能已产出可复用位图（全尺寸/更大桶）：串行后再查一次。
      final reuse = _smallestBitmapAtLeast(srcKey, bucketWidth);
      if (reuse != null) return reuse;
      // retain 跨过整个解码期：被 LRU 逐出只会标记，release 后才释放。
      final entry = await _entryFor(
        source,
        isCanceled: isCanceled,
        isVisible: isVisible,
        priority: priority,
        retain: true,
      );
      try {
        final info = entry.info;
        // 目标不超原图：超采样无意义。
        final targetWidth = bucketWidth >= info.width ? null : bucketWidth;
        final codec = await entry.descriptor.instantiateCodec(targetWidth: targetWidth);
        late final ui.Image image;
        try {
          if (codec.frameCount > 1) return null; // 动图让路
          final frame = await codec.getNextFrame();
          image = frame.image;
        } finally {
          codec.dispose();
        }
        final decodedBucket = targetWidth ?? info.width;
        _cacheBitmap(srcKey, image, bucketWidth: decodedBucket, isFullResolution: targetWidth == null, original: info);
        return image;
      } finally {
        entry.release();
      }
    } finally {
      _decodeSlots.release();
      _decodeInFlight.remove(key);
      gate.complete();
      if (identical(_perSourceDecodeChain[srcKey], gate.future)) {
        _perSourceDecodeChain.remove(srcKey);
      }
    }
  }

  void _cacheBitmap(
    String srcKey,
    ui.Image image, {
    required int bucketWidth,
    required bool isFullResolution,
    required ImageDescriptorInfo original,
  }) {
    _originalSizeBySrc[srcKey] = original;
    final cacheKey = '$srcKey@$bucketWidth';
    final bytes = image.width * image.height * 4;
    final replaced = _bitmaps.remove(cacheKey);
    if (replaced != null) {
      _bitmapBytes -= replaced.bytes;
      _bitmapsBySrc[srcKey]?.remove(replaced);
      if (!identical(replaced.image, image)) replaced.image.dispose();
    }
    final cached = _BitmapEntry(
      srcKey: srcKey,
      cacheKey: cacheKey,
      image: image,
      bucketWidth: bucketWidth,
      // 原图全尺寸解码（目标桶 ≥ 原宽）：分辨率已封顶，任何桶请求都可复用。
      isFullResolution: isFullResolution,
      bytes: bytes,
    );
    _bitmaps[cacheKey] = cached;
    (_bitmapsBySrc[srcKey] ??= []).add(cached);
    _bitmapBytes += bytes;
    _evictBitmaps();
  }

  ui.Image? _smallestBitmapAtLeast(String srcKey, int bucketWidth) {
    final entries = _bitmapsBySrc[srcKey];
    _BitmapEntry? best;
    if (entries != null) {
      for (final value in entries) {
        if (!value.isFullResolution && value.bucketWidth < bucketWidth) continue;
        if (best == null || value.bucketWidth < best.bucketWidth) best = value;
      }
    }
    if (best == null) return null;
    // LRU touch。
    _bitmaps.remove(best.cacheKey);
    _bitmaps[best.cacheKey] = best;
    return best.image;
  }

  void _evictDescriptors() {
    final limit = debugMaxDescriptorBytesOverride ?? _maxDescriptorBytes;
    while (_descriptorBytes > limit && _descriptors.length > 1) {
      final oldest = _descriptors.remove(_descriptors.keys.first)!;
      _descriptorBytes -= oldest.byteLength;
      oldest.evict();
    }
  }

  void _evictBitmaps() {
    final limit = debugMaxBitmapBytesOverride ?? _maxBitmapBytes;
    while (_bitmapBytes > limit && _bitmaps.length > 1) {
      final oldest = _bitmaps.remove(_bitmaps.keys.first)!;
      _bitmapBytes -= oldest.bytes;
      final list = _bitmapsBySrc[oldest.srcKey];
      list?.remove(oldest);
      if (list != null && list.isEmpty) {
        _bitmapsBySrc.remove(oldest.srcKey);
        _originalSizeBySrc.remove(oldest.srcKey);
      }
      // Render 持有 clone，缓存 handle 可立即释放；拖到 GC finalizer 批量回收会
      // 在数百张热滚时制造几十毫秒尖峰。
      oldest.image.dispose();
    }
  }

  /// 展示宽 → 32px 桶（下限 64），避免 2 的幂把常见 cell 过度放大解码。
  static int bucketForTargetWidth(double targetWidth) {
    final needed = targetWidth.ceil().clamp(1, 1 << 30);
    return math.max(64, ((needed + 31) ~/ 32) * 32);
  }

  /// 按原图比例、布局尺寸、DPR 与 fit 推导所需解码宽度桶。
  static int bucketForLayout(ImageDescriptorInfo info, ui.Size layoutSize, double dpr, BoxFit fit) {
    final original = ui.Size(info.width.toDouble(), info.height.toDouble());
    final fitted = applyBoxFit(fit, original, layoutSize);
    final destinationPhysicalWidth = fitted.destination.width * dpr;
    final targetWidth = fitted.source.width <= 0
        ? info.width.toDouble()
        : destinationPhysicalWidth * info.width / fitted.source.width;
    return bucketForTargetWidth(targetWidth);
  }

  /// 测试钩子：驱逐上限覆盖（null = 生产默认）。
  @visibleForTesting
  static int? debugMaxDescriptorBytesOverride;

  /// 测试钩子：位图驱逐上限覆盖（null = 生产默认）。
  @visibleForTesting
  static int? debugMaxBitmapBytesOverride;

  /// 测试钩子：清空全部缓存与计数；在途描述符延迟到 release 后释放。
  @visibleForTesting
  void debugClear() {
    for (final entry in _descriptors.values) {
      entry.evict();
    }
    _descriptors.clear();
    _descriptorBytes = 0;
    for (final entry in _bitmaps.values) {
      entry.image.dispose();
    }
    _bitmaps.clear();
    _bitmapsBySrc.clear();
    _originalSizeBySrc.clear();
    _bitmapBytes = 0;
    _mediaThumbnailHits = 0;
    _mediaThumbnailMisses = 0;
  }

  /// 重置设备画像结果，供同进程 A/B 单测重新注入平台返回值。
  @visibleForTesting
  void debugResetPlatformTuning() {
    _platformTuning = null;
    _maxBitmapBytes = _defaultBitmapBytes;
  }

  /// 当前内存位图条目数。
  @visibleForTesting
  int get debugBitmapCount => _bitmaps.length;

  /// 当前内存位图估算字节数。
  @visibleForTesting
  int get debugBitmapBytes => _bitmapBytes;

  /// 低清保底图机制已移除；旧 benchmark 统计字段固定为 0。
  @visibleForTesting
  int get debugFallbackBitmapCount => 0;

  /// 低清保底图机制已移除；旧 benchmark 统计字段固定为 0。
  @visibleForTesting
  int get debugFallbackBitmapBytes => 0;

  /// 当前自适应位图缓存上限。
  @visibleForTesting
  int get debugBitmapLimitBytes => debugMaxBitmapBytesOverride ?? _maxBitmapBytes;

  /// MediaStore 系统缩略图成功次数。
  @visibleForTesting
  int get debugMediaThumbnailHits => _mediaThumbnailHits;

  /// MediaStore 系统缩略图不可用并回退原图管线的次数。
  @visibleForTesting
  int get debugMediaThumbnailMisses => _mediaThumbnailMisses;

  /// 当前描述符条目数。
  @visibleForTesting
  int get debugDescriptorCount => _descriptors.length;
}

/// 描述符头信息（原始像素尺寸）。
@immutable
class ImageDescriptorInfo {
  /// 创建原图尺寸信息。
  const ImageDescriptorInfo({required this.width, required this.height});

  /// 原图像素宽。
  final int width;

  /// 原图像素高。
  final int height;
}

class _DescriptorEntry {
  _DescriptorEntry({required this.descriptor, required this.byteLength, required this.info});

  final ui.ImageDescriptor descriptor;
  final int byteLength;
  final ImageDescriptorInfo info;

  int _retainCount = 0;
  bool _evicted = false;
  bool _disposed = false;

  void retain() {
    assert(!_disposed);
    _retainCount++;
  }

  void release() {
    assert(_retainCount > 0);
    _retainCount--;
    _disposeIfUnused();
  }

  void evict() {
    _evicted = true;
    _disposeIfUnused();
  }

  void _disposeIfUnused() {
    if (!_evicted || _retainCount != 0 || _disposed) return;
    _disposed = true;
    descriptor.dispose();
  }
}

class _BitmapEntry {
  _BitmapEntry({
    required this.srcKey,
    required this.cacheKey,
    required this.image,
    required this.bucketWidth,
    required this.isFullResolution,
    required this.bytes,
  });

  final String srcKey;
  final String cacheKey;
  final ui.Image image;
  final int bucketWidth;

  /// 原图全尺寸解码：分辨率封顶，任何桶请求可复用。
  final bool isFullResolution;
  final int bytes;
}
