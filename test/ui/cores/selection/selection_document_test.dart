import 'package:flutter_base/src/ui/cores/selection/docs/selection_view.dart';
import 'dart:convert';

import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Align(alignment: Alignment.topLeft, child: child),
);

void main() {
  testWidgets('当前文档直接登记文本和图片，共享官方选区与纯文本复制', (tester) async {
    final document = SelectionDocument();
    addTearDown(() async {
      await tester.pumpWidget(SizedBox());
      document.dispose();
    });
    await tester.pumpWidget(
      _host(
        SelectionContainer(
          delegate: document,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElView(child: 'own'),
              Text('native'),
              ElImageView.memory(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4AWMAAQAABQABDQottAAAAABJRU5ErkJggg==',
                ),
                alt: 'picture',
                width: 24,
                height: 24,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(document.members, hasLength(3));
    document.dispatchSelectionEvent(SelectAllSelectionEvent());
    await tester.pump();
    expect(document.getSelectedContent()?.plainText, 'own\nnative\npicture');
    expect(document.edge(end: false), isNotNull);
    expect(document.edge(end: true), isNotNull);
    document.dispatchSelectionEvent(ClearSelectionEvent());
    expect(document.getSelectedContent(), isNull);
    await tester.pumpWidget(SizedBox());
    expect(document.members, isEmpty);
  });

  testWidgets('成员替换后只登记当前挂载内容，卸载对象不进入复制结果', (tester) async {
    final key = GlobalKey();
    final document = SelectionDocument();
    addTearDown(() async {
      await tester.pumpWidget(SizedBox());
      document.dispose();
    });
    Widget build(bool replace) => _host(
      SelectionContainer(
        key: key,
        delegate: document,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElView(key: ValueKey(replace ? 'new' : 'old'), child: replace ? 'new' : 'old'),
            ElView(key: ValueKey('survivor'), child: 'survivor'),
          ],
        ),
      ),
    );
    await tester.pumpWidget(build(false));
    document.dispatchSelectionEvent(SelectAllSelectionEvent());
    expect(document.getSelectedContent()?.plainText, 'old\nsurvivor');
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(document.members.length, 2);
    expect(document.getSelectedContent()?.plainText, isNot(contains('old')));
    document.dispatchSelectionEvent(SelectAllSelectionEvent());
    expect(document.getSelectedContent()?.plainText, 'new\nsurvivor');
  });

  testWidgets('官方边缘事件跨越 El 文本和官方 Text 时补齐当前范围', (tester) async {
    final key = GlobalKey();
    final ownKey = GlobalKey();
    final nativeKey = GlobalKey();
    final document = SelectionDocument();
    addTearDown(() async {
      await tester.pumpWidget(SizedBox());
      document.dispose();
    });
    await tester.pumpWidget(
      _host(
        SelectionContainer(
          key: key,
          delegate: document,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElView(key: ownKey, child: 'first'),
              Text('last', key: nativeKey),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byKey(ownKey));
    final last = tester.getRect(find.byKey(nativeKey));
    document.dispatchSelectionEvent(SelectionEdgeUpdateEvent.forStart(globalPosition: first.centerLeft + Offset(1, 0)));
    document.dispatchSelectionEvent(SelectionEdgeUpdateEvent.forEnd(globalPosition: last.centerRight - Offset(1, 0)));
    expect(document.getSelectedContent()?.plainText, 'first\nlast');
  });
}
