import 'package:flutter/widgets.dart';
import 'package:flutter_base/ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewKey = ValueKey('constrained-intrinsic-view');

Widget _scene(Widget child, {required bool horizontal}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: horizontal ? 300 : 100,
        maxHeight: horizontal ? 100 : 300,
      ),
      child: child,
    ),
  ),
);

void main() {
  for (final horizontal in [false, true]) {
    for (final minimum in [true, false]) {
      testWidgets(
        '${minimum ? "最小" : "最大"}固有${horizontal ? "宽度" : "高度"}按受限跨轴尺寸扣除内外边距',
        (tester) async {
          await tester.pumpWidget(
            _scene(
              ElView(
                key: _viewKey,
                style: ElStyle(
                  width: horizontal ? null : 200,
                  height: horizontal ? 200 : null,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.all(5),
                ),
                child: AspectRatio(aspectRatio: horizontal ? 0.5 : 2),
              ),
              horizontal: horizontal,
            ),
          );
          final view = tester.renderObject<RenderBox>(find.byKey(_viewKey));
          expect(
            view.size,
            horizontal ? const Size(65, 100) : const Size(100, 65),
          );

          final double intrinsic;
          if (horizontal) {
            intrinsic = minimum
                ? view.getMinIntrinsicWidth(100)
                : view.getMaxIntrinsicWidth(100);
          } else {
            intrinsic = minimum
                ? view.getMinIntrinsicHeight(100)
                : view.getMaxIntrinsicHeight(100);
          }
          // 跨轴内容尺寸为 100 - 10(margin) - 20(padding)，按比例换轴后加回边距。
          expect(intrinsic, 65);
        },
      );
    }

    testWidgets(
      '${horizontal ? "IntrinsicWidth" : "IntrinsicHeight"} 中超出父约束的声明尺寸不增加占位',
      (tester) async {
        final view = ElView(
          key: _viewKey,
          style: ElStyle(
            width: horizontal ? null : 200,
            height: horizontal ? 200 : null,
          ),
          child: AspectRatio(aspectRatio: horizontal ? 0.5 : 2),
        );
        await tester.pumpWidget(
          _scene(
            horizontal
                ? IntrinsicWidth(child: view)
                : IntrinsicHeight(child: view),
            horizontal: horizontal,
          ),
        );
        expect(
          tester.getSize(find.byKey(_viewKey)),
          horizontal ? const Size(50, 100) : const Size(100, 50),
        );
      },
    );
  }
}
