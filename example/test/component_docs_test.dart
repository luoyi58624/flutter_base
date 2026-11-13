import 'package:example/src/pages/components/index.dart';
import 'package:example/src/widgets/code_preview/index.dart';
import 'package:example/src/widgets/docs_page/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

final _pages = <(String, String, int)>[
  ('icon', 'basic/icon', 3),
  ('text', 'basic/text', 2),
  ('tag', 'basic/tag', 2),
  ('input', 'form/input', 2),
  ('input-number', 'form/input_number', 2),
  ('input-otp', 'form/input_otp', 2),
  ('input-tag', 'form/input_tag', 2),
  ('autocomplete', 'form/autocomplete', 2),
  ('mention', 'form/mention', 2),
  ('select', 'form/select', 2),
  ('switch', 'form/switch', 2),
  ('radio', 'form/radio', 2),
  ('checkbox', 'form/checkbox', 2),
  ('segmented', 'form/segmented', 2),
  ('slider', 'form/slider', 2),
  ('calendar', 'form/calendar', 2),
  ('form', 'form/form', 2),
  ('card', 'layout/card', 2),
  ('divider', 'layout/divider', 2),
  ('collapse', 'layout/collapse', 2),
  ('tabs', 'layout/tabs', 2),
  ('list-group', 'list/list_group', 3),
  ('avatar', 'data/avatar', 2),
  ('badge', 'data/badge', 2),
  ('progress', 'data/progress', 2),
  ('skeleton', 'data/skeleton', 2),
  ('steps', 'data/steps', 2),
  ('alert', 'feedback/alert', 2),
  ('loading', 'feedback/loading', 2),
  ('toast', 'feedback/toast', 2),
  ('message', 'feedback/message', 2),
  ('dialog', 'feedback/dialog', 4),
  ('drawer', 'feedback/drawer', 2),
  ('tooltip', 'feedback/tooltip', 2),
  ('popover', 'feedback/popover', 3),
  ('popup-menu', 'feedback/popup_menu', 4),
];

void main() {
  testWidgets('普通正文和源码示例共用文档目录', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(1100, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final source = 'lib/src/pages/components/basic/button/examples/example1.dart';
    await tester.pumpWidget(
      ElComponentProvider(
        components: el.desktopComponents,
        child: MaterialApp(
          home: DocsPage(
            title: '使用指南',
            navTitle: '指南',
            sections: [
              DocsSection(
                title: '说明',
                child: SizedBox(height: 900, child: Text('说明正文')),
              ),
              DocsSection(title: '示例', source: source, child: Text('示例正文')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '指南'), findsOneWidget);
    final anchor = find.byType(ElAnchor);
    expect(tester.widget<ElAnchor>(anchor).links, ['说明', '示例']);
    expect(
      find.descendant(of: find.widgetWithText(DocsSection, '说明正文'), matching: find.byType(ElCodeExample)),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: anchor,
        matching: find.byWidgetPredicate((widget) => widget is ElButtonView && widget.child == '示例'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('示例正文').hitTestable(), findsOneWidget);
    final card = find.byType(ElCodeExample);
    final bundle = DefaultAssetBundle.of(tester.element(card));
    final code = await tester.runAsync(() => bundle.loadString(source));
    await tester.pumpAndSettle();
    expect(tester.widget<ElCodeExample>(card).code, code);
    expect(tester.takeException(), isNull);
  });

  for (final mobile in [true, false]) {
    for (final (key, directory, count) in _pages) {
      testWidgets('${mobile ? '移动' : '桌面'} $key 文档、源码与窄屏逐节布局', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(320, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final sources = [
          for (var i = 1; i <= count; i++) 'lib/src/pages/components/$directory/examples/example$i.dart',
        ];
        final code = (await tester.runAsync(() => Future.wait(sources.map(rootBundle.loadString))))!;
        final page = componentCatalog.expand((group) => group.children).firstWhere((page) => page.key == key);
        await tester.pumpWidget(
          ElComponentProvider(
            components: mobile ? el.mobileComponents : el.desktopComponents,
            child: MaterialApp(home: Builder(builder: page.data!)),
          ),
        );
        await tester.pump();
        await tester.pump(Duration(milliseconds: 400));
        final missing = mobile
            ? ['input-number', 'input-otp', 'input-tag', 'mention'].contains(key)
            : key == 'skeleton';
        if (missing) {
          expect(find.byType(DocsPage), findsNothing);
          expect(find.widgetWithText(AppBar, page.title), findsOneWidget);
        } else {
          expect(find.byType(DocsPage), findsOneWidget);
          for (var i = 0; i < count; i++) {
            await Scrollable.ensureVisible(tester.element(find.byKey(ValueKey(sources[i]))));
            await tester.pump();
            await tester.runAsync(() async {});
            await tester.pump(Duration(milliseconds: 400));
            final section = find.byKey(ValueKey(sources[i]));
            expect(section, findsOneWidget);
            final card = find.descendant(of: section, matching: find.byType(ElCodeExample));
            expect(tester.widget<ElCodeExample>(card).code, code[i]);
            expect(tester.takeException(), isNull, reason: sources[i]);
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(SizedBox());
      });
    }
  }
}
