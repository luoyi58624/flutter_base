import 'package:flutter/material.dart';
import 'package:flutter_base/flutter.dart' show ElTokens, ElThemeContextExt;
import 'package:flutter_base/ui.dart' show ElView, ElStyle, ElThemeMode;
import 'package:flutter_base/mobile.dart' show ElMobileTheme;
import 'package:flutter_base/desktop.dart' show ElDesktopTheme;
import 'package:flutter_test/flutter_test.dart';

import 'theme_tokens_readers.dart';

void main() {
  for (final mobile in [true, false]) {
    for (final dark in [false, true]) {
      testWidgets('${mobile ? 'mobile' : 'desktop'} ${dark ? 'dark' : 'light'} 完整提供公共 token，读取不改值', (tester) async {
        final brightness = dark ? Brightness.dark : Brightness.light;
        final expected = mobile
            ? {...ElMobileTheme.lightVars, if (dark) ...ElMobileTheme.darkVars}
            : {...ElDesktopTheme.lightVars, if (dark) ...ElDesktopTheme.darkVars};
        late Map<Object, Object> actual;
        final reader = Builder(
          builder: (context) {
            actual = {for (final entry in tokenReaders.entries) entry.key: entry.value(context.elTheme)};
            return SizedBox();
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: mobile
                ? ElMobileTheme(brightness: brightness, child: reader)
                : ElDesktopTheme(
                    themeMode: ElThemeMode(brightness: brightness),
                    child: reader,
                  ),
          ),
        );
        for (final key in tokenReaders.keys) {
          expect(expected.containsKey(key), isTrue, reason: '品牌必须提供 $key');
          expect(actual[key], expected[key], reason: '$key');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('仅使用 flutter 规范和 ElView 就能逐键读取，不依赖品牌或隐藏默认值', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: ElView(
          style: ElStyle(vars: {ElTokens.$cardPressColor: Colors.green, ElTokens.$dividerColor: Colors.purple}),
          child: Builder(
            builder: (value) {
              context = value;
              return SizedBox();
            },
          ),
        ),
      ),
    );
    expect(context.elTheme.cardPressColor, Colors.green);
    expect(context.elTheme.dividerColor, Colors.purple);
    expect(() => context.elTheme.bgColor, throwsStateError);
    expect(tester.takeException(), isNull);
  });

  testWidgets('边框色阶是独立 token，改基础边框不重建色阶读者', (tester) async {
    var border = Colors.blue;
    var baseBuilds = 0, lightBuilds = 0;
    late StateSetter update;
    final reader = Row(
      children: [
        Builder(
          builder: (context) {
            baseBuilds++;
            context.elTheme.borderColor;
            return SizedBox();
          },
        ),
        Builder(
          builder: (context) {
            lightBuilds++;
            expect(context.elTheme.borderColorLight, Colors.green);
            return SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ElView(
              style: ElStyle(vars: {ElTokens.$borderColor: border, ElTokens.$borderColorLight: Colors.green}),
              child: reader,
            );
          },
        ),
      ),
    );
    final before = (baseBuilds, lightBuilds);
    update(() => border = Colors.red);
    await tester.pumpAndSettle();
    expect(baseBuilds, before.$1 + 1);
    expect(lightBuilds, before.$2);
    expect(tester.takeException(), isNull);
  });
}
