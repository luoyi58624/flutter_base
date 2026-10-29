import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter_base/src/ui/cores/editable/ime/editable_ime_client.dart';
import 'package:flutter_base/src/ui/cores/editable/ime/windows_ime_geometry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('el.ui/windows_ime');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> request(Map<dynamic, dynamic> snapshot, int offset, {int? generation}) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('requestPosition', {
          'owner': snapshot['owner'],
          'generation': generation ?? snapshot['generation'],
          'offset': offset,
        }),
      ),
      (_) {},
    );
  }

  test('中间位置按需合并读取，普通几何更新不遍历组合文本', () async {
    var frames = 0;
    final measured = <int>[];
    final geometry = WindowsImeGeometry(viewId: 1, onPositionRequested: () => frames++);
    addTearDown(geometry.close);
    void update({int version = 0}) => geometry.update(
      anchor: Rect.fromLTWH(10, 20, 1.5, 20),
      composingEnd: Rect.fromLTWH(110, 20, 1.5, 20),
      document: Rect.fromLTWH(0, 0, 320, 40),
      composingLength: 10,
      version: version,
      resolvePosition: (offset) {
        measured.add(offset);
        return Rect.fromLTWH(10.0 + offset * 10, 20, 1.5, 20);
      },
    );
    update();
    update();
    expect(measured, isEmpty);
    final snapshot = calls.single.arguments as Map;
    await request(snapshot, 3);
    await request(snapshot, 3);
    await request(snapshot, 5);
    await request(snapshot, 0);
    await request(snapshot, 10);
    expect(frames, 1);
    expect(measured, isEmpty, reason: '平台消息回调不得同步触发测量');
    update();
    expect(measured, [3, 5]);
    expect(calls.last.method, 'cache');
    expect(calls.last.arguments['generation'], snapshot['generation']);
    expect(calls.last.arguments['positions'], [
      {
        'offset': 3,
        'rect': [40.0, 20.0, 41.5, 40.0],
      },
      {
        'offset': 5,
        'rect': [60.0, 20.0, 61.5, 40.0],
      },
    ]);
    update();
    expect(measured, [3, 5]);
    await request(snapshot, 4);
    update(version: 1);
    expect(measured, [3, 5], reason: '文本/布局版本变化后不得解析旧 offset 请求');
    final next = calls.last.arguments as Map;
    expect(next['generation'], greaterThan(snapshot['generation'] as int));
    await request(snapshot, 4);
    expect(frames, 2, reason: '过期请求直接忽略');
    await request(next, 4);
    update(version: 1);
    expect(measured, [3, 5, 4]);
  });

  test('单版最多读取 64 个位置，布局缺失不伪造坐标，关闭后丢弃请求', () async {
    var frames = 0;
    var measures = 0;
    final geometry = WindowsImeGeometry(viewId: 1, onPositionRequested: () => frames++);
    void update() => geometry.update(
      anchor: Rect.fromLTWH(10, 20, 1.5, 20),
      document: Rect.fromLTWH(0, 0, 320, 40),
      composingLength: 100000,
      resolvePosition: (_) {
        measures++;
        return null;
      },
    );
    update();
    final snapshot = calls.single.arguments as Map;
    for (var offset = 1; offset <= 100; offset++) {
      await request(snapshot, offset);
    }
    expect(frames, 1);
    update();
    expect(measures, 64);
    expect(calls, hasLength(1), reason: '未排版位置不发送伪造结果');
    geometry.close();
    await request(snapshot, 1);
    update();
    expect(frames, 1);
    expect(measures, 64);
  });

  testWidgets('原生查询快照先于官方候选几何发送，重复帧不产生额外消息', (tester) async {
    final events = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      events.add('native.${call.method}');
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.textInput, (call) async {
      events.add(call.method);
      return null;
    });
    addTearDown(tester.testTextInput.register);
    final controller = EditableController();
    addTearDown(controller.dispose);
    final client = EditableImeClient(controller: controller);
    addTearDown(client.close);
    client.open(TextInputConfiguration(viewId: 42));
    events.clear();
    void update() => client.updateGeometry(
      size: Size(320, 40),
      transform: Matrix4.identity(),
      caretRect: Rect.fromLTWH(12, 8, 1.5, 22),
      composingRect: Rect.fromLTWH(12, 8, 24, 22),
    );
    update();
    await tester.pump();
    expect(events, [
      'native.update',
      'TextInput.setEditableSizeAndTransform',
      'TextInput.setCaretRect',
      'TextInput.setMarkedTextRect',
    ]);
    events.clear();
    update();
    await tester.pump();
    expect(events, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  test('仅在几何变化时发送缓存，关闭后不再更新且 owner 隔离连接', () async {
    final geometry = WindowsImeGeometry(viewId: 7);
    final anchor = Rect.fromLTWH(12, 20, 1.5, 22);
    final document = Rect.fromLTWH(0, 0, 320, 40);
    for (var i = 0; i < 10; i++) {
      geometry.update(anchor: anchor, document: document);
    }
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'update');
    expect(calls.single.arguments['anchor'], [12.0, 20.0, 13.5, 42.0]);
    expect((calls.single.arguments as Map).containsKey('candidate'), isFalse);
    final owner = calls.single.arguments['owner'];

    geometry.update(anchor: anchor.shift(Offset(0, 8)), document: document);
    geometry.close();
    geometry.close();
    geometry.update(anchor: anchor, document: document);
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((call) => call.method), ['update', 'update', 'clear']);
    expect(calls.last.arguments, {'viewId': 7, 'owner': owner});

    final next = WindowsImeGeometry(viewId: 7);
    next.update(anchor: anchor, document: document);
    await Future<void>.delayed(Duration.zero);
    expect(calls.last.arguments['owner'], isNot(owner));
    next.close();
    await Future<void>.delayed(Duration.zero);
  });

  test('旧进程没有原生插件时只探测一次并继续 Flutter 既有输入', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw MissingPluginException();
    });
    final geometry = WindowsImeGeometry(viewId: 0);
    for (var i = 0; i < 3; i++) {
      geometry.update(anchor: Rect.fromLTWH(i.toDouble(), 10, 1.5, 20), document: Rect.fromLTWH(0, 0, 300, 40));
      await Future<void>.delayed(Duration.zero);
    }
    geometry.close();
    expect(calls, hasLength(1));
  });

  test('组合终点独立变化也刷新缓存', () async {
    final geometry = WindowsImeGeometry(viewId: 1);
    final anchor = Rect.fromLTWH(10, 20, 1.5, 20);
    for (final length in [1, 2]) {
      geometry.update(
        anchor: anchor,
        document: Rect.fromLTWH(0, 0, 320, 40),
        composingEnd: anchor.shift(Offset(length * 10.0, 0)),
        composingLength: length,
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(calls, hasLength(2));
    expect(calls.last.arguments['length'], 2);
    expect(calls.last.arguments['end'], [30.0, 20.0, 31.5, 40.0]);
    geometry.close();
    await Future<void>.delayed(Duration.zero);
  });
}
