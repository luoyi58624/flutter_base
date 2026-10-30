import 'package:flutter_base/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final nativeStack in [false, true]) {
    testWidgets('层叠子盒同起点时，越出底边选择正文末端：原生 Stack=$nativeStack', (tester) async {
      final controller = ElSelectionController();
      addTearDown(() async {
        await tester.pumpWidget(SizedBox.shrink());
        controller.dispose();
      });
      final children = <Widget>[
        Positioned(left: 0, right: 0, top: 0, height: 56, child: ElView(child: '导航文字')),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                ElView(child: '起点之前'),
                ElView(key: ValueKey('anchor'), child: '拖选起点'),
                Spacer(),
                ElView(child: '正文末尾'),
              ],
            ),
          ),
        ),
      ];
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: ElSelectionView(
            controller: controller,
            child: nativeStack ? Stack(children: children) : ElStackView(children: children),
          ),
        ),
      );
      final start = tester.getCenter(find.byKey(ValueKey('anchor')));
      final gesture = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
      for (final point in [Offset(300, 599), Offset(300, 600), Offset(300, 700), Offset(300, 599)]) {
        await gesture.moveTo(point);
        await tester.pump();
        expect(controller.text, contains('正文末尾'));
        expect(controller.text, isNot(contains('导航文字')));
        expect(controller.text, isNot(contains('起点之前')));
      }
      await gesture.up();
    });
  }
}
