import 'package:flutter_base/src/ui/testing/ui_test_api.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _headerKey = ValueKey<String>('selection-boundary-header');
const _headerUpperKey = ValueKey<String>('selection-boundary-header-upper');
const _anchorKey = ValueKey<String>('selection-boundary-anchor');

void main() {
  testWidgets('层叠视觉层级变化不改变文档全选顺序', (tester) async {
    final controller = ElSelectionController();
    final layer = ValueNotifier<int>(11);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ElSelectionView(
          controller: controller,
          child: ValueListenableBuilder<int>(
            valueListenable: layer,
            builder: (context, zIndex, _) => ElStackView(
              children: [
                ElPositioned(
                  top: 0,
                  left: 0,
                  zIndex: zIndex,
                  child: ElView(child: 'first'),
                ),
                ElPositioned(top: 0, left: 0, zIndex: 5, child: ElView(child: 'second')),
              ],
            ),
          ),
        ),
      ),
    );
    controller.selectAll();
    await tester.pump();
    final original = controller.text!;
    expect(original, contains('first'));
    expect(original, contains('second'));
    expect(original.indexOf('first'), lessThan(original.indexOf('second')));
    layer.value = 0;
    await tester.pump();
    controller.selectAll();
    await tester.pump();
    expect(controller.text, original);
    await tester.pumpWidget(SizedBox.shrink());
    controller.dispose();
    layer.dispose();
  });

  for (final nativeStack in [false, true]) {
    testWidgets('正文拖出上边缘保持当前范围，导航不加入文档，原生 Stack=$nativeStack', (tester) async {
      await tester.pumpWidget(_BoundaryHarness(nativeStack: nativeStack));
      await tester.pumpAndSettle();

      final header = tester.getRect(find.byKey(_headerKey));
      final upperHeader = tester.getRect(find.byKey(_headerUpperKey));
      final anchor = _centerOfText(tester, 'Body node 2');
      debugPrint('[selection-boundary-repro] header=$header anchor=$anchor');
      final gesture = await tester.startGesture(anchor, kind: PointerDeviceKind.mouse);
      final headerSelected = <bool>[];
      final anchorSelected = <bool>[];
      final ranges = <TextRange?>[];
      try {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump();
        debugPrint(
          '[selection-boundary-repro] after-start header=${_selected(tester, _headerKey)} anchor=${_selected(tester, _anchorKey)}',
        );

        // x 落在文字内部；使用宽容器中心会落到文本末尾，无法建立导航部分选区。
        for (final point in <Offset>[
          Offset(40, header.center.dy),
          Offset(40, header.top - 8),
          Offset(40, upperHeader.center.dy),
        ]) {
          await gesture.moveTo(point);
          await tester.pump();
          debugPrint(
            '[selection-boundary-repro] point=$point '
            'header=${tester.renderObject<ElRenderView>(find.byKey(_headerKey)).selectionParticipant?.currentSelectionRange} '
            'anchor=${tester.renderObject<ElRenderView>(find.byKey(_anchorKey)).selectionParticipant?.currentSelectionRange}',
          );
          headerSelected.add(_selected(tester, _headerKey));
          ranges.add(
            tester.renderObject<ElRenderView>(find.byKey(_headerKey)).selectionParticipant?.currentSelectionRange,
          );
          anchorSelected.add(_selected(tester, _anchorKey));
        }
        await gesture.moveTo(Offset(40, header.center.dy));
        await tester.pump();
        expect(
          tester.renderObject<ElRenderView>(find.byKey(_headerKey)).selectionParticipant?.currentSelectionRange,
          ranges.first,
          reason: '反向回到同一点必须恢复相同范围，不能用保留旧范围掩盖错误',
        );
        await gesture.moveTo(anchor);
        await tester.pump();
        expect(_selected(tester, _headerKey), isFalse, reason: '回到正文后导航应正常退出选区');
      } finally {
        await gesture.up();
        await tester.pump();
        await gesture.removePointer();
      }

      debugPrint('[selection-boundary-repro] header=$headerSelected anchor=$anchorSelected');
      expect(headerSelected, [false, false, false], reason: '导航始终不属于正文文档');
      expect(ranges[1], isNull);
      expect(ranges[2], ranges[1]);
      expect(anchorSelected, everyElement(isTrue), reason: '边界跳变不能把正文原选区清掉');
    });
  }
}

bool _selected(WidgetTester tester, Key key) {
  final range = _range(tester, key);
  return range != null && !range.isCollapsed;
}

TextRange? _range(WidgetTester tester, Key key) {
  final render = tester.renderObject<ElRenderView>(find.byKey(key));
  return render.selectionParticipant?.currentSelectionRange;
}

Offset _centerOfText(WidgetTester tester, String needle) {
  for (final participant in selectionParticipantsOf(tester.allRenderObjects)) {
    if (participant.selectionContentKind != SelectionContentKind.text) continue;
    final text = participant.selectionTextForRange(TextRange(start: 0, end: participant.selectionTextLength));
    if (text.contains(needle)) {
      return participant.box.localToGlobal(participant.box.size.center(Offset.zero));
    }
  }
  fail('未找到含 "$needle" 的选区参与者');
}

class _BoundaryHarness extends StatelessWidget {
  const _BoundaryHarness({required this.nativeStack});

  final bool nativeStack;

  Widget _stack(List<Widget> children) => nativeStack ? Stack(children: children) : ElStackView(children: children);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: SizedBox(
      width: 640,
      height: 360,
      child: _stack([
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: ElSelectionView(
              child: ElScroll(
                scrollCacheExtent: .pixels(0),
                children: [
                  for (var index = 0; index < 12; index++)
                    SizedBox(
                      height: 32,
                      child: ElView(
                        key: index == 2 ? _anchorKey : null,
                        child: 'Body node $index with selectable text.',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 36,
          width: 640,
          height: 18,
          child: const ElView(key: _headerKey, child: 'Navigation Header'),
        ),
        Positioned(
          left: 0,
          top: 0,
          width: 640,
          height: 18,
          child: const ElView(key: _headerUpperKey, child: 'Top navigation'),
        ),
      ]),
    ),
  );
}
