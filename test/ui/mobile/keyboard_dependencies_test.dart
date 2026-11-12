import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/flutter/views/editable/editable_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('键盘高度不重建卡片和编辑器，减少动画设置仍实时生效', (tester) async {
    final media = ValueNotifier(MediaQueryData(size: Size(390, 900)));
    addTearDown(media.dispose);
    final cardKey = GlobalKey();
    final content = ElComponentProvider(
      components: el.mobileComponents,
      child: Align(
        alignment: .topLeft,
        child: SizedBox(
          width: 320,
          child: ElCard(
            key: cardKey,
            child: ElInput(value: '输入内容'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<MediaQueryData>(
          valueListenable: media,
          child: content,
          builder: (_, data, child) => MediaQuery(data: data, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = tester.element(find.byKey(cardKey));
    final editor = tester.element(find.byType(EditableView));
    final previous = debugOnRebuildDirtyWidget;
    var cardBuilds = 0, editorBuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (identical(element, card)) cardBuilds++;
      if (identical(element, editor)) editorBuilds++;
      previous?.call(element, builtOnce);
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previous);
    for (final bottom in [120.0, 240.0, 320.0, 0.0]) {
      media.value = media.value.copyWith(viewInsets: EdgeInsets.only(bottom: bottom));
      await tester.pump();
    }
    expect(cardBuilds, 0, reason: '卡片只依赖减少动画设置');
    expect(editorBuilds, 0, reason: '键盘高度不影响编辑器动画配置');
    for (final disabled in [true, false]) {
      cardBuilds = editorBuilds = 0;
      media.value = media.value.copyWith(disableAnimations: disabled);
      await tester.pump();
      expect(cardBuilds, greaterThan(0));
      expect(editorBuilds, greaterThan(0));
      final surface = find.descendant(of: find.byKey(cardKey), matching: find.byType(ElView)).first;
      final transition = tester.widget<ElView>(surface).style!.transition!;
      expect(transition.isEmpty, disabled);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox());
  });
}
