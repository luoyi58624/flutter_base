import 'package:flutter_base/src/ui/desktop/components/icon/index.dart' show ElIcons;
import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_base/desktop.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {bool compact = false}) => MediaQuery(
  data: const MediaQueryData(size: Size(800, 600)),
  child: Directionality(
    textDirection: .ltr,
    child: ElComponentProvider(
      components: el.desktopComponents,
      child: Overlay.wrap(
        clipBehavior: Clip.none,
        alwaysSizeToContent: true,
        child: ElView(
          style: ElStyle(vars: {ElementPlusThemeData.$compact: compact}),
          child: ElView(
            style: const ElStyle(width: 620, height: 420, alignment: .center),
            child: ElView(style: const ElStyle(width: 420), child: child),
          ),
        ),
      ),
    ),
  ),
);

Finder _tag(int index) => find.byKey(ValueKey<(String, int)>(('el-input-tag', index)));

Future<void> _focus(WidgetTester tester, FocusNode node) async {
  node.requestFocus();
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String text) async {
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump();
}

Future<void> _mouseTapAt(WidgetTester tester, Offset position) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.down(position);
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('标签、草稿和前缀同步紧凑模式，tagStyle 与输入样式可显式覆盖', (tester) async {
    final shell = find.byKey(ValueKey<String>('el-input-tag-shell'));
    final prefixIcon = find.descendant(
      of: find.byKey(ValueKey<String>('el-input-tag-prefix-slot')),
      matching: find.byWidgetPredicate((widget) => widget is ElView && widget.child is IconData),
    );
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        _host(
          ElInputTag(value: ['Dart'], prefix: ElIcons.plus),
          compact: compact,
        ),
      );
      expect(tester.takeException(), isNull, reason: '密度切换首帧不应产生布局异常');
      await tester.pumpAndSettle();
      expect(tester.getSize(shell).height, compact ? 32 : 36);
      expect(tester.getSize(_tag(0)).height, compact ? 20 : 24);
      expect(tester.getSize(prefixIcon).width, compact ? 13 : 14);
      expect(editableTextStyleOf(tester.element(find.byType(ElEditableView)))?.fontSize, compact ? 13 : 14);
    }

    await tester.pumpWidget(
      _host(
        ElInputTag(
          value: ['Dart'],
          prefix: ElIcons.plus,
          style: ElStyle(height: 52, fontSize: 18, iconSize: 17),
          tagStyle: ElStyle(height: 34),
        ),
        compact: true,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, 52);
    expect(tester.getSize(_tag(0)).height, 34);
    expect(tester.getSize(prefixIcon).width, 17);
    expect(editableTextStyleOf(tester.element(find.byType(ElEditableView)))?.fontSize, 18);

    for (final compact in [false, true]) {
      await tester.pumpWidget(_host(ElInputTag(value: ['Dart'], disabled: true), compact: compact));
      expect(tester.takeException(), isNull, reason: '密度切换首帧不应产生布局异常');
      await tester.pumpAndSettle();
      expect(tester.getSize(shell).height, compact ? 32 : 36);
    }

    await tester.pumpWidget(
      _host(ElInputTag(value: ['Dart', 'Flutter', 'Widget'], style: ElStyle(width: 160)), compact: true),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(shell).height, greaterThan(32), reason: '多行标签仍应自然增高');
  });

  testWidgets('唯一输入后端：可编辑/只读只有一个 ElEditableView，禁用态完全摘除', (tester) async {
    await tester.pumpWidget(_host(ElInputTag(value: const ['Dart'])));

    expect(find.byType(ElEditableView), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);

    await tester.pumpWidget(_host(ElInputTag(value: const ['Dart'], readOnly: true)));
    await tester.pump();
    expect(find.byType(ElEditableView), findsOneWidget);
    expect(tester.widget<ElEditableView>(find.byType(ElEditableView)).style.readOnly, isTrue);
    expect(find.byType(ElButtonView), findsNothing, reason: '只读态不得保留标签关闭或清空动作');

    await tester.pumpWidget(_host(ElInputTag(value: const ['Dart'], disabled: true)));
    await tester.pump();
    expect(find.byType(ElEditableView), findsNothing);
    expect(find.byType(EditableText), findsNothing);
    expect(find.byType(ElButtonView), findsNothing);
  });

  testWidgets('自定义标签外壳的左右 1 DIP 边框与 padding 都能首击聚焦 editable', (tester) async {
    final focusNode = FocusNode(debugLabel: 'el-input-tag-shell-focus');
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(_host(ElInputTag(value: const ['Dart'], focusNode: focusNode)));
    await tester.pump();

    final shellFinder = find.byKey(const ValueKey<String>('el-input-tag-shell'));
    expect(tester.widget<ElView>(shellFinder).event?.onTap, isNotNull);
    final shellRender = tester.renderObject<RenderBox>(shellFinder);
    final shell = tester.getRect(shellFinder);
    expect(focusNode.context, isNotNull, reason: '外借 focusNode 必须已经挂到内部 editable');
    expect(focusNode.canRequestFocus, isTrue);
    final leftBorder = shell.centerLeft + const Offset(0.25, 0);
    final leftHitPath = tester.hitTestOnBinding(leftBorder).path;
    final shellHit = leftHitPath.any((entry) => identical(entry.target, shellRender));
    final leftHits = leftHitPath.map((entry) => entry.target.runtimeType).toList();
    expect(shellHit, isTrue, reason: 'shell 自身必须覆盖边框 hit test；hit path=$leftHits');
    await _mouseTapAt(tester, leftBorder);
    expect(focusNode.hasFocus, isTrue, reason: '左边框覆盖内不得成为不可点击死区；hit path=$leftHits');

    focusNode.unfocus();
    await tester.pump();
    await _mouseTapAt(tester, shell.centerRight - const Offset(0.25, 0));
    expect(focusNode.hasFocus, isTrue, reason: '右边框覆盖内不得成为不可点击死区');

    focusNode.unfocus();
    await tester.pump();
    await _mouseTapAt(tester, shell.topCenter + const Offset(0, 2));
    expect(focusNode.hasFocus, isTrue, reason: '标签换行区上方 padding 也必须把焦点交给输入内核');
  });

  testWidgets('受控 value：Enter 添加一次，父级回写与外部热更新不制造重复事件', (tester) async {
    final focusNode = FocusNode();
    final changes = <List<String>>[];
    final added = <String>[];
    var value = <String>['seed'];
    late void Function(List<String> next) updateOutside;
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          updateOutside = (next) => setState(() => value = next);
          return _host(
            ElInputTag(
              value: value,
              focusNode: focusNode,
              onChanged: (next) {
                changes.add(List<String>.of(next));
                setState(() => value = next);
              },
              onAdd: added.add,
            ),
          );
        },
      ),
    );
    await _focus(tester, focusNode);
    await _type(tester, 'flutter');
    await _key(tester, LogicalKeyboardKey.enter);

    expect(value, ['seed', 'flutter']);
    expect(changes, [
      ['seed', 'flutter'],
    ]);
    expect(added, ['flutter']);
    expect(tester.widget<ElEditableView>(find.byType(ElEditableView)).controller!.text, isEmpty);

    updateOutside(<String>['external']);
    await tester.pump();
    await tester.pump();
    expect(_tag(0), findsOneWidget);
    expect(tester.widget<ElTag>(_tag(0)).child, 'external');
    expect(changes, hasLength(1), reason: '父级 value 热更新不得回调成用户变更');
  });

  testWidgets('modelValue：添加、移除、清空与外部回灌各自只通知一次', (tester) async {
    final model = Obs<List<String>>(<String>['a']);
    final focusNode = FocusNode();
    final changes = <List<String>>[];
    final removed = <(String, int)>[];
    var cleared = 0;
    addTearDown(model.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        ElInputTag(
          modelValue: model,
          focusNode: focusNode,
          clearable: true,
          onChanged: (next) => changes.add(List<String>.of(next)),
          onRemove: (value, index) => removed.add((value, index)),
          onClear: () => cleared++,
        ),
      ),
    );
    await _focus(tester, focusNode);
    await _type(tester, 'b');
    await _key(tester, LogicalKeyboardKey.enter);
    expect(model.value, ['a', 'b']);
    expect(changes, [
      ['a', 'b'],
    ]);

    final close = find.descendant(of: _tag(0), matching: find.byType(ElButtonView));
    await tester.tap(close);
    await tester.pump();
    await tester.pump();
    expect(model.value, ['b']);
    expect(removed, [('a', 0)]);
    expect(changes, [
      ['a', 'b'],
      ['b'],
    ]);

    await tester.tap(find.byKey(const ValueKey<String>('el-input-tag-clear')));
    await tester.pump();
    expect(model.value, isEmpty);
    expect(cleared, 1);
    expect(changes, [
      ['a', 'b'],
      ['b'],
      <String>[],
    ]);

    model.value = <String>['outside'];
    await tester.pump();
    expect(tester.widget<ElTag>(_tag(0)).child, 'outside');
    expect(changes, [
      ['a', 'b'],
      ['b'],
      <String>[],
    ], reason: '外部 modelValue 回灌不应伪造成用户 onChanged');
  });

  testWidgets('ElForm prop：List<String> 双向直连，change/blur 校验与动态列表回灌正确', (tester) async {
    final model = Obs<Map<String, dynamic>>(<String, dynamic>{
      'skills': <dynamic>['Dart'],
    });
    final focusNode = FocusNode();
    late ElFormState form;
    addTearDown(model.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        ElForm(
          modelValue: model,
          rules: {
            'skills': [const ElRequiredFormRule(message: '至少一个技能')],
          },
          child: Builder(
            builder: (context) {
              form = ElForm.of(context);
              return ElFormItem(
                prop: 'skills',
                child: ElInputTag(focusNode: focusNode, clearable: true),
              );
            },
          ),
        ),
      ),
    );
    expect(tester.widget<ElTag>(_tag(0)).child, 'Dart');
    await _focus(tester, focusNode);
    await _type(tester, 'Flutter');
    await _key(tester, LogicalKeyboardKey.enter);
    expect(model.value['skills'], ['Dart', 'Flutter']);
    expect(model.value['skills'], isA<List<String>>());

    await tester.tap(find.byKey(const ValueKey<String>('el-input-tag-clear')));
    await tester.pump();
    expect(model.value['skills'], isEmpty);
    expect(form.errorMessages['skills'], isNull, reason: '必填规则只在 blur 触发');
    focusNode.unfocus();
    await tester.pump();
    await tester.pump();
    expect(form.errorMessages['skills'], '至少一个技能');

    model.value = <String, dynamic>{
      'skills': <dynamic>['Rust'],
    };
    await tester.pump();
    await tester.pump();
    expect(tester.widget<ElTag>(_tag(0)).child, 'Rust');
  });

  testWidgets('控制门面支持 focus/blur、热替换，默认 saveOnBlur 只提交一次', (tester) async {
    final firstController = ElInputTagController();
    final secondController = ElInputTagController();
    final model = Obs<List<String>>(<String>[]);
    final changes = <List<String>>[];
    var useSecond = false;
    addTearDown(model.dispose);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          ElInputTag(
            controller: useSecond ? secondController : firstController,
            modelValue: model,
            onChanged: (next) => changes.add(List<String>.of(next)),
          ),
        ),
      ),
    );
    expect(firstController.attached, isTrue);
    expect(secondController.attached, isFalse);
    expect(firstController.focus(), isTrue);
    await tester.pump();
    await _type(tester, 'blur-save');
    expect(firstController.blur(), isTrue);
    await tester.pump();
    await tester.pump();
    expect(model.value, ['blur-save']);
    expect(changes, [
      ['blur-save'],
    ]);

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          useSecond = true;
          return _host(ElInputTag(controller: secondController, modelValue: model));
        },
      ),
    );
    await tester.pump();
    expect(firstController.attached, isFalse);
    expect(firstController.focus(), isFalse);
    expect(secondController.attached, isTrue);
    expect(secondController.focus(), isTrue);

    await tester.pumpWidget(_host(ElInputTag(controller: secondController, modelValue: model, disabled: true)));
    await tester.pump();
    expect(secondController.focus(), isFalse);
  });

  testWidgets('focusNode 热替换结算旧 blur/saveOnBlur，并接入已聚焦新节点', (tester) async {
    final model = Obs<List<String>>(<String>[]);
    final first = FocusNode();
    final second = FocusNode();
    var focusCount = 0;
    var blurCount = 0;
    var useSecond = false;
    late StateSetter updateHost;
    addTearDown(model.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    useSecond = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          updateHost = setState;
          return _host(
            Column(
              crossAxisAlignment: .start,
              children: [
                ElInputTag(
                  modelValue: model,
                  focusNode: useSecond ? second : first,
                  onFocus: () => focusCount++,
                  onBlur: () => blurCount++,
                ),
              ],
            ),
          );
        },
      ),
    );
    await _focus(tester, first);
    await _type(tester, 'old-node');
    expect(focusCount, 1);

    updateHost(() => useSecond = true);
    await tester.pump();
    await tester.pump();
    expect(model.value, ['old-node']);
    expect(blurCount, 1);
    expect(focusCount, 1);

    updateHost(() => useSecond = false);
    await tester.pump();
    second.requestFocus();
    updateHost(() => useSecond = true);
    await tester.pump();
    await tester.pump();
    expect(second.hasFocus, isTrue);
    expect(focusCount, 2, reason: '新 focusNode 在别处已聚焦时，热接入 InputTag 也要补发 onFocus');
    expect(blurCount, 1);
  });

  testWidgets('Controller 禁止双实例同时绑定，卸载后可复用', (tester) async {
    final controller = ElInputTagController();
    final captured = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = captured.add;

    try {
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: .min,
            children: [
              ElView(
                style: const ElStyle(width: 220),
                child: ElInputTag(controller: controller),
              ),
              ElView(
                style: const ElStyle(width: 220),
                child: ElInputTag(controller: controller),
              ),
            ],
          ),
        ),
      );
    } finally {
      FlutterError.onError = previousOnError;
    }

    await tester.pumpWidget(_host(ElView(child: 'empty')));
    await tester.pump();
    expect(captured.map((details) => details.exception), contains(isA<StateError>()));
    expect(controller.attached, isFalse);

    await tester.pumpWidget(_host(ElInputTag(controller: controller)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(controller.attached, isTrue);

    await tester.pumpWidget(_host(ElView(child: 'empty')));
    await tester.pump();
    expect(controller.attached, isFalse);
  });
}
