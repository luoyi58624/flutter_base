import 'package:example/src/pages/settings/create_vs_update/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/mobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('重建会销毁并创建，更新只刷新已有条目', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ElComponentProvider(
        components: el.mobileComponents,
        child: MaterialApp(home: CreateVsUpdatePage()),
      ),
    );
    await tester.pumpAndSettle();

    final createBefore = _stat(tester, 'create-stat');
    final updateBefore = _stat(tester, 'update-stat');
    expect(createBefore.created, 1);
    expect(createBefore.disposed, 0);
    expect(updateBefore.created, 1);
    expect(updateBefore.disposed, 0);

    await tester.tap(find.byKey(ValueKey('create-switch')));
    await tester.pumpAndSettle();
    final created = _stat(tester, 'create-stat');
    final updateAfterCreate = _stat(tester, 'update-stat');
    expect(created.lastCreated, 1);
    expect(created.lastDisposed, 1);
    expect(created.lastUpdated, 0);
    expect(updateAfterCreate.created, updateBefore.created);
    expect(updateAfterCreate.disposed, 0);

    await tester.tap(find.byKey(ValueKey('update-switch')));
    await tester.pumpAndSettle();
    final updated = _stat(tester, 'update-stat');
    final createAfterUpdate = _stat(tester, 'create-stat');
    expect(updated.lastCreated, 0);
    expect(updated.lastDisposed, 0);
    expect(updated.lastUpdated, 1);
    expect(updated.created, updateBefore.created);
    expect(createAfterUpdate.disposed, created.disposed);
    expect(tester.takeException(), isNull);
  });
}

_Counts _stat(WidgetTester tester, String key) {
  final text = tester.widget<Text>(find.byKey(ValueKey(key))).data!;
  int field(String label) => int.parse(RegExp('$label (\\d+)').firstMatch(text)!.group(1)!);
  return _Counts(field('累计创建'), field('累计销毁'), field('上次创建'), field('上次销毁'), field('上次更新'));
}

class _Counts {
  _Counts(this.created, this.disposed, this.lastCreated, this.lastDisposed, this.lastUpdated);

  final int created;
  final int disposed;
  final int lastCreated;
  final int lastDisposed;
  final int lastUpdated;
}
