import 'dart:convert';

import 'package:flutter_base/src/flutter/widgets/image/index.dart';
import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart';

import 'package:flutter_base/src/flutter/views/view/render/render_view.dart';
import 'package:flutter_base/src/flutter/views/view/style/style.dart';
import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Delegate extends StaticSelectionContainerDelegate {
  List<Selectable> get members => List.of(selectables);
}

Widget _app(_Delegate delegate, List<Widget> children) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: SelectionContainer(
      delegate: delegate,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  ),
);

void main() {
  testWidgets('El 文本、官方 Text 与图片共用官方注册和选区事件', (tester) async {
    final delegate = _Delegate();
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      _app(delegate, [
        ElView(child: 'el text'),
        Text('native text'),
        ElImage.memory(
          base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4AWMAAQAABQABDQottAAAAABJRU5ErkJggg=='),
          alt: 'picture',
          width: 24,
          height: 24,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(delegate.members, hasLength(3));
    expect(delegate.members.whereType<SelectionParticipant>(), hasLength(2));
    delegate.dispatchSelectionEvent(SelectAllSelectionEvent());
    await tester.pump();
    expect(delegate.members.map((node) => node.getSelectedContent()?.plainText), ['el text', 'native text', 'picture']);
    expect(delegate.value.status, SelectionStatus.uncollapsed);
    expect(delegate.value.startSelectionPoint, isNotNull);
    expect(delegate.value.endSelectionPoint, isNotNull);

    delegate.dispatchSelectionEvent(ClearSelectionEvent());
    expect(delegate.getSelectedContent(), isNull);
    await tester.pumpWidget(SizedBox());
    await tester.pump();
    expect(delegate.members, isEmpty);
  });

  testWidgets('官方边缘事件可跨 El 文本和官方 Text 连续选中', (tester) async {
    final delegate = _Delegate();
    addTearDown(delegate.dispose);
    final own = GlobalKey();
    final native = GlobalKey();
    await tester.pumpWidget(
      _app(delegate, [
        ElView(key: own, style: ElStyle(fontSize: 20), child: 'alpha beta'),
        Text('gamma delta', key: native, style: TextStyle(fontSize: 20)),
      ]),
    );
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byKey(own));
    final last = tester.getRect(find.byKey(native));
    delegate.dispatchSelectionEvent(SelectionEdgeUpdateEvent.forStart(globalPosition: first.centerLeft + Offset(1, 0)));
    delegate.dispatchSelectionEvent(SelectionEdgeUpdateEvent.forEnd(globalPosition: last.centerRight - Offset(1, 0)));
    await tester.pump();
    expect(delegate.members.first.getSelectedContent()?.plainText, 'alpha beta');
    expect(delegate.members.last.getSelectedContent()?.plainText, 'gamma delta');
  });

  testWidgets('官方协议稳定拖选保留 ElView 渲染宿主和正文布局缓存', (tester) async {
    final delegate = _Delegate();
    addTearDown(delegate.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(delegate, [
        ElView(
          key: key,
          style: ElStyle(
            fontSize: 20,
            onSelection: ElStyle(backgroundColor: Colors.blue, color: Colors.white),
          ),
          child: 'alpha beta gamma delta',
        ),
      ]),
    );
    await tester.pumpAndSettle();
    final render = tester.renderObject<ElRenderView>(find.byKey(key));
    final layouts = render.debugLayoutCount;
    final rect = tester.getRect(find.byKey(key));
    delegate.dispatchSelectionEvent(SelectionEdgeUpdateEvent.forStart(globalPosition: rect.centerLeft + Offset(1, 0)));
    for (var i = 1; i <= 6; i++) {
      delegate.dispatchSelectionEvent(
        SelectionEdgeUpdateEvent.forEnd(globalPosition: rect.centerLeft + Offset(rect.width * i / 7, 0)),
      );
      await tester.pump();
    }
    expect(identical(tester.renderObject(find.byKey(key)), render), isTrue);
    expect(render.debugLayoutCount, layouts);
    expect(selectionParticipantOf(render)?.currentSelectionRange?.isCollapsed, isFalse);
    expect(selectionParticipantOf(render)!.effectiveSelectionBgColor, Colors.blue);
    expect(selectionParticipantOf(render)!.effectiveSelectionTextColor, Colors.white);
  });
}
