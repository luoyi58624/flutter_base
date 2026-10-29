import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter_base/src/ui/cores/scroll/common/viewport/scroll_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show MatrixUtils, RenderAbstractViewport, RenderBox;
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontSize: 10, height: 1, color: Color(0xff000000));
const _timeout = Timeout(Duration(seconds: 30));

Widget _host(Widget child, {double width = 240, double height = 120}) => MaterialApp(
  home: Align(
    alignment: .topLeft,
    child: SizedBox(width: width, height: height, child: child),
  ),
);

String _document(int lines, {int columns = 1}) =>
    List<String>.generate(lines, (line) => String.fromCharCode(97 + line % 26) * columns).join('\n');

Future<void> _pumpFrames(WidgetTester tester, [int count = 24]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<bool> _pumpReveal(WidgetTester tester, Future<bool> future, {int maxFrames = 48}) async {
  bool? result;
  Object? error;
  future.then(
    (value) => result = value,
    onError: (Object value, StackTrace _) {
      error = value;
      return false;
    },
  );
  for (var frame = 0; frame < maxFrames && result == null && error == null; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (error != null) fail('reveal 不得抛错：$error');
  if (result == null) fail('reveal 在 $maxFrames 帧内未结清');
  return result!;
}

Rect? _viewportRectInEditor(WidgetTester tester, GlobalKey<EditableViewTestState> key, EditableController controller) {
  final context = key.currentContext;
  if (context == null) return null;
  final editor = context.findRenderObject();
  if (editor is! RenderBox || !editor.attached || !editor.hasSize) return null;
  final targetLine = controller.document.lineIndexOf(controller.selection.extentOffset);
  final line = tester
      .renderObjectList<RenderEditableLine>(find.byType(EditableLineView))
      .where((render) => render.index == targetLine)
      .firstOrNull;
  if (line == null) return null;
  final viewport = RenderAbstractViewport.maybeOf(line);
  if (viewport == null || viewport is! RenderBox) return null;
  final box = viewport as RenderBox;
  if (!box.attached || !box.hasSize) return null;
  final bounds = viewport is ScrollViewport ? (viewport as ScrollViewport).contentViewportRect : Offset.zero & box.size;
  return MatrixUtils.transformRect(box.getTransformTo(editor), bounds);
}

bool _containsRect(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;

final class _VariableHeightComposer extends EditableComposer {
  const _VariableHeightComposer();

  @override
  InlineSpan compose(EditableLineContext context) => TextSpan(
    text: context.text,
    style: context.baseStyle.copyWith(fontSize: context.line.isEven ? 8 : 48, height: 1),
  );
}

final class _ThrowingIndexScrollController extends ElScrollController {
  @override
  Future<bool> scrollToIndexWithResult(
    int index, {
    double alignment = 0,
    Duration? duration,
    Curve curve = Curves.easeInOut,
  }) => throw StateError('sync scroll failure');
}

final class _LeadingWindowScrollBar extends ElWindowScrollBar {
  const _LeadingWindowScrollBar();

  @override
  ScrollbarOrientation resolveOrientation(BuildContext context, Axis axis) =>
      axis == Axis.vertical ? ScrollbarOrientation.left : ScrollbarOrientation.top;
}

void main() {
  testWidgets('失焦真取消 far index 迭代且陈旧自动意图不复活，显式失焦调用仍允许', (tester) async {
    final controller = EditableController(text: _document(20000))..collapseTo(0);
    final vertical = ElScrollController();
    final focusNode = FocusNode();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          focusNode: focusNode,
          scrollController: vertical,
          style: EditableConfiguration(
            composer: const _VariableHeightComposer(),
            textStyle: _style,
            cacheExtent: 0,
            autofocus: true,
          ),
        ),
      ),
    );
    await tester.pump();

    controller.collapseTo(controller.document.lineStart(18000));
    final canceled = key.currentState!.revealCaret();
    expect(identical(key.currentState!.revealCaret(), canceled), isTrue, reason: '同目标调用必须复用同一个 Future');
    focusNode.unfocus();
    expect(await _pumpReveal(tester, canceled), isFalse);
    final pixelsAfterCancel = vertical.offset;
    await _pumpFrames(tester, 10);
    expect(vertical.offset, closeTo(pixelsAfterCancel, 0.01), reason: '底层 index refinement 与旧自动意图都必须停止');

    final explicitWhileUnfocused = key.currentState!.revealCaret();
    expect(await _pumpReveal(tester, explicitWhileUnfocused), isTrue);
    final viewport = _viewportRectInEditor(tester, key, controller)!;
    expect(_containsRect(viewport, key.currentState!.caretRectInEditor()!), isTrue);
  }, timeout: _timeout);

  testWidgets('scrollToIndex 同步异常结清且不会毒化后续同目标请求', (tester) async {
    final controller = EditableController(text: _document(5000))..collapseTo(0);
    final vertical = _ThrowingIndexScrollController();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          scrollController: vertical,
          style: EditableConfiguration(textStyle: _style, cacheExtent: 0),
        ),
      ),
    );
    await tester.pump();
    controller.collapseTo(controller.document.lineStart(4500));

    expect(await _pumpReveal(tester, key.currentState!.revealCaret()), isFalse);
    expect(await _pumpReveal(tester, key.currentState!.revealCaret()), isFalse);
    expect(key.currentState!.ensureCaretVisible, returnsNormally);
    await tester.pump();
  });

  testWidgets('IME teardown visual 重入不能在最终取消点后留下 reveal', (tester) async {
    final controller = EditableController(text: 'abc');
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          style: EditableConfiguration(autofocus: true, textStyle: _style),
        ),
      ),
    );
    await tester.pump();
    controller.imeReplace(
      0,
      0,
      'n',
      selection: const TextSelection.collapsed(offset: 1),
      composing: const TextRange(start: 0, end: 1),
    );
    await tester.pump();

    final state = key.currentState!;
    Future<bool>? reentrant;
    void listener() {
      if (!controller.hasActiveImeComposition) reentrant ??= state.revealCaret();
    }

    controller.visualChanges.addListener(listener);
    addTearDown(() => controller.visualChanges.removeListener(listener));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(reentrant, isNotNull);
    expect(await reentrant!, isFalse);
  });

  testWidgets('首帧 build 后 layout 前调用会重返 coarse 定位远行', (tester) async {
    final controller = EditableController(text: _document(10000))
      ..collapseTo(0)
      ..collapseTo(18000);
    final vertical = ElScrollController();
    final key = GlobalKey<EditableViewTestState>();
    Future<bool>? reveal;
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 240,
            height: 140,
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  child: EditableView(
                    key: key,
                    controller: controller,
                    scrollController: vertical,
                    style: EditableConfiguration(textStyle: _style, cacheExtent: 0),
                  ),
                ),
                Builder(
                  builder: (_) {
                    reveal ??= key.currentState!.revealCaret();
                    return const SizedBox(height: 1);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(reveal, isNotNull);
    expect(await _pumpReveal(tester, reveal!), isTrue);
    expect(
      tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView)).map((line) => line.index),
      contains(controller.document.lineIndexOf(controller.selection.extentOffset)),
    );
  }, timeout: _timeout);

  testWidgets('transactionChanges 中的新 revision reveal 等待 view-model 同步后完成', (tester) async {
    final controller = EditableController(text: _document(6000))..collapseTo(0);
    final vertical = ElScrollController();
    final key = GlobalKey<EditableViewTestState>();
    Future<bool>? reveal;
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          scrollController: vertical,
          style: EditableConfiguration(textStyle: _style, cacheExtent: 0),
        ),
      ),
    );
    await tester.pump();
    void listener() => reveal ??= key.currentState!.revealCaret();
    controller.transactionChanges.addListener(listener);
    addTearDown(() => controller.transactionChanges.removeListener(listener));

    final oldTarget = controller.document.lineStart(5000);
    controller.replaceRange(
      0,
      0,
      'prefix\n',
      selection: TextSelection.collapsed(offset: oldTarget + 'prefix\n'.length),
    );
    expect(reveal, isNotNull);
    expect(await _pumpReveal(tester, reveal!), isTrue);
    expect(
      tester.renderObjectList<RenderEditableLine>(find.byType(EditableLineView)).map((line) => line.index),
      contains(controller.document.lineIndexOf(controller.selection.extentOffset)),
    );
  }, timeout: _timeout);

  testWidgets('祖先同帧缩小不能用旧 layout 提前完成 true', (tester) async {
    final controller = EditableController(text: _document(30))..collapseTo(30);
    final vertical = ElScrollController();
    final key = GlobalKey<EditableViewTestState>();
    late StateSetter rebuild;
    var height = 180.0;
    var trigger = false;
    Future<bool>? reveal;
    Rect? viewportAtCompletion;
    Rect? caretAtCompletion;
    final editor = EditableView(
      key: key,
      controller: controller,
      scrollController: vertical,
      style: EditableConfiguration(textStyle: _style, cacheExtent: 0),
    );
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Align(
              alignment: .topLeft,
              child: SizedBox(
                width: 200,
                height: 200,
                child: Column(
                  children: [
                    SizedBox(width: 200, height: height, child: editor),
                    Builder(
                      builder: (_) {
                        if (trigger) {
                          trigger = false;
                          final state = key.currentState!;
                          reveal = state.revealCaret();
                          reveal!.then((_) {
                            viewportAtCompletion = state.debugCaretScrollViewportRectInEditor;
                            caretAtCompletion = state.caretRectInEditor();
                          });
                        }
                        return const SizedBox(height: 1);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(key.currentState!.caretRectInEditor()!.top, greaterThan(100));

    rebuild(() {
      height = 80;
      trigger = true;
    });
    await tester.pump();
    expect(reveal, isNotNull);
    expect(await _pumpReveal(tester, reveal!), isTrue);
    expect(viewportAtCompletion, isNotNull);
    expect(viewportAtCompletion!.height, closeTo(80, 0.5));
    expect(_containsRect(viewportAtCompletion!, caretAtCompletion!), isTrue);
  });

  testWidgets('持续 viewport 抖动会在全局预算内明确返回 false', (tester) async {
    final controller = EditableController(text: _document(30))..collapseTo(30);
    final vertical = ElScrollController();
    final key = GlobalKey<EditableViewTestState>();
    late StateSetter rebuild;
    var height = 180.0;
    final editor = EditableView(
      key: key,
      controller: controller,
      scrollController: vertical,
      style: EditableConfiguration(textStyle: _style, cacheExtent: 0),
    );
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Align(
              alignment: .topLeft,
              child: SizedBox(width: 200, height: height, child: editor),
            );
          },
        ),
      ),
    );
    await tester.pump();

    bool? result;
    key.currentState!.revealCaret().then((value) => result = value);
    for (var frame = 0; frame < 96 && result == null; frame++) {
      rebuild(() => height = frame.isEven ? 80 : 180);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(result, isFalse, reason: 'resize/restart 不得靠重置 refinement 形成无限会话');
  });

  testWidgets('Window 双轴 trailing/leading inset 以真实 viewport 判定完成', (tester) async {
    for (final entry in <({ElScrollbar scrollbar, Offset origin})>[
      (scrollbar: const ElWindowScrollBar(), origin: Offset.zero),
      (scrollbar: const _LeadingWindowScrollBar(), origin: const Offset(15, 15)),
    ]) {
      final controller = EditableController(text: _document(300, columns: 120))
        ..collapseTo(0)
        ..collapseTo(_document(300, columns: 120).length);
      final vertical = ElScrollController();
      final horizontal = ScrollController();
      final key = GlobalKey<EditableViewTestState>();

      await tester.pumpWidget(
        _host(
          EditableView(
            key: key,
            controller: controller,
            scrollController: vertical,
            horizontalScrollController: horizontal,
            style: EditableConfiguration(
              scrollbar: entry.scrollbar,
              cacheExtent: 0,
              softWrap: false,
              textStyle: _style,
            ),
          ),
          width: 320,
          height: 180,
        ),
      );
      await tester.pump();

      Rect? viewportAtCompletion;
      Rect? caretAtCompletion;
      final state = key.currentState!;
      final reveal = state.revealCaret();
      reveal.then((_) {
        viewportAtCompletion = state.debugCaretScrollViewportRectInEditor;
        caretAtCompletion = state.caretRectInEditor();
      });
      expect(await _pumpReveal(tester, reveal, maxFrames: 64), isTrue, reason: '${entry.origin}');
      expect(viewportAtCompletion, isNotNull);
      expect(viewportAtCompletion!.topLeft, entry.origin);
      expect(viewportAtCompletion!.size, const Size(305, 165));
      expect(_containsRect(viewportAtCompletion!, caretAtCompletion!), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      vertical.dispose();
      horizontal.dispose();
    }
  }, timeout: _timeout);

  testWidgets('仅垂直 controller 换绑会取消旧 reveal', (tester) async {
    final controller = EditableController(text: _document(5000, columns: 200))..collapseTo(0);
    final verticalA = ElScrollController();
    final verticalB = ElScrollController();
    final horizontal = ScrollController();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(verticalA.dispose);
    addTearDown(verticalB.dispose);
    addTearDown(horizontal.dispose);

    Widget editor(ElScrollController vertical) => _host(
      EditableView(
        key: key,
        controller: controller,
        scrollController: vertical,
        horizontalScrollController: horizontal,
        style: EditableConfiguration(softWrap: false, textStyle: _style, cacheExtent: 0),
      ),
    );

    await tester.pumpWidget(editor(verticalA));
    await tester.pump();
    controller.collapseTo(controller.document.length);
    final old = key.currentState!.revealCaret();
    await tester.pumpWidget(editor(verticalB));
    expect(await _pumpReveal(tester, old), isFalse);
  });

  testWidgets('仅水平 controller 换绑会取消旧 reveal', (tester) async {
    final controller = EditableController(text: _document(5000, columns: 200))..collapseTo(0);
    final vertical = ElScrollController();
    final horizontalA = ScrollController();
    final horizontalB = ScrollController();
    final key = GlobalKey<EditableViewTestState>();
    addTearDown(controller.dispose);
    addTearDown(vertical.dispose);
    addTearDown(horizontalA.dispose);
    addTearDown(horizontalB.dispose);

    Widget editor(ScrollController horizontal) => _host(
      EditableView(
        key: key,
        controller: controller,
        scrollController: vertical,
        horizontalScrollController: horizontal,
        style: EditableConfiguration(softWrap: false, textStyle: _style, cacheExtent: 0),
      ),
    );

    await tester.pumpWidget(editor(horizontalA));
    await tester.pump();
    controller.collapseTo(controller.document.length);
    final old = key.currentState!.revealCaret();
    await tester.pumpWidget(editor(horizontalB));
    expect(await _pumpReveal(tester, old), isFalse);
  });
}
