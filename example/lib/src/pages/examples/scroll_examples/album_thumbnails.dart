import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// 相册单项的已解码封面；格子回收时切换订阅对象。
class AlbumThumbnail extends ValueNotifier<ImageInfo?> {
  /// 用与 Flutter ImageCache 相同的 provider 读取缩略图。
  AlbumThumbnail(this.provider) : super(null);

  /// 按媒体身份与缩略图尺寸共享缓存的图片来源。
  final ImageProvider provider;

  void _release() {
    final previous = value;
    if (previous == null) return;
    final deferDisposal = hasListeners;
    value = null;
    if (deferDisposal) {
      final scheduler = SchedulerBinding.instance;
      scheduler.addPostFrameCallback((_) => previous.dispose());
      scheduler.ensureVisualUpdate();
    } else {
      previous.dispose();
    }
  }
}

/// 只为相册当前窗口发起缩略图请求，限制已经提交给平台的任务数。
class AlbumThumbnailQueue {
  /// 创建一个相册页面独享的请求队列。
  AlbumThumbnailQueue();

  static const _concurrency = 4;
  Set<AlbumThumbnail> _visible = {};
  Set<AlbumThumbnail> _ahead = {};
  final Set<AlbumThumbnail> _inFlight = {};
  final Set<AlbumThumbnail> _settled = {};
  AlbumThumbnail? _speculative;
  bool _disposed = false;

  /// 用最新视口替换等待任务，优先处理屏内图片，然后预热滚动方向。
  void update(Iterable<AlbumThumbnail> visible, Iterable<AlbumThumbnail> ahead) {
    if (_disposed) return;
    _visible = visible.toSet();
    _ahead = ahead.where((thumbnail) => !_visible.contains(thumbnail)).toSet();
    _settled.removeWhere((thumbnail) {
      if (_wanted(thumbnail)) return false;
      thumbnail._release();
      return true;
    });
    _pump();
  }

  bool _wanted(AlbumThumbnail thumbnail) => _visible.contains(thumbnail) || _ahead.contains(thumbnail);

  bool _pending(AlbumThumbnail thumbnail) => !_inFlight.contains(thumbnail) && !_settled.contains(thumbnail);

  void _pump() {
    if (_disposed) return;
    for (final thumbnail in _visible) {
      if (_inFlight.length == _concurrency) return;
      if (_pending(thumbnail)) _start(thumbnail);
    }
    // 前探只占一个槽，用户换方向时其余槽还能立刻处理新视口。
    if (_speculative != null || _inFlight.length == _concurrency) return;
    for (final thumbnail in _ahead) {
      if (!_pending(thumbnail)) continue;
      _speculative = thumbnail;
      _start(thumbnail);
      break;
    }
  }

  void _start(AlbumThumbnail thumbnail) {
    _inFlight.add(thumbnail);
    unawaited(_load(thumbnail));
  }

  Future<void> _load(AlbumThumbnail thumbnail) async {
    ImageInfo? image;
    try {
      // 直接解析 provider：由队列决定启动时机，避免 Image 在快滚期间逐帧推迟请求。
      final stream = thumbnail.provider.resolve(ImageConfiguration.empty);
      final result = Completer<ImageInfo?>();
      final listener = ImageStreamListener(
        (info, _) {
          if (result.isCompleted) {
            info.dispose();
          } else {
            result.complete(info);
          }
        },
        onError: (_, _) {
          if (!result.isCompleted) result.complete(null);
        },
      );
      stream.addListener(listener);
      try {
        image = await result.future;
      } finally {
        stream.removeListener(listener);
      }
    } catch (_) {
      // 损坏的媒体保持空白，离开再进入窗口后可以重试。
    }
    _inFlight.remove(thumbnail);
    if (identical(_speculative, thumbnail)) _speculative = null;
    if (!_disposed && _wanted(thumbnail)) {
      _settled.add(thumbnail);
      thumbnail.value = image;
    } else {
      image?.dispose();
    }
    _pump();
  }

  /// 释放窗口持有的解码结果，停止提交请求。
  void dispose() {
    _disposed = true;
    for (final thumbnail in _settled) {
      thumbnail._release();
    }
    _settled.clear();
    _visible.clear();
    _ahead.clear();
  }
}
