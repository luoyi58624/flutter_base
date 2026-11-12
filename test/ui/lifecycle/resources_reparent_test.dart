import '../support/overlay.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_base/ui.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/reparent.dart';

Future<Uint8List> png() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(ui.Rect.fromLTWH(0, 0, 8, 6), ui.Paint()..color = ui.Color(0xff123456));
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 6);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Future<void> imageFrames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: 30)));
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  for (final initiallyLoaded in [false, true]) {
    testWidgets('Image 解码前后重挂，加载结果和事件仍可用 loaded=$initiallyLoaded', (tester) async {
      final bytes = (await tester.runAsync(png))!;
      final move = GlobalKey<ReparentHarnessState>();
      final imageKey = GlobalKey();
      var loaded = 0, taps = 0;
      await tester.pumpWidget(
        lifecycleHost(
          ReparentHarness(
            key: move,
            child: ElImageView.memory(
              bytes,
              key: imageKey,
              width: 80,
              height: 60,
              placeholder: ElView(key: ValueKey('placeholder'), child: 'loading'),
              onLoad: (info) {
                loaded++;
                expect(info.width, 8);
                expect(info.height, 6);
              },
              event: ElEvent(onTap: (_) => taps++),
            ),
          ),
        ),
      );
      if (initiallyLoaded) await imageFrames(tester);
      for (var i = 0; i < 3; i++) {
        await reparent(tester, move, settle: false);
        await imageFrames(tester);
        expect(find.byKey(ValueKey('placeholder')), findsNothing);
        await tester.tap(find.byKey(imageKey));
        await tester.pump();
        expect(taps, i + 1);
      }
      expect(loaded, 1, reason: '相同来源重新接入不能重复发 onLoad');
      await tester.pumpWidget(ElView());
      await imageFrames(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Image 解码在永久卸载后完成不调用旧业务回调', (tester) async {
    final bytes = (await tester.runAsync(png))!;
    var callbacks = 0;
    await tester.pumpWidget(
      lifecycleHost(ElImageView.memory(bytes, onLoad: (_) => callbacks++, onError: (_) => callbacks++)),
    );
    await tester.pumpWidget(ElView());
    await imageFrames(tester);
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Portal 迁移到新 Overlay 后保留身份和命中，旧 Overlay 完成销毁', (tester) async {
    final move = GlobalKey<ReparentHarnessState>();
    final leaf = GlobalKey();
    var hits = 0;
    final portal = ElPortalController();
    addTearDown(portal.dispose);
    await tester.pumpWidget(
      lifecycleHost(
        ReparentHarness(
          key: move,
          wrap: (_, child) => ElTestOverlay(child: child),
          child: ElPortal(
            controller: portal,
            anchor: ElOverlayAnchor(placement: .bottomStart, offset: -80, viewportPadding: 0),
            overlayBuilder: (_) => ElView(
              key: leaf,
              style: ElStyle(width: 120, height: 80),
              event: ElEvent(onTap: (_) => hits++),
              child: '浮层',
            ),
            child: SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );
    portal.open();
    await tester.pumpAndSettle();
    var host = Overlay.of(leaf.currentContext!);
    final render = leaf.currentContext!.findRenderObject();
    for (var i = 0; i < 3; i++) {
      await reparent(tester, move);
      final next = Overlay.of(leaf.currentContext!);
      expect(next, isNot(same(host)));
      expect(host.mounted, isFalse);
      expect(leaf.currentContext!.findRenderObject(), same(render));
      await tester.tap(find.byKey(leaf));
      await tester.pump();
      expect(hits, i + 1);
      host = next;
    }
    await tester.pumpWidget(ElView());
    expect(host.mounted, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final selected in [false, true]) {
    testWidgets('Editable 重挂保留正文选区，重新聚焦后 IME 继续编辑 selected=$selected', (tester) async {
      final move = GlobalKey<ReparentHarnessState>();
      final controller = ElEditableController(text: 'original text');
      final focus = FocusNode();
      final editor = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: ReparentHarness(
            key: move,
            child: ElEditableView(key: editor, controller: controller, focusNode: focus),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byKey(editor));
      for (var i = 0; i < 3; i++) {
        final selection = selected ? TextSelection(baseOffset: 0, extentOffset: 3) : TextSelection.collapsed(offset: 3);
        controller.setSelection(selection);
        await tester.pump();
        final before = controller.text;
        await reparent(tester, move, settle: false);
        expect(tester.state(find.byKey(editor)), same(state));
        expect(controller.text, before);
        expect(controller.selection, selection);
        focus.requestFocus();
        await tester.pump();
        expect(tester.testTextInput.hasAnyClients, isTrue);
        tester.testTextInput.enterText('edited-$i');
        await tester.pump();
        expect(controller.text, 'edited-$i');
        expect(controller.selection.extentOffset, 'edited-$i'.length);
      }
      await tester.pumpWidget(ElView());
      expect(tester.testTextInput.hasAnyClients, isFalse);
      controller.dispose();
      focus.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Editable 更换外部控制器后旧数据不再写入 IME，销毁后外部控制器仍可用', (tester) async {
    final a = ElEditableController(text: 'first');
    final b = ElEditableController(text: 'second');
    final current = ValueNotifier<ElEditableController>(a);
    final focus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<ElEditableController>(
          valueListenable: current,
          builder: (_, controller, _) => ElEditableView(controller: controller, focusNode: focus),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    current.value = b;
    await tester.pump();
    await tester.pump();
    a.text = 'stale';
    await tester.pump();
    expect(tester.testTextInput.editingState!['text'], 'second');
    tester.testTextInput.enterText('new-value');
    await tester.pump();
    expect(b.text, 'new-value');
    expect(a.text, 'stale');
    await tester.pumpWidget(ElView());
    a.text = 'still-owned';
    b.text = 'still-owned';
    a.dispose();
    b.dispose();
    current.dispose();
    focus.dispose();
    expect(tester.takeException(), isNull);
  });
}
