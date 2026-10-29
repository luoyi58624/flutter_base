import 'package:flutter_base/src/ui/testing/ui_test_api.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final interactiveSelection in [true, false]) {
    testWidgets('隐藏键盘后再次触摸可恢复输入（选区交互：$interactiveSelection）', (tester) async {
      final controller = EditableController(text: 'hello');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ElView(
            style: ElStyle(width: 320, height: 120),
            child: EditableView(
              controller: controller,
              focusNode: focusNode,
              style: EditableConfiguration(enableInteractiveSelection: interactiveSelection),
            ),
          ),
        ),
      );
      final editor = find.byType(EditableView);
      await tester.tap(editor);
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // 系统仅收起软键盘，焦点和输入连接都继续保留。
      tester.testTextInput.hide();
      tester.testTextInput.log.clear();
      await tester.pump(Duration(seconds: 1));
      expect(focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tap(editor);
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.testTextInput.log.where((call) => call.method == 'TextInput.setClient'), isEmpty);
      tester.testTextInput.updateEditingValue(TextEditingValue(text: 'hello!', selection: .collapsed(offset: 6)));
      await tester.pump();
      expect(controller.text, 'hello!');

      // 滑动取消点击后不能顺带重新弹出键盘。
      tester.testTextInput.hide();
      await tester.pump(Duration(seconds: 1));
      await tester.drag(editor, Offset(0, -60));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.pumpWidget(SizedBox.shrink());
    }, variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}));
  }
}
