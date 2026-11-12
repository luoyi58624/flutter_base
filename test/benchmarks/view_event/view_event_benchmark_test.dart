// 基准需要直接读取 VM 的分配概况；vm_service 随 flutter_test 提供，不为此新增依赖。
// ignore_for_file: depend_on_referenced_packages, avoid_print

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart';

/// 显式开启计时采样；默认只用很小的规模检查场景本身能跑通。
const _timing = bool.fromEnvironment('VIEW_EVENT_TIMING');

/// 显式开启内存测量，需要同时传入 `--enable-vmservice`。
const _memory = bool.fromEnvironment('VIEW_EVENT_MEMORY');

const _samples = int.fromEnvironment('VIEW_EVENT_SAMPLES', defaultValue: _timing ? 15 : 2);
const _warmups = _timing ? 4 : 1;
const _views = _timing ? 2000 : 50;
const _depth = 16;
const _strokes = _timing ? 300 : 10;
const _memoryViews = 20000;

/// 三种声明：纯样式、可点击、带焦点变体。
enum _Kind { plain, tap, focus }

Widget _view(_Kind kind, int seed) {
  final color = Color(0xFF000000 | (seed & 0xFFFFFF));
  return switch (kind) {
    .plain => ElView(style: ElStyle(width: 4, height: 4, backgroundColor: color)),
    .tap => ElView(
      style: ElStyle(width: 4, height: 4, backgroundColor: color),
      event: ElEvent(onTap: (_) {}),
    ),
    .focus => ElView(
      style: ElStyle(
        width: 4,
        height: 4,
        backgroundColor: color,
        onFocus: ElStyle(backgroundColor: Color(0xFF00FF00)),
      ),
    ),
  };
}

Widget _shell(Widget child) => Directionality(
  textDirection: .ltr,
  child: Align(alignment: .topLeft, child: child),
);

Widget _grid(_Kind kind, int count, int seed) =>
    _shell(Wrap(children: [for (var i = 0; i < count; i++) _view(kind, seed + i)]));

/// [_depth] 层嵌套的可点击视图；[leaf] 是最内层的事件声明。
Widget _chain(ElEvent Function(int level) event) {
  Widget child = SizedBox(width: 40, height: 40);
  for (var level = 0; level < _depth; level++) {
    child = ElView(event: event(level), child: child);
  }
  return _shell(child);
}

void _report(String scenario, List<int> micros, {Map<String, Object?> extra = const {}}) {
  final sorted = List.of(micros)..sort();
  print(
    'VIEW_EVENT_RESULT ${jsonEncode({'scenario': scenario, 'timing': _timing, 'samples': micros.length, 'median_us': sorted[sorted.length ~/ 2], 'min_us': sorted.first, 'max_us': sorted.last, ...extra})}',
  );
}

void main() {
  for (final kind in _Kind.values) {
    testWidgets('挂载 ${kind.name} × $_views', (tester) async {
      final micros = <int>[];
      for (var round = 0; round < _warmups + _samples; round++) {
        await tester.pumpWidget(_shell(SizedBox()));
        final tree = _grid(kind, _views, round);
        final watch = Stopwatch()..start();
        await tester.pumpWidget(tree);
        watch.stop();
        if (round >= _warmups) micros.add(watch.elapsedMicroseconds);
      }
      expect(find.byType(ElView), findsNWidgets(_views));
      _report('mount_${kind.name}', micros, extra: {'views': _views});
    });

    testWidgets('更新 ${kind.name} × $_views', (tester) async {
      final micros = <int>[];
      await tester.pumpWidget(_grid(kind, _views, 0));
      for (var round = 0; round < _warmups + _samples; round++) {
        // 每轮换一批新的声明与样式值，走完整的配置更新。
        final tree = _grid(kind, _views, 1000 + round);
        final watch = Stopwatch()..start();
        await tester.pumpWidget(tree);
        watch.stop();
        if (round >= _warmups) micros.add(watch.elapsedMicroseconds);
      }
      _report('update_${kind.name}', micros, extra: {'views': _views});
    });
  }

  testWidgets('点击 $_depth 层链路 × $_strokes', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_chain((_) => ElEvent(onTap: (_) => taps++)));
    final micros = <int>[];
    var time = Duration.zero;
    for (var round = 0; round < _warmups + _samples; round++) {
      final watch = Stopwatch()..start();
      for (var i = 0; i < _strokes; i++) {
        time += Duration(milliseconds: 500);
        _send(tester, PointerDownEvent(pointer: 1, kind: .mouse, position: Offset(20, 20), timeStamp: time));
        _send(tester, PointerUpEvent(pointer: 1, kind: .mouse, position: Offset(20, 20), timeStamp: time));
      }
      watch.stop();
      if (round >= _warmups) micros.add(watch.elapsedMicroseconds);
    }
    await tester.pump(Duration(seconds: 1));
    expect(taps, (_warmups + _samples) * _strokes * _depth);
    _report('tap_chain', micros, extra: {'depth': _depth, 'strokes': _strokes});
  });

  testWidgets('点击路线上的指针移动 $_depth 层 × $_strokes', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_chain((_) => ElEvent(onTap: (_) => taps++)));
    final micros = <int>[];
    var time = Duration.zero;
    for (var round = 0; round < _warmups + _samples; round++) {
      time += Duration(milliseconds: 500);
      _send(tester, PointerDownEvent(pointer: 1, kind: .mouse, position: Offset(20, 20), timeStamp: time));
      final watch = Stopwatch()..start();
      for (var i = 0; i < _strokes; i++) {
        time += Duration(milliseconds: 8);
        // 在点击容差内来回抖动，路线始终只有点击候选。
        final position = Offset(20 + (i.isEven ? 1 : 0), 20);
        _send(
          tester,
          PointerMoveEvent(
            pointer: 1,
            kind: .mouse,
            buttons: kPrimaryButton,
            position: position,
            delta: Offset(i.isEven ? 1 : -1, 0),
            timeStamp: time,
          ),
        );
      }
      watch.stop();
      _send(tester, PointerUpEvent(pointer: 1, kind: .mouse, position: Offset(20, 20), timeStamp: time));
      if (round >= _warmups) micros.add(watch.elapsedMicroseconds);
    }
    await tester.pump(Duration(seconds: 1));
    expect(taps, (_warmups + _samples) * _depth);
    _report('move_on_tap_route', micros, extra: {'depth': _depth, 'moves': _strokes});
  });

  testWidgets('拖拽路线上的指针移动 $_depth 层 × $_strokes', (tester) async {
    var updates = 0;
    // 最内层声明拖拽，其余祖先只声明点击：拖拽路线不能因拆分而变慢。
    await tester.pumpWidget(
      _chain(
        (level) => level == 0
            ? ElEvent(onDragStart: (_) {}, onDragUpdate: (_) => updates++, onDragEnd: (_) {})
            : ElEvent(onTap: (_) {}),
      ),
    );
    final micros = <int>[];
    var time = Duration.zero;
    for (var round = 0; round < _warmups + _samples; round++) {
      time += Duration(milliseconds: 500);
      _send(tester, PointerDownEvent(pointer: 1, kind: .mouse, position: Offset(5, 20), timeStamp: time));
      final watch = Stopwatch()..start();
      for (var i = 0; i < _strokes; i++) {
        time += Duration(milliseconds: 8);
        final x = 5 + (i % 30) + 1.0;
        _send(
          tester,
          PointerMoveEvent(
            pointer: 1,
            kind: .mouse,
            buttons: kPrimaryButton,
            position: Offset(x, 20),
            delta: Offset(1, 0),
            timeStamp: time,
          ),
        );
      }
      watch.stop();
      _send(tester, PointerUpEvent(pointer: 1, kind: .mouse, position: Offset(5, 20), timeStamp: time));
      if (round >= _warmups) micros.add(watch.elapsedMicroseconds);
    }
    await tester.pump(Duration(seconds: 1));
    expect(updates, greaterThan(0));
    _report('move_on_drag_route', micros, extra: {'depth': _depth, 'moves': _strokes});
  });

  for (final kind in _Kind.values) {
    testWidgets('常驻内存 ${kind.name} × $_memoryViews', (tester) async {
      final service = await tester.runAsync(_connect);
      if (service == null) {
        markTestSkipped('未传入 --enable-vmservice，跳过内存测量');
        return;
      }
      addTearDown(() => tester.runAsync(service.dispose));
      final isolate = developer.Service.getIsolateId(Isolate.current)!;
      Future<vm.AllocationProfile> profile() async =>
          (await tester.runAsync(() => service.getAllocationProfile(isolate, gc: true)))!;

      // 先完整挂载卸载一轮，排除静态缓存与一次性初始化。
      await tester.pumpWidget(_grid(kind, _memoryViews, 0));
      await tester.pumpWidget(_shell(SizedBox()));
      final empty = await profile();
      await tester.pumpWidget(_grid(kind, _memoryViews, 0));
      final mounted = await profile();

      Map<String, int> bytesOf(vm.AllocationProfile profile) => {
        for (final member in profile.members ?? const <vm.ClassHeapStats>[])
          if ((member.bytesCurrent ?? 0) > 0)
            '${member.classRef?.library?.uri}::${member.classRef?.name}': member.bytesCurrent!,
      };
      final before = bytesOf(empty);
      final after = bytesOf(mounted);
      final growth = <String, int>{
        for (final entry in after.entries)
          if (entry.value - (before[entry.key] ?? 0) >= _memoryViews * 8)
            entry.key.split('::').last: ((entry.value - (before[entry.key] ?? 0)) / _memoryViews).round(),
      };
      final heap = (mounted.memoryUsage!.heapUsage! - empty.memoryUsage!.heapUsage!) / _memoryViews;
      print(
        'VIEW_EVENT_RESULT ${jsonEncode({'scenario': 'retained_${kind.name}', 'views': _memoryViews, 'bytes_per_view': heap.round(), 'bytes_per_view_by_class': Map.fromEntries(growth.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))})}',
      );
    }, skip: !_memory);
  }
}

void _send(WidgetTester tester, PointerEvent event) =>
    tester.binding.handlePointerEventForSource(event, source: TestBindingEventSource.test);

Future<vm.VmService?> _connect() async {
  final uri = (await developer.Service.getInfo()).serverWebSocketUri;
  return uri == null ? null : vmServiceConnectUri(uri.toString());
}
