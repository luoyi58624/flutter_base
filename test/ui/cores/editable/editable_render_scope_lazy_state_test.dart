import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter_base/src/ui/cores/editable/render/editable_render_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const TextStyle _textStyle = TextStyle(fontSize: 14, height: 1);

EditableRenderConfig _config({required bool softWrap, Color caretColor = const Color(0xff000000)}) =>
    EditableRenderConfig(
      textStyle: _textStyle,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      softWrap: softWrap,
      caretColor: caretColor,
      caretWidth: 1.5,
      selectionColor: const Color(0x400000ff),
      composingUnderline: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真实短 softWrap editable 挂载与卸载不激活长行或 nowrap 状态', (tester) async {
    final controller = EditableController(text: 'short');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: .topLeft,
          child: SizedBox(
            width: 240,
            height: 80,
            child: EditableView(
              controller: controller,
              style: const EditableConfiguration(textStyle: _textStyle, softWrap: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final scope = tester.renderObject<RenderEditableLine>(find.byType(EditableLineView)).scope;
    expect(scope.debugLongLineStateCreationCount, 0);
    expect(scope.debugKnownLineWidthsCreationCount, 0);
    expect(scope.debugMinimumCrossAxisExtentCreationCount, 0);

    await tester.pumpWidget(const SizedBox());
    expect(scope.debugLongLineStateCreationCount, 0);
    expect(scope.debugKnownLineWidthsCreationCount, 0);
    expect(scope.debugMinimumCrossAxisExtentCreationCount, 0);
  });

  test('空与短 softWrap 输入的读取、失效和释放均不创建高级缓存', () {
    final controller = EditableController(text: 'short');
    addTearDown(controller.dispose);
    final scope = EditableRenderScope(controller: controller, config: _config(softWrap: true));

    expect(scope.debugLongLineStateCreationCount, 0);
    expect(scope.debugKnownLineWidthsCreationCount, 0);
    expect(scope.debugMinimumCrossAxisExtentCreationCount, 0);
    expect(scope.lineTextOf(0), 'short');
    scope
      ..reportLayoutWidth(200)
      ..setHorizontalViewport(pixels: 10, width: 200)
      ..reportLineWidth(Object(), textWidth: 40, insertTrailingExtent: 1.5, overwriteTrailingExtent: 7)
      ..invalidateLineWidths(<Object>[Object()])
      ..pump(config: _config(softWrap: true, caretColor: const Color(0xff111111)));
    expect(scope.painterFor(0).plainText, 'short');
    expect(scope.debugLongLineStateCreationCount, 0);
    expect(scope.debugKnownLineWidthsCreationCount, 0);
    expect(scope.debugMinimumCrossAxisExtentCreationCount, 0);

    scope.dispose();
    expect(scope.debugLongLineStateCreationCount, 0, reason: 'dispose 不得为了 clear 反向初始化长行 capsule');
    expect(scope.debugKnownLineWidthsCreationCount, 0, reason: 'dispose 不得为了 clear 反向初始化宽度表');
    expect(scope.debugMinimumCrossAxisExtentCreationCount, 0, reason: 'dispose 不得为了释放反向初始化宽度通知器');
    expect(() => scope.minimumCrossAxisExtent, throwsStateError, reason: '已释放 scope 不得复活新的监听资源');
    expect(scope.debugMinimumCrossAxisExtentCreationCount, 0);
  });

  test('连续短行读取共享有界批次，正文修订后才重建', () {
    final controller = EditableController(text: List.generate(200, (index) => 'line-$index').join('\n'));
    addTearDown(controller.dispose);
    final scope = EditableRenderScope(controller: controller, config: _config(softWrap: false));
    addTearDown(scope.dispose);

    TextDocument.debugResetGetTextCounters();
    TextDocument.debugResetTextReadCounters();
    expect(scope.usesWindowedLineLayout(40), isFalse);
    expect(scope.lineTextOf(40), 'line-40');
    expect(scope.lineTextOf(41), 'line-41');
    expect(scope.usesWindowedLineLayout(42), isFalse);
    expect(scope.debugLineTextBatchBuildCount, 1);
    expect(scope.debugLineTextBatchReuseCount, 3);
    expect(scope.debugLineTextBatchCachedLineCount, greaterThan(3));
    expect(TextDocument.debugLineBatchReadCount, 1);
    expect(TextDocument.debugGetTextCallCount, 0, reason: '可见短行不得逐行回退到 getText');
    expect(TextDocument.debugMaxLineBatchCopiedCodeUnits, lessThanOrEqualTo(64 * 1024));
    expect(TextDocument.debugMaxTextReadSpan, lessThan(16));

    final start = controller.document.lineStart(40);
    controller.replaceRange(start, start + 1, 'L');
    scope.pumpFromController();
    TextDocument.debugResetGetTextCounters();
    TextDocument.debugResetTextReadCounters();

    expect(scope.lineTextOf(40), 'Line-40');
    expect(scope.lineTextOf(41), 'line-41');
    expect(scope.debugLineTextBatchBuildCount, 2);
    expect(TextDocument.debugLineBatchReadCount, 1);
    expect(TextDocument.debugGetTextCallCount, 0);
  });

  test('短 nowrap 输入只创建宽度索引，不支付长行 Bidi 与 Tab 缓存', () {
    final controller = EditableController(text: 'short', singleLine: true);
    addTearDown(controller.dispose);
    final scope = EditableRenderScope(controller: controller, config: _config(softWrap: false));
    addTearDown(scope.dispose);
    final identity = Object();

    expect(scope.usesWindowedLineLayout(0), isFalse);
    expect(scope.debugLongLineStateCreationCount, 0);
    expect(scope.debugKnownLineWidthsCreationCount, 0);
    expect(scope.debugMinimumCrossAxisExtentCreationCount, 0);

    scope.reportLineWidth(identity, textWidth: 40, insertTrailingExtent: 1.5, overwriteTrailingExtent: 7);
    expect(scope.retainsLineWidth(identity), isTrue);
    expect(scope.debugKnownLineWidthsCreationCount, 1);
    expect(scope.debugMinimumCrossAxisExtentCreationCount, 1);
    expect(scope.debugLongLineStateCreationCount, 0);
  });

  test('超过 Paragraph 上限的 nowrap 行首次请求窗口才创建长行 capsule', () {
    final controller = EditableController(
      text: 'a' * (EditableRenderScope.longLineParagraphCodeUnitLimit + 1),
      singleLine: true,
    );
    addTearDown(controller.dispose);
    final scope = EditableRenderScope(controller: controller, config: _config(softWrap: false));
    addTearDown(scope.dispose);

    expect(scope.usesWindowedLineLayout(0), isTrue);
    expect(scope.debugLongLineStateCreationCount, 0);
    expect(scope.debugKnownLineWidthsCreationCount, 0);

    final window = scope.longLineWindowFor(0, Object());
    expect(window.lineLength, EditableRenderScope.longLineParagraphCodeUnitLimit + 1);
    expect(scope.debugLongLineStateCreationCount, 1);
    expect(scope.debugLongLineWidthModelCount, 1);
    expect(scope.debugKnownLineWidthsCreationCount, 0);
  });
}
