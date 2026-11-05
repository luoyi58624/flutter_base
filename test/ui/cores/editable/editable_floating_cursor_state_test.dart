import 'dart:ui' show Offset, Rect, Size, TextPosition;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_base/src/flutter/views/editable/ime/editable_floating_cursor_state.dart';

const _bounds = Rect.fromLTRB(0, 0, 100, 100);
const _caret = Rect.fromLTWH(48, 46, 4, 8);

TextPosition _hit(Offset point) => TextPosition(offset: point.dx.round());

Rect _caretFor(TextPosition position) =>
    Rect.fromCenter(center: Offset(position.offset.toDouble(), 40), width: 4, height: 8);

void main() {
  group('EditableFloatingCursorState 拖动几何', () {
    test('Start 缓存原点，Update 使用相对 delta 并记录自由 rect 与吸附位置', () {
      final state = EditableFloatingCursorState();
      final controller = Object();

      expect(
        state.start(
          pointOrigin: const Offset(100, 200),
          caretRect: _caret,
          caretPosition: const TextPosition(offset: 5),
          preferredLineHeight: 8,
          anchorBounds: _bounds,
          controllerToken: controller,
          documentRevision: 7,
        ),
        isTrue,
      );
      expect(state.startCaretCenter, const Offset(50, 50));
      expect(state.pointOrigin, const Offset(100, 200));
      expect(state.cursorAnchor, const Offset(50, 46));
      expect(state.frame!.cursorAnchor, const Offset(50, 46));
      expect(state.frame!.freeRect, const Rect.fromLTRB(49.5, 45, 54.5, 55));
      expect(state.frame!.freeRect.size, const Size(5, 10), reason: '自由 caret 必须按 Flutter 官方 margin 扩大');
      expect(state.frame!.placeholderRect, _caret, reason: '占位 caret 保持普通尺寸');

      expect(
        state.update(
          point: const Offset(120, 230),
          anchorBounds: _bounds,
          hitTest: _hit,
          caretRectForPosition: _caretFor,
          controllerToken: controller,
          documentRevision: 7,
        ),
        isTrue,
      );
      expect(state.frame!.cursorAnchor, const Offset(70, 76));
      expect(state.frame!.freeRect.center, const Offset(72, 80));
      expect(state.frame!.freeRect.size, const Size(5, 10), reason: 'Update 不得丢失自由 caret 扩大量');
      expect(state.frame!.snappedPosition, const TextPosition(offset: 70));
      expect(state.frame!.placeholderRect, _caretFor(const TextPosition(offset: 70)));
      expect(state.frame!.resetProgress, isNull);
    });

    test('平台 startLocation 作为 caret 中心生成 prototype 锚点，不误当自由矩形中心', () {
      final state = EditableFloatingCursorState();
      final controller = Object();

      state.start(
        pointOrigin: const Offset(100, 200),
        caretRect: _caret,
        caretPosition: const TextPosition(offset: 5),
        preferredLineHeight: 8,
        anchorBounds: _bounds,
        controllerToken: controller,
        documentRevision: 8,
        startCaretCenter: const Offset(20, 30),
        resetRelativeOrigin: false,
      );

      expect(state.startCaretCenter, const Offset(20, 30));
      expect(state.frame!.cursorAnchor, const Offset(20, 26));
      expect(state.frame!.freeRect, const Rect.fromLTRB(19.5, 25, 24.5, 35));
    });

    test('左边越界后回拖先重置相对原点，再从边界平滑进入', () {
      final state = _startedState();
      final controller = _controllerOf(state);

      _update(state, controller, const Offset(-80, 0));
      expect(state.frame!.cursorAnchor.dx, 0);
      _update(state, controller, const Offset(-70, 0));
      expect(state.frame!.cursorAnchor.dx, 0, reason: '反向第一步只能吃掉左侧越界距离');
      _update(state, controller, const Offset(-60, 0));
      expect(state.frame!.cursorAnchor.dx, 10);
    });

    test('右边越界后回拖先重置相对原点，再从边界平滑进入', () {
      final state = _startedState();
      final controller = _controllerOf(state);

      _update(state, controller, const Offset(80, 0));
      expect(state.frame!.cursorAnchor.dx, 100);
      _update(state, controller, const Offset(70, 0));
      expect(state.frame!.cursorAnchor.dx, 100, reason: '反向第一步只能吃掉右侧越界距离');
      _update(state, controller, const Offset(60, 0));
      expect(state.frame!.cursorAnchor.dx, 90);
    });

    test('上边越界后回拖先重置相对原点，再从边界平滑进入', () {
      final state = _startedState();
      final controller = _controllerOf(state);

      _update(state, controller, const Offset(0, -80));
      expect(state.frame!.cursorAnchor.dy, 0);
      _update(state, controller, const Offset(0, -70));
      expect(state.frame!.cursorAnchor.dy, 0, reason: '反向第一步只能吃掉上侧越界距离');
      _update(state, controller, const Offset(0, -60));
      expect(state.frame!.cursorAnchor.dy, 10);
    });

    test('下边越界后回拖先重置相对原点，再从边界平滑进入', () {
      final state = _startedState();
      final controller = _controllerOf(state);

      _update(state, controller, const Offset(0, 80));
      expect(state.frame!.cursorAnchor.dy, 100);
      _update(state, controller, const Offset(0, 70));
      expect(state.frame!.cursorAnchor.dy, 100, reason: '反向第一步只能吃掉下侧越界距离');
      _update(state, controller, const Offset(0, 60));
      expect(state.frame!.cursorAnchor.dy, 90);
    });

    test('resetRelativeOrigin false 只直接 clamp，回到框内的第一步不被吞', () {
      final state = EditableFloatingCursorState();
      final controller = Object();
      state.start(
        pointOrigin: Offset.zero,
        caretRect: _caret,
        caretPosition: const TextPosition(offset: 50),
        preferredLineHeight: 8,
        anchorBounds: _bounds,
        controllerToken: controller,
        documentRevision: 0,
        resetRelativeOrigin: false,
      );

      _update(state, controller, const Offset(60, 0));
      expect(state.frame!.cursorAnchor.dx, 100, reason: '越界点仍应直接钳在右边界');
      _update(state, controller, const Offset(49, 0));
      expect(state.frame!.cursorAnchor.dx, 99, reason: '禁用相对原点后，回到框内的第一步必须立即生效');
    });

    test('reproject 只按当前自由锚点重新命中，不污染下一笔平台 delta', () {
      final state = _startedState();
      final controller = _controllerOf(state);
      _update(state, controller, const Offset(20, 0));
      expect(state.frame!.cursorAnchor, const Offset(70, 46));
      expect(state.frame!.snappedPosition, const TextPosition(offset: 70));

      expect(
        state.reproject(
          anchorBounds: _bounds,
          hitTest: (point) => TextPosition(offset: point.dx.round() + 100),
          caretRectForPosition: _caretFor,
          controllerToken: controller,
          documentRevision: 0,
        ),
        isTrue,
      );
      expect(state.frame!.cursorAnchor, const Offset(70, 46));
      expect(state.frame!.snappedPosition, const TextPosition(offset: 170));

      _update(state, controller, const Offset(21, 0));
      expect(state.frame!.cursorAnchor, const Offset(71, 46));
      expect(state.frame!.snappedPosition, const TextPosition(offset: 71));
    });
  });

  group('EditableFloatingCursorState 生命周期', () {
    test('Update-before-Start、重复 End 与重复取消均为幂等 no-op', () {
      final state = EditableFloatingCursorState();
      final controller = Object();
      var hitCount = 0;

      expect(
        state.update(
          point: Offset.zero,
          anchorBounds: _bounds,
          hitTest: (point) {
            hitCount++;
            return const TextPosition(offset: 0);
          },
          caretRectForPosition: _caretFor,
          controllerToken: controller,
          documentRevision: 0,
        ),
        isFalse,
      );
      expect(hitCount, 0);
      expect(state.end(controllerToken: controller, documentRevision: 0), isFalse);

      state.start(
        pointOrigin: Offset.zero,
        caretRect: _caret,
        caretPosition: const TextPosition(offset: 5),
        preferredLineHeight: 8,
        anchorBounds: _bounds,
        controllerToken: controller,
        documentRevision: 0,
      );
      expect(
        state.settle(
          elapsed: Duration.zero,
          selectionCollapsed: true,
          caretRectForPosition: _caretFor,
          controllerToken: controller,
          documentRevision: 0,
        ),
        isNull,
        reason: 'Start 后尚未 End 的乱序动画帧必须被忽略',
      );
      expect(state.isDragging, isTrue);
      expect(state.end(controllerToken: controller, documentRevision: 0), isTrue);
      expect(state.end(controllerToken: controller, documentRevision: 0), isFalse);
      expect(
        state.update(
          point: const Offset(10, 0),
          anchorBounds: _bounds,
          hitTest: _hit,
          caretRectForPosition: _caretFor,
          controllerToken: controller,
          documentRevision: 0,
        ),
        isFalse,
        reason: 'End 后迟到的 Update 不得把状态拉回拖动阶段',
      );
      expect(state.cancel(), isTrue);
      expect(state.cancel(), isFalse);
      expect(
        state.settle(
          elapsed: EditableFloatingCursorState.resetDuration,
          selectionCollapsed: true,
          caretRectForPosition: _caretFor,
          controllerToken: controller,
          documentRevision: 0,
        ),
        isNull,
      );
    });

    test('回落在 0/124/125ms 使用 decelerate 插值且只产出一次完成帧', () {
      final state = EditableFloatingCursorState();
      final controller = Object();
      state.start(
        pointOrigin: Offset.zero,
        caretRect: const Rect.fromLTWH(8, 6, 4, 8),
        caretPosition: const TextPosition(offset: 1),
        preferredLineHeight: 8,
        anchorBounds: _bounds,
        controllerToken: controller,
        documentRevision: 3,
      );
      state.update(
        point: const Offset(80, 0),
        anchorBounds: _bounds,
        hitTest: (_) => const TextPosition(offset: 5),
        caretRectForPosition: (_) => const Rect.fromLTWH(48, 6, 4, 8),
        controllerToken: controller,
        documentRevision: 3,
      );
      expect(state.frame!.cursorAnchor, const Offset(90, 6));
      expect(state.frame!.freeRect.center, const Offset(92, 10));
      expect(state.end(controllerToken: controller, documentRevision: 3), isTrue);

      final atZero = state.settle(
        elapsed: Duration.zero,
        selectionCollapsed: true,
        caretRectForPosition: (_) => const Rect.fromLTWH(48, 6, 4, 8),
        controllerToken: controller,
        documentRevision: 3,
      )!;
      expect(atZero.cursorAnchor, const Offset(90, 6));
      expect(atZero.freeRect.center, const Offset(92, 10));
      expect(atZero.freeRect.size, const Size(5, 10));
      expect(atZero.resetProgress, 0);
      expect(atZero.isComplete, isFalse);

      final at124 = state.settle(
        elapsed: const Duration(milliseconds: 124),
        selectionCollapsed: true,
        caretRectForPosition: (_) => const Rect.fromLTWH(48, 6, 4, 8),
        controllerToken: controller,
        documentRevision: 3,
      )!;
      final expectedProgress = Curves.decelerate.transform(124 / 125);
      expect(at124.resetProgress, closeTo(expectedProgress, 1e-12));
      expect(at124.cursorAnchor.dx, closeTo(90 + (48 - 90) * expectedProgress, 1e-9));
      expect(at124.freeRect.center.dx, closeTo(92 + (50 - 92) * expectedProgress, 1e-9));
      expect(at124.freeRect.width, closeTo(5 + (4 - 5) * expectedProgress, 1e-9));
      expect(at124.freeRect.height, closeTo(10 + (8 - 10) * expectedProgress, 1e-9));
      expect(at124.freeRect.center.dx, isNot(50), reason: '124ms 尚不能提前完成');
      expect(at124.isComplete, isFalse);

      final at125 = state.settle(
        elapsed: const Duration(milliseconds: 125),
        selectionCollapsed: true,
        caretRectForPosition: (_) => const Rect.fromLTWH(48, 6, 4, 8),
        controllerToken: controller,
        documentRevision: 3,
      )!;
      expect(at125.freeRect, at125.placeholderRect);
      expect(at125.cursorAnchor, at125.placeholderRect.topLeft);
      expect(at125.resetProgress, 1);
      expect(at125.isComplete, isTrue);
      expect(at125.shouldCollapseSelection, isTrue);
      expect(state.isActive, isFalse);
      expect(
        state.settle(
          elapsed: const Duration(milliseconds: 126),
          selectionCollapsed: true,
          caretRectForPosition: _caretFor,
          controllerToken: controller,
          documentRevision: 3,
        ),
        isNull,
        reason: '完成帧只能消费一次',
      );
    });

    test('回落每帧重算目标 caret，滚动或重排不会落到 End 时旧坐标', () {
      final state = EditableFloatingCursorState();
      final controller = Object();
      var target = const Rect.fromLTWH(48, 6, 4, 8);
      state.start(
        pointOrigin: Offset.zero,
        caretRect: const Rect.fromLTWH(8, 6, 4, 8),
        caretPosition: const TextPosition(offset: 1),
        preferredLineHeight: 8,
        anchorBounds: _bounds,
        controllerToken: controller,
        documentRevision: 4,
      );
      state.update(
        point: const Offset(80, 0),
        anchorBounds: _bounds,
        hitTest: (_) => const TextPosition(offset: 5),
        caretRectForPosition: (_) => target,
        controllerToken: controller,
        documentRevision: 4,
      );
      state.end(controllerToken: controller, documentRevision: 4);

      final beforeScroll = state.settle(
        elapsed: const Duration(milliseconds: 60),
        selectionCollapsed: true,
        caretRectForPosition: (_) => target,
        controllerToken: controller,
        documentRevision: 4,
      )!;
      expect(beforeScroll.placeholderRect, const Rect.fromLTWH(48, 6, 4, 8));

      target = const Rect.fromLTWH(18, 26, 4, 8);
      final afterScroll = state.settle(
        elapsed: const Duration(milliseconds: 125),
        selectionCollapsed: true,
        caretRectForPosition: (_) => target,
        controllerToken: controller,
        documentRevision: 4,
      )!;
      expect(afterScroll.freeRect, target);
      expect(afterScroll.placeholderRect, target);
      expect(afterScroll.cursorAnchor, target.topLeft);
    });

    test('caret 高度不等于首选行高时，回落锚点仍使用 centerLeft 减半行高', () {
      final state = EditableFloatingCursorState();
      final controller = Object();
      const target = Rect.fromLTWH(48, 10, 4, 8);
      state.start(
        pointOrigin: Offset.zero,
        caretRect: const Rect.fromLTWH(8, 10, 4, 8),
        caretPosition: const TextPosition(offset: 1),
        preferredLineHeight: 12,
        anchorBounds: _bounds,
        controllerToken: controller,
        documentRevision: 5,
      );
      state.update(
        point: const Offset(40, 0),
        anchorBounds: _bounds,
        hitTest: (_) => const TextPosition(offset: 5),
        caretRectForPosition: (_) => target,
        controllerToken: controller,
        documentRevision: 5,
      );
      state.end(controllerToken: controller, documentRevision: 5);

      final complete = state.settle(
        elapsed: EditableFloatingCursorState.resetDuration,
        selectionCollapsed: true,
        caretRectForPosition: (_) => target,
        controllerToken: controller,
        documentRevision: 5,
      )!;

      expect(complete.freeRect, target);
      expect(complete.cursorAnchor, const Offset(48, 8));
      expect(complete.cursorAnchor, isNot(target.topLeft));
    });

    test('双指已形成非折叠选区时完成帧不得要求 collapse', () {
      final state = EditableFloatingCursorState();
      final controller = Object();
      state.start(
        pointOrigin: Offset.zero,
        caretRect: _caret,
        caretPosition: const TextPosition(offset: 5),
        preferredLineHeight: 8,
        anchorBounds: _bounds,
        controllerToken: controller,
        documentRevision: 9,
      );
      state.end(controllerToken: controller, documentRevision: 9);

      final complete = state.settle(
        elapsed: EditableFloatingCursorState.resetDuration,
        selectionCollapsed: false,
        caretRectForPosition: _caretFor,
        controllerToken: controller,
        documentRevision: 9,
      )!;
      expect(complete.isComplete, isTrue);
      expect(complete.shouldCollapseSelection, isFalse);
      expect(complete.snappedPosition, const TextPosition(offset: 5));
    });

    test('controller identity 或 revision 漂移会取消且不再调用几何回调', () {
      final state = EditableFloatingCursorState();
      final firstController = _EqualControllerToken();
      final secondController = _EqualControllerToken();
      expect(firstController, equals(secondController), reason: '测试 token 值相等但 identity 不同');
      var hitCount = 0;

      void start() => state.start(
        pointOrigin: Offset.zero,
        caretRect: _caret,
        caretPosition: const TextPosition(offset: 5),
        preferredLineHeight: 8,
        anchorBounds: _bounds,
        controllerToken: firstController,
        documentRevision: 11,
      );

      start();
      expect(
        state.update(
          point: const Offset(10, 0),
          anchorBounds: _bounds,
          hitTest: (point) {
            hitCount++;
            return _hit(point);
          },
          caretRectForPosition: _caretFor,
          controllerToken: secondController,
          documentRevision: 11,
        ),
        isFalse,
      );
      expect(hitCount, 0);
      expect(state.isActive, isFalse);

      start();
      expect(state.end(controllerToken: firstController, documentRevision: 12), isFalse);
      expect(state.isActive, isFalse);

      start();
      expect(
        state.cancelIfInvalid(controllerToken: firstController, documentRevision: 11),
        isFalse,
        reason: '同一 controller/revision 必须保留会话',
      );
      expect(state.isActive, isTrue);
      expect(state.cancelIfInvalid(controllerToken: firstController, documentRevision: 12), isTrue);
      expect(state.isActive, isFalse);
    });
  });

  test('浮动与占位中心距离严格小于 15px 才隐藏占位 caret', () {
    const placeholder = Rect.fromLTWH(0, 0, 2, 10);
    const under = Rect.fromLTWH(14.999, 0, 2, 10);
    const exact = Rect.fromLTWH(15, 0, 2, 10);
    const over = Rect.fromLTWH(15.001, 0, 2, 10);

    expect(
      EditableFloatingCursorState.shouldHidePlaceholder(floatingRect: under, placeholderRect: placeholder),
      isTrue,
    );
    expect(
      EditableFloatingCursorState.shouldHidePlaceholder(floatingRect: exact, placeholderRect: placeholder),
      isFalse,
    );
    expect(
      EditableFloatingCursorState.shouldHidePlaceholder(floatingRect: over, placeholderRect: placeholder),
      isFalse,
    );
  });
}

final Expando<Object> _controllerTokens = Expando<Object>();

EditableFloatingCursorState _startedState() {
  final state = EditableFloatingCursorState();
  final controller = Object();
  _controllerTokens[state] = controller;
  state.start(
    pointOrigin: Offset.zero,
    caretRect: _caret,
    caretPosition: const TextPosition(offset: 50),
    preferredLineHeight: 8,
    anchorBounds: _bounds,
    controllerToken: controller,
    documentRevision: 0,
  );
  return state;
}

Object _controllerOf(EditableFloatingCursorState state) => _controllerTokens[state]!;

final class _EqualControllerToken {
  @override
  bool operator ==(Object other) => other is _EqualControllerToken;

  @override
  int get hashCode => 0;
}

void _update(EditableFloatingCursorState state, Object controller, Offset point) {
  expect(
    state.update(
      point: point,
      anchorBounds: _bounds,
      hitTest: _hit,
      caretRectForPosition: _caretFor,
      controllerToken: controller,
      documentRevision: 0,
    ),
    isTrue,
  );
}
