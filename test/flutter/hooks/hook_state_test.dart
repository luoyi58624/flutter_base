import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('useHookState 按 keys 重建并释放旧状态', (tester) async {
    final events = <String>[];
    late _LocalState current;
    Widget scene(int key) => HookBuilder(
      builder: (_) {
        current = useHookState(() => _LocalState(events), keys: [key]);
        return Text('${current.count}', textDirection: TextDirection.ltr);
      },
    );
    await tester.pumpWidget(scene(1));
    final first = current;
    current.count = 2;
    current.notify();
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await tester.pumpWidget(scene(1));
    expect(current, same(first));
    await tester.pumpWidget(scene(2));
    expect(current, isNot(same(first)));
    expect(events.where((event) => event == 'init').length, 2);
    expect(events.where((event) => event == 'dispose').length, 1);
    await tester.pumpWidget(SizedBox());
    expect(events.where((event) => event == 'dispose').length, 2);
  });
}

class _LocalState extends ElHookState {
  _LocalState(this.events);
  final List<String> events;
  int count = 0;
  @override
  void initState() => events.add('init');
  @override
  void dispose() {
    events.add('dispose');
    super.dispose();
  }
}
