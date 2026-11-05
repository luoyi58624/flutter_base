import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_base/src/ui/mobile/components/others/divider/index.dart' as skin;
import 'package:flutter_test/flutter_test.dart';

Finder _views(Finder parent, bool Function(ElView) predicate) =>
    find.descendant(of: parent, matching: find.byWidgetPredicate((widget) => widget is ElView && predicate(widget)));

void main() {
  testWidgets('卡片和列表按压、内容分隔线独立于控件边框及通用按压色，并随变量更新', (tester) async {
    var cardPress = Colors.green;
    var divider = Colors.purple;
    late StateSetter update;
    late ThemeData material;
    final rowKey = GlobalKey(), cardKey = GlobalKey();
    final content = Column(
      mainAxisSize: .min,
      children: [
        ElListGroup(
          children: [
            ElListTile(key: rowKey, title: Text('列表行'), onTap: () {}),
            ElListTile(title: Text('最后一行')),
          ],
        ),
        ElCard(key: cardKey, onTap: () {}, child: SizedBox(height: 20)),
        skin.Divider(),
        Builder(
          builder: (context) {
            material = context.elMaterialThemeData;
            return SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return ElMobileTheme(
                style: ElStyle(
                  vars: {
                    ElTokens.$cardPressColor: cardPress,
                    ElTokens.$dividerColor: divider,
                    ElTokens.$press: Colors.red,
                    ElTokens.$borderColor: Colors.blue,
                  },
                ),
                child: Align(
                  alignment: .topLeft,
                  child: SizedBox(width: 320, child: content),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = _views(find.byKey(rowKey), (view) => view.event?.onTap != null).first;
    final rowDivider = _views(find.byKey(rowKey), (view) => view.style?.height == .5);
    final card = _views(find.byKey(cardKey), (view) => view.style?.onTap?.backgroundColor != null).first;
    final line = _views(find.byType(skin.Divider), (view) => view.style?.border != null).first;
    for (var phase = 0; phase < 2; phase++) {
      expect(material.dividerColor, divider);
      expect(material.dividerTheme.color, divider);
      expect(material.tabBarTheme.dividerColor, divider);
      expect(material.inputDecorationTheme.enabledBorder!.borderSide.color, Colors.blue);
      expect(tester.renderObject<ElRenderView>(rowDivider).committedResolvedStyle.box.backgroundColor, divider);
      expect(tester.widget<ElView>(line).style!.border!.borderTop.borderColor, divider);
      for (final host in [row, card]) {
        final touch = await tester.startGesture(tester.getCenter(host));
        await tester.pump(Duration(milliseconds: 100));
        expect(tester.renderObject<ElRenderView>(host).committedResolvedStyle.box.backgroundColor, cardPress);
        await touch.cancel();
        await tester.pumpAndSettle();
      }
      if (phase == 0) {
        update(() {
          cardPress = Colors.orange;
          divider = Colors.teal;
        });
        await tester.pumpAndSettle();
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('弹出菜单沿用卡片按压与专用分隔线颜色', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ElMobileTheme(
            style: ElStyle(
              vars: {
                ElTokens.$cardPressColor: Colors.green,
                ElTokens.$dividerColor: Colors.purple,
                ElTokens.$press: Colors.red,
                ElTokens.$borderColor: Colors.blue,
              },
            ),
            child: Align(
              alignment: .topLeft,
              child: SizedBox(
                width: 320,
                child: ElListTile<int>.popup(
                  title: Text('菜单'),
                  value: 1,
                  options: [ElLabelModel('第一项', 1), ElLabelModel('第二项', 2)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('菜单'));
    await tester.pumpAndSettle();
    final item = find
        .ancestor(
          of: find.byWidgetPredicate((widget) => widget is ElView && widget.child == '第二项'),
          matching: find.byWidgetPredicate((widget) => widget is ElView && widget.event?.onTap != null),
        )
        .first;
    final touch = await tester.startGesture(tester.getCenter(item));
    await tester.pump(Duration(milliseconds: 100));
    expect(tester.renderObject<ElRenderView>(item).committedResolvedStyle.box.backgroundColor, Colors.green);
    expect(find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == Colors.purple), findsOneWidget);
    await touch.cancel();
    await tester.pumpAndSettle();
    await tester.pumpWidget(SizedBox());
    expect(tester.takeException(), isNull);
  });
}
