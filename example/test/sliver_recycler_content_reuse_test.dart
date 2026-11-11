import 'package:example/src/pages/examples/sliver_recycler/index.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  home: ElComponentProvider(
    components: el.mobileComponents,
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('复杂卡片按实际字段更新，保留图片地点与静态说明并点击当前记录', (tester) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: Builder(builder: (context) => ElSliverRecyclerExampleContent.complex.buildItem(context, index)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    final place = tester.widget<Text>(find.text('松林北坡'));
    final description = tester.widget<Text>(find.text('暮色里记录到一次短暂的停栖，随后飞入林间。'));
    final placeIcon = tester.widget<Icon>(find.byIcon(Icons.place_outlined));
    final timeIcon = tester.widget<Icon>(find.byIcon(Icons.schedule));
    index.value = 4;
    await tester.pumpAndSettle();
    expect(find.text('林缘的猫头鹰 · #5'), findsOneWidget);
    expect(find.text('10 分钟'), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)), same(image));
    expect(tester.widget<Text>(find.text('松林北坡')), same(place));
    expect(tester.widget<Text>(find.text('暮色里记录到一次短暂的停栖，随后飞入林间。')), same(description));
    expect(tester.widget<Icon>(find.byIcon(Icons.place_outlined)), same(placeIcon));
    expect(tester.widget<Icon>(find.byIcon(Icons.schedule)), same(timeIcon));
    await tester.tap(find.text('查看记录'));
    await tester.pumpAndSettle();
    expect(find.text('记录 #5 · 松林北坡'), findsOneWidget);
    index.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('树梢的夜行者 · #2'), findsOneWidget);
    expect(find.text('石桥溪谷'), findsOneWidget);
    expect(find.text('7 分钟'), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isNot(image.image));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });

  testWidgets('矩形换绑相同颜色不更新叶子，颜色变化仍生效', (tester) async {
    final index = ValueNotifier(0);
    addTearDown(index.dispose);
    await tester.pumpWidget(
      _app(Builder(builder: (context) => ElSliverRecyclerExampleContent.rectangles.buildItem(context, index))),
    );
    final leaf = find.descendant(
      of: find.byType(ElListenableBuilder<ValueListenable<int>, Color>),
      matching: find.byType(ColoredBox),
    );
    final initial = tester.widget<ColoredBox>(leaf);
    index.value = 4;
    await tester.pump();
    expect(tester.widget<ColoredBox>(leaf), same(initial));
    index.value = 1;
    await tester.pump();
    expect(tester.widget<ColoredBox>(leaf).color, isNot(initial.color));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(SizedBox.shrink());
  });
}
