import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('事件模块的导出声明使用 El 前缀，内部声明不使用 El 前缀', () {
    final exportedNames = _eventExportNames().toSet();
    final declarations = RegExp(
      r'^\s*(?:(?:abstract|final|base|sealed|interface)\s+)*(?:class|enum|typedef|mixin|extension(?:\s+type)?)\s+([A-Za-z_$][\w$]*)',
      multiLine: true,
    );
    final violations = <String>[];
    for (final file in Directory('lib/src/flutter/views/view/event').listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final declaration in declarations.allMatches(file.readAsStringSync())) {
        final name = declaration.group(1)!;
        if (name.startsWith('_')) continue;
        if (exportedNames.contains(name) != name.startsWith('El')) {
          violations.add('${file.path}: $name');
        }
      }
    }
    expect(violations, isEmpty, reason: '项目规范要求导出声明使用 El 前缀，内部声明不使用 El 前缀。');
  });

  test('事件模块不保留废弃标注或过渡别名', () {
    final deprecated = RegExp(r'@\s*Deprecated\b');
    final violations = <String>[];
    for (final file in Directory('lib/src/flutter/views/view/event').listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      if (deprecated.hasMatch(file.readAsStringSync())) violations.add(file.path);
    }
    expect(violations, isEmpty, reason: '事件模块直接移除废弃 API，不保留过渡别名。');
  });

  test('SURFACE-0: 事件主入口仅保留业务 API，识别器与分发器不导出', () {
    expect(
      _eventExportNames(),
      unorderedEquals([
        'ElDragProxy',
        'ElDragProxyExt',
        'ElEvent',
        'ElEventExt',
        'ElEventDetails',
        'ElEventCancelReason',
        'ElEventConfig',
        'ElEventConfigExt',
        'ElEventHandler',
        'ElEventPhase',
        'ElFocusReason',
      ]),
    );
  });

  test('SURFACE-1: ElEventPhase、ElFocusReason 与 ElEventCancelReason 枚举面保持完整', () {
    expect(ElEventPhase.values.map((value) => value.name), <String>[
      'pointerEnter',
      'pointerHover',
      'pointerExit',
      'pointerDown',
      'pointerMove',
      'pointerUp',
      'pointerCancel',
      'pointerPanZoomStart',
      'pointerPanZoomUpdate',
      'pointerPanZoomEnd',
      'pointerSignal',
      'tapDown',
      'tapUp',
      'tap',
      'doubleTap',
      'doubleTapDown',
      'tripleTap',
      'tripleTapDown',
      'secondaryTapDown',
      'secondaryTapUp',
      'secondaryTap',
      'tertiaryTapDown',
      'tertiaryTapUp',
      'tertiaryTap',
      'forwardTapDown',
      'forwardTapUp',
      'forwardTap',
      'backTapDown',
      'backTapUp',
      'backTap',
      'longPress',
      'tapCancel',
      'dragDown',
      'dragStart',
      'dragUpdate',
      'dragEnd',
      'dragCancel',
      'scaleStart',
      'scaleUpdate',
      'scaleEnd',
      'scaleCancel',
      'rotationUpdate',
      'keyDown',
      'keyRepeat',
      'keyUp',
      'focus',
      'blur',
    ]);
    expect(ElEventPhase.tap.toString(), 'ElEventPhase.tap');
    expect(ElFocusReason.values.map((value) => value.name), <String>[
      'programmatic',
      'pointer',
      'keyboard',
      'lifecycle',
    ]);
    expect(ElEventCancelReason.values.map((value) => value.name), <String>[
      'tapRejected',
      'selfGestureAccepted',
      'otherGestureAccepted',
      'pointerCanceled',
      'external',
    ]);
    final cancel = ElEventDetails(
      phase: ElEventPhase.tapCancel,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
      cancelReason: ElEventCancelReason.pointerCanceled,
    );
    expect(cancel.cancelReason, ElEventCancelReason.pointerCanceled);
    final externalCancel = ElEventDetails(
      phase: ElEventPhase.tapCancel,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
    );
    expect(externalCancel.cancelReason, ElEventCancelReason.external);
    final physicalPointerCancel = ElEventDetails(
      phase: ElEventPhase.pointerCancel,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
    );
    expect(physicalPointerCancel.cancelReason, ElEventCancelReason.pointerCanceled);
    expect(
      () => ElEventDetails(
        phase: ElEventPhase.tap,
        globalPosition: Offset.zero,
        localPosition: Offset.zero,
        cancelReason: ElEventCancelReason.tapRejected,
      ),
      throwsAssertionError,
    );
  });

  test('SURFACE-3: ElEvent 公开回调和生成复制保持完整', () {
    void handler(ElEventDetails event) {}

    const config = ElEventConfig(dragStartDistance: 3);
    final proxy = ElDragProxy(axis: Axis.horizontal, onDragPreUpdate: handler, onDragOverflow: handler);
    final free = ElEvent(
      config: config,
      dragProxy: proxy,
      onPointerEnter: handler,
      onPointerHover: handler,
      onPointerExit: handler,
      onPointerDown: handler,
      onPointerMove: handler,
      onPointerUp: handler,
      onPointerCancel: handler,
      onPointerPanZoomStart: handler,
      onPointerPanZoomUpdate: handler,
      onPointerPanZoomEnd: handler,
      onPointerSignal: handler,
      onTapDown: handler,
      onTapUp: handler,
      onTap: handler,
      onDoubleTap: handler,
      onDoubleTapDown: handler,
      onTripleTap: handler,
      onTripleTapDown: handler,
      onSecondaryTapDown: handler,
      onSecondaryTapUp: handler,
      onSecondaryTap: handler,
      onTertiaryTapDown: handler,
      onTertiaryTapUp: handler,
      onTertiaryTap: handler,
      onForwardTapDown: handler,
      onForwardTapUp: handler,
      onForwardTap: handler,
      onBackTapDown: handler,
      onBackTapUp: handler,
      onBackTap: handler,
      onLongPress: handler,
      onTapCancel: handler,
      onDragDown: handler,
      onDragStart: handler,
      onDragUpdate: handler,
      onDragEnd: handler,
      onDragCancel: handler,
      onScaleStart: handler,
      onScaleUpdate: handler,
      onScaleEnd: handler,
      onScaleCancel: handler,
      onRotationUpdate: handler,
      onKeyDown: handler,
      onKeyRepeat: handler,
      onKeyUp: handler,
      onFocus: handler,
      onBlur: handler,
    );
    final axial = ElEvent(
      onVerticalDragStart: handler,
      onVerticalDragUpdate: handler,
      onVerticalDragEnd: handler,
      onVerticalDragCancel: handler,
      onHorizontalDragStart: handler,
      onHorizontalDragUpdate: handler,
      onHorizontalDragEnd: handler,
      onHorizontalDragCancel: handler,
    );

    expect(free.config, same(config));
    expect(free.dragProxy, same(proxy));
    expect(proxy.axis, Axis.horizontal);
    expect(proxy.onDragPreUpdate, same(handler));
    expect(proxy.onDragOverflow, same(handler));
    expect(_freeHandlers(free), everyElement(same(handler)));
    expect(_axialHandlers(axial), everyElement(same(handler)));
    expect(free.hasTapLikeCallback, isTrue);
    expect(free.hasKeyboardCallback, isTrue);
    expect(free.hasAnyCallback, isTrue);

    final retained = free.copyWith(onTap: null);
    expect(free.copyWith().onTap, same(handler));
    expect(retained.onTap, isNull, reason: '生成 copyWith 的显式 null 清除回调');

    final clearedFree = free.copyWith(
      config: null,
      dragProxy: null,
      cursor: null,
      onPointerEnter: null,
      onPointerHover: null,
      onPointerExit: null,
      onPointerDown: null,
      onPointerMove: null,
      onPointerUp: null,
      onPointerCancel: null,
      onPointerPanZoomStart: null,
      onPointerPanZoomUpdate: null,
      onPointerPanZoomEnd: null,
      onPointerSignal: null,
      onTapDown: null,
      onTapUp: null,
      onTap: null,
      onDoubleTap: null,
      onDoubleTapDown: null,
      onTripleTap: null,
      onTripleTapDown: null,
      onSecondaryTapDown: null,
      onSecondaryTapUp: null,
      onSecondaryTap: null,
      onTertiaryTapDown: null,
      onTertiaryTapUp: null,
      onTertiaryTap: null,
      onForwardTapDown: null,
      onForwardTapUp: null,
      onForwardTap: null,
      onBackTapDown: null,
      onBackTapUp: null,
      onBackTap: null,
      onLongPress: null,
      onTapCancel: null,
      onDragDown: null,
      onDragStart: null,
      onDragUpdate: null,
      onDragEnd: null,
      onDragCancel: null,
      onVerticalDragStart: null,
      onVerticalDragUpdate: null,
      onVerticalDragEnd: null,
      onVerticalDragCancel: null,
      onHorizontalDragStart: null,
      onHorizontalDragUpdate: null,
      onHorizontalDragEnd: null,
      onHorizontalDragCancel: null,
      onScaleStart: null,
      onScaleUpdate: null,
      onScaleEnd: null,
      onScaleCancel: null,
      onRotationUpdate: null,
      onKeyDown: null,
      onKeyRepeat: null,
      onKeyUp: null,
      onFocus: null,
      onBlur: null,
    );
    final clearedAxial = axial.copyWith(
      onVerticalDragStart: null,
      onVerticalDragUpdate: null,
      onVerticalDragEnd: null,
      onVerticalDragCancel: null,
      onHorizontalDragStart: null,
      onHorizontalDragUpdate: null,
      onHorizontalDragEnd: null,
      onHorizontalDragCancel: null,
    );
    expect(clearedFree.config, isNull);
    expect(clearedFree.dragProxy, isNull);
    expect(_freeHandlers(clearedFree), everyElement(isNull));
    expect(_axialHandlers(clearedAxial), everyElement(isNull));
    expect(clearedFree.hasAnyCallback, isFalse);
  });

  test('SURFACE-4: ElEventConfig 默认识别参数保持冻结', () {
    const config = ElEventConfig();
    expect(config.doubleTapInterval, const Duration(milliseconds: 300));
    expect(config.tripleTapInterval, const Duration(milliseconds: 300));
    expect(config.longPressDelay, const Duration(milliseconds: 500));
    expect(config.tapCancelDistance, 10);
    expect(config.tapCancelByDistance, isFalse);
    expect(config.deferTap, isFalse);
    expect(config.dragStartDistance, isNull);
    expect(config.dragHorizontalAngle, closeTo(math.pi / 4, 0.000001));
    expect(config.dragMinFlingDistance, isNull);
    expect(config.dragMinFlingVelocity, kMinFlingVelocity);
    expect(config.dragMaxFlingVelocity, kMaxFlingVelocity);
  });

  test('SURFACE-5: 业务回调不暴露内部接线方法，通用数据能力保持可用', () {
    final dynamic callback = ElEventDetails(
      phase: ElEventPhase.tap,
      globalPosition: Offset.zero,
      localPosition: Offset.zero,
    );
    expect(() => callback.shareControl(callback), throwsNoSuchMethodError);
    expect(() => callback.markCallbackInvoked(), throwsNoSuchMethodError);
    expect(() => callback.updateEagerGestureHandler(null), throwsNoSuchMethodError);
    expect(() => callback.updatePreserveFocusHandler(null), throwsNoSuchMethodError);
    expect(callback.isActive, isTrue);
    expect(callback.isPrimaryTarget, isTrue);
    expect(callback.dispatchIdentity, same(callback));
    expect(callback.sequenceIdentity, same(callback));
  });
}

/// 解析事件主入口的唯一显式导出块，供命名与导出名单合同共用。
List<String> _eventExportNames() {
  final source = File('lib/ui.dart').readAsStringSync();
  final exports = RegExp(r"export\s+'src/flutter/views/view/event/[^']+'[^;]*;").allMatches(source).toList();
  expect(exports, hasLength(1));
  final names = <String>[];
  for (final export in exports) {
    final declaration = export.group(0)!;
    final visible = RegExp(r'\bshow\s+([^;]+);').firstMatch(declaration);
    expect(visible, isNotNull);
    names.addAll(visible!.group(1)!.split(',').map((name) => name.trim()));
  }
  return names;
}

List<ElEventHandler?> _freeHandlers(ElEvent event) {
  return <ElEventHandler?>[
    event.onPointerEnter,
    event.onPointerHover,
    event.onPointerExit,
    event.onPointerDown,
    event.onPointerMove,
    event.onPointerUp,
    event.onPointerCancel,
    event.onPointerPanZoomStart,
    event.onPointerPanZoomUpdate,
    event.onPointerPanZoomEnd,
    event.onPointerSignal,
    event.onTapDown,
    event.onTapUp,
    event.onTap,
    event.onDoubleTap,
    event.onDoubleTapDown,
    event.onTripleTap,
    event.onTripleTapDown,
    event.onSecondaryTapDown,
    event.onSecondaryTapUp,
    event.onSecondaryTap,
    event.onTertiaryTapDown,
    event.onTertiaryTapUp,
    event.onTertiaryTap,
    event.onForwardTapDown,
    event.onForwardTapUp,
    event.onForwardTap,
    event.onBackTapDown,
    event.onBackTapUp,
    event.onBackTap,
    event.onLongPress,
    event.onTapCancel,
    event.onDragDown,
    event.onDragStart,
    event.onDragUpdate,
    event.onDragEnd,
    event.onDragCancel,
    event.onScaleStart,
    event.onScaleUpdate,
    event.onScaleEnd,
    event.onScaleCancel,
    event.onRotationUpdate,
    event.onKeyDown,
    event.onKeyRepeat,
    event.onKeyUp,
    event.onFocus,
    event.onBlur,
  ];
}

List<ElEventHandler?> _axialHandlers(ElEvent event) {
  return <ElEventHandler?>[
    event.onVerticalDragStart,
    event.onVerticalDragUpdate,
    event.onVerticalDragEnd,
    event.onVerticalDragCancel,
    event.onHorizontalDragStart,
    event.onHorizontalDragUpdate,
    event.onHorizontalDragEnd,
    event.onHorizontalDragCancel,
  ];
}
