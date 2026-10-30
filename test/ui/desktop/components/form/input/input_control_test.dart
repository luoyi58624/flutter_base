import 'package:flutter_base/desktop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ElDesktopTheme(
      child: ElView(
        style: const ElStyle(width: 420, height: 260, alignment: .center),
        child: ElView(style: const ElStyle(width: 260), child: child),
      ),
    ),
  );
}

Future<void> _pumpControl(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'ElInputController 挂载 enabled 输入框，focus/blur/clear/selectAll 均走唯一 Editable',
    (tester) async {
      final control = ElInputController();
      final changes = <String>[];
      var value = 'abc';

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              return ElInput(
                value: value,
                onChanged: (next) {
                  changes.add(next);
                  setState(() => value = next);
                },
                control: control,
                placeholder: '请输入',
              );
            },
          ),
        ),
      );
      await _pumpControl(tester);

      expect(control.attached, isTrue);
      expect(control.controller, isNotNull);
      expect(
        control.controller,
        tester.widget<ElEditableView>(find.byType(ElEditableView)).controller,
      );
      expect(control.focusNode, isNotNull);
      expect(control.hasFocus, isFalse);
      expect(find.byType(ElEditableView), findsOneWidget);
      expect(control.controller!.text, 'abc');

      expect(control.focus(), isTrue);
      await _pumpControl(tester);
      expect(control.hasFocus, isTrue);

      expect(control.selectAll(), isTrue);
      await _pumpControl(tester);
      expect(
        control.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      expect(changes, isEmpty, reason: 'selectAll 只改选区，不能污染 value/onChanged');

      expect(control.clear(), isTrue);
      await _pumpControl(tester);
      expect(value, '');
      expect(control.controller!.text, '');
      expect(changes, ['']);
      expect(
        control.controller!.selection,
        const TextSelection.collapsed(offset: 0),
      );

      expect(control.blur(), isTrue);
      await _pumpControl(tester);
      expect(control.hasFocus, isFalse);

      await tester.pumpWidget(const SizedBox());
      await _pumpControl(tester);
      expect(control.attached, isFalse);
      control.dispose();
    },
  );

  testWidgets(
    'disabled 态仍 attach control，但 editable/focus 暴露为 null 且命令返回 false',
    (tester) async {
      final control = ElInputController();

      await tester.pumpWidget(
        _host(ElInput(value: 'disabled', disabled: true, control: control)),
      );
      await _pumpControl(tester);

      expect(control.attached, isTrue);
      expect(control.controller, isNull);
      expect(control.controller, isNull);
      expect(control.focusNode, isNull);
      expect(control.hasFocus, isFalse);
      expect(control.focus(), isFalse);
      expect(control.blur(), isFalse);
      expect(control.clear(), isFalse);
      expect(control.selectAll(), isFalse);
      expect(find.byType(ElEditableView), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _pumpControl(tester);
      expect(control.attached, isFalse);
      control.dispose();
    },
  );

  testWidgets('control 热替换只迁移门面，value 与内部 ElEditableController 身份保持并继续同步', (
    tester,
  ) async {
    final first = ElInputController();
    final second = ElInputController();
    final model = Obs<String>('abcdef');

    await tester.pumpWidget(
      _host(ElInput(modelValue: model, control: first, maxLength: 10)),
    );
    await _pumpControl(tester);
    final oldEditable = first.controller;
    expect(first.attached, isTrue);
    expect(oldEditable, isNotNull);
    expect(oldEditable!.text, 'abcdef');

    model.value = 'xyz';
    await _pumpControl(tester);
    expect(first.controller, same(oldEditable));
    expect(first.controller!.text, 'xyz');

    await tester.pumpWidget(
      _host(ElInput(modelValue: model, control: second, maxLength: 3)),
    );
    await _pumpControl(tester);
    expect(first.attached, isFalse);
    expect(second.attached, isTrue);
    expect(second.controller, same(oldEditable));
    expect(second.controller!.text, 'xyz');
    expect(
      second.controller,
      tester.widget<ElEditableView>(find.byType(ElEditableView)).controller,
    );

    await tester.pumpWidget(const SizedBox());
    await _pumpControl(tester);
    expect(second.attached, isFalse);
    first.dispose();
    second.dispose();
  });

  testWidgets(
    '同一 control 热换策略/focus/disabled 后 controller 与 viewState 保持，listener 无树锁异常',
    (tester) async {
      final control = ElInputController();
      final firstFocus = FocusNode(debugLabel: 'first-input-control-focus');
      final secondFocus = FocusNode(debugLabel: 'second-input-control-focus');
      StateSetter? rebuild;
      var maxLength = 10;
      var useSecondFocus = false;
      var disabled = false;
      var notifications = 0;

      void handleControlChanged() {
        final setState = rebuild;
        if (setState != null) setState(() => notifications++);
      }

      control.addListener(handleControlChanged);

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ElInput(
                value: 'abcdef',
                maxLength: maxLength,
                focusNode: useSecondFocus ? secondFocus : firstFocus,
                disabled: disabled,
                control: control,
              );
            },
          ),
        ),
      );
      await _pumpControl(tester);
      expect(tester.takeException(), isNull);
      expect(control.attached, isTrue);
      expect(
        control.controller,
        tester.widget<ElEditableView>(find.byType(ElEditableView)).controller,
      );
      expect(control.controller!.text, 'abcdef');
      expect(control.focusNode, same(firstFocus));
      expect(
        notifications,
        greaterThanOrEqualTo(1),
        reason: '首挂通知必须延到帧尾，listener setState 不能树锁报错',
      );

      final firstViewState = control.controller;
      final firstController = control.controller;
      rebuild!(() => maxLength = 3);
      await _pumpControl(tester);
      expect(tester.takeException(), isNull);
      expect(control.controller, same(firstController));
      expect(
        control.controller!.text,
        'abcdef',
        reason: 'maxLength 热降只约束后续输入，不得截断既有值',
      );
      expect(control.controller!.maxLength, 3);
      expect(
        control.controller,
        same(firstViewState),
        reason: '策略热更新不得替换 EditableViewTestState',
      );

      rebuild!(() => useSecondFocus = true);
      await _pumpControl(tester);
      expect(tester.takeException(), isNull);
      expect(control.focusNode, same(secondFocus));
      expect(
        control.controller,
        same(firstViewState),
        reason: '同一个 EditableViewTestState 热换 focusNode 后仍应回挂到 control',
      );

      rebuild!(() => disabled = true);
      await _pumpControl(tester);
      expect(tester.takeException(), isNull);
      expect(control.attached, isTrue);
      expect(control.controller, isNull);
      expect(control.focusNode, isNull);
      expect(control.controller, isNull);
      expect(find.byType(ElEditableView), findsNothing);

      rebuild!(() => disabled = false);
      await _pumpControl(tester);
      expect(tester.takeException(), isNull);
      expect(control.attached, isTrue);
      expect(control.controller, same(firstController));
      expect(control.focusNode, same(secondFocus));
      expect(
        control.controller,
        tester.widget<ElEditableView>(find.byType(ElEditableView)).controller,
      );

      control.removeListener(handleControlChanged);
      rebuild = null;
      await tester.pumpWidget(const SizedBox());
      await _pumpControl(tester);
      expect(control.attached, isFalse);
      control.dispose();
      firstFocus.dispose();
      secondFocus.dispose();
    },
  );

  testWidgets('ElInputController 仍 attached 时 dispose 抛 StateError，卸载后才允许释放', (
    tester,
  ) async {
    final control = ElInputController();

    await tester.pumpWidget(_host(ElInput(value: 'abc', control: control)));
    await _pumpControl(tester);
    expect(control.attached, isTrue);

    expect(
      control.dispose,
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('仍挂载')),
      ),
    );
    expect(control.attached, isTrue);

    await tester.pumpWidget(const SizedBox());
    await _pumpControl(tester);
    expect(control.attached, isFalse);
    control.dispose();
  });

  testWidgets('同一个 ElInputController 双挂直接抛 StateError', (tester) async {
    final control = ElInputController();
    final previousErrorBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (_) => const SizedBox.shrink();

    await tester.pumpWidget(
      _host(
        Column(
          children: [
            ElInput(value: 'a', control: control),
            ElInput(value: 'b', control: control),
          ],
        ),
      ),
    );

    final exception = tester.takeException();
    ErrorWidget.builder = previousErrorBuilder;
    expect(exception, isA<StateError>());
    expect(exception.toString(), contains('不能同时挂载到多个 ElInput'));

    await tester.pumpWidget(const SizedBox());
    control.dispose();
  });
}
