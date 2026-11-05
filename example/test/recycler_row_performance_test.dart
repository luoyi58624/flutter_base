import 'dart:convert';

import 'package:example/src/pages/examples/recycler_view/chat.dart';
import 'package:example/src/pages/examples/recycler_view/selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/recycler_view.dart' as rv;
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in ['selection', 'chat-outgoing', 'chat-incoming']) {
    testWidgets('真实示例行绑定性能：$scenario', (tester) async {
      final content = ValueNotifier<Widget>(SizedBox.shrink());
      final page = scenario == 'selection' ? RecyclerSelectionPage() : RecyclerChatPage();
      await tester.pumpWidget(
        ElComponentProvider(
          components: el.mobileComponents,
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  // 保留实际页面和业务模型的生命周期，单独测同一适配器的真实行。
                  Offstage(child: page),
                  Align(
                    alignment: .topLeft,
                    child: ValueListenableBuilder<Widget>(
                      valueListenable: content,
                      builder: (context, child, _) => child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<rv.RecyclerView>(find.byType(rv.RecyclerView, skipOffstage: false));
      list.setItemViewCacheSize(0);
      (list.getLayoutManager()! as rv.LinearLayoutManager).setItemPrefetchEnabled(false);
      await tester.pump();
      final adapter = list.getAdapter()!;
      final first = scenario == 'chat-incoming' ? 1 : 0;
      final type = adapter.getItemViewType(first);
      final positions = [
        for (var index = 0; index < adapter.getItemCount(); index++)
          if (adapter.getItemViewType(index) == type) index,
      ].take(121).toList();
      final holder = adapter.createViewHolder(list, type);
      adapter.bindViewHolder(holder, positions.first);
      content.value = RepaintBoundary(child: SizedBox(width: 360, child: holder.itemView));
      await tester.pumpAndSettle();

      var elements = _elements(holder);
      final initialElements = elements.length;
      var rootRender = _root(holder).renderObject;
      var paragraphs = _paragraphs(elements);
      var added = 0;
      var removed = 0;
      var rootPreserved = 0;
      var paragraphPreserved = 0;
      var previousParagraphCount = 0;
      final timings = <int>[];
      final ids = <int>{holder.getItemId()};
      for (final position in positions.skip(1)) {
        final clock = Stopwatch()..start();
        adapter.bindViewHolder(holder, position);
        await tester.pump(Duration(milliseconds: 8));
        clock.stop();
        timings.add(clock.elapsedMicroseconds);
        final nextElements = _elements(holder);
        final nextRender = _root(holder).renderObject;
        final nextParagraphs = _paragraphs(nextElements);
        added += nextElements.difference(elements).length;
        removed += elements.difference(nextElements).length;
        if (identical(rootRender, nextRender)) rootPreserved++;
        paragraphPreserved += paragraphs.intersection(nextParagraphs).length;
        previousParagraphCount += paragraphs.length;
        elements = nextElements;
        rootRender = nextRender;
        paragraphs = nextParagraphs;
        ids.add(holder.getItemId());
      }
      expect(ids, hasLength(121), reason: '每次绑定必须真的换成不同业务 ID');
      expect(holder.getItemId(), adapter.getItemId(positions.last));
      if (scenario == 'selection') {
        final title = '条目 ${(positions.last + 1).toString().padLeft(5, '0')}';
        expect(find.text(title).hitTestable(), findsOneWidget);
      } else {
        expect(find.textContaining('消息 #${holder.getItemId() + 1}：').hitTestable(), findsOneWidget);
      }

      // 旧源码快照保留同样的工作量，只跳过用于守护修复的结构保留断言。
      if (!const bool.fromEnvironment('RECYCLER_LEGACY_BASELINE')) {
        expect(rootPreserved, timings.length, reason: '真实行不能只复用 holder 外壳');
        expect(added, 0, reason: '同类型未选中行换 ID 不应创建新的 Element');
        expect(removed, 0, reason: '同类型行的结构不应随业务 ID 销毁');
        expect(paragraphPreserved, previousParagraphCount, reason: '文本数据更新应保留已有 RenderParagraph');
      }
      expect(tester.takeException(), isNull);
      final sorted = [...timings]..sort();
      double p(double q) => sorted[((sorted.length - 1) * q).floor()] / 1000;
      debugPrint(
        'RECYCLER_REAL_ROW_PERF ${jsonEncode({'scenario': scenario, 'label': const String.fromEnvironment('RECYCLER_BENCH_LABEL', defaultValue: 'current'), 'source': 'actual page Adapter/ViewHolder and actual row widgets', 'environment': 'flutter_test/debug; host pump wall time, not phone FrameTiming/FPS', 'binds': timings.length, 'different_data_ids': ids.length, 'initial_elements': initialElements, 'added_elements': added, 'removed_elements': removed, 'root_render_preserved_binds': rootPreserved, 'retained_paragraphs': paragraphPreserved, 'previous_paragraphs': previousParagraphCount, 'pump_p50_ms': p(.5), 'pump_p95_ms': p(.95), 'pump_max_ms': p(1)})}',
      );
      await tester.pumpWidget(SizedBox());
      content.dispose();
    });
  }
}

Element _root(rv.ViewHolder holder) => find.byWidget(holder.itemView).evaluate().single;

Set<Element> _elements(rv.ViewHolder holder) {
  final result = <Element>{};
  void visit(Element element) {
    result.add(element);
    element.visitChildren(visit);
  }

  visit(_root(holder));
  return result;
}

Set<RenderParagraph> _paragraphs(Set<Element> elements) => {
  for (final element in elements)
    if (element is RenderObjectElement && element.renderObject is RenderParagraph)
      element.renderObject as RenderParagraph,
};
