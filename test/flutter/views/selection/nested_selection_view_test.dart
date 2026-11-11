import 'package:flutter_base/src/flutter/views/selection/common/selection_core.dart' show selectionParticipantOf;
import 'package:flutter_base/src/flutter/views/selection/docs/selection_view.dart';

import 'package:flutter_base/src/flutter/views/view/view.dart';
import 'package:flutter_base/src/flutter/views/view/render/render_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

const _outerTopKey = Key('outer-top-text');
const _innerKey = Key('inner-text');
const _outerBottomKey = Key('outer-bottom-text');

/// 外层（全局）+ 内层（组件自带）双包裹结构。
Widget _nested({required ElSelectionController outer, required ElSelectionController inner, bool outerEnabled = true}) {
  return ElSelectionView(
    enabled: outerEnabled,
    controller: outer,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ElView(child: 'alpha one', key: _outerTopKey),
        ElSelectionView(
          controller: inner,
          child: const ElView(child: 'bravo two', key: _innerKey),
        ),
        const ElView(child: 'charlie three', key: _outerBottomKey),
      ],
    ),
  );
}

List<RenderSelectionView> _roots(WidgetTester tester) {
  // allRenderObjects 按 element 遍历：选区根上方的组件元素（Focus 包装等）
  // 会把同一个 render 报多次，按 identity 去重（Set 保插入序）。
  return tester.allRenderObjects.whereType<RenderSelectionView>().toSet().toList();
}

/// 按 key 取文本参与者的当前选区 range。
TextRange? _rangeOf(WidgetTester tester, Key key) {
  final render = tester.renderObject<ElRenderView>(find.byKey(key));
  return selectionParticipantOf(render)?.currentSelectionRange;
}

Future<void> _mouseDrag(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.down(from);
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('嵌套文档各自全选，不接管另一根的内容', (tester) async {
    final outer = ElSelectionController();
    final inner = ElSelectionController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    await tester.pumpWidget(_app(_nested(outer: outer, inner: inner)));
    expect(_roots(tester).every((root) => root.selectionEnabled), isTrue);
    outer.selectAll();
    inner.selectAll();
    await tester.pump();
    expect(outer.text, 'alpha one\ncharlie three');
    expect(inner.text, 'bravo two');
    expect(_rangeOf(tester, _innerKey), const TextRange(start: 0, end: 9));
    outer.clear();
    await tester.pump();
    expect(outer.hasSelection, isFalse);
    expect(inner.text, 'bravo two');
  });

  testWidgets('外层跨过内层拖动只选择外层文档', (tester) async {
    final outer = ElSelectionController();
    final inner = ElSelectionController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    await tester.pumpWidget(_app(_nested(outer: outer, inner: inner)));
    final top = tester.getRect(find.byKey(_outerTopKey));
    final bottom = tester.getRect(find.byKey(_outerBottomKey));
    await _mouseDrag(tester, top.centerLeft + const Offset(1, 0), bottom.centerRight - const Offset(1, 0));
    expect(outer.text, 'alpha one\ncharlie three');
    expect(inner.hasSelection, isFalse);
    expect(_rangeOf(tester, _innerKey), isNull);
  });

  testWidgets('内层起手拖出文档仍只更新内层选区', (tester) async {
    final outer = ElSelectionController();
    final inner = ElSelectionController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    await tester.pumpWidget(_app(_nested(outer: outer, inner: inner)));
    final rect = tester.getRect(find.byKey(_innerKey));
    final bottom = tester.getRect(find.byKey(_outerBottomKey));
    await _mouseDrag(tester, rect.centerLeft + const Offset(1, 0), bottom.centerRight - const Offset(1, 0));
    expect(inner.text, 'bravo two');
    expect(outer.hasSelection, isFalse);
    expect(_rangeOf(tester, _outerBottomKey), isNull);
  });

  testWidgets('外层禁用与恢复不改变内层的启用状态和选区', (tester) async {
    final outer = ElSelectionController();
    final inner = ElSelectionController();
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    var enabled = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _nested(outer: outer, inner: inner, outerEnabled: enabled);
          },
        ),
      ),
    );
    inner.selectAll();
    await tester.pump();
    for (final value in [false, true]) {
      rebuild(() => enabled = value);
      await tester.pump();
      expect(_roots(tester).last.selectionEnabled, isTrue);
      expect(inner.text, 'bravo two');
      outer.selectAll();
      await tester.pump();
      expect(outer.text, value ? 'alpha one\ncharlie three' : null);
    }
  });
}
