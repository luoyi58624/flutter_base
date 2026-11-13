import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget card, {Brightness brightness = Brightness.light}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: true),
    child: ElView(
      themeMode: ElThemeMode(brightness: brightness),
      child: ElComponentProvider(
        components: el.mobileComponents,
        child: Align(
          alignment: .topLeft,
          child: SizedBox(width: 320, child: card),
        ),
      ),
    ),
  ),
);

Finder _surface() => find.descendant(
  of: find.byType(ElCard),
  matching: find.byWidgetPredicate((widget) => widget is ElView && widget.style?.width == '100%'),
);

void main() {
  test('移动端五档阴影只使用柔和投影，按层级增加范围和下移距离', () {
    final keys = [ElTokens.$shadowXs, ElTokens.$shadowSm, ElTokens.$shadowMd, ElTokens.$shadowLg, ElTokens.$shadowXl];
    for (final dark in [false, true]) {
      final tokens = {...el.mobileComponents.style!.vars!, if (dark) ...el.mobileComponents.style!.onDark!.vars!};
      var previousBlur = 0.0;
      var previousOffset = 0.0;
      for (final key in keys) {
        final shadows = ElStyle().withShadow(level: tokens[key] as int).boxShadow!;
        expect(shadows, isNotEmpty);
        for (final shadow in shadows) {
          expect(shadow.blurRadius, greaterThan(0), reason: '零模糊轮廓会产生描边感');
          expect(shadow.spreadRadius, lessThanOrEqualTo(0));
          expect(shadow.offset.dx, 0);
        }
        expect(shadows.last.blurRadius, greaterThan(previousBlur));
        expect(shadows.last.offset.dy, greaterThanOrEqualTo(previousOffset));
        previousBlur = shadows.last.blurRadius;
        previousOffset = shadows.last.offset.dy;
      }
    }
  });

  testWidgets('卡片按压同时改变颜色与缩放，style 可逐字段覆盖，取消后恢复', (tester) async {
    var calls = 0;
    for (final custom in [false, true]) {
      await tester.pumpWidget(
        _host(
          ElCard(
            onTap: () => calls++,
            style: custom
                ? ElStyle(
                    onTap: ElStyle(backgroundColor: Colors.purple, transform: ElTransform.scale(.9)),
                  )
                : null,
            child: SizedBox(height: 60),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final render = tester.renderObject<ElRenderView>(_surface());
      final original = render.committedResolvedStyle.box;
      final touch = await tester.startGesture(tester.getCenter(_surface()));
      await tester.pump(Duration(milliseconds: 100));
      expect(
        render.committedResolvedStyle.box.backgroundColor,
        custom ? Colors.purple : el.mobileComponents.style!.vars![ElTokens.$cardPressColor],
      );
      expect(render.committedResolvedStyle.box.transform, ElTransform.scale(custom ? .9 : .96));
      await touch.cancel();
      await tester.pumpAndSettle();
      expect(render.committedResolvedStyle.box.backgroundColor, original.backgroundColor);
      expect(render.committedResolvedStyle.box.transform, original.transform);
      expect(calls, 0);
    }
  });

  testWidgets('移动端卡片默认不创建焦点，也不建立区域语义容器', (tester) async {
    for (final onTap in <VoidCallback?>[null, () {}]) {
      await tester.pumpWidget(_host(ElCard(semanticLabel: '区域', onTap: onTap, child: Text('正文'))));
      expect(FocusManager.instance.rootScope.traversalDescendants.where((node) => node is! FocusScopeNode), isEmpty);
      expect(find.bySemanticsLabel('区域'), findsNothing);
    }
  });

  testWidgets('shadowLevel 读取品牌五档明暗阴影，style 可以覆盖和移除', (tester) async {
    for (final brightness in Brightness.values) {
      final tokens = {
        ...el.mobileComponents.style!.vars!,
        if (brightness == Brightness.dark) ...el.mobileComponents.style!.onDark!.vars!,
      };
      final levels = {
        ElLevelType.xs: ElTokens.$shadowXs,
        ElLevelType.sm: ElTokens.$shadowSm,
        ElLevelType.md: ElTokens.$shadowMd,
        ElLevelType.lg: ElTokens.$shadowLg,
        ElLevelType.xl: ElTokens.$shadowXl,
      };
      for (final entry in levels.entries) {
        await tester.pumpWidget(
          _host(
            ElCard(shadowLevel: entry.key, child: SizedBox(height: 30)),
            brightness: brightness,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.renderObject<ElRenderView>(_surface()).committedResolvedStyle.box.boxShadow,
          ElStyle().withShadow(level: tokens[entry.value] as int).boxShadow,
        );
      }
    }
    await tester.pumpWidget(
      _host(
        ElView(
          style: ElStyle(vars: {ElTokens.$shadowMd: 37}),
          child: ElCard(shadowLevel: .md, child: SizedBox(height: 30)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.renderObject<ElRenderView>(_surface()).committedResolvedStyle.box.boxShadow,
      ElStyle().withShadow(level: 37).boxShadow,
    );
    await tester.pumpWidget(_host(ElCard()));
    await tester.pumpAndSettle();
    expect(tester.renderObject<ElRenderView>(_surface()).committedResolvedStyle.box.boxShadow, isNull);
    expect(tester.renderObject<ElRenderView>(_surface()).committedResolvedStyle.box.border, isNull);
    for (final shadows in [
      <BoxShadow>[],
      [BoxShadow(color: Colors.green, blurRadius: 4)],
    ]) {
      await tester.pumpWidget(
        _host(
          ElCard(
            shadowLevel: .md,
            style: ElStyle(
              boxShadow: shadows,
              border: ElBorder.all(borderColor: Colors.blue),
            ),
            child: SizedBox(height: 30),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.renderObject<ElRenderView>(_surface()).committedResolvedStyle.box.boxShadow, shadows);
      expect(
        tester.renderObject<ElRenderView>(_surface()).committedResolvedStyle.box.border!.borderTop.borderColor,
        Colors.blue,
      );
    }
  });

  testWidgets('event 保留识别配置与默认动作取消，禁用时不激活', (tester) async {
    var taps = 0, events = 0;
    await tester.pumpWidget(
      _host(
        ElCard(
          onTap: () => taps++,
          event: ElEvent(
            delayTouchDown: Duration(milliseconds: 150),
            delayTouchUp: Duration.zero,
            onTap: (event) {
              events++;
              event.preventDefault();
            },
          ),
          child: SizedBox(height: 40),
        ),
      ),
    );
    final render = tester.renderObject<ElRenderView>(_surface());
    final touch = await tester.startGesture(tester.getCenter(_surface()));
    await tester.pump(Duration(milliseconds: 100));
    expect(render.committedResolvedStyle.box.backgroundColor, el.mobileComponents.style!.vars![ElTokens.$cardColor]);
    await tester.pump(Duration(milliseconds: 60));
    expect(render.committedResolvedStyle.box.transform, ElTransform.scale(.96));
    await touch.up();
    await tester.pumpAndSettle();
    expect(events, 1);
    expect(taps, 0);
    await tester.pumpWidget(
      _host(ElCard(onTap: () => taps++, event: ElEvent(disabled: true), child: SizedBox(height: 40))),
    );
    await tester.tap(_surface());
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });
}
