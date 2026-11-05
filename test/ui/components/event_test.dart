import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_base/desktop.dart';
import 'package:flutter_base/mobile.dart' show ElMobileExt;
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {required bool desktop}) => Directionality(
  textDirection: .ltr,
  child: desktop
      ? ElComponentProvider(
          components: el.desktopComponents,
          child: Center(child: child),
        )
      : ElComponentProvider(
          components: el.mobileComponents,
          child: Center(child: child),
        ),
);

void main() {
  for (final desktop in [true, false]) {
    testWidgets('event 与默认动作组合执行，preventDefault 阻止默认动作：desktop=$desktop', (tester) async {
      var taps = 0;
      var presses = 0;
      var prevent = true;
      final event = ElEvent(
        onTap: (event) {
          taps++;
          if (prevent) event.preventDefault();
        },
      );
      final toggle = ValueNotifier(false);
      final switched = ValueNotifier(false);
      addTearDown(toggle.dispose);
      addTearDown(switched.dispose);
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: .min,
            children: [
              ElButton(key: ValueKey('button'), event: event, onPressed: () => presses++, child: '按钮'),
              ElButton.toggle(key: ValueKey('toggle'), event: event, modelValue: toggle, child: '切换'),
              ElSwitch(key: ValueKey('switch'), event: event, modelValue: switched),
            ],
          ),
          desktop: desktop,
        ),
      );
      Future<void> tapAll() async {
        for (final key in ['button', 'toggle', 'switch']) {
          await tester.tap(find.byKey(ValueKey(key)), kind: PointerDeviceKind.mouse);
          await tester.pumpAndSettle();
        }
      }

      await tapAll();
      expect(taps, 3);
      expect((presses, toggle.value, switched.value), (0, false, false));

      prevent = false;
      await tapAll();
      expect(taps, 6);
      expect((presses, toggle.value, switched.value), (1, true, true));
    });
  }
}
