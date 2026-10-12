import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('展示九个实际场景并支持全部切换和快速反向', (tester) async {
    await tester.binding.setSurfaceSize(Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ElAnimationExampleApp());
    expect(find.text('开关动画'), findsOneWidget);
    expect(_animations(tester), hasLength(9));
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.byKey(ValueKey('toggle-all')));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 60));
    expect(_animations(tester).every((widget) => !widget.value), true);
    await tester.tap(find.byKey(ValueKey('toggle-all')));
    await tester.pumpAndSettle();
    expect(_animations(tester).every((widget) => widget.value), true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('每张卡片单独控制自己的动画', (tester) async {
    await tester.binding.setSurfaceSize(Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ElAnimationExampleApp());
    await tester.tap(find.byKey(ValueKey('toggle-fade')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElFadeAnimation>(find.byKey(ValueKey('animation-fade')))
          .value,
      false,
    );
    expect(
      tester
          .widget<ElFadeScaleAnimation>(find.byType(ElFadeScaleAnimation))
          .value,
      true,
    );
    await tester.tap(find.byKey(ValueKey('toggle-fade')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElFadeAnimation>(find.byKey(ValueKey('animation-fade')))
          .value,
      true,
    );
  });

  testWidgets('360px 窄屏无溢出，所有场景可完成进出场', (tester) async {
    await tester.binding.setSurfaceSize(Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ElAnimationExampleApp());
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(ValueKey('toggle-all')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(ValueKey('toggle-all')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(ValueKey('toggle-collapseHorizontal')),
    );
    await tester.tap(find.byKey(ValueKey('toggle-collapseHorizontal')));
    await tester.pumpAndSettle();
    final horizontal = tester
        .widgetList<ElCollapseAnimation>(find.byType(ElCollapseAnimation))
        .singleWhere((widget) => widget.axis == Axis.horizontal);
    expect(horizontal.value, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('弹窗背景与内容在显隐和快速切换时保持同步', (tester) async {
    await tester.binding.setSurfaceSize(Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ElAnimationExampleApp());
    void verify() {
      double opacity(Finder owner) => tester
          .widget<FadeTransition>(
            find.descendant(of: owner, matching: find.byType(FadeTransition)),
          )
          .opacity
          .value;
      expect(
        opacity(find.byKey(ValueKey('dialog-scrim'))),
        closeTo(opacity(find.byKey(ValueKey('animation-fadeScale'))), 0.000001),
      );
    }

    verify();
    await tester.tap(find.byKey(ValueKey('toggle-fadeScale')));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 50));
    verify();
    await tester.tap(find.byKey(ValueKey('toggle-fadeScale')));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 16));
    verify();
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    verify();
    expect(tester.takeException(), isNull);
  });

  testWidgets('折叠箭头与面板在进出场和反转时保持同步', (tester) async {
    await tester.binding.setSurfaceSize(Size(1200, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ElAnimationExampleApp());
    void verify() {
      final vertical = find.byWidgetPredicate(
        (widget) =>
            widget is ElCollapseAnimation && widget.axis == Axis.vertical,
      );
      final factor = tester
          .widget<SizeTransition>(
            find.descendant(
              of: vertical,
              matching: find.byType(SizeTransition),
            ),
          )
          .sizeFactor
          .value;
      final turns = tester
          .widget<RotationTransition>(
            find.descendant(
              of: find.byKey(ValueKey('collapse-arrow')),
              matching: find.byType(RotationTransition),
            ),
          )
          .turns
          .value;
      expect(turns * 2, closeTo(factor, 0.000001));
    }

    verify();
    await tester.tap(find.byKey(ValueKey('toggle-collapseVertical')));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 50));
    verify();
    await tester.tap(find.byKey(ValueKey('toggle-collapseVertical')));
    await tester.pump();
    await tester.pump(Duration(milliseconds: 16));
    verify();
    await tester.pumpAndSettle(Duration(milliseconds: 16));
    verify();
    expect(tester.takeException(), isNull);
  });
}

List<ElSwitcherAnimation> _animations(WidgetTester tester) => tester
    .widgetList<ElSwitcherAnimation>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ElSwitcherAnimation &&
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith('animation-'),
      ),
    )
    .toList();
