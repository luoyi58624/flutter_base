import 'package:flutter/material.dart';
import 'package:flutter_base/flutter_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('精确监听器跳过未改变选择结果的通知', (tester) async {
    final model = _Model();
    addTearDown(model.dispose);
    var builds = 0;
    await tester.pumpWidget(
      ElListenableBuilder<_Model, int>(
        listenable: model,
        select: (value) => value.count,
        builder: (_, _) {
          builds++;
          return Text('${model.count}', textDirection: TextDirection.ltr);
        },
      ),
    );
    model.refresh();
    await tester.pump();
    expect(builds, 1);
    model.count = 1;
    model.refresh();
    await tester.pump();
    expect(builds, 2);
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(SizedBox());
  });
}

class _Model extends ChangeNotifier {
  int count = 0;
  void refresh() => notifyListeners();
}
