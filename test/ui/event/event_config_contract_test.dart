import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/src/ui/event/index.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('同结构事件忽略回调闭包身份，但可单独识别 handler 是否相同', () {
    void first(ElEventCallback _) {}
    void second(ElEventCallback _) {}
    final left = ElEvent(
      onTap: first,
      onDragStart: first,
      onScaleUpdate: first,
      dragProxy: ElDragProxy(onDragPreUpdate: first),
    );
    final right = ElEvent(
      onTap: second,
      onDragStart: second,
      onScaleUpdate: second,
      dragProxy: ElDragProxy(onDragPreUpdate: second),
    );

    expect(left, right);
    expect(left.hashCode, right.hashCode);
    expect(left.identicalHandlers(right), isFalse);
    expect(left.identicalHandlers(left.copyWith()), isTrue);
    expect(left.dragProxy, right.dragProxy);
    expect(left.dragProxy!.hashCode, right.dragProxy!.hashCode);
  });

  test('高位 Drag、Scale、Rotation 与低位回调各自形成不同结构且支持显式清除', () {
    void first(ElEventCallback _) {}
    void second(ElEventCallback _) {}
    final shapes = <(ElEventClearField, ElEvent Function(ElEventHandler))>[
      (ElEventClearField.onPointerEnter, (h) => ElEvent(onPointerEnter: h)),
      (ElEventClearField.onTapCancel, (h) => ElEvent(onTapCancel: h)),
      (ElEventClearField.onDragDown, (h) => ElEvent(onDragDown: h)),
      (ElEventClearField.onDragStart, (h) => ElEvent(onDragStart: h)),
      (ElEventClearField.onDragUpdate, (h) => ElEvent(onDragUpdate: h)),
      (ElEventClearField.onDragEnd, (h) => ElEvent(onDragEnd: h)),
      (ElEventClearField.onDragCancel, (h) => ElEvent(onDragCancel: h)),
      (
        ElEventClearField.onVerticalDragStart,
        (h) => ElEvent(onVerticalDragStart: h),
      ),
      (
        ElEventClearField.onVerticalDragUpdate,
        (h) => ElEvent(onVerticalDragUpdate: h),
      ),
      (
        ElEventClearField.onVerticalDragEnd,
        (h) => ElEvent(onVerticalDragEnd: h),
      ),
      (
        ElEventClearField.onVerticalDragCancel,
        (h) => ElEvent(onVerticalDragCancel: h),
      ),
      (
        ElEventClearField.onHorizontalDragStart,
        (h) => ElEvent(onHorizontalDragStart: h),
      ),
      (
        ElEventClearField.onHorizontalDragUpdate,
        (h) => ElEvent(onHorizontalDragUpdate: h),
      ),
      (
        ElEventClearField.onHorizontalDragEnd,
        (h) => ElEvent(onHorizontalDragEnd: h),
      ),
      (
        ElEventClearField.onHorizontalDragCancel,
        (h) => ElEvent(onHorizontalDragCancel: h),
      ),
      (ElEventClearField.onScaleStart, (h) => ElEvent(onScaleStart: h)),
      (ElEventClearField.onScaleUpdate, (h) => ElEvent(onScaleUpdate: h)),
      (ElEventClearField.onScaleEnd, (h) => ElEvent(onScaleEnd: h)),
      (ElEventClearField.onScaleCancel, (h) => ElEvent(onScaleCancel: h)),
      (ElEventClearField.onRotationUpdate, (h) => ElEvent(onRotationUpdate: h)),
    ];
    final events = <ElEvent>[];
    for (final (field, build) in shapes) {
      final event = build(first);
      final replaced = build(second);
      expect(event.hasAnyCallback, isTrue, reason: field.name);
      expect(event, replaced, reason: '${field.name} 替换闭包不改变结构');
      expect(event.hashCode, replaced.hashCode, reason: field.name);
      expect(event.identicalHandlers(replaced), isFalse, reason: field.name);
      expect(
        event.copyWith(clear: {field}).hasAnyCallback,
        isFalse,
        reason: field.name,
      );
      expect(
        event.copyWith(clear: {field}),
        const ElEvent(),
        reason: field.name,
      );
      for (var previous = 0; previous < events.length; previous++) {
        expect(
          event,
          isNot(events[previous]),
          reason: '${field.name} 不能与 ${shapes[previous].$1.name} 共享结构',
        );
      }
      events.add(event);
    }
    expect(events.toSet(), hasLength(shapes.length));
  });

  test('copyWith 的 null 保留声明，clear 显式删除可空字段并保留标志', () {
    void handler(ElEventCallback _) {}
    final event = ElEvent(
      config: const ElEventConfig(dragStartDistance: 8),
      dragProxy: ElDragProxy(onDragOverflow: handler),
      cursor: SystemMouseCursors.click,
      behavior: HitTestBehavior.translucent,
      disabled: true,
      rotationStartEnabled: true,
      onTap: handler,
      onScaleUpdate: handler,
    );
    final retained = event.copyWith(
      config: null,
      dragProxy: null,
      cursor: null,
      onTap: null,
      onScaleUpdate: null,
    );
    expect(retained, event);
    expect(retained.identicalHandlers(event), isTrue);
    final cleared = event.copyWith(
      clear: {
        ElEventClearField.config,
        ElEventClearField.dragProxy,
        ElEventClearField.cursor,
        ElEventClearField.onTap,
        ElEventClearField.onScaleUpdate,
      },
    );
    expect(cleared.config, isNull);
    expect(cleared.dragProxy, isNull);
    expect(cleared.cursor, isNull);
    expect(cleared.hasAnyCallback, isFalse);
    expect(cleared.behavior, HitTestBehavior.translucent);
    expect(cleared.disabled, isTrue);
    expect(cleared.rotationStartEnabled, isTrue);
  });

  test('事件配置的设备与平台集合按内容比较且保持相同 hash', () {
    final first = ElEventConfig(
      dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      dragResampling: {TargetPlatform.android, TargetPlatform.windows},
    );
    final second = ElEventConfig(
      dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
      dragResampling: {TargetPlatform.windows, TargetPlatform.android},
    );
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(ElEvent(config: first), ElEvent(config: second));
    expect(ElEvent(config: first).hashCode, ElEvent(config: second).hashCode);
    expect(
      first.copyWith(dragDevices: {PointerDeviceKind.touch}),
      isNot(first),
    );
    expect(first.copyWith(dragResampling: {}), isNot(first));
  });
}
