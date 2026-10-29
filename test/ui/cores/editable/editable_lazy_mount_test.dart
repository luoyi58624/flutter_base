import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ListenerCountingScrollController extends ScrollController {
  int activeListenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    activeListenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    activeListenerCount--;
    super.removeListener(listener);
  }
}

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: SizedBox(width: 320, height: 80, child: child),
);

void main() {
  testWidgets('未聚焦 soft-wrap 首挂不创建编辑能力与横向滚动器', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abc');
    final focusNode = FocusNode(debugLabel: 'editable-lazy-mount');
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          focusNode: focusNode,
          style: const EditableConfiguration(textStyle: TextStyle(fontSize: 14)),
        ),
      ),
    );
    await tester.pump();

    final state = key.currentState!;
    expect(state.debugOpsInitialized, isFalse);
    expect(state.debugKeyHandlerInitialized, isFalse);
    expect(state.debugImeInitialized, isFalse);
    expect(state.debugAutofillClientInitialized, isFalse);
    expect(state.debugSelectionHandleControllerInitialized, isFalse);
    expect(state.debugSelectionToolbarActionsInitialized, isFalse);
    expect(state.debugOwnHorizontalControllerInitialized, isFalse);
    expect(state.debugLineProjectionSelectionRepairScheduled, isFalse);
    expect(state.debugCaretGeometryPublishCount, 0);
    expect(state.debugSelectionGeometryUpdateCount, 0, reason: '未聚焦输入不能为移动选区 chrome 排帧尾几何任务');

    controller.collapseTo(2);
    await tester.pump();
    expect(state.debugOpsInitialized, isFalse, reason: '程序化模型更新不能反向创建编辑操作层');
    expect(state.debugImeInitialized, isFalse, reason: '未聚焦模型更新不能创建平台输入法客户端');

    expect(state.caretGeometry.value, state.caretRectGlobal(), reason: '首次读取几何门面必须同步提供当前已布局值');
    await tester.pump();
    expect(state.debugCaretGeometryPublishCount, 0, reason: '相同初值不得补发重复几何通知');

    controller.collapseTo(3);
    expect(controller.selection.extentOffset, 3);
    expect(state.debugKeyHandlerInitialized, isFalse);
    expect(state.debugOpsInitialized, isFalse);
    expect(state.debugImeInitialized, isFalse, reason: '程序化命令不需要平台输入法客户端');
  });

  testWidgets('只读首挂与热切配置不会为清理反向创建编辑能力', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'readonly');
    addTearDown(controller.dispose);

    Widget editor({required bool readOnly, bool softWrap = true}) => _host(
      EditableView(
        key: key,
        controller: controller,
        style: EditableConfiguration(textStyle: const TextStyle(fontSize: 14), readOnly: readOnly, softWrap: softWrap),
      ),
    );

    await tester.pumpWidget(editor(readOnly: true));
    await tester.pump();
    var state = key.currentState!;
    expect(state.debugOpsInitialized, isFalse);
    expect(state.debugKeyHandlerInitialized, isFalse);
    expect(state.debugImeInitialized, isFalse);
    expect(state.debugAutofillClientInitialized, isFalse);
    expect(state.debugSelectionHandleControllerInitialized, isFalse);
    expect(state.debugSelectionToolbarActionsInitialized, isFalse);
    expect(state.debugOwnHorizontalControllerInitialized, isFalse);
    expect(state.debugLineProjectionSelectionRepairScheduled, isFalse);
    expect(state.debugCaretGeometryPublishCount, 0);
    expect(state.debugSelectionGeometryUpdateCount, 0);

    await tester.pumpWidget(editor(readOnly: true, softWrap: false));
    await tester.pump();
    state = key.currentState!;
    expect(state.debugOwnHorizontalControllerInitialized, isTrue);
    expect(state.debugOpsInitialized, isFalse);
    expect(state.debugKeyHandlerInitialized, isFalse);
    expect(state.debugImeInitialized, isFalse);

    await tester.pumpWidget(editor(readOnly: true));
    await tester.pump();
    expect(state.debugOwnHorizontalControllerInitialized, isFalse, reason: '恢复 soft-wrap 后应释放内部横向滚动器');
    expect(state.debugOpsInitialized, isFalse);
    expect(state.debugKeyHandlerInitialized, isFalse);
    expect(state.debugImeInitialized, isFalse);
  });

  testWidgets('未创建 IME client 的 controller 换绑只结清旧 controller 组合态', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final previous = EditableController()
      ..imeReplace(
        0,
        0,
        'a',
        selection: const TextSelection.collapsed(offset: 1),
        composing: const TextRange(start: 0, end: 1),
      );
    final next = EditableController()
      ..imeReplace(
        0,
        0,
        'b',
        selection: const TextSelection.collapsed(offset: 1),
        composing: const TextRange(start: 0, end: 1),
      );
    addTearDown(previous.dispose);
    addTearDown(next.dispose);

    Widget editor(EditableController controller) => _host(
      EditableView(
        key: key,
        controller: controller,
        style: const EditableConfiguration(textStyle: TextStyle(fontSize: 14)),
      ),
    );

    await tester.pumpWidget(editor(previous));
    await tester.pump();
    expect(key.currentState!.debugImeInitialized, isFalse);

    await tester.pumpWidget(editor(next));
    await tester.pump();

    expect(previous.hasActiveImeComposition, isFalse);
    expect(next.hasActiveImeComposition, isTrue, reason: '旧管线 teardown 不得误提交刚换入 controller 的组合态');
    expect(key.currentState!.debugImeInitialized, isFalse);
  });

  testWidgets('首次真实聚焦才创建 IME client，并能立即接收平台输入', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abc');
    final focusNode = FocusNode(debugLabel: 'editable-lazy-ime');
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          focusNode: focusNode,
          style: const EditableConfiguration(textStyle: TextStyle(fontSize: 14)),
        ),
      ),
    );
    await tester.pump();
    expect(key.currentState!.debugImeInitialized, isFalse);

    focusNode.requestFocus();
    await tester.pump();
    expect(key.currentState!.debugImeInitialized, isTrue);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(text: 'abcd', selection: TextSelection.collapsed(offset: 4)),
    );
    await tester.pump();
    expect(controller.text, 'abcd');
  });

  testWidgets('soft-wrap 不监听不会参与布局的外借横向滚动器', (tester) async {
    final controller = EditableController(text: 'abc');
    final horizontal = _ListenerCountingScrollController();
    addTearDown(controller.dispose);
    addTearDown(horizontal.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          controller: controller,
          horizontalScrollController: horizontal,
          style: const EditableConfiguration(textStyle: TextStyle(fontSize: 14)),
        ),
      ),
    );
    await tester.pump();

    expect(horizontal.activeListenerCount, 0);
  });

  testWidgets('固定行高 nowrap input 不创建可变行高失效通道', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abc', singleLine: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          style: const EditableConfiguration(
            textStyle: TextStyle(fontSize: 14),
            lineHeightMode: EditableLineHeightMode.fixed,
            softWrap: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(key.currentState!.debugLineExtentInvalidationInitialized, isFalse);
  });

  testWidgets('卸载前未读取 caretGeometry 时，释放后不能复活 notifier', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final controller = EditableController(text: 'abc');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        EditableView(
          key: key,
          controller: controller,
          style: const EditableConfiguration(textStyle: TextStyle(fontSize: 14)),
        ),
      ),
    );
    await tester.pump();
    final state = key.currentState!;

    await tester.pumpWidget(const SizedBox());

    expect(() => state.caretGeometry, throwsStateError);
  });

  testWidgets('controller 与 autofill 配置同帧热换会按新配置注册和注销', (tester) async {
    final key = GlobalKey<EditableViewTestState>();
    final first = EditableController();
    final second = EditableController();
    final third = EditableController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    addTearDown(third.dispose);

    Widget editor(EditableController controller, {List<String>? hints, bool readOnly = false}) => AutofillGroup(
      child: _host(
        EditableView(
          key: key,
          controller: controller,
          style: EditableConfiguration(
            textStyle: const TextStyle(fontSize: 14),
            autofillHints: hints,
            readOnly: readOnly,
          ),
        ),
      ),
    );

    await tester.pumpWidget(editor(first));
    await tester.pump();
    expect(key.currentState!.debugAutofillClientInitialized, isFalse);
    expect(key.currentState!.debugAutofillClientRegistered, isFalse);

    await tester.pumpWidget(editor(second, hints: const [AutofillHints.email]));
    await tester.pump();
    expect(key.currentState!.debugAutofillClientInitialized, isTrue);
    expect(key.currentState!.debugAutofillClientRegistered, isTrue);

    await tester.pumpWidget(editor(third, hints: const [AutofillHints.email], readOnly: true));
    await tester.pump();
    expect(key.currentState!.debugAutofillClientRegistered, isFalse);
  });
}
