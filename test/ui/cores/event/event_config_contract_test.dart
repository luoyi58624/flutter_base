import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/src/ui/cores/event/index.dart';
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
    final shapes =
        <(ElEvent Function(ElEvent), ElEvent Function(ElEventHandler))>[
          (
            (e) => e.copyWith(onPointerEnter: null),
            (h) => ElEvent(onPointerEnter: h),
          ),
          (
            (e) => e.copyWith(onTapCancel: null),
            (h) => ElEvent(onTapCancel: h),
          ),
          ((e) => e.copyWith(onDragDown: null), (h) => ElEvent(onDragDown: h)),
          (
            (e) => e.copyWith(onDragStart: null),
            (h) => ElEvent(onDragStart: h),
          ),
          (
            (e) => e.copyWith(onDragUpdate: null),
            (h) => ElEvent(onDragUpdate: h),
          ),
          ((e) => e.copyWith(onDragEnd: null), (h) => ElEvent(onDragEnd: h)),
          (
            (e) => e.copyWith(onDragCancel: null),
            (h) => ElEvent(onDragCancel: h),
          ),
          (
            (e) => e.copyWith(onVerticalDragStart: null),
            (h) => ElEvent(onVerticalDragStart: h),
          ),
          (
            (e) => e.copyWith(onVerticalDragUpdate: null),
            (h) => ElEvent(onVerticalDragUpdate: h),
          ),
          (
            (e) => e.copyWith(onVerticalDragEnd: null),
            (h) => ElEvent(onVerticalDragEnd: h),
          ),
          (
            (e) => e.copyWith(onVerticalDragCancel: null),
            (h) => ElEvent(onVerticalDragCancel: h),
          ),
          (
            (e) => e.copyWith(onHorizontalDragStart: null),
            (h) => ElEvent(onHorizontalDragStart: h),
          ),
          (
            (e) => e.copyWith(onHorizontalDragUpdate: null),
            (h) => ElEvent(onHorizontalDragUpdate: h),
          ),
          (
            (e) => e.copyWith(onHorizontalDragEnd: null),
            (h) => ElEvent(onHorizontalDragEnd: h),
          ),
          (
            (e) => e.copyWith(onHorizontalDragCancel: null),
            (h) => ElEvent(onHorizontalDragCancel: h),
          ),
          (
            (e) => e.copyWith(onScaleStart: null),
            (h) => ElEvent(onScaleStart: h),
          ),
          (
            (e) => e.copyWith(onScaleUpdate: null),
            (h) => ElEvent(onScaleUpdate: h),
          ),
          ((e) => e.copyWith(onScaleEnd: null), (h) => ElEvent(onScaleEnd: h)),
          (
            (e) => e.copyWith(onScaleCancel: null),
            (h) => ElEvent(onScaleCancel: h),
          ),
          (
            (e) => e.copyWith(onRotationUpdate: null),
            (h) => ElEvent(onRotationUpdate: h),
          ),
        ];
    final events = <ElEvent>[];
    for (final (clear, build) in shapes) {
      final event = build(first);
      final replaced = build(second);
      expect(event.hasAnyCallback, isTrue, reason: build.toString());
      expect(event, replaced, reason: '${build.toString()} 替换闭包不改变结构');
      expect(event.hashCode, replaced.hashCode, reason: build.toString());
      expect(
        event.identicalHandlers(replaced),
        isFalse,
        reason: build.toString(),
      );
      expect(clear(event).hasAnyCallback, isFalse, reason: build.toString());
      expect(clear(event), const ElEvent(), reason: build.toString());
      for (var previous = 0; previous < events.length; previous++) {
        expect(
          event,
          isNot(events[previous]),
          reason:
              '${build.toString()} 不能与 ${shapes[previous].$2.toString()} 共享结构',
        );
      }
      events.add(event);
    }
    expect(events.toSet(), hasLength(shapes.length));
  });

  test('生成 copyWith 省略保留、显式 null 清除，并保留非空标志', () {
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
    final retained = event.copyWith();
    expect(retained, event);
    expect(retained.identicalHandlers(event), isTrue);
    final cleared = event.copyWith(
      config: null,
      dragProxy: null,
      cursor: null,
      onTap: null,
      onScaleUpdate: null,
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
    );
    final second = ElEventConfig(
      dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
    );
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(ElEvent(config: first), ElEvent(config: second));
    expect(ElEvent(config: first).hashCode, ElEvent(config: second).hashCode);
    expect(
      first.copyWith(dragDevices: {PointerDeviceKind.touch}),
      isNot(first),
    );
  });

  test('生成配置复制接受整数字面量且可恢复默认声明', () {
    const config = ElEventConfig(dragStartDistance: 8, tapCancelDistance: 12);
    final immediate = config.copyWith(dragStartDistance: 0);
    expect(immediate.dragStartDistance, 0.0);
    expect(immediate.tapCancelDistance, 12.0);
    expect(
      immediate.copyWith(dragStartDistance: null).dragStartDistance,
      isNull,
    );
    expect(
      ElEvent(config: config).copyWith(config: const ElEventConfig()).config,
      const ElEventConfig(),
    );
  });
}
