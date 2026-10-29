import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 将已排版的输入锚点缓存到 Windows 窗口线程，供首次候选同步定位。
final class WindowsImeGeometry {
  /// 为一个原生视图创建独立的连接所有者。
  WindowsImeGeometry({required this.viewId, this.onPositionRequested}) : _owner = ++_nextOwner {
    _owners[_owner] = this;
    if (!_handlerInstalled) {
      _handlerInstalled = true;
      _channel.setMethodCallHandler(_handleCall);
    }
  }

  /// 当前 Flutter 原生视图编号。
  final int viewId;

  /// 原生需要补充位置时通知宿主安排一次帧尾几何更新。
  final VoidCallback? onPositionRequested;
  static int _nextOwner = DateTime.now().microsecondsSinceEpoch;
  static const _channel = MethodChannel('el.ui/windows_ime');
  static final _owners = <int, WindowsImeGeometry>{};
  static bool _handlerInstalled = false;
  final int _owner;
  bool _available = true;
  bool _closed = false;
  int _generation = 0;
  final _requested = <int>{};
  ({Rect anchor, Rect end, Rect caret, int length, Rect document, Object? version, bool diagnostics})? _last;

  /// 原生诊断回调，仅诊断探针设置，事件不包含输入正文或候选内容。
  @visibleForTesting
  static ValueChanged<Map<Object?, Object?>>? debugOnEvent;

  /// 提交视图客户区中的 DIP 矩形，相同几何不重复跨平台通道。
  void update({
    required Rect anchor,
    required Rect document,
    Rect? caret,
    Rect? composingEnd,
    int composingLength = 0,
    Object? version,
    Rect? Function(int offset)? resolvePosition,
  }) {
    if (_closed || !_available || !anchor.isFinite || !document.isFinite) return;
    if (anchor.height <= 0 || document.isEmpty) return;
    final diagnostics = kDebugMode && debugOnEvent != null;
    final end = composingEnd ?? anchor;
    final currentCaret = caret ?? end;
    if (!end.isFinite || end.height <= 0 || !currentCaret.isFinite || currentCaret.height <= 0 || composingLength < 0) {
      return;
    }
    final next = (
      anchor: anchor,
      end: end,
      caret: currentCaret,
      length: composingLength,
      document: document,
      version: version,
      diagnostics: diagnostics,
    );
    if (_last == next) {
      _resolveRequestedPositions(resolvePosition);
      return;
    }
    _last = next;
    _generation++;
    _requested.clear();
    if (diagnostics) {
      debugOnEvent?.call({
        'event': 'geometry',
        'owner': _owner,
        'anchor': anchor.toString(),
        'end': end.toString(),
        'length': composingLength,
        'generation': _generation,
      });
    }
    unawaited(
      _send('update', {
        'viewId': viewId,
        'owner': _owner,
        'generation': _generation,
        'anchor': [anchor.left, anchor.top, anchor.right, anchor.bottom],
        'end': [end.left, end.top, end.right, end.bottom],
        'caret': [currentCaret.left, currentCaret.top, currentCaret.right, currentCaret.bottom],
        'length': composingLength,
        'document': [document.left, document.top, document.right, document.bottom],
        'diagnostics': diagnostics,
      }),
    );
  }

  static Future<void> _handleCall(MethodCall call) async {
    if (call.arguments is! Map) return;
    final args = (call.arguments as Map).cast<Object?, Object?>();
    if (call.method == 'trace') {
      if (kDebugMode) debugOnEvent?.call(args);
      return;
    }
    if (call.method != 'requestPosition') return;
    final owner = _owners[args['owner']];
    final offset = args['offset'];
    if (owner == null ||
        owner._closed ||
        !owner._available ||
        args['generation'] != owner._generation ||
        offset is! int ||
        offset <= 0 ||
        offset >= (owner._last?.length ?? 0) ||
        owner._requested.length >= 64) {
      return;
    }
    final wasEmpty = owner._requested.isEmpty;
    if (!owner._requested.add(offset)) return;
    if (kDebugMode) debugOnEvent?.call({'event': 'requestPosition', ...args});
    if (wasEmpty) owner.onPositionRequested?.call();
  }

  void _resolveRequestedPositions(Rect? Function(int offset)? resolve) {
    if (_requested.isEmpty || resolve == null) return;
    final positions = <Map<String, Object>>[];
    for (final offset in _requested) {
      final rect = resolve(offset);
      // 未挂载/未排版不能伪装精确结果；原生继续使用有效 caret，下一版几何再查询。
      if (rect == null || !rect.isFinite || rect.height <= 0) continue;
      positions.add({
        'offset': offset,
        'rect': [rect.left, rect.top, rect.right, rect.bottom],
      });
    }
    _requested.clear();
    if (positions.isEmpty) return;
    if (kDebugMode) {
      debugOnEvent?.call({'event': 'cachePositions', 'generation': _generation, 'count': positions.length});
    }
    unawaited(_send('cache', {'viewId': viewId, 'owner': _owner, 'generation': _generation, 'positions': positions}));
  }

  /// 释放当前连接的锚点，迟到的释放不会清除后来获得焦点的输入框。
  void close() {
    if (_closed) return;
    _closed = true;
    _owners.remove(_owner);
    _requested.clear();
    if (_last != null && _available) unawaited(_send('clear', {'viewId': viewId, 'owner': _owner}));
  }

  Future<void> _send(String method, Map<String, Object> arguments) async {
    try {
      final result = await _channel.invokeMethod<bool>(method, arguments);
      if (result == false) _available = false;
    } on MissingPluginException {
      // 单元测试与尚未重启注册原生插件的旧进程仍可走 Flutter 既有通道。
      _available = false;
    } on PlatformException catch (error) {
      _available = false;
      FlutterError.reportError(FlutterErrorDetails(exception: error, library: 'el_ui Windows IME'));
    }
  }
}
