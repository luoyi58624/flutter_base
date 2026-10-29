import 'package:flutter_base/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/reparent.dart';

void main() {
  testWidgets('焦点切换不能在待布局子树上提前提交语义，下一帧仍正确上报焦点', (tester) async {
    final semantics = tester.ensureSemantics();
    final focus = FocusNode();
    final leaf = GlobalKey();
    final target = GlobalKey();
    await tester.pumpWidget(lifecycleHost(ElView(
      semantics: ElSemantics(container: true),
      child: Column(children: [
        ElView(key: target, focusNode: focus, child: 'focus target'),
        ElView(key: leaf, semantics: ElSemantics(label: 'layout child'), child: 'pending layout'),
      ]),
    )));
    await tester.pumpAndSettle();
    final render = tester.renderObject<RenderBox>(find.byKey(leaf));
    render.markNeedsLayout();
    render.markNeedsSemanticsUpdate();
    focus.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    expect(tester.takeException(), isNull, reason: 'idle 只表示不在帧内，不表示所有布局已经干净');
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(tester.getSemantics(find.byKey(target)).flagsCollection.isFocused.toBoolOrNull(), isTrue);
    await tester.pumpWidget(ElView());
    focus.dispose();
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
