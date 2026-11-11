import 'dart:convert';

import 'package:example/src/pages/examples/scroll_examples/rich_document.dart';
import 'package:example/src/pages/examples/scroll_examples/scroll_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

const _baseline = bool.fromEnvironment('SPECIAL_REUSE_BASELINE');

void main() {
  for (final mode in SliverExampleMode.values) {
    testWidgets('${mode.name} 文档局部展开保留其余小节，回收源码后高度恢复', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(390, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: ElComponentProvider(components: el.mobileComponents, child: RecyclerRichDocumentPage()),
        ),
      );
      await tester.pumpAndSettle();
      if (mode == .official) {
        final menu = tester.widget<PopupMenuButton<SliverExampleMode>>(find.byKey(ValueKey('comparison-mode-menu')));
        menu.onSelected!(mode);
        await tester.pumpAndSettle();
      }
      final cards = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_SectionCard');
      final before = {for (final element in cards.evaluate()) element: element.widget};
      expect(before.length, mode == .recycler ? 240 : lessThan(20));
      final title = find.byKey(ValueKey('rich-document-title-0'));
      final first = find.ancestor(of: title, matching: cards);
      final height = tester.getSize(first).height;
      final builds = <Element, int>{};
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        if (before.containsKey(element)) builds.update(element, (count) => count + 1, ifAbsent: () => 1);
      };
      try {
        for (final expanded in [true, false]) {
          builds.clear();
          tester.widget<TextButton>(find.byKey(ValueKey('rich-document-code-toggle-0'))).onPressed!();
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('rich-document-code-0')), expanded ? findsOneWidget : findsNothing);
          expect(tester.getSize(first).height, expanded ? greaterThan(height) : closeTo(height, .01));
          debugPrintSynchronously(
            'SPECIAL_REUSE_RESULT ${jsonEncode({'scene': 'richDocument', 'mode': mode == .recycler ? 'resident' : 'official', 'content_sliver': mode == .recycler ? 'ElSliverList' : 'SliverList', 'phase': expanded ? 'expand' : 'collapse', 'mounted_sections': before.length, 'section_rebuilds': builds.values.fold(0, (sum, value) => sum + value), 'changed_section_widgets': before.entries.where((entry) => entry.key.mounted && !identical(entry.key.widget, entry.value)).length})}',
          );
          if (!_baseline) {
            expect(builds, isEmpty, reason: '源码叶子改变高度，无需重建小节壳或其他小节。');
            for (final entry in before.entries.where((entry) => entry.key.mounted)) {
              expect(entry.key.widget, same(entry.value));
            }
          }
          expect(tester.takeException(), isNull);
        }
      } finally {
        debugOnRebuildDirtyWidget = previous;
      }
      await tester.pumpWidget(SizedBox.shrink());
    });
  }
}
