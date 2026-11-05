import 'dart:js_interop';

// 该文件只会被 dart.library.js_interop 条件门面选中。
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// 通过浏览器 MessageChannel 让出一个 task，避免零时长 timer 的嵌套钳制。
Future<void> yieldLongLineWebEventLoop() {
  final promise = JSPromise<JSAny?>(_createPendingWebYield.toJS);
  return promise.toDart.then<void>((_) {});
}

final List<_PendingWebYield> _pendingWebYields = <_PendingWebYield>[];

void _createPendingWebYield(JSFunction resolve, JSFunction _) {
  final pending = _PendingWebYield(resolve);
  _pendingWebYields.add(pending);
  pending.start();
}

final class _PendingWebYield {
  _PendingWebYield(this.resolve) : channel = web.MessageChannel();

  final JSFunction resolve;
  final web.MessageChannel channel;
  late final JSFunction listener;

  void start() {
    listener = _handleMessage.toJS;
    channel.port1.onmessage = listener;
    channel.port1.start();
    channel.port2.postMessage(0.toJS);
  }

  void _handleMessage(web.Event _) {
    channel.port1.close();
    channel.port2.close();
    _pendingWebYields.remove(this);
    resolve.callAsFunction(resolve);
  }
}
