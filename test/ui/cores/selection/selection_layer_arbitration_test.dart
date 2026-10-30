import '../../support/overlay.dart';
import '../../support/portal.dart';
import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('无文档作用域的弹层不自动创建选区', (tester) async {
    final sourceKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: ElTestOverlay(
          child: ElTestPortal(
            child: ElView(key: sourceKey, child: 'page'),
          ),
        ),
      ),
    );
    final source = sourceKey.currentContext!;
    ElTestPortal.of(source).show(builder: (_) => ElView(child: 'overlay'));
    await tester.pump();
    await tester.pump();
    expect(tester.allRenderObjects.whereType<RenderSelectionView>(), isEmpty);
  });

  testWidgets('文档内打开普通弹层不捕获选区配置或增加文档根', (tester) async {
    final selection = ElSelectionController();
    final sourceKey = GlobalKey();
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ElTestOverlay(
          child: ElTestPortal(
            child: ElSelectionView(
              controller: selection,
              child: ElView(key: sourceKey, child: 'page document'),
            ),
          ),
        ),
      ),
    );
    final originalRoot = tester.allRenderObjects.whereType<RenderSelectionView>().toSet().single;
    final source = sourceKey.currentContext!;
    final entry = ElTestPortal.of(source).show(builder: (_) => ElView(child: 'overlay content'));
    await tester.pump();
    await tester.pump();
    selection.selectAll();
    await tester.pump();
    expect(tester.allRenderObjects.whereType<RenderSelectionView>().toSet(), {originalRoot});
    expect(selection.text, 'page document');
    entry.close();
    await tester.pumpAndSettle();
    await tester.pump(Duration(milliseconds: 1));
    expect(selection.text, 'page document');
  });

  testWidgets('弹层显式文档只选择自身内容，关闭后释放控制器', (tester) async {
    final page = ElSelectionController();
    final overlay = ElSelectionController();
    final sourceKey = GlobalKey();
    addTearDown(page.dispose);
    addTearDown(overlay.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ElTestOverlay(
          child: ElTestPortal(
            child: ElSelectionView(
              controller: page,
              child: ElView(key: sourceKey, child: 'page document'),
            ),
          ),
        ),
      ),
    );
    final source = sourceKey.currentContext!;
    final entry = ElTestPortal.of(source).show(
      builder: (_) => ElSelectionView(
        controller: overlay,
        child: ElView(child: 'overlay document'),
      ),
    );
    await tester.pump();
    await tester.pump();
    page.selectAll();
    overlay.selectAll();
    await tester.pump();
    expect(tester.allRenderObjects.whereType<RenderSelectionView>().toSet(), hasLength(2));
    expect(page.text, 'page document');
    expect(overlay.text, 'overlay document');
    entry.close();
    await tester.pumpAndSettle();
    await tester.pump(Duration(milliseconds: 1));
    expect(tester.allRenderObjects.whereType<RenderSelectionView>().toSet(), hasLength(1));
    expect(overlay.text, isNull);
    expect(page.text, 'page document');
  });
}
